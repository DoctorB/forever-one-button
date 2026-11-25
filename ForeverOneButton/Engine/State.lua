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

-- What the client says about a real cooldown (the global cooldown excluded).
local function ClientCooldown(spellID)
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

-- The cooldown our own cast started: (start, seconds) while the spell's base
-- cooldown, counted from the cast seen, is still running; nil otherwise.
-- Spells whose cooldown is only the global one have none.
State.GCD_SECONDS = 1.5
function State.CastCooldown(spellID)
    local since = State.SecondsSinceCast(spellID)
    if not since then return nil end
    local ms = Plain(Call(GetSpellBaseCooldown, spellID))
    if type(ms) ~= "number" then return nil end
    local seconds = ms / 1000
    if seconds <= State.GCD_SECONDS or since >= seconds then return nil end
    return GetTime() - since, seconds
end

-- Real cooldown running (the global cooldown excluded). The client answers;
-- when it cannot (secret timers), or in the moment between the cast and the
-- client's cooldown update, the cast we saw does.
State.CAST_LAG_SECONDS = 0.5
function State.OnCooldown(spellID)
    local active = ClientCooldown(spellID)
    if active == true then return true end
    if State.CastCooldown(spellID) then
        if active == nil then return true end
        if State.SecondsSinceCast(spellID) < State.CAST_LAG_SECONDS then return true end
    end
    return active
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

-- Elite, rare elite or boss target: true, false, or nil when unreadable.
local ELITE = {elite = true, rareelite = true, worldboss = true}
function State.TargetIsElite()
    if State.TargetIsBoss() == true then return true end
    local classification = Plain(Call(UnitClassification, "target"))
    if type(classification) ~= "string" then return nil end
    return ELITE[classification] == true
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

-- Enemies on nameplates that attack someone else in the group: a threat
-- entry for the player without the aggro (UnitThreatSituation 0 or 1) and a
-- friendly target other than the player (a mob held by crowd control has
-- none). Unreadable plates are not counted; 0 when nameplates are off.
-- State.looseDetail, for the log: plates without the player's aggro, of
-- those with a readable target, of those friendly (a log of 2026-11-16 had
-- 17 Taunts on the pixel but the count stayed at 0).
local looseCount, looseAt = 0, -1
State.looseDetail = "0/0/0"
function State.LooseCount()
    local now = GetTime()
    if now - looseAt < ENEMY_CACHE_SECONDS then return looseCount end
    local n, low, targeted = 0, 0, 0
    if UnitThreatSituation then
        for i = 1, 40 do
            local unit = "nameplate" .. i
            -- Enemy players are not "loose": they have no threat table to
            -- win back (Warsong Gulch log of 2026-11-22: Taunt and
            -- Demoralizing Shout pressed for players attacking a teammate).
            if Plain(Call(UnitExists, unit)) == true and Plain(Call(UnitCanAttack, "player", unit)) == true
                and State.UnitIsPlayer(unit) ~= true then
                local status = Plain(Call(UnitThreatSituation, "player", unit))
                if type(status) == "number" and status < 2 then
                    low = low + 1
                    local target = unit .. "target"
                    if Plain(Call(UnitExists, target)) == true then
                        targeted = targeted + 1
                        if Plain(Call(UnitIsUnit, target, "player")) ~= true
                            and Plain(Call(UnitIsFriend, "player", target)) == true then
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
    looseCount, looseAt = n, now
    State.looseDetail = low .. "/" .. targeted .. "/" .. n
    return n
end

-- A player character: true, false, or nil when unreadable, and the reading
-- that answered (target log line). UnitIsPlayer alone answered nothing in
-- the battleground of 2026-11-22 (Taunt and Sunder kept coming on players),
-- so the other readings follow: player-controlled, the GUID, and last being
-- in a battleground or arena, where nearly every enemy is a player.
function State.UnitIsPlayer(unit)
    local player = Plain(Call(UnitIsPlayer, unit))
    if player ~= nil then return player == true, "unit" end
    local controlled = Plain(Call(UnitPlayerControlled, unit))
    if controlled ~= nil then return controlled == true, "controlled" end
    local guid = Plain(Call(UnitGUID, unit))
    if type(guid) == "string" then
        if guid:find("^Player%-") then return true, "guid" end
        if guid:find("^%a+%-") then return false, "guid" end
    end
    local _, instanceType = Call(IsInInstance)
    instanceType = Plain(instanceType)
    if instanceType == "pvp" or instanceType == "arena" then return true, "instance" end
    return nil, "-"
end

-- Class token of the target ("WARRIOR"), nil when unreadable.
function State.TargetClass()
    local _, class = Call(UnitClass, "target")
    class = Plain(class)
    if type(class) ~= "string" then return nil end
    return class
end

-- Rage kept through a stance change. Forever data (build 1.60.1.71091,
-- SpellEffect): Tactical Mastery 1310185 (class ability, level 14) keeps 10,
-- the talent Improved Tactical Mastery 12295 adds 15.
State.STANCE_RAGE = {[1310185] = 10, [12295] = 15}
function State.StanceRageKept()
    local kept = 0
    for spellID, rage in pairs(State.STANCE_RAGE) do
        if ns.Ranks.Known(spellID) then kept = kept + rage end
    end
    return kept
end

function State.TargetIsPlayer()
    return (State.UnitIsPlayer("target"))
end

-- In a party or raid: true or false (unreadable counts as alone).
function State.InGroup()
    return Plain(Call(IsInGroup)) == true
end

-- The target attacks someone else: true when the player has a threat entry
-- on it but is not tanking it (UnitThreatSituation 0 or 1), false while
-- tanking it (2 or 3), nil when unreadable or not in combat with it.
function State.TargetOnOther()
    if not UnitThreatSituation then return nil end
    local status = Plain(Call(UnitThreatSituation, "player", "target"))
    if type(status) ~= "number" then return nil end
    return status < 2
end

-- The target's own target is a friendly unit other than the player (a group
-- member or a pet): true; false when it targets the player or nobody (a
-- mob polymorphed, sapped, trapped or otherwise held drops its target); nil
-- when unreadable.
function State.TargetAttacksAlly()
    local exists = Plain(Call(UnitExists, "targettarget"))
    if exists == nil then return nil end
    if exists ~= true then return false end
    if Plain(Call(UnitIsUnit, "targettarget", "player")) == true then return false end
    local friend = Plain(Call(UnitIsFriend, "player", "targettarget"))
    if friend == nil then return nil end
    return friend == true
end

-- Crowd control that breaks or is wasted on a taunt, all ranks: Polymorph,
-- Sap, Hibernate, Freezing Trap, Shackle Undead, Banish, Seduction, Blind,
-- Gouge, Repentance, Wyvern Sting, Scare Beast, Fear.
local TARGET_CC = {118, 12824, 12825, 12826, 28270, 28271, 28272, 6770, 2070, 11297, 2637, 18657, 18658,
    3355, 14308, 14309, 9484, 9485, 10955, 710, 18647, 6358, 2094, 1776, 1777, 8629, 11285, 11286, 20066,
    19386, 24132, 24133, 1513, 14326, 14327, 5782, 6213, 6215}

-- One of those on the target: true; false when none is seen (target auras
-- are often unreadable in combat, so TargetAttacksAlly is the main check);
-- nil without the aura API.
function State.TargetControlled()
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) then return nil end
    for _, id in ipairs(TARGET_CC) do
        if type(Call(C_UnitAuras.GetUnitAuraBySpellID, "target", id)) == "table" then return true end
    end
    return false
end

-- Player under a stun, fear, charm or similar: nothing can be cast. In a
-- battleground (log of 2026-11-22) the pixel kept pressing through them:
-- 369 refusals in 91 minutes ("Can't do that while stunned/fleeing").
-- Roots, snares, silences and disarms are left out: a Warrior still acts.
-- Returns lost (true/false), source ("loc" from C_LossOfControl,
-- "full" from HasFullControl when the former cannot be read).
State.LOST_CONTROL = {
    STUN = true, STUN_MECHANIC = true, FEAR = true, FEAR_MECHANIC = true, CHARM = true,
    CONFUSE = true, POSSESS = true, SLEEP = true, INCAPACITATE = true, POLYMORPH = true,
    HORROR = true, FREEZE = true, BANISH = true, CYCLONE = true,
}
function State.ControlLost()
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount then
        local count = Plain(Call(C_LossOfControl.GetActiveLossOfControlDataCount))
        if type(count) == "number" then
            for i = 1, count do
                local data = Call(C_LossOfControl.GetActiveLossOfControlData, i)
                local locType = type(data) == "table" and Plain(data.locType)
                if locType and State.LOST_CONTROL[locType] then return true, "loc" end
            end
            return false, "loc"
        end
    end
    local full = Plain(Call(HasFullControl))
    if full == false then return true, "full" end
    return false, full == nil and "?" or "full"
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
-- On the target, when the aura cannot be read, the player's own
-- applications (Engine/Dots.lua) answer.
function State.StacksAtLeast(unit, spellID, count)
    local own = unit == "target" and ns.Dots.Stacks(spellID) or nil
    if not C_UnitAuras then
        if own then return own >= count end
        return nil
    end
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
        if type(applications) == "number" then return math.max(applications, 1) >= count end
        if own then return math.max(own, 1) >= count end
        return nil
    end
    if ns.InCombat() then
        if own then return own >= count end
        return nil
    end
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

-- Fleeing target -------------------------------------------------------------
-- Fleeing humanoids announce it with the emote "%s attempts to run away in
-- fear!" (same detection as HC One Button, Hunter/Pet.lua). The English text
-- is matched directly; on other locales any emote from the current target
-- below 35% health counts. The mark holds for FLEE_WINDOW seconds and only
-- for that target.
State.FLEE_WINDOW = 8
local fleeingGUID, fleeingUntil = nil, 0

function State.NoteMonsterEmote(text, sender)
    if type(sender) ~= "string" or ns.IsSecret(sender) or not State.TargetAttackable() then return end
    if Plain(Call(UnitName, "target")) ~= sender then return end
    local english = type(text) == "string" and not ns.IsSecret(text) and text:find("run away in fear", 1, true)
    if not english and State.HealthBelow("target", 35) ~= true then return end
    local guid = Plain(Call(UnitGUID, "target"))
    if not guid then return end
    fleeingGUID, fleeingUntil = guid, GetTime() + State.FLEE_WINDOW
end

-- true while the current target is marked as fleeing, false otherwise: the
-- emote is the only evidence, so its absence is a plain no.
function State.TargetFleeing()
    if not fleeingGUID or GetTime() >= fleeingUntil or not State.TargetAttackable() then return false end
    return Plain(Call(UnitGUID, "target")) == fleeingGUID
end

-- Events --------------------------------------------------------------------
local frame = CreateFrame("Frame")
State.frame = frame
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(frame.RegisterEvent, frame, "PLAYER_SWING")
pcall(frame.RegisterEvent, frame, "CHAT_MSG_MONSTER_EMOTE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spellID = select(3, ...)
        if type(spellID) == "number" and not ns.IsSecret(spellID) then State.NoteCast(spellID) end
    elseif event == "CHAT_MSG_MONSTER_EMOTE" then
        local text, sender = ...
        pcall(State.NoteMonsterEmote, text, sender)
    elseif event == "PLAYER_SWING" then
        -- Payload (duration, swingType, checksRange), as JustAC reads it on Forever.
        local duration, swingType = ...
        if type(swingType) == "number" and not ns.IsSecret(swingType) then State.NoteSwing(swingType, duration) end
    end
end)
