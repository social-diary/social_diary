-- The person's page's words (the person-page proposal, variant A, as the
-- copy has them: .claude/ui-proposal/person-page-copy.md): what the taped
-- strips at the top of their list say in place of the old summary
-- paragraph (first met, how often and how long, their level then and now),
-- their tooltips, and the tooltips of the marks on their plate
-- (UI/Journal/PersonPlate.lua). The strips' headings are book prose cut to
-- a heading (the hand, no full stop); their subtitles and every tooltip
-- are ledger lines (figures, no full stop on a label, one on a click hint).
--
-- Times on the marks are Your Diary's ("Today at 21:43", Text.When) and
-- passed no level: on Your Diary "at level 12" is the user's, and on their
-- page it would read as theirs. No mark names a zone (the user's decision,
-- 20 Oct), but for where they were last seen (the summary's sentence lives
-- on only there) and a dungeon's name (it says what the door is).

local addonName, ns = ...

local Format = ns.UI.Format
local L, Fmt = ns.L, ns.Fmt
local G = ns.Locale.grammar

-- The first letter up, as a line starts (a locale's own, umlauts too).
local function Capital(text)
    return G.Capital(text)
end

local PersonText = {}
ns.UI.PersonText = PersonText

-- At most this many gates of five are drawn beside "Met 37 times": the
-- number carries the rest (round 1: no row of seven gates, no ellipsis).
-- Below GATES * 5 the strokes are the count exactly.
PersonText.GATES = 2

-- What the note slip says before there is a note: today's line, kept, as
-- Edit is still there to click.
PersonText.NO_NOTE = L["No note yet. Click Edit to write one."]

-- Your Diary's words (UI/Journey/Text/), loaded before this file is ever
-- asked, looked up when called.
local function JText() return ns.UI.JourneyText end

-- A day for a heading: "today", "yesterday" (the same day test as
-- Format.DayLabel's, lowercase in a heading), else "11 October", with the
-- year once it is not this one's; `short`, the month cut to three letters
-- ("11 Oct 2025"), the fitter's fallback where the long form will not fit.
local function Day(t, now, short)
    local label = Format.DayLabel(t, now)
    if label == L["Today"] then return L["today"] end
    if label == L["Yesterday"] then return L["yesterday"] end
    if not short then return Format.DayMonth(t, now) end
    return Format.ShortDate(t, date("%Y", t) ~= date("%Y", now))
end
PersonText.Day = Day

-- The first strip: its heading, the same in short where that differs (or
-- nil), and its subtitle (or nil, and the strip is one line). Never met
-- (added from Recently nearby, or only whispered), it says when they were
-- added, and under that the day they were last seen, or nothing if never:
-- a strip saying "First met" with no meeting would be wrong.
function PersonText.FirstMet(s, now)
    now = now or ns.Now()
    local met = (s.timesMet or 0) > 0
    local seen = s.record and s.record.seen
    local sub
    if met then
        sub = s.levelThen and Fmt(L["at level %d"], s.levelThen) or nil
    elseif seen then
        sub = Fmt(L["last seen %s"], Day(seen.time, now, true))
    end
    local t = met and s.firstMet or s.entry.addedAt
    if not t then return met and L["First met"] or L["Added to the diary"], nil, sub end
    local lead = met and L["First met %s"] or L["Added %s"]
    local long, short = Fmt(lead, Day(t, now)), Fmt(lead, Day(t, now, true))
    if short == long then short = nil end
    return long, short, sub
end

-- The tally strip: its heading ("Met once", "Met twice", "Met 5 times",
-- Format.Times), how many strokes its gates draw (the count, at most
-- GATES gates), and its subtitle: the time together, "under a minute
-- together", or nil where there was none (a trade kept before they were in
-- the diary; there is no honest word for it). Nil for no meeting: there is
-- no tally to keep.
function PersonText.Tally(s)
    local n = s.timesMet or 0
    if n <= 0 then return nil end
    local seconds = s.seconds or 0
    local together
    if seconds >= 60 then
        together = Fmt(L["%s together##duration"], Format.Duration(seconds))
    elseif seconds > 0 then
        together = L["under a minute together"]
    end
    return Capital(Fmt(L["Met %s"], Format.Times(n))), math.min(n, PersonText.GATES * 5), together
end

-- Where they were last seen, as one line of a tooltip: "Last seen today at
-- 21:43 in Goldshire, Elwynn Forest", "Not seen nearby yet" (the summary's
-- sentence, its full stop dropped). The page no longer says it anywhere
-- else when the X is off the plate.
function PersonText.Seen(s, now)
    local seen = s.record and s.record.seen
    return (Format.SeenText(seen, now):gsub("%.$", ""))
end

-- The tally's tooltip: the count, what counts as a meeting (a session,
-- opened by a group, a trade or a /say, and a trade outside one; never a
-- whisper), when they last met, and where they were last seen.
function PersonText.TallyTip(s, now)
    now = now or ns.Now()
    local heading = PersonText.Tally(s)
    if not heading then return nil end
    local lines = { L["Each time you grouped, traded or talked nearby"] }
    if s.lastMet then lines[#lines + 1] = Fmt(L["Last met %s"], Format.At(s.lastMet, now)) end
    lines[#lines + 1] = PersonText.Seen(s, now)
    return heading, lines
end

-- The first strip's tooltip, only where they never met (there is no tally
-- strip to carry it): where they were last seen.
function PersonText.FirstMetTip(s, now)
    if (s.timesMet or 0) > 0 then return nil end
    local heading = PersonText.FirstMet(s, now)
    return heading, { PersonText.Seen(s, now) }
end

-- Their level then and now, for the level tag: then, now; nil where it
-- did not change or either is unknown (the who line already prints their
-- level), or where they never met ("when you first met" would be untrue).
function PersonText.Level(s)
    local before, after = s.levelThen, s.levelNow
    if (s.timesMet or 0) <= 0 or not (before and after) or before == after then return nil end
    return before, after
end

-- The level tag's tooltip.
function PersonText.LevelTip(s)
    local before, after = PersonText.Level(s)
    if not before then return nil end
    return L["Their level"], { Fmt(L["%s when you first met"], before), Fmt(L["%s now"], after) }
end

-- The plate's tooltip, over the print outside a mark: one name for one
-- thing, the side tab's (UI/Journal/Profile.lua).
PersonText.PLATE = { L["Where you saw them"], { L["Click to open the map."] } }

--------------------------------------------------------------------------
-- The plate's marks
--------------------------------------------------------------------------

-- "Today at 21:43", "On 11 Oct at 17:30": no level.
local function When(t, now) return JText().When(t, nil, now) end
PersonText.When = When

-- The meeting's ring: "Where you first met", what the meeting was (the
-- meeting row's timeline words: "Grouped", "Traded: got 5x [Tough Jerky]")
-- and when; or, where it is the spot they were added at, "Added to the
-- diary" and when.
function PersonText.MetTip(words, t, now)
    local lines = {}
    if words and words ~= "" then lines[1] = words end
    lines[#lines + 1] = When(t, now)
    return L["Where you first met"], lines
end
function PersonText.AddedTip(t, now)
    return L["Added to the diary"], { When(t, now) }
end

-- Their first sighting, in hindsight.
function PersonText.FirstSeenTip(t, now)
    return L["First seen"], { When(t, now) }
end

-- Time together (a session's ring): "Together for 1 h 5 min", when.
function PersonText.TogetherTip(seconds, t, now)
    local title = (seconds or 0) >= 60 and Fmt(L["Together for %s"], Format.Duration(seconds)) or L["Together"]
    return title, { When(t, now) }
end

-- A word said within earshot: "They said", the words between the book's
-- curly quotes, when.
local SAID = { say = L["They said"], yell = L["They yelled"] }

-- A row on the plate (a trade, a /say, a fight, a feature's): its words.
-- A fight is WorldPvP's own sentence with "them" for the name and no
-- place ("You killed them", "They probably killed you"), the spell on a
-- line of its own; a trade the timeline's words as they are; anything
-- else its timeline words, the place left to the map.
function PersonText.RowTip(row, guid, now)
    local spec = ns.Rows.Get(row.type)
    local c = row.context or {}
    local lines = {}
    local title
    if spec.fight == "kill" then
        title = ns.UI.Format.You(row.me, c.by and L["{Your} group killed them"] or L["{You} killed them"])
    elseif spec.fight == "death" then
        title = ns.UI.Format.You(row.me, c.probable and L["They probably killed {you}"] or L["They killed {you}"])
        if c.spell then lines[1] = Fmt(L["With %s"], c.spell) end
    elseif SAID[row.type] then
        title = SAID[row.type]
        local said = row.excerpt and JText().Written(row.excerpt)
        if said and said ~= "" then lines[1] = Fmt(L["\226\128\156%s\226\128\157"], said) end
    elseif spec.text then
        -- The place is the map's to say: the kind's words without it.
        title = spec.text(row, guid, true)
    else
        title = row.type
    end
    lines[#lines + 1] = When(row.time, now)
    return title, lines
end

-- Your note: the note, who else it is about (only others besides them),
-- when.
function PersonText.NoteTip(note, guid, now)
    local Text = JText()
    local lines = { Text.Written(note.text) }
    local others = {}
    for about in pairs(note.about or {}) do
        if about ~= guid then others[#others + 1] = Text.Who(about) or L["someone"] end
    end
    table.sort(others)
    if #others > 0 then lines[#lines + 1] = Fmt(L["Also about %s"], Text.List(others)) end
    lines[#lines + 1] = When(note.time, now)
    return L["Your note"], lines
end

-- A dungeon's door: its name (it says what the door is, not where),
-- how long inside, when.
function PersonText.DoorTip(name, seconds, t, now)
    return name or L["An instance"], { Fmt(L["%s inside"], Format.Duration(seconds or 0)), When(t, now) }
end

-- Where they were last seen: when, and the place as every place is
-- written, "Subzone, Zone".
function PersonText.SeenTip(seen, now)
    local lines = { When(seen.time, now) }
    local place = seen.zone
    if place and seen.subZone and seen.subZone ~= seen.zone then place = Fmt(L["%1$s, %2$s"], seen.subZone, place) end
    if place then lines[#lines + 1] = place end
    return L["Last seen"], lines
end

-- Anything else on the timeline put on the plate (a rare killed, a while
-- seen around): its timeline words and when.
function PersonText.ItemTip(words, t, now)
    return words or L["Together"], { When(t, now) }
end

--------------------------------------------------------------------------
-- A stranger's glimpse (the stranger-glimpse proposal; the copywriter's
-- words, .claude/proposals/stranger-glimpse-copy.md, 5 Nov 2026)
--------------------------------------------------------------------------
--
-- Their page pencilled in (UI/Journal/Glimpse.lua), the strip that leads
-- to it, and the hindsight line's link. Book ledger throughout: figures,
-- days from Format, no full stops but on the seen line (a sentence, as the
-- profile's). Headings are written in sentence case here and set in
-- capitals by the page. Every string the page writes is in this one table,
-- so a word changes in one place:
--   notYet     the strip's tooltip, its second line (Nearby's "In your
--              diary", mirrored)
--   click      its third line, the click hint: names what the click opens
--              (and the witness card's line for a stranger)
--   first      note 1's heading
--   after      the ledger's heading
--   moments    note 2's heading where the hinge came within a minute
--   nextDay    ... on the next calendar day, 12 h or more after
--   dayBefore  ... the calendar day before (the hinge came first)
--   later, earlier, daysLater, daysEarlier   ... "{duration} later", "{n}
--              days later" and their mirrors, as templates (ns.Fmt; the
--              days ns.Plural)
--   levels     note 2's sub line, both levels known; `mine` only yours
--   stood      a hinge off the print where only you are placed (a group
--              join, a whisper: the diary keeps your position, never
--              theirs); where they were beside you (a trade, a /say) the
--              zone's phrase alone (ns.ZoneIn, "in Durotar")
--   joinLevels how the levels join a place on one line
--   more       the ledger's count past its lines (ns.Plural)
--   seenDays   the seen line's day count, Format.SeenText after it
--              (ns.Plural)
--   until      the foot strip's name; `words` under it; `add` its link
PersonText.GLIMPSE = {
    notYet = L["Not in your diary yet"],
    click = L["Click to see their page, pencilled in"],
    first = L["First seen"],
    after = L["After that"],
    moments = L["Moments later"],
    nextDay = L["The next day"],
    dayBefore = L["The day before"],
    later = L["%s later"], earlier = L["%s earlier"],
    daysLater = L["%d day later|%d days later##plural"], daysEarlier = L["%d day earlier|%d days earlier##plural"],
    levels = L["you at level %1$d, they at %2$d"], mine = L["at level %d"],
    stood = L["you were %s##zone"],
    joinLevels = L["%1$s  \194\183  %2$s"],
    more = L["and %d more|and %d more##plural"],
    seenDays = L["Seen on %1$d day since %2$s. %3$s|Seen on %1$d days since %2$s. %3$s##plural"],
    ["until"] = L["Pencilled in until %s"],
    words = L["Strangers are forgotten after %s. Once in your diary, all of this is kept for good."],
    add = L["Add %s to your diary"],
}
local GW = PersonText.GLIMPSE

-- A time with its first letter up: "Yesterday at 14:05", "On 3 Nov at
-- 14:05" (Format.At, as a line of its own starts).
local function AtCapital(t, now)
    return Capital(Format.At(t, now))
end

-- The tooltip of a stranger's name that opens their glimpse (a margin
-- strip, a "met" strip, the hindsight line): their full name, that they are
-- not in the diary, and the click hint in its grey. A list for
-- Style.Tooltip.
function PersonText.GlimpseTip(full)
    return { { full or "" }, { GW.notYet, 1, 1, 1 }, { GW.click, 0.6, 0.6, 0.6, true } }
end

-- Note 1, where they were first seen (`first`, ns.Glimpse.Of's): its
-- heading, its line (the place as every place is written, "Red Rocks,
-- Mulgore"; with no place, the time) and its sub line (the time; with no
-- place, your level, or nil).
function PersonText.GlimpseFirst(first, now)
    now = now or ns.Now()
    local zone = first.mapID and ns.MapName(first.mapID) or nil
    local place = zone
    if zone and first.subZone and first.subZone ~= zone then place = Fmt(L["%1$s, %2$s"], first.subZone, zone) end
    if place then return GW.first, place, Format.At(first.t, now) end
    return GW.first, AtCapital(first.t, now), first.level and Fmt(GW.mine, first.level) or nil
end

-- How long after the first sighting (at `from`) the hinge came (at `t`),
-- as note 2's heading: within a minute, under 12 hours by the clock, then
-- by calendar days; mirrored where the hinge came first. No first
-- sighting: the hinge's time is the heading's clock.
local function After(from, t, now)
    if not from then return AtCapital(t, now) end
    local d = t - from
    local gap = math.abs(d)
    if gap < 60 then return GW.moments end
    local days = math.floor((ns.DayStart(math.max(t, from)) - ns.DayStart(math.min(t, from))) / ns.DAY + 0.5)
    if gap < 12 * 60 * 60 or days == 0 then
        return Fmt(d > 0 and GW.later or GW.earlier, Format.Duration(gap))
    end
    if days == 1 then return d > 0 and GW.nextDay or GW.dayBefore end
    return ns.Plural(days, d > 0 and GW.daysLater or GW.daysEarlier)
end
PersonText.GlimpseAfter = After

-- Note 2, the hinge (`row`, the first that made them matter): its heading
-- (After), its line (the row's own timeline words, as they are) and its sub
-- lines. `onPrint`: its mark is on the print, so the leader says where and
-- the sub line is the levels; else the place, by whose it is ("in
-- Durotar" where they were beside you, "you were in Durotar" where only
-- you are placed). Returns heading, line, sub, and `long`, the place with
-- the levels joined on, for the page to take where it fits one line.
function PersonText.GlimpseHinge(row, first, onPrint, now, guid)
    now = now or ns.Now()
    local spec = ns.Rows.Get(row.type)
    local line = spec.text and spec.text(row, guid) or row.type
    local levels
    if row.myLevel and row.theirLevel then
        levels = Fmt(GW.levels, row.myLevel, row.theirLevel)
    elseif row.myLevel then
        levels = Fmt(GW.mine, row.myLevel)
    end
    local heading = After(first and first.t, row.time, now)
    if onPrint then return heading, line, levels, nil end
    local zone = ns.RowZone(row)
    if not zone then return heading, line, levels, nil end
    local phrase = ns.ZoneIn(row.mapID, zone)
    local place = spec.proximity and phrase or Fmt(GW.stood, phrase)
    return heading, line, place, levels and Fmt(GW.joinLevels, place, levels) or nil
end

-- A ledger line's day, short ("today", "yesterday", "3 Nov"), for its
-- 76 px column (Format.DayLabel is three times that); the page sets it in
-- capitals.
function PersonText.GlimpseDay(t, now)
    return Day(t, now or ns.Now(), true)
end

-- A ledger line's words: the row's own timeline words.
function PersonText.GlimpseRow(row, guid)
    local spec = ns.Rows.Get(row.type)
    return spec.text and spec.text(row, guid) or row.type
end

function PersonText.GlimpseMore(n)
    return ns.Plural(n, GW.more)
end

-- The seen line: Recently nearby's tooltip written on the page. The day
-- count only past one day; "Last seen ..." always; never sighted, Format's
-- own "Not seen nearby yet.".
function PersonText.GlimpseSeen(g, now)
    now = now or ns.Now()
    local seen = g.record and g.record.seen
    local text = Format.SeenText(seen, now)
    if seen and not text:find("%.$") then text = text .. "." end
    if g.seen and (g.seen.days or 0) > 1 and g.seen.since then
        text = ns.Plural(g.seen.days, GW.seenDays, g.seen.days, Format.DayMonth(g.seen.since, now), text)
    end
    return text
end

-- The foot strip: its name ("Pencilled in until 5 December", the year
-- only across New Year), the same short where that differs (or nil: "4 Jan
-- 2027"), its words with the buffer's days (`days`, "30 days"), and its
-- link with their short name.
function PersonText.GlimpseFoot(g, short, days, now)
    now = now or ns.Now()
    local t = g["until"] or now
    local long = Fmt(GW["until"], Format.DayMonth(t, now))
    local brief = Fmt(GW["until"], Day(t, now, true))
    return long, brief ~= long and brief or nil, Fmt(GW.words, days), Fmt(GW.add, short or g.name or "")
end
