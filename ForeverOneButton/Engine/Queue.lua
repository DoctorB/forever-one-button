-- Forever One Button: the suggestion queue.
--
-- Only the entries of the active tree's list are candidates (plus the class's
-- gap closers): a spell the list does not name, such as the other stance, is
-- never suggested. Each entry is ready when it is known, usable, off cooldown,
-- in range, not held back by a gate and not a DoT already ticking. Ready
-- entries come first in list order; the others follow as "coming up". With
-- nothing ready in a fight, position 1 is a deliberate wait.
--
-- The result has the shape the panel and the pixel read:
--   {status, detail, entries = {{kind, id, base, ready}...}, count, tree, context}
-- and an unchanged queue returns the previous snapshot object.
local ADDON_NAME, ns = ...

local Queue = {}
ns.Queue = Queue

Queue.MAX_ENTRIES = 10
Queue.GAP_CLOSER_MIN_YARDS = 8 -- Charge and Intercept start at 8 yards
Queue.GAP_CLOSER_DEBOUNCE = 3
local ATTACK_SPELL = 6603 -- "Attack": skipped while already swinging

local STATUS, ENTRY = ns.STATUS, ns.ENTRY

local function Result(status, detail)
    return {status = status, detail = detail, entries = {}, count = 0}
end

local function Same(a, b)
    if not b or a.status ~= b.status or a.count ~= b.count or a.tree ~= b.tree or a.context ~= b.context
        or a.detail ~= b.detail or a.leveling ~= b.leveling then
        return false
    end
    for i = 1, a.count do
        local x, y = a.entries[i], b.entries[i]
        if x.kind ~= y.kind or x.id ~= y.id or x.ready ~= y.ready or x.burst ~= y.burst
            or x.emergency ~= y.emergency then
            return false
        end
    end
    return true
end

local function Attacking()
    if not (C_Spell and C_Spell.IsCurrentSpell) then return false end
    local ok, on = pcall(C_Spell.IsCurrentSpell, ATTACK_SPELL)
    return ok and not ns.IsSecret(on) and on == true
end

-- Auto-repeat spells (Auto Shot, a wand's Shoot) toggle off when pressed
-- again: never suggested while running.
local function Repeating(spellID)
    if not (C_Spell and C_Spell.IsAutoRepeatSpell) then return false end
    local ok, on = pcall(C_Spell.IsAutoRepeatSpell, spellID)
    return ok and not ns.IsSecret(on) and on == true
end

-- Ready or the tier it waits in: 1 cooldown/resources, 2 barred (wrong
-- stance or form), 3 held back (gate, range, DoT up).
local function Evaluate(entry, id, ctx)
    local usable, noResources = ns.State.Usable(id)
    if ns.State.OnCooldown(id) == true or noResources == true then return false, 1 end
    if usable == false then return false, 2 end
    if ctx.targetAttackable and ns.State.InRange(id) == false then return false, 3 end
    if ns.Dots.Active(id) == true then return false, 3 end
    if ns.Gates.Blocks(entry.gates, ctx) then return false, 3 end
    return true
end

-- A list's home stance that is not learned yet (Berserker Stance before
-- level 30) stands for the stance the abilities use until then, with the
-- same "not already in it" gate.
Queue.STANCE_FALLBACK = {[2458] = 2457}
local fallbackEntries = {}
function Queue.HomeStance(entry)
    local fallback = Queue.STANCE_FALLBACK[entry.id]
    if not fallback or ns.Ranks.HighestKnown(entry.id) then return entry end
    fallbackEntries[fallback] = fallbackEntries[fallback]
        or {id = fallback, gates = {{t = "buff", id = fallback, neg = true}}}
    return fallbackEntries[fallback]
end

local function GapCloser(class, ctx)
    if not ctx.targetAttackable or ns.State.TargetWithin(Queue.GAP_CLOSER_MIN_YARDS) ~= false then return nil end
    for _, first in ipairs(ns.Data.Defaults.gapClosers[class] or {}) do
        local id = ns.Ranks.Pressed(first)
        local since = id and ns.State.SecondsSinceCast(first)
        if id and not (since and since < Queue.GAP_CLOSER_DEBOUNCE) and ns.State.OnCooldown(id) ~= true
            and ns.State.Usable(id) ~= false and ns.State.InRange(id) ~= false then
            return id, first
        end
    end
    return nil
end

-- Burst cue: in a fight, the first ready burst cooldown of the class
-- (Defaults.burstTriggers) that the list itself calls moves to position 2,
-- or stays at 1 when it already leads, and is marked. Never on a lone
-- non-boss target about to die.
Queue.DYING_PCT = 20
local function ApplyBurst(entries, class, ctx)
    if not (ns.Settings.Feature("burstCue") and ns.InCombat()) then return end
    if ctx.enemies == 1 and not ctx.targetBoss and ns.State.HealthBelow("target", Queue.DYING_PCT) == true then return end
    local triggers = {}
    for _, id in ipairs(ns.Data.Defaults.burstTriggers[class] or {}) do triggers[id] = true end
    for index, item in ipairs(entries) do
        if item.ready and triggers[item.base] then
            item.burst = true
            if index > 2 then
                table.remove(entries, index)
                table.insert(entries, 2, item)
            end
            return
        end
    end
end

function Queue.Build(previous)
    local class = ns.Trees.Class()
    if not (class and ns.Data.Rotations.classes[class]) then
        local result = Result(STATUS.MISSING, "no priority list for this class")
        if Same(result, previous) then return previous end
        return result
    end
    local enemies = ns.State.EnemyCount()
    local ctx = {targetAttackable = ns.State.TargetAttackable()}
    if ctx.targetAttackable and enemies < 1 then enemies = 1 end
    ctx.enemies = enemies
    ctx.targetBoss = ctx.targetAttackable and ns.State.TargetIsBoss() == true
    local tree = ns.Trees.Pick(class)
    local list, context, leveling = ns.Trees.List(class, tree, ns.Trees.Context(enemies))
    local result = Result(STATUS.OK)
    result.tree, result.context, result.leveling = tree, context, leveling
    if not list then
        result.detail = "no list for " .. tostring(tree) .. " " .. tostring(context)
        if Same(result, previous) then return previous end
        return result
    end

    -- Mana starvation (gate `starved`): something lacks resources and nothing
    -- else is usable. Settled before the gates read it.
    local candidates, seen = {}, {}
    local roles, activeForm = ns.Data.Defaults.abilityRoles, ns.State.ActiveForm()
    local attacking = Attacking()
    for _, listed in ipairs(list) do
        local entry = Queue.HomeStance(listed)
        local first = entry.id
        local id = ns.Ranks.Pressed(first)
        local role = roles[first]
        if id and not seen[first] and (role == nil or role == "mixed")
            and not (activeForm and activeForm == first)
            and not (first == ATTACK_SPELL and attacking)
            and not Repeating(id)
            and not (not ns.InCombat() and ns.Precombat.Offered(first)) then
            seen[first] = true
            candidates[#candidates + 1] = {entry = entry, id = id, first = first}
        end
    end
    local anyUsable = false
    for _, c in ipairs(candidates) do
        local usable, noResources = ns.State.Usable(c.id)
        if noResources then ctx.sawNoResources = true end
        if usable == true and not noResources then anyUsable = true end
    end
    ctx.starved = ctx.sawNoResources == true and not anyUsable

    if #candidates == 0 then
        result.detail = string.format("none of %d list entries known or usable here", #list)
    end

    local ready, waiting = {}, {{}, {}, {}}
    for _, c in ipairs(candidates) do
        local ok, tier = Evaluate(c.entry, c.id, ctx)
        local item = {kind = ENTRY.SPELL, id = c.id, base = c.first, ready = ok}
        if ok then ready[#ready + 1] = item else table.insert(waiting[tier], item) end
    end

    local entries = {}
    local gapID, gapFirst = GapCloser(class, ctx)
    if gapID then
        entries[1] = {kind = ENTRY.SPELL, id = gapID, base = gapFirst, ready = true, gapCloser = true}
    elseif #ready == 0 and (ns.InCombat() or ctx.targetAttackable) and #candidates > 0 then
        entries[1] = {kind = ENTRY.WAIT, id = ns.WAIT_ID}
    end
    for _, item in ipairs(ready) do
        if item.base ~= gapFirst then entries[#entries + 1] = item end
    end
    for tier = 1, 3 do
        for _, item in ipairs(waiting[tier]) do
            if item.base ~= gapFirst then entries[#entries + 1] = item end
        end
    end
    ApplyBurst(entries, class, ctx)
    -- Critical health: the emergency heal leads, replacing a wait.
    local heal = ns.Defensives.EmergencyHeal()
    if heal then
        for i = #entries, 1, -1 do
            if entries[i].kind == ENTRY.WAIT or entries[i].id == heal.id then table.remove(entries, i) end
        end
        table.insert(entries, 1, heal)
    end
    for i = 1, math.min(#entries, Queue.MAX_ENTRIES) do result.entries[i] = entries[i] end
    result.count = #result.entries
    result.candidates, result.ready = #candidates, #ready
    if Same(result, previous) then return previous end
    return result
end

-- Position 1 as the pixel needs it: an executable spell, or nil.
function Queue.Head(snapshot)
    if not snapshot or snapshot.status ~= STATUS.OK then return nil end
    local first = snapshot.entries[1]
    if first and first.ready and (first.kind == ENTRY.SPELL or first.kind == ENTRY.ITEM) then return first.id end
    return nil
end

local frame = CreateFrame("Frame")
Queue.frame = frame
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
for _, event in ipairs({"SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "UPDATE_SHAPESHIFT_FORM"}) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = select(3, ...)
        if type(spellID) == "number" and not ns.IsSecret(spellID) then ns.Dots.NoteCast(spellID) end
    else
        ns.Trees.Invalidate()
    end
end)
