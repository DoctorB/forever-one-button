-- JustAC adapter contract (SpellQueue.lua @ 431e9a2). See docs/PROTOCOL_COMPATIBILITY.md.
package.path = "tests/?.lua;" .. package.path
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
local S, E = ns.STATUS, ns.ENTRY
local read = ns.JustAC.Read

-- Library absent: explicit state, no entries, pixel black.
local snap = read()
H.Equal(snap.status, S.MISSING, "absent library")
H.Equal(snap.count, 0, "absent library has no entries")
H.Tick(0.1)
local r, g, b = H.Pixel255()
H.Equal(r + g + b, 0, "absent library keeps the pixel black")

-- Library registered late (after login): picked up without a reload.
local lib = H.InstallJustAC(43)
lib.SetQueue({2687})
snap = read()
H.Equal(snap.status, S.OK, "late library is read")
H.Equal(snap.minor, 43, "minor reported")
H.Check(snap.verifiedMinor, "minor 43 is the verified one")

-- Method missing / not a function.
local real = lib.GetCurrentSpellQueue
lib.GetCurrentSpellQueue = nil
H.Equal(read().status, S.NO_METHOD, "method missing")
lib.GetCurrentSpellQueue = "nope"
H.Equal(read().status, S.NO_METHOD, "method not callable")

-- Error inside JustAC.
lib.GetCurrentSpellQueue = function() error("boom") end
snap = read()
H.Equal(snap.status, S.ERROR, "call error contained")
H.Equal(snap.count, 0, "error yields no entries")

-- Non-conforming results.
lib.GetCurrentSpellQueue = function() return 2687 end
H.Equal(read().status, S.INVALID, "number result rejected")
lib.GetCurrentSpellQueue = function() return {2687, "6603"} end
H.Equal(read().status, S.INVALID, "string entry rejected, not coerced")
lib.GetCurrentSpellQueue = function() return {2687.5} end
H.Equal(read().status, S.INVALID, "fractional ID rejected")
lib.GetCurrentSpellQueue = function() return {0} end
H.Equal(read().status, S.INVALID, "zero rejected")
lib.GetCurrentSpellQueue = function() return H.Secret() end
H.Equal(read().status, S.UNREADABLE, "secret result")
local hidden = {2687}
H.MakeInaccessible(hidden)
lib.GetCurrentSpellQueue = function() return hidden end
H.Equal(read().status, S.UNREADABLE, "inaccessible table")
lib.GetCurrentSpellQueue = real

-- Empty queue.
lib.SetQueue({})
snap = read()
H.Equal(snap.status, S.OK, "empty queue is OK")
H.Equal(snap.count, 0, "empty queue count")
H.Equal(ns.JustAC.Head(snap), nil, "empty queue has no head")

-- Historical sample 2687 6603 284 6546 as an input fixture: order and
-- identity are kept, nothing is filtered or deduplicated.
local sample = {2687, 6603, 284, 6546}
lib.SetQueue(sample)
snap = read()
H.Equal(snap.count, 4, "sample length")
for i, id in ipairs(sample) do
    H.Equal(snap.entries[i].id, id, "sample position " .. i)
    H.Equal(snap.entries[i].kind, E.SPELL, "sample kind " .. i)
end
H.Equal(ns.JustAC.Head(snap), 2687, "head is JustAC position 1")

-- Duplicates are JustAC's business: kept as given.
lib.SetQueue({284, 284})
snap = read()
H.Equal(snap.count, 2, "duplicates not removed")

-- Items (-itemID) and the wait sentinel at position 1.
lib.SetQueue({-5512, 2687})
snap = read()
H.Equal(snap.entries[1].kind, E.ITEM, "negative ID is an item entry")
H.Equal(snap.entries[1].id, -5512, "item ID kept in JustAC encoding")
H.Equal(ns.JustAC.Head(snap), -5512, "item head")
lib.SetQueue({lib.WAIT_SENTINEL, 6603})
snap = read()
H.Equal(snap.entries[1].kind, E.WAIT, "wait sentinel recognised")
H.Equal(snap.entries[2].id, 6603, "tail after wait kept")
H.Equal(ns.JustAC.Head(snap), nil, "wait means no executable head")
-- The live sentinel wins over the recorded one.
lib.WAIT_SENTINEL = -42
lib.SetQueue({-42})
H.Equal(read().entries[1].kind, E.WAIT, "live WAIT_SENTINEL used")
lib.WAIT_SENTINEL = -999999999

-- Holes: copy stops at the first nil, later keys are not guessed at.
lib.GetCurrentSpellQueue = function() return {2687, nil, 284} end
snap = read()
H.Equal(snap.count, 1, "copy stops at first hole")
lib.GetCurrentSpellQueue = real

-- Secret entries are kept as unreadable positions, never compared.
lib.GetCurrentSpellQueue = function() return {H.Secret(), 6603} end
snap = read()
H.Equal(snap.status, S.OK, "secret entry does not fail the snapshot")
H.Equal(snap.entries[1].kind, E.UNREADABLE, "secret entry marked")
H.Equal(snap.entries[2].id, 6603, "readable entries after a secret one kept")
H.Equal(ns.JustAC.Head(snap), nil, "unreadable head is not executable")
lib.GetCurrentSpellQueue = real

-- Snapshot isolation: JustAC mutates its shared table in place between
-- builds; an earlier snapshot must not change, and the adapter must never
-- write to JustAC's table.
lib.SetQueue({2687, 6603})
local first = read()
local before = {}
for k, v in pairs(lib._shared) do before[k] = v end
lib.SetQueue({284})
H.Equal(first.count, 2, "old snapshot keeps its length")
H.Equal(first.entries[1].id, 2687, "old snapshot keeps position 1")
H.Equal(first.entries[2].id, 6603, "old snapshot keeps position 2")
local second = read()
H.Equal(second.count, 1, "new snapshot follows JustAC")
H.Equal(lib._shared[1], 284, "JustAC table untouched by reads")
H.Equal(lib._shared[2], nil, "adapter did not add to JustAC table")
H.Check(rawequal(lib.GetCurrentSpellQueue(), lib._shared), "JustAC still returns its own table")

-- Reuse: an unchanged queue returns the previous (immutable) snapshot; any
-- change, including a shorter or longer queue, returns a new one.
lib.SetQueue({2687, 6603})
local a = read()
H.Check(read(a) == a, "unchanged queue reuses the snapshot")
lib.SetQueue({2687})
local b2 = read(a)
H.Check(b2 ~= a and b2.count == 1 and a.count == 2, "shorter queue: new snapshot, old one intact")
lib.SetQueue({2687, 6603, 284})
H.Check(read(a) ~= a, "longer queue: new snapshot")
lib.SetQueue({6603, 2687})
H.Check(read(a) ~= a, "reordered queue: new snapshot")
lib.GetCurrentSpellQueue = function() return {H.Secret()} end
local u = read()
H.Check(read(u) ~= u, "unreadable entries are never treated as unchanged")
lib.GetCurrentSpellQueue = real
H.libs["JustAC-SpellQueue"] = nil
local m = read()
H.Check(read(m) == m, "repeated missing state reuses the snapshot")
H.libs["JustAC-SpellQueue"] = {lib = lib, minor = 43}

-- Unverified minor is used but flagged.
H.libs["JustAC-SpellQueue"].minor = 44
H.Equal(read().verifiedMinor, false, "other minor flagged as untested")
H.libs["JustAC-SpellQueue"].minor = 43

-- Call shape: dot call, no arguments (the stub asserts it).
lib.calls = 0
read()
H.Equal(lib.calls, 1, "one call per read")

H.Done("test_justac_adapter")
