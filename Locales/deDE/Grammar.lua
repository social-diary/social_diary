-- German (deDE): the grammar the templates cannot carry. Decisions in
-- .claude/skills/translate/voices/deDE.md. First written by CarnVanBeck
-- (pr-4), brought up to the current framework.
local addonName, ns = ...
-- Offered on every client, by its own name (Settings, Language).
ns.Locale.Offer("deDE", "Deutsch")
if not ns.Locale.Is("deDE") then return end

local G = ns.Locale.grammar

-- CLDR: 1 is "one", everything else "other".
G.PluralForm = function(n) return n == 1 and 1 or 2 end
G.PLURAL_FORMS = 2

-- Letters outside ASCII, in UTF-8: ä ö ü (and é, â in names) are two bytes
-- with lead \195; the capital is 32 below the small letter. "ß" stays (no
-- capital the fonts carry), "÷" is no letter.
local function Up(text)
    return (text:upper():gsub("\195([\160-\190])", function(b)
        if b == "\183" or b == "\159" then return nil end
        return "\195" .. string.char(b:byte() - 32)
    end))
end
G.Upper = Up

-- The first letter up, umlauts too, past an opening „.
G.Capital = function(text)
    local lead, first, rest = text:match("^(\226\128\158?)([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return text end
    return lead .. Up(first) .. rest
end

-- "25." for the 25th, whatever it counts.
G.Ordinal = function(n) return n .. "." end

-- A date's day always takes its point: "6. Oktober", "25. Okt.".
G.Day = function(n) return n .. "." end

-- "18:30" stays the clock; the words round it say "Uhr" where prose wants it.
-- "2,5"
G.DECIMAL = ","

-- A number word that arrives as a value before a feminine noun, marked
-- "<f>" in the words ("%s<f> Stunde"): "ein" becomes "eine"; the mark goes
-- either way.
G.Agree = function(text)
    if not text:find("<f>", 1, true) then return text end
    return (text:gsub("([Ee]in)<f>", "%1e"):gsub("<f>", ""))
end

-- A creature is named bare, as the client gives it ("Ebenenschreiter hat
-- dich getötet"): the article's gender cannot be known.
G.NO_ARTICLE = true

-- A name's genitive: "Thrains", but "Thex’" after s, x, z, ß.
local function Genitive(name)
    if name:find("[sxzSXZ]$") or name:find("\195\159$") then return name .. "’" end
    return name .. "s"
end
G.Genitive = Genitive

-- The reader's words, each with its form for another character's name: a
-- word in braces is the reader's, or another of their characters' in a
-- shared diary (ns.UI.Format.You). The templates brace the pronoun with its
-- verb where the verb changes with it ("{Du hast}" -> "Thex hat").
G.YOU_FOR = {
    ["du"] = "%s", ["dich"] = "%s", ["dir"] = "%s",
    ["du hast"] = "%s hat", ["du bist"] = "%s ist", ["du warst"] = "%s war", ["du wirst"] = "%s wird",
    ["hast du"] = "hat %s", ["bist du"] = "ist %s", ["warst du"] = "war %s",
    -- "{ihr habt} beide Stufe 20 erreicht" -> "Thex und sie haben beide ..."
    ["ihr habt"] = "%s und sie haben",
    ["dein"] = Genitive, ["deine"] = Genitive, ["deinen"] = Genitive, ["deinem"] = Genitive,
    ["deiner"] = Genitive, ["deines"] = Genitive,
}

-- The plain preposition per role, before the name as the client gives it.
-- Names with an article ("Brachland": "im Brachland", "ins Brachland")
-- need ZONES, filled from a German client; until then they read bare.
G.PLACE = {
    ["in"] = "in %s", to = "nach %s", from = "aus %s", into = "nach %s",
    through = "durch %s", near = "bei %s", at = "bei %s",
    around = "rund um %s", round = "rund um %s",
}
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client.

-- A creature's or an item's name for more than one, and a killer's name
-- in a sentence: German plurals and articles can't be guessed from the
-- word, so the name stays as it is ("31 Ebenenschreiter").
G.Plural = function(name) return name end
G.ItemWord = function(n, item) return item end
G.KillerName = function(k) return k.name end

-- "Sortiert nach Zuletzt getroffen": German nouns keep their capital.
G.PeopleSortLabel = function(label) return label end

-- A first found card's heading, whole. German articles and endings go
-- with each noun: "Deine erste Tasche!", "Dein erster grüner Gegenstand!",
-- short, for a narrow margin, "Dein erstes Grünes!". Several firsts of one
-- item: "Deine erste Tasche und dein erster grüner Gegenstand!".
local FIRST = {
    bag = { "deine erste Tasche" },
    shoulder = { "deine ersten Schultern" },
    uncommon = { "dein erster grüner Gegenstand", "dein erstes Grünes" },
    rare = { "dein erster blauer Gegenstand", "dein erstes Blaues" },
    epic = { "dein erster epischer Gegenstand", "dein erstes Episches" },
}
G.FirstsHeading = function(list, short)
    local words = {}
    for i, kind in ipairs(list) do
        local forms = FIRST[kind] or { "dein erster Fund" }
        local full = not short and i == #list
        words[#words + 1] = full and forms[1] or forms[2] or forms[1]
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " und " .. words[#words]
    end
    return G.Capital(text) .. "!"
end
