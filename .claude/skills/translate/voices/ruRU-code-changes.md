# ruRU: code changes the translation needs (for a separate branch)

Found while translating ruRU (10 Nov 2026). Nothing here was worked round in
`Locales/ruRU/`: each key was translated as well as its template allows, and
where a template could not carry Russian the sentence was rebuilt around a
colon or a noun label (the cost is named per item). The first part is the
consolidated list, ordered by how much it hurts; the second part is each
area's own numbered list, as the translators wrote it.

## Consolidated

1. **Case: names cannot decline.** Zone, dungeon, creature, item, boss and
   character names arrive bare (nominative) and Russian needs a case after
   nearly every preposition ("в Дуротаре", "от Брама", "с Брамом"). Today
   `grammar.PLACE` puts the name in quotes after the preposition
   ("в «Дуротар»") and killers/opponents/boss names are rebuilt after a
   colon ("Противник: %s", "Убийцы: %s", "после босса: %s"). Needs, in the
   framework: `PLACE[role]` and a name-keyed `ZONES/DUNGEONS/SUBZONES` to be
   functions or to take a case (`ns.ZoneIn(mapID, name, role)` already has
   the role; add a case per role), filled from the ruRU client (names are
   not verified, tables are empty). A generic fallback could use the
   client's own declension tables where it ships them (e.g. the dungeon
   name's prepositional form in the Dungeon Journal).
2. **Gender of the reader and of a stranger.** Past tense and short
   participles are gendered; the diary does not know. The translation
   avoids them with noun labels ("Смерть: Брам"), impersonal plurals
   ("тебя убили"), "они", and the historic present ("{ты сбегаешь}"). The
   character's `sex` is stored (class names already use it): a
   gender-aware pass (`{you}` plus a gender key, or `##male/##female`
   contexts, or a `grammar.Gender(guid)` hook that picks between two
   words) would let the diary write proper past tense ("Брам убил тебя").
   Also for the reader: the player's own sex is known.
3. **Number words have one gender.** `NUMBER`/`WORDS`/`Said`
   (`UI/Journey/Text/Grammar.lua`, `UI/Dungeon`, `Features/*/Text.lua`):
   "один/два" are masculine; feminine nouns ("смерть", "заметка",
   "охота", "профессия") need "одна/две", neuter "одно". Translations use
   a colon form ("смерть: два") or masculine nouns, and `a##one` is written
   as "1". Needs a gender per noun counted (`NUMBER[gender]`, or
   `Said(n, gender)`), as `Format.Nth` already does by context. The same
   words are nominative only: "после двух", "двое упали", "в трёх матчах"
   need cases (see 1).
4. **Ordinals have no gender or case.** `grammar.Ordinal(n)` takes only n:
   "25-й" is masculine nominative; "13-я смерть", "в 13-м матче" and the
   death ordinals past the twelfth (`NTH_DEATH`, `NTH_MATCH` fall back to
   `Format.Ordinal`) disagree with their noun. Pass the noun's context.
5. **No ordinals in dates (sitting label).** `##month day`
   (`Text.SittingLabel`) builds from `Format.Ordinal(day)`, so ruRU reads
   "25-й окт."; Russian writes "25 окт.". Use a cardinal day for ruRU.
6. **Plural of an item or creature name after a count** (`ItemWord`,
   `Plural`, `Counts`): "3 Hezrul's Head" needs the genitive plural, which
   cannot be known; the names stay as they come. Units beside number boxes
   in Settings ("строк", "мин", "дн.") cannot take the three plural forms
   (a label next to a spinner); and "Format.Times" ("5 times") sits in
   `UI/Words/Format.lua` with a count the translation handles with its own
   plural key, but compound numbers ("21 раз") through `Said` fall back to
   digits.
7. **Byte padding.** `%-22s`, `%-3s` in `/sd` chat lists (`Core/Slash.lua`,
   city list, "вкл/выкл") pad by bytes, Cyrillic is 2 bytes per letter, so
   columns misalign. Needs a UTF-8-aware pad.
8. **Decimals.** "%.1f seconds" gives "3.2"; Russian writes "3,2".
9. **Lists and joiners.** `Format.List`'s "и" joiner is fine, but lists of
   places put one pair of quotes round the whole list ("в «A, B»") and a
   place list with a first phrase and a bare second name
   ("в «Мулгор» и Дуротар"). Needs a per-name role phrase. `Format.MORE`
   ("and %d more") has to read "и ещё %d" (the toast continues it).
9a. **"%s and a half hours"** takes the form of the whole number; Russian
   takes the genitive singular after "с половиной" for 2 to 4 and 21+; the
   translation sets forms 1 and 2 alike, which only works for those.
10. **Shared compound keys** (`"ran %s"`, `"raided %s"`, `"%1$s %2$s"`,
    `"%1$s's %2$s"`, `"Reached by %s"`) are used both with a count and with
    a bare name; Russian needs a different case in each and got a neutral
    phrase. Candidates for split keys.
11. **`recent %s`** (`Core/Candidates.lua`) shows an internal English row
    type id ("недавно: type").
12. **"Whose(...)" and own-page** defaults ("{you}" literal) as in esES #4.
13. **Hand-quoted button labels** ("Remove from the diary", "Recording"
    section names inside hints) must be kept equal in both files by hand;
    worth a key reference.
14. **`Genitive`** returns the bare name ("История: %s"); a real genitive of
    a character name is not knowable, so the label is "story: Name".
15. **Slash tokens, "Total RP 3"** and similar stay English by design.
16. **Window-width.** Russian runs 20 to 35 % longer; the strings listed in
    "Likely too long" in the report need an in-client look (toast cards,
    key-binding column, duel margin slip box of 107 px, ticket lines).

---

# Per-area lists (as written by the translators)

## Core
1. "%1$-22s lvl %2$-3s ..." and "%1$s%2$s  %3$s%4$s  lvl ..." (Core/Slash.lua): %-N padding counts bytes, Cyrillic is 2 bytes/letter, columns misalign (names, "ур.").
2. "on##switch"/"off##switch" (Slash.lua): "%-3s" byte padding; "вкл"/"выкл" are 6/8 bytes, no padding, column ragged.
3. "%s added to the city list." / "%s removed ...": the map name must not be gendered/declined; written as "в список городов добавлено: %s." (workaround via colon).
4. "Met %1$d time, last ..." / "Seen here %d time" / "%s hour": the "раз" forms use the three-form plural, fine; but Format.Times(count) in "Seen %1$s, last %2$s" (Tooltip) is built elsewhere (Words/Format): "3 times" needs its own Russian plural there.
5. "Remove %s from the diary?" / "Delete everything ... about %s": the name is a character name, undeclined; written with "персонажа %s" apposition (accusative "персонажа" with bare name ok).
6. "%1$s is set to %2$s... for %3$s": the action name %3$s (from Keys.ActionName) must be nominative after a colon; written "другое действие: %3$s?".
7. "Just %s" (HeatSheet): a first name, "Только %s" ok bare.
8. "recent %s" (Candidates): %s is an internal row type id (English), shown as "недавно: type".
9. "(you at %1$.1f, %2$.1f)": written "(ты здесь: ...)".
10. "Written %1$s %2$s##zone": %1 is a day phrase ("yesterday", "6 октября"); used a colon, "Написано: %1$s, %2$s", since the day phrase has no known preposition.

## Windows
1. "on %s" (Reunion/Words.lua When): the date after it is a bare "12 сентября 2025"; Russian needs no preposition, so the value is just "%s". Fine, but the relative forms ("3 дня назад") come from Words.lua and must read after "Последняя схватка" / "последний раз".
2. "Your %1$s match ..." takes Format.NTH_MATCH words (first##match ...) / Ordinal "3-й": the template fixes the noun "матч" (masculine); the `##match` words in Words.lua must therefore be masculine ("первый, второй ...").
3. "Pencilled in" plural: the count is the object ("записал карандашом %d человека"): forms are accusative animate (1/21 "человека", 2-4 "человека", 5+ "человек"). Works because the diary speaks as masculine "дневник" (я записал), gender-safe.
4. "Added %1$s ..." uses "Добавлено" (impersonal) so no gender.
5. Toast headings are fixed noun/prepositional phrases ("В твоей группе") because "Joined your group" has a stranger as singular subject.
6. MORE lines ("из твоего дневника тоже рядом.") follow the plural key "and %d more" from another file; it must read "и ещё %d".
7. "Click him to see his page." / "Open his page": Thex is an explicit male sample, so "его" is fine.
8. Sample names Bram and Thex stay in Latin and cannot decline ("Добавить Thex", "Thex теперь в ...", "Добавь Thex ...").


## Settings
1. "Keep the whole scoreboard for this many matches" (Battlegrounds.lua): number box with no unit; written "Сколько матчей хранить с полной таблицей" so a bare number follows.
2. Units "lines"/"min"/"days" (Recording, Toasts, Memory): a unit beside a number box cannot take the three plural forms; written "строк", "мин", "дн." ("строк" is right only for 0 and 5+).
3. "%1$d in the diary, %2$s ..." (Memory): first count has no plural key; written "Людей в дневнике: %1$d; ..." (number after a colon). "%d sighting" plural uses the noun-adjective "замеченный/замеченных".
4. "One person: Remove on their page..." quotes the button label by hand as «Убрать из дневника»; must match the Remove button's Russian text.
5. "Over %d MB ... (Recording)" names the section by hand as «Запись» (matches JournalDungeon.lua).
6. Ellipsis keys ("Delete all sightings..." etc.): wrote single-char "…" per the voice file (English has three dots).


## Words
1. "%s died" family, `%1$s died ...` (Timeline.lua DIED): a stranger's death needs a gendered past verb. Written as a noun
   label "Смерть: %s, ..." instead. Where the name is the fallback "They" -> "Этот персонаж", it reads "Смерть: Этот персонаж" (capital after colon).
2. Killer in "died to %2$s": needs a genitive/instrumental of a bare game name; written "виновник — %2$s" (nominative after a dash).
3. "%1$s's %2$s" (killer name and spell): possessive needs declension; written "%1$s: %2$s" ("Брам: Огненный шар").
4. "killed %s##timeline" / "Killed %s##timeline": the rare's name is the accusative object, arrives bare; written "убили: %s" (colon, bare list).
5. "ran %s" / "raided %s": the key is used both with a count ("3 подземелья") and with one bare dungeon name; no accusative possible for the name, so "пройдено: %s" / "рейд: %s" (noun/neuter participle, no subject). "raided %s##times" is "рейд: 5 раз".
6. "%1$s and %2$s" for places (Places()): the first has a quoted phrase ("в «A»"), the second is a bare name: "в «Мулгор» и Дуротар"; quotes lost on the second, cannot be declined.
7. "%s and around": the first name already carries the role preposition ("вокруг «A»" for the "around" role), so the key is "%s и другие места" ("вокруг «A» и другие места") to work with every role.
8. "with %s" (who else was in a dungeon): "с + names" needs the instrumental; written "ещё в группе: %s".
9. "Also about %s" / "Also about %s.": names after "о" need the prepositional; written "Также о персонажах: %s" (apposition word).
10. "{You} killed them" etc. in a shared diary: "Убиты {тобой}" and "Они убили {тебя}" put the other character's bare name in the instrumental/accusative slot ("Убиты Брам", "Они убили Брам"). Only affects another character's name; the own diary is right. "{Your} group killed them" -> "Убиты группой, где {ты}".
11. "%1$s %2$s" (shared key, Timeline "Feivel 3 times" and other files): kept as a bare two-word join, "Брам 3 раза".
12. "%1$s reached lv %2$d" family: a past verb with a stranger as subject; rewritten as "Новый уровень: %1$s — %2$d-й, ..." and the tail "%1$s: %2$d-й уровень". Ordinal "%d-й / -го / -м" endings are fixed (masculine "уровень"), fine here (the noun is always "уровень").
13. "{your} %s match together/against them": "{ты}: %s матч вместе"; the ordinal words (first##match...) are masculine ("матч"). `Format.Ordinal` fallback past the twelfth is "13-й" (also masculine, fine for "матч").
14. "%1$d deaths between {you} and %2$s": the count has no plural key; written as "Смертей на двоих: %1$d, ..." so the number needs no agreement.
15. "{you} left before the end" / "{you} won" / "{you} lost": past verbs with the reader as subject; written as labels "досрочный выход: {ты}", "победа: {ты}", "поражение: {ты}".
16. "{you} both reached lv %d": "{вы} достигли ..." — needs the plural "вы"; the other-character form is "%s и они".
17. Ordinal "NTH_MATCH" words: one list for "матч"; fine as is.
18. "Seen on %1$d day since ..." plural key keyed on the day count: written with the count as an invariant noun-less label ("Видели в разные дни: N, начиная с ..."), all three forms alike.
19. "%d other interaction", "%d wipe": plural written in three forms; "wipe" -> "поражение группы".
20. "Met %s" (heading "Met once"): "Встретились 1 раз" (the "once" word does not exist in Russian; Times() first form is "%d раз").
21. "%1$s and %2$d other|...##plural": three forms with the genitive "человек/человека/человек".
22. "Last seen" lines: "Последний раз видели %1$s %2$s, %3$s" — with a zone phrase "в «...»" after a time that already contains "в 21:43", reads "в 21:43 в «Голдшир», Элвиннский лес" (works, slightly heavy).
23. `Format.Ordinal` (grammar) is masculine only (not my file); "at level %d" and "Level %d" use "%d-м / %d-й" with the noun "уровень" so no agreement problem.
24. "%d-го" in "достигли %d-го уровня": ordinal genitive "-го" holds for every number (1-го, 12-го, 22-го).


## FeaturesA
1. "a death|%s deaths##plural" (Deaths/Text.lua): the count is fed from NUMBER (a##one, two ... five, shared by all nouns). "смерть" is feminine (одна, две), NUMBER words carry one gender. Written as "смерть: %s|смерти: %s|смертей: %s" (colon, so the numeral stands alone); n=1 reads "смерть: один". Needs a gendered NUMBER or a count-free first form.
2. Same fault, same workaround, in the Duels caption phrases: "a duel won|%s duels won##plural", "A duel won %2$s|%1$s duels won %2$s##zone##plural", and the "lost" pair (colon after the noun). n=1 reads "победа в дуэли: один".
3. "another|%s others##plural", "one more close call|...##plural", "%s close call|...##plural" (CloseCalls/Text.lua): written with a masculine noun ("опасный момент") so the shared masculine NUMBER words agree; "ещё один" needs "a##one" = "один". Form 1 must show the count because of 21, so "a close call" cannot be count-free.
4. "One more was in the fight|%s more were in the fight##plural": the code Capital()s the number word, so it reads "Два ещё в бою". Cannot put "Ещё" first. Same for NUMBER words used with a noun in any case.
5. "Got away from %1$s with %2$s." / "Against %s ..." / "a close call with %s" (CloseCalls): the killer's name (Text.KillerName, bare nominative) needs genitive ("от", "против") or instrumental ("с"). Rephrased with colons ("Схватка: %1$s.", "Противник: %1$s", "опасный момент: %s"). Foes list "%1$s and %2$s" (not my file) must read "Plainstrider и ещё два".
6. Duels: the opponent's name needs the instrumental ("с Брамом") or "над Брамом". Rephrased "соперник: %s" everywhere. Nameless "them##with"/"them##against" is "кто-то" (it follows "соперник: ").
7. "{you} fled %s" / "you fled %s" / "they fled %s" (Duels): "бежал/бежала" is gendered by the reader or the stranger, with no noun form available in a list template. Written in the historic present: "{ты сбегаешь} %s" (other character: "%s сбегает"), "ты сбегаешь %s", "они сбегают %s". Reads oddly next to the past counts. "You fled"/"They fled" (field labels and one-line outcome) are noun phrases "Твоё бегство", "Бегство соперника" (the first is reader-only, no brace in the key).
8. "{You} whispered" (Chat/Kind.lua): "Шёпот: {ты}"; for another character reads "Шёпот: Брам". "They whispered/Said/Yelled/Said in party" use "Они ..." plural past (gender-free but "они" for one stranger).
9. "Won/Lost %1$d duel..." series: the second count ("lost %3$d") has no plural key of its own, so it is written "побед %1$d, поражений %3$d" (genitive plural after the noun, correct for any number); the three plural forms of those keys are identical. Only the single-count keys inflect.
10. "Lv %d" is "ур. %d": a gender-free abbreviation. "%d%% health" (Core, not mine) must be "...% здоровья" for "осталось %s" to read.
11. "Won/Lost ... %s##zone" keys: the zone arrives as "в «X»" after the noun, so "Победа в дуэли в «Дуротар», соперник: Брам" (double "в" is intended and natural). For the campfire keys "%2$s, %3$s" the second %3$s is a bare zone name after the phrase ("в «Оазис», Пустоши"): reads as a title, not declined.
12. "beat %1$s %2$d to %3$d" etc.: "победа 3 к 1, Брам" (name last, apposition).
13. "Killed you here", "killed you ..." (Deaths): "убили тебя" impersonal plural; "%1$s, to %2$s" is "%1$s, виновник: %2$s".


## FeaturesB
1. "%d kill|..." and every `Count(n, name)` ("31 Plainstriders", "7 Plainstrider Meat", `Items`, `Hunts.Words`): a figure beside a bare game name cannot take its case ("31 Название" for kills, "4 Название за 7 Название"). Read with a colon: "Понадобилось всего: %1$s за %2$s." Features/Hunts/Text.lua (Parts, Killed, Items).
2. L["drop"] ("предметов") is glued after a figure by `Items(need, "drop")` ("7 предметов" is right, "один предметов" for 1 is wrong). Features/Hunts/Text.lua Parts.
3. NUMBER/WORDS words ("two", "three"...) have one gender, nouns here have three. I wrote feminine nouns where I could (охота, профессия, цепочка, неделя, персона) assuming Words.lua gives "одна/две". Masculine ones break with "две": "%s день|%s дня|%s дней" and "%s месяц..." (QuestFinales Span), "Свидетелей: %s" (kept as a colon form; "Свидетелей: две"), "%s свидетель" avoided. If Words.lua writes "два", the feminine ones break instead. Needs a gender-aware NUMBER (code change).
4. "The end of %1$s, a chain of %2$s..." : %2$s is a nominative number word, "из девяти заданий" needs the genitive; written "цепочка заданий, всего %2$s".
5. "and %s##others" + the verb: "Numa and another tried to save you" makes the verb plural; "Нума и ещё одна персона пытается спасти тебя": verb stays singular (Witnesses.Caption). Also "another|%s others" (not in this file) gives "ещё одна персона" by a feminine noun chosen to suit the numeral word.
6. Witness/PvP sentences: the name (killer, witness) has unknown gender, so verbs are in the present ("смотрит, как ты умираешь", "убивает тебя"). The reader's own act is told through the victim/killer's name plus "от {твоей руки}". Present tense inside a ledger is a style choice (voice file point 5).
7. "%.1f seconds": decimal point stays ("2.3 с"), Russian wants a comma (format string in Witnesses.Tip).
8. "Article" / "Disable (\"A Hogger\")": the setting changes nothing in Russian (G.KillerName returns the bare name); the label is translated only.
9. Firsts.Sentence "%s came by mail" / "%s was a gift" are Capital()ed noun phrases; the verbs of the English ("Bought...") became nouns ("Покупка %2$s — %1$s") because the participle would agree with an item of unknown gender; the place comes first (positional) so it does not hang on the item.
10. "%1$s gave you %2$s": giver's gender unknown, written "Подарок от персонажа %1$s — %2$s". Margin note "gave you %s" → "подарок: %s".
11. "Disable"/choice "Their role" names "Saved/Saw it/Tried" are nouns ("Спасение", "Наблюдение", "Попытка").
12. Creature name after the foe: "от существа %s" (apposition, bare name) in "to %s##witness"/"from %s##witness".
13. "them##killed" is a sentence subject in my template ("Этот персонаж погибает от твоей руки"), so it is capitalised; "They##someone" the same.
14. "Dropped by the first %s", "The first %1$s gave up its %2$s": "Выпало у первого существа: %s" / "Уже с первого существа, %1$s, выпало: %2$s".
15. "after %s": "через %s" takes the accusative; fine for "четыре" and for "14 убийств", but a number word for 1 ("one") would need "одно" (never used: kills <= 1 is "с первого раза").
16. "A day|%s days": used after "за" ("за 5 дней до этого"); "неделю" is the accusative (one form), "день"/"месяц" same as nominative.


## JournalDungeon
1. "{you}##for" / "{you}##from" (UI/Dungeon/Words.lua): another character's name goes bare after "выпало: " and "у ", never declined ("у Орест"). Worded as colon/"у" so the reader form reads ("выпало: тебе", "у тебя"). The two keys cannot share one dative/genitive word for "Reached by" and "snagged from", so "Reached by %s" is "Достигнут у %s" (a stretch).
2. "{You} rolled a %d" / "%1$s rolled a %2$d": rendered "Выпало %d — {тебе}" / "Выпало %2$d — %1$s" to avoid a gendered past verb.
3. "Finally! After %s drop..." and "%s went down": the count is a NUMBER word in the nominative (два, три), so "после двух" / "двое упали" cannot be said; worded with the count after a colon ("Выпадений: два", "Упавших: два").
4. "One item for someone else|%s items for others": NUMBER word nominative: "два предмета" is ok for 2-4 only if the word is masculine; "две"/"одна" wrong for feminine nouns (fine here, предмет is masculine; 1 is "один", 21+ not reached).
5. "The diary has no map of %s yet." / "this place": name must be genitive; set after a colon, so the fallback reads "карты: это место".
6. "%s's story": template passes G.Genitive(name) (bare); "История: %s".
7. "On the way to %s" / "After %s": boss names would be dative/genitive; worded "На пути к боссу: %s", "После босса: %s".
8. "to %s##killers": names joined by Format.List with an English article ("a Dark Iron Looter"?) if the code adds articles; "Убийцы: %s".
9. "The path is full (at most %d points).": "%d точек" is genitive plural, wrong if MAX were 1/2-4 (MAX is a big constant, so fine).
10. "Joined the path back up. Left out: %s." unknown %s type (count or list), written to read for either.
11. "killed on the %s try": "убийство с %s попытки", ordinals in the genitive feminine (первой, второй ...), capital by code.
12. "met in the last %s day|...": %s is tostring(days), so "за последний 21 день" is slightly off for 21, 31...
13. "Seen on %1$d day since %2$s": e.days>1 only, worded with the invariable "дн." so the three forms are equal.
14. "Level %s##level tag": "Ур. %s".
15. "%1$s %2$s##weekday": written "%1$s, %2$s" (comma), the English key says no comma but Russian wants one; weekday is expected lower case.
16. "Everyone you cross paths with is saved for %s.": %s is the "%d day|%d days" plural value, used in the accusative after "на" ("на 30 дней", "на 1 день", "на 2 дня"): fine.
17. "Notice who passes you in the open world" must equal the Settings label (Settings.lua); verify they match.


## Journey
1. "two" (and "one") feed NUMBER/WORDS/SAID shared by every noun (UI/Journey/Text/Grammar.lua:93, Features/*/Text.lua, UI/Dungeon). "два" is masculine; feminine nouns ("заметки", "смерти", "близкие ситуации") need "две". Written "два". Affects "a note|%s notes##plural" and "one more note|..." (reads "два заметки" at 2). Fix: NUMBER words per noun gender, or digits.
2. "a##one" is the n=1 argument of every "%s ..." plural form (NUMBER[1]). Written "1" so it is gender-free ("1 заметка"); the form for 21 shows the figure.
3. "one" (Items(1, item) "one Hezrul's Head", Said(1)): "один" is masculine; the item/noun may not be (item names are the game's, undeclinable). Written "один".
4. "%1$s %2$s##month day" (SittingLabel): month short + `Format.Ordinal(day)`; Russian ordinal helper gives "25-й", so the label reads "25-й окт." instead of "25 окт." Needs a cardinal day for ruRU.
5. Text.Fight "beat %s" / "lost to %s": a name must be declined after "над"/"перед"; written as "победа: %s" / "поражение: %s" (lower case, joined by List).
6. Text.RunWhose "Brom's": G.Genitive returns the bare name, so another's keepsake is labelled with the nominative name; "yours" / "yours at last" / "someone's" written as "ты" / "наконец-то ты" / "кто-то" to match (label = owner).
7. Text.RunDiedTo "%1$s died to %2$s" and "%s died" are not in my file (other area?) check: the past tense "погиб/погибла" would need the person's gender.
8. Flew %s: ns.ZoneIn(nil, list, "to") puts a list of places inside one pair of quotes ("в «A, B»"). The list should be quoted per name.
9. Where(r) in Prose: a subzone arrives as a phrase ("в «Перекрёсток»") and the zone bare after it; written "... %2$s («%3$s»)", a parenthesis rather than a second preposition phrase.
10. "someone##whom" is used where the template takes an object ("You first saw %s"). Russian template written with the nominative ("Первая встреча: кто-то"), so the word is "кто-то", not "кого-то".
11. "We fell once|we fell %s times" and "%1$s %2$s time|..." take the number in words (Said) from a list that ends at twenty, then figures; fine, but "21" uses form 1 ("21 раз").
12. "%s and a half hour|%s and a half hours##plural" takes the form by the whole number of hours; Russian takes the genitive singular after "с половиной" for 2-4 ("два с половиной часа") and 21+ ones; written accordingly (forms 1 and 2 equal).
13. Month/weekday-free; no other faults found. The sample sentences (Empty.lua) contain game names (The Crossroads, The Barrens, Lushwater Oasis): kept as English in quotes, to be filled by someone with the Russian client.


## JourneyMatch
1. Said(n) words (UI/Journey/Text/Match.lua SAID, "one".."twenty") are nominative only. Keys that put a Said word in a case-governed slot ("killed you in all %s", "in %s of them", "With you in all %s", "Against you in all %s") were reworded so the count stands after a colon or "всего" ("в каждом матче: %s", "всего %s"). A list of match numerals ("With you in %s##matches") is "в матчах: %s", wrong for a single match ("в матчах: II").
2. "%1$s killed you %2$s" (Match.lua MatchKilled): a stranger as subject would be gendered; written "%1$s: тебя убили %2$s" (name bare, colon). Same for "killed you in all/of them" ("тебя убивали ...").
3. Death ordinals ("first##death".. "twelfth##death", Match.lua NTH_DEATH) are feminine (смерть). Past 12, Format.Nth falls back to Format.Ordinal (UI/Words/Format.lua) = masculine "13-й", disagreeing with the feminine words before it.
4. Said(n) for n>20 returns digits and for 1 "один": the "one" plural forms are used for 21, 31 (digits) so forms use "%s матч" etc.; fine, but "один раз" / "один матч" depend on SAID[1]="один" (masculine). OK for раз/матч/удар; would break for a feminine noun.
5. "Took their flag %1$s ..." family: the template builds Times() words (дважды / "3 раза") which need no agreement; but the sentence is rebuilt with the flag as subject ("Вражеский флаг захвачен ...") to avoid the gendered "ты захватил". "Нанесён/нанесено" agrees with the kb count through the plural form (1 -> "нанесён", others "нанесено"), which only works because Plural is keyed by kb.
6. "Went in %1$s, %2$s in all" (Tips.lua Dungeon): "Заходили дважды, всего ..." uses an indefinite-plural past verb (no subject); acceptable by the voice rule 2.
7. "With %1$s ..." / "Together ..." (Tips.lua Company): "с + name" would need the instrumental for the name list; rewritten as "Вместе: <names>, ...".
8. "beat %1$s %2$s" / "lost to %1$s %2$s": "над/по + name" would need declension; rewritten "%1$s: победа %2$s" (name, colon, noun). The result is capitalised by code (Text.Capital), the name is not in first position issue-free.
9. "Killed you" (face tooltip) -> "Тебя убили" (stranger subject dropped).
10. "Reached %s" takes Format.At's result, which may be capitalised ("Сегодня в 12:47"): "Достигнут: Сегодня в 12:47" if At capitalises.
11. "From %1$s to %2$s##days" built from AtDay's "вчера в 21:40": "С вчера в 21:40 до сегодня в 12:00" is colloquial, correct only with "вчерашнего"; no way to inflect.
12. "%1$s %2$s##race class" is "Орк, Воин" with the client's names; comma added since the template cannot decline.
13. Times() plural "once|%s times": Said gives words, so "5 раз" is "пять раз", "21" is digits ("21 раз"): fine.


