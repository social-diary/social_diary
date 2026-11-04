-- Rare kills (SES-4): a rare, rare elite or world boss killed by the user
-- or their group during a together session, counted for every participant
-- grouped right then ("killed Humar the Pridelord" on their timeline). A
-- feature in a folder of its own (.claude/skills/new-feature/folder.md),
-- and a detection and nothing else: no row kind, no route list, no moment
-- on the plates, no mark, no margin note, no caption words.
--
--   Kind.lua     this header, and the feature's namespace
--   Capture.lua  PARTY_KILL, and the unit still on the corpse that says
--                what kind of creature it was
--
-- Its own names are on ns.Rares, made here, the first of its files the TOC
-- loads. No Dev.lua: Tester's rares are fields of Tester's sessions, which
-- Dev/TestData.lua writes whole, as it does the sessions' deaths.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the session's rares (Sessions.Rare: participant.rares, MAX_RARES;
--     Core/Sessions.lua), which Capture.lua writes through, as Deaths
--     writes the session's deaths;
--   - the timeline's activity "rare" (Core/Timeline.lua's RANK, an
--     episode's rare items) and its words and icon ("killed Humar the
--     Pridelord"; UI/Words/Timeline.lua), keyed by activity, not by kind;
--   - the "rare" art (UI/Style/Art.lua);
--   - /sd sessions' count of a session's rares (Dev/Diagnostics.lua).

local addonName, ns = ...

local Rares = {}
ns.Rares = Rares
