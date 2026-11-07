-- German (deDE): Features2. Keys are the English text (Locales/enUS.lua).
-- Duels, firsts found, quest chain finales, campfires, chat, profession
-- caps, trades, world PvP, someone you met, level-ups.

local addonName, ns = ...

ns.Locale.Add("deDE", {
    -- Features/Duels/Kind.lua: the timeline's line, the card form
    [" in %s"] = " in %s",
    ["them##against"] = "sie",
    ["them##with"] = "ihnen",
    ["Won a duel against %1$s%2$s"] = "Gewann ein Duell gegen %1$s%2$s",
    ["Won a duel when they fled%s"] = "Gewann ein Duell, als sie flohen%s",
    ["Won a duel when %1$s fled%2$s"] = "Gewann ein Duell, als %1$s floh%2$s",
    ["Fled a duel with %1$s%2$s"] = "Floh aus einem Duell mit %1$s%2$s",
    ["Lost a duel to %1$s%2$s"] = "Verlor ein Duell gegen %1$s%2$s",
    ["Won %1$d duels against %2$s and lost %3$d"] = "Gewann %1$d Duelle gegen %2$s und verlor %3$d",
    ["Won %1$d duels against %2$s"] = "Gewann %1$d Duelle gegen %2$s",
    ["Lost %1$d duels to %2$s and won %3$d"] = "Verlor %1$d Duelle gegen %2$s und gewann %3$d",
    ["Lost %1$d duels to %2$s"] = "Verlor %1$d Duelle gegen %2$s",
    ["{you} fled %s"] = "{du bist} %s geflohen",
    ["they fled %s"] = "sie sind %s geflohen",
    ["you duelled them"] = "ihr habt euch duelliert",
    ["Duel"] = "Duell",
    ["A duel"] = "Ein Duell",
    ["Opponent"] = "Gegner",
    ["who it was, or leave this empty"] = "wer es war, oder leer lassen",
    ["Duels won"] = "Duelle gewonnen",
    ["Duels lost"] = "Duelle verloren",
    ["They fled"] = "Sie sind geflohen",
    ["You fled"] = "Du bist geflohen",

    -- Features/Duels/Text.lua: the margin note, the tooltip, the caption
    ["duelled %s"] = "Duell mit %s",
    ["a duel"] = "ein Duell",
    ["beat %s in a duel"] = "%s im Duell besiegt",
    ["won a duel"] = "ein Duell gewonnen",
    ["%s fled the duel"] = "%s floh aus dem Duell",
    ["they fled the duel"] = "sie flohen aus dem Duell",
    ["fled a duel with %s"] = "aus dem Duell mit %s geflohen",
    ["fled a duel"] = "aus einem Duell geflohen",
    ["lost a duel to %s"] = "ein Duell gegen %s verloren",
    ["lost a duel"] = "ein Duell verloren",
    ["%1$d each with %2$s"] = "gleichauf mit %2$s, je %1$d",
    ["%d duels each"] = "je %d Siege",
    ["beat %1$s %2$s"] = "%1$s %2$s besiegt",
    ["won %d duels"] = "%d Duelle gewonnen",
    ["lost to %1$s %2$s"] = "%2$s gegen %1$s verloren",
    ["lost %d duels"] = "%d Duelle verloren",
    ["beat %1$s %2$d to %3$d"] = "%1$s %2$d zu %3$d besiegt",
    ["won %1$d duels to %2$d"] = "Duelle %1$d zu %2$d gewonnen",
    ["lost to %1$s %2$d to %3$d"] = "%2$d zu %3$d gegen %1$s verloren",
    ["lost %1$d duels to %2$d"] = "Duelle %1$d zu %2$d verloren",
    ["You won"] = "Du hast gewonnen",
    ["You lost"] = "Du hast verloren",
    ["Won %1$d, lost %2$d"] = "%1$d gewonnen, %2$d verloren",
    ["Lost %1$d, won %2$d"] = "%1$d verloren, %2$d gewonnen",
    ["Won both"] = "Beide gewonnen",
    ["Lost both"] = "Beide verloren",
    ["Won all %d"] = "Alle %d gewonnen",
    ["Lost all %d"] = "Alle %d verloren",
    ["you fled %s"] = "du bist %s geflohen",
    ["In %s"] = "In %s",
    ["Duelled %s"] = "Duell mit %s",
    ["%d duels"] = "%d Duelle",
    ["a duel won"] = "ein gewonnenes Duell",
    ["a duel lost"] = "ein verlorenes Duell",
    ["%s duels won"] = "%s gewonnene Duelle",
    ["%s duels lost"] = "%s verlorene Duelle",
    ["duels won and lost"] = "gewonnene und verlorene Duelle",
    ["duels mostly won"] = "meist gewonnene Duelle",
    ["duels mostly lost"] = "meist verlorene Duelle",
    ["%1$s in %2$s"] = "%1$s in %2$s",

    -- Features/Firsts/Kind.lua: the card form
    ["First Found"] = "Erster Fund",
    ["A first found"] = "Ein erster Fund",
    ["First"] = "Erstes",
    ["Green"] = "Grün",
    ["Blue"] = "Blau",
    ["Purple"] = "Lila",
    ["Bag"] = "Tasche",
    ["Shoulders"] = "Schultern",

    -- Features/Firsts/Text.lua: a first on a plate and in a sentence
    ["a first bag"] = "eine erste Tasche",
    ["first shoulders"] = "erste Schultern",
    ["a first green"] = "ein erstes Grünes",
    ["a first blue"] = "ein erstes Blaues",
    ["a first epic"] = "ein erstes Episches",
    ["a first find"] = "ein erster Fund",
    ["your first bag"] = "deine erste Tasche",
    ["your first shoulders"] = "deine ersten Schultern",
    ["your first green"] = "dein erstes Grünes",
    ["your first blue"] = "dein erstes Blaues",
    ["your first epic"] = "dein erstes Episches",
    ["your first find"] = "dein erster Fund",
    ["from %s"] = "von %s",
    ["a gift"] = "ein Geschenk",
    ["%1$s gave you %2$s"] = "%1$s gab dir %2$s",
    ["%s was a gift"] = "bekam %s geschenkt",
    ["A quest gave you %s"] = "Eine Quest gab dir %s",
    ["Bought %1$s in %2$s"] = "Kaufte %1$s in %2$s",
    ["Bought %s"] = "Kaufte %s",
    ["Made %1$s in %2$s"] = "Stellte %1$s in %2$s her",
    ["Made %s"] = "Stellte %s her",
    ["%s came by mail"] = "bekam %s per Post",
    ["Found %1$s in %2$s"] = "Fand %1$s in %2$s",
    ["Found %s"] = "Fand %s",
    ["%1$s: %2$s."] = "%1$s: %2$s.",
    ["a quest's reward"] = "Questbelohnung",
    ["bought"] = "gekauft",
    ["made by hand"] = "selbst hergestellt",
    ["by mail"] = "per Post",
    ["looted"] = "erbeutet",
    ["found"] = "gefunden",
    ["at level %d"] = "auf Stufe %d",
    ["gave you %s"] = "gab dir %s",
    ["%1$s: %2$s"] = "%1$s: %2$s",
    ["%s, a gift"] = "%s, ein Geschenk",

    -- Features/QuestFinales/Text.lua: a chain's end in the prose, the caption, the tooltip
    ["a quest"] = "eine Quest",
    ["a day"] = "einen Tag",
    ["%s days"] = "%s Tage",
    ["a week"] = "eine Woche",
    ["%s weeks"] = "%s Wochen",
    ["a month"] = "einen Monat",
    ["%s months"] = "%s Monate",
    ["the end of %s"] = "das Ende von %s",
    ["The end of %s."] = "Das Ende von %s.",
    ["The end of %1$s, a chain of %2$s."] = "Das Ende von %1$s, einer Kette aus %2$s Quests.",
    ["The end of %1$s, a chain of %2$s begun %3$s before."] = "Das Ende von %1$s, einer Kette aus %2$s Quests, begonnen %3$s zuvor.",
    ["The end of %1$s, a chain of %2$s begun in %3$s %4$s before."] = "Das Ende von %1$s, einer Kette aus %2$s Quests, begonnen in %3$s %4$s zuvor.",
    ["A chain of %d quests"] = "Eine Kette aus %d Quests",
    ["Begun in %1$s, %2$s"] = "Begonnen in %1$s, %2$s",
    ["Begun %s"] = "Begonnen %s",
    ["%s chains finished"] = "%s Ketten abgeschlossen",

    -- Features/Campfire/Kind.lua: the timeline's line, the card form
    ["sat by a campfire together"] = "ihr saßt zusammen am Lagerfeuer",
    ["{You} and %1$s sat by a campfire together in %2$s"] = "{Du hast} mit %1$s in %2$s am Lagerfeuer gesessen",
    ["{You} and %s sat by a campfire together"] = "{Du hast} mit %s am Lagerfeuer gesessen",
    ["Sat by a campfire together in %s"] = "Saß in %s gemeinsam am Lagerfeuer",
    ["Sat by a campfire together"] = "Saß gemeinsam am Lagerfeuer",
    ["Campfire"] = "Lagerfeuer",
    ["A campfire"] = "Ein Lagerfeuer",
    ["Where"] = "Wo",
    ["a camp, a village, an oasis"] = "ein Lager, ein Dorf, eine Oase",

    -- Features/Campfire/Text.lua: the slip, the tooltip, the caption
    ["sat by a campfire"] = "saß am Lagerfeuer",
    ["a campfire"] = "ein Lagerfeuer",
    ["campfires"] = "Lagerfeuer",
    ["By a campfire in %s"] = "An einem Lagerfeuer in %s",
    ["By a campfire"] = "An einem Lagerfeuer",
    ["By campfires in %s"] = "An Lagerfeuern in %s",
    ["By campfires"] = "An Lagerfeuern",

    -- Features/Chat/Kind.lua: the timeline's lines
    ["They whispered"] = "Sie haben geflüstert",
    ["{You} whispered"] = "{Du hast} geflüstert",
    ["Said"] = "Gesagt",
    ["Yelled"] = "Geschrien",
    ["Said in party"] = "In der Gruppe gesagt",

    -- Features/ProfessionCaps/Text.lua: a cap in the prose, the caption, the tooltip
    ["as far as an Apprentice goes"] = "so weit ein Lehrling ausbildet",
    ["as far as a Journeyman goes"] = "so weit ein Geselle ausbildet",
    ["as far as an Expert goes"] = "so weit ein Experte ausbildet",
    ["as far as an Artisan goes"] = "so weit ein Fachmann ausbildet",
    ["a profession"] = "ein Beruf",
    ["its cap##reached"] = "das Maximum",
    ["its cap##at"] = "dem Maximum",
    ["%1$s at %2$s"] = "%1$s auf %2$s",
    ["Then %1$s, %2$s."] = "Dann %1$s, %2$s.",
    ["Then %s."] = "Dann %s.",
    ["%1$s reached %2$s, %3$s."] = "%1$s erreichte %2$s, %3$s.",
    ["%1$s reached %2$s."] = "%1$s erreichte %2$s.",
    ["%s professions at their cap"] = "%s Berufe auf dem Maximum",
    ["%1$s, then %2$s"] = "%1$s, dann %2$s",

    -- Features/Trade/Kind.lua: the timeline's line
    ["gave %s"] = "gegeben: %s",
    ["got %s"] = "bekommen: %s",
    ["Traded"] = "Gehandelt",
    ["Traded: %s"] = "Gehandelt: %s",
    ["; "] = "; ",

    -- Features/WorldPvP/Kind.lua: the timeline's lines
    ["you killed them"] = "du hast sie getötet",
    ["they killed you"] = "sie haben dich getötet",
    ["them##killed"] = "sie",
    ["{You} killed %1$s%2$s"] = "{Du hast} %1$s%2$s getötet",
    ["{Your} group killed %1$s%2$s (%3$s's killing blow)"] = "{Deine} Gruppe hat %1$s%2$s getötet (Todesstoß: %3$s)",
    ["{Your} group killed %1$s%2$s"] = "{Deine} Gruppe hat %1$s%2$s getötet",
    [" with %s"] = " mit %s",
    ["%1$s probably killed {you}%2$s%3$s"] = "%1$s hat {dich} vermutlich%3$s%2$s getötet",
    ["%1$s killed {you}%2$s%3$s"] = "%1$s hat {dich}%3$s%2$s getötet",
    ["They probably killed {you}%1$s%2$s"] = "Sie haben {dich} vermutlich%2$s%1$s getötet",
    ["They killed {you}%1$s%2$s"] = "Sie haben {dich}%2$s%1$s getötet",

    -- Features/Met/Kind.lua: the card form
    ["Someone You Met"] = "Eine Begegnung",
    ["Someone you met"] = "Eine Begegnung",
    ["Someone in your diary, or any name"] = "Jemand aus deinem Tagebuch oder ein beliebiger Name",
    ["Description"] = "Beschreibung",
    ["What you did, in a line"] = "Was ihr getan habt, in einer Zeile",

    -- Features/Met/Text.lua: the strip, the tooltip, the caption
    ["with %s"] = "mit %s",
    ["With %s"] = "Mit %s",
    ["someone##with"] = "jemandem",

    -- Features/LevelUps/Kind.lua: the timeline's line
    ["%1$s is now level %2$s"] = "%1$s ist jetzt Stufe %2$s",
    ["Now level %s"] = "Jetzt Stufe %s",

})

if not ns.Locale.Is("deDE") then return end

-- Features/Firsts/Text.lua: a first found card's heading. German articles
-- and endings go with each noun, so every first is written whole: "Deine
-- erste Tasche!", "Dein erster grüner Gegenstand!", and short, for a narrow
-- margin, "Dein erstes Grünes!". Several firsts of one item are listed,
-- the last of the qualities in full: "Deine erste Tasche und dein erster
-- grüner Gegenstand!". `list` comes sorted (bag, shoulders, then quality).
local FIRSTS_HEADING = {
    bag = { "deine erste Tasche" },
    shoulder = { "deine ersten Schultern" },
    uncommon = { "dein erster grüner Gegenstand", "dein erstes Grünes" },
    rare = { "dein erster blauer Gegenstand", "dein erstes Blaues" },
    epic = { "dein erster epischer Gegenstand", "dein erstes Episches" },
}

function ns.Locale.grammar.FirstsHeading(list, short)
    local words = {}
    for i, kind in ipairs(list) do
        local forms = FIRSTS_HEADING[kind] or { "dein erster Fund" }
        local full = not short and i == #list
        words[#words + 1] = full and forms[1] or forms[2] or forms[1]
    end
    return ns.Locale.grammar.Capital(ns.UI.Format.List(words)) .. "!"
end
