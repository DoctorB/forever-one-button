-- Forever One Button: optional diagnostic log (off by default).
--
-- Records what the addon does with the pixel so the protocol behaviour can be
-- checked in game: every colour written, every player UNIT_SPELLCAST_SUCCEEDED
-- received and whether it produced the acknowledgement edge, suggestion
-- changes and combat transitions. It never alters the protocol, never adds a
-- pixel and never stores a secret value: a secret is recorded as "secret".
--
-- Storage: ForeverOneButtonLog (account SavedVariables, written by the client
-- on /reload or logout), one string per entry:
--   "<seconds>|pixel|black|white|<slot>|<frame time>[|<cell content>]"
--     <cell content> for a slot: "<spell or item ID> <name> / <key>", i.e.
--     the action that slot stands for
--   "<seconds>|cast|<spellID or secret>|<1 = acknowledged, 0 = not>"
--   "<seconds>|head|<JustAC ID or none>|<flags: c casting, r out of range, o out of combat>"
--   "<seconds>|combat|in|out"
--   "<seconds>|session|<addon version>|<client build>"
-- <seconds> is GetTimePreciseSec (when the code ran). <frame time> is GetTime,
-- the time of the frame being built: the acknowledgement edge is timed on it,
-- as in HCOneButton, and it is what the screen shows, so edges are measured
-- on frame times.
-- The pixel lines form the timeline of what the screen shows:
-- Diagnostics.Timeline merges them into visible states with durations.
-- scripts/analyze_log.py reads that file.
local ADDON_NAME, ns = ...

local Diagnostics = {}
ns.Diagnostics = Diagnostics

Diagnostics.MAX_ENTRIES = 5000
Diagnostics.ACK_MIN_SECONDS = 0.060
-- 20 ms is one frame at 50 Hz (HCOneButton DiagnosticPixel.lua comment):
-- a visible state shorter than that can be missed when sampled at that rate.
Diagnostics.SAMPLE_SECONDS = 0.020

local log -- the entries table while logging, else nil

local function Now()
    if GetTimePreciseSec then
        local ok, t = pcall(GetTimePreciseSec)
        if ok and ns.Readable(t) then return t end
    end
    return GetTime and GetTime() or 0
end

function Diagnostics.FrameTime()
    if not log then return nil end
    return string.format("%.4f", GetTime and GetTime() or 0)
end

-- Keeps the saved table well formed; called on ADDON_LOADED.
function Diagnostics.Load()
    local saved = ForeverOneButtonLog
    if type(saved) ~= "table" or type(saved.entries) ~= "table" then
        saved = {entries = {}}
    end
    local entries = {}
    for i = math.max(1, #saved.entries - Diagnostics.MAX_ENTRIES + 1), #saved.entries do
        if type(saved.entries[i]) == "string" then entries[#entries + 1] = saved.entries[i] end
    end
    local function Lines(list)
        if type(list) ~= "table" then return nil end
        local out = {}
        for _, line in ipairs(list) do
            if type(line) == "string" then out[#out + 1] = line end
        end
        return out
    end
    ForeverOneButtonLog = {version = 1, enabled = saved.enabled == true, entries = entries,
        probe = Lines(saved.probe), probeFrames = Lines(saved.probeFrames)}
    log = ForeverOneButtonLog.enabled and ForeverOneButtonLog.entries or nil
end

function Diagnostics.IsEnabled()
    return log ~= nil
end

local function Field(value)
    if ns.IsSecret(value) then return "secret" end
    if value == nil then return "none" end
    return (tostring(value):gsub("|", "/"))
end

-- ns.Log(event, a, ...): a no-op unless logging is on. Trailing nil fields
-- are dropped.
function ns.Log(event, a, ...)
    if not log then return end
    if #log >= Diagnostics.MAX_ENTRIES then table.remove(log, 1) end
    local entry = string.format("%.4f|%s|%s", Now(), event, Field(a))
    local extra = {...}
    local last = select("#", ...)
    while last > 0 and extra[last] == nil do last = last - 1 end
    for i = 1, last do entry = entry .. "|" .. Field(extra[i]) end
    log[#log + 1] = entry
end

-- What a slot colour means right now: the action the cell executes and its
-- key. nil when off.
function Diagnostics.Describe(slot)
    if not log or type(slot) ~= "number" then return nil end
    local cell = ns.Actions.applied[slot]
    if not cell then return "empty" end
    local name = cell.kind == "spell" and ns.SpellName(cell.id) or ns.ItemName(cell.id)
    return string.format("%s %d %s / %s", cell.kind, cell.id, name or "?", ns.Actions.appliedKeys[slot] or "no key")
end

function Diagnostics.SetEnabled(enabled)
    ForeverOneButtonLog.enabled = enabled and true or false
    if enabled then
        log = ForeverOneButtonLog.entries
        local build = "unknown"
        if GetBuildInfo then
            local ok, version, number = pcall(GetBuildInfo)
            if ok and ns.Readable(version) then build = tostring(version) .. "." .. Field(number) end
        end
        ns.Log("session", ns.VERSION, build)
        ns.Log("combat", ns.InCombat() and "in" or "out")
    else
        log = nil
    end
end

function Diagnostics.Clear()
    for i = #ForeverOneButtonLog.entries, 1, -1 do ForeverOneButtonLog.entries[i] = nil end
end

local function Split(entry)
    local parts = {}
    for part in entry:gmatch("[^|]+") do parts[#parts + 1] = part end
    return tonumber(parts[1]), parts[2], parts[3], parts[4], parts[5]
end

-- Visible pixel states over time (frame times), consecutive identical writes
-- merged: what the screen shows. Returns segments
-- {state, start, duration (nil for the last), cell} and counts.
function Diagnostics.Timeline(entries)
    entries = entries or ForeverOneButtonLog.entries
    local segments = {}
    for _, entry in ipairs(entries) do
        local t, event, state, frame, cell = Split(entry)
        if event == "pixel" then
            t = tonumber(frame) or t
            local current = segments[#segments]
            if not current or current.state ~= state then
                if current then current.duration = t - current.start end
                segments[#segments + 1] = {state = state, start = t, cell = cell}
            end
        end
    end
    local result = {segments = segments, cycles = 0, shortStates = 0}
    for _, segment in ipairs(segments) do
        if segment.state ~= "black" then result.cycles = result.cycles + 1 end
        if segment.duration and segment.duration + 1e-6 < Diagnostics.SAMPLE_SECONDS then
            result.shortStates = result.shortStates + 1
        end
    end
    return result
end

-- Acknowledgement edges in the log: for every acknowledged cast, how long the
-- pixel stayed black and which colour came back.
function Diagnostics.Summary(entries)
    entries = entries or ForeverOneButtonLog.entries
    local result = {casts = 0, secretCasts = 0, acknowledged = 0, edges = {}, short = 0, open = 0, restarted = 0}
    -- The cast line is written right after the acknowledgement, so the black
    -- write of the edge is the pixel line just before it.
    local pendingAck, blackSince, colourBefore = nil, nil, nil
    local lastColour, previousColour, lastPixelTime = nil, nil, nil
    for _, entry in ipairs(entries) do
        local t, event, a, b = Split(entry)
        if event == "pixel" and tonumber(b) then t = tonumber(b) end
        if event == "cast" then
            result.casts = result.casts + 1
            if a == "secret" then result.secretCasts = result.secretCasts + 1 end
            if b == "1" then
                result.acknowledged = result.acknowledged + 1
                -- A second acknowledged cast before the colour came back
                -- (e.g. two swings within 60 ms) restarts the same edge.
                -- The black already on screen continues: keep its start.
                local restarting = pendingAck ~= nil and blackSince ~= nil
                if pendingAck then result.restarted = result.restarted + 1 end
                pendingAck = t
                if restarting then
                    -- edge continues
                elseif lastColour == "black" then
                    blackSince, colourBefore = lastPixelTime, previousColour
                else
                    blackSince, colourBefore = nil, lastColour
                end
            end
        elseif event == "pixel" then
            if pendingAck then
                if a == "black" then
                    blackSince = blackSince or t
                elseif blackSince then
                    local duration = t - blackSince
                    result.edges[#result.edges + 1] = {duration = duration, before = colourBefore, after = a}
                    if duration + 1e-6 < Diagnostics.ACK_MIN_SECONDS then result.short = result.short + 1 end
                    pendingAck = nil
                end
            end
            previousColour, lastColour, lastPixelTime = lastColour, a, t
        elseif event == "combat" and a == "out" and pendingAck then
            result.open = result.open + 1 -- edge ended by leaving combat (pixel stays black)
            pendingAck = nil
        end
    end
    if pendingAck then result.open = result.open + 1 end
    local total, minimum = 0, nil
    for _, edge in ipairs(result.edges) do
        total = total + edge.duration
        if not minimum or edge.duration < minimum then minimum = edge.duration end
    end
    result.minimum = minimum
    result.average = #result.edges > 0 and total / #result.edges or nil
    return result
end

function Diagnostics.Show(lines)
    local s = Diagnostics.Summary()
    ns.Print(string.format("log %s, %d entries", log and "on" or "off", #ForeverOneButtonLog.entries))
    ns.Print(string.format("casts %d (secret ID %d), acknowledged %d, edges %d (shorter than 60 ms: %d, restarted: %d, not closed: %d)",
        s.casts, s.secretCasts, s.acknowledged, #s.edges, s.short, s.restarted, s.open))
    if s.minimum then
        ns.Print(string.format("black edge: min %.1f ms, average %.1f ms", s.minimum * 1000, s.average * 1000))
    end
    local timeline = Diagnostics.Timeline()
    ns.Print(string.format("pixel timeline: %d visible states, %d recommendation cycles, %d states shorter than 20 ms",
        #timeline.segments, timeline.cycles, timeline.shortStates))
    local entries = ForeverOneButtonLog.entries
    for i = math.max(1, #entries - (lines or 12) + 1), #entries do ns.Print(entries[i]) end
end
