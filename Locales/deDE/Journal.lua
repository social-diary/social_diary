-- German (deDE): Journal. Keys are the English text (Locales/enUS.lua).
--
-- The book's pages (UI/Journal/), the timeline's words (UI/Words/Timeline.lua)
-- and a person's page (UI/Words/Person.lua). Ledger lines: short, the
-- subject dropped where the English drops it, Perfekt or a bare participle
-- ("Zusammen gequestet in Westfall, 1 Std. 5 Min."). A name the game gives
-- goes bare, as subject or after a colon. "{Du hast}" and its kin are the
-- reader's, or another of their characters' in a shared diary
-- (Locales/deDE/Grammar.lua's G.YOU_FOR).

local addonName, ns = ...

if ns.Locale.Is("deDE") then
    -- UI/Journal/People.lua: "Sortiert nach Zuletzt getroffen": German nouns
    -- keep their capital, so the sort's label is set as it is.
    ns.Locale.grammar.PeopleSortLabel = function(label) return label end
end

ns.Locale.Add("deDE", {
    -- UI/Words/Timeline.lua: a row's shared words
    ["%1$dx %2$s"] = "%1$d× %2$s",
    ["%1$s: \"%2$s\""] = "%1$s: „%2$s“",
    ["Raided together"] = "Zusammen geraidet",
    ["Grouped"] = "In der Gruppe",

    -- a death: "{Du bist} wahrscheinlich durch Ebenenschreiter (3 Angreifer) bei Roter Wolkenhügel gestorben"
    ["falling##death"] = "einen Sturz",
    ["drowning##death"] = "Ertrinken",
    ["fatigue##death"] = "Erschöpfung",
    ["fire##death"] = "Feuer",
    ["lava##death"] = "Lava",
    ["slime##death"] = "Schleim",
    [" (%s)##environment"] = " durch %s",
    ["%1$s's %2$s"] = "%2$s von %1$s",
    [" to %s##death"] = " durch %s",
    [", probably to %s"] = " wahrscheinlich durch %s",
    [" (%d attackers)"] = " (%d Angreifer)",
    [" there"] = " dort",
    [" near %s"] = " bei %s",
    ["%1$s died%2$s"] = "%1$s ist%2$s gestorben",
    ["They"] = "Sie",
    ["{You} died%s"] = "{Du bist}%s gestorben",

    -- places and rares
    ["%1$s and %2$s"] = "%1$s und %2$s",
    ["%s and around"] = "%s und Umgebung",
    ["a rare"] = "ein Seltener",

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
    ["%1$s for %2$s##duration"] = "%1$s, %2$s",
    ["%1$s for %2$s through %3$s"] = "%1$s durch %3$s, %2$s",
    ["%1$s for %2$s in %3$s"] = "%1$s in %3$s, %2$s",
    ["%1$s through %2$s"] = "%1$s durch %2$s",

    -- a together session's headline: runs
    ["dungeon"] = "Dungeon",
    ["dungeons"] = "Dungeons",
    ["ran %s"] = "%s absolviert",
    ["raided %s##times"] = "%s geraidet",
    ["ran %1$s and %2$s"] = "%1$s und %2$s absolviert",
    ["raid"] = "Schlachtzug",
    ["raids"] = "Schlachtzüge",
    ["raided %s"] = "%s geraidet",
    ["raided %1$s and ran %2$s"] = "%1$s geraidet und %2$s absolviert",
    ["ran %1$s and raided %2$s"] = "%1$s absolviert und %2$s geraidet",
    ["raided %s twice"] = "%s zweimal geraidet",
    ["ran %s twice"] = "%s zweimal absolviert",
    ["raided %1$s and %2$s"] = "%1$s und %2$s geraidet",
    ["a dungeon"] = "ein Dungeon",
    ["%s together"] = "Zusammen %s",

    -- levels
    ["Reached lv %d together"] = "Zusammen Stufe %d erreicht",
    ["{you} both reached lv %d"] = "beide Stufe %d erreicht",
    ["{You} reached lv %1$d, %2$s lv %3$d"] = "{Du hast} Stufe %1$d erreicht, %2$s Stufe %3$d",
    ["{you} reached lv %1$d, %2$s lv %3$d"] = "{du hast} Stufe %1$d erreicht, %2$s Stufe %3$d",
    ["%1$s reached lv %2$d at {your} side"] = "%1$s erreichte Stufe %2$d an {deiner} Seite",
    ["%1$s reached lv %2$d with {you}"] = "%1$s erreichte Stufe %2$d mit {dir}",
    ["%1$s reached lv %2$d"] = "%1$s erreichte Stufe %2$d",
    ["{You} reached lv %1$d while questing with %2$s"] = "{Du hast} beim Questen mit %2$s Stufe %1$d erreicht",
    ["{You} reached lv %1$d with %2$s"] = "{Du hast} mit %2$s Stufe %1$d erreicht",
    ["{you} reached lv %d"] = "{du hast} Stufe %d erreicht",

    -- a rough patch
    ["{You} died %1$s with %2$s close by"] = "{Du bist} %1$s gestorben, %2$s ganz in der Nähe",
    ["%1$s died %2$s at {your} side"] = "%1$s starb %2$s an {deiner} Seite",
    ["%1$s died %2$s with {you} close by"] = "%1$s starb %2$s, {du} ganz in der Nähe",
    ["{You} and %1$s died %2$s between you"] = "{Du} und %1$s: zusammen %2$s gestorben",
    ["%1$d deaths between {you} and %2$s"] = "%1$d Tode zwischen {dir} und %2$s",

    -- a rare, a journey, a place
    ["Hunted %s together"] = "Zusammen %s gejagt",
    ["Went from %1$s to %2$s together"] = "Zusammen von %1$s nach %2$s gezogen",
    ["Travelled from %1$s to %2$s together"] = "Gemeinsam von %1$s nach %2$s gereist",
    ["on the Deeprun Tram"] = "in der Tiefenbahn",
    ["in %s"] = "in %s",
    ["Kept company %s"] = "%s Gesellschaft geleistet",
    ["Kept each other company %s"] = "Einander Gesellschaft geleistet %s",
    ["%1$s at %2$s in %3$s"] = "%1$s bei %2$s in %3$s",
    ["Together for %1$s; %2$s"] = "Zusammen, %1$s; %2$s",
    ["%1$s over %2$s"] = "%1$s, in %2$s",
    ["%1$s; %2$s"] = "%1$s; %2$s",

    -- a run, and the details line
    ["others##members"] = "weitere",
    ["An instance"] = "Eine Instanz",
    ["%1$s (%2$s)##difficulty"] = "%1$s (%2$s)",
    ["%1$d of %2$d bosses"] = "%1$d von %2$d Bossen",
    ["boss"] = "Boss",
    ["bosses"] = "Bosse",
    ["death"] = "Tod",
    ["deaths"] = "Tode",
    ["wipe"] = "Wipe",
    ["wipes"] = "Wipes",
    ["trade"] = "Tausch",
    ["trades"] = "Tausche",
    ["%1$d trades: %2$s"] = "%1$d Tausche: %2$s",
    ["\226\128\156%s\226\128\157"] = "„%s“",
    ["quest"] = "Quest",
    ["quests"] = "Quests",
    ["message"] = "Nachricht",
    ["messages"] = "Nachrichten",
    ["other interaction"] = "andere Begegnung",
    ["other interactions"] = "andere Begegnungen",
    ["still going"] = "läuft noch",

    -- a note
    ["Also about %s."] = "Auch über %s.",
    ["Written at %1$s in %2$s."] = "Geschrieben um %1$s in %2$s.",
    ["Written at %s."] = "Geschrieben um %s.",
    ["Click to change or delete it."] = "Klicke, um sie zu ändern oder zu löschen.",

    -- the other items
    ["%1$s went from level %2$s to %3$s"] = "%1$s stieg von Stufe %2$s auf %3$s",
    ["Went from level %1$s to %2$s"] = "Von Stufe %1$s auf %2$s gestiegen",
    ["%1$s  level %2$s"] = "%1$s  Stufe %2$s",
    ["{You} died %s"] = "{Du bist} %s gestorben",
    ["%1$s died %2$s"] = "%1$s ist %2$s gestorben",
    ["Killed %s##timeline"] = "%s getötet",
    ["Seen around %1$s for %2$s"] = "In der Nähe gesehen, in %1$s, %2$s",
    ["Seen around %s"] = "In der Nähe gesehen, in %s",
    ["Seen around for %s"] = "In der Nähe gesehen, %s",
    ["Seen around"] = "In der Nähe gesehen",
    ["First seen at %1$s, level %2$s"] = "Zuerst gesehen bei %1$s, Stufe %2$s",
    ["First seen at %s"] = "Zuerst gesehen bei %s",
    ["First seen, level %s"] = "Zuerst gesehen, Stufe %s",
    ["First seen"] = "Zuerst gesehen",
    ["Added to the diary in %s"] = "In %s ins Tagebuch eingetragen",
    ["Added to the diary"] = "Ins Tagebuch eingetragen",

    -- UI/Words/Person.lua: the strips at the top of their page
    ["No note yet. Click Edit to write one."] = "Noch keine Notiz. Klicke auf Bearbeiten, um eine zu schreiben.",
    ["last seen %s"] = "zuletzt gesehen: %s",
    ["First met"] = "Erste Begegnung",
    ["First met %s"] = "Erste Begegnung: %s",
    ["Added %s"] = "Eingetragen: %s",
    ["%s together##duration"] = "%s zusammen",
    ["under a minute together"] = "keine Minute zusammen",
    ["Met %s"] = "%s getroffen",
    ["Each time you grouped, traded or talked nearby"] = "Jedes Mal, wenn ihr in einer Gruppe wart, gehandelt oder in der Nähe geredet habt",
    ["Last met %s"] = "Zuletzt getroffen %s",
    ["Their level"] = "Ihre Stufe",
    ["%s when you first met"] = "%s bei der ersten Begegnung",
    ["%s now"] = "%s jetzt",

    -- the plate's marks
    ["Where you saw them"] = "Wo du sie gesehen hast",
    ["Click to open the map."] = "Klicke, um die Karte zu öffnen.",
    ["Where you first met"] = "Wo ihr euch zuerst begegnet seid",
    ["Together for %s"] = "Zusammen, %s",
    ["They said"] = "Sie sagten",
    ["They yelled"] = "Sie riefen",
    ["{Your} group killed them"] = "{Deine} Gruppe hat sie getötet",
    ["{You} killed them"] = "{Du hast} sie getötet",
    ["They probably killed {you}"] = "Sie haben {dich} wahrscheinlich getötet",
    ["They killed {you}"] = "Sie haben {dich} getötet",
    ["Also about %s"] = "Auch über %s",
    ["%s inside"] = "%s drinnen",

    -- a stranger's glimpse
    ["Not in your diary yet"] = "Noch nicht in deinem Tagebuch",
    ["Click to see their page, pencilled in"] = "Klicke für ihre Seite, mit Bleistift notiert",
    ["After that"] = "Danach",
    ["Moments later"] = "Kurz darauf",
    ["The next day"] = "Am nächsten Tag",
    ["The day before"] = "Am Tag davor",
    ["%s later"] = "%s später",
    ["%s earlier"] = "%s früher",
    ["%d days later"] = "%d Tage später",
    ["%d days earlier"] = "%d Tage früher",
    ["you at level %1$d, they at %2$d"] = "du auf Stufe %1$d, sie auf %2$d",
    ["you were in %s"] = "du warst in %s",
    ["and %d more##glimpse"] = "und %d weitere",
    ["Seen on %1$d days since %2$s. "] = "An %1$d Tagen gesehen seit %2$s. ",
    ["Pencilled in until %s"] = "Mit Bleistift notiert bis %s",
    ["Strangers are forgotten after %s. Once in your diary, all of this is kept for good."] = "Fremde bleiben %s mit Bleistift notiert, dann werden sie vergessen. Im Tagebuch bleibt all das für immer.",
    ["Add %s to your diary"] = "%s ins Tagebuch eintragen",

    -- UI/Journal/Book.lua
    ["day##count"] = "Tag",
    ["days##count"] = "Tage",

    -- UI/Journal/Strips.lua: "Stufe 17", the figures struck out
    ["Level "] = "Stufe ",

    -- UI/Journal/Timeline.lua
    ["Click to go back to their story."] = "Klicke, um zu ihrer Geschichte zurückzukehren.",
    ["Click to fold it up again."] = "Klicke, um es wieder zuzuklappen.",
    ["Click to show all %d."] = "Klicke, um alle %d zu zeigen.",
    ["%1$s +%2$d"] = "%1$s +%2$d",

    -- UI/Journal/People.lua
    ["time"] = "Mal",
    ["times"] = "Mal",
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
    ["met in %s"] = "getroffen in %s",
    ["met in the last %s days"] = "getroffen in den letzten %s Tagen",
    ["nobody yet"] = "noch niemand",
    ["%d in the diary"] = "%d im Tagebuch",
    ["%1$d of %2$d"] = "%1$d von %2$d",
    ["Nobody matches."] = "Niemand passt.",
    ["All people"] = "Alle",
    ["filter"] = "Filter",
    ["filters"] = "Filter",
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

    -- UI/Journal/Profile.lua: the side tabs
    ["Add a note"] = "Notiz schreiben",
    ["edit"] = "Bearbeiten",

    -- UI/Journal/Nearby.lua
    ["Dealt with"] = "Mit Kontakt",
    ["Seen before"] = "Schon gesehen",
    ["Hostile"] = "Feindselig",
    ["Grouped with you"] = "War mit dir in der Gruppe",
    ["Traded with you"] = "Hat mit dir gehandelt",
    ["Talked with you"] = "Hat mit dir geredet",
    ["%1$s %2$s##weekday"] = "%1$s, %2$s",
    ["Last week"] = "Letzte Woche",
    ["Seen on %1$d days since %2$s"] = "An %1$d Tagen gesehen seit %2$s",
    ["Level %d when you first saw them"] = "Stufe %d, als du sie zuerst gesehen hast",
    ["%1$s at %2$s##time"] = "%1$s um %2$s",
    ["In your diary"] = "In deinem Tagebuch",
    ["Open"] = "Öffnen",
    ["Added"] = "Eingetragen",
    ["Nobody yet."] = "Noch niemand.",
    ["Sightings are switched off. Turn them back on in the settings, under %1$s: %2$s."] = "Sichtungen sind ausgeschaltet. Schalte sie in den Einstellungen wieder ein, unter %1$s: %2$s.",
    ["Sightings pause in cities and dungeons."] = "In Städten und Dungeons ruhen die Sichtungen.",
    ["Friendly nameplates are off, so only people you target, mouse over or hear in /say are listed."] = "Freundliche Namensplaketten sind aus, also stehen hier nur Leute, die du anvisierst, mit der Maus berührst oder in /sagen hörst.",
    ["person"] = "Person",
    ["people"] = "Personen",
    ["Everyone you passed in the open world. Kept for %d days."] = "Alle, an denen du in der offenen Welt vorbeigekommen bist. %d Tage aufbewahrt.",
    ["Recently nearby"] = "Kürzlich in der Nähe",
    ["Search names, zones, subzones"] = "Namen, Zonen, Gebiete suchen",
    ["Lvl"] = "Stufe",
    ["Zone"] = "Zone",
    ["Subzone"] = "Gebiet",

    -- UI/Journal/Empty.lua
    ["This is where your diary entries will show up"] = "Hier erscheinen die Einträge deines Tagebuchs",
    ["Whisper"] = "Flüstern",
    ["Invite"] = "Einladen",
    ["Nobody is in the diary yet. There are three ways in."] = "Noch steht niemand im Tagebuch. Es gibt drei Wege hinein.",
    ["Right-click them"] = "Rechtsklick auf sie",
    ["In the world, in chat, or in your group."] = "In der Welt, im Chat oder in deiner Gruppe.",
    ["Or press a key"] = "Oder drück eine Taste",
    ["Target them first."] = "Visiere sie vorher an.",
    ["Or add them later"] = "Oder trag sie später ein",
    ["Everyone you cross paths with is saved for %s."] = "Alle, denen du begegnest, bleiben %s gespeichert.",
    ["Everyone you cross paths with is saved for %s. One is there already."] = "Alle, denen du begegnest, bleiben %s gespeichert. Eine Person ist schon da.",
    ["Everyone you cross paths with is saved for %1$s. %2$d are there already."] = "Alle, denen du begegnest, bleiben %1$s gespeichert. %2$d sind schon da.",

    -- UI/Journal/Hints.lua
    ["Something missing?"] = "Fehlt etwas?",
    ["Right-Click the map to add events yourself."] = "Rechtsklick auf die Karte, um selbst Ereignisse einzutragen.",
    ["Quickly Add Notes"] = "Schnell Notizen schreiben",
    ["Assign a hotkey to add a note quickly."] = "Leg eine Taste fest, um schnell eine Notiz zu schreiben.",
    ["Go to Settings"] = "Zu den Einstellungen",
    ["Remember to use your hotkey for adding Notes! (%s)"] = "Denk an deine Taste für Notizen. (%s)",
})
