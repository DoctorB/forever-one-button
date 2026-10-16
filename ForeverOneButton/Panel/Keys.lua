-- Forever One Button: key-string normalization.
-- Normalize() is a technical reuse of HCOB.UI.ActionPanel.NormalizeSlotKey
-- (HCOneButton, MIT, (c) 2026 DoctorB, UI/ActionPanel.lua @ e973acb):
-- modifiers are reordered to the client's CTRL-ALT-SHIFT-KEY form.
local ADDON_NAME, ns = ...

local Keys = {}
ns.Keys = Keys

function Keys.Normalize(key)
    if key == nil or key == false then return nil end
    if ns.IsSecret(key) then return nil end
    key = tostring(key):upper():gsub("%s+", ""):gsub("%+", "-")
    key = key:gsub("CONTROL", "CTRL")
    if key == "" or key == "NONE" or key == "UNBOUND" then return nil end

    local ctrl, alt, shift, base = false, false, false, nil
    for part in key:gmatch("[^%-]+") do
        if part == "CTRL" then ctrl = true
        elseif part == "ALT" then alt = true
        elseif part == "SHIFT" then shift = true
        elseif part ~= "" then base = part end
    end
    if not base then return nil end

    local parts = {}
    if ctrl then parts[#parts + 1] = "CTRL" end
    if alt then parts[#parts + 1] = "ALT" end
    if shift then parts[#parts + 1] = "SHIFT" end
    parts[#parts + 1] = base
    return table.concat(parts, "-")
end

-- Keys the grid refuses to take over: primary mouse buttons (needed to click
-- the cells and the world), Escape (game menu) and bare modifiers.
local REFUSED_BASES = {
    BUTTON1 = true, BUTTON2 = true, ESCAPE = true,
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    UNKNOWN = true,
}

function Keys.Base(key)
    return key and key:match("([^%-]+)$") or nil
end

function Keys.IsAllowed(key)
    if type(key) ~= "string" then return false end
    return not REFUSED_BASES[Keys.Base(key)]
end

-- Short label drawn on a cell, e.g. "CTRL-SHIFT-1" -> "cs1".
local SHORT = {CTRL = "c", ALT = "a", SHIFT = "s"}
local BASE_SHORT = {
    BUTTON3 = "M3", BUTTON4 = "M4", BUTTON5 = "M5",
    MOUSEWHEELUP = "WU", MOUSEWHEELDOWN = "WD", SPACE = "Spc",
}

function Keys.Short(key)
    if not key then return "" end
    local prefix, base = "", Keys.Base(key)
    for part in key:gmatch("[^%-]+") do
        if SHORT[part] then prefix = prefix .. SHORT[part] end
    end
    base = BASE_SHORT[base] or base:gsub("^NUMPAD", "N")
    return prefix .. base
end
