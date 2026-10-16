-- Forever One Button: reminders out of combat.
--
-- Out of combat only (never mounted, dead or eating), up to six entries the
-- player can click in the reminder row (Panel/Reminders.lua):
--   * class buffs (Defaults.maintainedBuffs) missing or lapsing (3 minutes
--     solo, 5 in a group); group-wide buffs also when a party member in
--     range lacks them;
--   * consumables (Consumables.precombat): flask/elixir, Well Fed food,
--     scroll, weapon stone or oil, each category when no buff of it is up;
--     the first item owned whose stat the class uses; shamans get their
--     weapon imbue (Defaults.weaponImbues) instead of oils and stones;
--   * stealth for rogues (and Prowl for feral druids);
--   * a top-off heal below the threshold (off by default);
--   * recovery: drink below 50% mana (not warriors and rogues), food below
--     70% health, else a bandage unless recently bandaged.
-- Auras are readable out of combat; when they are not, nothing is offered.
local ADDON_NAME, ns = ...

local Precombat = {}
ns.Precombat = Precombat

Precombat.MAX_ENTRIES = 6
Precombat.LAPSE_SOLO, Precombat.LAPSE_GROUP = 180, 300
Precombat.DRINK_BELOW, Precombat.FOOD_BELOW = 50, 70
Precombat.TOPOFF_ALWAYS_BELOW = 35
local RECENTLY_BANDAGED = 11196
local STEALTH = {ROGUE = 1784, DRUID = 5215}
local MANA = 0
local CATEGORIES = {"flask", "food", "scroll", "weaponEnchant"}

-- Stats each class gains from (consumables are tagged with one).
local CLASS_STATS = {
    WARRIOR = {strength = true, agility = true, stamina = true, attackpower = true, armor = true, physical = true},
    ROGUE = {agility = true, strength = true, stamina = true, attackpower = true, armor = true, physical = true},
    HUNTER = {agility = true, stamina = true, intellect = true, attackpower = true, armor = true, physical = true},
    PALADIN = {strength = true, stamina = true, intellect = true, attackpower = true, spellpower = true,
        healing = true, armor = true, physical = true, caster = true},
    SHAMAN = {strength = true, agility = true, stamina = true, intellect = true, attackpower = true,
        spellpower = true, healing = true, armor = true, physical = true, caster = true},
    PRIEST = {intellect = true, spirit = true, stamina = true, spellpower = true, healing = true, armor = true, caster = true},
    MAGE = {intellect = true, spirit = true, stamina = true, spellpower = true, armor = true, caster = true},
    WARLOCK = {intellect = true, spirit = true, stamina = true, spellpower = true, armor = true, caster = true},
}

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function Results(ok, ...)
    if not ok then return nil end
    return ...
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return Results(pcall(fn, ...))
end

local function InGroup()
    return Plain(Call(IsInGroup)) == true
end

-- An aura of the set on unit, or nil. `remaining` is plain when known.
local function FindAura(unit, ids)
    if not C_UnitAuras then return nil end
    for _, id in ipairs(ids) do
        local aura
        if unit == "player" then aura = Call(C_UnitAuras.GetPlayerAuraBySpellID, id)
        else aura = Call(C_UnitAuras.GetUnitAuraBySpellID, unit, id) end
        if type(aura) == "table" then return aura end
    end
    return nil
end

-- Missing, or running out within the lapse window.
local function Lapsing(unit, ids)
    local aura = FindAura(unit, ids)
    if not aura then return true end
    local expires = Plain(aura.expirationTime)
    if type(expires) ~= "number" or expires == 0 then return false end
    local window = InGroup() and Precombat.LAPSE_GROUP or Precombat.LAPSE_SOLO
    return expires - GetTime() <= window
end

local function Usable(spellID)
    local id = ns.Ranks.Pressed(spellID)
    if not id or ns.State.Usable(id) == false or ns.State.OnCooldown(id) == true then return nil end
    return id
end

local function SpellEntry(id, reason)
    return {kind = ns.ENTRY.SPELL, id = id, reason = reason}
end

local function ItemEntry(itemID, reason)
    return {kind = ns.ENTRY.ITEM, id = -itemID, item = itemID, reason = reason}
end

-- Class buffs ---------------------------------------------------------------
local function PartyMissing(group, castID)
    for i = 1, 4 do
        local unit = "party" .. i
        if Plain(Call(UnitExists, unit)) == true and Plain(Call(UnitIsDeadOrGhost, unit)) ~= true
            and Plain(Call(UnitIsConnected, unit)) ~= false
            and Plain(Call(C_Spell and C_Spell.IsSpellInRange, castID, unit)) == true
            and not FindAura(unit, group.auraIDs) then
            return true
        end
    end
    return false
end

local function ClassBuffs(class, add)
    if not ns.Settings.Feature("classBuffs") then return end
    for _, group in ipairs(ns.Data.Defaults.maintainedBuffs[class] or {}) do
        -- The member that is active (any rank), else the default one.
        local member
        for _, id in ipairs(group.group or {}) do
            if FindAura("player", ns.Ranks.Chain(id) or {id}) then member = id end
        end
        local castID = Usable(member or group.default)
        if castID and (Lapsing("player", group.auraIDs) or (group.raidWide and PartyMissing(group, castID))) then
            add(SpellEntry(castID, "buff"))
        end
    end
end

-- Consumables -----------------------------------------------------------------
local function Count(itemID) return ns.Defensives.ItemCount(itemID) end

local function WeaponFits(entry)
    if not entry.wmask then return true end
    local weapon = Plain(Call(GetInventoryItemID, "player", 16))
    if type(weapon) ~= "number" then return false end
    local _, _, _, _, _, classID, subclassID = Call(C_Item and C_Item.GetItemInfoInstant, weapon)
    if Plain(classID) ~= 2 or type(Plain(subclassID)) ~= "number" then return false end
    return math.floor(entry.wmask / 2 ^ subclassID) % 2 == 1
end

-- Main-hand enhancement of the kind (imbue or temporary enchant). Forever
-- tells them apart (C_Item.GetWeaponEnchantInfo, as JustAC reads it); other
-- clients only say whether the main hand has a temporary enchant.
local MAIN_HAND = 0
local function MainHandEnhanced(imbue)
    if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.ItemEnchantType then
        local enchants = Call(C_Item.GetWeaponEnchantInfo, MAIN_HAND)
        if type(enchants) ~= "table" then return nil end
        local wanted = imbue and Enum.ItemEnchantType.Imbue or Enum.ItemEnchantType.Temporary
        for _, enchant in pairs(enchants) do
            if Plain(enchant.hasEnchant) == true and Plain(enchant.enchantType) == wanted then return true end
        end
        return false
    end
    local has = Plain(Call(GetWeaponEnchantInfo))
    if has == nil then return nil end
    return has == true
end

local function Consumables(class, add)
    local stats = CLASS_STATS[class] -- druids use every stat: no filter
    for _, category in ipairs(CATEGORIES) do
        local list = ns.Data.Consumables.precombat[category]
        if ns.Settings.Feature(category) and list then
            if category == "weaponEnchant" then
                local imbue
                for _, id in ipairs(ns.Data.Defaults.weaponImbues) do imbue = imbue or Usable(id) end
                if imbue then
                    if MainHandEnhanced(true) == false then add(SpellEntry(imbue, category)) end
                elseif MainHandEnhanced(false) == false then
                    for _, entry in ipairs(list) do
                        if (not stats or stats[entry.stat]) and Count(entry.id) > 0 and WeaponFits(entry) then
                            add(ItemEntry(entry.id, category))
                            break
                        end
                    end
                end
            else
                local buffs = {}
                for i, entry in ipairs(list) do buffs[i] = entry.buff end
                if not FindAura("player", buffs) then
                    for _, entry in ipairs(list) do
                        if (not stats or stats[entry.stat]) and Count(entry.id) > 0 then
                            add(ItemEntry(entry.id, category))
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Recovery ----------------------------------------------------------------------
local function BestRecovery(kind)
    local level = Plain(Call(UnitLevel, "player")) or 0
    local fallback
    for _, entry in ipairs(ns.Data.Consumables.recovery[kind] or {}) do
        if (entry.level or 0) <= level and Count(entry.id) > 0
            and Plain(Call(C_Item and C_Item.IsUsableItem, entry.id)) ~= false then
            if not entry.wellfed then return entry.id end
            fallback = fallback or entry.id
        end
    end
    return fallback
end

local function Recovery(class, add)
    if not ns.Settings.Feature("recovery") then return end
    if FindAura("player", ns.Data.Consumables.eatingAuras) then return end
    if class ~= "WARRIOR" and class ~= "ROGUE" and ns.State.PowerBelow("player", Precombat.DRINK_BELOW, MANA) == true then
        local drink = BestRecovery("drink")
        if drink then add(ItemEntry(drink, "drink")) end
    end
    if ns.State.HealthBelow("player", Precombat.FOOD_BELOW) == true then
        local food = BestRecovery("food")
        if food then
            add(ItemEntry(food, "food"))
        elseif not FindAura("player", {RECENTLY_BANDAGED}) then
            local bandage = BestRecovery("bandage")
            if bandage then add(ItemEntry(bandage, "bandage")) end
        end
    end
end

local function Stealth(class, add)
    if not ns.Settings.Feature("stealthReminder") or not STEALTH[class] then return end
    if class == "DRUID" and ns.Trees.Pick(class) ~= "feral" then return end
    if ns.State.Stealthed() == false then
        local id = Usable(STEALTH[class])
        if id then add(SpellEntry(id, "stealth")) end
    end
end

local function TopOff(class, add)
    local below = ns.Settings.Feature("topoffHeal") and ns.Settings.Feature("topoffBelow") or Precombat.TOPOFF_ALWAYS_BELOW
    if ns.State.HealthBelow("player", below) ~= true then return end
    for _, first in ipairs(ns.Data.Defaults.topoffHeals[class] or {}) do
        local id = Usable(first)
        if id then return add(SpellEntry(id, "heal")) end
    end
end

-- Entries, or an empty list in combat and while mounted, dead or casting.
function Precombat.Suggest()
    local entries = {}
    if not ns.Settings.Feature("precombat") or ns.InCombat() then return entries end
    if Plain(Call(IsMounted)) == true or Plain(Call(UnitIsDeadOrGhost, "player")) == true then return entries end
    local class = ns.Trees.Class()
    if not class then return entries end
    local seen = {}
    local function add(entry)
        if #entries < Precombat.MAX_ENTRIES and not seen[entry.id] then
            seen[entry.id] = true
            entries[#entries + 1] = entry
        end
    end
    ClassBuffs(class, add)
    Consumables(class, add)
    Stealth(class, add)
    TopOff(class, add)
    Recovery(class, add)
    return entries
end

-- Is this spell (any rank) offered right now (so the queue need not show it).
local offered = {}
function Precombat.SetOffered(entries)
    wipe(offered)
    for _, entry in ipairs(entries) do
        if entry.kind == ns.ENTRY.SPELL then offered[ns.Ranks.Base(entry.id)] = true end
    end
end
function Precombat.Offered(spellID) return offered[ns.Ranks.Base(spellID)] == true end
