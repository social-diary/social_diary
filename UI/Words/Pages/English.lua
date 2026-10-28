-- English for the pages (PAGE-3): the grammar every page leans on --
-- numbers as words, a or an, plurals, lists, and how long, how long ago and
-- how much, said the way a diary says them rather than the way a log does.
--
-- Everything here is a pure function of its arguments, so the page tests
-- (tests/prose/run.lua) can hold it to account without a client. Another
-- language gets its own file with the same names, and Pages.Lang points at
-- whichever one the locale wants.

local addonName, ns = ...

local Pages = ns.Pages or {}
ns.Pages = Pages

local En = {}
Pages.En = En
Pages.Lang = Pages.Lang or En

local floor = math.floor

--------------------------------------------------------------------------
-- Numbers
--------------------------------------------------------------------------

local ONES = {
    "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
    "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
    "eighteen", "nineteen",
}
local TENS = { nil, "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety" }

local ORDINALS = {
    "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
    "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth",
    "seventeenth", "eighteenth", "nineteenth", "twentieth",
}

-- Digits with thousands commas: 1234 -> "1,234".
function En.Digits(n)
    local s = tostring(floor(n))
    local sign, body = s:match("^(-?)(%d+)$")
    if not body then return s end
    body = body:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return sign .. body
end

-- 0..99 as words, anything else as digits: a diary writes "nineteen days"
-- and "twenty-three quests", but "140 sightings".
function En.Num(n, max)
    n = floor(n or 0)
    max = max or 99
    if n < 0 or n > max then return En.Digits(n) end
    if n == 0 then return "no" end
    if n < 20 then return ONES[n] end
    local t, o = floor(n / 10), n % 10
    if o == 0 then return TENS[t] end
    return TENS[t] .. "-" .. ONES[o]
end

-- "zero" rather than "no", for scores ("three to nothing" reads better as
-- a phrase, so the duel words pick their own).
function En.Zero(n)
    if floor(n or 0) == 0 then return "zero" end
    return En.Num(n)
end

-- 1 -> "1st", 22 -> "22nd", 113 -> "113th".
function En.Ordinal(n)
    n = floor(n)
    local suffix = "th"
    local tens = n % 100
    if tens < 11 or tens > 13 then
        local last = n % 10
        if last == 1 then suffix = "st" elseif last == 2 then suffix = "nd"
        elseif last == 3 then suffix = "rd" end
    end
    return n .. suffix
end

-- 3 -> "third"; past twenty, "23rd".
function En.Nth(n)
    n = floor(n)
    return ORDINALS[n] or En.Ordinal(n)
end

-- "once", "twice", "three times".
function En.Times(n)
    n = floor(n)
    if n == 1 then return "once" end
    if n == 2 then return "twice" end
    return En.Num(n) .. " times"
end

--------------------------------------------------------------------------
-- Words
--------------------------------------------------------------------------

-- The text a reader sees, without WoW's escape sequences (colour codes,
-- hyperlinks, textures), for decisions such as a or an.
function En.Visible(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    s = s:gsub("|n", " ")
    return s
end

-- Words that start with a vowel letter but a consonant sound, and the other
-- way round. Matched against the start of the lowercased word.
local A_BEFORE = { "uni", "use", "usu", "uti", "ure", "uri", "ura", "uro", "uk", "eu", "ewe", "one", "once" }
local AN_BEFORE = { "hour", "honest", "honor", "honour", "heir" }

local function StartsWithAny(word, list)
    for i = 1, #list do
        if word:sub(1, #list[i]) == list[i] then return true end
    end
    return false
end

-- "a" or "an" for what follows it.
function En.Article(phrase)
    local s = En.Visible(phrase):gsub("^[%s%[%(\"']+", "")
    local digits = s:match("^(%d[%d,]*)")
    if digits then
        digits = digits:gsub(",", "")
        if digits:sub(1, 1) == "8" then return "an" end
        if digits:match("^1[18]") and (#digits == 2 or #digits == 5 or #digits == 8) then return "an" end
        return "a"
    end
    local word = s:lower()
    if StartsWithAny(word, AN_BEFORE) then return "an" end
    if StartsWithAny(word, A_BEFORE) then return "a" end
    if word:match("^[aeiou]") then return "an" end
    return "a"
end

-- "an undead rogue", "a Thistlefur Shaman".
function En.A(phrase)
    return En.Article(phrase) .. " " .. phrase
end

local PLURALS = {
    person = "people", man = "men", woman = "women", child = "children",
    elf = "elves", dwarf = "dwarves", wolf = "wolves", life = "lives",
    foot = "feet", tooth = "teeth", mouse = "mice", goose = "geese",
    sheep = "sheep", fish = "fish", deer = "deer",
}

function En.Plural(noun)
    local lower = noun:lower()
    if PLURALS[lower] then return PLURALS[lower] end
    if lower:match("[^aeiou]y$") then return noun:sub(1, -2) .. "ies" end
    if lower:match("[sxz]$") or lower:match("[cs]h$") then return noun .. "es" end
    return noun .. "s"
end

-- "one quest", "nine quests"; `plural` when the noun is irregular in a way
-- the table above doesn't know.
function En.Count(n, noun, plural)
    n = floor(n)
    if n == 1 then return "one " .. noun end
    return En.Num(n) .. " " .. (plural or En.Plural(noun))
end

-- "a quest" for one, otherwise as Count.
function En.CountA(n, noun, plural)
    if floor(n) == 1 then return En.A(noun) end
    return En.Count(n, noun, plural)
end

-- "Ashenvale", "Ashenvale and Stonetalon", "Ashenvale, Stonetalon and the
-- Barrens". No serial comma, as the rest of the diary.
function En.List(items, conj)
    conj = conj or "and"
    local n = #items
    if n == 0 then return nil end
    if n == 1 then return items[1] end
    if n == 2 then return items[1] .. " " .. conj .. " " .. items[2] end
    return table.concat(items, ", ", 1, n - 1) .. " " .. conj .. " " .. items[n]
end

-- "Brennick's"; always 's, so "Morthis's".
function En.Possessive(name)
    return name .. "'s"
end

function En.Lower(s)
    return (s:lower())
end

--------------------------------------------------------------------------
-- Time
--------------------------------------------------------------------------

-- A span of days the way people round it: 19 -> "nearly three weeks".
-- `exact` gives "nineteen days" instead.
function En.Days(d, exact)
    d = floor(d or 0)
    if exact or d <= 4 then
        if d <= 0 then return "less than a day" end
        if d == 1 then return "a day" end
        return En.Num(d) .. " days"
    end
    if d <= 6 then return "nearly a week" end
    if d == 7 then return "a week" end
    if d <= 10 then return "over a week" end
    if d <= 12 then return "nearly two weeks" end
    if d <= 15 then return "two weeks" end
    if d <= 17 then return "over two weeks" end
    if d <= 20 then return "nearly three weeks" end
    if d <= 23 then return "three weeks" end
    if d <= 26 then return "over three weeks" end
    if d <= 29 then return "nearly a month" end
    if d <= 34 then return "a month" end
    if d <= 45 then return "over a month" end
    if d <= 58 then return "nearly two months" end
    if d <= 75 then return "two months" end
    if d < 330 then
        local m = floor(d / 30 + 0.5)
        local whole = floor(d / 30)
        if m > whole then return "nearly " .. En.Num(m) .. " months" end
        if d % 30 > 7 then return "over " .. En.Num(whole) .. " months" end
        return En.Num(whole) .. " months"
    end
    if d < 365 then return "nearly a year" end
    if d < 400 then return "a year" end
    if d < 700 then return "over a year" end
    return "over " .. En.Num(floor(d / 365)) .. " years"
end

-- A span of days as an adjective: "nineteen-day", "one-day".
function En.DayAdj(d)
    d = floor(d or 0)
    if d < 1 then return nil end
    return En.Num(d) .. "-day"
end

-- How long ago, in days: "yesterday", "nineteen days ago", "nearly three
-- weeks ago".
function En.Ago(d, exact)
    d = floor(d or 0)
    if d <= 0 then return "earlier today" end
    if d == 1 then return "yesterday" end
    return En.Days(d, exact) .. " ago"
end

local WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local MONTHS = {
    "January", "February", "March", "April", "May", "June", "July", "August",
    "September", "October", "November", "December",
}

local date = date or os.date
local time = time or os.time

-- Calendar days between two times, by the dates on them rather than by
-- 24-hour blocks: 23:50 to 00:10 is a day apart.
local function DayNumber(t)
    local d = date("*t", t)
    return floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

function En.CalendarDays(t, now)
    return DayNumber(now) - DayNumber(t)
end

-- When something was, from the page's own time: "on Tuesday" within the
-- week, "on the 12th" within the month, "back in September" before that,
-- "in September 2025" past a year.
function En.When(t, now)
    local days = En.CalendarDays(t, now)
    local a, b = date("*t", t), date("*t", now)
    if days <= 0 then return "earlier today" end
    if days == 1 then return "yesterday" end
    if days < 7 then return "on " .. WEEKDAYS[a.wday] end
    if a.year == b.year and a.month == b.month then return "on the " .. En.Ordinal(a.day) end
    if a.year == b.year or (b.month < a.month and days < 330) then
        return "back in " .. MONTHS[a.month]
    end
    return "in " .. MONTHS[a.month] .. " " .. a.year
end

-- A bare date for after "since" or "until": "Tuesday", "the 12th",
-- "September", "September 2025".
function En.Date(t, now)
    local days = En.CalendarDays(t, now)
    local a, b = date("*t", t), date("*t", now)
    if days <= 0 then return "earlier today" end
    if days == 1 then return "yesterday" end
    if days < 7 then return WEEKDAYS[a.wday] end
    if a.year == b.year and a.month == b.month then return "the " .. En.Ordinal(a.day) end
    if a.year == b.year or (b.month < a.month and days < 330) then return MONTHS[a.month] end
    return MONTHS[a.month] .. " " .. a.year
end

-- The part of the day a session belongs to, from its start. Late nights
-- belong to the evening before, so a session from 23:00 to 01:00 is still
-- "tonight".
function En.PartOfDay(t)
    local h = tonumber(date("%H", t))
    if h < 5 then return "night" end
    if h < 12 then return "morning" end
    if h < 17 then return "afternoon" end
    if h < 22 then return "evening" end
    return "night"
end

-- "tonight", "this morning", "this afternoon", "this evening".
local TODAY = {
    morning = "this morning", afternoon = "this afternoon",
    evening = "tonight", night = "tonight",
}
function En.Today(part)
    return TODAY[part] or "today"
end

-- How long something lasted: "twenty minutes", "about an hour", "nearly
-- two hours".
function En.Duration(sec)
    sec = floor(sec or 0)
    local m = floor(sec / 60 + 0.5)
    if m < 2 then return "a minute or two" end
    if m < 5 then return "a few minutes" end
    if m < 13 then
        local rounded = floor(m / 5 + 0.5) * 5
        return En.Num(rounded) .. " minutes"
    end
    if m < 20 then return "a quarter of an hour" end
    if m < 26 then return "twenty minutes" end
    if m < 37 then return "half an hour" end
    if m < 50 then return "the better part of an hour" end
    if m < 70 then return "about an hour" end
    if m < 80 then return "over an hour" end
    if m < 100 then return "an hour and a half" end
    if m < 110 then return "nearly two hours" end
    local h = floor(m / 60)
    local rest = m - h * 60
    if rest < 10 then return En.Num(h) .. " hours" end
    if rest < 40 then return "over " .. En.Num(h) .. " hours" end
    if rest < 50 then return En.Num(h) .. " and a half hours" end
    return "nearly " .. En.Num(h + 1) .. " hours"
end

-- Short spans, as a watcher's seconds: "eight seconds", "about half a
-- minute", "over a minute".
function En.Seconds(sec)
    sec = floor(sec or 0)
    if sec <= 1 then return "a second" end
    if sec <= 20 then return En.Num(sec) .. " seconds" end
    if sec <= 25 then return "over twenty seconds" end
    if sec <= 40 then return "about half a minute" end
    if sec <= 55 then return "most of a minute" end
    if sec <= 70 then return "a full minute" end
    if sec <= 150 then return "over a minute" end
    return En.Duration(sec)
end

-- How much of the session `sec` was, in words for `part` of the day:
-- "most of the evening", "all night", "a little while".
function En.Share(sec, total, part)
    local word = (part == "night" and "night") or part or "session"
    if not total or total <= 0 then return En.Duration(sec) end
    local r = sec / total
    if r >= 0.9 then return "the whole " .. word end
    if r >= 0.6 then return "most of the " .. word end
    if r >= 0.4 then return "a good part of the " .. word end
    if r >= 0.2 then return "part of the " .. word end
    return "a little while"
end

--------------------------------------------------------------------------
-- Money
--------------------------------------------------------------------------

-- Copper as a reader says it: "2 gold and 10 silver", "45 silver".
function En.Money(copper)
    copper = floor(copper or 0)
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = En.Digits(g) .. " gold" end
    if s > 0 then parts[#parts + 1] = s .. " silver" end
    if c > 0 and g == 0 then parts[#parts + 1] = c .. " copper" end
    if #parts == 0 then return "nothing" end
    return En.List(parts)
end

-- Money without the figures, banded by size: "a few coppers", "some
-- silver", "a few gold", "a fair bit of gold", "a lot of gold".
function En.Coins(copper)
    copper = floor(copper or 0)
    if copper < 100 then return "a few coppers" end
    if copper < 10000 then return "some silver" end
    if copper < 100000 then return "a few gold" end
    if copper < 1000000 then return "a fair bit of gold" end
    return "a lot of gold"
end

--------------------------------------------------------------------------
-- Items
--------------------------------------------------------------------------

-- One trade entry { link, count } as a phrase: "a [Lesser Healing Potion]",
-- "five [Silk Cloth]". Item names are never pluralised: a guessed plural of
-- a name reads worse than the count in front of it.
function En.Item(entry)
    local link = entry.link or entry.name or "something"
    local count = floor(entry.count or 1)
    if count <= 1 then return En.A(link) end
    return En.Num(count) .. " " .. link
end

-- A list of trade entries: up to `max` named (default 2), then "and three
-- other things".
function En.Items(list, max)
    max = max or 2
    if not list or #list == 0 then return nil end
    local parts = {}
    for i = 1, math.min(#list, max) do parts[#parts + 1] = En.Item(list[i]) end
    local rest = #list - max
    if rest == 1 then
        parts[#parts + 1] = "one other thing"
    elseif rest > 1 then
        parts[#parts + 1] = En.Num(rest) .. " other things"
    end
    return En.List(parts)
end

--------------------------------------------------------------------------
-- Sentences
--------------------------------------------------------------------------

-- Upper-cases the first letter a reader would see, stepping over escape
-- sequences and an opening bracket or quote, so an item link at the start
-- of a sentence is left alone.
function En.CapFirst(s)
    local i, n = 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c == "|" then
            local nxt = s:sub(i + 1, i + 1)
            if nxt == "c" then i = i + 10
            elseif nxt == "H" then
                local stop = s:find("|h", i + 2, true)
                i = stop and stop + 2 or n + 1
            elseif nxt == "T" or nxt == "A" then
                local stop = s:find("|[ta]", i + 2)
                i = stop and stop + 2 or n + 1
            else
                i = i + 2
            end
        elseif c:match("[%s%[\"'%(]") then
            i = i + 1
        else
            if c:match("%l") then
                return s:sub(1, i - 1) .. c:upper() .. s:sub(i + 1)
            end
            return s
        end
    end
    return s
end

-- Tidies the joins between pieces: doubled spaces, a comma before a full
-- stop (an appositive at the end of a sentence), doubled commas.
function En.Clean(s)
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("%s+([,%.;:!%?])", "%1")
    s = s:gsub(",+", ",")
    s = s:gsub(",([%.;:!%?])", "%1")
    s = s:gsub("([;:]),", "%1")
    s = s:gsub("%.%.+", ".")
    s = s:gsub("([!%?])%.", "%1")
    -- Every sentence after the first starts with a capital, wherever the
    -- piece that began it came from.
    s = s:gsub("([%.!%?][\"']?%s+)([%l])", function(gap, letter) return gap .. letter:upper() end)
    return s
end

-- Ends a sentence that doesn't end itself.
function En.Close(s)
    local visible = En.Visible(s):gsub("[\"'%)]+$", "")
    if visible:match("[%.!%?]$") then return s end
    return s .. "."
end
