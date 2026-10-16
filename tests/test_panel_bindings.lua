-- Action Panel grid, cell assignments, key bindings, combat rules and persistence.
local H = dofile("tests/harness/wow.lua")
local saved, charSaved = {}, {}
local ns = H.Boot(saved, charSaved)
ForeverOneButtonDB.pixel.combatOnly = false -- encoding checked out of combat; gating in test_protocol_v3
local lib = H.InstallQueue()
local A = ns.Actions
H.spells[2687] = {name = "Bloodrage", icon = "bloodrage"}
H.spells[6603] = {name = "Auto Attack", icon = "attack"}
H.spells[284] = {name = "Heroic Strike", icon = "hs"}
H.spells[6546] = {name = "Rend", icon = "rend"}

-- Saved table replaced by a sanitized copy in the same global.
H.Check(ForeverOneButtonDB ~= nil and ForeverOneButtonDB.schema == 2, "dedicated SavedVariables created")
H.Check(ForeverOneButtonCharDB ~= nil and ForeverOneButtonCharDB.cells ~= nil, "per-character cells created")
H.Equal(ForeverOneButtonDB.cells, nil, "no cells in the account table")

-- Default grid: 20 cells, 10 columns, checkerboard; no binding without an action.
local g = ForeverOneButtonDB.grid
H.Equal(g.slots, 20, "default cells")
H.Equal(g.columns, 10, "default columns")
local shown = 0
for slot = 1, 20 do if ns.Grid.buttons[slot].shown then shown = shown + 1 end end
H.Equal(shown, 20, "20 buttons shown")
H.Equal(next(H.overrideBindings), nil, "empty cells get no binding")
local b1, b2, b7 = ns.Grid.buttons[1], ns.Grid.buttons[2], ns.Grid.buttons[11]
H.Check(b1.bg.color[1] ~= b2.bg.color[1], "neighbours alternate (checkerboard)")
H.Check(b7.bg.color[1] ~= b1.bg.color[1], "row 2 starts on the other colour")
H.Equal(b1.template, "SecureActionButtonTemplate", "cells are secure action buttons")
H.Equal(b1.name, "ForeverOneButtonCell1", "stable button name for CLICK bindings")
local x1 = b1.points[1][4]
local x2 = b2.points[1][4]
H.Equal(x2 - x1, g.cellSize + g.spacing, "regular column step")

-- Assign actions explicitly.
H.Check(A.Assign(1, "spell", 2687), "assign 1")
H.Check(A.Assign(2, "spell", 6603), "assign 2")
H.Check(A.Assign(3, "spell", 284), "assign 3")
H.Equal(b1.attributes.type1, "spell", "left button casts")
H.Equal(b1.attributes.spell, 2687, "cell 1 spell attribute")
H.Equal(b1.attributes.type, nil, "no generic type: right click does nothing")
local ok, message = A.Assign(5, "spell", 284)
H.Check(not ok and message:find("cell 3"), "duplicate action refused, cell named")
H.Equal(ForeverOneButtonCharDB.cells[5], nil, "duplicate not stored")
H.Check(not A.Assign(21, "spell", 1), "slot 21 refused (protocol limit 20)")
H.Check(not A.Assign(4, "macro", 1), "only spells and items")

-- Keys: normalization, conflicts, external bindings.
H.Check(A.Bind(1, "shift+1"), "bind 1")
H.Equal(ForeverOneButtonDB.keys[1], "SHIFT-1", "normalized key stored")
H.Equal(H.overrideBindings["SHIFT-1"].command, "CLICK ForeverOneButtonCell1:LeftButton", "override click binding")
ok, message = A.Bind(2, "SHIFT-1")
H.Check(not ok and message:find("cell 1"), "key used by another cell refused")
H.Equal(H.overrideBindings["SHIFT-1"].command, "CLICK ForeverOneButtonCell1:LeftButton", "first owner kept, nothing reassigned")
H.Check(not A.Bind(2, "BUTTON1"), "left mouse refused")
H.Check(not A.Bind(2, "ESCAPE"), "escape refused")
H.Check(not A.Bind(2, "SHIFT"), "bare modifier refused")
H.bindingActions["F"] = "INTERACTTARGET"
ok, message = A.Bind(2, "f")
H.Check(ok and message:find("INTERACTTARGET"), "shadowed client binding reported")
local report = A.Report()
local rowsBySlot = {}
for _, row in ipairs(report) do rowsBySlot[row.slot] = row end
H.Equal(rowsBySlot[2].shadowed, "INTERACTTARGET", "report shows the shadowed binding")
H.Check(rowsBySlot[3].defaultKey and rowsBySlot[3].key == "SHIFT-3", "cell 3 uses its default key")
H.Equal(H.overrideBindings["SHIFT-3"].command, "CLICK ForeverOneButtonCell3:LeftButton", "default key bound")
H.Equal(ns.Grid.buttons[3].keyText:GetText(), "s3", "default key visible on the cell")
H.Check(A.Unbind(3), "unbind 3")
H.Equal(ForeverOneButtonDB.keys[3], false, "explicit removal stored")
H.Equal(H.overrideBindings["SHIFT-3"], nil, "default key removed")
for _, row in ipairs(A.Report()) do if row.slot == 3 then H.Check(row.missingKey, "cell 3 has no key") end end
H.Equal(ns.Grid.buttons[3].keyText:GetText(), "no key", "missing key visible on the cell")
H.Check(A.DefaultKey(3), "back to default")
H.Equal(H.overrideBindings["SHIFT-3"].command, "CLICK ForeverOneButtonCell3:LeftButton", "default key restored")
H.Check(A.Unbind(3), "unbind 3 again")
-- Taking another cell's default key: accepted, that cell loses it (reported).
H.Check(A.Assign(4, "spell", 6546), "assign 4")
H.Equal(H.overrideBindings["SHIFT-4"].command, "CLICK ForeverOneButtonCell4:LeftButton", "cell 4 default")
ok, message = A.Bind(5, "SHIFT-4")
H.Check(ok and message:find("cell 4 no longer uses its default key"), "lost default reported")
H.Equal(H.overrideBindings["SHIFT-4"], nil, "empty cell 5 not bound; cell 4 lost SHIFT-4")
H.Check(A.Unbind(5) and A.DefaultKey(4) and A.Clear(4), "restore")
H.Equal(ns.Grid.buttons[1].keyText:GetText(), "s1", "short key label")

-- A key on an empty cell is kept but not bound.
H.Check(A.Bind(10, "CTRL-9"), "bind empty cell")
H.Equal(H.overrideBindings["CTRL-9"], nil, "no binding for an empty cell")
local emptyRow
for _, row in ipairs(A.Report()) do if row.slot == 10 then emptyRow = row end end
H.Check(emptyRow and emptyRow.emptyCell, "reported as key on empty cell")

-- Suggestions mark cells; they never change cells or keys.
local cellsBefore, keysBefore = {}, {}
for slot = 1, 20 do cellsBefore[slot] = ForeverOneButtonCharDB.cells[slot]; keysBefore[slot] = ForeverOneButtonDB.keys[slot] end
local bindingsBefore = {}
for key, binding in pairs(H.overrideBindings) do bindingsBefore[key] = binding.command end
lib.Set({284, 6546, 2687, 6603})
H.Tick(0.1)
H.Equal(ns.Grid.buttons[3].positionText:GetText(), "1", "cell 3 marked as queue position 1")
H.Equal(ns.Grid.buttons[1].positionText:GetText(), "3", "cell 1 marked as position 3")
H.Equal(ns.Grid.buttons[2].positionText:GetText(), "", "position 4 beyond the shown depth (3)")
H.Equal(ns.Grid.queueIcons[2].label:GetText(), "2: --", "position 2 (Rend) is not on the grid")
H.Equal(ns.Grid.queueIcons[1].label:GetText(), "1: c3", "strip lists the queue order with the cell")
lib.Set({6546})
H.Tick(0.1)
H.Check(ns.Grid.statusText:GetText():find("not on the grid"), "unmapped head stated explicitly")
for slot = 1, 20 do H.Equal(ns.Grid.buttons[slot].positionText:GetText(), "", "no substitute highlight on " .. slot) end
for _ = 1, 50 do lib.Set({math.random(1, 3) == 1 and 284 or 6546, 2687}); H.Tick(0.05) end
for slot = 1, 20 do
    H.Equal(ForeverOneButtonCharDB.cells[slot], cellsBefore[slot], "cell " .. slot .. " unchanged by suggestions")
    H.Equal(ForeverOneButtonDB.keys[slot], keysBefore[slot], "key " .. slot .. " unchanged by suggestions")
end
for key, command in pairs(bindingsBefore) do H.Equal(H.overrideBindings[key].command, command, "binding " .. key .. " unchanged") end

-- Combat: every protected change is refused or deferred, never attempted.
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Check(not A.Assign(4, "spell", 6546), "assign refused in combat")
H.Check(not A.Bind(3, "SHIFT-3"), "bind refused in combat")
H.Check(not A.Unbind(1), "unbind refused in combat")
H.Check(not A.Clear(1), "clear refused in combat")
H.Check(not ns.Settings.SetGridValue("columns", 4), "layout refused in combat")
H.Check(not ns.Grid.SetShown(false), "hide refused in combat")
H.Check(not ns.Options.Open(), "options do not open in combat")
-- Drag-assign in combat: refused, cursor kept.
H.cursor = {"spell", 1, "spell", 6546}
ns.Grid.buttons[4].scripts.OnReceiveDrag(ns.Grid.buttons[4])
H.Equal(ForeverOneButtonCharDB.cells[4], nil, "drop refused in combat")
H.Check(H.cursor ~= nil, "cursor not consumed")
lib.Set({2687})
H.Tick(0.1)     -- marks and pixel still update in combat
H.Equal(ns.Grid.buttons[1].positionText:GetText(), "1", "marks update in combat")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")

-- Drag and drop out of combat.
ns.Grid.buttons[4].scripts.OnReceiveDrag(ns.Grid.buttons[4])
H.Equal(ForeverOneButtonCharDB.cells[4].id, 6546, "spell dropped on cell 4")
H.Equal(H.cursor, nil, "cursor cleared after drop")

-- Unbind and clear.
H.Check(A.Unbind(2), "unbind")
H.Equal(H.overrideBindings["F"], nil, "override removed")
H.Check(A.Clear(4), "clear")
H.Equal(ns.Grid.buttons[4].attributes.type1, nil, "cleared cell has no action")

-- Hidden cells do not execute or keep bindings.
H.Check(A.Assign(12, "spell", 6546), "assign 12")
H.Check(A.Bind(12, "CTRL-SHIFT-2"), "bind 12")
H.Check(ns.Settings.SetGridValue("slots", 8), "shrink to 8")
H.Equal(ns.Grid.buttons[12].attributes.type1, nil, "hidden cell not executable")
H.Equal(H.overrideBindings["CTRL-SHIFT-2"], nil, "hidden cell not bound")
H.Equal(ForeverOneButtonCharDB.cells[12].id, 6546, "hidden cell keeps its saved action")
lib.Set({6546})
H.Tick(0.1)
local r = H.Pixel255()
H.Equal(r, 255, "action on a hidden cell is unmapped (white)")
H.Check(ns.Settings.SetGridValue("slots", 12), "back to 12")
H.Tick(0.1)
H.Equal(H.Pixel255(), 144, "visible again: slot 12")

-- Persistence and reload: same saved table, fresh addon instance.
local savedCopy, charCopy = ForeverOneButtonDB, ForeverOneButtonCharDB
H.overrideBindings = {}
ns = H.Boot(savedCopy, charCopy)
A = ns.Actions
H.Equal(ForeverOneButtonCharDB.cells[1].id, 2687, "cell restored")
H.Equal(ForeverOneButtonDB.keys[1], "SHIFT-1", "key restored")
H.Equal(H.overrideBindings["SHIFT-1"].command, "CLICK ForeverOneButtonCell1:LeftButton", "binding re-applied on login")

-- Reload while in combat: nothing protected runs; the pixel maps only what the
-- buttons really do (nothing yet) until combat ends.
H.overrideBindings = {}
H.inCombat = true
ns = H.Boot(savedCopy, charCopy)
H.InstallQueue().Set({2687})
H.Equal(next(H.overrideBindings), nil, "no binding applied in combat")
H.Equal(ns.Grid.buttons[1].attributes.spell, nil, "no attribute set in combat")
H.Tick(0.1)
r = H.Pixel255()
H.Equal(r, 255, "not yet applied: unmapped, never a slot the button does not execute")
H.Check(ns.Grid.statusText:GetText():find("after combat"), "pending state shown")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Equal(H.overrideBindings["SHIFT-1"].command, "CLICK ForeverOneButtonCell1:LeftButton", "applied after combat")
H.Tick(0.1)
H.Equal(H.Pixel255(), 12, "slot 1 once applied")

-- Key-down setting follows the client CVar (technical reuse from HCOneButton).
H.Equal(ns.Grid.buttons[1].attributes.useOnKeyDown, false, "useOnKeyDown follows CVar")
H.Equal(#ns.Grid.buttons[1].clickButtons, 2, "registered for down and up clicks")

H.Done("test_panel_bindings")
