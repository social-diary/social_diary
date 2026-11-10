-- French (France): the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/frFR.md.
local addonName, ns = ...
if not ns.Locale.Is("frFR") then return end

local G = ns.Locale.grammar

-- CLDR: 0 and 1 are "one", the rest "other" (the "many" of whole millions
-- is never reached by a count in the diary). So the first form of a
-- "##plural" value always shows the count: "%d combat|%d combats".
G.PluralForm = function(n) return n < 2 and 1 or 2 end
G.PLURAL_FORMS = 2

-- Letters outside ASCII, in UTF-8 (two bytes: lead \195, or \197 for œ).
local UP = {
    ["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["ç"] = "Ç", ["é"] = "É", ["è"] = "È",
    ["ê"] = "Ê", ["ë"] = "Ë", ["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ö"] = "Ö",
    ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü", ["ÿ"] = "Ÿ", ["œ"] = "Œ",
}
local function Up(text)
    return (text:upper():gsub("[\195\197][\128-\191]", function(c)
        return UP[c] or c
    end))
end
G.Upper = Up

-- The first letter up, past an opening « and its no-break space.
G.Capital = function(text)
    local lead, first, rest = text:match("^(«?\194?\160?)([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return text end
    return lead .. Up(first) .. rest
end

-- "25e", "1er" (a feminine noun's "1re" cannot be told: see the report).
G.Ordinal = function(n) return n == 1 and "1er" or (n .. "e") end

-- Whether a name starts with a vowel sound, so "de" elides: "d’Ana".
-- (A mute h is left out on purpose: names such as "Hana" keep "de".)
local function Vowel(name)
    local c = name:sub(1, 1)
    if c:find("^[AEIOUYaeiouy]") then return true end
    return name:find("^\195[\128-\134\136-\143\146-\150\153-\156\160-\166\168-\175\178-\182\185-\188]") ~= nil
end
local function De(name)
    return (Vowel(name) and "d’" or "de ") .. name
end

-- A name in the genitive: "l’histoire de Brom", "l’histoire d’Ana".
G.Genitive = De

-- The reader's words, each with its form for another character's name.
-- Filled after the translation (every braced word in Locales/frFR/).
G.YOU_FOR = {
    -- The reader as the subject: "%s a tué".
    ["tu as péri"] = "%s a péri", ["tu y as péri"] = "%s y a péri",
    ["tu as succombé"] = "%s a succombé", ["tu as probablement succombé"] = "%s a probablement succombé",
    ["tu as tué"] = "%s a tué", ["tu as atteint"] = "%s a atteint",
    ["tu as chuchoté"] = "%s a chuchoté", ["tu as partagé"] = "%s a partagé",
    ["tu as fui"] = "%s a fui", ["tu as fait"] = "%s a fait", ["tu as gagné"] = "%s a gagné",
    ["tu as perdu"] = "%s a perdu", ["tu as abandonné"] = "%s a abandonné",
    ["vous avez tous les deux atteint"] = "%s et cette personne ont tous deux atteint",
    ["toi et"] = "%s et", ["avez"] = "ont",
    -- The reader as the object: "%s a tué %s" (the name follows the verb).
    ["t’a tué"] = "a tué %s", ["t’a probablement tué"] = "a probablement tué %s",
    ["t’a regardé mourir"] = "a regardé mourir %s", ["t’a vu mourir"] = "a vu mourir %s",
    ["a essayé de te sauver"] = "a essayé de sauver %s", ["t’a sauvé"] = "a sauvé %s",
    -- The reader after a preposition, or as a possessor.
    ["toi"] = "%s", ["ton"] = "le",
    ["ton groupe"] = function(name) return "le groupe " .. De(name) end,
    ["à tes côtés"] = function(name) return "aux côtés " .. De(name) end,
}

-- The plain preposition per role. The client's name arrives bare, with no
-- article ("à Forêt d’Elwynn" should be "dans la forêt d’Elwynn") and no
-- elision ("près de Orgrimmar"): see the report.
G.PLACE = {
    ["in"] = "à %s", to = "vers %s", from = "depuis %s", into = "à %s",
    through = "par %s", near = "près de %s", at = "à %s",
    around = "autour de %s", round = "autour de %s",
}
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client.

-- A creature's or item's name for more than one, and a killer's name in a
-- sentence: the client's names carry their own article and gender, which
-- cannot be known here, so they stay as they come (the sentences read a
-- bare name: "tué par %s").
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- After "Trié par", lower case, accents included.
local DOWN = { ["É"] = "é", ["È"] = "è", ["À"] = "à", ["Ê"] = "ê", ["Ô"] = "ô", ["Î"] = "î" }
G.PeopleSortLabel = function(label)
    local first = label:match("^[\195][\128-\191]") or label:sub(1, 1)
    return (DOWN[first] or first:lower()) .. label:sub(#first + 1)
end

-- A first found card's heading, whole: "Ton premier objet vert !".
-- Genders differ (un sac, une paire, un objet), so each kind carries its own
-- noun phrase and the article "ton"/"ta" with it.
local FIRST = {
    bag = { "ton premier sac", "ton premier sac" },
    shoulder = { "ta première paire d’épaulières", "ta première paire d’épaulières" },
    uncommon = { "ton premier objet vert", "ton premier vert" },
    rare = { "ton premier objet bleu", "ton premier bleu" },
    epic = { "ton premier objet épique", "ton premier épique" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for _, kind in ipairs(list) do
        local f = FIRST[kind]
        words[#words + 1] = f and f[short and 2 or 1] or "ta première trouvaille"
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " et " .. words[#words]
    end
    return text:sub(1, 1):upper() .. text:sub(2) .. "\194\160!"
end
