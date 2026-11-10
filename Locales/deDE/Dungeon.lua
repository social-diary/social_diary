-- German (deDE): Dungeon. Keys are the English text (Locales/enUS.lua).
--
-- A run is a "Durchlauf"; a wipe is "gewipt", as German players say it.
-- The "{you}" a sentence takes is declined by what it follows: "{dich}"
-- after "für", "{dir}" after "von" (UI/Dungeon/Words.lua's For and From).

local addonName, ns = ...

ns.Locale.Add("deDE", {
    -- UI/Dungeon/Words.lua: tries and wipes
    ["first##try"] = "ersten", ["second##try"] = "zweiten", ["third##try"] = "dritten", ["fourth##try"] = "vierten",
    ["fifth##try"] = "fünften", ["sixth##try"] = "sechsten", ["seventh##try"] = "siebten", ["eighth##try"] = "achten",
    ["ninth##try"] = "neunten", ["tenth##try"] = "zehnten",
    ["Wiped %s"] = "%s gewipt",
    ["Tried %s"] = "%s versucht",
    ["killed on the %s try"] = "beim %s Versuch besiegt",
    ["left standing"] = "blieb stehen",
    ["Ran back %s"] = "%s zurückgelaufen",
    ["as a ghost"] = "als Geist",
    ["Ran back %s as a ghost"] = "%s als Geist zurückgelaufen",
    ["Wiped on the way"] = "Unterwegs gewipt",
    ["to %s and others"] = "durch %s und andere",
    ["to %s##killers"] = "durch %s",
    ["Nearly wiped"] = "Fast gewipt",
    ["%s went down|%s went down##plural"] = "einer ging zu Boden|%s gingen zu Boden",

    -- loot
    ["someone"] = "jemand",
    ["{you}##for"] = "{dich}",
    ["{you}##from"] = "{dir}",
    ["dropped for %s"] = "fiel für %s",
    ["dropped for %s on the way"] = "fiel unterwegs für %s",
    ["%1$s, dropped for %2$s"] = "%1$s, für %2$s",
    ["One item for someone else|%s items for others##plural"] =
        "Ein Gegenstand für jemand anderen|%s Gegenstände für andere",

    -- deaths
    ["{You} died"] = "{Du bist} gestorben",
    ["{You} died to %s"] = "{Du bist} durch %s gestorben",
    ["{You} died, probably to %s"] = "{Du bist} gestorben, vermutlich durch %s",
    ["{You} died (%s)"] = "{Du bist} gestorben (%s)",
    ["%s died"] = "%s ist gestorben",
    ["%1$s died to %2$s"] = "%1$s ist durch %2$s gestorben",
    ["%1$s died, probably to %2$s"] = "%1$s ist gestorben, vermutlich durch %2$s",
    ["%1$s died (%2$s)"] = "%1$s ist gestorben (%2$s)",
    ["falling"] = "Sturz", ["drowning"] = "Ertrinken", ["fatigue"] = "Erschöpfung", ["fire"] = "Feuer",
    ["lava"] = "Lava", ["slime"] = "Schleim",
    ["On the way to %s"] = "Auf dem Weg zu %s",
    ["After %s"] = "Nach %s",
    ["On the way in"] = "Auf dem Weg hinein",

    -- levels and rolls
    ["Reached by %s"] = "Erreicht von %s",
    ["%s snagged it"] = "%s hat es",
    ["%1$s from %2$s##snagged"] = "%1$s %2$s weggeschnappt",
    ["%1$d against %2$d"] = "%1$d gegen %2$d",
    ["Finally! After %s drop, it's yours|Finally! After %s drops, it's yours##plural"] =
        "Endlich! Nach einem Drop gehört es dir|Endlich! Nach %s Drops gehört es dir",
    ["Finally!"] = "Endlich!",
    ["{You} rolled a %d"] = "{Du hast} eine %d gewürfelt",
    ["%1$s rolled a %2$d"] = "%1$s hat eine %2$d gewürfelt",
    ["on %s##item"] = "um %s",

    -- UI/Dungeon/Print.lua
    ["The way in"] = "Der Weg hinein",
    ["Killed on this run, going by its loot"] = "In diesem Durchlauf besiegt, der Beute nach",
    ["Killed on this run"] = "In diesem Durchlauf besiegt",
    ["Rare##boss"] = "Selten",
    ["Not killed on this run"] = "In diesem Durchlauf nicht besiegt",

    -- UI/Dungeon/Sheet.lua
    ["Floor %d"] = "Ebene %d",
    ["The diary has no map of %s yet."] = "Das Tagebuch hat noch keine Karte von %s.",
    ["this place"] = "diesem Ort",

    -- UI/Dungeon/Spread.lua: the bookmark (the name in the genitive, "Thrains Geschichte")
    ["Your Diary"] = "Dein Tagebuch",
    ["%s's story"] = "%s Geschichte",
    ["Their story"] = "Ihre Geschichte",

    -- UI/Dungeon/Tutorial.lua
    ["About this map"] = "Zu dieser Karte",
    ["There is no navigation data inside dungeons, so the diary has to work out where things happened."] =
        "In Dungeons gibt es keine Wegdaten, also muss das Tagebuch selbst herausfinden, wo etwas geschah.",
    ["It uses a default route, the usual way through, to pinpoint the spots."] =
        "Dafür nimmt es einen Standardweg, den üblichen Weg hindurch, und bestimmt daran die Stellen.",
    ["If you went another way on a run, use Adjust Path at the top of the map to draw your own."] =
        "Bist du in einem Durchlauf anders gegangen, zeichne mit „Pfad anpassen“ oben auf der Karte deinen eigenen.",
    ["Got it"] = "Verstanden",

    -- UI/Dungeon/Way.lua: drawing the path (plain and literal, as the English)
    ["Adjust Path"] = "Pfad anpassen",
    ["Draw the way you went on this run. It starts from the usual way through."] =
        "Zeichne den Weg, den du in diesem Durchlauf gegangen bist. Er beginnt beim üblichen Weg hindurch.",
    ["Change the path you drew for this run."] = "Ändere den Pfad, den du für diesen Durchlauf gezeichnet hast.",
    ["DRAWING YOUR PATH"] = "PFAD ZEICHNEN",
    ["Click the map to add a point. Click a boss to add a stop. Click stairs or a door to add a step. Ctrl-click a line to insert a point. Drag a point to move it. Right-click a point to delete it."] =
        "Klicke auf die Karte, um einen Punkt zu setzen. Klicke auf einen Boss, um einen Halt zu setzen. "
        .. "Klicke auf Treppen oder eine Tür, um einen Übergang zu setzen. Strg-Klick auf eine Linie fügt einen "
        .. "Punkt ein. Ziehe einen Punkt, um ihn zu verschieben. Rechtsklick auf einen Punkt löscht ihn.",
    ["No point selected. New points go at the end."] = "Kein Punkt ausgewählt. Neue Punkte kommen ans Ende.",
    ["Point %1$d of %2$d selected."] = "Punkt %1$d von %2$d ausgewählt.",
    ["The path ends at point %d. Click a grey point to join it back up."] =
        "Der Pfad endet bei Punkt %d. Klicke auf einen grauen Punkt, um ihn wieder anzuschließen.",
    ["Joined the path back up."] = "Pfad wieder angeschlossen.",
    ["Joined the path back up. Left out: %s."] = "Pfad wieder angeschlossen. Ausgelassen: %s.",
    ["The path is full (at most %d points)."] = "Der Pfad ist voll (höchstens %d Punkte).",
    ["Reset the path for this run?\n\nThe path you drew is removed and the usual way through shows again.\n\nThis cannot be undone."] =
        "Den Pfad für diesen Durchlauf zurücksetzen?\n\nDer gezeichnete Pfad wird entfernt, und der übliche Weg "
        .. "hindurch erscheint wieder.\n\nDies kann nicht rückgängig gemacht werden.",
    ["Reset Path"] = "Pfad zurücksetzen",
    ["Done"] = "Fertig",
    ["Stop drawing and keep the path."] = "Mit dem Zeichnen aufhören und den Pfad behalten.",
    ["Undo"] = "Rückgängig",
    ["Take back the last change."] = "Die letzte Änderung zurücknehmen.",
    ["Previous Point"] = "Voriger Punkt",
    ["Select the point before the selected one."] = "Den Punkt vor dem ausgewählten auswählen.",
    ["Next Point"] = "Nächster Punkt",
    ["Select the point after the selected one."] = "Den Punkt nach dem ausgewählten auswählen.",
    ["Delete Point"] = "Punkt löschen",
    ["Delete the selected point."] = "Den ausgewählten Punkt löschen.",
    ["Set early End point"] = "Früheres Ende setzen",
    ["End the path at the selected point. The rest turns grey. Draw on from here, then click a grey point to join it back up. If you don't, Done joins the first grey point."] =
        "Den Pfad beim ausgewählten Punkt enden lassen. Der Rest wird grau. Zeichne von hier weiter und klicke dann "
        .. "auf einen grauen Punkt, um ihn wieder anzuschließen. Tust du das nicht, schließt „Fertig“ den ersten "
        .. "grauen Punkt an.",
    ["Clear"] = "Leeren",
    ["Remove every point, to draw the path from the start."] = "Alle Punkte entfernen, um den Pfad von vorn zu zeichnen.",
    ["Reset"] = "Zurücksetzen",
    ["Remove the path you drew for this run and show the usual way through again."] =
        "Den gezeichneten Pfad für diesen Durchlauf entfernen und wieder den üblichen Weg hindurch zeigen.",
    ["Stairs up"] = "Treppe hinauf",
    ["Stairs down"] = "Treppe hinab",
    ["Passage"] = "Durchgang",
    ["Entrance"] = "Eingang",
    ["Exit"] = "Ausgang",
    ["Portal"] = "Portal",
    ["Trigger"] = "Auslöser",
    ["Click to add this step to the path."] = "Klicken, um diesen Übergang zum Pfad hinzuzufügen.",
    ["Click to add this step to the path, and its other end."] =
        "Klicken, um diesen Übergang und sein anderes Ende zum Pfad hinzuzufügen.",
    ["Click to add a stop at this boss."] = "Klicken, um bei diesem Boss einen Halt hinzuzufügen.",
    ["Point %d. Drag to move it. Right-click to delete it."] = "Punkt %d. Ziehen zum Verschieben, Rechtsklick zum Löschen.",
    ["Point %d. Right-click to delete it."] = "Punkt %d. Rechtsklick zum Löschen.",
    ["Click to join the path back up here."] = "Klicken, um den Pfad hier wieder anzuschließen.",

    -- UI/Dungeon/Pad.lua: the pad's prompts on the table
    ["See this floor"] = "Diese Ebene ansehen",
    ["See another floor"] = "Andere Ebene ansehen",
    ["Put the map away"] = "Karte weglegen",
    ["Put the note away"] = "Notiz weglegen",
})
