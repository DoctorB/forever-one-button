-- The grid can be found and moved: its title bar is always shown, right-click
-- toggles the lock, left-drag moves it while unlocked, and the position is
-- saved in SavedVariables and restored after /reload. Out of combat only.
local H = dofile("tests/harness/wow.lua")

local ns = H.Boot(nil, nil)
local bar = _G.ForeverOneButtonGridDragBar
local grid = _G.ForeverOneButtonGrid
H.Equal(ForeverOneButtonDB.grid.locked, true, "locked by default")
H.Check(bar:IsVisible(), "title bar shown while locked")
H.Equal(bar.dragButtons[1], "LeftButton", "left-drag registered")

-- Locked: dragging does nothing and saves nothing.
bar.scripts.OnDragStart(bar)
H.Check(not grid.moving, "no move while locked")
bar.scripts.OnDragStop(bar)
H.Equal(ForeverOneButtonDB.grid.point[1], "CENTER", "default point kept")
H.Equal(ForeverOneButtonDB.grid.point[4], -220, "default offset kept")

-- Right-click unlocks; left-click does not toggle.
bar.scripts.OnMouseUp(bar, "LeftButton")
H.Equal(ForeverOneButtonDB.grid.locked, true, "left-click leaves the lock alone")
bar.scripts.OnMouseUp(bar, "RightButton")
H.Equal(ForeverOneButtonDB.grid.locked, false, "right-click unlocks")
H.Check(bar:IsVisible(), "title bar still shown")

-- Drag: the client moves the frame and re-anchors it; the new anchor is saved.
bar.scripts.OnDragStart(bar)
H.Check(grid.moving, "moving while unlocked")
grid:ClearAllPoints()
grid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -150)
bar.scripts.OnDragStop(bar)
H.Check(not grid.moving, "move stopped")
H.Equal(grid.userPlaced, false, "not left to the client layout cache")
local saved = ForeverOneButtonDB.grid.point
H.Equal(saved[1], "TOPLEFT", "saved point")
H.Equal(saved[2], "TOPLEFT", "saved relative point")
H.Equal(saved[3], 300, "saved x")
H.Equal(saved[4], -150, "saved y")

-- A layout pass keeps the moved position.
ns.Settings.SetGridValue("cellSize", 40)
H.Equal(grid:GetPoint(1), "TOPLEFT", "layout keeps the point")
H.Equal(select(4, grid:GetPoint(1)), 300, "layout keeps x")

-- Right-click locks again.
bar.scripts.OnMouseUp(bar, "RightButton")
H.Equal(ForeverOneButtonDB.grid.locked, true, "right-click locks")

-- /reload: the position comes back from SavedVariables.
ns = H.Boot(ForeverOneButtonDB, ForeverOneButtonCharDB)
grid = _G.ForeverOneButtonGrid
bar = _G.ForeverOneButtonGridDragBar
local p, rel, rp, x, y = grid:GetPoint(1)
H.Equal(p, "TOPLEFT", "restored point")
H.Equal(rel, UIParent, "restored relative to UIParent")
H.Equal(rp, "TOPLEFT", "restored relative point")
H.Equal(x, 300, "restored x")
H.Equal(y, -150, "restored y")
H.Check(bar:IsVisible(), "title bar shown after reload")

-- Combat starting mid-drag ends the drag and saves, before the lockdown.
ns.Grid.SetLocked(false)
bar.scripts.OnDragStart(bar)
grid:ClearAllPoints()
grid:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 60)
H.Fire("PLAYER_REGEN_DISABLED")
H.inCombat = true
H.Check(not grid.moving, "drag ended when combat starts")
H.Equal(ForeverOneButtonDB.grid.point[1], "BOTTOMRIGHT", "position saved when combat starts")

-- In combat: no drag, no lock change.
bar.scripts.OnDragStart(bar)
H.Check(not grid.moving, "no move in combat")
bar.scripts.OnMouseUp(bar, "RightButton")
H.Equal(ForeverOneButtonDB.grid.locked, false, "no lock change in combat")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")

H.Done("grid move")
