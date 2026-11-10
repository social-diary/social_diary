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
- **Gender from the game** (second pass, 10 Nov 2026): a participle or
  adjective that agrees with the reader or a named character takes the
  forms, `<you:Al nuevo titular/A la nueva titular>`, `<1:solo/sola>`
  (`Locales/Locale.lua`, "A person's gender"). Only where the key names
  the character (a value that is a player's name) or the reader; a word
  about a third person in a key with no name stays masculine or is said
  impersonally ("Se añadió al diario", not "Añadido al diario").
  Verbs in the pretérito need no forms, so most lines need none.
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
  octubre de 2025"; short "6 oct", "6 oct 2025". Weekdays lower-case ("el
  lunes"). No ordinals in dates. Months lower-case. No zero padding.
- Time 24 h, the hour unpadded (`G.Clock`): "18:30", "9:05". In a
  sentence "a las 18:30", and the words always write "a las %s": `G.Agree`
  turns "las 1:05" into "la 1:05".
- Numbers in words up to ten, as English; figures after. The word for 1
  is "un"; where it arrives as a value before a feminine noun, mark it
  `%s<f>` and `G.Agree` writes "una" ("victorias: %2$s<f>"). Where the
  count is the plural's own, the first form says it whole instead ("cayó
  uno|cayeron %s", "una caza lenta|%s cazas lentas"). Decimal comma,
  thousands separated by a no-break space or a dot (follow the helpers).
  Number and unit together with the no-break space the code uses.
- Ordinals: "25.º", and "25.ª" for a death or a match (`grammar.Ordinal`
  with the word list's context); words "primero, segundo…" take the noun's
  gender per `##context` key ("primer intento", "primera partida").
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
- Gender of "they" for a stranger with no name in the key ("Un
  adversario se unió a tu grupo", "Añadido"): masculine for now.
- Whether "Tu diario" or "Mi diario" fits the tab name.
- "You and they" is the third person plural ("Se cruzaron una vez",
  "Entre tú y Feivel murieron…"), never vosotros ("os cruzasteis"). (?)
