# Voice: ruRU (Russian)

First submittal (10 Nov 2026), written by the translator from the English
voice (`/copywriter` §1 to §6) because the project has no Russian speaker.
**Every decision below is open to the Russian contributors**; when one
changes a decision, change it here too. Marked (?) = a guess worth a
native's first look.

## Gender: the forms in the words (second pass, 10 Nov 2026)
Russian past tense and short participles agree with the subject's sex.
The framework now knows it (the game's own sex of each character, and of
the one playing), so **write the past tense and pick the form**:
`%1$s <1:погиб/погибла>`, `{Ты} <you:погиб/погибла>` (Locales/Locale.lua,
"A person's gender"). Never rebuild a sentence round a colon, a noun label,
an impersonal plural or the historic present only to dodge a gender.
- `<N:...>` only where value N is a player character's name (from
  `ns.Characters.Name/FullName`, a group member's first name). Creature,
  item, boss and zone names cannot be matched: a creature as subject keeps
  a wording that needs no agreement ("убили тебя", "виновник — %s").
- **Two forms, masculine first**, is the house default: with the sex not
  known the first is used, the masculine is Russian's ordinary fallback,
  and it agrees with the stand-in name "Этот персонаж" (`They`,
  `They##someone`, `them##killed`). A subject with no name value at all
  is written "Этот персонаж убил {тебя}" (masculine, agreeing with
  "персонаж").
- A **third form** only where the name may be one the player typed (a
  custom card) or a scoreboard's and the masculine would be a guess: the
  present ("сбегает"), or the old colon wording inside the form
  (`%1$s<1: убил тебя/ убила тебя/: тебя убили> %2$s`).
- A line that starts with the reader: "{Ты} ..." (the capital is in
  `YOU_FOR`, since string.lower leaves Cyrillic alone), or the capital
  inside the forms (`<you:Ты отдыхал/Ты отдыхала>`).
- Where a deed is a value with no name in its template
  (Witnesses.Deed: "saved you" under a name), no form can reach it: those
  stay in the present ("спасает тебя"), as do the `##line` deeds.
- The fallbacks still in use, in order: a noun phrase; an impersonal or
  indefinite-plural verb where the subject is no person ("тебя убили" by a
  creature); a dative or genitive; a plural subject ("вы", "мы").

## Number words
`a##one` is "один"; a number word before a feminine or neuter noun carries
`<f>` / `<n>` after its placeholder (`%s<f> заметка` gives "одна заметка",
"две заметки"; `%s<n> поражение`). Nominative only: a number word in a
case-governed slot ("после двух", "во всех трёх") stays after a colon.

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
  capitalised in the other form, so brace a sentence's first word only
  where that form begins with the name ("{Ты}" is "%s"; never "{твоя
  группа}" first: "Этого персонажа убила {твоя группа}").

## Tense
- **Prose** (Your Diary, profile, tour) and **rows** (timeline, toasts):
  the past tense, with the gender forms ("Брам погиб рядом с зоной «…»",
  "Ты задержалась в зоне «…» на полчаса", "Нума спасла тебя"). State in the
  present ("Брам теперь на 14-м уровне").
- **Ledger** (tooltip lines, margin notes): short, often no subject
  ("Задание выполнено вместе за 1 ч 5 мин", "убили тебя дважды").

## Typography
- Places: a noun takes the case and the client's name follows in quotes,
  undeclined: "в зоне «Доланаар»", "в зону", "из зоны", "рядом с зоной";
  a dungeon "в подземелье «…»" (`Grammar.lua`, `PLACE` and `DUNGEONS`).
  Never a bare preposition before a quoted name ("в «Доланаар»"): it
  reads as a missed case (player report, 13 Nov 2026).
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
- Ordinals: "25-й", "13-я" for a death (`grammar.Ordinal(n, context)`);
  words "первый, второй…" take the noun's gender per `##context` key.
  A date's day is the figure: "25 окт" (`grammar.Day`).
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
- How to say "they" of one stranger where no name is in the template
  ("They said", "They whispered", the picker's reasons): still "они" or an
  impersonal plural.
- "Твой дневник" or "Дневник" as the tab name.
- Whether the masculine as the unknown-sex default reads well, or a
  native prefers the third form ("погиб(ла)") in more places.
