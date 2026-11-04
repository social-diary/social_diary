-- A hunter's moments: the client's numbers, read at call time only
-- (Capture.lua). From the pets probe of 4 Nov 2026 (a fresh hunter on
-- Forever 1.60.1, .claude/features/hunter-tames.md, "Probe").

local addonName, ns = ...

local Hunter = ns.Hunter

-- Tame Beast, the hunter's own: a channel of about 20 s, the pet coming at
-- its end. Not the quest's rods (19688, 19689, 19692), whose beasts are
-- charmed creatures and never pets, nor the 13481 "Tame Beast" that Call
-- Pet and Revive Pet fire behind the scenes.
Hunter.TAME_BEAST = { [1515] = true }

-- How long a cast of Tame Beast waits for its pet: the channel (20 s) and
-- some to spare for a laggy server.
Hunter.ARMED = 30

-- How long after the pet comes its name and family are read: the client
-- names it "Unknown" on its first UNIT_PET and fills it in a moment later
-- (the probe, +1 s).
Hunter.SETTLE = 1
