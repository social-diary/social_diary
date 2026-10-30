# Changelog

All notable changes to Social Diary. Versions follow the `## Version` line in
`social_diary.toc`; a release is the matching `v` tag (for example `v1.0.0`).

## [unreleased]

### Shiny new Things

- Dungeons activites are now mapped!
  - Group members now get a business card. Art is WIP
  - Dungeon Routes can be drawn by hand if they diverge from the default route.
  - They also appear in _Your Diary_ as full-sized pages
- A minimap button now opens the journal and _Settings_

### Changes

- Social Diary is now licensed under the GPL v3
- Sessions on a profile now tell proper stories -- will get better over time with more addtions.
- _Your Diary_ now lists play sessions instead of levels. This prepares for later levels where too much happens in one level to portray it correctly on one page.
- Removed Together Sessions Setting to improve clarity in settings.

### Fixes

- Flight paths in _Your Diary_ now use a single Flight Master node
- First items in _Your Diary_ do not show up as mail items anymore
  - Crafted firsts now say you made them
- A zone's full map in _Your Diary_ now pans without zooming first
- Sessions no longer list the same zone over and over
- Memory page no longer shows file size of all characters combined

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
