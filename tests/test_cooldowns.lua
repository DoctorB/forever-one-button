-- Cooldowns and readiness on the panel: a cell whose cooldown runs is shown
-- as such (swipe, desaturated icon), also when the client's timers are
-- secret and right after the cast; only ready queue entries are framed and
-- position 1 glows.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
local A, Grid, S = ns.Actions, ns.Grid, ns.State
ns.Settings.Get().autoFill = false -- cells chosen by the test

local STRIKE, BLOODRAGE, CHARGE = 78, 2687, 100
H.spells[STRIKE] = {name = "Heroic Strike", icon = "hs"}
H.spells[BLOODRAGE] = {name = "Bloodrage", icon = "br"}
H.spells[CHARGE] = {name = "Charge", icon = "charge"}
for _, id in ipairs({STRIKE, BLOODRAGE, CHARGE}) do H.known[id] = true end
H.baseCooldowns[BLOODRAGE] = 60000
H.baseCooldowns[CHARGE] = 15000
local POTION = ns.Data.Consumables.healingItems[2]
H.items[POTION] = {name = "Potion", icon = "potion", spell = 22729}
H.bags[POTION] = 3

H.Check(A.Assign(1, "spell", STRIKE), "Heroic Strike on cell 1")
H.Check(A.Assign(2, "spell", BLOODRAGE), "Bloodrage on cell 2")
H.Check(A.Assign(3, "item", POTION), "potion on cell 3")
H.Check(A.Assign(4, "spell", CHARGE), "Charge on cell 4")
local b1, b2, b3, b4 = Grid.buttons[1], Grid.buttons[2], Grid.buttons[3], Grid.buttons[4]

local function Refresh() H.now = H.now + 0.01; Grid.RefreshCooldowns(true) end
local function Cast(id) H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) end

-- The cooldown widget sits under the marks: the key and position stay readable.
H.Equal(b1.cooldown.type, "Cooldown", "each cell has a cooldown widget")
H.Check(b1.marks:GetFrameLevel() > b1:GetFrameLevel(), "marks above the swipe")
H.Equal(b1.positionText.parent, b1.marks, "position text on the marks frame")

-- Plain client cooldown: swipe and desaturated icon.
H.spells[BLOODRAGE].cooldown = true
Refresh()
H.Check(b2.cooldown.cooldownShown, "Bloodrage swipe")
H.Equal(b2.icon.desaturated, true, "Bloodrage desaturated")
H.Equal(b1.icon.desaturated, false, "Heroic Strike in colour")
H.spells[BLOODRAGE].cooldown = nil
Refresh()
H.Equal(b2.icon.desaturated, false, "cooldown over: back in colour")

-- Right after the cast, before the client reports the cooldown.
Cast(BLOODRAGE)
H.Equal(S.OnCooldown(BLOODRAGE), true, "cast just seen: on cooldown")
Refresh()
H.Equal(b2.icon.desaturated, true, "desaturated at once")
H.Equal(b2.cooldown.cooldownDuration, 60, "swipe from the base cooldown")
H.now = H.now + S.CAST_LAG_SECONDS
H.Equal(S.OnCooldown(BLOODRAGE), false, "the client's plain answer wins after the lag")

-- A spell with only the global cooldown never counts as cooling down.
Cast(STRIKE)
H.Equal(S.OnCooldown(STRIKE), false, "no base cooldown, no cooldown")

-- Secret timers in combat: the cast seen answers for the whole cooldown.
H.inCombat = true
H.secretCooldowns = true
Cast(CHARGE)
H.now = H.now + 5
H.Equal(S.OnCooldown(CHARGE), true, "secret timers: cast 5 s ago, 15 s cooldown")
Refresh()
H.Equal(b4.icon.desaturated, true, "Charge desaturated in combat")
H.Equal(b4.cooldown.cooldownDuration, 15, "swipe drawn from the cast")
H.now = H.now + 10
H.Equal(S.OnCooldown(CHARGE), nil, "cooldown over: unknown again, never a guess")
Refresh()
H.Equal(b4.icon.desaturated, false, "Charge back in colour")

H.inCombat = false
H.secretCooldowns = false

-- Potion drunk in combat with secret timers.
H.inCombat = true
H.secretCooldowns = true
H.secretBags = true -- counts are secret too: the use seen takes one off
Cast(22729)
Refresh()
H.Equal(b3.icon.desaturated, true, "potion desaturated after use")
H.Equal(b3.cooldown.cooldownDuration, ns.Defensives.ITEM_COOLDOWN_SECONDS, "potion swipe from the use")
H.Equal(b3.countText:GetText(), "2", "one potion fewer")
H.inCombat = false
H.secretCooldowns = false
H.secretBags = false
H.Fire("PLAYER_REGEN_ENABLED")

-- Out of combat the client's plain item cooldown is shown.
H.now = H.now + 200
H.itemCooldowns[POTION] = {H.now - 10, 120}
Refresh()
H.Equal(b3.icon.desaturated, true, "plain item cooldown")
H.Equal(b3.cooldown.cooldownDuration, 120, "plain item swipe")
H.itemCooldowns[POTION] = nil
Refresh()
H.Equal(b3.icon.desaturated, false, "item ready")

-- Tints: blue without resources, grey when unusable.
H.spells[STRIKE].noResources = true
Refresh()
H.Equal(b1.icon.vertex[3], 1, "no rage: blue tint")
H.Check(b1.icon.vertex[1] < 1, "no rage: tinted")
H.spells[STRIKE].noResources = nil
H.spells[STRIKE].usable = false
Refresh()
H.Equal(b1.icon.vertex[1], b1.icon.vertex[3], "unusable: grey")
H.Check(b1.icon.vertex[1] < 1, "unusable: darkened")
H.spells[STRIKE].usable = nil
Refresh()
H.Equal(b1.icon.vertex[1], 1, "usable: plain colour")

-- Queue marks: position 1 glows, a waiting entry has a grey number and no frame.
local snapshot = {status = ns.STATUS.OK, tree = "arms", context = "st", count = 3, entries = {
    {kind = ns.ENTRY.SPELL, id = STRIKE, ready = true},
    {kind = ns.ENTRY.SPELL, id = CHARGE, ready = true},
    {kind = ns.ENTRY.SPELL, id = BLOODRAGE, ready = false},
}}
Grid.ShowQueue(snapshot, {})
H.Check(b1.glow.shown and b1.pulse:IsPlaying(), "position 1 glows")
H.Check(b1.edges[1].shown, "position 1 framed")
H.Check(Grid.queueIcons[1].edges[1].shown, "strip head framed")
H.Check(not b4.glow.shown, "position 2 does not glow")
H.Check(b4.edges[1].shown, "ready position 2 framed")
H.Equal(b2.positionText:GetText(), "3", "waiting entry keeps its number")
H.Check(not b2.edges[1].shown, "waiting entry not framed")
H.Check(Grid.queueIcons[3].icon.desaturated, "waiting entry desaturated in the strip")

-- A wait at position 1: nothing glows.
snapshot = {status = ns.STATUS.OK, tree = "arms", context = "st", count = 2, entries = {
    {kind = ns.ENTRY.WAIT, id = ns.WAIT_ID},
    {kind = ns.ENTRY.SPELL, id = STRIKE, ready = false},
}}
Grid.ShowQueue(snapshot, {})
for slot = 1, 4 do H.Check(not Grid.buttons[slot].glow.shown, "no glow on a wait (cell " .. slot .. ")") end
H.Check(not Grid.queueIcons[1].edges[1].shown, "strip head not framed on a wait")
H.Check(not b1.pulse:IsPlaying(), "pulse stopped")

-- Everything above ran in and out of combat without a protected operation.
H.inCombat = true
Grid.RefreshCooldowns(true)
Grid.ShowQueue(snapshot, {})
H.inCombat = false
H.Done("test_cooldowns")
