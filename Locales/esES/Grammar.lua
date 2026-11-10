-- Spanish (Spain): the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/esES.md.
local addonName, ns = ...
-- Offered on every client, by its own name (Settings, Language).
ns.Locale.Offer("esES", "Español")
if not ns.Locale.Is("esES") then return end

local G = ns.Locale.grammar

-- CLDR: 1 is "one", the rest "other" (the "many" of whole millions is
-- never reached by a count in the diary).
G.PluralForm = function(n) return n == 1 and 1 or 2 end
G.PLURAL_FORMS = 2

-- Letters outside ASCII, in UTF-8.
local UP = {
    ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú",
    ["ü"] = "Ü", ["ñ"] = "Ñ",
}
local function Up(text)
    return (text:upper():gsub("[\195][\161\169\173\179\186\188\177]", function(c)
        return UP[c] or c
    end))
end
G.Upper = Up

-- The first letter up, past an opening ¿ or ¡.
G.Capital = function(text)
    local lead, first, rest = text:match("^([¿¡]*)([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return text end
    return lead .. Up(first) .. rest
end

-- "25.º", and "25.ª" for a feminine noun: the death ("muerte") and the
-- match ("partida") of the word lists.
local FEMININE = { death = true, match = true }
G.Ordinal = function(n, context) return n .. (FEMININE[context] and ".ª" or ".º") end

-- A date's day is the figure: "25 oct", "6 de octubre".
G.Day = function(n) return tostring(n) end

-- "3,2"
G.DECIMAL = ","

-- The hour unpadded, 24 h: "18:30", "9:05", "1:05".
G.Clock = function(h, m) return ("%d:%02d"):format(h, m) end

-- The last pass over every filled template (Locales/Locale.lua, ns.Fmt):
--   "un" before a feminine noun, when the number word arrives as a value:
--   the words mark it "%s<f>" ("victorias: una"); the mark goes either way.
--   The hour's article: the templates say "a las %s", and one o'clock is
--   "a la 1:05" (Clock gives the hour alone, the article is the words').
G.Agree = function(text)
    if text:find("<f>", 1, true) then
        text = text:gsub("%f[%a]([Uu]n)<f>", "%1a"):gsub("<f>", "")
    end
    if text:find("las 1:", 1, true) then
        text = text:gsub("%f[%a]([Ll])as 1:(%d%d)", "%1a 1:%2")
    end
    return text
end

-- "y" is "e" before a word that starts with the sound i ("e Inés", "e
-- Hilda"; not before "hie", "y hierro").
G.ListEnd = function(head, last)
    local low = last:lower()
    local e = (low:find("^i") or low:find("^hi")) and not low:find("^hie") and not low:find("^io")
    return head .. (e and " e " or " y ") .. last
end

-- A creature is named as it comes, with no article to turn off.
G.NO_ARTICLE = true

-- A name in the genitive: "la historia de Brom".
G.Genitive = function(name) return "de " .. name end

-- The reader's words, each with its form for another character's name.
-- Filled after the translation (every braced word in Locales/esES/).
G.YOU_FOR = {
    ["te sentaste"] = "%s se sentó", ["huiste"] = "%s huyó", ["tuyo"] = "de %s",
    ["tuya"] = "de %s", ["ti"] = "%s", ["tú"] = "%s", ["contigo"] = "con %s",
    ["sacaste"] = "%s sacó", ["moriste"] = "%s murió", ["mataste"] = "%s mató",
    ["llegaste"] = "%s llegó", ["saliste"] = "%s salió", ["ganaste"] = "%s ganó",
    ["perdiste"] = "%s perdió", ["tu grupo"] = "el grupo de %s", ["tu bando"] = "el bando de %s",
    ["los dos"] = "%s y esa persona", ["te mató"] = "mató a %s",
    ["te vio morir"] = "vio morir a %s", ["te miró morir"] = "miró morir a %s",
    ["intentó salvarte"] = "intentó salvar a %s", ["te salvó"] = "salvó a %s",
}

-- The plain preposition per role. "de" and "a" contract with a name's own
-- article: "del Cruce", "al Cruce" (a name that begins "El ").
local function De(lead)
    return function(name)
        local rest = name:match("^El (.+)$")
        return rest and (lead .. "del " .. rest) or (lead .. "de " .. name)
    end
end
local function A(name)
    local rest = name:match("^El (.+)$")
    return rest and ("al " .. rest) or ("a " .. name)
end
G.PLACE = {
    ["in"] = "en %s", to = A, from = De(""), into = A,
    through = "por %s", near = De("cerca "), at = "en %s",
    around = De("alrededor "), round = De("alrededor "),
}
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client.

-- A creature's or item's name for more than one, and a killer's name in a
-- sentence: the client's names carry their own article and gender, which
-- cannot be known here, so they stay as they come (the sentences read a
-- bare name: "a manos de %s").
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- After "Ordenado por", lower case, accents included.
local DOWN = { ["Á"] = "á", ["É"] = "é", ["Í"] = "í", ["Ó"] = "ó", ["Ú"] = "ú", ["Ñ"] = "ñ" }
G.PeopleSortLabel = function(label)
    local first = label:match("^[\195][\128-\191]") or label:sub(1, 1)
    return (DOWN[first] or first:lower()) .. label:sub(#first + 1)
end

-- A first found card's heading, whole: "¡Tu primer objeto verde!".
local FIRST = {
    bag = { "primera bolsa", "primera bolsa" },
    shoulder = { "primer par de hombreras", "primer par de hombreras" },
    uncommon = { "primer objeto verde", "primer verde" },
    rare = { "primer objeto azul", "primer azul" },
    epic = { "primer objeto épico", "primer épico" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRST[kind]
        words[#words + 1] = f and f[short and 2 or 1] or "hallazgo"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " y " .. words[#words]
    end
    return "¡Tu " .. text .. "!"
end
