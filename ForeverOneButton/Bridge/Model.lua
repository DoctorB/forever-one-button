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

local function Harmful(spellID)
    if not (C_Spell and type(C_Spell.IsSpellHarmful) == "function") then return nil end
    local harmful = ns.SafeCall(C_Spell.IsSpellHarmful, spellID)
    if harmful == nil or ns.IsSecret(harmful) then return nil end
    return harmful == true
end

-- An attack with no living enemy targeted: pressed at that moment, the client
-- picks the nearest enemy by itself (the player never chose it). Black until
-- a living enemy is targeted. Only a readable "harmful" counts; spells on
-- the player (shouts, seals, stances, the emergency heal) are unaffected.
local function AttackWithoutTarget(snapshot, head, entry)
    local first = entry or snapshot.entries[1]
    if not (first and first.kind == ns.ENTRY.SPELL and first.id == head) then return false end
    if ns.State.TargetAttackable() then return false end
    return Harmful(head) == true
end
Model.AttackWithoutTarget = AttackWithoutTarget

-- Cell 20 is pressed by hand only. Its key, CTRL-SHIFT-0, never reached the
-- game from the reader (owner's logs of 2026-11-20/21: Challenging Shout on
-- the pixel for 94 s and the Healing Potion for 26-35 s per session without
-- a single cast or error), and while it led the pixel nothing else was
-- pressed. The grid still shows it first; the pixel moves on to the next
-- ready action (owner decision 2026-11-21).
Model.MANUAL_SLOT = 20

-- Position 1 for the pixel: the queue head, or, when the head sits on the
-- manual cell, the next ready action on another cell. Returns id, entry.
function Model.PixelHead(snapshot)
    local head = ns.Queue.Head(snapshot)
    if not head then return nil, nil end
    local entries = snapshot.entries
    if ns.Actions.SlotFor(head) ~= Model.MANUAL_SLOT then return head, entries[1] end
    for i = 2, #entries do
        local entry = entries[i]
        if not entry.ready then break end
        if (entry.kind == ns.ENTRY.SPELL or entry.kind == ns.ENTRY.ITEM)
            and ns.Actions.SlotFor(entry.id) ~= Model.MANUAL_SLOT then
            return entry.id, entry
        end
    end
    return nil, nil
end

local lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat, lastNoTarget = nil, nil, nil, nil, nil
local lastInterruptHead = nil
local lastControlled = false
local lastLogged -- the snapshot last written to the diagnostic log

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

    local head, headEntry = Model.PixelHead(snapshot)
    local casting = PlayerIsCasting()
    -- An emergency heal is cast on the player: the target's range does not apply.
    local selfHeal = headEntry and headEntry.emergency
    -- Interrupt (owner request 2026-11-14: what is suggested, the reader
    -- presses): the suggested kick, or crowd control as fallback, takes the
    -- pixel ahead of the rotation when it has a cell; only the emergency
    -- heal comes before it. Engine/Interrupts.lua already checks readiness,
    -- reach and the debounce after a cast.
    local okInterrupt, interrupt = pcall(ns.Interrupts.Suggest)
    if not okInterrupt then interrupt = nil end
    local interruptSlot = interrupt and interrupt.id and ns.Actions.SlotFor(interrupt.id)
    local interruptHead = (interruptSlot and not selfHeal and interruptSlot ~= Model.MANUAL_SLOT) == true
    if interruptHead then head = interrupt.id end
    local outOfRange = head ~= nil and not casting and not selfHeal and ConfirmedOutOfRange(head)
    local noTarget = head ~= nil and not casting and not selfHeal and AttackWithoutTarget(snapshot, head, headEntry)
    Model.observation.casting = casting
    Model.observation.outOfRange = outOfRange
    Model.observation.noTarget = noTarget
    -- Combat-only pixel (owner decision 2026-10-15, default on): out of combat
    -- the pixel publishes protocol black, "no executable recommendation". Only
    -- the moment changes; the encoder and its colours do not. The grid still
    -- shows the suggestions.
    -- Exception (owner request 2026-11-14): a stealth opener on an
    -- attackable target is published out of combat too, so the reader
    -- presses it; it is what starts the fight. Not on a target the player
    -- tried to Pick Pocket or Sap (owner decision 2026-11-14).
    local opener = snapshot.entries[1] and snapshot.entries[1].opener and ns.State.Stealthed() == true
        and ns.State.TargetAttackable() == true and not ns.Targets.OpenerHeld()
    local outOfCombat = ns.Settings.Get().pixel.combatOnly and not ns.InCombat() and not opener
    Model.observation.outOfCombat = outOfCombat
    -- Stunned, feared or charmed: protocol black until control comes back,
    -- instead of presses the client refuses. The grid still shows the queue.
    local lost, controlSource = ns.State.ControlLost()
    local controlled = lost == true
    Model.observation.controlled = controlled
    if controlled ~= lastControlled then ns.Log("control", controlled and "lost" or "back", controlSource or "?") end
    if casting or outOfRange or noTarget or outOfCombat or controlled then head = nil end

    local changed = snapshot ~= lastSnapshot or casting ~= lastCasting or outOfRange ~= lastOutOfRange
        or outOfCombat ~= lastOutOfCombat or noTarget ~= lastNoTarget or interruptHead ~= lastInterruptHead
        or controlled ~= lastControlled
    lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat, lastNoTarget =
        snapshot, casting, outOfRange, outOfCombat, noTarget
    lastInterruptHead, lastControlled = interruptHead, controlled

    if head ~= Model.pixelHead or changed then
        if changed then
            if snapshot ~= lastLogged then
                lastLogged = snapshot
                ns.Log("queue", snapshot.status, (snapshot.tree or "-") .. (snapshot.leveling and "+leveling" or ""),
                    snapshot.context or "-", snapshot.count or 0,
                    snapshot.candidates or "-", snapshot.ready or "-", snapshot.detail or "-",
                    snapshot.why or "-")
            end
            local first = snapshot.entries[1]
            ns.Log("head", interruptHead and interrupt.id or (first and first.id) or "none",
                (casting and "c" or "") .. (outOfRange and "r" or "") .. (noTarget and "t" or "")
                    .. (outOfCombat and "o" or "") .. (controlled and "x" or "")
                    .. (headEntry and headEntry ~= first and ("m" .. headEntry.id) or "") .. "-")
        end
        Model.pixelHead = head
        ns.Pixel.Update(head)
    end
    if changed and ns.Grid and ns.Grid.ShowQueue then ns.Grid.ShowQueue(snapshot, Model.observation) end
    -- Cooldowns and usability on the cells change without a queue change.
    if ns.Grid and ns.Grid.RefreshCooldowns then ns.Grid.RefreshCooldowns() end

    -- Reminder row, out of combat, at most once a second.
    local now = GetTime()
    if not ns.InCombat() and ns.Reminders and now - (Model.remindersAt or -math.huge) >= ns.Reminders.REFRESH_SECONDS then
        Model.remindersAt = now
        ns.Reminders.Update()
    end

    -- Defensive row: beside the grid. Only the emergency heal (Queue.Build)
    -- reaches the pixel.
    local okDefense, row = pcall(ns.Defensives.Suggest)
    if not okDefense then row = nil end
    local signature = ""
    for _, entry in ipairs(row and row.entries or {}) do
        signature = signature .. entry.id .. (entry.ready and "r" or "") .. (entry.waiting and "w" or "") .. ","
    end
    if signature ~= Model.defenseSignature then
        Model.defenseSignature, Model.defenses = signature, row
        ns.Log("defense", signature ~= "" and signature or "none", row and row.band or "-")
        if ns.Grid and ns.Grid.ShowDefensives then ns.Grid.ShowDefensives(row) end
    end

    -- Interrupt suggestion: shown beside the grid; in the pixel above. The
    -- log line also says why nothing was suggested while the target casts,
    -- and "noslot" when the suggestion has no cell to press.
    local before = Model.interrupt
    local why = okInterrupt and ns.Interrupts.why or nil
    if interrupt and interrupt.id and not interruptHead then
        why = (why and why .. "," or "") .. (selfHeal and "heal" or "noslot")
    end
    if (interrupt and interrupt.id) ~= (before and before.id) then
        Model.interrupt = interrupt
        if ns.Grid and ns.Grid.ShowInterrupt then ns.Grid.ShowInterrupt(interrupt) end
    end
    local line = tostring(interrupt and interrupt.id or "none") .. "|" .. (why or "-")
    if line ~= Model.interruptLine then
        Model.interruptLine = line
        ns.Log("interrupt", interrupt and interrupt.id or "none", interrupt and interrupt.kind or "-", why or "-")
    end

    -- Enemies on someone else in the group (tanks: owner request
    -- 2026-11-16): the warning above the grid and a log line on change.
    -- The line carries the plate readings (State.looseDetail).
    local loose, detail = 0, "-"
    if ns.InCombat() and ns.State.InGroup() then
        loose = ns.State.LooseCount()
        detail = ns.State.looseDetail
    end
    if detail ~= Model.looseDetail then
        Model.looseDetail = detail
        ns.Log("loose", loose, detail)
    end
    if loose ~= Model.loose then
        Model.loose = loose
        if ns.Grid and ns.Grid.ShowLoose then ns.Grid.ShowLoose(loose) end
    end
    return changed
end

-- Forget everything shown, e.g. while the UI is torn down. Nothing obsolete
-- may stay on screen looking current.
function Model.Reset()
    lastSnapshot, lastCasting, lastOutOfRange, lastOutOfCombat, lastNoTarget = nil, nil, nil, nil, nil
    lastInterruptHead, lastControlled = nil, false
    Model.snapshot = {status = ns.STATUS.MISSING, entries = {}, count = 0}
    Model.pixelHead = nil
    Model.interrupt = nil
    Model.interruptLine = nil
    if ns.Grid and ns.Grid.ShowInterrupt then ns.Grid.ShowInterrupt(nil) end
    Model.loose, Model.looseDetail = nil, nil
    if ns.Grid and ns.Grid.ShowLoose then ns.Grid.ShowLoose(0) end
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
    Model.running = true
    elapsedSinceRefresh = Model.POLL_SECONDS
    driver:SetScript("OnUpdate", OnUpdate)
    driver:Show()
end

function Model.Stop()
    Model.running = false
    driver:SetScript("OnUpdate", nil)
    Model.Reset()
end
