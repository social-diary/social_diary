-- The in-game changelog (Settings > About > Changelog,
-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.
-- Written by Dev/changelog.lua; do not edit by hand. Run it again after
-- CHANGELOG.md changes (tests/changelog.lua fails until you do).

local addonName, ns = ...

ns.Changelog = {
    {
        version = "3.0.1",
        summary = "A Hotfix for Behaviour in Battlegrounds. Currently, BG data is interpreted badly and potentially clogging up a Diary entry. Until a proper Battleground Feature is implemented, BG Capture will be turned off.",
        groups = {
            { heading = "Fixes", entries = {
                { text = "Battleground Activities are currently skipped, because they result in bad Diary data." },
            } },
        },
    },
    {
        version = "3.0.0",
        summary = "A big Update: the diary now works with a controller through WoW's Gamepad UI, and a new _Changelog_ under _About_ in _Settings_ shows what's new after each update.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "The Addon now supports Gamepad UI!", sub = { { text = "You can use almost all diary features just with a controller." }, { text = "Some actions still require Keyboard and Mouse, such as:" }, { text = "Editing A Dungeon Route" }, { text = "Precise Placing of Custom Events" }, { text = "As this is a new feature and Blizzard's Gamepad UI will likely change frequently, bug reports are especially welcome." } } },
                { text = "An in-game _Changelog_ in _Settings_, under _About_", sub = { { text = "A hint points you to the _Changelog_ after a big update" } } },
            } },
            { heading = "Changes", entries = {
                { text = "_Feedback_ and _Credits_ now sit under _About_ in _Settings_" },
            } },
        },
    },
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
}
