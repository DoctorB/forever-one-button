-- Forever One Button: the conditions of a priority-list entry.
--
-- Each gate (Data/Rotations.lua `gates`) answers true, false or nil. An entry
-- is held back only by a gate that answers false: an unknown never blocks,
-- since on Forever many combat values cannot be read.
local ADDON_NAME, ns = ...

local Gates = {}
ns.Gates = Gates

local POWER = {mana = 0, rage = 1, energy = 3}
local DOT_MIN_TARGET_PCT = 35

local function Not(v)
    if v == nil then return nil end
    return not v
end

local function Neg(gate, v)
    if gate.neg then return Not(v) end
    return v
end

-- "below pct" answers for the comparison operators. = and != have no answer.
local function Compare(op, below, belowOrAt)
    if op == "<" then return below end
    if op == "<=" then return belowOrAt end
    if op == ">=" then return Not(below) end
    if op == ">" then return Not(belowOrAt) end
    return nil
end

local function NumberCompare(op, value, n)
    if type(value) ~= "number" then return nil end
    if op == "<" then return value < n end
    if op == "<=" then return value <= n end
    if op == ">" then return value > n end
    if op == ">=" then return value >= n end
    if op == "=" then return value == n end
    if op == "!=" then return value ~= n end
    return nil
end

local function PowerPercent(gate)
    if gate.ispct then return gate.n end
    local max = ns.State.PowerMax(POWER[gate.res])
    if not max then return nil end
    return gate.n / max * 100
end

-- Applications compared through at-least questions only.
local function Stacks(gate)
    local unit = gate.tgt and "target" or "player"
    local function AtLeast(k) return ns.State.StacksAtLeast(unit, gate.id, k) end
    local op, n = gate.op, gate.n
    if op == ">=" then return AtLeast(n) end
    if op == ">" then return AtLeast(n + 1) end
    if op == "<" then return Not(AtLeast(n)) end
    if op == "<=" then return Not(AtLeast(n + 1)) end
    if op == "=" then
        local atLeast, above = AtLeast(n), AtLeast(n + 1)
        if atLeast == nil or above == nil then return nil end
        return atLeast and not above
    end
    return nil
end

local Verdict
local EVALUATE = {
    stealth = function(g) return Neg(g, ns.State.Stealthed()) end,
    known = function(g) return Neg(g, ns.Ranks.HighestKnown(g.id) ~= nil) end,
    starved = function(_, ctx) return ctx.starved end,
    unconfirmed = function() return false end,
    targets = function(g, ctx) return NumberCompare(g.op, ctx.enemies, g.n) end,
    -- Enemies attacking someone else in the group (State.LooseCount).
    free = function(g) return NumberCompare(g.op, ns.State.LooseCount(), g.n) end,
    totem = function(g) return Neg(g, ns.State.TotemActive(g.slot)) end,
    -- strict: only a sure "within" passes (a stance change is not undone
    -- for free).
    near = function(g)
        local within = ns.State.TargetWithin(g.n)
        if g.strict then return within == true end
        return within
    end,
    -- Target announced it is running away (Engine/State.lua).
    fleeing = function(g) return Neg(g, ns.State.TargetFleeing()) end,
    -- Seconds since our own last cast of the spell; never cast counts as long ago.
    since = function(g)
        local seconds = ns.State.SecondsSinceCast(g.id)
        if seconds == nil then return g.op == ">" or g.op == ">=" end
        return NumberCompare(g.op, seconds, g.n)
    end,
    swing = function(g) return NumberCompare(g.op, ns.State.SwingRemaining(g.ranged and 2 or 0), g.n) end,
    resource = function(g) return NumberCompare(g.op, ns.State.ComboPoints(), g.n) end,
    power = function(g)
        local pct = PowerPercent(g)
        if not pct then return nil end
        local powerType = POWER[g.res]
        return Compare(g.op, ns.State.PowerBelow("player", pct, powerType),
            ns.State.PowerBelow("player", pct + 0.1, powerType))
    end,
    execute = function(g, ctx)
        if not ctx.targetAttackable then return nil end
        return Compare(g.op, ns.State.HealthBelow("target", g.pct), ns.State.HealthBelow("target", g.pct + 0.1))
    end,
    health = function(g)
        return Compare(g.op, ns.State.HealthBelow("player", g.pct), ns.State.HealthBelow("player", g.pct + 0.1))
    end,
    stack = Stacks,
    -- Elite or boss target. Unlike the other gates an unknown answer
    -- blocks: the entry is only worth it where the fight is long.
    elite = function(g) return Neg(g, ns.State.TargetIsElite() == true) end,
    -- The target is a player character (PvP); unknown does not block.
    -- strict: unknown counts as not a player.
    player = function(g)
        local player = ns.State.TargetIsPlayer()
        if g.strict then player = player == true end
        return Neg(g, player)
    end,
    -- Target's class (UnitClass token) in g.set; unknown does not block.
    class = function(g)
        local class = ns.State.TargetClass()
        if class == nil then return nil end
        return Neg(g, g.set[class] == true)
    end,
    -- A stance change that keeps at least g.need rage and loses at most
    -- g.lose: rage between g.need and the kept rage + g.lose (Forever:
    -- Tactical Mastery keeps 10, Improved Tactical Mastery 15 more).
    stanceRage = function(g, ctx)
        local kept = ns.State.StanceRageKept()
        if kept < g.need then return false end
        return Verdict({t = "all", g = {
            {t = "power", res = "rage", op = ">=", n = g.need},
            {t = "power", res = "rage", op = "<=", n = kept + g.lose},
        }}, ctx)
    end,
    -- In a party or raid; unreadable counts as alone.
    group = function(g) return Neg(g, ns.State.InGroup()) end,
    -- The target attacks someone else in the group (a taunt): not tanked by
    -- the player, its own target a friendly unit, no crowd control seen on
    -- it (owner request 2026-11-16: never wake a polymorphed or sapped mob).
    -- Unknown blocks: a taunt is only pressed when every reading says so.
    loose = function(g)
        local free = ns.State.TargetOnOther() == true and ns.State.TargetAttacksAlly() == true
            and ns.State.TargetControlled() ~= true
        return Neg(g, free)
    end,
    -- neg: the gate wants the spell ON cooldown. An unlearned spell counts
    -- as on cooldown (it cannot be pressed either).
    cd = function(g)
        local id = ns.Ranks.HighestKnown(g.id)
        local onCooldown = true
        if id then onCooldown = ns.State.OnCooldown(id) end
        if onCooldown == nil then return nil end
        if g.neg then return onCooldown end
        return not onCooldown
    end,
    buff = function(g) return Neg(g, ns.State.BuffActive(g.id, g.dur)) end,
    -- The spell is queued by the client (an on-next-swing attack waiting
    -- for the swing: its rage is spent when it lands).
    queued = function(g)
        local id = ns.Ranks.HighestKnown(g.id)
        if not id then return Neg(g, false) end
        return Neg(g, ns.Queue.Current(id))
    end,
    -- Rage kept for an interrupt (g.id) against a kind of target seen
    -- casting: needs g.n rage there; elsewhere, or when the interrupt is off,
    -- unknown, cooling down or unusable for a reason other than rage (no
    -- shield), it does not hold anything back.
    reserve = function(g, ctx)
        if not ns.Settings.Feature("interrupts") then return true end
        if not (ns.Interrupts and ns.Interrupts.TargetIsCaster() == true) then return true end
        local id = ns.Ranks.HighestKnown(g.id)
        if not id or ns.State.OnCooldown(id) == true then return true end
        local usable, noResources = ns.State.Usable(id)
        if usable == false and not noResources then return true end
        return Verdict({t = "power", res = g.res or "rage", op = ">=", n = g.n}, ctx)
    end,
    -- Informational in the data; it only says "no DoT on a target about to
    -- die" (non-boss, below 35%). DoTs already ticking are handled by
    -- Engine/Dots.lua.
    dot = function(g, ctx)
        if ctx.targetBoss or ns.Data.Defaults.frontalDots[g.id] then return nil end
        if ns.State.HealthBelow("target", DOT_MIN_TARGET_PCT) == true then return false end
        return nil
    end,
    tick = function() return nil end,
    any = function(g, ctx)
        local unknown = false
        for _, member in ipairs(g.g or {}) do
            local v = Verdict(member, ctx)
            if v == true then return true end
            if v == nil then unknown = true end
        end
        if unknown or #(g.g or {}) == 0 then return nil end
        return false
    end,
    all = function(g, ctx)
        local unknown = false
        for _, member in ipairs(g.g or {}) do
            local v = Verdict(member, ctx)
            if v == false then return false end
            if v == nil then unknown = true end
        end
        if unknown or #(g.g or {}) == 0 then return nil end
        return true
    end,
}

function Verdict(gate, ctx)
    local evaluate = EVALUATE[gate.t]
    if not evaluate then return nil end
    local ok, v = pcall(evaluate, gate, ctx)
    if not ok then return nil end
    return v
end
Gates.Verdict = Verdict

-- True when some gate answers false.
function Gates.Blocks(gates, ctx)
    for _, gate in ipairs(gates or {}) do
        if Verdict(gate, ctx) == false then return true end
    end
    return false
end
