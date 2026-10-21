-- Forever One Button: Diagnostic Pixel, HCOneButton RGB protocol v3.
--
-- Ported from HCOneButton (MIT, (c) 2026 DoctorB), HCOneButton/UI/DiagnosticPixel.lua
-- at e973acb (file last changed in 6baa93c). The frozen original is kept in
-- tests/fixtures/hcob/DiagnosticPixel.lua and tests/test_pixel_differential.lua
-- proves both produce the same colour stream. Unchanged from the original:
--   * the colour formula and the two special colours;
--   * 8x8 frame parented to UIParent, TOOLTIP strata, mouse disabled,
--     OVERLAY colour texture filling the frame, black at creation;
--   * the 60 ms black acknowledgement edge and its release timer (only the
--     clock it is measured on differs, see below).
-- Adapted, with the reason:
--   * slot source: the cell that executes the queue's position-1 action
--     (ns.Actions.SlotFor) replaces HCOB.UI.ActionPanel.idToSlot;
--   * anchor: an independent anchor frame instead of HCOneButton's Advisor
--     frame, which does not exist here; never the grid (see ARCHITECTURE.md);
--   * SurvivalStrip.ManualUsePending() is removed with the excluded strip;
--   * the 60 ms edge is timed on the precise clock instead of GetTime, so
--     it lasts at least 60 ms from the cast event (see PixelNow);
--   * cast matching guards secret values before comparing.
--
-- RGB protocol v3: the color encodes ONLY the fixed slot.
-- The colour carries neither the class nor the spell.
-- R = slot * 12, G = 96, B = 224.
-- Black = no recommended action; white = unmapped recommendation.
local ADDON_NAME, ns = ...

local Pixel = {}
ns.Pixel = Pixel

-- Anchor that carries the user-chosen position. The pixel hangs off its
-- TOPLEFT exactly as HCOneButton's pixel hangs off the Advisor's TOPRIGHT.
local anchor = CreateFrame("Frame", "ForeverOneButtonPixelAnchor", UIParent)
anchor:SetSize(8, 8)
anchor:SetFrameStrata("TOOLTIP")
anchor:EnableMouse(false)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
Pixel.anchor = anchor

local diagPixel = CreateFrame("Frame", "ForeverOneButtonDiagPixel", UIParent)
diagPixel:SetSize(8, 8)
diagPixel:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
diagPixel:SetFrameStrata("TOOLTIP")
diagPixel:EnableMouse(false)
local diagPixelTex = diagPixel:CreateTexture(nil, "OVERLAY")
diagPixelTex:SetAllPoints()
diagPixelTex:SetColorTexture(0, 0, 0, 1)
Pixel.frame = diagPixel
Pixel.texture = diagPixelTex

-- 20 ms is one frame at 50 Hz. Keep a completed recommendation black for
-- 60 ms so the screen always shows a nil edge before the
-- next recommendation, including when the same spell is recommended again.
local ACK_GAP_SECONDS = 0.060
Pixel.ACK_GAP_SECONDS = ACK_GAP_SECONDS
local desiredSpellID = nil
local suppressionUntil = 0
local acknowledgementToken = 0

-- The edge is timed on the precise clock, from the moment the black is
-- written. The original used GetTime (frame start): with the cast event
-- handled 20-30 ms into the frame, the black was on screen for only 40-58 ms
-- (diagnostic log of 2026-10-21, build 70450). With one clock for frame and
-- event (tests) both behave identically.
local function PixelNow()
    return ns.Diagnostics.Now()
end

-- Last colour written, for /fob status and tests: "black", "white" or a slot.
Pixel.lastState = "black"

local function RenderDiagnosticPixel(spellId)
    if not diagPixelTex then return end
    if not spellId then
        diagPixelTex:SetColorTexture(0, 0, 0, 1)
        Pixel.lastState = "black"
        ns.Log("pixel", "black", ns.Diagnostics.FrameTime())
        return
    end

    local slot = ns.Actions.SlotFor(spellId)
    if slot then
        diagPixelTex:SetColorTexture((slot * 12) / 255, 96 / 255, 224 / 255, 1)
        Pixel.lastState = slot
    else
        diagPixelTex:SetColorTexture(1, 1, 1, 1)
        Pixel.lastState = "white"
    end
    ns.Log("pixel", Pixel.lastState, ns.Diagnostics.FrameTime(), ns.Diagnostics.Describe(slot))
end

function Pixel.Update(spellId)
    desiredSpellID = spellId
    if PixelNow() < suppressionUntil then
        RenderDiagnosticPixel(nil)
        return
    end
    RenderDiagnosticPixel(spellId)
end

local function NameOfSpell(spellID)
    local name = ns.SpellName(spellID)
    if type(name) == "string" then return name end
    return nil
end

-- The spell a queue item entry casts, so its UNIT_SPELLCAST_SUCCEEDED can be
-- recognised. C_Item.GetItemSpell returns name, spellID.
local function ItemSpellID(itemID)
    if not C_Item or type(C_Item.GetItemSpell) ~= "function" then return nil end
    local ok, _, spellID = pcall(C_Item.GetItemSpell, itemID)
    if not ok or not ns.Readable(spellID) or type(spellID) ~= "number" then return nil end
    return spellID
end

local function SameEncodedSpell(castSpellID)
    if not desiredSpellID or not ns.Readable(castSpellID) then return false end
    local cast = tonumber(castSpellID)
    if not cast then return false end
    local wanted = desiredSpellID
    if wanted < 0 then
        wanted = ItemSpellID(-wanted)
        if not wanted then return false end
    end
    if wanted == cast then return true end
    local wantedName = NameOfSpell(wanted)
    local castName = NameOfSpell(cast)
    return wantedName ~= nil and wantedName == castName
end

local SchedulePixelRelease
SchedulePixelRelease = function(token, delay)
    if not C_Timer or not C_Timer.After then return end
    C_Timer.After(math.max(0.001, delay), function()
        if token ~= acknowledgementToken then return end
        local remaining = suppressionUntil - PixelNow()
        if remaining > 0.001 then
            SchedulePixelRelease(token, remaining)
            return
        end
        RenderDiagnosticPixel(desiredSpellID)
    end)
end

function Pixel.AcknowledgeCast(castSpellID)
    if not SameEncodedSpell(castSpellID) then return false end
    acknowledgementToken = acknowledgementToken + 1
    suppressionUntil = PixelNow() + ACK_GAP_SECONDS
    RenderDiagnosticPixel(nil)
    SchedulePixelRelease(acknowledgementToken, ACK_GAP_SECONDS)
    return true
end

-- Re-render after the slot table changed (cells assigned or cleared).
function Pixel.Rerender()
    if PixelNow() < suppressionUntil then return end
    RenderDiagnosticPixel(desiredSpellID)
end

-- Position and visibility. Only these UI settings touch the pixel; none of
-- them changes its size, strata, parent, scale or colours.
function Pixel.ApplySettings()
    local settings = ns.Settings.Get().pixel
    local p = settings.point
    anchor:ClearAllPoints()
    anchor:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    if settings.enabled then diagPixel:Show() else diagPixel:Hide() end
    Pixel.ApplyLock()
end

-- Unlocked: a handle drawn around (never over) the pixel lets the user drag
-- the anchor. The pixel itself keeps EnableMouse(false).
local handle
local function EnsureHandle()
    if handle then return handle end
    handle = CreateFrame("Frame", "ForeverOneButtonPixelHandle", UIParent)
    handle:SetSize(28, 28)
    handle:SetPoint("TOPLEFT", anchor, "TOPLEFT", -10, 10)
    handle:SetFrameStrata("DIALOG")
    local function Edge(point, relative, width, height)
        local tex = handle:CreateTexture(nil, "ARTWORK")
        tex:SetColorTexture(1, 0.82, 0.1, 0.9)
        tex:SetSize(width, height)
        tex:SetPoint(point, handle, relative, 0, 0)
    end
    -- Four 2 px edges: the 8x8 pixel area in the middle stays uncovered.
    Edge("TOPLEFT", "TOPLEFT", 28, 2)
    Edge("BOTTOMLEFT", "BOTTOMLEFT", 28, 2)
    Edge("TOPLEFT", "TOPLEFT", 2, 28)
    Edge("TOPRIGHT", "TOPRIGHT", 2, 28)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() anchor:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local point, _, relative, x, y = anchor:GetPoint(1)
        ns.Settings.Get().pixel.point = {point, relative, x, y}
    end)
    return handle
end

function Pixel.ApplyLock()
    local locked = ns.Settings.Get().pixel.locked
    if locked then
        if handle then handle:Hide() end
    else
        EnsureHandle():Show()
    end
end

function Pixel.SetEnabled(enabled)
    ns.Settings.Get().pixel.enabled = enabled and true or false
    Pixel.ApplySettings()
end

function Pixel.SetLocked(locked)
    ns.Settings.Get().pixel.locked = locked and true or false
    Pixel.ApplyLock()
end

-- Combat-only publication is decided in Bridge/Model.lua; this only stores
-- the choice and refreshes.
function Pixel.SetCombatOnly(enabled)
    ns.Settings.Get().pixel.combatOnly = enabled and true or false
    if ns.Model and ns.Model.Refresh then ns.Model.Refresh() end
end

function Pixel.ResetPosition()
    local d = ns.Settings.DEFAULT_PIXEL_POINT
    ns.Settings.Get().pixel.point = {d[1], d[2], d[3], d[4]}
    Pixel.ApplySettings()
end
