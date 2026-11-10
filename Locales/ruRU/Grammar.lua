-- Russian: the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/ruRU.md.
local addonName, ns = ...
-- Offered on every client, by its own name (Settings, Language).
ns.Locale.Offer("ruRU", "Русский")
if not ns.Locale.Is("ruRU") then return end

local G = ns.Locale.grammar

-- CLDR "one | few | many" for integers: 1, 21, 101 take the first form;
-- 2 to 4 (not 12 to 14) the second; the rest (0, 5 to 20, 25) the third.
G.PluralForm = function(n)
    local tail, last = n % 100, n % 10
    if last == 1 and tail ~= 11 then return 1 end
    if last >= 2 and last <= 4 and (tail < 12 or tail > 14) then return 2 end
    return 3
end
G.PLURAL_FORMS = 3

-- Cyrillic in UTF-8: lead byte 208 (\208) holds А-п (\144-\191), lead byte
-- 209 (\209) holds р-я (\128-\143) and ё (\145); Ё is \208\129.
local function UpOne(c)
    local a, b = c:byte(1, 2)
    if a == 208 and b >= 176 and b <= 191 then return string.char(208, b - 32) end
    if a == 209 and b >= 128 and b <= 143 then return string.char(208, b + 32) end
    if a == 209 and b == 145 then return "\208\129" end
    return c
end
local function DownOne(c)
    local a, b = c:byte(1, 2)
    if a == 208 and b >= 144 and b <= 159 then return string.char(208, b + 32) end
    if a == 208 and b >= 160 and b <= 175 then return string.char(209, b - 32) end
    if a == 208 and b == 129 then return "\209\145" end
    return c
end
local function Up(text)
    return (text:upper():gsub("[\208\209][\128-\191]", UpOne))
end
G.Upper = Up

-- The first letter up (a whole UTF-8 character).
G.Capital = function(text)
    local first, rest = text:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return text end
    return Up(first) .. rest
end

-- "25-й", and "25-я" for a feminine noun: the death ("смерть") of the
-- word lists (the match, "матч", is masculine). Nominative only.
local FEMININE = { death = true }
G.Ordinal = function(n, context) return n .. (FEMININE[context] and "-я" or "-й") end

-- A date's day is the figure: "25 окт".
G.Day = function(n) return tostring(n) end

-- "3,2"
G.DECIMAL = ","

-- Every name of a list takes its own preposition and quotes: "в «Мулгор»
-- и в «Дуротар»". A creature is named as it comes, with no article.
G.EACH_PLACE = true
G.NO_ARTICLE = true

-- A number word before a feminine or neuter noun, marked "<f>" or "<n>"
-- in the words ("%s<f> смерти"): "один" and "два" change, the mark goes
-- either way. Nominative only.
local AGREE = {
    f = { ["один"] = "одна", ["Один"] = "Одна", ["два"] = "две", ["Два"] = "Две" },
    n = { ["один"] = "одно", ["Один"] = "Одно" },
}
G.Agree = function(text)
    if not text:find("<[fn]>") then return text end
    return (text:gsub("([^%s<]+)<([fn])>", function(word, gender)
        return AGREE[gender][word] or word
    end))
end

-- A name in a sentence of the "story of" kind: the name is not declined
-- (it arrives from the game), the translation's template takes it bare.
G.Genitive = function(name) return name end

-- The reader's words, each with its form for another character's name.
-- Filled after the translation (every braced word in Locales/ruRU/).
G.YOU_FOR = {
    ["ты"] = "%s", ["тебя"] = "%s", ["тебе"] = "%s", ["тобой"] = "%s",
    -- A sentence's first word: string.lower leaves Cyrillic as it is, so
    -- the capital is looked up as written.
    ["Ты"] = "%s",
    ["у тебя"] = "у %s", ["твоя группа"] = "группа %s",
    ["вы"] = "%s и они", ["ты умираешь"] = "%s умирает",
    ["твоей руки"] = "руки %s", ["руки твоей группы"] = "руки группы %s",
}

-- The plain preposition per role. The client's name arrives bare, in the
-- nominative, and Russian declines it ("в Дуротаре"): that cannot be done
-- here, so the name is set in quotes after the preposition and reads as a
-- title ("в «Дуротар»"), the same for a zone, a subzone and a dungeon.
-- ZONES, DUNGEONS, SUBZONES stay empty: see ruRU-code-changes.md.
G.PLACE = {
    ["in"] = "в «%s»", to = "в «%s»", from = "из «%s»", into = "в «%s»",
    through = "через «%s»", near = "рядом с «%s»", at = "у «%s»",
    around = "вокруг «%s»", round = "вокруг «%s»",
}

-- Names for more than one, and a killer's name in a sentence: the client's
-- names decline in ways that cannot be known here, so they stay as they come.
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- After "Сортировка:", lower case.
G.PeopleSortLabel = function(label)
    local first = label:match("^[%z\1-\127\194-\244][\128-\191]*")
    return DownOne(first:lower()) .. label:sub(#first + 1)
end

-- A first found card's heading, whole: "Первый зелёный предмет!". The kinds
-- come sorted; each noun carries its own gender, so no "Твой/Твоя" leads it.
local FIRST = {
    bag = { "первая сумка", "первая сумка" },
    shoulder = { "первые наплечники", "первые наплечники" },
    uncommon = { "первый зелёный предмет", "первый зелёный" },
    rare = { "первый синий предмет", "первый синий" },
    epic = { "первый эпический предмет", "первый эпический" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRST[kind]
        words[#words + 1] = f and f[short and 2 or 1] or "первая находка"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " и " .. words[#words]
    end
    return G.Capital(text) .. "!"
end
