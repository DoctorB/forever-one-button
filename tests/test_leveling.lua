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
    fleeing = true, since = true, elite = true, reserve = true, group = true, loose = true, free = true,
    player = true, class = true, stanceRage = true, queued = true,
}

-- Abilities the leveling lists use beyond the imported class abilities; each
-- must still be a rank-1 ID of the imported rank chains.
local EXTRA_ABILITIES = {
    ROGUE = {[8647] = "Expose Armor"},
    WARRIOR = {[355] = "Taunt", [1161] = "Challenging Shout", [676] = "Disarm"},
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
        H.Check(R.rankChains[id] == nil or R.rankChains[id][1] == id, class .. ": " .. name .. " is a rank-1 ID or has one rank")
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

-- Defensive Stance after Charge (log of 2026-11-15): in Battle Stance with
-- the Charge rage (9) and nothing affordable, no swap that would throw the
-- rage away; below 5 rage the swap comes.
H.activeForm = 1
H.units.player.power[RAGE] = 9
for _, id in ipairs({772, 284, 6673}) do H.spells[id].noResources = true end
H.now = H.now + 1
s = ns.Queue.Build(nil)
for i = 1, s.count do
    H.Check(s.entries[i].id ~= 71 or not s.entries[i].ready, "9 rage in Battle Stance: no Defensive Stance yet")
end
H.units.player.power[RAGE] = 4
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 71, "4 rage in Battle Stance: Defensive Stance")
-- Right after Charge the rage still reads as before the pull: wait 1.5 s.
H.known[100], H.spells[100] = true, {name = "Charge", inRange = true}
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 100)
H.now = H.now + 0.1
s = ns.Queue.Build(nil)
for i = 1, s.count do
    H.Check(s.entries[i].id ~= 71 or not s.entries[i].ready, "just after Charge: no Defensive Stance yet")
end
H.now = H.now + 2
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 71, "2 s after Charge with 4 rage: Defensive Stance")
H.known[100], H.spells[100] = nil, nil
-- The same with Forever's own Charge (1240287, share of 2026-11-20).
H.units.player.power[RAGE] = 4
H.known[1240287], H.spells[1240287] = true, {name = "Charge", inRange = true}
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g2", 1240287)
H.now = H.now + 0.1
s = ns.Queue.Build(nil)
for i = 1, s.count do
    H.Check(s.entries[i].id ~= 71 or not s.entries[i].ready, "just after Forever's Charge: no Defensive Stance yet")
end
H.now = H.now + 2
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 71, "2 s after Forever's Charge: Defensive Stance")
H.known[1240287], H.spells[1240287] = nil, nil
for _, id in ipairs({772, 284, 6673}) do H.spells[id].noResources = nil end
H.units.player.power[RAGE] = 20

-- Rage kept for Shield Bash (owner request 2026-11-15) against a kind of
-- creature seen casting: Heroic Strike (15) needs 25 rage there.
local function Ready(id)
    local built = ns.Queue.Build(nil)
    for i = 1, built.count do
        if built.entries[i].id == id then return built.entries[i].ready end
    end
    return false
end
H.known[72], H.spells[72] = true, {name = "Shield Bash", inRange = true}
H.units.target.guid = "Creature-0-1-2-3-1234-0000000001"
H.now = H.now + 1
H.Check(Ready(284), "20 rage, target never seen casting: Heroic Strike")
H.targetCast = {name = "Frostbolt", texture = "frostbolt"}
H.Equal(ns.Interrupts.Suggest().id, 72, "the caster's cast: Shield Bash")
H.targetCast = nil
H.units.target.guid = "Creature-0-1-2-3-1234-0000000002" -- another of the same kind
H.now = H.now + 1
H.Check(not Ready(284), "20 rage against a caster: Heroic Strike waits, 10 kept for Shield Bash")
H.units.player.power[RAGE] = 25
H.now = H.now + 1
H.Check(Ready(284), "25 rage against a caster: Heroic Strike")
H.units.player.power[RAGE] = 20
H.spells[72].cooldown = true
H.now = H.now + 1
H.Check(Ready(284), "Shield Bash cooling down: nothing to keep")
H.spells[72].cooldown = nil
H.spells[72].usable = false -- no shield
H.now = H.now + 1
H.Check(Ready(284), "no shield: nothing to keep")
H.spells[72].usable = nil
H.units.target.guid = "Creature-0-1-2-3-999-0000000003"
H.now = H.now + 1
H.Check(Ready(284), "another kind of creature: nothing to keep")
ns.Interrupts.ForgetCasters()
H.known[72], H.spells[72] = nil, nil
H.units.target.guid = "mob"

-- Group tanking (owner decision 2026-11-16): Taunt, Shield Block and
-- Sunder Armor after 5 stacks only in a group.
H.known[355], H.spells[355] = true, {name = "Taunt", inRange = true}
H.known[2565], H.spells[2565] = true, {name = "Shield Block", inRange = true}
H.known[7386], H.spells[7386] = true, {name = "Sunder Armor", inRange = true}
H.auras.target[772] = {applications = 0, expirationTime = H.now + 15} -- Rend up
H.units.player.power[RAGE] = 30
H.units.target.threat = 1 -- attacking someone else
H.units.targettarget = {friend = true} -- the healer
H.inGroup = false
H.now = H.now + 1
H.Check(not Ready(355), "alone: no Taunt")
H.inGroup = true
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 355, "group, target on someone else: Taunt first")
-- A crowd-controlled mob: no target of its own, or a polymorph seen on it.
H.units.targettarget = nil
H.now = H.now + 1
H.Check(not Ready(355), "group, target with no target (held by crowd control): no Taunt")
H.units.targettarget = {is = "player"}
H.now = H.now + 1
H.Check(not Ready(355), "group, target on the player: no Taunt")
H.units.targettarget = {friend = true}
H.aurasHiddenInCombat = false
H.auras.target[12826] = {applications = 0, expirationTime = H.now + 20} -- Polymorph rank 4
H.now = H.now + 1
H.Check(not Ready(355), "group, polymorphed target: no Taunt")
H.auras.target[12826] = nil
H.aurasHiddenInCombat = true
H.now = H.now + 1
H.Check(Ready(355), "group, target on the healer again: Taunt")
H.units.targettarget = nil
H.units.target.threat = 3
H.now = H.now + 1
H.Check(not Ready(355), "group, tanking the target: no Taunt")
H.units.target.threat = nil
H.now = H.now + 1
H.Check(not Ready(355), "group, threat unreadable: no Taunt")

-- Enemies on someone else (owner request 2026-11-16, four mobs with one
-- targeted): counted from the nameplates; Thunder Clap and Demoralizing
-- Shout lead from 1, Challenging Shout from 2.
H.known[1160], H.spells[1160] = true, {name = "Demoralizing Shout", inRange = true}
H.units.target.threat = 3 -- the targeted mob is on the player
H.units.nameplate1 = {attackable = true, threat = 0}
H.units.nameplate1target = {friend = true} -- on the healer
H.units.nameplate2 = {attackable = true, threat = 3}
H.units.nameplate2target = {is = "player"}
H.units.nameplate3 = {attackable = true, threat = 0} -- polymorphed: no target
H.now = H.now + 1
H.Equal(ns.State.LooseCount(), 1, "one enemy on someone else")
H.Equal(ns.State.looseDetail, "2/1/1", "plates without aggro / with a target / loose")
-- A client answering nil instead of false for "is it the player".
local unitIsUnit = UnitIsUnit
UnitIsUnit = function(a, b) if unitIsUnit(a, b) then return true end return nil end
H.now = H.now + 1
H.Equal(ns.State.LooseCount(), 1, "UnitIsUnit nil: still one enemy loose")
UnitIsUnit = unitIsUnit
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 1160)
H.now = H.now + 7
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 6343, "group, an enemy loose: Thunder Clap first")
H.Check(Ready(1160), "an enemy loose: Demoralizing Shout although its debuff is up")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 1160)
H.now = H.now + 1
H.Check(not Ready(1160), "Demoralizing Shout for a loose enemy at most every 6 s")
H.known[1161], H.spells[1161] = true, {name = "Challenging Shout", inRange = true}
H.now = H.now + 1
H.Check(not Ready(1161), "one enemy loose: no Challenging Shout")
H.units.nameplate3target = {friend = true}
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 1161, "two enemies loose: Challenging Shout first")
H.inGroup = false
H.now = H.now + 1
H.Check(not Ready(1161), "alone: no Challenging Shout")
H.Check(not Ready(1160), "alone: Demoralizing Shout waits for its debuff")
H.inGroup = true
for _, unit in ipairs({"nameplate1", "nameplate1target", "nameplate2", "nameplate2target", "nameplate3",
    "nameplate3target"}) do H.units[unit] = nil end
H.known[1160], H.spells[1160], H.known[1161], H.spells[1161] = nil, nil, nil, nil
H.units.target.threat = nil
ns.Grid.ShowLoose(2)
H.Equal(ns.Grid.looseText:GetText(), "2 enemies not on you", "warning above the grid")
ns.Grid.ShowLoose(0)

H.units.target.classification = "elite"
H.now = H.now + 1
H.Check(Ready(2565), "group, elite target: Shield Block")
H.inGroup = false
H.now = H.now + 1
H.Check(not Ready(2565), "alone: no Shield Block")
H.inGroup = true
H.units.target.classification = nil
H.now = H.now + 1
H.Check(not Ready(2565), "group, one normal target: no Shield Block")

-- Sunder Armor: the first entry up to 5 stacks, the second only after.
H.Fire("PLAYER_TARGET_CHANGED")
for _ = 1, 5 do H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 7386) end
H.Equal(ns.Dots.Stacks(7386), 5, "five Sunders counted")
H.inGroup = false
H.now = H.now + 1
H.Check(not Ready(7386), "alone, 5 stacks: no more Sunder")
H.inGroup = true
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Check(Ready(7386), "group, 5 stacks: Sunder again for threat")
local sunderAt, heroicAt, listed = nil, nil, 0
for i = 1, s.count do
    if s.entries[i].id == 7386 then sunderAt = sunderAt or i; listed = listed + 1 end
    if s.entries[i].id == 284 then heroicAt = i end
end
H.Equal(listed, 1, "Sunder listed once")
H.Check(heroicAt == nil or sunderAt < heroicAt, "Sunder again before Heroic Strike")
H.units.target.guid = "mob-2" -- a fresh target
H.Fire("PLAYER_TARGET_CHANGED")
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Equal(select(2, s.why:gsub("7386", "")), 1, "fewer than 5 stacks: the first Sunder entry only")

-- A player target (owner decision 2026-11-22, Warsong Gulch log): a
-- battleground is a group, but no Taunt, no Sunder (2026-11-22, fifth BG),
-- Demoralizing Shout only with 2 or more enemies, players never "loose".
H.units.target.guid = "Player-1-0000001"
H.units.target.player = true
H.Fire("PLAYER_TARGET_CHANGED")
H.units.target.threat = 1
H.units.targettarget = {friend = true}
H.now = H.now + 1
H.Check(not Ready(355), "player attacking a teammate: no Taunt")
s = ns.Queue.Build(nil)
H.Check(not Ready(7386), "player, no Sunder yet: still no Sunder")
H.Check(s.why:find("7386-gate", 1, true) ~= nil, "player: Sunder held by its gate")
H.Check(not s.why:find("7386+", 1, true), "player: neither Sunder entry ready")
H.known[1160], H.spells[1160] = true, {name = "Demoralizing Shout", inRange = true}
ns.Dots.Reset() -- no shout from the earlier pulls
H.now = H.now + 1
s = ns.Queue.Build(nil)
H.Check(s.why:find("1160-gate", 1, true) ~= nil, "player, alone in front: no Demoralizing Shout")
H.units.nameplate1 = {attackable = true, threat = 0, player = true}
H.units.nameplate1target = {friend = true}
H.now = H.now + 1
H.Equal(ns.State.LooseCount(), 0, "an enemy player on a teammate is not loose")
H.units.nameplate1, H.units.nameplate1target = nil, nil
H.units.target.player = nil
H.units.target.threat = nil
H.units.targettarget = nil
H.Fire("PLAYER_TARGET_CHANGED")
H.now = H.now + 1
H.Check(Ready(1160), "creature: Demoralizing Shout as before")
H.known[1160], H.spells[1160] = nil, nil

-- Hamstring and Disarm against players (owner request 2026-11-25).
-- Forever: Hamstring in Battle Stance only, Disarm in Defensive Stance only;
-- Tactical Mastery keeps 10 rage through a stance change, the talent 15 more.
local function Head()
    H.now = H.now + 1
    return ns.Queue.Build(nil).entries[1].id
end
for id, name in pairs({[1715] = "Hamstring", [676] = "Disarm", [2457] = "Battle Stance",
        [71] = "Defensive Stance", [772] = "Rend"}) do
    H.known[id] = true
    H.spells[id] = H.spells[id] or {name = name}
    H.spells[id].inRange = true
end
-- Every known melee reference (Rend, Hamstring, Sunder Armor) at once.
local function Melee(reached)
    for _, id in ipairs({772, 1715, 7386}) do
        if H.spells[id] then H.spells[id].inRange = reached end
    end
end
H.activeForm = 2 -- Defensive Stance
H.spells[1715].usable = false -- not in Defensive Stance
H.spells[676].usable = true
H.units.target.guid = "Player-1-0000003"
H.units.target.player = true
H.units.target.class = "PRIEST"
H.Fire("PLAYER_TARGET_CHANGED")
H.units.player.power[RAGE] = 30
H.known[1310185], H.known[12295] = true, true -- 25 rage kept
H.Equal(ns.State.StanceRageKept(), 25, "Tactical Mastery + talent keep 25")
H.Equal(Head(), 2457, "player in melee, 30 rage, 25 kept: Battle Stance for Hamstring")
H.units.player.power[RAGE] = 40
H.Check(Head() ~= 2457, "40 rage would lose 15: no stance change")
H.units.player.power[RAGE] = 30
H.known[12295] = nil
H.Equal(ns.State.StanceRageKept(), 10, "Tactical Mastery alone keeps 10")
H.Check(Head() ~= 2457, "30 rage, 10 kept: no stance change")
H.units.player.power[RAGE] = 20
H.Equal(Head(), 2457, "20 rage, 10 kept: Battle Stance")
-- Heroic Strike queued: the swing takes the rage Hamstring needs (2 swaps
-- wasted in the log of 2026-11-25).
local queuedStrike = ns.Ranks.HighestKnown(78)
H.Check(queuedStrike, "Heroic Strike known")
H.currentSpells[queuedStrike] = true
H.Check(Head() ~= 2457, "Heroic Strike queued: no stance change")
H.currentSpells[queuedStrike] = nil
H.Equal(Head(), 2457, "Heroic Strike landed: Battle Stance")
H.known[1310185] = nil
H.Check(Head() ~= 2457, "no Tactical Mastery: no stance change")
H.known[1310185], H.known[12295] = true, true
H.units.player.power[RAGE] = 30
H.units.target.player = nil
H.units.target.guid = "Creature-0-1-2-3-99-0000000009"
H.Fire("PLAYER_TARGET_CHANGED")
H.Check(Head() ~= 2457, "creature: no Hamstring stance change")
H.units.target.guid = "Player-1-0000003"
H.units.target.player = true
H.Fire("PLAYER_TARGET_CHANGED")
Melee(false)
H.Check(Head() ~= 2457, "player out of melee: no stance change")
Melee(true)

-- The sequence: Battle Stance, Hamstring, at once Defensive Stance.
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s1", 2457)
H.activeForm = 1
H.spells[1715].usable, H.spells[676].usable = true, false
H.units.player.power[RAGE] = 25
H.Equal(Head(), 1715, "in Battle Stance: Hamstring")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "h1", 1715)
H.units.player.power[RAGE] = 15
H.Equal(Head(), 71, "after Hamstring: back to Defensive Stance")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "d1", 71)
H.activeForm = 2
H.spells[1715].usable, H.spells[676].usable = false, true
H.units.player.power[RAGE] = 30
H.Check(Head() ~= 2457, "Hamstring just cast: no new stance change for 12 s")
-- Hamstring out of reach after the change: back after 2 s.
H.now = H.now + 12
H.Equal(Head(), 2457, "12 s later: Battle Stance again")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s2", 2457)
H.activeForm = 1
H.spells[1715].usable, H.spells[676].usable = true, false
Melee(false)
H.now = H.now + 0.5
s = ns.Queue.Build(nil)
H.Check(s.entries[1].id ~= 71, "Hamstring out of reach: wait up to 2 s in Battle Stance")
H.now = H.now + 1.5
s = ns.Queue.Build(nil)
H.Equal(s.entries[1].id, 71, "2 s without Hamstring: back to Defensive Stance")
H.activeForm = 2
H.spells[1715].usable, H.spells[676].usable = false, true
Melee(true)

-- Disarm: a melee class player while the player's health is below 60 %.
H.now = H.now + 30
H.units.player.health = 50
H.now = H.now + 1
H.Check(not Ready(676), "a priest: no Disarm")
H.units.target.class = "ROGUE"
H.Equal(Head(), 676, "a rogue, health 50 %: Disarm first")
H.units.player.health = 80
H.now = H.now + 1
H.Check(not Ready(676), "health 80 %: no Disarm")
H.units.player.health = 100
for _, id in ipairs({1715, 676, 2457, 1310185, 12295}) do H.known[id] = nil end
H.units.target.player, H.units.target.class = nil, nil
H.units.target.guid = "mob-2"
H.Fire("PLAYER_TARGET_CHANGED")
H.activeForm = 1

-- UnitIsPlayer unreadable (battleground of 2026-11-22: the gate never
-- answered): the GUID, then the instance type.
local unitIsPlayer = UnitIsPlayer
UnitIsPlayer = function() return H.Secret() end
H.units.target.guid = "Player-1-0000002"
H.Equal(select(2, ns.State.UnitIsPlayer("target")), "guid", "player GUID read")
H.Check(ns.State.TargetIsPlayer() == true, "secret UnitIsPlayer: the GUID says player")
H.units.target.guid = "Creature-0-1-2-3-4-5"
H.Check(ns.State.TargetIsPlayer() == false, "secret UnitIsPlayer: the GUID says creature")
local unitGUID = UnitGUID
UnitGUID = function() return H.Secret() end
H.Check(ns.State.TargetIsPlayer() == nil, "nothing readable outside a battleground: unknown")
H.instanceType = "pvp"
H.Check(ns.State.TargetIsPlayer() == true, "nothing readable in a battleground: player")
H.units.nameplate1 = {attackable = true, threat = 0}
H.units.nameplate1target = {friend = true}
H.now = H.now + 1
H.Equal(ns.State.LooseCount(), 0, "battleground: no loose enemies")
H.units.nameplate1, H.units.nameplate1target = nil, nil
H.instanceType = nil
UnitGUID, UnitIsPlayer = unitGUID, unitIsPlayer
H.units.target.guid = "mob-2"
H.inGroup = false
H.known[355], H.spells[355], H.known[2565], H.spells[2565] = nil, nil, nil, nil
H.known[7386], H.spells[7386] = nil, nil
H.units.target.guid = "mob"
H.auras.target[772] = nil
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
