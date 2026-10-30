-- Run from the addon folder:  /opt/homebrew/bin/luajit tests/run.lua
--
--   tests/run.lua -v              sections and everything the addon printed
--   tests/run.lua trade diary     just those files
--
-- Loads the addon against the mock in wowmock.lua, once per file, and asserts
-- the behaviour that the client would otherwise have to prove. Extend this
-- whenever a module lands: it is the only regression net this project has.
-- A new file goes in FILES below; see harness.lua for what a file receives.

local here = (arg and arg[0] or "tests/run.lua"):match("^(.*)[/\\]") or "."

local FILES = {
    "identity",
    "interactions",
    "trade",
    "chat",
    "diary",
    "notes",
    "menus",
    "group_sessions",
    "deaths",
    "pvp",
    "journey",
    "sittings",
    "firsts",
    "skills",
    "skills_ui",
    "combat",
    "questie",
    "journal_ui",
    "journey_ui",
    "killer_card",
    "combat_ui",
    "hunt_card",
    "lucky_card",
    "ink_trail",
    "ink_blot",
    "hand",
    "people",
    "reunion",
    "settings",
    "minimap",
    "sightings",
    "timeline",
    "person_plate",
    "person_page",
    "instances",
    "dungeons",
    "dungeon_run",
    "dungeon_rolls",
    "dungeon_ui",
    "dungeon_spread",
    "dungeon_light",
    "dungeon_way",
    "dungeon_way_ui",
    "dungeon_tutorial",
    "run_page",
    "events",
    "slash",
    "helpers",
    "sounds",
    "witnesses",
    "witness_card",
    "campfire",
    "campfire_ui",
    "duels",
    "you",
    "duels_ui",
    "kinds",
    "margin_caption",
    "registry",
    "pages",
    "paper_strip",
    "ui_layout",
}

dofile(here .. "/harness.lua").Run(here, FILES, arg)
