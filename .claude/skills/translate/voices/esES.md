# Voice: esES (Spanish, Spain)

First submittal (10 Nov 2026), written by the translator from the English
voice (`/copywriter` §1 to §6) because the project has no Spanish speaker.
**Every decision below is open to the Spanish contributors**; when one
changes a decision, change it here too. Marked (?) = a guess worth a
native's first look.

## Address and people
- **tú**, never usted, never vosotros for the player. The diary says "tú"
  only where it must; Spanish drops the pronoun ("Llegaste al nivel 12",
  not "Tú llegaste…").
- The diary calls itself **el diario** ("Por lo que el diario pudo saber"),
  never "yo". Sample notes the player wrote stay first person.
- Other players: the **name**, or **esa persona** / **les** where English
  says "they". Avoid gendered forms for a person we know nothing about
  (no "el jugador", "cansado"): use the name, a verb, or "esa persona".
  Plural "they" (a group) is the masculine-neutral plural only where
  unavoidable ("se vieron"). (?)
- `{you}` braces: the brace holds the **verb phrase with its reader form**
  ("{Mataste} a Bram"); the other-character form is the same phrase in
  the third person with the name before it ("%s mató"). A braced word is
  looked up lower-case in `YOU_FOR`, and its form is **not** capitalised,
  so never brace something that must start a sentence with a capital:
  put the name or a verb first, or reword.

## Tense
- **Prose** (Your Diary, profile, tour): pretérito indefinido for events
  ("Llegaste al nivel 12 el 6 de octubre. El camino sigue."), presente for
  state ("Ya es de nivel 14"), condicional for hindsight ("Volverían a
  encontrarse en el nivel 15").
- **Ledger** (rows, tooltips): the same, short, subject dropped
  ("Misión completada juntos durante 1 h 5 min", "te mató dos veces").

## Typography
- Quotes: **«…»** (quest titles, notes), nested “…”. Apostrophe: ’ where
  one is needed. Ellipsis: … (one character).
- Inverted marks ¿ ¡ are required. Exclamation marks only where the
  English has its two allowed ones.
- Dates: "6 de octubre", with the year only when not this year: "6 de
  octubre de 2025". Weekdays lower-case ("el lunes"). Time 24 h, "18:30".
  No ordinals in dates. Months lower-case. No zero padding.
- Numbers in words up to ten, as English; figures after. Decimal comma,
  thousands separated by a no-break space or a dot (follow the helpers).
  Number and unit together with the no-break space the code uses.
- Ordinals: "25.º" (`grammar.Ordinal`); words "primero, segundo…" take
  the noun's gender per `##context` key.
- **No middle dots, ever.**
- Case: sentence case. Month and day names lower-case. Proper names keep
  their case (*Social Diary*, *Tu diario* for "Your Diary" (?)).

## Game terms (as the esES client says them; verify in the client)
| English | Spanish |
|---|---|
| level | nivel |
| group / party | grupo |
| raid | banda |
| quest | misión |
| duel | duelo |
| guild | hermandad |
| rare (creature) | raro |
| elite | élite |
| pet | mascota |
| dungeon | mazmorra |
| battleground | campo de batalla |
| World PvP | JcJ en el mundo |
| boss | jefe |
| wipe | derrota del grupo (?) |
| Need / Greed roll | Necesidad / Codicia |
| gold / silver / copper | oro / plata / cobre |
| zone | zona |
| profession | profesión |
| campfire | hoguera |
| ghost / spirit | fantasma / espíritu |
| flight path | ruta de vuelo |
| hearthstone | piedra de hogar |
| nameplate | placa de nombre |
| Horde / Alliance | Horda / Alianza |

## The diary's own words (one word each, kept)
| English | Spanish |
|---|---|
| the diary | el diario |
| Your Diary | Tu diario |
| ink in / add to the diary | anotar en el diario / añadir al diario |
| pencilled in | apuntado a lápiz |
| rubbed out / forgotten | borrado / olvidado |
| remove from the diary | quitar del diario |
| delete (for good) | eliminar |
| the road | el camino |
| route (one setting label) | ruta |
| crossed paths / met | coincidir / conocer, "se cruzaron" |
| toast (Settings, changelog) | aviso |
| card (on the card only) | tarjeta |
| foe | adversario |
| People | Personas |
| Recently nearby | Cerca hace poco |
| sighting | avistamiento |
| reunion | reencuentro |

## Length
Spanish runs about 15 to 25 % longer than English. Tight surfaces: toast
cards, key-binding column, tickets, Settings labels, tab names, map keys,
`Windows/Reunion` lines. There, prefer the shorter phrasing ("Reencuentro",
not "Un reencuentro con alguien").

## Not settled
- Gender of "they" for a stranger; gendered ordinal (º/ª) in
  `Format.Ordinal` (no noun to agree with).
- Whether "Tu diario" or "Mi diario" fits the tab name.
