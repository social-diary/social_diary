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
-- The gender is the article's: "Das" neuter, "Der" masculine, "Die"
-- plural, or feminine where the noun's ending says so (FEMININE). A name
-- without one takes an article only where its last word ends in a
-- landscape noun whose gender is known (BARE: "Rotkammgebirge" -> "im
-- Rotkammgebirge", "Brennende Steppe" -> "in der Brennenden Steppe");
-- cities and proper names ("Orgrimmar", "Mulgore") stay bare.
-- After the article an adjective takes -n in the dative ("im
-- Scharlachroten Kloster") and in the masculine accusative, and a plural
-- noun takes -n in the dative ("in den Sümpfen des Elends").
-- A name the rules get wrong goes into ZONES / DUNGEONS / SUBZONES, which
-- win over all of this, or into GENDER ("n", "m", "f", "p") by its name.

-- The forms per role and gender: the article (or its contraction), and
-- the case the words after it take ("dat" or "acc"). `bare` is the
-- preposition before a name with no article.
local ROLES = {
    ["in"]  = { bare = "in",       n = "im",           m = "im",           f = "in der",       p = "in den",       case = "dat" },
    to      = { bare = "nach",     n = "in das",       m = "in den",       f = "in die",       p = "in die",       case = "acc" },
    into    = { bare = "in",       n = "in das",       m = "in den",       f = "in die",       p = "in die",       case = "acc" },
    from    = { bare = "aus",      n = "aus dem",      m = "aus dem",      f = "aus der",      p = "aus den",      case = "dat" },
    through = { bare = "durch",    n = "durch das",    m = "durch den",    f = "durch die",    p = "durch die",    case = "acc" },
    near    = { bare = "bei",      n = "beim",         m = "beim",         f = "bei der",      p = "bei den",      case = "dat" },
    around  = { bare = "rund um",  n = "rund um das",  m = "rund um den",  f = "rund um die",  p = "rund um die",  case = "acc" },
}
ROLES.at, ROLES.round = ROLES.near, ROLES.around

-- A name's own gender, where the rules below guess wrong: GENDER["Name"].
local GENDER = {}
G.GENDER = GENDER

-- Nouns after "Die" that are feminine singular, not plural, by ending.
local FEMININE = {
    "bahn", "schlucht", "steppe", "insel", "burg", "feste", "festung", "zitadelle",
    "höhle", "grotte", "bucht", "küste", "ebene", "oase", "mine", "halle", "wacht",
    "klamm", "senke", "spitze", "tiefe", "marsch", "kammer", "arena", "enklave",
    "kluft", "quelle", "lichtung", "heide", "wüste", "straße", "ruine", "kapelle",
    "kathedrale", "akademie", "stätte", "zuflucht", "anhöhe", "mühle", "farm", "hütte",
    "schmiede", "brücke", "grube", "werft", "taverne", "hölle", "allee", "wiese",
}

-- The last word of a name with no article, for the landscape nouns whose
-- gender is sure: compounds take their last part's ("Rotkammgebirge").
local BARE = {
    { "vorgebirge", "n" }, { "gebirge", "n" }, { "hochland", "n" }, { "land", "n" },
    { "tal", "n" }, { "moor", "n" }, { "kloster", "n" }, { "verlies", "n" },
    { "wald", "m" }, { "sumpf", "m" }, { "krater", "m" }, { "abgrund", "m" },
    { "schlund", "m" }, { "bruch", "m" },
    { "steppe", "f" }, { "schlucht", "f" }, { "küste", "f" }, { "lichtung", "f" },
    { "ebene", "f" }, { "wüste", "f" }, { "spitze", "f" },
    { "marschen", "p" }, { "tiefen", "p" }, { "höhlen", "p" }, { "berge", "p" },
}

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

-- The name's gender and the name without its article, or nil (bare).
local function Article(name)
    local article, rest = name:match("^([Dd][aei][rse]) (.+)$")
    local own = GENDER[name]
    if article then
        article = article:lower()
        if article ~= "das" and article ~= "der" and article ~= "die" then article = nil end
    end
    if article then
        if own then return own, rest end
        if article == "das" then return "n", rest end
        if article == "der" then return "m", rest end
        local noun = LastWord(Split(rest)):lower()
        for _, ending in ipairs(FEMININE) do
            if Ends(noun, ending) then return "f", rest end
        end
        return "p", rest
    end
    if own then return own, name end
    local noun = LastWord(Split(name)):lower()
    for _, entry in ipairs(BARE) do
        if Ends(noun, entry[1]) then return entry[2], name end
    end
    return nil, name
end

local function Place(role)
    local forms = ROLES[role]
    return function(name)
        local gender, rest = Article(name)
        if not gender then return forms.bare .. " " .. name end
        local head, tail = Split(rest)
        return forms[gender] .. " " .. Decline(head, gender, forms.case) .. tail
    end
end

G.PLACE = {}
for role in pairs(ROLES) do G.PLACE[role] = Place(role) end

-- Every name of a list takes its own preposition and article: "im
-- Brachland und in Durotar".
G.EACH_PLACE = true
-- ZONES, DUNGEONS, SUBZONES stay empty: names come from the game client,
-- and the rules above read their articles.

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
