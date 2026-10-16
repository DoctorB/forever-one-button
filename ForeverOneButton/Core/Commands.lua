-- Forever One Button: /fob slash commands.
-- Only bindings, cell assignments and the whitelisted UI/pixel settings.
local ADDON_NAME, ns = ...

local Commands = {}
ns.Commands = Commands

local function Done(ok, message)
    if message then ns.Print(message) elseif ok then ns.Print("done") else ns.Print("change refused") end
end

local function ResolveSpell(text)
    local id = tonumber(text)
    if id then return id end
    if not C_Spell or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local info = ns.SafeCall(C_Spell.GetSpellInfo, text)
    if type(info) == "table" and ns.Readable(info.spellID) then return info.spellID end
    return nil
end

local function Status()
    local snapshot = ns.Model.snapshot
    ns.Print(string.format("suggestions: %s%s, tree %s, context %s, queue length %d", snapshot.status,
        snapshot.detail and (" (" .. tostring(snapshot.detail) .. ")") or "", tostring(snapshot.tree or "-"),
        tostring(snapshot.context or "-") .. (snapshot.leveling and " (leveling list)" or ""), snapshot.count or 0))
    local head = ns.Model.pixelHead
    ns.Print(string.format("pixel: %s, %s; head %s; %s", ns.Settings.Get().pixel.enabled and "shown" or "hidden",
        tostring(ns.Pixel.lastState), head and tostring(head) or "none",
        ns.Settings.Get().pixel.combatOnly and (ns.InCombat() and "combat only: active" or "combat only: idle (out of combat)")
            or "always active"))
    ns.Print(string.format("autofill: %s, %s%s", ns.Settings.Get().autoFill and "on" or "off", ns.AutoFill.status,
        ns.AutoFill.overflow > 0 and (", " .. ns.AutoFill.overflow .. " spells did not fit") or ""))
    if ns.Actions.pendingApply or ns.Grid.pendingLayout or ns.AutoFill.pending then ns.Print("changes pending until combat ends") end
end

local function Bindings()
    local rows = ns.Actions.Report()
    if #rows == 0 then return ns.Print("no cells or keys configured") end
    for _, row in ipairs(rows) do
        local action = row.cell and (row.cell.kind .. " " .. row.cell.id .. (row.cell.auto and " (auto)" or "")) or "empty"
        local notes = {}
        if row.missingKey then notes[#notes + 1] = "no key" end
        if row.defaultKey then notes[#notes + 1] = "default key" end
        if row.emptyCell then notes[#notes + 1] = "key on empty cell" end
        if row.shadowed then notes[#notes + 1] = "overrides " .. row.shadowed end
        if row.hidden then notes[#notes + 1] = "cell hidden" end
        ns.Print(string.format("cell %d: %s, key %s%s", row.slot, action, row.key or "-",
            #notes > 0 and (" [" .. table.concat(notes, "; ") .. "]") or ""))
    end
end

local HELP = {
    "/fob - open options",
    "/fob status | bindings",
    "/fob assign <cell> spell <id|name> | assign <cell> item <id> | clear <cell>",
    "/fob bind <cell> <key> | unbind <cell> | defaultkey <cell>",
    "/fob autofill on | off | now | reset",
    "/fob features | feature <name> on | off | <value>  (engine features)",
    "/fob log on | off | show | clear  (diagnostic log of pixel and casts)",
    "/fob probe spellbook | probe frames  (read-only client data for development)",
    "/fob blizzardbar hide | show  (Blizzard's bottom bar; stance and XP bars stay)",
    "/fob show | hide | lock | unlock | reset",
    "/fob pixel on | off | lock | unlock | reset | combat on | combat off",
}

local function Features()
    local names = {}
    for name in pairs(ns.Settings.FEATURES) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local value = ns.Settings.Feature(name)
        if type(value) == "boolean" then value = value and "on" or "off" end
        ns.Print(name .. ": " .. tostring(value))
    end
end

local function SetFeature(typed, text)
    local name
    for key in pairs(ns.Settings.FEATURES) do
        if key:lower() == tostring(typed):lower() then name = key end
    end
    local spec = name and ns.Settings.FEATURES[name]
    if not spec then return ns.Print("unknown feature; /fob features lists them") end
    local value = text
    if spec.kind == "boolean" then
        if text == "on" then value = true elseif text == "off" then value = false else value = nil end
    elseif spec.kind == "number" then
        value = tonumber(text)
    end
    Done(ns.Settings.SetFeature(name, value))
end

function Commands.Handle(input)
    local args = {}
    for word in tostring(input or ""):gmatch("%S+") do args[#args + 1] = word end
    local command = (args[1] or ""):lower()

    if command == "" or command == "options" or command == "config" then
        ns.Options.Open()
    elseif command == "features" then
        Features()
    elseif command == "feature" then
        SetFeature(args[2], args[3])
    elseif command == "status" then
        Status()
    elseif command == "bindings" or command == "keys" then
        Bindings()
    elseif command == "assign" then
        local kind = (args[3] or ""):lower()
        local value = table.concat(args, " ", 4)
        local id = kind == "spell" and ResolveSpell(value) or tonumber(value)
        if not id then return ns.Print("unknown " .. (kind ~= "" and kind or "action") .. ": " .. value) end
        Done(ns.Actions.Assign(args[2], kind, id))
    elseif command == "clear" then
        Done(ns.Actions.Clear(args[2]))
    elseif command == "bind" then
        Done(ns.Actions.Bind(args[2], args[3]))
    elseif command == "unbind" then
        Done(ns.Actions.Unbind(args[2]))
    elseif command == "defaultkey" then
        Done(ns.Actions.DefaultKey(args[2]))
    elseif command == "probe" and (args[2] or ""):lower() == "spellbook" then
        local _, message = ns.Probe.Spellbook()
        ns.Print(message)
    elseif command == "probe" and (args[2] or ""):lower() == "frames" then
        local _, message = ns.Probe.Frames()
        ns.Print(message)
    elseif command == "blizzardbar" then
        local sub = (args[2] or ""):lower()
        if sub == "hide" or sub == "show" then Done(ns.BlizzardBar.SetHidden(sub == "hide"))
        else ns.Print("/fob blizzardbar hide | show") end
    elseif command == "log" then
        local sub = (args[2] or ""):lower()
        if sub == "on" or sub == "off" then
            ns.Diagnostics.SetEnabled(sub == "on")
            ns.Print("diagnostic log " .. sub .. (sub == "on" and "; /reload or log out to write it to disk" or ""))
        elseif sub == "show" then ns.Diagnostics.Show(tonumber(args[3]))
        elseif sub == "clear" then ns.Diagnostics.Clear(); Done(true)
        else ns.Print("/fob log on | off | show [lines] | clear") end
    elseif command == "autofill" then
        local sub = (args[2] or ""):lower()
        if sub == "on" or sub == "off" then ns.AutoFill.SetEnabled(sub == "on"); Done(true)
        elseif sub == "now" then ns.AutoFill.Run(); ns.Print("autofill: " .. ns.AutoFill.status)
        elseif sub == "reset" then Done(ns.AutoFill.ResetDismissed())
        else ns.Print("/fob autofill on | off | now | reset") end
    elseif command == "show" or command == "hide" then
        Done(ns.Grid.SetShown(command == "show"))
    elseif command == "lock" or command == "unlock" then
        Done(ns.Grid.SetLocked(command == "lock"))
    elseif command == "reset" then
        Done(ns.Settings.ResetLayout())
    elseif command == "pixel" then
        local sub = (args[2] or ""):lower()
        if sub == "on" or sub == "off" then ns.Pixel.SetEnabled(sub == "on")
        elseif sub == "lock" or sub == "unlock" then ns.Pixel.SetLocked(sub == "lock")
        elseif sub == "reset" then ns.Pixel.ResetPosition()
        elseif sub == "combat" and (args[3] == "on" or args[3] == "off") then ns.Pixel.SetCombatOnly(args[3] == "on")
        else return ns.Print("/fob pixel on | off | lock | unlock | reset | combat on | combat off") end
        Done(true)
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
    ns.Options.Refresh()
end

SLASH_FOREVERONEBUTTON1 = "/fob"
SLASH_FOREVERONEBUTTON2 = "/foreveronebutton"
SlashCmdList = SlashCmdList or {}
SlashCmdList.FOREVERONEBUTTON = Commands.Handle
