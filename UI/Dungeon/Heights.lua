-- How high everything on the table spread lies, so the one lamp over the
-- table (UI/Paper/Light.lua, the house light the map sheet obeys) casts
-- every shadow from its height: higher means further out and paler. The
-- spread lies over the game world (the book is put aside, UI/Dungeon/
-- Spread.lua): on it the map sheet, the party's cards in a small stack by
-- its bottom-left corner and the bookmark that is the way back; on the
-- sheet the strips; the cards fanned out of the stack held up over
-- everything. Each throws two shadows where it can:
--   - on what lies just under it (the sheet, the strip or card beneath),
--     drawn with it, from how high it stands over that;
--   - on the world, drawn on the sheet's ground layer (UI/Dungeon/
--     Sheet.lua's view.ground) under the sheet, from how high it stands
--     over the world, in the world's darker, wider shadow. The sheet covers
--     the part of it that falls on the sheet, so only what falls past the
--     paper shows: a card's or a strip's shadow lies on whatever is really
--     under it.

local addonName, ns = ...

local DungeonPage = ns.UI.DungeonPage

-- Heights in px, as the sheet's folds are (a fold stands 10 px, CREASE.ridge
-- in UI/Dungeon/Sheet.lua): the sheet on the world (`sheet`, its folds
-- higher); a strip taped flat on the sheet (`strip`: a tight shadow), one
-- pinned by a tack at a corner (`tacked`: it stands off the paper a
-- little), and what of either sticks out past the paper's edge over the
-- world (`overhang` more: the paper's thickness and the bridge off it); a
-- card over what is just under it (`onCard`: the card under it in the
-- stack, the card above it fanned), a slip tucked under a card's foot over
-- what is under it (`slip`), a raid's deck, a small stack (`deck`); the
-- cards lying in their stack, a few cards thick, on the world (`stack`);
-- the cards fanned out of it, held up over the map (`fan`); the bookmark on
-- the world (`bookmark`), and how much higher something picked up under
-- the mouse is (`lifted`).
local HEIGHT = { sheet = 0, strip = 1, tacked = 2.5, overhang = 3, onCard = 1.5, slip = 1, deck = 3.5, stack = 2,
    fan = 9, bookmark = 1.5, lifted = 5 }
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
