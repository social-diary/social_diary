-- German (deDE): the grammar every area shares (Locales/Locale.lua) and the
-- words of UI/Words/Format.lua, UI/Journey/Text/Grammar.lua and Time.lua:
-- counts, times, dates, lists.
--
-- The voice: the diary speaks to the player as "du" (lower case, as in a
-- letter today), quiet, past tense for what happened (Präteritum in prose,
-- Perfekt where a ledger line reads more naturally). Other players are
-- "sie" (plural) or by name.

local addonName, ns = ...

if not ns.Locale.Is("deDE") then return end

local G = ns.Locale.grammar

-- A creature's or an item's name for more than one: the client gives it in
-- German, and German plurals can't be guessed from the word, so the name
-- stays as it is ("31 Ebenenschreiter", "7 Ebenenschreiterfleisch"). The
-- templates count with it, never decline it.
function G.Plural(name) return name end
function G.ItemWord(n, item) return item end

-- A killer's name in a sentence: German articles follow a gender the
-- client doesn't give, so the name goes bare; the templates are written so
-- a bare name reads ("getötet von: Ebenenschreiter" is never needed:
-- "Ebenenschreiter hat dich getötet").
function G.KillerName(k) return k.name end

-- "25." for the 25th.
function G.Ordinal(n) return n .. "." end

-- The first letter capitalised, umlauts too (string.upper leaves UTF-8 alone).
local UPPER = { ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü" }
function G.Capital(text)
    local two = text:sub(1, 2)
    if UPPER[two] then return UPPER[two] .. text:sub(3) end
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- A name's genitive: "Thrains", but "Thex'" after s, x, z, ß.
local function Genitive(name)
    if name:find("[sxzß]$") or name:find("\195\159$") then return name .. "'" end
    return name .. "s"
end
G.Genitive = Genitive

-- The "you" of a shared diary (ns.UI.Format.You): a word in braces is the
-- reader's, or another of their characters' when the diary is shared. The
-- German templates brace the pronoun with its verb where the verb changes
-- with it ("{Du hast}" → "Thex hat").
G.YOU_FOR = {
    ["du"] = "%s", ["dich"] = "%s", ["dir"] = "%s",
    ["du hast"] = "%s hat", ["du bist"] = "%s ist", ["du warst"] = "%s war", ["du wirst"] = "%s wird",
    ["hast du"] = "hat %s", ["bist du"] = "ist %s", ["warst du"] = "war %s",
    ["dein"] = Genitive, ["deine"] = Genitive, ["deinen"] = Genitive, ["deinem"] = Genitive,
    ["deiner"] = Genitive, ["deines"] = Genitive,
}

ns.Locale.Add("deDE", {
    -- UI/Words/Format.lua: the calendar
    ["January"] = "Januar", ["February"] = "Februar", ["March"] = "März", ["April"] = "April",
    ["May"] = "Mai", ["June"] = "Juni", ["July"] = "Juli", ["August"] = "August",
    ["September"] = "September", ["October"] = "Oktober", ["November"] = "November",
    ["December"] = "Dezember",
    ["Jan"] = "Jan.", ["Feb"] = "Feb.", ["Mar"] = "März", ["Apr"] = "Apr.", ["May##short"] = "Mai",
    ["Jun"] = "Juni", ["Jul"] = "Juli", ["Aug"] = "Aug.", ["Sep"] = "Sept.", ["Oct"] = "Okt.",
    ["Nov"] = "Nov.", ["Dec"] = "Dez.",
    ["Sunday"] = "Sonntag", ["Monday"] = "Montag", ["Tuesday"] = "Dienstag", ["Wednesday"] = "Mittwoch",
    ["Thursday"] = "Donnerstag", ["Friday"] = "Freitag", ["Saturday"] = "Samstag",
    ["%1$d %2$s %3$s"] = "%1$d. %2$s %3$s",
    ["%1$d %2$s"] = "%1$d. %2$s",

    -- times and counts
    ["%d min"] = "%d Min.",
    ["%d h"] = "%d Std.",
    ["%d h %d min"] = "%d Std. %d Min.",
    ["%d h %02d"] = "%d:%02d Std.",
    ["never"] = "nie",
    ["today"] = "heute",
    ["yesterday"] = "gestern",
    ["%d days ago"] = "vor %d Tagen",
    ["%d weeks ago"] = "vor %d Wochen",
    ["Today"] = "Heute",
    ["Yesterday"] = "Gestern",
    ["today at %s"] = "heute um %s",
    ["yesterday at %s"] = "gestern um %s",
    ["on %1$s at %2$s"] = "am %1$s um %2$s",
    ["once"] = "einmal",
    ["twice"] = "zweimal",
    ["%d times"] = "%d-mal",
    ["%d%% health"] = "%d %% Gesundheit",

    -- lists
    ["%1$s and %2$d %3$s"] = "%1$s und %2$d %3$s",
    [", "] = ", ",
    ["more"] = "weitere",
    [" and "] = " und ",
    [", and "] = " und ",
    ["%1$s, %2$s"] = "%1$s, %2$s",
    ["%1$s %2$s"] = "%1$s %2$s",
    ["%s."] = "%s.",

    -- who someone is
    ["Not seen nearby yet."] = "Noch nicht in der Nähe gesehen.",
    ["Last seen %1$s in %2$s"] = "Zuletzt gesehen %1$s in %2$s",
    ["Last seen %s"] = "Zuletzt gesehen %s",
    ["Level %d"] = "Stufe %d",
    ["Night Elf"] = "Nachtelf",
    ["Undead"] = "Untoter",
    ["Alliance"] = "Allianz",
    ["Horde"] = "Horde",
    ["%dg"] = "%dg",
    ["%ds"] = "%ds",
    ["%dc"] = "%dk",

    -- fights
    ["You've killed them %s"] = "Du hast sie %s getötet",
    ["Your group has killed them %s"] = "Deine Gruppe hat sie %s getötet",
    ["You and your group have killed them %s"] = "Du und deine Gruppe habt sie %s getötet",
    ["%1$s and they've killed you %2$s."] = "%1$s, und sie haben dich %2$s getötet.",
    ["%1$s, they've killed you %2$s."] = "%1$s, sie dich %2$s.",
    ["They've killed you %s."] = "Sie haben dich %s getötet.",

    -- UI/Journey/Text/Grammar.lua and Time.lua: numbers in words
    ["a##one"] = "ein", ["one"] = "ein", ["two"] = "zwei", ["three"] = "drei", ["four"] = "vier",
    ["five"] = "fünf", ["six"] = "sechs", ["seven"] = "sieben", ["eight"] = "acht", ["nine"] = "neun",
    ["ten"] = "zehn", ["eleven"] = "elf", ["twelve"] = "zwölf", ["fifteen"] = "fünfzehn",
    ["twenty"] = "zwanzig", ["twenty-five"] = "fünfundzwanzig", ["forty"] = "vierzig",
    ["forty-five"] = "fünfundvierzig", ["fifty"] = "fünfzig", ["fifty-five"] = "fünfundfünfzig",

    -- spoken times
    ["a moment"] = "einen Augenblick",
    ["a few minutes"] = "ein paar Minuten",
    ["%s minutes"] = "%s Minuten",
    ["half an hour"] = "eine halbe Stunde",
    ["an hour"] = "eine Stunde",
    ["an hour and a half"] = "anderthalb Stunden",
    ["%s and a half hours"] = "%sundeinhalb Stunden",
    ["%s hours"] = "%s Stunden",
    ["%1$s, at level %2$d"] = "%1$s, auf Stufe %2$d",
    ["Morning"] = "Morgen",
    ["Noon"] = "Mittag",
    ["Afternoon"] = "Nachmittag",
    ["Evening"] = "Abend",
    ["Night"] = "Nacht",
})
