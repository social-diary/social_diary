-- German (deDE): Features2. Keys are the English text (Locales/enUS.lua).
-- Duels, firsts found, quest chain finales, campfires, chat, profession
-- caps, trades, world PvP, someone you met, level-ups.

local addonName, ns = ...

ns.Locale.Add("deDE", {
    -- Features/Duels/Kind.lua: the timeline's line, the card form. The
    -- place ("in Späherkuppe, Westfall") goes last, where its comma reads.
    ["them##against"] = "sie",
    ["them##with"] = "ihnen",
    ["Won a duel against %1$s %2$s##zone"] = "Gewann ein Duell gegen %1$s %2$s",
    ["Won a duel against %s"] = "Gewann ein Duell gegen %s",
    ["Won a duel when %1$s fled %2$s##zone"] = "Gewann ein Duell %2$s, als %1$s floh",
    ["Won a duel when %s fled"] = "Gewann ein Duell, als %s floh",
    ["Won a duel when they fled %s##zone"] = "Gewann ein Duell %s, als sie flohen",
    ["Won a duel when they fled"] = "Gewann ein Duell, als sie flohen",
    ["Fled a duel with %1$s %2$s##zone"] = "Floh aus einem Duell mit %1$s %2$s",
    ["Fled a duel with %s"] = "Floh aus einem Duell mit %s",
    ["Lost a duel to %1$s %2$s##zone"] = "Verlor ein Duell gegen %1$s %2$s",
    ["Lost a duel to %s"] = "Verlor ein Duell gegen %s",
    ["Won %1$d duel against %2$s and lost %3$d %4$s|Won %1$d duels against %2$s and lost %3$d %4$s##zone##plural"] =
        "Gewann ein Duell gegen %2$s und verlor %3$d %4$s|Gewann %1$d Duelle gegen %2$s und verlor %3$d %4$s",
    ["Won %1$d duel against %2$s and lost %3$d|Won %1$d duels against %2$s and lost %3$d##plural"] =
        "Gewann ein Duell gegen %2$s und verlor %3$d|Gewann %1$d Duelle gegen %2$s und verlor %3$d",
    ["Won %1$d duel against %2$s %3$s|Won %1$d duels against %2$s %3$s##zone##plural"] =
        "Gewann ein Duell gegen %2$s %3$s|Gewann %1$d Duelle gegen %2$s %3$s",
    ["Won %1$d duel against %2$s|Won %1$d duels against %2$s##plural"] =
        "Gewann ein Duell gegen %2$s|Gewann %1$d Duelle gegen %2$s",
    ["Lost %1$d duel to %2$s and won %3$d %4$s|Lost %1$d duels to %2$s and won %3$d %4$s##zone##plural"] =
        "Verlor ein Duell gegen %2$s und gewann %3$d %4$s|Verlor %1$d Duelle gegen %2$s und gewann %3$d %4$s",
    ["Lost %1$d duel to %2$s and won %3$d|Lost %1$d duels to %2$s and won %3$d##plural"] =
        "Verlor ein Duell gegen %2$s und gewann %3$d|Verlor %1$d Duelle gegen %2$s und gewann %3$d",
    ["Lost %1$d duel to %2$s %3$s|Lost %1$d duels to %2$s %3$s##zone##plural"] =
        "Verlor ein Duell gegen %2$s %3$s|Verlor %1$d Duelle gegen %2$s %3$s",
    ["Lost %1$d duel to %2$s|Lost %1$d duels to %2$s##plural"] =
        "Verlor ein Duell gegen %2$s|Verlor %1$d Duelle gegen %2$s",
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
    ["%d duel each|%d duels each##plural"] = "je ein Sieg|je %d Siege",
    ["beat %1$s %2$s"] = "%1$s %2$s besiegt",
    ["won %d duel|won %d duels##plural"] = "ein Duell gewonnen|%d Duelle gewonnen",
    ["lost to %1$s %2$s"] = "%2$s gegen %1$s verloren",
    ["lost %d duel|lost %d duels##plural"] = "ein Duell verloren|%d Duelle verloren",
    ["beat %1$s %2$d to %3$d"] = "%1$s %2$d zu %3$d besiegt",
    ["won %1$d duel to %2$d|won %1$d duels to %2$d##plural"] =
        "Duell %1$d zu %2$d gewonnen|Duelle %1$d zu %2$d gewonnen",
    ["lost to %1$s %2$d to %3$d"] = "%2$d zu %3$d gegen %1$s verloren",
    ["lost %1$d duel to %2$d|lost %1$d duels to %2$d##plural"] =
        "Duell %1$d zu %2$d verloren|Duelle %1$d zu %2$d verloren",
    ["You won"] = "Du hast gewonnen",
    ["You lost"] = "Du hast verloren",
    ["Won %1$d, lost %2$d"] = "%1$d gewonnen, %2$d verloren",
    ["Lost %1$d, won %2$d"] = "%1$d verloren, %2$d gewonnen",
    ["Won both"] = "Beide gewonnen",
    ["Lost both"] = "Beide verloren",
    ["Won all %d"] = "Alle %d gewonnen",
    ["Lost all %d"] = "Alle %d verloren",
    ["%d duel|%d duels##plural"] = "%d Duell|%d Duelle",
    ["Duelled %s and others"] = "Duell mit %s und anderen",
    ["Duelled %s"] = "Duell mit %s",
    ["you fled %s"] = "du bist %s geflohen",
    ["A duel %s##zone"] = "Ein Duell %s",
    ["a duel won|%s duels won##plural"] = "ein gewonnenes Duell|%s gewonnene Duelle",
    ["A duel won %2$s|%1$s duels won %2$s##zone##plural"] = "Ein gewonnenes Duell %2$s|%1$s gewonnene Duelle %2$s",
    ["a duel lost|%s duels lost##plural"] = "ein verlorenes Duell|%s verlorene Duelle",
    ["A duel lost %2$s|%1$s duels lost %2$s##zone##plural"] = "Ein verlorenes Duell %2$s|%1$s verlorene Duelle %2$s",
    ["duels won and lost"] = "gewonnene und verlorene Duelle",
    ["Duels won and lost %s##zone"] = "Gewonnene und verlorene Duelle %s",
    ["duels mostly won"] = "meist gewonnene Duelle",
    ["Duels mostly won %s##zone"] = "Meist gewonnene Duelle %s",
    ["duels mostly lost"] = "meist verlorene Duelle",
    ["Duels mostly lost %s##zone"] = "Meist verlorene Duelle %s",

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
    ["Bought %1$s %2$s##zone"] = "Kaufte %1$s %2$s",
    ["Bought %s"] = "Kaufte %s",
    ["Made %1$s %2$s##zone"] = "Stellte %1$s %2$s her",
    ["Made %s"] = "Stellte %s her",
    ["%s came by mail"] = "bekam %s per Post",
    ["Found %1$s %2$s##zone"] = "Fand %1$s %2$s",
    ["Found %s"] = "Fand %s",
    ["%1$s: %2$s."] = "%1$s: %2$s.",
    ["a quest's reward"] = "Questbelohnung",
    ["bought"] = "gekauft",
    ["made by hand"] = "selbst hergestellt",
    ["by mail"] = "per Post",
    ["looted"] = "erbeutet",
    ["found"] = "gefunden",
    ["at level %d"] = "auf Stufe %d",
    -- the firsts after the first in a tooltip's title: "Deine erste
    -- Tasche und erstes Grünes"
    ["first bag"] = "erste Tasche",
    ["first green"] = "erstes Grünes",
    ["first blue"] = "erstes Blaues",
    ["first epic"] = "erstes Episches",
    ["first find"] = "erster Fund",
    ["an item"] = "ein Gegenstand",
    ["gave you %s"] = "gab dir %s",
    ["%1$s: %2$s"] = "%1$s: %2$s",
    ["%s, a gift"] = "%s, ein Geschenk",

    -- Features/QuestFinales/Text.lua: a chain's end in the prose, the caption, the tooltip
    ["a quest"] = "eine Quest",
    ["a day|%s days##plural"] = "einen Tag|%s Tage",
    ["a week|%s weeks##plural"] = "eine Woche|%s Wochen",
    ["a month|%s months##plural"] = "einen Monat|%s Monate",
    ["the end of %s"] = "das Ende von %s",
    ["The end of %s."] = "Das Ende von %s.",
    ["The end of %1$s, a chain of %2$s."] = "Das Ende von %1$s, einer Kette aus %2$s Quests.",
    ["The end of %1$s, a chain of %2$s begun %3$s %4$s before.##zone"] =
        "Das Ende von %1$s, einer Kette aus %2$s Quests, begonnen %3$s %4$s zuvor.",
    ["The end of %1$s, a chain of %2$s begun %3$s before."] = "Das Ende von %1$s, einer Kette aus %2$s Quests, begonnen %3$s zuvor.",
    ["A chain of %s"] = "Eine Kette aus %s",
    ["Begun %1$s, %2$s##zone"] = "Begonnen %1$s, %2$s",
    ["Begun %s"] = "Begonnen %s",
    ["%1$s, a chain of %2$d quest|%1$s, a chain of %2$d quests##plural"] =
        "%1$s, eine Kette aus einer Quest|%1$s, eine Kette aus %2$d Quests",
    ["%s chain finished|%s chains finished##plural"] = "%s Kette abgeschlossen|%s Ketten abgeschlossen",

    -- Features/Campfire/Kind.lua: the timeline's line, the card form. A
    -- subzone's place, "in Lushwasser-Oase, Brachland", closes with a comma
    -- where the sentence goes on after it.
    ["sat by a campfire together"] = "ihr saßt zusammen am Lagerfeuer",
    ["{You} and %1$s sat by a campfire together %2$s, %3$s##zone"] = "{Du hast} mit %1$s %2$s, %3$s, am Lagerfeuer gesessen",
    ["{You} and %1$s sat by a campfire together %2$s##zone"] = "{Du hast} mit %1$s %2$s am Lagerfeuer gesessen",
    ["{You} and %s sat by a campfire together"] = "{Du hast} mit %s am Lagerfeuer gesessen",
    ["Sat by a campfire together %1$s, %2$s##zone"] = "Saß gemeinsam am Lagerfeuer %1$s, %2$s",
    ["Sat by a campfire together %s##zone"] = "Saß gemeinsam am Lagerfeuer %s",
    ["Sat by a campfire together"] = "Saß gemeinsam am Lagerfeuer",
    ["Campfire"] = "Lagerfeuer",
    ["A campfire"] = "Ein Lagerfeuer",
    ["Where"] = "Wo",
    ["a camp, a village, an oasis"] = "ein Lager, ein Dorf, eine Oase",

    -- Features/Campfire/Text.lua: the slip, the tooltip, the caption
    ["sat by a campfire"] = "saß am Lagerfeuer",
    ["Sat by a campfire %s##times"] = "Saß %s am Lagerfeuer",
    ["a campfire"] = "ein Lagerfeuer",
    ["campfires"] = "Lagerfeuer",
    ["By a campfire %s##zone"] = "An einem Lagerfeuer %s",
    ["By campfires %s##zone"] = "An Lagerfeuern %s",
    ["By a campfire"] = "An einem Lagerfeuer",
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
    ["%s profession at its cap|%s professions at their cap##plural"] =
        "%s Beruf auf dem Maximum|%s Berufe auf dem Maximum",
    ["%1$s, then %2$s"] = "%1$s, dann %2$s",

    -- Features/Trade/Kind.lua: the timeline's line
    ["gave %s"] = "gegeben: %s",
    ["got %s"] = "bekommen: %s",
    ["Traded"] = "Gehandelt",
    ["Traded: %s"] = "Gehandelt: %s",

    -- Features/WorldPvP/Kind.lua: the timeline's lines
    ["you killed them"] = "du hast sie getötet",
    ["they killed you"] = "sie haben dich getötet",
    ["them##killed"] = "sie",
    ["{You} killed %1$s %2$s##zone"] = "{Du hast} %1$s %2$s getötet",
    ["{You} killed %s"] = "{Du hast} %s getötet",
    ["{Your} group killed %1$s %2$s (%3$s's killing blow)##zone"] = "{Deine} Gruppe hat %1$s %2$s getötet (Todesstoß: %3$s)",
    ["{Your} group killed %1$s (%2$s's killing blow)"] = "{Deine} Gruppe hat %1$s getötet (Todesstoß: %2$s)",
    ["{Your} group killed %1$s %2$s##zone"] = "{Deine} Gruppe hat %1$s %2$s getötet",
    ["{Your} group killed %s"] = "{Deine} Gruppe hat %s getötet",
    ["%1$s killed {you} %2$s##zone"] = "%1$s hat {dich} %2$s getötet",
    ["%s killed {you}"] = "%s hat {dich} getötet",
    ["%1$s killed {you} with %2$s %3$s##zone"] = "%1$s hat {dich} %3$s mit %2$s getötet",
    ["%1$s killed {you} with %2$s"] = "%1$s hat {dich} mit %2$s getötet",
    ["%1$s probably killed {you} %2$s##zone"] = "%1$s hat {dich} wahrscheinlich %2$s getötet",
    ["%s probably killed {you}"] = "%s hat {dich} wahrscheinlich getötet",
    ["%1$s probably killed {you} with %2$s %3$s##zone"] = "%1$s hat {dich} wahrscheinlich %3$s mit %2$s getötet",
    ["%1$s probably killed {you} with %2$s"] = "%1$s hat {dich} wahrscheinlich mit %2$s getötet",
    ["They killed {you} %s##zone"] = "Sie haben {dich} %s getötet",
    ["They killed {you} with %1$s %2$s##zone"] = "Sie haben {dich} %2$s mit %1$s getötet",
    ["They killed {you} with %s"] = "Sie haben {dich} mit %s getötet",
    ["They probably killed {you} %s##zone"] = "Sie haben {dich} wahrscheinlich %s getötet",
    ["They probably killed {you} with %1$s %2$s##zone"] = "Sie haben {dich} wahrscheinlich %2$s mit %1$s getötet",
    ["They probably killed {you} with %s"] = "Sie haben {dich} wahrscheinlich mit %s getötet",

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
    ["%1$s; %2$s##list"] = "%1$s; %2$s",

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
