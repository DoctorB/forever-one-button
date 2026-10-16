-- Forever One Button: cell -> action -> key associations.
--
-- Cells are filled by the user (drag and drop, /fob assign) or by AutoFill
-- from the engine's priority list (Panel/AutoFill.lua). Keys are the user's or
-- the fixed default scheme. Nothing here reacts to the queue: a
-- recommendation never assigns, moves or rebinds a cell.
-- Secure attributes and override bindings are protected, so every change is
-- refused in combat; the initial apply after a /reload in combat is deferred
-- to PLAYER_REGEN_ENABLED.
local ADDON_NAME, ns = ...

local Actions = {}
ns.Actions = Actions

-- What the secure buttons actually do right now. The pixel resolves slots
-- from this table, never from the saved settings, so a slot colour always
-- names the action the cell really executes.
Actions.applied = {}
Actions.appliedKeys = {}
Actions.pendingApply = false

local COMBAT_MESSAGE = "changes to cells and keys are blocked in combat"

local function db() return ns.Settings.Get() end
local function cells() return ns.Settings.Char().cells end
local function dismissed() return ns.Settings.Char().dismissed end

local function ValidSlot(slot)
    slot = tonumber(slot)
    if not slot or slot ~= math.floor(slot) or slot < 1 or slot > ns.MAX_SLOTS then return nil end
    return slot
end

function Actions.ButtonName(slot)
    return "ForeverOneButtonCell" .. slot
end

function Actions.SlotUsingAction(kind, id, exceptSlot)
    for slot, cell in pairs(cells()) do
        if slot ~= exceptSlot and cell.kind == kind and cell.id == id then return slot end
    end
    return nil
end

-- Cell whose key the user set explicitly to `key`.
function Actions.SlotUsingKey(key, exceptSlot)
    for slot, bound in pairs(db().keys) do
        if slot ~= exceptSlot and bound == key then return slot end
    end
    return nil
end

-- Name under which a spell removed by the user is remembered; the name
-- covers every rank of the spell.
function Actions.DismissKey(spellID)
    return ns.SpellName(spellID) or ("spell:" .. tostring(spellID))
end

-- Binding currently attached to `key` outside this addon, if any.
function Actions.ExternalBinding(key)
    if type(GetBindingAction) ~= "function" or not key then return nil end
    local action = ns.SafeCall(GetBindingAction, key)
    if type(action) ~= "string" or action == "" then return nil end
    if action:find("ForeverOneButtonCell", 1, true) then return nil end
    return action
end

-- Assign an action to a cell. One cell per action: a duplicate is refused,
-- never moved, so the slot <-> action relation stays unambiguous. A spell
-- replaced here is removed from the automatic fill.
function Actions.Assign(slot, kind, id)
    slot = ValidSlot(slot)
    if not slot then return false, "slot must be 1-" .. ns.MAX_SLOTS end
    if kind ~= "spell" and kind ~= "item" then return false, "kind must be spell or item" end
    id = tonumber(id)
    if not id or id <= 0 or id ~= math.floor(id) then return false, "invalid " .. kind .. " ID" end
    if ns.InCombat() then return false, COMBAT_MESSAGE end
    local other = Actions.SlotUsingAction(kind, id, slot)
    if other then return false, string.format("%s %d is already on cell %d", kind, id, other) end
    local previous = cells()[slot]
    if previous and previous.kind == "spell" then dismissed()[Actions.DismissKey(previous.id)] = true end
    if kind == "spell" then dismissed()[Actions.DismissKey(id)] = nil end
    cells()[slot] = {kind = kind, id = id}
    Actions.Apply()
    return true
end

-- Emptying a cell also removes its spell from the automatic fill, so the
-- next fill does not put it back.
function Actions.Clear(slot)
    slot = ValidSlot(slot)
    if not slot then return false, "slot must be 1-" .. ns.MAX_SLOTS end
    if ns.InCombat() then return false, COMBAT_MESSAGE end
    local cell = cells()[slot]
    if cell and cell.kind == "spell" then dismissed()[Actions.DismissKey(cell.id)] = true end
    if cell and cell.kind == "item" and cell.auto then dismissed()[Actions.HEALING_ITEM_KEY] = true end
    cells()[slot] = nil
    Actions.Apply()
    return true
end

-- AutoFill only, out of combat: a spell placed in a free cell, or the same
-- spell at another rank in its own cell. The caller applies.
function Actions.SetAuto(slot, spellID)
    cells()[slot] = {kind = "spell", id = spellID, auto = true}
end

-- The automatic healing-item cell; clearing it removes it from the fill.
Actions.HEALING_ITEM_KEY = "item:healing"
function Actions.SetAutoItem(slot, itemID)
    cells()[slot] = {kind = "item", id = itemID, auto = true}
end

-- AutoFill only: empties an automatic cell without dismissing its action.
function Actions.RemoveAuto(slot)
    local cell = cells()[slot]
    if cell and cell.auto then cells()[slot] = nil end
end

-- Bind a key to a cell. A key the user already gave another cell is refused;
-- no alternative key or cell is chosen. A cell whose default key is taken
-- loses it (reported). A key bound elsewhere in the client is reported: the
-- override binding takes precedence while the addon runs.
function Actions.Bind(slot, key)
    slot = ValidSlot(slot)
    if not slot then return false, "slot must be 1-" .. ns.MAX_SLOTS end
    key = ns.Keys.Normalize(key)
    if not key then return false, "invalid key" end
    if not ns.Keys.IsAllowed(key) then return false, key .. " cannot be bound to a cell" end
    if ns.InCombat() then return false, COMBAT_MESSAGE end
    local other = Actions.SlotUsingKey(key, slot)
    if other then return false, string.format("%s is already bound to cell %d", key, other) end
    local notes = {}
    for cell = 1, ns.MAX_SLOTS do
        if cell ~= slot and db().keys[cell] == nil and ns.Settings.DEFAULT_KEYS[cell] == key then
            notes[#notes + 1] = string.format("cell %d no longer uses its default key %s", cell, key)
        end
    end
    db().keys[slot] = key
    Actions.Apply()
    local shadowed = Actions.ExternalBinding(key)
    if shadowed then
        notes[#notes + 1] = string.format("%s overrides your binding %q while Forever One Button is loaded", key, shadowed)
    end
    if #notes > 0 then return true, table.concat(notes, "; ") end
    return true
end

-- Remove a cell's key, including its default one.
function Actions.Unbind(slot)
    slot = ValidSlot(slot)
    if not slot then return false, "slot must be 1-" .. ns.MAX_SLOTS end
    if ns.InCombat() then return false, COMBAT_MESSAGE end
    db().keys[slot] = false
    Actions.Apply()
    return true
end

-- Back to the default key scheme for a cell.
function Actions.DefaultKey(slot)
    slot = ValidSlot(slot)
    if not slot then return false, "slot must be 1-" .. ns.MAX_SLOTS end
    if ns.InCombat() then return false, COMBAT_MESSAGE end
    db().keys[slot] = nil
    Actions.Apply()
    if not ns.Settings.KeyFor(slot) then
        return true, string.format("default key %s is used by another cell", ns.Settings.DEFAULT_KEYS[slot])
    end
    return true
end

-- Binding report for the options panel and /fob bindings.
function Actions.Report()
    local rows = {}
    local settings = db()
    for slot = 1, ns.MAX_SLOTS do
        local cell, key = cells()[slot], ns.Settings.KeyFor(slot)
        if cell or type(settings.keys[slot]) == "string" then
            rows[#rows + 1] = {
                slot = slot,
                cell = cell,
                key = key,
                defaultKey = key ~= nil and settings.keys[slot] == nil,
                missingKey = cell ~= nil and key == nil,
                emptyCell = cell == nil and key ~= nil,
                shadowed = key and Actions.ExternalBinding(key) or nil,
                hidden = slot > settings.grid.slots,
            }
        end
    end
    return rows
end

local function ConfigureButton(button, cell)
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("useOnKeyDown", ns.Grid.UseKeyDown())
    -- type1 limits execution to the left button; a right click does nothing.
    if cell and cell.kind == "spell" then
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell", cell.id)
        button:SetAttribute("item", nil)
    elseif cell and cell.kind == "item" then
        button:SetAttribute("type1", "item")
        button:SetAttribute("item", "item:" .. cell.id)
        button:SetAttribute("spell", nil)
    else
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("item", nil)
    end
end

-- Pushes saved cells and keys into the secure buttons and override bindings.
-- Out of combat only. Cells beyond the visible slot count are not executable.
function Actions.Apply()
    if ns.InCombat() then
        Actions.pendingApply = true
        return false
    end
    local grid = ns.Grid
    if not grid or not grid.buttons or not grid.owner then return false end
    local visible = db().grid.slots

    for slot = 1, ns.MAX_SLOTS do
        local cell = slot <= visible and cells()[slot] or nil
        ConfigureButton(grid.buttons[slot], cell)
        Actions.applied[slot] = cell and {kind = cell.kind, id = cell.id} or nil
    end

    ClearOverrideBindings(grid.owner)
    for slot = 1, ns.MAX_SLOTS do
        local key = slot <= visible and Actions.applied[slot] and ns.Settings.KeyFor(slot) or nil
        if key then
            SetOverrideBindingClick(grid.owner, false, key, Actions.ButtonName(slot), "LeftButton")
        end
        Actions.appliedKeys[slot] = key
    end
    Actions.pendingApply = false
    if grid.Refresh then grid.Refresh() end
    return true
end

-- Maps a queue ID to the grid slot that executes the same action.
-- Spells match the assigned ID, or the assigned spell's current override, or
-- else another rank of it (same localized name, as HCOneButton's
-- acknowledgement matches ranks). Items match by item ID (the queue encodes
-- them as -itemID). Returns nil
-- when no cell holds it.
function Actions.SlotFor(queueID)
    if type(queueID) ~= "number" then return nil end
    if queueID < 0 then
        local itemID = -queueID
        for slot = 1, ns.MAX_SLOTS do
            local cell = Actions.applied[slot]
            if cell and cell.kind == "item" and cell.id == itemID then return slot end
        end
        return nil
    end
    for slot = 1, ns.MAX_SLOTS do
        local cell = Actions.applied[slot]
        if cell and cell.kind == "spell" and cell.id == queueID then return slot end
    end
    local getOverride = C_Spell and C_Spell.GetOverrideSpell
    if getOverride then
        for slot = 1, ns.MAX_SLOTS do
            local cell = Actions.applied[slot]
            if cell and cell.kind == "spell" and ns.SafeCall(getOverride, cell.id) == queueID then return slot end
        end
    end
    local name = ns.SpellName(queueID)
    if name then
        for slot = 1, ns.MAX_SLOTS do
            local cell = Actions.applied[slot]
            if cell and cell.kind == "spell" and ns.SpellName(cell.id) == name then return slot end
        end
    end
    return nil
end
