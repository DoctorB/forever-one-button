-- Refresh cost on the offline mock (Lua 5.1 interpreter, not the client).
-- Budget: one refresh every Model.POLL_SECONDS (50 ms, the model's poll
-- throttle). The threshold keeps a refresh under 1% of that interval on the
-- mock; client timings remain a runtime check (docs/TEST_REPORT.md).
local H = dofile("tests/harness/wow.lua")
H.recordColors = false -- the mock's colour log would dominate memory figures
local ns = H.Boot(nil)
local lib = H.InstallQueue()
H.Check(ns.Settings.SetGridValue("slots", 20), "20 cells")
H.Check(ns.Settings.SetGridValue("queueDepth", 5), "5 positions")
for slot = 1, 20 do
    H.spells[100 + slot] = {name = "S" .. slot, icon = "i" .. slot, inRange = true}
    H.Check(ns.Actions.Assign(slot, "spell", 100 + slot), "assign")
end
H.target = true

local function Measure(label, iterations, prepare)
    collectgarbage("collect")
    collectgarbage("stop")
    local memBefore = collectgarbage("count")
    local start = os.clock()
    for i = 1, iterations do
        prepare(i)
        ns.Model.Refresh()
    end
    local elapsed = os.clock() - start
    local allocated = collectgarbage("count") - memBefore
    collectgarbage("restart")
    local micro = elapsed / iterations * 1e6
    print(string.format("  %-34s %8.1f us/refresh %7.2f KB/refresh", label, micro, allocated / iterations))
    return micro, allocated / iterations
end

-- Steady queue (the common case: most refreshes change nothing).
lib.Set({120, 119, 118, 117, 116})
local steady = Measure("steady queue", 20000, function() end)
-- Queue changing every refresh, head unmapped (worst case: full override scan).
local changing = Measure("changing queue, unmapped head", 20000, function(i)
    lib.Set({9000 + i % 7, 119, 118, 117, 116})
end)
H.Check(steady < 500 and changing < 500, "refresh under 1% of the 50 ms poll on the mock")

-- No growth across many refreshes once garbage is collected.
collectgarbage("collect")
local base = collectgarbage("count")
for i = 1, 20000 do lib.Set({100 + i % 20 + 1, 105}); ns.Model.Refresh() end
collectgarbage("collect")
local growth = collectgarbage("count") - base
print(string.format("  retained after 20000 refreshes: %.1f KB", growth))
H.Check(growth < 64, "no retained growth")

-- The real engine: an Arms warrior in a fight, every list spell known.
ns = H.Boot(nil)
for _, entry in ipairs(ns.Data.Rotations.classes.WARRIOR.arms.st) do
    H.known[entry.id] = true
    H.spells[entry.id] = H.spells[entry.id] or {name = "spell " .. entry.id, inRange = true}
end
H.forms = {2457, 71}
H.activeForm = 1
H.units.player = {health = 80, healthMax = 100, power = {[1] = 50}, powerMax = {[1] = 100}}
H.units.target = {health = 60, healthMax = 100, attackable = true}
H.inCombat = true
local engine = Measure("engine build (arms, in combat)", 5000, function() H.now = H.now + 0.05 end)
H.Check(engine < 2500, "engine build under 5% of the 50 ms poll on the mock")
H.inCombat = false
H.Done("test_bench")
