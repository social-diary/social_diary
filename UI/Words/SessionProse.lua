-- A together session told in prose (experimental): the planner between a
-- person's timeline and the page writer (Core/Pages/Render.lua).
--
-- Reads one session episode (Core/Timeline.lua) into the facts the
-- `together` and `ding` angles take (UI/Words/Pages/WRITING.md, "The fact
-- contract") and has the page writer say them. Nothing is saved: every
-- choice is seeded by the session and the person, so a row reads the same
-- each time it is drawn, until the words themselves change.
--
-- Off until `/sd prose <voice>` (a dev command, for this session only); the
-- timeline's own headline (UI/Words/Timeline.lua's SessionHeadline) is used
-- whenever this is off or has nothing to say.

local addonName, ns = ...

local Pages = ns.Pages

local SessionProse = ns.UI.SessionProse or {}
ns.UI.SessionProse = SessionProse

-- nil (off), or the page writer's voice: plain, warm, wry, terse, mixed.
SessionProse.voice = nil

local VOICES = { plain = true, warm = true, wry = true, terse = true, mixed = true }

function SessionProse.On()
    return SessionProse.voice ~= nil
end

--------------------------------------------------------------------------
-- The plan
--------------------------------------------------------------------------

-- The page facts. No `seconds`: that is the whole play session's length,
-- which the diary doesn't keep, and the together session's own would make
-- every share of it "the whole afternoon" ({share:...}).
local function PageFacts(episode)
    local session = episode.session
    local start = session.startedAt
    local mine = session.myLevelStart and session.myLevelEnd
    return {
        part = Pages.Lang.PartOfDay(start),
        zones = episode.zones,
        zoneFirst = episode.zones[1],
        zoneLast = episode.zones[#episode.zones],
        levelStart = session.myLevelStart,
        levelEnd = session.myLevelEnd,
        levelsGained = mine and math.max(0, session.myLevelEnd - session.myLevelStart) or 0,
        levelCap = ns.Journey.MaxLevel(),
    }
end

-- What a row holds (the user's decision: three sentences), and of it: the
-- point, at most one more Notable beat, and at most one Texture beat. The
-- design has Texture ride inside a sentence as a stem or a tail; the
-- page writer joins pieces of one move only, so here it is a short
-- sentence of its own instead.
local BUDGET, MORE_NOTABLE, MORE_TEXTURE = 3, 1, 1
SessionProse.BUDGET = BUDGET

-- Beats that cut against a good point: told after it with "but".
local CONTRAST = { ["dungeon/trouble"] = true, ["together/deaths"] = true }
-- The frame: the time together and where. The design has it ride inside
-- the lead sentence as a stem; as a sentence of its own it is the last
-- support taken, and never "then" (it is no event in a sequence).
local FRAME = { ["together/time"] = true }

local function Kind(c) return c.angle .. "/" .. c.move end

-- The row's beats: { c, role, rel, short } in order, the point first; or
-- one short beat for a quiet row; or nil when there is nothing to say.
-- `skip` holds candidates already tried as the point.
function SessionProse.Choose(list, skip)
    local T, Better = SessionProse.TIERS, SessionProse.Better
    local open = {}
    for _, c in ipairs(list) do
        if not skip[c] then open[#open + 1] = c end
    end
    local point = SessionProse.Point(open)

    if not point then
        -- A quiet row: one sentence from the best Texture beat that may
        -- lead, never promoted to fill the room.
        local best
        for _, c in ipairs(open) do
            if not c.noLead and not c.coveredBy and c.tier >= T.TEXTURE and (not best or Better(c, best)) then
                best = c
            end
        end
        return best and { { c = best, role = "quiet", short = true } } or nil
    end

    local sorted = {}
    for _, c in ipairs(list) do
        if c ~= point and not c.coveredBy and c.tier >= T.TEXTURE then sorted[#sorted + 1] = c end
    end
    table.sort(sorted, Better)

    -- Support by its relation to the point, in this order of preference:
    -- a part of the point's own episode, something that cuts against it,
    -- the frame, then an unrelated Notable beat.
    local elaboration, contrast, frame, also
    for _, c in ipairs(sorted) do
        if FRAME[Kind(c)] then
            frame = frame or c
        elseif CONTRAST[Kind(c)] and not CONTRAST[Kind(point)] then
            contrast = contrast or c
        elseif c.episode == point.episode then
            elaboration = elaboration or c
        elseif c.tier >= T.NOTABLE and not c.noLead then
            also = also or c
        end
    end

    local beats = { { c = point, role = "point" } }
    local notable, texture = 0, 0
    local function Take(c, role, rel)
        if not c or #beats >= BUDGET then return end
        if c.tier >= T.NOTABLE then
            if notable >= MORE_NOTABLE then return end
            notable = notable + 1
        else
            if texture >= MORE_TEXTURE then return end
            texture = texture + 1
        end
        beats[#beats + 1] = { c = c, role = role, rel = rel, short = true }
    end
    -- "then" only for a real sequence in the point's own episode.
    Take(elaboration, "elaboration", elaboration and point.time and elaboration.time
        and elaboration.time > point.time and "then" or nil)
    Take(contrast, "contrast", "but")
    Take(frame, "frame", nil)
    Take(also, "also", "also")
    return beats
end

local function Beat(entry)
    local c = entry.c
    local beat = { angle = c.angle, moves = { c.move }, facts = c.facts, rel = entry.rel,
        short = entry.short, epithets = false }
    if entry.role == "point" then
        -- The lead says why it won, or it isn't the lead.
        if c.musts and c.musts[1] then beat.must = { c.musts[1] } end
        beat.required = { c.move }
    end
    return beat
end

-- The plan for one session on `guid`'s page, and the chosen beats, or nil.
local function Plan(episode, guid, skip)
    local list, h = SessionProse.Candidates(episode, guid)
    SessionProse.Weigh(list, h, SessionProse.LedgerBefore(episode, guid))
    local beats = SessionProse.Choose(list, skip or {})
    if not beats then return nil, nil, list end
    local paragraph = {}
    for i, entry in ipairs(beats) do paragraph[i] = Beat(entry) end
    return {
        key = "session/" .. tostring(episode.session.id) .. "/" .. tostring(guid),
        now = episode.session.startedAt,
        page = PageFacts(episode),
        paragraphs = { paragraph },
    }, beats, list
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- How many points to try before giving up on prose for a row.
local TRIES = 3

-- The session's prose and what it said, in the timeline's `said` keys
-- (rare, deaths, level, quest, dungeon, trade), for the details line to
-- leave out; nil when the writer had nothing to say. When the lead can't
-- say why it was chosen, the next candidate becomes the point.
function SessionProse.Write(episode, guid)
    if not SessionProse.On() or not episode.session then return nil end
    local skip = {}
    for _ = 1, TRIES do
        local plan, beats = Plan(episode, guid, skip)
        if not plan then return nil end
        local text, report = Pages.Render(plan, { voice = SessionProse.voice, epithets = false })

        local leadFailed = false
        for _, entry in ipairs(report.skipped) do
            if entry:match("^beat 1/1 ") then leadFailed = true end
        end
        if leadFailed then
            skip[beats[1].c] = true
        elseif text and text ~= "" then
            local said = {}
            for key in pairs(report.picks) do
                local bi = tonumber(key:match("^.-/1/(%d+)/"))
                local c = bi and beats[bi] and beats[bi].c
                if c and c.said then said[c.said] = true end
            end
            return text, said, beats
        else
            return nil
        end
    end
    return nil
end

-- The chosen beats, for the trace: "point  visit:77/run", "but  ...".
function SessionProse.Choice(episode, guid)
    local _, beats = Plan(episode, guid)
    return beats
end

-- For the tests: the plan alone.
SessionProse.Plan = Plan

--------------------------------------------------------------------------
-- /sd prose
--------------------------------------------------------------------------

local function Command(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)")
    if arg == "off" then
        SessionProse.voice = nil
    elseif VOICES[arg] then
        SessionProse.voice = arg
    else
        ns.Print("Session prose is " .. (SessionProse.voice or "off")
            .. ". /sd prose plain | warm | wry | terse | mixed | off")
        return
    end
    ns.Print("Session prose: " .. (SessionProse.voice or "off") .. ".")
    local J = ns.UI.Journal
    if J and J.RefreshProfile then J.RefreshProfile() end
end

ns.Slash.Register("prose", Command,
    "Together sessions in prose: |cffffd100plain|r, |cffffd100warm|r, |cffffd100wry|r, |cffffd100terse|r, |cffffd100mixed|r, |cffffd100off|r",
    { dev = true, usage = "prose [plain | warm | wry | terse | mixed | off]" })
