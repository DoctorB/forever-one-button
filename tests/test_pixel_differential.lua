-- Differential test: the ported pixel (ForeverOneButton/Pixel/DiagnosticPixel.lua)
-- against the frozen original producer (tests/fixtures/hcob/DiagnosticPixel.lua,
-- HCOneButton e973acb, blob 3c6b4050...). Both run in one process on the same
-- clock and timer queue and receive the same semantic inputs; every colour they
-- write must be identical, in the same order.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
H.InstallQueue()

-- Spells known to both sides. 1101 is a higher rank of 101 (same name).
H.spells[101] = {name = "Heal"}
H.spells[1101] = {name = "Heal"}
H.spells[202] = {name = "Smite"}
H.spells[303] = {name = "Unmapped"}

-- Original producer environment, as HCOneButton provides it.
local idToSlot = {}
HCOneButton = {UI = {ActionPanel = {idToSlot = idToSlot}}}
HCOneButton.Internal = setmetatable({}, {__index = _G})
local E = HCOneButton.Internal
E.advisor = CreateFrame("Frame", nil, UIParent)
E.SafeNumber = function(value, fallback) return tonumber(value) or fallback end
E.SpellName = function(id) return C_Spell.GetSpellName(id) end
assert(loadfile("tests/fixtures/hcob/DiagnosticPixel.lua"))()

local original = _G.HCOneButtonDiagPixel
local ported = _G.ForeverOneButtonDiagPixel
local originalTex, portedTex = original.regions[1], ported.regions[1]

-- Static contract: identical frame and texture setup.
H.Equal(ported.width, original.width, "width")
H.Equal(ported.height, original.height, "height")
H.Equal(ported.width, 8, "8 px wide")
H.Equal(ported.strata, original.strata, "strata")
H.Equal(ported.mouse, original.mouse, "mouse disabled")
H.Equal(ported.parent, original.parent, "parent")
H.Equal(ported.parent, UIParent, "parent is UIParent")
H.Equal(portedTex.layer, originalTex.layer, "texture layer")
H.Check(portedTex.allPoints == ported and originalTex.allPoints == original, "texture fills the frame")
H.Equal(#originalTex.colorHistory, 1, "original writes one initial colour")
for i = 1, 4 do H.Equal(portedTex.colorHistory[1][i], originalTex.colorHistory[1][i], "initial colour " .. i) end

-- Same slot table on both sides: original idToSlot and user-assigned cells.
H.Check(ns.Settings.SetGridValue("slots", 20), "20 cells")
local mapping = {[101] = 2, [202] = 3}
for slot = 1, 20 do
    local id = 5000 + slot
    H.spells[id] = {name = "Spell" .. slot}
    if slot ~= 2 and slot ~= 3 then mapping[id] = slot end
end
for id, slot in pairs(mapping) do
    idToSlot[id] = slot
    H.Check(ns.Actions.Assign(slot, "spell", id), "assign " .. id)
end
-- Rank equivalence is part of the slot table, not of the encoder. HCOneButton
-- listed rank-1 IDs, its Advisor emitted only those and its buttons cast by
-- name (any rank). Forever One Button maps every rank of a cell's spell to
-- that cell (Actions.SlotFor, same localized name). The original encoder gets
-- the same equivalence through its table, so both sides see one mapping.
idToSlot[1101] = 2

local ops = 0
local function CompareLast(label)
    local a, b = originalTex.color, portedTex.color
    for i = 1, 4 do
        if a[i] ~= b[i] then
            error(string.format("FAIL: %s: channel %d original %s ported %s", label, i, tostring(a[i]), tostring(b[i])))
        end
    end
end
local function Update(id) ops = ops + 1; E.UpdateDiagnosticPixel(id); ns.Pixel.Update(id); CompareLast("update " .. tostring(id)) end
local function Ack(id)
    ops = ops + 1
    local a = E.AcknowledgeDiagnosticPixelCast(id)
    local b = ns.Pixel.AcknowledgeCast(id)
    H.Equal(b, a, "ack result for " .. tostring(id))
    CompareLast("ack " .. tostring(id))
end
local function Advance(dt) H.Advance(dt); CompareLast("advance " .. dt) end

-- Scripted cases from the original regression (tests/fixtures/hcob/diagnostic_pixel_edge.lua).
-- Boot and cell assignment re-render the (black) pixel on the ported side;
-- the streams are compared from here on.
local baseOriginal, basePorted = #originalTex.colorHistory, #portedTex.colorHistory
Update(101)
H.Equal(H.Pixel255(), 24, "slot 2 -> R 24")
Ack(999)                -- unrelated cast ignored
Ack(1101)               -- higher rank, same name: acknowledged
H.Equal(H.Pixel255(), 0, "black edge")
Update(202)             -- suppressed during the gap
Advance(0.061)          -- released by the timer
H.Equal(H.Pixel255(), 36, "next spell after edge")
Ack(202); Update(202); Advance(0.061)
H.Equal(H.Pixel255(), 36, "same spell re-emitted after edge")
Update(303)             -- not on the grid: white
local r, g, b = H.Pixel255()
H.Check(r == 255 and g == 255 and b == 255, "unmapped is white")
Update(nil)
H.Equal(H.Pixel255(), 0, "nil is black")
-- Gap shorter than the timer, then a second ack restarting the edge.
Update(101); Ack(101); Advance(0.03); Ack(101); Advance(0.03); Advance(0.031)

-- Every slot 1..20.
for slot = 1, 20 do
    local id = slot == 2 and 101 or slot == 3 and 202 or 5000 + slot
    Update(id)
    local R, G, B, A = H.Pixel255()
    H.Equal(R, slot * 12, "slot " .. slot .. " R")
    H.Equal(G, 96, "slot " .. slot .. " G")
    H.Equal(B, 224, "slot " .. slot .. " B")
    H.Equal(A, 1, "slot " .. slot .. " alpha")
end

-- Seeded fuzz over updates, acknowledgements and clock steps.
math.randomseed(20261015)
local ids = {101, 202, 303, 1101, 5007, 5020, 5001, false}
for _ = 1, 3000 do
    local roll = math.random()
    local id = ids[math.random(#ids)] or nil
    if roll < 0.45 then Update(id)
    elseif roll < 0.75 then Ack(id or 999)
    else Advance(math.random(1, 90) / 1000) end
end
Advance(1)

-- Whole colour streams, not just final states.
local writes = #originalTex.colorHistory - baseOriginal
H.Equal(#portedTex.colorHistory - basePorted, writes, "same number of writes")
for i = 1, writes do
    local a, b = originalTex.colorHistory[baseOriginal + i], portedTex.colorHistory[basePorted + i]
    for c = 1, 4 do
        if a[c] ~= b[c] then error("FAIL: colour stream differs at write " .. i) end
    end
end
print(string.format("  compared %d operations, %d colour writes", ops, writes))

H.Done("test_pixel_differential")
