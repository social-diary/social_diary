---
paths:
  - "CHANGELOG.md"
---

# Writing CHANGELOG.md entries

The changelog is for players skimming a release. Say what changed in a
few words. The addon shows the details, so the changelog doesn't need to.

## Shape

Every released version opens with a **summary paragraph** directly under
its `## [X.Y.Z]` heading, before the first subheading: one or two
sentences on what the update is about as a whole, on one line (never
wrapped). It is shown in-game atop the release on the _Changelog_ page in
Settings, and as the release notes on CurseForge and GitHub. Write it when cutting the release at the latest;
`[Unreleased]` may carry one in progress. Its voice and openers are in the
copywriter skill (`.claude/skills/copywriter/SKILL.md`, §5 Release
summaries).

Then group entries under these subheadings inside each version
(`## [Unreleased]`, `## [1.2.0]`, …), in this order. Leave out any that
are empty.

```markdown
### Shiny new Things

### Changes

### Fixes
```

- **Shiny new Things**: new features, pages, cards, settings, shortcuts.
- **Changes**: things that already existed and now work or look different.
- **Fixes**: things that were wrong and are now right.

## Each entry

- **One line, about 10 words.** Never wrap it onto a second line.
- **Say what, not how.** Leave out mechanics, edge cases, examples in
  parentheses, quoted UI text, thresholds, and lists of what moved where.
- **Put feature names in italics**: _Your Diary_, _People_, _Settings_,
  _Recently nearby_, _Plates_, _Toasts_.
- **Write for players**: present tense, plain words. Never mention
  internals (functions, SavedVariables, events, tests).
- **One entry per feature.** A closely related extra can go in one
  indented sub-bullet, two at most.
- **Merge small polish** in one area into a single entry ("_Your Diary_
  prose reads more naturally"); don't list each tweak.
- **Fixes describe the corrected behaviour**, not the cause of the bug.
- If an entry needs a comma clause to explain itself, it is too long. Cut
  it down to the subject and the verb.
- **Credit a player** who reported or helped with an entry by a trailing
  `(thanks Name)` at the end of the bullet line. A name only: no `@`
  (GitHub would notify someone), no realm, no link. It doesn't count
  towards the ten words. Only real people who agreed to be named; examples
  use invented names.

## Example

Too verbose:

```markdown
- Your Diary's plates show what killed you there: a taped card in the
  margin with the creature cut in ink as a silhouette, its name and
  "killed you twice" (a rare or elite outranks the most kills); death
  crosses name their killers under the mouse.
- Settings has subpages: Interface's Toasts and Keybinds & Shortcuts hang
  under it on the left page, each with its own page. The toast switches,
  the cooldown, Move the toast and the Nearby Toast Blacklist moved from
  Interface to Toasts; …
- A level's entry in Your Diary tells where the time went in the order it
  happened (a fight, then a rest, then the long stay) instead of longest
  first, which read backwards.
```

Right:

```markdown
## [1.3.0]

This Update brings the creatures that killed you into _Your Diary_ and gives _Settings_ subpages.

### Shiny new Things

- _Your Diary_ now showcases NPCs that killed you
- _Settings_ pages have subpages now
  - Also added a draggable macro for opening the main window

### Fixes

- Map _Plates_ in _Your Diary_ now show only their own level's content (thanks Brannoc Ashby)
```

## Scope

- Follow this rule for new entries and for any you edit.
- Leave released sections (`## [1.1.0]` and earlier) as they are unless
  asked to change them.
