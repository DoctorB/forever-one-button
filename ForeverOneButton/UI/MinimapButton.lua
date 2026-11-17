-- Forever One Button: round button on the minimap edge (owner request,
-- 2026-11-17).
--
-- Left-click opens or closes the options, right-click locks or unlocks the
-- grid, dragging moves the button around the minimap. The angle is saved in
-- ForeverOneButtonDB.minimap; "Show minimap button" on the Layout page hides
-- it. A plain button: no secure template, nothing protected, usable in combat
-- (the options themselves still refuse to open in combat).
local ADDON_NAME, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\ForeverOneButton\\Media\\icon"
-- Central tile of the logo (the infinity sign), as on the empty cells.
local ICON_CROP = {0.23, 0.77, 0.22, 0.76}
local SIZE = 31
local button

-- Offset from the minimap centre for an angle in degrees, just outside the
-- round edge.
function MinimapButton.Offset(angle, minimapWidth)
    local radius = (minimapWidth or 140) / 2 + 10
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

-- Angle in degrees (0-359) of a point relative to the minimap centre.
function MinimapButton.AngleOf(dx, dy)
    local angle = math.deg(math.atan2(dy, dx))
    if angle < 0 then angle = angle + 360 end
    return math.floor(angle + 0.5) % 360
end

local function Place()
    local x, y = MinimapButton.Offset(ns.Settings.Get().minimap.angle, Minimap:GetWidth())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function DragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not (mx and cx and scale and scale > 0) then return end
    ns.Settings.Get().minimap.angle = MinimapButton.AngleOf(cx / scale - mx, cy / scale - my)
    Place()
end

local function ShowTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.TITLE, 1, 0.82, 0)
    GameTooltip:AddLine("Left-click: options", 1, 1, 1)
    local locked = ns.Settings.Get().grid.locked
    GameTooltip:AddLine(locked and "Right-click: unlock the grid" or "Right-click: lock the grid", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function Build()
    button = CreateFrame("Button", "ForeverOneButtonMinimapButton", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ICON)
    button.icon:SetTexCoord(unpack(ICON_CROP))
    button.icon:SetSize(19, 19)
    button.icon:SetPoint("CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    end

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.Grid.SetLocked(not ns.Settings.Get().grid.locked)
            ns.Options.Refresh()
        elseif ns.Options.IsShown() then
            ns.Options.Close()
        else
            ns.Options.Open()
        end
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then ShowTooltip(button) end
    end)
    button:SetScript("OnDragStart", function(self)
        if GameTooltip then GameTooltip:Hide() end
        self:SetScript("OnUpdate", DragUpdate)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- Creates the button on first use, then shows it in place or hides it.
function MinimapButton.Apply()
    if not Minimap then return end
    local settings = ns.Settings.Get().minimap
    if not settings.shown then
        if button then button:Hide() end
        return
    end
    if not button then Build() end
    Place()
    button:Show()
end

function MinimapButton.SetShown(shown)
    ns.Settings.Get().minimap.shown = shown and true or false
    MinimapButton.Apply()
    return true
end
