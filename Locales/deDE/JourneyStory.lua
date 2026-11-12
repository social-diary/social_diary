-- German (deDE): Your Diary, a match's story (UI/Journey/MatchStory.lua, UI/Journey/Text/MatchStory.lua).
-- Voice: .claude/skills/translate/voices/deDE.md
local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- UI/Journey/MatchStory.lua
    -- A name in these arrives as "Du" (L["You"]) as often as "Koko": no
    -- verb agrees with it, so the lines are ledger, a bare participle.
    ["Back to the match"] = "Zurück zur Partie",
    ["A fight, %1$s into the match##story"] = "Ein Kampf, %1$s nach Spielbeginn",
    ["%1$d of us against %2$d of them##story"] = "%1$d von uns gegen %2$d von ihnen",
    ["%1$s fell at %2$s##story"] = "%1$s um %2$s gefallen",
    -- The killer may be "du" (nominative), so it follows a colon.
    ["%1$s fell to %3$s at %2$s##story"] = "%1$s um %2$s gefallen, Todesstoß: %3$s",
    ["%1$s carried their flag##story"] = "%1$s mit ihrer Flagge unterwegs",
    ["%1$s carried our flag##story"] = "%1$s mit unserer Flagge unterwegs",
    ["Brought home at %1$s##story"] = "Um %1$s heimgebracht",
    ["Brought back at %1$s##story"] = "Um %1$s zurückgebracht",
    ["Still out when the match ended##story"] = "Bei Spielende noch unterwegs",
    ["you##story"] = "du",
    ["One of ours##story"] = "Einer von uns",
    ["one of ours##story"] = "einer von uns",
    ["One of theirs##story"] = "Einer von ihnen",
    ["one of theirs##story"] = "einer von ihnen",
    ["Someone##story"] = "Jemand",
    ["someone##story"] = "jemand",

    -- UI/Journey/Text/MatchStory.lua
    ["%1$s against %2$s##outnumbered"] = "%1$s gegen %2$s",
    -- "zum dritten Mal": the ordinal after "zum" (past twelve, "zum 13. Mal").
    ["first##time"] = "ersten",
    ["fourth##time"] = "vierten",
    ["second##time"] = "zweiten",
    ["third##time"] = "dritten",
    ["eighth##time"] = "achten",
    ["fifth##time"] = "fünften",
    ["ninth##time"] = "neunten",
    ["seventh##time"] = "siebten",
    ["sixth##time"] = "sechsten",
    ["eleventh##time"] = "elften",
    ["tenth##time"] = "zehnten",
    ["twelfth##time"] = "zwölften",
    ["%d s"] = "%d Sek.",
    ["%1$d min %2$d s"] = "%1$d Min. %2$d Sek.",
    ["VICTORY"] = "SIEG",
    ["DEFEAT"] = "NIEDERLAGE",
    ["Won in a minute|Won in %s minutes##plural"] = "In einer Minute gewonnen|In %s Minuten gewonnen",
    ["Lost in a minute|Lost in %s minutes##plural"] = "In einer Minute verloren|In %s Minuten verloren",
    ["Over in a minute|Over in %s minutes##plural"] = "Nach einer Minute vorbei|Nach %s Minuten vorbei",
    ["See the board"] = "Zur Punktetafel",
    ["The opening"] = "Der Auftakt",
    ["The last flag"] = "Die letzte Flagge",
    ["The clock ran out"] = "Die Zeit lief ab",
    ["No flag came home"] = "Keine Flagge kam heim",
    ["The long stand-off"] = "Das lange Patt",
    ["Level again"] = "Wieder Gleichstand",
    ["Both flags out"] = "Beide Flaggen unterwegs",
    ["A carry broken"] = "Ein Lauf gestoppt",
    ["We broke in"] = "Wir brachen durch",
    ["They broke in"] = "Sie brachen durch",
    ["The Zerg"] = "Der Zerg",
    ["%1$d of ours fell, %2$d of theirs|%1$d of ours fell, %2$d of theirs##plural"] =
        "%1$d von uns gefallen, %2$d von ihnen|%1$d von uns gefallen, %2$d von ihnen",
    ["%d of theirs fell, none of ours|%d of theirs fell, none of ours##plural"] =
        "%d von ihnen gefallen, keiner von uns|%d von ihnen gefallen, keiner von uns",
    ["%d of ours fell|%d of ours fell##plural"] = "%d von uns gefallen|%d von uns gefallen",
    ["no one fell##zerg"] = "keiner gefallen",
    ["%1$s, a %2$s time"] = "%1$s, zum %2$s Mal",
    ["and you never got them"] = "und du hast dich nie gerächt",
    -- the count arrives as a word ("ein", "sieben"): "eine Minute"
    ["%s minute, no flag out|%s minutes, no flag out##plural"] =
        "%s<f> Minute, keine Flagge unterwegs|%s Minuten, keine Flagge unterwegs",
    ["%1$s, beside you"] = "%1$s, an deiner Seite",
    ["%1$s, again"] = "%1$s, schon wieder",
    -- the ordinal is first##match ("dritte"), before a feminine noun
    ["your %s match with them tonight"] = "eure %s gemeinsame Partie heute Abend",
    ["your %s match against them tonight"] = "eure %s Partie gegeneinander heute Abend",
    ["You against %1$s"] = "Du gegen %1$s",
    ["You against one of theirs"] = "Du gegen einen von ihnen",
    ["you fell##duel"] = "du bist gefallen",
    ["you won##duel"] = "du hast gewonnen",
    ["You killed %1$s"] = "Du hast %1$s getötet",
    ["%1$s killed %2$s"] = "%1$s hat %2$s getötet",
    ["One of ours killed %1$s"] = "Einer von uns hat %1$s getötet",
    ["who had killed you %s"] = "hatte dich zuvor %s getötet",
    ["%1$s, against you"] = "%1$s, gegen dich",
    ["%1$s, with you"] = "%1$s, mit dir",
    ["You carried their flag"] = "Du hast ihre Flagge getragen",
    ["You carried their flag home"] = "Du hast ihre Flagge heimgebracht",
    ["You killed %1$s and brought our flag back"] = "Du hast %1$s getötet und unsere Flagge zurückgebracht",
    ["You brought our flag back"] = "Du hast unsere Flagge zurückgebracht",
    -- "%1$s against %2$s##outnumbered": left in English (one of us arrives
    -- as "ein": "Ein gegen vier" needs "Einer", no plural key to give it).
    ["You ran with %1$s"] = "Du hast %1$s begleitet",
    ["You ran with our flag carrier"] = "Du hast unseren Flaggenträger begleitet",
    ["the flag came home"] = "die Flagge kam heim",
    ["You and %1$s fell"] = "Du und %1$s seid gefallen",
    ["You and one of ours fell"] = "Du und einer von uns seid gefallen",
    ["in the same second"] = "in derselben Sekunde",
    ["%s second apart|%s seconds apart##plural"] = "%s<f> Sekunde auseinander|%s Sekunden auseinander",
    ["you never fell"] = "du bist nie gefallen",
    ["you fell twice, both times to %s"] = "du bist zweimal gefallen, beide Male durch %s",
    ["you fell %1$s, every time to %2$s"] = "du bist %1$s gefallen, jedes Mal durch %2$s",
    ["you fell %1$s, %2$s of them to %3$s|you fell %1$s, %2$s of them to %3$s##plural"] =
        "du bist %1$s gefallen, %2$smal davon durch %3$s|du bist %1$s gefallen, %2$smal davon durch %3$s",
})
