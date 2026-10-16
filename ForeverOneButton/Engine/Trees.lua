-- Forever One Button: which priority list applies.
--
-- The class's talent tree with the most points spent; with no points (or no
-- readable talent data) the class default (Data/Rotations.lua `default`).
-- The context follows the engaged enemies: 1 st, 2 cleave, 3+ aoe; a missing
-- list falls back to the next simpler one (cleave -> aoe -> st, aoe -> st).
local ADDON_NAME, ns = ...

local Trees = {}
ns.Trees = Trees

local FALLBACK = {cleave = {"cleave", "aoe", "st"}, aoe = {"aoe", "st"}, st = {"st"}}

function Trees.Class()
    if not UnitClass then return nil end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or not ns.Readable(class) then return nil end
    return class
end

local function Slug(name)
    if type(name) ~= "string" or ns.IsSecret(name) then return nil end
    return (name:lower():gsub("[^%a]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

-- Points spent per talent tree, by slug; nil when unreadable. The same reads
-- Forever's talent frame makes: one currency query for all trait groups.
local function SpentByTree()
    if not (C_ClassTalents and C_Traits and C_SpecializationInfo) then return nil end
    local ok, spent = pcall(function()
        local configID = C_ClassTalents.GetActiveConfigID()
        local spec = C_SpecializationInfo.GetSpecialization()
        local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
        local treeID = specID and C_ClassTalents.GetTraitTreeForSpec(specID)
        if not (configID and treeID) then return nil end
        local displays = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
        if type(displays) ~= "table" then return nil end
        local ids, names = {}, {}
        for i, display in ipairs(displays) do
            ids[i] = display.groupID
            names[display.groupID] = Slug(display.displayName)
        end
        local out = {}
        for _, info in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
            local currency = info.currencyInfos and info.currencyInfos[1]
            local n = currency and (currency.spentInTree or currency.spent)
            local slug = names[info.traitNodeGroupID]
            if slug and type(n) == "number" and not ns.IsSecret(n) then out[slug] = n end
        end
        return out
    end)
    if ok then return spent end
    return nil
end

-- Bear and Dire Bear Form (GetShapeshiftFormID 5 and 8).
local function BearForm()
    if not GetShapeshiftFormID then return false end
    local ok, id = pcall(GetShapeshiftFormID)
    return ok and ns.Readable(id) and (id == 5 or id == 8)
end

local picked -- [class] = tree key, until talents or spells change
function Trees.Invalidate() picked = nil end

function Trees.Pick(class)
    local trees = class and ns.Data.Rotations.classes[class]
    if not trees then return nil end
    picked = picked or {}
    if picked[class] then return picked[class] end
    local best, bestSpent = nil, 0
    for slug, n in pairs(SpentByTree() or {}) do
        -- "feral_combat" -> "feral" when only the first word names a list.
        local first = slug:match("^[^_]+")
        local key = (trees[slug] and slug) or (first and trees[first] and first)
        if key and n > bestSpent then best, bestSpent = key, n end
    end
    best = best or trees.default
    -- Feral: bear form has its own list.
    if best == "feral" and trees.feral_bear and BearForm() then best = "feral_bear" end
    picked[class] = best
    return best
end

function Trees.Context(enemies)
    if enemies >= 3 then return "aoe" end
    if enemies == 2 then return "cleave" end
    return "st"
end

-- Below level 60 the leveling lists (Data/Leveling.lua: the tree's own, or
-- the class's base list); from 60 the imported level-60 lists.
Trees.LEVELING_BELOW = 60
function Trees.Leveling()
    if not UnitLevel then return false end
    local ok, level = pcall(UnitLevel, "player")
    if not ok or not ns.Readable(level) or type(level) ~= "number" then return false end
    return level < Trees.LEVELING_BELOW
end

-- The contexts (st / cleave / aoe lists) for class and tree, and whether
-- they are the leveling ones.
function Trees.Contexts(class, tree)
    if Trees.Leveling() then
        local leveling = ns.Data.Leveling[class]
        local contexts = leveling and (leveling[tree] or leveling.base)
        if contexts then return contexts, true end
    end
    local trees = ns.Data.Rotations.classes[class]
    return trees and trees[tree], false
end

-- The list for class / tree / context, the context actually used and
-- whether it is a leveling list.
function Trees.List(class, tree, context)
    local contexts, leveling = Trees.Contexts(class, tree)
    if not contexts then return nil end
    for _, key in ipairs(FALLBACK[context] or FALLBACK.st) do
        if contexts[key] then return contexts[key], key, leveling end
    end
    return nil
end
