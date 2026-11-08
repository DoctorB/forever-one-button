-- Forever One Button: the share window (/fob share).
--
-- Shows the address and the line to copy (Core/Share.lua). Closing the
-- window keeps the log; only "I sent it" removes the entries that were
-- shown, so a share that never reached the site can be made again.
-- The line is in a single-line box on purpose: a multi-line box stalls the
-- client on very long text, while Ctrl+A / Ctrl+C still copy all of it.
local ADDON_NAME, ns = ...

local ShareWindow = {}
ns.ShareWindow = ShareWindow

local frame
local pending -- the share on screen, until "I sent it"

local function ReadOnly(box, text)
    box.fixed = text
    box:SetText(text)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(self.fixed)
            self:HighlightText()
        end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
end

local function Box(parent, anchor, y)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(400, 20)
    box:SetPoint("TOP", anchor, "BOTTOM", 0, y)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    return box
end

local function Build()
    frame = CreateFrame("Frame", "ForeverOneButtonShare", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(460, 250)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverOneButtonShare") end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(ns.TITLE .. ": share the diagnostic log")

    local step1 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    step1:SetPoint("TOPLEFT", 20, -36)
    step1:SetText("1. Open this address in your browser:")
    frame.url = Box(frame, step1, -6)
    frame.url:SetPoint("LEFT", 26, 0)
    ReadOnly(frame.url, ns.Share.URL)

    local step2 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    step2:SetPoint("TOPLEFT", step1, "BOTTOMLEFT", 0, -38)
    step2:SetText("2. Click the line below, press Ctrl+A, Ctrl+C, and paste it there:")
    frame.line = Box(frame, step2, -6)
    frame.line:SetPoint("LEFT", 26, 0)
    frame.line:SetMaxLetters(0)

    frame.stats = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.stats:SetPoint("TOPLEFT", step2, "BOTTOMLEFT", 0, -38)
    frame.stats:SetWidth(420)
    frame.stats:SetJustifyH("LEFT")

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", frame.stats, "BOTTOMLEFT", 0, -8)
    note:SetWidth(420)
    note:SetJustifyH("LEFT")
    note:SetText("Spells, game messages and timings only: your character and realm names are removed.")

    frame.sent = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.sent:SetSize(120, 22)
    frame.sent:SetPoint("BOTTOMLEFT", 20, 14)
    frame.sent:SetText("I sent it")
    frame.sent:SetScript("OnClick", function() ShareWindow.Sent() end)
    frame.sent:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click after the site has accepted the log: the shared entries are removed so they are not sent twice.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame.sent:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(100, 22)
    close:SetPoint("BOTTOMRIGHT", -20, 14)
    close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)
end

local function Duration(seconds)
    if type(seconds) ~= "number" or seconds < 0 then return "?" end
    local minutes = math.floor(seconds / 60 + 0.5)
    if minutes < 60 then return minutes .. " min" end
    return string.format("%d h %02d min", math.floor(minutes / 60), minutes % 60)
end

function ShareWindow.Open()
    local share, reason = ns.Share.Build()
    if not share then
        pending = nil
        if reason == "empty" then
            ns.Print("the diagnostic log is empty: /fob log on, play a while, then /fob share")
        end
        return false
    end
    if not frame then Build() end
    pending = share
    ReadOnly(frame.line, share.text)
    frame.stats:SetText(string.format("%d entries, about %s of play, %d KB to paste%s.",
        share.entries, Duration(share.played),
        math.ceil(#share.text / 1024), share.compressed and "" or " (not compressed)"))
    frame.sent:Show()
    frame:Show()
    frame.line:SetFocus()
    frame.line:HighlightText()
    return true
end

function ShareWindow.Sent()
    if not pending then return end
    local removed = ns.Share.Forget(pending.last)
    pending = nil
    if frame then frame:Hide() end
    ns.Print(string.format("thank you: %d shared entries removed from the log", removed))
end
