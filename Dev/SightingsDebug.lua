-- Development tooling for sightings (M2): is the radar listening, what can
-- it see, why does a tooltip line show or not, and what seen around (SES-9)
-- holds, and the switch, the rollup and the counters' reset (out of
-- Core/Slash.lua before launch: the switch is Settings' Recording page). The
-- user's own sighting commands -- recent, of, city -- are in Core/Slash.lua.
--
-- Registered under /sd sightings, listed in its help only while debug is on.
-- Not part of a release: the TOC's Dev/ block goes.

local addonName, ns = ...

local MapName = ns.MapName
local ResolveArgument = ns.Slash.ResolveArgument

local function CVar(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    return get and ns.Plain(get(name)) or nil
end

local PAUSED = {
    login = "waiting for login",
    off = "switched off (|cffffd100/sd sightings on|r)",
    instance = "paused: in an instance (SIG-6)",
    city = "paused: in a city (SIG-5)",
}

local function SightingStatus()
    local Capture = ns.SightingCapture
    local state, detail, listening = Capture.State()

    if state == "active" then
        ns.Print("sightings |cff40c040active|r -- %d sources and a nameplate sweep every 30 s",
            Capture.SOURCE_COUNT)
    else
        local why = PAUSED[state] or state
        if state == "city" then
            why = why .. " -- " .. (type(detail) == "number" and (MapName(detail) or "map " .. detail)
                or tostring(detail))
        end
        ns.Print("sightings |cffc04040%s|r%s", why, listening and " |cffc04040(but still listening!)|r" or "")
    end

    local where = ns.Where()
    DEFAULT_CHAT_FRAME:AddMessage(("   here: %s, map %s%s"):format(
        tostring(where.zone), tostring(where.mapID),
        where.x and (" at %.1f, %.1f"):format(where.x * 100, where.y * 100) or ""))

    -- SIG-9: what the user's nameplates let the radar see.
    local friends, enemies, range = CVar("nameplateShowFriends"), CVar("nameplateShowEnemies"),
        CVar("nameplateMaxDistance")
    local function OnOff(value)
        if value == nil then return "?" end
        return value == "1" and "|cff40c040on|r" or "|cffc04040off|r"
    end
    DEFAULT_CHAT_FRAME:AddMessage(("   nameplates: friendly %s, enemy %s, range %s yd"):format(
        OnOff(friends), OnOff(enemies), tostring(range or "?")))
    if friends == "0" or enemies == "0" then
        DEFAULT_CHAT_FRAME:AddMessage("   |cff808080players without a nameplate are only seen when"
            .. " targeted, moused over or heard in /say, /yell or emotes|r")
    end

    local s = Capture.Stats()
    DEFAULT_CHAT_FRAME:AddMessage(("   since %s: %d events, %d queued, %d throttled, %d dropped;"
        .. " %d new row(s), %d updated, %d unreadable"):format(
        date("%H:%M", s.since), s.events, s.queued, s.throttled, s.dropped,
        s.new, s.updated, s.skipped))
    DEFAULT_CHAT_FRAME:AddMessage(("   frame cost: %.3f ms avg over %d busy frame(s), %.3f ms max; queue %d"):format(
        s.frames > 0 and s.ms / s.frames or 0, s.frames, s.maxMs, Capture.QueueLength()))

    local rows, characters = ns.Sightings.Count()
    DEFAULT_CHAT_FRAME:AddMessage(("   stored: %d row(s) across %d character(s), rolled up after %d days"):format(
        rows, characters, ns.BufferDays()))
end

-- What the radar sees right now. While paused it only looks.
local function SightingScan()
    local state = ns.SightingCapture.State()
    local dry = state ~= "active"
    local players, queued = ns.SightingCapture.Sweep(dry)

    for i = 1, math.min(#players, 15) do
        local unit = players[i].unit
        DEFAULT_CHAT_FRAME:AddMessage(("   %-10s %-22s lvl %s"):format(unit,
            ns.JoinName(ns.NameFromUnit(unit)) or players[i].guid,
            tostring(ns.Plain(UnitLevel(unit)) or "?")))
    end

    ns.Print("%d player nameplate%s in range; %s.", #players, #players == 1 and "" or "s",
        dry and "capture is paused, nothing queued"
            or ("%d queued, the rest were seen in the last minute"):format(queued))
end

-- REU-6, step by step: what the tooltip would add for your target (or
-- mouseover), and if nothing, why.
local function SightingTooltip()
    local unit
    for _, token in ipairs({ "target", "mouseover" }) do
        if UnitExists(token) and ns.SafeGUID(UnitGUID(token)) then unit = token break end
    end
    if not unit then
        ns.Print("target a player first.")
        return
    end

    local guid = ns.SafeGUID(UnitGUID(unit))
    local now = ns.Now()
    ns.Print("|cffffffff%s|r (%s)", ns.JoinName(ns.NameFromUnit(unit)) or guid, unit)

    local function Step(ok, text)
        DEFAULT_CHAT_FRAME:AddMessage(("   %s  %s"):format(
            ok and "|cff40c040yes|r" or "|cffc04040no |r", text))
    end

    Step(ns.db.settings.tooltipSeen, "setting on (Settings > Reunions)")
    Step(not ns.Diary.IsDiary(guid), "outside the diary (diary entries get the diary lines instead)")

    local rows = ns.Sightings.For(guid)
    local summary = ns.Sightings.Summary(guid)
    Step(summary ~= nil, ("sighted before: %d raw row(s)%s"):format(#rows,
        summary and (", %d in all, first %s"):format(summary.count, ns.UI.Format.At(summary.first, now)) or ""))

    local enc, live = ns.Sightings.EncounterState(guid, now)
    if enc then
        DEFAULT_CHAT_FRAME:AddMessage(("   encounter %s, last pulse %ds ago, seen before it: %s"):format(
            live and "under way" or "over", now - enc.last,
            enc.before == nil and "never" or enc.before == false and "unknown (reload)"
                or ns.UI.Format.At(enc.before, now)))
    end

    local line, why = ns.UI.SeenLine(guid, now)
    if line then
        ns.Print("tooltip line: |cff999999%s|r", line)
    else
        ns.Print("no tooltip line: %s.", why or "?")
    end
end

-- SES-9, for testing: every stretch on record, the glimpses that are not
-- shown included, and whether a together session is taking the pulses.
local function SightingAround(text)
    local guid = ResolveArgument(text, true)
    if not guid then
        if not text or text == "" then ns.Print("usage: |cffffd100/sd sightings around <name>|r, or target them.") end
        return
    end

    local name = ns.Characters.FullName(guid) or guid
    if not ns.Diary.IsDiary(guid) then
        ns.Print("|cffffffff%s|r is not in the diary; seen around is only kept for diary entries.", name)
        return
    end

    local now = ns.Now()
    local session = ns.Sessions.Current()
    local p = session and session.participants[guid]
    if p and not p.done then
        ns.Print("together session |cffffd100#%d|r is open with |cffffffff%s|r: sightings count"
            .. " towards it, not towards seen around. It ends %d min after you were last together.",
            session.id, name, math.floor(ns.Sessions.Gap() / 60))
    end

    local list = ns.Sessions.AroundAll(guid)
    for i = #list, math.max(1, #list - 9), -1 do
        local stretch = list[i]
        local shown = stretch.count >= ns.Sessions.AROUND_MIN
        DEFAULT_CHAT_FRAME:AddMessage(("   %s  %s-%s  %d sighting(s)  %s  %s"):format(
            date("%d %b", stretch.start), date("%H:%M", stretch.start), date("%H:%M", stretch.last),
            stretch.count, table.concat(stretch.zones, ", "),
            shown and "|cff40c040on the timeline|r"
                or ("|cff808080a glimpse, needs %d|r"):format(ns.Sessions.AROUND_MIN)))
    end

    local last = list[#list]
    if last and now - last.last <= ns.Sessions.Gap() then
        ns.Print("the newest stretch is still open: a sighting in the next %d min extends it.",
            math.ceil((ns.Sessions.Gap() - (now - last.last)) / 60))
    end
    ns.Print("%d stretch(es) for |cffffffff%s|r, %d on the timeline.", #list, name,
        #ns.Sessions.AroundFor(guid))
end

-- SIG-1's switch, answered with the status report.
local function SightingSwitch(_, name)
    ns.SightingCapture.SetEnabled(name == "on")
    SightingStatus()
end

local function SightingRollup(rest)
    local word, sure = (rest or ""):match("^(%S*)%s*(%S*)")
    local days = tonumber(word)
    -- Rolled rows do not come back: under a day is refused, and sooner than
    -- the retention setting has to be meant.
    if days and days < 1 then
        ns.Print("nothing rolled up: that would take even today's sightings. Use 1 day or more.")
        return
    end
    if days and days < ns.BufferDays() and sure ~= "confirm" then
        ns.Print("sightings stay in full for %d days. Rolling them up sooner cannot be undone. To go ahead: |cffffd100/sd sightings rollup %s confirm|r",
            ns.BufferDays(), word)
        return
    end
    local rolled, touched = ns.Sightings.Rollup(nil, days)
    ns.Print("rolled %d row(s) of %d character(s) into summaries.", rolled, touched)
end


local function Sub(name, fn, help, usage, alias)
    ns.Slash.Register(name, fn, help, { under = "sightings", dev = true, usage = usage, alias = alias })
end

Sub("status", SightingStatus, "status: listening or paused, nameplate settings, counters, frame cost",
    "", { "" })
Sub("scan", SightingScan, "the player nameplates around you right now")
Sub("around", SightingAround, "seen-around stretches for a diary entry, or your target (SES-9)",
    "around [name]")
Sub("tooltip", SightingTooltip, "why your target does or does not get the \"Seen N times\" line")
Sub("on", SightingSwitch, "switch passive detection", "on | off", { "off" })
Sub("rollup", SightingRollup, "roll sightings older than [days] into summaries now", "rollup [days] [confirm]")
Sub("reset", function()
    ns.SightingCapture.ResetStats()
    ns.Print("sighting counters reset.")
end, "reset the counters")
