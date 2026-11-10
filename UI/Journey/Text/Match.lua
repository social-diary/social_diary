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

local SAID = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
    "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty" }
local function Said(n)
    return SAID[n] or tostring(n)
end

local function Capital(s)
    return (s:gsub("^%l", string.upper))
end

-- "once", "twice", "three times".
local function Times(n)
    if n == 1 then return "once" end
    if n == 2 then return "twice" end
    return Said(n) .. " times"
end

-- "second", "third", ... for "your fourth match against them".
local ORDINAL = { "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
    "eleventh", "twelfth" }
local function Ordinal(n)
    return ORDINAL[n] or (n .. "th")
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
    warsong = { name = "Warsong Gulch", short = "Warsong" }, -- (locked short)
    arathi = { name = "Arathi Basin", short = "Arathi" }, -- (locked short)
    alterac = { name = "Alterac Valley", short = "Alterac" }, -- (locked short)
}
local function MapOf(match)
    local spec = ns.Matches.MAPS[match and match.map]
    return spec and MAPS[spec.key]
end
function Text.MatchMap(match)
    local m = MapOf(match)
    return m and m.name or (match and match.mapName) or "A battleground"
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
    if match.state == "left" then return ("Left before the end, %s"):format(time) end
    local won = ns.Matches.Won(match)
    if won == true then return ("Won, %s"):format(time) end
    if won == false then return ("Lost, after %s"):format(time) end
    return ("Neither side won, %s"):format(time)
end

-- A ticket's result in the hand: "Won", "Lost", "Left early", "No score".
function Text.TicketResult(match)
    if match.state == "left" then return "Left early" end
    local won = ns.Matches.Won(match)
    if match.state == "noboard" and won == nil then return "No score" end
    if won == true then return "Won" end
    if won == false then return "Lost" end
    return "No winner"
end

-- A ticket's time, as a figure: "22 min".
function Text.TicketTime(seconds)
    return ("%d min"):format(math.max(1, math.floor((seconds or 0) / 60 + 0.5)))  -- (Format.Duration's "min")
end

-- A ticket's top line: "I  Warsong".
function Text.TicketHead(i, match)
    return ("%s  %s"):format(Text.MatchNumeral(i), Text.MatchMapShort(match))
end

-- The tickets past the tenth: "and 3 more".
function Text.TicketsMore(n)
    return ("and %d more"):format(n)
end

-- A side's heading on the board, the faction in words: "HORDE, 10"; a
-- rolled-up board's without the count ("HORDE": its rows are not all kept).
function Text.MatchSide(faction, n)
    local name = faction == 0 and "HORDE" or faction == 1 and "ALLIANCE" or "THE OTHER SIDE"  -- (rubrics: capitals in the source)
    if not n then return name end
    return ("%s, %d"):format(name, n)
end

-- Turning the board or the roll over: "Turn the board over, 1 of 5".
function Text.MatchTurn(face, faces)
    return ("Turn the board over, %d of %d"):format(face, faces)
end
function Text.RollTurn(face, faces)
    return ("Turn the roll over, %d of %d"):format(face, faces)
end

-- The stand-out's strip: "Feivel killed you three times".
function Text.MatchKilled(name, n)
    return ("%s killed you %s"):format(name, Times(n))
end

-- A repeat's line on their strip: "your fourth match against them",
-- "your second match with them" (counting every saved match, Jan).
function Text.MatchMeeting(n, side)
    if side == "with" then return ("your %s match with them"):format(Ordinal(n)) end
    return ("your %s match against them"):format(Ordinal(n))
end

-- A rolled-up match's lost records: "and 34 more, rubbed out".
function Text.MatchLost(n)
    return ("and %d more, rubbed out"):format(n)
end
function Text.MatchLostTip(n)
    return ("%d names on this old board were rubbed out. The people in your diary stay on it."):format(n)
end

-- Your note at the foot of the match page: "you fell four times", "You
-- never fell."; then what you did: "Took their flag once, brought ours
-- back twice and dealt four killing blows."
function Text.MatchFell(n)
    if n == 0 then return "You never fell." end
    return ("you fell %s"):format(Times(n))
end
local function Deeds(caps, returns, kb)
    local parts = {}
    if caps and caps > 0 then parts[#parts + 1] = ("took their flag %s"):format(Times(caps)) end
    if returns and returns > 0 then parts[#parts + 1] = ("brought ours back %s"):format(Times(returns)) end
    if kb then parts[#parts + 1] = ("dealt %s killing blow%s"):format(Said(kb), kb == 1 and "" or "s") end
    if #parts == 0 then return nil end
    if #parts == 1 then return parts[1] end
    return table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts]
end
function Text.MatchDeeds(caps, returns, kb)
    local words = Deeds(caps, returns, kb)
    return words and (Capital(words) .. ".") or nil
end
Text.MATCH_REST = "The rest went unwritten."

-- The overview's subtitle: "Four matches, two won, 3 hours 12 minutes".
function Text.EveningSubtitle(n, won, seconds)
    return ("%s matches, %s won, %s"):format(Capital(Said(n)), won == 0 and "none" or Said(won), Long(seconds))
end

-- The overview's note: "You fell 14 times, took their flag twice and
-- brought ours back five times." / "You fell 14 times and dealt 31
-- killing blows."
function Text.EveningNote(deaths, caps, returns, kb)
    local fell = deaths == 0 and "You never fell" or ("You fell %s"):format(Times(deaths))
    if (caps or 0) > 0 or (returns or 0) > 0 then
        return fell .. ", " .. Deeds(caps, returns, nil) .. "."
    end
    return fell .. (" and dealt %s killing blow%s."):format(Said(kb or 0), kb == 1 and "" or "s")
end

-- The roll: the stand-out's words beside their name, "killed you in three
-- of them"; the print's heading, "and everyone else, 111 more".
function Text.RollKilled(n, of)
    if of == 1 or n == of then
        return n == 1 and "killed you" or ("killed you in all %s"):format(Said(n))
    end
    return ("killed you in %s of them"):format(Said(n))
end
function Text.RollEveryone(n)
    return ("and everyone else, %d more"):format(n)
end

-- The left page: "Battlegrounds, four matches"; "Warsong Gulch, won".
function Text.EveningLine(n)
    return ("Battlegrounds, %s matches"):format(Said(n))
end
function Text.MatchLine(match)
    local result = Text.TicketResult(match):lower()
    return ("%s, %s"):format(Text.MatchMap(match), result)
end

Text.MATCH = {
    title = "Battlegrounds", -- (locked, Jan)
    back = "Back to the battlegrounds", -- (sessions are not always evenings)
    final = "FINAL",
    kills = "Kills",
    deaths = "Deaths",
    to = "to",
    unwritten = "The score went unwritten. Who was there:",
    withYou = "With you",
    againstYou = "Against you",
    you = "You",
    fromDiary = "from your diary",
    open = "Click to open their page.",
    ticketOpen = "Click to open the match.",
}

-- A board row's tooltip: its whole row, damage and healing too (no rank):
-- { title, lines }.
function Text.MatchRowTip(p, match)
    local lines = {}
    local who = {}
    if p.race then who[#who + 1] = p.race end
    if p.class then who[#who + 1] = p.class:sub(1, 1) .. p.class:sub(2):lower() end
    if #who > 0 then lines[#lines + 1] = table.concat(who, " ") end
    local side = ns.Matches.Side(match, p)
    if side then lines[#lines + 1] = side == "with" and "With you" or "Against you" end
    if p.kb or p.deaths then
        -- (the honourable kills, said without the honour word: Jan)
        lines[#lines + 1] = ("%d killing blows, %d deaths, a hand in %d kills"):format(p.kb or 0, p.deaths or 0, p.hk or 0)
    end
    if p.damage or p.healing then
        lines[#lines + 1] = ("%s damage, %s healing"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(p.damage or 0)
            or tostring(p.damage or 0), BreakUpLargeNumbers and BreakUpLargeNumbers(p.healing or 0)
            or tostring(p.healing or 0))
    end
    return p.name or "?", lines
end

-- A ticket's tooltip lines: "Warsong Gulch, won, 22 minutes." and "You
-- dealt five killing blows and fell twice."
function Text.TicketTip(match, me, deaths)
    local line = ("%s, %s, %s."):format(Text.MatchMap(match), Text.TicketResult(match):lower(), Long(match.duration or 0))
    local you = ("You fell %s."):format(Times(deaths))
    if deaths == 0 then you = "You never fell." end
    if me and me.kb then you = ("You dealt %s killing blow%s and %s"):format(Said(me.kb), me.kb == 1 and "" or "s",
        deaths == 0 and "never fell." or ("fell %s."):format(Times(deaths))) end
    return line, you
end

-- A hand row's tooltip on the roll: which matches they were in, on which
-- side, how you know them: "With you in I and III", "Against you in all
-- four", "In your diary".
function Text.RollTip(with, against, of, diary)
    local function In(list)
        if #list == of and of > 1 then return ("in all %s"):format(Said(of)) end
        local n = {}
        for i, k in ipairs(list) do n[i] = Text.MatchNumeral(k) end
        if #n == 1 then return "in " .. n[1] end
        return "in " .. table.concat(n, ", ", 1, #n - 1) .. " and " .. n[#n]
    end
    local lines = {}
    if #with > 0 then lines[#lines + 1] = "With you " .. In(with) end
    if #against > 0 then lines[#lines + 1] = "Against you " .. In(against) end
    if diary then lines[#lines + 1] = "In your diary" end
    return lines
end

-- Your note's tooltip: each death's minute into the match, "Second, 12
-- min in, killed by Feivel Ashgrove" (a ledger's "min": no "1 minutes").
function Text.MatchDeathLine(k, minute, killer)
    if killer then return ("%s, %d min in, killed by %s"):format(Capital(Ordinal(k)), minute, killer) end
    return ("%s, %d min in"):format(Capital(Ordinal(k)), minute)
end

Text.MatchSaid, Text.MatchTimes, Text.MatchOrdinal = Said, Times, Ordinal
