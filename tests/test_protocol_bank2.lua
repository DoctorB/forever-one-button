-- Cells 21-30 (owner request 2026-11-25): second colour bank of the pixel
-- protocol, R = (slot - 20) * 12, G = 160, B = 224. Cells 1-20 keep the
-- HCOneButton v3 colours unchanged, and a v3 decoder reads the second bank
-- as invalid, so an older reader presses nothing. Default keys CTRL-1..CTRL-0.
-- The automatic fill uses only the cells the grid shows.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
ForeverOneButtonDB.pixel.combatOnly = false
local lib = H.InstallQueue()

local function DecodeV3(r, g, b)
    if g ~= 96 or b ~= 224 or r % 12 ~= 0 then return "invalid" end
    local slot = r / 12
    if slot < 1 or slot > 20 then return "invalid" end
    return slot
end
local function DecodeBanks(r, g, b)
    if b ~= 224 or r % 12 ~= 0 then return "invalid" end
    local base = (g == 96 and 0) or (g == 160 and 20)
    local slot = base and r / 12
    if not slot or slot < 1 or slot > 20 then return "invalid" end
    return base + slot
end

H.Equal(ns.MAX_SLOTS, 30, "30 cells")
H.Check(ns.Settings.SetGridValue("slots", 30), "30 cells shown")
for slot = 1, 30 do
    H.spells[7000 + slot] = {name = "S" .. slot, inRange = true}
    H.Check(ns.Actions.Assign(slot, "spell", 7000 + slot), "assign slot " .. slot)
end

-- Cell 20 is pressed by hand only (Bridge/Model.lua MANUAL_SLOT): its colour
-- is checked in test_protocol_v3 through the README examples.
local hex = {[1] = "0C60E0", [19] = "E460E0", [21] = "0CA0E0", [25] = "3CA0E0", [30] = "78A0E0"}
for slot = 1, 30 do
    if slot ~= 20 then
        lib.Set({7000 + slot})
        H.Tick(0.06)
        local r, g, b = H.Pixel255()
        H.Equal(DecodeBanks(r, g, b), slot, "both banks decode cell " .. slot)
        if slot <= 20 then
            H.Equal(DecodeV3(r, g, b), slot, "v3 colour unchanged for cell " .. slot)
        else
            H.Equal(DecodeV3(r, g, b), "invalid", "a v3 reader ignores cell " .. slot)
        end
        if hex[slot] then
            H.Equal(string.format("%02X%02X%02X", r, g, b), hex[slot], "hex for cell " .. slot)
        end
        lib.Set({})
        H.Tick(0.1)
    end
end

-- Default keys of the third row.
for slot = 21, 29 do H.Equal(ns.Settings.KeyFor(slot), "CTRL-" .. (slot - 20), "default key " .. slot) end
H.Equal(ns.Settings.KeyFor(30), "CTRL-0", "default key 30")
H.Equal(ns.Actions.appliedKeys[25], "CTRL-5", "cell 25 bound")

-- Twenty cells shown: no key and no pixel colour for 21-30.
H.Check(ns.Settings.SetGridValue("slots", 20), "20 cells shown")
H.Equal(ns.Actions.appliedKeys[25], nil, "hidden cell has no key")
lib.Set({7025})
H.Tick(0.06)
H.Equal(select(1, H.Pixel255()), 255, "hidden cell: unmapped (white)")
lib.Set({})
H.Tick(0.1)

H.Done("test_protocol_bank2")
