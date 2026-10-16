-- Gate verdicts: true, false or nil; only false holds an entry back.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local V = ns.Gates.Verdict
local RAGE = 1
H.units.player = {health = 60, healthMax = 100, power = {[RAGE] = 50}, powerMax = {[RAGE] = 100}}
H.units.target = {health = 30, healthMax = 100, attackable = true}
local ctx = {enemies = 2, targetAttackable = true, starved = false}
local function Fresh() H.now = H.now + 1 end

H.stealthed = true
H.Equal(V({t = "stealth"}, ctx), true, "stealth")
H.Equal(V({t = "stealth", neg = true}, ctx), false, "not stealthed")
H.known[603] = true
H.Equal(V({t = "known", id = 603, neg = true}, ctx), false, "known neg")
H.Equal(V({t = "known", id = 999}, ctx), false, "unknown spell")
H.Equal(V({t = "starved"}, {starved = true}), true, "starved")
H.Equal(V({t = "unconfirmed"}, ctx), false, "unconfirmed always blocks")
H.totems[1] = true
H.Equal(V({t = "totem", slot = 1, neg = true}, ctx), false, "totem down, neg")
H.Equal(V({t = "targets", op = ">", n = 1}, ctx), true, "two targets > 1")
H.Equal(V({t = "targets", op = "=", n = 1}, ctx), false, "not one target")
H.Fire("PLAYER_SWING", 2.0, 0)
H.Equal(V({t = "swing", op = "<", n = 2.5}, ctx), true, "swing soon")
H.Equal(V({t = "swing", op = "<", n = 1, ranged = true}, ctx), nil, "no ranged swing known")
H.comboPoints = 3
H.Equal(V({t = "resource", res = "combo_points", op = ">=", n = 3}, ctx), true, "3 combo points")
-- Absolute rage turns into a percentage of max rage.
H.Equal(V({t = "power", res = "rage", op = ">=", n = 40}, ctx), true, "rage 50 >= 40")
Fresh()
H.Equal(V({t = "power", res = "rage", op = "<", n = 40}, ctx), false, "rage 50 not < 40")
H.Equal(V({t = "power", res = "rage", op = "=", n = 50}, ctx), nil, "= has no answer")
H.Equal(V({t = "health", op = ">", pct = 50}, ctx), true, "health 60% > 50%")
H.Equal(V({t = "execute", op = "<", pct = 20}, ctx), false, "target 30% not in execute")
H.Equal(V({t = "execute", op = "<", pct = 20}, {targetAttackable = false}), nil, "no target: unknown")
-- dot: only "no DoT on a target about to die" (non-boss below 35%).
H.Equal(V({t = "dot", id = 772}, ctx), false, "dying target: skip the DoT")
H.Equal(V({t = "dot", id = 772}, {targetBoss = true}), nil, "boss: no opinion")
-- cd: neg wants the spell on cooldown; unlearned counts as on cooldown.
H.spells[23881] = {name = "Bloodthirst", cooldown = true}
H.known[23881] = true
H.Equal(V({t = "cd", id = 23881, neg = true}, ctx), true, "Bloodthirst on cooldown")
H.Equal(V({t = "cd", id = 23881}, ctx), false, "not ready")
H.Equal(V({t = "cd", id = 1680, neg = true}, ctx), true, "unlearned Whirlwind counts as on cooldown")
-- any / all are three-valued.
local T, F, U = {t = "starved"}, {t = "unconfirmed"}, {t = "tick"} -- true, false, unknown below
local yes = {starved = true, enemies = 1}
H.Equal(V({t = "any", g = {F, T}}, yes), true, "any: one true")
H.Equal(V({t = "any", g = {F, U}}, yes), nil, "any: false and unknown")
H.Equal(V({t = "any", g = {F, F}}, yes), false, "any: all false")
H.Equal(V({t = "all", g = {T, F}}, yes), false, "all: one false")
H.Equal(V({t = "all", g = {T, U}}, yes), nil, "all: true and unknown")
H.Equal(V({t = "all", g = {T, T}}, yes), true, "all: all true")
H.Equal(V({t = "tick", op = "<", n = 1}, ctx), nil, "tick: no evaluator")
H.Equal(V({t = "nonsense"}, ctx), nil, "unknown type: no opinion")
H.Equal(ns.Gates.Blocks({U, T}, yes), false, "unknown does not block")
H.Equal(ns.Gates.Blocks({T, F}, yes), true, "false blocks")

H.Done("test_gates")
