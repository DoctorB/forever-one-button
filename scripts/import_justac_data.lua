-- Captures the WoW Forever data tables of JustAC and writes them as plain Lua
-- data for Forever One Button. Run through scripts/import_justac_data.py,
-- which checks the source hashes first.
--
--   lua5.1 scripts/import_justac_data.lua <JustAC folder> <output folder>
--
-- Each JustAC data file is executed against stub libraries that record what
-- it registers; nothing of JustAC's code runs. The output is deterministic:
-- keys sorted, array order kept.
local source, output = arg[1], arg[2]
assert(source and output, "usage: import_justac_data.lua <JustAC folder> <output folder>")

local function Recorder(functions)
    local rec = {calls = {}, tables = {}}
    return rec, setmetatable({}, {__index = function(self, key)
        if functions[key] then
            local value = function(...)
                rec.calls[key] = rec.calls[key] or {}
                table.insert(rec.calls[key], {...})
                return functions[key](...)
            end
            rawset(self, key, value)
            return value
        end
        local t = {}
        rec.tables[key] = t
        rawset(self, key, t)
        return t
    end})
end

local function Run(file, libraries)
    local chunk = assert(loadfile(source .. "/" .. file))
    local env = setmetatable({
        LibStub = setmetatable({
            NewLibrary = function(_, name) libraries[name] = libraries[name] or {}; return libraries[name] end,
        }, {__call = function(_, name) return libraries[name] end}),
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    }, {__index = _G})
    setfenv(chunk, env)
    chunk("JustAC", {})
end

local function True() return true end
local function None() end

-- Rotations: one RegisterForever(classes, rankChains, classAbilities) call.
local rotRec, rotLib = Recorder({RegisterForever = None})
Run("Data/Forever/Rotations.lua", {["JustAC-RotationImport"] = rotLib})
local rotCall = assert(rotRec.calls.RegisterForever, "RegisterForever not called")[1]

-- Interrupts, base list (retail and classic ids), then the Forever additions.
local intRec, intLib = Recorder({RegisterInterruptAbilities = None, RegisterSootheAbilities = None})
Run("Data/InterruptAbilities.lua", {["JustAC-SpellDB"] = intLib})

-- Defaults: tables filled by Put() under "<CLASS>_F" plus Register* calls.
local defRec, defLib = Recorder({
    IsForever = True, IndexMaintainedBuffs = None, RegisterInterruptAbilities = None,
    RegisterSootheAbilities = None, RegisterRangeReferences = None, RegisterDefenseTiers = None,
    RegisterCategories = None, RegisterChanneledSpells = None, RegisterTargetDots = None,
})
Run("Data/Forever/Defaults.lua", {["JustAC-SpellDB"] = defLib})

-- Consumables.
local conRec, conLib = Recorder({
    IsForever = True, RegisterPrecombatBuffs = None, RegisterEatingAuras = None,
    RegisterRecoveryItems = None, RegisterHealingItems = None,
})
Run("Data/Forever/Consumables.lua", {["JustAC-SpellDB"] = conLib})

-- CC breakers: the Forever map, read back through the library function.
local ccLibs = {["JustAC-SpellDB"] = {IsForever = True}}
Run("Data/CCBreakers.lua", ccLibs)
local ccLib = ccLibs["JustAC-CCBreakers"]
local breakers = {}
for mechanic = 0, 64 do breakers[mechanic] = ccLib.GetBreakers(mechanic) end

local function Only(rec, name)
    local calls = assert(rec.calls[name], name .. " not called")
    assert(#calls == 1, name .. " called " .. #calls .. " times")
    return calls[1][1]
end

-- "<CLASS>_F" keys only: the class-key duplicates are the same tables.
local function ForeverKeys(t)
    local out = {}
    for key, value in pairs(t) do
        local class = type(key) == "string" and key:match("^(%u+)_F$")
        if class then out[class] = value end
    end
    return out
end

local function Merge(a, b)
    local out = {}
    for k, v in pairs(a or {}) do out[k] = v end
    for k, v in pairs(b or {}) do out[k] = v end
    return out
end

local soothe = {}
for _, call in ipairs(intRec.calls.RegisterSootheAbilities or {}) do soothe = Merge(soothe, call[1]) end
for _, call in ipairs(defRec.calls.RegisterSootheAbilities or {}) do soothe = Merge(soothe, call[1]) end
for id, value in pairs(soothe) do if value == false then soothe[id] = nil end end

local defaults = {
    defensive = ForeverKeys(defRec.tables.CLASS_DEFENSIVE_DEFAULTS),
    previousDefensive = rawget(defLib, "FOREVER_PREVIOUS_DEFENSIVE_DEFAULTS"),
    abilityRoles = rawget(defLib, "FOREVER_ABILITY_ROLES"),
    totemSlots = rawget(defLib, "FOREVER_TOTEM_SLOTS"),
    maintainedProtection = rawget(defLib, "FOREVER_MAINTAINED_PROTECTION"),
    petHeal = ForeverKeys(defRec.tables.CLASS_PETHEAL_DEFAULTS),
    petRez = ForeverKeys(defRec.tables.CLASS_PET_REZ_DEFAULTS),
    groupHelp = ForeverKeys(defRec.tables.CLASS_GROUP_HELP_DEFAULTS),
    groupHeal = ForeverKeys(defRec.tables.CLASS_GROUPHEAL_DEFAULTS),
    emergencyLadder = ForeverKeys(defRec.tables.HEAL_EMERGENCY_LADDER),
    gapClosers = ForeverKeys(defRec.tables.CLASS_GAPCLOSER_DEFAULTS),
    burstTriggers = ForeverKeys(defRec.tables.CLASS_BURST_TRIGGER_DEFAULTS),
    topoffHeals = ForeverKeys(defRec.tables.CLASS_TOPOFF_HEALS),
    maintainedBuffs = defRec.tables.CLASS_MAINTAINED_BUFFS,
    weaponImbues = rawget(defLib, "WEAPON_IMBUE_SPELLS"),
    weaponEnchantCasts = defRec.tables.WEAPON_ENCHANT_SPELLS,
    frontalDots = defRec.tables.FRONTAL_DOTS,
    nextSwing = defRec.tables.NEXT_SWING_SPELLS,
    rangeReferences = Only(defRec, "RegisterRangeReferences"),
    defenseTiers = Only(defRec, "RegisterDefenseTiers"),
    categories = Only(defRec, "RegisterCategories"),
    channeled = Only(defRec, "RegisterChanneledSpells"),
    targetDots = Only(defRec, "RegisterTargetDots"),
}
local interrupts = Merge(Only(intRec, "RegisterInterruptAbilities"), Only(defRec, "RegisterInterruptAbilities"))

local consumables = {
    precombat = Only(conRec, "RegisterPrecombatBuffs"),
    eatingAuras = Only(conRec, "RegisterEatingAuras"),
    recovery = Only(conRec, "RegisterRecoveryItems"),
    healingItems = Only(conRec, "RegisterHealingItems"),
}

-- Serializer ---------------------------------------------------------------
local function IsArray(t)
    local n = #t
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then return false end
    end
    return true
end

local function Key(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
    if type(k) == "string" then return string.format("[%q]", k) end
    return "[" .. tostring(k) .. "]"
end

local function Scalar(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
    error("unsupported value type " .. type(v))
end

local function SortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return keys
end

-- Short tables (only scalars) on one line; others one entry per line.
local function Serialize(v, indent)
    if type(v) ~= "table" then return Scalar(v) end
    local flat = true
    for _, x in pairs(v) do if type(x) == "table" then flat = false break end end
    local parts = {}
    if IsArray(v) then
        for i = 1, #v do parts[i] = Serialize(v[i], indent .. "  ") end
    else
        for _, k in ipairs(SortedKeys(v)) do parts[#parts + 1] = Key(k) .. "=" .. Serialize(v[k], indent .. "  ") end
    end
    if #parts == 0 then return "{}" end
    if flat then return "{" .. table.concat(parts, ",") .. "}" end
    return "{\n" .. indent .. "  " .. table.concat(parts, ",\n" .. indent .. "  ") .. ",\n" .. indent .. "}"
end

local HEADER = [[
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Data imported from JustAC 6.0.0 (%s), Copyright (C) 2024-2026 wealdly,
-- GPL-3.0-or-later, https://github.com/wealdly/JustAC.%s
-- GENERATED by scripts/import_justac_data.py - do not edit by hand.
local _, ns = ...
ns.Data = ns.Data or {}
]]

local WOWSIMS = [[

-- The priority lists derive from the wowsims rotation files of
-- github.com/ElliotWood/Forever (commit 96719dc69ff3e93de4a8b0eff4653e7df269a604),
-- MIT License, Copyright (c) 2022 wowsims team.]]

local function Write(name, sources, value, extra)
    local handle = assert(io.open(output .. "/" .. name .. ".lua", "wb"))
    handle:write(string.format(HEADER, sources, extra or ""))
    handle:write("ns.Data." .. name .. " = " .. Serialize(value, "") .. "\n")
    handle:close()
end

Write("Rotations", "Data/Forever/Rotations.lua",
    {classes = ForeverKeys(rotCall[1]), rankChains = rotCall[2], classAbilities = ForeverKeys(rotCall[3])}, WOWSIMS)
Write("Defaults", "Data/Forever/Defaults.lua", defaults)
Write("Interrupts", "Data/InterruptAbilities.lua, Data/Forever/Defaults.lua", {abilities = interrupts, soothe = soothe})
Write("Consumables", "Data/Forever/Consumables.lua", consumables)
Write("CCBreakers", "Data/CCBreakers.lua", {byMechanic = breakers})
print("imported: Rotations, Defaults, Interrupts, Consumables, CCBreakers")
