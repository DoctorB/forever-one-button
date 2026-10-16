-- Forever One Button: answers about secret values without reading them.
--
-- On Forever, health, power, cooldown timers and auras can be secret in
-- combat: Lua may hold them and pass them to the client, never compare them.
-- Two client mechanisms answer yes/no questions on our behalf:
--   * a curve evaluated by UnitHealthPercent / UnitPowerPercent maps "below
--     the threshold" to 100 and "at or above" to 0; the secret result is then
--     read only for zero / non-zero through C_StringUtil.TruncateWhenZero;
--   * a cooldown DurationObject drives a hidden Cooldown widget, whose
--     IsShown() is a plain boolean.
-- Each answer is true, false or nil (unknown). There is deliberately no
-- function that returns a number: one threshold per decision, never a search
-- for the hidden value.
local ADDON_NAME, ns = ...

local Secret = {}
ns.Secret = Secret

-- Two hidden font strings: one receives the secrets, the other only plain
-- text. A font string that once held a secret returns secret text for good,
-- so the plain readback check must never use the probe's own widget.
local function NewScratch()
    local ok, holder = pcall(CreateFrame, "Frame")
    if not ok or not holder then return false end
    holder:Hide()
    local okFS, fs = pcall(holder.CreateFontString, holder, nil, "BACKGROUND", "GameFontNormal")
    return okFS and fs or false
end

local probeText, checkText, probeArg
local function TextProbe()
    probeText:SetText(C_StringUtil.TruncateWhenZero(probeArg) or "")
    return probeText:GetText()
end

local function Scratches()
    if probeText == nil then probeText, checkText = NewScratch(), NewScratch() end
    return probeText and checkText
end

-- Does a plain text still come back at all? A dead readback and a real zero
-- both give no text.
local function ReadbackWorks()
    local ok, back = pcall(function() checkText:SetText("1"); return checkText:GetText() end)
    return ok and not ns.IsSecret(back) and back == "1"
end

-- true when v is zero, false when it is not, nil when that cannot be known.
function Secret.IsZero(v)
    if v == nil then return nil end
    if not ns.IsSecret(v) then
        if type(v) == "number" then return v == 0 end
        return nil
    end
    if not (C_StringUtil and C_StringUtil.TruncateWhenZero) or not Scratches() then return nil end
    probeArg = v
    local ok, text = pcall(TextProbe)
    probeArg = nil
    if not ok then return nil end
    -- Text came back: a real non-zero (a secret string is truthy, never
    -- compared). No text: zero, unless the readback itself stopped working,
    -- which a plain round trip on the other widget tells apart.
    if text and (ns.IsSecret(text) or text ~= "") then return false end
    if not ReadbackWorks() then return nil end
    return true
end

-- Threshold curves, one per percentage, self-tested on plain inputs.
local curves = {}
local function Curve(pct)
    local cached = curves[pct]
    if cached ~= nil then return cached or nil end
    curves[pct] = false
    local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and linear) then return nil end
    local ok, curve = pcall(function()
        local t = math.min(0.998, math.max(0.002, pct / 100))
        local c = C_CurveUtil.CreateCurve()
        c:SetType(linear)
        c:AddPoint(0, 100)
        c:AddPoint(t - 0.001, 100)
        c:AddPoint(t + 0.001, 0)
        c:AddPoint(1, 0)
        local low, high = c:Evaluate(t - 0.005), c:Evaluate(t + 0.005)
        if type(low) == "number" and type(high) == "number" and low >= 1 and high < 1 then return c end
    end)
    if ok and curve then curves[pct] = curve end
    return curves[pct] or nil
end

-- Is the unit's health (power) fraction below pct, asked of the client.
function Secret.Below(unit, pct, powerType)
    pct = math.floor(pct * 10 + 0.5) / 10
    local curve = Curve(pct)
    if not curve then return nil end
    local ok, result
    if powerType ~= nil then
        if not UnitPowerPercent then return nil end
        ok, result = pcall(UnitPowerPercent, unit, powerType, false, curve)
    else
        if not UnitHealthPercent then return nil end
        ok, result = pcall(UnitHealthPercent, unit, false, curve)
    end
    if not ok or result == nil then return nil end
    local zero = Secret.IsZero(result)
    if zero == nil then return nil end
    return not zero
end

-- Is a cooldown DurationObject running. nil when the widget cannot tell.
local scratchCooldown
function Secret.DurationActive(duration)
    if duration == nil then return false end
    if scratchCooldown == nil then
        scratchCooldown = false
        local ok, holder = pcall(CreateFrame, "Frame", nil, UIParent)
        if ok and holder then
            holder:Hide()
            local okCD, cd = pcall(CreateFrame, "Cooldown", nil, holder, "CooldownFrameTemplate")
            if okCD and cd and cd.SetCooldownFromDurationObject then scratchCooldown = cd end
        end
    end
    if not scratchCooldown then return nil end
    local ok, shown = pcall(function()
        scratchCooldown:SetCooldownFromDurationObject(duration)
        local s = scratchCooldown:IsShown()
        scratchCooldown:SetCooldown(0, 0)
        return s
    end)
    if not ok or ns.IsSecret(shown) then return nil end
    return shown and true or false
end
