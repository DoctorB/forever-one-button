-- Minimap button: shown by default on the minimap edge, left-click toggles
-- the options, right-click locks/unlocks the grid, drag saves the angle,
-- the Layout option hides it.
local H = dofile("tests/harness/wow.lua")

local ns = H.Boot(nil, nil)
local b = _G.ForeverOneButtonMinimapButton
H.Check(b ~= nil, "button created at login")
H.Equal(b.parent, Minimap, "parented to the minimap")
H.Check(b.shown, "shown by default")
H.Equal(ns.Settings.Get().minimap.angle, 225, "default angle")
H.Equal(b.icon.texture, "Interface\\AddOns\\ForeverOneButton\\Media\\icon", "add-on logo")
H.Equal(b.template, nil, "plain button, nothing secure")

-- Offset on the edge: 0 degrees is right of the centre, 90 above it.
local x, y = ns.MinimapButton.Offset(0, 140)
H.Equal(math.floor(x + 0.5), 80, "radius just outside the edge")
H.Equal(math.floor(y + 0.5), 0, "angle 0 on the right")
H.Equal(ns.MinimapButton.AngleOf(0, 10), 90, "above is 90")
H.Equal(ns.MinimapButton.AngleOf(-10, -10), 225, "lower left is 225")

-- Left-click toggles the options.
b.scripts.OnClick(b, "LeftButton")
H.Check(ns.Options.IsShown(), "left-click opens the options")
b.scripts.OnClick(b, "LeftButton")
H.Check(not ns.Options.IsShown(), "second left-click closes them")

-- Right-click locks and unlocks the grid.
local locked = ns.Settings.Get().grid.locked
b.scripts.OnClick(b, "RightButton")
H.Equal(ns.Settings.Get().grid.locked, not locked, "right-click toggles the grid lock")
b.scripts.OnClick(b, "RightButton")
H.Equal(ns.Settings.Get().grid.locked, locked, "and back")

-- In combat the options refuse to open; the button does not fail.
H.inCombat = true
b.scripts.OnClick(b, "LeftButton")
H.Check(not ns.Options.IsShown(), "options stay closed in combat")
H.inCombat = false

-- Drag: the angle follows the cursor around the minimap centre.
Minimap.centerX, Minimap.centerY = 1000, 500
H.cursor_x, H.cursor_y = 1000, 600
b.scripts.OnDragStart(b)
H.Check(b.scripts.OnUpdate ~= nil, "drag follows the cursor")
b.scripts.OnUpdate(b, 0.02)
H.Equal(ns.Settings.Get().minimap.angle, 90, "dragged above the minimap")
b.scripts.OnDragStop(b)
H.Equal(b.scripts.OnUpdate, nil, "drag ends")

-- Hidden from the option, shown again.
H.Check(ns.MinimapButton.SetShown(false), "hide")
H.Check(not b.shown, "hidden")
H.Equal(ns.Settings.Get().minimap.shown, false, "saved hidden")
ns.MinimapButton.SetShown(true)
H.Check(b.shown, "shown again")

-- Saved values are sanitized.
ForeverOneButtonDB.minimap = {shown = "yes", angle = 725.6, extra = 1}
ns.Settings.Load()
local m = ns.Settings.Get().minimap
H.Equal(m.shown, true, "non-false shown kept on")
H.Equal(m.angle, 5, "angle wrapped to 0-359")
H.Equal(m.extra, nil, "no extra fields")
ForeverOneButtonDB.minimap = {angle = "x"}
ns.Settings.Load()
H.Equal(ns.Settings.Get().minimap.angle, 225, "bad angle back to default")

H.Done("test_minimap_button")
