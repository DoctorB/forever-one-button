-- Suggestion engine: priority lists, gates, ranks, trees, contexts, gap
-- closers, DoTs, wait, and the stance loop JustAC 6.0.0 produced.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local Q = ns.Queue
local RAGE = 1

local NAMES = {
    [6673] = "Battle Shout", [7386] = "Sunder Armor", [772] = "Rend", [78] = "Heroic Strike",
    [2687] = "Bloodrage", [2457] = "Battle Stance", [71] = "Defensive Stance", [100] = "Charge",
    [6343] = "Thunder Clap", [5308] = "Execute", [7384] = "Overpower", [1715] = "Hamstring",
    [6572] = "Revenge", [845] = "Cleave", [1160] = "Demoralizing Shout",
}
for id, name in pairs(NAMES) do
    H.spells[id] = {name = name}
    H.known[id] = true
end
H.known[7384], H.known[5308], H.known[845], H.known[1160] = nil, nil, nil, nil
H.forms = {2457, 71}
H.activeForm = 1
H.units.player = {health = 100, healthMax = 100, power = {[RAGE] = 50}, powerMax = {[RAGE] = 100}}
H.units.target = {health = 100, healthMax = 100, attackable = true, guid = "mob-1"}
H.auras.player[6673] = {expirationTime = H.now + 120} -- Battle Shout up

local function Fresh() H.now = H.now + 1 end
local function Ids(snapshot)
    local out = {}
    for i = 1, snapshot.count do
        local e = snapshot.entries[i]
        out[i] = (e.kind == ns.ENTRY.WAIT and "wait" or tostring(e.id)) .. (e.ready and "" or "~")
    end
    return table.concat(out, ",")
end
local function Build() Fresh(); return Q.Build(nil) end
local function Has(snapshot, id) return ("," .. Ids(snapshot) .. ","):find("," .. id .. "~?,") ~= nil end

-- Arms (no talent data: the default tree), one target, in melee.
local s = Build()
H.Equal(s.status, ns.STATUS.OK, "status")
H.Equal(s.tree, "arms", "default tree")
H.Equal(s.context, "st", "one target")
-- Sunder (no stack yet), Rend, Heroic Strike (rage 50 >= 40, one target),
-- Bloodrage (rage < 90, health > 50); Battle Stance is skipped (already in
-- it); Battle Shout waits (buff up); Hamstring waits (rage not > 80).
H.Equal(Ids(s), "7386,772,78,2687,6673~,1715~", "arms list order")
H.Equal(Q.Head(s), 7386, "head")

-- An unchanged queue is the same snapshot object.
Fresh()
H.Check(Q.Build(s) == s, "unchanged queue reuses the snapshot")

-- Ranks: the pressed rank is suggested.
H.known[284] = true
H.spells[284] = {name = "Heroic Strike"}
s = Build()
H.Check(Ids(s):find("284"), "Heroic Strike rank 2")

-- Rage 20: Heroic Strike held back; Bloodrage still fine.
H.units.player.power[RAGE] = 20
s = Build()
H.Equal(Ids(s), "7386,772,2687,6673~,284~,1715~", "low rage")

-- Rend cast on this target: ticking, so it waits; another target: needed again.
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 772)
s = Build()
H.Equal(Ids(s), "7386,2687,6673~,772~,284~,1715~", "Rend ticking")
H.units.target.guid = "mob-2"
s = Build()
H.Check(Ids(s):find("772,"), "Rend on a new target")
H.units.target.guid = "mob-1"

-- Nothing ready in a fight: wait first, then what comes up.
H.inCombat = true
for id in pairs(NAMES) do H.spells[id].noResources = true end
H.spells[284].noResources = true
s = Build()
H.Equal(s.entries[1].kind, ns.ENTRY.WAIT, "wait when nothing is ready")
H.Equal(Q.Head(s), nil, "wait has no pixel head")
for id in pairs(NAMES) do H.spells[id].noResources = nil end
H.spells[284].noResources = nil

-- Out of melee: Charge first.
H.spells[100].inRange = true
local refs = ns.Data.Defaults.rangeReferences
for id, yards in pairs(refs) do
    H.known[id] = true
    H.spells[id] = H.spells[id] or {name = "probe " .. id}
    H.spells[id].inRange = yards >= 25 -- target between 8 and 25 yards
end
H.inCombat = false
s = Build()
H.Equal(s.entries[1].id, 100, "Charge as gap closer")
H.Check(s.entries[1].gapCloser, "marked as gap closer")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 100)
s = Build()
H.Check(s.entries[1].id ~= 100, "no Charge right after Charge")
for id in pairs(refs) do H.spells[id].inRange = true end

-- Execute below 20% once known.
H.known[5308] = true
H.spells[5308] = {name = "Execute"}
H.units.target.health = 15
s = Build()
H.Check(Ids(s):find("^7386,5308"), "Execute in execute range")
H.units.target.health = 100

-- Three enemies: the aoe list (Thunder Clap after Battle Shout).
for i = 1, 3 do H.units["nameplate" .. i] = {attackable = true, threat = 1} end
s = Build()
H.Equal(s.context, "aoe", "aoe context")
H.Equal(s.entries[1].id, 6343, "Thunder Clap leads the aoe list")
for i = 1, 3 do H.units["nameplate" .. i] = nil end

-- Protection talents: Defensive Stance is on the list and suggested in
-- Battle Stance; in Defensive Stance nothing brings Battle Stance back.
H.talents = {Arms = 0, Fury = 0, Protection = 5}
ns.Trees.Invalidate()
s = Build()
H.Equal(s.tree, "protection", "most points in Protection")
H.Equal(s.entries[1].id, 71, "Defensive Stance from Battle Stance")
H.activeForm = 2
ns.Trees.Invalidate()
H.inCombat = true
-- Thunder Clap needs Battle Stance; no rage for the rest.
H.spells[6343].usable = false
for _, id in ipairs({7386, 284, 6572}) do H.spells[id].noResources = true end
for _ = 1, 20 do
    s = Build()
    H.Check(not Has(s, 2457), "never Battle Stance on the Protection list: " .. Ids(s))
end
H.Equal(s.entries[1].kind, ns.ENTRY.WAIT, "Protection without rage: wait")
for _, id in ipairs({7386, 284, 6572}) do H.spells[id].noResources = nil end
s = Build()
H.Equal(s.entries[1].id, 6572, "rage back: Revenge leads (Shield Slam unknown)")
H.inCombat = false

-- Arms in Defensive Stance: the list asks for Battle Stance; Battle Stance
-- never asks for Defensive Stance.
H.talents = nil
ns.Trees.Invalidate()
for id in pairs(NAMES) do H.spells[id].usable = false end
H.spells[2457].usable = true
s = Build()
H.Equal(s.entries[1].id, 2457, "Arms in Defensive Stance: Battle Stance")
H.activeForm = 1
for id in pairs(NAMES) do H.spells[id].usable = nil end
s = Build()
H.Check(not Has(s, 71), "Arms in Battle Stance never suggests Defensive Stance")

-- Burst cue: a ready Death Wish (on the Arms list) moves to position 2 in a
-- fight; not out of combat, not when switched off, not on a lone dying mob.
H.spells[12328] = {name = "Death Wish"}
H.known[12328] = true
H.auras.player[6673] = nil -- Battle Shout missing: it leads
Build() -- read as absent out of combat, so no remembered expiry
H.inCombat = true
s = Build()
H.Equal(Ids(s):sub(1, 16), "6673,12328,7386,", "Death Wish at position 2")
H.Check(s.entries[2].burst, "marked as burst")
H.inCombat = false
s = Build()
H.Equal(Ids(s):sub(1, 16), "6673,7386,12328,", "no burst cue out of combat")
H.inCombat = true
ns.Settings.SetFeature("burstCue", false)
s = Build()
H.Check(not s.entries[3].burst and s.entries[2].id == 7386, "burst cue off")
ns.Settings.SetFeature("burstCue", true)
H.units.target.health = 10
s = Build()
H.Check(s.entries[2].id ~= 12328, "no burst on a dying non-boss")
H.units.target.classification = "worldboss"
s = Build()
H.Equal(s.entries[2].id, 12328, "burst on a dying boss")
H.units.target.health, H.units.target.classification = 100, nil
H.inCombat = false
H.auras.player[6673] = {expirationTime = H.now + 600}

-- In-game 2026-10-16: the queue stayed empty for 18 s after a pull. With the
-- spellbook answering in secrets in combat, the spells known out of combat
-- stay known and nothing raises.
s = Build()
local before = s.count
H.Check(before > 0, "queue out of combat")
H.inCombat = true
H.secretSpellbook = true
s = Build()
H.Equal(s.status, ns.STATUS.OK, "no error with a secret spellbook")
H.Equal(s.count, before, "same entries with a secret spellbook")
H.Equal(s.candidates > 0, true, "candidates counted")
H.secretSpellbook = false
H.inCombat = false
-- A list where nothing is known says so.
for id in pairs(NAMES) do H.known[id] = nil end
for _, id in ipairs({284, 12328, 5308}) do H.known[id] = nil end
s = Build()
H.Check(s.detail and s.detail:find("none of"), "detail when no list entry is known")
for id in pairs(NAMES) do H.known[id] = true end
H.known[284], H.known[12328] = true, true

-- Fury before level 30: Berserker Stance is not known, so the list's home
-- stance is Battle Stance. In Defensive Stance with everything barred it is
-- suggested; in Battle Stance nothing stance-related appears.
H.talents = {Arms = 0, Fury = 5, Protection = 0}
ns.Trees.Invalidate()
H.activeForm = 2
for _, spell in pairs(H.spells) do spell.usable = false end
H.spells[2457].usable = true
s = Build()
H.Equal(s.tree, "fury", "fury talents")
H.Equal(s.entries[1].id, 2457, "Fury in Defensive Stance: back to Battle Stance")
H.activeForm = 1
for _, spell in pairs(H.spells) do spell.usable = nil end
s = Build()
H.Check(not Has(s, 2457) and not Has(s, 2458) and not Has(s, 71), "Fury in Battle Stance: no stance")
H.known[2458] = true
H.spells[2458] = {name = "Berserker Stance"}
H.forms = {2457, 71, 2458}
s = Build()
H.Check(Has(s, 2458) and not Has(s, 2457), "Berserker Stance known: it is the home stance")
H.known[2458], H.forms = nil, {2457, 71}
H.talents = nil
ns.Trees.Invalidate()

-- Sunder Armor (Arms list: only while the target has none): counted from
-- own casts while target debuffs are unreadable in combat.
H.inCombat = true
H.auras.target[7386] = nil
s = Build()
H.Check(Has(s, 7386) and s.entries[1].id ~= nil, "no Sunder yet")
local sunderReady
for i = 1, s.count do if s.entries[i].id == 7386 then sunderReady = s.entries[i].ready end end
H.Equal(sunderReady, true, "Sunder ready before the first application")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 7386)
s = Build()
for i = 1, s.count do if s.entries[i].id == 7386 then sunderReady = s.entries[i].ready end end
H.Equal(sunderReady, false, "one Sunder on the target: held back")
H.Equal(ns.Dots.Stacks(7386), 1, "one application counted")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 7386)
H.Equal(ns.Dots.Stacks(7386), 2, "two applications")
-- A secret GUID in combat: the target counter still identifies the target.
H.units.target.guid = H.Secret()
H.Equal(ns.Dots.Stacks(7386), 2, "same target with a secret GUID")
H.Fire("PLAYER_TARGET_CHANGED")
H.Equal(ns.Dots.Stacks(7386), 0, "new target")
H.units.target.guid = "mob-1"
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 7386)
H.now = H.now + 31
H.Equal(ns.Dots.Stacks(7386), 0, "expired after 30 s")
H.inCombat = false

-- A class without data.
H.class = "DEATHKNIGHT"
s = Build()
H.Equal(s.status, ns.STATUS.MISSING, "no list for the class")
H.class = "WARRIOR"

H.Done("test_queue")
