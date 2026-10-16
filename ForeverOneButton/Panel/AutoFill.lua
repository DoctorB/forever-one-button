-- Forever One Button: automatic, stable cell filling (owner decision, 2026-10-15).
--
-- Source: the set of abilities JustAC can suggest on this character (rotation
-- pool plus gap closers, see AddGapClosers), read
-- once per change from JustAC's public library function
-- LibStub("JustAC-BlizzardAPI").GetRotationSpells() (BlizzardAPI/SpellQuery.lua:326
-- @ 431e9a2). On Forever that is JustAC's pool: the spells on the action bars
-- plus the known abilities of its Forever list, at the rank JustAC presses
-- (ForeverPool, :317). Passive spells are already excluded there.
--
-- Rules:
--   * a pool spell not on the grid takes the first free cell, in pool order,
--     and keeps that cell: nothing is ever moved;
--   * a new rank of a spell (same name) replaces the old rank in the SAME
--     cell, if the cell was filled automatically;
--   * a spell the user removed from a cell is never put back automatically;
--   * cells the user filled are never touched;
--   * out of combat only; requests in combat run when combat ends.
-- This never looks at JustAC's queue: what JustAC suggests at a given moment
-- has no influence on which cell a spell gets.
local ADDON_NAME, ns = ...

local AutoFill = {}
ns.AutoFill = AutoFill

AutoFill.LIBRARY = "JustAC-BlizzardAPI"
AutoFill.VERIFIED_MINOR = 36
AutoFill.MAX_POOL = 80
AutoFill.DELAY_SECONDS = 0.5 -- coalesces SPELLS_CHANGED / ACTIONBAR_SLOT_CHANGED bursts
AutoFill.pending = false
AutoFill.status = "not run"
AutoFill.overflow = 0

local scheduled = false

-- Copy of JustAC's pool: positive integer spell IDs in JustAC's order.
-- Returns list or nil, status.
function AutoFill.ReadPool()
    local stub = LibStub
    if ns.IsSecret(stub) or type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then
        return nil, "JustAC not loaded"
    end
    local ok, lib = pcall(stub.GetLibrary, stub, AutoFill.LIBRARY, true)
    if not ok or type(lib) ~= "table" then return nil, "JustAC not loaded" end
    if type(lib.GetRotationSpells) ~= "function" then return nil, "JustAC pool not available" end
    local okCall, pool = pcall(lib.GetRotationSpells)
    if not okCall then return nil, "JustAC pool error" end
    if ns.IsSecret(pool) or type(pool) ~= "table" then return nil, "JustAC pool empty" end
    local out = {}
    for i = 1, AutoFill.MAX_POOL do
        local id = rawget(pool, i)
        if ns.IsSecret(id) then return nil, "JustAC pool unreadable" end
        if id == nil then break end
        if type(id) == "number" and id > 0 and id == math.floor(id) then out[#out + 1] = id end
    end
    AutoFill.AddGapClosers(stub, lib, out)
    return out, "ok"
end

-- JustAC also suggests gap closers (Charge, Intercept...) from a separate
-- list, injected by its gap-closer stage (SpellQueue._StageGapCloser), not
-- from the rotation pool. They are appended after the pool: the class
-- defaults JustAC uses (JustAC-SpellDB.GetGapCloserDefaults, rank-1 IDs on
-- Forever, Data/ForeverDefaults.lua GAP_CLOSER) resolved to the rank the
-- character knows with JustAC's own BlizzardAPI.ResolveKnownSpellID.
-- Unknown spells resolve to nil and are skipped.
function AutoFill.AddGapClosers(stub, blizzardAPI, out)
    local okDB, spellDB = pcall(stub.GetLibrary, stub, "JustAC-SpellDB", true)
    if not okDB or type(spellDB) ~= "table" or type(spellDB.GetGapCloserDefaults) ~= "function" then return end
    if type(blizzardAPI.ResolveKnownSpellID) ~= "function" then return end
    local ok, defaults = pcall(spellDB.GetGapCloserDefaults)
    if not ok or ns.IsSecret(defaults) or type(defaults) ~= "table" then return end
    local have = {}
    for _, id in ipairs(out) do have[id] = true end
    for i = 1, 20 do
        local raw = rawget(defaults, i)
        if raw == nil or ns.IsSecret(raw) then break end
        if type(raw) == "number" and raw > 0 then
            local okID, id = pcall(blizzardAPI.ResolveKnownSpellID, raw)
            if okID and ns.Readable(id) and type(id) == "number" and id > 0 and not have[id] then
                have[id] = true
                out[#out + 1] = id
            end
        end
    end
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

function AutoFill.Run()
    if not ns.Settings.Get().autoFill then
        AutoFill.status = "off"
        return false
    end
    if ns.InCombat() then
        AutoFill.pending = true
        return false
    end
    AutoFill.pending = false
    local pool, status = AutoFill.ReadPool()
    AutoFill.status = status
    if not pool then return false end

    local char = ns.Settings.Char()
    local cells, dismissed = char.cells, char.dismissed
    local changed, overflow = false, 0
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
