-- The in-game changelog (Settings > About > Changelog,
-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.
-- Written by Dev/changelog.lua; do not edit by hand. Run it again after
-- CHANGELOG.md changes (tests/changelog.lua fails until you do).

local addonName, ns = ...

ns.Changelog = {
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
    {
        version = "4.2.1",
        summary = "A small Update: people who ride a zeppelin or boat with you, or walk beside you into a new zone, no longer count as seen twice.",
        groups = {
            { heading = "Fixes", entries = {
                { text = "Crossing a zone border no longer counts nearby people as seen twice", thanks = "OscillatorZ" },
            } },
        },
    },
    {
        version = "4.2.0",
        summary = "This Update brings the diary in Brazilian Portuguese.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "Added Brazilian Portuguese to the diary’s language settings", thanks = "thiagocoutinhor" },
            } },
        },
    },
}
