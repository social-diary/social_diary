-- A battleground's pages in Your Diary's words (ns.UI.JourneyText): the
-- match page (C, the board clipped) and the evening's overview
-- ("Battlegrounds"), UI/Journey/Match.lua; their lines on the left page,
-- UI/Journey/Left.lua (.claude/ui-proposal/battleground-page.md, §8).
--
-- Locked by Jan (9 Nov): the overview's title "Battlegrounds" and the
-- short map names on the tickets. Never a PvP rank, a title or honour
-- (Jan). Strangers dropped by the roll-up are "rubbed out", the pencil's
-- word for forgetting.
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local L, Fmt = ns.L, ns.Fmt
local Capital, Upper = Text.Capital, Text.Upper

local SAID = { L["one"], L["two"], L["three"], L["four"], L["five"], L["six"], L["seven"], L["eight"], L["nine"],
    L["ten"], L["eleven"], L["twelve"], L["thirteen"], L["fourteen"], L["fifteen"], L["sixteen"], L["seventeen"],
    L["eighteen"], L["nineteen"], L["twenty"] }
local function Said(n)
    return SAID[n] or tostring(n)
end

-- "once", "twice", "three times" (the count in words, as Said says it).
-- "twice" is a word, not a plural form: a locale without one writes "".
local function Times(n)
    if n == 2 and L["twice"] ~= "" then return L["twice"] end
    return ns.Plural(n, L["once|%s times##plural"], Said(n))
end

-- "second", "third", ... for "your fourth match against them".
local ORDINAL = { L["first##match"], L["second##match"], L["third##match"], L["fourth##match"], L["fifth##match"],
    L["sixth##match"], L["seventh##match"], L["eighth##match"], L["ninth##match"], L["tenth##match"],
    L["eleventh##match"], L["twelfth##match"] }
local function Ordinal(n)
    return ORDINAL[n] or Fmt(L["%dth##match"], n)
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV",
    "XVI", "XVII", "XVIII", "XIX", "XX" }
-- A match's numeral in its session: "I", "IV".
function Text.MatchNumeral(i)
    return ROMAN[i] or tostring(i)
end

-- The maps' names: whole on a match page's title and the left page, short
-- on a ticket (Jan, 9 Nov: "Warsong", "Arathi", "Alterac").
local MAPS = {
    warsong = { name = L["Warsong Gulch"], short = L["Warsong"] }, -- (locked short)
    arathi = { name = L["Arathi Basin"], short = L["Arathi"] }, -- (locked short)
    alterac = { name = L["Alterac Valley"], short = L["Alterac"] }, -- (locked short)
}
local function MapOf(match)
    local spec = ns.Matches.MAPS[match and match.map]
    return spec and MAPS[spec.key]
end
function Text.MatchMap(match)
    local m = MapOf(match)
    return m and m.name or (match and match.mapName) or L["A battleground"]
end
function Text.MatchMapShort(match)
    local m = MapOf(match)
    return m and m.short or Text.MatchMap(match)
end

-- How long: "22 minutes", "2 hours 5 minutes" (the run's own words).
local function Long(seconds)
    return Text.RunDuration(seconds)
end

-- The match page's subtitle: "Won, 22 minutes", "Lost, after 2 hours 5
-- minutes", "Neither side won, 40 minutes", "Left before the end, 9
-- minutes" (the subject dropped, as the run's "Level 22, 35 minutes").
function Text.MatchSubtitle(match)
    local time = Long(match.duration or 0)
    if match.state == "left" then return Fmt(L["Left before the end, %s"], time) end
    local won = ns.Matches.Won(match)
    if won == true then return Fmt(L["Won, %s"], time) end
    if won == false then return Fmt(L["Lost, after %s"], time) end
    return Fmt(L["Neither side won, %s"], time)
end

-- A ticket's result in the hand: "Won", "Lost", "Left early", "No score".
-- `lower`: the same in a line's middle ("Warsong Gulch, won"), its own
-- words rather than :lower() on the capitalised ones.
function Text.TicketResult(match, lower)
    local won = ns.Matches.Won(match)
    if lower then
        if match.state == "left" then return L["left early##match"] end
        if match.state == "noboard" and won == nil then return L["no score##match"] end
        if won == true then return L["won##match"] end
        if won == false then return L["lost##match"] end
        return L["no winner##match"]
    end
    if match.state == "left" then return L["Left early##match"] end
    if match.state == "noboard" and won == nil then return L["No score##match"] end
    if won == true then return L["Won##match"] end
    if won == false then return L["Lost##match"] end
    return L["No winner##match"]
end

-- A ticket's time, as a figure: "22 min".
function Text.TicketTime(seconds)
    return Fmt(L["%d min"], math.max(1, math.floor((seconds or 0) / 60 + 0.5)))  -- (Format.Duration's "min")
end

-- A ticket's top line: "I  Warsong".
function Text.TicketHead(i, match)
    return Fmt(L["%1$s  %2$s##ticket"], Text.MatchNumeral(i), Text.MatchMapShort(match))
end

-- The tickets past the tenth: "and 3 more".
function Text.TicketsMore(n)
    return ns.Plural(n, L["and %d more|and %d more##plural"])
end

-- A side's heading on the board, the faction in words: "HORDE, 10"; a
-- rolled-up board's without the count ("HORDE": its rows are not all kept).
function Text.MatchSide(faction, n)
    local name = Upper(faction == 0 and L["Horde"] or faction == 1 and L["Alliance"] or L["The other side"])  -- (rubrics: capitals)
    if not n then return name end
    return Fmt(L["%1$s, %2$d##side"], name, n)
end

-- Turning the board or the roll over: "Turn the board over, 1 of 5".
function Text.MatchTurn(face, faces)
    return Fmt(L["Turn the board over, %1$d of %2$d"], face, faces)
end
function Text.RollTurn(face, faces)
    return Fmt(L["Turn the roll over, %1$d of %2$d"], face, faces)
end

-- The stand-out's strip: "Feivel killed you three times".
function Text.MatchKilled(name, n)
    return Fmt(L["%1$s killed you %2$s"], name, Times(n))
end

-- A repeat's line on their strip: "your fourth match against them",
-- "your second match with them" (counting every saved match, Jan).
function Text.MatchMeeting(n, side)
    if side == "with" then return Fmt(L["your %s match with them"], Ordinal(n)) end
    return Fmt(L["your %s match against them"], Ordinal(n))
end

-- A rolled-up match's lost records: "and 34 more, rubbed out".
function Text.MatchLost(n)
    return ns.Plural(n, L["and %d more, rubbed out|and %d more, rubbed out##plural"])
end
function Text.MatchLostTip(n)
    -- (English says "names" for one as well, as it always has)
    return ns.Plural(n, L["%d names on this old board were rubbed out. The people in your diary stay on it.|%d names on this old board were rubbed out. The people in your diary stay on it.##plural"])
end

-- Your note at the foot of the match page: "you fell four times", "You
-- never fell."; then what you did: "Took their flag once, brought ours
-- back twice and dealt four killing blows."
function Text.MatchFell(n)
    if n == 0 then return L["You never fell."] end
    return Fmt(L["you fell %s"], Times(n))
end
-- Each combination of the deeds its own sentence, so a language may order
-- them as it needs.
function Text.MatchDeeds(caps, returns, kb)
    local c = caps and caps > 0 and Times(caps)
    local r = returns and returns > 0 and Times(returns)
    if kb then
        local k = Said(kb)
        if c and r then
            return ns.Plural(kb, L["Took their flag %1$s, brought ours back %2$s and dealt %3$s killing blow.|Took their flag %1$s, brought ours back %2$s and dealt %3$s killing blows.##plural"], c, r, k)
        elseif c then
            return ns.Plural(kb, L["Took their flag %1$s and dealt %2$s killing blow.|Took their flag %1$s and dealt %2$s killing blows.##plural"], c, k)
        elseif r then
            return ns.Plural(kb, L["Brought ours back %1$s and dealt %2$s killing blow.|Brought ours back %1$s and dealt %2$s killing blows.##plural"], r, k)
        end
        return ns.Plural(kb, L["Dealt %s killing blow.|Dealt %s killing blows.##plural"], k)
    end
    if c and r then return Fmt(L["Took their flag %1$s and brought ours back %2$s."], c, r) end
    if c then return Fmt(L["Took their flag %s."], c) end
    if r then return Fmt(L["Brought ours back %s."], r) end
    return nil
end
Text.MATCH_REST = L["The rest went unwritten."]

-- The overview's subtitle: "Four matches, two won, 3 hours 12 minutes".
function Text.EveningSubtitle(n, won, seconds)
    return Capital(ns.Plural(n, L["%1$s match, %2$s won, %3$s|%1$s matches, %2$s won, %3$s##plural"], Said(n),
        won == 0 and L["none##won"] or Said(won), Long(seconds)))
end

-- The overview's note: "You fell 14 times, took their flag twice and
-- brought ours back five times." / "You fell 14 times and dealt 31
-- killing blows."
function Text.EveningNote(deaths, caps, returns, kb)
    local c = (caps or 0) > 0 and Times(caps)
    local r = (returns or 0) > 0 and Times(returns)
    if deaths == 0 then
        if c and r then return Fmt(L["You never fell, took their flag %1$s and brought ours back %2$s."], c, r) end
        if c then return Fmt(L["You never fell, took their flag %s."], c) end
        if r then return Fmt(L["You never fell, brought ours back %s."], r) end
        return ns.Plural(kb or 0, L["You never fell and dealt %s killing blow.|You never fell and dealt %s killing blows.##plural"],
            Said(kb or 0))
    end
    local fell = Times(deaths)
    if c and r then
        return Fmt(L["You fell %1$s, took their flag %2$s and brought ours back %3$s."], fell, c, r)
    end
    if c then return Fmt(L["You fell %1$s, took their flag %2$s."], fell, c) end
    if r then return Fmt(L["You fell %1$s, brought ours back %2$s."], fell, r) end
    return ns.Plural(kb or 0, L["You fell %1$s and dealt %2$s killing blow.|You fell %1$s and dealt %2$s killing blows.##plural"],
        fell, Said(kb or 0))
end

-- The roll: the stand-out's words beside their name, "killed you in three
-- of them"; the print's heading, "and everyone else, 111 more".
function Text.RollKilled(n, of)
    if of == 1 or n == of then
        return n == 1 and L["killed you"] or ns.Plural(n, L["killed you in all %s|killed you in all %s##plural"], Said(n))
    end
    return ns.Plural(n, L["killed you in %s of them|killed you in %s of them##plural"], Said(n))
end
function Text.RollEveryone(n)
    return ns.Plural(n, L["and everyone else, %d more|and everyone else, %d more##plural"])
end

-- The left page: "Battlegrounds, four matches"; "Warsong Gulch, won".
function Text.EveningLine(n)
    return ns.Plural(n, L["Battlegrounds, %s match|Battlegrounds, %s matches##plural"], Said(n))
end
function Text.MatchLine(match)
    return Fmt(L["%1$s, %2$s##match"], Text.MatchMap(match), Text.TicketResult(match, true))
end

Text.MATCH = {
    title = L["Battlegrounds"], -- (locked, Jan)
    back = L["Back to the battlegrounds"], -- (sessions are not always evenings)
    final = Upper(L["Final##score"]),
    kills = L["Kills"],
    deaths = L["Deaths"],
    to = L["to##score"],
    unwritten = L["The score went unwritten. Who was there:"],
    withYou = L["With you"],
    againstYou = L["Against you"],
    you = L["You"],
    fromDiary = L["from your diary"],
    open = L["Click to open their page."],
    ticketOpen = L["Click to open the match."],
}

-- A board row's tooltip: its whole row, damage and healing too (no rank):
-- { title, lines }.
function Text.MatchRowTip(p, match)
    local lines = {}
    -- (the class is the board's token, "WARRIOR": the client's name for it)
    local class = p.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.class]
        or (p.class:sub(1, 1) .. p.class:sub(2):lower()))
    if p.race and class then
        lines[#lines + 1] = Fmt(L["%1$s %2$s##race class"], p.race, class)
    elseif p.race or class then
        lines[#lines + 1] = p.race or class
    end
    local side = ns.Matches.Side(match, p)
    if side then lines[#lines + 1] = side == "with" and L["With you"] or L["Against you"] end
    if p.kb or p.deaths then
        -- (the honourable kills, said without the honour word: Jan)
        lines[#lines + 1] = Fmt(L["%1$d killing blows, %2$d deaths, a hand in %3$d kills"], p.kb or 0, p.deaths or 0, p.hk or 0)
    end
    if p.damage or p.healing then
        lines[#lines + 1] = Fmt(L["%1$s damage, %2$s healing"], BreakUpLargeNumbers and BreakUpLargeNumbers(p.damage or 0)
            or tostring(p.damage or 0), BreakUpLargeNumbers and BreakUpLargeNumbers(p.healing or 0)
            or tostring(p.healing or 0))
    end
    return p.name or "?", lines
end

-- A ticket's tooltip lines: "Warsong Gulch, won, 22 minutes." and "You
-- dealt five killing blows and fell twice."
function Text.TicketTip(match, me, deaths)
    local line = Fmt(L["%1$s, %2$s, %3$s.##match"], Text.MatchMap(match), Text.TicketResult(match, true),
        Long(match.duration or 0))
    local you
    if me and me.kb then
        if deaths == 0 then
            you = ns.Plural(me.kb, L["You dealt %s killing blow and never fell.|You dealt %s killing blows and never fell.##plural"],
                Said(me.kb))
        else
            you = ns.Plural(me.kb, L["You dealt %1$s killing blow and fell %2$s.|You dealt %1$s killing blows and fell %2$s.##plural"],
                Said(me.kb), Times(deaths))
        end
    elseif deaths == 0 then
        you = L["You never fell."]
    else
        you = Fmt(L["You fell %s."], Times(deaths))
    end
    return line, you
end

-- A hand row's tooltip on the roll: which matches they were in, on which
-- side, how you know them: "With you in I and III", "Against you in all
-- four", "In your diary".
function Text.RollTip(with, against, of, diary)
    -- `all` and `some` the side's two sentences: every match, or these.
    local function In(list, all, some)
        if #list == of and of > 1 then return ns.Plural(of, all, Said(of)) end
        local n = {}
        for i, k in ipairs(list) do n[i] = Text.MatchNumeral(k) end
        return Fmt(some, ns.UI.Format.List(n))
    end
    local lines = {}
    if #with > 0 then
        lines[#lines + 1] = In(with, L["With you in all %s|With you in all %s##plural"], L["With you in %s##matches"])
    end
    if #against > 0 then
        lines[#lines + 1] = In(against, L["Against you in all %s|Against you in all %s##plural"],
            L["Against you in %s##matches"])
    end
    if diary then lines[#lines + 1] = L["In your diary"] end
    return lines
end

-- Your note's tooltip: each death's minute into the match, "Second, 12
-- min in, killed by Feivel Ashgrove" (a ledger's "min": no "1 minutes").
function Text.MatchDeathLine(k, minute, killer)
    if killer then return Fmt(L["%1$s, %2$d min in, killed by %3$s"], Capital(Ordinal(k)), minute, killer) end
    return Fmt(L["%1$s, %2$d min in"], Capital(Ordinal(k)), minute)
end

Text.MatchSaid, Text.MatchTimes, Text.MatchOrdinal = Said, Times, Ordinal
