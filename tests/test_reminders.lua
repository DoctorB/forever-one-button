-- Reminders out of combat: class buffs, consumables filtered by class stat,
-- weapon enhancements, stealth, recovery; the clickable secure row.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
local P = ns.Precombat
local features = ForeverOneButtonDB.features
local MANA = 0

local function Ids()
    H.now = H.now + 1
    local out = {}
    for i, e in ipairs(P.Suggest()) do out[i] = tostring(e.id) end
    return table.concat(out, ",")
end

-- Mage: Arcane Intellect (group-wide) and an armor.
H.class = "MAGE"
for _, id in ipairs({1459, 168}) do
    H.known[id] = true
    H.spells[id] = {name = "spell " .. id, inRange = true}
end
H.units.player = {health = 100, healthMax = 100, power = {[MANA] = 100}, powerMax = {[MANA] = 100}}
H.Equal(Ids(), "1459,168", "both mage buffs missing")
H.auras.player[1459] = {expirationTime = H.now + 1500}
H.auras.player[168] = {expirationTime = H.now + 1500}
H.Equal(Ids(), "", "buffs up")
H.auras.player[1459].expirationTime = H.now + 100
H.Equal(Ids(), "1459", "Arcane Intellect lapsing (under 3 minutes solo)")
H.auras.player[1459].expirationTime = H.now + 250
H.Equal(Ids(), "", "250 s left: fine solo")
H.inGroup = true
H.Equal(Ids(), "1459", "250 s left: lapsing in a group (5 minutes)")
H.auras.player[1459].expirationTime = H.now + 1500
H.units.party1 = {health = 100, healthMax = 100}
H.Equal(Ids(), "1459", "a party member in range lacks it")
H.auras.party1 = {[1459] = {expirationTime = H.now + 1500}}
H.Equal(Ids(), "", "party buffed")
H.inGroup, H.units.party1 = false, nil

-- Recovery for a mage: drink below 50% mana.
H.units.player.power[MANA] = 30
H.bags[262433] = 4
H.Equal(Ids(), "-262433", "drink below 50% mana")
H.auras.player[430] = {} -- eating/drinking
H.Equal(Ids(), "", "already drinking")
H.auras.player[430] = nil
H.units.player.power[MANA] = 100
H.bags[262433] = nil

-- Warrior: consumables by stat; a strength flask, not an intellect one.
H.class = "WARRIOR"
H.bags[250337] = 1 -- intellect flask
H.Equal(Ids(), "", "intellect flask ignored by a warrior")
H.bags[13453] = 1 -- strength elixir (flask category)
H.Equal(Ids(), "-13453", "strength elixir offered")
H.auras.player[17537] = {expirationTime = H.now + 3000}
H.Equal(Ids(), "", "its buff is up")
features.flask = false
H.auras.player[17537] = nil
H.Equal(Ids(), "", "category off")
features.flask = true
H.bags[13453], H.bags[250337] = nil, nil

-- Weapon stone on a one-handed sword (weapon subclass 7) without enchant.
H.bags[217347] = 2
H.mainHand = {id = 1000, classID = 2, subclassID = 7}
H.Equal(Ids(), "-217347", "weapon stone offered")
H.mainHandEnchant.temporary = true
H.Equal(Ids(), "", "weapon already enhanced")
H.mainHandEnchant.temporary = false
H.bags[217347] = nil

-- Recovery for a warrior: food below 70% health, else a bandage.
H.units.player.health = 60
H.bags[23684] = 5
H.Equal(Ids(), "-23684", "no food: bandage")
H.bags[262433] = 3
H.Equal(Ids(), "-262433", "food first")
H.bags[262433] = nil
H.auras.player[11196] = {expirationTime = H.now + 30}
H.Equal(Ids(), "", "recently bandaged")
H.auras.player[11196] = nil
H.units.player.health = 100

-- Shaman: the weapon imbue instead of stones and oils.
H.class = "SHAMAN"
H.known[8232] = true
H.spells[8232] = {name = "Windfury Weapon"}
H.bags[217347] = 2
H.Equal(Ids(), "8232", "imbue missing: the imbue spell, no stone")
H.mainHandEnchant.imbue = true
H.Equal(Ids(), "", "imbue on")
H.bags[217347] = nil

-- Rogue: stealth.
H.class = "ROGUE"
H.known[1784] = true
H.spells[1784] = {name = "Stealth"}
H.stealthed = false
H.Equal(Ids(), "1784", "stealth reminder")
H.stealthed = true
H.Equal(Ids(), "", "stealthed")

-- Never in combat, mounted or when switched off.
H.stealthed = false
H.inCombat = true
H.Equal(Ids(), "", "not in combat")
H.inCombat = false
H.mounted = true
H.Equal(Ids(), "", "not mounted")
H.mounted = false
features.precombat = false
H.Equal(Ids(), "", "feature off")
features.precombat = true

-- The row: secure buttons, configured out of combat, hidden by a combat
-- state driver; spells offered here are known to the queue.
local R = ns.Reminders
H.Equal(H.stateDrivers[R.row].value, "[combat] hide; show", "row hidden in combat by the client")
R.Reset()
H.Check(R.Update(), "row updated")
local b1 = R.buttons[1]
H.Equal(b1:GetAttribute("type1"), "spell", "spell button")
H.Equal(b1:GetAttribute("spell"), 1784, "Stealth on the first button")
H.Check(b1:IsShown() and not R.buttons[2]:IsShown(), "one button shown")
H.Check(P.Offered(1784), "Stealth offered: the queue skips it")
H.bags[13453] = 1
H.inCombat = true
H.Equal(R.Update(), false, "no change in combat")
H.Equal(R.buttons[2]:IsShown(), false, "nothing reconfigured in combat")
H.inCombat = false
H.Check(R.Update(), "updated after combat")
H.Equal(R.buttons[1]:GetAttribute("item"), "item:13453", "item button first (consumables before stealth)")
H.Equal(R.buttons[1]:GetAttribute("type1"), "item", "item type")
H.Equal(R.buttons[2]:GetAttribute("spell"), 1784, "Stealth second")
H.Equal(b1.scripts.OnClick, nil, "no Lua click handler: the secure button acts on the player's click only")

H.Done("test_reminders")
