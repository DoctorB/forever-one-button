-- Forever One Button: options window.
--
-- Exposes exactly the whitelist in docs/BINDINGS_AND_OPTIONS.md: grid layout,
-- pixel position/visibility, the cell -> action -> key associations and the
-- engine features (burst cue, interrupts, defensives, reminders).
-- Uses only templates verified on Forever 1.60.1.70374
-- (BasicFrameTemplateWithInset, UIPanelButtonTemplate, UICheckButtonTemplate).
-- Closed on entering combat; refuses to open in combat.
local ADDON_NAME, ns = ...

local Options = {}
ns.Options = Options

local LABELS = {
    slots = "Cells",
    columns = "Columns",
    cellSize = "Cell size",
    spacing = "Spacing",
    scale = "Scale",
    queueDepth = "Queue positions shown",
}
Options.NUMERIC_ORDER = {"slots", "columns", "cellSize", "spacing", "scale", "queueDepth"}

local frame, pages, captureFrame
local refreshers = {}

local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 20)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Report(ok, message)
    if message then ns.Print(message) elseif not ok then ns.Print("change refused") end
    Options.Refresh()
end

local function BuildLayoutPage(page)
    local y = -8
    for _, name in ipairs(Options.NUMERIC_ORDER) do
        local limits = ns.Settings.GRID_LIMITS[name]
        local step = name == "scale" and 0.05 or 1
        local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 12, y - 3)
        label:SetText(LABELS[name])
        local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", 230, y - 3)
        value:SetWidth(50)
        local function Change(delta)
            local current = ns.Settings.Get().grid[name]
            Report(ns.Settings.SetGridValue(name, current + delta))
        end
        Button(page, "-", 24, function() Change(-step) end):SetPoint("TOPLEFT", 200, y)
        Button(page, "+", 24, function() Change(step) end):SetPoint("TOPLEFT", 284, y)
        local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", 316, y - 4)
        hint:SetText(string.format("%s-%s", tostring(limits.min), tostring(limits.max)))
        refreshers[#refreshers + 1] = function()
            local v = ns.Settings.Get().grid[name]
            value:SetText(name == "scale" and string.format("%.2f", v) or tostring(v))
        end
        y = y - 26
    end

    local function Check(text, get, set)
        local c = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        c:SetPoint("TOPLEFT", 8, y)
        local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", c, "RIGHT", 4, 0)
        label:SetText(text)
        c:SetScript("OnClick", function(self) Report(set(self:GetChecked() and true or false)) end)
        refreshers[#refreshers + 1] = function() c:SetChecked(get()) end
        y = y - 28
    end
    Check("Show grid", function() return ns.Settings.Get().grid.shown end, ns.Grid.SetShown)
    Check("Lock grid position", function() return ns.Settings.Get().grid.locked end, ns.Grid.SetLocked)
    Check("Show diagnostic pixel", function() return ns.Settings.Get().pixel.enabled end,
        function(v) ns.Pixel.SetEnabled(v); return true end)
    Check("Lock pixel position", function() return ns.Settings.Get().pixel.locked end,
        function(v) ns.Pixel.SetLocked(v); return true end)
    Check("Pixel only in combat (black out of combat)", function() return ns.Settings.Get().pixel.combatOnly end,
        function(v) ns.Pixel.SetCombatOnly(v); return true end)
    Check("Hide Blizzard's bottom bar (keys keep working; stance and XP bars stay)",
        function() return ns.Settings.Get().hideBlizzardBar end,
        function(v) return ns.BlizzardBar.SetHidden(v) end)
    Check("Fill cells automatically from the priority list", function() return ns.Settings.Get().autoFill end,
        function(v) ns.AutoFill.SetEnabled(v); return true end)

    Button(page, "Reset grid layout", 150, function() Report(ns.Settings.ResetLayout()) end)
        :SetPoint("TOPLEFT", 12, y - 6)
    Button(page, "Reset pixel position", 150, function() ns.Pixel.ResetPosition(); Report(true) end)
        :SetPoint("TOPLEFT", 172, y - 6)
end

-- Engine features, in display order: {setting, label}. Booleans are check
-- boxes, enums cycle through their values, numbers have -/+ buttons.
Options.FEATURE_ORDER = {
    {"burstCue", "Burst cue: a ready cooldown moves to position 2 (purple)"},
    {"interrupts", "Interrupt icon when the target casts (red \"!\" on its cell)"},
    {"interruptMode", "Interrupts: kickOnly, kickPrefer (CC on shielded casts), ccPrefer"},
    {"interruptFears", "Interrupts may use fears"},
    {"defensives", "Defensive column right of the grid (orange \"D\" on its cell)"},
    {"holdEmergencies", "Hold immunities and big heals until health is low"},
    {"healingItems", "Best healing potion or healthstone in the column"},
    {"petCues", "Pet heal, revive and summon"},
    {"petHealBelow", "Pet heal below health %"},
    {"groupHeals", "Group heals when allies are low"},
    {"ccBreak", "Escape from loss of control"},
}
local ENUM_ORDER = {interruptMode = {"kickOnly", "kickPrefer", "ccPrefer"}}

local function BuildFeaturesPage(page)
    local y = -8
    for _, row in ipairs(Options.FEATURE_ORDER) do
        local name, text = row[1], row[2]
        local spec = ns.Settings.FEATURES[name]
        if spec.kind == "boolean" then
            local c = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
            c:SetPoint("TOPLEFT", 8, y)
            local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT", c, "RIGHT", 4, 0)
            label:SetText(text)
            c:SetScript("OnClick", function(self) Report(ns.Settings.SetFeature(name, self:GetChecked() and true or false)) end)
            refreshers[#refreshers + 1] = function() c:SetChecked(ns.Settings.Feature(name)) end
            y = y - 28
        else
            local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOPLEFT", 12, y - 3)
            label:SetText(text)
            local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            value:SetPoint("TOPLEFT", 400, y - 3)
            if spec.kind == "enum" then
                Button(page, ">", 24, function()
                    local order = ENUM_ORDER[name]
                    local current = ns.Settings.Feature(name)
                    for i, v in ipairs(order) do
                        if v == current then return Report(ns.Settings.SetFeature(name, order[i % #order + 1])) end
                    end
                end):SetPoint("TOPLEFT", 370, y)
            else
                Button(page, "-", 24, function() Report(ns.Settings.SetFeature(name, ns.Settings.Feature(name) - 5)) end)
                    :SetPoint("TOPLEFT", 340, y)
                Button(page, "+", 24, function() Report(ns.Settings.SetFeature(name, ns.Settings.Feature(name) + 5)) end)
                    :SetPoint("TOPLEFT", 370, y)
            end
            refreshers[#refreshers + 1] = function() value:SetText(tostring(ns.Settings.Feature(name))) end
            y = y - 26
        end
    end
end

local function ActionLabel(cell)
    if not cell then return "|cff808080(empty - drag a spell/item onto the cell)|r" end
    if cell.kind == "spell" then
        return (ns.SpellName(cell.id) or "Spell") .. " (" .. cell.id .. ")" .. (cell.auto and " |cff80c0ffauto|r" or "")
    end
    return (ns.ItemName(cell.id) or "Item") .. " (item " .. cell.id .. ")"
end

local function StartCapture(slot)
    if ns.InCombat() then return Report(false, "changes to cells and keys are blocked in combat") end
    captureFrame.slot = slot
    captureFrame.text:SetText(string.format("Press a key for cell %d\n(Esc cancels)", slot))
    captureFrame:Show()
end

local function BuildCellsPage(page)
    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 12, -6)
    header:SetText("Cell   Action                                     Key")
    for slot = 1, ns.MAX_SLOTS do
        local y = -22 - (slot - 1) * 21
        local num = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        num:SetPoint("TOPLEFT", 14, y - 4)
        num:SetText(string.format("%02d", slot))
        local action = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        action:SetPoint("TOPLEFT", 40, y - 4)
        action:SetWidth(190)
        action:SetJustifyH("LEFT")
        action:SetWordWrap(false)
        local key = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        key:SetPoint("TOPLEFT", 234, y - 4)
        key:SetWidth(90)
        key:SetJustifyH("LEFT")
        Button(page, "Bind", 44, function() StartCapture(slot) end):SetPoint("TOPLEFT", 326, y)
        Button(page, "Unbind", 54, function() Report(ns.Actions.Unbind(slot)) end):SetPoint("TOPLEFT", 372, y)
        Button(page, "Default", 56, function() Report(ns.Actions.DefaultKey(slot)) end):SetPoint("TOPLEFT", 428, y)
        Button(page, "Clear", 44, function() Report(ns.Actions.Clear(slot)) end):SetPoint("TOPLEFT", 486, y)
        refreshers[#refreshers + 1] = function()
            local settings = ns.Settings.Get()
            local cell, bound = ns.Settings.Char().cells[slot], ns.Settings.KeyFor(slot)
            local hidden = slot > settings.grid.slots
            action:SetText(ActionLabel(cell) .. (hidden and " |cffff8040[hidden]|r" or ""))
            if bound then
                local shadowed = ns.Actions.ExternalBinding(bound)
                local isDefault = settings.keys[slot] == nil
                key:SetText(bound .. (isDefault and " |cff808080d|r" or "") .. (shadowed and " |cffff8040!|r" or ""))
            else
                key:SetText(cell and "|cffff4040none|r" or "")
            end
        end
    end
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 12, -22 - ns.MAX_SLOTS * 21 - 4)
    note:SetWidth(530)
    note:SetJustifyH("LEFT")
    note:SetText("d = default key.  ! = this key also has a normal WoW binding; the cell overrides it while the addon is loaded. Clear removes a spell from the automatic fill.")
end

local function BuildCapture()
    captureFrame = CreateFrame("Frame", "ForeverOneButtonKeyCapture", frame)
    captureFrame:SetAllPoints(frame)
    captureFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
    captureFrame:EnableMouse(true)
    captureFrame:EnableKeyboard(true)
    if captureFrame.SetPropagateKeyboardInput then captureFrame:SetPropagateKeyboardInput(false) end
    local shade = captureFrame:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.85)
    captureFrame.text = captureFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    captureFrame.text:SetPoint("CENTER")
    local MODIFIERS = {LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true}
    local function Finish(key)
        local slot = captureFrame.slot
        captureFrame:Hide()
        if not key then return end
        local parts = {}
        if IsControlKeyDown and IsControlKeyDown() then parts[#parts + 1] = "CTRL" end
        if IsAltKeyDown and IsAltKeyDown() then parts[#parts + 1] = "ALT" end
        if IsShiftKeyDown and IsShiftKeyDown() then parts[#parts + 1] = "SHIFT" end
        parts[#parts + 1] = key
        Report(ns.Actions.Bind(slot, table.concat(parts, "-")))
    end
    captureFrame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then return Finish(nil) end
        if MODIFIERS[key] then return end
        Finish(key)
    end)
    local MOUSE = {MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5"}
    captureFrame:SetScript("OnMouseDown", function(_, button)
        if MOUSE[button] then Finish(MOUSE[button]) end
    end)
    captureFrame:EnableMouseWheel(true)
    captureFrame:SetScript("OnMouseWheel", function(_, delta)
        Finish(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)
    captureFrame:Hide()
end

local function Build()
    frame = CreateFrame("Frame", "ForeverOneButtonOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(560, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverOneButtonOptions") end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(ns.TITLE .. " " .. ns.VERSION)

    pages = {}
    for index, name in ipairs({"Layout & pixel", "Cells & keys", "Features"}) do
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 4, -58)
        page:SetPoint("BOTTOMRIGHT", -4, 4)
        page:Hide()
        pages[index] = page
        Button(frame, name, 140, function() Options.ShowPage(index) end)
            :SetPoint("TOPLEFT", 12 + (index - 1) * 146, -30)
    end
    BuildLayoutPage(pages[1])
    BuildCellsPage(pages[2])
    BuildFeaturesPage(pages[3])
    BuildCapture()
    Options.ShowPage(1)
end

function Options.ShowPage(index)
    for i, page in ipairs(pages) do
        if i == index then page:Show() else page:Hide() end
    end
end

function Options.Refresh()
    if not frame or not frame:IsShown() then return end
    for _, refresh in ipairs(refreshers) do refresh() end
end

function Options.Open(page)
    if ns.InCombat() then
        ns.Print("options cannot be opened in combat")
        return false
    end
    if not frame then Build() end
    frame:Show()
    if page then Options.ShowPage(page) end
    Options.Refresh()
    return true
end

function Options.CloseForCombat()
    if captureFrame then captureFrame:Hide() end
    if frame and frame:IsShown() then frame:Hide() end
end

function Options.IsShown()
    return frame ~= nil and frame:IsShown()
end
