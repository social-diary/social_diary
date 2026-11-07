-- German (deDE): Your Diary (UI/Journey/ and its words, UI/Journey/Text/).
-- Keys are the English text (Locales/enUS.lua).
--
-- The prose is in Präteritum, the subject dropped where the English drops it
-- ("Erreichte am 6. Oktober Stufe 12."), the tooltips and margin words in
-- Perfekt or participles, as a ledger reads. Names the game gives (zones,
-- subzones, dungeons) can carry their own article, so a template puts them
-- as the subject or after a preposition that reads without one where it can.
-- A stop's spoken time (UI/Journey/Text/Time.lua's Spoken) is in the
-- accusative ("einen Augenblick", "eine halbe Stunde"), so the templates
-- take it as a time span: "%s lang", "%s später", "%s zusammen".

local addonName, ns = ...

if ns.Locale.Is("deDE") then
    -- A rubric's capitals (Text.Upper): string.upper leaves the umlauts.
    local UPPER = { ["ä"] = "Ä", ["ö"] = "Ö", ["ü"] = "Ü" }
    ns.Locale.grammar.JourneyUpper = function(text)
        return (text:upper():gsub("\195[\164\182\188]", UPPER))
    end
end

ns.Locale.Add("deDE", {
    -- UI/Journey/Text/Time.lua: a sitting's label, "25. Okt."
    ["%1$s %2$s##month day"] = "%2$s %1$s",

    -- UI/Journey/Text/Notes.lua
    ["And one more note."] = "Und noch eine Notiz.",
    ["And %d more notes."] = "Und noch %d Notizen.",

    -- UI/Journey/Text/Prose.lua
    ["This diary began at level %1$d, in %2$s, on %3$s."] = "Dieses Tagebuch begann am %3$s auf Stufe %1$d, in %2$s.",
    ["This diary began at level %1$d, on %2$s."] = "Dieses Tagebuch begann am %2$s auf Stufe %1$d.",
    ["Week of %s"] = "Woche vom %s",
    ["Reached level %1$d in %2$s, on %3$s. The road goes on."] =
        "Erreichte am %3$s in %2$s Stufe %1$d. Der Weg geht weiter.",
    ["Reached level %1$d, on %2$s. The road goes on."] = "Erreichte am %2$s Stufe %1$d. Der Weg geht weiter.",
    ["Your road begins here, on %1$s, in %2$s."] = "Hier beginnt dein Weg, am %1$s, in %2$s.",
    ["Your road begins here, on %s."] = "Hier beginnt dein Weg, am %s.",
    ["Reached on %1$s in %2$s."] = "Erreicht am %1$s in %2$s.",
    ["Reached on %s."] = "Erreicht am %s.",
    -- the stops: %1$s the time capitalised, %2$s as is, %3$s the place
    ["%1$s of fighting at %3$s."] = "%1$s lang Kämpfe bei %3$s.",
    ["%3$s kept you fighting for %2$s."] = "%3$s hielt dich %2$s lang mit Kämpfen auf.",
    ["%1$s of quests round %3$s."] = "%1$s lang Quests rund um %3$s.",
    ["Quests kept you at %3$s for %2$s."] = "%3$s hielt dich %2$s lang mit Quests fest.",
    ["%1$s resting at %3$s."] = "%1$s Rast bei %3$s.",
    ["You rested %2$s at %3$s."] = "%3$s bot dir %2$s lang Rast.",
    ["%1$s at %3$s."] = "%1$s bei %3$s.",
    ["You lingered at %3$s for %2$s."] = "Du verweiltest %2$s lang in %3$s.",
    ["fighting near %s"] = "Kämpfe bei %s",
    ["quests at %s"] = "Quests in %s",
    ["a rest at %s"] = "eine Rast in %s",
    ["Later, %s."] = "Später %s.",
    ["After that, %s."] = "Danach %s.",
    ["Flew to %s."] = "Flog nach %s.",
    ["%1$s for %2$s##with"] = "%1$s, %2$s lang",
    ["%s briefly"] = "%s kurz",
    ["With %s."] = "Mit %s.",
    ["beat %s"] = "besiegte %s",
    ["won a fight"] = "gewann einen Kampf",
    ["lost to %s"] = "verlor gegen %s",
    ["lost a fight"] = "verlor einen Kampf",
    ["Nothing on the road at this level."] = "Auf dieser Stufe blieb der Weg still.",
    ["so far"] = "bisher",
    ["someone##whom"] = "jemanden",
    ["You first saw %1$s in %2$s."] = "Du sahst %1$s zum ersten Mal in %2$s.",
    ["You first saw %s."] = "Du sahst %s zum ersten Mal.",
    ["You'd meet again at level %d."] = "Ihr würdet euch auf Stufe %d wiedersehen.",
    ["You'd meet again before the level was out."] = "Ihr würdet euch noch auf dieser Stufe wiedersehen.",

    -- UI/Journey/Text/Zones.lua
    ["Map %s"] = "Karte %s",
    ["levels %1$d to %2$d"] = "Stufen %1$d bis %2$d",
    ["level %s"] = "Stufe %s",
    ["a fight"] = "ein Kampf",
    ["%d fights"] = "%d Kämpfe",

    -- UI/Journey/Text/Tips.lua
    ["mostly fighting"] = "meist gekämpft",
    ["questing##deed"] = "gequestet",
    ["resting##deed"] = "gerastet",
    ["With someone"] = "Mit jemandem",
    ["About %s"] = "Über %s",
    ["fighting"] = "Kampf",
    ["questing"] = "Quests",
    ["resting"] = "Rast",
    ["Under a minute"] = "Unter einer Minute",
    ["Fought here for %s"] = "Hier %s gekämpft",
    ["Fought here"] = "Hier gekämpft",
    ["Took a quest"] = "Eine Quest angenommen",
    ["Took %d quests"] = "%d Quests angenommen",
    ["Handed in a quest"] = "Eine Quest abgegeben",
    ["Handed in %d quests"] = "%d Quests abgegeben",
    ["Levels %1$d to %2$d"] = "Stufen %1$d bis %2$d",
    ["And one more short stay close by"] = "Und ein weiterer kurzer Halt in der Nähe",
    ["And %d more short stays close by"] = "Und %d weitere kurze Halte in der Nähe",
    ["A stop"] = "Ein Halt",
    ["Reached %s"] = "Erreicht %s",
    ["Flew to %s"] = "Flug nach %s",
    ["Flew in from %s"] = "Flug aus %s",
    ["A flight"] = "Ein Flug",
    ["First seen: %s"] = "Zuerst gesehen: %s",
    ["first seen"] = "zuerst gesehen",
    ["a fight, won"] = "ein Kampf, gewonnen",
    ["Quested here"] = "Hier gequestet",
    ["Rested here"] = "Hier gerastet",
    ["Stayed here"] = "Hier verweilt",
    ["under a minute"] = "unter einer Minute",

    -- UI/Journey/Text/Caption.lua
    ["Somewhere"] = "Irgendwo",
    ["%1$s, in %2$s"] = "%1$s, in %2$s",
    ["A fight, won"] = "Ein Kampf, gewonnen",
    ["A fight, lost"] = "Ein Kampf, verloren",
    ["%s fights"] = "%s Kämpfe",
    ["Where the diary began"] = "Wo das Tagebuch begann",
    ["Into a new zone for the first time"] = "Zum ersten Mal in einer neuen Zone",
    ["Into %s for the first time"] = "Zum ersten Mal in %s",
    ["The way into a dungeon"] = "Der Weg in einen Dungeon",
    ["The way into %s"] = "Der Weg hinein: %s",
    ["A long stay"] = "Ein langer Aufenthalt",
    ["Where the fighting was"] = "Wo gekämpft wurde",
    ["In good company"] = "In guter Gesellschaft",
    ["On the road"] = "Unterwegs",

    -- UI/Journey/Text/Margin.lua
    ["one more note"] = "noch eine Notiz",
    ["%s more notes"] = "noch %s Notizen",
    ["a note"] = "eine Notiz",
    ["%s notes"] = "%s Notizen",
    ["a fight, lost"] = "ein Kampf, verloren",
    ["you won the fight"] = "du hast den Kampf gewonnen",
    ["you'd meet again at level %d"] = "ihr würdet euch auf Stufe %d wiedersehen",
    ["you'd meet again"] = "ihr würdet euch wiedersehen",
    ["first seen  \194\183  %s"] = "zuerst gesehen  \194\183  %s",
    ["with someone"] = "mit jemandem",

    -- UI/Journey/Text/Run.lua (a run's page)
    ["thirteen"] = "dreizehn",
    ["fourteen"] = "vierzehn",
    ["sixteen"] = "sechzehn",
    ["seventeen"] = "siebzehn",
    ["eighteen"] = "achtzehn",
    ["nineteen"] = "neunzehn",
    ["a minute"] = "eine Minute",
    ["1 hour"] = "1 Stunde",
    ["%d hours"] = "%d Stunden",
    ["1 minute"] = "1 Minute",
    ["%d minutes"] = "%d Minuten",
    ["%1$s %2$s##hours minutes"] = "%1$s %2$s",
    ["Level %1$d\226\128\147%2$d, %3$s"] = "Stufe %1$d\226\128\147%2$d, %3$s",
    ["Level %1$d, %2$s"] = "Stufe %1$d, %2$s",
    ["Full run"] = "Alle Bosse besiegt",
    ["%1$d out of %2$d bosses slain"] = "%1$d von %2$d Bossen besiegt",
    ["and one more"] = "und noch eins",
    ["and %s more"] = "und %s weitere",
    ["yours at last"] = "endlich deins",
    ["yours"] = "deins",
    ["someone's"] = "von jemandem",
    ["we fell once"] = "wir fielen einmal",
    ["we fell twice"] = "wir fielen zweimal",
    ["we fell %s times"] = "wir fielen %smal",
    ["%s twice"] = "%s zweimal",
    ["%s thrice"] = "%s dreimal",
    ["%1$s %2$s times"] = "%1$s %2$smal",
    ["%s, and one other"] = "%s und ein weiterer",
    ["%1$s, and %2$s others"] = "%1$s und %2$s weitere",
    ["you died to %s"] = "du starbst durch %s",
    ["you died"] = "du starbst",
    ["and one you didn't keep"] = "und einer, den du nicht eingetragen hast",
    ["and %s you didn't keep"] = "und %s, die du nicht eingetragen hast",
    ["and 1 other"] = "und 1 weiterer",
    ["and %d others"] = "und %d weitere",
    ["Nobody fell."] = "Niemand fiel.",
    ["No noteworthy drops."] = "Keine nennenswerte Beute.",
    ["you"] = "du",
    ["Click to open its map."] = "Klicken, um die Karte zu öffnen.",
    ["Click to open its sheet."] = "Klicken, um das Blatt zu öffnen.",
    ["A dungeon"] = "Ein Dungeon",
    ["1 death"] = "1 Tod",
    ["%d deaths"] = "%d Tode",

    -- UI/Journey/Look.lua
    ["Left click to go back"] = "Linksklick: zurück",

    -- UI/Journey/Caption.lua
    ["Nothing of this level's road was kept."] = "Vom Weg dieser Stufe wurde nichts aufgezeichnet.",

    -- UI/Journey/Full.lua
    ["Nothing of your road is on this map yet."] = "Auf dieser Karte ist noch nichts von deinem Weg.",

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
    ["The Barrens"] = "Brachland",
    ["1 h 20"] = "1:20 Std.",
    ["Stonetalon Mountains"] = "Steinkrallengebirge",
    ["40 min"] = "40 Min.",
    ["Your road starts here"] = "Hier beginnt dein Weg",
    ["Not keeping your road"] = "Dein Weg wird nicht aufgezeichnet",
    ["Nothing is on it yet. From now on the diary keeps where this character goes: the places you stay a while, the roads between, flights and dungeons, and who you were with."] =
        "Noch steht nichts darauf. Ab jetzt zeichnet das Tagebuch auf, wohin dieser Charakter geht: die Orte, an denen du eine Weile bleibst, die Wege dazwischen, Flüge und Dungeons, und mit wem du unterwegs warst.",
    ["The diary is not keeping this character's road just now, so there is nothing to tell here yet."] =
        "Das Tagebuch zeichnet den Weg dieses Charakters gerade nicht auf, darum gibt es hier noch nichts zu erzählen.",

    -- UI/Journey/Page.lua
    ["Your road is not being kept just now."] = "Dein Weg wird gerade nicht aufgezeichnet.",
    ["Keep it again"] = "Wieder aufzeichnen",

    -- UI/Journey/CardSheet.lua (the custom cards' form)
    ["Combat"] = "Kampf",
    ["Quests and Lore"] = "Quests und Geschichten",
    ["Social"] = "Soziales",
    ["Other"] = "Anderes",
    ["Add custom event..."] = "Eigenes Ereignis hinzufügen …",
    ["What happened here?"] = "Was ist hier passiert?",
    ["Choose another"] = "Etwas anderes wählen",
    ["Which one?"] = "Welches?",
    ["Left out of this page"] = "Auf dieser Seite weggelassen",
    ["Leave it out"] = "Weglassen",
    ["Undo my changes"] = "Meine Änderungen zurücknehmen",
    ["Delete this card"] = "Diese Karte löschen",
    ["Delete this card you wrote?\n\nIt comes off the map and the page. This cannot be undone."] =
        "Diese Karte löschen, die du geschrieben hast?\n\nSie verschwindet von der Landkarte und von der Seite. Das kann nicht rückgängig gemacht werden.",
})
