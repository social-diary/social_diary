-- German (deDE): Your Diary (UI/Journey/ and its words, UI/Journey/Text/).
-- Keys are the English text (Locales/enUS.lua).
--
-- The prose is in Präteritum, the subject dropped where the English drops it
-- ("Erreichte am 6. Oktober Stufe 12."), the tooltips and margin words in
-- Perfekt or participles, as a ledger reads. A place arrives as a whole
-- phrase with its preposition ("##zone": "in Brachland", "bei Wegekreuz",
-- Locales/deDE/Grammar.lua's PLACE), so a template never writes one before
-- it. A stop's spoken time (UI/Journey/Text/Time.lua's Spoken) is in the
-- accusative ("einen Augenblick", "eine halbe Stunde"), so the templates
-- take it as a time span: "%s lang", "%s später", "%s zusammen".
--
-- A battleground's match is "das Match" (as Windows.lua says it), the
-- battlegrounds "Schlachtfelder", a killing blow "Todesstoß". The notes on a
-- match page and its tooltips read as a ledger: Perfekt ("Du bist zweimal
-- gefallen."), the deeds as participles ("Ihre Flagge einmal erobert.").

local addonName, ns = ...

ns.Locale.Add("deDE", {
    -- UI/Journey/Caption.lua
    ["Nothing of this level's road was kept."] = "Vom Weg dieser Stufe wurde nichts aufgezeichnet.",

    -- UI/Journey/CardPad.lua: the pad's prompts (the book's shared ones in
    -- Journal.lua and Windows.lua)
    ["Go to the names"] = "Zu den Namen",
    ["Put the card away"] = "Karte weglegen",
    ["Back to the line"] = "Zurück zur Zeile",

    -- UI/Journey/CardSheet.lua (the custom cards' form)
    ["Combat"] = "Kampf",
    ["Quests and Lore"] = "Quests und Geschichten",
    ["Other"] = "Anderes",
    ["Social"] = "Soziales",
    ["Add custom event..."] = "Eigenes Ereignis hinzufügen …",
    ["Choose another"] = "Etwas anderes wählen",
    ["What happened here?"] = "Was ist hier passiert?",
    ["Which one?"] = "Welches?",
    ["Left out of this page"] = "Auf dieser Seite weggelassen",
    ["Delete this card"] = "Diese Karte löschen",
    ["Leave it out"] = "Weglassen",
    ["Undo my changes"] = "Meine Änderungen zurücknehmen",
    ["Delete this card you wrote?\n\nIt comes off the map and the page. This cannot be undone."] =
        "Diese Karte löschen, die du geschrieben hast?\n\nSie verschwindet von der Landkarte und von der Seite. Das kann nicht rückgängig gemacht werden.",

    -- UI/Journey/Empty.lua (the sample uses the German client's names)
    ["Each level's places are glued in here:"] = "Die Orte jeder Stufe werden hier eingeklebt:",
    ["Where you stayed a while, darker the longer."] = "Wo du eine Weile bliebst, dunkler, je länger.",
    ["The roads between."] = "Die Wege dazwischen.",
    ["Flights, dashed. Dungeons, where you went in."] = "Flüge, gestrichelt. Dungeons, wo du hineingingst.",
    ["Who you met there, written in the margin."] = "Wen du dort trafst, am Rand notiert.",
    ["Where the level came."] = "Wo die Stufe erreicht wurde.",
    ["The Barrens, Tuesday"] = "Brachland, Dienstag",
    ["Level 12, and a death by the oasis."] = "Stufe 12 und ein Tod an der Oase.",
    ["A few words for each place, up to three a level."] = "Ein paar Worte zu jedem Ort, bis zu drei pro Stufe.",
    ["A recap of where you went and who you were with. It counts no quests and keeps no score."] =
        "Ein Rückblick, wo du warst und mit wem. Es zählt keine Quests und führt keine Punkte.",
    ["Only your own position, never anyone else's."] = "Nur deine eigene Position, nie die von anderen.",
    ["Each level gets an entry, like this:"] = "Jede Stufe bekommt einen Eintrag, etwa so:",
    ["Reached on 6 October at the Crossroads, The Barrens."] = "Erreicht am 6. Oktober am Wegekreuz, Brachland.",
    ["An hour of quests round the Crossroads. Then Lushwater Oasis."] =
        "Eine Stunde lang Quests rund um das Wegekreuz. Dann die Oase von Lushwater.",
    ["With Thex Theximus for forty minutes."] = "Mit Thex Theximus, vierzig Minuten lang.",
    ["1 h 20"] = "1:20 Std.",
    ["40 min"] = "40 Min.",
    ["Stonetalon Mountains"] = "Steinkrallengebirge",
    ["The Barrens"] = "Brachland",
    ["Not keeping your road"] = "Dein Weg wird nicht aufgezeichnet",
    ["Your road starts here"] = "Hier beginnt dein Weg",
    ["Nothing is on it yet. From now on the diary keeps where this character goes: the places you stay a while, the roads between, flights and dungeons, and who you were with."] =
        "Noch steht nichts darauf. Ab jetzt zeichnet das Tagebuch auf, wohin dieser Charakter geht: die Orte, an denen du eine Weile bleibst, die Wege dazwischen, Flüge und Dungeons, und mit wem du unterwegs warst.",
    ["The diary is not keeping this character's road just now, so there is nothing to tell here yet."] =
        "Das Tagebuch zeichnet den Weg dieses Charakters gerade nicht auf, darum gibt es hier noch nichts zu erzählen.",

    -- UI/Journey/Full.lua
    ["Nothing of your road is on this map yet."] = "Auf dieser Karte ist noch nichts von deinem Weg.",

    -- UI/Journey/Look.lua: the foot's hint (with the pad in hand, B's glyph)
    ["Left click to go back"] = "Linksklick: zurück",
    ["%s to go back"] = "%s: zurück",

    -- UI/Journey/Match.lua: a print on the roll, the name and its matches' numerals
    ["%1$s  %2$s##roll"] = "%1$s  %2$s",

    -- UI/Journey/Pad.lua: the pad's prompts
    ["Earlier or later"] = "Früher oder später",
    ["Go to the levels"] = "Zu den Stufen",
    ["See the whole map"] = "Ganze Karte ansehen",
    ["Back to the contents"] = "Zurück zum Inhalt",
    ["Back to the plates"] = "Zurück zu den Karten",
    ["Change the card"] = "Karte ändern",
    ["Add a card here"] = "Hier eine Karte ablegen",
    ["Closer"] = "Näher",
    ["Further"] = "Weiter weg",
    ["Move the map"] = "Karte verschieben",
    ["See the others"] = "Die anderen ansehen",
    ["Open the match"] = "Match öffnen",
    ["Turn the board over"] = "Tafel umdrehen",
    ["Turn the roll over"] = "Liste umdrehen",

    -- UI/Journey/Page.lua
    ["Your road is not being kept just now."] = "Dein Weg wird gerade nicht aufgezeichnet.",
    ["Keep it again"] = "Wieder aufzeichnen",

    -- UI/Journey/Text/Caption.lua
    ["Somewhere"] = "Irgendwo",
    ["%1$s, %2$s##zone"] = "%1$s, %2$s",
    ["A fight, lost"] = "Ein Kampf, verloren",
    ["%s fight|%s fights##plural"] = "%s Kampf|%s Kämpfe",
    ["Where the diary began"] = "Wo das Tagebuch begann",
    ["Into a new zone for the first time"] = "Zum ersten Mal in einer neuen Zone",
    ["%s for the first time##zone"] = "Zum ersten Mal %s",
    ["The way into a dungeon"] = "Der Weg in einen Dungeon",
    ["The way %s##zone"] = "Der Weg %s",
    ["A long stay"] = "Ein langer Aufenthalt",
    ["Where the fighting was"] = "Wo gekämpft wurde",
    ["In good company"] = "In guter Gesellschaft",
    ["On the road"] = "Unterwegs",

    -- UI/Journey/Text/Margin.lua
    ["one more note|%s more notes##plural"] = "eine weitere Notiz|%s weitere Notizen",
    ["a note|%s notes##plural"] = "eine Notiz|%s Notizen",
    ["a fight, lost"] = "ein Kampf, verloren",
    ["a fight, won"] = "ein Kampf, gewonnen",
    ["you won the fight"] = "du hast den Kampf gewonnen",
    ["you'd meet again"] = "ihr würdet euch wiedersehen",
    ["you'd meet again at level %d"] = "ihr würdet euch auf Stufe %d wiedersehen",
    ["first seen, and %s"] = "zuerst gesehen, und %s",
    ["with someone"] = "mit jemandem",

    -- UI/Journey/Text/Match.lua (a battleground's pages)
    ["once|%s times##plural"] = "einmal|%smal",
    -- a death in a match, "Zweiter Tod" (der Tod)
    ["first##death"] = "erster",
    ["fourth##death"] = "vierter",
    ["second##death"] = "zweiter",
    ["third##death"] = "dritter",
    ["eighth##death"] = "achter",
    ["fifth##death"] = "fünfter",
    ["ninth##death"] = "neunter",
    ["seventh##death"] = "siebter",
    ["sixth##death"] = "sechster",
    ["eleventh##death"] = "elfter",
    ["tenth##death"] = "zehnter",
    ["twelfth##death"] = "zwölfter",
    -- the tickets' short map names (not yet checked in a German client)
    ["Warsong"] = "Kriegshymnen",
    ["Arathi"] = "Arathi",
    ["Alterac"] = "Alterac",
    ["Left before the end, %s"] = "Vor dem Ende gegangen, %s",
    ["Won, %s"] = "Gewonnen, %s",
    ["Lost, after %s"] = "Verloren, nach %s",
    ["Neither side won, %s"] = "Keine Seite gewann, %s",
    ["left early##match"] = "früh gegangen",
    ["no score##match"] = "ohne Ergebnis",
    ["won##match"] = "gewonnen",
    ["lost##match"] = "verloren",
    ["no winner##match"] = "ohne Sieger",
    ["Left early##match"] = "Früh gegangen",
    ["No score##match"] = "Ohne Ergebnis",
    ["Won##match"] = "Gewonnen",
    ["Lost##match"] = "Verloren",
    ["No winner##match"] = "Ohne Sieger",
    ["%1$s  %2$s##ticket"] = "%1$s  %2$s",
    ["The other side"] = "Die andere Seite",
    ["%1$s, %2$d##side"] = "%1$s, %2$d",
    ["Turn the board over, %1$d of %2$d"] = "Tafel umdrehen, %1$d von %2$d",
    ["Turn the roll over, %1$d of %2$d"] = "Liste umdrehen, %1$d von %2$d",
    ["%1$s killed you %2$s"] = "%1$s hat dich %2$s getötet",
    ["your %s match with them"] = "dein %s Match mit ihnen",
    ["your %s match against them"] = "dein %s Match gegen sie",
    ["and %d more, rubbed out|and %d more, rubbed out##plural"] =
        "und %d weiterer, ausradiert|und %d weitere, ausradiert",
    ["%d names on this old board were rubbed out. The people in your diary stay on it.|%d names on this old board were rubbed out. The people in your diary stay on it.##plural"] =
        "%d Name auf dieser alten Tafel wurde ausradiert. Die Leute aus deinem Tagebuch bleiben darauf.|%d Namen auf dieser alten Tafel wurden ausradiert. Die Leute aus deinem Tagebuch bleiben darauf.",
    ["You never fell."] = "Du bist nie gefallen.",
    ["you fell %s"] = "du bist %s gefallen",
    ["Took their flag %1$s, brought ours back %2$s and dealt %3$s killing blow.|Took their flag %1$s, brought ours back %2$s and dealt %3$s killing blows.##plural"] =
        "Ihre Flagge %1$s erobert, unsere %2$s zurückgebracht und einen Todesstoß versetzt.|Ihre Flagge %1$s erobert, unsere %2$s zurückgebracht und %3$s Todesstöße versetzt.",
    ["Took their flag %1$s and dealt %2$s killing blow.|Took their flag %1$s and dealt %2$s killing blows.##plural"] =
        "Ihre Flagge %1$s erobert und einen Todesstoß versetzt.|Ihre Flagge %1$s erobert und %2$s Todesstöße versetzt.",
    ["Brought ours back %1$s and dealt %2$s killing blow.|Brought ours back %1$s and dealt %2$s killing blows.##plural"] =
        "Unsere Flagge %1$s zurückgebracht und einen Todesstoß versetzt.|Unsere Flagge %1$s zurückgebracht und %2$s Todesstöße versetzt.",
    ["Dealt %s killing blow.|Dealt %s killing blows.##plural"] = "Einen Todesstoß versetzt.|Todesstöße versetzt: %s.",
    ["Took their flag %1$s and brought ours back %2$s."] = "Ihre Flagge %1$s erobert und unsere %2$s zurückgebracht.",
    ["Took their flag %s."] = "Ihre Flagge %s erobert.",
    ["Brought ours back %s."] = "Unsere Flagge %s zurückgebracht.",
    ["The rest went unwritten."] = "Der Rest blieb ungeschrieben.",
    -- (left in English: "%1$s match, %2$s won, %3$s|...##plural" and
    -- "none##won", whose won count 1 is "ein" and would need "eins")
    ["You never fell, took their flag %1$s and brought ours back %2$s."] =
        "Du bist nie gefallen, hast %1$s ihre Flagge erobert und %2$s unsere zurückgebracht.",
    ["You never fell, took their flag %s."] = "Du bist nie gefallen und hast %s ihre Flagge erobert.",
    ["You never fell, brought ours back %s."] = "Du bist nie gefallen und hast %s unsere Flagge zurückgebracht.",
    ["You never fell and dealt %s killing blow.|You never fell and dealt %s killing blows.##plural"] =
        "Du bist nie gefallen und hast einen Todesstoß versetzt.|Du bist nie gefallen und hast %s Todesstöße versetzt.",
    ["You fell %1$s, took their flag %2$s and brought ours back %3$s."] =
        "Du bist %1$s gefallen, hast %2$s ihre Flagge erobert und %3$s unsere zurückgebracht.",
    ["You fell %1$s, took their flag %2$s."] = "Du bist %1$s gefallen und hast %2$s ihre Flagge erobert.",
    ["You fell %1$s, brought ours back %2$s."] = "Du bist %1$s gefallen und hast %2$s unsere Flagge zurückgebracht.",
    ["You fell %1$s and dealt %2$s killing blow.|You fell %1$s and dealt %2$s killing blows.##plural"] =
        "Du bist %1$s gefallen und hast einen Todesstoß versetzt.|Du bist %1$s gefallen und hast %2$s Todesstöße versetzt.",
    ["killed you in all %s|killed you in all %s##plural"] = "tötete dich in allen %s|tötete dich in allen %s",
    ["killed you in %s of them|killed you in %s of them##plural"] = "tötete dich in einem davon|tötete dich in %s davon",
    ["and everyone else, %d more|and everyone else, %d more##plural"] =
        "und alle anderen, %d weiterer|und alle anderen, %d weitere",
    ["Battlegrounds, %s match|Battlegrounds, %s matches##plural"] = "Schlachtfelder, ein Match|Schlachtfelder, %s Matches",
    ["%1$s, %2$s##match"] = "%1$s, %2$s",
    ["Battlegrounds"] = "Schlachtfelder",
    ["Back to the battlegrounds"] = "Zurück zu den Schlachtfeldern",
    ["Final##score"] = "Endstand",
    ["Deaths"] = "Tode",
    ["to##score"] = "zu",
    ["The score went unwritten. Who was there:"] = "Der Spielstand blieb ungeschrieben. Wer dabei war:",
    ["With you"] = "Mit dir",
    ["Against you"] = "Gegen dich",
    ["You"] = "Du",
    ["from your diary"] = "aus deinem Tagebuch",
    ["Click to open their page."] = "Klicken, um die Seite zu öffnen.",
    ["Click to open the match."] = "Klicken, um das Match zu öffnen.",
    ["%1$s %2$s##race class"] = "%1$s %2$s",
    ["%1$s, %2$s, %3$s##board row"] = "%1$s, %2$s, %3$s",
    ["a hand in %d kill|a hand in %d kills##plural"] = "an %d Kill beteiligt|an %d Kills beteiligt",
    ["%1$s damage, %2$s healing"] = "%1$s Schaden, %2$s Heilung",
    ["%1$s, %2$s, %3$s.##match"] = "%1$s, %2$s, %3$s.",
    ["You dealt %s killing blow and never fell.|You dealt %s killing blows and never fell.##plural"] =
        "Du hast einen Todesstoß versetzt und bist nie gefallen.|Du hast %s Todesstöße versetzt und bist nie gefallen.",
    ["You dealt %1$s killing blow and fell %2$s.|You dealt %1$s killing blows and fell %2$s.##plural"] =
        "Du hast einen Todesstoß versetzt und bist %2$s gefallen.|Du hast %1$s Todesstöße versetzt und bist %2$s gefallen.",
    ["You fell %s."] = "Du bist %s gefallen.",
    ["With you in %s##matches"] = "Mit dir in %s",
    ["With you in all %s|With you in all %s##plural"] = "Mit dir in allen %s|Mit dir in allen %s",
    ["Against you in all %s|Against you in all %s##plural"] = "Gegen dich in allen %s|Gegen dich in allen %s",
    ["Against you in %s##matches"] = "Gegen dich in %s",
    ["%1$s, %2$d min in, killed by %3$s"] = "%1$s Tod, nach %2$d Min., getötet von %3$s",
    ["%1$s, %2$d min in"] = "%1$s Tod, nach %2$d Min.",

    -- UI/Journey/Text/Notes.lua
    ["And one more note.|And %d more notes.##plural"] = "Und noch eine Notiz.|Und noch %d Notizen.",

    -- UI/Journey/Text/Prose.lua
    ["This diary began at level %1$d, %2$s, on %3$s.##zone"] = "Dieses Tagebuch begann am %3$s auf Stufe %1$d, %2$s.",
    ["This diary began at level %1$d, on %2$s."] = "Dieses Tagebuch begann am %2$s auf Stufe %1$d.",
    ["Week of %s"] = "Woche vom %s",
    ["Reached level %1$d %2$s, %3$s, on %4$s. The road goes on.##zone"] =
        "Erreichte am %4$s %2$s, %3$s, Stufe %1$d. Der Weg geht weiter.",
    ["Reached level %1$d %2$s, on %3$s. The road goes on.##zone"] =
        "Erreichte am %3$s %2$s Stufe %1$d. Der Weg geht weiter.",
    ["Reached level %1$d, on %2$s. The road goes on."] = "Erreichte am %2$s Stufe %1$d. Der Weg geht weiter.",
    ["Your road begins here, on %1$s, %2$s.##zone"] = "Hier beginnt dein Weg, am %1$s, %2$s.",
    ["Your road begins here, on %s."] = "Hier beginnt dein Weg, am %s.",
    ["Reached on %1$s %2$s, %3$s.##zone"] = "Erreicht am %1$s %2$s, %3$s.",
    ["Reached on %1$s %2$s.##zone"] = "Erreicht am %1$s %2$s.",
    ["Reached on %s."] = "Erreicht am %s.",
    -- the stops: %1$s the time capitalised, %2$s as is, %3$s the place
    ["%1$s of fighting %3$s.##zone"] = "%1$s lang Kämpfe %3$s.",
    ["%3$s kept you fighting for %2$s."] = "%3$s hielt dich %2$s lang mit Kämpfen auf.",
    ["%1$s of quests %3$s.##zone"] = "%1$s lang Quests %3$s.",
    ["Quests kept you %3$s for %2$s.##zone"] = "Quests hielten dich %2$s lang %3$s fest.",
    ["%1$s resting %3$s.##zone"] = "%1$s Rast %3$s.",
    ["You rested %2$s %3$s.##zone"] = "Du machtest %2$s lang Rast %3$s.",
    ["%1$s %3$s.##zone"] = "%1$s %3$s.",
    ["You lingered %3$s for %2$s.##zone"] = "Du verweiltest %2$s lang %3$s.",
    ["fighting %s##zone"] = "Kämpfe %s",
    ["quests %s##zone"] = "Quests %s",
    ["a rest %s##zone"] = "eine Rast %s",
    ["After that, %s."] = "Danach %s.",
    ["Later, %s."] = "Später %s.",
    ["Flew %s.##zone"] = "Flog %s.",
    ["%1$s for %2$s##with"] = "%1$s, %2$s lang",
    ["%s briefly"] = "%s kurz",
    ["With %s."] = "Mit %s.",
    ["beat %s"] = "besiegte %s",
    ["won a fight"] = "gewann einen Kampf",
    ["lost a fight"] = "verlor einen Kampf",
    ["lost to %s"] = "verlor gegen %s",
    ["Nothing on the road at this level."] = "Auf dieser Stufe blieb der Weg still.",
    ["so far"] = "bisher",
    ["someone##whom"] = "jemanden",
    ["You first saw %1$s %2$s.##zone"] = "Du sahst %1$s zum ersten Mal %2$s.",
    ["You first saw %s."] = "Du sahst %s zum ersten Mal.",
    ["You'd meet again at level %d."] = "Ihr würdet euch auf Stufe %d wiedersehen.",
    ["You'd meet again before the level was out."] = "Ihr würdet euch noch auf dieser Stufe wiedersehen.",

    -- UI/Journey/Text/Run.lua (a run's page)
    ["fourteen"] = "vierzehn",
    ["seventeen"] = "siebzehn",
    ["sixteen"] = "sechzehn",
    ["thirteen"] = "dreizehn",
    ["eighteen"] = "achtzehn",
    ["nineteen"] = "neunzehn",
    ["a minute"] = "eine Minute",
    ["%d hour|%d hours##plural"] = "%d Stunde|%d Stunden",
    ["%d minute|%d minutes##plural"] = "%d Minute|%d Minuten",
    ["%1$s %2$s##hours minutes"] = "%1$s %2$s",
    ["Level %1$d\226\128\147%2$d, %3$s"] = "Stufe %1$d\226\128\147%2$d, %3$s",
    ["Level %1$d, %2$s"] = "Stufe %1$d, %2$s",
    ["Full run"] = "Alle Bosse besiegt",
    ["%1$d out of %2$d bosses slain"] = "%1$d von %2$d Bossen besiegt",
    ["and one more|and %s more##plural"] = "und noch eins|und %s weitere",
    ["yours"] = "deins",
    ["yours at last"] = "endlich deins",
    ["someone's"] = "von jemandem",
    ["we fell twice"] = "wir fielen zweimal",
    ["we fell once|we fell %s times##plural"] = "wir fielen einmal|wir fielen %smal",
    ["%s twice"] = "%s zweimal",
    ["%s thrice"] = "%s dreimal",
    ["%1$s %2$s time|%1$s %2$s times##plural"] = "%1$s einmal|%1$s %2$smal",
    ["%1$s, and %2$s other|%1$s, and %2$s others##plural"] = "%1$s und %2$s weiterer|%1$s und %2$s weitere",
    ["you died to %s"] = "du starbst durch %s",
    ["you died"] = "du starbst",
    ["and one you didn't keep|and %s you didn't keep##plural"] =
        "und einer, den du nicht eingetragen hast|und %s, die du nicht eingetragen hast",
    ["and %d other|and %d others##plural"] = "und %d weiterer|und %d weitere",
    ["Nobody fell."] = "Niemand fiel.",
    ["No noteworthy drops."] = "Keine nennenswerte Beute.",
    ["you"] = "du",
    ["Click to open its map."] = "Klicken, um die Karte zu öffnen.",
    ["Click to open its sheet."] = "Klicken, um das Blatt zu öffnen.",
    ["A dungeon"] = "Ein Dungeon",
    ["%1$d of %2$d bosses"] = "%1$d von %2$d Bossen",

    -- UI/Journey/Text/Time.lua: a sitting's label, "25. Okt."
    ["%1$s %2$s##month day"] = "%2$s %1$s",

    -- UI/Journey/Text/Tips.lua
    ["Levels %1$d to %2$d"] = "Stufen %1$d bis %2$d",
    ["%1$s at %2$s##date"] = "%1$s um %2$s",
    ["From %1$s to %2$s##days"] = "Von %1$s bis %2$s",
    ["Today from %1$s to %2$s"] = "Heute von %1$s bis %2$s",
    ["Yesterday from %1$s to %2$s"] = "Gestern von %1$s bis %2$s",
    ["On %1$s from %2$s to %3$s"] = "Am %1$s von %2$s bis %3$s",
    ["Fought here briefly"] = "Hier kurz gekämpft",
    ["Fought here for %s"] = "Hier %s gekämpft",
    ["Fought here on and off, %s in all"] = "Hier mit Pausen gekämpft, insgesamt %s",
    ["Quested here briefly"] = "Hier kurz gequestet",
    ["Quested here for %s"] = "Hier %s gequestet",
    ["Quested here on and off, %s in all"] = "Hier mit Pausen gequestet, insgesamt %s",
    ["Rested here briefly"] = "Hier kurz gerastet",
    ["Rested here for %s"] = "Hier %s gerastet",
    ["Rested here on and off, %s in all"] = "Hier mit Pausen gerastet, insgesamt %s",
    ["Stayed here briefly"] = "Hier kurz verweilt",
    ["Stayed here for %s"] = "Hier %s verweilt",
    ["Stayed here on and off, %s in all"] = "Hier mit Pausen verweilt, insgesamt %s",
    ["Took a quest, handed in %2$d|Took %1$d quests, handed in %2$d##plural"] =
        "Eine Quest angenommen, %2$d abgegeben|%1$d Quests angenommen, %2$d abgegeben",
    ["Took a quest|Took %d quests##plural"] = "Eine Quest angenommen|%d Quests angenommen",
    ["Handed in a quest|Handed in %d quests##plural"] = "Eine Quest abgegeben|%d Quests abgegeben",
    ["fighting"] = "Kampf",
    ["questing"] = "Quests",
    ["resting"] = "Rast",
    ["A fight"] = "Ein Kampf",
    ["Fought for %s"] = "%s gekämpft",
    ["Fought for %s and died"] = "%s gekämpft und gestorben",
    ["Fought for %1$s and died %2$s"] = "%1$s gekämpft und %2$s gestorben",
    ["A stop"] = "Ein Halt",
    ["Reached %s"] = "Erreicht %s",
    ["Went in %1$s, %2$s in all"] = "Betreten: %1$s, insgesamt %2$s",
    ["Inside briefly"] = "Kurz drinnen",
    ["Inside for %s"] = "%s drinnen",
    -- a flight's way: the title "Flug nach Orgrimmar", a line "Nach
    -- Orgrimmar, zweimal" or "Ankunft aus Orgrimmar"
    ["Flew within the zone"] = "Flug innerhalb der Zone",
    ["Flew within the zone %s"] = "Flug innerhalb der Zone, %s",
    ["Within the zone"] = "Innerhalb der Zone",
    ["Within the zone %s"] = "Innerhalb der Zone, %s",
    ["Flew to another zone"] = "Flug in eine andere Zone",
    ["Flew to another zone %s"] = "Flug in eine andere Zone, %s",
    ["To another zone"] = "In eine andere Zone",
    ["To another zone %s"] = "In eine andere Zone, %s",
    ["Flew in from another zone"] = "Flug aus einer anderen Zone",
    ["Flew in from another zone %s"] = "Flug aus einer anderen Zone, %s",
    ["In from another zone"] = "Aus einer anderen Zone",
    ["In from another zone %s"] = "Aus einer anderen Zone, %s",
    ["Flew %1$s %2$s##zone"] = "Flug %1$s, %2$s",
    ["Flew %s##zone"] = "Flug %s",
    ["Flew in %1$s %2$s##zone"] = "Flug %1$s, %2$s",
    ["Flew in %s##zone"] = "Flug %s",
    ["%1$s %2$s##zone, how often"] = "%1$s, %2$s",
    ["In %1$s %2$s##zone"] = "Ankunft %1$s, %2$s",
    ["In %s##zone"] = "Ankunft %s",
    ["A flight"] = "Ein Flug",
    ["Flew out %s"] = "Abgeflogen: %s",
    ["Flew in %s##times"] = "Angekommen: %s",
    ["Flew %s##times"] = "Geflogen: %s",
    ["won a fight|won %d fights##plural"] = "einen Kampf gewonnen|%d Kämpfe gewonnen",
    ["lost one|lost %d##plural"] = "einen verloren|%d verloren",
    ["lost a fight|lost %d fights##plural"] = "einen Kampf verloren|%d Kämpfe verloren",
    ["With %1$s %2$s, %3$s in all"] = "Mit %1$s, %2$s, insgesamt %3$s",
    ["With %1$s for %2$s"] = "Mit %1$s, %2$s",
    ["With %s briefly"] = "Kurz mit %s",
    ["Together %1$s, %2$s in all"] = "Zusammen %1$s, insgesamt %2$s",
    ["Together briefly"] = "Kurz zusammen",
    ["About %s"] = "Über %s",
    ["First saw %s"] = "Zuerst gesehen: %s",
    ["First seen: %s"] = "Zuerst gesehen: %s",
    ["A fight, won"] = "Ein Kampf, gewonnen",
    ["Killed you"] = "Hat dich getötet",

    -- UI/Journey/Text/Zones.lua
    ["Map %s"] = "Karte %s",
    ["levels %1$d to %2$d"] = "Stufen %1$d bis %2$d",
    ["level %s"] = "Stufe %s",
    ["a fight|%d fights##plural"] = "ein Kampf|%d Kämpfe",
})
