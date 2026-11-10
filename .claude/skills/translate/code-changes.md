# Code changes the translations need

One list from the three first translations (esES, frFR, ruRU, 10 Nov 2026).
Each language's own list stays beside its voice file and holds the detail and
the sentences that were rebuilt: `voices/esES-code-changes.md`,
`voices/frFR-code-changes.md`, `voices/ruRU-code-changes.md`. The numbers in
brackets point into them (ru numbers are from its "Consolidated" part).

These are framework changes: they go on `translations`, never on a locale
branch, and never change the English. When one lands, the locale's words that
were rebuilt round it get a second pass (the per-language lists name them).

## A. Needed by all three

| # | Change | Where | es | fr | ru |
|---|---|---|---|---|---|
| A1 | **A place phrase may be a function.** `grammar.PLACE[role]` (and an entry of `ZONES`/`DUNGEONS`/`SUBZONES`) may be a function of the bare name, so a locale can contract ("del Cruce"), elide ("près d’Orgrimmar") or decline. A list of places gets one phrase per name, not one phrase round the list. | `Locales/Locale.lua` `Phrase`; callers that pass a joined list (`Flew %s`, `Places()`) | 1 | 1 | 1, 9 |
| A2 | **Place names from the client.** `ZONES`, `DUNGEONS`, `SUBZONES` are empty in all three; articles, gender and case per name cannot be guessed. Needs an export from each client, then a filled table. Until then A1 only helps with elision. | `Locales/<id>/Grammar.lua`, a dev export | 1 | 1 | 1 |
| A3 | **Ordinals take their noun.** `Format.Ordinal(n, context)` and `grammar.Ordinal(n, context)`: past the twelfth a death or a match falls back to a masculine "13.º" / "13e" / "13-й". The word lists already carry the context (`##match`, `##death`). | `UI/Words/Format.lua` `Ordinal`, `Nth` | 2 | 4 | 4 |
| A4 | **The day of a date is not an ordinal.** The sitting label builds from `Format.Ordinal(day)`: "25.º oct", "25e oct.", "25-й окт.". Add `grammar.Day(n)` (English keeps "25th"; French returns "1er" for the first and the figure otherwise) and use it in the sitting label, `DayMonth` and `DayLabel`. | `UI/Journey/Text/Time.lua:99`, `UI/Words/Format.lua` | 3 | 5 | 5 |
| A5 | **Decimals.** `%.1f seconds` prints "3.2"; all three write "3,2". A `Format.Decimal(n, places)` with a `grammar.DECIMAL` mark. | Witnesses tip, any `%.1f` | 5 | 7 | 8 |
| A6 | **Number words take a gender.** `NUMBER`/`WORDS`/`Said` give one word per number; "un/une", "один/одна/одно" depend on the noun. Pass the noun's context (`Said(n, "f")`), as `Format.Nth` does. Russian also needs a case here, which a word list cannot give: those lines stay rebuilt. | `UI/Journey/Text/Grammar.lua:93`, `UI/Journey/Text/Match.lua` `SAID`, `Features/*/Text.lua` | | 3 | 3 |
| A7 | **Padding counts bytes.** `%-3s`, `%-22s` in the `/sd` chat lists misalign with accents and Cyrillic. A pad that counts UTF-8 characters. | `Core/Slash.lua` | 9 | 18 | 7 |
| A8 | **Several helpers, one singular verb.** "Numa and another tried to save you": the verb is in the deed text and stays singular. A plural-aware deed key. | `Features/Witnesses/Text.lua` `Caption`, `Others` | 10 | 9 | area B5 |
| A9 | **`Whose(...)` without `you`** falls back to the English literal "{you}", so an own-page line can show "You" in a translated diary. | `UI/Dungeon/Words.lua:75` (`Snagged`, `Death`, `Rolled`) | 4 | | 12 |

## B. Needed by two, or by one with a clear fix

| # | Change | Where | es | fr | ru |
|---|---|---|---|---|---|
| B1 | **Short and long date share `%1$d %2$s`.** Split into two keys with contexts. | `UI/Words/Format.lua` | 7 | 5 | |
| B2 | **The list joiner is a template.** "y" becomes "e" before i/hi; a list of quoted places. A `grammar.List(items)` hook. | `Format.List`, `Credits.lua:47` | 8 | 16 | 9 |
| B3 | **The clock is `date("%H:%M")`.** French writes "18 h 30", Spanish "a la 1" for 1:xx. A `grammar.Clock(h, m)` hook; `Format.At` then builds from it. | `UI/Words/Format.lua:140`, `Timeline.lua:815,838`, `Nearby.lua:199`, `Slash.lua:262,272` | 6 | 6 | |
| B4 | **Shared keys used for two things.** `"%1$s's %2$s"`, `"%1$s %2$s"`, `"ran %s"`, `"raided %s"`, `"Reached by %s"`, `{you}##from`: one use takes a count, the other a name, or two prepositions. Split by context. | `UI/Words/Timeline.lua`, `UI/Dungeon/Words.lua` | | 8, 13 | 10 |
| B5 | **`recent %s` shows an internal row kind** in English. Give the kinds a label. | `Core/Candidates.lua:132` | | 17 | 11 |
| B6 | **The weekday and date key carries a comma** (`%1$s, %2$s`); French has none, Russian wants one where English has none. Already a template, so this is a words fix once the two keys are told apart by context. | `UI/Words/Format.lua:136` | | 5 | area JD15 |
| B7 | **`when:find("ago$")`** tests an English word. | `UI/Windows/Reunion/Words.lua` `When` | | 15 | |
| B8 | **`Capital(Did(w))`** capitalises a deed into a line with no subject. A line-start form of the deed. | `Features/Witnesses/Text.lua` `Tip`, `Tips` | | 10 | |
| B9 | **The "Article" option does nothing** where `KillerName` returns the bare name. Hide it for such a locale. | Witnesses settings | | 11 | area B8 |
| B10 | **Units beside a number box** ("lines", "min", "days") cannot take a plural form. Word them as a label before the box in the English, or accept the abbreviation. | Settings sections | | | 6 |

## C. In the checks, not the addon

| # | Change | Where |
|---|---|---|
| C1 | **The markup scan reads a plural separator plus a letter as markup** (`form|nous`, `…|r…`), so a plural form cannot start with r, c, n, T, H, A. Scan each plural form on its own. | `tests/locale.lua` `Markup` (fr 14) |
| C2 | **A French first form must show the count** (0 and 1 share it), so "once" cannot be "une fois" and `once|%s times##plural` (`Match.lua:31`) is untranslated in frFR. Let a locale say its first form covers more than one number and split `once` out in code (`n == 1` its own key), which is what the English means. | `tests/locale.lua` `Within`, `Format.Times`, `Match.lua:31` (fr 2) |

## D. Larger, a decision first

| # | Question | es | fr | ru |
|---|---|---|---|---|
| D1 | **Gender of the reader and of a stranger.** Spanish and French participles and all of the Russian past tense agree with a person's sex. The character's `sex` is stored. A gender-aware `{you}` and a way to pick between two words for a stranger would let Russian leave the noun labels and the historic present. Largest single gain for ruRU, and the largest change. | 12 | 19 | 2 |
| D2 | **Case for names (Russian).** Character, creature, item and boss names arrive in the nominative and cannot be declined; the lines are rebuilt round a colon. No framework change fixes this short of name tables per case (A2 covers places only). Accept the rebuilt lines. | | | 1, 14 |
| D3 | **Plural of a creature or item name after a count** ("31 Plainstrider"). `G.Plural` and `ItemWord` return the name as it comes. Accept. | | 11 | 6 |

## E. No change

Slash tokens (`recent`, `city add`) and "Total RP 3" stay English by design.
Sample names in the intro and the empty diary stay English until someone
with that client fills them. Lengths (Russian runs 20 to 35 % longer) need a
look in the client: see the reports.

## Status (10 Nov 2026)

Done on `translations`, with each locale's grammar using it on `locale/all`:

| # | How |
|---|---|
| A1 | `PLACE[role]` and a `ZONES`/`DUNGEONS`/`SUBZONES` entry may be a function of the name. Lists go through `ns.ZonesIn(names, role, List)`; `grammar.EACH_PLACE` gives every name its own preposition. es contracts "del/al", fr elides "d’", fr and ru set `EACH_PLACE`. |
| A3 | `Format.Ordinal(n, context)`, `grammar.Ordinal(n, context)`; a word list carries `context` ("match", "death"). |
| A4, B1, B6 | `Format.Day(n, ordinal)` / `grammar.Day`. The date keys are split: `##short date`, `##date`, `##weekday date`, `##date and year`. |
| A5 | `Format.Decimal(n, places)`, `grammar.DECIMAL`. The key is `"%s seconds"`. |
| A6 | `grammar.Agree(text)`, a last pass over every filled template. fr resolves `<f>` ("un" to "une"), ru `<f>` and `<n>` ("один", "два"). No word uses a mark yet. |
| A7 | `Format.Pad(text, width)` in the `/sd` lists. |
| A8, B8 | `Witnesses.Deed(w, form)`: `##many` after several names, `##line` at a line's start. `##many` is written in all three; `##line` is the singular carried over. |
| A9 | `L["{you}##subject"]`. |
| B2 | `grammar.ListEnd(head, last, oxford)`; es writes "e" before i/hi. Only `Format.List` asks it. |
| B3 | `Format.Clock(time)` / `grammar.Clock(h, m)` in sentences; fr writes "18 h 05". The timeline's time column and the `/sd` lists keep "18:05". |
| B4 | `"%1$s %2$s"` has a context per use; `"ran %s##count"`; `"{you}##by"` for "Reached by". `"%1$s's %2$s"` has one use and stays. |
| B5 | A key per row kind, `L["recent whisper_in"]`. The English still shows the code's word: a copy decision. |
| B7 | `Format.Ago` returns whether its answer is a date. |
| B9 | `grammar.NO_ARTICLE` leaves the Article box off the witness form. |
| C1 | A plural value's bars are not read as markup. |
| C2 | French has three forms: 1, then 0, then the rest ("une fois|%d fois|%d fois"). No code change. |

Open:

- **A2**, place names from each client.
- **B10**, units beside a number box: no change; the abbreviation stays.
- **The second pass over the words.** The hooks are there, the sentences
  rebuilt round their absence are not yet written back: gender marks on
  number words (A6), French first forms that may now drop the count (C2),
  the `##line` deeds (B8), Spanish "a la 1" (the clock hook gives the hour,
  the template still says "a las").
- **D2, D3**, as above.

**D1 is decided and built** (Jan, 10 Nov: the game's own sex of a
character, no field for the player to set). A locale's words hold the
forms, `<1:he/she/neither>` by a value's character and `<you:he/she>` by
the reader (`Locales/Locale.lua`, "A person's gender"). No word uses them
yet: writing the past tense back into the Russian, and the participles into
the French and Spanish, is part of the second pass.
