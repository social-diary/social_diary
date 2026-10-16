---
name: release-version
description: Cut a Social Diary release — bump the TOC version, close the changelog's Unreleased section, commit, tag, and (after confirmation) push the tag that makes GitHub Actions package and publish the release.
argument-hint: "[patch|minor|major|X.Y.Z]"
disable-model-invocation: true
---

# Release a version

A release is a `vX.Y.Z` tag that matches `## Version:` in `social_diary.toc`.
Pushing the tag runs `.github/workflows/release.yml`: it checks the tag
against the TOC, runs the tests, and has the BigWigs packager publish a
GitHub release. The zip leaves out what `.pkgmeta` ignores (`.claude`, `Dev`,
`tests`, …), and the TOC's `#@do-not-package@` block is stripped. The whole
`CHANGELOG.md` becomes the release notes.

`ns.version` (shown on the Settings page) reads the TOC at runtime. Nothing
else carries the version number.

## 1. Pick the version

Read the current `## Version:` from the TOC and the latest tag (`git tag`).

- Argument `X.Y.Z`: use it.
- Argument `patch` / `minor` / `major`: bump that part.
- No argument: **minor** if `## [Unreleased]` has a `### Shiny new Things`
  section, otherwise **patch**. Never pick **major** yourself.

Stop if the tag already exists.

## 2. Preflight (stop and report on any failure)

- On `main`, up to date with `origin/main` (`git fetch`, then compare).
- `git status`: if there are uncommitted changes, list them and ask whether
  they belong in this release. Don't commit them without a yes.
- Tests pass: `/opt/homebrew/bin/luajit tests/run.lua`. Show the failure
  output if they don't. Don't release on a red suite.
- `## [Unreleased]` in `CHANGELOG.md` has at least one entry. If it is
  empty, there is nothing to release. Say so and stop.
- The changelog entries follow `.claude/rules/changelog.md`. Tighten any
  that don't, and show the user what you changed.
- The `Dev/` lines in the TOC are still inside
  `#@do-not-package@` … `#@end-do-not-package@`, and no new `Dev/` or
  `tests/` file sits outside that block.
- If `Core/DB.lua` changed since the last tag (`git diff vPREV -- Core/DB.lua`):
  every raised `SCHEMA_VERSION` / `ACCOUNT_SCHEMA` / `CHARACTER_SCHEMA` has a
  matching `STEPS.*` entry (see `.claude/rules/settings.md`). A release that
  renames a key without a step loses players' data.
- Dungeon Crawler Forever: compare `Vendor/DungeonCrawlerForever/VERSION`
  with the release in `Interface/AddOns/DungeonCrawlerForever/*.toc` (or its
  GitHub). If DCF is newer, tell the user and offer the sync: copy its
  `Data/` files that `Vendor/` holds, re-apply the one changed line (and
  ArtCustom's tile paths, see each file's header), copy new `Art/*.blp`,
  raise `VERSION`, run the tests. Never sync without a yes.

Leave `## Interface:` alone unless the user asks. WoW Forever's interface
number moves with the client, not with the addon.

## 3. Make the release commit

1. TOC: set `## Version: X.Y.Z`.
2. CHANGELOG: rename `## [Unreleased]` to `## [X.Y.Z]`, then add a fresh,
   empty `## [Unreleased]` above it. Headings carry no date.
3. Run the tests again.
4. Commit only those two files (plus anything the user approved in step 2)
   with the message `vX.Y.Z`.
5. `git tag vX.Y.Z`.

## 4. Publish (confirm first)

Pushing publishes a public GitHub release, so show a summary and ask before
pushing:

- version and tag, previous tag
- the changelog section being released
- the commits since the previous tag (`git log --oneline vPREV..HEAD`)

On a yes:

```bash
git push origin main
git push origin vX.Y.Z
gh run watch "$(gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')"
gh release view vX.Y.Z
```

Report the release URL. If the workflow fails, show the failing step's log
(`gh run view --log-failed`). Don't delete or move the tag without asking.

On a no, leave the commit and tag local and tell the user how to push later.
