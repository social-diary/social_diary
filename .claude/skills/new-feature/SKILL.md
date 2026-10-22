---
name: new-feature
description: Add a new detection to Social Diary — something the addon notices in the game (a duel, a campfire, a rare kill) and writes into a person's timeline, the route, Your Diary's plates or the journal. Runs the whole pipeline: feasibility, scope in player terms, probe, UI proposal, copy, build, verification, in-client rounds, and folding what was learnt back into this skill.
argument-hint: "[the game moment to detect, in a sentence]"
disable-model-invocation: true
---

# Add a new feature

A feature (a *detection*) is one folder, `Features/<Name>/`, that registers
itself into the registries of `Core/` and `UI/`. Nothing outside the folder
names it. A new feature touches only these places:

- its folder;
- `social_diary.toc` (its lines in the features block and the Dev block);
- `tests/<name>.lua`, `tests/<name>_ui.lua` and `tests/run.lua`'s `FILES`;
- `CHANGELOG.md`.

Anything else is a **core hook** (phase 4b), done on purpose and on its own.

This skill is the reference for adding a feature. What goes in which file,
which registry, where capture loads, and the patterns earlier features
needed are all in [folder.md](folder.md). The code's spec comments (above
each `Register…` function) are the truth for the fields; this skill says
where to look and why.

**Keep it current.** Every run ends with phase 11: what this run found out
goes back into this file and `folder.md`, edited in place.

## Standing rules

- Read `AGENTS.md` and `.impeccable.md` first.
- **Who does what.**
  - The main session does feasibility, the probe, `Kind.lua`, `Data.lua`,
    `Capture.lua`, `Dev.lua`, the capture tests, verification, the
    changelog and the in-client rounds.
  - UI design and the UI build go to a subagent that loads `plates` and
    `frontend-design` (AGENTS.md).
  - Words a player reads go to a subagent that loads `copywriter`. The only
    exception is words the user locked: these go in exactly as given.
  - The changelog is written by the main session, per
    `.claude/rules/changelog.md`.
- **Ask in player terms.** "Should it show on the person's timeline?", not
  "register a row kind?". The user decides what a player sees. You decide
  the code, and report it.
- **Other sessions edit between turns.** Re-read a file right before
  editing it. Use Edit, not whole-file rewrites. Never revert changes you
  didn't make.
- **Never commit.** The user commits. Offer a natural commit point after
  phase 4b and after phase 9.
- **Invented names only.** Tests, test data, comments and this skill use
  made-up names, never anything recorded from real players. Probe logs and
  the dossier stay local and untracked.
- **Comments match the house style.** Long prose that explains *why*. A
  constant table gets a comment field by field. A value changed after a
  screenshot gets a dated note: "(16 Oct, in the client: …)".

## The dossier

Each feature has one working file, `.claude/features/<name>.md` (local,
untracked: `.claude/*` is gitignored). Every phase appends its output to it.
It is the hand-off to every subagent, and the way back in after a context
reset. Start it in phase 1:

```markdown
# <Name>: <the moment, in the user's sentence>
Started <date>. Status: <phase>.

## Feasibility      signals, neighbours, nearest example, non-goals
## Scope            the surface sheet, weight, locked words
## Probe            what the client really sends (facts, dated)
## Record           the data contract: what Kind.lua stores, field by field
## UI proposal      link to .claude/ui-proposal/<name>.md, decisions
## Build            files made, TOC lines and why, tests
## In the client    rounds: date, what was asked, what came back
## For the skill    what this run taught (phase 11)
```

## The pipeline

| # | Phase | Who | Gate |
|---|---|---|---|
| 1 | Describe | user | the moment in a sentence |
| 2 | Feasibility | main (+ Explore) | signal table, neighbours, nearest example |
| 3 | Scope | **user** | surface sheet signed |
| 4 | Probe | main + user | every signal relied on is confirmed; loop to 3 if the scope moves |
| 4b | Core hook (only if needed) | main | hook in, its break-it test fails and passes |
| 5 | Scaffold ∥ UI proposal | main ∥ subagent | capture side green ∥ proposal written |
| 6 | Sign-off | **user** | proposal signed |
| 7 | Copy | subagent | words in place |
| 8 | UI build | subagent | UI tests green, render checked |
| 9 | Verification | main | every check below passes |
| 10 | Wrap-up and in-client rounds | main + user | checklist answered |
| 11 | Fold back | main, **user** approves | skill updated |

### 1. Describe

The user says what they want in a sentence ("huddle by a campfire, it's
social", "a duel"). Name the folder (`Features/<Name>/`, PascalCase) and the
namespace (`ns.<Name>`). Start the dossier.

### 2. Feasibility

The question: which signals does the current client allow, and how
robustly can we detect the moment from them?

**Sources.** Use these before anything remembered:
- `.claude/api_resource.md` (where the current API docs are, and the
  secret-values rules);
- `.claude/feasability_report.md` (earlier verdicts by area: units,
  groups, location, deaths, loot, trades, duels, emotes, …);
- the current build's generated API docs.

This is a classic-era game on the **retail** API (12.x). The combat log is
closed. Secret values hide units, auras and chat in combat and in
instances. Advice written before 2026 is suspect.

**The signal table.** One row per signal:

| Signal | Carries: who · where · when · how long | Reliable / partial / impossible | Restricted when | Edge cases |

"Who" is what the surfaces in phase 3 hinge on. It can be:
- another player (a GUID, a name);
- a creature (an npcID, a name, a rank);
- the user alone;
- an object (no owner);
- an aura (a spell id, a duration).

**Neighbours.** An Explore subagent does this sweep:
- every `ns.On("<EVENT>"` for the same client events in `Core/`,
  `Capture/` and `Features/`, with what each handler touches;
- the `SD_*` messages that already carry the moment (header of
  `Core/Events.lua`);
- the **nearest existing feature**, whose folder becomes the example to
  copy ([folder.md](folder.md), "Patterns by example").

**Also note:**
- what the moment cannot be told apart from;
- what happens in a group, in combat, in an instance, on a reload, at
  logout;
- non-goals;
- whether any surface would need a core hook (4b).

### 3. Scope: the surface sheet

**Build the choices from the signal table, not from a fixed menu.** A
surface is offered only if the signals carry what it needs:

| A player would see… | Needs from the signal | Lands in | Example |
|---|---|---|---|
| a line on that person's timeline | another player's GUID | `Kind.lua`: `ns.Rows.Register` (with `plate`, its rank for the person page's plate, Core/PersonPlate.lua) | Chat, Trade, Campfire |
| the person marked on Recently nearby's day | a player within range (a `dealt` mark from `Rows.DEALT`; a new mark is a core hook) | `Kind.lua`: Rows `dealt` | Trade |
| a count in a together session | a group and a session open | core session (Rares writes through `Sessions.Rare`) | Rares |
| kept on the user's route | the user, a place, a time | `Kind.lua`: `Journey.RegisterList` | Campfire, Hunts |
| it can open a plate in Your Diary, or only fills one | a route record | `Kind.lua`: `Recap.RegisterMoment` (rank, light) | Hunts (heavy), Campfire (light) |
| a mark on the plate's map | a place (map + x, y) | `Mark.lua` | Hunts' tally and star |
| a note or card in the plate's margin, and its size | a moment on a plate | `Slip.lua` / `Card.lua` | Hunts' cards, Campfire's slip |
| words in a plate's caption | a moment on a plate | `Text.lua`: `RegisterCaption` | Deaths, Hunts |
| a paragraph in a level's entry on the left page | a route record | `Text.lua`: `RegisterLines` | Close calls + Hunts ("combat") |
| something drawn over the plate's picture | a moment on a plate | `RegisterPass` | Hunts' lucky print |
| a journal page, a setting, a toast, a slash command | — | the page/section registries, `Slash.Register`; a toast is a core hook | — |

Each surface asks something different of the signal:
- A creature gives no timeline line, because rows are on players. It can
  give route, mark, card and caption (Hunts).
- An aura gives place and duration (Campfire).
- Another player in range gives a row and, possibly, Nearby.

Ask with AskUserQuestion: a multi-select of the surfaces the signals allow,
each described as the player sees it. Then settle:
- **Weight.** Does it open a plate, or only fill one ("filler if we have
  nothing better")? Compare it with moments the user knows: "above a
  dungeon, below a death".
- **The plate label.** Which sizes the margin note comes in, and its
  wording. Decide both here, before any design. The sizes are standing
  terms, set by the width of the box the note gets (`LAYOUT` in
  `UI/Journey/Look.lua`):
  - **XL** (190 px and wider): a shared row; a three-plate page's
    columns; under a single plate's caption.
  - **L** (150–189 px): the usual full-plate caption column (176 px).
  - **M** (122–149 px): the row boxes under a plate; the two-plate page's
    left column.
  - **S**: one line in the hand. It is the only size that goes under a
    light plate's caption (filler), and the size used on a print.

  A card that matters supports L and M at least, or it gets left off on
  most pages. Filler is S.
- **Locked words.** Any wording the user gives verbatim. It is written into
  the dossier as locked, and no one changes it (Campfire's "sat by a
  campfire", lower-case s included).
- **Non-goals**, confirmed.

The signed list is the **surface sheet**. It fixes the folder's file list.

### 4. Probe

Prove that the signals in the sheet behave as the table says, in this
client.

- **Prefer `/run` snippets** the user pastes. For anything beyond one
  value, the snippet writes into a SavedVariables table instead of
  printing.
- **For watches over time** (an aura's life, an event's order, a group),
  use a module in the local probe addon,
  `Interface/AddOns/SDiaryProbe/<Name>.lua` (its own SavedVariables,
  `SDiaryProbeDB`, `/sdp`). Copy an existing module's shape. The probe
  addon is not in this repo.
- **Data never comes back as screenshots.** Long output is hard to read off
  an image. The user does `/reload` (or logs out), then you read
  `WTF/Account/*/SavedVariables/<Addon>.lua` with luajit. A reload loads
  only code already on disk, so finish every edit before asking.
- **Give the user numbered steps:** where to stand, what to do, what to
  type, when to reload.

Write the facts into the dossier, dated: ids, durations, payloads, what is
secret when. Then ask: **does this change the scope?** If a signal is
weaker or richer than assumed, go back to 3 with the difference stated in
player terms.

Close the phase by writing the **Record** section. This is the data
contract the UI and the copy work from: each stored field, its type, and
an example with invented names.

### 4b. Core hook (only when the sheet needs one)

A core hook is needed when:
- a surface needs something no registry offers (a new `dealt` mark, a new
  `SD_*` message, a new spec field);
- core would have to name the feature.

Then, in the main session, before the folder:
- Prefer a **flag on the row kind** (`fight`, `witness`, `climb`) that core
  reads, or an **`SD_*` message** fired where the moment happens (the
  shared file fires, the feature listens). A registry field is the last
  choice.
- Write the contract where the others are: the `Core/Events.lua` header for
  messages, the spec comment above the `Register…` function for fields.
- **Break it once on purpose.** Make a test fail with the hook broken, then
  restore the file byte for byte.
- Add a line to [folder.md](folder.md)'s registry or message tables.

Stop for the user to commit this before the feature itself.

### 5. Scaffold ∥ UI proposal (in parallel)

**5a. Main session: the feature's bones.** [folder.md](folder.md) has the
details.
- `Kind.lua`, with the header listing the folder's files and what stays
  core. It registers the row kind, the list, the moment and the art.
- `Data.lua`, if there are static tables.
- `Capture.lua`, with **its TOC line decided**: [folder.md](folder.md),
  "Where capture loads". The reasoning goes in the TOC comment and the
  file's header.
- `Dev.lua`, the feature's part of `/sd testdata`, timed off stops.
- `tests/<name>.lua`, the capture driven by `mock.fire` and
  `mock.RunTimers`, with invented names. Add it to `tests/run.lua`.
- TOC lines in both blocks.
- Words not yet written are placeholders marked `-- COPY:`, so phase 7
  finds them.

The suite must be green, `tests/kinds.lua` included. A moment registered
with no mark yet fails kinds.lua. If so, leave the moment's registration
for phase 8 and say so.

**5b. Subagent: the UI proposal.** Use the "UI proposal" brief below. It
writes `.claude/ui-proposal/<name>.md` and `<name>-mockup.html`, the mockup
copied from the plates skill's template: three variants, each at the sizes
decided in scope, nothing more; the .md short (decisions and open
questions). It writes no Lua.

### 6. Sign-off

Relay the proposal and the mockup's path. The user picks one of the three
variants and its sizes and comments in the mockup itself, then pastes its **"Copy
handover"** text back. Pass that text on unchanged to **the same
subagent** (SendMessage to its id, so it keeps its context). Each
round's handover and decisions go into the dossier, then the user's
sign-off.

### 7. Copy

Subagent, "Copy" brief. It writes every string a player reads:
- the row's line and the picker's reason;
- tooltips;
- caption words;
- the prose paragraph;
- the margin note's words.

They go into `Kind.lua` and `Text.lua`, replacing each `-- COPY:`
placeholder. Locked words go in exactly as given. Copy comes before the UI
build, so the build lays out real words.

### 8. UI build

Subagent, "UI build" brief. It writes `Text.lua`'s registrations,
`Mark.lua`, `Slip.lua` / `Card.lua` and `tests/<name>_ui.lua`. It checks the
geometry with the plates' render (`.claude/skills/plates/tools/plates.sh`)
and reports which pages it looked at.

### 9. Verification (main session, independently of the subagents)

- `luajit tests/run.lua` is green. `tests/kinds.lua` passes, which means:
  - every kind reads;
  - every moment is ranked, gathered and marked;
  - every margin note and caption has its own place;
  - every card keeps the strip's contract;
  - every file in the folder is in the TOC, and Dev.lua isn't packaged;
  - no file in Core, UI, Capture or Dev names `ns.<Name>`.
- `grep -rn "<Name>\|<name>" Core UI Capture Dev` returns nothing.
  kinds.lua only catches `ns.<Name>`; this grep also catches the kind
  names, list names and words in comments or strings.
- `git status` and `git diff --stat` show changes only in the places listed
  at the top. Anything else is either a phase-4b hook or a mistake.
- Every new hook has its break-it test (4b).
- The capture placement's reasoning is written in the TOC comment and the
  header of `Capture.lua`. If capture shares a client event with core or
  another feature, there is a test that fails when the order is wrong.
- `Dev.lua`: `/sd testdata` shows the feature, and `/sd testdata remove`
  clears it (the `"remove"` point, for anything off the route and off
  Tester).
- PRV-3: a feature that keeps a GUID on the route registers `forget` (and
  `prune` if the GUID should go once the buffer forgets them).
- Read the subagents' diffs yourself. Don't take their reports on trust.

### 10. Wrap-up and in-client rounds

- `CHANGELOG.md`: an entry under `## [Unreleased]` → `### Shiny new Things`,
  per `.claude/rules/changelog.md`.
- A memory note: the decisions, what is waiting on the client, and a
  pointer to the dossier.
- **The in-client checklist**, numbered. It opens with a **full client
  restart**, because new files in the TOC are not picked up by `/reload`.
  Then the commands (`/sd testdata`, `/sd`, the page and level to open),
  then exactly which screenshots to take. Data is read from SavedVariables,
  not screenshots.
- **Each round:** fix what came back, leave dated notes in the code where a
  value changed because of a screenshot, and log the round in the dossier.
  Remove the probe module once it has done its job.

### 11. Fold back (every run, before calling it done)

Compare what happened with what this skill said:
- a surface or signal kind phase 3 didn't list;
- a hook, a pattern or a capture-order surprise;
- a brief that left a subagent guessing;
- a check that would have caught something earlier;
- a step that turned out useless.

Write the proposed edits as a short list in the dossier's "For the skill"
section. Show them to the user, and apply the approved ones to `SKILL.md` /
`folder.md` **in place**: change the instruction, don't add a diary of runs.
If the feature became the best example of a pattern, update the example in
[folder.md](folder.md).

## Subagent briefs

Each brief points the subagent at the dossier. The dossier is its context.
It doesn't get the conversation. All briefs share these rules:
- never commit;
- don't touch `CHANGELOG.md`;
- re-read before editing;
- invented names only;
- report the files changed, the tests run, and anything left open.

### UI proposal (phase 5b)

> Load the skills `plates` and `frontend-design`. Read `AGENTS.md`,
> `.impeccable.md`, `.claude/rules/ui.md` and the dossier
> `.claude/features/<name>.md` (scope, probe, record).
>
> Propose how <Name> shows on: <the sheet's surfaces>. The plate label
> comes in <S/M/L/XL, as decided> and says <wording>. Locked words,
> verbatim: <…>.
>
> Start the mockup from the template: copy
> `.claude/skills/plates/tools/proposal-template.html` to
> `.claude/ui-proposal/<name>-mockup.html` and write only its DESIGN
> block: three variants (A, B, C), each at the sizes decided in scope,
> nothing more (no extra boards, layout code or render scripts). Keep the
> HTML free of prose; the .md is short: decisions and open questions, not
> essays. Each round, the user sends back the mockup's handover text
> (picks and comments): act on it, and say in the .md what changed.
>
> The model to learn from is the hunt cards: `Features/Hunts/`
> (`HuntCard.lua`, `LuckyCard.lua`, `Mark.lua`, the lucky print's pass)
> and `.claude/ui-proposal/hunt-card-proposal.md` /
> `lucky-card-proposal.md`. They show the diary's rule (printed type is
> what the tables said, the hand is what happened, graphite is what the
> diary worked out), a card on the PaperStrip contract, a mark, and a
> pass.
>
> Set the new mark against the existing ones (render them). Place the note
> in the margin's order, and say what is dropped on a crowded plate.
>
> Write `.claude/ui-proposal/<name>.md` and `<name>-mockup.html`. Write no
> Lua. If the template lacks something every proposal would need, say so;
> don't fork it silently.

### Copy (phase 7)

> Load the skill `copywriter`. Read the dossier, `Features/<Name>/Kind.lua`
> and `Text.lua`. Replace every `-- COPY:` placeholder with player-facing
> words in the house voice, matching the register of the strings round the
> same surface in other features. Words marked locked in the dossier go in
> exactly as given. Edit only those strings and their comments. List every
> string you wrote.

### UI build (phase 8)

> Load the skills `plates` and `frontend-design`. Read `.claude/rules/ui.md`,
> the dossier (the signed proposal and its decisions) and
> `.claude/skills/new-feature/folder.md`.
>
> Build in `Features/<Name>/` only: `Text.lua`'s registrations, `Mark.lua`,
> `Slip.lua` / `Card.lua`, and `tests/<name>_ui.lua` (add it to
> `tests/run.lua`). Copy the structure of `Features/Hunts/` (cards on
> `ns.UI.PaperStrip`; never override its `Layout`, `Smaller` or
> `Nearest`; tooltips through `Style.TipList`).
>
> Don't edit `Core/`, `UI/`, `Capture/`, `Kind.lua`'s data or
> `Capture.lua`. If you need a hook, stop and say what and why.
>
> Run `luajit tests/run.lua` and `.claude/skills/plates/tools/plates.sh`,
> and look at the render of the testdata levels where the feature shows.
> Report what you saw, and the in-client screenshots you'd want.
