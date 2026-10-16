-- Automatic, stable cell filling from JustAC's ability pool (owner decision 2026-10-15).
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
ForeverOneButtonDB.pixel.combatOnly = false -- encoding checked out of combat; gating in test_protocol_v3
local queue = H.InstallJustAC(43)
local A, F = ns.Actions, ns.AutoFill
local char = ForeverOneButtonCharDB

local names = {[100] = "Strike", [101] = "Strike", [200] = "Rend", [300] = "Shout", [400] = "Charge",
    [500] = "Cleave", [600] = "Slam", [700] = "Overpower", [710] = "Overpower Empowered"}
for id, name in pairs(names) do H.spells[id] = {name = name} end
H.spells[700].override = 710

local function CellIDs()
    local out = {}
    for slot = 1, 20 do out[slot] = char.cells[slot] and char.cells[slot].id or 0 end
    return table.concat(out, ",", 1, 8)
end

-- No pool library: nothing happens, the state says why.
H.Tick(1)
H.Equal(F.status, "JustAC not loaded", "no pool")
H.Equal(next(char.cells), nil, "no cells without JustAC")

-- First fill: pool order, first free cells, default keys.
local pool = H.InstallJustACPool({100, 200, 300})
local frozen = {100, 200, 300}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(F.status, "ok", "pool read")
H.Equal(CellIDs(), "100,200,300,0,0,0,0,0", "filled in pool order")
H.Check(char.cells[1].auto, "marked automatic")
H.Equal(H.overrideBindings["SHIFT-1"].command, "CLICK ForeverOneButtonCell1:LeftButton", "default key cell 1")
H.Equal(H.overrideBindings["SHIFT-3"].command, "CLICK ForeverOneButtonCell3:LeftButton", "default key cell 3")
for i, id in ipairs(frozen) do H.Equal(pool.pool[i], id, "JustAC pool table untouched") end

-- A newly learned spell goes to the first free cell; nothing moves even if
-- JustAC's pool order changes.
pool.pool = {400, 300, 100, 200}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "100,200,300,400,0,0,0,0", "new spell appended, others stay")

-- Bursts of events are coalesced into one read.
pool.poolCalls = 0
for _ = 1, 10 do H.Fire("ACTIONBAR_SLOT_CHANGED") end
H.Tick(1)
H.Equal(pool.poolCalls, 1, "one pool read per burst")

-- A new rank (same name) replaces the old one in the same cell.
pool.pool = {101, 200, 300, 400}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "101,200,300,400,0,0,0,0", "rank 2 of Strike in cell 1")
H.Equal(ns.Grid.buttons[1].attributes.spell, 101, "button casts the new rank")
-- JustAC suggesting the old rank still maps to that cell (same spell).
queue.SetQueue({100})
H.Tick(0.1)
H.Equal(H.Pixel255(), 12, "old rank maps to the same cell")

-- Override IDs are the same ability: no duplicate cell.
pool.pool = {101, 200, 300, 400, 700, 710}
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
pool.pool = {101, 200, 300, 400, 700, 500, 600}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(CellIDs(), "101,600,300,400,700,0,0,500", "Slam takes free cell 2; Cleave stays on its manual cell")
-- A manual cell holding another rank keeps it.
H.Check(A.Assign(6, "spell", 100), "another rank of Strike can still be placed manually")
H.Equal(CellIDs(), "101,600,300,400,700,100,0,500", "a second rank is a different ID; allowed manually")
H.Check(A.Clear(6), "clear 6")
H.Check(char.dismissed["Strike"], "clearing rank 1 dismisses the spell name")
pool.pool = {101}
H.Fire("SPELLS_CHANGED")
H.Tick(1)
H.Equal(char.cells[1].id, 101, "existing cell kept although dismissed later")
H.Check(F.ResetDismissed(), "reset dismissed")
H.Equal(next(char.dismissed), nil, "dismissed list empty")

-- Overflow: more pool spells than cells.
local big = {}
for i = 1, 30 do big[i] = 9000 + i; H.spells[9000 + i] = {name = "Big" .. i} end
pool.pool = big
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
pool.pool = {101, 400}
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
pool.poolCalls = 0
queue.SetQueue({600, 300})
H.Tick(2)
H.Equal(pool.poolCalls, 0, "queue changes never read the pool")
H.Equal(A.SlotUsingAction("spell", 600), nil, "suggested spell not placed by the queue")

-- Unreadable pool: nothing changes.
local before = CellIDs()
pool.pool = {H.Secret()}
F.Run()
H.Equal(F.status, "JustAC pool unreadable", "secret pool entry")
H.Equal(CellIDs(), before, "cells unchanged")

-- Off switch.
H.Check(F.SetEnabled(false), "off")
pool.pool = {101, 400, 300}
F.Run()
H.Equal(A.SlotUsingAction("spell", 300), nil, "nothing placed when off")
F.SetEnabled(true)
H.Check(A.SlotUsingAction("spell", 300), "placed when switched on")

-- Gap closers (Charge 100, Intercept 20252 on Forever) are not in the
-- rotation pool; JustAC injects them from its gap-closer list. They are
-- appended after the pool, resolved to the known rank; unknown ones skipped.
H.spells[20252] = {name = "Intercept"}
H.spells[6178] = {name = "Charge"} -- rank 2
local spellDB = LibStub:NewLibrary("JustAC-SpellDB", 1)
local gapCalls = 0
function spellDB.GetGapCloserDefaults() gapCalls = gapCalls + 1; return {1000, 20252} end
H.spells[1000] = {name = "Charge"} -- rank 1 (100 on the client; 100 is "Strike" in this test)
local known = {[1000] = 6178} -- the character knows Charge rank 2, not Intercept
function pool.ResolveKnownSpellID(id) return known[id] end
for slot = 1, 20 do if char.cells[slot] then A.Clear(slot) end end
F.ResetDismissed()
for slot = 1, 20 do if char.cells[slot] then A.Clear(slot) end end
F.ResetDismissed()
for slot = 1, 20 do if char.cells[slot] then A.Clear(slot) end end
wipe(char.dismissed)
pool.pool = {101, 300}
F.Run()
H.Equal(CellIDs(), "101,300,6178,0,0,0,0,0", "Charge (known rank) after the pool; Intercept unknown, skipped")
H.Check(gapCalls > 0, "gap-closer defaults read")
known[20252] = 20252
pool.pool = {101, 300, 600}
F.Run()
H.Equal(CellIDs(), "101,300,6178,600,20252,0,0,0", "new pool spell and newly learned Intercept take the next free cells")
-- JustAC suggesting Charge rank 1 (as in the in-game log, head 100) maps to the Charge cell.
queue.SetQueue({1000})
H.Tick(0.1)
H.Equal(H.Pixel255(), 36, "Charge suggestion -> cell 3")
spellDB.GetGapCloserDefaults = function() error("broken") end
F.Run()
H.Equal(F.status, "ok", "a failing gap-closer list never breaks the pool fill")

-- Per character: another character starts empty and fills from its own pool.
local account = ForeverOneButtonDB
ns = H.Boot(account, nil)
H.libs["JustAC-BlizzardAPI"] = nil
H.InstallJustACPool({200})
H.Tick(1)
H.Equal(ForeverOneButtonCharDB.cells[1].id, 200, "second character: own cells")
H.Equal(ForeverOneButtonCharDB.cells[2], nil, "nothing from the first character")

-- 0.1.0 account-wide cells move to the character once.
ns = H.Boot({schema = 1, cells = {[3] = {kind = "spell", id = 300}}, grid = {slots = 12, columns = 6}}, nil)
H.Equal(ForeverOneButtonCharDB.cells[3].id, 300, "legacy cell migrated")
H.Equal(ForeverOneButtonDB.cells, nil, "legacy cells removed from the account")
H.Equal(ForeverOneButtonDB.grid.slots, 20, "untouched 0.1.0 grid defaults upgraded")

H.Done("test_autofill")
