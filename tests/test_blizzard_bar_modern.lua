-- Hide Blizzard's bottom bar on the modern layout reported by /fob probe frames
-- on Forever 1.60.1.70374 (2026-10-15).
local H = dofile("tests/harness/wow.lua")

local bar = CreateFrame("Frame", "MainActionBar", UIParent)
for i = 1, 12 do
    local container = CreateFrame("Frame", "MainActionBarButtonContainer" .. i, bar)
    CreateFrame("CheckButton", "ActionButton" .. i, container, "SecureActionButtonTemplate, ActionButtonTemplate")
end
local micro = CreateFrame("Frame", "MicroMenuContainer", UIParent)
local menu = CreateFrame("Frame", "MicroMenu", micro)
CreateFrame("Button", "CharacterMicroButton", menu)
local bags = CreateFrame("Frame", "BagsBar", UIParent)
CreateFrame("Button", "MainMenuBarBackpackButton", bags)
local stance = CreateFrame("Frame", "StanceBar", UIParent)
local stanceContainer = CreateFrame("Frame", "StanceBarButtonContainer1", stance)
CreateFrame("CheckButton", "StanceButton1", stanceContainer, "SecureActionButtonTemplate")
local status = CreateFrame("Frame", "StatusTrackingBarManager", UIParent)
CreateFrame("Frame", "MainStatusTrackingBarContainer", status)

local ns = H.Boot({hideBlizzardBar = true, schema = 2}, nil)
H.Equal(bar:GetAlpha(), 0, "MainActionBar (art, dividers, paging, background) hidden")
H.Equal(bar:IsMouseEnabled(), false, "MainActionBar click-through")
H.Equal(MainActionBarButtonContainer5:GetAlpha(), 0, "button containers hidden")
H.Equal(ActionButton5:GetAlpha(), 0, "buttons hidden")
H.Equal(micro:GetAlpha(), 0, "micro menu hidden")
H.Equal(bags:GetAlpha(), 0, "bags hidden")
H.Equal(stance:GetAlpha(), 1, "stance bar visible")
H.Equal(StanceButton1:GetAlpha(), 1, "stance buttons visible")
H.Equal(status:GetAlpha(), 1, "experience bar visible")
H.Equal(MainStatusTrackingBarContainer:GetAlpha(), 1, "experience bar container visible")

ns.BlizzardBar.SetHidden(false)
H.Equal(bar:GetAlpha(), 1, "MainActionBar restored")
H.Equal(ActionButton5:GetAlpha(), 1, "buttons restored")

ns.Commands.Handle("probe frames")
local text = table.concat(ForeverOneButtonLog.probeFrames, "\n")
H.Check(text:find("child of MainActionBar|MainActionBarButtonContainer1|Frame"), "probe lists MainActionBar children")
H.Check(text:find("UIParent child|StanceBar|Frame"), "probe lists bar-like UIParent children")
H.Done("test_blizzard_bar_modern")
