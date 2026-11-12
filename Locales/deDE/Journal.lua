-- German (deDE): Journal. Keys are the English text (Locales/enUS.lua).
--
-- The book's pages (UI/Journal/), the heat map's sheet (UI/Map/), the note
-- sheet (UI/Paper/), a person's page (UI/Words/Person.lua) and the
-- timeline's words (UI/Words/Timeline.lua). Ledger lines: short, the
-- subject dropped where the English drops it, Perfekt or a bare participle
-- ("Zusammen gequestet in Westfall, 1 Std. 5 Min."). A name the game gives
-- goes bare, as subject or after a colon. "{Du hast}" and its kin are the
-- reader's, or another of their characters' in a shared diary
-- (Locales/deDE/Grammar.lua's G.YOU_FOR). A battleground match is a
-- "Partie" (UI/Words/Format.lua's ordinals, Locales/deDE/Words.lua).

local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- UI/Journal/Book.lua: "7 Tage"
    ["%d day|%d days##plural"] = "%d Tag|%d Tage",

    -- UI/Journal/Empty.lua
    ["This is where your diary entries will show up"] = "Hier erscheinen die Einträge deines Tagebuchs",
    ["Or press a key"] = "Oder drück eine Taste",
    ["Target them first."] = "Visiere sie vorher an.",
    ["Invite"] = "Einladen",
    ["Whisper"] = "Flüstern",
    ["Nobody is in the diary yet. There are three ways in."] = "Noch steht niemand im Tagebuch. Es gibt drei Wege hinein.",
    ["Right-click them"] = "Rechtsklick auf sie",
    ["In the world, in chat, or in your group."] = "In der Welt, im Chat oder in deiner Gruppe.",
    ["Or add them later"] = "Oder trag sie später ein",
    ["Or press a button"] = "Oder drück einen Knopf",
    ["Everyone you cross paths with is saved for %s."] = "Alle, denen du begegnest, bleiben %s gespeichert.",
    ["One is there already.|%d are there already.##plural"] = "Eine Person ist schon da.|%d sind schon da.",

    -- UI/Journal/HintPad.lua
    ["Put the hint away"] = "Hinweis weglegen",

    -- UI/Journal/Hints.lua
    ["Right-Click the map to add events yourself."] = "Rechtsklick auf die Karte, um selbst Ereignisse einzutragen.",
    ["Something missing?"] = "Fehlt etwas?",
    ["Assign a hotkey to add a note quickly."] = "Leg eine Taste fest, um schnell eine Notiz zu schreiben.",
    ["Quickly Add Notes"] = "Schnell Notizen schreiben",
    ["Go to Settings"] = "Zu den Einstellungen",
    ["Remember to use your hotkey for adding Notes! (%s)"] = "Denk an deine Taste für Notizen. (%s)",
    ["Fresh Pages"] = "Frische Seiten",
    ["Social Diary %s is here, with a few new things to find."] =
        "Social Diary %s ist da, mit ein paar neuen Dingen zum Entdecken.",
    ["See what’s new"] = "Ansehen, was neu ist",
    ["Old Scoreboards"] = "Alte Punktetafeln",
    ["In %d match, your oldest battleground scoreboards begin to lose their strangers. The people in your diary stay on them.|In %d matches, your oldest battleground scoreboards begin to lose their strangers. The people in your diary stay on them.##plural"] =
        "Nach der nächsten Partie verlieren deine ältesten Punktetafeln nach und nach ihre Fremden. Wer in deinem Tagebuch steht, bleibt darauf.|"
        .. "Nach %d weiteren Partien verlieren deine ältesten Punktetafeln nach und nach ihre Fremden. Wer in deinem Tagebuch steht, bleibt darauf.",
    ["Keep more"] = "Mehr behalten",

    -- UI/Journal/Nearby.lua
    ["Dealt with"] = "Mit Kontakt",
    ["Seen before"] = "Schon gesehen",
    ["Hostile"] = "Feindselig",
    ["Grouped with you"] = "War mit dir in der Gruppe",
    ["Talked with you"] = "Hat mit dir geredet",
    ["Traded with you"] = "Hat mit dir gehandelt",
    ["%1$s %2$s##weekday"] = "%1$s, %2$s",
    ["Last week"] = "Letzte Woche",
    ["Seen on %1$d day since %2$s|Seen on %1$d days since %2$s##plural"] =
        "An einem Tag seit dem %2$s gesehen|An %1$d Tagen seit dem %2$s gesehen",
    ["Level %d when you first saw them"] = "Stufe %d, als du sie zuerst gesehen hast",
    ["%1$s at %2$s##time"] = "%1$s um %2$s",
    ["Added"] = "Eingetragen",
    ["Nobody yet."] = "Noch niemand.",
    ["Sightings are switched off. Turn them back on in the settings, under %1$s: %2$s."] = "Sichtungen sind ausgeschaltet. Schalte sie in den Einstellungen wieder ein, unter %1$s: %2$s.",
    ["Sightings pause in cities and dungeons."] = "In Städten und Dungeons ruhen die Sichtungen.",
    ["Friendly nameplates are off, so only people you target, mouse over or hear in /say are listed."] = "Freundliche Namensplaketten sind aus, also stehen hier nur Leute, die du anvisierst, mit der Maus berührst oder in /sagen hörst.",
    ["%d person|%d people##plural"] = "%d Person|%d Personen",
    ["Everyone you passed in the open world. Kept for %d day.|Everyone you passed in the open world. Kept for %d days.##plural"] =
        "Alle, die in der offenen Welt an dir vorbeikamen, bleiben einen Tag hier.|"
        .. "Alle, die in der offenen Welt an dir vorbeikamen, bleiben %d Tage hier.",
    ["Recently nearby"] = "Kürzlich in der Nähe",
    ["Search names, zones, subzones"] = "Namen, Zonen, Gebiete suchen",
    ["Lvl"] = "Stufe",
    ["Zone"] = "Zone",
    ["Subzone"] = "Gebiet",
    ["In your diary"] = "In deinem Tagebuch",
    ["Open"] = "Öffnen",

    -- UI/Journal/NearbyPad.lua
    ["Go to the days"] = "Zu den Tagen",
    ["See this day"] = "Diesen Tag ansehen",
    ["Go to the people"] = "Zu den Leuten",
    ["Sort by this"] = "Danach sortieren",
    ["Sort the other way"] = "Andersherum sortieren",
    ["Sort by last seen"] = "Nach „Zuletzt gesehen“ sortieren",
    ["Open their page"] = "Ihre Seite öffnen",
    ["Back to the days"] = "Zurück zu den Tagen",

    -- UI/Journal/NotePad.lua
    ["Back to the note"] = "Zurück zur Notiz",
    ["Link them"] = "Verknüpfen",

    -- UI/Journal/Pad.lua
    ["Turn the page"] = "Umblättern",
    ["Close the book"] = "Buch schließen",

    -- UI/Journal/People.lua
    ["%d time|%d times##plural"] = "einmal|%d-mal",
    ["Not seen yet"] = "Noch nicht gesehen",
    ["Seen this week"] = "Diese Woche gesehen",
    ["Seen this month"] = "Diesen Monat gesehen",
    ["Seen earlier"] = "Früher gesehen",
    ["No Interactions yet"] = "Noch keine Begegnung",
    ["This week"] = "Diese Woche",
    ["This month"] = "Diesen Monat",
    ["Earlier"] = "Früher",
    ["tag: %s"] = "Tag: %s",
    ["relationship: %s"] = "Beziehung: %s",
    ["met %s##zone"] = "getroffen %s",
    ["met in the last %s day|met in the last %s days##plural"] =
        "getroffen am letzten Tag|getroffen in den letzten %s Tagen",
    ["%d in the diary"] = "%d im Tagebuch",
    ["nobody yet"] = "noch niemand",
    ["%1$d of %2$d"] = "%1$d von %2$d",
    ["Nobody matches."] = "Niemand passt.",
    ["%d filter|%d filters##plural"] = "%d Filter|%d Filter",
    ["All people"] = "Alle",
    ["Any"] = "Alle",
    ["Sort by"] = "Sortieren nach",
    ["Clear filters"] = "Filter aufheben",
    ["Tag"] = "Tag",
    ["Faction"] = "Fraktion",
    ["Met in zone"] = "Getroffen in Zone",
    ["Any time"] = "Jederzeit",
    ["People"] = "Leute",
    ["Sorted by"] = "Sortiert nach",
    ["Choose someone from the list to read their page."] = "Wähle jemanden aus der Liste, um die Seite zu lesen.",

    -- UI/Journal/PeoplePad.lua
    ["Go to the list"] = "Zur Liste",
    ["Sort another way"] = "Anders sortieren",
    ["See the rest"] = "Den Rest ansehen",
    ["Fold it up"] = "Zusammenfalten",
    ["Open the sheet"] = "Blatt öffnen",
    ["See their story"] = "Ihre Geschichte ansehen",
    ["See where you saw them"] = "Ansehen, wo du sie gesehen hast",
    ["Go to the tabs"] = "Zu den Reitern",
    ["Back to the list"] = "Zurück zur Liste",
    ["Change the note"] = "Notiz ändern",
    ["Write about them"] = "Über sie schreiben",
    ["Back to the left page"] = "Zurück zur linken Seite",

    -- UI/Journal/Profile.lua: the side tabs
    ["Add a note"] = "Notiz schreiben",
    ["edit"] = "Bearbeiten",

    -- UI/Journal/Strips.lua: "Stufe 17", the figures struck out
    ["Level %s##level tag"] = "Stufe %s",

    -- UI/Journal/Timeline.lua
    ["Click to go back to their story."] = "Klicke, um zu ihrer Geschichte zurückzukehren.",
    ["Click to fold it up again."] = "Klicke, um es wieder zuzuklappen.",
    ["Click to show all %d."] = "Klicke, um alle %d zu zeigen.",
    ["%1$s +%2$d"] = "%1$s +%2$d",

    -- the pad's prompts first used on Your Diary (UI/Journey/Pad.lua)
    ["See the map"] = "Karte ansehen",
    ["Go to their page"] = "Zu ihrer Seite",
    ["Show marks"] = "Markierungen zeigen",
    ["Back to the plate"] = "Zurück zur Karte",
    ["Open the map"] = "Karte öffnen",
    ["Add to the diary"] = "Ins Tagebuch eintragen",

    -- UI/Journey/Text/Run.lua
    ["%1$d of %2$d bosses"] = "%1$d von %2$d Bossen",

    -- UI/Map/HeatSheet.lua: the map key
    ["Your diary was seen here %d time|Your diary was seen here %d times##plural"] =
        "Dein Tagebuch wurde hier einmal gesehen|Dein Tagebuch wurde hier %d-mal gesehen",
    ["Seen here %d time|Seen here %d times##plural"] = "Hier einmal gesehen|Hier %d-mal gesehen",

    -- UI/Paper/NoteSheet.lua: "Geschrieben am 6. Oktober in Westfall"
    ["Written %1$s %2$s##zone"] = "Geschrieben am %1$s %2$s",

    -- UI/Words/Person.lua: the strips at the top of their page
    ["No note yet. Click Edit to write one."] = "Noch keine Notiz. Klicke auf Bearbeiten, um eine zu schreiben.",
    ["last seen %s"] = "zuletzt gesehen: %s",
    ["First met"] = "Erste Begegnung",
    ["Added %s"] = "Eingetragen: %s",
    ["First met %s"] = "Erste Begegnung: %s",
    ["%s together##duration"] = "%s zusammen",
    ["under a minute together"] = "keine Minute zusammen",
    ["Met %s"] = "%s getroffen",
    ["Each time you grouped, traded or talked nearby"] = "Jedes Mal, wenn ihr in einer Gruppe wart, gehandelt oder in der Nähe geredet habt",
    ["Last met %s"] = "Zuletzt getroffen %s",
    ["%s now"] = "%s jetzt",
    ["%s when you first met"] = "%s bei der ersten Begegnung",
    ["Their level"] = "Ihre Stufe",

    -- the plate's marks
    ["Click to open the map."] = "Klicke, um die Karte zu öffnen.",
    ["Where you saw them"] = "Wo du sie gesehen hast",
    ["Where you first met"] = "Wo ihr euch zuerst begegnet seid",
    ["Together for %s"] = "Zusammen, %s",
    ["They said"] = "Sie sagten",
    ["They yelled"] = "Sie riefen",
    ["{Your} group killed them"] = "{Deine} Gruppe hat sie getötet",
    ["{You} killed them"] = "{Du hast} sie getötet",
    ["They killed {you}"] = "Sie haben {dich} getötet",
    ["They probably killed {you}"] = "Sie haben {dich} wahrscheinlich getötet",
    ["Also about %s"] = "Auch über %s",
    ["%s inside"] = "%s drinnen",

    -- a stranger's glimpse
    ["Not in your diary yet"] = "Noch nicht in deinem Tagebuch",
    ["Click to see their page, pencilled in"] = "Klicke für ihre Seite, mit Bleistift notiert",
    ["After that"] = "Danach",
    ["Moments later"] = "Kurz darauf",
    ["The next day"] = "Am nächsten Tag",
    ["The day before"] = "Am Tag davor",
    ["%s earlier"] = "%s früher",
    ["%s later"] = "%s später",
    ["%d day earlier|%d days earlier##plural"] = "Einen Tag früher|%d Tage früher",
    ["%d day later|%d days later##plural"] = "Einen Tag später|%d Tage später",
    ["you at level %1$d, they at %2$d"] = "du auf Stufe %1$d, sie auf %2$d",
    ["you were %s##zone"] = "du warst %s",
    ["Seen on %1$d day since %2$s. %3$s|Seen on %1$d days since %2$s. %3$s##plural"] =
        "An einem Tag seit dem %2$s gesehen. %3$s|An %1$d Tagen seit dem %2$s gesehen. %3$s",
    ["Pencilled in until %s"] = "Mit Bleistift notiert bis %s",
    ["Strangers are forgotten after %s. Once in your diary, all of this is kept for good."] = "Fremde bleiben %s mit Bleistift notiert, dann werden sie vergessen. Im Tagebuch bleibt all das für immer.",
    ["Add %s to your diary"] = "%s ins Tagebuch eintragen",

    -- UI/Words/Timeline.lua: a row's shared words
    ["%1$dx %2$s"] = "%1$d× %2$s",
    ["%1$s: \"%2$s\""] = "%1$s: „%2$s“",
    ["Grouped"] = "In der Gruppe",
    ["Raided together"] = "Zusammen geraidet",

    -- a death: "{Du bist} bei Roter Wolkenhügel durch Ebenenschreiter (3 Angreifer) gestorben";
    -- the environment in brackets after it, "{Du bist} gestorben (Sturz)"
    ["drowning##death"] = "Ertrinken",
    ["falling##death"] = "Sturz",
    ["fatigue##death"] = "Erschöpfung",
    ["fire##death"] = "Feuer",
    ["lava##death"] = "Lava",
    ["slime##death"] = "Schleim",
    ["%1$s died %2$s##zone"] = "%1$s ist %2$s gestorben",
    ["%s died there"] = "%s ist dort gestorben",
    ["%1$s died (%2$s) there"] = "%1$s ist dort gestorben (%2$s)",
    ["%1$s died (%2$s) %3$s##zone"] = "%1$s ist %3$s gestorben (%2$s)",
    ["%1$s died to %2$s there"] = "%1$s ist dort durch %2$s gestorben",
    ["%1$s died to %2$s %3$s##zone"] = "%1$s ist %3$s durch %2$s gestorben",
    ["%1$s died, probably to %2$s there"] = "%1$s ist dort gestorben, vermutlich durch %2$s",
    ["%1$s died, probably to %2$s %3$s##zone"] = "%1$s ist %3$s gestorben, vermutlich durch %2$s",
    ["{You} died %s##zone"] = "{Du bist} %s gestorben",
    ["{You} died there"] = "{Du bist} dort gestorben",
    ["{You} died (%s) there"] = "{Du bist} dort gestorben (%s)",
    ["{You} died (%1$s) %2$s##zone"] = "{Du bist} %2$s gestorben (%1$s)",
    ["{You} died to %s there"] = "{Du bist} dort durch %s gestorben",
    ["{You} died to %1$s %2$s##zone"] = "{Du bist} %2$s durch %1$s gestorben",
    ["{You} died, probably to %s there"] = "{Du bist} dort gestorben, vermutlich durch %s",
    ["{You} died, probably to %1$s %2$s##zone"] = "{Du bist} %2$s gestorben, vermutlich durch %1$s",
    ["%1$s's %2$s"] = "%2$s von %1$s",
    ["%1$s (%2$d attacker)|%1$s (%2$d attackers)##plural"] = "%1$s (%2$d Angreifer)|%1$s (%2$d Angreifer)",
    ["They"] = "Sie",

    -- places and rares
    ["%s and around"] = "%s und Umgebung",
    ["a rare"] = "einen seltenen Gegner",

    -- what was done together: how a headline opens, and its clauses after
    ["Quested together"] = "Zusammen gequestet",
    ["Hunted together"] = "Zusammen gejagt",
    ["Chatted"] = "Geplaudert",
    ["Crossed paths"] = "Begegnet",
    ["quested together"] = "zusammen gequestet",
    ["killed %s##timeline"] = "%s getötet",
    ["grouped"] = "in der Gruppe",
    ["traded"] = "gehandelt",
    ["chatted"] = "geplaudert",
    ["crossed paths"] = "begegnet",
    ["Together"] = "Zusammen",
    ["%1$s for %2$s %3$s##zone"] = "%1$s %3$s, %2$s",
    ["%1$s for %2$s##duration"] = "%1$s, %2$s",
    ["%1$s %2$s##zone"] = "%1$s %2$s",

    -- a together session's headline: runs
    ["%d dungeon|%d dungeons##plural"] = "%d Dungeon|%d Dungeons",
    ["ran %s##count"] = "%s absolviert",
    ["raided %s##times"] = "%s geraidet",
    ["%d raid|%d raids##plural"] = "%d Schlachtzug|%d Schlachtzüge",
    ["ran %1$s and %2$s"] = "%1$s und %2$s absolviert",
    ["raided %s"] = "%s geraidet",
    ["ran %s"] = "%s absolviert",
    ["raided %1$s and ran %2$s"] = "%1$s geraidet und %2$s absolviert",
    ["ran %1$s and raided %2$s"] = "%1$s absolviert und %2$s geraidet",
    ["raided %s twice"] = "%s zweimal geraidet",
    ["ran %s twice"] = "%s zweimal absolviert",
    ["raided %1$s and %2$s"] = "%1$s und %2$s geraidet",
    ["a dungeon"] = "ein Dungeon",
    ["%s together"] = "Zusammen %s",

    -- levels
    ["Reached lv %d together"] = "Zusammen Stufe %d erreicht",
    ["{you} both reached lv %d"] = "{ihr habt} beide Stufe %d erreicht",
    ["{You} reached lv %1$d, %2$s lv %3$d"] = "{Du hast} Stufe %1$d erreicht, %2$s Stufe %3$d",
    ["{you} reached lv %1$d, %2$s lv %3$d"] = "{du hast} Stufe %1$d erreicht, %2$s Stufe %3$d",
    ["%1$s reached lv %2$d at {your} side"] = "%1$s hat an {deiner} Seite Stufe %2$d erreicht",
    ["%1$s reached lv %2$d with {you}"] = "%1$s hat mit {dir} Stufe %2$d erreicht",
    ["%1$s reached lv %2$d"] = "%1$s hat Stufe %2$d erreicht",
    ["{You} reached lv %1$d while questing with %2$s"] = "{Du hast} beim Questen mit %2$s Stufe %1$d erreicht",
    ["{You} reached lv %1$d with %2$s"] = "{Du hast} mit %2$s Stufe %1$d erreicht",
    ["{you} reached lv %d"] = "{du hast} Stufe %d erreicht",

    -- a rough patch
    ["{You} died %1$s with %2$s close by"] = "{Du bist} %1$s gestorben, %2$s ganz in der Nähe",
    ["%1$s died %2$s at {your} side"] = "%1$s ist %2$s an {deiner} Seite gestorben",
    ["%1$s died %2$s with {you} close by"] = "%1$s ist %2$s gestorben, {du} ganz in der Nähe",
    ["{You} and %1$s died %2$s between you"] = "{Du} und %1$s: zusammen %2$s gestorben",
    ["%1$d deaths between {you} and %2$s"] = "%1$d Tode zwischen {dir} und %2$s",

    -- a rare, a journey, a place
    ["Hunted %s together"] = "Zusammen %s gejagt",
    ["Went %1$s %2$s together##zone"] = "Zusammen %1$s %2$s gezogen",
    ["Travelled %1$s %2$s together##zone"] = "Gemeinsam %1$s %2$s gereist",
    ["on the Deeprun Tram"] = "in der Tiefenbahn",
    ["Kept company %s##zone"] = "Gesellschaft geleistet %s",
    ["Kept each other company %s##zone"] = "Einander Gesellschaft geleistet %s",
    ["%1$s %2$s %3$s##zone"] = "%1$s %2$s %3$s",
    ["Together for %1$s; %2$s"] = "%1$s zusammen; %2$s",
    ["%1$s over %2$s"] = "%1$s, in %2$s",
    ["%1$s; %2$s"] = "%1$s; %2$s",

    -- a run, and the details line
    ["%d death|%d deaths##plural"] = "%d Tod|%d Tode",
    ["%d trade|%d trades##plural"] = "einmal gehandelt|%d-mal gehandelt",
    ["An instance"] = "Eine Instanz",
    ["%1$s (%2$s)##difficulty"] = "%1$s (%2$s)",
    ["%1$d of %2$d boss|%1$d of %2$d bosses##plural"] = "%1$d von %2$d Boss|%1$d von %2$d Bossen",
    ["%d boss|%d bosses##plural"] = "%d Boss|%d Bosse",
    ["%d wipe|%d wipes##plural"] = "%d Wipe|%d Wipes",

    -- a battleground match: "Kriegshymnenschlucht, auf deiner Seite"
    ["Warsong Gulch"] = "Kriegshymnenschlucht",
    ["Arathi Basin"] = "Arathibecken",
    ["Alterac Valley"] = "Alteractal",
    ["A battleground"] = "Ein Schlachtfeld",
    ["%s, on {your} side"] = "%s, auf {deiner} Seite",
    ["%s, against {you}"] = "%s, gegen {dich}",
    ["{your} %s match together"] = "{deine} %s gemeinsame Partie",
    ["{your} %s match against them"] = "{deine} %s Partie gegen sie",
    ["{you} left before the end"] = "{du bist} vor dem Ende gegangen",
    ["{you} won"] = "{du hast} gewonnen",
    ["{you} lost"] = "{du hast} verloren",
    ["%d killing blow|%d killing blows##plural"] = "%d Todesstoß|%d Todesstöße",
    ["still going"] = "läuft noch",

    -- trades, quests, the rest
    ["%1$d trade: %2$s|%1$d trades: %2$s##plural"] = "einmal gehandelt: %2$s|%1$d-mal gehandelt: %2$s",
    ["\226\128\156%s\226\128\157"] = "„%s“",
    ["%d quest|%d quests##plural"] = "%d Quest|%d Quests",
    ["%d message|%d messages##plural"] = "%d Nachricht|%d Nachrichten",
    ["%d other interaction|%d other interactions##plural"] = "%d weiterer Kontakt|%d weitere Kontakte",

    -- a note
    ["Also about %s."] = "Auch über %s.",
    ["Written at %1$s %2$s.##zone"] = "Geschrieben um %1$s %2$s.",
    ["Written at %s."] = "Geschrieben um %s.",
    ["Click to change or delete it."] = "Klicke, um sie zu ändern oder zu löschen.",

    -- the other items
    ["%1$s went from level %2$s to %3$s"] = "%1$s ist von Stufe %2$s auf %3$s gestiegen",
    ["Went from level %1$s to %2$s"] = "Von Stufe %1$s auf %2$s gestiegen",
    ["%1$s  level %2$s"] = "%1$s  Stufe %2$s",
    ["{You} died %s"] = "{Du bist} %s gestorben",
    ["%1$s died %2$s"] = "%1$s ist %2$s gestorben",
    ["%1$s %2$s##name and times"] = "%1$s %2$s",
    ["Killed %s##timeline"] = "%s getötet",
    ["Seen %1$s for %2$s##zone"] = "Gesehen %1$s, %2$s",
    ["Seen %s##zone"] = "Gesehen %s",
    ["Seen around for %s"] = "In der Nähe gesehen, %s",
    ["Seen around"] = "In der Nähe gesehen",
    ["First seen %1$s, %2$s, level %3$s##zone"] = "Zuerst gesehen %1$s, %2$s, Stufe %3$s",
    ["First seen %1$s, %2$s##zone"] = "Zuerst gesehen %1$s, %2$s",
    ["First seen %1$s, level %2$s##zone"] = "Zuerst gesehen %1$s, Stufe %2$s",
    ["First seen %s##zone"] = "Zuerst gesehen %s",
    ["First seen, level %s"] = "Zuerst gesehen, Stufe %s",
    ["First seen"] = "Zuerst gesehen",
    ["Added to the diary %s##zone"] = "Ins Tagebuch eingetragen %s",
    ["Added to the diary"] = "Ins Tagebuch eingetragen",

    -- UI/Journal/Hints.lua
    ["Translated Pages"] = "Übersetzte Seiten",
    ["The diary is now written in %s. The translation is early and machine-made, so expect odd lines and clipped text. Corrections are welcome."] =
        "Das Tagebuch ist jetzt auf %s geschrieben. Die Übersetzung ist noch frisch und maschinell erstellt, rechne also mit seltsamen Zeilen und abgeschnittenem Text. Korrekturen sind willkommen.",
    ["Suggest Translation"] = "Übersetzung vorschlagen",
    ["Go to Language"] = "Zur Spracheinstellung",
})
