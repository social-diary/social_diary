-- The table Dungeon Crawler Forever's data files load into (ns.DCF), made
-- before them. Their files are copied as they ship, with one changed line
-- each (VERSION says which release), so a new release is a copy step.
-- Only Core/Dungeons.lua reads ns.DCF; tests/dungeons.lua checks that.

local _, ns = ...

ns.DCF = {}
