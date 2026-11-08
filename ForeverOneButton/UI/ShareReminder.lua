-- Forever One Button: the share reminder.
--
-- When there is a log worth sending, a chat line with a link that opens the
-- share window (UI/ShareWindow.lua) - as QuestieTrace does. Only:
--   - with the diagnostic log on (it is off by default) and at least
--     MIN_PLAYED seconds of play not shared yet (Share.Played);
--   - in a resting area (inn, city) and out of combat;
--   - at most once every INTERVAL seconds of real time, across /reload and
--     logout (ForeverOneButtonLog.remindedAt, time()). Opening the share
--     window counts as a reminder.
-- The link is the addon's own type, "fobshare:open", handled by
-- LinkUtil.RegisterLinkHandler, or by a hook on SetItemRef on clients
-- without it (hooksecurefunc: Blizzard's code runs unchanged).
local ADDON_NAME, ns = ...

local ShareReminder = {}
ns.ShareReminder = ShareReminder

ShareReminder.MIN_PLAYED = 1800
ShareReminder.INTERVAL = 3600
ShareReminder.LINK_TYPE = "fobshare"
ShareReminder.LINK = "|cff33ff99|Hfobshare:open|h[Share the log]|h|r"

local function Now()
    if type(time) ~= "function" then return nil end
    local ok, t = pcall(time)
    return ok and type(t) == "number" and t or nil
end

local function Resting()
    if type(IsResting) ~= "function" then return false end
    local ok, resting = pcall(IsResting)
    return ok and resting == true
end

function ShareReminder.MarkShown()
    if type(ForeverOneButtonLog) == "table" then ForeverOneButtonLog.remindedAt = Now() end
end

function ShareReminder.Due()
    if not ns.Diagnostics.IsEnabled() or ns.InCombat() or not Resting() then return false end
    local now = Now()
    local last = type(ForeverOneButtonLog) == "table" and ForeverOneButtonLog.remindedAt
    if not now or (type(last) == "number" and last <= now and now - last < ShareReminder.INTERVAL) then return false end
    local entries = ForeverOneButtonLog and ForeverOneButtonLog.entries
    return type(entries) == "table" and ns.Share.Played(entries) >= ShareReminder.MIN_PLAYED
end

function ShareReminder.Check()
    if not ShareReminder.Due() then return false end
    ShareReminder.MarkShown()
    ns.Print("you have a diagnostic log ready to send to the author, to help fix wrong suggestions: "
        .. ShareReminder.LINK)
    return true
end

-- "fobshare:open" -> the share window. True when the link was ours.
function ShareReminder.HandleLink(link)
    if type(link) ~= "string" then return false end
    local kind, action = link:match("^([^:]+):([^:|]+)")
    if kind ~= ShareReminder.LINK_TYPE or action ~= "open" then return false end
    ns.ShareWindow.Open()
    return true
end

local function RegisterLink()
    if type(LinkUtil) == "table" and type(LinkUtil.RegisterLinkHandler) == "function" then
        local registered = type(LinkUtil.IsLinkHandlerRegistered) == "function"
            and LinkUtil.IsLinkHandlerRegistered(ShareReminder.LINK_TYPE)
        if not registered then
            LinkUtil.RegisterLinkHandler(ShareReminder.LINK_TYPE, function(link) ShareReminder.HandleLink(link) end)
        end
        return "LinkUtil"
    end
    if type(hooksecurefunc) == "function" then
        hooksecurefunc("SetItemRef", function(link)
            if ShareReminder.HandleLink(link) and ItemRefTooltip and ItemRefTooltip.Hide then ItemRefTooltip:Hide() end
        end)
        return "SetItemRef"
    end
    return nil
end
ShareReminder.linkHandler = RegisterLink()

local frame = CreateFrame("Frame")
ShareReminder.frame = frame
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_ENABLED"}) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function()
    pcall(ShareReminder.Check)
end)
