# Voice: deDE (German, Germany)

Settled by the first German translation (CarnVanBeck, pr-4, 9 Nov 2026,
written as the German section of `/copywriter`), carried over and brought
to the current framework on 11 Nov 2026. Marked (?) = worth a native's
second look. Companion, if one is needed: `deDE-code-changes.md`
(framework faults).

## Address and people
- **du**, lower case (as in a letter today), never *Sie*. German drops no
  pronoun, so "du" is said where the verb needs it ("Du hast Stufe 12
  erreicht"); ledger lines drop the subject as the English does ("1 Std.
  5 Min. zusammen gequestet").
- The diary calls itself **das Tagebuch**, never "ich". Sample notes the
  player wrote stay first person.
- Other players: the **name**, or **sie** (plural) where English says
  "they". German past participles do not agree with the subject, so most
  sentences need no gender forms. Where one does (an adjective or noun for
  a person: "der/die Erste", "tot", "Retter/Retterin"), use the forms
  `<1:er/sie/er>` (§2 of the skill) rather than a slash or an asterisk;
  better still, a sentence that needs none.
- `{you}` braces hold the pronoun with its verb where the verb changes
  with it: "{Du hast}" -> "Thex hat", "{dich}" -> "Thex". Every braced word
  goes into `YOU_FOR` (`Grammar.lua`), lower case. A possessive ("{deine}
  Gruppe") becomes the name's genitive ("Thex’ Gruppe", "Thrains Gruppe").

## Tense
- **Prose** (Your Diary, the profile, the tour): **Präteritum** for
  events ("Erreichte am 6. Oktober Stufe 12. Der Weg geht weiter.").
  Präsens for state; Konjunktiv II for hindsight ("Ihr würdet euch auf
  Stufe 15 wiedersehen").
- **Ledger** (rows, tooltips, cards): **Perfekt** or a bare participle,
  subject dropped where the English drops it ("Zusammen gequestet in
  Westfall", "hat dich zweimal getötet").
- A spoken time (`UI/Journey/Text/Time.lua`) arrives in the accusative
  ("einen Augenblick", "eine halbe Stunde"): templates take it as a span,
  "%s lang", "%s später", "%s zusammen".

## Typography
- Quotes **„…“**, nested **‚…‘**. Apostrophe **’**. Ellipsis **…** (one
  character).
- **No middle dots, ever** (`tests/copy_rules.lua`). Where the English
  separates with words or a comma, so does the German; two facts in one
  line take a comma, "und" or a dash with spaces ("Gesehen am 6. Okt., zuletzt
  gestern").
- Dates: "6. Oktober", "6. Okt.", with the year only where the English has
  it ("6. Oktober 2025"); weekday "Montag, 6. Oktober". `G.Day` gives the
  day with its point ("6."), so a date template never adds one.
- Time of day: "18:30", "um 18:30 Uhr" in prose. Durations: "1 Std.
  5 Min." in ledger lines, words in prose ("eine halbe Stunde").
- Numbers in words up to twelve in prose, figures after. Decimal comma
  (`G.DECIMAL`). Ordinals "25." (`G.Ordinal`), in words "erste, zweite…"
  where a word list exists (`first##death`, `first##match`): declined for
  the noun they stand before.
- Counts: two forms, "eine Notiz|%d Notizen". The first form may leave the
  figure out (1 alone). A number word that arrives as a value before a
  feminine noun is marked `%s<f>` ("ein" -> "eine", `G.Agree`).
- "zweimal" for "twice", "%d-mal" for the rest.
- Case: German nouns keep their capital everywhere, labels in sentence
  case otherwise. Exclamation marks only where the English has its two.

## Game terms (as the deDE client says them; verify in the client)
| English | German |
|---|---|
| level | Stufe |
| group / party | Gruppe |
| raid | Schlachtzug |
| quest | Quest (die) |
| duel | Duell |
| guild | Gilde |
| friends list | Freundesliste |
| rare (creature) | Rare / seltener Gegner (?) |
| elite | Elite |
| pet (hunter) | Begleiter |
| tame | zähmen |
| dungeon | Dungeon / Instanz |
| battleground | Schlachtfeld |
| match (battleground) | Partie (?) |
| World PvP | Welt-PvP |
| boss | Boss |
| wipe | Wipe, "gewiped" (as German players say it) |
| run (a dungeon) | Durchlauf |
| Need / Greed roll | Bedarf / Gier |
| gold / silver / copper | Gold / Silber / Kupfer (g / s / k) |
| zone | Gebiet |
| skill / profession | Fertigkeit / Beruf |
| campfire | Lagerfeuer |
| spirit healer / resurrection | Geistheiler / Wiederbelebung |
| flight path | Flugroute |
| hearthstone | Ruhestein |
| whisper | flüstern |
| trade | Handel |
| Horde / Alliance | Horde / Allianz |

## The diary's own words (one word each, kept)
| English | German |
|---|---|
| the diary | das Tagebuch |
| Your Diary | Dein Tagebuch |
| add to the diary | ins Tagebuch eintragen |
| pencilled in | mit Bleistift notiert |
| rubbed out | ausradiert |
| remove from the diary | aus dem Tagebuch entfernen |
| delete (for good) | löschen |
| the road | der Weg |
| route (the one setting) | Route |
| foe | Feind |
| a meeting / crossed paths | Begegnung / sich begegnen |
| card | Karte |
| toast | Hinweis (in Settings: Einblendung) |
| sighting | Sichtung |
| reunion | Wiedersehen |
| People | Personen (?) |
| close call | knapp entkommen (?) |
| hunt | Jagd |
| witness | Zeuge |

## Game-supplied names
Zones, creatures, items, classes arrive in German without an article
anyone can know: write the sentence so a bare name reads (as the subject,
after a colon, after "bei"/"in"/"nach" where no article is needed). Never
"ein/eine %s" or "des %s".

Zones, subzones and dungeons are the exception: the client gives them in
the nominative with their article ("Das Brachland"), and `G.PLACE` in
`Grammar.lua` reads it (settled 13 Nov 2026, from players' reports of
"Flog nach Das Brachland", "Zum ersten Mal nach Stormwind"):
- `in` dative ("im Brachland", "in den Sümpfen des Elends"), `to` "nach"
  before a bare name and "in" + accusative before an article ("nach
  Stormwind", "in das Brachland": spelled out, not "ins"), `into` "in"
  either way ("Zum ersten Mal in Stormwind", "in das Brachland").
- "Die" is plural unless the noun's ending is feminine (`FEMININE`); a bare
  name takes an article only for a landscape noun (`BARE`: "-gebirge",
  "-tal", "-steppe"); cities stay bare.
- Every name of a list takes its own preposition (`EACH_PLACE`).
- A name the rules miss goes into `GENDER` or `ZONES`/`SUBZONES`/`DUNGEONS`.

## Length
German runs about a third longer than English. Tight surfaces: toast
cards, the key-binding column, tickets, Settings labels and section
descriptions, tab names, map keys, the reunion toast. There prefer the
shorter natural phrasing. A Settings section's description that does not
fit beside its heading needed a layout change in pr-4 (UI/Settings/Kit.lua,
not carried over: a code change, see the report).

## Not settled
- "Rare" vs "seltener Gegner" for a rare creature.
- "Partie" vs "Match" for a battleground match.
- "Personen" vs "Leute" for the People page.
