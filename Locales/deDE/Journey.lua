-- German (deDE): Your Diary (UI/Journey/ and its words, UI/Journey/Text/).
-- Keys are the English text (Locales/enUS.lua), in its order.
--
-- The prose is in Präteritum, the subject dropped where the English drops it
-- ("Erreichte am 6. Oktober Stufe 12."), the tooltips and margin words in
-- Perfekt or participles, as a ledger reads. A "##zone" value arrives with
-- its preposition ("in Durotar", "bei Roter Wolkenhügel": G.PLACE), so a
-- template never writes one before it. A stop's spoken time
-- (UI/Journey/Text/Time.lua's Spoken) is in the accusative ("einen
-- Augenblick", "eine halbe Stunde"), so the templates take it as a time
-- span: "%s lang", "%s später", "%s zusammen". The sample on the empty page
-- (UI/Journey/Empty.lua) uses the German client's names.

local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- UI/Journey/Caption.lua
    ["Nothing of this level's road was kept."] = "Vom Weg dieser Stufe wurde nichts aufgezeichnet.",

    -- UI/Journey/CardPad.lua
    ["Go to the names"] = "Zu den Namen",
    ["Put the card away"] = "Karte weglegen",

    -- UI/Journey/CardSheet.lua
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

    -- UI/Journey/Empty.lua
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

    -- UI/Journey/Look.lua
    ["Left click to go back"] = "Linksklick: zurück",
    ["%s to go back"] = "%s: zurück",

    -- UI/Journey/Pad.lua
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
    ["Open the match"] = "Partie öffnen",
    ["Turn the board over"] = "Tafel umdrehen",
    ["Turn the roll over"] = "Liste umdrehen",
    ["Look along the line"] = "Die Linie entlang",
    ["Back to the line"] = "Zurück zur Zeile",

    -- UI/Journey/Page.lua
    ["Your road is not being kept just now."] = "Dein Weg wird gerade nicht aufgezeichnet.",
    ["Keep it again"] = "Wieder aufzeichnen",

    -- UI/Journey/Text/Caption.lua
    ["Somewhere"] = "Irgendwo",
    ["%1$s, %2$s##zone"] = "%1$s, %2$s",
    ["A fight, lost"] = "Ein Kampf, verloren",
    ["%s fight|%s fights##plural"] = "%s Kampf|%s Kämpfe",
    ["Where the diary began"] = "Wo das Tagebuch begann",
    ["Into a new zone for the first time"] = "Zum ersten Mal in einem neuen Gebiet",
    ["%s for the first time##zone"] = "Zum ersten Mal %s",
    ["The way into a dungeon"] = "Der Weg in einen Dungeon",
    ["The way %s##zone"] = "Der Weg %s",
    ["A long stay"] = "Ein langer Aufenthalt",
    ["Where the fighting was"] = "Wo gekämpft wurde",
    ["In good company"] = "In guter Gesellschaft",
    ["On the road"] = "Unterwegs",

    -- UI/Journey/Text/Margin.lua
    ["one more note|%s more notes##plural"] = "noch eine Notiz|noch %s Notizen",
    ["a note|%s notes##plural"] = "eine Notiz|%s Notizen",
    ["a fight, lost"] = "ein Kampf, verloren",
    ["a fight, won"] = "ein Kampf, gewonnen",
    ["you won the fight"] = "du hast den Kampf gewonnen",
    ["you'd meet again"] = "ihr würdet euch wiedersehen",
    ["you'd meet again at level %d"] = "ihr würdet euch auf Stufe %d wiedersehen",
    ["first seen, and %s"] = "zuerst gesehen, und %s",
    ["with someone"] = "mit jemandem",

    -- UI/Journey/Text/Notes.lua
    ["And one more note.|And %d more notes.##plural"] = "Und noch eine Notiz.|Und noch %d Notizen.",

    -- UI/Journey/Text/Prose.lua
    ["This diary began at level %1$d, %2$s, on %3$s.##zone"] = "Dieses Tagebuch begann am %3$s auf Stufe %1$d, %2$s.",
    ["This diary began at level %1$d, on %2$s."] = "Dieses Tagebuch begann am %2$s auf Stufe %1$d.",
    ["Week of %s"] = "Woche vom %s",
    ["Reached level %1$d %2$s, %3$s, on %4$s. The road goes on.##zone"] =
        "Erreichte am %4$s Stufe %1$d %2$s, %3$s. Der Weg geht weiter.",
    ["Reached level %1$d %2$s, on %3$s. The road goes on.##zone"] =
        "Erreichte am %3$s Stufe %1$d %2$s. Der Weg geht weiter.",
    ["Reached level %1$d, on %2$s. The road goes on."] = "Erreichte am %2$s Stufe %1$d. Der Weg geht weiter.",
    ["Your road begins here, on %1$s, %2$s.##zone"] = "Hier beginnt dein Weg, am %1$s %2$s.",
    ["Your road begins here, on %s."] = "Hier beginnt dein Weg, am %s.",
    ["Reached on %1$s %2$s, %3$s.##zone"] = "Erreicht am %1$s %2$s, %3$s.",
    ["Reached on %1$s %2$s.##zone"] = "Erreicht am %1$s %2$s.",
    ["Reached on %s."] = "Erreicht am %s.",
    ["%1$s of fighting %3$s.##zone"] = "%1$s lang Kämpfe %3$s.",
    ["%3$s kept you fighting for %2$s."] = "%3$s hielt dich %2$s lang mit Kämpfen auf.",
    ["%1$s of quests %3$s.##zone"] = "%1$s lang Quests %3$s.",
    ["Quests kept you %3$s for %2$s.##zone"] = "Quests hielten dich %2$s lang %3$s.",
    ["%1$s resting %3$s.##zone"] = "%1$s lang Rast %3$s.",
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

    -- UI/Journey/Text/Run.lua
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
    ["Level %1$d–%2$d, %3$s"] = "Stufe %1$d–%2$d, %3$s",
    ["Level %1$d, %2$s"] = "Stufe %1$d, %2$s",
    ["Full run"] = "Alle Bosse besiegt",
    ["%1$d out of %2$d bosses slain"] = "%1$d von %2$d Bossen besiegt",
    ["and one more|and %s more##plural"] = "und noch eins|und noch %s",
    ["yours"] = "deins",
    ["yours at last"] = "endlich deins",
    ["someone's"] = "von jemandem",
    ["we fell twice"] = "wir fielen zweimal",
    ["we fell once|we fell %s times##plural"] = "wir fielen einmal|wir fielen %smal",
    ["%s twice"] = "%s zweimal",
    ["%s thrice"] = "%s dreimal",
    ["%1$s %2$s time|%1$s %2$s times##plural"] = "%1$s %2$smal|%1$s %2$smal",
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

    -- UI/Journey/Text/Time.lua
    ["%s minute|%s minutes##plural"] = "%s Minute|%s Minuten",
    ["%s and a half hour|%s and a half hours##plural"] = "%seinhalb Stunde|%seinhalb Stunden",
    ["%1$s %2$s##month day"] = "%2$s %1$s",
    ["%1$s %2$s##date and year"] = "%1$s %2$s",

    -- UI/Journey/Text/Tips.lua
    ["Levels %1$d to %2$d"] = "Stufen %1$d bis %2$d",
    ["Fought here for %s"] = "Hier %s gekämpft",
    ["fighting"] = "Kampf",
    ["questing"] = "Quests",
    ["resting"] = "Rast",
    ["A stop"] = "Ein Halt",
    ["Reached %s"] = "Erreicht %s",
    ["A flight"] = "Ein Flug",
    ["About %s"] = "Über %s",
    ["First seen: %s"] = "Zuerst gesehen: %s",
    ["A fight, won"] = "Ein Kampf, gewonnen",

    -- UI/Journey/Text/Zones.lua
    ["Map %s"] = "Karte %s",
    ["levels %1$d to %2$d"] = "Stufen %1$d bis %2$d",
    ["level %s"] = "Stufe %s",
    ["a fight|%d fights##plural"] = "ein Kampf|%d Kämpfe",
})
