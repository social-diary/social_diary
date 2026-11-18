-- The in-game changelog (Settings > About > Changelog,
-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.
-- Written by Dev/changelog.lua; do not edit by hand. Run it again after
-- CHANGELOG.md changes (tests/changelog.lua fails until you do).

local addonName, ns = ...

ns.Changelog = {
    {
        version = "4.2.0",
        summary = "This Update brings the diary in Brazilian Portuguese.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "Added Brazilian Portuguese to the diary’s language settings", thanks = "thiagocoutinhor" },
            } },
        },
    },
    {
        version = "4.1.1",
        summary = "A small Update: the preset tags now speak your language, and Feign Death or healing yourself no longer leaves false deaths and _Close Calls_ in your diary.",
        groups = {
            { heading = "Changes", entries = {
                { text = "The preset tags now show in your language", thanks = "YaN9Yu96" },
            } },
            { heading = "Fixes", entries = {
                { text = "Feign Death no longer counts as a death", thanks = "JasonLudeli" },
                { text = "Healing yourself no longer records false _Close Calls_" },
            } },
        },
    },
    {
        version = "4.1.0",
        summary = "This Update brings an exciting new Addition to _Your Diary_: Gear Upgrades! Whenever you equip a better Item, it gets written down. Just trying it on will not trigger it. There may be some funkiness going on with 2H->2x1H weapons and so on – Please report issues on this! The Diary also now, optionally, adds Players you encounter often enough automatically.",
        groups = {
            { heading = "Shiny new Things", entries = {
                { text = "_Your Diary_ now detects when you equip upgrades of your existing equipment and displays them on your Diary's plates" },
                { text = "Added Polish to the diary’s language settings", thanks = "KO.Media" },
                { text = "You can now make the Diary auto-add players you encounter often or do dungeons and raids with", thanks = "ubrider, replayablecontent46369" },
            } },
        },
    },
    {
        version = "4.0.2",
        summary = "A hotfix for the Gamepad UI, where opening a player's menu locked the controller. For now, add players with the Remember key or the macros when playing with a controller.",
        groups = {
            { heading = "Fixes", entries = {
                { text = "A player's menu no longer locks the controller with the Gamepad UI", sub = { { text = "The diary's entry is left out of that menu for now" } } },
                { text = "German zone names now take their article and case", thanks = "CarnVanBeck" },
            } },
        },
    },
    {
        version = "4.0.1",
        summary = "This update brings support for simplified Chinese as well with some more bug fixes.",
        groups = {
            { heading = "Shiny New Things", entries = {
                { text = "Added Simplified Chinese support", thanks = "jasonzxy0825" },
            } },
            { heading = "Changes", entries = {
                { text = "It's now more likely to _get lucky_ on a quest item hunt, now requiring just half of expected kills instead of an eighth" },
            } },
            { heading = "Fixes", entries = {
                { text = "In Korean and Chinese Clients, Box / Tofu Characters no longer appear in place of no-break spaces" },
                { text = "Language Fixes for ruRU" },
            } },
        },
    },
}
