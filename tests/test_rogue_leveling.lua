-- Rogue leveling (Data/Leveling.lua): Slice and Dice waits for 3 combo
-- points on a target above half health; Eviscerate spends the points before
-- the target dies (5 points, 3 below 35 %, 2 below 20 %); Expose Armor only on
-- elites and bosses at 5 points, once while it lasts; from stealth Garrote,
-- Cheap Shot when Garrote is refused from the front; Gouge gets a cell.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)

local ENERGY = 3
local SPELLS = {[1752] = "Sinister Strike", [5171] = "Slice and Dice", [2098] = "Eviscerate",
    [703] = "Garrote", [8647] = "Expose Armor", [1776] = "Gouge", [1766] = "Kick"}
for id, name in pairs(SPELLS) do
    H.known[id] = true
    H.spells[id] = {name = name, inRange = true}
end
H.class = "ROGUE"
H.talents = {Assassination = 0, Combat = 5, Subtlety = 0}
H.units.player = {level = 20, health = 100, healthMax = 100, power = {[ENERGY] = 100}, powerMax = {[ENERGY] = 100}}
H.units.target = {health = 100, healthMax = 100, attackable = true, guid = "mob"}
H.inCombat = true

local function Head(points, targetPct)
    H.comboPoints = points
    H.units.target.health = targetPct
    H.Advance(0.5) -- past the 0.1 s read cache
    local s = ns.Queue.Build(nil)
    H.Equal(s.tree, "combat", "combat talents")
    H.Check(s.leveling, "leveling list below 60")
    for i = 1, s.count do
        if s.entries[i].ready then return s.entries[i].id end
    end
    return nil
end

-- Slice and Dice: never below 3 points, at 3 points only above half health.
H.Equal(Head(1, 100), 1752, "1 point, full health: Sinister Strike, no Slice and Dice")
H.Equal(Head(2, 100), 1752, "2 points, full health: Sinister Strike, no Slice and Dice")
H.Equal(Head(3, 100), 5171, "3 points, full health: Slice and Dice")
H.Equal(Head(3, 50), 5171, "3 points at exactly half health: Slice and Dice")
H.Equal(Head(3, 49), 1752, "3 points below half health: Sinister Strike")

-- Eviscerate thresholds (Slice and Dice held back below half health).
H.Equal(Head(3, 40), 1752, "3 points at 40 %: keep building")
H.Equal(Head(3, 34), 2098, "3 points below 35 %: Eviscerate")
H.Equal(Head(2, 34), 1752, "2 points below 35 %: keep building")
H.Equal(Head(2, 19), 2098, "2 points below 20 %: Eviscerate")
H.Equal(Head(5, 45), 2098, "5 points: Eviscerate")


-- Expose Armor: elites and bosses only, at 5 points, once while it lasts.
H.units.target.classification = "elite"
H.Equal(Head(5, 45), 8647, "5 points on an elite: Expose Armor")
H.Equal(Head(4, 45), 1752, "4 points on an elite: keep building")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 8647)
H.Equal(Head(5, 45), 2098, "Expose Armor already on the elite: Eviscerate")
H.units.target.classification = "worldboss"
H.units.target.guid = "boss"
H.Equal(Head(5, 45), 8647, "5 points on a new boss target: Expose Armor")
H.units.target.classification = "normal"
H.units.target.guid = "mob2"
H.Equal(Head(5, 45), 2098, "normal mob: no Expose Armor")

-- Openers from stealth: Garrote; refused from the front -> next opener.
H.inCombat = false
H.stealthed = true
H.units.target.guid = "mob3"
H.Equal(Head(0, 100), 703, "stealth: Garrote")
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-1", 703)
H.Fire("UI_ERROR_MESSAGE", 50, "You must be behind your target.")
H.Equal(Head(0, 100), 1752, "Garrote refused from the front, Cheap Shot not learned: Sinister Strike")
H.known[1833] = true
H.spells[1833] = {name = "Cheap Shot", inRange = true}
H.Equal(Head(0, 100), 1833, "Garrote refused from the front: Cheap Shot")
H.units.target.guid = "mob4"
H.Equal(Head(0, 100), 703, "next target: Garrote again")

-- The combat-only pixel publishes the stealth opener out of combat, so the
-- pixel reader presses it; anything else stays black out of combat.
H.Check(ForeverOneButtonDB.pixel.combatOnly, "combat-only pixel (default)")
ns.AutoFill.Run()
local garroteSlot = ns.Actions.SlotFor(703)
H.Check(garroteSlot, "Garrote has a cell")
H.Tick(0.2)
H.Equal(ns.Model.pixelHead, 703, "out of combat, stealthed: Garrote on the pixel")
H.Equal(select(1, H.Pixel255()), garroteSlot * 12, "pixel encodes Garrote's cell")
H.stealthed = false
H.Advance(0.5)
H.Tick(0.2)
H.Equal(ns.Model.pixelHead, nil, "out of combat, not stealthed: black")
H.Equal(select(1, H.Pixel255()), 0, "pixel black")

-- The suggested interrupt goes on the pixel ahead of the rotation, so the
-- reader presses it; after the kick the rotation comes back.
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.comboPoints = 1
H.units.target.health = 100
ns.AutoFill.Run()
local kickSlot = ns.Actions.SlotFor(1766)
H.Check(kickSlot, "Kick has a cell")
H.Advance(0.5)
H.Tick(0.2)
H.Equal(ns.Model.pixelHead, 1752, "no cast: Sinister Strike on the pixel")
H.targetCast = {name = "Fireball", texture = "fireball"}
H.Advance(0.5)
H.Tick(0.2)
H.Equal(ns.Model.pixelHead, 1766, "target casting: Kick on the pixel")
H.Equal(select(1, H.Pixel255()), kickSlot * 12, "pixel encodes Kick's cell")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 1766)
H.targetCast = nil
H.Advance(0.5)
H.Tick(0.2)
H.Equal(ns.Model.pixelHead, 1752, "after the kick: Sinister Strike again")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")

-- Gouge, a crowd-control interrupt, gets a cell next to Kick; not with
-- the "kick only" interrupt mode.
local function InPool(id)
    for _, pooled in ipairs((ns.AutoFill.ReadPool())) do
        if pooled == id then return true end
    end
    return false
end
H.Check(InPool(1766) and InPool(1776), "Kick and Gouge in the automatic fill")
H.Check(ns.Settings.SetFeature("interruptMode", "kickOnly"), "kick only")
H.Check(InPool(1766) and not InPool(1776), "kick only: Gouge left out")

H.Done("test_rogue_leveling")
