-- Emergency heal (owner request 2026-10-18): with health below the threshold
-- in a fight, a healing spell with a cell (else the healing item's cell)
-- takes queue position 1, so the grid and the pixel both name it.
local H = dofile("tests/harness/wow.lua")
H.class = "PALADIN"
local ns = H.Boot({}, {})
local D, A = ns.Defensives, ns.Actions
local features = ForeverOneButtonDB.features
ns.Settings.Get().autoFill = false -- cells chosen by the test

local HOLY_LIGHT, FLASH, STRIKE = 635, 19750, 679
for id, name in pairs({[HOLY_LIGHT] = "Holy Light", [FLASH] = "Flash of Light", [STRIKE] = "Holy Strike"}) do
    H.known[id] = true
    H.spells[id] = {name = name}
end
local POTION = ns.Data.Consumables.healingItems[2]
H.items[POTION] = {name = "Potion", icon = "potion", spell = 22729}
H.units.player = {health = 100, healthMax = 100}
H.units.target = {health = 100, healthMax = 100, attackable = true}

local function Fresh() H.now = H.now + 1 end
local function Heal()
    Fresh()
    local entry = D.EmergencyHeal()
    return entry and entry.id or "none"
end

H.Check(A.Assign(1, "spell", STRIKE), "Holy Strike on cell 1")
H.Check(A.Assign(2, "spell", HOLY_LIGHT), "Holy Light on cell 2")
H.Check(A.Assign(3, "item", POTION), "potion on cell 3")
H.bags[POTION] = 2

H.units.player.health = 20
H.Equal(Heal(), "none", "out of combat: never")
H.inCombat = true
H.units.player.health = 50
H.Equal(Heal(), "none", "health above the threshold")
H.units.player.health = 20
H.Equal(Heal(), HOLY_LIGHT, "critical: the class's first healing spell with a cell")

-- Position 1 of the queue, and the pixel names its cell.
Fresh()
local snapshot = ns.Queue.Build()
H.Equal(snapshot.entries[1].id, HOLY_LIGHT, "heal at position 1")
H.Check(snapshot.entries[1].emergency, "marked as emergency")
H.Tick(0.1)
H.Equal(H.Pixel255(), 2 * 12, "pixel: Holy Light's cell")
-- A target out of range does not hold back a heal cast on the player.
H.spells[HOLY_LIGHT].inRange = false
H.Tick(0.1)
H.Equal(H.Pixel255(), 2 * 12, "target range ignored for the heal")
H.spells[HOLY_LIGHT].inRange = nil

-- Order: list order (Flash of Light is listed before Holy Light).
H.inCombat = false
H.Check(A.Assign(4, "spell", FLASH), "Flash of Light on cell 4")
H.inCombat = true
H.Equal(Heal(), FLASH, "Flash of Light comes first in the class list")
H.inCombat = false
H.Check(A.Clear(4), "clear Flash of Light")
H.inCombat = true

-- No usable heal spell: the healing item, if it has a cell.
H.spells[HOLY_LIGHT].cooldown = true
H.Equal(Heal(), -POTION, "heal on cooldown: the potion")
H.inCombat = false
H.Check(A.Clear(3), "clear the potion's cell")
H.inCombat = true
H.Equal(Heal(), "none", "nothing without a cell (the pixel would be white)")
H.spells[HOLY_LIGHT].cooldown = nil

-- Threshold and switch.
features.emergencyHealBelow = 15
H.Equal(Heal(), "none", "20% is above a 15% threshold")
features.emergencyHealBelow = 30
features.emergencyHeal = false
H.Equal(Heal(), "none", "off")
features.emergencyHeal = true

-- Health that cannot be read never triggers it.
H.secretStats = true
local savedCurve = C_CurveUtil
C_CurveUtil = nil
H.Equal(Heal(), "none", "unknown health")
C_CurveUtil = savedCurve
H.secretStats = false
H.Equal(Heal(), HOLY_LIGHT, "readable again")

H.Done("test_emergency_heal")
