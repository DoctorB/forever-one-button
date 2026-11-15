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

-- Kinds of creature seen casting this session ("npc:<id>" from
-- Targets.Key): the rotation keeps rage for the kick against them.
local casters = {}

-- true when the target is of a kind seen casting, false when it is not,
-- nil when the target cannot be told apart.
function Interrupts.TargetIsCaster()
    local key = ns.Targets.Key()
    if not key then return nil end
    return casters[key] == true
end

function Interrupts.ForgetCasters() casters = {} end

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

-- The pressed rank, or nil and why not (written to the diagnostic log).
local function Ready(entry, isKick)
    local id = ns.Ranks.Pressed(entry.first)
    if not id then return nil, "rank" end
    local since = ns.State.SecondsSinceCast(entry.first)
    if since and since < (isKick and Interrupts.KICK_DEBOUNCE or Interrupts.CC_DEBOUNCE) then return nil, "recent" end
    local usable, noResources = ns.State.Usable(id)
    -- Kicks fail open on an unknown answer; crowd control does not.
    if usable == false or (not isKick and usable == nil) then return nil, noResources and "res" or "use" end
    if ns.State.OnCooldown(id) == true then return nil, "cd" end
    if ns.Targets.Allows(id) == false then return nil, "refused" end
    if not Reaches(entry.info, id) then return nil, "range" end
    return id
end

-- {id, base, kind, castTexture} or nil. Interrupts.why tells the log what
-- was decided while the target casts: nil without a cast, else "trivial"
-- (target not worth it), "none" (no interrupt known) or one
-- "<spell><+|-reason>" per ability tried, as in the queue line.
function Interrupts.Suggest()
    Interrupts.why = nil
    if not ns.Settings.Feature("interrupts") then return nil end
    local cast = Interrupts.TargetCast()
    if not cast then return nil end
    if not Worthy() then Interrupts.why = "trivial"; return nil end
    local key = ns.Targets.Key()
    if key then casters[key] = true end
    local tried = {}
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
                local id, reason = Ready(entry, isKick)
                tried[#tried + 1] = entry.first .. (id and "+" or ("-" .. reason))
                if id then return {id = id, base = entry.first, kind = entry.info.kind, castTexture = cast.texture} end
            end
        end
        return nil
    end
    local result
    if mode == "ccPrefer" then
        result = Pick(false) or (not shielded and Pick(true)) or nil
    elseif not shielded then
        result = Pick(true)
    elseif mode ~= "kickOnly" then
        result = Pick(false)
    end
    Interrupts.why = #tried > 0 and table.concat(tried, ",") or (shielded and "shielded" or "none")
    return result
end

local frame = CreateFrame("Frame")
Interrupts.frame = frame
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", Interrupts.Invalidate)
