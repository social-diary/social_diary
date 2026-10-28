---
name: copywriter
description: Write or review player-facing text in Social Diary (journal prose, timeline rows, toasts and cards, onboarding, empty states, settings labels and hints, tooltips, chat output, keybind names). Use whenever adding or changing a string a player will read, and for "/copywriter audit <area>" to check existing copy against the house voice.
argument-hint: "[what to write | audit <file or area>]"
---

# Social Diary copy

The brand voice is set in `.impeccable.md` → *Brand Personality*: **warm,
personal, timeworn; a diary, quiet, never shouts during 
play.** This skill turns that into rules per surface. The changelog has its
own rule (`.claude/rules/changelog.md`); follow that one there.

All copy is English-only, hard-coded (there is no localisation table).
Write British English: *pencilled*, *colour*, *grey*, *levelling*.

## 1. Find the register first

Every surface belongs to one of four registers. Read the strings next to
yours in the same file before writing, and match them.

| Register | Where | Sounds like |
|---|---|---|
| **Book prose** | Your Diary entries (`UI/Journey/Text/`, `Core/JourneyRecap.lua`), the profile story (`UI/Journal/Profile.lua`), front matter, frontispiece, empty states, map keys | “Reached level 12 on 6 October. The road goes on.” |
| **Book ledger** | Timeline rows (`UI/Words/Timeline.lua`), People list, Nearby page, tooltips, card tags and margin words | “Quested together for 1 h 5 min” · “killed you twice” |
| **Book furniture** | Settings, keybinds, link-choices, confirms, the Blizzard settings stub | “Keep my own route” / “Applies to every character.” |
| **Chat** | `ns.Print` output, `/sd` help (`Core/Slash.lua`) | `Social Diary added Thex to the diary.` |

The **parcel** (`UI/Windows/Intro/`) is the one place the diary speaks as “I”
and jokes (goblin shopkeepers, “no refunds”). It is role-play, kept on the
envelope.

## 2. Voice rules (all registers in the book)

- **Who speaks.** The diary narrates to **you**. It calls itself *the
  diary* (“As near as the diary could tell”), never “I”. Other players are
  **they**. Sample notes the player wrote are first person (“Helped me with
  the Nagas.”), because they're the player's words.
- **Tell, don't count.** Prose recaps where you went and who you were
  with. No scores, tallies or progress bars in words (“12 quests done”).
  Counts are fine where they *are* the story (“a chain of nine”, “killed you
  twice”).
- **Past tense for events**, present for state (“They're level 14 now”).
  Hindsight is allowed: “You'd meet again at level 15.”
- **Short and plain.** One idea per sentence. Drop the subject where the
  diary already does (“Reached on…”, “Flew to…”, “Bought your first…”).
- **Whole sentences, not slogans.** Taglines that clip the verb (“Every
  meeting, remembered”, “Your road, inked”, “Strangers, pencilled in”)
  sound like an advert, not a diary. Keep the verb and say it plainly:
  “Every meeting is remembered”, or with more room, “Each meeting is
  automatically noted down”. This holds for headings, toasts, the
  frontispiece and the addon's own description too.
- **Vary the prose** that repeats per level or per row. Use the existing
  seeded variant tables (`STOPS` etc. in `UI/Journey/Text/Prose.lua`) rather than
  one fixed template.
- **Quiet.** No exclamation marks. The only exceptions, both chosen by
  the user: the find card's “Your first green!” and the dungeon sheet's
  “Finally! After two drops, it’s yours” (an item lost on a Need roll
  before, at last won). Warnings are carried by colour and rules, not words: “A
  foe, nearby”, not “WARNING: FOE!”.
- **Humour is dry and rare**, never on errors or deaths of friends. “Even a
  boar, once” is the ceiling.
- **The pencil and ink metaphor** is the model of the data and holds
  everywhere: strangers are *pencilled in* by themselves, *rubbed out* after
  the retention days; adding someone *inks them in*, *for good*.
- **Use game names as the client gives them**: zones, items, creatures
  (with an article: “a Sunscale Lashtail”; rares bare), quest titles in
  curly quotes. Prefer *creature* or the name over gamer words (*mob*,
  *NPC*, *aggro*, *lvl*).

## 3. Words to use

One word per thing. If a sentence needs the other one, rewrite it.

| Thing | Say | Not |
|---|---|---|
| A person you added | *in your diary* / *ink in* / *add* | save, track, favourite |
| A stranger the addon kept | *pencilled in* | candidate, buffer, cached |
| Automatic forgetting | *rubbed out* / *forgotten* (book), *forget* (setting) | expire, purge |
| Taking someone out of the diary | *remove from the diary* (they go back to pencil) | delete |
| Wiping data for good | *delete* + what, + “This cannot be undone.” | clear, reset, remove |
| The player's movement record | *road* (book), *route* only in the one setting label | trail, path, track |
| A meeting | *crossed paths*, *met*, *together* | interaction, session, event |
| The pop-up | *toast* in Settings and changelog; *card* only on the card | notification, alert |
| Someone tagged hostile | *foe* | enemy, target, KOS |

Never show internal words: *interaction(s)*, *data*, *session*, *buffer*,
*retention*, *record(s)*, *SavedVariables*, *passive detection*.

## 4. Mechanics

Use the helpers; don't hand-format numbers or dates.

- **Durations.** Prose speaks them: `Spoken()` in `UI/Journey/Text/Time.lua`
  (“half an hour”, “three hours”). Ledger uses `ns.UI.Format.Duration()`
  (“1 h 5 min”). Mock-ups and samples must match the live formatter.
- **Counts.** Prose: words up to ten (`Count`, `Plural`, number words).
  Ledger: figures (`ns.UI.Format.Times()` → “4 times”). Never mix both in one
  sentence. Keep a number and its unit together with the no-break space the
  helpers use.
- **Dates.** Recent is relative (“today”, “yesterday”, a weekday within the
  week). Older is “6 October”, with the year only when it isn't this year
  (`ns.UI.Format.DayMonth`, `ns.UI.Format.DayLabel`, `ns.UI.Format.Ago`, `ns.UI.Format.At`). No
  ordinals, no zero padding. Timeline rows show only the time; the day is
  in the heading.
- **Case.** Sentence case for everything a player reads, including setting
  labels, headings and macro names. Rubrics (“LEVEL 12”, “WEEK OF…”, day
  headings, “IN THIS BOOK”) are written in sentence case in the source and
  uppercased by the code. Proper names keep their case: *Social Diary*,
  *Your Diary*, *People*, *Recently nearby*, *Questie*, *World PvP*.
- **Punctuation.** Curly quotes and apostrophes in the book (“ ” ’), the
  ellipsis character (…), and a spaced middle dot for ledger joins
  (`  ·  `). No “e.g.”, “fyi”, “&”, “(s)”, or a hyphen used as a dash.
  Sentences end with a full stop; labels, headings and link-choices don't.

## 5. Surface patterns

- **Empty states**: say what's missing, how it fills, what will appear.
  “Nothing of your road is on this map yet.” + the one thing to do.
- **Link-choices and buttons**: a verb for what happens. “Keep” · “Don’t”,
  “Tear it open”, “Reset Position”. Never *OK*, *Submit*, *Yes/No*, *Dismiss*.
- **Destructive confirms**: name exactly what goes, then “This cannot be
  undone.” The confirm link repeats the verb (“Delete”).
- **Setting label**: what it does, in the player's words (“Notice who
  passes you in the open world”). **Hint**: one sentence on the
  consequence or the catch (“Only works if nameplates are on.”). An account
  setting's hint says “Applies to every character.” (`.claude/rules/settings.md`).
- **Toasts**: a heading of a few words, one sentence of story, two lines at
  most. Give the longest variant first so the fitter can fall back.
- **Tooltips**: one fact per line, ledger register; a click hint names the
  result (“Click to open their page in the diary”).
- **Errors and refusals**: what happened, then what to do. “Not during a
  fight. Try again after it.”
- **Chat**: after the coloured prefix, start lowercase, end with a full
  stop, plain words, no internals. Debug-only lines (behind `/sd debug`)
  may be technical.

## 6. How to work

**Writing new copy**

1. Name the register (§1) and read the neighbouring strings and helpers.
2. Draft. For prominent copy (headings, toasts, onboarding, empty states)
   give the user two or three variants with a one-line reason each, and
   recommend one.
3. Check against §2–§5. Read it aloud: if it sounds like a form or a log,
   rewrite it as the diary would say it.
4. Check fit: long names and translations of zones are long; test with the
   longest realistic values (“Hillsbrad Foothills”, an 18-character name).
5. Search `tests/` for the old string. The suite asserts copy; update the
   assertions with it, then run `/opt/homebrew/bin/luajit tests/run.lua`.

**`audit <file or area>`**

List the strings that break §2–§5 as a table: `file:line`, current text,
the rule, the proposed text. Group by severity: *breaks the voice*
(internals, dev slang, OK/Dismiss), *inconsistent* (case, terms, number
format), *polish*. Don't edit until the user picks what to apply.

When the user settles a wording question these rules don't cover, add it
here.
