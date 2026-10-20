-- Forever One Button: spells the current target cannot be affected by.
--
-- Two sources answer:
--   * creature-type rules (Data/TargetRules.lua): Exorcism only on undead
--     and demons, Polymorph only on humanoids, beasts and critters...;
--   * refusals seen: a cast the client refuses with "Invalid target" or
--     "Immune" marks the spell for that kind of creature (its NPC ID, or the
--     unit itself for players) until the next /reload.
-- The combat log is forbidden on Forever, so a hit that lands as "Immune"
-- after a successful cast is not learned.
-- Allows(spellID) answers true, false or nil (unknown); nil never blocks.
local ADDON_NAME, ns = ...

local Targets = {}
ns.Targets = Targets

Targets.PAIR_SECONDS = 0.5 -- the failed cast and its error message arrive together

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

function Targets.Forget()
    wipe(refused)
    cachedAt = nil
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

local failedSpell, failedAt, errorAt = nil, nil, nil
local function Pair()
    if failedSpell and failedAt and errorAt and math.abs(failedAt - errorAt) <= Targets.PAIR_SECONDS then
        Targets.Refuse(failedSpell, Targets.Key())
        failedSpell, failedAt, errorAt = nil, nil, nil
    end
end

local frame = CreateFrame("Frame")
Targets.frame = frame
pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_FAILED", "player")
pcall(frame.RegisterEvent, frame, "UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_FAILED" then
        local spellID = Plain(select(3, ...))
        if type(spellID) ~= "number" then return end
        failedSpell, failedAt = spellID, GetTime()
    else
        local message = Plain(select(2, ...))
        if type(message) ~= "string" or not RefusalMessages()[message] then return end
        errorAt = GetTime()
    end
    Pair()
end)
