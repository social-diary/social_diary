-- Portuguese (Brazil): the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/ptBR.md.
local addonName, ns = ...
-- Offered on every client, by its own name (Settings, Language).
ns.Locale.Offer("ptBR", "Português (Brasil)")
if not ns.Locale.Is("ptBR") then return end

local G = ns.Locale.grammar

-- CLDR: 1 is "one", the rest "other" (Brazilian speech counts 0 as other:
-- "0 combates"; the "many" of whole millions is never reached by a count
-- in the diary). 1 alone, so the first form may leave the figure out
-- ("um combate") and 0 keeps its own with the plural ("0 combates").
G.PluralForm = function(n) return n == 1 and 1 or 2 end
G.PLURAL_FORMS = 2

-- Letters outside ASCII, in UTF-8: every accented lower-case letter of
-- Portuguese sits after the lead byte \195.
local UP = {
    ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["ä"] = "Ä",
    ["ç"] = "Ç", ["é"] = "É", ["ê"] = "Ê", ["ë"] = "Ë",
    ["í"] = "Í", ["î"] = "Î", ["ï"] = "Ï",
    ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ö"] = "Ö",
    ["ú"] = "Ú", ["ü"] = "Ü", ["ñ"] = "Ñ",
}
local function Up(text)
    return (text:upper():gsub("[\195][\128-\191]", function(c)
        return UP[c] or c
    end))
end
G.Upper = Up

-- The first letter up, past an opening quote or bracket.
G.Capital = function(text)
    local lead, first, rest = text:match("^([“\"‘'«(¿¡]*)([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return text end
    return lead .. Up(first) .. rest
end

-- "25º", and "25ª" for a feminine noun: the death ("morte"), the match
-- ("partida") and the time ("pela 13ª vez") of the word lists.
local FEMININE = { death = true, match = true, time = true }
G.Ordinal = function(n, context) return n .. (FEMININE[context] and "ª" or "º") end

-- A date's day is the figure: "1 de outubro", "25 de outubro".
G.Day = function(n) return tostring(n) end

-- "3,2"
G.DECIMAL = ","

-- The hour unpadded, 24 h: "18:30", "9:05", "1:05".
G.Clock = function(h, m) return ("%d:%02d"):format(h, m) end

-- The last name of a list: "Ana, Bia e Caio" (a comma before "e" only in
-- a list of clauses, `oxford`).
G.ListEnd = function(head, last, oxford)
    return head .. (oxford and ", e " or " e ") .. last
end

-- The last pass over every filled template (Locales/Locale.lua, ns.Fmt):
--   a number word before a feminine noun, when the count arrives as a
--   value: the words mark it "%s<f>" ("vitórias: duas"); the mark goes
--   either way. Portuguese: um -> uma, dois -> duas.
--   The hour's article: the templates say "às %s", and one o'clock is
--   "à 1:05" (Clock gives the hour alone, the article is the words').
local FEM = { um = "uma", Um = "Uma", dois = "duas", Dois = "Duas" }
G.Agree = function(text)
    if text:find("<f>", 1, true) then
        text = (text:gsub("([Uu]m)<f>", function(w) return FEM[w] end)
            :gsub("([Dd]ois)<f>", function(w) return FEM[w] end)
            :gsub("<f>", ""))
    end
    if text:find("às 1:", 1, true) then
        text = (text:gsub("às 1:(%d%d)", "à 1:%1"))
    end
    return text
end

-- A creature is named as it comes, with no article to turn off; the
-- client's names carry their own gender, which cannot be known here, so
-- the sentences read a bare name ("morto por %s").
G.NO_ARTICLE = true

-- A name in the genitive: "a história de Brom".
G.Genitive = function(name) return "de " .. name end

-- The reader's words, each with its form for another character's name in
-- a shared diary (UI/Words/Format.lua, Format.You). A form is written as
-- it reads: one that opens a sentence is capitalised here, and the words
-- use its brace only where it fits. Every braced phrase of
-- Locales/ptBR/ is one of these.
G.YOU_FOR = {
    -- The reader, as the subject or the object of the line.
    ["você"] = "%s",
    ["vocês dois"] = function(name) return name .. " e você" end,
    -- "a terceira partida sua": another character's is "de Bram".
    ["sua"] = function(name) return "de " .. name end,
    -- The diary's own phrases, braced whole so the name falls inside them.
    ["seu grupo"] = "O grupo de %s",
    ["com você"] = "com %s",
}

-- Lower case, accents included ("Pântano" -> "pântano"): by the first letter,
-- which is all a place's name needs, and by the whole word after "Ordenado
-- por" (PeopleSortLabel).
local DOWN = { ["Á"] = "á", ["À"] = "à", ["Â"] = "â", ["Ã"] = "ã", ["Ä"] = "ä",
    ["Ç"] = "ç", ["É"] = "é", ["Ê"] = "ê", ["Ë"] = "ë", ["Í"] = "í", ["Î"] = "î",
    ["Ï"] = "ï", ["Ó"] = "ó", ["Ô"] = "ô", ["Õ"] = "õ", ["Ö"] = "ö", ["Ú"] = "ú",
    ["Ü"] = "ü", ["Ñ"] = "ñ" }
local function Down(word)
    local first = word:match("^[\195][\128-\191]") or word:sub(1, 1)
    return (DOWN[first] or first:lower()) .. word:sub(#first + 1)
end

-- A place after a preposition. The client gives the bare name ("Floresta de
-- Elwynn"), and Portuguese says it with an article, contracted into the
-- preposition: "na Floresta de Elwynn", "para o Vale de Alterac". The gender
-- is the head noun's, which in Portuguese is the name's first word.
--
-- A name whose first word is no common noun is a city or a proper name and
-- takes no article ("em Orgrimmar", "em Ventobravo", "em Durotar"); so does
-- a zone whose head is not in HEAD yet: the plain preposition, as before.
-- Names come from the game, never from here: this file only reads the first
-- word of a name the client gave.
--
--   "f" one feminine, "m" one masculine, "fp"/"mp" more than one
-- Every key in ["..."]: WoW's Lua 5.1 takes no accented bare name.
-- HEAD (first words of place names that take an article) now lives in
-- Locales/ptBR/AreaHead.lua, which populates G.HEAD right after this file.
G.HEAD = {}

-- An article the client's name brings with it ("A Cidade Afogada", "O Grande
-- Oceano", "As Catacumbas"), used and dropped. A place's name never begins
-- with one of these words as part of itself, so a leading one is the article,
-- whatever word follows it.
local LEAD = { a = "f", o = "m", as = "fp", os = "mp" }

-- The preposition per role and gender, and before a bare name.
local BARE = {
    ["in"] = "em", at = "em", to = "para", into = "para", from = "de",
    through = "por", near = "perto de", around = "ao redor de", round = "ao redor de",
}
local WITH = {
    f = { ["in"] = "na", at = "na", to = "para a", into = "para a", from = "da",
        through = "pela", near = "perto da", around = "ao redor da", round = "ao redor da" },
    m = { ["in"] = "no", at = "no", to = "para o", into = "para o", from = "do",
        through = "pelo", near = "perto do", around = "ao redor do", round = "ao redor do" },
    fp = { ["in"] = "nas", at = "nas", to = "para as", into = "para as", from = "das",
        through = "pelas", near = "perto das", around = "ao redor das", round = "ao redor das" },
    mp = { ["in"] = "nos", at = "nos", to = "para os", into = "para os", from = "dos",
        through = "pelos", near = "perto dos", around = "ao redor dos", round = "ao redor dos" },
}

-- `name`'s gender and its name without the article it brought, or no gender
-- and the name whole.
local function Gender(name)
    local article, rest = name:match("^([AaOo][s]?) (%S.*)$")
    if article then return LEAD[article:lower()], rest end
    local word = name:match("^%S+")
    local head = G.HEAD
    return word and head and head[Down(word)], name
end

local function Place(role)
    return function(name)
        name = name or ""
        if name == "" then return BARE[role] end
        local gender, rest = Gender(name)
        if not gender then return BARE[role] .. " " .. name end
        return WITH[gender][role] .. " " .. rest
    end
end

G.PLACE = {}
for role in pairs(BARE) do G.PLACE[role] = Place(role) end
-- Every name of a list takes its own article and preposition: "na Floresta
-- de Elwynn e no Vale de Alterac".
G.EACH_PLACE = true
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client,
-- and PLACE reads the first word of each.

-- A creature's or item's name for more than one, and a killer's name in a
-- sentence: the client's names carry their own article and gender, which
-- cannot be known here, so they stay as they come.
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- A foe described ("um Caçador Anão de nível 16"): the same shapes as the
-- English (UI/Journey/Text/Grammar.lua, FoeName), with no "a"/"an" to
-- choose and the article agreeing with the foe's sex ("uma Caçadora").
-- The client gives the class in the foe's gender; the race name it gives
-- is one form for both (see the voice file).
G.FoeName = function(w, foe)
    -- The forms picked before the values go in (ns.Fmt would take the
    -- form for no one known).
    local sex = foe and foe.sex
    local L = setmetatable({}, { __index = function(_, key) return ns.Locale.They(ns.L[key], sex) end })
    local Fmt = ns.Fmt
    local text
    if w.level and w.race and w.class then
        text = Fmt(L["a level %1$d %2$s %3$s##foe"], w.level, w.race, w.class)
    elseif w.level and (w.race or w.class) then
        text = Fmt(L["a level %1$d %2$s##foe"], w.level, w.class or w.race)
    elseif w.level then
        text = Fmt(L["someone at level %d##foe"], w.level)
    elseif w.race and w.class then
        text = Fmt(L["a %1$s %2$s##foe"], w.race, w.class)
    else
        text = Fmt(L["a %s##foe"], w.class or w.race)
    end
    return text
end

-- After "Ordenado por", lower case, accents included.
G.PeopleSortLabel = function(label)
    return Down(label)
end

-- A first found card's heading, whole: "Sua primeira bolsa!", "Seu
-- primeiro item verde!". The genders differ (uma bolsa, um par, um item),
-- so each kind carries its own possessive and ordinal.
local FIRST = {
    bag = { "sua primeira bolsa", "sua primeira bolsa" },
    shoulder = { "seu primeiro par de ombreiras", "seu primeiro par de ombreiras" },
    uncommon = { "seu primeiro item verde", "seu primeiro verde" },
    rare = { "seu primeiro item azul", "seu primeiro azul" },
    epic = { "seu primeiro item épico", "seu primeiro épico" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRST[kind]
        words[#words + 1] = f and f[short and 2 or 1] or "sua primeira descoberta"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " e " .. words[#words]
    end
    return G.Capital(text) .. "!"
end
