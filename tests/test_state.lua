-- Engine state layer: plain reads, engine-side comparisons for secrets,
-- unknown answers stay nil, nothing secret is ever compared in Lua.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local S, Secret, Ranks = ns.State, ns.Secret, ns.Ranks
local RAGE, MANA = 1, 0

local function Fresh() H.now = H.now + 1 end

-- Secret.IsZero: plain numbers, secrets through TruncateWhenZero.
H.Equal(Secret.IsZero(0), true, "plain zero")
H.Equal(Secret.IsZero(5), false, "plain non-zero")
H.Equal(Secret.IsZero(H.SecretOf(0)), true, "secret zero")
H.Equal(Secret.IsZero(H.SecretOf(100)), false, "secret non-zero")
H.Equal(Secret.IsZero(H.SecretOf(0.4)), true, "below 1 truncates to zero")
H.Equal(Secret.IsZero(nil), nil, "nil is unknown")

-- Health thresholds: plain, then secret through the curve.
H.units.player = {health = 40, healthMax = 100, power = {[RAGE] = 30, [MANA] = 0}, powerMax = {[RAGE] = 100, [MANA] = 0}}
H.Equal(S.HealthBelow("player", 50), true, "40% < 50% (plain)")
H.Equal(S.HealthBelow("player", 35), false, "40% >= 35% (plain)")
H.secretStats = true
Fresh()
H.Equal(S.HealthBelow("player", 50), true, "40% < 50% (secret)")
H.Equal(S.HealthBelow("player", 35), false, "40% >= 35% (secret)")
H.Equal(S.HealthBelow("player", 40.5), true, "close threshold (secret)")
H.Equal(S.PowerBelow("player", 40, RAGE), true, "rage 30 < 40% (secret)")
H.Equal(S.PowerBelow("player", 20, RAGE), false, "rage 30 >= 20% (secret)")
Fresh()
H.Equal(S.HealthBelow("target", 20), nil, "no target: unknown")
-- Without the curve API the secret path has no answer: nil, never a guess.
local savedCurve = C_CurveUtil
C_CurveUtil = nil
Fresh()
H.Equal(S.HealthBelow("player", 60), nil, "no curve API: unknown")
C_CurveUtil = savedCurve
H.secretStats = false
Fresh()
H.Equal(S.PowerMax(RAGE), 100, "rage max plain")

-- Memo: answers are reused inside 0.1 s.
Fresh()
H.Equal(S.HealthBelow("player", 50), true, "40% < 50%")
H.units.player.health = 90
H.Equal(S.HealthBelow("player", 50), true, "memoized inside the window")
Fresh()
H.Equal(S.HealthBelow("player", 50), false, "fresh after the window")

-- Ranks: chains from the data, highest known; the bars are never read.
H.Equal(Ranks.Base(284), 78, "Heroic Strike rank 2 -> rank 1")
H.known[78], H.known[284], H.known[285] = true, true, true
H.Equal(Ranks.HighestKnown(78), 285, "highest known rank")
H.actions[1] = 78
H.Equal(Ranks.Pressed(78), 285, "an old rank left on the bars does not hold the rank back")
H.Equal(Ranks.Pressed(284), 285, "any rank asks for the highest known")
H.actions[1] = nil
H.Equal(Ranks.Higher(78), 285, "higher known rank")
H.Equal(Ranks.Higher(285), nil, "already the highest")
H.Equal(Ranks.Higher(6603), nil, "spell without ranks")
H.Equal(Ranks.HighestKnown(12294), nil, "unknown spell")

-- Usable, cooldown (GCD excluded), range.
H.spells[78] = {name = "Heroic Strike"}
H.spells[100] = {name = "Charge", cooldown = true}
H.spells[772] = {name = "Rend", usable = false, noResources = true}
H.Equal(S.Usable(78), true, "usable")
local usable, noResources = S.Usable(772)
H.Equal(usable, false, "not usable")
H.Equal(noResources, true, "not enough rage")
H.Equal(S.OnCooldown(100), true, "Charge on cooldown")
H.Equal(S.OnCooldown(78), false, "Heroic Strike ready")
H.spells[6343] = {name = "Thunder Clap", onGCD = true}
H.Equal(S.OnCooldown(6343), false, "only the GCD running")
H.spells[78].inRange = true
H.Equal(S.InRange(78), true, "in range")
H.spells[78].inRange = false
H.Equal(S.InRange(78), false, "out of range")
H.spells[78].inRange = nil
H.Equal(S.InRange(78), nil, "range unknown")

-- Target and enemies.
H.Equal(S.TargetAttackable(), false, "no target")
H.units.target = {health = 15, healthMax = 100, attackable = true}
H.Equal(S.TargetAttackable(), true, "hostile target")
Fresh()
H.Equal(S.HealthBelow("target", 20), true, "execute range")
H.Equal(S.TargetIsBoss(), false, "normal mob")
H.units.target.classification = "worldboss"
H.Equal(S.TargetIsBoss(), true, "boss")
H.Equal(S.EnemyCount(), 0, "no nameplates")
for i = 1, 3 do H.units["nameplate" .. i] = {attackable = true, threat = 1} end
H.units.nameplate4 = {attackable = true} -- not engaged
Fresh()
H.Equal(S.EnemyCount(), 3, "three engaged enemies")

-- Stances: the active form decides stance buffs.
H.forms = {2457, 71}
H.activeForm = 1
H.Equal(S.ActiveForm(), 2457, "Battle Stance active")
H.Equal(S.IsForm(71), true, "Defensive Stance is a form")
H.Equal(S.BuffActive(2457), true, "in Battle Stance")
H.Equal(S.BuffActive(71), false, "not in Defensive Stance")

-- Buffs: aura out of combat; in combat only the cast window or the expiry
-- remembered while the aura was readable.
H.auras.player[6673] = {expirationTime = H.now + 120}
H.Equal(S.BuffActive(6673, 120), true, "Battle Shout aura")
H.inCombat = true
H.Equal(S.BuffActive(6673, 120), true, "remembered expiry in combat")
H.auras.player[6673] = nil
H.now = H.now + 200
H.Equal(S.BuffActive(6673, 120), nil, "expired and unreadable: unknown")
H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 6673)
H.Equal(S.BuffActive(6673, 120), true, "own cast opens the window")
H.now = H.now + 121
H.Equal(S.BuffActive(6673, 120), nil, "window closed, aura unreadable")
H.inCombat = false
H.Equal(S.BuffActive(6673, 120), false, "out of combat: readable and absent")

-- Stacks on the target.
H.auras.target[7386] = {applications = 3}
H.Equal(S.StacksAtLeast("target", 7386, 3), true, "three Sunders")
H.Equal(S.StacksAtLeast("target", 7386, 5), false, "not five")
H.auras.target[7386] = nil
H.Equal(S.StacksAtLeast("target", 7386, 1), false, "none out of combat")
H.inCombat = true
H.Equal(S.StacksAtLeast("target", 7386, 1), false, "in combat: own Sunders counted, none yet")
H.inCombat = false

-- Swing timer from PLAYER_SWING (duration, swingType).
H.Equal(S.SwingRemaining(0), nil, "no swing yet")
H.Fire("PLAYER_SWING", 2.0, 0)
H.now = H.now + 0.5
H.Equal(S.SwingRemaining(0), 1.5, "1.5 s to the next swing")
H.Fire("PLAYER_SWING", H.SecretOf(2.0), 0)
H.Equal(S.SwingRemaining(0), 1.5, "secret duration ignored")

-- Combo points, stealth, totems.
H.comboPoints = 4
H.Equal(S.ComboPoints(), 4, "combo points")
H.stealthed = true
H.Equal(S.Stealthed(), true, "stealthed")
H.totems[1] = true
H.Equal(S.TotemActive(1), true, "fire totem down")
H.Equal(S.TotemActive(2), false, "earth totem up")

-- Distance bracket from the range references.
local refs = ns.Data.Defaults.rangeReferences
local near, far
for id, yards in pairs(refs) do
    if yards <= 5 and not near then near = id end
    if yards >= 25 and not far then far = id end
end
H.Check(near and far, "range references with melee and long range")
H.known[near], H.known[far] = true, true
H.spells[near] = {name = "melee probe", inRange = true}
H.spells[far] = {name = "far probe", inRange = true}
H.Equal(S.TargetWithin(5), true, "melee probe reaches")
H.spells[near].inRange = false
H.spells[far].inRange = false
H.Equal(S.TargetWithin(10), false, "beyond the long probe")

H.Done("test_state")
