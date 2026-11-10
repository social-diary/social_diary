-- Spanish (Spain): the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/esES.md.
local addonName, ns = ...
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

-- "25.º"
G.Ordinal = function(n) return n .. ".º" end

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

-- The plain preposition per role. The client's name arrives bare, with no
-- article ("de El Cruce" should be "del Cruce"): see the report.
G.PLACE = {
    ["in"] = "en %s", to = "a %s", from = "de %s", into = "a %s",
    through = "por %s", near = "cerca de %s", at = "en %s",
    around = "alrededor de %s", round = "alrededor de %s",
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
