-- Forever One Button: the reminder row, below the queue strip.
--
-- Out of combat, the reminders of Engine/Precombat.lua (class buffs,
-- consumables, stealth, top-off heal, food/drink/bandage) as buttons the
-- player clicks. They are secure action buttons: their action changes only
-- out of combat, and a secure state driver hides the row as soon as combat
-- starts. A button acts only on the player's click; nothing is pressed by
-- the addon, and no key is bound to them.
--
-- The weapon coating entry goes on its weapon in one click: the item's
-- targeting is resolved by the secure template's `target-slot` attribute
-- (main hand 16, off hand 17), no macro. The same action is also on
-- ForeverOneButtonCoating, a button without a frame on screen that the
-- player may bind under Key Bindings > AddOns (Bindings.xml): pressed
-- repeatedly, it applies the next coating each time (one cast per press).
-- It is emptied before combat starts (Reminders.ClearCoatingKey).
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

local HAND_TEXT = {main = "main hand", off = "off hand"}
local COATING_BINDING = "CLICK ForeverOneButtonCoating:LeftButton"
BINDING_HEADER_FOREVERONEBUTTON = "Forever One Button"
_G["BINDING_NAME_" .. COATING_BINDING] = "Apply the next weapon coating"

local function OnEnter(button)
    if not GameTooltip or not button.entry then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    local entry = button.entry
    local name = entry.kind == ns.ENTRY.ITEM and ns.ItemName(entry.item) or ns.SpellName(entry.id)
    GameTooltip:AddLine(name or "?")
    local reason = REASON_TEXT[entry.reason] or ""
    if entry.hand then reason = reason .. " (" .. HAND_TEXT[entry.hand] .. ")" end
    GameTooltip:AddLine(reason, 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Click to use (out of combat)", 0.6, 0.6, 0.6)
    if entry.reason == "weaponEnchant" then
        local key = GetBindingKey and GetBindingKey(COATING_BINDING)
        GameTooltip:AddLine(key and ("Next coating key: " .. key) or "Next coating key: Key Bindings > AddOns",
            0.6, 0.6, 0.6)
    end
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

-- The bindable coating button: no size, no point, nothing drawn.
-- Its clicks are registered in Reminders.Layout, out of combat.
local coatingKey = CreateFrame("Button", "ForeverOneButtonCoating", UIParent, "SecureActionButtonTemplate")
Reminders.coatingKey = coatingKey

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
    coatingKey:RegisterForClicks("AnyDown", "AnyUp")
    if RegisterStateDriver then RegisterStateDriver(row, "visibility", "[combat] hide; show") end
    laidOut = true
    return true
end
Reminders.Layout()

-- The secure action of an entry (nil: none).
local function SetAction(button, entry)
    button:SetAttribute("useOnKeyDown", ns.Grid.UseKeyDown())
    local item = entry and entry.kind == ns.ENTRY.ITEM
    button:SetAttribute("type1", entry and (item and "item" or "spell") or nil)
    button:SetAttribute("item", item and ("item:" .. entry.item) or nil)
    button:SetAttribute("spell", entry and not item and entry.id or nil)
    button:SetAttribute("target-slot", item and entry.slot or nil)
end

local function Configure(button, entry)
    button.entry = entry
    SetAction(button, entry)
    if not entry then
        button:Hide()
        return
    end
    if entry.kind == ns.ENTRY.ITEM then
        button.icon:SetTexture(ns.ItemIcon(entry.item) or EMPTY_ICON)
    else
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
    local key, coating = {}, nil
    for i, entry in ipairs(entries) do
        key[i] = entry.id .. (entry.slot and ("@" .. entry.slot) or "")
        if entry.reason == "weaponEnchant" then coating = entry end
    end
    key = table.concat(key, ",")
    if key == signature then return false end
    signature = key
    for i, button in ipairs(Reminders.buttons) do Configure(button, entries[i]) end
    coatingKey.entry = coating
    SetAction(coatingKey, coating)
    return true
end

function Reminders.Reset() signature = nil end

-- Before combat (PLAYER_REGEN_DISABLED, still outside the lockdown): the
-- key does nothing in combat; the next update after combat sets it again.
function Reminders.ClearCoatingKey()
    if ns.InCombat() then return end
    coatingKey.entry = nil
    SetAction(coatingKey, nil)
    signature = nil
end
