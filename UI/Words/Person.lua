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

local PersonText = {}
ns.UI.PersonText = PersonText

-- At most this many gates of five are drawn beside "Met 37 times": the
-- number carries the rest (round 1: no row of seven gates, no ellipsis).
-- Below GATES * 5 the strokes are the count exactly.
PersonText.GATES = 2

-- What the note slip says before there is a note: today's line, kept, as
-- Edit is still there to click.
PersonText.NO_NOTE = "No note yet. Click Edit to write one."

-- Your Diary's words (UI/Journey/Text/), loaded before this file is ever
-- asked, looked up when called.
local function JText() return ns.UI.JourneyText end

-- A day for a heading: "today", "yesterday" (the same day test as
-- Format.DayLabel's, lowercase in a heading), else "11 October", with the
-- year once it is not this one's; `short`, the month cut to three letters
-- ("11 Oct 2025"), the fitter's fallback where the long form will not fit.
local function Day(t, now, short)
    local label = Format.DayLabel(t, now)
    if label == "Today" or label == "Yesterday" then return label:lower() end
    if not short then return Format.DayMonth(t, now) end
    local text = tonumber(date("%d", t)) .. date(" %b", t)
    if date("%Y", t) ~= date("%Y", now) then text = text .. date(" %Y", t) end
    return text
end
PersonText.Day = Day

-- The first strip: its heading, the same in short where that differs (or
-- nil), and its subtitle (or nil, and the strip is one line). Never met
-- (added from Recently nearby, or only whispered), it says when they were
-- added: a strip saying "First met" with no meeting would be wrong.
function PersonText.FirstMet(s, now)
    now = now or ns.Now()
    local met = (s.timesMet or 0) > 0
    local t = met and s.firstMet or s.entry.addedAt
    if not t then return met and "First met" or "Added to the diary", nil, met and nil or "not met yet" end
    local lead = met and "First met " or "Added "
    local long, short = lead .. Day(t, now), lead .. Day(t, now, true)
    if short == long then short = nil end
    if not met then return long, short, "not met yet" end
    return long, short, s.levelThen and ("at level " .. s.levelThen) or nil
end

-- The tally strip: its heading ("Met once", "Met twice", "Met 5 times",
-- Format.Times), how many strokes its gates draw (the count, at most
-- GATES gates), and its subtitle: the time together, "under a minute
-- together", or nil where there was none (a trade kept before they were in
-- the diary; there is no honest word for it). Nil for no meeting: the
-- first strip already says "not met yet".
function PersonText.Tally(s)
    local n = s.timesMet or 0
    if n <= 0 then return nil end
    local seconds = s.seconds or 0
    local together
    if seconds >= 60 then
        together = Format.Duration(seconds) .. " together"
    elseif seconds > 0 then
        together = "under a minute together"
    end
    return "Met " .. Format.Times(n), math.min(n, PersonText.GATES * 5), together
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
    local lines = { "Each time you grouped, traded or talked nearby" }
    if s.lastMet then lines[#lines + 1] = "Last met " .. Format.At(s.lastMet, now) end
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
    return "Their level", { before .. " when you first met", after .. " now" }
end

-- The plate's tooltip, over the print outside a mark: one name for one
-- thing, the side tab's (UI/Journal/Profile.lua).
PersonText.PLATE = { "Where you saw them", { "Click to open the map." } }

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
    return "Where you first met", lines
end
function PersonText.AddedTip(t, now)
    return "Added to the diary", { When(t, now) }
end

-- Their first sighting, in hindsight.
function PersonText.FirstSeenTip(t, now)
    return "First seen", { When(t, now) }
end

-- Time together (a session's ring): "Together for 1 h 5 min", when.
function PersonText.TogetherTip(seconds, t, now)
    local title = (seconds or 0) >= 60 and ("Together for " .. Format.Duration(seconds)) or "Together"
    return title, { When(t, now) }
end

-- A word said within earshot: "They said", the words between the book's
-- curly quotes, when.
local SAID = { say = "They said", yell = "They yelled" }
local OPEN, CLOSE = "\226\128\156", "\226\128\157"

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
        title = ns.UI.Format.You(row.me, c.by and "{Your} group killed them" or "{You} killed them")
    elseif spec.fight == "death" then
        title = "They" .. ns.UI.Format.You(row.me, c.probable and " probably killed {you}" or " killed {you}")
        if c.spell then lines[1] = "With " .. c.spell end
    elseif SAID[row.type] then
        title = SAID[row.type]
        local said = row.excerpt and JText().Written(row.excerpt)
        if said and said ~= "" then lines[1] = OPEN .. said .. CLOSE end
    elseif spec.text then
        title = spec.text(row, guid)
        -- The place is the map's to say.
        if row.zone then title = title:gsub(" in " .. row.zone:gsub("%p", "%%%0") .. "$", "") end
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
        if about ~= guid then others[#others + 1] = Text.Who(about) or "someone" end
    end
    table.sort(others)
    if #others > 0 then lines[#lines + 1] = "Also about " .. Text.List(others) end
    lines[#lines + 1] = When(note.time, now)
    return "Your note", lines
end

-- A dungeon's door: its name (it says what the door is, not where),
-- how long inside, when.
function PersonText.DoorTip(name, seconds, t, now)
    return name or "An instance", { Format.Duration(seconds or 0) .. " inside", When(t, now) }
end

-- Where they were last seen: when, and the place as every place is
-- written, "Subzone, Zone".
function PersonText.SeenTip(seen, now)
    local lines = { When(seen.time, now) }
    local place = seen.zone
    if place and seen.subZone and seen.subZone ~= seen.zone then place = seen.subZone .. ", " .. place end
    if place then lines[#lines + 1] = place end
    return "Last seen", lines
end

-- Anything else on the timeline put on the plate (a rare killed, a while
-- seen around): its timeline words and when.
function PersonText.ItemTip(words, t, now)
    return words or "Together", { When(t, now) }
end
