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
    queueDepth = "Numbered moves",
}
local NUMERIC_TIPS = {
    slots = "How many cells the grid shows.",
    columns = "Cells in each row.",
    cellSize = "Edge of each cell.",
    spacing = "Gap between cells.",
    scale = "Size of the whole grid.",
    queueDepth = "How many upcoming moves get a number on their cell.",
}
Options.NUMERIC_ORDER = {"slots", "columns", "cellSize", "spacing", "scale", "queueDepth"}

-- Page geometry: each page sits PAGE_TOP below the window's top and
-- PAGE_INSET inside its other edges; content must end within PAGE_HEIGHT.
local FRAME_SIZE, PAGE_TOP, PAGE_INSET = 560, 58, 4
Options.PAGE_HEIGHT = FRAME_SIZE - PAGE_TOP - PAGE_INSET
Options.PAGE_WIDTH = FRAME_SIZE - 2 * PAGE_INSET
-- Lowest point reached by each page's content, recorded while building.
Options.pageExtents = {}

local frame, pages, tabs, captureFrame
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

-- Tooltip with a title and a wrapped explanation, shown on hover.
local function AddTooltip(widget, title, text)
    if not text then return end
    widget:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
Options.AddTooltip = AddTooltip

-- Gold section title with a thin rule under it; returns the next row's y.
local SECTION_HEIGHT = 24
local function Section(page, text, y)
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, y - 4)
    title:SetText(text)
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.25)
    rule:SetPoint("TOPLEFT", 12, y - 19)
    rule:SetSize(Options.PAGE_WIDTH - 24, 1)
    return y - SECTION_HEIGHT
end

-- Check box whose label is part of the clickable area; `tip` goes in the
-- tooltip. Returns the check box and its label.
local function CheckRow(page, x, y, text, tip, onClick)
    local c = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y)
    local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", c, "RIGHT", 4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    if c.SetHitRectInsets then c:SetHitRectInsets(0, -240, 0, 0) end
    c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    AddTooltip(c, text, tip)
    return c, label
end

local function BuildLayoutPage(page)
    local y = Section(page, "Grid", -2)
    for _, name in ipairs(Options.NUMERIC_ORDER) do
        local limits = ns.Settings.GRID_LIMITS[name]
        local step = name == "scale" and 0.05 or 1
        local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 16, y - 3)
        label:SetText(LABELS[name])
        local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", 228, y - 3)
        value:SetWidth(54)
        value:SetJustifyH("CENTER")
        local function Change(delta)
            local current = ns.Settings.Get().grid[name]
            Report(ns.Settings.SetGridValue(name, current + delta))
        end
        local minus = Button(page, "-", 24, function() Change(-step) end)
        minus:SetPoint("TOPLEFT", 200, y)
        local plus = Button(page, "+", 24, function() Change(step) end)
        plus:SetPoint("TOPLEFT", 286, y)
        AddTooltip(minus, LABELS[name], NUMERIC_TIPS[name])
        AddTooltip(plus, LABELS[name], NUMERIC_TIPS[name])
        local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", 320, y - 4)
        hint:SetText(string.format("%s - %s", tostring(limits.min), tostring(limits.max)))
        refreshers[#refreshers + 1] = function()
            local v = ns.Settings.Get().grid[name]
            value:SetText(name == "scale" and string.format("%.2f", v) or tostring(v))
        end
        y = y - 26
    end

    local function Check(text, tip, get, set)
        local c = CheckRow(page, 12, y, text, tip, function(v) Report(set(v)) end)
        refreshers[#refreshers + 1] = function() c:SetChecked(get()) end
        y = y - 28
    end
    local db = ns.Settings.Get
    Check("Show grid", "Show or hide the whole grid.",
        function() return db().grid.shown end, ns.Grid.SetShown)
    Check("Lock grid position", "Unlock to drag the grid by its title bar (or right-click the title bar).",
        function() return db().grid.locked end, ns.Grid.SetLocked)
    Check("Fill cells automatically", "Moves of your class go into the first free cell. A filled cell never moves.",
        function() return db().autoFill end, function(v) ns.AutoFill.SetEnabled(v); return true end)

    y = Section(page, "Diagnostic pixel", y - 4)
    Check("Show pixel", "The small coloured square that says which cell to press.",
        function() return db().pixel.enabled end, function(v) ns.Pixel.SetEnabled(v); return true end)
    Check("Lock pixel position", "Unlock to drag the square somewhere else.",
        function() return db().pixel.locked end, function(v) ns.Pixel.SetLocked(v); return true end)
    Check("Only in combat", "Out of combat the square stays black.",
        function() return db().pixel.combatOnly end, function(v) ns.Pixel.SetCombatOnly(v); return true end)

    y = Section(page, "Interface", y - 4)
    Check("Hide Blizzard's bottom bar", "Hides the main action bar, the menu and the bag buttons. Their keys keep working; the stance and experience bars stay.",
        function() return db().hideBlizzardBar end, function(v) return ns.BlizzardBar.SetHidden(v) end)
    Check("Show minimap button", "Left-click opens these options, right-click locks or unlocks the grid. Drag it along the minimap edge. Without it, type /fob.",
        function() return db().minimap.shown end, ns.MinimapButton.SetShown)

    Button(page, "Reset grid layout", 150, function() Report(ns.Settings.ResetLayout()) end)
        :SetPoint("TOPLEFT", 12, y - 8)
    Button(page, "Reset pixel position", 150, function() ns.Pixel.ResetPosition(); Report(true) end)
        :SetPoint("TOPLEFT", 172, y - 8)
    return -(y - 8 - 20)
end

-- Engine features, split over two pages in display order. Each row is
-- {setting, label, tooltip, parent}: a row with a parent is indented and
-- greyed out while the parent is off. Booleans are check boxes, enums cycle
-- through their values, numbers have -/+ buttons; buttons and values sit in
-- a column right of the labels.
Options.FEATURE_PAGES = {
    {title = "Combat", rows = {
        {"burstCue", "Burst cue", "A ready burst cooldown moves to position 2, with a purple border."},
        {"interrupts", "Interrupts", "When the target casts, an icon left of the grid shows the interrupt; its cell gets a red \"!\"."},
        {"interruptMode", "Interrupt style", "Kick only: never crowd control. Kick first: crowd control only on casts that cannot be kicked. CC first: crowd control before the kick.", "interrupts"},
        {"interruptFears", "Fears may interrupt", "Fears count as interrupts. A feared enemy may run into others.", "interrupts"},
        {"defensives", "Defensive column", "Defensives in a column right of the grid; the first ready one puts an orange \"D\" on its cell."},
        {"holdEmergencies", "Save big defensives for low health", "Immunities and big heals wait until health is low.", "defensives"},
        {"healingItems", "Healing potion or healthstone", "The best one in your bags, in the defensive column and in a cell."},
        {"emergencyHeal", "Emergency heal", "At critical health a heal takes position 1."},
        {"emergencyHealBelow", "Critical health below", "Health that counts as critical.", "emergencyHeal"},
        {"petCues", "Pet heal, revive and summon", "Suggests healing, reviving or calling your pet."},
        {"petHealBelow", "Pet heal below", "Pet health that brings the pet heal.", "petCues"},
        {"groupHeals", "Group heals", "Heals allies when they are low."},
        {"ccBreak", "Escape from loss of control", "Suggests the move that breaks a stun, fear or root."},
    }},
    {title = "Reminders", rows = {
        {"precombat", "Reminder row", "Out of combat, buttons under the grid for what is missing. Click to use."},
        {"classBuffs", "Class buffs", "Your own buffs, when missing.", "precombat"},
        {"flask", "Flask or elixir", "When you carry one and none is active.", "precombat"},
        {"food", "Well Fed food", "When you carry it and are not Well Fed.", "precombat"},
        {"scroll", "Scroll", "When you carry one and it is not active.", "precombat"},
        {"weaponEnchant", "Weapon coatings", "Poison, stone, oil or imbue: one press each.", "precombat"},
        {"poisonMainHand", "Poison, main hand", "Rogue poison for the main hand.", "weaponEnchant"},
        {"poisonOffHand", "Poison, off hand", "Rogue poison for the off hand.", "weaponEnchant"},
        {"recovery", "Eat, drink or bandage", "After a fight, when health or mana is low.", "precombat"},
        {"stealthReminder", "Stealth", "Rogue and feral druid: stealth out of combat.", "precombat"},
        {"topoffHeal", "Top-off heal", "Heal yourself out of combat. Below 35% health it is always suggested.", "precombat"},
        {"topoffBelow", "Top-off heal below", "Health under which the top-off heal is suggested.", "topoffHeal"},
    }},
}
Options.FEATURE_ORDER = {}
for _, featurePage in ipairs(Options.FEATURE_PAGES) do
    for _, row in ipairs(featurePage.rows) do Options.FEATURE_ORDER[#Options.FEATURE_ORDER + 1] = row end
end
local POISON_NAMES = {instant = "Instant", deadly = "Deadly", crippling = "Crippling",
    mindNumbing = "Mind-numbing", wound = "Wound", off = "None"}
Options.ENUM_NAMES = {
    interruptMode = {kickOnly = "Kick only", kickPrefer = "Kick first", ccPrefer = "CC first"},
    poisonMainHand = POISON_NAMES, poisonOffHand = POISON_NAMES,
}
local ENUM_ORDER = {interruptMode = {"kickOnly", "kickPrefer", "ccPrefer"},
    poisonMainHand = ns.Coatings.POISON_CHOICES, poisonOffHand = ns.Coatings.POISON_CHOICES}
local CONTROL_X, INDENT, LABEL_X = 360, 22, 44

-- A row is active while every parent up its chain is on.
local function ParentsOn(parentOf, name)
    local parent = parentOf[name]
    while parent do
        if not ns.Settings.Feature(parent) then return false end
        parent = parentOf[parent]
    end
    return true
end

local function SetRowEnabled(widgets, enabled)
    for _, w in ipairs(widgets) do
        if w.SetEnabled then w:SetEnabled(enabled) end
        w:SetAlpha(enabled and 1 or 0.4)
    end
end

local function BuildFeaturesPage(page, rows)
    local y = -8
    local parentOf = {}
    for _, row in ipairs(rows) do parentOf[row[1]] = row[4] end
    for _, row in ipairs(rows) do
        local name, text, tip, parent = row[1], row[2], row[3], row[4]
        local spec = ns.Settings.FEATURES[name]
        local depth, p = 0, parent
        while p do depth = depth + 1; p = parentOf[p] end
        local x = depth * INDENT
        local widgets
        if spec.kind == "boolean" then
            local c, label = CheckRow(page, 8 + x, y, text, tip, function(v) Report(ns.Settings.SetFeature(name, v)) end)
            label:SetWidth(Options.PAGE_WIDTH - 52 - x)
            widgets = {c, label}
            refreshers[#refreshers + 1] = function() c:SetChecked(ns.Settings.Feature(name)) end
            y = y - 28
        else
            local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            -- Same column as the check box labels.
            label:SetPoint("TOPLEFT", LABEL_X + x, y - 3)
            label:SetWidth(CONTROL_X - LABEL_X - 8 - x)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(text)
            local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            widgets = {label, value}
            if spec.kind == "enum" then
                local cycle = Button(page, ">", 24, function()
                    local order = ENUM_ORDER[name]
                    local current = ns.Settings.Feature(name)
                    for i, v in ipairs(order) do
                        if v == current then return Report(ns.Settings.SetFeature(name, order[i % #order + 1])) end
                    end
                end)
                cycle:SetPoint("TOPLEFT", CONTROL_X, y)
                AddTooltip(cycle, text, tip)
                widgets[#widgets + 1] = cycle
                value:SetPoint("TOPLEFT", CONTROL_X + 32, y - 3)
                value:SetWidth(Options.PAGE_WIDTH - CONTROL_X - 40)
                value:SetJustifyH("LEFT")
            else
                local minus = Button(page, "-", 24, function() Report(ns.Settings.SetFeature(name, ns.Settings.Feature(name) - 5)) end)
                minus:SetPoint("TOPLEFT", CONTROL_X, y)
                local plus = Button(page, "+", 24, function() Report(ns.Settings.SetFeature(name, ns.Settings.Feature(name) + 5)) end)
                plus:SetPoint("TOPLEFT", CONTROL_X + 76, y)
                AddTooltip(minus, text, tip)
                AddTooltip(plus, text, tip)
                widgets[#widgets + 1] = minus
                widgets[#widgets + 1] = plus
                value:SetPoint("TOPLEFT", CONTROL_X + 26, y - 3)
                value:SetWidth(48)
                value:SetJustifyH("CENTER")
            end
            refreshers[#refreshers + 1] = function()
                local v = ns.Settings.Feature(name)
                local names = Options.ENUM_NAMES[name]
                if names then value:SetText(names[v] or tostring(v))
                elseif spec.kind == "number" then value:SetText(v .. "%")
                else value:SetText(tostring(v)) end
            end
            y = y - 26
        end
        if parent then
            refreshers[#refreshers + 1] = function() SetRowEnabled(widgets, ParentsOn(parentOf, name)) end
        end
    end
    return -y
end

local function ActionLabel(cell)
    if not cell then return "|cff808080empty|r" end
    if cell.kind == "spell" then
        return (ns.SpellName(cell.id) or "Spell") .. (cell.auto and " |cff80c0ff(auto)|r" or "")
    end
    return ns.ItemName(cell.id) or "Item"
end

local function ActionIcon(cell)
    if not cell then return nil end
    if cell.kind == "spell" then return ns.SpellIcon(cell.id) end
    return ns.ItemIcon(cell.id)
end

-- "CTRL-SHIFT-1" -> "Ctrl-Shift-1"; mouse names shortened.
local KEY_WORDS = {CTRL = "Ctrl", ALT = "Alt", SHIFT = "Shift", BUTTON3 = "Mouse 3", BUTTON4 = "Mouse 4",
    BUTTON5 = "Mouse 5", MOUSEWHEELUP = "Wheel up", MOUSEWHEELDOWN = "Wheel down"}
function Options.KeyText(key)
    local parts = {}
    for part in string.gmatch(key, "[^-]+") do parts[#parts + 1] = KEY_WORDS[part] or part end
    if key:sub(-1) == "-" then parts[#parts + 1] = "-" end
    return table.concat(parts, "-")
end

local function StartCapture(slot)
    if ns.InCombat() then return Report(false, "changes to cells and keys are blocked in combat") end
    captureFrame.slot = slot
    captureFrame.text:SetText(string.format("Press a key for cell %d\n\n|cffa0a0a0Esc cancels|r", slot))
    captureFrame:Show()
end

local CELL_ROW, CELL_TOP = 21, 24
-- 30 rows do not fit the page: 15 at a time, switched by "1-15" / "16-30".
Options.CELL_GROUP = 15
local function BuildCellsPage(page)
    local groups = {}
    local groupCount = math.ceil(ns.MAX_SLOTS / Options.CELL_GROUP)
    local function ShowGroup(index)
        for i, group in ipairs(groups) do
            if i == index then group.holder:Show() else group.holder:Hide() end
            group.button:SetEnabled(i ~= index)
        end
        Options.cellGroup = index
    end
    for i = 1, groupCount do
        local holder = CreateFrame("Frame", nil, page)
        holder:SetAllPoints(page)
        local first = (i - 1) * Options.CELL_GROUP + 1
        local last = math.min(ns.MAX_SLOTS, i * Options.CELL_GROUP)
        local button = Button(page, first .. "-" .. last, 56, function() ShowGroup(i) end)
        button:SetHeight(16)
        button:SetPoint("TOPRIGHT", -12 - (groupCount - i) * 60, -1)
        groups[i] = {holder = holder, button = button}
    end
    local function Header(text, x)
        local h = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", x, -6)
        h:SetText(text)
    end
    Header("Cell", 12)
    Header("Action", 60)
    Header("Key", 254)
    local rule = page:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(1, 0.82, 0, 0.25)
    rule:SetPoint("TOPLEFT", 12, -19)
    rule:SetSize(Options.PAGE_WIDTH - 24, 1)
    for slot = 1, ns.MAX_SLOTS do
        local holder = groups[math.floor((slot - 1) / Options.CELL_GROUP) + 1].holder
        local y = -CELL_TOP - ((slot - 1) % Options.CELL_GROUP) * CELL_ROW
        if slot % 2 == 0 then
            local band = holder:CreateTexture(nil, "BACKGROUND")
            band:SetColorTexture(1, 1, 1, 0.04)
            band:SetPoint("TOPLEFT", 8, y + 1)
            band:SetSize(Options.PAGE_WIDTH - 16, CELL_ROW)
        end
        local num = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        num:SetPoint("TOPLEFT", 14, y - 4)
        num:SetText(tostring(slot))
        local icon = holder:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("TOPLEFT", 36, y)
        local action = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        action:SetPoint("TOPLEFT", 60, y - 4)
        action:SetWidth(190)
        action:SetJustifyH("LEFT")
        action:SetWordWrap(false)
        local key = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        key:SetPoint("TOPLEFT", 254, y - 4)
        key:SetWidth(84)
        key:SetJustifyH("LEFT")
        key:SetWordWrap(false)
        local bind = Button(holder, "Bind", 44, function() StartCapture(slot) end)
        bind:SetPoint("TOPLEFT", 340, y)
        AddTooltip(bind, "Bind", "Press a new key for this cell.")
        local unbind = Button(holder, "Unbind", 54, function() Report(ns.Actions.Unbind(slot)) end)
        unbind:SetPoint("TOPLEFT", 385, y)
        AddTooltip(unbind, "Unbind", "Remove the key from this cell.")
        local default = Button(holder, "Default", 56, function() Report(ns.Actions.DefaultKey(slot)) end)
        default:SetPoint("TOPLEFT", 440, y)
        AddTooltip(default, "Default", "Give back the default key (Shift-1 ... Ctrl-Shift-0, then Ctrl-1 ... Ctrl-0).")
        local clear = Button(holder, "Clear", 44, function() Report(ns.Actions.Clear(slot)) end)
        clear:SetPoint("TOPLEFT", 497, y)
        AddTooltip(clear, "Clear", "Empty the cell. An automatic spell will not come back.")
        refreshers[#refreshers + 1] = function()
            local settings = ns.Settings.Get()
            local cell, bound = ns.Settings.Char().cells[slot], ns.Settings.KeyFor(slot)
            local hidden = slot > settings.grid.slots
            local texture = ActionIcon(cell)
            icon:SetTexture(texture)
            if texture then icon:Show() else icon:Hide() end
            action:SetText(ActionLabel(cell) .. (hidden and " |cffff8040(not shown)|r" or ""))
            if bound then
                local shadowed = ns.Actions.ExternalBinding(bound)
                local isDefault = settings.keys[slot] == nil
                local text = Options.KeyText(bound)
                if isDefault then text = "|cffb0b0b0" .. text .. "|r" end
                key:SetText(text .. (shadowed and " |cffff8040!|r" or ""))
            else
                key:SetText(cell and "|cffff4040no key|r" or "")
            end
            local alpha = hidden and 0.5 or 1
            num:SetAlpha(alpha); icon:SetAlpha(alpha); action:SetAlpha(alpha); key:SetAlpha(alpha)
        end
    end
    ShowGroup(1)
    local noteY = -CELL_TOP - math.min(ns.MAX_SLOTS, Options.CELL_GROUP) * CELL_ROW - 4
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 12, noteY)
    note:SetWidth(Options.PAGE_WIDTH - 24)
    note:SetJustifyH("LEFT")
    note:SetText("Drag a spell or item onto a cell of the grid to fill it.  Grey key: the default one.  |cffff8040!|r the key also has a normal WoW binding; the cell wins while the add-on is loaded.")
    -- The note wraps to at most two lines of small text.
    return -noteY + 28
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
    frame:SetSize(FRAME_SIZE, FRAME_SIZE)
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

    pages, tabs = {}, {}
    local titles = {"Layout", "Cells & keys"}
    for _, featurePage in ipairs(Options.FEATURE_PAGES) do titles[#titles + 1] = featurePage.title end
    for index, name in ipairs(titles) do
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", PAGE_INSET, -PAGE_TOP)
        page:SetPoint("BOTTOMRIGHT", -PAGE_INSET, PAGE_INSET)
        page:Hide()
        pages[index] = page
        local tab = Button(frame, name, 126, function() Options.ShowPage(index) end)
        tab:SetPoint("TOPLEFT", 12 + (index - 1) * 133, -30)
        -- Gold bar under the open page's tab.
        tab.marker = frame:CreateTexture(nil, "OVERLAY")
        tab.marker:SetColorTexture(1, 0.82, 0, 0.9)
        tab.marker:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 6, -1)
        tab.marker:SetSize(114, 2)
        tabs[index] = tab
    end
    Options.pageExtents[1] = BuildLayoutPage(pages[1])
    Options.pageExtents[2] = BuildCellsPage(pages[2])
    for i, featurePage in ipairs(Options.FEATURE_PAGES) do
        Options.pageExtents[2 + i] = BuildFeaturesPage(pages[2 + i], featurePage.rows)
    end
    BuildCapture()
    Options.ShowPage(1)
end

function Options.ShowPage(index)
    for i, page in ipairs(pages) do
        local open = i == index
        if open then page:Show() else page:Hide() end
        local tab = tabs[i]
        if open then tab:LockHighlight() else tab:UnlockHighlight() end
        if open then tab.marker:Show() else tab.marker:Hide() end
    end
    Options.currentPage = index
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

function Options.Close()
    if captureFrame then captureFrame:Hide() end
    if frame then frame:Hide() end
end

function Options.CloseForCombat()
    if captureFrame then captureFrame:Hide() end
    if frame and frame:IsShown() then frame:Hide() end
end

function Options.IsShown()
    return frame ~= nil and frame:IsShown()
end
