-- Forever One Button: JustAC adapter.
--
-- JustAC is the only Advisor. This module reads its public queue and returns
-- an immutable copy. It never reorders, filters, deduplicates or substitutes
-- entries, never calls JustAC internals and never writes to JustAC tables.
--
-- Contract verified in wealdly/JustAC @ 431e9a2 (5.9.0-beta2), SpellQueue.lua:
--   * LibStub:NewLibrary("JustAC-SpellQueue", 43)                  (line 4)
--   * SpellQueue.GetCurrentSpellQueue() - dot call, no arguments   (line 2333)
--   * returns one table: the module-level `lastSpellIDs`, a dense array that
--     JustAC wipes and refills in place on every build               (29, 1963-1999, 2371)
--   * entries: spell ID (> 0), -itemID for Custom Queue items (< 0)  (1393-1396)
--     or SpellQueue.WAIT_SENTINEL (-999999999) at position 1         (10, 2326-2329)
--   * position 1 is the Assisted Combat primary; 2+ the JustAC tail  (2401-2427)
--   * calls are throttled inside JustAC (0.03 s in combat, 0.05 s out) and the
--     same table is returned between builds                         (2350-2359)
local ADDON_NAME, ns = ...

local Adapter = {}
ns.JustAC = Adapter

Adapter.LIBRARY = "JustAC-SpellQueue"
Adapter.VERIFIED_MINOR = 43
Adapter.VERIFIED_COMMIT = "431e9a220dc3cf4bbfe8c05818a1de88ee40fa14"
-- Value of SpellQueue.WAIT_SENTINEL at the verified commit. The live value is
-- preferred when the library exposes it.
Adapter.WAIT_SENTINEL = -999999999
-- Defensive bound on how many positions are copied. JustAC caps the queue at
-- its maxIcons option; this only protects against a malformed table.
Adapter.MAX_ENTRIES = 40

local STATUS, ENTRY = ns.STATUS, ns.ENTRY

local function Result(status, detail)
    return {status = status, detail = detail, entries = {}, count = 0}
end

-- Failure states repeat every poll while JustAC is absent or broken; the
-- previous snapshot is reused when nothing about the failure changed.
local function Fail(previous, status, detail)
    if previous and previous.status == status and previous.detail == detail then return previous end
    return Result(status, detail)
end

local function GetLibrary()
    local stub = LibStub
    if ns.IsSecret(stub) or type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then
        return nil, nil
    end
    local ok, lib, minor = pcall(stub.GetLibrary, stub, Adapter.LIBRARY, true)
    if not ok or type(lib) ~= "table" then return nil, nil end
    return lib, minor
end

local function Classify(value, waitSentinel)
    if ns.IsSecret(value) then return ENTRY.UNREADABLE, nil end
    if type(value) ~= "number" or value ~= value or value ~= math.floor(value) or value == 0 then
        return nil, nil
    end
    if value == waitSentinel then return ENTRY.WAIT, value end
    if value > 0 then return ENTRY.SPELL, value end
    return ENTRY.ITEM, value
end

-- True when `queue` holds exactly the IDs of the OK snapshot `previous`.
local function SameAsSnapshot(queue, previous, minor)
    if not previous or previous.status ~= STATUS.OK or previous.minor ~= minor then return false end
    for position = 1, previous.count do
        local value = rawget(queue, position)
        if ns.IsSecret(value) or previous.entries[position].kind == ENTRY.UNREADABLE then return false end
        if value ~= previous.entries[position].id then return false end
    end
    local after = rawget(queue, previous.count + 1)
    return not ns.IsSecret(after) and after == nil
end

-- Returns a snapshot:
--   {status, detail, minor, verifiedMinor, entries = {{kind, id}...}, count}
-- `entries` keeps JustAC's positions exactly; entry i is JustAC position i.
-- Snapshots are never modified after creation, so when JustAC's queue still
-- holds exactly the IDs of `previous`, that snapshot is returned as is.
function Adapter.Read(previous)
    local lib, minor = GetLibrary()
    if not lib then return Fail(previous, STATUS.MISSING) end

    local getQueue = lib.GetCurrentSpellQueue
    if type(getQueue) ~= "function" then return Fail(previous, STATUS.NO_METHOD) end

    local ok, queue = pcall(getQueue)
    if not ok then return Fail(previous, STATUS.ERROR, tostring(queue)) end
    if ns.IsSecret(queue) then return Fail(previous, STATUS.UNREADABLE) end
    if type(queue) ~= "table" then return Fail(previous, STATUS.INVALID, "result is " .. type(queue)) end
    if canaccesstable and not canaccesstable(queue) then return Fail(previous, STATUS.UNREADABLE) end

    if SameAsSnapshot(queue, previous, minor) then return previous end

    local waitSentinel = lib.WAIT_SENTINEL
    if ns.IsSecret(waitSentinel) or type(waitSentinel) ~= "number" then
        waitSentinel = Adapter.WAIT_SENTINEL
    end

    local snapshot = Result(STATUS.OK)
    snapshot.minor = minor
    snapshot.verifiedMinor = minor == Adapter.VERIFIED_MINOR
    -- Copy positions 1..n until the first nil. JustAC builds the array by
    -- appending, so a nil ends it; anything after a hole is not part of the
    -- contract and is ignored rather than guessed at.
    for position = 1, Adapter.MAX_ENTRIES do
        local value = rawget(queue, position)
        if not ns.IsSecret(value) and value == nil then break end
        local kind, id = Classify(value, waitSentinel)
        if not kind then
            return Fail(previous, STATUS.INVALID, "entry " .. position .. " is not a queue ID")
        end
        snapshot.entries[position] = {kind = kind, id = id}
        snapshot.count = position
    end
    return snapshot
end

-- Position 1 as the pixel protocol needs it: a JustAC ID that names an
-- executable action, or nil for "no executable recommendation".
function Adapter.Head(snapshot)
    if not snapshot or snapshot.status ~= STATUS.OK then return nil end
    local first = snapshot.entries[1]
    if not first then return nil end
    if first.kind == ENTRY.SPELL or first.kind == ENTRY.ITEM then return first.id end
    return nil -- WAIT (JustAC's own "nothing to press yet") or unreadable
end
