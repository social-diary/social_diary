---
name: controller-support
description: Make a Social Diary window, page, sheet, card or control work with a gamepad (WoW Forever's Gamepad UI) the way the rest of the addon does — scopes, the focus model, the chosen look, the button map, input detection, taint and combat rules, tests. Load (in the main session or a UI subagent, next to frontend-design) whenever adding or changing UI a player can reach, so it stays usable with the pad without new pad code where discovery already covers it.
argument-hint: "[the UI to make controller-ready]"
---

# Controller support in Social Diary

With **WoW Forever's Gamepad UI** on and the pad the input used last, every
part of the diary works from the controller. With the mouse, or with the
Gamepad UI off, nothing of this runs and the diary looks exactly as it
does without it. This skill is how to keep it that way when the UI
changes. Read it before you build or change anything a player can reach.

Background, if you need more than this file:
- `.claude/controller-plan.md`: the decisions, as built per step, the
  in-client findings.
- `.claude/controller_api_reference.md`: the client's gamepad API. But its
  §9 is **overridden**, see the rules below.
- `.claude/ui-proposal/controller/headings/proposal.md`: the look.

## The rules that are not up for debate

1. **Never drive Blizzard's Gamepad UI.**
   - Never call `GamepadMode.FrameControlsManager` (`FrameShown`,
     `Focus*`), `ShowUIPanel`, `AddManagedFrame` or SmartNavigation.
   - Never set a property on a Blizzard frame (`SetAlpha`, `Hide`,
     `SetPoint`, marker fields).

   Any of these taints the game: closing a pad-focused window then fails
   with `SetPreferredGamepadInteractTarget` forbidden. Blizzard's frame
   manager may only be **read**.

2. **Only path B.** Our own unprotected frames take pad buttons
   (`EnableGamePadButton`), so it works in combat.
   - No override bindings for navigation.
   - Never `SetBinding` for the player, except the key setter
     (`UI/Kit/Keys.lua`), where they choose the key. That's their opt-in,
     and it is refused in combat. The setter is **keyboard-only**.
   - **Never bind a pad button** (`PAD1`, `SHIFT-PAD3`): under the Gamepad
     UI the binding context `GamepadModeInGameCore` takes nearly every pad
     press first, so a normal binding on a pad button never fires
     (`.claude/ui-proposal/controller/bindings-and-radial.md`). A
     controller's player opens the diary or Remember this with the
     **macro books** (`UI/Settings/Macro.lua`), placed in a slot of their
     controller's action bar. With the pad in hand, Keybinds & Shortcuts
     shows the books first and hides the key setters; the empty People
     page shows Remember this's book in place of its key. A book is a
     control of its own kind (`.diaryMacro`): A picks it up as a click
     does. Words for it say what to do, never what doesn't work.

3. **Additive.** The pad never takes a press it doesn't use.
   - Unclaimed buttons go on to the game (movement, camera, action bars),
     with the book open, in combat too.
   - The Escape stand-in (`GamePadEmulateEsc`) is never taken. Windows
     close on it through `UISpecialFrames`, as with the keyboard.

4. **A window takes the pad only if the player opened it.**
   - Call `Pad.Opened(frame)` on the player's path into it.
   - Its scope's `active` asks `Pad.Owns(frame)`.
   - A toast or anything that appears by itself never takes the pad. The
     reunion toast and the login parcel deliberately don't.

5. **Never click an item for the pad.** No chat links, no try-on: items
   show their tooltip only. LB is the pad's Ctrl and LT its Shift, so a
   click made while one is held would be a modified click.

6. **Blizzard's own pieces step aside.**
   - A StaticPopup we show (`UI/Kit/Confirm.lua`): the dialog's `OnShow` /
     `OnHide` call `Pad.Aside(self, true/nil)`.
   - A Blizzard menu opened by A: call `Pad.MenuAside()` right after.

   Forever's Gamepad UI drives those itself.

7. **Saved data:** pad support saves nothing. If it ever must, follow
   AGENTS.md's migration rule.

## The parts (`UI/Pad/`, table `ns.UI.Pad`)

| File | What you use from it |
|---|---|
| `Input.lua` | `Pad.Input.Active()` (pad in hand), `Pad.Input.OnChange(fn)`. Detection is settled (see "Input detection" below): don't add your own. |
| `Glyphs.lua` | `Pad.Glyphs.Text(key, size)` (inline icon), `.Atlas(key)`, `.Name(key)`, `.Style()`. Keys are binding keys (`PAD1`, `PADDUP`), never labels. |
| `Focus.lua` | The focus model. Groups (`list` / `spatial`, `wrap`, jumps `left/right/up/down`, `reveal`), items, `Remember`, `EnterGroup`, `Focus(key)`, `Within`. |
| `Look.lua` | The look. You never draw focus yourself: you describe the item (fields below) and `Look` does it. |
| `Controls.lua` | `Pad.Controls.Find(root, skip)` and `.Add(f, group, found, opts)`: a form's or sheet's controls found rather than listed. |
| `Catcher.lua` | `Pad.RegisterScope`, `Pad.Refresh`, `Pad.Top`, `Pad.Opened` / `Owns`, `Pad.Aside`, `Pad.MenuAside`, `Pad.RegisterJoin` / `JoinAside` / `LandAside`. |

`Dev/Pad.lua`: `/sd pad` prints every signal and the last reason the pad
was picked up or put down. `/sd pad on|off|auto` forces it for testing.

## Adding pad support: the order to think in

### 1. Is it found already? (most new UI needs no pad code)

| You add | Found by | You do |
|---|---|---|
| A **margin card / strip** on Your Diary or a person's page | every strip's `:Focus()` (`UI/Paper/Strip.lua`) | nothing. Only if its heading isn't the strip's `name`, or the card is more than its slip, add the optional `focus(strip, f)` card hook (documented above `ns.UI.PaperStrip`). Never touch the strip's private fields. |
| A **mark on a plate** | the plate's mark buttons keep `padAt`; prints on `plate.overButtons` | nothing |
| A **setting** built with `UI/Settings/Kit.lua` or a Style widget | the settings scope walks the pane (`UI/Settings/Pad.lua`) | nothing (use the kit) |
| A **field on a form or sheet** (entry, note, link card, custom card) | `Pad.Controls` / the sheet's collector | nothing, if it's a standard widget: `Style.Checkbox` (tick+label), `Style.Link` (line+label), EditBox, `Style.TagButton`, `Style.Portrait`, a key setter, a macro book (`BookButton`) |
| A **row in an existing list** (People, Nearby, the quiet list, the left page) | that page's scope walks the virtual list | nothing |

Discovery reads **lowercase fields** the widgets set (`tick`, `label`,
`line`, `box`, `slider`, `padAt`, `group`). Build with the kit and Style
widgets and keep those fields. Probing a frame for an uppercase method
errors in the test mock, so classify by fields, and use `rawget` for a
method.

### 2. A new widget kind or a new page/window: register a scope

```lua
local Pad = ns.UI.Pad
Pad.RegisterScope("mything", {
    layer  = 20,                    -- see the layer table
    parent = "journal",             -- a page in the book; nil for a window of its own
    host   = function() return myFrame end,
    active = function() return myFrame:IsShown() end,  -- a window: and Pad.Owns(myFrame)
    build  = function(f, scope)     -- called on every Pad.Refresh; keys keep the place
        f:Group("list", { mode = "list", right = "detail" })
        f:Group("detail", { mode = "spatial", left = "list" })
        for _, row in ipairs(rows) do
            f:Add("list", { key = "row:" .. row.id, frame = row })   -- A clicks it
        end
    end,
    keys   = { PAD3 = function(scope) ... end },  -- only what this surface needs
    back   = function(scope) ... return true end, -- B, one level; false lets the parent take it
    legend = function(scope) return { { "PAD1", "Open", main = true }, { "PAD2", "Back to the list" } } end,
})
```

- **Call `Pad.Refresh()`** after anything that changes what's shown: a
  page turned, a section shown, rows rebuilt, a sheet opened or closed.
  The book's `ShowView` already does it for page turns.
- **Stable keys** (`"row:" .. guid`, `"nav:" .. sectionKey`). The model
  remembers where the pad was by key, so a rebuilt page keeps its place.
- **Items:** a frame (A clicks it, OnEnter/OnLeave give the tooltip), or a
  table:
  - `key`, `frame`
  - `press()`, `step(dir)` (left/right on a slider: return true)
  - `enter()` / `leave()`, `available()`
  - `center()` for a spot with no frame
  - the look's fields (below)
- **A sheet over a page:** a higher layer, `parent = nil` if the page's
  keys must stop (the note sheet), and B returns the pad where it was.
- **Something laid on a page that isn't the page's** (a hint slip): use
  `Pad.RegisterJoin`. It joins at the right edge and never moves the pad
  by itself.
- **Sticks:** only if the surface pans or aims, as the full zone page
  does. Add `stick = function(scope, stick, x, y, len, elapsed)`. Only a
  top scope with `stick` gets sticks turned on, so the camera works
  everywhere else. The right stick may be named "Right" or "Camera":
  accept both.
- **Prompt slip somewhere else:** `slip = function(scope, w) ... end`
  (the Dungeon View lays it on the table).

**Layers in use:**

| Layer | Scope |
|---|---|
| 10 | `journal` (LB/RB ribbons, B closes, title holds the box) |
| 20 | pages: `yourdiary`, `people`, `nearby`, `settings` |
| 25 | `writing` |
| 28 | `tour` |
| 30 | sheets over a page: `cards`, `note` (`links` +5) |
| 40 | `spread` (Dungeon View) |
| 50+ | windows outside the book: `entry`, `picker`, `quicknote`, `parcel`, `toastplace` |

### 3. The look: describe, don't draw

The chosen design (user, 7 Nov 2026), all in `Look.lua`:
- **Words:** the focused item's own words turn red (`Style.RUBRIC`) and
  bold (a same-red shadow, never a font swap), and the diary's pen draws
  a box round them. Their group's subheading turns red, its rule fading
  red.
- **Paper (plates, strips, cards):** a red outline, a slight red drop
  shadow, and the heading red.
- **Marks and faces:** a pen ring.
- **Prompts:** on a paper slip under the cover's foot. LB/RB sit beside
  the ribbons.

Item fields `Look` reads: `words`, `subhead`, `room`, `adjust`
(sliders), `clip` (scroll child), `level` (over a sheet), `ring`,
`outline` + `heading`, `plain` (keep a coloured chip's own colours).
Legend entries: `{ key | {keyA, keyB}, text, main = true, beside = {l, r} }`.

Everything Look changes is saved and given back on Unmark, on Hide and
when the mouse takes over. It only ever recolours **our** widgets' words,
never a Blizzard frame. Don't add a cursor, a glow or a second
highlight. If something truly can't take the look (an item-quality name
keeps its colour; escape-coded names keep theirs), say so, as earlier
steps did.

### 4. The button map: don't invent a new grammar

| Button | Means everywhere |
|---|---|
| D-pad | move focus (held repeats: 0.35 s, then every 0.2 s). Left/right steps a slider or number. On Your Diary's left page it changes level. |
| A | do what a click does: open, tick, follow, enter (a plate's marks, a form's line). An EditBox gets the keyboard cursor; A again, B or moving off lets go. |
| B | back one level, on its **release**: stop typing, then leave the sheet or page part, then close the book. Returns the pad to where it came from. |
| X | the larger view: the whole map from a plate, zoom out on it |
| Y | the right-click: add or edit a custom card |
| LB / RB | turn the book's ribbons. On the Dungeon View: change floor. |
| LT / RT | not used (LT is the pad's Shift by default) |
| Right stick | pan, only where something pans |

Landing on a list row doesn't open it; A does. The exception is the
Settings sections, which show on landing. After a ribbon turn the page's
title holds the box until the first D-pad press (`journal.held()`).

### 5. Words

Every prompt label goes through the **copywriter** (`/copywriter`, in a
subagent). Until then, mark it `-- copy TBD (copywriter)`. The settled
grammar:
- 1–4 words, imperative.
- **"See"** when something is shown, **"Go to"** when the pad moves,
  **"Open"** for a new page or view, **"Put the … away"** to close,
  **"Back to the …"** to go back.
- Reuse the settled labels: Choose, Write, Done writing, Stop writing,
  Tick / Untick, Less · more, Turn the page, Close the book.

## Input detection (settled, found in the client)

The pad is **picked up** by:
- a pad button (looked at every frame);
- a stick pushed well past where it lay at the last click;
- the game saying so (`GAME_PAD_ACTIVE_CHANGED`, `IsUsingGamepad` turning
  true).

It is **put down** only by:
- a mouse click the pad didn't make;
- the game saying so.

It is never put down by time or the cursor's position (the Gamepad UI
moves the cursor itself), nor by `IsUsingGamepad` turning false. Nothing
picks the pad up while a mouse button is held, or within 0.5 s of a
click. Reading axes or triggers against fixed thresholds broke clicks
and the camera; don't bring it back. The watcher sleeps unless a window
of ours is open (`Input.Watch`, set by `Pad.Refresh`).

## Tests (required)

Add `tests/pad_<area>.lua` to `FILES` in `tests/run.lua`, next to the
other `pad_*` files, and copy their setup:

```lua
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
local catcher = Pad.Catcher(host)
local function Press(key) mock.PadPress(catcher, key, true); mock.PadPress(catcher, key, false) end
```

- Mock widgets start hidden, unlike the client. Show what the test needs
  (`ShowAll`, as in `tests/pad_settings.lua`).
- Also available: `mock.PadStick(frame, stick, x, y)`, `mock.keysDown`,
  `mock.pad.sticks`, `mock.pad.style`, `mock.inCombat`.
- Check, at least:
  - every new thing is reachable;
  - A does what the click does;
  - B returns one level, to where the pad was;
  - unclaimed buttons propagate;
  - items offer no click;
  - a window not opened by the player doesn't take the pad;
  - the mouse taking over gives every colour back;
  - with the Gamepad UI off, nothing is enabled.
- Never define a client global for the whole mock that other code
  feature-tests for (e.g. `IsMouseButtonDown`, which the plate drag reads):
  set it inside your test and clear it after.

## Checks before you call it done

- `luajit tests/run.lua` is green (incl. `kinds`, `ui_layout`; new
  `ns.UI` names go in `tests/ui_layout.lua`, new TOC lines change
  `dungeons`' count).
- Golden: with the pad off nothing drawn changes. Use
  `tests/golden/golden.sh` and `compare.sh`; `uidump.txt` is known broken
  on the clean tree, so ignore its address line.
- `luajit -bl <file> | grep -oE 'GSET.*"[A-Za-z_]+"'` is empty. A
  handler defined above the `local` it uses writes a global: this
  happened.
- `/sd pad` explains it in the client. Add the surface's in-client checks
  to `.claude/controller-plan.md`: placement of the look on turned paper,
  red surviving a widget's own `SetFontObject` on hover, B round trips,
  the mouse handing over.
