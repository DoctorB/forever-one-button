-- Leveling lists (Data/Leveling.lua): every ID a class ability of the
-- imported data, every gate known, a list for every tree; used below level
-- 60, the level-60 lists from 60.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local L, R = ns.Data.Leveling, ns.Data.Rotations

local GATES = {
    dot = true, power = true, buff = true, swing = true, any = true, targets = true, cd = true,
    stack = true, starved = true, health = true, resource = true, known = true, near = true,
    all = true, stealth = true, unconfirmed = true, execute = true, totem = true, tick = true,
    fleeing = true, since = true, elite = true,
}

-- Abilities the leveling lists use beyond the imported class abilities; each
-- must still be a rank-1 ID of the imported rank chains.
local EXTRA_ABILITIES = {
    ROGUE = {[8647] = "Expose Armor"},
}

local function CheckGates(gates, label, abilities)
    for _, gate in ipairs(gates) do
        H.Check(GATES[gate.t], label .. ": gate type " .. tostring(gate.t))
        if gate.g then CheckGates(gate.g, label, abilities) end
        if (gate.t == "known" or gate.t == "cd") and gate.id then
            H.Check(abilities[gate.id], label .. ": gate spell " .. gate.id .. " is a class ability")
        end
    end
end

local entries = 0
for class, trees in pairs(R.classes) do
    local leveling = L[class]
    H.Check(leveling, class .. ": leveling lists")
    local abilities = {}
    for _, id in ipairs(R.classAbilities[class]) do abilities[id] = true end
    for id, name in pairs(EXTRA_ABILITIES[class] or {}) do
        H.Check(R.rankChains[id] and R.rankChains[id][1] == id, class .. ": " .. name .. " is a rank-1 ID")
        abilities[id] = true
    end
    for tree in pairs(trees) do
        if tree ~= "default" then
            H.Check(leveling[tree] or leveling.base, class .. "/" .. tree .. ": a leveling list")
        end
    end
    for tree, contexts in pairs(leveling) do
        H.Check(contexts.st, class .. "/" .. tree .. ": single-target list")
        for context, list in pairs(contexts) do
            H.Check(context == "st" or context == "cleave" or context == "aoe", class .. "/" .. tree .. ": context " .. context)
            for i, entry in ipairs(list) do
                local label = class .. "/" .. tree .. "/" .. context .. "/" .. i
                H.Check(abilities[entry.id], label .. ": " .. tostring(entry.id) .. " is a " .. class .. " ability")
                H.Equal(type(entry.gates), "table", label .. ": gates")
                CheckGates(entry.gates, label, abilities)
                entries = entries + 1
            end
        end
    end
end
H.Check(entries > 150, "leveling entries for all classes, got " .. entries)

-- A level-13 Fury warrior (the in-game character of 2026-10-16).
local RAGE = 1
local SPELLS = {[6673] = "Battle Shout", [2687] = "Bloodrage", [772] = "Rend", [7386] = "Sunder Armor",
    [78] = "Heroic Strike", [284] = "Heroic Strike", [6343] = "Thunder Clap", [1715] = "Hamstring",
    [7384] = "Overpower", [2457] = "Battle Stance", [71] = "Defensive Stance"}
for id, name in pairs(SPELLS) do
    H.known[id] = true
    H.spells[id] = {name = name, inRange = true}
end
H.spells[7384].usable = false -- no dodge yet
H.spells[2687].cooldown = true
H.forms = {2457, 71}
H.activeForm = 1
H.talents = {Arms = 0, Fury = 3, Protection = 0}
H.units.player = {level = 13, health = 100, healthMax = 100, power = {[RAGE] = 20}, powerMax = {[RAGE] = 100}}
H.units.target = {health = 100, healthMax = 100, attackable = true, guid = "mob"}
H.auras.player[6673] = {expirationTime = H.now + 120}
ns.Queue.Build(nil) -- Battle Shout read out of combat: its expiry is remembered
H.inCombat = true
local function Ids(s)
    local out = {}
    for i = 1, s.count do out[i] = (s.entries[i].kind == ns.ENTRY.WAIT and "wait" or tostring(s.entries[i].id)) .. (s.entries[i].ready and "" or "~") end
    return table.concat(out, ",")
end
H.now = H.now + 1
local s = ns.Queue.Build(nil)
H.Equal(s.tree, "fury", "fury talents")
H.Check(s.leveling, "leveling list below 60")
-- Rend, Sunder, Heroic Strike (rage 20, no Bloodthirst yet) are ready.
H.Equal(Ids(s):sub(1, 12), "772,7386,284", "Rend, Sunder, Heroic Strike at rage 20")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 772)
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 7386)
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 284, "Rend ticking and one Sunder: Heroic Strike")
-- 16 rage: Heroic Strike (15) is affordable and suggested (in game a
-- 20-rage threshold waited here).
H.units.player.power[RAGE] = 16
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 284, "Heroic Strike with 16 rage")
-- 10 rage: the client says not enough rage for everything left: wait.
H.units.player.power[RAGE] = 10
for _, id in ipairs({284, 7386, 6343}) do H.spells[id].noResources = true end
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].kind, ns.ENTRY.WAIT, "no rage: wait")
for _, id in ipairs({284, 7386, 6343}) do H.spells[id].noResources = nil end
-- Overpower after a dodge leads.
H.units.player.power[RAGE] = 20
H.spells[7384].usable = nil
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 7384, "Overpower when usable")
H.Check(ns.AutoFill.ReadPool(), "pool from the leveling list")
local inPool = false
for _, id in ipairs(ns.AutoFill.ReadPool()) do if id == 1715 then inPool = true end end
H.Check(inPool, "Hamstring gets a cell from the leveling list")

-- Hamstring only on a target running away (owner request, 2026-11-06).
for i = 1, s.count do H.Check(s.entries[i].id ~= 1715 or not s.entries[i].ready, "no Hamstring before the flight") end
H.units.target.name = "Defias Thug"
H.Fire("CHAT_MSG_MONSTER_EMOTE", "%s attempts to run away in fear!", "Other Mob")
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Check(s.entries[1].id ~= 1715, "another mob's emote is ignored")
H.Fire("CHAT_MSG_MONSTER_EMOTE", "%s versucht, voller Angst zu fliehen!", "Defias Thug")
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Check(s.entries[1].id ~= 1715, "a localized emote at full health is ignored")
H.Fire("CHAT_MSG_MONSTER_EMOTE", "%s attempts to run away in fear!", "Defias Thug")
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 1715, "fleeing target: Hamstring first")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 1715)
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Check(s.entries[1].id ~= 1715, "Hamstring once per flight")
H.now = H.now + ns.State.FLEE_WINDOW
H.Equal(ns.State.TargetFleeing(), false, "the flight mark expires")
H.units.target.health = 20
H.Fire("CHAT_MSG_MONSTER_EMOTE", "%s versucht, voller Angst zu fliehen!", "Defias Thug")
H.Equal(ns.State.TargetFleeing(), true, "a localized emote below 35% health counts")
H.units.target.guid = "another mob"
H.Equal(ns.State.TargetFleeing(), false, "the mark does not pass to a new target")
H.units.target.guid, H.units.target.health = "mob", 100
H.now = H.now + ns.State.FLEE_WINDOW -- no flight left for the cases below

-- Level 40 with Death Wish: the burst cue works on the leveling list too
-- (it leads the ready entries here, so it stays at position 1, marked).
H.known[12328], H.spells[12328] = true, {name = "Death Wish", inRange = true}
H.units.player.level = 40
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Check(s.entries[1].id == 12328 and s.entries[1].burst, "Death Wish marked as burst")
H.known[12328] = nil

-- Level 60: the imported list.
H.units.player.level = 60
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.leveling, false, "level 60: imported list")
H.units.player.level = 13

-- Protection talents at level 11 (shared log of 2026-11-08): Rend, then
-- Heroic Strike whenever affordable; with Shield Slam known, Heroic Strike
-- only from 40 rage.
H.talents = {Arms = 0, Fury = 0, Protection = 2}
ns.Trees.Invalidate()
H.known[7386], H.spells[7386] = nil, nil -- Sunder not trained, as in the log
H.units.player.level = 11
H.units.player.power[RAGE] = 20
H.auras.target = H.auras.target or {}
H.auras.target[772] = nil
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.tree, "protection", "protection talents")
H.Equal(s.entries[1].id, 772, "protection lv 11: Rend first")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 772)
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 284, "protection lv 11: Heroic Strike with 20 rage")
H.known[23922], H.spells[23922] = true, {name = "Shield Slam", inRange = true, cooldown = true}
H.now = H.now + 1
s = ns.Queue.Build(nil)
for i = 1, s.count do
    H.Check(s.entries[i].id ~= 284 or not s.entries[i].ready, "Shield Slam known: no Heroic Strike under 40 rage")
end
H.units.player.power[RAGE] = 45
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 284, "Shield Slam on cooldown, 45 rage: Heroic Strike")
H.known[23922], H.spells[23922] = nil, nil
H.units.player.power[RAGE] = 20

-- A priest's wand: never suggested while Shoot is already running.
H.class = "PRIEST"
H.talents = nil
ns.Trees.Invalidate()
H.known[5019], H.spells[5019] = true, {name = "Shoot", inRange = true}
H.units.player.power = {[0] = 5}
H.units.player.powerMax = {[0] = 100}
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 5019, "low mana: the wand")
H.autoRepeat[5019] = true
H.now = H.now + 1
s = ns.Queue.Build(nil)
for i = 1, s.count do H.Check(s.entries[i].id ~= 5019, "wand already shooting: not suggested") end
H.inCombat = false

H.Done("test_leveling")
