-- The in-game changelog (Settings > About > Changelog,
-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.
-- Written by Dev/changelog.lua; do not edit by hand. Run it again after
-- CHANGELOG.md changes (tests/changelog.lua fails until you do).

local addonName, ns = ...

ns.Changelog = {
    {
        version = "2.4.0",
        summary = "Just small fixes connected to _Hunts_, Nearby _Toasts_ and the _Dungeon View_.",
        groups = {
            { heading = "Fixes", entries = {
                { text = "_Hunts_ in _Your Diary_ are no longer confused by crafting" },
                { text = "Nearby _Toasts_ and last-seen places ignore group members who are far away" },
                { text = "Items in the _Dungeon View_ can be shift-clicked and ctrl-clicked" },
                { text = "A rare killed again in one session is named once on the timeline" },
            } },
        },
    },
    {
        version = "2.3.0",
        summary = "This Update adds support for non-latin languages and pencilled-in preview pages for strangers in _Your Diary_.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "Strangers in _Your Diary_ open a pencilled-in preview of their page" },
            } },
            { heading = "Fixes", entries = {
                { text = "Names and places now show on Russian, Korean and Chinese clients" },
            } },
        },
    },
    {
        version = "2.2.1",
        summary = "Just one small fix, so the journal can be closed during a fight.",
        groups = {
            { heading = "Fixes", entries = {
                { text = "The journal's close button now works in combat" },
            } },
        },
    },
    {
        version = "2.2.0",
        summary = "This Update introduces hints, a _Feedback_ page and tamed pets for Hunters, and the _Dungeon View_ now knows which pack killed you.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "Occasional hints point out features you may have missed" },
                { text = "A _Feedback_ page in _Settings_ for bug reports and comments" },
                { text = "Hunters: _Your Diary_ remembers the pets you tame and name" },
            } },
            { heading = "Changes", entries = {
                { text = "A few rarely used chat commands are gone", sub = { { text = "The sightings switch now lives in _Settings_" } } },
                { text = "_Dungeon View_ places deaths and wipes at the pack that killed you", sub = { { text = "In Ragefire, the Deadmines, the Stockade and both Razorfens so far" } } },
                { text = "_Dungeon View_ keeps a wipe's marks and its note together in one spot" },
                { text = "_Dungeon View_ marks no longer drift ahead after idle time" },
            } },
            { heading = "Fixes", entries = {
                { text = "_Dungeon View_ spreads deaths along the way before the first boss falls" },
            } },
        },
    },
    {
        version = "2.1.0",
        summary = "This Update lets you add your own events to _Your Diary_ and makes getting started shorter, along with a good round of fixes.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "_Your Diary_ now allows adding custom events by right clicking the Map" },
                { text = "_Dungeon View_ explains its default route the first time it opens" },
                { text = "Paper texture intensity can be set in _Settings_" },
            } },
            { heading = "Changes", entries = {
                { text = "Onboarding and the login parcel are shorter and easier to follow" },
                { text = "Any key or mouse button can be bound to the addon's shortcuts" },
                { text = "Clicking your current dungeon in _Your Diary_ opens its _Dungeon View_" },
            } },
            { heading = "Fixes", entries = {
                { text = "Sightings, language support and _Remember this_ behave reliably again" },
                { text = "_Dungeon View_ stays open when you right-click beside the map" },
                { text = "_People_ shows the right time for people you've only seen" },
                { text = "_People_ names back-to-back dungeons together correctly" },
                { text = "_Your Diary_ skips empty levels from before the addon was installed" },
                { text = "Dungeon run pages in _Your Diary_ list everyone and lay out correctly" },
            } },
        },
    },
}
