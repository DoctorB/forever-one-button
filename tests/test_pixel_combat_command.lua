-- /fob pixel on | off (and the other pixel subcommands) work in combat: the
-- pixel and its anchor are plain frames, never protected, so the command is
-- never deferred or refused, and the pixel shows the current recommendation
-- at once when it comes back on.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local lib = H.InstallQueue()
H.spells[100] = {name = "A"}
H.Check(ns.Actions.Assign(1, "spell", 100), "assign")
lib.Set({100})

local pixel = _G.ForeverOneButtonDiagPixel
local function Slash(text)
    H.printed = {}
    SlashCmdList.FOREVERONEBUTTON(text)
    return table.concat(H.printed, "\n")
end

H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Tick(0.1)
H.Equal(select(1, H.Pixel255()), 12, "slot 1 published in combat")

local printed = Slash("pixel off")
H.Check(printed:find("done", 1, true) ~= nil, "pixel off answers done in combat: " .. printed)
H.Check(not printed:find("combat", 1, true), "pixel off is not refused in combat: " .. printed)
H.Equal(pixel:IsShown(), false, "pixel hidden in combat")
H.Equal(ForeverOneButtonDB.pixel.enabled, false, "setting stored")

-- The recommendation keeps being encoded while hidden.
lib.Set({})
H.Tick(0.1)
lib.Set({100})
H.Tick(0.1)

printed = Slash("pixel on")
H.Check(printed:find("done", 1, true) ~= nil, "pixel on answers done in combat: " .. printed)
H.Equal(pixel:IsShown(), true, "pixel shown in combat")
H.Equal(ForeverOneButtonDB.pixel.enabled, true, "setting stored")
local r, g, b = H.Pixel255()
H.Equal(r .. "," .. g .. "," .. b, "12,96,224", "current recommendation visible at once")

-- The other pixel subcommands are not combat-gated either.
for _, command in ipairs({"pixel unlock", "pixel lock", "pixel reset", "pixel combat off", "pixel combat on"}) do
    printed = Slash(command)
    H.Check(printed:find("done", 1, true) ~= nil, command .. " answers done in combat: " .. printed)
end
H.Equal(ForeverOneButtonDB.pixel.locked, true, "locked again")
H.Equal(ForeverOneButtonDB.pixel.combatOnly, true, "combat only again")

-- Nothing was deferred to the end of combat.
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Tick(0.1)
H.Equal(pixel:IsShown(), true, "still shown after combat")

H.Done("test_pixel_combat_command")
