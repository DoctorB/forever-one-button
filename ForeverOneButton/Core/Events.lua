-- Forever One Button: lifecycle.
-- ADDON_LOADED loads the dedicated SavedVariables; PLAYER_LOGIN builds the
-- layout and starts the refresh loop. Protected work missed in combat runs on
-- PLAYER_REGEN_ENABLED. No event ever generates input or runs an action.
local ADDON_NAME, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame", "ForeverOneButtonEvents", UIParent)
Events.frame = frame

local handlers = {}

handlers.ADDON_LOADED = function(name)
    if name ~= ADDON_NAME then return end
    ns.Settings.Load()
    ns.Diagnostics.Load()
end

handlers.PLAYER_LOGIN = function()
    if not ns.Settings.Get() then ns.Settings.Load() end
    ns.Pixel.ApplySettings()
    ns.Grid.ApplyLayout() -- deferred automatically after a /reload in combat
    ns.Grid.Refresh()
    ns.Model.Start()
    ns.AutoFill.Request()
    ns.BlizzardBar.Apply()
end

-- Blizzard may redraw its bar on these; the hidden state is applied again.
local function ReapplyBar()
    if ns.Settings.Get() and ns.Settings.Get().hideBlizzardBar then ns.BlizzardBar.Apply() end
end
handlers.PLAYER_ENTERING_WORLD = ReapplyBar
handlers.ACTIONBAR_PAGE_CHANGED = ReapplyBar
handlers.UPDATE_BONUS_ACTIONBAR = ReapplyBar

handlers.PLAYER_REGEN_DISABLED = function()
    ns.Options.CloseForCombat()
    ns.Grid.StopMoving() -- before the lockdown: the grid holds protected buttons
    ns.Log("combat", "in")
    ns.Model.Refresh() -- combat-only pixel starts at once
end

handlers.PLAYER_REGEN_ENABLED = function()
    ns.Log("combat", "out")
    if ns.Grid.pendingLayout then
        ns.Grid.ApplyLayout()
    elseif ns.Actions.pendingApply then
        ns.Actions.Apply()
    end
    if ns.AutoFill.pending then ns.AutoFill.Run() end
    if ns.BlizzardBar.pending then ns.BlizzardBar.Apply() end
    ns.Model.Refresh() -- combat-only pixel goes black at once
end

-- Icons follow spell overrides; learned spells, new ranks and spells put on
-- the action bars (their rank is the one a cell uses) trigger the automatic fill.
local function SpellsChanged()
    ns.Grid.Refresh()
    ns.AutoFill.Request()
end
handlers.SPELLS_CHANGED = SpellsChanged
handlers.PLAYER_SPECIALIZATION_CHANGED = SpellsChanged
handlers.ACTIONBAR_SLOT_CHANGED = function() ns.AutoFill.Request() end

-- Diagnostic Pixel acknowledgement edge (HCOneButton Core/Events.lua:144-145).
handlers.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    if ns.IsSecret(unit) or unit ~= "player" then return end
    local acknowledged = ns.Pixel.AcknowledgeCast(spellID)
    ns.Log("cast", spellID, acknowledged and 1 or 0)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)

-- Registration is guarded: the client rejects unknown event names, and the
-- Forever event list is only partly verified (docs/FOREVER_API_COMPATIBILITY.md).
Events.registered = {}
local function Register(event, unit)
    local ok
    if unit and frame.RegisterUnitEvent then
        ok = pcall(frame.RegisterUnitEvent, frame, event, unit)
    else
        ok = pcall(frame.RegisterEvent, frame, event)
    end
    Events.registered[event] = ok
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIONBAR_SLOT_CHANGED", "PLAYER_ENTERING_WORLD",
    "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR"}) do
    Register(event)
end
Register("UNIT_SPELLCAST_SUCCEEDED", "player")

Events.handlers = handlers
