# esES: code changes the translation needs (for a separate branch)

Found while translating esES (10 Nov 2026); the second pass over the words
(10 Nov 2026, after the hooks in `../code-changes.md` "Status" landed)
wrote the Spanish back where a hook allows it. Done items are kept short,
with what the words now do.

## Done

1. **Contractions with the zone's article.** `PLACE` roles are functions in
   `Locales/esES/Grammar.lua`: "del Cruce", "al Cruce". The articles of the
   names themselves still need A2 (below).
2. **Ordinals take their noun.** "13.ª partida", "13.ª muerte" (`G.Ordinal`).
3. **No ordinals in dates.** `G.Day` is the figure: "25 oct".
4. **Whose(...) without `you`**: `{you}##subject` is "{tú}". `{you}##from` is
   now "{tú}" with "%1$s, y no %2$s" ("Brom se lo llevó, y no tú").
5. **Decimals**: "3,2" (`G.DECIMAL`).
6. **"a la 1"**: `G.Clock` writes "1:05" (hour unpadded) and `G.Agree` turns
   "las 1:05" into "la 1:05", so every "a las %s" template reads right
   ("hoy a la 1:05"); the spans say the hour bare ("Hoy de 1:05 a 2:00").
   Enough as it is; a `Clock` that also gave the article would only be
   needed if a template had to say "de la 1" with "de las" in its words.
7. **Short and long date** have their own keys: "6 oct 2026", "6 de octubre
   de 2026".
8. **"y" / "e"** before i-/hi- (`G.ListEnd`), in `Format.List` only.
9. **Padding** counts characters (`Format.Pad`).
10. **Several helpers, plural verb**: `##many` deeds ("Numa y otro te
    salvaron"); `##line` deeds start a tooltip line ("Te salvó de Hogger").
11. Slash tokens and "Total RP 3" stay English by design.
12. **Gender forms.** Used where a key names the reader with no braces
    ("To the new owner": `<you:Al nuevo titular/A la nueva titular>`). The
    first translation had already avoided participles with verbs, so few
    lines needed one. Where a key names no one, the line is impersonal
    ("Se añadió al diario", "Se añadió el 6 de octubre…", "A lápiz hasta
    el…").
13. **Number words**: `G.Agree` writes "una" for "un<f>" (the match
    overview: "Una partida, una ganada", "victorias: una"); "cayó uno|cayeron
    %s" says the 1 in its own form.

## Still open

- **A2: place names from the client.** `ZONES`, `DUNGEONS`, `SUBZONES` are
  empty: "en Bosque de Elwynn" until an esES export fills the articles.
- **A person with no name in the key** cannot agree: "Added" (Nearby row
  link, "Añadido"), "Added %s" (profile strip, "Añadido: %s"), toast headings
  "A foe joined your group" and kin ("Un adversario…"). Masculine for now;
  the code would have to pass the person's name as a value.
- **`Items(1, item)`** writes `L["one"]` before an item's name ("un
  [Piedra…]"): the item's gender is the client's and cannot be known; a
  figure ("1 [item]") would avoid it, but the word is shared with every
  other count.
- **A weekday that starts a heading** stays lower case ("martes, 6 de
  octubre" in the timeline's day headings, the Nearby right page's "martes"):
  the weekday is a value, and the code does not capitalise those headings
  (`Format.DayLabel`, `Nearby.lua` `DayTitle`), unless their font does.
  Needs a `Capital` at those call sites; check in the client.
- **Own character as the snagger** (`Words.Snagged`, a shared diary seen
  from another character): "Tú se lo llevó" (the verb is the third
  person's); the code has no reader's sentence for it, as `Rolled` has.
- **Shared "another|%s others"** (close calls and witnesses): "otro", so a
  witness line reads "Numa y otro te salvaron" rather than "otra persona".
