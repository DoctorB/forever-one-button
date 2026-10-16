-- Forever One Button: interrupt suggestion.
--
-- When the target casts or channels, the best interrupt the character knows
-- and can use right now (Data/Interrupts.lua) is shown next to the grid and
-- its cell is marked. Lockout kicks come first; crowd control is the
-- fallback for shielded casts (mode "kickPrefer"), never used ("kickOnly")
-- or preferred ("ccPrefer"). Crowd control is skipped on bosses, fears unless
-- enabled. A secret "not interruptible" flag counts as interruptible, since
-- the cast itself is certain.
local ADDON_NAME, ns = ...

local Interrupts = {}
ns.Interrupts = Interrupts

Interrupts.KICK_DEBOUNCE = 1
Interrupts.CC_DEBOUNCE = 2
local MECH_FEAR = 5

-- Reliability tier, lower first: a kick locks the school and works on
-- bosses; a stun stops anything; a silence only magic; the rest are softer.
local TIER_BY_MECH = {[12] = 1, [9] = 2, [14] = 3, [2] = 4, [10] = 4, [5] = 5}
local function Tier(info)
    if info.kind == "interrupt" then return 0 end
    return TIER_BY_MECH[info.mech] or 6
end

local known -- sorted {first, info}, until spells change
function Interrupts.Invalidate() known = nil end

function Interrupts.Known()
    if known then return known end
    known = {}
    for first, info in pairs(ns.Data.Interrupts.abilities) do
        if ns.Ranks.HighestKnown(first) then known[#known + 1] = {first = first, info = info} end
    end
    table.sort(known, function(a, b)
        local ta, tb = Tier(a.info), Tier(b.info)
        if ta ~= tb then return ta < tb end
        local pa, pb = a.info.pri or 0, b.info.pri or 0
        if pa ~= pb then return pa < pb end
        return a.first < b.first
    end)
    return known
end

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

-- The target's cast: {texture, notInterruptible (true/false/nil)} or nil.
function Interrupts.TargetCast()
    if not (UnitCastingInfo and UnitChannelInfo) then return nil end
    local ok, name, _, texture, _, _, _, _, notInterruptible = pcall(UnitCastingInfo, "target")
    if ok and name ~= nil then return {texture = texture, notInterruptible = Plain(notInterruptible)} end
    local okChannel, channel, _, channelTexture, _, _, _, channelShield = pcall(UnitChannelInfo, "target")
    if okChannel and channel ~= nil then return {texture = channelTexture, notInterruptible = Plain(channelShield)} end
    return nil
end

local function Worthy()
    if not ns.State.TargetAttackable() then return false end
    local ok, classification = pcall(UnitClassification, "target")
    if ok and Plain(classification) == "minus" then return false end
    if UnitIsMinion then
        local okMinion, minion = pcall(UnitIsMinion, "target")
        if okMinion and Plain(minion) == true then return false end
    end
    return true
end

local function Reaches(info, id)
    if info.reach == "pbaoe" then return ns.State.TargetWithin(info.radius or 8) == true end
    return ns.State.InRange(id) ~= false
end

local function Ready(entry, isKick)
    local id = ns.Ranks.Pressed(entry.first)
    if not id then return nil end
    local since = ns.State.SecondsSinceCast(entry.first)
    if since and since < (isKick and Interrupts.KICK_DEBOUNCE or Interrupts.CC_DEBOUNCE) then return nil end
    local usable = ns.State.Usable(id)
    -- Kicks fail open on an unknown answer; crowd control does not.
    if usable == false or (not isKick and usable == nil) then return nil end
    if ns.State.OnCooldown(id) == true then return nil end
    if not Reaches(entry.info, id) then return nil end
    return id
end

-- {id, base, kind, castTexture} or nil.
function Interrupts.Suggest()
    if not ns.Settings.Feature("interrupts") then return nil end
    local cast = Interrupts.TargetCast()
    if not cast or not Worthy() then return nil end
    local mode = ns.Settings.Feature("interruptMode")
    local shielded = cast.notInterruptible == true
    local boss = ns.State.TargetIsBoss() == true
    local function Pick(wantKick)
        for _, entry in ipairs(Interrupts.Known()) do
            local isKick = entry.info.kind == "interrupt"
            local allowed = isKick == wantKick
            if not isKick and (boss or (entry.info.mech == MECH_FEAR and not ns.Settings.Feature("interruptFears"))) then
                allowed = false
            end
            if allowed then
                local id = Ready(entry, isKick)
                if id then return {id = id, base = entry.first, kind = entry.info.kind, castTexture = cast.texture} end
            end
        end
        return nil
    end
    if mode == "ccPrefer" then return Pick(false) or (not shielded and Pick(true)) or nil end
    if not shielded then
        local kick = Pick(true)
        if kick or mode == "kickOnly" then return kick end
        return nil
    end
    if mode == "kickOnly" then return nil end
    return Pick(false)
end

local frame = CreateFrame("Frame")
Interrupts.frame = frame
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", Interrupts.Invalidate)
