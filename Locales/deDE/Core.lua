-- German (deDE): Core. Keys are the English text (Locales/enUS.lua).

local addonName, ns = ...
if not ns.Locale.Is("deDE") then return end

ns.Locale.Add("deDE", {
    -- Capture/Menus.lua
    ["Social Diary: open entry"] = "Social Diary: Eintrag öffnen",
    ["Social Diary: remember this"] = "Social Diary: ins Tagebuch eintragen",

    -- Core/Candidates.lua
    ["your target"] = "dein Ziel",
    ["under your cursor"] = "unter deinem Mauszeiger",
    ["your focus"] = "dein Fokus",
    ["in your raid"] = "in deinem Schlachtzug",
    ["in your group"] = "in deiner Gruppe",
    ["you traded with them"] = "ihr habt gehandelt",
    ["they whispered you"] = "hat dir geflüstert",
    ["they resurrected you"] = "hat dich wiederbelebt",
    ["they summoned you"] = "hat dich beschworen",
    ["recent say"] = "hat kürzlich in der Nähe gesprochen",
    ["recent whisper_in"] = "hat dir kürzlich geflüstert",
    ["recent whisper_out"] = "kürzlich von dir angeflüstert",
    ["recent party"] = "hat kürzlich im Gruppenchat geschrieben",
    ["recent trade"] = "hat kürzlich mit dir gehandelt",
    ["recent yell"] = "hat kürzlich in der Nähe geschrien",
    ["recent group_join"] = "ist kürzlich deiner Gruppe beigetreten",
    ["recent group_leave"] = "hat kürzlich deine Gruppe verlassen",
    ["recent level_up"] = "ist kürzlich eine Stufe aufgestiegen",
    ["recent %s"] = "kürzlich: %s",

    -- Core/Diary.lua
    ["added |cffffffff%s|r to the diary."] = "hat |cffffffff%s|r ins Tagebuch eingetragen.",
    ["deleted everything about |cffffffff%s|r."] = "hat alles über |cffffffff%s|r gelöscht.",
    ["removed |cffffffff%s|r from the diary; their history is now kept under the buffer's retention rules."] =
        "hat |cffffffff%s|r aus dem Tagebuch entfernt; was ihr erlebt habt, steht jetzt nur noch mit Bleistift darin und wird mit der Zeit ausradiert.",

    -- Core/People.lua
    ["Last met"] = "Zuletzt getroffen",
    ["Times met"] = "Wie oft getroffen",
    ["Time together"] = "Zeit zusammen",
    ["Last seen"] = "Zuletzt gesehen",
    ["Name"] = "Name",
    ["Last 7 days"] = "Letzte 7 Tage",
    ["Last 30 days"] = "Letzte 30 Tage",
    ["Last 90 days"] = "Letzte 90 Tage",
    ["Last year"] = "Letztes Jahr",

    -- Core/Slash.lua
    ["commands:"] = "Befehle:",
    ["no character called |cffffffff%s|r on record."] = "kein Charakter namens |cffffffff%s|r bekannt.",
    ["%1$s matches %2$d character -- add the surname.|%1$s matches %2$d characters -- add the surname.##plural"] =
        "%1$s passt auf %2$d Charakter -- gib auch den Nachnamen an.|%1$s passt auf %2$d Charaktere -- gib auch den Nachnamen an.",
    ["usage: |cffffd100/sd remove <name>|r, or target them first."] =
        "so geht’s: |cffffd100/sd remove <Name>|r, oder nimm die Person vorher ins Ziel.",
    ["|cffffffff%s|r is not in the diary."] = "|cffffffff%s|r steht nicht im Tagebuch.",
    ["%1$s %2$s %3$s##chat date"] = "%1$s. %2$s %3$s",
    ["%1$s %2$s##chat date"] = "%1$s. %2$s",
    ["%d diary entry.|%d diary entries.##plural"] = "%d Eintrag im Tagebuch.|%d Einträge im Tagebuch.",
    ["usage: |cffffd100/sd forget <name>|r"] = "so geht’s: |cffffd100/sd forget <Name>|r",
    ["map %s"] = "Karte %s",
    ["%1$-22s lvl %2$-3s %3$-18s %4$s%5$s%6$s"] = "%1$-22s St. %2$-3s %3$-18s %4$s%5$s%6$s",
    ["hostile##chat"] = "feindlich",
    ["diary##chat tag"] = "Tagebuch",
    ["and %d more|and %d more##plural"] = "und noch %d|und noch %d",
    ["%1$d character seen in the last %2$s.|%1$d characters seen in the last %2$s.##plural"] =
        "%1$d Charakter innerhalb der letzten %2$s gesehen.|%1$d Charaktere innerhalb der letzten %2$s gesehen.",
    ["%s hour|%s hours##plural"] = "%s Stunde|%s Stunden",
    ["usage: |cffffd100/sd sightings of <name>|r, or target them."] =
        "so geht’s: |cffffd100/sd sightings of <Name>|r, oder nimm die Person ins Ziel.",
    ["no sightings of |cffffffff%s|r."] = "keine Sichtungen von |cffffffff%s|r.",
    ["|cffffffff%1$s|r: %2$d sighting(s), %3$s to %4$s, level %5$s-%6$s, hostile %7$d time(s)"] =
        "|cffffffff%1$s|r: %2$d Sichtung(en), %3$s bis %4$s, Stufe %5$s-%6$s, %7$d-mal feindlich",
    ["|cffffffff%1$s|r: %2$d sighting(s), %3$s to %4$s, level %5$s-%6$s"] =
        "|cffffffff%1$s|r: %2$d Sichtung(en), %3$s bis %4$s, Stufe %5$s-%6$s",
    ["%1$s, %2$s##list"] = "%1$s, %2$s",
    ["%1$s%2$s  %3$s%4$s  lvl %5$s  %6$s%7$s"] = "%1$s%2$s  %3$s%4$s  St. %5$s  %6$s%7$s",
    ["(you at %1$.1f, %2$.1f)"] = "(du bei %1$.1f, %2$.1f)",
    ["nothing to add here."] = "hier gibt es nichts hinzuzufügen.",
    ["nothing to remove here."] = "hier gibt es nichts zu entfernen.",
    ["%s added to the city list."] = "%s zur Liste der Städte hinzugefügt.",
    ["%s removed from the city list."] = "%s von der Liste der Städte entfernt.",
    ["on##switch"] = "an",
    ["off##switch"] = "aus",
    ["<- you are here"] = "<- du bist hier",
    ["here: map %1$s, %2$s -- a city."] = "hier: Karte %1$s, %2$s -- eine Stadt.",
    ["here: map %1$s, %2$s -- not a city."] = "hier: Karte %1$s, %2$s -- keine Stadt.",
    ["open the journal (also plain |cffffd100/sd|r)"] = "öffnet das Tagebuch (auch einfach |cffffd100/sd|r)",
    ["add your target to the diary, or |cffffd100/sd add <name>|r"] =
        "trägt dein Ziel ins Tagebuch ein, oder |cffffd100/sd add <Name>|r",
    ["open the Remember this picker"] = "öffnet die Auswahl „Ins Tagebuch eintragen“",
    ["list diary entries"] = "listet die Einträge im Tagebuch auf",
    ["remove <name> from the diary"] = "entfernt <Name> aus dem Tagebuch",
    ["sighting capture; |cffffd100/sd sightings help|r for more"] =
        "Sichtungen; mehr mit |cffffd100/sd sightings help|r",
    ["open the settings"] = "öffnet die Einstellungen",
    ["show the introduction again"] = "zeigt die Einführung noch einmal",
    ["delete everything about <name>, in the diary or not"] = "löscht alles über <Name>, ob im Tagebuch oder nicht",
    ["debug off."] = "Fehlersuche aus.",
    ["debug on."] = "Fehlersuche an.",
    ["turn extra chat messages on or off, for reporting a bug"] =
        "schaltet zusätzliche Chatmeldungen ein oder aus, um einen Fehler zu melden",
    ["recent [hours]"] = "recent [Stunden]",
    ["who was seen in the last 24 hours, by zone"] = "wer in den letzten 24 Stunden gesehen wurde, nach Gebiet",
    ["of <name>"] = "of <Name>",
    ["one character's sightings, or your target's"] = "die Sichtungen eines Charakters oder deines Ziels",
    ["the city list; without an id, the map you are on"] = "die Liste der Städte; ohne ID die Karte, auf der du bist",
    ["city [add or remove] [mapID]"] = "city [add oder remove] [Karten-ID]",
})
