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
-- Coming back from AFK is also a good moment (the player is at the screen,
-- idle): then the resting-area condition does not apply.
--
-- With the log off, coming back from AFK may instead show the invitation to
-- turn it on, with two links: [Turn on the log] and [No thanks]. At most
-- INVITE_MAX times per account, INVITE_INTERVAL apart, never again after
-- "No thanks" or once the log has been turned on (ForeverOneButtonLog.invite).
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
ShareReminder.INVITE_MAX = 3
ShareReminder.INVITE_INTERVAL = 7 * 24 * 3600
ShareReminder.LINK_LOG_ON = "|cff33ff99|Hfobshare:logon|h[Turn on the log]|h|r"
ShareReminder.LINK_NO_THANKS = "|cff9d9d9d|Hfobshare:nothanks|h[No thanks]|h|r"

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

-- fromAfk: the player just came back from AFK (no resting-area condition).
function ShareReminder.Due(fromAfk)
    if not ns.Diagnostics.IsEnabled() or ns.InCombat() or not (fromAfk or Resting()) then return false end
    local now = Now()
    local last = type(ForeverOneButtonLog) == "table" and ForeverOneButtonLog.remindedAt
    if not now or (type(last) == "number" and last <= now and now - last < ShareReminder.INTERVAL) then return false end
    local entries = ForeverOneButtonLog and ForeverOneButtonLog.entries
    return type(entries) == "table" and ns.Share.Played(entries) >= ShareReminder.MIN_PLAYED
end

function ShareReminder.Check(fromAfk)
    if not ShareReminder.Due(fromAfk) then return false end
    ShareReminder.MarkShown()
    ns.Print("you have a diagnostic log ready to send to the author, to help fix wrong suggestions: "
        .. ShareReminder.LINK)
    return true
end

local function Invite()
    return type(ForeverOneButtonLog) == "table" and type(ForeverOneButtonLog.invite) == "table"
        and ForeverOneButtonLog.invite or nil
end

function ShareReminder.InviteDue()
    local invite = Invite()
    if not invite or invite.declined or ns.Diagnostics.IsEnabled() or ns.InCombat() then return false end
    if invite.count >= ShareReminder.INVITE_MAX then return false end
    local now = Now()
    if not now then return false end
    return not (type(invite.at) == "number" and invite.at <= now and now - invite.at < ShareReminder.INVITE_INTERVAL)
end

function ShareReminder.InviteCheck()
    if not ShareReminder.InviteDue() then return false end
    local invite = Invite()
    invite.count = invite.count + 1
    invite.at = Now()
    ns.Print("would you like to help make Forever One Button better? Turn on the diagnostic log and play as usual."
        .. " Later you can send it to the author with /fob share: nothing is ever sent without you. "
        .. ShareReminder.LINK_LOG_ON .. "  " .. ShareReminder.LINK_NO_THANKS)
    return true
end

-- Back from AFK: the share reminder with the log on, the invitation without.
function ShareReminder.BackFromAfk()
    if ns.Diagnostics.IsEnabled() then return ShareReminder.Check(true) end
    return ShareReminder.InviteCheck()
end

-- "fobshare:open" -> the share window; "fobshare:logon" and
-- "fobshare:nothanks" answer the invitation. True when the link was ours.
function ShareReminder.HandleLink(link)
    if type(link) ~= "string" then return false end
    local kind, action = link:match("^([^:]+):([^:|]+)")
    if kind ~= ShareReminder.LINK_TYPE then return false end
    local invite = Invite()
    if action == "open" then
        ns.ShareWindow.Open()
    elseif action == "logon" then
        if invite then invite.declined = true end
        if not ns.Diagnostics.IsEnabled() then ns.Diagnostics.SetEnabled(true) end
        ns.Print("thank you! The diagnostic log is on. Play as usual; when you have played a while,"
            .. " /fob share shows how to send it. /fob log off turns it off.")
    elseif action == "nothanks" then
        if invite then invite.declined = true end
        ns.Print("no problem, you will not be asked again. You can turn the log on any time with /fob log on.")
    else
        return false
    end
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

local function Afk()
    if type(UnitIsAFK) ~= "function" then return false end
    local ok, afk = pcall(UnitIsAFK, "player")
    return ok and not ns.IsSecret(afk) and afk == true
end

local wasAfk = false
local frame = CreateFrame("Frame")
ShareReminder.frame = frame
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_ENABLED",
        "PLAYER_FLAGS_CHANGED"}) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_FLAGS_CHANGED" then
        if unit ~= "player" then return end
        local afk = Afk()
        local back = wasAfk and not afk
        wasAfk = afk
        if back then pcall(ShareReminder.BackFromAfk) end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then wasAfk = Afk() end
    pcall(ShareReminder.Check)
end)
