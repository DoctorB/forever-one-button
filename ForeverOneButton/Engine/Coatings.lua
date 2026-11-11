-- Forever One Button: the next weapon coating to apply, out of combat.
--
-- Forever reports two enhancements per weapon (C_Item.GetWeaponEnchantInfo):
-- an imbue (rogue poison, shaman imbue) and a temporary enchant (stone, oil),
-- and the two coexist. Each weapon hand is a task per kind:
--   * rogues: a poison on each hand (settings poisonMainHand / poisonOffHand,
--     default Instant on the main hand, Deadly on the off hand), then stones;
--   * shamans: the weapon imbue spell on the main hand (no stones or oils
--     once an imbue is known);
--   * every other class: a stone or oil on each hand holding a weapon.
-- A task is due when its enhancement is missing, lapsing (the reminder
-- window) or down to its last charges. Next() returns the most urgent one:
-- missing first, in task order, then the shortest time left. The player
-- applies it with one press (Panel/Reminders.lua); one press, one coating.
--
-- Other clients only say whether each hand has a temporary enchant: there
-- the main hand gets one task (poison for rogues, imbue for shamans, else
-- a stone or oil), as before.
local ADDON_NAME, ns = ...

local Coatings = {}
ns.Coatings = Coatings

Coatings.MAIN_HAND, Coatings.OFF_HAND = 16, 17
Coatings.LOW_CHARGES = 10
-- After a coating's item is used, its weapon waits this long for the client
-- to report the new enhancement before it can be offered again.
Coatings.RECENT_SECONDS = 5

-- Rogue poisons by family, highest rank first (item IDs).
Coatings.POISONS = {
    instant = {8928, 8927, 8926, 6950, 6949, 6947},
    deadly = {20844, 8985, 8984, 2893, 2892},
    crippling = {3776, 3775},
    mindNumbing = {9186, 6951, 5237},
    wound = {10922, 10921, 10920, 10918},
}
Coatings.POISON_CHOICES = {"instant", "deadly", "crippling", "mindNumbing", "wound", "off"}
-- When the chosen poison is not in the bags, the other common one.
local POISON_FALLBACK = {"instant", "deadly"}

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

local function Count(itemID) return ns.Defensives.ItemCount(itemID) end
local function Owned(itemID)
    return Count(itemID) > 0 and Plain(Call(C_Item and C_Item.IsUsableItem, itemID)) ~= false
end

-- Weapon class and subclass in the slot, or nil when it holds no weapon.
local function WeaponSubclass(slot)
    local weapon = Plain(Call(GetInventoryItemID, "player", slot))
    if type(weapon) ~= "number" then return nil end
    local _, _, _, _, _, classID, subclassID = Call(C_Item and C_Item.GetItemInfoInstant, weapon)
    if Plain(classID) ~= 2 or type(Plain(subclassID)) ~= "number" then return nil end
    return subclassID
end

local function Fits(entry, subclass)
    if not entry.wmask then return true end
    return math.floor(entry.wmask / 2 ^ subclass) % 2 == 1
end

-- Enhancements on a hand: {imbue = info|false, temporary = info|false},
-- info = {left = seconds|nil, charges = n|nil}; nil when unreadable.
-- `typed` is false on clients that do not tell the two kinds apart.
local function Enhancements(slot)
    if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.ItemEnchantType then
        local records = Call(C_Item.GetWeaponEnchantInfo, slot == Coatings.MAIN_HAND and 0 or 1)
        if type(records) ~= "table" then return nil end
        local out = {imbue = false, temporary = false, typed = true}
        for _, e in pairs(records) do
            if type(e) == "table" and Plain(e.hasEnchant) == true then
                local kind = Plain(e.enchantType)
                local info = {charges = Plain(e.charges)}
                local left = Plain(e.timeLeft) -- milliseconds, as the legacy API
                if type(left) == "number" and left > 0 then info.left = left / 1000 end
                if kind == Enum.ItemEnchantType.Imbue then out.imbue = info
                elseif kind == Enum.ItemEnchantType.Temporary then out.temporary = info end
            end
        end
        return out
    end
    local hasMain, mainLeft, mainCharges, _, hasOff, offLeft, offCharges = Call(GetWeaponEnchantInfo)
    local has, left, charges = hasMain, mainLeft, mainCharges
    if slot == Coatings.OFF_HAND then has, left, charges = hasOff, offLeft, offCharges end
    has = Plain(has)
    if has == nil then return nil end
    local info = has and {charges = Plain(charges)} or false
    if info and type(Plain(left)) == "number" and left > 0 then info.left = left / 1000 end
    return {imbue = info, temporary = info, typed = false}
end

-- Missing (returns -1), lapsing or low on charges (time left), else nil.
local function Due(info, lapse)
    if not info then return -1 end
    local left = info.left
    if left and left <= lapse then return left end
    if type(info.charges) == "number" and info.charges > 0 and info.charges < Coatings.LOW_CHARGES then
        return left or 0
    end
    return nil
end

local function PoisonFor(choice)
    if choice == "off" then return nil end
    local families, seen = {choice}, {[choice] = true}
    for _, family in ipairs(POISON_FALLBACK) do
        if not seen[family] then families[#families + 1] = family; seen[family] = true end
    end
    for _, family in ipairs(families) do
        for _, id in ipairs(Coatings.POISONS[family] or {}) do
            if Owned(id) then return id end
        end
    end
    return nil
end

-- Best stone or oil the class uses for the weapon (consumables data order).
local function StoneFor(subclass, stats)
    for _, entry in ipairs(ns.Data.Consumables.precombat.weaponEnchant or {}) do
        if (not stats or stats[entry.stat]) and Fits(entry, subclass) and Owned(entry.id) then return entry.id end
    end
    return nil
end

local recent = {}   -- task key -> time until which it is not offered
local offered       -- the last task offered: {key, item, count}

local function Casting()
    return Plain(Call(UnitCastingInfo, "player")) ~= nil or Plain(Call(UnitChannelInfo, "player")) ~= nil
end

-- The next coating: {slot, item} or {spell}, with `hand` ("main"/"off") and
-- `kind` ("imbue"/"temporary"), or nil. `stats` filters stones and oils by
-- the stats the class uses (nil: every stat); `lapse` is the reminder window
-- in seconds; `imbueSpell` is the shaman's usable imbue, if any.
function Coatings.Next(class, stats, lapse, imbueSpell)
    local now = GetTime()
    -- The coating offered last time was used (its item count dropped): its
    -- weapon is skipped until the client reports the new enhancement.
    if offered and offered.item and Count(offered.item) < offered.count then
        recent[offered.key] = now + Coatings.RECENT_SECONDS
    end
    offered = nil
    if Casting() then return nil end

    local tasks = {}
    local hands = {Coatings.MAIN_HAND, Coatings.OFF_HAND}
    local state = {}
    for _, slot in ipairs(hands) do
        local subclass = WeaponSubclass(slot)
        if subclass then state[slot] = {subclass = subclass, enhancements = Enhancements(slot)} end
    end
    local main = state[Coatings.MAIN_HAND]
    local typed = main and main.enhancements and main.enhancements.typed

    local function Add(slot, kind, pick)
        local s = state[slot]
        if not s or not s.enhancements then return end
        tasks[#tasks + 1] = {slot = slot, kind = kind, info = s.enhancements[kind], pick = pick, subclass = s.subclass}
    end
    if class == "ROGUE" then
        local mainChoice, offChoice = ns.Settings.Feature("poisonMainHand"), ns.Settings.Feature("poisonOffHand")
        Add(Coatings.MAIN_HAND, "imbue", function() return {item = PoisonFor(mainChoice)} end)
        if typed then
            Add(Coatings.OFF_HAND, "imbue", function() return {item = PoisonFor(offChoice)} end)
        end
    elseif class == "SHAMAN" and imbueSpell then
        Add(Coatings.MAIN_HAND, "imbue", function() return {spell = imbueSpell} end)
    end
    if (class ~= "SHAMAN" or not imbueSpell) and (typed or #tasks == 0) then
        local slots = typed and hands or {Coatings.MAIN_HAND}
        for _, slot in ipairs(slots) do
            Add(slot, "temporary", function(subclass) return {item = StoneFor(subclass, stats)} end)
        end
    end

    local best, bestLeft
    for _, task in ipairs(tasks) do
        local key = task.slot .. ":" .. task.kind
        local left = Due(task.info, lapse)
        if left and not ((recent[key] or 0) > now) and (not best or left < bestLeft) then
            local action = task.pick(task.subclass)
            if action.item or action.spell then
                action.slot = action.item and task.slot or nil
                action.hand = task.slot == Coatings.MAIN_HAND and "main" or "off"
                action.kind = task.kind
                action.key = key
                best, bestLeft = action, left
            end
        end
    end
    if best and best.item then offered = {key = best.key, item = best.item, count = Count(best.item)} end
    return best
end

function Coatings.Reset()
    recent, offered = {}, nil
end
