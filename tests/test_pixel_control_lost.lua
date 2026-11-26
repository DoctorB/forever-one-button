-- Stunned, feared or charmed: the pixel publishes protocol black until
-- control comes back (battleground log of 2026-11-22: 369 presses refused
-- with "Can't do that while stunned/fleeing" in 91 minutes). Roots and
-- silences do not stop it; without the loss-of-control API the full-control
-- flag decides.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local lib = H.InstallQueue()
H.spells[100] = {name = "A"}
H.Check(ns.Actions.Assign(1, "spell", 100), "assign")
lib.Set({100})

H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Tick(0.1)
H.Equal(select(1, H.Pixel255()), 12, "slot 1 published in combat")

H.lossOfControl = {{locType = "STUN_MECHANIC"}}
H.Tick(0.1)
H.Equal(ns.Model.pixelHead, nil, "no head while stunned")
H.Equal(ns.Model.observation.controlled, true, "observation says controlled")
H.Equal(ns.State.ControlLost(), true, "stun is a loss of control")

H.lossOfControl = {}
H.Tick(0.1)
H.Equal(ns.Model.pixelHead, 100, "head back when the stun ends")
H.Equal(select(1, H.Pixel255()), 12, "slot 1 published again")

for _, kind in ipairs({"FEAR", "FEAR_MECHANIC", "CHARM", "CONFUSE", "INCAPACITATE", "POLYMORPH", "SLEEP"}) do
    H.lossOfControl = {{locType = kind}}
    H.Equal(ns.State.ControlLost(), true, kind .. " is a loss of control")
end
for _, kind in ipairs({"ROOT", "SNARE", "SILENCE", "DISARM", "SCHOOL_INTERRUPT"}) do
    H.lossOfControl = {{locType = kind}}
    H.Equal(ns.State.ControlLost(), false, kind .. " leaves the pixel on")
end
H.lossOfControl = {{locType = "ROOT"}}
H.Tick(0.1)
H.Equal(ns.Model.pixelHead, 100, "rooted: the pixel keeps pressing")
H.lossOfControl = {}

-- Without the loss-of-control API: HasFullControl decides.
local api = C_LossOfControl
C_LossOfControl = nil
_G.HasFullControl = function() return false end
local lost, source = ns.State.ControlLost()
H.Equal(lost, true, "no full control is a loss of control")
H.Equal(source, "full", "source full")
_G.HasFullControl = function() return true end
H.Equal(ns.State.ControlLost(), false, "full control")
_G.HasFullControl = nil
H.Equal(ns.State.ControlLost(), false, "unknown never blocks")
C_LossOfControl = api

-- Battleground log of 2026-11-25: the loss-of-control list stayed empty
-- through every stun and fear (351 refused presses). The other readings
-- answer then: the full-control flag, and the client's refusal of a press.
H.lossOfControl = {}
_G.HasFullControl = function() return false end
lost, source = ns.State.ControlLost()
H.Equal(lost, true, "empty list, no full control: lost")
H.Equal(source, "full", "source full with the list readable")
_G.HasFullControl = function() return true end
H.Equal(ns.State.ControlLost(), false, "empty list, full control")
H.Tick(0.1)
H.Equal(ns.Model.pixelHead, 100, "pixel on before the refusal")
H.Fire("UI_ERROR_MESSAGE", 57, "Can't do that while stunned")
H.Equal(ns.Model.pixelHead, nil, "refused press: black at once, without a poll")
lost, source = ns.State.ControlLost()
H.Equal(lost, true, "refused press: lost")
H.Equal(source, "refused", "source refused")
H.Tick(ns.State.REFUSED_CONTROL_SECONDS + 0.1)
H.Equal(ns.Model.pixelHead, 100, "pixel back after the hold")
for _, message in ipairs({"Can't attack while stunned.", "Can't do that while incapacitated",
    "Can't do that while fleeing", "Can't do that while charmed", "Can't do that while sapped"}) do
    H.Fire("UI_ERROR_MESSAGE", 57, message)
    H.Equal(ns.State.ControlLost(), true, message)
    H.Tick(ns.State.REFUSED_CONTROL_SECONDS + 0.1)
end
for _, message in ipairs({"Can't do that while frozen", "Ability is not ready yet.", "Not enough rage",
    "Target needs to be in front of you."}) do
    H.Fire("UI_ERROR_MESSAGE", 57, message)
    H.Equal(ns.State.ControlLost(), false, message .. " keeps the pixel on")
end
H.Fire("UI_ERROR_MESSAGE", 57, H.Secret())
H.Equal(ns.State.ControlLost(), false, "secret message ignored")
_G.HasFullControl = nil

H.Done("test_pixel_control_lost")
