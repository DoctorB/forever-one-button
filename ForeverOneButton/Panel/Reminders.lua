-- Forever One Button: the reminder row, below the queue strip.
--
-- Out of combat, the reminders of Engine/Precombat.lua (class buffs,
-- consumables, stealth, top-off heal, food/drink/bandage) as buttons the
-- player clicks. They are secure action buttons: their action changes only
-- out of combat, and a secure state driver hides the row as soon as combat
-- starts. A button acts only on the player's click; nothing is pressed by
-- the addon, and no key is bound to them.
local ADDON_NAME, ns = ...

local Reminders = {}
ns.Reminders = Reminders

Reminders.SIZE = 30
Reminders.REFRESH_SECONDS = 1.0
local EMPTY_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local REASON_TEXT = {buff = "Class buff", flask = "Flask or elixir", food = "Food", scroll = "Scroll",
    weaponEnchant = "Weapon enhancement", stealth = "Stealth", heal = "Top-off heal", drink = "Drink",
    bandage = "Bandage"}

-- The row holds secure buttons, so it is protected: its layout and the
-- state driver are applied out of combat (Reminders.Layout), also after a
-- /reload in combat.
local row = CreateFrame("Frame", "ForeverOneButtonReminders", ns.Grid.container)
Reminders.row = row

local function OnEnter(button)
    if not GameTooltip or not button.entry then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    local entry = button.entry
    local name = entry.kind == ns.ENTRY.ITEM and ns.ItemName(entry.item) or ns.SpellName(entry.id)
    GameTooltip:AddLine(name or "?")
    GameTooltip:AddLine(REASON_TEXT[entry.reason] or "", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Click to use (out of combat)", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

Reminders.buttons = {}
for i = 1, ns.Precombat.MAX_ENTRIES do
    local button = CreateFrame("Button", "ForeverOneButtonReminder" .. i, row, "SecureActionButtonTemplate")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    Reminders.buttons[i] = button
end

local laidOut = false
function Reminders.Layout()
    if laidOut or ns.InCombat() then return laidOut end
    row:SetSize(ns.Precombat.MAX_ENTRIES * (Reminders.SIZE + 4), Reminders.SIZE)
    row:SetPoint("TOPLEFT", ns.Grid.strip, "BOTTOMLEFT", 0, -4)
    for i, button in ipairs(Reminders.buttons) do
        button:SetSize(Reminders.SIZE, Reminders.SIZE)
        button:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * (Reminders.SIZE + 4), 0)
        -- As the grid's cells: both edges, acting on the one the client's
        -- ActionButtonUseKeyDown setting picks (a click otherwise does nothing).
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:Hide()
    end
    if RegisterStateDriver then RegisterStateDriver(row, "visibility", "[combat] hide; show") end
    laidOut = true
    return true
end
Reminders.Layout()

local function Configure(button, entry)
    button.entry = entry
    button:SetAttribute("useOnKeyDown", ns.Grid.UseKeyDown())
    if not entry then
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("item", nil)
        button:Hide()
        return
    end
    if entry.kind == ns.ENTRY.ITEM then
        button:SetAttribute("type1", "item")
        button:SetAttribute("item", "item:" .. entry.item)
        button:SetAttribute("spell", nil)
        button.icon:SetTexture(ns.ItemIcon(entry.item) or EMPTY_ICON)
    else
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell", entry.id)
        button:SetAttribute("item", nil)
        button.icon:SetTexture(ns.SpellIcon(entry.id) or EMPTY_ICON)
    end
    button:Show()
end

local signature
-- Out of combat only; in combat the row is hidden and stays as it was.
function Reminders.Update()
    if ns.InCombat() or not Reminders.Layout() then return false end
    local ok, entries = pcall(ns.Precombat.Suggest)
    if not ok then entries = {} end
    ns.Precombat.SetOffered(entries)
    local key = {}
    for i, entry in ipairs(entries) do key[i] = entry.id end
    key = table.concat(key, ",")
    if key == signature then return false end
    signature = key
    for i, button in ipairs(Reminders.buttons) do Configure(button, entries[i]) end
    return true
end

function Reminders.Reset() signature = nil end
