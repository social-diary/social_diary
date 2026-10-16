-- The usual way through dungeons Dungeon Crawler Forever has no route for
-- yet, drawn by us in its route editor and copied out of its saved
-- variables (DungeonMapDB.routes). Ours, not part of Vendor/: its shape is
-- DCF's Data/Routes.lua ([instanceID][wing or 0] = { {f = floor, x, y,
-- boss}, ... }), so it can go back to them as is. Core/Dungeons.lua reads
-- these before DCF's.

local addonName, ns = ...

ns.DungeonRoutes = {
    -- The Hall of Thanes, drawn 2026-10-16 on DCF's drawn floor (830651).
    [3065] = {
        [0] = {
            { f = 830651, x = 0.5083, y = 0.8977 }, { f = 830651, x = 0.5090, y = 0.8245 }, { f = 830651, x = 0.5032, y = 0.7894 },
            { f = 830651, x = 0.4800, y = 0.7790 }, { f = 830651, x = 0.4433, y = 0.7800 }, { f = 830651, x = 0.4294, y = 0.7773 },
            { f = 830651, x = 0.4271, y = 0.7540 }, { f = 830651, x = 0.4275, y = 0.6794 }, { f = 830651, x = 0.4291, y = 0.6395 },
            { f = 830651, x = 0.4412, y = 0.6245 }, { f = 830651, x = 0.4673, y = 0.6221 }, { f = 830651, x = 0.4886, y = 0.6207 },
            { f = 830651, x = 0.5067, y = 0.6332 }, { f = 830651, x = 0.5370, y = 0.6457 }, { f = 830651, x = 0.5275, y = 0.7019, boss = "Faldrim Anvilmar" },
            { f = 830651, x = 0.5474, y = 0.7200 }, { f = 830651, x = 0.5788, y = 0.7144 }, { f = 830651, x = 0.5920, y = 0.6992 },
            { f = 830651, x = 0.5920, y = 0.6735 }, { f = 830651, x = 0.6156, y = 0.6683 }, { f = 830651, x = 0.6404, y = 0.6707 },
            { f = 830651, x = 0.6788, y = 0.6485 }, { f = 830651, x = 0.6938, y = 0.6235 }, { f = 830651, x = 0.6973, y = 0.5478 },
            { f = 830651, x = 0.7217, y = 0.4846, boss = "Magmatus" }, { f = 830651, x = 0.6453, y = 0.5024 }, { f = 830651, x = 0.5874, y = 0.5093 },
            { f = 830651, x = 0.5536, y = 0.5180 }, { f = 830651, x = 0.5085, y = 0.5132, boss = "Plunder" }, { f = 830651, x = 0.5104, y = 0.4597 },
            { f = 830651, x = 0.5099, y = 0.3830 }, { f = 830651, x = 0.5117, y = 0.3150 }, { f = 830651, x = 0.5083, y = 0.2664 },
            { f = 830651, x = 0.5096, y = 0.1676, boss = "Durgen Dirgehammer" },
        },
    },
}
