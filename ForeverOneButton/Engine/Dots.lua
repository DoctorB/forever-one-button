-- Forever One Button: own debuffs on the target, counted from own casts.
--
-- Target debuffs cannot be read in combat on Forever, so:
--   * a DoT counts as up when the player cast it on the current target within
--     its duration (Defaults.targetDots: spell -> seconds, any rank); Forever
--     has no pandemic window, so it is refreshed once it has run out;
--   * a stacking debuff named by a target stack gate of the lists (Sunder
--     Armor...) counts one application per cast on the current target, each
--     cast refreshing it, up to its maximum.
-- A cast remembers the target's GUID (when readable) and a counter that
-- changes on every target change; the GUID decides when both sides have
-- one, the counter otherwise (the GUID can turn secret in combat).
local ADDON_NAME, ns = ...

local Dots = {}
ns.Dots = Dots

-- Stacking debuffs: duration and maximum applications. Sunder Armor lasts
-- 30 s and stacks to 5 (the imported DoT table lists it with 5 s).
Dots.STACKING = {[7386] = {duration = 30, max = 5}}
Dots.DEFAULT_STACKING = {duration = 30, max = 5}

local applied = {}  -- [rank-1 id] = {target, at}
local stacks = {}   -- [rank-1 id] = {target, at, count}
local targetSerial = 0

local function TargetGUID()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "target")
    if ok and ns.Readable(guid) then return guid end
    return nil
end

local function Here()
    return {guid = TargetGUID(), serial = targetSerial}
end

local function SameTarget(entry)
    local guid = TargetGUID()
    if guid and entry.target.guid then return guid == entry.target.guid end
    return entry.target.serial == targetSerial
end

local stacked -- [rank-1 id] = true for every target stack gate in the data
local function Stacked(first)
    if not stacked then
        stacked = {}
        local function Scan(gates)
            for _, gate in ipairs(gates or {}) do
                if gate.t == "stack" and gate.tgt then stacked[gate.id] = true end
                if gate.g then Scan(gate.g) end
            end
        end
        for _, trees in pairs(ns.Data.Rotations.classes) do
            for tree, contexts in pairs(trees) do
                if tree ~= "default" then
                    for _, list in pairs(contexts) do
                        for _, entry in ipairs(list) do Scan(entry.gates) end
                    end
                end
            end
        end
    end
    return stacked[first] == true
end

local function DotDuration(first)
    local durations = ns.Data.Defaults.targetDots
    return durations[first]
end

function Dots.NoteCast(spellID)
    local first = ns.Ranks.Base(spellID)
    local now = GetTime()
    if Stacked(first) then
        local spec = Dots.STACKING[first] or Dots.DEFAULT_STACKING
        local s = stacks[first]
        if s and SameTarget(s) and now - s.at < spec.duration then
            s.count, s.at, s.target = math.min(s.count + 1, spec.max), now, Here()
        else
            stacks[first] = {target = Here(), at = now, count = 1}
        end
    elseif DotDuration(first) then
        applied[first] = {target = Here(), at = now}
    end
end

-- true when the DoT should still be on the current target, false when not,
-- nil for spells that are not DoTs.
function Dots.Active(spellID)
    local first = ns.Ranks.Base(spellID)
    if Stacked(first) then return nil end
    local duration = DotDuration(first)
    if not duration then return nil end
    local entry = applied[first]
    if not entry or not SameTarget(entry) then return false end
    return GetTime() - entry.at < duration
end

-- Own applications of a stacking debuff on the current target, or nil for
-- spells that are not tracked.
function Dots.Stacks(spellID)
    local first = ns.Ranks.Base(spellID)
    if not Stacked(first) then return nil end
    local spec = Dots.STACKING[first] or Dots.DEFAULT_STACKING
    local s = stacks[first]
    if not s or not SameTarget(s) or GetTime() - s.at >= spec.duration then return 0 end
    return s.count
end

function Dots.Reset()
    wipe(applied)
    wipe(stacks)
end

local frame = CreateFrame("Frame")
Dots.frame = frame
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function() targetSerial = targetSerial + 1 end)
