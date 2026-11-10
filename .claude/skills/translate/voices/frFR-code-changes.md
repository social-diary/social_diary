# frFR: code changes the translation needs (for a separate branch)

Found while translating frFR (10 Nov 2026). The framework items of the
first pass were built on `translations` (see `../code-changes.md`,
"Status"), and the second pass over the words (10 Nov 2026) wrote the
French back where a hook now allows it. What is left open is listed first;
what was resolved is kept below, short, so a reader can see why a sentence
reads as it does. Items that esES also found are marked (= esES n).

## Still open

1. **Zone and dungeon names** (= esES 1). `PLACE` elides ("près d’Orgrimmar")
   and every name of a list takes its own preposition, but "en Durotar",
   "dans les Tarides", "au Mulgore", "à Hurlevent" need the client's names:
   `ZONES`, `DUNGEONS`, `SUBZONES` stay empty until someone exports them from
   the frFR client. `PLACE.into` "à %s" still reads oddly in "The way %s" and
   "first arrival %s" captions (Caption.lua:146,153).
5. **"Pencilled in until %s"** (Person.lua:415) takes the short day, which
   may be "aujourd’hui": "Au crayon jusqu’au %s" breaks then ("jusqu’au
   aujourd’hui"). The template cannot choose "au"/"à". "Added %s" and "First
   met %s" stay "Ajout : %s", "Première rencontre : %s" for the same reason.
   The `/sd` chat dates keep the code's zero padding ("06 oct.",
   Slash.lua:156: `date("%d")`).
8. **Genitive in a template**: `"%1$s's %2$s"` (a creature's spell,
   Timeline.lua:122) is still "%1$s : %2$s" (no elision in a template).
   `{your} %s match together`: another character's form is "la %s partie"
   (`YOU_FOR["ta"] = "la"`), the owner unnamed; a function in `YOU_FOR`
   cannot see the noun.
11. **Creature and item plurals** (D3, accepted): `G.Plural` returns the
    name, so "31 Plainstrider"; `ItemWord` leaves "7 objet" for the fallback.
12. **Duel series** (Duels/Kind.lua:114-131): the second count cannot agree
    with "perdu/perdus"; still a label list ("victoires 3, défaites 1").
22. **Two people's gender at once**: "{You} and %1$s died %2$s between you"
    would agree with both ("Toi et Numa êtes mortes"); a form picks by one
    person, so it stays "{Toi et} %1$s {avez} péri".
20. **The reader's sex at load.** Words that agree with the reader without
    braces (`"killed you"`, `"Died here"`, the witness deeds) are resolved
    once, as the locale loads, from `UnitSex("player")`. Check in the client
    that it is known that early; if not, a woman reads "t’a tué".
21. **`{you}##subject`** ("{toi}") is the fallback for a dungeon line about
    the page's own character that has no sentence of its own ("%s snagged
    it": "Toi l’a pris"). No line reaches it today; if one does, it needs
    its own template, as `"{You} rolled a %d"` has.

## Resolved (second pass, 10 Nov 2026)

2. **Three plural forms** (1, then 0, then the rest). Form 1 leaves the count
   out wherever the English's first form does: "une fois", "un combat",
   "une note", "une mort", "une chasse chanceuse", "une chaîne terminée",
   "un autre", "une semaine", "une personne y est déjà". `once|%s
   times##plural` (Match.lua) is written.
3. **Number words with a feminine noun.** Form 1 holds the article itself
   now, which covers every count of one; `%s<f>` is used where a number word
   arrives in a sentence that is not a count of its own noun (the match
   page's "une partie, une gagnée"). The natural nouns are back: "mort" for
   "décès", "note" for "mot", "partie" for "match" (the battleground's
   word, as Settings and the hints already said; `FEMININE.match` in
   Grammar.lua and `first##match` "première" changed with it).
4. **Ordinals take their noun**: "1re mort", "1re partie".
5. (part) **Dates**: "1er octobre" (`G.Day`), "lundi 6 octobre" with no
   comma, "25 oct." on the sitting label, "Écrit le 6 octobre" (the note's
   date is always a date).
6. **Clock**: "18 h 05" in sentences (`G.Clock`).
7. **Decimals**: "2,5 secondes".
9. **Several witnesses** take the plural deed (`##many`): "Numa et un autre
   t’ont sauvée".
10. **A deed starting a tooltip line** (`##line`): the tooltip's other lines
    already drop their subject ("A rejoint ton combat", "Ne se battait
    pas"), so the line form is the singular deed ("T’a sauvée face à
    Hogger"), with its gender.
13. `{you}##from` / `{you}##by` are their own keys.
14. The markup scan reads each plural form on its own: "rencontre il y a
    moins de %s jours" is back.
15. `Format.Ago` says whether it gave a date ("le 12 sept.").
16. The list joiner is `grammar.ListEnd` (French needs none).
17. The picker's recent reasons have their own words ("t’a chuchoté
    récemment", "a rejoint ton groupe récemment").
18. `/sd` lists pad by characters.
19. **Gender** (D1): participles agree with the reader (`<you:tué/tuée>`;
    braced, `<you:{t’a sauvé}/{t’a sauvée}>`) and with a named character
    (`<1:est mort/est morte/a péri>`, the third for a sex not known and for
    "Cette personne"). Deaths say "tu es morte", "Zuri a été tuée par
    Hogger" instead of "tu as péri"/"tu as succombé".

## Names not verified against the client (never filled from memory)
- `ZONES`, `DUNGEONS`, `SUBZONES`: all empty.
- Sample names left English: "The Barrens", "Stonetalon Mountains" (Empty.lua:229),
  "Wolfskin Bracers" (Tour.lua:172). Intro keeps "Tinker Town", "Ratchet"
  in English; battleground short names "Chanteguerres", "Arathi", "Alterac"
  are from memory.
- Profession ranks "apprenti / compagnon / expert / artisan", "coup fatal",
  quest verbs "accepter / rendre", "/dire", "Réglages" vs "Options",
  "partie" for a battleground match.
