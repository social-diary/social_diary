-- The in-game changelog (Settings > About > Changelog,
-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.
-- Written by Dev/changelog.lua; do not edit by hand. Run it again after
-- CHANGELOG.md changes (tests/changelog.lua fails until you do).

local addonName, ns = ...

ns.Changelog = {
    {
        version = "3.0.2",
        summary = "This Updates brings small but important UX fixes. Especially the red ink spills that mark your combat zones in _Your Diary_ are now more clearly computed and displayed.",
        groups = {
            { heading = "Changes", entries = {
                { text = "_Dungeon View_ now places deaths, wipes and rolls precisely by mob pack data in Wailing Caverns and Shadowfang Keep" },
            } },
            { heading = "Changes", entries = {
                { text = "Tooltips in _Your Diary_ Plates now summarize their data instead of showing e.g. 4 times \"Fought here for x Minutes\"" },
            } },
            { heading = "Fixes", entries = {
                { text = "Dungeons, battlegrounds and boss fights no longer cause repeated Lua errors" },
                { text = "In _Your Diary_, The red ink spills that mark your combat zones are now more clearly visible." },
            } },
        },
    },
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
}
