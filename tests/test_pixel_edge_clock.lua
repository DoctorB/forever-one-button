-- The acknowledgement edge is timed on the precise clock. In game GetTime is
-- the frame start and the cast event is handled later in the frame; the
-- diagnostic log of 2026-10-21 (build 70450) showed the black written 22 ms
-- after the frame start and replaced 43 ms later. Here GetTime lags the
-- precise clock the same way: the black must stay for 60 ms of precise time.
local H = dofile("tests/harness/wow.lua")
GetTimePreciseSec = function() return H.now end
local frameStart = H.now
GetTime = function() return frameStart end

-- As in the client, a timer counts from the frame time and runs at a frame start.
function C_Timer.After(delay, callback)
    H.timers[#H.timers + 1] = {at = frameStart + delay, delay = delay, callback = callback}
end

local ns = H.Boot(nil, nil)
H.InstallQueue()
H.spells[20271] = {name = "Judgement"}
H.spells[1866] = {name = "Holy Strike"}
H.Check(ns.Actions.Assign(2, "spell", 20271), "Judgement on 2")
H.Check(ns.Actions.Assign(3, "spell", 1866), "Holy Strike on 3")

-- One frame: its start is GetTime, timers run at the start, events later.
local FRAME = 0.025
local function NextFrame()
    frameStart = frameStart + FRAME
    H.Advance(frameStart - H.now)
end

local function Edge(eventOffset)
    ns.Pixel.Update(20271)
    H.Equal(H.Pixel255(), 24, "Judgement shown (cell 2)")
    NextFrame()
    H.Advance(eventOffset) -- the cast event arrives inside the frame
    local blackAt = H.now
    H.Check(ns.Pixel.AcknowledgeCast(20271), "cast acknowledged")
    ns.Pixel.Update(1866) -- next suggestion arrives at once: held back by the edge
    H.Equal(H.Pixel255(), 0, "black edge")
    local releasedAt
    for _ = 1, 20 do
        NextFrame()
        if H.Pixel255() ~= 0 then releasedAt = H.now; break end
    end
    H.Check(releasedAt ~= nil, "edge released")
    H.Equal(H.Pixel255(), 36, "next spell after the edge (cell 3)")
    return releasedAt - blackAt
end

for _, offset in ipairs({0, 0.005, 0.022, 0.024}) do
    local black = Edge(offset)
    H.Check(black >= 0.060 - 1e-9, string.format("black %.1f ms >= 60 ms with the event %d ms into the frame",
        black * 1000, offset * 1000))
    NextFrame()
end

-- The same scene timed on the frame start (the original behaviour) would
-- have released the edge at the first frame start 60 ms after the frame the
-- event arrived in: 22 ms into the frame that is 50 ms of precise time.
H.Check(math.ceil(0.060 / FRAME) * FRAME - 0.022 < 0.060, "the scene reproduces the short edge")

H.Done("test_pixel_edge_clock")
