-- The automatic fill's pool from the imported data: the active tree's list
-- (single target, cleave, aoe), then gap closers, interrupts and defensives;
-- known spells only, at the pressed rank, each once.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot({}, {})
local F = ns.AutoFill

local KNOWN = {6673, 7386, 772, 78, 284, 2687, 2457, 71, 100, 6552, 72, 871, 6343}
for _, id in ipairs(KNOWN) do
    H.known[id] = true
    H.spells[id] = {name = "spell " .. id}
end
H.spells[284].name, H.spells[78].name = "Heroic Strike", "Heroic Strike"

-- Arms (default tree): list order, Heroic Strike at rank 2, Battle Stance
-- once although both lists name it; Thunder Clap from the aoe list; then
-- Charge, the interrupts (Shield Bash 72 and Pummel 6552, same tier, by ID)
-- and Shield Wall. Unknown list spells (Hamstring, Execute...) are skipped.
local pool, status = F.ReadPool()
H.Equal(status, "ok", "pool built")
H.Equal(table.concat(pool, ","), "6673,7386,772,284,2687,2457,6343,100,72,6552,871", "arms pool")

-- Protection talents: the protection list instead.
H.talents = {Arms = 0, Fury = 0, Protection = 3}
ns.Trees.Invalidate()
pool = F.ReadPool()
H.Equal(table.concat(pool, ","), "6673,71,6343,7386,284,100,72,6552,871", "protection pool")

-- The fill itself places them in that order.
H.talents = nil
ns.Trees.Invalidate()
F.Run()
local cells = ForeverOneButtonCharDB.cells
H.Equal(cells[1].id, 6673, "cell 1: Battle Shout")
H.Equal(cells[8].id, 100, "cell 8: Charge")
H.Equal(cells[11].id, 871, "cell 11: Shield Wall")
H.Equal(cells[12], nil, "nothing beyond the pool")

-- A class without data: no pool.
H.class = "DEATHKNIGHT"
local none, why = F.ReadPool()
H.Equal(none, nil, "no pool")
H.Equal(why, "no priority list for this class", "reason")

H.Done("test_autofill_pool")
