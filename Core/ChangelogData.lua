-- The in-game changelog (Settings > About > Changelog,
-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.
-- Written by Dev/changelog.lua; do not edit by hand. Run it again after
-- CHANGELOG.md changes (tests/changelog.lua fails until you do).

local addonName, ns = ...

ns.Changelog = {
    {
        version = "4.2.6",
        summary = "This Update makes your save files around 60 to 80% smaller, and a new _Memory_ setting caps how many strangers the diary keeps.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "_Memory_ settings can now cap how many strangers are kept" },
            } },
            { heading = "Changes", entries = {
                { text = "Strangers now take far less room in your save files" },
            } },
        },
    },
    {
        version = "4.2.5",
        summary = "This Update brings five more dungeons to the _Dungeon View_. A quest item everyone in your group loots, like a boss's head, no longer counts as a lucky drop in _Your Diary_.",
        groups = {
            { heading = "Changes", entries = {
                { text = "_Dungeon View_ now knows five more dungeons and more default routes", sub = { { text = "Blackmaw Hold and The Shaper's Terrace maps are in beta" } } },
            } },
            { heading = "Fixes", entries = {
                { text = "_Your Diary_ no longer calls quest items the whole group loots lucky" },
            } },
        },
    },
    {
        version = "4.2.4",
        summary = "This update brings support for Traditional Chinese.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "Added Traditional Chinese support" },
            } },
        },
    },
    {
        version = "4.2.3",
        summary = "A small Update: new gear and more of the diary's wording now read in your language.",
        groups = {
            { heading = "Fixes", entries = {
                { text = "Missing translations added to all languages", thanks = "CarnVanBeck" },
            } },
        },
    },
    {
        version = "4.2.2",
        summary = "This small update brings improvements to the PvP labels in _Your Diary_.",
        groups = {
            { heading = "Changes", entries = {
                { text = "PvP labels in _Your Diary_ now show the opponents level, class and race, or, if they are in your Diary, their name." },
                { text = "Improved the design of the PvP labels in _Your Diary_." },
            } },
            { heading = "Fixes", entries = {
                { text = "Quest drops are now only judged on looted items. Items that come from trading and mails are ignored for lucky / unlucky cards." },
            } },
        },
    },
}
