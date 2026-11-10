-- The text helpers, ns.UI.Format: durations, days, lists, counts, money,
-- and characters in words. Callers that write often keep the table (or the
-- functions they use) in a local, taken at load; Core loads before the UI,
-- so it reads ns.UI.Format when it writes. Its siblings: the chrome
-- (ns.UI.Chrome, UI/Kit/Chrome.lua), the virtual list (UI/Kit/List.lua).

local addonName, ns = ...

local Format = {}
ns.UI.Format = Format

local L, Fmt = ns.L, ns.Fmt
local G = ns.Locale.grammar

-- The calendar's names in the reader's language: the client's date() writes
-- English ones on every client, so they are looked up by number instead.
local MONTHS = { L["January"], L["February"], L["March"], L["April"], L["May"], L["June"], L["July"],
    L["August"], L["September"], L["October"], L["November"], L["December"] }
local MONTHS_SHORT = { L["Jan"], L["Feb"], L["Mar"], L["Apr"], L["May##short"], L["Jun"], L["Jul"],
    L["Aug"], L["Sep"], L["Oct"], L["Nov"], L["Dec"] }
local WEEKDAYS = { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"],
    L["Saturday"] }

-- `time`'s month ("October"), its short form ("Oct"), its weekday ("Monday").
function Format.Month(time) return MONTHS[tonumber(date("%m", time))] end
function Format.MonthShort(time) return MONTHS_SHORT[tonumber(date("%m", time))] end
function Format.Weekday(time) return WEEKDAYS[tonumber(date("%w", time)) + 1] end

-- A day of the month as a date writes it: "6" in English, and "25th" where
-- the English says it as an ordinal (`ordinal`: the sitting label, "Oct
-- 25th"). A locale's own is grammar.Day(n, ordinal): French "1er" for the
-- first and the figure after it, Spanish and Russian the figure always.
function Format.Day(n, ordinal)
    if G.Day then return G.Day(n, ordinal) end
    return ordinal and Format.Ordinal(n) or tostring(n)
end

-- A time of day, "21:43" (a locale's own, grammar.Clock(hour, minute):
-- French "21 h 43").
function Format.Clock(time)
    if G.Clock then return G.Clock(tonumber(date("%H", time)), tonumber(date("%M", time))) end
    return date("%H:%M", time)
end

-- A number with decimals, "3.2" (grammar.DECIMAL is the locale's mark:
-- "3,2").
function Format.Decimal(n, places)
    local text = ("%." .. (places or 1) .. "f"):format(n)
    if G.DECIMAL then text = text:gsub("%.", G.DECIMAL, 1) end
    return text
end

-- `text` padded with spaces to `width` characters, for a column in chat.
-- Counted in characters, not bytes ("%-3s" counts bytes: "sí" is three).
function Format.Pad(text, width)
    text = tostring(text)
    local _, more = text:gsub("[\128-\191]", "")
    return text .. (" "):rep(width - (#text - more))
end

-- "6 Oct 2026" (a short date with its year), "6 Oct" without. Its own keys
-- beside the long date's: a locale may join the two differently.
function Format.ShortDate(time, withYear)
    local day = Format.Day(tonumber(date("%d", time)))
    if withYear then return Fmt(L["%1$s %2$s %3$s##short date"], day, Format.MonthShort(time), date("%Y", time)) end
    return Fmt(L["%1$s %2$s##short date"], day, Format.MonthShort(time))
end

--------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------

function Format.Duration(seconds)
    local minutes = math.floor((seconds or 0) / 60)
    if minutes < 60 then return Fmt(L["%d min"], minutes) end
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60
    if minutes == 0 then return Fmt(L["%d h"], hours) end
    return Fmt(L["%d h %d min"], hours, minutes)
end

-- DAT-4: stored as server epoch, shown relative or in local time. The
-- second value is true where the answer is a date ("6 Oct 2026") and not
-- words ("3 days ago"), for a sentence that takes "on" before one.
function Format.Ago(time, now)
    if not time then return L["never"] end
    now = now or ns.Now()
    local days = math.floor((now - time) / ns.DAY)
    if days < 1 then return L["today"] end
    if days < 2 then return L["yesterday"] end
    if days < 14 then return ns.Plural(days, L["%d day ago|%d days ago##plural"]) end
    if days < 60 then return ns.Plural(math.floor(days / 7), L["%d week ago|%d weeks ago##plural"]) end
    return Format.ShortDate(time, true), true
end

-- "Mulgore", "Mulgore and Durotar", "Mulgore, Durotar and The Barrens".
--
-- `opts` (all optional):
--   max      past this many names, only `shown` of them and a count of the
--            rest: "Mulgore, Durotar and 2 more"
--   shown    how many to name then (default `max`)
--   more     the rest, as a "##plural" template taking the names and the
--            count (default Format.MORE, "%1$s and %2$d more";
--            Format.OTHERS for people)
--   oxford   a comma before the last "and" once there are three or more,
--            for lists of clauses rather than names
--
-- nil for an empty list.
Format.MORE = L["%1$s and %2$d more|%1$s and %2$d more##plural"]
Format.OTHERS = L["%1$s and %2$d other|%1$s and %2$d others##plural"]

-- names[1], ..., names[last], joined by the list's comma.
local function Commas(names, last)
    local text = names[1]
    for i = 2, last do text = Fmt(L["%1$s, %2$s##list"], text, names[i]) end
    return text
end

function Format.List(names, opts)
    local n = #names
    if n == 0 then return nil end
    opts = opts or {}

    if opts.max and n > opts.max then
        local shown = opts.shown or opts.max
        local head, rest, more = Commas(names, shown), n - shown, opts.more or Format.MORE
        return ns.Plural(rest, more, head, rest)
    end

    if n == 1 then return names[1] end
    local oxford = opts.oxford and n > 2
    -- A locale whose "and" turns on the word after it (Spanish "e Inés")
    -- joins the last name itself: grammar.ListEnd(head, last, oxford).
    if G.ListEnd then return G.ListEnd(Commas(names, n - 1), names[n], oxford) end
    return Fmt(oxford and L["%1$s, and %2$s##list"] or L["%1$s and %2$s"], Commas(names, n - 1), names[n])
end

--------------------------------------------------------------------------
-- Days
--------------------------------------------------------------------------
--
-- Calendar days in local time, not 24-hour blocks: 23:50 last night is
-- "yesterday", not "today".

-- 0 when `time` falls on `now`'s day, 1 on the day before, nil otherwise.
local function DaysBack(time, now)
    local day = date("%Y-%m-%d", time)
    if day == date("%Y-%m-%d", now) then return 0 end
    if day == date("%Y-%m-%d", now - ns.DAY) then return 1 end
    return nil
end

-- "6 October". Given `now`, the year too once it is not now's: "6 October
-- 2025". Without it, never -- for a page that only reaches back as far as
-- the buffer does.
function Format.DayMonth(time, now)
    local day = Format.Day(tonumber(date("%d", time)))
    if now and date("%Y", time) ~= date("%Y", now) then
        return Fmt(L["%1$s %2$s %3$s##date"], day, Format.Month(time), date("%Y", time))
    end
    return Fmt(L["%1$s %2$s##date"], day, Format.Month(time))
end

-- A heading for the day `time` falls on: "Today", "Yesterday", else
-- "Monday, 6 October" (with the year once it is not now's).
function Format.DayLabel(time, now)
    now = now or ns.Now()
    local back = DaysBack(time, now)
    if back == 0 then return L["Today"] end
    if back == 1 then return L["Yesterday"] end
    return Fmt(L["%1$s, %2$s##weekday date"], Format.Weekday(time), Format.DayMonth(time, now))
end

-- "today at 21:43", "yesterday at 18:02", "on 12 Sep at 18:02"; the year is
-- added once it is not this one.
function Format.At(time, now)
    now = now or ns.Now()
    local clock = Format.Clock(time)
    local back = DaysBack(time, now)

    if back == 0 then return Fmt(L["today at %s"], clock) end
    if back == 1 then return Fmt(L["yesterday at %s"], clock) end
    -- The day unpadded, "on 6 Oct" (the copy rules: no zero padding).
    local sameYear = date("%Y", time) == date("%Y", now)
    return Fmt(L["on %1$s at %2$s"], Format.ShortDate(time, not sameYear), clock)
end

-- The profile's "last seen" line, from a character record's `seen`.
function Format.SeenText(seen, now)
    if not seen then return L["Not seen nearby yet."] end

    -- Subzone first, as every place is written: "Last seen today at 21:43
    -- in Goldshire, Elwynn Forest".
    local at = Format.At(seen.time, now)
    if seen.zone and seen.subZone and seen.subZone ~= seen.zone then
        return Fmt(L["Last seen %1$s %2$s, %3$s##zone"], at, ns.ZoneIn(nil, seen.subZone), seen.zone)
    end
    if seen.zone then return Fmt(L["Last seen %1$s %2$s##zone"], at, ns.ZoneIn(seen.mapID, seen.zone)) end
    return Fmt(L["Last seen %s"], at)
end

-- "25th": a number as an ordinal (a locale's own, grammar.Ordinal:
-- German "25."). `context` names the noun it counts where the caller has
-- one ("match", "death", as the word lists' "##match"): an ordinal takes
-- its noun's gender in most languages (Spanish "13.ª" for a death).
function Format.Ordinal(n, context)
    if G.Ordinal then return G.Ordinal(n, context) end
    local tail = n % 100
    if tail >= 11 and tail <= 13 then return n .. "th" end
    local last = n % 10
    return n .. (last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th")
end

-- "third": an ordinal said as a word, from `words` (its words in order,
-- "first" on); past them, the number's ("13th"). The words are a list
-- per noun they count, as an ordinal takes its noun's gender and case in
-- most languages ("dein drittes Match", but "beim dritten Versuch"):
-- Format.NTH_MATCH for a match, a file's own for anything else.
function Format.Nth(n, words)
    return words[n] or Format.Ordinal(n, words.context)
end

Format.NTH_MATCH = { L["first##match"], L["second##match"], L["third##match"], L["fourth##match"],
    L["fifth##match"], L["sixth##match"], L["seventh##match"], L["eighth##match"], L["ninth##match"],
    L["tenth##match"], L["eleventh##match"], L["twelfth##match"], context = "match" }

-- "once", "twice", "5 times". "twice" is a word English has for 2, not a
-- plural form: a locale without one leaves it empty, and 2 takes the
-- plural like any other number.
function Format.Times(n)
    if n == 2 and L["twice"] ~= "" then return L["twice"] end
    return ns.Plural(n, L["once|%d times##plural"])
end

-- The score with a foe, from Interactions.Fights: "You've killed them twice and
-- they've killed you 5 times." A kill by the group counts, and the sentence
-- says whose it was: "Your group has killed them once", "You and your group
-- have killed them 3 times". `em` marks the numbers, if given. `short`,
-- for the reunion card's two lines: "You've killed them 3 times, they've
-- killed you twice", every kill counted as yours. nil for no fights.
function Format.FightsText(fights, em, short)
    if not fights then return nil end
    em = em or tostring
    local kills
    if fights.kills > 0 then
        local who = (short or fights.yours == fights.kills) and L["You've killed them %s"]
            or fights.yours == 0 and L["Your group has killed them %s"] or L["You and your group have killed them %s"]
        kills = Fmt(who, em(Format.Times(fights.kills)))
    end
    local deaths = fights.deaths > 0 and em(Format.Times(fights.deaths)) or nil

    if kills and deaths then
        return Fmt(short and L["%1$s, they've killed you %2$s."] or L["%1$s and they've killed you %2$s."], kills, deaths)
    end
    if kills then return Fmt(L["%s."], kills) end
    if deaths then return Fmt(L["They've killed you %s."], deaths) end
    return nil
end

function Format.Money(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local rest = copper % 100

    local parts = {}
    if gold > 0 then parts[#parts + 1] = Fmt(L["%dg"], gold) end
    if silver > 0 then parts[#parts + 1] = Fmt(L["%ds"], silver) end
    if rest > 0 or #parts == 0 then parts[#parts + 1] = Fmt(L["%dc"], rest) end
    return table.concat(parts, " ")
end

function Format.ClassColor(guid)
    local record = ns.Characters.Get(guid)
    local token = record and record.class
    local color = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if not color then return "|cffffffff" end
    return ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
end

--------------------------------------------------------------------------
-- Characters in words
--------------------------------------------------------------------------
--
-- The colours are the Style files', which load after this one: ns.Style is
-- read when a line is written, never at load.

-- The user in a record's words. A record one of the user's characters
-- wrote keeps who (`me`, `addedBy`, a death's `guid`); in a shared diary
-- another character's "you" is not the one playing, so it is named. Write
-- the sentence as it reads for the one playing, each "you" word in braces:
--
--   You(row.me, "{You} killed Bram")        "You killed Bram", "Thrall killed Bram"
--   You(row.me, "Bram saved {you}")         "Bram saved you", "Bram saved Thrall"
--   You(row.me, "{Your} group killed Bram") "Your group ...", "Thrall's group ..."
--   You(row.me, "{You've} met twice")       "You've met ...", "Thrall has met ..."
--
-- "You" stays for the character playing, a diary of its own, a record from
-- before characters were kept apart (no `me`), and a character without a
-- name. Totals over every character (the score with someone, times met)
-- are the player's and keep a plain "you".

-- Each brace word for another character, its name in place of %s.
local YOU_FOR = {
    ["you"] = "%s", ["your"] = "%s's", ["yours"] = "%s's",
    ["you've"] = "%s has", ["you're"] = "%s is", ["you were"] = "%s was",
}

-- Whether `me` is "you": the character playing, or as good as.
function Format.IsYou(me)
    return not ns.diaryShared or me == nil or me == ns.ownGUID or Format.YouName(me) == nil
end

-- The first name of the user's character `me`, or nil.
function Format.YouName(me)
    local own = me and ns.OwnCharacters()[me]
    return own and own.first or (me and ns.Characters.Name(me)) or nil
end

-- The reader's words a template may brace, for tests/locale.lua: a
-- translation's braced words are checked against its locale's forms.
Format.YOU_FOR = YOU_FOR

function Format.You(me, text)
    if Format.IsYou(me) then return (text:gsub("{(.-)}", "%1")) end
    local name = Format.YouName(me)
    local forms = G.YOU_FOR or YOU_FOR
    return (text:gsub("{(.-)}", function(word)
        local form = forms[word:lower()]
        if type(form) == "function" then return form(name) end
        return form and form:format(name) or word
    end))
end

local RACE_NAMES = { Scourge = L["Undead"], NightElf = L["Night Elf"] }

function Format.RaceName(record)
    if record.raceID and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
        local info = C_CreatureInfo.GetRaceInfo(record.raceID)
        if info and type(info.raceName) == "string" then return info.raceName end
    end
    return record.race and (RACE_NAMES[record.race] or record.race)
end

function Format.ClassName(record)
    local token = record.class
    if not token then return nil end
    local names = record.sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
    if names and names[token] then return names[token] end
    return token:sub(1, 1) .. token:sub(2):lower()
end

-- "Level 6 Tauren Druid, Horde  <Guild>", inked for the page. With
-- dropOwn the faction goes when it is the player's own, as it nearly
-- always is out in the world; with "always" it goes whoever's it is (the
-- person's page: the portrait and the book say enough).
function Format.WhoLine(record, guild, dropOwn)
    record = record or {}
    local parts = {}
    if record.level then parts[#parts + 1] = Fmt(L["Level %d"], record.level) end
    parts[#parts + 1] = Format.RaceName(record)
    parts[#parts + 1] = Format.ClassName(record)

    local text = table.concat(parts, " ")
    local own = dropOwn == "always" or (dropOwn and record.faction == UnitFactionGroup("player"))
    if not own and (record.faction == "Horde" or record.faction == "Alliance") then
        local hex = record.faction == "Horde" and ns.Style.HEX.horde or ns.Style.HEX.alliance
        local faction = "|cff" .. hex .. (record.faction == "Horde" and L["Horde"] or L["Alliance"]) .. "|r"
        text = text ~= "" and Fmt(L["%1$s, %2$s"], text, faction) or faction
    end

    if guild then text = text .. "  |cff" .. ns.Style.HEX.faded .. "<" .. guild .. ">|r" end
    return text
end
