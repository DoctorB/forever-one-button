-- Optional diagnostic log: records pixel writes, casts and edges without
-- changing the protocol or storing secret values.
local H = dofile("tests/harness/wow.lua")
GetTimePreciseSec = function() return H.now end
function GetBuildInfo() return "1.60.1", "70374", "Oct 12 2026", 16001 end

local ns = H.Boot(nil, nil)
local lib = H.InstallQueue()
H.spells[6603] = {name = "Strike"}
H.spells[2687] = {name = "Rend"}
H.Check(ns.Actions.Assign(3, "spell", 6603), "Strike on 3")
H.Check(ns.Actions.Assign(4, "spell", 2687), "Rend on 4")

-- Off by default: nothing recorded.
lib.Set({6603})
H.Tick(0.2)
H.Equal(#ForeverOneButtonLog.entries, 0, "nothing logged while off")
H.Equal(ForeverOneButtonLog.enabled, false, "off by default")

ns.Commands.Handle("log on")
H.Check(ForeverOneButtonLog.entries[1]:find("|session|" .. ns.VERSION .. "|1.60.1.70374", 1, true), "session header")

-- Same spell suggested again and again ("spam"), each press succeeds.
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Tick(0.05) -- the first press comes after the colour has been on screen
for _ = 1, 4 do
    H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 6603)
    H.Tick(0.1)
end
-- A press that did nothing (no cast event) changes nothing; an unrelated cast
-- is logged as not acknowledged; a secret spell ID is logged as "secret".
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 9999)
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", H.Secret())
H.Tick(0.1)
lib.Set({2687})
H.Tick(0.1)
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")

local s = ns.Diagnostics.Summary()
H.Equal(s.casts, 6, "six casts logged")
-- Queue lines end with why each candidate waits ("-" when the queue has none).
local queueLine
for _, line in ipairs(ForeverOneButtonLog.entries) do
    if line:find("|queue|", 1, true) then queueLine = line end
end
H.Check(queueLine ~= nil, "queue logged")
local fields = 0
for _ in (queueLine .. "|"):gmatch("([^|]*)|") do fields = fields + 1 end
H.Equal(fields, 10, "queue line: time, kind, status, tree, context, count, candidates, ready, detail, why")
H.Equal(s.secretCasts, 1, "secret ID recorded as such")
H.Equal(s.acknowledged, 4, "four acknowledged casts")
H.Equal(#s.edges, 4, "four black edges")
H.Equal(s.short, 0, "no edge shorter than 60 ms")
H.Check(s.minimum >= 0.060 - 1e-9, "minimum edge >= 60 ms")
for _, edge in ipairs(s.edges) do
    H.Equal(edge.before, "3", "colour before the edge: cell 3")
    H.Equal(edge.after, "3", "same colour after the edge (same spell again)")
end
local text = table.concat(ForeverOneButtonLog.entries, "\n")
H.Check(text:find("|cast|secret|0"), "secret cast line")
H.Check(text:find("|cast|9999|0"), "unrelated cast line")
H.Check(text:find("|combat|in") and text:find("|combat|out"), "combat transitions")
H.Check(text:find("|head|2687|"), "suggestion change")
H.Check(not text:find("userdata"), "no raw values stored")

-- Pixel timeline: every slot colour names the cell content and key; the
-- timeline merges writes into visible states with durations.
H.Check(text:find("|pixel|3|%d+%.%d+|spell 6603 Strike / SHIFT%-3"), "slot colour logged with cell content and key")
local timeline = ns.Diagnostics.Timeline()
local states = {}
for _, segment in ipairs(timeline.segments) do states[#states + 1] = segment.state end
H.Equal(table.concat(states, ","), "3,black,3,black,3,black,3,black,3,4,black",
    "five Strike cycles split by black edges, then Rend (cell 4), then black out of combat")
H.Equal(timeline.cycles, 6, "six recommendation cycles")
H.Equal(timeline.shortStates, 0, "no state shorter than one 50 Hz sample")
H.Check(timeline.segments[2].duration >= 0.060 - 1e-9, "black between cycles >= 60 ms")

-- In-game report works.
local before = #H.printed
ns.Commands.Handle("log show 5")
H.Check(#H.printed > before + 2, "summary printed")
H.Check(H.printed[before + 2]:find("edges 4"), "edges reported")

-- The log survives a reload (SavedVariables) and stays on.
local saved = ForeverOneButtonLog
local count = #saved.entries
ns = H.Boot(ForeverOneButtonDB, ForeverOneButtonCharDB)
ForeverOneButtonLog = saved
ns.Diagnostics.Load()
H.Equal(#ForeverOneButtonLog.entries, count, "entries kept across reload")
H.Check(ns.Diagnostics.IsEnabled(), "still on after reload")

-- Bounded size.
H.Equal(ns.Diagnostics.MAX_ENTRIES, 20000, "a 2-3 hour session fits")
ns.Commands.Handle("log clear")
for i = 1, ns.Diagnostics.MAX_ENTRIES + 50 do ns.Log("pixel", "black", i) end
local entries = ForeverOneButtonLog.entries
H.Check(#entries <= ns.Diagnostics.MAX_ENTRIES, "capped")
H.Equal(#entries, ns.Diagnostics.MAX_ENTRIES - ns.Diagnostics.TRIM_ENTRIES + 50, "oldest dropped in one batch")
H.Check(entries[#entries]:find("|" .. (ns.Diagnostics.MAX_ENTRIES + 50) .. "$"), "newest kept last")
for i = 2, #entries do
    local previous, current = tonumber(entries[i - 1]:match("(%d+)$")), tonumber(entries[i]:match("(%d+)$"))
    if previous and current and current ~= previous + 1 then H.Check(false, "order kept") break end
end

-- Refused presses and failed casts are logged (only while logging).
ns.Commands.Handle("log clear")
H.Fire("UI_ERROR_MESSAGE", 50, "Target needs to be in front of you.")
H.Fire("UNIT_SPELLCAST_FAILED", "player", "guid", 1752)
H.Fire("UNIT_SPELLCAST_FAILED", "target", "guid", 1752)
H.Check(ForeverOneButtonLog.entries[1]:find("|error|50|Target needs to be in front of you.", 1, true), "ui error logged")
H.Check(ForeverOneButtonLog.entries[2]:find("|failed|1752", 1, true), "failed cast logged")
H.Equal(#ForeverOneButtonLog.entries, 2, "other units ignored")

ns.Commands.Handle("log clear")
H.Equal(#ForeverOneButtonLog.entries, 0, "cleared")
ns.Commands.Handle("log off")
ns.Log("pixel", "black")
H.Equal(#ForeverOneButtonLog.entries, 0, "off again")

H.Done("test_diagnostics")
