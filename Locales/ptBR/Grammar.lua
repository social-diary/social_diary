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

-- "25º", and "25ª" for a feminine noun: the death ("morte") and the match
-- ("partida") of the word lists.
local FEMININE = { death = true, match = true }
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

-- The plain preposition per role. The client's name arrives bare, with no
-- article ("Floresta de Elwynn" is a feminine name that wants "na": that
-- needs the names, see the report); "near" reads "perto de".
G.PLACE = {
    ["in"] = "em %s", to = "para %s", from = "de %s", into = "em %s",
    through = "por %s", near = "perto de %s", at = "em %s",
    around = "ao redor de %s", round = "ao redor de %s",
}
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client.

-- A creature's or item's name for more than one, and a killer's name in a
-- sentence: the client's names carry their own article and gender, which
-- cannot be known here, so they stay as they come.
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- After "Ordenado por", lower case, accents included.
local DOWN = { ["Á"] = "á", ["À"] = "à", ["Â"] = "â", ["Ã"] = "ã", ["Ä"] = "ä",
    ["Ç"] = "ç", ["É"] = "é", ["Ê"] = "ê", ["Ë"] = "ë", ["Í"] = "í", ["Î"] = "î",
    ["Ï"] = "ï", ["Ó"] = "ó", ["Ô"] = "ô", ["Õ"] = "õ", ["Ö"] = "ö", ["Ú"] = "ú",
    ["Ü"] = "ü", ["Ñ"] = "ñ" }
G.PeopleSortLabel = function(label)
    local first = label:match("^[\195][\128-\191]") or label:sub(1, 1)
    return (DOWN[first] or first:lower()) .. label:sub(#first + 1)
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
