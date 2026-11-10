# German (deDE)

The diary is a quiet German diary, not a translation of the English one.
Every decision below was made once; a key follows it, never re-decides it.

## Address

- The player is **du**, lower case as in a letter today ("dein Weg",
  "hast du"). Never *Sie*.
- Other players are *sie* (plural) or are named. A name the game gives goes
  bare, with no article: as the subject, or after a colon.
- The reader's words are braced for a shared diary: `{Du hast}`, `{dich}`,
  `{dir}`, `{dein}`. Every braced form is in `G.YOU_FOR`
  (`Locales/deDE/Grammar.lua`). After *für* it is `{dich}`, after *von* it
  is `{dir}`.

## Tense

- **Prose** (Your Diary, the profile, the tour): Präteritum, with the
  subject dropped where the English drops it ("Erreichte am 6. Oktober
  Stufe 12.").
- **Ledger lines** (tooltips, timeline rows, margin words): Perfekt or a
  bare participle ("Zusammen gequestet", "Hier gestorben").
- **The parcel** (`UI/Windows/Intro/`) is the one place the diary says
  *ich* and jokes. Everywhere else it is the quiet diary.

## Typography

- Quotes: „…“ (`\226\128\158` … `\226\128\156`); inner quotes ‚…‘.
- Ellipsis: the single character …, with no space before it.
- Apostrophe: ' (as the client writes it), and only where German needs
  one (the genitive after s, x, z, ß: "Thex'").
- Dates: "6. Oktober", "6. Okt."; the ordinal is "25." (`G.Ordinal`).
  Times: "21:43", "um 21:43".
- Durations: "1 Std. 5 Min.", "5 Min.".
- Numbers in words up to twelve (and the round ones the English spells
  out); a count after that is in digits.
- "%d-mal" for times, "zweimal" for twice.
- **No middle dots**, ever. Say it with a comma, *und*, or its own line,
  as the English now does.

## Game terms (as the German client says them)

| English | German |
|---|---|
| level | Stufe |
| group | Gruppe |
| raid | Schlachtzug ("geraidet" as a verb) |
| quest | Quest (die), "gequestet" |
| duel | Duell |
| guild | Gilde |
| rare / rare elite | Selten / Seltene Elite, "ein Seltener" |
| elite / boss | Elite / Boss |
| pet (tamed) | Tier ("Gezähmtes Tier") |
| run (dungeon) | Durchlauf |
| wipe | Wipe, "gewipt" |
| health | Gesundheit |
| killing blow | Todesstoß (Todesstöße) |
| kill (noun) / honourable kill | Kill (Kills) / "an %d Kills beteiligt" |
| times, with a number word or a figure | "%s Mal" where the count may be a word or a figure ("drei Mal", "21 Mal"); "%d-mal" with a figure alone |
| battleground / match / scoreboard | Schlachtfeld / das Match (Matches) / Punktetafel (not yet checked in the client); an ordinal before Match is neuter ("dein erstes Match") |

## The diary's own words

| English | German |
|---|---|
| the diary | das Tagebuch |
| add to the diary / added | ins Tagebuch eintragen / eingetragen |
| remember this | Ins Tagebuch eintragen |
| the road | der Weg ("Der Weg geht weiter.", "Unterwegs") |
| kept (recorded) | aufgezeichnet |
| a note | eine Notiz |
| a sighting / seen | eine Sichtung / gesehen |
| first seen / last seen | zuerst gesehen / zuletzt gesehen |
| met | getroffen |
| a session | eine Sitzung |

## Places

- A place arrives as a whole phrase with its preposition (`##zone`, through
  `ns.ZoneIn` / `ns.DungeonIn`). A template never writes a preposition
  before it.
- `G.PLACE` holds the plain prepositions: in, nach, aus, in, durch, bei,
  bei, um, rund um.
- `G.ZONES`, `G.DUNGEONS` and `G.SUBZONES` ("im Brachland", "in den
  Todesminen", "am Wegekreuz") are filled only from names checked in a
  German client, never from memory. Until then they stay empty and the plain
  preposition reads ("in Brachland").

## Length

German runs about a third longer than English. These surfaces are tight,
so prefer the shorter phrasing there:

- the reunion toast and the cards on Your Diary's plates
- the key-binding column
- Settings labels and the number row
- the timeline's tickets and filters

Use abbreviations where the client uses them (Std., Min., Okt.). Drop the
subject sooner than abbreviate a word.

## Not settled yet

(none)
