# esES: code changes the translation needs (for a separate branch)

Found while translating esES (10 Nov 2026). Nothing here was worked round in
`Locales/esES/`; each key was translated as well as its template allows.

1. **Contractions with the zone's article.** `PLACE` is a plain template, so
   "de" + "El Cruce" cannot become "del Cruce", nor "a" + "El …" "al …".
   Let `grammar.PLACE[role]` be a function of the bare name (Locale.lua `Phrase`).
   Also needs `ZONES`/`DUNGEONS`/`SUBZONES` filled from the esES client (articles:
   "en el Bosque de Elwynn"); not done, names come from the game.
2. **Ordinals have no gender.** `Format.Ordinal(n)` and `grammar.Ordinal(n)` take
   only n, so past the 12th "tu 13.º partida" (match, feminine) and "la 11.ª
   muerte" cannot agree. Pass the noun's context (as `Format.Nth` word lists do).
3. **No ordinals in dates.** The sitting label (`##month day`, Text.SittingLabel)
   is built from `grammar.Ordinal`, so it reads "25.º oct"; Spanish writes "25 oct".
4. **Whose(...) without `you`** (UI/Dungeon/Words.lua, `Snagged`, `Death`):
   defaults to the English literal "{you}", so an own-page line may show "You".
5. **Decimals.** "%.1f seconds" gives "3.2"; Spanish writes "3,2".
6. **Hours "a las 01:05" / "a la 1".** `on %1$s at %2$s` is fixed; Spanish says
   "a la 1" for 1:xx. Translations avoided it where they could; Format.At is not
   locale-aware.
7. **Short date "6 de oct de 2026"**: the template `%1$d %2$s` is shared by the
   short date and the long one; Spanish needs "de" in one and not the other.
8. **List joiner "y" vs "e"** before a name starting with i/hi: not knowable
   from a template; needs a grammar hook on `List`.
9. **`%-3s` padding counts bytes** (city list "sí"/"no"): accents misalign the column.
10. **Compound subject with a singular verb** (Witnesses.Others: "Numa y otra
    persona te salvó"): needs a plural-aware key.
11. **"Total RP 3", slash tokens (`recent`, `city add`) stay English** by design;
    no fault, noted for readers.
12. **Gendered participles for "a person"** ("Añadido", "Vistos esta semana",
    "tuyo"): Spanish has no neutral; contributors may prefer a gender-aware
    record (the character's `sex` is stored).
