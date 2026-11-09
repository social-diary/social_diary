-- Level-ups (others'): someone seen at a higher level than last time, a
-- row on them ("Tester is now level 16"). A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md), and a People row
-- and nothing else, as Chat and Trade are: no route list, no moment on the
-- plates, no mark, no margin note, no caption words. Not the user's own
-- levels: those are the route's (Your Diary's level pins, the sessions'
-- levelEnd), and stay core.
--
--   Kind.lua     what a level-up is to the diary: its row kind, its words
--                and icon on the timeline
--   Capture.lua  a rise in level heard from the character store
--                (SD_LEVEL_ROSE), and who is worth a row
--   Dev.lua      its part of /sd testdata: Tester's level-ups, 18 to 22
--                (never packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder names the level-up row. Its own names are on
-- ns.LevelUps, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - a character's level as such: Characters.Observe (Core/Characters.lua)
--     keeps record.level (FILLABLE, never blanked; the People index's
--     `level`), and tells a rise on a live reading as SD_LEVEL_ROSE (Core/
--     Events.lua's header), which Capture.lua listens to;
--   - the climb: level-ups one after another folded into one line on the
--     timeline (Core/Timeline.lua's Climbs, by Core/Rows.lua's `climb`
--     flag, which this kind sets), with its words ("Tester went from level 1
--     to 6") and icon in UI/Words/Timeline.lua, reading the rows' context
--     { from, level };
--   - the "levelup" art (UI/Style/Art.lua), the climb's icon too;
--   - the sessions' levelStart/levelEnd (SES-4: Capture/Group.lua's
--     UNIT_LEVEL, Core/Sessions.lua), read off the same readings but not
--     from these rows.
--
-- This file: the kind, whole (Core/Rows.lua's spec in one call, words and
-- icon included).

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local LevelUps = {}
ns.LevelUps = LevelUps

--------------------------------------------------------------------------
-- The People row
--------------------------------------------------------------------------
--
-- Something the user saw of them, not an exchange (`observed`): it does not
-- count as an interaction on record, nor make them someone just dealt
-- with. Always a line, and names nothing in a headline: the details line
-- already says "they went from 18 to 21". One after another they fold into
-- a climb (`climb`).
--
-- Its words: "Tester is now level 16", the name being the profile's.

ns.Rows.Register("level_up", { observed = true, climb = true,
    moment = function() return true end,
    text = function(row, guid)
        local first = guid and ns.Characters.Name(guid)
        local level = tostring(row.context and row.context.level or "?")
        return first and Fmt(L["%1$s is now level %2$s"], first, level) or Fmt(L["Now level %s"], level)
    end,
    icon = "levelup" })
