# Changelog

## [Unreleased]

## [3.0.2]

This Updates brings small but important UX fixes. Especially the red ink spills that mark your combat zones in _Your Diary_ are now more clearly computed and displayed.

### Changes

- _Dungeon View_ now places deaths, wipes and rolls precisely by mob pack data in Wailing Caverns and Shadowfang Keep

### Changes

- Tooltips in _Your Diary_ Plates now summarize their data instead of showing e.g. 4 times "Fought here for x Minutes"

### Fixes

- Dungeons, battlegrounds and boss fights no longer cause repeated Lua errors
- In _Your Diary_, The red ink spills that mark your combat zones are now more clearly visible. 

## [3.0.1]

A Hotfix for Behaviour in Battlegrounds. Currently, BG data is interpreted badly and potentially clogging up a Diary entry. Until a proper Battleground Feature is implemented, BG Capture will be turned off.

### Fixes

- Battleground Activities are currently skipped, because they result in bad Diary data. 

## [3.0.0]

A big Update: the diary now works with a controller through WoW's Gamepad UI, and a new _Changelog_ under _About_ in _Settings_ shows what's new after each update.

### Shiny new Things

- The Addon now supports Gamepad UI!
  - You can use almost all diary features just with a controller.
  - Some actions still require Keyboard and Mouse, such as:
    - Editing A Dungeon Route
    - Precise Placing of Custom Events
  - As this is a new feature and Blizzard's Gamepad UI will likely change frequently, bug reports are especially welcome.
- An in-game _Changelog_ in _Settings_, under _About_
  - A hint points you to the _Changelog_ after a big update

### Changes

- _Feedback_ and _Credits_ now sit under _About_ in _Settings_

## [2.4.0]

Just small fixes connected to _Hunts_, Nearby _Toasts_ and the _Dungeon View_.

### Fixes

- _Hunts_ in _Your Diary_ are no longer confused by crafting
- Nearby _Toasts_ and last-seen places ignore group members who are far away
- Items in the _Dungeon View_ can be shift-clicked and ctrl-clicked
- A rare killed again in one session is named once on the timeline

## [2.3.0]

This Update adds support for non-latin languages and pencilled-in preview pages for strangers in _Your Diary_.

### Shiny new Things

- Strangers in _Your Diary_ open a pencilled-in preview of their page

### Fixes

- Names and places now show on Russian, Korean and Chinese clients

## [2.2.1]

Just one small fix, so the journal can be closed during a fight.

### Fixes

- The journal's close button now works in combat

## [2.2.0]

This Update introduces hints, a _Feedback_ page and tamed pets for Hunters, and the _Dungeon View_ now knows which pack killed you.

### Shiny new Things

- Occasional hints point out features you may have missed
- A _Feedback_ page in _Settings_ for bug reports and comments
- Hunters: _Your Diary_ remembers the pets you tame and name

### Changes

- A few rarely used chat commands are gone
  - The sightings switch now lives in _Settings_
- _Dungeon View_ places deaths and wipes at the pack that killed you
  - In Ragefire, the Deadmines, the Stockade and both Razorfens so far
- _Dungeon View_ keeps a wipe's marks and its note together in one spot
- _Dungeon View_ marks no longer drift ahead after idle time

### Fixes

- _Dungeon View_ spreads deaths along the way before the first boss falls

## [2.1.0]

This Update lets you add your own events to _Your Diary_ and makes getting started shorter, along with a good round of fixes.

### Shiny new Things

- _Your Diary_ now allows adding custom events by right clicking the Map
- _Dungeon View_ explains its default route the first time it opens
- Paper texture intensity can be set in _Settings_

### Changes

- Onboarding and the login parcel are shorter and easier to follow
- Any key or mouse button can be bound to the addon's shortcuts
- Clicking your current dungeon in _Your Diary_ opens its _Dungeon View_

### Fixes

- Sightings, language support and _Remember this_ behave reliably again
- _Dungeon View_ stays open when you right-click beside the map
- _People_ shows the right time for people you've only seen
- _People_ names back-to-back dungeons together correctly
- _Your Diary_ skips empty levels from before the addon was installed
- Dungeon run pages in _Your Diary_ list everyone and lay out correctly

## [2.0.0]

### Shiny new Things

- **Major feature**: _Dungeon View_ now maps your dungeon activities
  - Routes can be drawn by hand
  - Dungeons also appear in _Your Diary_ as full-sized pages
- A minimap button now opens the journal and _Settings_

### Changes

- Social Diary is now licensed under the GPL v3
- Sessions on a profile now tell proper stories
- _Your Diary_ now lists play sessions instead of levels
- Removed Together Sessions from _Settings_
- _People_ page entries are no longer sticky
  - Editing someone is now a tab beside the page

### Fixes

- Flight paths in _Your Diary_ now use a single Flight Master node
- First items in _Your Diary_ no longer show up as mail items
  - Crafted firsts now say you made them
- A zone's full map in _Your Diary_ now pans without zooming first
- Sessions no longer list the same zone over and over
- _Memory_ page no longer shows file size of all characters combined

## [1.7.0]

### Shiny new Things

- Profiles now remember who sat by a campfire with you
  - Campfires also appear on _Your Diary_'s _Plates_
- Profiles now remember your duels, won or lost
  - Duels also appear on _Your Diary_'s _Plates_

### Fixes

- Duels no longer count as close calls, fighting or hostility
- Shared diaries now name the character in diary entries
- Zone map pen strokes in _Your Diary_ keep their width while zooming
- Right-clicking a target in dungeons no longer throws Lua errors

## [1.6.0]

### Shiny new Things

- Profiles now remember who watched you die or tried to save you
  - They also appear in _Your Diary_

### Changes

- _Recently nearby_ now has a _Subzone_ column
- Places now name the subzone before the zone

### Fixes

- People added from _Recently nearby_ now show where they were last seen
- Dragging a zoomed zone map in _Your Diary_ no longer lags
- Zone maps in _Your Diary_ keep their darkened edges in place while zooming

## [1.5.0]

### Shiny new Things

- Lucky and unlucky quest drops get their own cards on _Your Diary_'s _Plates_

### Changes

- _Plates_ in _Your Diary_ now favour what happened over level-ups
- Close call cards in _Your Diary_ now carry a heading

### Fixes

- Unlucky quest items in _Your Diary_ are now counted correctly
- _Your Diary_ labels now use the full available width

## [1.4.0]

### Shiny new Things

- _Your Diary_ now remembers your first bag, shoulders, green, blue and epic
- _Your Diary_ now showcases NPCs that killed you
  - Death marks name their killer on hover
- _Your Diary_ marks close calls and unlucky quest drops on its _Plates_
- _Your Diary_ celebrates the end of long quest chains
- _Your Diary_ notes when a profession reaches its cap
- _Your Diary_ reads Questie's data when it is installed
  - Quest drops are measured against real drop rates, lucky ones too
  - _Settings_ has an _Integrations_ page showing whether it's found
- _Settings_ pages have subpages now
  - Also added draggable macros for opening the main window and Remember this
- Each character keeps its own diary and settings now
  - _Settings_ can share one diary between all your characters

### Changes

- _Your Diary_ level entries read more naturally
- _People_ maps include sightings from before you added someone
- Repeated level-ups and deaths on a timeline fold into one line
- Margin notes in _Your Diary_ point to their marks with pencil lines
- Margin notes in _Your Diary_ quote what you wrote about someone
- _People_ remembers how you sorted it across reloads and relogs
- First sightings only appear for people you interacted with

### Fixes

- Map _Plates_ in _Your Diary_ now show only their own level's content

## [1.1.0]

### Shiny new Things

- _Your Diary_: your own journey, one entry per level
  - Map _Plates_ and full-page zone maps of where you went
- Your route is recorded and inked onto the zone maps
  - Can be switched off in _Settings_
- First sightings appear once someone turns out to matter
- New "Pencil and ink" page explains how strangers become entries
- The login slip is now a parcel to unwrap

### Changes

- Characters with an existing diary start their route from now on
- Maps show explored areas, like your world map
- The book opens on _Your Diary_ once the intro is read
- The front matter previews each section of the book
- Ribbons turn the book from the intro too
- Opening people's pages turns forward one page at a time

### Fixes

- An error in one event handler no longer breaks the others

## [1.0.0]

First packaged build, for WoW Classic Beta (Interface 16001).

### Shiny new Things

- Add people to your diary with tags and dated notes
  - From unit menus, chat names, a keybind or `/sd add`
- Trades, chat, groups, deaths and PvP kills are recorded
- _Recently nearby_ lists players you've seen out in the world
- _People_ pages show a timeline and a map of where you met
- _Toasts_ and tooltips greet diary friends when they're nearby
  - Optional alert for foes
- The journal: _People_, profiles, front matter and _Settings_
- Strangers are forgotten after 30 days of nothing new
