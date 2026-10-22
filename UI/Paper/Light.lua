-- The house light (.impeccable.md, "one light, physically derived"): one
-- lamp at the top left, for everything that lies on the diary's paper or
-- on a dungeon's table. A loose sheet (UI/Paper/Sheet.lua) was the first to obey
-- it, and its model is this one, moved here so what lies beside the sheet
-- obeys the same numbers:
--   - a shadow is cast from a height: something `h` px above what it lies
--     on throws its shadow `LIFT.base` + `LIFT.gain` * h px down and to
--     the right, at `LIFT.alpha` / (1 + `LIFT.fade` * h); its soft edge
--     falls `reach` times as far and `extra` px more, at `soft` of that.
--     Higher means further out and paler (Fall);
--   - what the shadow falls on decides how it shows (GROUND): the same
--     shadow that reads on pale paper is lost on the game world seen
--     through the put-aside book, so the world takes it darker, in black,
--     and spread a little wider;
--   - something that cannot bend is shadowed by a few copies of its own
--     outline stacked from the contact shadow out to the soft edge (Cast):
--     dark close in, paler and wider further out;
--   - something flat takes the light across itself (SHEEN): as painted at
--     its top left, a little darker toward its bottom right, inside the
--     sheet's own facets' range (UI/Paper/Sheet.lua's CREASE.lo to hi),
--     so a card or a strip reads as lit by the same lamp as the folds.
--
-- Pure arithmetic and colouring: it makes nothing as it loads.

local addonName, ns = ...

local Style = ns.Style

local Light = {}
ns.UI.Light = Light

-- The shadow's fall from a height h (px above what it lies on), the loose
-- sheet's (UI/Paper/Sheet.lua, where its numbers were tuned in the
-- client): `base` + `gain` * h px down and to the right, at `alpha` / (1 +
-- `fade` * h); its soft edge `reach` times as far plus `extra`, at `soft`
-- of the shadow's darkness.
local LIFT = { base = 1, gain = 0.22, alpha = 0.32, fade = 0.04, reach = 1.8, extra = 1.5, soft = 0.35 }
-- What a shadow falls on: its `colour`, how much darker than LIFT's it is
-- there (`strength`), and how much further its soft edge reaches
-- (`spread`). Paper and a card (the book's page, the map sheet, a card
-- under another): ink, as tuned. The world under a dungeon's table (the
-- book is put aside, UI/Dungeon/Spread.lua): grass, stone, night, busy
-- and mostly darker than paper, so black at 0.32 is lost on it; black,
-- nearly twice as dark, and a little wider, so the soft edge still reads
-- where the core is a thin line.
local GROUND = {
    paper = { colour = Style.INK, strength = 1, spread = 1 },
    world = { colour = { 0.03, 0.02, 0.012 }, strength = 1.85, spread = 1.45 },
}
-- An outline's shadow (Cast): `layers` copies, from the contact shadow to
-- the soft edge, each grown `grow` px per px it lies further out, so the
-- edge softens as it falls away; the stack's darkness at its core and at
-- its edge as LIFT says (each layer as dark as makes it so).
local CAST = { layers = 3, grow = 0.55 }
-- The light across something flat (a card, a strip, a slip): its colour
-- times `top` along its top edge and `bottom` along its foot, and over it
-- a wash of shade growing from `left` at its left edge to `right` at its
-- right: as painted at the top left (1), about 0.88 at the bottom right.
-- Gentle, so painted art and writing keep their contrast.
local SHEEN = { top = 1, bottom = 0.94, left = 0, right = 0.065, colour = { 0.02, 0.012, 0.006 } }
Light.LIFT, Light.GROUND, Light.CAST, Light.SHEEN = LIFT, GROUND, CAST, SHEEN

-- How far a shadow falls from something `h` px up, and how dark it is:
-- the core's, or with `soft` its soft edge's; on `ground` (GROUND's, paper
-- by default). The loose sheet's own formula, operation for operation.
function Light.Fall(h, soft, ground)
    local off = LIFT.base + LIFT.gain * h
    if soft then off = off * LIFT.reach + LIFT.extra end
    local alpha = LIFT.alpha / (1 + LIFT.fade * h) * (soft and LIFT.soft or 1)
    if ground then
        if soft then off = off * (ground.spread or 1) end
        alpha = alpha * (ground.strength or 1)
    end
    return off, alpha
end

-- The shadow of an outline `h` px up, on `ground` (a GROUND entry or its
-- key; paper by default), that cannot bend: CAST.layers copies of the
-- outline, { right, down, grown by, alpha }, from the contact shadow out to
-- the soft edge, and the colour to draw them in. Stacked, they are as dark
-- as the core where all overlap and as the soft edge where only the last
-- reaches.
function Light.Cast(h, ground)
    if type(ground) == "string" then ground = GROUND[ground] end
    ground = ground or GROUND.paper
    local near, dark = Light.Fall(h, false, ground)
    local far, pale = Light.Fall(h, true, ground)
    dark, pale = math.min(dark, 0.9), math.min(pale, dark)
    local n = math.max(1, CAST.layers)
    local layers, under = {}, 0
    -- From the outside in: each layer makes up what the ones outside it
    -- leave of the darkness wanted there.
    for k = n, 1, -1 do
        local t = n == 1 and 0 or (k - 1) / (n - 1)
        local want = dark + (pale - dark) * t
        local off = near + (far - near) * t
        local alpha = math.max(0, 1 - (1 - want) / (1 - under))
        under = want
        layers[k] = { off, off, CAST.grow * (off - near), alpha }
    end
    return layers, ground.colour
end

-- A texture's colours as a gradient, from `from` ({ r, g, b, a }, the
-- left, or the bottom for VERTICAL) to `to`, without resetting what it
-- draws (Style.Gradient paints it white first, for a colour; this keeps
-- its art). Where SetGradient fails, the average, flat.
function Light.Tint(texture, orientation, from, to)
    local ok = CreateColor and pcall(texture.SetGradient, texture, orientation,
        CreateColor(from[1], from[2], from[3], from[4] or 1), CreateColor(to[1], to[2], to[3], to[4] or 1))
    if not ok then
        texture:SetVertexColor((from[1] + to[1]) / 2, (from[2] + to[2]) / 2, (from[3] + to[3]) / 2,
            ((from[4] or 1) + (to[4] or 1)) / 2)
    end
end

-- Something flat lit across itself (SHEEN): `base` (its stock: a colour
-- texture, or art with `colour` nil) lit from its top down, and `shade`
-- (a texture laid over the same outline: a colour, or the same art, so
-- the shade falls only where the art is) shading it toward the right. A
-- colour stock is given as `colour` ({ r, g, b }).
function Light.Sheen(base, shade, colour, art)
    local S = SHEEN
    if colour then
        Style.Gradient(base, "VERTICAL", { colour[1] * S.bottom, colour[2] * S.bottom, colour[3] * S.bottom, 1 },
            { colour[1] * S.top, colour[2] * S.top, colour[3] * S.top, 1 })
    elseif base then
        Light.Tint(base, "VERTICAL", { S.bottom, S.bottom, S.bottom, 1 }, { S.top, S.top, S.top, 1 })
    end
    if shade then
        local C = S.colour
        if art then
            shade:SetTexture(art)
        else
            shade:SetColorTexture(1, 1, 1, 1)
        end
        Light.Tint(shade, "HORIZONTAL", { C[1], C[2], C[3], S.left }, { C[1], C[2], C[3], S.right })
    end
end
