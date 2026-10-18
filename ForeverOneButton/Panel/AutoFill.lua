-- Forever One Button: automatic, stable cell filling (owner decision, 2026-10-15).
--
-- Source: the abilities the engine can suggest for this character, in a
-- fixed order: the active tree's priority list (single target, cleave, aoe),
-- then the class's gap closers, interrupts and defensives. Known spells only,
-- at the rank the character presses (Engine/Ranks.lua).
--
-- Rules:
--   * a pool spell not on the grid takes the first free cell, in pool order,
--     and keeps that cell: nothing is ever moved;
--   * a new rank of a spell replaces the old rank in the SAME cell, in every
--     cell, also the user's and also with the automatic fill off;
--   * a spell the user removed from a cell is never put back automatically;
--   * cells the user filled are never touched, except for the rank;
--   * out of combat only; requests in combat run when combat ends.
-- This never looks at the current queue: what is suggested at a given moment
-- has no influence on which cell a spell gets.
local ADDON_NAME, ns = ...

local AutoFill = {}
ns.AutoFill = AutoFill

AutoFill.DELAY_SECONDS = 0.5 -- coalesces SPELLS_CHANGED / ACTIONBAR_SLOT_CHANGED bursts
AutoFill.pending = false
AutoFill.status = "not run"
AutoFill.overflow = 0

local scheduled = false
local CONTEXTS = {"st", "cleave", "aoe"}

-- Interrupt spells of the data this character knows, best first (lockout
-- kicks before crowd control, then the data's tiebreaker).
local function KnownInterrupts()
    local out = {}
    for id, info in pairs(ns.Data.Interrupts.abilities) do
        if info.kind == "interrupt" and ns.Ranks.HighestKnown(id) then out[#out + 1] = {id = id, pri = info.pri or 9} end
    end
    table.sort(out, function(a, b)
        if a.pri ~= b.pri then return a.pri < b.pri end
        return a.id < b.id
    end)
    for i, item in ipairs(out) do out[i] = item.id end
    return out
end

-- Pool: spell IDs at the pressed rank. Returns list or nil, status.
function AutoFill.ReadPool()
    local class = ns.Trees.Class()
    local trees = class and ns.Data.Rotations.classes[class]
    if not trees then return nil, "no priority list for this class" end
    local out, seen = {}, {}
    local function Add(first)
        first = ns.Ranks.Base(first)
        if seen[first] then return end
        seen[first] = true
        local id = ns.Ranks.Pressed(first)
        if id then out[#out + 1] = id end
    end
    local roles = ns.Data.Defaults.abilityRoles
    local contexts = ns.Trees.Contexts(class, ns.Trees.Pick(class)) or {}
    for _, key in ipairs(CONTEXTS) do
        for _, listed in ipairs(contexts[key] or {}) do
            local entry = ns.Queue.HomeStance(listed)
            local role = roles[entry.id]
            if role == nil or role == "mixed" then Add(entry.id) end
        end
    end
    for _, id in ipairs(ns.Data.Defaults.gapClosers[class] or {}) do Add(id) end
    for _, id in ipairs(KnownInterrupts()) do Add(id) end
    for _, id in ipairs(ns.Data.Defaults.defensive[class] or {}) do Add(id) end
    return out, "ok"
end

local function Override(spellID)
    if not C_Spell or not C_Spell.GetOverrideSpell then return nil end
    return ns.SafeCall(C_Spell.GetOverrideSpell, spellID)
end

-- Cell already holding this spell: same ID, override in either direction, or
-- another rank (same name). Returns slot, sameRank.
local function FindCell(cells, spellID, name)
    for slot = 1, ns.MAX_SLOTS do
        local cell = cells[slot]
        if cell and cell.kind == "spell" then
            if cell.id == spellID or Override(cell.id) == spellID or Override(spellID) == cell.id then
                return slot, true
            end
        end
    end
    if name then
        for slot = 1, ns.MAX_SLOTS do
            local cell = cells[slot]
            if cell and cell.kind == "spell" and ns.SpellName(cell.id) == name then return slot, false end
        end
    end
    return nil
end

local function FirstFreeCell(cells)
    for slot = 1, ns.MAX_SLOTS do
        if not cells[slot] then return slot end
    end
    return nil
end

-- One automatic item cell for the best healing item owned; a better one
-- replaces it in the same cell, and with none left the cell is emptied
-- (not dismissed: the next healing item comes back). A healing item the
-- user placed is left alone.
local function PlaceHealingItem(cells, dismissed)
    if not ns.Settings.Feature("healingItems") or dismissed[ns.Actions.HEALING_ITEM_KEY] then return false end
    local best = ns.Defensives.BestHealingItem()
    local healing = {}
    for _, id in ipairs(ns.Data.Consumables.healingItems) do healing[id] = true end
    for slot = 1, ns.MAX_SLOTS do
        local cell = cells[slot]
        if cell and cell.kind == "item" and healing[cell.id] then
            if not cell.auto or cell.id == best then return false end
            if best then ns.Actions.SetAutoItem(slot, best) else ns.Actions.RemoveAuto(slot) end
            return true
        end
    end
    if not best then return false end
    local slot = FirstFreeCell(cells)
    if not slot then return false end
    ns.Actions.SetAutoItem(slot, best)
    return true
end

-- Every spell cell, automatic or the user's, moves to the highest rank known
-- in the same cell, also with the automatic fill off.
local function UpgradeRanks(cells)
    local changed = false
    for slot = 1, ns.MAX_SLOTS do
        local cell = cells[slot]
        local higher = cell and cell.kind == "spell" and ns.Ranks.Higher(cell.id)
        if higher then
            cell.id = higher
            changed = true
        end
    end
    return changed
end

function AutoFill.Run()
    if ns.InCombat() then
        AutoFill.pending = true
        return false
    end
    AutoFill.pending = false
    local char = ns.Settings.Char()
    local cells, dismissed = char.cells, char.dismissed
    local upgraded = UpgradeRanks(cells)
    if not ns.Settings.Get().autoFill then
        AutoFill.status = "off"
        if upgraded then ns.Actions.Apply() end
        return upgraded
    end
    local pool, status = AutoFill.ReadPool()
    AutoFill.status = status
    if not pool then
        if upgraded then ns.Actions.Apply() end
        return upgraded
    end

    local changed, overflow = upgraded, 0
    for _, spellID in ipairs(pool) do
        local name = ns.SpellName(spellID)
        if not dismissed[name or ("spell:" .. spellID)] then
            local slot, sameRank = FindCell(cells, spellID, name)
            if slot then
                if not sameRank and cells[slot].auto then
                    ns.Actions.SetAuto(slot, spellID) -- new rank, same cell
                    changed = true
                end
            else
                slot = FirstFreeCell(cells)
                if slot then
                    ns.Actions.SetAuto(slot, spellID)
                    changed = true
                else
                    overflow = overflow + 1
                end
            end
        end
    end
    if PlaceHealingItem(cells, dismissed) then changed = true end
    AutoFill.overflow = overflow
    if changed then ns.Actions.Apply() end
    return changed
end

-- Coalesced request from events.
function AutoFill.Request()
    if scheduled then return end
    if not C_Timer or not C_Timer.After then return AutoFill.Run() end
    scheduled = true
    C_Timer.After(AutoFill.DELAY_SECONDS, function()
        scheduled = false
        AutoFill.Run()
    end)
end

function AutoFill.SetEnabled(enabled)
    ns.Settings.Get().autoFill = enabled and true or false
    if enabled then return AutoFill.Run() end
    AutoFill.status = "off"
    return true
end

-- Forget the spells the user removed, then fill again.
function AutoFill.ResetDismissed()
    if ns.InCombat() then return false, "changes to cells and keys are blocked in combat" end
    wipe(ns.Settings.Char().dismissed)
    AutoFill.Run()
    return true
end
