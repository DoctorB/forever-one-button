-- Forever One Button: spell ranks.
--
-- The data names every spell by its rank-1 ID (Data/Rotations.lua rankChains:
-- rank 1 first, in learn order). Cells and the queue use the highest rank
-- known, for every class. The Blizzard bars are not read: the addon hides
-- them, and they can still hold the rank learned first.
local ADDON_NAME, ns = ...

local Ranks = {}
ns.Ranks = Ranks

local base -- [any rank] = rank 1
local function Index()
    if base then return end
    base = {}
    for first, chain in pairs(ns.Data.Rotations.rankChains) do
        for _, id in ipairs(chain) do base[id] = first end
    end
end

function Ranks.Base(spellID)
    Index()
    return base[spellID] or spellID
end

function Ranks.Chain(spellID)
    return ns.Data.Rotations.rankChains[Ranks.Base(spellID)]
end

-- Known spells do not change in a fight, but the client may answer with a
-- secret there: the last plain answer is kept (every plain answer replaces
-- it, so learning or unlearning a spell updates it) and used whenever the
-- current one cannot be read.
local knownCache = {}

local function Ask(query, spellID)
    if not query then return nil end
    local ok, known = pcall(query, spellID)
    if not ok or ns.IsSecret(known) or known == nil then return nil end
    return known == true
end

function Ranks.Known(spellID)
    local player, book = Ask(IsPlayerSpell, spellID), Ask(IsSpellKnown, spellID)
    if player == nil and book == nil then return knownCache[spellID] == true end
    local known = player == true or book == true
    knownCache[spellID] = known
    return known
end

-- Highest known rank of the spell, or nil when no rank is known.
function Ranks.HighestKnown(spellID)
    local chain = Ranks.Chain(spellID)
    if not chain then return Ranks.Known(spellID) and spellID or nil end
    for i = #chain, 1, -1 do
        if Ranks.Known(chain[i]) then return chain[i] end
    end
    return nil
end

-- A known rank of the spell higher than this one, the highest; nil when
-- there is none.
function Ranks.Higher(spellID)
    local chain = Ranks.Chain(spellID)
    if not chain then return nil end
    for i = #chain, 1, -1 do
        if chain[i] == spellID then return nil end
        if Ranks.Known(chain[i]) then return chain[i] end
    end
    return nil
end

-- The rank to show and press.
function Ranks.Pressed(spellID)
    return Ranks.HighestKnown(spellID)
end
