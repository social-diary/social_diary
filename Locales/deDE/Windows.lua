-- German (deDE): Windows. Keys are the English text (Locales/enUS.lua).
--
-- The entry page and the picker, the reunion toast, the introduction's
-- parcel and tour (UI/Windows/), the loose sheets (UI/Paper/), the shared
-- kit (UI/Kit/) and the heat-map sheet (UI/Map/). The parcel is the one
-- place the diary speaks as "ich" and jokes; everywhere else it is the
-- quiet diary of Grammar.lua.

local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- UI/Journey/CardPad.lua
    ["Stop writing"] = "Schreiben abbrechen",

    -- UI/Journey/Text/Run.lua
    ["+ Add"] = "+ Eintragen",

    -- UI/Kit/Confirm.lua
    ["Delete"] = "Löschen",
    ["Cancel"] = "Abbrechen",
    ["Delete everything Social Diary knows about %s?\n\nThis cannot be undone."] =
        "Alles löschen, was Social Diary über %s weiß?\n\nDas kann nicht rückgängig gemacht werden.",
    ["Remove %s from the diary?\n\nTheir history can stay as an ordinary character, where the buffer's retention rules apply to it again."] =
        "%s aus dem Tagebuch nehmen?\n\nWas ihr erlebt habt, kann mit Bleistift notiert bleiben und wird dann wie bei allen anderen irgendwann ausradiert.",
    ["Keep history"] = "Verlauf behalten",
    ["Delete everything"] = "Alles löschen",

    -- UI/Kit/Keys.lua
    ["That key stays with the game. Choose another."] = "Diese Taste bleibt beim Spiel. Wähle eine andere.",
    ["Not during a fight. Try again after it."] = "Nicht im Kampf. Versuch es danach noch einmal.",
    ["%1$s is set to %2$s.\n\nUse it for %3$s instead?"] =
        "%1$s ist mit %2$s belegt.\n\nStattdessen für %3$s verwenden?",
    ["Use it"] = "Verwenden",
    ["It was %s until now."] = "Bisher lag dort %s.",
    ["press a key"] = "Taste drücken",
    ["Escape to cancel"] = "Esc zum Abbrechen",
    ["Change"] = "Ändern",
    ["no key"] = "keine Taste",
    ["Choose one"] = "Taste wählen",

    -- UI/Map/HeatSheet.lua
    ["Map %d"] = "Karte %d",
    ["%1$s (%2$d)"] = "%1$s (%2$d)",
    ["Show map"] = "Karte zeigen",
    ["Everyone"] = "Alle",
    ["ALSO SEEN IN"] = "AUCH GESEHEN IN",
    ["Just %s"] = "Nur %s",
    ["Just them"] = "Nur sie",
    ["No maps yet"] = "Noch keine Karten",
    ["Nobody from your diary seen on a map yet."] = "Noch niemand aus deinem Tagebuch auf einer Karte gesehen.",
    ["Not seen on a map yet.\nThis fills in as you see them nearby."] =
        "Noch auf keiner Karte gesehen.\nDas füllt sich, sobald du sie in der Nähe siehst.",

    -- UI/Pad/Controls.lua
    ["Write"] = "Schreiben",
    ["Done writing"] = "Fertig geschrieben",
    ["Choose"] = "Wählen",
    ["Add the tag"] = "Tag setzen",
    ["Take the tag off"] = "Tag entfernen",
    ["Unlink them"] = "Verknüpfung lösen",
    ["Choose a keyboard key"] = "Taste wählen",
    ["Pick it up"] = "Aufnehmen",
    ["Stop listening"] = "Tastenwahl abbrechen",
    ["Tick"] = "Haken setzen",
    ["Untick"] = "Haken entfernen",

    -- UI/Pad/Menu.lua
    ["See the choices"] = "Auswahl ansehen",
    ["Put the menu away"] = "Menü schließen",
    ["Back to the menu"] = "Zurück zum Menü",

    -- UI/Paper/LinkSheet.lua
    ["WITH THEM THEN"] = "DAMALS DABEI",
    ["WITH THEM BEFORE"] = "SCHON FRÜHER DABEI",
    ["EVERYONE ELSE"] = "ALLE ANDEREN",
    ["Link others"] = "Weitere verknüpfen",
    ["Search names, tags, notes"] = "Namen, Tags, Notizen suchen",
    ["Nobody in the diary matches."] = "Niemand im Tagebuch passt dazu.",
    ["%d linked"] = "%d verknüpft",

    -- UI/Paper/NoteSheet.lua
    ["Unlink %s"] = "Verknüpfung mit %s lösen",
    ["ABOUT"] = "ÜBER",
    ["What happened? Write it down while you remember it."] =
        "Was ist passiert? Schreib es auf, solange du es noch weißt.",
    ["Delete this note"] = "Diese Notiz löschen",
    ["Save"] = "Speichern",
    ["Link who it is about"] = "Verknüpfen, um wen es geht",
    ["A new note"] = "Eine neue Notiz",
    ["Your note"] = "Deine Notiz",
    ["Written %s"] = "Geschrieben am %s",

    -- UI/Paper/Strip.lua
    ["“##quote open"] = "„",
    ["”##quote close"] = "“",

    -- UI/Windows/Entry.lua
    ["no interactions yet"] = "noch keine Begegnungen",
    ["%d interaction on record|%d interactions on record##plural"] = "%d Begegnung notiert|%d Begegnungen notiert",
    ["Added %1$s %2$s, %3$s##zone"] = "Eingetragen am %1$s %2$s, %3$s",
    ["Added %1$s, %2$s"] = "Eingetragen am %1$s, %2$s",
    ["What happened? What should you remember about them?"] =
        "Was ist passiert? Was willst du über sie nicht vergessen?",
    ["Tags"] = "Tags",
    ["+ add a tag"] = "+ Tag hinzufügen",
    ["Relationship"] = "Beziehung",
    ["'leveling buddy', 'weirdo', 'Sulfuras Guy', …"] =
        "‚Levelpartner‘, ‚komischer Kauz‘, ‚der mit Sulfuras‘, …",
    ["Note"] = "Notiz",
    ["Remove from the diary"] = "Aus dem Tagebuch nehmen",
    ["could not identify that character."] = "konnte diesen Charakter nicht erkennen.",
    ["|cffffffff%s|r is already in the diary."] = "|cffffffff%s|r steht schon im Tagebuch.",

    -- UI/Windows/Intro/Pad.lua
    ["Open the introduction"] = "Einführung öffnen",
    ["Put the parcel away"] = "Paket weglegen",
    ["Add Thex"] = "Thex eintragen",
    ["Open his page"] = "Seine Seite öffnen",
    ["Back to this step"] = "Zurück zu diesem Schritt",
    ["Put the introduction away"] = "Einführung weglegen",
    ["Back to the page"] = "Zurück zur Seite",

    -- UI/Windows/Intro/Scene.lua
    ["Diarywrights, Tinker Town"] = "Tagebuchmacher, Tüftlerstadt",
    ["WIZZLEBOLT & DAUGHTER"] = "WIZZLEBOLT & TOCHTER",
    ["TINKER"] = "TÜFTLER",
    ["TOWN"] = "STADT",
    ["GRIZZIK'S DIARIES"] = "GRIZZIKS TAGEBÜCHER",
    ["Ratchet, no refunds"] = "Ratschet, Umtausch ausgeschlossen",
    ["(paid in full)"] = "(voll bezahlt)",
    ["RATCHET"] = "RATSCHET",
    ["To the new owner"] = "An den neuen Besitzer",
    ["Oh — hello. I'm your new diary."] = "Oh — hallo. Ich bin dein neues Tagebuch.",
    ["Your diary, still here whenever you're ready."] = "Dein Tagebuch. Noch immer da, wann immer du so weit bist.",
    ["I write down the people you meet, all by myself, so that months from now you still know who they were. It's only pencil, until you ink someone in."] =
        "Ich schreibe die Leute auf, denen du begegnest, ganz von allein, damit du noch in Monaten weißt, wer sie waren. Alles nur mit Bleistift, bis du jemanden mit Tinte einträgst.",
    ["I've pencilled in one already.|I've pencilled in %d already.##plural"] =
        "Einen habe ich schon mit Bleistift notiert.|%d habe ich schon mit Bleistift notiert.",

    -- UI/Windows/Intro/Torn.lua
    ["Open me"] = "Öffne mich",

    -- UI/Windows/Intro/Tour.lua
    ["Continue"] = "Weiter",
    ["Social Diary"] = "Social Diary",
    ["Wherever you go, the diary marks your path. Each level you reach gets a page like this."] =
        "Wohin du auch gehst, das Tagebuch zeichnet deinen Weg auf. Jede Stufe, die du erreichst, bekommt eine Seite wie diese.",
    ["What you did"] = "Was du getan hast",
    ["Red splats show where you've fought. Memorable moments, such as finding your first green item, are shown in cards."] =
        "Rote Spritzer zeigen, wo du gekämpft hast. Besondere Momente, etwa dein erster grüner Gegenstand, stehen auf Karten.",
    ["Who you met"] = "Wem du begegnet bist",
    ["Any player you interact with, is written down automatically, like Bram and Thex. After %s their data is deleted."] =
        "Jeder Spieler, mit dem du zu tun hast, wird von selbst notiert, wie Bram und Thex. %s später wird alles über sie gelöscht.",
    ["Keep one"] = "Jemanden behalten",
    ["To keep someone for good, add them to your diary."] =
        "Um jemanden für immer zu behalten, trag ihn in dein Tagebuch ein.",
    ["Add Thex now."] = "Trag jetzt Thex ein.",
    ["Kept for good"] = "Für immer behalten",
    ["Thex is in your diary now. When you meet again, the diary will tell you."] =
        "Thex steht jetzt in deinem Tagebuch. Trefft ihr euch wieder, sagt es dir das Tagebuch.",
    ["Click him to see his page."] = "Klick auf ihn, um seine Seite zu sehen.",
    ["Wolfskin Bracers"] = "Wolfsfellarmschienen",
    ["%d of 5"] = "%d von 5",
    ["An Example"] = "Ein Beispiel",
    ["This is how the people you add will look."] = "So sehen die Leute aus, die du einträgst.",
    ["Begin your own diary"] = "Beginne dein eigenes Tagebuch",

    -- UI/Windows/Intro/Wrapped.lua
    ["Tear it open"] = "Aufreißen",
    ["Later"] = "Später",

    -- UI/Windows/Pad.lua
    ["Put the page away"] = "Seite weglegen",
    ["Remember them"] = "Ins Tagebuch eintragen",
    ["Put the list away"] = "Liste weglegen",

    -- UI/Windows/Picker.lua
    ["Remember this"] = "Ins Tagebuch eintragen",
    ["Click somebody to add them. Already in the diary opens their entry."] =
        "Klick auf jemanden, um ihn einzutragen. Wer schon im Tagebuch steht, öffnet seinen Eintrag.",
    ["Nobody to remember right now. Target someone, or interact with them first."] =
        "Gerade ist niemand zum Eintragen da. Nimm jemanden ins Ziel oder begegne ihm zuerst.",

    -- UI/Windows/Reunion/Placing.lua
    ["the toast can be moved once the fight is over."] = "kann die Einblendung erst nach dem Kampf verschieben.",

    -- UI/Windows/Reunion/Toast.lua
    ["Drag to move it"] = "Ziehen, um sie zu verschieben",
    ["Click to open the diary"] = "Klicken, um das Tagebuch zu öffnen",
    ["Click to open their page in the diary"] = "Klicken, um die Seite im Tagebuch zu öffnen",
    ["Right-click to put it away"] = "Rechtsklick, um sie wegzulegen",
    ["Put it back"] = "Zurücklegen",

    -- UI/Windows/Reunion/Words.lua
    ["Joined your group"] = "Deiner Gruppe beigetreten",
    ["Nearby"] = "In der Nähe",
    ["Nearby and in your group"] = "In der Nähe und in deiner Gruppe",
    ["On your side"] = "Auf deiner Seite",
    ["In this battleground"] = "Auf diesem Schlachtfeld",
    ["from your diary joined your group too."] = "aus deinem Tagebuch sind auch deiner Gruppe beigetreten.",
    ["from your diary are nearby too."] = "aus deinem Tagebuch sind auch in der Nähe.",
    ["from your diary are about too."] = "aus deinem Tagebuch sind auch unterwegs.",
    ["from your diary are in this battleground too."] = "aus deinem Tagebuch sind auch auf diesem Schlachtfeld.",
    ["A foe joined your group"] = "Ein Feind in deiner Gruppe",
    ["A foe, nearby"] = "Ein Feind, in der Nähe",
    ["A foe, on your side"] = "Ein Feind, auf deiner Seite",
    ["A foe, against you"] = "Ein Feind, gegen dich",
    ["A foe in this battleground"] = "Ein Feind auf diesem Schlachtfeld",
    ["Someone to avoid joined your group"] = "Zu meiden: in deiner Gruppe",
    ["Someone to avoid, nearby"] = "Zu meiden: in der Nähe",
    ["Someone to avoid, on your side"] = "Zu meiden: auf deiner Seite",
    ["Someone to avoid, against you"] = "Zu meiden: auf der Gegenseite",
    ["Someone to avoid in this battleground"] = "Zu meiden: auf diesem Schlachtfeld",
    ["on %s"] = "am %s",
    ["No blood between you yet."] = "Zwischen euch ist noch kein Blut geflossen.",
    ["%1$s Last fight %2$s %3$s.##zone"] = "%1$s Letzter Kampf %2$s %3$s.",
    ["%1$s Last fight %2$s."] = "%1$s Letzter Kampf %2$s.",
    ["You've only seen them in passing so far."] = "Bisher hast du sie nur im Vorbeigehen gesehen.",
    ["Your first time together since you wrote them in."] = "Zum ersten Mal zusammen, seit du sie eingetragen hast.",
    ["You've met once, %1$s %2$s.##zone"] = "Ihr habt euch einmal getroffen, %1$s %2$s.",
    ["You've met once, %s."] = "Ihr habt euch einmal getroffen, %s.",
    ["You've crossed paths %1$s, last %2$s %3$s.##zone"] = "Eure Wege haben sich %1$s gekreuzt, zuletzt %2$s %3$s.",
    ["You've crossed paths %1$s, last %2$s."] = "Eure Wege haben sich %1$s gekreuzt, zuletzt %2$s.",
    ["Your %1$s match with them, %2$s.##zone"] = "Deine %1$s Partie mit ihnen, %2$s.",
    ["Your %s match with them."] = "Deine %s Partie mit ihnen.",
    ["Your %1$s match against them, %2$s.##zone"] = "Deine %1$s Partie gegen sie, %2$s.",
    ["Your %s match against them."] = "Deine %s Partie gegen sie.",
    ["Somewhere %s.##zone"] = "Irgendwo %s.",
    ["Placing the toast"] = "Einblendung platzieren",
    ["Your toasts"] = "Deine Einblendungen",
    ["will appear where you leave this card."] = "erscheinen dort, wo du diese Karte ablegst.",
    ["%1$s %2$s##sentences"] = "%1$s %2$s",
})
