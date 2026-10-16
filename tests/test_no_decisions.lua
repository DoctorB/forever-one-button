-- No HCOneButton decision logic, no automation, no spam/pull features
-- (spec section 8 "Assenza di decisioni HCOneButton", criteria 3 and 11).
local H = dofile("tests/harness/wow.lua")

-- 1. Static scan of the shipped code with comments removed.
local function StripComments(source)
    source = source:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (source:gsub("%-%-[^\n]*", ""))
end
local files = H.ReadToc("ForeverOneButton/ForeverOneButton.toc")
-- Decision vocabulary: allowed only in the suggestion engine (Engine/) and
-- its imported data (Data/).
local DECISION = {"Engine", "Recommend", "Rotation", "Priority", "Threat"}
local FORBIDDEN = {
    -- HCOneButton runtime and modules.
    "HCOB", "HCOneButton", "Advisor", "Readiness", "Survival",
    -- Excluded product features.
    "[Ss]pam", "[Pp]ull", "[Aa]uto[Aa]ttack", "[Aa]utoBind", "startattack",
    -- Input generation or action execution from Lua.
    "CastSpell", "UseAction", "RunMacro", "UseItemByName", "SpellStopCasting", "AttackTarget",
    "TargetNearest", "[^%w]SetBinding[%s%(C]", "SaveBindings", "SetOverrideBindingSpell",
    "SetOverrideBindingMacro", "macrotext", "C_Timer.NewTicker",
    -- Another advisor: Blizzard's assistant, JustAC or any shared library.
    "AssistedCombat", "GetNextCastSpell", "BlizzardAPI", "_Stage", "JustAC", "LibStub",
}
local hits = {}
-- Data/ holds imported tables only (checked by test_data.lua).
local codeFiles = {}
for _, file in ipairs(files) do
    if not file:match("^Data/") then codeFiles[#codeFiles + 1] = file end
end
for _, file in ipairs(codeFiles) do
    local handle = assert(io.open("ForeverOneButton/" .. file, "rb"))
    local code = StripComments(handle:read("*a"))
    handle:close()
    for _, pattern in ipairs(FORBIDDEN) do
        if code:find(pattern) then hits[#hits + 1] = file .. ": " .. pattern end
    end
    if not file:match("^Engine/") then
        -- Reading the imported lists (AutoFill, the probe) is not deciding.
        local outside = code:gsub("ns%.Data%.Rotations", "")
        for _, pattern in ipairs(DECISION) do
            if outside:find(pattern) then hits[#hits + 1] = file .. ": " .. pattern end
        end
    end
end
H.Check(#hits == 0, "forbidden symbols in shipped code: " .. table.concat(hits, ", "))

-- Only the timers/loops that exist, none of which runs an action:
-- the pixel ACK release and the AutoFill coalescing (C_Timer.After), and the
-- model OnUpdate poll.
local timerUses = 0
for _, file in ipairs(files) do
    local handle = assert(io.open("ForeverOneButton/" .. file, "rb"))
    local code = StripComments(handle:read("*a"))
    handle:close()
    for _ in code:gmatch("C_Timer%.After%(") do timerUses = timerUses + 1 end
    for _ in code:gmatch('"OnUpdate"') do timerUses = timerUses + 1 end
end
H.Equal(timerUses, 4, "C_Timer.After in pixel and AutoFill, OnUpdate set/cleared in the model")

-- 2. Runtime: HCOneButton entry points are tripwires.
local tripped = {}
local function Tripwire(name) return function() tripped[#tripped + 1] = name; error("HCOneButton " .. name .. " invoked") end end
HCOneButton = setmetatable({}, {__index = function(_, k) tripped[#tripped + 1] = "HCOneButton." .. k; return Tripwire(k) end})
for _, name in ipairs({"UpdateDiagnosticPixel", "Recommend", "UpdateDisplay", "EvaluatePrePullReadiness", "BuildMacros", "HCOB"}) do
    _G[name] = Tripwire(name)
end
HCOB_DB = setmetatable({}, {__index = function(_, k) tripped[#tripped + 1] = "HCOB_DB." .. k end})

local ns = H.Boot(nil)
H.spells[2687] = {name = "Bloodrage"}
H.Check(ns.Actions.Assign(1, "spell", 2687), "assign")
H.Check(ns.Actions.Bind(1, "SHIFT-1"), "bind")

-- No list, a failing build, then working queues; login, combat, casts.
H.Tick(0.2)
local lib = H.InstallQueue()
lib.Remove()
H.Tick(0.2)
lib.Fail("engine failure")
H.Tick(0.2)
for _, queue in ipairs({{2687}, {}, {lib.WAIT}, {9999}, {2687, 6603, 284, 6546}}) do
    lib.Set(queue)
    H.Tick(0.1)
    H.inCombat = true
    H.Fire("PLAYER_REGEN_DISABLED")
    H.Tick(0.1)
    H.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 2687)
    H.Tick(0.1)
    H.inCombat = false
    H.Fire("PLAYER_REGEN_ENABLED")
    H.Fire("SPELLS_CHANGED")
end
-- When the build fails, nothing is recommended: no marks, black pixel.
lib.Fail("engine failure")
H.Tick(0.2)
for slot = 1, 20 do H.Equal(ns.Grid.buttons[slot].positionText:GetText(), "", "no suggestion on cell " .. slot) end
local r, g, b = H.Pixel255()
H.Equal(r + g + b, 0, "no fallback recommendation in the pixel")

-- Every slash command, including names of excluded features.
for _, command in ipairs({"", "status", "bindings", "spam on", "pull", "pullready", "rotation", "advisor on",
    "autobind on", "assign 2 spell 2687", "pixel unlock", "pixel lock", "show", "hide", "lock", "unlock", "reset"}) do
    ns.Commands.Handle(command)
end
H.Check(SlashCmdList.FOREVERONEBUTTON == ns.Commands.Handle, "single slash handler")

H.Equal(#tripped, 0, "HCOneButton touched: " .. table.concat(tripped, ", "))
-- No action ever ran: no secure button was clicked by code.
for slot = 1, 20 do H.Equal(ns.Grid.buttons[slot].scripts.OnClick, nil, "no Lua OnClick on cell " .. slot) end
H.Done("test_no_decisions")
