-- The sheet's labels and tooltips in Your Diary (ns.UI.JourneyText): a
-- meeting mark's, a stop's (its kind, its label, its tooltip), a pin's, a
-- dungeon's, a flight's, a first sighting's, a face's on the rubric and an
-- ink pool's. No key on the plates: these say what each mark means.
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Format = ns.UI.Format

local Text = ns.UI.JourneyText
local List = Format.List
-- Tooltips and single lines keep the plain formatter; what wraps (the
-- prose, captions, margin notes) holds its times together (Text.Duration,
-- UI/Journey/Text/Time.lua).
local Plain = Format.Duration
local MapName, Who, Written, When = Text.MapName, Text.Who, Text.Written, Text.When
local Times, PEOPLE = Text.Times, Text.PEOPLE
local L, Fmt = ns.L, ns.Fmt

--------------------------------------------------------------------------
-- The sheet's tooltips (JRN-14)
--------------------------------------------------------------------------
--
-- One account a mark (9 Nov 2026): where several things fall on one spot
-- and are drawn as one mark, its tooltip tells them all together, as a
-- fight's stain tells its stops (Text.Fought, the model): a title, four
-- lines at most, totals instead of repeats, one span of time and one of
-- levels at its foot, and no "and 4 more short stays" bookkeeping. A lone
-- record is an account of one and reads the same way, each fact once.
-- (9 Nov, in the client: a merged spot stacked each record's tooltip,
-- titles and "Today at 12:47 · Level 20" over and over.) The plate gathers
-- each account (UI/Journey/Plate.lua; a pool's is Ink.Account,
-- UI/Ink/Trail.lua) and hands these plain tables: nothing here knows how
-- the marks were merged.

-- "Levels 19 to 20", "Level 20", or nil; `lower` for after a comma,
-- "levels 19 to 20", "level 20".
local function Levels(from, to, lower)
    if from and to and from ~= to then
        return Fmt(lower and L["levels %1$d to %2$d"] or L["Levels %1$d to %2$d"], math.min(from, to), math.max(from, to))
    end
    local level = from or to
    return level and Fmt(lower and L["level %s"] or L["Level %d"], level) or nil
end

-- 0 when `t` falls on `now`'s calendar day, 1 on the day before, nil
-- otherwise (as Format.At counts them).
local function DayBack(t, now)
    local day = date("%Y-%m-%d", t)
    if day == date("%Y-%m-%d", now) then return 0 end
    if day == date("%Y-%m-%d", now - ns.DAY) then return 1 end
    return nil
end

-- A day and a time with no "on" before the date, for a span over days:
-- "yesterday at 21:40", "12 Sep at 18:02".
local function AtDay(t, now)
    local clock, back = Format.Clock(t), DayBack(t, now)
    if back == 0 then return Fmt(L["today at %s"], clock) end
    if back == 1 then return Fmt(L["yesterday at %s"], clock) end
    return Fmt(L["%1$s at %2$s##date"], Format.ShortDate(t, date("%Y", t) ~= date("%Y", now)), clock)
end

-- When a stretch was, from its first minute to its last: "Today from 12:47
-- to 13:20", "On 12 Sep from 18:02 to 18:40"; over midnight or days "From
-- yesterday at 21:40 to today at 12:00" (as the features' marks say it,
-- Features/Met/Text.lua's Foot); only the start ("Today at 12:47") within
-- a minute.
local function Span(from, to, now)
    now = now or ns.Now()
    if not to or to <= from or date("%Y-%m-%d %H:%M", to) == date("%Y-%m-%d %H:%M", from) then
        return When(from, nil, now)
    end
    if date("%Y-%m-%d", to) ~= date("%Y-%m-%d", from) then
        return Fmt(L["From %1$s to %2$s##days"], AtDay(from, now), AtDay(to, now))
    end
    local a, b, back = Format.Clock(from), Format.Clock(to), DayBack(from, now)
    if back == 0 then return Fmt(L["Today from %1$s to %2$s"], a, b) end
    if back == 1 then return Fmt(L["Yesterday from %1$s to %2$s"], a, b) end
    return Fmt(L["On %1$s from %2$s to %3$s"], Format.ShortDate(from, date("%Y", from) ~= date("%Y", now)), a, b)
end

-- When moments apart were (`ts`, times; Met's cards on one spot, the
-- campfire's sittings, the duels' series, the tames): each time, a day said
-- once for the times on it, "Today at 12:47", "Today at 12:47 and 15:10",
-- "Yesterday at 21:40 and today at 08:10"; past four, from the first to
-- the last as Span says a stretch, "Today from 12:47 to 19:02". Nil for
-- none.
local function Moments(ts, now)
    if not ts or #ts == 0 then return nil end
    local sorted = {}
    for i, t in ipairs(ts) do sorted[i] = t end
    table.sort(sorted)
    if #sorted > 4 then return Span(sorted[1], sorted[#sorted], now) end
    local parts, day, last = {}, nil, nil
    for _, t in ipairs(sorted) do
        local d, clock = date("%Y-%m-%d", t), Format.Clock(t)
        if d ~= day then
            parts[#parts + 1], day, last = Format.At(t, now), d, clock
        elseif clock ~= last then
            parts[#parts + 1], last = clock, clock
        end
    end
    return Text.Capital(List(parts))
end

-- A tooltip's foot: when, then the levels after a comma (never a middle
-- dot: the copywriter skill), "Today at 12:47, level 20", "Today from
-- 12:47 to 13:20, levels 19 to 20"; the levels alone keep their capital,
-- "Level 20". `a` an account's from, to, levelFrom, levelTo, or `times`
-- (a list of moments apart, Moments) in place of from and to; nil with
-- neither.
local function Foot(a, now)
    local span = a.times and Moments(a.times, now) or a.from and Span(a.from, a.to, now)
    if span and (a.levelFrom or a.levelTo) then
        return Fmt(L["%1$s, %2$s"], span, Levels(a.levelFrom, a.levelTo, true))
    end
    return span or Levels(a.levelFrom, a.levelTo)
end
-- For the features' marks, which tell their spots the same way.
Text.Span, Text.Levels, Text.Foot, Text.Moments = Span, Levels, Foot, Moments

-- How long, in all: "Fought here for 15 min", over several stops "Fought
-- here on and off, 42 min in all", under a minute "Fought here briefly".
-- `did` is what was done: "fought", "quested", "rested" or "stayed".
local HOW_LONG = {
    fought = { L["Fought here briefly"], L["Fought here on and off, %s in all"], L["Fought here for %s"] },
    quested = { L["Quested here briefly"], L["Quested here on and off, %s in all"], L["Quested here for %s"] },
    rested = { L["Rested here briefly"], L["Rested here on and off, %s in all"], L["Rested here for %s"] },
    stayed = { L["Stayed here briefly"], L["Stayed here on and off, %s in all"], L["Stayed here for %s"] },
}

local function HowLong(did, seconds, parts)
    local words = HOW_LONG[did]
    if (seconds or 0) < 60 then return words[1] end
    if (parts or 1) > 1 then return Fmt(words[2], Plain(seconds)) end
    return Fmt(words[3], Plain(seconds))
end

-- The quests of a stop or a pool, one line: "Took 2 quests, handed in 3",
-- "Handed in a quest"; nil for none.
local function Quests(took, gave)
    took, gave = took or 0, gave or 0
    if took > 0 and gave > 0 then
        return ns.Plural(took, L["Took a quest, handed in %2$d|Took %1$d quests, handed in %2$d##plural"], took, gave)
    end
    if took > 0 then return ns.Plural(took, L["Took a quest|Took %d quests##plural"]) end
    if gave > 0 then return ns.Plural(gave, L["Handed in a quest|Handed in %d quests##plural"]) end
    return nil
end

-- What kind of place a stop was, for the sheet's activity areas:
-- "fighting", "questing", "resting", or nil for a place you only stayed.
-- The recap's main activity, and a quest taken or handed in on a short
-- stop (a quest giver passed on the way) counts as questing too.
function Text.StopKind(seg)
    local main = ns.JourneyRecap.MainActivity(seg)
    if main then return main end
    local act = seg.act
    if act and (act.questsIn or 0) + (act.questsOut or 0) > 0 then return "questing" end
    return nil
end

local SHORT = { fighting = L["fighting"], questing = L["questing"], resting = L["resting"] }

-- How long a stop lasted, in words: a quest giver passed on the way is
-- "under a minute", not "0 min".
local function StopTime(seconds)
    return seconds >= 60 and Plain(seconds) or nil
end

-- A stop's label on the sheet: "Red Cloud Mesa, 6 min", or what was done
-- there where the place has no name ("fighting, 2 min"), the time left
-- off under a minute; nil with neither name nor deed.
function Text.StopLabel(seg, seconds)
    local kind = Text.StopKind(seg)
    local name = seg.subZone or (kind and SHORT[kind])
    if not name then return nil end
    local time = StopTime(seconds or seg.seconds or (seg.to - seg.from))
    return time and Fmt(L["%1$s, %2$s"], name, time) or name
end

-- A fight's tooltip on the plates: one account of a rust stain, all the
-- stops (and fought roads) it stands for together. `a` is Ink.Account's
-- (UI/Ink/Trail.lua): place, mapID, from, to, combat, deaths, questsIn,
-- questsOut, levelFrom, levelTo, parts. The place, how long you fought
-- (in all, "on and off", when it was several stops), deaths, quests, then
-- from when to when and at what level: four lines at most. (9 Nov, in the
-- client: the stain said "Fought here" twice, with a stay's time and the
-- fighting's, of its longest stop only, and "4 more short stays close by"
-- for the rest.) The span is what tells a short fight in a long stay.
function Text.Fought(a, now)
    local lines = { HowLong("fought", a.combat, a.parts) }
    local deaths = a.deaths or 0
    if deaths > 0 then lines[#lines + 1] = Times(deaths, L["Died here"], L["Died here %s"]) end
    lines[#lines + 1] = Quests(a.questsIn, a.questsOut)
    lines[#lines + 1] = Foot(a, now)
    return a.place or MapName(a.mapID) or L["A fight"], lines
end

-- A pool's tooltip that is not a fight's: what its ink means (no key on the
-- plates, Decision 7) and how long, in all, then any fighting and deaths,
-- the quests, and the foot. `a` is Ink.Account's, with its kind (the
-- pool's ink: "questing", "resting", "stayed") and seconds (its stops'
-- time). "Quested here on and off, 25 min in all", "Fought for 3 min and
-- died", "Handed in 2 quests", "Today from 18:40 to 19:05, level 13".
-- (9 Nov: it told its longest stop alone, then "And 4 more short stays
-- close by".)
local STAYED = { questing = "quested", resting = "rested" }

function Text.Stayed(a, now)
    local lines = { HowLong(STAYED[a.kind] or "stayed", a.seconds, a.parts) }
    local combat, deaths = a.combat or 0, a.deaths or 0
    if combat >= 60 then
        if deaths == 0 then
            lines[#lines + 1] = Fmt(L["Fought for %s"], Plain(combat))
        elseif deaths == 1 then
            lines[#lines + 1] = Fmt(L["Fought for %s and died"], Plain(combat))
        else
            lines[#lines + 1] = Fmt(L["Fought for %1$s and died %2$s"], Plain(combat), Format.Times(deaths))
        end
    elseif deaths > 0 then
        lines[#lines + 1] = Times(deaths, L["Died here"], L["Died here %s"])
    end
    lines[#lines + 1] = Quests(a.questsIn, a.questsOut)
    lines[#lines + 1] = Foot(a, now)
    return a.place or MapName(a.mapID) or L["A stop"], lines
end

-- A stop's tooltip, a stop alone: its account of one, told as a pool's.
function Text.Stop(seg, now)
    local act = seg.act or {}
    local a = { place = seg.subZone, mapID = seg.mapID, from = seg.from, to = seg.to, parts = 1,
        kind = Text.StopKind(seg) or "stayed", seconds = seg.seconds or ((seg.to or 0) - (seg.from or 0)),
        combat = act.combat, deaths = act.deaths, questsIn = act.questsIn, questsOut = act.questsOut,
        levelFrom = seg.levelFrom, levelTo = seg.levelTo }
    if a.kind == "fighting" then return Text.Fought(a, now) end
    return Text.Stayed(a, now)
end

function Text.Pin(pin, now)
    return Fmt(L["Level %d"], pin.level), { Fmt(L["Reached %s"], Format.At(pin.at, now)) }
end

-- A dungeon's door: one account of every visit through it (the plate
-- draws one door for the visits of one instance on one spot). `a`:
-- name, visits, seconds (inside, in all), from, to, levelFrom, levelTo;
-- a visit's seg (or a person's page's { name, seconds, from }) reads as
-- one. "Wailing Caverns", "Inside for 50 min" or "Went in twice, 1 h 27
-- min in all", the foot.
function Text.Dungeon(a, now)
    local visits, seconds = a.visits or 1, a.seconds or 0
    local line
    if visits > 1 then
        line = Fmt(L["Went in %1$s, %2$s in all"], Format.Times(visits), Plain(seconds))
    else
        line = seconds >= 60 and Fmt(L["Inside for %s"], Plain(seconds)) or L["Inside briefly"]
    end
    local to = a.to or (a.from and a.from + seconds)
    return a.name or L["An instance"],
        { line, Foot({ from = a.from, to = to, levelFrom = a.levelFrom, levelTo = a.levelTo }, now) }
end

-- The flights at one ring: one account. `a`: flights ({ out (true: flown
-- to `other`; false: in from it; nil: both ends on this map), other (a
-- mapID) }), from, to, levelFrom, levelTo. One way: "Flew to Orgrimmar
-- twice"; several: "Flew 3 times", a line each way ("To Orgrimmar
-- twice", "In from The Crossroads"), or past three, out and in counted.

-- Which way a flight went, to count the flights each way by.
local function WayKey(f)
    if f.out == nil then return "within" end
    local name = f.other and MapName(f.other)
    return (f.out and "to:" or "from:") .. (name or "")
end

-- A way in words, as the title ("Flew to Orgrimmar") or a line ("To
-- Orgrimmar"), with how often (`times`, Format.Times's) where it was more
-- than once ("Flew to Orgrimmar twice").
local function Way(f, title, times)
    local name = f.other and MapName(f.other)
    if f.out == nil then
        if title then return times and Fmt(L["Flew within the zone %s"], times) or L["Flew within the zone"] end
        return times and Fmt(L["Within the zone %s"], times) or L["Within the zone"]
    end
    if not name then
        if f.out then
            if title then return times and Fmt(L["Flew to another zone %s"], times) or L["Flew to another zone"] end
            return times and Fmt(L["To another zone %s"], times) or L["To another zone"]
        end
        if title then return times and Fmt(L["Flew in from another zone %s"], times) or L["Flew in from another zone"] end
        return times and Fmt(L["In from another zone %s"], times) or L["In from another zone"]
    end
    -- "Flew to Orgrimmar", "Flew in from Orgrimmar": the zone's phrase.
    local place = ns.ZoneIn(f.other, name, f.out and "to" or "from")
    if title then
        if f.out then return times and Fmt(L["Flew %1$s %2$s##zone"], place, times) or Fmt(L["Flew %s##zone"], place) end
        return times and Fmt(L["Flew in %1$s %2$s##zone"], place, times) or Fmt(L["Flew in %s##zone"], place)
    end
    if f.out then return Text.Capital(times and Fmt(L["%1$s %2$s##zone, how often"], place, times) or place) end
    return times and Fmt(L["In %1$s %2$s##zone"], place, times) or Fmt(L["In %s##zone"], place)
end

function Text.Flights(a, now)
    local ways, count, out, into = {}, {}, 0, 0
    for _, f in ipairs(a.flights or {}) do
        local key = WayKey(f)
        if not count[key] then
            ways[#ways + 1] = f
            count[key] = 0
        end
        count[key] = count[key] + 1
        if f.out then out = out + 1 elseif f.out == false then into = into + 1 end
    end
    local foot = Foot(a, now)
    if #ways == 0 then return L["A flight"], { foot } end
    local function Told(f, title)
        local n = count[WayKey(f)]
        return Way(f, title, n > 1 and Format.Times(n) or nil)
    end
    if #ways == 1 then return Told(ways[1], true), { foot } end
    local lines = {}
    if #ways <= 3 then
        for _, f in ipairs(ways) do lines[#lines + 1] = Told(f) end
    else
        if out > 0 then lines[#lines + 1] = Fmt(L["Flew out %s"], Format.Times(out)) end
        if into > 0 then lines[#lines + 1] = Fmt(L["Flew in %s##times"], Format.Times(into)) end
    end
    lines[#lines + 1] = foot
    return Fmt(L["Flew %s##times"], Format.Times(#(a.flights))), lines
end

-- One flight, alone: `seg` a flight, seen from `mapID`.
function Text.Flight(seg, mapID, now)
    local f = { other = seg.mapID1 == mapID and seg.mapID2 or seg.mapID1 }
    if seg.mapID1 ~= seg.mapID2 then f.out = seg.mapID1 == mapID end
    return Text.Flights({ flights = { f }, from = seg.from, levelFrom = seg.levelFrom, levelTo = seg.levelTo }, now)
end

-- The people's spot: one account of everyone and everything met on it
-- (the plate merges what lies within MARK.merge into one mark). `a`:
-- sessions ({ session, seconds (your time together, this entry's share) }),
-- fights (Journey's fight marks) and index (Journey.FightIndex), notes,
-- firsts (first sightings, { guid }), from, to, levelFrom, levelTo.
-- The title is the fight (its strokes are the mark drawn on top), else
-- who you were with, else your note, else the first sighting; each other
-- kind a line: "Beat Thex twice", "With Tester Testerson for 45 min" (or,
-- as the title, "With Tester Testerson", "Together twice, 1 h 5 min in
-- all"), your note's words, "First saw Numa", the foot. Four lines at most: where
-- there's more, "About ..." goes first, then your second note, then the
-- first sighting.
local function Fought(fights, index)
    -- The fights told alike (the same foe, the same end) are one: `said`
    -- its words (Text.Fight), `name` its foe where the buffer has one.
    local won, lost, told, by = 0, 0, {}, {}
    for _, mark in ipairs(fights) do
        local wonIt = mark.outcome == "won"
        if wonIt then won = won + 1 else lost = lost + 1 end
        local said = Text.Fight(mark, index)
        local one = by[said]
        if not one then
            local guid = ns.Journey.FightWho(mark, index)
            one = { said = said, won = wonIt, name = guid and Who(guid) or nil, n = 0 }
            told[#told + 1] = one
            by[said] = one
        end
        one.n = one.n + 1
    end
    if #told > 2 then
        -- Many foes: the score, not a roll of names.
        local score = {}
        if won > 0 then score[1] = ns.Plural(won, L["won a fight|won %d fights##plural"]) end
        if lost > 0 then
            score[#score + 1] = won > 0 and ns.Plural(lost, L["lost one|lost %d##plural"])
                or ns.Plural(lost, L["lost a fight|lost %d fights##plural"])
        end
        return Text.Capital(List(score))
    end
    local words = {}
    for k, one in ipairs(told) do
        local n = one.n
        if n == 1 then
            words[k] = one.said
        elseif not one.name then
            words[k] = one.won and ns.Plural(n, L["won a fight|won %d fights##plural"])
                or ns.Plural(n, L["lost a fight|lost %d fights##plural"])
        else
            words[k] = Fmt(one.won and L["beat %1$s %2$s"] or L["lost to %1$s %2$s"], one.name, Format.Times(n))
        end
    end
    return Text.Capital(List(words))
end

-- The people's names, sorted; `someone` the word for one the buffer has
-- let go.
local function Names(guids, someone)
    local names = {}
    for _, guid in ipairs(guids) do names[#names + 1] = Who(guid) or someone end
    table.sort(names)
    return names
end

function Text.Company(a, now)
    local sessions, fights, notes, firsts = a.sessions or {}, a.fights or {}, a.notes or {}, a.firsts or {}
    local with, seen, together = {}, {}, 0
    for _, s in ipairs(sessions) do
        for guid in pairs(s.session.participants or {}) do
            if not seen[guid] then
                seen[guid] = true
                with[#with + 1] = guid
            end
        end
        together = together + (s.seconds or 0)
    end
    -- Lines, each with when it goes where there is no room (higher first).
    local title, rows = nil, {}
    local function Row(text, drop) if text then rows[#rows + 1] = { text, drop } end end
    -- The fight first, as its crossed strokes are drawn on top
    -- (Plate.lua's PRIORITY), then who you were with.
    if #fights > 0 then title = Fought(fights, a.index) end
    if #with > 0 then
        local who = List(Names(with, L["someone##with"]), PEOPLE)
        local often, long = #sessions > 1 and Format.Times(#sessions), together >= 60 and Plain(together)
        if title then
            Row(often and Fmt(L["With %1$s %2$s, %3$s in all"], who, often, Plain(together))
                or long and Fmt(L["With %1$s for %2$s"], who, long) or Fmt(L["With %s briefly"], who), 0)
        else
            title = Fmt(L["With %s"], who)
            Row(often and Fmt(L["Together %1$s, %2$s in all"], often, Plain(together))
                or long and Fmt(L["Together for %s"], long) or L["Together briefly"], 0)
        end
    end
    local about = {}
    for k, note in ipairs(notes) do
        if not title then title = L["Your note"] end
        Row(Written(note.text), k > 1 and 2 or 0)
        for guid in pairs(note.about or {}) do
            if not seen[guid] then
                seen[guid] = true
                about[#about + 1] = guid
            end
        end
    end
    if #about > 0 then Row(Fmt(L["About %s"], List(Names(about, L["someone##whom"]), PEOPLE)), 3) end
    if #firsts > 0 then
        local guids = {}
        for _, f in ipairs(firsts) do guids[#guids + 1] = f.guid end
        local names = List(Names(guids, L["someone"]), PEOPLE)
        if title then Row(Fmt(L["First saw %s"], names), 1) else title = Fmt(L["First seen: %s"], names) end
    end
    local foot = Foot(a, now)
    while #rows + (foot and 1 or 0) > 4 do
        local worst = 1
        for k, row in ipairs(rows) do if row[2] >= rows[worst][2] then worst = k end end
        table.remove(rows, worst)
    end
    local lines = {}
    for _, row in ipairs(rows) do lines[#lines + 1] = row[1] end
    lines[#lines + 1] = foot
    return title or "", lines
end

-- A meeting mark's tooltip, a moment alone (Recap's or a sheet's: kind,
-- t, session, mark, note, level): its account of one.
function Text.Meeting(m, now, index)
    local a = { index = index, from = m.t, levelFrom = m.level, levelTo = m.level }
    if m.kind == "session" then
        local s = m.session
        local seconds = m.seconds or ns.Sessions.Duration(s)
        a.sessions, a.from, a.to = { { session = s, seconds = seconds } }, s.startedAt, s.startedAt + seconds
    elseif m.kind == "fight" then
        a.fights = { m.mark }
    elseif m.kind == "note" then
        a.notes = { m.note }
    else
        return "", {}
    end
    return Text.Company(a, now)
end

-- The hollow lozenge's tooltip, a first sighting alone: "First seen: Koko
-- Skybluff", "On 4 Oct at 18:30, level 1".
function Text.FirstSeen(f, now)
    return Text.Company({ firsts = { f }, from = f.t, levelFrom = f.level, levelTo = f.level }, now or ns.Now())
end

-- A face's tooltip on a level's rubric: the name as its title, then what
-- they were to you that level on a line of its own, "Koko Skybluff" over
-- "20 min together" (one fact per line, as every tooltip). The name alone
-- where there is nothing to say.
function Text.Face(face, e)
    local name = Who(face.guid) or L["someone"]
    local function Tip(fact) return ns.Style.TipList(name, { fact }) end
    for _, person in ipairs(e.people or {}) do
        if person.guid == face.guid and person.seconds >= 60 then
            return Tip(Fmt(L["%s together"], Plain(person.seconds)))
        end
    end
    for _, f in ipairs(e.hindsight or {}) do
        if f.guid == face.guid then return Tip(L["First seen"]) end
    end
    for _, mark in ipairs(e.fights or {}) do
        if mark.guid == face.guid then
            return Tip(mark.outcome == "lost" and L["Killed you"] or L["A fight, won"])
        end
    end
    return name
end
