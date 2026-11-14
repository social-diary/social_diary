# Voice: itIT (Italian, Italy)

First submittal (14 Nov 2026), written with AI from the English voice
(`/copywriter` §1 to §6) and modelled on esES/frFR. **Every decision below
is open to Italian contributors**; Marked (?) = a guess worth a native's
first look. Translator: a guild-mate of the WoW Classic "Forever" community
(English client only, no Italian client exists), so game terms stay English.

## Address and people
- **tu**, never Lei, for the player. Italian drops the subject pronoun
  ("Hai raggiunto il Level 12", not "Tu hai raggiunto...").
- The diary calls itself **il diario** ("Per quanto il diario ha potuto
  vedere"), never "io". Sample notes the player wrote stay first person.
- Other players: the **name**, or **quella persona** where English says
  "they". No "il giocatore", and no adjective that agrees with someone whose
  sex no value carries.
- **Gender from the game.** Participles with *essere* agree: `<you:morto/morta>`
  for the reader, `<1:è morto/è morta/è morto>` for a named character. Most
  lines use *avere* (passato prossimo "hai ucciso") and need no forms.
- `{you}` braces: the brace holds the **verb phrase in its reader form**
  ("{Hai ucciso} Bram"); its other-character form is the third person with
  the name ("%s ha ucciso"), registered in `YOU_FOR` (lower case, not
  capitalised by the code).

## Tense
- **Prose**: **passato prossimo** for events ("Hai raggiunto il Level 12 il
  6 ottobre. La strada continua."), presente for state, condizionale for
  hindsight.
- **Ledger** (rows, tooltips): the same, short, subject dropped.

## Typography
- Quotes: **«…»**, nested “…”. Apostrophe: ’ (curly). Ellipsis: … (one char).
- Dates: "6 ottobre", with the year only when not this year ("6 ottobre
  2025"), short "6 ott", "6 ott 2025". Months and weekdays lower case. "1°"
  is NOT used: dates take the figure (`G.Day`).
- Time 24 h, hour unpadded ("18:30", "9:05"). In a sentence "alle 18:30";
  `G.Agree` turns "alle 1:05" into "all’1:05" and "alle 0:" into "a
  mezzanotte"-free "alle 0:".
- Numbers in words up to ten, as English; figures after. Decimal comma.
- Ordinals: "25°" (`G.Ordinal`), "25ª" for a feminine noun (death "morte",
  match "partita").
- **No middle dots, ever.**
- Case: sentence case. Proper names keep their case (*Social Diary*, *Il tuo
  diario* for "Your Diary" (?)).

## Game terms (the English client has no Italian: kept English)
| English | Italian |
|---|---|
| level | Level (?) |
| group / party | gruppo |
| raid | raid |
| quest | quest (f.) |
| duel | duello |
| guild | guild (f.) |
| rare / elite | rare / elite |
| pet | pet |
| dungeon | dungeon |
| battleground | battleground |
| World PvP | PvP in mondo aperto (?) |
| boss | boss |
| wipe | wipe |
| Need / Greed | Need / Greed |
| gold / silver / copper | oro / argento / rame |
| zone | zona |
| profession | professione |
| campfire | falò |
| ghost / spirit | fantasma / spirito |
| flight path | flight path |
| hearthstone | Hearthstone |
| nameplate | nameplate |
| Horde / Alliance | Horde / Alliance |

## The diary's own words (one word each, kept)
| English | Italian |
|---|---|
| the diary | il diario |
| Your Diary | Il tuo diario |
| ink in / add to the diary | annotare nel diario / aggiungere al diario |
| pencilled in | segnato a matita |
| rubbed out / forgotten | cancellato / dimenticato |
| remove from the diary | togliere dal diario |
| delete (for good) | eliminare |
| the road | la strada |
| route (one setting label) | percorso |
| crossed paths / met | incrociarsi / conoscere |
| toast (Settings, changelog) | avviso |
| card (on the card only) | scheda |
| foe | avversario |
| People | Persone |
| Recently nearby | Vicini da poco |
| sighting | avvistamento |
| reunion | rincontro |

## Length
Italian runs about 15 to 25 % longer than English. Tight surfaces: toast
cards, key-binding column, tickets, Settings labels, tab names, map keys.
There prefer the shorter phrasing.

## Not settled
- "Level" vs "livello" (the English client shows "Level").
- Gender of "they" for a stranger with no name in the key: masculine for now.
