-- Forever One Button: bridge model and refresh loop.
--
-- Holds the latest JustAC snapshot and the observations the pixel protocol
-- needs, and hands both to the grid and the pixel. It contains no rotation:
-- it never picks, ranks or replaces a spell.
--
-- JustAC exposes no queue-change callback (its own renderer polls from an
-- OnUpdate loop, JustAC.lua:2322), so the model polls the public function.
-- POLL_SECONDS equals JustAC's out-of-combat build throttle (SpellQueue.lua:2350):
-- a faster poll would only return JustAC's cached table.
local ADDON_NAME, ns = ...

local Model = {}
ns.Model = Model

Model.POLL_SECONDS = 0.05
Model.snapshot = {status = ns.STATUS.MISSING, entries = {}, count = 0}
Model.pixelHead = nil
Model.observation = {casting = false, outOfRange = false, outOfCombat = false}

local function Active(query)
    if type(query) ~= "function" then return false end
    local ok, name = pcall(query, "player")
    return ok and (ns.IsSecret(name) or name ~= nil)
end

local function PlayerIsCasting()
    -- HCOneButton protocol v3 publishes black "while the player is finishing
    -- any cast/channel" (HCOneButton README, protocol v3, step 4).
    -- A secret result is still a non-nil result: a cast is in progress.
    return Active(UnitCastingInfo) or Active(UnitChannelInfo)
end

local function ConfirmedOutOfRange(queueID)
    -- Protocol v3 also publishes black when the recommendation is out of
    -- range. Only an explicit, readable `false` counts; unknown range never
    -- suppresses anything. Items have no client range answer here.
    if type(queueID) ~= "number" or queueID <= 0 then return false end
    if not C_Spell or type(C_Spell.IsSpellInRange) ~= "function" then return false end
    if type(UnitExists) == "function" and not ns.SafeCall(UnitExists, "target") then return false end
    local inRange = ns.SafeCall(C_Spell.IsSpellInRange, queueID, "target")
    return inRange == false
end

local lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat = nil, nil, nil, nil

-- One refresh: read JustAC, derive the pixel head, notify consumers.
-- An unchanged JustAC queue yields the same snapshot object (no allocation).
function Model.Refresh()
    local snapshot = ns.JustAC.Read(lastSnapshot)
    Model.snapshot = snapshot

    local head = ns.JustAC.Head(snapshot)
    local casting = PlayerIsCasting()
    local outOfRange = head ~= nil and not casting and ConfirmedOutOfRange(head)
    Model.observation.casting = casting
    Model.observation.outOfRange = outOfRange
    -- Combat-only pixel (owner decision 2026-10-15, default on): out of combat
    -- the pixel publishes protocol black, "no executable recommendation". Only
    -- the moment changes; the encoder and its colours do not. The grid still
    -- shows JustAC's suggestions.
    local outOfCombat = ns.Settings.Get().pixel.combatOnly and not ns.InCombat()
    Model.observation.outOfCombat = outOfCombat
    if casting or outOfRange or outOfCombat then head = nil end

    local changed = snapshot ~= lastSnapshot or casting ~= lastCasting or outOfRange ~= lastOutOfRange
        or outOfCombat ~= lastOutOfCombat
    lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat = snapshot, casting, outOfRange, outOfCombat

    if head ~= Model.pixelHead or changed then
        if changed then
            local first = snapshot.entries[1]
            ns.Log("head", first and first.id or "none",
                (casting and "c" or "") .. (outOfRange and "r" or "") .. (outOfCombat and "o" or "") .. "-")
        end
        Model.pixelHead = head
        ns.Pixel.Update(head)
    end
    if changed and ns.Grid and ns.Grid.ShowQueue then ns.Grid.ShowQueue(snapshot, Model.observation) end
    return changed
end

-- Forget everything shown, e.g. while the UI is torn down. Nothing obsolete
-- may stay on screen looking current.
function Model.Reset()
    lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat = nil, nil, nil, nil
    Model.snapshot = {status = ns.STATUS.MISSING, entries = {}, count = 0}
    Model.pixelHead = nil
    ns.Pixel.Update(nil)
end

-- No parent: the poll keeps running while the UI is hidden (Alt+Z).
local driver = CreateFrame("Frame", "ForeverOneButtonDriver")
local elapsedSinceRefresh = 0
Model.driver = driver

local function OnUpdate(_, elapsed)
    elapsedSinceRefresh = elapsedSinceRefresh + (elapsed or 0)
    if elapsedSinceRefresh < Model.POLL_SECONDS then return end
    elapsedSinceRefresh = 0
    Model.Refresh()
end

function Model.Start()
    elapsedSinceRefresh = Model.POLL_SECONDS
    driver:SetScript("OnUpdate", OnUpdate)
    driver:Show()
end

function Model.Stop()
    driver:SetScript("OnUpdate", nil)
    Model.Reset()
end
