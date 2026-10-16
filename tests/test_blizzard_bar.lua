-- Option: hide Blizzard's bottom bar; stance and experience bars stay; keys
-- and bindings untouched; protected changes out of combat only.
local H = dofile("tests/harness/wow.lua")

-- Classic-style layout: buttons and micro buttons inside the art frame, stance
-- and XP bars directly under MainMenuBar.
local main = CreateFrame("Frame", "MainMenuBar", UIParent)
local art = CreateFrame("Frame", "MainMenuBarArtFrame", main)
for i = 1, 12 do CreateFrame("CheckButton", "ActionButton" .. i, art, "SecureActionButtonTemplate, ActionButtonTemplate") end
CreateFrame("Button", "ActionBarUpButton", art)
CreateFrame("Button", "CharacterMicroButton", art)
CreateFrame("Button", "MainMenuBarBackpackButton", art)
CreateFrame("Button", "CharacterBag0Slot", art)
local stance = CreateFrame("Frame", "StanceBarFrame", main)
local xp = CreateFrame("StatusBar", "MainMenuExpBar", main)
H.bindingActions["1"] = "ACTIONBUTTON1"

local ns = H.Boot(nil, nil)
H.Equal(ActionButton1:GetAlpha(), 1, "visible by default")

-- Hide.
ns.Commands.Handle("blizzardbar hide")
H.Equal(ForeverOneButtonDB.hideBlizzardBar, true, "option saved")
for _, name in ipairs({"MainMenuBarArtFrame", "ActionButton1", "ActionButton12", "ActionBarUpButton",
    "CharacterMicroButton", "MainMenuBarBackpackButton", "CharacterBag0Slot"}) do
    H.Equal(_G[name]:GetAlpha(), 0, name .. " invisible")
    H.Equal(_G[name]:IsMouseEnabled(), false, name .. " click-through")
end
H.Equal(stance:GetAlpha(), 1, "stance bar untouched")
H.Equal(xp:GetAlpha(), 1, "experience bar untouched")
H.Equal(main:GetAlpha(), 1, "MainMenuBar itself untouched (it holds the stance and XP bars)")
H.Check(ActionButton1:IsShown(), "action button still shown (only transparent)")
H.Equal(ActionButton1:GetParent(), art, "nothing reparented")
H.Equal(H.bindingActions["1"], "ACTIONBUTTON1", "key binding untouched")
H.Equal(H.calls.SetBinding, nil, "no binding API called")

-- Blizzard re-showing on page change: hidden again.
ActionButton3:SetAlpha(1)
H.Fire("ACTIONBAR_PAGE_CHANGED")
H.Equal(ActionButton3:GetAlpha(), 0, "re-hidden after a page change")

-- In combat: nothing protected is touched; applied when combat ends.
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
local ok, message = ns.BlizzardBar.SetHidden(false)
H.Check(ok and message:find("combat"), "deferred in combat")
H.Equal(ActionButton1:GetAlpha(), 0, "unchanged in combat")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Equal(ActionButton1:GetAlpha(), 1, "restored after combat")
H.Equal(ActionButton1:IsMouseEnabled(), true, "mouse restored")
H.Equal(CharacterMicroButton:GetAlpha(), 1, "micro menu restored")

-- Layout where the stance bar lives inside the art frame: the art frame is
-- left alone (alpha is inherited), the buttons are still hidden.
stance.parent = art
ns.BlizzardBar.SetHidden(true)
H.Equal(art:GetAlpha(), 1, "art frame containing the stance bar is not hidden")
H.Equal(ActionButton1:GetAlpha(), 0, "buttons hidden")
H.Equal(stance:GetAlpha(), 1, "stance bar still visible")

-- Persisted across reload.
local saved = ForeverOneButtonDB
ActionButton1:SetAlpha(1)
ns = H.Boot(saved, ForeverOneButtonCharDB)
H.Equal(ActionButton1:GetAlpha(), 0, "hidden again at login")

-- Probe lists what exists.
ns.Commands.Handle("probe frames")
local text = table.concat(ForeverOneButtonLog.probeFrames, "\n")
H.Check(text:find("ActionButton1|parent MainMenuBarArtFrame"), "probe records frames and parents")
H.Check(text:find("StanceBarFrame%(kept%)"), "probe records kept frames")

H.Done("test_blizzard_bar")
