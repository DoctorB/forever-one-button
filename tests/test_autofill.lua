-- Automatic, stable cell filling (owner decision 2026-10-15): placement
-- rules on a pool chosen by the test. The real pool, built from the priority
-- lists, is checked in test_autofill_pool.lua.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
ForeverOneButtonDB.pixel.combatOnly = false -- encoding checked out of combat; gating in test_protocol_v3
local queue = H.InstallQueue()
local A, F = ns.Actions, ns.AutoFill
local char = ForeverOneButtonCharDB

local names = {[100] = "Strike", [101] = "Strike", [200] = "Rend", [300] = "Shout", [400] = "Charge",
    [500] = "Cleave", [600] = "Slam", [700] = "Overpower", [710] = "Overpower Empowered"}
for id, name in pairs(names) do H.spells[id] = {name = name} end
H.spells[700].override = 710

-- Pool chosen by the test in place of AutoFill.ReadPool.
local pool = {ids = {}, calls = 0}
local function InstallPool()
    ns.AutoFill.ReadPool = function()
        pool.calls = pool.calls + 1
        if pool.status then return nil, pool.status end
        local copy = {}
        for i, id in ipairs(pool.ids) do copy[i] = id end
        return copy, "ok"
    end
end
InstallPool()

local function CellIDs()
    local out = {}
    for slot = 1, 20 do out[slot] = char.cells[slot] and char.cells[slot].id or 0 end
    return table.concat(out, ",", 1, 8)
end

-- No pool (a class without a priority list): nothing happens, the state says why.
pool.status = "no priority list for this class"
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(F.status, "no priority list for this class", "no pool")
H.Equal(next(char.cells), nil, "no cells without a pool")

-- First fill: pool order, first free cells, default keys.
pool.status = nil
pool.ids = {100, 200, 300}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(F.status, "ok", "pool read")
H.Equal(CellIDs(), "100,200,300,0,0,0,0,0", "filled in pool order")
H.Check(char.cells[1].auto, "marked automatic")
H.Equal(H.overrideBindings["SHIFT-1"].command, "CLICK ForeverOneButtonCell1:LeftButton", "default key cell 1")
H.Equal(H.overrideBindings["SHIFT-3"].command, "CLICK ForeverOneButtonCell3:LeftButton", "default key cell 3")

-- A newly learned spell goes to the first free cell; nothing moves even if
-- the pool order changes.
pool.ids = {400, 300, 100, 200}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "100,200,300,400,0,0,0,0", "new spell appended, others stay")

-- Bursts of events are coalesced into one read.
pool.calls = 0
for _ = 1, 10 do H.Fire("ACTIONBAR_SLOT_CHANGED") end
H.Tick(1)
H.Equal(pool.calls, 1, "one pool read per burst")

-- A new rank (same name) replaces the old one in the same cell.
pool.ids = {101, 200, 300, 400}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "101,200,300,400,0,0,0,0", "rank 2 of Strike in cell 1")
H.Equal(ns.Grid.buttons[1].attributes.spell, 101, "button casts the new rank")
-- A suggestion of the old rank still maps to that cell (same spell).
queue.Set({100})
H.Tick(0.1)
H.Equal(H.Pixel255(), 12, "old rank maps to the same cell")

-- Override IDs are the same ability: no duplicate cell.
pool.ids = {101, 200, 300, 400, 700, 710}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "101,200,300,400,700,0,0,0", "override not duplicated")

-- The user's choices win: a cleared spell is not put back, a manual cell is
-- not touched, and the free cell is reused by the next new spell.
H.Check(A.Clear(2), "user clears Rend")
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "101,0,300,400,700,0,0,0", "cleared spell not put back")
H.Check(A.Assign(8, "spell", 500), "manual Cleave on 8")
H.Check(not char.cells[8].auto, "manual cell not automatic")
pool.ids = {101, 200, 300, 400, 700, 500, 600}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "101,600,300,400,700,0,0,500", "Slam takes free cell 2; Cleave stays on its manual cell")
-- A manual cell holding another rank keeps it.
H.Check(A.Assign(6, "spell", 100), "another rank of Strike can still be placed manually")
H.Equal(CellIDs(), "101,600,300,400,700,100,0,500", "a second rank is a different ID; allowed manually")
H.Check(A.Clear(6), "clear 6")
H.Check(char.dismissed["Strike"], "clearing rank 1 dismisses the spell name")
pool.ids = {101}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(char.cells[1].id, 101, "existing cell kept although dismissed later")
H.Check(F.ResetDismissed(), "reset dismissed")
H.Equal(next(char.dismissed), nil, "dismissed list empty")

-- Overflow: more pool spells than cells.
local big = {}
for i = 1, 30 do big[i] = 9000 + i; H.spells[9000 + i] = {name = "Big" .. i} end
pool.ids = big
H.Fire("SPELLS_CHANGED")
H.Tick(1)
local filled = 0
for slot = 1, 20 do if char.cells[slot] then filled = filled + 1 end end
H.Equal(filled, 20, "all 20 cells used")
H.Check(F.overflow > 0, "overflow counted")
H.Check(ns.Grid.statusText:GetText():find("did not fit"), "overflow shown")

-- Combat: nothing protected runs; the fill happens after combat.
for slot = 2, 20 do if char.cells[slot] then A.Clear(slot) end end
F.ResetDismissed()
for slot = 2, 20 do if char.cells[slot] then A.Clear(slot) end end
pool.ids = {101, 400}
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Check(F.pending, "fill pending in combat")
H.Equal(char.cells[2], nil, "nothing placed in combat")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Equal(char.cells[2].id, 400, "placed after combat")

-- The queue never drives placement: a suggestion outside the pool is not placed.
pool.calls = 0
queue.Set({600, 300})
H.Tick(2)
H.Equal(pool.calls, 0, "queue changes never read the pool")
H.Equal(A.SlotUsingAction("spell", 600), nil, "suggested spell not placed by the queue")

-- A failing pool read: nothing changes.
local before = CellIDs()
pool.status = "no priority list for this class"
F.Run()
H.Equal(CellIDs(), before, "cells unchanged")
pool.status = nil

-- Off switch.
H.Check(F.SetEnabled(false), "off")
pool.ids = {101, 400, 300}
F.Run()
H.Equal(A.SlotUsingAction("spell", 300), nil, "nothing placed when off")
F.SetEnabled(true)
H.Check(A.SlotUsingAction("spell", 300), "placed when switched on")

-- Learned ranks (real chains, Heroic Strike 78 -> 284 -> 285): every spell
-- cell moves to the highest known rank in the same cell, the user's too,
-- also with the fill off, whatever rank the hidden Blizzard bars hold.
H.spells[78], H.spells[284], H.spells[285] = {name = "Heroic Strike"}, {name = "Heroic Strike"}, {name = "Heroic Strike"}
H.known[78] = true
H.actions[1] = 78
pool.ids = {}
H.Check(A.Assign(10, "spell", 78), "user places Heroic Strike rank 1")
H.known[284] = true
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(char.cells[10].id, 284, "user cell moves to rank 2")
H.Check(not char.cells[10].auto, "still the user's cell")
H.Equal(ns.Grid.buttons[10].attributes.spell, 284, "button casts rank 2")
F.SetEnabled(false)
H.known[285] = true
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(char.cells[10].id, 285, "rank 3 with the fill off")
H.Equal(ns.Grid.buttons[10].attributes.spell, 285, "button casts rank 3")
F.SetEnabled(true)
A.Clear(10)
F.ResetDismissed()
H.actions[1] = nil

-- Per character: another character starts empty and fills from its own pool.
local account = ForeverOneButtonDB
ns = H.Boot(account, nil)
pool.ids = {200}
InstallPool()
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(ForeverOneButtonCharDB.cells[1].id, 200, "second character: own cells")
H.Equal(ForeverOneButtonCharDB.cells[2], nil, "nothing from the first character")

-- 0.1.0 account-wide cells move to the character once.
ns = H.Boot({schema = 1, cells = {[3] = {kind = "spell", id = 300}}, grid = {slots = 12, columns = 6}}, nil)
H.Equal(ForeverOneButtonCharDB.cells[3].id, 300, "legacy cell migrated")
H.Equal(ForeverOneButtonDB.cells, nil, "legacy cells removed from the account")
H.Equal(ForeverOneButtonDB.grid.slots, 20, "untouched 0.1.0 grid defaults upgraded")

H.Done("test_autofill")
