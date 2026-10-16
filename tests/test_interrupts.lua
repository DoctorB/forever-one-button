-- Interrupt suggestion: kicks first, crowd control on shielded casts, the
-- modes, bosses, fears, debounce, range; the icon and the cell mark.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
local I = ns.Interrupts
ForeverOneButtonDB.features.burstCue = false

local SPELLS = {[6552] = "Pummel", [72] = "Shield Bash", [5246] = "Intimidating Shout", [20549] = "War Stomp"}
for id, name in pairs(SPELLS) do
    H.known[id] = true
    H.spells[id] = {name = name, icon = "icon-" .. id, inRange = true}
end
H.spells[72].usable = false -- no shield
H.units.player = {health = 100, healthMax = 100}
H.units.target = {health = 100, healthMax = 100, attackable = true}
local function Suggest() H.now = H.now + 3; return I.Suggest() end
local function Id() local s = Suggest(); return s and s.id end

H.Equal(Id(), nil, "no cast, no interrupt")
H.targetCast = {name = "Fireball", texture = "fireball"}
H.Equal(Id(), 6552, "Pummel on an interruptible cast (Shield Bash needs a shield)")
H.spells[72].usable = nil
H.Equal(Id(), 72, "Shield Bash first: same tier, lower ID")
H.spells[72].cooldown = true
H.Equal(Id(), 6552, "Shield Bash on cooldown: Pummel")
H.spells[6552].inRange = false
H.Equal(Id(), nil, "out of range")
H.spells[6552].inRange = true
H.targetCast.notInterruptible = H.Secret()
H.Equal(Id(), 6552, "a secret shield flag counts as interruptible")

-- Debounce: right after Pummel, nothing for a second.
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 6552)
H.Equal(I.Suggest(), nil, "debounced after the kick")

-- Shielded cast: kicks cannot stop it; kickPrefer falls back to crowd
-- control (War Stomp needs the target within 8 yards; fears are off).
H.targetCast.notInterruptible = true
H.Equal(Id(), nil, "shielded, no usable crowd control")
local refs = ns.Data.Defaults.rangeReferences
for id, yards in pairs(refs) do
    H.known[id] = true
    H.spells[id] = H.spells[id] or {name = "probe " .. id}
    H.spells[id].inRange = yards <= 5
end
H.Equal(Id(), 20549, "War Stomp on a shielded cast in melee")
ForeverOneButtonDB.features.interruptMode = "kickOnly"
H.Equal(Id(), nil, "kickOnly: no crowd control")
ForeverOneButtonDB.features.interruptMode = "ccPrefer"
H.targetCast.notInterruptible = false
H.Equal(Id(), 20549, "ccPrefer: crowd control first")
H.spells[20549].cooldown = true
ForeverOneButtonDB.features.interruptFears = true
H.Equal(Id(), 5246, "ccPrefer with fears allowed: Intimidating Shout")
ForeverOneButtonDB.features.interruptFears = false
H.Equal(Id(), 6552, "ccPrefer, no crowd control left: the kick")
ForeverOneButtonDB.features.interruptMode = "kickPrefer"
H.spells[20549].cooldown = nil

-- No crowd control on bosses; trivial and minion targets are skipped.
H.targetCast.notInterruptible = true
H.units.target.classification = "worldboss"
H.Equal(Id(), nil, "boss: no crowd control")
H.units.target.classification = "minus"
H.targetCast.notInterruptible = false
H.Equal(Id(), nil, "trivial mob")
H.units.target.classification = nil
H.units.target.minion = true
H.Equal(Id(), nil, "minion")
H.units.target.minion = nil

-- Channels count too; the feature switch.
H.targetCast = nil
H.targetChannel = {name = "Drain Life", texture = "drain"}
H.Equal(Id(), 6552, "channel")
ForeverOneButtonDB.features.interrupts = false
H.Equal(Id(), nil, "feature off")
ForeverOneButtonDB.features.interrupts = true

-- On the panel: the icon beside the grid and the cell holding Pummel.
H.Check(ns.Actions.Assign(5, "spell", 6552), "Pummel on cell 5")
H.now = H.now + 3
H.Tick(0.1)
local ui = ns.Grid.interrupt
H.Check(ui.icon:IsShown(), "interrupt icon shown")
H.Equal(ui.icon.texture, "icon-6552", "Pummel's icon")
H.Equal(ui.cast.texture, "drain", "enemy cast in the corner")
H.Equal(ui.key:GetText(), "SHIFT-5", "key of the cell")
H.Equal(ns.Grid.buttons[5].positionText:GetText(), "!", "cell marked")
H.targetChannel = nil
H.Tick(0.1)
H.Check(not ui.icon:IsShown(), "icon hidden when the cast ends")
H.Equal(ns.Grid.buttons[5].positionText:GetText(), "", "mark removed")

H.Done("test_interrupts")
