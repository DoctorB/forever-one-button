-- Forever One Button: the Action Panel, a checkerboard grid of action buttons.
--
-- Designed from scratch (docs/ACTION_PANEL_DESIGN.md). Each cell is a secure
-- action button whose action and key the user chose. JustAC suggestions are
-- shown as numbered marks on the cells and in the queue strip below the grid;
-- they never change what a cell does or which key it has.
--
-- Combat rules: the container holds protected buttons, so layout, position,
-- scale and visibility change only out of combat (deferred otherwise). Icons,
-- marks and texts are plain regions and update in combat.
local ADDON_NAME, ns = ...

local Grid = {}
ns.Grid = Grid
Grid.buttons = {}
Grid.pendingLayout = false

local POSITION_COLORS = {
    [1] = {1.00, 0.82, 0.10}, -- JustAC position 1: gold
    other = {0.30, 0.80, 1.00}, -- positions 2+: cyan
}
local CHECKER = {{0.10, 0.12, 0.15, 0.92}, {0.17, 0.19, 0.23, 0.92}}
local EMPTY_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local STRIP_HEIGHT = 44

local container = CreateFrame("Frame", "ForeverOneButtonGrid", UIParent)
container:SetFrameStrata("MEDIUM")
container:SetMovable(true)
container:SetClampedToScreen(true)
Grid.container = container
-- Owner of the override bindings (SetOverrideBindingClick).
Grid.owner = container

local background = container:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0.02, 0.02, 0.03, 0.75)

-- Title bar above the grid, always shown with the grid so the panel can be
-- found and moved: left-drag moves it while unlocked, right-click toggles the
-- lock. The position is saved in grid.point (SavedVariables), not in the
-- client's layout cache.
local dragBar = CreateFrame("Frame", "ForeverOneButtonGridDragBar", container)
dragBar:SetHeight(14)
dragBar:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 1)
dragBar:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, 1)
dragBar:EnableMouse(true)
dragBar:RegisterForDrag("LeftButton")
local dragTex = dragBar:CreateTexture(nil, "ARTWORK")
dragTex:SetAllPoints()
local dragText = dragBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dragText:SetPoint("CENTER")

local function RefreshDragBar()
    if ns.Settings.Get().grid.locked then
        dragTex:SetColorTexture(0.20, 0.22, 0.26, 0.55)
        dragText:SetText("Forever One Button (locked) - right-click to unlock")
    else
        dragTex:SetColorTexture(0.30, 0.80, 1.00, 0.55)
        dragText:SetText("Forever One Button - drag to move, right-click to lock")
    end
end

dragBar:SetScript("OnDragStart", function()
    if ns.InCombat() or ns.Settings.Get().grid.locked then return end
    Grid.moving = true
    container:StartMoving()
end)
-- Ends a drag and saves the position. Also called when combat starts.
function Grid.StopMoving()
    if not Grid.moving then return end
    Grid.moving = false
    container:StopMovingOrSizing()
    container:SetUserPlaced(false)
    local point, _, relative, x, y = container:GetPoint(1)
    ns.Settings.Get().grid.point = {point, relative, x, y}
end
dragBar:SetScript("OnDragStop", Grid.StopMoving)
dragBar:SetScript("OnMouseUp", function(_, button)
    if button ~= "RightButton" then return end
    local ok, message = Grid.SetLocked(not ns.Settings.Get().grid.locked)
    if ok then
        ns.Print(ns.Settings.Get().grid.locked and "grid locked" or "grid unlocked: drag the title bar to move it")
    else
        ns.Print(message)
    end
end)
dragBar:SetScript("OnEnter", function()
    if not GameTooltip then return end
    GameTooltip:SetOwner(dragBar, "ANCHOR_TOP")
    GameTooltip:AddLine("Forever One Button")
    if ns.Settings.Get().grid.locked then
        GameTooltip:AddLine("Locked. Right-click to unlock, then drag to move.", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Drag to move. Right-click to lock.", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("The position is saved. Out of combat only.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
dragBar:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
end)

-- Status line and JustAC queue strip, below the cells. The strip lists the
-- queue in JustAC order with the cell that holds each entry.
local strip = CreateFrame("Frame", "ForeverOneButtonQueueStrip", container)
strip:SetHeight(STRIP_HEIGHT)
strip:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, -2)
strip:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", 0, -2)
local stripBg = strip:CreateTexture(nil, "BACKGROUND")
stripBg:SetAllPoints()
stripBg:SetColorTexture(0.02, 0.02, 0.03, 0.75)
local statusText = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusText:SetPoint("TOPLEFT", strip, "TOPLEFT", 4, -3)
statusText:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -4, -3)
statusText:SetJustifyH("LEFT")
Grid.statusText = statusText

Grid.queueIcons = {}
local MAX_QUEUE_ICONS = ns.Settings.GRID_LIMITS.queueDepth.max
for position = 1, MAX_QUEUE_ICONS do
    local icon = strip:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 4 + (position - 1) * 56, 3)
    local label = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 2, 0)
    icon:Hide()
    label:Hide()
    Grid.queueIcons[position] = {icon = icon, label = label}
end

local function Edge(button, layer)
    local edges = {}
    for i = 1, 4 do edges[i] = button:CreateTexture(nil, layer) end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(2)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(2)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(2)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(2)
    return edges
end

local function SetEdges(edges, color)
    for i = 1, 4 do
        if color then
            edges[i]:SetColorTexture(color[1], color[2], color[3], 1)
            edges[i]:Show()
        else
            edges[i]:Hide()
        end
    end
end

function Grid.UseKeyDown()
    -- Technical reuse of HCOneButton CoreHUD.lua:20-25: follow the client's
    -- ActionButtonUseKeyDown setting so a key press fires exactly once.
    if type(GetCVarBool) ~= "function" then return false end
    return ns.SafeCall(GetCVarBool, "ActionButtonUseKeyDown") == true
end

local function ActionFromCursor()
    if type(GetCursorInfo) ~= "function" then return nil end
    local ok, infoType, info1, info2, info3 = pcall(GetCursorInfo)
    if not ok or not ns.Readable(infoType) then return nil end
    if infoType == "spell" then
        -- (spell, spellIndex, bookType, spellID) on the modern client.
        local spellID = ns.Readable(info3) and tonumber(info3) or nil
        if spellID then return "spell", spellID end
    elseif infoType == "item" then
        local itemID = ns.Readable(info1) and tonumber(info1) or nil
        if itemID then return "item", itemID end
    end
    return nil
end

local function OnReceiveDrag(button)
    local kind, id = ActionFromCursor()
    if not kind then return end
    local ok, message = ns.Actions.Assign(button.slot, kind, id)
    if ok and ClearCursor then ClearCursor() end
    if message then ns.Print(message) end
end

local function CellDescription(slot)
    local cell = ns.Actions.applied[slot]
    if not cell then return "Empty cell" end
    if cell.kind == "spell" then return ns.SpellName(cell.id) or ("Spell " .. cell.id) end
    return ns.ItemName(cell.id) or ("Item " .. cell.id)
end

local function OnEnter(button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(string.format("Cell %d: %s", button.slot, CellDescription(button.slot)))
    local key = ns.Actions.appliedKeys[button.slot]
    GameTooltip:AddLine(key and ("Key: " .. key) or "No key bound", 0.8, 0.8, 0.8)
    if button.queuePosition then
        GameTooltip:AddLine("JustAC position " .. button.queuePosition, 1, 0.82, 0.1)
    end
    if not ns.Actions.applied[button.slot] then
        GameTooltip:AddLine("Drag a spell or item here (out of combat)", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function OnLeave()
    if GameTooltip then GameTooltip:Hide() end
end

local function CreateCell(slot)
    local button = CreateFrame("Button", ns.Actions.ButtonName(slot), container, "SecureActionButtonTemplate")
    button.slot = slot
    -- Click registration and attributes are protected: Actions.Apply sets
    -- them out of combat (a /reload in combat creates the cells unconfigured).

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.rangeTint = button:CreateTexture(nil, "OVERLAY")
    button.rangeTint:SetAllPoints(button.icon)
    button.rangeTint:SetColorTexture(0.9, 0.1, 0.1, 0.35)
    button.rangeTint:Hide()
    button.edges = Edge(button, "OVERLAY")
    SetEdges(button.edges, nil)

    button.slotText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.slotText:SetPoint("TOPLEFT", 3, -2)
    button.slotText:SetText(tostring(slot))
    button.keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.keyText:SetPoint("BOTTOMRIGHT", -3, 3)
    button.positionText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.positionText:SetPoint("TOPRIGHT", -3, -2)

    button:SetScript("OnReceiveDrag", OnReceiveDrag)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    Grid.buttons[slot] = button
    return button
end

for slot = 1, ns.MAX_SLOTS do CreateCell(slot) end

-- Out-of-combat layout: cell positions, sizes, scale, anchor and visibility.
function Grid.ApplyLayout()
    if ns.InCombat() then
        Grid.pendingLayout = true
        return false
    end
    local g = ns.Settings.Get().grid
    local columns = math.min(g.columns, g.slots)
    local rows = math.ceil(g.slots / columns)
    local step = g.cellSize + g.spacing

    for slot = 1, ns.MAX_SLOTS do
        local button = Grid.buttons[slot]
        if slot <= g.slots then
            local index = slot - 1
            local column, row = index % columns, math.floor(index / columns)
            button:ClearAllPoints()
            button:SetSize(g.cellSize, g.cellSize)
            button:SetPoint("TOPLEFT", container, "TOPLEFT", g.spacing + column * step, -(g.spacing + row * step))
            local shade = CHECKER[(row + column) % 2 + 1]
            button.bg:SetColorTexture(shade[1], shade[2], shade[3], shade[4])
            button:Show()
        else
            button:Hide()
        end
    end

    container:SetSize(g.spacing + columns * step, g.spacing + rows * step)
    container:SetScale(g.scale)
    container:ClearAllPoints()
    container:SetPoint(g.point[1], UIParent, g.point[2], g.point[3], g.point[4])
    if g.shown then container:Show() else container:Hide() end
    RefreshDragBar()
    Grid.pendingLayout = false
    -- The visible slot count limits which cells execute, so re-apply actions.
    ns.Actions.Apply()
    return true
end

function Grid.SetLocked(locked)
    if ns.InCombat() then return false, "layout changes are blocked in combat" end
    ns.Settings.Get().grid.locked = locked and true or false
    Grid.ApplyLayout()
    return true
end

function Grid.SetShown(shown)
    if ns.InCombat() then return false, "layout changes are blocked in combat" end
    ns.Settings.Get().grid.shown = shown and true or false
    Grid.ApplyLayout()
    return true
end

-- Icons and key labels from the applied state. Safe in combat.
function Grid.Refresh()
    for slot = 1, ns.MAX_SLOTS do
        local button = Grid.buttons[slot]
        local cell = ns.Actions.applied[slot]
        local texture
        if cell and cell.kind == "spell" then texture = ns.SpellIcon(cell.id)
        elseif cell then texture = ns.ItemIcon(cell.id) end
        button.icon:SetTexture(texture or EMPTY_ICON)
        button.icon:SetAlpha(cell and 1 or 0.15)
        local key = ns.Actions.appliedKeys[slot]
        if key then
            button.keyText:SetText(ns.Keys.Short(key))
            button.keyText:SetTextColor(1, 1, 1)
        elseif cell then
            button.keyText:SetText("no key")
            button.keyText:SetTextColor(1, 0.3, 0.3)
        else
            button.keyText:SetText("")
        end
    end
    if ns.Pixel then ns.Pixel.Rerender() end
    Grid.ShowQueue(ns.Model.snapshot, ns.Model.observation)
end

local STATUS_TEXT = {
    [ns.STATUS.MISSING] = "JustAC not loaded - no suggestions",
    [ns.STATUS.NO_METHOD] = "JustAC queue API not found - no suggestions",
    [ns.STATUS.ERROR] = "JustAC queue error - no suggestions",
    [ns.STATUS.INVALID] = "JustAC returned unexpected data - no suggestions",
    [ns.STATUS.UNREADABLE] = "JustAC queue unreadable - no suggestions",
}

local function EntryVisual(entry)
    if entry.kind == ns.ENTRY.SPELL then return ns.SpellIcon(entry.id) end
    if entry.kind == ns.ENTRY.ITEM then return ns.ItemIcon(-entry.id) end
    return nil
end

-- Marks JustAC positions on the cells and lists the queue in JustAC order.
-- Called on every queue change; touches regions only, so it is combat safe.
function Grid.ShowQueue(snapshot, observation)
    snapshot = snapshot or {status = ns.STATUS.MISSING, entries = {}, count = 0}
    observation = observation or {}
    local depth = ns.Settings.Get().grid.queueDepth

    for slot = 1, ns.MAX_SLOTS do
        local button = Grid.buttons[slot]
        button.queuePosition = nil
        button.positionText:SetText("")
        SetEdges(button.edges, nil)
        button.rangeTint:Hide()
    end

    local mappedHead, unmappedHead = false, false
    for position = 1, MAX_QUEUE_ICONS do
        local item = Grid.queueIcons[position]
        local entry = snapshot.status == ns.STATUS.OK and position <= depth and snapshot.entries[position] or nil
        if entry then
            local slot = (entry.kind == ns.ENTRY.SPELL or entry.kind == ns.ENTRY.ITEM)
                and ns.Actions.SlotFor(entry.id) or nil
            local label
            if entry.kind == ns.ENTRY.WAIT then label = position .. ": wait"
            elseif entry.kind == ns.ENTRY.UNREADABLE then label = position .. ": ?"
            elseif slot then label = position .. ": c" .. slot
            else label = position .. ": --" end
            item.icon:SetTexture(EntryVisual(entry) or EMPTY_ICON)
            item.icon:Show()
            item.label:SetText(label)
            item.label:Show()
            if slot then
                local button = Grid.buttons[slot]
                if not button.queuePosition then
                    button.queuePosition = position
                    button.positionText:SetText(tostring(position))
                    SetEdges(button.edges, POSITION_COLORS[position] or POSITION_COLORS.other)
                    if position == 1 and observation.outOfRange then button.rangeTint:Show() end
                end
                if position == 1 then mappedHead = true end
            elseif position == 1 and (entry.kind == ns.ENTRY.SPELL or entry.kind == ns.ENTRY.ITEM) then
                unmappedHead = true
            end
        else
            item.icon:Hide()
            item.label:Hide()
        end
    end

    local text = STATUS_TEXT[snapshot.status]
    if not text then
        local first = snapshot.entries[1]
        if not first then text = "JustAC: no suggestion"
        elseif first.kind == ns.ENTRY.WAIT then text = "JustAC: wait"
        elseif first.kind == ns.ENTRY.UNREADABLE then text = "JustAC suggestion unreadable"
        elseif unmappedHead then text = "JustAC suggestion is not on the grid (--)"
        elseif observation.casting then text = "JustAC: casting"
        elseif observation.outOfRange then text = "JustAC: out of range"
        else text = "JustAC" end
        if snapshot.verifiedMinor == false then text = text .. " (untested JustAC version)" end
    end
    if Grid.pendingLayout or ns.Actions.pendingApply or (ns.AutoFill and ns.AutoFill.pending) then
        text = text .. " - changes apply after combat"
    end
    if ns.AutoFill and ns.AutoFill.overflow > 0 then text = text .. " - " .. ns.AutoFill.overflow .. " spells did not fit" end
    if Grid.OverlapsPixel() then text = text .. " - grid covers the pixel!" end
    statusText:SetText(text)
    Grid.mappedHead, Grid.unmappedHead = mappedHead, unmappedHead
end

local function ScreenRect(frame)
    if not frame or not frame.GetRect or not frame:IsShown() then return nil end
    local left, bottom, width, height = frame:GetRect()
    if not left or ns.IsSecret(left) then return nil end
    local scale = frame:GetEffectiveScale()
    return left * scale, bottom * scale, width * scale, height * scale
end

-- True when the grid (or its strip) intersects the pixel on screen.
function Grid.OverlapsPixel()
    local pl, pb, pw, ph = ScreenRect(ns.Pixel and ns.Pixel.frame)
    if not pl then return false end
    for _, frame in ipairs({container, strip, dragBar}) do
        local l, b, w, h = ScreenRect(frame)
        if l and l < pl + pw and pl < l + w and b < pb + ph and pb < b + h then return true end
    end
    return false
end
