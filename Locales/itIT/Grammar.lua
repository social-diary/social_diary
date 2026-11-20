-- Italian (Italy): the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/itIT.md.
local addonName, ns = ...
-- Offered on every client, by its own name (Settings, Language).
ns.Locale.Offer("itIT", "Italiano")
if not ns.Locale.Is("itIT") then return end

local G = ns.Locale.grammar

-- CLDR: 1 is "one", the rest "other" (the "many" of whole millions is
-- never reached by a count in the diary).
G.PluralForm = function(n) return n == 1 and 1 or 2 end
G.PLURAL_FORMS = 2

-- Letters outside ASCII, in UTF-8.
local UP = {
    ["à"] = "À", ["è"] = "È", ["é"] = "É", ["ì"] = "Ì", ["ò"] = "Ò", ["ù"] = "Ù",
}
local function Up(text)
    return (text:upper():gsub("[\195][\160\168\169\172\178\185]", function(c)
        return UP[c] or c
    end))
end
G.Upper = Up

-- The first letter up.
G.Capital = function(text)
    local first, rest = text:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return text end
    return Up(first) .. rest
end

-- "25°", and "25ª" for a feminine noun: the death ("morte"), the match
-- ("partita") and the time ("per la 13ª volta") of the word lists.
local FEMININE = { death = true, match = true, time = true }
G.Ordinal = function(n, context) return n .. (FEMININE[context] and "ª" or "°") end

-- A date's day is the figure: "25 ott", "6 ottobre".
G.Day = function(n) return tostring(n) end

-- "3,2"
G.DECIMAL = ","

-- The hour unpadded, 24 h: "18:30", "9:05", "1:05".
G.Clock = function(h, m) return ("%d:%02d"):format(h, m) end

-- The last pass over every filled template (Locales/Locale.lua, ns.Fmt):
--   "un" before a feminine noun, when the number word arrives as a value:
--   the words mark it "%s<f>" ("vittorie: una").
--   The hour's article: the templates say "alle %s", and one o'clock is
--   "all’1:05" (Clock gives the hour alone, the article is the words').
G.Agree = function(text)
    if text:find("<f>", 1, true) then
        text = text:gsub("%f[%a]([Uu]n)<f>", "%1a"):gsub("<f>", "")
    end
    if text:find("alle 1:", 1, true) then
        text = text:gsub("%f[%a]([Aa])lle 1:(%d%d)", "%1ll’1:%2")
    end
    if text:find("dalle 1:", 1, true) then
        text = text:gsub("dalle 1:(%d%d)", "dall’1:%1")
    end
    return text
end

-- "e" before a word: "e Ida" (the Italian "e" is always "e"; "ed" is
-- avoided).
G.ListEnd = function(head, last) return head .. " e " .. last end

-- A creature is named as it comes, with no article to turn off.
G.NO_ARTICLE = true

-- A name in the genitive: "la storia di Brom".
G.Genitive = function(name) return "di " .. name end

-- The reader's words, each with its form for another character's name.
-- Filled after the translation (every braced word in Locales/itIT/).
G.YOU_FOR = {
    ["con te"] = "con %s", ["dal tuo gruppo"] = "dal gruppo di %s", ["del tuo gruppo"] = "del gruppo di %s",
    ["ha cercato di salvarti"] = "ha cercato di salvare %s",
    ["hai abbandonato il duello"] = "%s ha abbandonato il duello",
    ["hai condiviso"] = "%s ha condiviso", ["hai lasciato"] = "%s ha lasciato",
    ["hai perso"] = "%s ha perso", ["hai raggiunto"] = "%s ha raggiunto",
    ["hai tirato"] = "%s ha tirato", ["hai ucciso"] = "%s ha ucciso", ["hai vinto"] = "%s ha vinto",
    ["sei morta"] = "%s è morta", ["sei morto"] = "%s è morto",
    ["te"] = "%s", ["tu"] = "%s", ["tu e quella persona"] = "%s e quella persona",
    ["ti ha guardato morire"] = "ha guardato morire %s", ["ti ha salvato"] = "ha salvato %s",
    ["ti ha ucciso"] = "ha ucciso %s", ["ti ha visto morire"] = "ha visto morire %s",
    ["tua"] = "di %s", ["tuo"] = "di %s",
}

-- The plain preposition per role. The client gives a bare name that may
-- carry its own article ("The Barrens"), which cannot be known here, so the
-- prepositions stay simple ("a", "in", "da").
G.PLACE = {
    ["in"] = "in %s", to = "verso %s", from = "da %s", into = "dentro %s",
    through = "attraverso %s", near = "vicino a %s", at = "a %s",
    around = "intorno a %s", round = "intorno a %s",
}
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client.

G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- A foe described ("un Dwarf Hunter di Level 16"): the race and class come
-- in the client's words (English), the article is Italian and goes by the
-- foe's sex and the word after it: "una Hunter", "un’Orc", "uno Shaman",
-- "uno Gnome" (UI/Journey/Text/Grammar.lua's FoeName).
local FEMALE = 3
local function Article(text, sex)
    local word = text:match("^un (.*)$")
    if not word then return text end
    if sex == FEMALE then
        return (word:find("^[AEIOUaeiou]") and "un’" or "una ") .. word
    end
    local uno = word:find("^[Ss][^AEIOUaeiou]") or word:find("^[Zz]") or word:find("^[Gg][Nn]")
        or word:find("^[Pp][Ss]") or word:find("^[Xx]")
    return (uno and "uno " or "un ") .. word
end
G.FoeName = function(words, foe)
    local L, Fmt = ns.L, ns.Fmt
    local level, race, class = words.level, words.race, words.class
    local text
    if level and race and class then text = Fmt(L["a level %1$d %2$s %3$s##foe"], level, race, class)
    elseif level and (race or class) then text = Fmt(L["a level %1$d %2$s##foe"], level, race or class)
    elseif level then return Fmt(L["someone at level %d##foe"], level)
    elseif race and class then text = Fmt(L["a %1$s %2$s##foe"], race, class)
    else text = Fmt(L["a %s##foe"], race or class) end
    return Article(text, foe and foe.sex)
end

-- After "Ordinato per", lower case, accents included.
local DOWN = { ["À"] = "à", ["È"] = "è", ["É"] = "é", ["Ì"] = "ì", ["Ò"] = "ò", ["Ù"] = "ù" }
G.PeopleSortLabel = function(label)
    local first = label:match("^[\195][\128-\191]") or label:sub(1, 1)
    return (DOWN[first] or first:lower()) .. label:sub(#first + 1)
end

-- A first found card's heading, whole: "Il tuo primo oggetto verde!".
local FIRST = {
    bag = { "prima borsa", "prima borsa" },
    shoulder = { "primo paio di spalline", "prime spalline" },
    uncommon = { "primo oggetto verde", "primo verde" },
    rare = { "primo oggetto blu", "primo blu" },
    epic = { "primo oggetto epico", "primo epico" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRST[kind]
        words[#words + 1] = f and f[short and 2 or 1] or "ritrovamento"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " e " .. words[#words]
    end
    return "Il tuo " .. text .. "!"
end
