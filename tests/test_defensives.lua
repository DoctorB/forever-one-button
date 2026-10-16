-- Defensive column: health bands, tiers, holding emergencies, healing items,
-- pet cues, crowd-control breakers; the panel and the automatic item cell.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
local D = ns.Defensives
local features = ForeverOneButtonDB.features

local SPELLS = {[12975] = "Last Stand", [871] = "Shield Wall", [18499] = "Berserker Rage"}
for id, name in pairs(SPELLS) do
    H.known[id] = true
    H.spells[id] = {name = name, icon = "icon-" .. id}
end
local POTION = ns.Data.Consumables.healingItems[2] -- 18253 Major Rejuvenation Potion
local BETTER = ns.Data.Consumables.healingItems[1]
H.items[POTION] = {name = "Potion", icon = "potion", spell = 22729}
H.items[BETTER] = {name = "Better potion", icon = "better", spell = 1}
H.units.player = {health = 100, healthMax = 100}

local function Fresh() H.now = H.now + 1 end
local function Ids()
    Fresh()
    local row = D.Suggest()
    if not row then return "none" end
    local out = {}
    for i, e in ipairs(row.entries) do out[i] = tostring(e.id) .. (e.waiting and "w" or "") .. (e.ready and "" or "~") end
    return table.concat(out, ",")
end

H.Equal(Ids(), "none", "healthy out of combat: nothing")
H.inCombat = true
H.Equal(Ids(), "12975,871", "in combat, healthy: list order, no item owned")
H.bags[POTION] = 3
H.Equal(Ids(), "12975,871,-" .. POTION .. "w", "item held while healthy")
H.units.player.health = 70
H.Equal(Ids(), "12975,871,-" .. POTION .. "w", "mitigate band: walls first, item still held")
H.units.player.health = 40
H.Equal(Ids(), "-" .. POTION .. ",12975,871", "below 50%: the item leads (tier 2 first)")
H.spells[871].cooldown = true
H.Equal(Ids(), "-" .. POTION .. ",12975,871~", "Shield Wall on cooldown: last")
H.spells[871].cooldown = nil
-- The potion is used: on cooldown for the rest of the fight.
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 22729)
H.Equal(Ids(), "12975,871,-" .. POTION .. "~", "potion used this fight")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Equal(Ids(), "-" .. POTION .. ",12975,871", "out of combat but below 50%: shown, potion ready again")
H.inCombat = true
H.units.player.health = 100
features.holdEmergencies = false
H.Equal(Ids(), "12975,871,-" .. POTION, "nothing held when the option is off")
features.holdEmergencies = true
-- Unknown health never hides the column.
H.secretStats = true
local savedCurve = C_CurveUtil
C_CurveUtil = nil
H.Equal(Ids(), "12975,871,-" .. POTION, "health unknown: shown, nothing held")
C_CurveUtil = savedCurve
H.secretStats = false

-- Crowd-control breaker leads when enabled (Berserker Rage frees from fear).
H.lossOfControl = {{locType = "FEAR"}}
H.Equal(Ids():sub(1, 5), "12975", "breakers off by default")
features.ccBreak = true
H.Equal(Ids():sub(1, 6), "18499,", "Berserker Rage on fear")
features.ccBreak = false
H.lossOfControl = {}

-- Pet cues (hunter): heal below 50%, revive when dead.
H.class = "HUNTER"
H.known[136], H.known[982] = true, true
H.spells[136] = {name = "Mend Pet"}
H.spells[982] = {name = "Revive Pet"}
H.units.pet = {health = 30, healthMax = 100}
H.Equal(Ids():sub(1, 4), "136,", "Mend Pet below 50%")
H.units.pet.dead = true
H.Equal(Ids():sub(1, 4), "982,", "Revive Pet when dead")
H.units.pet = nil
H.Equal(Ids():sub(1, 4), "982,", "pet seen earlier, now missing: revive / call")
H.class = "WARRIOR"

features.defensives = false
H.Equal(Ids(), "none", "feature off")
features.defensives = true

-- On the panel: icons beside the grid; the cell of the first live entry.
H.inCombat = false
local standSlot = ns.Actions.SlotUsingAction("spell", 12975)
if not standSlot then
    H.Check(ns.Actions.Assign(6, "spell", 12975), "Last Stand on cell 6")
    standSlot = 6
end
H.inCombat = true
H.Tick(0.1)
local icons = ns.Grid.defenseIcons
H.Check(icons[1].icon:IsShown(), "first icon shown")
H.Equal(icons[1].icon.texture, "icon-12975", "Last Stand first")
H.Equal(icons[1].key:GetText(), ns.Settings.KeyFor(standSlot), "its key")
H.Equal(ns.Grid.buttons[standSlot].positionText:GetText(), "D", "cell marked")
H.Equal(icons[3].icon.alpha, 0.4, "held potion dimmed")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Tick(0.1)
H.Check(not icons[1].icon:IsShown(), "column hidden when healthy out of combat")

-- Automatic item cell: the best owned healing item; a better one replaces
-- it in the same cell; clearing it keeps it out.
local char = ForeverOneButtonCharDB
ns.AutoFill.Run()
local slot = ns.Actions.SlotUsingAction("item", POTION)
H.Check(slot and char.cells[slot].auto, "potion placed automatically")
H.bags[BETTER] = 1
ns.AutoFill.Run()
H.Equal(char.cells[slot].id, BETTER, "better potion in the same cell")
H.Check(ns.Actions.Clear(slot), "clear the item cell")
ns.AutoFill.Run()
H.Equal(ns.Actions.SlotUsingAction("item", BETTER), nil, "not put back after clearing")

H.Done("test_defensives")
