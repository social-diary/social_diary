# frFR: code changes the translation needs (for a separate branch)

Found while translating frFR (10 Nov 2026). Nothing here was worked round in
`Locales/frFR/` except where marked "worked round"; each key was translated
as well as its template allows. Items that esES also found are marked (= esES n).
See `esES-code-changes.md`; most of these hooks help both languages.

## Framework faults

1. **Zone and dungeon phrases need article, contraction and elision** (= esES 1).
   `PLACE` is a plain template, so French cannot say "en Durotar", "dans les
   Tarides", "au Mulgore", "à Hurlevent", and "près d’Orgrimmar" / "autour
   d’Orgrimmar" elide before a vowel. Plain `PLACE` is "à %s" / "près de %s" /
   "autour de %s": wrong for most names. Let `grammar.PLACE[role]` be a function
   of the bare name, and fill `ZONES`, `DUNGEONS`, `SUBZONES` from the frFR
   client (not done: names come from the game). Also `PLACE.into` "à %s" is
   wrong for "The way %s" and "first arrival %s" captions (Caption.lua:146,153).
2. **Plural rule: 0 and 1 share form 1, so a first form must show the count**
   (tests/locale.lua). `once|%d times##plural` (UI/Words/Format.lua:192, used
   by `Format.Times`) is "1 fois" where French says "une fois". Either let
   the check accept a first form without the count when the locale says so,
   or give `Times` a French path for 1. Same for `once|%s times##plural`
   (UI/Journey/Text/Match.lua:31): **left untranslated** (a `%.0s` workaround
   was written by a translator and removed). Also "a note|%d notes"-style keys
   had to be reworded to show the count.
3. **Number words are masculine** (`NUMBER[1]` = "un", `Said(1)`,
   UI/Journey/Text/Grammar.lua:93): "un chasse", "un fois" break with feminine
   nouns, so masculine nouns were chosen on purpose (match, décès, mot,
   moment critique, duel). Needs a gender-aware count (`one##f`), as for
   ordinals. Rows affected: Hunts, CloseCalls, Deaths, QuestFinales span,
   Journey "we fell", match page.
4. **Ordinals have no gender** (= esES 2). `Format.Ordinal(n)`/`grammar.Ordinal`:
   "1er" is always masculine; "1re", "première" (death ordinals, "11e partie")
   cannot agree. Pass the noun's context.
5. **Dates**. `Format.DayMonth` / `DayLabel` write "6 October" shaped dates:
   French needs **"1er"** for the first of the month ("1er octobre"; today
   it shows "1 octobre"), and "le" before a bare date ("Écrit le 6 octobre",
   NoteSheet.lua:237; "Ajouté le …"). Add `grammar.Day(n)`. Also the sitting
   label (`##month day`, Time.lua:99) builds from `Ordinal`: reads "25e oct.",
   French writes "25 oct." (= esES 3). The weekday and date key `%1$s, %2$s`
   (Format.lua:136) takes a comma, French has none ("lundi 6 octobre").
   Chat dates (Slash.lua:156) are zero padded "06 oct 2026". "Pencilled in
   until %s" breaks if `Day()` returns "aujourd’hui" ("jusqu’au aujourd’hui").
   The short date `%1$d %2$s` is shared with the long one.
6. **Clock**. The code writes `date("%H:%M")` ("18:30", Format.lua:140,
   Timeline.lua:815,838, Nearby.lua:199, Slash.lua:262,272); French writes
   "18 h 30". Add `grammar.Clock(h, m)`.
7. **Decimals** (= esES 5). `%.1f seconds` gives "2.5", French "2,5".
8. **Genitive and possessive in a template**: `"%s's %2$s"` (a creature's
   spell, Timeline.lua:122) cannot become "%2$s de %1$s" with elision, so it
   is written "%1$s : %2$s". `G.Genitive` exists but a template cannot call it.
   `{your} %s match together`: the other-character form is "le …" and the
   owner is lost (a function in `YOU_FOR` cannot see the noun).
9. **Compound subject, singular verb** (= esES 10). Witnesses.Caption: "Numa
   et un autre" takes "ont essayé" but the deed text is singular. Needs a
   plural-aware deed.
10. **`Capital(Did(w))`** (Witnesses.Text Tip/Tips): the deed "t’a sauvé face à
    Hogger" is capitalised into a line with no subject. Needs a line-start form.
11. **Creature and item plurals and articles**. `G.Plural` returns the name,
    so "31 Plainstrider"; `ItemWord` leaves "7 drop" (fallback word).
    `KillerName` has no article, so the Witnesses option "Article / Disable
    (“A Hogger”)" does nothing in French (hide it for frFR).
12. **Duel series** (Duels/Kind.lua:114-131): the second count cannot agree
    with "perdu/perdus"; rewritten as a label list ("victoires 3, défaites 1").
13. **A braced word serving two prepositions**: `{you}##from` for "Atteint par
    toi" and "l’a pris à toi": the preposition sits outside the brace.
14. **Markup scan reads a plural separator plus a letter** (`|r`, `|c`, `|n`,
    `|T`, `|H`, `|A`) as client markup (tests/locale.lua `Markup`): a plural
    form cannot start with "r", "c", "n" ("nous", "contact"). Two keys were
    reworded; the check should look for the real escape only after a start or
    whitespace.
15. **Same-day English tests**: Reunion/Words.lua `When()` tests the word "ago"
    (`when:find("ago$")`), English-bound; it works in French only by its digit test.
16. **List joiner and `Format.List`** (Credits.lua:47): "et" vs commas must come
    from a hook; check in the client.
17. **Command tokens stay English** (`recent`, `of`, `city add/remove`,
    Slash.lua:347-351) and `recent %s` (Candidates.lua:132) shows the raw English
    row kind: no fault, noted for readers.
18. **`%-3s` padding counts bytes** (= esES 9) where accents appear.
19. **Gendered participles for a person** (= esES 12): French agrees with the
    sex, avoided throughout with avoir-verbs and nouns (“t’a tué” is written
    without “tuée” for a woman reader). The character's `sex` is stored; a
    gender-aware `YOU_FOR` and `Format.You` could agree.

## Names not verified against the client (never filled from memory)
- `ZONES`, `DUNGEONS`, `SUBZONES`: all empty.
- Sample names left English: "The Barrens", "Stonetalon Mountains" (Empty.lua:229),
  "Wolfskin Bracers" (Tour.lua:172). Intro keeps "Tinker Town", "Ratchet"
  in English; battleground short names "Chanteguerres", "Arathi", "Alterac"
  are from memory.
- Profession ranks "apprenti / compagnon / expert / artisan", "coup fatal",
  quest verbs "accepter / rendre", "/dire", "Réglages" vs "Options".
