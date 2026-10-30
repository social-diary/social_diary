-- How high everything on the table spread lies, so the one lamp over the
-- table (UI/Paper/Light.lua, the house light the map sheet obeys) casts
-- every shadow from its height: higher means further out and paler. The
-- spread lies over the game world (the book is put aside, UI/Dungeon/
-- Spread.lua): on it the map sheet and the bookmark that is the way back;
-- on the sheet the strips. Each throws two shadows where it can:
--   - on what lies just under it (the sheet, the strip beneath),
--     drawn with it, from how high it stands over that;
--   - on the world, drawn on the sheet's ground layer (UI/Dungeon/
--     Sheet.lua's view.ground) under the sheet, from how high it stands
--     over the world, in the world's darker, wider shadow. The sheet covers
--     the part of it that falls on the sheet, so only what falls past the
--     paper shows: a strip's shadow lies on whatever is really
--     under it.

local addonName, ns = ...

local DungeonPage = ns.UI.DungeonPage

-- Heights in px, as the sheet's folds are (a fold stands 10 px, CREASE.ridge
-- in UI/Dungeon/Sheet.lua): the sheet on the world (`sheet`, its folds
-- higher); a strip taped flat on the sheet (`strip`: a tight shadow), one
-- pinned by a tack at a corner (`tacked`: it stands off the paper a
-- little), and what of either sticks out past the paper's edge over the
-- world (`overhang` more: the paper's thickness and the bridge off it);
-- the bookmark on the world (`bookmark`), the pencil's slip across the sheet's top edge
-- (`way`, UI/Dungeon/Way.lua), and how much higher something picked up
-- under the mouse is (`lifted`).
local HEIGHT = { sheet = 0, strip = 1, tacked = 2.5, overhang = 3, bookmark = 1.5, way = 2, lifted = 5 }
DungeonPage.HEIGHT = HEIGHT

-- The shadow of an outline `h` px up on `ground` ("paper", "world"): the
-- house light's layers ({ right, down, grown by, alpha }) and colour.
function DungeonPage.Cast(h, ground)
    return ns.UI.Light.Cast(h, ground)
end

-- A strip's shadows (UI/Paper/Strip.lua's note.shadow, note.soft and
-- note.ground), `tacked` or taped: its contact shadow and soft edge on the
-- sheet, from its height over it, and its shadow on the world, from its
-- height over that, drawn on `frame` (the sheet's ground layer).
function DungeonPage.StripShadows(tacked, frame)
    local Light = ns.UI.Light
    local h = tacked and HEIGHT.tacked or HEIGHT.strip
    local near, dark = Light.Fall(h, false)
    local far, pale = Light.Fall(h, true)
    local layers, colour = Light.Cast(h + HEIGHT.overhang, "world")
    return { near, near, dark }, { out = near, blur = far - near, alpha = (dark + pale) / 2 },
        frame and { frame = frame, layers = layers, colour = colour } or nil
end
