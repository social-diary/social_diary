# Contributing to Social Diary

Thank you for helping.

## Setting up

The addon folder sits inside the game install, where copy and sync tools
possibly mark files executable. Git would then list each file as changed
with no lines added or removed which is annoying. Here's the fix for it. Tell git to ignore the executable bit in your
clone:

```sh
git config core.fileMode false
```

## Running the tests

The suite runs offline, against a mock of the WoW API (`tests/wowmock.lua`).
You need [LuaJIT](https://luajit.org).

```sh
luajit tests/run.lua            # everything
luajit tests/run.lua -v         # verbose
luajit tests/run.lua people.lua # only the files you name
```

A new test file only runs once it is listed in `FILES` in `tests/run.lua`.
CI runs the suite on every push to `main` and on every pull request
(`.github/workflows/tests.yml`).

The mock does not do layout. For anything a player sees, try it in the game
client as well.

## Finding your way round

[AGENTS.md](AGENTS.md) is the map of the code: what lives in `Core/`,
`Capture/`, `UI/`, `Features/`, `Dev/` and `tests/`, and the load order in
`social_diary.toc`. It also holds the rules for AI-assisted work, so it is
worth reading whether you use an assistant or not.

- `.claude/skills/` holds the copywriter, plates, release and new-feature
  skills. To add a detection, follow `.claude/skills/new-feature/`: the
  pipeline in `SKILL.md`, the folder and its registries in `folder.md`.
- `.claude/rules/` holds the project rules, such as how to write the changelog
  and whether a new setting is per character or per account.
- `.impeccable.md` describes the look and feel of the book.
- `Dev/` holds in-game debug tools (`/sd art`, `/sd journey`, `/sd testdata`).
  They load from the repository but are fenced out of releases.

### Requirement IDs in comments

Comments often cite requirement IDs (such as `JRN-28` or `DIA-9`) and design
notes. They point to the initial planning documents, which are not
in the repository. You can ignore them.

## Text a player reads

Every string a player reads follows the house voice in
`.claude/skills/copywriter/SKILL.md`. In short:

- British English, sentence case, whole sentences.
- The diary speaks to _you_ and calls itself _the diary_, never _I_.
- Quiet: no exclamation marks, no warnings in capitals.
- One word per thing: strangers are _pencilled in_ and _rubbed out_, people
  you add are _inked in_, your movement is your _road_.
- No internal words on screen: _data_, _session_, _record_, _SavedVariables_.

The suite asserts some copy. If you change a string, search `tests/` for it
and update the test.

## UI conventions

The journal is an open book on parchment, not a window. In brief:

- The Addon prioritises drawing actual memories over statistics and quantified data.
- Build from what the client draws: textures, gradients, masks and font
  strings. No Blizzard frame templates, to avoid taint.
- Every art file has a list of candidates and a flat-colour fallback.
- Light theme: dark ink on warm parchment. Shared colours, fonts and sizes
  live in `UI/Style/`; use them rather than new values.
- Lapis blue is for ornament only, since blue on the page also reads Alliance.
- New settings are per character unless there is a reason otherwise
  (`.claude/rules/settings.md`).
- Work on _Your Diary_'s map plates follows `.claude/skills/plates/`.
- Where UI code goes, how pages, settings sections, marks and cards plug
  in, and how to prove a refactor changed nothing: `.claude/rules/ui.md`.

## Changelog

Anything a player would notice gets one line in `CHANGELOG.md`, under
`## [Unreleased]`. Follow `.claude/rules/changelog.md`: about ten words, what
changed and not how, under _Shiny new Things_, _Changes_ or _Fixes_.

## Images

`*.png` is in `.gitignore` on purpose, so the history stays small. Attach
screenshots to your pull request or issue.

## Pull request checklist

- [ ] `luajit tests/run.lua` passes, new code has tests, and new test files
      are in `FILES` in `tests/run.lua`.
- [ ] Tried in the game client. Say what you did, and attach a screenshot for
      UI changes.
- [ ] Player-facing text follows the copywriter skill.
- [ ] `CHANGELOG.md` has a line under `## [Unreleased]` for anything a player
      would notice.
- [ ] No images committed.

## Releases

Releases are made by the maintainer. The version in `## Version` in
`social_diary.toc` and the changelog are raised together, then a tag
`v<version>` is pushed. `.github/workflows/release.yml` runs the tests,
packages the addon with the BigWigs packager and publishes a GitHub release.
`.claude/skills/release-version/` describes the steps.

## Licence

By contributing, you agree that your code is released under the
[GNU General Public License v3.0 or later](LICENSE).
