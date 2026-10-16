-- Forever One Button: persistent settings with an explicit whitelist.
-- ForeverOneButtonDB (account: keys, layout, pixel) and ForeverOneButtonCharDB
-- (character: cell actions) are dedicated to this addon. They are never seeded
-- from HCOneButton saved data or other addons' profiles, and every unknown key is
-- dropped on load, so excluded features cannot be revived through saved data.
local ADDON_NAME, ns = ...

local Settings = {}
ns.Settings = Settings

Settings.SCHEMA = 2
Settings.CHAR_SCHEMA = 1

-- The complete whitelist. See docs/BINDINGS_AND_OPTIONS.md for the reason
-- behind every entry. Nothing here selects, ranks or triggers an action.
Settings.GRID_LIMITS = {
    slots = {min = 1, max = 20, default = 20},       -- number of cells shown
    columns = {min = 1, max = 20, default = 10},     -- cells per row
    cellSize = {min = 24, max = 64, default = 40},   -- cell edge, UI units
    spacing = {min = 0, max = 12, default = 4},      -- gap between cells
    scale = {min = 0.5, max = 2.0, default = 1.0},   -- grid frame scale
    queueDepth = {min = 1, max = 5, default = 3},    -- queue positions labelled
}
-- Schema 1 (0.1.0) defaults, replaced by the schema 2 ones when untouched.
local SCHEMA1_DEFAULTS = {slots = 12, columns = 6}

-- Default key per cell, chosen by the owner on 2026-10-15 (same scheme as
-- HCOneButton's Action Panel): SHIFT-1..0 then CTRL-SHIFT-1..0.
Settings.DEFAULT_KEYS = {
    "SHIFT-1", "SHIFT-2", "SHIFT-3", "SHIFT-4", "SHIFT-5",
    "SHIFT-6", "SHIFT-7", "SHIFT-8", "SHIFT-9", "SHIFT-0",
    "CTRL-SHIFT-1", "CTRL-SHIFT-2", "CTRL-SHIFT-3", "CTRL-SHIFT-4", "CTRL-SHIFT-5",
    "CTRL-SHIFT-6", "CTRL-SHIFT-7", "CTRL-SHIFT-8", "CTRL-SHIFT-9", "CTRL-SHIFT-0",
}

Settings.DEFAULT_GRID_POINT = {"CENTER", "CENTER", 0, -220}
-- HCOneButton keeps its pixel immediately right of a 282 px Advisor frame.
-- There is no Advisor here, so the pixel has its own independent anchor; the
-- default keeps it well clear of the default grid.
Settings.DEFAULT_PIXEL_POINT = {"TOPLEFT", "TOPLEFT", 16, -16}

local function Clamp(value, limits)
    value = tonumber(value)
    if not value or value ~= value then return limits.default end
    if value < limits.min then return limits.min end
    if value > limits.max then return limits.max end
    return value
end

local ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function SanitizePoint(point, default)
    if type(point) ~= "table" or not ANCHOR_POINTS[point[1]] or not ANCHOR_POINTS[point[2]]
        or type(point[3]) ~= "number" or type(point[4]) ~= "number" then
        return {default[1], default[2], default[3], default[4]}
    end
    return {point[1], point[2], point[3], point[4]}
end

local function SanitizeCell(cell)
    if type(cell) ~= "table" then return nil end
    local id = tonumber(cell.id)
    if not id or id <= 0 or id ~= math.floor(id) then return nil end
    if cell.kind ~= "spell" and cell.kind ~= "item" then return nil end
    return {kind = cell.kind, id = id, auto = cell.auto == true or nil}
end

local function SanitizeCells(cells)
    local out, seen = {}, {}
    cells = type(cells) == "table" and cells or {}
    for slot = 1, ns.MAX_SLOTS do
        local cell = SanitizeCell(cells[slot])
        if cell then
            local identity = cell.kind .. ":" .. cell.id
            if not seen[identity] then -- one cell per action, as enforced on assign
                seen[identity] = true
                out[slot] = cell
            end
        end
    end
    return out
end

-- Account table. Unknown keys disappear. keys[n] is a key string, `false`
-- (the user removed the key: no default) or absent (default key).
function Settings.Sanitize(raw)
    if type(raw) ~= "table" then raw = {} end
    local db = {schema = Settings.SCHEMA, keys = {}, grid = {}, pixel = {}}

    local keys = type(raw.keys) == "table" and raw.keys or {}
    local usedKeys = {}
    for slot = 1, ns.MAX_SLOTS do
        if keys[slot] == false then
            db.keys[slot] = false
        else
            local key = ns.Keys.Normalize(keys[slot])
            if key and ns.Keys.IsAllowed(key) and not usedKeys[key] then
                usedKeys[key] = true
                db.keys[slot] = key
            end
        end
    end

    local grid = type(raw.grid) == "table" and raw.grid or {}
    if raw.schema == 1 and grid.slots == SCHEMA1_DEFAULTS.slots and grid.columns == SCHEMA1_DEFAULTS.columns then
        grid.slots, grid.columns = nil, nil
    end
    for name, limits in pairs(Settings.GRID_LIMITS) do
        db.grid[name] = Clamp(grid[name], limits)
    end
    for _, name in ipairs({"slots", "columns", "cellSize", "spacing", "queueDepth"}) do
        db.grid[name] = math.floor(db.grid[name] + 0.5)
    end
    db.grid.locked = grid.locked ~= false
    db.grid.shown = grid.shown ~= false
    db.grid.point = SanitizePoint(grid.point, Settings.DEFAULT_GRID_POINT)

    local pixel = type(raw.pixel) == "table" and raw.pixel or {}
    db.pixel.enabled = pixel.enabled ~= false
    db.pixel.locked = pixel.locked ~= false
    -- Owner decision 2026-10-15: out of combat the pixel stays black.
    db.pixel.combatOnly = pixel.combatOnly ~= false
    db.pixel.point = SanitizePoint(pixel.point, Settings.DEFAULT_PIXEL_POINT)

    db.autoFill = raw.autoFill ~= false
    -- Owner decision 2026-10-15: optionally hide Blizzard's bottom bar
    -- (stance and experience bars stay). Off by default.
    db.hideBlizzardBar = raw.hideBlizzardBar == true
    return db
end

-- Character table: cell actions and the spells the user removed from the
-- automatic fill (by spell name, so every rank stays removed).
function Settings.SanitizeChar(raw)
    if type(raw) ~= "table" then raw = {} end
    local db = {schema = Settings.CHAR_SCHEMA, cells = SanitizeCells(raw.cells), dismissed = {}}
    if type(raw.dismissed) == "table" then
        for name, flag in pairs(raw.dismissed) do
            if type(name) == "string" and flag == true then db.dismissed[name] = true end
        end
    end
    return db
end

function Settings.Load()
    local account = ForeverOneButtonDB
    local legacyCells = type(account) == "table" and account.schema == 1 and account.cells or nil
    ForeverOneButtonDB = Settings.Sanitize(account)
    -- 0.1.0 kept cells account-wide: they move to the first character that
    -- logs in with an empty cell table.
    local char = type(ForeverOneButtonCharDB) == "table" and ForeverOneButtonCharDB or {}
    if legacyCells and (type(char.cells) ~= "table" or next(char.cells) == nil) then
        char.cells = legacyCells
    end
    ForeverOneButtonCharDB = Settings.SanitizeChar(char)
    Settings.db = ForeverOneButtonDB
    Settings.char = ForeverOneButtonCharDB
    return Settings.db
end

function Settings.Get()
    return Settings.db
end

function Settings.Char()
    return Settings.char
end

-- Effective key of a cell: the user's key, none if the user removed it, else
-- the default key unless another cell explicitly uses that key.
function Settings.KeyFor(slot)
    local keys = Settings.db.keys
    local key = keys[slot]
    if key == false then return nil end
    if key then return key end
    local default = Settings.DEFAULT_KEYS[slot]
    for other = 1, ns.MAX_SLOTS do
        if other ~= slot and keys[other] == default then return nil end
    end
    return default
end

-- Whitelisted scalar grid options only. Returns ok, message.
function Settings.SetGridValue(name, value)
    local limits = Settings.GRID_LIMITS[name]
    if not limits then return false, "unknown option" end
    if ns.InCombat() then return false, "layout changes are blocked in combat" end
    local clamped = Clamp(value, limits)
    if name ~= "scale" then clamped = math.floor(clamped + 0.5) end
    Settings.db.grid[name] = clamped
    if ns.Grid and ns.Grid.ApplyLayout then ns.Grid.ApplyLayout() end
    return true
end

function Settings.ResetLayout()
    if ns.InCombat() then return false, "layout changes are blocked in combat" end
    local db = Settings.db
    for name, limits in pairs(Settings.GRID_LIMITS) do db.grid[name] = limits.default end
    db.grid.point = SanitizePoint(nil, Settings.DEFAULT_GRID_POINT)
    if ns.Grid and ns.Grid.ApplyLayout then ns.Grid.ApplyLayout() end
    return true
end
