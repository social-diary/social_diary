---
name: translate
description: Translate Social Diary into a language, or bring a translation up to date after the English changed (Locales/<id>/). Covers the voice decisions per language, the locale's grammar file, working through the keys in batches with their code context, the checks, and what is left for the game client and a native reader. Use for "translate into <language>", "update the German", "what is missing in <locale>".
argument-hint: "[locale id, e.g. deDE] [area path, e.g. Features/Hunts]"
---

# Translate Social Diary

How the framework works: `Locales/Locale.lua` (read it whole, it is short).
How strings are written in the code: `/copywriter` §7. This skill is the
translator's workflow. A translation touches only:

- `Locales/<id>/*.lua` (its words, a file per area, and `Grammar.lua`);
- `social_diary.toc` (its files, after `Locales/enUS.lua`);
- `.claude/skills/translate/voices/<id>.md` (its voice, decided once).

**Never** change the English, a key, or the code to make a sentence
translate. The English is the golden copy. Where a sentence cannot be said
in the language as its template stands (a fragment, a word order the
template fixes, a count with no plural key, a place glued to a preposition),
that is a fault in the framework: stop on that key, leave it untranslated,
and report it (§6). Do not work round it.

## 1. The voice, before any word

`voices/<id>.md` holds what a translator may not decide key by key. If it
does not exist, write it first and have the user settle it:

- **Address**: how the diary speaks to the player (German *du*, French
  *tu*, Spanish *tú*, Russian *ты*), and how it names other players.
- **Tense**: prose (Your Diary, the profile, the tour) and ledger lines
  (tooltips, timeline rows) may differ.
- **Typography**: quotes, apostrophe, ellipsis, date and time forms,
  numbers in words up to which number. **No middle dots**, ever
  (`tests/copy_rules.lua` scans `Locales/` too).
- **Game terms** as that language's client says them (level, group, raid,
  quest, duel, guild, rare, pet), and **the diary's own words** (add to the
  diary, pencilled in, rubbed out, the road). One word each, kept.
- **Length**: which surfaces are tight (toast cards, the key-binding
  column, tickets, Settings labels) and the shorter phrasing to prefer.

The English voice is `/copywriter` §1 to §6: quiet, personal, a diary that
never shouts. A translation is that diary in its language, said the way a
diary there would say it, not word for word.

## 2. A new locale's files

- `Locales/<id>/Grammar.lua`, first in the TOC of the locale's files. It
  begins `if not ns.Locale.Is("<id>") then return end`, then replaces what
  the language needs in `ns.Locale.grammar`:
  - `PluralForm(n)` and `PLURAL_FORMS` (CLDR, integers; the rule's row
    goes into `RULES` in `tests/locale.lua`);
  - `Upper`, `Capital` (letters outside ASCII);
  - `Ordinal(n, context)` ("25."): `context` is the noun counted where the
    caller has one ("match", "death"), for its gender;
  - `Day(n, ordinal)`: a date's day (French "1er", then the figure; the
    figure always where a date takes no ordinal), `Clock(hour, minute)`
    ("18 h 30"), `DECIMAL` (","), `ListEnd(head, last, oxford)` where the
    "and" turns on the next word (Spanish "e Inés");
  - `Agree(text)`: a last pass over every filled template, for a number
    word that arrives as a value and must agree with a noun in the words
    ("%s<f> morts" -> "deux mortes"): the locale picks its own mark and
    resolves it here;
  - `EACH_PLACE = true` where every name of a list takes its own
    preposition, `NO_ARTICLE = true` where a creature is named without one;
  - `YOU_FOR`: every word the translation braces for the reader, lower
    case, with its form for another character's name (`"%s hat"`, or a
    function for a genitive);
  - `PLACE[role]` (the plain preposition per role) and, only where a name
    needs an article or a case, `ZONES[mapID][role]`,
    `DUNGEONS[instanceID][role]`, `SUBZONES[name][role]`. Each may be a
    function of the bare name where the preposition contracts or elides
    ("del Cruce", "près d’Orgrimmar").
- **A person's gender comes from the game** (each character's sex is on
  its record; the reader's is the character playing). Where a verb or a
  participle agrees with someone, write the forms in the words and the
  lookup picks one:
  `["%1$s killed {you}"] = "%1$s <1:убил/убила/убивает> {тебя}"`,
  `["{You} died"] = "{ты} <you:погиб/погибла>"`.
  `<N:he/she>` goes by the character named in the key's Nth value,
  `<you:he/she>` by the reader. A third form is for a sex that is not
  known (an old row, a name the player typed): give one wherever the
  language has a neutral way to say it; with two, the first is used. The
  forms are split by `/` and hold no `%` and no `|`. Never rebuild a
  sentence round a colon to dodge a gender: use the forms. English has
  none of this, and no key changes for it.
- One file per area, each `ns.Locale.Add("<id>", { ... })`, with a comment
  line naming the source file above its keys, in the order of
  `Locales/enUS.lua`. Every file whose table is built at load starts with
  the same `Is` guard, so other clients do not build it.
- **Place names come from the game, never from memory.** Do not fill
  `ZONES`, `DUNGEONS` or `SUBZONES` with names you believe are right: leave
  the tables empty (the plain preposition is used) and list them in the
  report for someone with that client. The same for item, creature and
  quest names in sample content.

## 3. The keys, a batch at a time

Work by area, one subagent per area on a large run (give it this skill,
the voice file, `/copywriter`, and its path), never two on one file.

```sh
luajit Dev/Locale/extract.lua --context <id> <path>   # keys still to write, with their code
luajit Dev/Locale/extract.lua --missing <id>          # the bare list
```

For each key, read its context before writing: what each value will be (a
name, a time already written out, a zone's phrase, a list), where the line
shows (a tooltip's title, a card, a sentence in prose), and what stands
before or after it. Then, by kind of key:

- **Plain**: the sentence whole, the same placeholders. Reorder with
  positional ones (`%2$s ... %1$s`); in one value all positional or none.
- **`##context`**: the part after `##` is not text. It says which meaning
  ("May##short", "first##death": an ordinal takes its noun's gender).
- **`##plural`**: one form per category of the language's rule, in CLDR
  order, split by `|`. Every form shows the count unless the first form is
  for the number 1 alone. No colour codes inside.
- **`##zone`**: the place arrives as a whole phrase with its preposition
  ("im Brachland"). Never write a preposition before it.
- **`{you}`**: the reader, or another of their characters in a shared
  diary. Brace the pronoun with what changes with it ("{Du hast}"), and
  put every braced word into `YOU_FOR`.
- **Markup** (`|cff...|r`, `\n`, `|n`): keep each one; it may move with
  its word.
- **"twice"**: a language with no such word writes `""`, and 2 takes the
  plural.
- **Game-supplied names** (zones, creatures, items, classes) arrive in
  the client's language and take no article or case you can know: write
  the sentence so a bare name reads (as the subject, after a colon).

Updating a translation after the English changed is the same loop: the
missing keys are the new and reworded ones; `tests/locale.lua` names the
keys the code no longer uses, to delete.

## 4. Checks

```sh
luajit tests/run.lua locale copy_rules     # the translation's own checks
luajit tests/run.lua                       # everything
luajit tests/run.lua --locale <id>         # the whole suite on that client: NO ADDON ERRORS
```

The locale test fails on: unknown keys, other placeholders than the key's,
a wrong number of plural forms, lost or changed markup, the reader's braces
dropped or a braced word missing from `YOU_FOR`. Missing keys are a note,
not a failure: they read in English.

## 5. What the checks cannot see

- **Length.** Nothing measures text against its frame offline. List every
  string on a tight surface that runs more than about a quarter longer
  than its English.
- **Sense.** A value that passes every check can still say the wrong
  thing. Reread each batch against its context once it is whole.
- **The game.** One round on a client in that language: the tour, a
  profile, Your Diary's plates and tooltips, the toast, Settings, a
  shared diary seen from a second character.

## 6. The report

End a run with: coverage (translated of total), the keys left on purpose
and why (framework faults, by key and file), the names not verified
against the client, the strings likely too long, and anything the voice
file did not settle. When the user settles one, write it into the voice
file.
