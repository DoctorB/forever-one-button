-- Offline WoW client mock for Forever One Button tests (Lua 5.1).
--
-- It models only what the addon uses, plus the rules the tests must enforce:
--   * protected operations (secure attributes, override bindings, moving or
--     showing secure buttons and their ancestors) raise while in combat;
--   * secret values are userdata that raise on comparison, arithmetic,
--     concatenation and tostring, like restricted values on the client.
-- A mock is not the client: passing here proves nothing about Forever itself.
local H = {}

H.now = 100
H.inCombat = false
H.timers = {}
H.violations = {}
H.overrideBindings = {}     -- key -> {owner, command}
H.bindingActions = {}       -- key -> normal binding action
H.printed = {}
H.frames = {}
H.calls = {}                -- counters for forbidden/automation APIs

local function violation(message)
    H.violations[#H.violations + 1] = message
    error("ADDON_ACTION_BLOCKED: " .. message, 3)
end

-- Secret values ---------------------------------------------------------
local secretSet = setmetatable({}, {__mode = "k"})
local secretMeta
local function secretError() error("attempt to use a secret value", 2) end
function H.Secret()
    local value = newproxy(true)
    local mt = getmetatable(value)
    for _, name in ipairs({"__eq", "__lt", "__le", "__add", "__sub", "__mul", "__div",
        "__mod", "__pow", "__unm", "__concat", "__len", "__index", "__newindex", "__call"}) do
        mt[name] = secretError
    end
    mt.__tostring = secretError
    secretSet[value] = true
    return value
end
function issecretvalue(value) return secretSet[value] == true end
local inaccessibleTables = setmetatable({}, {__mode = "k"})
function H.MakeInaccessible(t) inaccessibleTables[t] = true end
function canaccesstable(t) return not inaccessibleTables[t] end

-- Regions ----------------------------------------------------------------
local Region = {}
Region.__index = Region
local function NewRegion(kind, parent, layer)
    return setmetatable({kind = kind, parent = parent, layer = layer, shown = true, points = {}, text = "", alpha = 1}, Region)
end
function Region:SetColorTexture(r, g, b, a)
    self.color = {r, g, b, a}
    if H.recordColors == false then return end
    self.colorHistory = self.colorHistory or {}
    self.colorHistory[#self.colorHistory + 1] = {r, g, b, a}
end
function Region:SetTexture(t) self.texture = t end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetVertexColor() end
function Region:SetAllPoints(target) self.allPoints = target or self.parent end
function Region:SetPoint(...) self.points[#self.points + 1] = {...} end
function Region:ClearAllPoints() self.points = {} end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end
function Region:SetText(t) self.text = t end
function Region:GetText() return self.text end
function Region:SetTextColor() end
function Region:SetJustifyH() end
function Region:SetWordWrap() end

-- Frames -----------------------------------------------------------------
local Frame = {}
Frame.__index = Frame

local function IsSecure(frame)
    return frame.template ~= nil and frame.template:find("Secure") ~= nil
end
-- A frame is protected when it is secure or has a secure descendant.
local function IsProtected(frame)
    if IsSecure(frame) then return true end
    for _, child in ipairs(frame.children) do
        if IsProtected(child) then return true end
    end
    return false
end
local function Guard(frame, operation)
    if H.inCombat and IsProtected(frame) then
        violation(operation .. " on protected " .. tostring(frame.name or frame.type) .. " in combat")
    end
end

function CreateFrame(frameType, name, parent, template)
    local frame = setmetatable({
        type = frameType, name = name, parent = parent, template = template,
        points = {}, attributes = {}, scripts = {}, events = {}, children = {},
        regions = {}, shown = true, scale = 1, width = 0, height = 0, level = 1,
    }, Frame)
    if parent and parent.children then parent.children[#parent.children + 1] = frame end
    if name then _G[name] = frame end
    H.frames[#H.frames + 1] = frame
    return frame
end

function Frame:CreateTexture(_, layer)
    local r = NewRegion("Texture", self, layer); self.regions[#self.regions + 1] = r; return r
end
function Frame:CreateFontString(_, layer)
    local r = NewRegion("FontString", self, layer); self.regions[#self.regions + 1] = r; return r
end
function Frame:SetSize(w, h) Guard(self, "SetSize"); self.width, self.height = w, h end
function Frame:SetWidth(w) Guard(self, "SetWidth"); self.width = w end
function Frame:SetHeight(h) Guard(self, "SetHeight"); self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetPoint(point, relativeTo, relativePoint, x, y)
    Guard(self, "SetPoint")
    if type(relativeTo) ~= "table" then
        -- SetPoint(point, x, y) or SetPoint(point) shorthand: relative to parent.
        if type(relativeTo) == "number" then relativeTo, relativePoint, x, y = nil, nil, relativeTo, relativePoint end
        relativeTo = nil
    end
    self.points[#self.points + 1] = {point, relativeTo or self.parent, relativePoint or point, x or 0, y or 0}
end
function Frame:ClearAllPoints() Guard(self, "ClearAllPoints"); self.points = {} end
function Frame:SetAllPoints(target)
    self.points = {{"TOPLEFT", target or self.parent, "TOPLEFT", 0, 0}, {"BOTTOMRIGHT", target or self.parent, "BOTTOMRIGHT", 0, 0}}
end
function Frame:GetPoint(index)
    local p = self.points[index or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
end
function Frame:SetFrameStrata(s) self.strata = s end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetFrameLevel(l) self.level = l end
function Frame:GetFrameLevel() return self.level end
function Frame:EnableMouse(e) Guard(self, "EnableMouse"); self.mouse = e end
function Frame:IsMouseEnabled() return self.mouse ~= false end
function Frame:SetAlpha(a) Guard(self, "SetAlpha"); self.alpha = a end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetParent() return self.parent end
function Frame:GetName() return self.name end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetObjectType() return self.type end
function Frame:EnableMouseWheel(e) self.mouseWheel = e end
function Frame:EnableKeyboard(e) self.keyboard = e end
function Frame:SetPropagateKeyboardInput(e) self.propagate = e end
function Frame:SetMovable(m) self.movable = m end
function Frame:SetClampedToScreen(c) self.clamped = c end
function Frame:RegisterForDrag(...) self.dragButtons = {...} end
function Frame:RegisterForClicks(...) Guard(self, "RegisterForClicks"); self.clickButtons = {...} end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event, fn) self.scripts[event] = fn end
function Frame:Show() Guard(self, "Show"); self.shown = true end
function Frame:Hide() Guard(self, "Hide"); self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    local f = self
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
function Frame:SetScale(s) Guard(self, "SetScale"); self.scale = s end
function Frame:GetScale() return self.scale end
function Frame:GetEffectiveScale()
    local scale, f = 1, self
    while f do scale = scale * (f.scale or 1); f = f.parent end
    return scale
end
function Frame:SetAttribute(name, value)
    if H.inCombat and IsProtected(self) then violation("SetAttribute(" .. name .. ") in combat") end
    self.attributes[name] = value
end
function Frame:GetAttribute(name) return self.attributes[name] end
function Frame:RegisterEvent(event)
    if H.unknownEvents and H.unknownEvents[event] then error("unknown event " .. event) end
    self.events[event] = true
end
function Frame:RegisterUnitEvent(event, unit) self.events[event] = unit or true end
function Frame:StartMoving() Guard(self, "StartMoving"); self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:SetUserPlaced(u) self.userPlaced = u end
function Frame:SetText(t) self.text = t end
function Frame:SetChecked(c) self.checked = c end
function Frame:GetChecked() return self.checked end
function Frame:Click(button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end

-- Screen geometry. Offsets are in the frame's own scale, as on the client.
local POINT_FACTORS = {
    TOPLEFT = {0, 1}, TOP = {0.5, 1}, TOPRIGHT = {1, 1}, LEFT = {0, 0.5}, CENTER = {0.5, 0.5},
    RIGHT = {1, 0.5}, BOTTOMLEFT = {0, 0}, BOTTOM = {0.5, 0}, BOTTOMRIGHT = {1, 0},
}
function H.ScreenRect(frame)
    if frame == UIParent then
        local s = UIParent.scale
        return 0, 0, UIParent.width * s, UIParent.height * s
    end
    local p = frame.points[1]
    if not p then return nil end
    local rl, rb, rw, rh = H.ScreenRect(p[2])
    if not rl then return nil end
    local scale = frame:GetEffectiveScale()
    local rf = POINT_FACTORS[p[3]]
    local ax, ay = rl + rf[1] * rw + p[4] * scale, rb + rf[2] * rh + p[5] * scale
    local w, h = frame.width * scale, frame.height * scale
    if p[1] == "TOPLEFT" and frame.points[2] and frame.points[2][1] == "BOTTOMRIGHT" then
        local _, _, rw2, rh2 = H.ScreenRect(frame.points[2][2])
        w, h = rw2, rh2
    end
    local f = POINT_FACTORS[p[1]]
    return ax - f[1] * w, ay - f[2] * h, w, h
end
function Frame:GetRect()
    local l, b, w, h = H.ScreenRect(self)
    if not l then return nil end
    local s = self:GetEffectiveScale()
    return l / s, b / s, w / s, h / s
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent.width, UIParent.height = 1920, 1080

-- Client globals -----------------------------------------------------------
function GetTime() return H.now end
C_Timer = {}
function C_Timer.After(delay, callback)
    H.timers[#H.timers + 1] = {at = H.now + delay, delay = delay, callback = callback}
end
function H.Advance(seconds)
    H.now = H.now + seconds
    local ran = true
    while ran do
        ran = false
        for i, timer in ipairs(H.timers) do
            if timer.at <= H.now + 1e-9 then
                table.remove(H.timers, i)
                timer.callback()
                ran = true
                break
            end
        end
    end
end
function InCombatLockdown() return H.inCombat end
function GetCVarBool(name) return name == "ActionButtonUseKeyDown" and H.useKeyDown or false end
function GetBindingAction(key) return H.bindingActions[key] or "" end
function ClearOverrideBindings(owner)
    if H.inCombat then violation("ClearOverrideBindings in combat") end
    for key, binding in pairs(H.overrideBindings) do
        if binding.owner == owner then H.overrideBindings[key] = nil end
    end
end
function SetOverrideBindingClick(owner, priority, key, buttonName, mouseButton)
    if H.inCombat then violation("SetOverrideBindingClick in combat") end
    H.overrideBindings[key] = {owner = owner, command = "CLICK " .. buttonName .. ":" .. (mouseButton or "LeftButton")}
end
H.cursor = nil
function GetCursorInfo() if H.cursor then return unpack(H.cursor) end end
function ClearCursor() H.cursor = nil end
function IsShiftKeyDown() return H.shift end
function IsControlKeyDown() return H.ctrl end
function IsAltKeyDown() return H.alt end
function UnitExists(unit) return unit == "target" and H.target ~= nil end
H.casting, H.channeling = nil, nil
function UnitCastingInfo(unit) if unit == "player" then return H.casting end end
function UnitChannelInfo(unit) if unit == "player" then return H.channeling end end

H.spells = {}   -- id -> {name, icon, override, inRange}
H.items = {}    -- id -> {name, icon, spell}
C_Spell = {}
function C_Spell.GetSpellName(id) local s = H.spells[id]; return s and s.name end
function C_Spell.GetSpellTexture(id) local s = H.spells[id]; return s and s.icon end
function C_Spell.GetOverrideSpell(id) local s = H.spells[id]; return s and s.override or id end
function C_Spell.IsSpellInRange(id) local s = H.spells[id]; if s then return s.inRange end end
function C_Spell.GetSpellInfo(query)
    for id, s in pairs(H.spells) do
        if id == query or s.name == query then return {spellID = id, name = s.name} end
    end
end
C_Item = {}
function C_Item.GetItemNameByID(id) local i = H.items[id]; return i and i.name end
function C_Item.GetItemIconByID(id) local i = H.items[id]; return i and i.icon end
function C_Item.GetItemSpell(id) local i = H.items[id]; if i and i.spell then return "use", i.spell end end

-- Automation and decision APIs the addon must never touch. Any call counts.
for _, name in ipairs({"CastSpellByName", "CastSpellByID", "UseAction", "RunMacro", "RunMacroText",
    "UseItemByName", "SpellStopCasting", "TargetNearestEnemy", "AttackTarget", "StartAttack",
    "SetBinding", "SetBindingClick", "SaveBindings", "SetOverrideBindingSpell", "SetOverrideBinding",
    "SetOverrideBindingMacro"}) do
    _G[name] = function() H.calls[name] = (H.calls[name] or 0) + 1 end
end

DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) H.printed[#H.printed + 1] = m end}
GameTooltip = {SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end}
UISpecialFrames = {}
SlashCmdList = {}
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- LibStub ------------------------------------------------------------------
H.libs = {}
LibStub = setmetatable({}, {__call = function(self, major, silent) return self:GetLibrary(major, silent) end})
function LibStub:GetLibrary(major, silent)
    local entry = H.libs[major]
    if not entry then
        if silent then return nil end
        error("Cannot find a library instance of " .. tostring(major))
    end
    return entry.lib, entry.minor
end
function LibStub:NewLibrary(major, minor)
    local entry = H.libs[major]
    if entry and entry.minor >= minor then return nil end
    H.libs[major] = {lib = entry and entry.lib or {}, minor = minor}
    return H.libs[major].lib
end

-- A JustAC-SpellQueue stand-in that mirrors the verified shape: one shared
-- table, wiped and refilled in place, returned by a dot-called function.
function H.InstallJustAC(minor)
    local lib = LibStub:NewLibrary("JustAC-SpellQueue", minor or 43)
    lib.WAIT_SENTINEL = -999999999
    local shared = {}
    lib._shared = shared
    lib.calls = 0
    function lib.GetCurrentSpellQueue(...)
        assert(select("#", ...) == 0, "GetCurrentSpellQueue takes no arguments")
        lib.calls = lib.calls + 1
        return shared
    end
    function lib.SetQueue(ids)
        wipe(shared)
        for i, id in ipairs(ids) do shared[i] = id end
    end
    return lib
end

-- JustAC-BlizzardAPI stand-in: only the pool function AutoFill reads.
function H.InstallJustACPool(ids)
    H.libs["JustAC-BlizzardAPI"] = H.libs["JustAC-BlizzardAPI"] or {lib = {}, minor = 36}
    local lib = H.libs["JustAC-BlizzardAPI"].lib
    lib.pool = ids
    lib.poolCalls = 0
    function lib.GetRotationSpells(...)
        assert(select("#", ...) == 0, "GetRotationSpells called with arguments")
        lib.poolCalls = lib.poolCalls + 1
        return lib.pool
    end
    return lib
end

-- Addon loader -------------------------------------------------------------
H.ADDON = "ForeverOneButton"
function H.ReadToc(path)
    local files, fields = {}, {}
    for line in io.lines(path) do
        line = line:gsub("\r$", "")
        local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then fields[key] = value
        elseif line:match("%S") and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files, fields
end

function H.LoadAddon(root)
    root = root or "ForeverOneButton"
    local ns = {}
    local files = H.ReadToc(root .. "/ForeverOneButton.toc")
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(root .. "/" .. file))
        chunk(H.ADDON, ns)
    end
    H.ns = ns
    return ns
end

function H.Fire(event, ...)
    for _, frame in ipairs(H.frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end

-- Full start: load files, ADDON_LOADED, PLAYER_LOGIN.
function H.Boot(savedVariables, characterVariables)
    -- A second Boot simulates /reload: the previous UI stops receiving events.
    for _, frame in ipairs(H.frames) do
        if frame ~= UIParent then frame.events = {}; frame.scripts = {} end
    end
    H.frames = {UIParent}
    H.timers = {}
    ForeverOneButtonDB = savedVariables
    ForeverOneButtonCharDB = characterVariables
    local ns = H.LoadAddon()
    H.Fire("ADDON_LOADED", H.ADDON)
    H.Fire("PLAYER_LOGIN")
    return ns
end

-- Runs the refresh loop for `seconds` in 10 ms frames.
function H.Tick(seconds)
    local driver = _G.ForeverOneButtonDriver
    local steps = math.max(1, math.floor((seconds or 0.05) / 0.01 + 0.5))
    for _ = 1, steps do
        H.Advance(0.01)
        local onUpdate = driver.scripts.OnUpdate
        if onUpdate then onUpdate(driver, 0.01) end
    end
end

-- Test helpers -------------------------------------------------------------
H.failures = 0
function H.Check(condition, label)
    if not condition then error("FAIL: " .. label, 2) end
end
function H.Equal(actual, wanted, label)
    if actual ~= wanted then
        error(string.format("FAIL: %s: expected %s, got %s", label, tostring(wanted), tostring(actual)), 2)
    end
end
function H.Pixel255()
    local c = _G.ForeverOneButtonDiagPixel.regions[1].color
    local function b(v) return math.floor(v * 255 + 0.5) end
    return b(c[1]), b(c[2]), b(c[3]), c[4]
end
function H.Done(name)
    H.Check(#H.violations == 0, "protected-operation violations: " .. table.concat(H.violations, "; "))
    for api, count in pairs(H.calls) do error("FAIL: forbidden API " .. api .. " called " .. count .. " times") end
    print(name .. ": PASS")
end

-- Game state for the suggestion engine -----------------------------------
-- H.units[unit] = {health, healthMax, power = {[type] = n}, powerMax = {...},
-- attackable, dead, classification, level, threat}. With H.secretStats the
-- health/power reads return secrets that carry their value, which only the
-- engine-side comparisons (curves, TruncateWhenZero) can use.
H.units = {}
H.secretStats = false
H.known = {}            -- spellID -> true (IsPlayerSpell)
H.actions = {}          -- slot -> spellID on the action bars
H.forms = {}            -- shapeshift form index -> spellID
H.activeForm = nil      -- active form index
H.auras = {player = {}, target = {}}  -- unit -> spellID -> {applications, expirationTime}
H.aurasHiddenInCombat = true
H.stealthed = false
H.comboPoints = 0
H.totems = {}           -- slot -> true

local hiddenValue = setmetatable({}, {__mode = "k"})
function H.SecretOf(value)
    local secret = H.Secret()
    hiddenValue[secret] = value
    return secret
end
local function Hidden(v) if issecretvalue(v) then return hiddenValue[v] end return v end
local function MaybeSecret(v)
    if H.secretStats and v ~= nil then return H.SecretOf(v) end
    return v
end

local function Unit(unit) return H.units[unit] end
function UnitExists(unit)
    if H.units[unit] then return true end
    return unit == "target" and H.target ~= nil
end
function UnitHealth(unit) local u = Unit(unit); return u and MaybeSecret(u.health) end
function UnitHealthMax(unit) local u = Unit(unit); return u and u.healthMax end
function UnitPower(unit, powerType) local u = Unit(unit); return u and u.power and MaybeSecret(u.power[powerType or 1]) end
function UnitPowerMax(unit, powerType) local u = Unit(unit); return u and u.powerMax and u.powerMax[powerType or 1] end
local function Fraction(current, max)
    if type(current) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    return current / max
end
function UnitHealthPercent(unit, _, curve)
    local u = Unit(unit)
    local f = u and Fraction(u.health, u.healthMax)
    if f == nil then return nil end
    return MaybeSecret(curve and curve:Evaluate(f) or f)
end
function UnitPowerPercent(unit, powerType, _, curve)
    local u = Unit(unit)
    local f = u and u.power and Fraction(u.power[powerType or 1], u.powerMax[powerType or 1])
    if f == nil then return nil end
    return MaybeSecret(curve and curve:Evaluate(f) or f)
end
function UnitCanAttack(_, unit) local u = Unit(unit); return u ~= nil and u.attackable == true end
function UnitIsDeadOrGhost(unit) local u = Unit(unit); return u ~= nil and u.dead == true end
function UnitClassification(unit) local u = Unit(unit); return u and (u.classification or "normal") end
function UnitLevel(unit) local u = Unit(unit); return u and (u.level or 10) end
function UnitThreatSituation(_, unit) local u = Unit(unit); return u and u.threat end

Enum = Enum or {}
Enum.LuaCurveType = {Linear = 0, Step = 1}
C_CurveUtil = {}
function C_CurveUtil.CreateCurve()
    local curve = {points = {}}
    function curve:SetType(t) self.type = t end
    function curve:AddPoint(x, y) self.points[#self.points + 1] = {x, y} end
    function curve:Evaluate(x)
        local p = self.points
        if x <= p[1][1] then return p[1][2] end
        for i = 2, #p do
            if x <= p[i][1] then
                local x0, y0, x1, y1 = p[i - 1][1], p[i - 1][2], p[i][1], p[i][2]
                if x1 == x0 then return y1 end
                return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
            end
        end
        return p[#p][2]
    end
    return curve
end
C_StringUtil = {}
-- Integer text of the value rounded down, nil for zero; secret in, secret out.
function C_StringUtil.TruncateWhenZero(v)
    local n = Hidden(v)
    if type(n) ~= "number" or math.floor(n) == 0 then return nil end
    local text = tostring(math.floor(n))
    if issecretvalue(v) then return H.SecretOf(text) end
    return text
end

-- Spells: H.spells[id] gains usable (default true), noResources, cooldown
-- (true = real cooldown running), onGCD.
function IsPlayerSpell(id) return H.known[id] == true end
function IsSpellKnown(id) return H.known[id] == true end
function GetActionInfo(slot) local id = H.actions[slot]; if id then return "spell", id end end
function C_Spell.IsSpellUsable(id)
    local s = H.spells[id]
    if not s then return false, false end
    return s.usable ~= false, s.noResources == true
end
function C_Spell.GetSpellCooldownDuration(id)
    local s = H.spells[id]
    return {active = s ~= nil and s.cooldown == true}
end
function C_Spell.GetSpellCooldown(id)
    local s = H.spells[id]
    return {isOnGCD = s and s.onGCD or nil, isActive = s ~= nil and s.cooldown == true,
        startTime = H.secretStats and H.Secret() or 0, duration = H.secretStats and H.Secret() or 0}
end
function Frame:SetCooldownFromDurationObject(d) self.shown = d ~= nil and d.active == true end
function Frame:SetCooldown() self.shown = false end

function GetNumShapeshiftForms() return #H.forms end
function GetShapeshiftFormInfo(i) return nil, H.activeForm == i, true, H.forms[i] end
function GetShapeshiftForm() return H.activeForm or 0 end
C_UnitAuras = {}
local function Aura(unit, id)
    if H.aurasHiddenInCombat and H.inCombat then return nil end
    local list = H.auras[unit]
    local a = list and list[id]
    if not a then return nil end
    return {auraInstanceID = id, applications = a.applications or 0, expirationTime = a.expirationTime or 0}
end
function C_UnitAuras.GetPlayerAuraBySpellID(id) return Aura("player", id) end
function C_UnitAuras.GetUnitAuraBySpellID(unit, id) return Aura(unit, id) end
function IsStealthed() return H.stealthed end
function GetComboPoints() return H.comboPoints end
function GetTotemInfo(slot) return H.totems[slot] == true end

return H
