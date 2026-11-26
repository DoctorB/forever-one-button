-- Forever One Button: spells the current target cannot be affected by.
--
-- Two sources answer:
--   * creature-type rules (Data/TargetRules.lua): Exorcism only on undead
--     and demons, Polymorph only on humanoids, beasts and critters...;
--   * refusals seen: a cast the client refuses with "Invalid target" or
--     "Immune" marks the spell for that kind of creature (its NPC ID, or the
--     unit itself for players) until the next /reload;
--   * positional refusals: "You must be behind your target" (Garrote...)
--     holds the spell back on that one target only, until the target
--     changes (also when its GUID cannot be read), so the next opener is
--     suggested instead;
--   * "A more powerful spell is already active" (someone else's stronger
--     buff): the spell waits STRONGER_HOLD_SECONDS on every target;
--   * Pick Pocket or Sap tried on a target (cast or refused): the stealth
--     opener is not published on the pixel for that target (OpenerHeld), so
--     it never starts a fight the player did not choose.
-- The combat log is forbidden on Forever, so a hit that lands as "Immune"
-- after a successful cast is not learned.
-- Allows(spellID) answers true, false or nil (unknown); nil never blocks.
local ADDON_NAME, ns = ...

local Targets = {}
ns.Targets = Targets

-- The failed cast and its error message arrive together (4 ms apart in
-- the logs); a wider window paired a failure with someone else's error.
Targets.PAIR_SECONDS = 0.1

local function Plain(value)
    if value == nil or ns.IsSecret(value) then return nil end
    return value
end

-- Creature types ---------------------------------------------------------------
local TYPE_IDS = {Beast = 1, Dragonkin = 2, Demon = 3, Elemental = 4, Giant = 5, Undead = 6,
    Humanoid = 7, Critter = 8, Mechanical = 9, ["Not specified"] = 10, Totem = 11,
    ["Non-combat Pet"] = 12, ["Gas Cloud"] = 13}
local MAX_TYPE_ID = 13

-- Localized type name -> ID, from the client when it can tell, else English.
local typeByName
local function TypeIDByName(name)
    if not typeByName then
        typeByName = {}
        for english, id in pairs(TYPE_IDS) do typeByName[english] = id end
        local info = C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo
        if info then
            for id = 1, MAX_TYPE_ID do
                local ok, t = pcall(info, id)
                local localized = ok and type(t) == "table" and Plain(t.name)
                if type(localized) == "string" then typeByName[localized] = id end
            end
        end
    end
    return typeByName[name]
end

-- Creature type ID of the unit, nil when unknown.
function Targets.CreatureType(unit)
    if not UnitCreatureType then return nil end
    local ok, name, id = pcall(UnitCreatureType, unit or "target")
    if not ok then return nil end
    id = Plain(id)
    if type(id) == "number" then return id end
    name = Plain(name)
    if type(name) ~= "string" then return nil end
    return TypeIDByName(name)
end

-- Who the target is, for the refusals: "npc:<id>" for every creature of the
-- same kind, else the unit's GUID.
function Targets.Key()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "target")
    if not ok or not ns.Readable(guid) or type(guid) ~= "string" then return nil end
    local kind, npcID = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if (kind == "Creature" or kind == "Vehicle") and npcID then return "npc:" .. npcID end
    return guid
end

-- Answers ----------------------------------------------------------------------
local refused = {} -- [target key] = {[rank-1 id] = true}
local behind = {}  -- [rank-1 id] = {guid = GUID or nil, epoch = target epoch}
local stronger = {} -- [rank-1 id] = GetTime() until which a stronger aura blocks it
local targetEpoch = 0 -- bumped on every target change
local openerHeldOn -- GUID of the target of the last Pick Pocket / Sap

-- Pick Pocket and Sap (all ranks): the player chose not to open on that target.
Targets.HOLD_OPENER = {[921] = true, [6770] = true, [2070] = true, [11297] = true}

local function TargetGUID()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "target")
    if ok and ns.Readable(guid) and type(guid) == "string" then return guid end
    return nil
end

-- The target's type and key, read once per frame.
local cachedAt, cachedType, cachedKey = nil, nil, nil
local function Target()
    local now = GetTime()
    if now ~= cachedAt then
        cachedAt, cachedType, cachedKey = now, Targets.CreatureType("target"), Targets.Key()
    end
    return cachedType, cachedKey
end

function Targets.Allows(spellID)
    local base = ns.Ranks.Base(spellID)
    local creature, key = Target()
    if key and refused[key] and refused[key][base] then return false end
    if stronger[base] and GetTime() < stronger[base] then return false end
    local held = behind[base]
    if held and held.epoch == targetEpoch and (held.guid == nil or held.guid == TargetGUID())
        and (held.untilAt == nil or GetTime() < held.untilAt) then
        return false
    end
    local types = ns.Data.TargetRules.creatureTypes[base]
    if not types or not creature then return nil end
    for _, allowed in ipairs(types) do
        if allowed == creature then return true end
    end
    return false
end

function Targets.Refuse(spellID, key)
    if not (spellID and key) then return end
    refused[key] = refused[key] or {}
    refused[key][ns.Ranks.Base(spellID)] = true
    cachedAt = nil
    ns.Log("refused", spellID, key)
end

-- True while the target is the one of the last Pick Pocket / Sap.
function Targets.OpenerHeld()
    local guid = TargetGUID()
    return guid ~= nil and guid == openerHeldOn
end

local function HoldOpener(spellID)
    if not Targets.HOLD_OPENER[spellID] then return end
    local guid = TargetGUID()
    if not guid or guid == openerHeldOn then return end
    openerHeldOn = guid
    ns.Log("opener", "held", spellID)
end

-- "A more powerful spell is already active": someone else's stronger
-- version of the buff is up (battleground of 2026-11-22: Battle Shout
-- refused 72 times in 10 s, the pixel stuck on it until the player died).
-- The aura cannot be read in combat, so the spell waits a while, on any
-- target.
Targets.STRONGER_HOLD_SECONDS = 60
function Targets.HoldStronger(spellID)
    if not spellID then return end
    stronger[ns.Ranks.Base(spellID)] = GetTime() + Targets.STRONGER_HOLD_SECONDS
    cachedAt = nil
    ns.Log("refused", spellID, "stronger")
end

function Targets.Forget()
    wipe(refused)
    wipe(stronger)
    wipe(behind)
    openerHeldOn = nil
    cachedAt = nil
    if Targets.ForgetPending then Targets.ForgetPending() end
end

-- Learning from refusals -------------------------------------------------------
-- UNIT_SPELLCAST_FAILED names the spell, UI_ERROR_MESSAGE the reason; they
-- come in either order within the same moment.
local function RefusalMessages()
    return {
        [_G.SPELL_FAILED_BAD_TARGETS or "Invalid target"] = true,
        [_G.SPELL_FAILED_IMMUNE or "Immune"] = true,
        [_G.SPELL_FAILED_TARGET_IS_IMMUNE or "Target is immune"] = true,
    }
end

local function NotBehind()
    return _G.SPELL_FAILED_NOT_BEHIND or "You must be behind your target."
end

local function Stronger()
    return _G.SPELL_FAILED_AURA_BOUNCED or "A more powerful spell is already active"
end

-- Holds the spell back on the current target only (positional refusal),
-- until the target changes; also when its GUID cannot be read. With
-- `seconds`, at most that long (reason: the word written to the log).
function Targets.RefuseHere(spellID, seconds, reason)
    if not spellID then return end
    local guid = TargetGUID()
    behind[ns.Ranks.Base(spellID)] = {guid = guid, epoch = targetEpoch, untilAt = seconds and GetTime() + seconds or nil}
    cachedAt = nil
    reason = reason or "behind"
    ns.Log("refused", spellID, guid and reason or (reason .. "-noguid"))
end

-- A stronger debuff of someone else on the target (battleground of
-- 2026-11-25: another Warrior's Rend; the buff rule then held Rend back
-- for 60 s on every target): only that target waits, and no longer than
-- the debuff can last. Only a readable "harmful" counts; a buff, or a
-- spell the client says nothing about, keeps the rule for buffs.
Targets.STRONGER_DEBUFF_SECONDS = 30
local function Harmful(spellID)
    if not (C_Spell and type(C_Spell.IsSpellHarmful) == "function") then return false end
    local ok, harmful = pcall(C_Spell.IsSpellHarmful, spellID)
    return ok and not ns.IsSecret(harmful) and harmful == true
end

-- A refusal says something about a living enemy only: on a corpse, a
-- friendly or no target, "Invalid target" teaches nothing about the creature.
-- kind: "refused" (the creature), "behind" (this target), "stronger" (a
-- buff, any target).
-- An error of another kind ("Not enough rage") explains the failed cast
-- that comes with it: that cast is not paired with a refusal message
-- arriving for something else in the same moment.
local failedSpell, failedAt, errorAt, kind = nil, nil, nil, nil
local otherErrorAt
local function Near(a, b)
    return a ~= nil and b ~= nil and math.abs(a - b) <= Targets.PAIR_SECONDS
end
local function Pair()
    if failedSpell and failedAt and errorAt and math.abs(failedAt - errorAt) <= Targets.PAIR_SECONDS then
        if kind == "stronger" then
            if Harmful(failedSpell) and ns.State.TargetAttackable() then
                Targets.RefuseHere(failedSpell, Targets.STRONGER_DEBUFF_SECONDS, "stronger-here")
            else
                Targets.HoldStronger(failedSpell)
            end
        elseif ns.State.TargetAttackable() then
            if kind == "behind" then Targets.RefuseHere(failedSpell) else Targets.Refuse(failedSpell, Targets.Key()) end
        end
        failedSpell, failedAt, errorAt, kind = nil, nil, nil, nil
    end
end

function Targets.ForgetPending()
    failedSpell, failedAt, errorAt, kind, otherErrorAt = nil, nil, nil, nil, nil
end

local frame = CreateFrame("Frame")
Targets.frame = frame
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_FAILED", "player")
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(frame.RegisterEvent, frame, "UI_ERROR_MESSAGE")
pcall(frame.RegisterEvent, frame, "PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        targetEpoch = targetEpoch + 1
        cachedAt = nil
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = Plain(select(3, ...))
        if type(spellID) == "number" then HoldOpener(spellID) end
        return
    elseif event == "UNIT_SPELLCAST_FAILED" then
        local spellID = Plain(select(3, ...))
        if type(spellID) ~= "number" then return end
        HoldOpener(spellID)
        if Near(otherErrorAt, GetTime()) then
            otherErrorAt = nil
            return
        end
        failedSpell, failedAt = spellID, GetTime()
    else
        local message = Plain(select(2, ...))
        if type(message) ~= "string" then return end
        if message == NotBehind() then
            kind = "behind"
        elseif message == Stronger() then
            kind = "stronger"
        elseif RefusalMessages()[message] then
            kind = "refused"
        else
            if failedSpell and Near(failedAt, GetTime()) then
                failedSpell, failedAt = nil, nil
            else
                otherErrorAt = GetTime()
            end
            return
        end
        errorAt = GetTime()
    end
    Pair()
end)
