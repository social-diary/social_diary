-- The reunion toasts' queue (REU-1, REU-2, REU-5): one card shows at a
-- time, for TOAST_SECONDS, longer while the mouse is on it.
--
-- REU-2: nothing appears in combat. Toasts wait in a queue and the queue
-- moves on PLAYER_REGEN_ENABLED, and a card already up when a fight starts
-- goes back to the front of it, to come again after. One toast shows at a time; a raid full of
-- friends would otherwise bury the screen, so the queue is capped and the
-- overflow becomes one "and N more" toast at the end.
--
-- Here: showing a card and putting it away (Display, Dismiss, Hover), the
-- combat gate (InCombat, Pump), forgetting (PRV-3), and the entry points:
-- ns.UI.Reunion, with the SD_REUNION handler that calls it, and a
-- feature's own kinds of card (Toast.RegisterKind, SD_TOAST), which share
-- the one card, the queue and its cap, the gate and the forgetting with
-- the reunions, but none of a reunion's rules. The card is
-- UI/Windows/Reunion/Toast.lua, which lists the state shared on
-- ns.UI.Toast; its words Words.lua's; placing it Placing.lua's.

local addonName, ns = ...

local Toast = ns.UI.Toast

local TOAST_SECONDS = 7
-- While the mouse is on it the card stays; once it leaves a card that is
-- past its time, the card goes this much later.
local LINGER_SECONDS = 1.5
local MAX_QUEUE = 5

--------------------------------------------------------------------------
-- Showing
--------------------------------------------------------------------------

local Pump

local function Dismiss()
    Toast.showing, Toast.overdue = nil, false
    if Toast.toast then Toast.toast:Hide() end
    Pump()
end
Toast.Dismiss = Dismiss

local function Hover(over)
    Toast.hovered = over
    if over or not Toast.overdue then return end
    local shown = Toast.shown
    C_Timer.After(LINGER_SECONDS, function()
        if Toast.showing and Toast.shown == shown and not Toast.hovered then Dismiss() end
    end)
end
Toast.Hover = Hover

local function Display(snap)
    Toast.toast = Toast.toast or Toast.Build()
    local toast = Toast.toast
    Toast.showing, Toast.overdue = snap, false
    -- This showing's own number, for its timers: a card put back in the
    -- queue comes again as the same snapshot, and a timer left from its
    -- first showing must not take it for its own and put it away early.
    Toast.shown = (Toast.shown or 0) + 1
    local shown = Toast.shown

    toast:Show()
    toast:Raise()
    toast:Fill(snap)
    toast.view:Show()

    C_Timer.After(TOAST_SECONDS, function()
        if not Toast.showing or Toast.shown ~= shown then return end
        if Toast.hovered then Toast.overdue = true else Dismiss() end
    end)
end

local function InCombat()
    return (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and ns.Plain(UnitAffectingCombat("player")))
end
Toast.InCombat = InCombat

Pump = function()
    if Toast.showing or Toast.placing or InCombat() then return end

    local snap = table.remove(Toast.queue, 1)
    if not snap and Toast.more > 0 then
        snap = { more = Toast.more, reason = Toast.moreReason }
        Toast.more, Toast.moreReason = 0, nil
    end
    -- Then each kind's own flood, one card for each, in the order the kinds
    -- registered: never folded into the reunions' count, whose words are
    -- about diary entries joining or coming near.
    if not snap then
        local moreKinds = Toast.moreKinds
        for _, spec in ipairs(Toast.kindOrder) do
            local count = moreKinds[spec.kind]
            if count and count > 0 then
                moreKinds[spec.kind] = nil
                snap = { more = count, kind = spec.kind }
                break
            end
        end
    end
    if snap then Display(snap) end
end
Toast.Pump = Pump

ns.On("PLAYER_REGEN_ENABLED", function() Pump() end)

-- REU-2 holds for the card already up too, mouse on it or not: it goes, and
-- comes again first in line. It may take the queue one past MAX_QUEUE, which
-- only caps who joins: nobody is lost to a fight. An "and N more" card goes
-- back into the count, to stay last.
ns.On("PLAYER_REGEN_DISABLED", function()
    local snap = Toast.showing
    if not snap then return end
    Toast.showing, Toast.overdue, Toast.hovered = nil, false, false
    Toast.toast:Hide()
    if snap.more and snap.kind then
        Toast.moreKinds[snap.kind] = (Toast.moreKinds[snap.kind] or 0) + snap.more
    elseif snap.more then
        Toast.more = Toast.more + snap.more
        Toast.moreReason = (Toast.moreReason == nil or Toast.moreReason == snap.reason) and snap.reason or "mixed"
    else
        table.insert(Toast.queue, 1, snap)
    end
end)

--------------------------------------------------------------------------
-- Forgetting
--------------------------------------------------------------------------

-- PRV-3: a toast still waiting to show a forgotten person goes, and so does
-- one showing them now, of whatever kind. Their cooldown stamp is
-- Core/Reunions.lua's store; what a feature's kind keeps of them is the
-- feature's to forget.
ns.RegisterStore("toasts", function(guid)
    if guid == nil then
        Toast.more, Toast.moreReason = 0, nil
        wipe(Toast.moreKinds)
    end

    local queue = Toast.queue
    for i = #queue, 1, -1 do
        if guid == nil or queue[i].guid == guid then table.remove(queue, i) end
    end
    local showing = Toast.showing
    if showing and (guid == nil or showing.guid == guid) then Dismiss() end
end)

--------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------

-- REU-1 and REU-5. `reason` is "group" (the default) or "nearby".
function ns.UI.Reunion(guid, reason)
    reason = reason or "group"
    local now = ns.Now()
    guid = ns.Reunions.Due(guid, reason, now)
    if not guid then return end

    -- Without a cooldown (a foe, settings.foeToastsUncooled) a nameplate
    -- at the edge of range comes and goes: one toast per person in line. A
    -- feature's card about them (snap.kind) is another matter, and does
    -- not stand in for their reunion.
    local showing, queue = Toast.showing, Toast.queue
    if showing and showing.guid == guid and not showing.kind then return end
    for i = 1, #queue do
        if queue[i].guid == guid and not queue[i].kind then return end
    end

    local snap = Toast.Snapshot(guid, reason)
    if not snap then return end
    ns.Reunions.Greet(guid, now)

    if #queue >= MAX_QUEUE then
        Toast.more = Toast.more + 1
        Toast.moreReason = (Toast.moreReason == nil or Toast.moreReason == reason) and reason or "mixed"
    else
        queue[#queue + 1] = snap
    end
    Pump()
end

-- The foe alert's sound, for the Sounds settings to play as a sample too.
function Toast.PlayFoeAlert()
    ns.Style.PlaySound("foeAlert", "Master")
end

-- Capture says who; this file decides whether that is worth a toast, and
-- Core/Reunions.lua whether it is a foe worth a warning.
ns.On("SD_REUNION", function(_, guid, reason)
    if reason == "nearby" and ns.Reunions.FoeAlert(guid) then Toast.PlayFoeAlert() end
    ns.UI.Reunion(guid, reason)
end)

--------------------------------------------------------------------------
-- A feature's own kinds of card
--------------------------------------------------------------------------
--
-- The reunion card is the one place the diary speaks up during play, so a
-- feature with something to say about a person in the world (someone you
-- meet wearing the boots you made them) says it there rather than with a
-- window of its own: one card at a time, never in a fight, out of the way
-- of the forgetting. But a reunion's rules are about diary entries met
-- again: its switches, its per-person cooldown, the quiet list, a
-- snapshot read off the entry, words that say who joined. A feature's card
-- may well be about a stranger, and keeps its own count of what it has
-- said (once ever, once a connection). So a kind brings its own rule, its
-- own snapshot and its own words, and borrows only the card and the line
-- it waits in.
--
--   ns.UI.Toast.RegisterKind(kind, {
--       snapshot = function(guid, data, now) ... end,
--           -- the card's snapshot, taken now, or nil for no toast. Asked
--           -- only once the toast is going to be queued (its kind due, no
--           -- twin in line), so a kind that counts its toasts may stamp
--           -- here. Strangers allowed: read the name and the record from
--           -- ns.Characters, never from a diary entry. The card reads
--           -- from it only `record` (the portrait; nil shows the diary's
--           -- own book); the rest is the kind's, for its `text`. The
--           -- dispatch writes .kind, .guid and .key into it, over
--           -- anything of the same name.
--       text = function(snap) ... end,
--           -- what the card says, in the shape ns.UI.ReunionText returns
--           -- (Words.lua, above it): `heading`, `name`, `stories` longest
--           -- first for the card to take the first that fits; optional
--           -- `who` (longest first), `tags`, `relationship`, `warning`.
--           -- Every string through L["..."].
--       due = function(guid, data, now) ... end,          -- optional
--           -- the kind's own rule: false or nil, no toast. Without it,
--           -- always due. None of a reunion's rules are asked for a kind:
--           -- not the cooldown, the quiet list, Reunions.Greet, the
--           -- `toasts` / `nearbyToasts` switches, nor the battleground's
--           -- hush; a kind that wants one asks it here.
--       setting = "someKey",                               -- optional
--           -- a per-character settings key of the kind's own that turns
--           -- it off when false. On by default: registering gives it the
--           -- default true (ns.RegisterSettingDefault, Core/DB.lua), so
--           -- the feature never touches Core/DB.lua for it, and a saved
--           -- file from before the kind existed reads as on. Under the
--           -- master switch (`showToasts`), as every toast is.
--       label = L["..."],                                  -- optional
--           -- the switch's words on Settings' Toasts page: a kind with
--           -- both `setting` and `label` gets a switch there, under the
--           -- master one, in the order the kinds registered
--           -- (UI/Settings/Sections/Toasts.lua). Without a label the
--           -- setting is still read, but only the feature can change it.
--       key = function(guid, data) ... end,                -- optional
--           -- what tells two cards of this kind about the same person
--           -- apart: the same (kind, guid, key) already in line or
--           -- showing is not queued twice. Without it, `data` itself
--           -- where it is a string or a number, else one card of the kind
--           -- per person in line.
--       more = function(count) ... end,                    -- optional
--           -- the last card of a flood of this kind, in `text`'s shape,
--           -- for `count` cards that found the line full ("and 3 more",
--           -- through L["and %d more|and %d more##plural"]). Each kind
--           -- floods on its own card, after the reunions' "and N more":
--           -- never counted with the reunions, so never in their words.
--           -- Without it, the kind's cards are never folded into a count:
--           -- they join the line past its cap, each to show in turn (a
--           -- card said once ever must not be lost to a crowd).
--   })
--
-- Registering a kind again replaces it (ns.Registry). The card's look is
-- the reunion card's: a click opens their page or a stranger's glimpse
-- (ns.UI.ShowJournal), a right-click puts it away, and it never takes the
-- pad (UI/Windows/Reunion/Pad.lua).

local kinds = ns.Registry.New({
    what = "Toast.RegisterKind(kind, { snapshot = fn, text = fn })",
    key = "kind",
    check = function(_, spec)
        if type(spec.snapshot) ~= "function" or type(spec.text) ~= "function" then
            return false, "Toast.RegisterKind: snapshot and text must be functions"
        end
        for _, field in ipairs({ "due", "key", "more" }) do
            if spec[field] ~= nil and type(spec[field]) ~= "function" then
                return false, "Toast.RegisterKind: " .. field .. " must be a function"
            end
        end
        if spec.setting ~= nil and type(spec.setting) ~= "string" then
            return false, "Toast.RegisterKind: setting must be a settings key"
        end
        if spec.label ~= nil and type(spec.label) ~= "string" then
            return false, "Toast.RegisterKind: label must be a string"
        end
        return true
    end,
})
Toast.kinds, Toast.kindOrder = kinds.specs, kinds.list

function Toast.RegisterKind(kind, spec)
    kinds:Add(kind, spec)
    if spec.setting then ns.RegisterSettingDefault(spec.setting, true) end
end

-- The kinds that bring a switch for the Toasts page: a `setting` and a
-- `label`, in the order they registered.
function Toast.Switches()
    local out = {}
    for _, spec in ipairs(kinds.list) do
        if spec.setting and spec.label then out[#out + 1] = spec end
    end
    return out
end

local function KeyOf(spec, guid, data)
    if spec.key then return spec.key(guid, data) end
    local t = type(data)
    if t == "string" or t == "number" then return data end
    return true
end

-- A kind's card, fired by SD_TOAST: due by its own rule, in line once, and
-- then the same way as a reunion's.
local function Raise(kind, guid, data)
    local spec = kinds:Get(kind)
    guid = ns.SafeGUID(guid)
    if not spec or not guid then return end
    if not ns.Setting("showToasts") then return end
    if spec.setting and not ns.Setting(spec.setting) then return end

    local key = KeyOf(spec, guid, data)
    local function Twin(snap)
        return snap and snap.kind == kind and snap.guid == guid and snap.key == key
    end
    local queue = Toast.queue
    if Twin(Toast.showing) then return end
    for i = 1, #queue do
        if Twin(queue[i]) then return end
    end

    local now = ns.Now()
    if spec.due and not spec.due(guid, data, now) then return end
    local snap = spec.snapshot(guid, data, now)
    if not snap then return end
    snap.kind, snap.guid, snap.key = kind, guid, key

    if #queue >= MAX_QUEUE and spec.more then
        Toast.moreKinds[kind] = (Toast.moreKinds[kind] or 0) + 1
    else
        queue[#queue + 1] = snap
    end
    Pump()
end

ns.On("SD_TOAST", function(_, kind, guid, data)
    Raise(kind, guid, data)
end)

-- For the smoke test.
function ns.UI.ReunionShowing()
    return Toast.showing
end
