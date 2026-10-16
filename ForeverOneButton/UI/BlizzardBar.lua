-- Forever One Button: hide Blizzard's bottom bar (owner decision, 2026-10-15).
--
-- Makes the main action bar, its art and page arrows, the micro menu and the
-- bag buttons invisible and click-through. The stance bar and the experience
-- bar stay as they are: they are never touched. Nothing is moved, unbound or
-- disabled, so the action bar keys keep working.
--
-- Frame names differ between client versions and are not verified on
-- Forever: candidates from the classic and the modern UI are tried and only
-- the ones that exist are changed. /fob probe frames records which exist.
-- Action buttons are protected, so changes happen out of combat only.
local ADDON_NAME, ns = ...

local BlizzardBar = {}
ns.BlizzardBar = BlizzardBar

local function Names()
    local names = {
        -- main bar art and paging (classic layout, then modern)
        "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground", "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap", "MainMenuBarPageNumber", "ActionBarUpButton", "ActionBarDownButton",
        "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
        "MainMenuBarMaxLevelBar",
        -- modern layout, as found on Forever 1.60.1.70374 (/fob probe frames,
        -- 2026-10-15): the buttons sit in MainActionBarButtonContainer1..12 of
        -- MainActionBar, which also draws the dividers, paging and background;
        -- the stance and status bars are separate children of UIParent.
        "MainActionBar", "MainMenuBar",
        -- micro menu
        "MicroButtonAndBagsBar", "MicroMenuContainer", "MicroMenu",
        "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton",
        "SocialsMicroButton", "GuildMicroButton", "WorldMapMicroButton", "MainMenuMicroButton",
        "HelpMicroButton", "LFGMicroButton", "PVPMicroButton", "CollectionsMicroButton",
        "AchievementMicroButton", "EJMicroButton", "StoreMicroButton", "ProfessionMicroButton",
        "PlayerSpellsMicroButton", "HousingMicroButton",
        -- bags
        "BagsBar", "BagBarExpandToggle", "MainMenuBarBackpackButton", "CharacterBag0Slot",
        "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot",
        "KeyRingButton",
    }
    for i = 1, 12 do
        names[#names + 1] = "ActionButton" .. i
        names[#names + 1] = "MainActionBarButtonContainer" .. i
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, name in ipairs(MICRO_BUTTONS) do
            if type(name) == "string" then names[#names + 1] = name end
        end
    end
    return names
end
BlizzardBar.Names = Names

-- Never changed, whatever the candidate list says.
BlizzardBar.KEEP = {
    StanceBar = true, StanceBarFrame = true, StanceButton1 = true,
    MainMenuExpBar = true, ExhaustionTick = true, ReputationWatchBar = true,
    StatusTrackingBarManager = true, MainStatusTrackingBarContainer = true,
    SecondaryStatusTrackingBarContainer = true,
}

BlizzardBar.saved = {}   -- name -> {alpha, mouse} before hiding
BlizzardBar.pending = false

-- True when `frame` contains a kept bar: alpha is inherited, so hiding it
-- would hide the stance or experience bar too.
local function ContainsKept(frame)
    for name in pairs(BlizzardBar.KEEP) do
        local kept = _G[name]
        local depth = 0
        while type(kept) == "table" and kept.GetParent and depth < 20 do
            kept = ns.SafeCall(kept.GetParent, kept)
            if kept == frame then return true end
            depth = depth + 1
        end
    end
    return false
end

local function Frame(name)
    if BlizzardBar.KEEP[name] then return nil end
    local frame = _G[name]
    if type(frame) ~= "table" or type(frame.SetAlpha) ~= "function" then return nil end
    if ContainsKept(frame) then return nil end
    return frame
end

local function Hide()
    for _, name in ipairs(Names()) do
        local frame = Frame(name)
        if frame then
            if not BlizzardBar.saved[name] then
                local alpha = frame.GetAlpha and ns.SafeCall(frame.GetAlpha, frame) or 1
                local mouse = frame.IsMouseEnabled and ns.SafeCall(frame.IsMouseEnabled, frame)
                BlizzardBar.saved[name] = {alpha = alpha, mouse = mouse}
            end
            pcall(frame.SetAlpha, frame, 0)
            if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
        end
    end
end

local function Restore()
    for name, state in pairs(BlizzardBar.saved) do
        local frame = Frame(name)
        if frame then
            pcall(frame.SetAlpha, frame, state.alpha or 1)
            if frame.EnableMouse and state.mouse ~= nil then pcall(frame.EnableMouse, frame, state.mouse) end
        end
    end
    wipe(BlizzardBar.saved)
end

-- Applies the saved option. Out of combat only; otherwise after combat.
function BlizzardBar.Apply()
    if ns.InCombat() then
        BlizzardBar.pending = true
        return false
    end
    BlizzardBar.pending = false
    if ns.Settings.Get().hideBlizzardBar then Hide() else Restore() end
    return true
end

function BlizzardBar.SetHidden(hidden)
    ns.Settings.Get().hideBlizzardBar = hidden and true or false
    if not BlizzardBar.Apply() then return true, "applied when combat ends" end
    return true
end

-- Names of the candidates that exist on this client (for the probe).
function BlizzardBar.Found()
    local found = {}
    for _, name in ipairs(Names()) do
        if Frame(name) then found[#found + 1] = name end
    end
    for name in pairs(BlizzardBar.KEEP) do
        if type(_G[name]) == "table" then found[#found + 1] = name .. "(kept)" end
    end
    return found
end
