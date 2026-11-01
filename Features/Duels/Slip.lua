-- The duel note (Your Diary's plates; .claude/ui-proposal/duels.md, signed
-- 15 Oct): the plate's biggest series told in one line in the diary's
-- hand, words only (Duels.Note, Text.lua: "lost to Bram 3 to 2", "won a
-- duel"), with a pencil leader to its flag (Mark.lua). S, the only size:
--
--   in the margin   a small cut slip of the strip family (UI/Paper/Strip.lua),
--                   the campfire's exactly (Features/Campfire/Slip.lua): the
--                   hand at 14 px, the small tape slanted over its top left
--                   corner, clear of the words; beside a full plate, and
--                   under a light plate's caption where its print had no
--                   room for it
--   on the print    on a light plate, the same words on a slip glued across
--                   the print's foot, where good luck's S goes (variant D,
--                   signed 15 Oct; Features/Hunts/LuckyCard.lua's PRINT): no
--                   tape, a leader up to the flag only where the flag is
--                   not beside it. Good luck keeps the print where both
--                   are there (it is not filler): the duel goes under the
--                   caption then
--
-- One note a plate however many series (each keeps its flag and its
-- tooltip): the one with the most duels, the latest of equals. No icon,
-- glyph, count or underline in it (the user, 15 Oct: "No icon within the
-- label text. we dont do that"). It opens nothing; under the mouse it
-- tells its series as the flag does.
--
-- A series the player changed or wrote (Core/Custom.lua, rec.customOf) is out of
-- that choice: each is a note of its own (`duelCustom`, order 8.5), never filler,
-- and it takes the print ahead of the plate's one, so a card just written shows
-- where its plate has no margin at all (FL's print). What it pushes off the print
-- goes on to the margin, then the words, as it would for good luck.
--
-- It is filler (the user, 15 Oct), so it never grows smaller: the named
-- words, then the nameless (Duels.Note's `named` false) where a long name
-- will not fit, then it is left off and the caption's words say it
-- (`said.duel`, Text.lua), unless that would run them past their foot
-- (plate.duelTold false: the flag alone tells it). It stands apart from a
-- person's own note on the same plate (the user, 15 Oct), never folded
-- into it.
--
-- Laid flat ("Flat paper only") both lie square, without shadows, as every
-- slip does.

local addonName, ns = ...

local Style = ns.Style
local Duels = ns.Duels
local Slip = {}
Duels.Slip = Slip

-- The slip in the margin: the hand's file and size (the S hand, the lucky
-- tag's 14 px), the most it turns (degrees, the strip's), and its tape
-- (the campfire slip's: `w` by `h`, its middle at `x`, `y` px of the slip
-- from its top left, i.e. on the corner, slanted between the two `slant`s,
-- degrees, seeded), which crosses the corner on the slip's margin, so the
-- words start clear of it.
local SLIP = { file = Style.NEUTON_ITALIC, size = 14, turn = 1.4,
    tape = { x = 1, y = 1, w = 22, h = 10, slant = { 39, 51 } } }

-- On a light plate's print: good luck's S slip (LuckyCard's PRINT), words
-- only. Its margins round the words (left, top, right, bottom), `height`
-- px tall, `bottom` px above the print's foot, turned between the two
-- `turn`s (degrees, seeded, either way); the hand at `hand` px, `line` px
-- a line. Along the foot it starts `pc` + 2 px past a photo corner, or
-- `edge` px from the print's edge where a corner has none (the corner
-- come unstuck); it moves to the foot's right end only where its flag lies
-- under it (`flag` px round); a leader goes up to the flag only where the
-- flag is `near` px off or more. (15 Oct, the proposal's Lines board: the
-- longest named line, 89 px, in 116 to 150 px of room on every print.)
local PRINT = { pad = { 4, 3, 4, 3 }, height = 21, bottom = 2, turn = { 0.2, 0.7 }, hand = 14, line = 17, edge = 6,
    flag = 9, near = 22 }
Slip.SLIP, Slip.PRINT = SLIP, PRINT

-- A number from a string, the same every time, text measured unbounded,
-- and a point of a slip turned about its middle (UI/Paper/Surface.lua).
local Surface = ns.UI.Surface
local Seed, Width, Turned = Surface.Seed, Surface.Width, Surface.Turned

-- How many duels a series was (flights counted).
local function Total(rec)
    local _, up, down = Duels.Score(rec)
    return up + down
end

-- The plate's one note, from its flags (plate.duelMarks: { x, y on the
-- card, list of moments, at = { x, y } on the page }): the series with
-- the most duels, the latest of equals (`rec`), its flag on the page
-- (`mark`, where its leader goes) and on the card (`x`, `y`), and every
-- series on the plate (`recs`, oldest first). Nil without a duel.
function Slip.Choose(marks)
    local recs, best, most, at = {}, nil, nil, nil
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local rec = m.duel
            if rec then
                recs[#recs + 1] = rec
            end
            if rec and not rec.customOf then
                local n = Total(rec)
                if not best or n > most or (n == most and (rec.t or 0) >= (best.t or 0)) then
                    best, most, at = rec, n, mark
                end
            end
        end
    end
    if not best then return nil end
    table.sort(recs, function(a, b) return (a.t or 0) < (b.t or 0) end)
    return { rec = best, recs = recs, mark = at.at, x = at.x, y = at.y }
end

-- The series on a plate the player changed or wrote, as Choose gives one, each
-- for a note of its own, the newest first: where the margin runs out, the oldest
-- are the ones left to their flags.
function Slip.Customs(marks)
    local list = {}
    for _, mark in ipairs(marks or {}) do
        for _, m in ipairs(mark.list or {}) do
            local rec = m.duel
            if rec and rec.customOf then
                list[#list + 1] = { rec = rec, recs = { rec }, mark = mark.at, x = mark.x, y = mark.y }
            end
        end
    end
    table.sort(list, function(a, b) return (a.rec.t or 0) > (b.rec.t or 0) end)
    return list
end

-- Whether `rec` is the one the print's slip tells.
local function OnPrint(plate, rec)
    return plate.duelPrint ~= nil and plate.duelPrint.rec == rec
end

-- The notes the player's own series want in the margin: all but the print's.
local function CustomNotes(plate)
    local items = {}
    for _, chosen in ipairs(plate.customDuels or {}) do
        if not OnPrint(plate, chosen.rec) then
            items[#items + 1] = { duel = chosen, top = chosen.mark[2], x = chosen.mark[1] }
        end
    end
    return items
end

-- The tooltip of the chosen series, the flag's (Duels.Tip), as a list.
local function TipOf(chosen, now)
    local title, lines = Duels.Tip(chosen.rec, now)
    return Style.TipList(title, lines)
end

--------------------------------------------------------------------------
-- In the margin, and under a light plate's caption
--------------------------------------------------------------------------

-- The slip as a card on the strip (UI/Paper/Strip.lua's hooks): its words,
-- named where the name fits the column, else nameless; `overfull` where
-- even those are wider (it does not wrap or shrink, so the page leaves it
-- off).
local CARD = {
    plan = function(slip, note, width)
        local l, _, r = slip:Pad()
        local text, rec = slip.name, slip.series.rec
        local function Fits(words)
            text:SetText(words)
            note.name = words
            return Width(text) + 2 + l + r <= width
        end
        slip.overfull = not (Fits(Duels.Note(rec, true)) or Fits(Duels.Note(rec, false)))
    end,
}

-- A slip on `parent`. slip:SetDuel(chosen, seed, now), then
-- slip:Layout(x, y, width) as a strip's (CARD).
function Slip.New(parent)
    local slip = ns.UI.PaperStrip(parent, CARD)
    slip.name:SetFont(SLIP.file, SLIP.size, "")

    function slip:SetDuel(chosen, seed, now)
        self.series = chosen
        local rand = ns.UI.Pen.Random(Seed(seed .. ":tape"))
        local T = SLIP.tape
        self:SetNote({ name = Duels.Note(chosen.rec, true), strong = true, seed = seed, turn = SLIP.turn,
            tip = function() return TipOf(chosen, now) end,
            tapeAt = { x = T.x, y = T.y, w = T.w, h = T.h, slant = T.slant[1] + (T.slant[2] - T.slant[1]) * rand() } })
    end

    -- The words as written (for the tests).
    function slip:Words() return self.name:GetText() end

    return slip
end

--------------------------------------------------------------------------
-- On a light plate's print
--------------------------------------------------------------------------

-- Where the slip may lie along a print's foot (`slot`, the page's LAYOUT):
-- from past its lower-left photo corner to short of the lower-right one,
-- or PRINT.edge px from the print's edge where a corner has none. Its left
-- and right, from the card's left. (Good luck's rule, LuckyCard.PrintRoom.)
function Slip.PrintRoom(slot)
    local has = {}
    for _, corner in ipairs(slot.corners or {}) do has[corner] = true end
    local left = has.bl and (slot.pc or 0) + 2 or PRINT.edge
    local right = has.br and slot.w - (slot.pc or 0) - 2 or slot.w - PRINT.edge
    return left, right
end

-- A hidden font string in the hand at PRINT.hand, to measure the words
-- before they are drawn.
local probe
local function Hand(text)
    text:SetFontObject(Style.FONT.noteWritten)
    text:SetFont(SLIP.file, PRINT.hand, "")
end
local function Probe()
    if not probe then
        probe = Style.Text(UIParent, Style.FONT.noteWritten)
        probe:Hide()
    end
    Hand(probe)
    return probe
end

-- The slip for series `rec` in `room` px along the foot: the first of its
-- words (named, then nameless) that fits, { words, w (the words'), Wb, Hb
-- (the slip's) }, or nil.
function Slip.PrintPlan(rec, room)
    local p, P = Probe(), PRINT
    for _, named in ipairs({ true, false }) do
        local words = Duels.Note(rec, named)
        p:SetText(words)
        local w = Width(p) + 2
        local Wb = math.ceil(P.pad[1] + w + P.pad[3])
        if Wb <= room then return { words = words, w = w, Wb = Wb, Hb = P.height } end
    end
    return nil
end

-- The slip drawn on a print through the pass's toolkit, `kit`: { Place
-- (K.Place), Texture(part), Text(part) }, the parts from the plate's pools
-- (PRINT_LAYERS, PRINT_TEXTS below). `chosen` is Slip.Choose's (x, y: its
-- flag on the card), `slot` the print's, `seed` a string, `flat` laid
-- flat. Nil where it will not fit (the margin, then the caption, has it);
-- else, all on the card: { plan, left, top, label (its four corners), edge
-- (its top edge, two points, for its leader), hit ({ x, y, w, h }: the
-- mouse's square), flag }.
function Slip.Print(kit, chosen, slot, seed, flat)
    local LOOK = ns.UI.PAPER_LOOK
    local left0, right0 = Slip.PrintRoom(slot)
    local plan = Slip.PrintPlan(chosen.rec, right0 - left0)
    if not plan then return nil end
    local P = PRINT
    local top = slot.h - P.bottom - plan.Hb
    local left = left0
    -- At the foot's right end only where its flag lies under it.
    local flag = chosen.x and { chosen.x, chosen.y } or nil
    if flag and flag[1] > left - P.flag and flag[1] < left + plan.Wb + P.flag and flag[2] > top - P.flag then
        left = right0 - plan.Wb
    end

    local rand = ns.UI.Pen.Random(Seed(seed))
    local sign = rand() < 0.5 and -1 or 1
    local a = flat and 0 or sign * math.rad(P.turn[1] + (P.turn[2] - P.turn[1]) * rand())
    local INK, INK_STRONG = Style.INK, Style.INK_STRONG
    local c, s = math.cos(a), math.sin(a)
    local Lx, Ly = left + plan.Wb / 2, top + plan.Hb / 2
    -- A point of the slip (u, v from its middle, y down) on the card.
    local function To(u, v) return Turned(Lx, Ly, u, v, c, s) end
    local function Put(region, x, y, w, h, dx, dy)
        kit.Place(region, x - w / 2, y - h / 2, w, h, a, dx, dy)
        region:Show()
        return region
    end
    local function Colour(part, colour, alpha)
        local texture = kit.Texture(part)
        texture:SetColorTexture(colour[1], colour[2], colour[3], alpha)
        if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, 1) end
        return texture
    end

    -- Glued on the print: its contact shadow, its cut edge, its stock.
    if not flat then
        local sh = LOOK.shadow
        Put(Colour("shadow", INK, sh[3]), Lx, Ly, plan.Wb, plan.Hb, sh[1], -sh[2])
    end
    Put(Colour("edge", INK, flat and LOOK.flatEdge or LOOK.edge), Lx, Ly, plan.Wb + 2, plan.Hb + 2)
    Put(Colour("paper", LOOK.paper, 1), Lx, Ly, plan.Wb, plan.Hb)
    -- The words, from its left margin, on the middle of its writing.
    local text = kit.Text("words")
    Hand(text)
    text:SetText(plan.words)
    text:SetTextColor(INK_STRONG[1], INK_STRONG[2], INK_STRONG[3])
    local mid = P.pad[2] + (plan.Hb - P.pad[2] - P.pad[4]) / 2
    local tx, ty = To(P.pad[1] + plan.w / 2 - plan.Wb / 2, mid - plan.Hb / 2)
    Put(text, tx, ty, plan.w, P.line)

    local corners = {}
    for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local x, y = To(k[1] * plan.Wb / 2, k[2] * plan.Hb / 2)
        corners[#corners + 1] = { x, y }
    end
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, pt in ipairs(corners) do
        x0, y0, x1, y1 = math.min(x0, pt[1]), math.min(y0, pt[2]), math.max(x1, pt[1]), math.max(y1, pt[2])
    end
    local e1x, e1y = To(-plan.Wb / 2 + 10, -plan.Hb / 2)
    local e2x, e2y = To(plan.Wb / 2 - 10, -plan.Hb / 2)
    return { plan = plan, words = plan.words, left = left, top = top, label = corners,
        edge = { { e1x, e1y }, { e2x, e2y } }, hit = { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }, flag = flag }
end

--------------------------------------------------------------------------
-- In the plate's margin (JourneyMargin.Register)
--------------------------------------------------------------------------

-- The note in the plates' margin: one, order 85, after the people only
-- seen (80), before the campfire (90): filler (the user, 15 Oct), so it
-- is the second left off, after the fire, and the caption's words say it
-- then (`said.duel`), unless that would cost the caption its place over
-- the plate or run it past its foot (plate.duelTold false then: the flag
-- alone tells it). On a light plate it is on the print where the pass
-- below drew it (plate.duelPrint: not in the margin, counted as written,
-- a short leader up to its flag where the flag is not beside it); else
-- under the light plate's caption, as the campfire's slip is, where there
-- is room (LF, LFF, LFL, FLF, FFL with the route kept; never under FL's
-- print, whose caption starts at y 474). The layouts stay as they are for
-- it: a note left off F+L's row costs the page its F+L, as the campfire's
-- does (the user, 15 Oct). Its leader goes to its series' flag.
ns.UI.JourneyMargin.Register("duel", {
    order = 85, pool = "duelPool", count = "duelsWritten", filler = true, flag = "duelTold",
    counted = function(shown, plate)
        return (shown[1] or (plate.duel and OnPrint(plate, plate.duel.rec))) and 1 or 0
    end,
    new = function(parent) return Slip.New(parent) end,
    item = function(plate)
        local d = plate.duel
        if not d or OnPrint(plate, d.rec) then return nil end
        return { duel = d, top = d.mark[2], x = d.mark[1] }
    end,
    write = function(slip, it, c)
        slip:SetDuel(it.duel, c.Seed("duel", it.duel.rec.t or 0), c.now)
    end,
    mark = function(it) return it.duel.mark end,
    custom = function(it) return "duel", it.duel.rec end,
    say = function(said, shown, plate)
        if plate.duel and not OnPrint(plate, plate.duel.rec) and not shown[1] then said.duel = true end
    end,
    after = function(plate, c)
        local s = plate.duelPrint
        if s and s.far then c.Leader(s, s.mark) end
    end,
})

-- The series the player changed or wrote, a note each, past the plate's one
-- (Slip.Choose), at the order the custom cards were given
-- (.claude/features/custom-cards.md): well ahead of the filler the automatic note
-- is, as a card someone just wrote reads as a bug if it is first to go. The same
-- slip, the same pool. Where one still finds no room the caption's words say a
-- duel; this is no filler, so those words are kept even at the foot, as a close
-- call's are.
ns.UI.JourneyMargin.Register("duelCustom", {
    order = 8.5, pool = "duelPool", count = "customDuelsWritten",
    counted = function(shown, plate)
        local printed = plate.duelPrint and plate.duelPrint.rec.customOf and 1 or 0
        return #shown + printed
    end,
    new = function(parent) return Slip.New(parent) end,
    items = CustomNotes,
    write = function(slip, it, c)
        slip:SetDuel(it.duel, c.Seed("duel", it.duel.rec.t or 0), c.now)
    end,
    mark = function(it) return it.duel.mark end,
    custom = function(it) return "duel", it.duel.rec end,
    say = function(said, shown, plate)
        if #shown < #CustomNotes(plate) then said.duel = true end
    end,
})

--------------------------------------------------------------------------
-- On the print, drawn on the plate (Plate.RegisterPass)
--------------------------------------------------------------------------

-- The slip's parts, from the print up, on the frame over the picture
-- (between the neat line and the lifted corner's shade, so it slopes away
-- from the light with the print): its shadow, its cut edge, its stock,
-- the words.
local PRINT_LAYERS = { shadow = { "ARTWORK", 4 }, edge = { "ARTWORK", 5 }, paper = { "ARTWORK", 6 } }
local PRINT_TEXTS = { words = { "ARTWORK", 7 } }

-- Each plate's toolkit for it (made by the pass's `new`), by plate.
local kits = setmetatable({}, { __mode = "k" })

-- The pass, after good luck's S (90), which keeps the print where both
-- are there: on a light plate's slot (a snapshot or the tucked print), the
-- plate's duel (plate.duel, the flags' `chosen`) on a slip across the
-- print's foot, drawn through the card's toolkit so it turns and lies with
-- the print. plate.duelPrint says where it went (for the margin: not
-- there, counted; a leader up to the flag where the flag is far) or is nil
-- where it did not go, and the margin has it. The mouse over it
-- (plate.duelHit, a square button round it as drawn, on the frame over the
-- picture): its series' tooltip; a press on it is a press on the plate.
ns.UI.JourneyPlate.RegisterPass("duelPrint", {
    order = 95,
    new = function(plate, kit)
        local pools, texts = {}, {}
        for part, at in pairs(PRINT_LAYERS) do pools[part] = kit.Pool(at[1], at[2]) end
        for part, at in pairs(PRINT_TEXTS) do texts[part] = kit.TextPool(Style.FONT.noteWritten, at[1], at[2]) end
        plate.duelHit = kit.Button()
        -- A right click on the slip is one on its flag: the form for its series.
        -- The kit's button knows no mark, and would offer the map's menu.
        plate.duelHit:SetScript("OnMouseUp", function(_, which)
            plate:Release(which)
            if which == "RightButton" then
                local s = plate.duelPrint
                plate:Right(s and { kind = "duel", list = { { kind = "duel", duel = s.rec } } } or nil)
            end
        end)
        Style.Tooltip(plate.duelHit, function()
            local s = plate.duelPrint
            return s and kit.Tip(Duels.Tip(s.rec, s.now))
        end)
        kits[plate] = { over = kit.over, PlaceButton = kit.PlaceButton,
            print = { Place = kit.Place,
                Texture = function(part) return pools[part]:Next() end,
                Text = function(part) return texts[part]:Next() end } }
    end,
    draw = function(plate, c)
        local k = kits[plate]
        if not k then return end
        plate.duelPrint = nil
        plate.duelHit:Hide()
        -- The player's newest ahead of the plate's one: a plate may have no
        -- margin to give it.
        plate.customDuels = Slip.Customs(plate.duelMarks)
        local chosen, slot = plate.customDuels[1] or plate.duel, plate.slot
        if not (chosen and slot and slot.light) or plate.print then return end
        local entry, OnPage = c.entry, c.OnPage
        local seed = table.concat({ "duel", chosen.rec.t or 0, plate.mapID or 0,
            entry and (entry.level or entry.week) or 0 }, ":") .. ":print"
        local s = Slip.Print(k.print, chosen, slot, seed, plate.flat)
        if not s then return end
        local hit = s.hit
        k.PlaceButton(plate.duelHit, hit.x, hit.y, hit.w, hit.h)
        plate.duelHit:SetFrameLevel(k.over:GetFrameLevel() + 1)
        plate.duelHit:Show()
        -- On the page: its corners, its top edge, and whether the flag is
        -- far enough off to need a leader (PRINT.near).
        local function Page(list)
            local out = {}
            for i, p in ipairs(list) do out[i] = { OnPage(p[1], p[2]) } end
            return out
        end
        local edge = Page(s.edge)
        local far = false
        if s.flag then
            local ex = math.max(s.edge[1][1], math.min(s.edge[2][1], s.flag[1]))
            far = math.sqrt((s.flag[1] - ex) ^ 2 + (s.flag[2] - s.top) ^ 2) >= PRINT.near
        end
        local polys = { label = Page(s.label) }
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, p in ipairs(polys.label) do
            x0, y0, x1, y1 = math.min(x0, p[1]), math.min(y0, p[2]), math.max(x1, p[1]), math.max(y1, p[2])
        end
        plate.duelPrint = { rec = chosen.rec, now = c.now, words = s.words, s = s, mark = chosen.mark, far = far,
            polys = polys, box = { x0, y0, x1 - x0, y1 - y0 }, plate = plate }
        -- A leader's way off it (UI/Journey/Leaders.lua's Aim): the point of
        -- its top edge nearest the mark, on the page.
        function plate.duelPrint:Nearest(x, y)
            local ax, ay, bx, by = edge[1][1], edge[1][2], edge[2][1], edge[2][2]
            local dx, dy = bx - ax, by - ay
            local t = ((x - ax) * dx + (y - ay) * dy) / math.max(dx * dx + dy * dy, 1e-6)
            t = math.max(0, math.min(1, t))
            return ax + dx * t, ay + dy * t
        end
        function plate.duelPrint:IsShown() return plate:IsShown() end
    end,
})
