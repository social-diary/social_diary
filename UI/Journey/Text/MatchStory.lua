-- A Warsong told by time, in Your Diary's words (ns.UI.JourneyText): the
-- v2 match page (UI/Journey/Match.lua draws Core/MatchStory.lua's story;
-- .claude/ui-proposal/battleground-page-v2.md, .claude/features/
-- battlegrounds.md).
--
-- Locked by Jan (10 Nov): "VICTORY" and "DEFEAT" in the corner stub, in
-- place of "FINAL"; "Won in x minutes" under the title; the zerg's name,
-- "The Zerg"; the phase names stay as named by the diary (the keys below).
-- Strangers stay strangers: a strip may name one, never as a friend. No
-- nemesis colour (that is the page's, not the words').
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local L, Fmt = ns.L, ns.Fmt

-- The words (/copywriter, 11 Nov). A strip is the ledger's register: the
-- hand says what happened ("Feivel killed you twice"), the print what the
-- tables said (times, seconds), the graphite what the diary worked out.
-- Counts in the hand and the foot are words ("Two against four", "you fell
-- five times"); the print keeps figures and clocks.

local Format = ns.UI.Format
local Capital, Glue = Text.Capital, Text.Glue

-- "one" ... "twenty", then the figure (UI/Journey/Text/Match.lua's words).
local SAID = { L["one"], L["two"], L["three"], L["four"], L["five"], L["six"], L["seven"], L["eight"], L["nine"],
    L["ten"], L["eleven"], L["twelve"], L["thirteen"], L["fourteen"], L["fifteen"], L["sixteen"], L["seventeen"],
    L["eighteen"], L["nineteen"], L["twenty"] }
local function Said(n)
    return SAID[n] or tostring(n)
end

-- "once", "twice", "three times". "twice" is a word, not a plural form: a
-- locale without one writes "".
local function Times(n)
    if n == 2 and L["twice"] ~= "" then return L["twice"] end
    return ns.Plural(n, L["once|%s times##plural"], Said(n))
end

-- "a third time": a nemesis's count, its ordinal taking "time" as its noun.
local NTH_TIME = { L["first##time"], L["second##time"], L["third##time"], L["fourth##time"],
    L["fifth##time"], L["sixth##time"], L["seventh##time"], L["eighth##time"], L["ninth##time"],
    L["tenth##time"], L["eleventh##time"], L["twelfth##time"], context = "time" }

-- The print's seconds: "26 s", "1 min 35 s", glued.
local function Secs(secs)
    secs = math.max(0, math.floor((secs or 0) + 0.5))
    if secs < 60 then return Glue(Fmt(L["%d s"], secs)) end
    return Glue(Fmt(L["%1$d min %2$d s"], math.floor(secs / 60), secs % 60))
end

-- "4:01": a second of the match, as the strips print it.
function Text.StoryClock(t)
    t = math.max(0, math.floor((t or 0) + 0.5))
    return ("%d:%02d"):format(math.floor(t / 60), t % 60)
end

-- The seconds of your deaths: "2:07, 7:10 and 11:20"; past four, "and 3 more".
local function Clocks(times)
    local clocks = {}
    for _, t in ipairs(times or {}) do clocks[#clocks + 1] = Text.StoryClock(t) end
    return Format.List(clocks, { max = 4, shown = 3 })
end

-- The corner stub's word: "VICTORY", "DEFEAT", or nil (no winner read).
-- (locked, Jan)
function Text.StoryResult(story)
    if story.won == true then return L["VICTORY"] end
    if story.won == false then return L["DEFEAT"] end
    return nil
end

-- Under the title: "Won in 7 minutes", "Lost in 24 minutes" (locked, Jan);
-- with no winner read, "Over in 12 minutes".
function Text.StorySub(story)
    local minutes = math.max(1, math.floor(story.T / 60 + 0.5))
    if story.won == true then return ns.Plural(minutes, L["Won in a minute|Won in %s minutes##plural"], minutes) end
    if story.won == false then return ns.Plural(minutes, L["Lost in a minute|Lost in %s minutes##plural"], minutes) end
    return ns.Plural(minutes, L["Over in a minute|Over in %s minutes##plural"], minutes)
end

-- The stub's link to the board view.
function Text.StorySeeBoard()
    return L["See the board"]
end

-- A phase's name, by Core/MatchStory.lua's key. Locked (Jan's mockup):
-- opening, lastflag, standoff, level, bothout, broken, theirs. Worded to
-- match them: clock (the stretch after the last capture, the time ran out
-- on it), nocap (one phase, no capture all match), ours (ended by our
-- capture, nothing rarer in it; the mirror of "They broke in").
local PHASES = {
    opening = L["The opening"],
    lastflag = L["The last flag"],
    clock = L["The clock ran out"],
    nocap = L["No flag came home"],
    standoff = L["The long stand-off"],
    level = L["Level again"],
    bothout = L["Both flags out"],
    broken = L["A carry broken"],
    ours = L["We broke in"],
    theirs = L["They broke in"],
}
function Text.StoryPhase(key)
    return PHASES[key]
end

-- Locked (Jan, 10 Nov).
function Text.StoryZerg()
    return L["The Zerg"]
end

-- The zerg's graphite: how many fell on each side (theirs only as far as
-- the meter saw, so no "none of theirs").
local function Fallen(ours, theirs)
    if ours > 0 and theirs > 0 then
        return ns.Plural(ours, L["%1$d of ours fell, %2$d of theirs|%1$d of ours fell, %2$d of theirs##plural"], ours, theirs)
    elseif theirs > 0 then
        return ns.Plural(theirs, L["%d of theirs fell, none of ours|%d of theirs fell, none of ours##plural"])
    elseif ours > 0 then
        return ns.Plural(ours, L["%d of ours fell|%d of ours fell##plural"])
    end
    return L["no one fell##zerg"]
end

-- A strip's words: { head = the hand, print = what the tables said, graphite
-- = what the diary worked out, sub = the diary's own memory of them (ink) }.
-- Any of them may be nil (sub is never set here yet). `story.Name(ref)`
-- names a reference. Names are first names, strangers as strangers.
function Text.StoryStrip(s, story)
    local name = type(s.name) == "string" and s.name:match("^(%S+)") or nil
    local k = s.kind
    local w = {}
    if k == "friend" then
        -- "Feivel killed you twice" / "2:52 and 4:01"
        w.head = Fmt(L["%1$s killed you %2$s"], name, Times(#(s.times or {})))
        w.print = Clocks(s.times)
    elseif k == "nemesis" then
        -- "Ilsabet, a third time" / "2:07, 7:10 and 11:20" / "and you never got them"
        w.head = Fmt(L["%1$s, a %2$s time"], name, Format.Nth(#(s.times or {}), NTH_TIME))
        w.print = Clocks(s.times)
        w.graphite = L["and you never got them"]
    elseif k == "zerg" then
        -- "Seven minutes, no flag out" / "9 fights" / "3 of ours fell, 5 of theirs"
        local minutes = math.max(1, math.floor(((s.to or 0) - (s.from or 0)) / 60 + 0.5))
        w.head = Capital(ns.Plural(minutes, L["%s minute, no flag out|%s minutes, no flag out##plural"], Said(minutes)))
        if (s.fights or 0) > 0 then w.print = Text.Counts(s.fights, L["%s fight|%s fights##plural"]) end
        w.graphite = Fallen(s.ours or 0, s.theirs or 0)
    elseif k == "acquaintance" then
        -- "Koko, beside you"
        w.head = Fmt(L["%1$s, beside you"], name)
    elseif k == "evening" then
        -- "Hesk, again" / "your third match against them tonight"
        w.head = Fmt(L["%1$s, again"], name)
        local nth = Format.Nth(s.count or 3, Format.NTH_MATCH)
        if s.side == "with" then
            w.print = Fmt(L["your %s match with them tonight"], nth)
        else
            w.print = Fmt(L["your %s match against them tonight"], nth)
        end
    elseif k == "duel" then
        -- "You against Aldous" / "25 s" / "you won"
        w.head = name and Fmt(L["You against %1$s"], name) or L["You against one of theirs"]
        w.print = Secs(s.secs)
        if s.won == true then w.graphite = L["you won##duel"] elseif s.won == false then w.graphite = L["you fell##duel"] end
    elseif k == "revenge" then
        -- "Halvard killed Feivel" / "You killed Feivel" / "who had killed you twice"
        if s.by == true then
            w.head = Fmt(L["You killed %1$s"], name)
        else
            local by = type(s.by) == "string" and s.by:match("^(%S+)") or nil
            w.head = by and Fmt(L["%1$s killed %2$s"], by, name) or Fmt(L["One of ours killed %1$s"], name)
        end
        w.graphite = Fmt(L["who had killed you %s"], Times(s.times or 1))
    elseif k == "person" then
        -- "Brannoc, with you" / "Brannoc, against you"
        w.head = s.side == "against" and Fmt(L["%1$s, against you"], name) or Fmt(L["%1$s, with you"], name)
    elseif k == "carry" then
        -- "You carried their flag" / "You carried their flag home" / "26 s"
        w.head = s.home and L["You carried their flag home"] or L["You carried their flag"]
        w.print = Secs(s.secs)
    elseif k == "return" then
        -- "You killed Hesk and brought our flag back" / "5:34"
        w.head = (s.killed and name) and Fmt(L["You killed %1$s and brought our flag back"], name)
            or L["You brought our flag back"]
        w.print = Text.StoryClock(s.t)
    elseif k == "outnumbered" then
        -- "Two against four" / "17 s"
        w.head = Capital(Fmt(L["%1$s against %2$s##outnumbered"], Said(s.us or 0), Said(s.them or 0)))
        w.print = Secs(s.secs)
    elseif k == "escort" then
        -- "You ran with Brannoc" / "35 s" / "the flag came home"
        w.head = name and Fmt(L["You ran with %1$s"], name) or L["You ran with our flag carrier"]
        w.print = Secs(s.secs)
        if s.home then w.graphite = L["the flag came home"] end
    elseif k == "together" then
        -- "You and Koko fell" / "five seconds apart"
        w.head = name and Fmt(L["You and %1$s fell"], name) or L["You and one of ours fell"]
        local apart = math.floor((s.apart or 0) + 0.5)
        if apart < 1 then
            w.print = L["in the same second"]
        else
            w.print = ns.Plural(apart, L["%s second apart|%s seconds apart##plural"], Said(apart))
        end
    end
    return w
end

-- Your line at the foot (the cross and the tally are drawn): "you fell
-- five times, three of them to Ilsabet", "you fell twice, both times to
-- Feivel", "you fell three times, every time to Ilsabet", "you fell
-- once", "you never fell".
function Text.StoryFoot(story)
    local n = #(story.mine or {})
    if n == 0 then return L["you never fell"] end
    local by, top, most = {}, nil, 0
    for _, d in ipairs(story.mine) do
        if d.killer then
            by[d.killer] = (by[d.killer] or 0) + 1
            if by[d.killer] > most then top, most = d.killer, by[d.killer] end
        end
    end
    if top and most >= 2 then
        local who = top:match("^(%S+)")
        if most == n and n == 2 then return Fmt(L["you fell twice, both times to %s"], who) end
        if most == n then return Fmt(L["you fell %1$s, every time to %2$s"], Times(n), who) end
        return ns.Plural(most, L["you fell %1$s, %2$s of them to %3$s|you fell %1$s, %2$s of them to %3$s##plural"],
            Times(n), Said(most), who)
    end
    return Fmt(L["you fell %s"], Times(n))
end
