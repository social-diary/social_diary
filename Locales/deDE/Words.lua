-- German (deDE): the text helpers (UI/Words/Format.lua), the numbers and
-- spoken times of UI/Journey/Text/Grammar.lua and Time.lua.
-- Voice: .claude/skills/translate/voices/deDE.md
--
-- A date's day arrives with its point (G.Day: "6."), so the date
-- templates add none: "6. Oktober", "6. Okt. 2026", "Montag, 6. Oktober".
local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

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
    ["%1$s %2$s %3$s##short date"] = "%1$s %2$s %3$s",
    ["%1$s %2$s##short date"] = "%1$s %2$s",

    -- times and counts
    ["%d min"] = "%d Min.",
    ["%d h"] = "%d Std.",
    ["%d h %d min"] = "%d Std. %d Min.",
    ["never"] = "nie",
    ["today"] = "heute",
    ["yesterday"] = "gestern",
    ["%d day ago|%d days ago##plural"] = "vor einem Tag|vor %d Tagen",
    ["%d week ago|%d weeks ago##plural"] = "vor einer Woche|vor %d Wochen",

    -- lists: "und noch 2" reads after "mit" as well as anywhere else
    ["%1$s and %2$d more|%1$s and %2$d more##plural"] = "%1$s und noch %2$d|%1$s und noch %2$d",
    ["%1$s and %2$d other|%1$s and %2$d others##plural"] = "%1$s und noch %2$d|%1$s und noch %2$d",
    ["%1$s and %2$s"] = "%1$s und %2$s",
    ["%1$s, and %2$s##list"] = "%1$s und %2$s",

    -- dates
    ["%1$s %2$s %3$s##date"] = "%1$s %2$s %3$s",
    ["%1$s %2$s##date"] = "%1$s %2$s",
    ["Today"] = "Heute",
    ["Yesterday"] = "Gestern",
    ["%1$s, %2$s##weekday date"] = "%1$s, %2$s",
    ["today at %s"] = "heute um %s",
    ["yesterday at %s"] = "gestern um %s",
    ["on %1$s at %2$s"] = "am %1$s um %2$s",

    -- who someone is
    ["Not seen nearby yet."] = "Noch nicht in der Nähe gesehen.",
    ["Last seen %1$s %2$s, %3$s##zone"] = "Zuletzt gesehen %1$s %2$s, %3$s",
    ["Last seen %1$s %2$s##zone"] = "Zuletzt gesehen %1$s %2$s",
    ["Last seen %s"] = "Zuletzt gesehen %s",

    -- a match counted in words, before "Partie": "deine dritte Partie"
    ["first##match"] = "erste",
    ["fourth##match"] = "vierte",
    ["second##match"] = "zweite",
    ["third##match"] = "dritte",
    ["eighth##match"] = "achte",
    ["fifth##match"] = "fünfte",
    ["ninth##match"] = "neunte",
    ["seventh##match"] = "siebte",
    ["sixth##match"] = "sechste",
    ["eleventh##match"] = "elfte",
    ["tenth##match"] = "zehnte",
    ["twelfth##match"] = "zwölfte",
    ["twice"] = "zweimal",
    ["once|%d times##plural"] = "einmal|%d-mal",

    -- fights
    ["You've killed them %s"] = "Du hast sie %s getötet",
    ["You and your group have killed them %s"] = "Du und deine Gruppe habt sie %s getötet",
    ["Your group has killed them %s"] = "Deine Gruppe hat sie %s getötet",
    ["%1$s and they've killed you %2$s."] = "%1$s, und sie haben dich %2$s getötet.",
    ["%1$s, they've killed you %2$s."] = "%1$s, sie dich %2$s.",
    ["%s."] = "%s.",
    ["They've killed you %s."] = "Sie haben dich %s getötet.",

    -- money, race, level, faction
    ["%dg"] = "%dg",
    ["%ds"] = "%ds",
    ["%dc"] = "%dk",
    ["Night Elf"] = "Nachtelf",
    ["Undead"] = "Untoter",
    ["Level %d"] = "Stufe %d",
    ["Alliance"] = "Allianz",
    ["Horde"] = "Horde",

    -- shared joins and figures
    ["%1$s, %2$s"] = "%1$s, %2$s",
    ["%d%% health"] = "%d %% Gesundheit",

    -- UI/Journey/Text/Grammar.lua and Time.lua: the ledger's times, numbers in words, spoken times
    ["%d h %02d"] = "%d:%02d Std.",
    ["a##one"] = "ein", ["one"] = "ein", ["two"] = "zwei", ["three"] = "drei", ["four"] = "vier",
    ["five"] = "fünf", ["six"] = "sechs", ["seven"] = "sieben", ["eight"] = "acht", ["nine"] = "neun",
    ["ten"] = "zehn", ["eleven"] = "elf", ["twelve"] = "zwölf", ["fifteen"] = "fünfzehn",
    ["twenty"] = "zwanzig", ["twenty-five"] = "fünfundzwanzig", ["forty"] = "vierzig",
    ["forty-five"] = "fünfundvierzig", ["fifty"] = "fünfzig", ["fifty-five"] = "fünfundfünfzig",
    ["a moment"] = "einen Augenblick",
    ["a few minutes"] = "ein paar Minuten",
    ["half an hour"] = "eine halbe Stunde",
    ["an hour"] = "eine Stunde",
    ["an hour and a half"] = "anderthalb Stunden",
    ["%1$s, at level %2$d"] = "%1$s, auf Stufe %2$d",
    ["Afternoon"] = "Nachmittag",
    ["Evening"] = "Abend",
    ["Morning"] = "Morgen",
    ["Night"] = "Nacht",
    ["Noon"] = "Mittag",
})
