-- Forever One Button: bridge model and refresh loop.
--
-- Builds the suggestion queue (Engine/Queue.lua) on a fixed poll, derives
-- the observations the pixel protocol needs, and hands both to the grid and
-- the pixel. Game state changes without events for most of what the queue
-- reads (resources, cooldowns, range), hence the poll.
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

-- One refresh: build the queue, derive the pixel head, notify consumers.
-- An unchanged queue yields the same snapshot object.
function Model.Refresh()
    local ok, snapshot = pcall(ns.Queue.Build, lastSnapshot)
    if not ok then
        snapshot = {status = ns.STATUS.ERROR, detail = tostring(snapshot), entries = {}, count = 0}
        if lastSnapshot and lastSnapshot.status == ns.STATUS.ERROR and lastSnapshot.detail == snapshot.detail then
            snapshot = lastSnapshot
        end
    end
    Model.snapshot = snapshot

    local head = ns.Queue.Head(snapshot)
    local casting = PlayerIsCasting()
    local outOfRange = head ~= nil and not casting and ConfirmedOutOfRange(head)
    Model.observation.casting = casting
    Model.observation.outOfRange = outOfRange
    -- Combat-only pixel (owner decision 2026-10-15, default on): out of combat
    -- the pixel publishes protocol black, "no executable recommendation". Only
    -- the moment changes; the encoder and its colours do not. The grid still
    -- shows the suggestions.
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

    -- Defensive row: beside the grid, never in the pixel.
    local okDefense, row = pcall(ns.Defensives.Suggest)
    if not okDefense then row = nil end
    local signature = ""
    for _, entry in ipairs(row and row.entries or {}) do
        signature = signature .. entry.id .. (entry.ready and "r" or "") .. (entry.waiting and "w" or "") .. ","
    end
    if signature ~= Model.defenseSignature then
        Model.defenseSignature, Model.defenses = signature, row
        if ns.Grid and ns.Grid.ShowDefensives then ns.Grid.ShowDefensives(row) end
    end

    -- Interrupt suggestion: shown beside the grid, never in the pixel.
    local okInterrupt, interrupt = pcall(ns.Interrupts.Suggest)
    if not okInterrupt then interrupt = nil end
    local before = Model.interrupt
    if (interrupt and interrupt.id) ~= (before and before.id) then
        Model.interrupt = interrupt
        if ns.Grid and ns.Grid.ShowInterrupt then ns.Grid.ShowInterrupt(interrupt) end
    end
    return changed
end

-- Forget everything shown, e.g. while the UI is torn down. Nothing obsolete
-- may stay on screen looking current.
function Model.Reset()
    lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat = nil, nil, nil, nil
    Model.snapshot = {status = ns.STATUS.MISSING, entries = {}, count = 0}
    Model.pixelHead = nil
    Model.interrupt = nil
    if ns.Grid and ns.Grid.ShowInterrupt then ns.Grid.ShowInterrupt(nil) end
    Model.defenses, Model.defenseSignature = nil, ""
    if ns.Grid and ns.Grid.ShowDefensives then ns.Grid.ShowDefensives(nil) end
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
