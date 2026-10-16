-- Forever One Button: damage over time already ticking on the target.
--
-- Target debuffs cannot be read in combat on Forever, so a DoT counts as up
-- when the player cast it on the current target within its duration
-- (Defaults.targetDots: spell -> seconds, any rank). Forever has no pandemic
-- window: a DoT is refreshed once it has run out.
local ADDON_NAME, ns = ...

local Dots = {}
ns.Dots = Dots

local applied = {} -- [rank-1 id] = {guid, at}

local function Duration(spellID)
    local durations = ns.Data.Defaults.targetDots
    return durations[spellID] or durations[ns.Ranks.Base(spellID)]
end

local function TargetGUID()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "target")
    if not ok or not ns.Readable(guid) then return nil end
    return guid
end

function Dots.NoteCast(spellID)
    if not Duration(spellID) then return end
    local guid = TargetGUID()
    if guid then applied[ns.Ranks.Base(spellID)] = {guid = guid, at = GetTime()} end
end

-- true when the DoT should still be on the current target, false when not,
-- nil for spells that are not DoTs.
function Dots.Active(spellID)
    local duration = Duration(spellID)
    if not duration then return nil end
    local entry = applied[ns.Ranks.Base(spellID)]
    if not entry or entry.guid ~= TargetGUID() then return false end
    return GetTime() - entry.at < duration
end

function Dots.Reset() wipe(applied) end
