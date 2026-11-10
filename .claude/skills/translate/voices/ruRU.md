# Voice: ruRU (Russian)

First submittal (10 Nov 2026), written by the translator from the English
voice (`/copywriter` §1 to §6) because the project has no Russian speaker.
**Every decision below is open to the Russian contributors**; when one
changes a decision, change it here too. Marked (?) = a guess worth a
native's first look.

## The one hard problem: gender
Russian past tense and short participles agree with the subject's gender
("пришёл / пришла", "убит / убита"). The diary knows neither the reader's
nor a stranger's. So **no finite past-tense verb or short participle may
have the reader or a stranger as its singular subject**. The ways out, in
order of preference:
1. A noun phrase or the verb's own noun: "12-й уровень, 6 октября",
   "Встреча в Элвиннском лесу".
2. An impersonal or indefinite-plural verb: "тебя убили", "тебе встретился
   Брам", "тебе не удалось".
3. A dative or genitive construction: "от руки Брама", "у тебя".
4. A verb whose subject is a thing, the diary or a group (plural past is
   gender-free: "они встретились", "вы сыграли").
5. Present tense (the historic present is natural in Russian diaries).
Past tense of a thing agrees with the thing ("уровень достигнут",
"поединок завершился"). Where nothing works, leave the key and report it.

## Address and people
- **ты**, lower case, never вы for the player. The diary says "ты" only
  where it must; Russian drops it where it can.
- The diary calls itself **дневник** ("Насколько дневник мог судить"),
  never "я". Sample notes the player wrote stay first person; first
  person singular there is gender-free only in present tense, keep it.
- Other players: the **name**, or **этот персонаж** / **они** (plural
  verbs) where English says "they". Never "игрок" with a gendered
  adjective. Names arrive bare from the game and do not decline: write
  sentences so a bare nominative reads (as subject, after a colon, "с %s"
  is acceptable only where the name is invariable: prefer "вместе с
  персонажем %s" (?)).
- `{you}` braces: brace the shortest reader word that changes ("{тебя}",
  "{тебе}", "{твоя}"); every braced word goes into `YOU_FOR`, lower case,
  with its form for another character's name. A braced word is **not**
  capitalised in the other form, so never brace a sentence's first word.

## Tense
- **Prose** (Your Diary, profile, tour): the gender rule above; events in
  noun phrases, impersonal verbs or the present, state in the present
  ("Ему уже 14-й уровень" is wrong: "Теперь у него 14-й уровень" is
  gendered only by "него", acceptable for a stranger because the diary
  says "у этого персонажа 14-й уровень" (?)).
- **Ledger** (rows, tooltips): short, no subject ("Задание выполнено
  вместе за 1 ч 5 мин", "убили тебя дважды").

## Typography
- Quotes: **«…»**, nested „…“. Apostrophe not needed. Ellipsis: …
  (one character). Dash: the long dash — only where Russian needs it
  (subject and predicate); never a hyphen as a dash.
- Exclamation marks only where the English has its two allowed ones.
- Dates: "6 октября" (genitive months, lower case), with the year only
  when not this year: "6 октября 2025 г." (?). Weekdays lower case
  ("в понедельник"). Time 24 h, "18:30". No zero padding.
- Numbers in words up to ten, as English; figures after. Decimal comma.
  Number and unit together with the no-break space the code uses.
  Counts always through the three plural forms (1 / 2-4 / 5+, 21 is "one").
- Ordinals: "25-й" (`grammar.Ordinal`, masculine only: see the code
  changes); words "первый, второй…" take the noun's gender per
  `##context` key.
- **No middle dots, ever.**
- Case: sentence case. Months and weekdays lower case. Proper names keep
  their case (*Social Diary*; "Твой дневник" for "Your Diary" (?)).
- Use «ё» where it is ambiguous only as the game client does ("всё").

## Game terms (as the ruRU client says them; verify in the client)
| English | Russian |
|---|---|
| level | уровень |
| group / party | группа |
| raid | рейд |
| quest | задание |
| duel | дуэль |
| guild | гильдия |
| rare (creature) | редкий противник (?) |
| elite | элитный |
| pet | питомец |
| dungeon | подземелье |
| battleground | поле боя |
| World PvP | PvP в открытом мире |
| boss | босс |
| wipe | поражение группы (?) |
| Need / Greed roll | «Мне это нужно» / «Не откажусь» (?) |
| gold / silver / copper | золото / серебро / медь (`%dg` → "з", `%ds` → "с", `%dc` → "м") |
| zone | зона |
| profession | профессия |
| campfire | костёр |
| ghost / spirit | призрак / дух |
| flight path | маршрут полёта |
| hearthstone | камень возвращения |
| nameplate | индикатор здоровья (?) |
| Horde / Alliance | Орда / Альянс |

## The diary's own words (one word each, kept)
| English | Russian |
|---|---|
| the diary | дневник |
| Your Diary | Твой дневник |
| ink in / add to the diary | записать в дневник / добавить в дневник |
| pencilled in | записан карандашом |
| rubbed out / forgotten | стёрт / забыт |
| remove from the diary | убрать из дневника |
| delete (for good) | удалить |
| the road | путь |
| route (one setting label) | маршрут |
| crossed paths / met | пересеклись / встреча |
| toast (Settings, changelog) | уведомление |
| card (on the card only) | карточка |
| foe | недруг |
| People | Люди |
| Recently nearby | Недавно рядом |
| sighting | замечен |
| reunion | новая встреча |

## Length
Russian runs 20 to 35 % longer than English. Tight surfaces: toast cards,
key-binding column, tickets, Settings labels, tab names, map keys,
`Windows/Reunion` lines. There prefer the short noun phrase ("Встреча",
not "Ты снова встретил кого-то").

## Not settled
- How to say "they" of one stranger without gender.
- "Твой дневник" or "Дневник" as the tab name.
- Whether a gender-aware record (the character's stored `sex`) is wanted
  later: see `ruRU-code-changes.md`.
