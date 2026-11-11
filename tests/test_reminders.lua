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

-- Rogue coatings on Forever: a poison (imbue) and a stone (temporary) on
-- each hand coexist; one entry at a time, the most urgent, with its slot.
local function Coating()
    H.now = H.now + 1
    for _, e in ipairs(P.Suggest()) do
        if e.reason == "weaponEnchant" then return tostring(e.id) .. "@" .. tostring(e.slot) end
    end
    return ""
end
local LONG = 1800000 -- 30 minutes, in milliseconds as the client reports
H.mainHandEnchant = {} -- the shaman's imbue is gone
H.offHand = {id = 1001, classID = 2, subclassID = 15} -- dagger
H.bags[8928], H.bags[20844], H.bags[217347] = 5, 5, 4 -- Instant VI, Deadly V, stone
H.Equal(Coating(), "-8928@16", "Instant Poison on the main hand first")
H.mainHandEnchant.imbue = {timeLeft = LONG, charges = 60}
H.Equal(Coating(), "-20844@17", "then Deadly Poison on the off hand")
H.offHandEnchant.imbue = {timeLeft = LONG, charges = 60}
H.Equal(Coating(), "-217347@16", "then the stone on the main hand")
H.mainHandEnchant.temporary = {timeLeft = LONG}
H.Equal(Coating(), "-217347@17", "then the stone on the off hand")
H.offHandEnchant.temporary = {timeLeft = LONG}
H.Equal(Coating(), "", "all four coatings on")
H.mainHandEnchant.imbue.timeLeft = 100000
H.Equal(Coating(), "-8928@16", "a poison lapsing (100 s left) is offered again")
H.mainHandEnchant.imbue = {timeLeft = LONG, charges = 5}
H.Equal(Coating(), "-8928@16", "a poison down to its last charges is offered again")
H.mainHandEnchant.imbue = {timeLeft = LONG, charges = 60}
H.offHandEnchant.temporary = {timeLeft = 20000}
H.mainHandEnchant.temporary = {timeLeft = 10000}
H.Equal(Coating(), "-217347@16", "two lapsing: the shorter first")
H.mainHandEnchant.temporary, H.offHandEnchant.temporary = {timeLeft = LONG}, {timeLeft = LONG}

-- Poison choice per hand, with Instant/Deadly as the fallback.
H.offHandEnchant.imbue = nil
features.poisonOffHand = "crippling"
H.Equal(Coating(), "-8928@17", "no Crippling Poison: Instant on the off hand")
H.bags[3776] = 2
H.Equal(Coating(), "-3776@17", "Crippling Poison II when owned")
features.poisonOffHand = "off"
H.Equal(Coating(), "", "off: no poison on the off hand")
features.poisonOffHand = "deadly"
H.bags[3776] = nil
H.unusable[20844] = true
H.bags[2893] = 3
H.Equal(Coating(), "-2893@17", "a rank the rogue cannot use yet is skipped")
H.unusable[20844], H.bags[2893] = nil, nil
ns.Coatings.Reset() -- the poison left the bags: it would count as used

-- After a use the weapon waits for the client to report the poison; while
-- casting nothing is offered.
H.Equal(Coating(), "-20844@17", "Deadly Poison offered")
H.bags[20844] = 4
H.Equal(Coating(), "", "used (one fewer in the bags): not offered again at once")
H.now = H.now + ns.Coatings.RECENT_SECONDS
H.Equal(Coating(), "-20844@17", "still missing after the wait: offered again")
H.casting = "Deadly Poison V"
H.Equal(Coating(), "", "nothing while casting")
H.casting = nil
H.offHandEnchant.imbue = {timeLeft = LONG, charges = 60}
features.weaponEnchant = false
H.mainHandEnchant.imbue = nil
H.Equal(Coating(), "", "category off")
features.weaponEnchant = true

-- Clients without typed enchant info: the main hand only, poison for rogues.
local typedInfo = C_Item.GetWeaponEnchantInfo
C_Item.GetWeaponEnchantInfo = nil
local legacyMain = false
function GetWeaponEnchantInfo() return legacyMain, 0, 0, 0, false, 0, 0, 0 end
ns.Coatings.Reset()
H.Equal(Coating(), "-8928@16", "legacy: poison on the main hand")
legacyMain = true
H.Equal(Coating(), "", "legacy: main hand enhanced, nothing else")
C_Item.GetWeaponEnchantInfo, GetWeaponEnchantInfo = typedInfo, nil
ns.Coatings.Reset()
H.Equal(Coating(), "-8928@16", "typed again")
H.mainHandEnchant.imbue = {timeLeft = LONG, charges = 60}
H.Equal(Coating(), "", "all coated again")
H.stealthed = false

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
-- In game (2026-10-16) a click did nothing: only the release was registered
-- while the client acts on the press (ActionButtonUseKeyDown). As the cells:
H.Equal(table.concat(b1.clickButtons, ","), "AnyDown,AnyUp", "press and release registered")
H.useKeyDown = true
R.Reset()
R.Update()
H.Equal(R.buttons[1]:GetAttribute("useOnKeyDown"), true, "follows ActionButtonUseKeyDown")
H.useKeyDown = false
H.bags[13453] = nil

-- The coating button puts the item on its weapon (target-slot, no macro);
-- the bindable key carries the same action and is emptied before combat.
local K = R.coatingKey
H.Equal(K:GetName(), "ForeverOneButtonCoating", "bindable button name (Bindings.xml)")
H.Equal(table.concat(K.clickButtons, ","), "AnyDown,AnyUp", "key: press and release registered")
H.offHandEnchant.imbue = nil
R.Reset()
H.Check(R.Update(), "row updated with a coating")
H.Equal(R.buttons[1]:GetAttribute("item"), "item:20844", "Deadly Poison button")
H.Equal(R.buttons[1]:GetAttribute("target-slot"), 17, "goes on the off hand")
H.Equal(R.buttons[2]:GetAttribute("target-slot"), nil, "Stealth: no target slot")
H.Equal(K:GetAttribute("type1"), "item", "key: item")
H.Equal(K:GetAttribute("item"), "item:20844", "key: same coating")
H.Equal(K:GetAttribute("target-slot"), 17, "key: same weapon")
H.Equal(K:GetAttribute("macrotext"), nil, "no macro")
H.Equal(K.scripts.OnClick, nil, "key: no Lua click handler")
H.Equal(K.scripts.PreClick, nil, "key: nothing runs before the click")
R.ClearCoatingKey()
H.Equal(K:GetAttribute("type1"), nil, "key emptied before combat")
H.Check(R.Update(), "set again after combat")
H.Equal(K:GetAttribute("item"), "item:20844", "key set again")
H.offHandEnchant.imbue = {timeLeft = LONG, charges = 60}
H.Check(R.Update(), "coating applied: row changes")
H.Equal(K:GetAttribute("type1"), nil, "key empty when nothing is due")
H.Equal(R.buttons[1]:GetAttribute("target-slot"), nil, "target slot cleared")
local bindings = io.open("ForeverOneButton/Bindings.xml", "rb")
local xml = bindings and bindings:read("*a") or ""
if bindings then bindings:close() end
H.Check(xml:find('name="CLICK ForeverOneButtonCoating:LeftButton"', 1, true) ~= nil, "Bindings.xml lists the key")
H.Equal(_G["BINDING_NAME_CLICK ForeverOneButtonCoating:LeftButton"], "Apply the next weapon coating", "binding label")

H.Done("test_reminders")
