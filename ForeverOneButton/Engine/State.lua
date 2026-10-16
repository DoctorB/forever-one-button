-- Forever One Button: game state for the suggestion engine.
--
-- Every question returns true, false or nil (unknown). Callers treat nil as
-- "no opinion": an unknown never blocks a suggestion and never invents one.
-- Plain values are used when the client gives them; otherwise the engine-side
-- comparisons of Engine/Secret.lua answer. No secret is ever compared in Lua.
local ADDON_NAME, ns = ...

local State = {}
ns.State = State

local MEMO_SECONDS = 0.1
local ENEMY_CACHE_SECONDS = 0.25

local function Plain(value)
    if value == nil or ns.IsSecret(value) then return nil end
    return value
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

-- Health and power thresholds ---------------------------------------------
local memo, memoAt = {}, -1
local function Memo(key, compute)
    local now = GetTime()
    if now - memoAt >= MEMO_SECONDS then wipe(memo); memoAt = now end
    local hit = memo[key]
    if hit ~= nil then
        if hit == "?" then return nil end
        return hit
    end
    local value = compute()
    if value == nil then memo[key] = "?" else memo[key] = value end
    return value
end

function State.HealthBelow(unit, pct)
    return Memo("h" .. unit .. pct, function()
        local current, max = Plain(Call(UnitHealth, unit)), Plain(Call(UnitHealthMax, unit))
        if type(current) == "number" and type(max) == "number" and max > 0 then
            return current / max * 100 < pct
        end
        return ns.Secret.Below(unit, pct)
    end)
end

function State.PowerBelow(unit, pct, powerType)
    return Memo("p" .. unit .. tostring(powerType) .. pct, function()
        local current = Plain(Call(UnitPower, unit, powerType))
        local max = Plain(Call(UnitPowerMax, unit, powerType))
        if type(current) == "number" and type(max) == "number" and max > 0 then
            return current / max * 100 < pct
        end
        return ns.Secret.Below(unit, pct, powerType)
    end)
end

-- Maximum of a power type (plain on Forever), used to turn absolute rage or
-- energy thresholds into percentages.
function State.PowerMax(powerType)
    local max = Plain(Call(UnitPowerMax, "player", powerType))
    if type(max) == "number" and max > 0 then return max end
    return nil
end

-- Spells ------------------------------------------------------------------
-- usable (true/false/nil), notEnoughResources (true/false/nil).
function State.Usable(spellID)
    if not (C_Spell and C_Spell.IsSpellUsable) then return nil, nil end
    local usable, noResources = Call(C_Spell.IsSpellUsable, spellID)
    return Plain(usable), Plain(noResources)
end

-- Real cooldown running (the global cooldown excluded).
function State.OnCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldownDuration then
        local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
        if ok then
            local active = ns.Secret.DurationActive(duration)
            if active ~= nil then return active end
        end
    end
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local info = Call(C_Spell.GetSpellCooldown, spellID)
    if type(info) ~= "table" then return nil end
    local onGCD = Plain(info.isOnGCD)
    local start, duration = Plain(info.startTime), Plain(info.duration)
    if onGCD == true then return false end
    if type(start) == "number" and type(duration) == "number" then
        return start > 0 and start + duration > GetTime()
    end
    local active = Plain(info.isActive)
    if active ~= nil then return active == true end
    return nil
end

function State.InRange(spellID)
    if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
    local inRange = Plain(Call(C_Spell.IsSpellInRange, spellID, "target"))
    if inRange == nil then return nil end
    return inRange == true or inRange == 1
end

-- Target ------------------------------------------------------------------
function State.TargetAttackable()
    local exists = Plain(Call(UnitExists, "target"))
    if exists ~= true then return false end
    local attackable = Plain(Call(UnitCanAttack, "player", "target"))
    local dead = Plain(Call(UnitIsDeadOrGhost, "target"))
    return attackable == true and dead ~= true
end

function State.TargetIsBoss()
    local classification = Plain(Call(UnitClassification, "target"))
    if classification == "worldboss" then return true end
    local level = Plain(Call(UnitLevel, "target"))
    if level == -1 then return true end
    if classification == nil and level == nil then return nil end
    return false
end

-- Enemies engaged with the player: hostile nameplates with a threat entry.
-- 0 when nameplates are off: callers read that as "one target".
local enemyCount, enemyAt = 0, -1
function State.EnemyCount()
    local now = GetTime()
    if now - enemyAt < ENEMY_CACHE_SECONDS then return enemyCount end
    local n = 0
    if UnitThreatSituation then
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if Plain(Call(UnitExists, unit)) == true and Plain(Call(UnitCanAttack, "player", unit)) == true
                and Plain(Call(UnitThreatSituation, "player", unit)) ~= nil then
                n = n + 1
            end
        end
    end
    enemyCount, enemyAt = n, now
    return n
end

-- Distance bracket from range references (Defaults.rangeReferences: spell ->
-- yards): true when a known reference of <= yards reaches the target, false
-- when one of >= yards does not, nil otherwise.
function State.TargetWithin(yards)
    if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
    local within, beyond
    for refID, refYards in pairs(ns.Data.Defaults.rangeReferences) do
        local id = ns.Ranks.HighestKnown(refID)
        if id then
            local inRange = Plain(Call(C_Spell.IsSpellInRange, id, "target"))
            if inRange ~= nil then
                local reached = inRange == true or inRange == 1
                if reached and refYards <= yards then within = true end
                if not reached and refYards >= yards then beyond = true end
            end
        end
    end
    if within then return true end
    if beyond then return false end
    return nil
end

-- Player ------------------------------------------------------------------
function State.Stealthed()
    return Plain(Call(IsStealthed))
end

function State.ComboPoints()
    local points = Plain(Call(GetComboPoints, "player", "target"))
    if type(points) == "number" then return points end
    return nil
end

function State.TotemActive(slot)
    local haveTotem = Plain(Call(GetTotemInfo, slot))
    if haveTotem == nil then return nil end
    return haveTotem == true
end

-- Stance or form spell currently active (rank 1), or nil when none or unknown.
function State.ActiveForm()
    local count = Plain(Call(GetNumShapeshiftForms))
    if type(count) ~= "number" then return nil end
    for i = 1, count do
        local _, active, _, spellID = Call(GetShapeshiftFormInfo, i)
        if Plain(active) == true and type(Plain(spellID)) == "number" then return ns.Ranks.Base(spellID) end
    end
    return nil
end

-- Is spellID a stance or form of this character.
function State.IsForm(spellID)
    local count = Plain(Call(GetNumShapeshiftForms))
    if type(count) ~= "number" then return false end
    local first = ns.Ranks.Base(spellID)
    for i = 1, count do
        local _, _, _, formSpell = Call(GetShapeshiftFormInfo, i)
        if type(Plain(formSpell)) == "number" and ns.Ranks.Base(formSpell) == first then return true end
    end
    return false
end

-- Own casts and buffs -------------------------------------------------------
-- Player auras are unreadable in combat on Forever; the cast that opened a
-- buff window is the evidence there.
local castAt, auraUntil = {}, {}
function State.NoteCast(spellID)
    castAt[ns.Ranks.Base(spellID)] = GetTime()
end

function State.SecondsSinceCast(spellID)
    local at = castAt[ns.Ranks.Base(spellID)]
    if not at then return nil end
    return GetTime() - at
end

local function PlayerAura(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    local chain = ns.Ranks.Chain(spellID) or {spellID}
    for i = #chain, 1, -1 do
        local aura = Call(C_UnitAuras.GetPlayerAuraBySpellID, chain[i])
        if type(aura) == "table" and aura.auraInstanceID ~= nil then return aura end
    end
    return nil
end

-- Is the buff up: stance/form state, the aura itself out of combat, or a
-- cast within `duration` seconds / a remembered expiry in combat.
function State.BuffActive(spellID, duration)
    local first = ns.Ranks.Base(spellID)
    if State.IsForm(first) then
        local form = State.ActiveForm()
        if form == nil and Plain(Call(GetShapeshiftForm)) == nil then return nil end
        return form == first
    end
    local since = State.SecondsSinceCast(first)
    local castLive = duration ~= nil and since ~= nil and since < duration
    local aura = PlayerAura(first)
    if aura then
        local expires = Plain(aura.expirationTime)
        if type(expires) == "number" and expires > 0 then auraUntil[first] = expires end
        return true
    end
    if not ns.InCombat() then
        auraUntil[first] = nil
        return castLive
    end
    local untilAt = auraUntil[first]
    if castLive or (untilAt and GetTime() < untilAt) then return true end
    return nil
end

-- At least `count` applications of the aura on unit, or nil when unknown.
function State.StacksAtLeast(unit, spellID, count)
    if not C_UnitAuras then return nil end
    local aura
    if unit == "player" then
        aura = PlayerAura(spellID)
    elseif C_UnitAuras.GetUnitAuraBySpellID then
        local chain = ns.Ranks.Chain(spellID) or {spellID}
        for i = #chain, 1, -1 do
            aura = Call(C_UnitAuras.GetUnitAuraBySpellID, unit, chain[i])
            if type(aura) == "table" then break end
            aura = nil
        end
    end
    if aura then
        local applications = Plain(aura.applications)
        if type(applications) ~= "number" then return nil end
        return math.max(applications, 1) >= count
    end
    if ns.InCombat() then return nil end
    return count <= 0
end

-- Swing timer: PLAYER_SWING gives each swing's duration plainly on Forever.
local swingAt, swingDuration = {}, {}
function State.NoteSwing(swingType, duration)
    if type(duration) == "number" and not ns.IsSecret(duration) and duration > 0 then
        swingAt[swingType], swingDuration[swingType] = GetTime(), duration
    end
end

-- Seconds until the next swing (0 main hand, 2 ranged), nil when unknown.
function State.SwingRemaining(swingType)
    local at, duration = swingAt[swingType], swingDuration[swingType]
    if not (at and duration) then return nil end
    local remaining = at + duration - GetTime()
    if remaining < -duration then return nil end
    return math.max(remaining, 0)
end

-- Events --------------------------------------------------------------------
local frame = CreateFrame("Frame")
State.frame = frame
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(frame.RegisterEvent, frame, "PLAYER_SWING")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = select(3, ...)
        if type(spellID) == "number" and not ns.IsSecret(spellID) then State.NoteCast(spellID) end
    elseif event == "PLAYER_SWING" then
        -- Payload (duration, swingType, checksRange), as JustAC reads it on Forever.
        local duration, swingType = ...
        if type(swingType) == "number" and not ns.IsSecret(swingType) then State.NoteSwing(swingType, duration) end
    else
        ns.Ranks.InvalidateBars()
    end
end)
