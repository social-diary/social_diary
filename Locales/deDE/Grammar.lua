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
-- (The „ is three bytes: a "?" after them would make only the last one
-- optional, so it is taken off first.)
local QUOTE = "\226\128\158"
G.Capital = function(text)
    local lead = text:sub(1, #QUOTE) == QUOTE and QUOTE or ""
    local first, rest = text:sub(#lead + 1):match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
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

--------------------------------------------------------------------------
-- A place after its preposition. The client gives the name in the
-- nominative, with its article where it has one ("Das Brachland", "Die
-- Sümpfe des Elends", "Der Wald von Elwynn"), or bare ("Durotar",
-- "Stormwind", "Rotkammgebirge"). The preposition takes the article's
-- case, and contracts with it:
--
--   in       im Brachland, in der Brennenden Steppe, in den Todesminen, in Durotar
--   to       in das Brachland, in den Wald von Elwynn, nach Stormwind
--   into     in das Brachland, in Stormwind ("Zum ersten Mal in Stormwind")
--   from     aus dem Brachland, aus Durotar
--   through  durch das Brachland, durch Durotar
--   near/at  beim Wegekreuz, bei Orgrimmar
--   around   rund um das Brachland, rund um Durotar
--
-- After the article an adjective takes -n in the dative ("im
-- Scharlachroten Kloster") and in the masculine accusative, and a plural
-- noun takes -n in the dative ("in den Sümpfen des Elends").
--
-- What a place is, is said in one way, in two tables:
--
--   NAMES     by the whole name, as the client gives it ("Wasserbrunnen",
--             "Die Tiefenbahn"); wins over ENDINGS
--   ENDINGS   by how the last word of the noun ends ("gebirge" for
--             "Rotkammgebirge"), for every name that ends so
--
-- Each value is the gender, and "an" after it for a place one is at, not
-- in (a well, a lake, a tower: "am Wasserbrunnen", "zum Wasserbrunnen"):
--
--   "n" das   "m" der   "f" die (one)   "p" die (more than one)
--   "-" no article: the name stays bare ("in Eisenschmiede")
--   "m an", "f an", ...
--
-- The article the client gives decides the gender over the tables ("Das",
-- "Der"); after "Die" a table's "f" makes it feminine, anything else is
-- plural. A name with no article and no entry stays bare, as cities and
-- proper names do ("in Orgrimmar", "nach Mulgore").
-- A phrase no rule here can make goes whole into ZONES / DUNGEONS /
-- SUBZONES, which win over all of this.

local NAMES = {
    -- ["Die Tiefenbahn"] = "f",
    -- ["Eisenschmiede"]  = "-",
}

local ENDINGS = {
    -- Every key in ["..."]: WoW's Lua takes no ä, ö, ü or ß in a bare name.
    -- The places one is at, not in ("n an", "m an"), stand first in
    -- their gender's lines.
    -- neuter: das
    ["kreuz"] = "n an",
    ["gebirge"] = "n", ["land"] = "n", ["tal"] = "n", ["moor"] = "n", ["kloster"] = "n", ["verlies"] = "n",
    -- masculine: der
    ["brunnen"] = "m an",
    ["wald"] = "m", ["sumpf"] = "m", ["krater"] = "m", ["abgrund"] = "m", ["schlund"] = "m", ["bruch"] = "m",
    -- feminine: die (one)
    ["kuppe"] = "f an",
    ["steppe"] = "f", ["schlucht"] = "f", ["küste"] = "f", ["lichtung"] = "f", ["ebene"] = "f", ["wüste"] = "f",
    ["spitze"] = "f", ["bahn"] = "f", ["insel"] = "f", ["burg"] = "f", ["feste"] = "f", ["festung"] = "f",
    ["zitadelle"] = "f", ["höhle"] = "f", ["grotte"] = "f", ["oase"] = "f", ["mine"] = "f", ["halle"] = "f",
    ["wacht"] = "f", ["klamm"] = "f", ["senke"] = "f", ["tiefe"] = "f", ["marsch"] = "f", ["kammer"] = "f",
    ["arena"] = "f", ["enklave"] = "f", ["kluft"] = "f", ["quelle"] = "f", ["heide"] = "f", ["straße"] = "f",
    ["ruine"] = "f", ["kapelle"] = "f", ["kathedrale"] = "f", ["akademie"] = "f", ["stätte"] = "f",
    ["zuflucht"] = "f", ["anhöhe"] = "f", ["mühle"] = "f", ["farm"] = "f", ["hütte"] = "f", ["brücke"] = "f",
    ["grube"] = "f", ["werft"] = "f", ["taverne"] = "f", ["hölle"] = "f", ["allee"] = "f", ["wiese"] = "f",
    -- plural: die (more than one)
    ["marschen"] = "p", ["tiefen"] = "p", ["höhlen"] = "p", ["berge"] = "p",
}
G.NAMES, G.ENDINGS = NAMES, ENDINGS

-- The preposition per role, gender and kind ("in" or "an"), and the case
-- the words after it take. `bare` is the one before a name with no article.
local PREPOSITIONS = {
    ["in"] = {
        ["in"]  = { case = "dat", bare = "in",      n = "im",          m = "im",          f = "in der",      p = "in den" },
        to      = { case = "acc", bare = "nach",    n = "in das",      m = "in den",      f = "in die",      p = "in die" },
        into    = { case = "acc", bare = "in",      n = "in das",      m = "in den",      f = "in die",      p = "in die" },
        from    = { case = "dat", bare = "aus",     n = "aus dem",     m = "aus dem",     f = "aus der",     p = "aus den" },
        through = { case = "acc", bare = "durch",   n = "durch das",   m = "durch den",   f = "durch die",   p = "durch die" },
        near    = { case = "dat", bare = "bei",     n = "beim",        m = "beim",        f = "bei der",     p = "bei den" },
        around  = { case = "acc", bare = "rund um", n = "rund um das", m = "rund um den", f = "rund um die", p = "rund um die" },
    },
    an = {
        ["in"]  = { case = "dat", n = "am",          m = "am",          f = "an der",      p = "an den" },
        to      = { case = "dat", n = "zum",         m = "zum",         f = "zur",         p = "zu den" },
        into    = { case = "dat", n = "zum",         m = "zum",         f = "zur",         p = "zu den" },
        from    = { case = "dat", n = "vom",         m = "vom",         f = "von der",     p = "von den" },
        through = { case = "acc", n = "über das",    m = "über den",    f = "über die",    p = "über die" },
        near    = { case = "dat", n = "am",          m = "am",          f = "an der",      p = "an den" },
        around  = { case = "acc", n = "rund um das", m = "rund um den", f = "rund um die", p = "rund um die" },
    },
}
for _, kind in pairs(PREPOSITIONS) do kind.at, kind.round = kind.near, kind.around end

local function Ends(word, ending)
    return #word >= #ending and word:sub(-#ending) == ending
end

-- The head noun's words: the name up to its genitive or "von" ("Sümpfe"
-- in "Sümpfe des Elends"), and what follows, kept as it is.
local function Split(rest)
    local head, tail = rest:match("^(.-)( [dv][eo][rsn]? .*)$")
    if not head or head == "" then return rest, "" end
    return head, tail
end

local function LastWord(text)
    return text:match("([^%s]+)$") or text
end

-- Adjectives before the noun ("Scharlachrote") take -n; the plural noun
-- in the dative too, unless it ends in n or s already.
local function Decline(head, gender, case)
    local words = {}
    for word in head:gmatch("[^%s]+") do words[#words + 1] = word end
    local weak = case == "dat" or (gender == "m" and case == "acc")
    for i = 1, #words - 1 do
        if weak and Ends(words[i], "e") then words[i] = words[i] .. "n" end
    end
    local noun = words[#words]
    if noun and gender == "p" and case == "dat" and not noun:find("[nsNS]$") then
        words[#words] = noun .. "n"
    end
    return table.concat(words, " ")
end

-- A table's value: its gender and kind ("m an" -> "m", "an").
local function Entry(value)
    if not value then return nil, "in" end
    local gender, kind = value:match("^([nmfp%-])%s*(%a*)$")
    return gender, kind == "an" and "an" or "in"
end

-- The longest ending that fits the noun: "hochland" before "land".
local function ByEnding(noun)
    local best
    for ending, value in pairs(ENDINGS) do
        if Ends(noun, ending) and (not best or #ending > #best) then best = ending end
    end
    return best and ENDINGS[best]
end

-- The name's gender ("-" or nil: bare), its kind, and the name without
-- its article.
local function Article(name)
    local article, rest = name:match("^([Dd][aei][rse]) (.+)$")
    article = article and article:lower()
    if article ~= "das" and article ~= "der" and article ~= "die" then article, rest = nil, name end
    local gender, kind = Entry(NAMES[name] or ByEnding(LastWord(Split(rest)):lower()))
    if article == "das" then return "n", kind, rest end
    if article == "der" then return "m", kind, rest end
    if article == "die" then return gender == "f" and "f" or "p", kind, rest end
    return gender, kind, rest
end

local function Place(role)
    return function(name)
        local gender, kind, rest = Article(name)
        if not gender or gender == "-" then
            return PREPOSITIONS["in"][role].bare .. " " .. rest
        end
        local forms = PREPOSITIONS[kind][role]
        local head, tail = Split(rest)
        return forms[gender] .. " " .. Decline(head, gender, forms.case) .. tail
    end
end

G.PLACE = {}
for role in pairs(PREPOSITIONS["in"]) do G.PLACE[role] = Place(role) end

-- Every name of a list takes its own preposition and article: "im
-- Brachland und in Durotar".
G.EACH_PLACE = true
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client,
-- and the tables above read their articles.

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
