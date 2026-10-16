-- The grid never moves, scales, hides or covers the pixel (spec 4.4, criterion 12).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local lib = H.InstallJustAC(43)
H.spells[100] = {name = "A"}
H.Check(ns.Actions.Assign(1, "spell", 100), "assign")
lib.SetQueue({100})
H.Tick(0.1)

local pixel = _G.ForeverOneButtonDiagPixel
local grid = _G.ForeverOneButtonGrid

-- Anchor chain: pixel -> pixel anchor -> UIParent. The grid is not in it.
local function Chain(frame)
    local seen, f = {}, frame
    while f and f ~= UIParent do
        seen[f] = true
        local p = f.points[1]
        f = p and p[2] or f.parent
    end
    for _, region in ipairs(frame.regions) do H.Check(region.parent == frame, "texture owned by pixel") end
    return seen
end
local chain = Chain(pixel)
H.Check(not chain[grid], "pixel does not anchor to the grid")
for slot = 1, 20 do H.Check(not chain[ns.Grid.buttons[slot]], "pixel does not anchor to cell " .. slot) end
H.Equal(pixel.parent, UIParent, "pixel parent is UIParent, as in HCOneButton")
local f = pixel
while f do H.Check(f ~= grid, "grid is not an ancestor of the pixel"); f = f.parent end

local function PixelState()
    local l, b, w, h = H.ScreenRect(pixel)
    local r, g, bl = H.Pixel255()
    return table.concat({l, b, w, h, pixel:GetEffectiveScale(), tostring(pixel:IsVisible()), pixel.strata, r, g, bl}, "|")
end
local reference = PixelState()

-- Every whitelisted grid option, at its limits.
for name, limits in pairs(ns.Settings.GRID_LIMITS) do
    for _, value in ipairs({limits.min, limits.max, limits.default}) do
        H.Check(ns.Settings.SetGridValue(name, value), name .. "=" .. value)
        H.Equal(PixelState(), reference, "pixel unchanged by " .. name .. "=" .. value)
    end
end
-- Move, lock/unlock, hide/show the grid.
ForeverOneButtonDB.grid.point = {"TOPLEFT", "TOPLEFT", 0, 0}
ns.Grid.ApplyLayout()
H.Equal(PixelState(), reference, "pixel unchanged by moving the grid")
H.Check(ns.Grid.SetLocked(false), "unlock"); H.Check(ns.Grid.SetLocked(true), "lock")
H.Check(ns.Grid.SetShown(false), "hide grid")
H.Equal(PixelState(), reference, "pixel stays visible and unchanged with the grid hidden")
H.Check(ns.Grid.SetShown(true), "show grid")
-- Inherited transformations: scaling the grid frame directly changes nothing.
grid.scale = 3
H.Equal(PixelState(), reference, "pixel ignores grid scale")
grid.scale = ForeverOneButtonDB.grid.scale

-- Pixel size never depends on grid settings: 8x8 UI units at UIParent scale.
local _, _, w, h = H.ScreenRect(pixel)
H.Equal(w, 8 * UIParent.scale, "8 px wide at UIParent scale")
H.Equal(h, 8 * UIParent.scale, "8 px high at UIParent scale")

-- Overlap: a grid placed over the pixel is detected and announced.
ForeverOneButtonDB.grid.point = {"TOPLEFT", "TOPLEFT", 0, 0}
ns.Grid.ApplyLayout()
H.Check(ns.Grid.OverlapsPixel(), "grid over the pixel detected")
H.Tick(0.1)
lib.SetQueue({100, 100})
H.Tick(0.1)
H.Check(ns.Grid.statusText:GetText():find("covers the pixel"), "overlap shown to the user")
H.Check(ns.Settings.ResetLayout(), "reset layout")
H.Check(not ns.Grid.OverlapsPixel(), "default layout keeps clear of the default pixel")
-- Strata: pixel above the grid in any case.
H.Equal(pixel.strata, "TOOLTIP", "pixel strata")
H.Equal(grid.strata, "MEDIUM", "grid strata below the pixel")

-- Pixel options are the only ones that touch it, and only position/visibility.
ns.Pixel.SetLocked(false)
local handle = _G.ForeverOneButtonPixelHandle
H.Check(handle and handle.shown, "drag handle shown while unlocked")
for _, edge in ipairs(handle.regions) do
    local l, b, w2, h2 = 0, 0, edge.width, edge.height
    H.Check(w2 == 2 or h2 == 2, "handle draws 2 px edges only")
end
H.Equal(pixel.mouse, false, "pixel never takes the mouse")
ns.Pixel.SetLocked(true)
H.Check(not handle.shown, "handle hidden when locked")
ns.Pixel.SetEnabled(false)
H.Check(not pixel.shown, "pixel can be hidden")
ns.Pixel.SetEnabled(true)
H.Equal(pixel.width, 8, "size untouched by pixel options")

H.Done("test_grid_pixel_isolation")
