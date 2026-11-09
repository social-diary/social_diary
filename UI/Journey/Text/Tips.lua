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

-- "Levels 19 to 20", "Level 20", or nil.
local function Levels(from, to)
    if from and to and from ~= to then return ("Levels %d to %d"):format(math.min(from, to), math.max(from, to)) end
    local level = from or to
    return level and ("Level " .. level) or nil
end

-- When a stretch was, from its first minute to its last: "Today from 12:47
-- to 13:20", "On 12 Sep from 18:02 to 18:40"; over midnight or days "From
-- yesterday at 21:40 to today at 12:00" (as the features' marks say it,
-- Features/Met/Text.lua's Foot); only the start ("Today at 12:47") within
-- a minute.
local function Span(from, to, now)
    local text = When(from, nil, now)
    if not to or to <= from or date("%Y-%m-%d %H:%M", to) == date("%Y-%m-%d %H:%M", from) then return text end
    if date("%Y-%m-%d", to) ~= date("%Y-%m-%d", from) then
        local function At(t) return (Format.At(t, now):gsub("^on ", "")) end
        return "From " .. At(from) .. " to " .. At(to)
    end
    return (text:gsub(" at (%d+:%d+)$", " from %1")) .. " to " .. date("%H:%M", to)
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
        local d, clock = Format.At(t, now):match("^(.-) at (%d+:%d+)$")
        if not d then
            parts[#parts + 1] = Format.At(t, now)
        elseif d ~= day then
            parts[#parts + 1], day, last = d .. " at " .. clock, d, clock
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
    local levels = Levels(a.levelFrom, a.levelTo)
    if span and levels then return span .. ", " .. levels:gsub("^L", "l") end
    return span or levels
end
-- For the features' marks, which tell their spots the same way.
Text.Span, Text.Levels, Text.Foot, Text.Moments = Span, Levels, Foot, Moments

-- How long, in all: "Fought here for 15 min", over several stops "Fought
-- here on and off, 42 min in all", under a minute "Fought here briefly".
local function HowLong(did, seconds, parts)
    if (seconds or 0) < 60 then return did .. " briefly" end
    if (parts or 1) > 1 then return did .. " on and off, " .. Plain(seconds) .. " in all" end
    return did .. " for " .. Plain(seconds)
end

-- The quests of a stop or a pool, one line: "Took 2 quests, handed in 3",
-- "Handed in a quest"; nil for none.
local function Quests(took, gave)
    took, gave = took or 0, gave or 0
    if took > 0 then
        local line = took == 1 and "Took a quest" or ("Took %d quests"):format(took)
        if gave > 0 then line = line .. ", handed in " .. gave end
        return line
    end
    if gave > 0 then return gave == 1 and "Handed in a quest" or ("Handed in %d quests"):format(gave) end
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

local SHORT = { fighting = "fighting", questing = "questing", resting = "resting" }

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
    return time and (name .. ", " .. time) or name
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
    local lines = { HowLong("Fought here", a.combat, a.parts) }
    local deaths = a.deaths or 0
    if deaths > 0 then lines[#lines + 1] = Times(deaths, "Died here", "Died here %s") end
    lines[#lines + 1] = Quests(a.questsIn, a.questsOut)
    lines[#lines + 1] = Foot(a, now)
    return a.place or MapName(a.mapID) or "A fight", lines
end

-- A pool's tooltip that is not a fight's: what its ink means (no key on the
-- plates, Decision 7) and how long, in all, then any fighting and deaths,
-- the quests, and the foot. `a` is Ink.Account's, with its kind (the
-- pool's ink: "questing", "resting", "stayed") and seconds (its stops'
-- time). "Quested here on and off, 25 min in all", "Fought for 3 min and
-- died", "Handed in 2 quests", "Today from 18:40 to 19:05, level 13".
-- (9 Nov: it told its longest stop alone, then "And 4 more short stays
-- close by".)
local STAYED = { questing = "Quested here", resting = "Rested here" }

function Text.Stayed(a, now)
    local lines = { HowLong(STAYED[a.kind] or "Stayed here", a.seconds, a.parts) }
    local combat, deaths = a.combat or 0, a.deaths or 0
    if combat >= 60 then
        lines[#lines + 1] = "Fought for " .. Plain(combat)
            .. (deaths > 0 and Times(deaths, " and died", " and died %s") or "")
    elseif deaths > 0 then
        lines[#lines + 1] = Times(deaths, "Died here", "Died here %s")
    end
    lines[#lines + 1] = Quests(a.questsIn, a.questsOut)
    lines[#lines + 1] = Foot(a, now)
    return a.place or MapName(a.mapID) or "A stop", lines
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
    return ("Level %d"):format(pin.level), { "Reached " .. Format.At(pin.at, now) }
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
        line = "Went in " .. Format.Times(visits) .. ", " .. Plain(seconds) .. " in all"
    else
        line = seconds >= 60 and ("Inside for " .. Plain(seconds)) or "Inside briefly"
    end
    local to = a.to or (a.from and a.from + seconds)
    return a.name or "An instance",
        { line, Foot({ from = a.from, to = to, levelFrom = a.levelFrom, levelTo = a.levelTo }, now) }
end

-- The flights at one ring: one account. `a`: flights ({ out (true: flown
-- to `other`; false: in from it; nil: both ends on this map), other (a
-- mapID) }), from, to, levelFrom, levelTo. One way: "Flew to Orgrimmar
-- twice"; several: "Flew 3 times", a line each way ("To Orgrimmar
-- twice", "In from The Crossroads"), or past three, out and in counted.
local function Way(f, title)
    local name = f.other and MapName(f.other)
    if f.out == nil then return title and "Flew within the zone" or "Within the zone" end
    if f.out then return (title and "Flew to " or "To ") .. (name or "another zone") end
    return (title and "Flew in from " or "In from ") .. (name or "another zone")
end

function Text.Flights(a, now)
    local ways, count, out, into = {}, {}, 0, 0
    for _, f in ipairs(a.flights or {}) do
        local key = Way(f)
        if not count[key] then
            ways[#ways + 1] = f
            count[key] = 0
        end
        count[key] = count[key] + 1
        if f.out then out = out + 1 elseif f.out == false then into = into + 1 end
    end
    local foot = Foot(a, now)
    if #ways == 0 then return "A flight", { foot } end
    local function Told(f, title)
        local n = count[Way(f)]
        return Way(f, title) .. (n > 1 and (" " .. Format.Times(n)) or "")
    end
    if #ways == 1 then return Told(ways[1], true), { foot } end
    local lines = {}
    if #ways <= 3 then
        for _, f in ipairs(ways) do lines[#lines + 1] = Told(f) end
    else
        if out > 0 then lines[#lines + 1] = "Flew out " .. Format.Times(out) end
        if into > 0 then lines[#lines + 1] = "Flew in " .. Format.Times(into) end
    end
    lines[#lines + 1] = foot
    return "Flew " .. Format.Times(#(a.flights)), lines
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
    local won, lost, words, count = 0, 0, {}, {}
    for _, mark in ipairs(fights) do
        if mark.outcome == "won" then won = won + 1 else lost = lost + 1 end
        local said = Text.Fight(mark, index)
        if not count[said] then
            words[#words + 1] = said
            count[said] = 0
        end
        count[said] = count[said] + 1
    end
    if #words > 2 then
        -- Many foes: the score, not a roll of names.
        local score = {}
        if won > 0 then score[1] = won == 1 and "won a fight" or ("won %d fights"):format(won) end
        if lost > 0 then
            score[#score + 1] = won > 0 and (lost == 1 and "lost one" or ("lost %d"):format(lost))
                or ("lost %d fights"):format(lost)
        end
        return Text.Capital(List(score))
    end
    for k, said in ipairs(words) do
        local n = count[said]
        if n > 1 then
            words[k] = said == "won a fight" and ("won %d fights"):format(n)
                or said == "lost a fight" and ("lost %d fights"):format(n) or (said .. " " .. Format.Times(n))
        end
    end
    return Text.Capital(List(words))
end

local function Names(guids)
    local names = {}
    for _, guid in ipairs(guids) do names[#names + 1] = Who(guid) or "someone" end
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
        local who = "With " .. List(Names(with), PEOPLE)
        local long = #sessions > 1 and (Format.Times(#sessions) .. ", " .. Plain(together) .. " in all")
            or together >= 60 and ("for " .. Plain(together)) or "briefly"
        if title then
            Row(who .. " " .. long, 0)
        else
            title = who
            Row("Together " .. long, 0)
        end
    end
    local about = {}
    for k, note in ipairs(notes) do
        if not title then title = "Your note" end
        Row(Written(note.text), k > 1 and 2 or 0)
        for guid in pairs(note.about or {}) do
            if not seen[guid] then
                seen[guid] = true
                about[#about + 1] = guid
            end
        end
    end
    if #about > 0 then Row("About " .. List(Names(about), PEOPLE), 3) end
    if #firsts > 0 then
        local guids = {}
        for _, f in ipairs(firsts) do guids[#guids + 1] = f.guid end
        local names = List(Names(guids), PEOPLE)
        if title then Row("First saw " .. names, 1) else title = "First seen: " .. names end
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
    local name = Who(face.guid) or "someone"
    local function Tip(fact) return ns.Style.TipList(name, { fact }) end
    for _, person in ipairs(e.people or {}) do
        if person.guid == face.guid and person.seconds >= 60 then
            return Tip(Plain(person.seconds) .. " together")
        end
    end
    for _, f in ipairs(e.hindsight or {}) do
        if f.guid == face.guid then return Tip("First seen") end
    end
    for _, mark in ipairs(e.fights or {}) do
        if mark.guid == face.guid then
            return Tip(mark.outcome == "lost" and "Killed you" or "A fight, won")
        end
    end
    return name
end

