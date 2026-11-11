-- German (deDE): Settings. Keys are the English text (Locales/enUS.lua).
-- The Settings page and its sections, the Blizzard hooks (tooltip, Social
-- tab, signpost, key bindings, minimap button) and the Style's capitals.

local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- UI/Blizzard/Minimap.lua
    ["Click to open or close the journal."] = "Klicken, um das Tagebuch zu öffnen oder zu schließen.",
    ["Right-click to open the settings."] = "Rechtsklick, um die Einstellungen zu öffnen.",
    ["Drag to move this button."] = "Ziehen, um diese Schaltfläche zu verschieben.",

    -- UI/Blizzard/Signpost.lua
    ["The settings live in your journal now, behind the grey ribbon at the bottom of the book."] =
        "Die Einstellungen stehen jetzt in deinem Tagebuch, hinter dem grauen Lesebändchen unten am Buch.",
    ["Open the settings"] = "Einstellungen öffnen",

    -- UI/Blizzard/SocialTab.lua
    ["Open your journal."] = "Öffne dein Tagebuch.",

    -- UI/Blizzard/Tooltip.lua
    ["Seen %1$s, last %2$s"] = "%1$s gesehen, zuletzt %2$s",
    ["in your diary"] = "in deinem Tagebuch",
    ["|cffffd100Diary:|r %s"] = "|cffffd100Tagebuch:|r %s",
    ["Met %1$d time, last %2$s|Met %1$d times, last %2$s##plural"] =
        "Einmal getroffen, zuletzt %2$s|%1$d-mal getroffen, zuletzt %2$s",

    -- UI/Journal/Nearby.lua
    ["Notice who passes you in the open world"] = "Bemerken, wer in der offenen Welt an dir vorbeikommt",
    ["Recording"] = "Aufzeichnung",

    -- UI/Journey/Empty.lua
    ["Keep my own route"] = "Meine eigene Route aufzeichnen",

    -- UI/Settings/Macro.lua
    ["Open Social Diary"] = "Social Diary öffnen",
    ["Your macros are full, so there is no room for it. %s works anywhere, typed in chat."] =
        "Deine Makros sind voll, es ist kein Platz mehr dafür. %s funktioniert überall, im Chat eingegeben.",
    ["Place it in your action bars."] = "Lege es in deine Aktionsleisten.",
    ["place it with your mouse in a slot on your controller's action bar."] =
        "Lege es mit der Maus auf einen Platz in der Aktionsleiste deines Controllers.",
    ["Drag onto an action bar."] = "Auf eine Aktionsleiste ziehen.",
    ["Place it in a slot on your controller's action bar."] =
        "Auf einen Platz in der Aktionsleiste deines Controllers legen.",
    ["Pick up the Macro with %s, then place it in a slot on your controller's action bar."] =
        "Nimm das Makro mit %s auf und lege es dann auf einen Platz in der Aktionsleiste deines Controllers.",
    ["Pick up a Macro with %s, then place it in a slot on your controller's action bar."] =
        "Nimm ein Makro mit %s auf und lege es dann auf einen Platz in der Aktionsleiste deines Controllers.",

    -- UI/Settings/Pad.lua
    ["Go to the page"] = "Zur Seite",
    ["Less or more"] = "Weniger oder mehr",
    ["Back to the sections"] = "Zurück zu den Abschnitten",
    ["Go to the sections"] = "Zu den Abschnitten",
    ["Read on"] = "Weiterlesen",

    -- UI/Settings/Page.lua
    ["Settings"] = "Einstellungen",
    ["Show the introduction again"] = "Die Einführung noch einmal zeigen",

    -- UI/Settings/Quiet.lua
    ["%d quiet"] = "%d ohne Einblendung",
    ["Nobody in the diary yet."] = "Noch niemand im Tagebuch.",
    ["Nobody yet. Search your diary above to choose who."] =
        "Noch niemand. Durchsuche oben dein Tagebuch, um jemanden auszuwählen.",
    ["Search your diary"] = "Tagebuch durchsuchen",

    -- UI/Settings/Sections/About.lua
    ["About"] = "Über",

    -- UI/Settings/Sections/Battlegrounds.lua
    ["%1$d of %2$d kept whole so far. In %3$d match, the oldest begin to lose their strangers.|%1$d of %2$d kept whole so far. In %3$d matches, the oldest begin to lose their strangers.##plural"] =
        "Bisher %1$d von %2$d ganz erhalten. Noch %3$d Partie, dann verlieren die ältesten ihre Fremden.|Bisher %1$d von %2$d ganz erhalten. Noch %3$d Partien, dann verlieren die ältesten ihre Fremden.",
    ["The newest %d are kept whole. Older ones keep only the people from your diary.|The newest %d are kept whole. Older ones keep only the people from your diary.##plural"] =
        "Die neueste bleibt ganz erhalten. Ältere behalten nur die Leute aus deinem Tagebuch.|Die %d neuesten bleiben ganz erhalten. Ältere behalten nur die Leute aus deinem Tagebuch.",
    ["Scoreboards"] = "Punktetafeln",
    ["Keep the whole scoreboard for this many matches"] = "Ganze Punktetafel für so viele Partien behalten",
    ["Older matches keep their map, result and times, and the people from your diary. Everyone else is rubbed out, leaving only a count."] =
        "Ältere Partien behalten Karte, Ergebnis und Zeiten und die Leute aus deinem Tagebuch. Alle anderen werden ausradiert, nur ihre Zahl bleibt.",
    ["Warnings"] = "Warnungen",
    ["Warn me before old scoreboards lose their strangers"] = "Warnen, bevor alte Punktetafeln ihre Fremden verlieren",
    ["A hint in the diary 25 matches before, and again as it nears. Applies to every character."] =
        "Ein Hinweis im Tagebuch 25 Partien vorher und noch einmal kurz davor. Gilt für alle Charaktere.",

    -- UI/Settings/Sections/Changelog.lua
    ["The full history is on CurseForge and GitHub."] = "Die ganze Versionsgeschichte steht auf CurseForge und GitHub.",
    ["Thanks to %s"] = "Danke an %s",
    ["Version %s"] = "Version %s",
    ["Shiny new Things"] = "Glänzend Neues",
    ["Changes"] = "Änderungen",
    ["Fixes"] = "Korrekturen",
    ["Changelog"] = "Versionshinweise",

    -- UI/Settings/Sections/Credits.lua
    ["Social Diary is released under the GNU General Public License v3 or later. Versions up to 1.7.0 were under the MIT License."] =
        "Social Diary steht unter der GNU General Public License v3 oder neuer. Versionen bis 1.7.0 standen unter der MIT-Lizenz.",
    ["Dungeon maps, bosses, routes and loot tables: Dungeon Crawler Forever by Per, GPL v3 or later."] =
        "Dungeonkarten, Bosse, Routen und Beutetabellen: Dungeon Crawler Forever von Per, GPL v3 oder neuer.",
    ["Creature positions along dungeon routes: TrinityCore and VMaNGOS, via advocaite/TrinityCore, GPL v2 or later."] =
        "Positionen der Kreaturen entlang der Dungeonrouten: TrinityCore und VMaNGOS, über advocaite/TrinityCore, GPL v2 oder neuer.",
    ["The Neuton Italic font: SIL Open Font License 1.1."] = "Die Schrift Neuton Italic: SIL Open Font License 1.1.",
    ["Questie and QuestieDB, which Social Diary reads from while the game runs, if you have them installed."] =
        "Questie und QuestieDB, aus denen Social Diary liest, während das Spiel läuft, falls du sie installiert hast.",
    ["Map art by %1$s, for %2$s."] = "Kartenzeichnungen von %1$s, für %2$s.",
    ["Map art by %s."] = "Kartenzeichnungen von %s.",
    ["Thanks"] = "Dank",
    ["Willing impromptu Beta Testers:"] = "Spontane, bereitwillige Betatester:",
    ["Licensing"] = "Lizenzen",
    ["Credits"] = "Danksagungen",

    -- UI/Settings/Sections/Dungeons.lua
    ["Dungeon maps"] = "Dungeonkarten",
    ["Show the usual way through on each map"] = "Den üblichen Weg auf jeder Karte zeigen",
    ["The diary can't follow you inside, so it inks the usual way up to the furthest boss you killed and pencils the rest."] =
        "Das Tagebuch kann dir nicht hinein folgen. Darum zieht es den üblichen Weg bis zum letzten Boss, den du besiegt hast, mit Tinte nach und skizziert den Rest mit Bleistift.",
    ["Open the diary on the map of the run you’re in"] =
        "Das Tagebuch auf der Karte deines aktuellen Durchlaufs öffnen",
    ["Only inside a dungeon or raid. Anywhere else, the diary opens where you left it."] =
        "Nur in einem Dungeon oder Schlachtzug. Überall sonst öffnet sich das Tagebuch dort, wo du es verlassen hast.",
    ["Dungeons and Raids"] = "Dungeons und Schlachtzüge",

    -- UI/Settings/Sections/Feedback.lua
    ["Bugs and ideas"] = "Fehler und Ideen",
    ["Report a bug or suggest an idea on GitHub."] = "Melde einen Fehler oder schlage eine Idee auf GitHub vor.",
    ["Comments"] = "Kommentare",
    ["Leave a comment on CurseForge."] = "Hinterlasse einen Kommentar auf CurseForge.",
    ["Copy and Paste this link"] = "Diesen Link kopieren und einfügen",
    ["You are on version |cff%1$s%2$s|r."] = "Du nutzt Version |cff%1$s%2$s|r.",
    ["If something breaks, try to write down what happened as precisely as possible!"] =
        "Wenn etwas nicht funktioniert, schreib so genau wie möglich auf, was passiert ist.",
    ["Reporting a bug"] = "Einen Fehler melden",
    ["Feedback"] = "Rückmeldung",

    -- UI/Settings/Sections/Integrations.lua
    ["Questie installed"] = "Questie installiert",
    ["Mobs get their real names and quest drops are checked against real drop rates. Social Diary only reads from it."] =
        "Kreaturen bekommen ihre echten Namen, und Questbeute wird mit den echten Dropchancen abgeglichen. Social Diary liest nur daraus.",
    ["Found, but this version isn't supported."] = "Gefunden, aber diese Version wird nicht unterstützt.",
    ["Deathlog installed"] = "Deathlog installiert",
    ["Adds permadeath notes in Hardcore. Not available until Hardcore is released."] =
        "Ergänzt Notizen zum endgültigen Tod im Hardcore-Modus. Erst verfügbar, wenn Hardcore erscheint.",
    ["Total RP 3 installed"] = "Total RP 3 installiert",
    ["Adds RP profile data to diary entries. Not available until it's ported to Forever."] =
        "Ergänzt Tagebucheinträge um RP-Profile. Erst verfügbar, wenn es für Forever umgesetzt ist.",
    ["Integrations"] = "Integrationen",

    -- UI/Settings/Sections/Interface.lua
    ["Tooltips"] = "Tooltips",
    ["Add diary lines to player tooltips"] = "Tagebuchzeilen in Spieler-Tooltips zeigen",
    ["For everyone else, how often you have seen them"] = "Bei allen anderen, wie oft du sie gesehen hast",
    ["Minimap"] = "Minikarte",
    ["Show a button on the minimap"] = "Eine Schaltfläche an der Minikarte zeigen",
    ["Look and Feel"] = "Aussehen",
    ["Paper Texture Intensity"] = "Papierstruktur",
    ["Diary Size"] = "Tagebuchgröße",
    ["On a smaller screen, the diary grows only as large as fits. Applies to every character."] =
        "Auf einem kleineren Bildschirm wird das Tagebuch nur so groß, wie es passt. Gilt für alle Charaktere.",
    ["Simulate Page Turns"] = "Seiten umblättern",
    ["New Diary entries add pages, and the book turns to the new page."] =
        "Neue Einträge fügen Seiten hinzu, und das Buch blättert zur neuen Seite um.",
    ["Flat paper only"] = "Nur glattes Papier",
    ["No folds or bends on the sheets, and a person’s name sits straight on their page."] =
        "Keine Falten oder Knicke in den Blättern, und der Name einer Person steht gerade auf ihrer Seite.",
    ["Use fully discovered map for map sheets"] = "Vollständig aufgedeckte Karte für Kartenblätter",
    ["Hints"] = "Hinweise",
    ["Show hints about things you may have missed"] = "Hinweise auf Dinge zeigen, die du übersehen haben könntest",
    ["Now and then a small note on the page points something out. Applies to every character."] =
        "Hin und wieder weist eine kleine Notiz auf der Seite auf etwas hin. Gilt für alle Charaktere.",
    ["the hints come again, each the next time its page is open."] =
        "die Hinweise kommen wieder, jeder beim nächsten Öffnen seiner Seite.",
    ["Show hints again"] = "Hinweise erneut zeigen",
    ["Show a hint after a big update"] = "Nach einem großen Update einen Hinweis zeigen",
    ["When a new major version such as 3.0 is installed, the book points you to what changed. Applies to every character."] =
        "Ist eine neue Hauptversion wie 3.0 installiert, zeigt dir das Buch, was sich geändert hat. Gilt für alle Charaktere.",
    ["Interface"] = "Oberfläche",

    -- UI/Settings/Sections/Language.lua
    ["The game's language"] = "Sprache des Spiels",
    ["The game's language (%s)"] = "Sprache des Spiels (%s)",
    ["Write the diary in %s?\n\nThe interface reloads, and the diary's own words are then in that language. Your notes stay as you wrote them."] =
        "Das Tagebuch auf %s schreiben?\n\nDie Oberfläche wird neu geladen, danach schreibt das Tagebuch in dieser Sprache. Deine Notizen bleiben, wie du sie geschrieben hast.",
    ["Change the Diary's Language"] = "Sprache des Tagebuchs ändern",
    ["Switching requires a reload. Applies to every character."] =
        "Der Wechsel lädt die Oberfläche neu. Gilt für alle Charaktere.",
    ["Names the game supplies, such as zones, classes and items, stay in the game's language."] =
        "Namen aus dem Spiel, etwa Gebiete, Klassen und Gegenstände, bleiben in der Sprache des Spiels.",
    ["The diary has no words for the game's language yet, so it is written in English."] =
        "Für die Sprache des Spiels hat das Tagebuch noch keine Worte, darum schreibt es auf Englisch.",
    ["Reload"] = "Neu laden",
    ["Translations"] = "Übersetzungen",
    ["Every language but English was machine-translated, so some lines may read oddly or wrongly. Text clipping is likely to occur also. Corrections are welcome."] =
        "Alle Sprachen außer Englisch wurden maschinell übersetzt, manche Zeilen lesen sich darum seltsam oder sind falsch. Auch abgeschnittener Text ist wahrscheinlich. Korrekturen sind willkommen.",
    ["Go to Feedback"] = "Zur Rückmeldung",
    ["The diary can't change language on this game client, because your choice reaches it too late. It stays in the game's language."] =
        "Auf diesem Spielclient kann das Tagebuch die Sprache nicht wechseln, weil deine Wahl es zu spät erreicht. Es bleibt in der Sprache des Spiels.",
    ["The diary is written in %s once the interface reloads."] =
        "Nach dem Neuladen der Oberfläche schreibt das Tagebuch auf %s.",
    ["Language"] = "Sprache",

    -- UI/Settings/Sections/Memory.lua
    ["%1$d in the diary, %2$s, %3$s, %4$s and %5$s.  About %6$d KB on disk."] =
        "%1$d im Tagebuch, %2$s, %3$s, %4$s und %5$s.  Etwa %6$d KB auf der Festplatte.",
    ["%d character known|%d characters known##plural"] = "%d Charakter bekannt|%d Charaktere bekannt",
    ["%d session|%d sessions##plural"] = "%d Sitzung|%d Sitzungen",
    ["%d interaction|%d interactions##plural"] = "%d Begegnung|%d Begegnungen",
    ["%d sighting|%d sightings##plural"] = "%d Sichtung|%d Sichtungen",
    ["Over %d MB: a lot to read at every login and /reload. Your diary keeps its history for good, so lowering the maximum chat lines (Recording) or deleting sightings is what brings it down."] =
        "Über %d MB: viel zu lesen bei jedem Login und /reload. Dein Tagebuch behält seine Geschichte für immer. Weniger Chatzeilen (Aufzeichnung) oder das Löschen der Sichtungen machen es wieder kleiner.",
    ["The shared diary is stored only on this computer, in %s. Nothing is sent to other players or to any server."] =
        "Das gemeinsame Tagebuch liegt nur auf diesem Computer, in %s. Nichts wird an andere Spieler oder an einen Server gesendet.",
    ["This character's diary is stored only on this computer, in %s. Nothing is sent to other players or to any server."] =
        "Das Tagebuch dieses Charakters liegt nur auf diesem Computer, in %s. Nichts wird an andere Spieler oder an einen Server gesendet.",
    ["Delete the shared diary?\n\nEvery diary entry, note, session and interaction your characters wrote in it goes, and every character's road in it. Your settings, and any diary a character keeps of its own, are kept. This cannot be undone."] =
        "Das gemeinsame Tagebuch löschen?\n\nJeder Eintrag, jede Notiz, Sitzung und Begegnung, die deine Charaktere darin festgehalten haben, geht verloren, ebenso der Weg jedes Charakters darin. Deine Einstellungen und jedes eigene Tagebuch eines Charakters bleiben erhalten. Das kann nicht rückgängig gemacht werden.",
    ["Delete this character's diary?\n\nEvery diary entry, note, session and interaction it recorded goes, and its road. Your settings, and your other characters' diaries, are kept. This cannot be undone."] =
        "Das Tagebuch dieses Charakters löschen?\n\nJeder Eintrag, jede Notiz, Sitzung und Begegnung, die er festgehalten hat, geht verloren, ebenso sein Weg. Deine Einstellungen und die Tagebücher deiner anderen Charaktere bleiben erhalten. Das kann nicht rückgängig gemacht werden.",
    ["Share one diary between all your characters?\n\nThe interface reloads, and every character then uses the shared diary (empty if they never shared one). Nothing is copied or deleted: each character's own diary stays as it is, for if you switch back."] =
        "Ein Tagebuch für alle deine Charaktere?\n\nDie Oberfläche wird neu geladen, danach schreibt jeder Charakter ins gemeinsame Tagebuch (leer, falls noch keines geteilt wurde). Nichts wird kopiert oder gelöscht: Das eigene Tagebuch jedes Charakters bleibt, wie es ist, falls du zurückwechselst.",
    ["Give every character its own diary again?\n\nThe interface reloads, and this character then uses its own diary, empty if it never had one. Nothing is copied or deleted: the shared diary stays as it is, for if you share again."] =
        "Jedem Charakter wieder sein eigenes Tagebuch geben?\n\nDie Oberfläche wird neu geladen, danach schreibt dieser Charakter in sein eigenes Tagebuch, leer, falls er nie eines hatte. Nichts wird kopiert oder gelöscht: Das gemeinsame Tagebuch bleibt, wie es ist, falls du wieder teilst.",
    ["Forgetting"] = "Vergessen",
    ["Forget people outside the diary after"] = "Leute außerhalb des Tagebuchs vergessen nach",
    ["days"] = "Tagen",
    ["Imagine adding a stranger to your diary after you've met them many times already. This setting pre-saves stranger's data for this so interaction data is available even though they were always strangers. Data for people in your diary are kept indefinitely."] =
        "Stell dir vor, du trägst jemanden ins Tagebuch ein, dem du schon oft begegnet bist. Darum hebt das Tagebuch auch Fremde eine Weile auf, damit eure Begegnungen dann schon da sind. Wer in deinem Tagebuch steht, bleibt für immer.",
    ["Your data"] = "Deine Daten",
    ["Share one diary between all my characters"] = "Ein Tagebuch für alle meine Charaktere",
    ["Switching requires a reload."] = "Der Wechsel lädt die Oberfläche neu.",
    ["Deleting"] = "Löschen",
    ["One person: Remove on their page, or type |cff%s/sd forget <name>|r for anyone else."] =
        "Eine Person: „Entfernen“ auf ihrer Seite, oder gib für alle anderen |cff%s/sd forget <Name>|r ein.",
    ["Delete all sightings?\n\nDiary entries, sessions and interactions are kept."] =
        "Alle Sichtungen löschen?\n\nTagebucheinträge, Sitzungen und Begegnungen bleiben erhalten.",
    ["all sightings deleted."] = "alle Sichtungen gelöscht.",
    ["Delete all sightings..."] = "Alle Sichtungen löschen …",
    ["the shared diary deleted."] = "das gemeinsame Tagebuch gelöscht.",
    ["this character's diary deleted."] = "das Tagebuch dieses Charakters gelöscht.",
    ["Delete everything..."] = "Alles löschen …",
    ["Delete this character's road?\n\nEvery stop, road, flight and level Your Diary kept for them goes, with every card you changed or wrote on its maps. Diary entries, notes and sessions are kept.\n\nThis cannot be undone."] =
        "Den Weg dieses Charakters löschen?\n\nJeder Halt, jeder Weg, jeder Flug und jede Stufe, die „Dein Tagebuch“ für ihn festgehalten hat, geht verloren, mit jeder Karte, die du auf seinen Landkarten geändert oder beschrieben hast. Tagebucheinträge, Notizen und Sitzungen bleiben erhalten.\n\nDas kann nicht rückgängig gemacht werden.",
    ["this character's road deleted."] = "der Weg dieses Charakters gelöscht.",
    ["Delete this character's road..."] = "Weg dieses Charakters löschen …",
    ["Memory"] = "Gedächtnis",

    -- UI/Settings/Sections/Recording.lua
    ["Data needed for the 'Your Diary' Page: Where you go and what you do."] =
        "Für die Seite „Dein Tagebuch“: wohin du gehst und was du tust.",
    ["Chat"] = "Chat",
    ["Keep whisper, /say and party text"] = "Flüstern, /sagen und Gruppenchat behalten",
    ["some text in dungeons cannot be accessed, fyi."] = "In Dungeons ist mancher Text nicht zugänglich.",
    ["Maximum chat lines kept per person"] = "Höchstens so viele Chatzeilen pro Person",
    ["lines"] = "Zeilen",
    ["Unlimited"] = "Unbegrenzt",
    ["Lines can still be lost if they exceed file size limits."] =
        "Zeilen können trotzdem verloren gehen, wenn die Datei zu groß wird.",
    ["Sightings"] = "Sichtungen",
    ["Only works if nameplates are on. Doesn't work in dungeons, raids or battlegrounds."] =
        "Nur mit eingeschalteten Namensplaketten. Nicht in Dungeons, Schlachtzügen oder Schlachtfeldern.",
    ["Enable sightings in cities - performance warning:"] = "Sichtungen in Städten (kostet Leistung):",

    -- UI/Settings/Sections/Shortcuts.lua
    ["Open the journal"] = "Tagebuch öffnen",
    ["Opens the journal"] = "Öffnet das Tagebuch",
    ["Adds your target, or whoever you name"] = "Trägt dein Ziel ein, oder wen du nennst",
    ["Remember this, from who you met lately"] = "Eintragen, aus deinen letzten Begegnungen",
    ["These pages"] = "Diese Seiten",
    ["What the diary keeps, and where"] = "Was das Tagebuch aufbewahrt, und wo",
    ["Deletes everything about someone"] = "Löscht alles über jemanden",
    ["Every command, in chat"] = "Alle Befehle, im Chat",
    ["Keys"] = "Tasten",
    ["On your action bar"] = "Auf deiner Aktionsleiste",
    ["Slash commands"] = "Chatbefehle",
    ["Keybinds & Shortcuts"] = "Tasten und Kürzel",

    -- UI/Settings/Sections/Sounds.lua
    ["World PvP"] = "Welt-PvP",
    ["Sound a raid warning when a foe comes into view"] = "Schlachtzugswarnung, wenn ein Feind in Sicht kommt",
    ["Tag someone foe in your diary, e.g. for World PVP."] =
        "Markiere jemanden in deinem Tagebuch als Feind, etwa für Welt-PvP.",
    ["Hear it"] = "Anhören",
    ["Sounds"] = "Klänge",

    -- UI/Settings/Sections/Toasts.lua
    ["When they show"] = "Wann sie erscheinen",
    ["Show a toast when someone from your diary joins your group"] =
        "Einblendung, wenn jemand aus deinem Tagebuch deiner Gruppe beitritt",
    ["Show a toast when someone from your diary comes into view"] =
        "Einblendung, wenn jemand aus deinem Tagebuch in Sicht kommt",
    ["At most one toast per person every"] = "Höchstens eine Einblendung pro Person alle",
    ["min"] = "Min.",
    ["Ignore toast cooldown for foes"] = "Bei Feinden ohne Pause einblenden",
    ["For World PVP e.g."] = "Etwa für Welt-PvP.",
    ["Nearby Toast Blacklist"] = "Ohne Einblendung in der Nähe",
    ["Toasts can get annoying for people you play with all the time."] =
        "Bei Leuten, mit denen du ständig spielst, können Einblendungen lästig werden.",
    ["Toasts"] = "Einblendungen",

    -- UI/Windows/Reunion/Pad.lua
    ["Move the toast"] = "Einblendung verschieben",
})
