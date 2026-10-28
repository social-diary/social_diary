# Writing words for the pages

The page writer turns a **plan** (what to say, decided by the planner) into
diary prose. This file is the guide for adding words, and the **fact
contract**: what the planner hands each angle.

Read `UI/Words/Pages/Angles/Reunion.lua` before writing anything. It is the
model for every other angle file.

## How a sentence is built

An **angle** (`reunion`, `rescue`, ...) has **moves**, one sentence each.
A move's words are declared with `Pages.Words(angle, move, spec)`, in five
kinds:

| kind | what it is | example |
|---|---|---|
| `stems` | an opening that leads into a clause; ends in `", "`, `" and "` or `": "` | `"After {days:gapDays} apart, "` |
| `clauses` | a full clause with its subject; starts lower case unless it starts with a slot or "I" | `"{ref} turned up again"` |
| `fragments` | diary shorthand that stands alone; never after a stem | `"Ran into {ref.obj} again"` |
| `tails` | follows a clause or fragment; starts with `", "` or `" "` | `", the longest we've gone without crossing paths"` |
| `wholes` | one or two complete sentences, with their own full stops | `"{ref} was back {today}. It had been {days:gapDays}."` |

A sentence is a whole, or `[stem] + clause + [tail]`, or `fragment + [tail]`.
The engine draws the **shape** first (by voice), then the words, so every
kind matters. The full stop and capitals are added for you.

### Pieces

A piece is a string, or a table with the text first:

```lua
{ "{ref} turned up {in:zone}, a zone we'd never shared", needs = { "zoneNewForUs" } },
{ ", which is a long time for us", needs = { "longAbsence" }, says = { "usual" } },
{ "After {days:gapDays} I'd half assumed {ref} had quit. Apparently not.", needs = { "longAbsence" }, voice = "wry" },
```

- `needs`: conditions on the facts. `"flag"`, `"!flag"`, `"n>=3"`, `"pct<10"`,
  `"foe.rank==elite"`, `"who.diary"`, `"page.part==evening"`, `"seen>@groupedWith"`
  (compared with another fact), `"#page.zones>=2"` (the length of a list). Slots add their
  own needs automatically, so `{num:quests}` already needs `quests` to be
  truthy (0 doesn't count). Add a need for **every fact the words assert that
  isn't a slot**: "the longest we've gone" needs `isRecordGap`.
- A `needs` entry starting with `?` is a **guard**: it must hold, but the
  piece doesn't say it (`"?viaChat"`), so two pieces guarded on the same flag
  can still meet.
- `says`: tags this piece says beyond its slots. Tags starting with `_`
  (`"_colon"`, `"_tense"`) only keep pieces of one sentence apart; other tags
  are remembered for the whole page, per person, so a later sentence about
  the same person won't say them again. Slots say the fact they read
  (`{days:gapDays}` says `gapDays`), and a bare positive flag in `needs` says
  itself. Two pieces that say the same tag are never combined, so nothing is
  said twice. Add `says` when the wording expresses something a different
  piece might also express (`says = { "record" }` on every record-gap line).
- Tags you invent are remembered per person for the whole page, across
  angles. Prefix them with your angle (`"rescue.act"`) unless you mean them
  to be shared, as `page.mood.*` is for "glad once per page". The engine adds
  its own sentence-only tags for a colon, a semicolon, ", and", ", but" and
  "though", so two pieces never stack those.
- `voice`: `"warm"`, `"wry"` or `"terse"`. Drawn only on pages in that voice,
  and more often there. Untagged pieces are neutral and drawn in every voice.
- `bonus`: added to specificity. Use `-0.5` or `-1` for a dull fallback.
- `final = true`: a clause or fragment that takes no tail (it already ends
  in its own "which ..." clause).
- `lead = true`: a whole that may take a lead ("Later, ").

### Move options

```lua
Words("reunion", "gap", {
    must = { "gapDays" },     -- tags every sentence of this move must say ("a|b": either)
    needs = { "gapDays" },    -- conditions before the move is tried at all
    rel = "then",             -- the lead when it follows another move of its angle
    stems = { ... }, clauses = { ... }, fragments = { ... }, tails = { ... }, wholes = { ... },
})
```

Use `must` for the point of the move, so the fallback combinations can't
leave it out. A whole that conveys the point another way (a date instead of
a day count) declares it in `says`.

### Text syntax

- `{slot}` / `{slot.mod:arg}`: words from the facts. Full list with examples
  in the header of `UI/Words/Pages/Slots.lua`. The common ones:
  `{ref}` `{ref.obj}` `{ref.poss}` `{ref.short}` `{ref:by}` `{he}` `{him}` `{his}`
  `{num:f}` `{count:f:noun}` `{times:f}` `{nth:f}` `{days:f}` `{ago:f}` `{when:f}`
  `{date:f}` `{dur:f}` `{secs:f}` `{share:f}` `{lvl:f}` `{levels:f}` `{money:f}`
  `{coins:f}` `{items:f}` `{item:f}` `{v:f}` `{in:f}` `{at:f}` `{pct:f}` `{foe:f}`
  `{score}` `{today}` `{part}` `{zones}`. `.cap` capitalises, `.a` adds a or an.
- `[a|b|c]`: one of these. Put synonyms here rather than in separate pieces.
  May nest and hold slots, but a slot inside counts as needed either way.
- `<bank>`: one entry of a bank (`UI/Words/Pages/Lexicon.lua`): `<ranInto>`,
  `<groupedWith>`, `<noticed>`, `<again>`, `<glad>`, `<relief>`, `<grumble>`.
  You may declare your own banks in your angle file, named `<angle>.<name>`.

## Rules of honesty

The data is observational, and the diary must not claim more than it shows.
These are the rules the words must keep:

1. **Positions are the user's own.** Write "near me at Astranaar", "{at:subZone}"
   about where *I* was. Never say where the other person stood, ran or went.
2. **Verbs follow the kind of evidence.** Met, saw, ran into, crossed paths:
   only for proximity (sessions, sightings, trade, say). A whisper is "heard
   from"; never "saw" for chat alone. Grouped, teamed up: only with `grouped`
   or a group session.
3. **Sightings are hour buckets.** Count days or evenings, never "times I saw".
4. **Hedge what is probable.** A `probable` kill is "probably", "as far as I
   can tell", "I think".
5. **No minds but mine.** Never say what another player wanted, meant, felt,
   noticed, remembered or decided. "He stepped in" yes; "he wanted to help"
   no; "she was glad" no. The narrator (I) may feel things about my own
   experience: glad, relieved, annoyed, amused.
6. **No invented actions or outcomes.** Don't add a hearthstone, a /wave, a
   joke, a conversation, a thank-you, a mount or a weather report the facts
   don't hold. A narrator's reaction is fine; a narrated event is not.
7. **Negative framing of others only with their tag.** Someone who watched me
   die is told neutrally, unless `who.tags.foe` or `who.tags.avoid` (and then
   dry, not cruel). Hostile players who killed me can be grumbled about.
8. **Words for amounts follow the facts.** "Barely" needs a small number,
   "a fortune" needs a big one: guard them with `needs`.
9. **Quotes only through `{v:quote}`**, short, and only in the chat angle.

## Style

- First person, past tense, a diary: plain, concrete, understated. Short
  sentences next to longer ones. British spelling (levelling, favour, colour).
- **Variants must differ in structure, focus or rhythm.** A synonym swap is
  not a new variant: put synonyms in `[a|b]`. Vary what comes first (time,
  place, person, the number), sentence length, and the angle of approach.
- No AI tells: no "Additionally", "Moreover", "Furthermore", "Notably",
  "testament", "tapestry", "delve", "vibrant", "bustling", "embark",
  "unforgettable", "a reminder that". No em dashes (use commas, colons,
  semicolons or a full stop). No triplets for rhythm's sake. Exclamation
  marks only rarely, in wry pieces.
- Never write "a" or "an" before a slot; use `{x.a}` or a slot that adds
  its own article (`{foe:f}`, `{ref}`, `{desc.a}`).
- **`{ref}` is a subject.** After a preposition or as an object ("with
  {ref.obj}", "saw {ref.obj}", "beat {ref.obj}") always use `.obj`, or a second
  mention turns into "with she". The tests flag "with she" and friends.
- `{ref.short}` is the plain name or description: never an epithet, never a
  pronoun. Use it for note-style fragments ("{ref.short} again").
- Use `{ref}` (and `.obj`, `.poss`) for people. `{he}` `{him}` `{his}` only
  after the person was named in the same piece or an earlier piece of the
  same sentence. Never "they" for one person. `.poss` is a possessive, never
  the "'s" of "has".
- Don't put `{ref}` in a stem and start the clause with "I" referring to
  them; the engine already makes the second `{ref}` a pronoun.
- Keep sentences under 35 words. A whole may be two sentences, rarely three.
- The voices: **plain** is neutral, observant; **warm** lets the diarist's
  fondness show; **wry** is dry humour at the diarist's own expense or the
  situation's (never mocking the other player); **terse** is clipped, notes
  more than prose.

## Quantity

There is no human budget here, so write a lot, but every line must earn its
place. For each move aim at:

- 10+ stems (where stems make sense for the move), 25+ clauses, 10+
  fragments, 15+ tails, 30+ wholes;
- every flag in the contract used by several pieces, both shapes and wholes;
- at least 15% warm, 15% wry and 10% terse pieces, spread across kinds;
- fallbacks that need nothing but the move's core facts, so a sentence can
  always be written.

## Fixtures and the tests

Each angle has `tests/prose/fixtures/<angle>.lua`:

```lua
return {
    angle = "reunion",
    n = 600,
    gen = function(P)            -- P: the helper in tests/prose/run.lua
        return { who = P.person({ diary = true }), gapDays = P.int(3, 90), ... }
        -- optionally a second value: the page, e.g. P.page({ levelsGained = 0 })
    end,
}
```

Generate realistic, consistent facts within the contract: flags both true
and false, optional facts sometimes missing, numbers across their range
including the edges (1, round numbers, large). `P.person`, `P.items`,
`P.foe`, `P.page`, `P.pick`, `P.int`, `P.chance`, `P.maybe`, `P.now`, `P.DAY`.

Run:

```
luajit tests/prose/run.lua . --load YourFile,Other --angle a,b --quiet
luajit tests/prose/run.lua . --load YourFile --angle a --show 40 --n 400
```

Get to **0 errors**. Every piece must be eligible under some fixture; "never
drawn" warnings are fine for a few rare voiced pieces, but not for many.
Then **read `--show` output in every voice** and fix whatever reads badly.

# The fact contract

What the planner puts in `facts` for each angle. Times are Unix times;
"days" are whole days. Every angle can read `page.*`:

| page fact | meaning |
|---|---|
| `part` | "morning", "afternoon", "evening" or "night" |
| `seconds` | the session's length |
| `zones`, `zoneFirst`, `zoneLast` | the session's zones, in order |
| `levelStart`, `levelEnd`, `levelsGained`, `levelCap` | my levels |
| `solo` | I never grouped this session |
| `diaryMet` | diary entries I met today |
| `newFaces` | strangers I dealt with (grouped, traded, talked) |
| `seen` | players I saw nearby |
| `myDeaths` | my deaths this session |

A **person** (`who`, and any other person fact) is
`{ id, name, sex (2 male, 3 female, nil), race, class, relationship, diary,
named, familiar, hostile, level, tags = { friend = true, ... } }`.
Named people (diary entries, or `named`) go by name, everyone else by how
they look.

### reunion (Reunion.lua) and regular

See the header of `Reunion.lua`.

### open: a page's first sentences (no who)
- `scene`: where and when. Page facts, plus `newZones` (list: zones this
  character entered for the first time today), `returnZone` (a zone I came
  back to after `returnDays`, 30+, away).
- `climb`: my levels. `page.levelsGained` (1+), `milestone` (a round level
  reached today: 10, 20, ...), `reachedCap` (bool), `levelsToCap`.

### close: a page's last sentence (no who)
- `coda`: page facts, plus `lateEnd` (the session ended after midnight),
  `endZone` (= page.zoneLast), `endSubZone` (where I stopped, if known).

### quiet: the whole page when little happened (no who)
- `line`: page facts, plus `nobodyKnown` (bool: no diary entry met),
  `seen` (players seen), `gained` (= page.levelsGained, may be 0).

### crowd: people in numbers (no who)
- `others`: `newFaces`, `seen`, `groupedWith` (strangers grouped with),
  `busiestZone`, `busiestSeen` (players seen there), `hostileSeen`.

### together: time with someone (who)
- `time`: `seconds` (together), `grouped` (bool; else just nearby),
  `zones` (list of zones together), `zone` (main one), `quests` (completed
  together), `others` (non-diary members of the group), `wholeSession` (bool).
- `rares`: `rare` (name of a rare found together), `rareCount`, `rareKilled`.
- `deaths`: `theirDeaths`, `myDeaths` (while together).

### parity: our levels side by side (who)
- `levels`: `myLevel`, `theirLevel`, `levelDiff` (mine minus theirs),
  `absLevelDiff`, `sameLevel`, `aheadMe`, `aheadThem`, `crossed` (the lead
  changed hands since we last met), `closed` (the gap narrowed), `widened`,
  `diffThen` (the gap at our last meeting).

### ding: they levelled while I was there (who)
- `level`: `level` (new level), `from`, `together` (grouped or nearby),
  `round` (a multiple of ten), `cap` (max level), `alsoMe` (I levelled within
  minutes of them), `levels` (levels they gained while with me, 1+).

### changed: what changed about them since we last met (who)
- `guild`: `oldGuild`, `newGuild` (names or nil), `joined`, `left`, `switched`.
- `name`: `oldName`, `newName`.
- `levels`: `theirLevelThen`, `theirLevel`, `gained`, `myGained`, `daysSince`.

### lost: not seen in a long time (who)
- `touch`: `lastDays` (since we last met), `lastZone`, `timesMet`,
  `usualGapDays`, `longest` (the longest absence yet), `seenDays` (since I
  last saw them nearby without meeting, if more recent), `heardDays` (since
  the last whisper, if more recent).

### new_face: someone new (who)
- `meet`: `how` ("group", "trade", "duel", "campfire", "chat", "rescue",
  "say") and the matching flag `viaGroup`, `viaTrade`, `viaDuel`,
  `viaCampfire`, `viaChat`, `viaRescue`, `viaSay`; `zone`, `subZone`,
  `seconds` (together, if grouped), `quests`, `guildmate`, `theirLevel`.
- `added`: `addedToday` (I wrote them into the diary today), `tag` (their
  first tag, e.g. "friend").

### stranger: a familiar stranger (who, usually unnamed)
- `seen`: `days` (distinct days seen, 3+), `windowDays` (7 or 30), `zone`,
  `subZone` (where most), `sameSpot`, `sameTime`, `levelFirst`, `levelNow`,
  `levelRise`.
- `silence`: `neverSpoke`, `neverGrouped`.

### chat: words exchanged (who)
- `heard`: `whispersIn`, `whispersOut` (today), `noMeeting` (only whispers
  today, no meeting), `firstWhisper`.
- `quote`: `quote` (90 chars at most), `fromMe` (my words; else theirs),
  `channel` ("whisper", "say", "party", "yell").

### campfire: someone sat at my campfire (who)
- `sat`: `zone`, `subZone`, `theirLevel`, `strangers` (others who sat too,
  0+), `firstTime` (the first time they sat at my fire).

### rescue: they helped me in a fight (who)
- `saved`: `pct` (my health left), `foe` ({ name, rank }), `firstByThem`,
  `timesSaved` (by them, 1+), `grouped`.
- `helped`: `foe`, `died` (I died anyway), `grouped`.

### witness: they watched me die (who)
- `watched`: `watched` (seconds), `foe`, `zone`, `subZone`, `alsoHelped`.
  Pointed lines need `who.tags.foe` or `who.tags.avoid`.

### misfortune: we died close together (who)
- `shared`: `foe` (what killed us), `sameKiller`, `within` (seconds between
  the deaths), `iDiedFirst`, `theyDiedFirst`, `zone`, `subZone`, `grouped`.

### duel: a duel series (who)
- `series`: `won`, `lost` (this series, 0 counts), `total`, `lastWon`,
  `lastLost`, `swept` (I won all, 2+), `wasSwept`, `even`, `first` (our
  first duels), `allWon`, `allLost` (all-time), `zone`, `subZone`.

### pvp: world PvP (who, hostile)
- `death`: they killed me. `probable`, `spell`, `timesKilledMe` (all-time,
  this one included), `lastDeathWhen`, `toldBefore` (the diary told an
  earlier one), `zone`, `subZone`, `outlevelled` (they were 5+ levels above).
- `kill`: we killed them. `by` (the person who landed the blow) or `mine`
  (my blow), `timesKilledThem`, `revenge` (they had killed me before), `zone`.

### trade (who)
- `gift`: they gave, I gave nothing. `received` (items), `moneyReceived`
  (copper), `first` (first trade with them), `returned` (I had given them
  something before), `returnDays`.
- `given`: I gave, they gave nothing. `given`, `moneyGiven`, `first`,
  `returned` (they had given me something before), `returnDays`.
- `swap`: both ways. `received`, `given`, `moneyReceived`, `moneyGiven`, `first`.

### dungeon (no who)
- `run`: `instance`, `difficulty`, `groupSize`, `friend` (a diary person in
  the group), `friendCount`, `strangers`, `seconds`, `bossesKilled`,
  `bossesTotal`, `fullClear`, `firstClear` (my first time finishing it),
  `firstVisit`.
- `trouble`: `wipes`, `deaths`, `myDeaths`, `noDeaths`, `deadliest` (a person),
  `deadliestCount`.
- `loot`: `myLoot` (items I got), `friend`, `friendLoot` (items they got).
- `roll`: `rollItem` (one item entry), `iWon`, `winner` (a person, when I
  lost), `myRoll`, `winRoll`, `close` (within 3).

## Notes for the planner

What the word libraries assume beyond the tables above, gathered while
writing them. The planner should keep to these, or the words need changing.

**Everywhere**
- Send a fact only when it is true and known. Absent and `false` both read as
  "no"; `0` counts as absent for most slots (use `{num0}` where zero matters).
- A person met today and written into the diary today is `diary = true` for
  the whole page, and its beats should pass `epithets = false` (a relationship
  typed today has no history to name yet).
- Hostile players are rarely diary entries. A repeat killer should be
  `familiar = true` (and `named`, once the diary knows the name), or a second
  killing reads "a priest killed me again", as if any priest would do.
- Places are always the user's own position at the time.

**open / close / quiet / crowd**
- `lateEnd` only for sessions that started in the evening or at night.
- `busiestZone` is one of `page.zones`.
- `quiet` and `crowd` are not meant for the same page.

**together**
- `others` is a count, or a list of people (preferred: the words can name
  up to three).
- When the `deaths` move is used, send both `theirDeaths` and `myDeaths`
  (0 counts).
- `grouped` is fixed for the session. Kills of rares are told as ours only
  when `grouped`; nearby-only sessions say the rare "went down" with them
  there.

**parity / ding / changed**
- `crossed` is a lead changing hands since we last met; `closed` and
  `widened` are only meaningful without it. `diffThen` is absent on a first
  meeting.
- `ding.from` is `level - levels`. `cap` uses `page.levelCap`.
- `changed`: `who.name` is the new name; an unchanged guild is
  `oldGuild == newGuild` or both absent; `myGained` is always sent (0+).

**new_face / stranger / chat**
- `addedToday` implies `who.diary`. `seconds` and `quests` come only with
  `viaGroup` (quests may be 0).
- `stranger.levelFirst` is their level on the first day of the window.
- `chat`: the quote's speaker is `who` unless `fromMe`. `noMeeting` goes
  only with whispered quotes; a /say, party or yell line means we were near.
  Prefer the user's own lines when choosing a quote.

**lost**
- `seenDays` and `heardDays` are absent rather than stale when they are not
  more recent than `lastDays`; `seenDays = 0` means today.

**duel / pvp**
- `{score}` puts the winner's side first; words around it say who won.
- `timesKilledThem` counts the times they died to me or my group.
- The pvp words hedge every `probable` death; send `probable` whenever the
  death recap hasn't confirmed the killer.

**trade**
- Each trade is one direction: `gift`, `given` or `swap`.
- Possible addition: `returnedItems` / `returnedMoney` (what the earlier gift
  was), and `returned` for swaps.

**dungeon**
- When `iWon`, `winRoll` is the best roll I beat.
- `deadliest` is never me. The rolled item is not repeated in `myLoot` or
  `friendLoot`. `difficulty` is "normal" or "heroic" (or absent).
- Only one `friend` person is sent; with `friendCount` 2+ the words say
  "and another familiar face". A list would let them name everyone.
