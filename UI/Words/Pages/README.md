# Diary pages: the writing layer

Turns a **plan** (who and what a page is about, chosen by a planner from the
diary's data) into diary prose, from large libraries of composable words.
Rule-based Lua 5.1, no network, no frames: it runs in the client, and the
page tests render tens of thousands of sentences without one.

```
plan (facts per beat)  ->  Pages.Render  ->  "Brennick turned up again tonight after nearly
                                              three weeks, the longest we've gone without
                                              crossing paths. We spent most of the evening..."
```

## Files

| file | what it is |
|---|---|
| `Core/Pages/Render.lua` | the engine: registry, conditions, combination, shapes, selection, memory, people in sentences |
| `UI/Words/Pages/English.lua` | grammar: numbers in words, a/an, plurals, lists, spans of days, durations, money, items, sentence clean-up |
| `UI/Words/Pages/Slots.lua` | every `{slot}` the words can use (the header lists them with examples) |
| `UI/Words/Pages/Lexicon.lua` | leads between sentences, shared verb banks, the narrator's small reactions |
| `UI/Words/Pages/Angles/*.lua` | the words: one file per angle |
| `WRITING.md` | how to write words, the rules of honesty, and the **fact contract** for every angle |
| `tests/prose/run.lua` | renders every angle against generated facts and checks the output |
| `tests/prose/fixtures/*.lua` | fact generators, one per angle |
| `tests/prose/pages/week.lua` | a week of whole pages with recurring people |
| `tests/prose/samples.txt` | that week, rendered in all four voices |

## What's in the library

6,541 pieces across 21 angles and 32 moves, plus 120 bank entries. In the
tests, almost every render is a different sentence (1,597 different rescue
texts from 1,600 renders), and pieces combine into far more sentences than
that: the shape is drawn first, then a stem, clause and tail that fit
together.

| angle | moves (pieces) | about |
|---|---|---|
| open | scene 156, climb 158 | where and when; my levels |
| close | coda 144 | how the page ends |
| quiet | line 182 | a page where little happened |
| crowd | others 160 | people in numbers |
| reunion | gap 123, history 30 | a diary entry back after a long gap |
| regular | streak 40 | met day after day |
| together | time 205, rares 124, deaths 102 | time spent with someone |
| parity | levels 222 | our levels side by side |
| ding | level 187 | they levelled while I was there |
| changed | name 135, guild 142, levels 137 | what changed since we last met |
| lost | touch 186 | not seen in a long time |
| new_face | meet 440, added 113 | someone new, and into the diary |
| stranger | seen 185, silence 102 | the familiar stranger |
| chat | heard 106, quote 156 | whispers and a kept line |
| campfire | sat 186 | someone sat at my fire |
| rescue | saved 258, helped 165 | someone stepped into my fight |
| witness | watched 259 | someone was there when I died |
| misfortune | shared 249 | we died together |
| duel | series 295 | friendly duels |
| pvp | death 180, kill 142 | world PvP, hedged when probable |
| trade | gift 243, given 216, swap 178 | gifts and exchanges |
| dungeon | run 206, trouble 144, loot 119, roll 166 | a dungeon run |

Four voices: plain, warm, wry and terse, or "mixed", drawn per page.

## Speed

About 24 ms a page on average and 80 ms at worst in stock Lua 5.1, for a
page of 15 to 20 sentences. A page is written once and kept, so this is a
one-off cost per page. If it ever shows as a hitch, write pages in a
coroutine and yield between beats.

## Load order (.toc)

```
UI\Words\Pages\English.lua
Core\Pages\Render.lua
UI\Words\Pages\Slots.lua
UI\Words\Pages\Lexicon.lua
UI\Words\Pages\Angles\Reunion.lua
UI\Words\Pages\Angles\Open.lua
... every other file in Angles\, in any order
```

## Using it

```lua
local memory = ns.Pages.Memory(ns.db.pages.memory)   -- a plain saved table

local text, report = ns.Pages.Render(plan, {
    voice = "plain",          -- "plain", "warm", "wry" or "terse"
    memory = memory,
    commit = true,            -- first time this page is written
})
ns.db.pages.list[plan.key] = { text = text, picks = report.picks }
```

A page is written once and kept: store its text (or its `picks`, which
re-write it word for word with `opts.picks`). Memory is what keeps pages
from repeating each other, so pages must be written in date order, each with
`commit = true` once.

The plan shape is documented above `Pages.Render`; each beat names an angle,
its facts (the contract in `WRITING.md`), and optionally which moves, a
relation to the sentence before (`rel`), a `must` (what the beat is for), and
`short`.

## What's not here yet

A planner for whole pages. The one planner so far writes single together
rows on a person's timeline, while `/sd prose` is on (a dev command):
`UI/Words/SessionHistory.lua`, `SessionCandidates.lua`, `SessionWeights.lua`,
`SessionLedger.lua`, `SessionProse.lua`. It saves nothing and doesn't use
`open/scene`, `close`, `quiet`, `crowd`, `regular`, `changed`, `lost`,
`stranger`, `chat/quote`, `misfortune`, `duel` or `pvp`. A page planner would
also read `db.around` and `People.Stats`; the fact contract in `WRITING.md`
is its spec, field by field.

## Tests

```
luajit tests/prose/run.lua .                       # everything
luajit tests/prose/run.lua . --angle rescue --show 40
luajit tests/prose/run.lua . --samples samples.txt
```
