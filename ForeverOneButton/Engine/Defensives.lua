-- Forever One Button: defensive and sustain suggestions.
--
-- A row of up to four icons beside the grid, in combat or when health is
-- low: the class's defensive cooldowns (Defaults.defensive) and the best
-- healing item owned (Consumables.healingItems, best first), ordered by how
-- hurt the player is:
--   health bands 25 / 50 / 80 %: panic, major, mitigate, healthy;
--   tiers (Defaults.defenseTiers): 1 immunity, 2 big heal, 3 other,
--   4 pre-emptive wall; items count as tier 2;
--   panic {1,2,4,3}, major {2,4,1,3}, mitigate {4,3,2,1}, healthy: list
--   order with immunities last.
-- With "hold emergencies" (default on) immunities wait for the panic band,
-- items and long big heals for health below 50 %; a waiting entry is shown
-- dimmed after the live ones. Pet cues (heal below the threshold, revive or
-- summon), group heals (off by default) and crowd-control breakers (off by
-- default) lead the row. Unknown health never hides an entry.
local ADDON_NAME, ns = ...

local Defensives = {}
ns.Defensives = Defensives

Defensives.MAX_ICONS = 4
Defensives.BANDS = {25, 50, 80}
Defensives.LONG_COOLDOWN_MS = 60000
local TIER_ORDER = {
    [1] = {1, 2, 4, 3},
    [2] = {2, 4, 1, 3},
    [3] = {4, 3, 2, 1},
}
-- Loss-of-control types -> spell mechanic (Data/CCBreakers.lua keys).
local MECHANIC_BY_LOC = {CHARM = 1, CONFUSE = 2, DISARM = 3, FEAR = 5, ROOT = 7, SILENCE = 9, SLEEP = 10,
    SNARE = 11, STUN = 12, FREEZE = 13, INCAPACITATE = 14, POLYMORPH = 17, BANISH = 18, HORROR = 24}

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

-- 1 panic .. 4 healthy, nil when health cannot be read.
function Defensives.Band(unit)
    for i, pct in ipairs(Defensives.BANDS) do
        local below = ns.State.HealthBelow(unit or "player", pct)
        if below == nil then return nil end
        if below then return i end
    end
    return #Defensives.BANDS + 1
end

-- Items ---------------------------------------------------------------------
local usedThisFight = {}

-- Bag counts can be secret in combat: the last plain count is kept per item
-- and used then (a use seen in the fight takes one off).
local lastCount = {}
function Defensives.ItemCount(itemID)
    local count = Plain(Call(C_Item and C_Item.GetItemCount, itemID))
    if count == nil then count = Plain(Call(GetItemCount, itemID)) end
    if type(count) == "number" then
        lastCount[itemID] = count
        return count
    end
    return lastCount[itemID] or 0
end

-- Item uses seen (any item on a cell, every healing item): the cooldown they
-- started when the client's timers are secret. Potions and healthstones
-- share two minutes.
Defensives.ITEM_COOLDOWN_SECONDS = 120
Defensives.USE_LAG_SECONDS = 0.5
local usedAt = {}

-- (start, seconds) while the cooldown of the last use seen still runs.
function Defensives.ItemUseCooldown(itemID)
    local at = usedAt[itemID]
    if not at or GetTime() - at >= Defensives.ITEM_COOLDOWN_SECONDS then return nil end
    return at, Defensives.ITEM_COOLDOWN_SECONDS
end

-- Item cooldowns are secret in combat: a healing item used this fight counts
-- as on cooldown until combat ends, any other item for two minutes after a
-- use seen. Right after a use the client may not show the cooldown yet.
function Defensives.ItemOnCooldown(itemID)
    if usedThisFight[itemID] then return true end
    local recent = Defensives.ItemUseCooldown(itemID)
    local start, duration = Call(C_Container and C_Container.GetItemCooldown, itemID)
    start, duration = Plain(start), Plain(duration)
    if type(start) == "number" and type(duration) == "number" then
        if start > 0 and start + duration > GetTime() then return true end
        return recent ~= nil and GetTime() - recent < Defensives.USE_LAG_SECONDS
    end
    if recent then return true end
    return nil
end

-- Best owned healing item, by the data's order (best first).
function Defensives.BestHealingItem()
    for _, itemID in ipairs(ns.Data.Consumables.healingItems) do
        if Defensives.ItemCount(itemID) > 0 then return itemID end
    end
    return nil
end

-- Spells --------------------------------------------------------------------
local function LongCooldown(spellID)
    local ms = Plain(Call(GetSpellBaseCooldown, spellID))
    return type(ms) == "number" and ms >= Defensives.LONG_COOLDOWN_MS
end

local function SpellEntry(first, tier)
    local id = ns.Ranks.Pressed(first)
    if not id then return nil end
    if ns.State.BuffActive(first) == true then return nil end -- already up
    local usable = ns.State.Usable(id)
    local ready = usable ~= false and ns.State.OnCooldown(id) ~= true
    return {kind = ns.ENTRY.SPELL, id = id, base = first, tier = tier, ready = ready}
end

local function ItemEntry(itemID)
    return {kind = ns.ENTRY.ITEM, id = -itemID, item = itemID, tier = 2,
        ready = Defensives.ItemOnCooldown(itemID) ~= true}
end

local function FirstReady(list)
    for _, first in ipairs(list or {}) do
        local entry = SpellEntry(first)
        if entry and entry.ready then return entry end
    end
    return nil
end

-- Leading cues ----------------------------------------------------------------
local petSeen = false
local function PetCue(class)
    if not ns.Settings.Feature("petCues") then return nil end
    local exists = Plain(Call(UnitExists, "pet"))
    if exists == true then
        petSeen = true
        if Plain(Call(UnitIsDead, "pet")) == true then return FirstReady(ns.Data.Defaults.petRez[class]) end
        if ns.State.HealthBelow("pet", ns.Settings.Feature("petHealBelow")) == true then
            return FirstReady(ns.Data.Defaults.petHeal[class])
        end
        return nil
    end
    -- No pet out: revive or summon only after one was seen this session.
    if petSeen and exists == false then return FirstReady(ns.Data.Defaults.petRez[class]) end
    return nil
end

local function GroupHealCue(class)
    if not ns.Settings.Feature("groupHeals") or not ns.InCombat() then return nil end
    local below80, below50 = 0, 0
    for i = 1, 4 do
        local unit = "party" .. i
        if Plain(Call(UnitExists, unit)) == true and Plain(Call(UnitIsDeadOrGhost, unit)) ~= true then
            if ns.State.HealthBelow(unit, 80) == true then below80 = below80 + 1 end
            if ns.State.HealthBelow(unit, 50) == true then below50 = below50 + 1 end
        end
    end
    if below80 >= 2 or below50 >= 1 then return FirstReady(ns.Data.Defaults.groupHeal[class]) end
    return nil
end

local function BreakerCue()
    if not ns.Settings.Feature("ccBreak") or not C_LossOfControl then return nil end
    local count = Plain(Call(C_LossOfControl.GetActiveLossOfControlDataCount))
    if type(count) ~= "number" then return nil end
    for i = 1, count do
        local data = Call(C_LossOfControl.GetActiveLossOfControlData, i)
        local mechanic = type(data) == "table" and MECHANIC_BY_LOC[Plain(data.locType)]
        for spellID, itemID in pairs(mechanic and ns.Data.CCBreakers.byMechanic[mechanic] or {}) do
            if itemID == 0 then
                local entry = SpellEntry(spellID)
                if entry and entry.ready then entry.breaker = true; return entry end
            end
        end
    end
    return nil
end

-- Emergency heal (owner request 2026-10-18) -----------------------------------
-- In a fight with health below the threshold: the first ready healing spell
-- of the class's defensive list (Defaults.categories.healing) that has a
-- cell, else the best healing item if it has a cell. Queue.Build puts it at
-- position 1, so the grid and the pixel both name it. Health that cannot be
-- read never triggers it.
function Defensives.EmergencyHeal()
    if not ns.Settings.Feature("emergencyHeal") or not ns.InCombat() then return nil end
    if ns.State.HealthBelow("player", ns.Settings.Feature("emergencyHealBelow")) ~= true then return nil end
    local class = ns.Trees.Class()
    local healing = ns.Data.Defaults.categories.healing
    for _, first in ipairs(class and ns.Data.Defaults.defensive[class] or {}) do
        if healing[first] then
            local entry = SpellEntry(first, 2)
            if entry and entry.ready and ns.Actions.SlotFor(entry.id) then
                entry.emergency = true
                return entry
            end
        end
    end
    local itemID = ns.Settings.Feature("healingItems") and Defensives.BestHealingItem()
    if itemID then
        local entry = ItemEntry(itemID)
        if entry.ready and ns.Actions.SlotFor(entry.id) then
            entry.emergency = true
            return entry
        end
    end
    return nil
end

-- The row ---------------------------------------------------------------------
-- {entries = {...}, band} or nil when the row is off or has nothing to show.
function Defensives.Suggest()
    if not ns.Settings.Feature("defensives") then return nil end
    local class = ns.Trees.Class()
    if not class then return nil end
    local band = Defensives.Band("player")
    local entries, seen = {}, {}
    local function Push(entry)
        if entry and #entries < Defensives.MAX_ICONS and not seen[entry.id] then
            seen[entry.id] = true
            entries[#entries + 1] = entry
        end
    end
    Push(BreakerCue())
    Push(GroupHealCue(class))
    Push(PetCue(class))

    if ns.InCombat() or (band and band <= 2) then
        local tiers = ns.Data.Defaults.defenseTiers
        local list = {}
        for index, first in ipairs(ns.Data.Defaults.defensive[class] or {}) do
            local entry = SpellEntry(first, tiers[first] or 3)
            if entry then entry.index = index; list[#list + 1] = entry end
        end
        if ns.Settings.Feature("healingItems") then
            local itemID = Defensives.BestHealingItem()
            if itemID then
                local entry = ItemEntry(itemID)
                entry.index = #list + 1
                list[#list + 1] = entry
            end
        end
        local hold = ns.Settings.Feature("holdEmergencies")
        for _, entry in ipairs(list) do
            if hold then
                if entry.tier == 1 then entry.waiting = band ~= nil and band > 1
                elseif entry.item or (entry.tier == 2 and LongCooldown(entry.id)) then entry.waiting = band ~= nil and band > 2 end
            end
        end
        local rank = {}
        local order = band and TIER_ORDER[band]
        if order then
            for position, tier in ipairs(order) do rank[tier] = position end
        end
        table.sort(list, function(a, b)
            local la, lb = a.ready and not a.waiting, b.ready and not b.waiting
            if la ~= lb then return la end
            local ra, rb = rank[a.tier] or (a.tier == 1 and 9 or 5), rank[b.tier] or (b.tier == 1 and 9 or 5)
            if ra ~= rb then return ra < rb end
            return a.index < b.index
        end)
        for _, entry in ipairs(list) do Push(entry) end
    end
    if #entries == 0 then return nil end
    return {entries = entries, band = band}
end

local frame = CreateFrame("Frame")
Defensives.frame = frame
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED")
-- Every healing item counted while counts are plain: when the bags change
-- and as a fight starts, so the counts kept for the fight are current.
local function Recount()
    for _, itemID in ipairs(ns.Data.Consumables.healingItems) do Defensives.ItemCount(itemID) end
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then wipe(usedThisFight) Recount() return end
    if event == "PLAYER_REGEN_DISABLED" or event == "BAG_UPDATE_DELAYED" then Recount() return end
    local spellID = select(3, ...)
    if type(spellID) ~= "number" or ns.IsSecret(spellID) then return end
    for _, itemID in ipairs(ns.Data.Consumables.healingItems) do
        local _, itemSpell = Call(C_Item and C_Item.GetItemSpell, itemID)
        if Plain(itemSpell) == spellID then
            usedAt[itemID] = GetTime()
            if ns.InCombat() then usedThisFight[itemID] = true end
            if lastCount[itemID] and lastCount[itemID] > 0 then lastCount[itemID] = lastCount[itemID] - 1 end
        end
    end
    for slot = 1, ns.MAX_SLOTS do
        local cell = ns.Actions.applied[slot]
        if cell and cell.kind == "item" then
            local _, itemSpell = Call(C_Item and C_Item.GetItemSpell, cell.id)
            if Plain(itemSpell) == spellID then usedAt[cell.id] = GetTime() end
        end
    end
end)
