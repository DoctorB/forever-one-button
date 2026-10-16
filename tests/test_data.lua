-- Imported data (scripts/import_justac_data.py): pure data, expected shape,
-- every gate type known.
local H = dofile("tests/harness/wow.lua")

-- Pure data: one header, one ns.Data assignment, no functions or calls.
local NAMES = {"Rotations", "Defaults", "Interrupts", "Consumables", "CCBreakers"}
for _, name in ipairs(NAMES) do
    local handle = assert(io.open("ForeverOneButton/Data/" .. name .. ".lua", "rb"))
    local source = handle:read("*a")
    handle:close()
    H.Check(source:find("^%-%- SPDX%-License%-Identifier: GPL%-3%.0%-or%-later\n"), name .. ": licence header")
    H.Check(source:find("wealdly", 1, true), name .. ": copyright notice")
    local code = source:gsub("%-%-[^\n]*", ""):gsub('"[^"\n]*"', '""')
    H.Check(not code:find("function"), name .. ": no functions")
    local _, assignments = code:gsub("ns%.Data%.%a+ = ", "")
    H.Equal(assignments, 1, name .. ": one table")
    H.Check(not code:find("%a%s*%("), name .. ": no calls")
end

local ns = H.Boot(nil)
local D = ns.Data
for _, name in ipairs(NAMES) do H.Equal(type(D[name]), "table", name .. " loaded") end

local CLASSES = {"DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"}
local GATES = {
    dot = true, power = true, buff = true, swing = true, any = true, targets = true, cd = true,
    stack = true, starved = true, health = true, resource = true, known = true, near = true,
    all = true, stealth = true, unconfirmed = true, execute = true, totem = true, tick = true,
}
local CONTEXTS = {st = true, cleave = true, aoe = true}

local function CheckGates(gates, label)
    H.Equal(type(gates), "table", label .. ": gates")
    for _, gate in ipairs(gates) do
        H.Check(GATES[gate.t], label .. ": known gate type " .. tostring(gate.t))
        if gate.t == "any" or gate.t == "all" then CheckGates(gate.g, label .. "/" .. gate.t) end
    end
end

-- Rotations: every class, its default tree, entries with rank-1 ids.
local entries = 0
for _, class in ipairs(CLASSES) do
    local trees = D.Rotations.classes[class]
    H.Equal(type(trees), "table", class .. " trees")
    H.Equal(type(trees[trees.default]), "table", class .. " default tree " .. tostring(trees.default))
    for tree, contexts in pairs(trees) do
        if tree ~= "default" then
            H.Check(contexts.st or contexts.cleave or contexts.aoe, class .. "/" .. tree .. " has a list")
            for context, list in pairs(contexts) do
                H.Check(CONTEXTS[context], class .. "/" .. tree .. ": context " .. context)
                for i, entry in ipairs(list) do
                    local label = class .. "/" .. tree .. "/" .. context .. "/" .. i
                    H.Check(type(entry.id) == "number" and entry.id > 0, label .. ": spell id")
                    CheckGates(entry.gates, label)
                    entries = entries + 1
                end
            end
        end
    end
    H.Check(#D.Rotations.classAbilities[class] > 0, class .. " class abilities")
end
H.Check(entries > 400, "about 477 entries, got " .. entries)
for base, chain in pairs(D.Rotations.rankChains) do
    H.Equal(chain[1], base, "rank chain starts at rank 1: " .. base)
end

-- Warrior lists as verified on 2026-10-16 (Arms ends with Battle Stance,
-- Protection opens with Battle Shout then Defensive Stance).
local arms = D.Rotations.classes.WARRIOR.arms.st
H.Equal(D.Rotations.classes.WARRIOR.default, "arms", "warrior default tree")
H.Equal(arms[#arms].id, 2457, "Arms ends with Battle Stance")
H.Equal(D.Rotations.classes.WARRIOR.protection.st[2].id, 71, "Protection: Defensive Stance")

-- Defaults.
local W = D.Defaults
H.Equal(table.concat(W.gapClosers.WARRIOR, ","), "100,20252", "warrior gap closers")
H.Equal(table.concat(W.burstTriggers.WARRIOR, ","), "1719,12328", "warrior burst triggers")
H.Equal(table.concat(W.defensive.WARRIOR, ","), "12975,871,402927,20594,1299026", "warrior defensives")
for _, key in ipairs({"abilityRoles", "totemSlots", "petHeal", "petRez", "groupHeal", "topoffHeals",
    "maintainedBuffs", "weaponImbues", "frontalDots", "nextSwing", "rangeReferences", "defenseTiers",
    "categories", "channeled", "targetDots"}) do
    H.Equal(type(W[key]), "table", "Defaults." .. key)
end

-- Interrupts: retail/classic base plus the Forever additions.
H.Equal(D.Interrupts.abilities[6552].kind, "interrupt", "Pummel")
H.Equal(D.Interrupts.abilities[72].kind, "interrupt", "Shield Bash (Forever)")
H.Equal(D.Interrupts.soothe[2908], nil, "Soothe removed on Forever")

-- Consumables.
for _, category in ipairs({"flask", "food", "scroll", "weaponEnchant"}) do
    H.Check(#D.Consumables.precombat[category] > 0, "precombat " .. category)
end
for _, kind in ipairs({"food", "drink", "bandage"}) do
    H.Check(#D.Consumables.recovery[kind] > 0, "recovery " .. kind)
end
H.Check(#D.Consumables.healingItems > 0, "healing items")
H.Equal(type(D.CCBreakers.byMechanic[5]), "table", "fear breakers")

H.Done("test_data")
