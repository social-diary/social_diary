---
paths:
  - "UI/Settings/**/*.lua"
  - "Core/DB.lua"
  - "UI/Windows/Intro/*.lua"
  - "UI/Journal/Front.lua"
  - "UI/Journal/Frontispiece.lua"
  - "UI/Journal/IntroLabel.lua"
---

# Adding or moving a setting: per character or per account?

Social Diary keeps two SavedVariables files (`Core/DB.lua`):

| File | Holds |
|---|---|
| `SocialDiaryDB` (account) | the account settings, the user's own characters (`ns.OwnCharacters()`), the shared diary (`shared`) once there is one |
| `SocialDiaryCharDB` (per character) | that character's settings, and its own diary (`data`) |

By default each character has **its own diary**. Sharing one diary between
all characters is the account setting `shareDiary`, read once at login.

**Settings are per character unless there is a reason otherwise.** Every
new setting is per character by default. That keeps things simple and lets
an alt be set up differently.

## How to decide

Make a setting **per account** only if one of these is true:

1. **It is about the person, not the character.** For example, "has read
   what the addon keeps" (`frontRead`, PRV-4), "has been through the
   introduction" (`introDone`), or developer `debug`.
2. **It decides which diary or file is loaded** (`shareDiary`). A setting
   stored inside the diary it chooses cannot choose it.
3. **A different value on an alt would be wrong or confusing**, not just
   different. "I like toasts on my main but not my alt" is a reason to keep
   it **per character**.

Everything else is **per character**: toasts, tooltips, retention days,
sightings and cities, chat storage, paper and map looks, sort orders,
the login parcel's torn or wrapped look (`parcelOpened`), and window
positions.

If you are unsure, choose per character and say so in your report.

## How to do it

- **Per character:** add the key and its default to `CHARACTER_SETTINGS` in
  `Core/DB.lua`.
- **Per account:** add the key and its default to `ACCOUNT_SETTINGS` in
  `Core/DB.lua`.
- Read and write it the same way in both cases: `ns.db.settings.key`,
  `ns.Setting(key)` / `ns.SetSetting(key, value)`. `ns.db.settings` sends
  each key to the right file. Never write to `SocialDiaryDB.settings` or
  `SocialDiaryCharDB.settings` directly.
- **Add every default to one of those two tables.** A setting without a
  default works, but it is always per character. The two tables are the
  only list of which file a key lives in.
- An account setting shown on the Settings page says it  every
  character. Per-character settings need no label: that is the default.
- `ns.db.settings` is a view and cannot be iterated (`pairs` returns
  nothing). Iterate a nested table instead (`ns.db.settings.cities`).

## Data, not settings

The same question applies to stored records:

- **Diary data** (anything about other players) lives in the diary in use
  (`ns.db.*`), which is this character's own diary or the shared one. **A
  new record of something the user's character did or saw notes which
  character** (`me = ns.ownGUID`, or `addedBy` for a diary entry), so a
  shared diary can still tell characters apart. Records keyed by the
  character's GUID (`journey[guid]`, `meta.begun[guid]`) already do.
- **The list of the user's own characters** is account-wide
  (`ns.OwnCharacters()`), so an alt is never a stranger in another
  character's diary. Do not use `ns.db.meta.characters`; it no longer
  exists.
- "Delete everything" (`ns.WipeData`) clears the diary in use only. It
  keeps settings and the list of own characters.

## Renaming or moving a setting or a record

Every table that gets saved has its own version number, `schema`. Each
diary has one (`SCHEMA_VERSION`). So does the account file
(`ACCOUNT_SCHEMA`), and so does the per-character file
(`CHARACTER_SCHEMA`). A rename or a move needs two changes in
`Core/DB.lua`:

- raise the number for the table that changes;
- add a step to `STEPS.diary`, `STEPS.account` or `STEPS.character`, under
  the new number.

A step runs before defaults are filled in. It sees the table as it was
saved: the old key is still there, and the new key does not exist yet. A
setting moving between account and character means a step in both files.
A diary that is not loaded keeps its old number until the next time it is
loaded.
