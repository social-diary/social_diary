-- A run's margin notes (MAP-13, MAP-15), laid on its map (the table
-- spread's step 2, UI/Dungeon/Sheet.lua): paper strips lying on the folded
-- sheet near what each is about, a pencil leader to it: a boss's face
-- ("Wiped once", "Killed on the third try", an item that dropped there for
-- you or for someone in the diary), the way in ("Ran back once", "as a
-- ghost"), or where a wipe on the way happened. The strips are
-- ns.UI.PaperStrip's, as the plates' margin notes are (UI/Journey/
-- Margin.lua); the leaders are drawn with the pen, as the plates' are
-- (UI/Journey/Leaders.lua), but on the sheet, through its toolkit, so
-- they fold and take the light with it.
--
-- Chosen, not dumped (MAP-15): wipes first, then near wipes, then loot
-- for you and the diary's people, then tries, then the runs back; at most NOTES.most, the
-- rest counted ("and 2 more", in pencil by the floors' label; told in
-- the bosses' tooltips too). A stranger's loot is never a note. Only notes
-- about something on the floor shown appear; another floor lays its own.
--
-- Each is laid in the order chosen, the first free place taken (PLACE):
-- round its mark at a heading and a distance, kept off the faces, the
-- numbers, the crosses and the way in, off the strips laid before it, the
-- floors' label and the count, off the inked way and the map's own title
-- (the top middle of drawn and client art) where it can be (the way still
-- to go may be covered); never across a valley of the fold, clear of it:
-- a strip is stiff, and laid across a valley it would stand off the
-- paper. Across a ridge it rests on the crest, so a strip too long for a
-- panel (two items' names) may lie there, at a cost. A strip may stick
-- out past the paper's edge (the user, 16 Oct), its shadow falling on the
-- book or the table, so long as its tape and a third of it lie on the
-- paper and it stays on the screen; places along each edge, half on the
-- paper, are tried with the rest, which moves strips off a crowded middle.
-- Nowhere at all, it is counted with the rest. A strip lies turned a little its own way
-- over the sheet's turn (the strip's `tilt`), so its square button still
-- covers it; it does not fold. A strip close to its mark has a small
-- pencil tick toward it instead of an arrow (LEADER.tick).

local addonName, ns = ...

local Style = ns.Style
local DungeonPage = ns.UI.DungeonPage
local Surface = ns.UI.Surface

-- At most `most` notes on a sheet (seven on the bigger sheet: the real
-- run's shape, four kills, a boss wipe, a wipe on the way, two runs back
-- and loot for you and two diary people, is six); at most `items` items
-- named on one boss's loot strip; a strip at most `width` px wide (the
-- old page's column), wider only for a heading that needs it (a strip's
-- heading is one line: two or three items' names), to `wide` at most.
local NOTES = { most = 7, items = 3, width = 210, wide = 320 }
-- Where a strip may lie: its nearest edge `gap` px (each in turn) from its
-- mark's edge, at each of `headings` (degrees, y down: right, left, the
-- lower and the upper diagonals, under, over), the first in this order
-- free (a place across a ridge counts `ridge` more), each also slid
-- sideways by each of `slide` (a share of the strip's own length that way,
-- so a long strip can find the middle of a panel); kept `clear` px off a
-- mark's halo, `apart` px off another strip, `fold` px off a fold. Along
-- each edge of the paper, every `step` px, sticking out by each of `out`
-- (a share of the strip's depth across that edge). At least `third` of a
-- strip lies on the paper, its tape `tape` px inside it, and all of it
-- `screen` px inside the screen. A strip lies turned up to `jitter`
-- degrees its own way over the sheet. The inked way is kept off where it
-- can be: a place over it counts `route` more than its distance; over the
-- map's own title (`banner`: the top `top` of the art, its middle `wide`
-- across), `banner.cost` more.
local PLACE = { gap = { 12, 30, 52, 76 }, headings = { 0, 180, 35, 145, -35, -145, 90, -90 },
    slide = { 0, -0.25, 0.25, -0.45, 0.45, -0.7, 0.7, -0.95, 0.95 }, clear = 4, apart = 6, fold = 14, step = 22,
    out = { 0.2, 0.45 }, third = 1 / 3, tape = 3, screen = 4, jitter = 1.2, route = 1000, ridge = 60,
    banner = { top = 0.12, wide = 0.5, cost = 300 } }
-- Where a strip's tape lies on it, about (UI/Paper/Strip.lua's TAPE: its
-- middle `at` of the way along the top, never nearer an end than `inset`
-- px, `w` by `h`), for keeping it on the paper.
local TAPE = { at = 0.16, inset = 16, w = 28, h = 11 }
-- A leader: chalk (UI/Dungeon/Print.lua's CHALK: a cream close to the
-- strips' paper, over a faint dark stroke) `width` px at `alpha`, thinning toward the
-- strip to `taper` of itself over `over` px, bowed by `bow` of its length;
-- it stops `gap` px short of its mark's edge, in an arrowhead `head`
-- (length, width) px. Resampled every `step` px, at most `budget` pieces.
-- A strip whose edge lies within `tick.near` px of its mark's has a tick
-- instead: a pencil stroke `tick.length` px from the strip toward it.
local LEADER = { colour = DungeonPage.CHALK.colour, width = 1.4, alpha = 0.92, taper = 0.55, over = 14, bow = 0.04,
    gap = 3, head = { 7, 5.5 }, step = 3, budget = 240, tick = { near = 30, length = 7 } }
-- The count of the rest: pencil, its right end `inset` px in from the
-- paper's right edge, `over` px above the floors' label (or the paper's
-- foot), its room kept free `w` by `h` px.
local MORE = { inset = 18, over = 12, w = 80, h = 14 }
-- A loot strip whose drop for you was rare is underlined once under its
-- heading, an epic's twice (and tacked, not taped: the strip's `tack`):
-- ink at `alpha`, `width` px, the second `gap` px under the first and
-- `short` of its length, each a hair off level (`tilt`, radians).
local RULE = { alpha = 0.85, width = { 1.2, 1 }, gap = 2.4, short = 0.82, under = 0.5, tilt = { 0.012, -0.015 } }
DungeonPage.NOTES, DungeonPage.LEADER, DungeonPage.PLACE, DungeonPage.MORE = NOTES, LEADER, PLACE, MORE
DungeonPage.RULE = RULE
-- A pair (an item snagged from you, one that finally came): the second
-- strip lies on the first's bottom right corner, its left `x` of the way
-- across it, turned `turn` degrees with the clock from it (so its left
-- end, over the first, is its higher), its highest corner
-- `clear` px under the first's writing: it lies on the first's margin
-- only, and both read whole (16 Oct, in the client: half way down, it hid
-- the first's "dropped for you"). The two laid as one, `pad` px round
-- them.
local PAIR = { x = 0.4, turn = 3, clear = 1, pad = 6 }
-- The first, where the item was snagged, is struck out in ink (STRIKE): a
-- stroke across each line it says, `width` px at `alpha`, `over` px past
-- its ends, in `pieces` a little off line (`wobble` px), still readable
-- under it.
local STRIKE = { width = 1.4, alpha = 0.72, over = 3, pieces = 3, wobble = 0.8 }
DungeonPage.PAIR, DungeonPage.STRIKE = PAIR, STRIKE

--------------------------------------------------------------------------
-- What to say
--------------------------------------------------------------------------

-- How the user's own loot among `items` stands out: "epic" (purple or
-- better), "rare" (blue), or nil (the quality from the item's link).
function DungeonPage.Tier(items)
    local best = 0
    for _, it in ipairs(items or {}) do
        if it.mine and (it.quality or 0) > best then best = it.quality end
    end
    return best >= 4 and "epic" or best == 3 and "rare" or nil
end

-- The notes worth a strip, in the order they are chosen: { rank, kind
-- ("wipe", "wayWipe", "near", "wayNear", "snagged", "finally", "loot",
-- "bad", "tries", "ranBack"), boss (or door = true,
-- or wipe = its index in notes.wipes), name, what, guid (a diary entry to
-- open, not the page's own person), items, seed }. A boss's loot for you
-- and the diary's people is one note, its items in its heading (MAP-13:
-- one leader a boss): `items` = { { item, guid (theirs to open, or nil),
-- line (for whom, for its tooltip), from, text (its piece of the
-- heading) } }, at most NOTES.items of them. The wipes, at a boss and on
-- the way (MAP-17), come first, in the order they happened.
-- The rolls (pass B, `notes.rolls`: ns.DungeonRun.Rolls(visit)): an item
-- snagged from you and one that finally came to you are a pair, ahead of
-- the plain loot: your loot strip for the item ("dropped for you"), and a
-- second strip on it (`top` = { name, what, guid }), the first scribbled
-- out where it was snagged (`struck`); that item leaves the plain loot
-- strips. A bad roll comes after the loot. A roll's note lies at its boss,
-- or where on the way it dropped (`when`, its time).
-- `notes` are ns.DungeonRun.Notes(visit); `guid` the page's person.
function DungeonPage.Choose(visit, notes, guid)
    local Words = DungeonPage.Words
    local list = {}
    local function Add(note)
        note.seed = table.concat({ visit.id or 0, note.kind, note.boss and note.boss.name or "door", #list }, ":")
        list[#list + 1] = note
    end
    local function FirstDeath(deaths)
        local first
        for _, d in ipairs(deaths or {}) do first = math.min(first or d.time, d.time) end
        return first
    end
    -- A diary entry's page to open from their name: not the page's own.
    local function Opens(who) return who ~= guid and ns.Diary.IsDiary(who) and who or nil end

    -- The rolls' notes (pass B), and the items their pairs take from the
    -- plain loot.
    local rolls, paired = notes.rolls or {}, {}
    local me = visit.me or ns.ownGUID
    local function Pair(kind, item, boss, time, top, struck)
        local mineItem = { item = item, mine = true, quality = ns.Timeline.Quality(item),
            line = Words.Capital(Words.Dropped(visit, me)), from = "", text = Style.Inkify(item or "?") }
        Add({ rank = 1.8, order = time or 0, kind = kind, boss = boss, when = not boss and time or nil,
            items = { mineItem }, name = mineItem.text, what = Words.Dropped(visit, me),
            tier = DungeonPage.Tier({ mineItem }), top = top, struck = struck })
    end
    for _, sn in ipairs(rolls.snagged or {}) do
        paired[sn.drop.itemID or -1] = true
        local name, mark = Words.Snagged(visit, sn.winner)
        Pair("snagged", sn.drop.item, sn.boss, sn.drop.time, { name = name, mark = mark,
            what = Words.Versus(sn.mine, sn.theirs), guid = Opens(sn.winner) }, true)
    end
    for _, g in ipairs(rolls.finally or {}) do
        paired[g.itemID or -1] = true
        local name, mark = Words.Finally(g.total)
        Pair("finally", g.item, g.boss, g.time, { name = name, mark = mark }, false)
    end
    for _, b in ipairs(rolls.bad or {}) do
        Add({ rank = 2.5, order = (b.drop.time or 0) + b.roll / 1000, kind = "bad", boss = b.boss,
            when = not b.boss and b.drop.time or nil, name = Words.Rolled(visit, b.guid, b.roll),
            what = Words.OnItem(b.drop.item), guid = Opens(b.guid) })
    end
    for i, e in ipairs(notes.bosses or {}) do
        if (e.wipes or 0) > 0 then
            Add({ rank = 1, order = FirstDeath(e.deaths) or e.at or math.huge, kind = "wipe", boss = e.boss,
                name = Words.Wipes(e.wipes),
                what = e.killed and Words.KilledOn(e.tries) or (not e.killed and Words.STANDING) or nil })
        end
        local items, links, guids, seen, owner, first = {}, {}, {}, {}, nil, nil
        for _, entry in ipairs(e.loot or {}) do
            if Words.Noted(visit, entry.guid) and #items < NOTES.items and not paired[entry.itemID] then
                local diary = entry.guid ~= guid and ns.Diary.IsDiary(entry.guid)
                local mine = entry.guid == ns.ownGUID or entry.guid == visit.me
                items[#items + 1] = { item = entry.item, guid = diary and entry.guid or nil,
                    line = Words.Capital(Words.Dropped(visit, entry.guid)), mine = mine,
                    quality = ns.Timeline.Quality(entry.item) }
                links[#links + 1] = Style.Inkify(entry.item or "?")
                if not seen[entry.guid] then
                    seen[entry.guid] = true
                    guids[#guids + 1] = entry.guid
                end
                owner = owner or (diary and entry.guid) or nil
                first = math.min(first or entry.time or 0, entry.time or 0)
            end
        end
        if #items > 0 then
            local heading, parts = Words.Items(links)
            for k, part in ipairs(parts) do items[k].from, items[k].text = part.from, part.text end
            Add({ rank = 2, order = first or i, kind = "loot", boss = e.boss, items = items, name = heading,
                what = Words.DroppedFor(visit, guids), guid = owner, tier = DungeonPage.Tier(items) })
        end
        if (e.near or 0) > 0 then
            Add({ rank = 1.5, order = FirstDeath(e.deaths) or e.at or math.huge, kind = "near", boss = e.boss,
                name = Words.NEARLY, what = Words.WentDown(e.nearDeaths or 2) })
        end
        if (e.wipes or 0) == 0 and (e.tries or 0) > 1 then
            local name = Words.Tries(e.tries, e.killed)
            if name then
                Add({ rank = 3, order = i, kind = "tries", boss = e.boss, name = name,
                    what = not e.killed and Words.STANDING or nil })
            end
        end
    end
    for i, w in ipairs(notes.wipes or {}) do
        Add({ rank = 1, order = FirstDeath(w.deaths) or 0, kind = "wayWipe", wipe = i, name = Words.WAY_WIPE,
            what = Words.WipedTo(visit, w) })
    end
    for i, w in ipairs(notes.near or {}) do
        Add({ rank = 1.5, order = FirstDeath(w.deaths) or 0, kind = "wayNear", near = i, name = Words.NEARLY,
            what = Words.WentDown(#w.deaths) })
    end
    if (notes.ranBack or 0) > 0 then
        Add({ rank = 4, order = 0, kind = "ranBack", door = true, name = Words.RanBack(notes.ranBack),
            what = Words.GHOST })
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)
    return list
end

--------------------------------------------------------------------------
-- The strips
--------------------------------------------------------------------------

local function ToPerson(guid)
    if guid then ns.UI.YourDiary.ToPerson(guid) end
end

-- A strip on `host` (a frame whose top left is the sheet's middle, so a
-- strip laid at x, y lies x, y from it on the screen, y down), and over
-- each item named on a loot strip a square of our own: the item's own
-- tooltip, for whom it dropped under it, and a click opens their page
-- where they are in the diary.
function DungeonPage.NewNote(host)
    local strip = ns.UI.PaperStrip(host)
    local note = { strip = strip }
    note.links = ns.UI.Pool.New(function()
        local hover = CreateFrame("Button", nil, host)
        hover:SetFrameLevel(strip:GetFrameLevel() + 5)
        hover:SetScript("OnEnter", function(self)
            strip:Hover(true)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local it = self.item
            local shown = it and it.item and type(GameTooltip.SetHyperlink) == "function"
                and pcall(GameTooltip.SetHyperlink, GameTooltip, it.item)
            if not shown then GameTooltip:SetText(it and it.text or "") end
            if it and it.line then GameTooltip:AddLine(it.line, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", function()
            strip:Hover(false)
            GameTooltip:Hide()
        end)
        hover:SetScript("OnClick", function(self) ToPerson(self.item and self.item.guid) end)
        return hover
    end)
    -- Its heading's underlines (RULE), on the strip, laid as it lies.
    note.rules = { strip:CreateTexture(nil, "ARTWORK", nil, 2), strip:CreateTexture(nil, "ARTWORK", nil, 2) }
    for _, rule in ipairs(note.rules) do rule:Hide() end
    -- Its strike-through, where its item was snagged (STRIKE).
    note.strikes = ns.UI.Pool.New(function()
        local t = strip:CreateTexture(nil, "OVERLAY", nil, 0)
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end)
    function note:Show() self.strip:Show() end
    function note:Hide()
        self.strip:Hide()
        for _, pool in ipairs({ self.links, self.strikes }) do
            pool:Begin()
            pool:Finish()
        end
    end
    return note
end

-- Over each item a loot strip names, its own square (NewNote's), as wide
-- as its link in the heading's hand, where the turned strip has it.
local function PlaceLinks(host, slot)
    slot.links:Begin()
    local items = slot.note.items
    if items then
        local strip, m = slot.strip, host.nameMeasure
        local l, t = strip:Pad()
        local W, H = strip.box[3], strip.box[4]
        local h = math.max(strip.name:GetStringHeight() or 0, 16)
        for _, it in ipairs(items) do
            m:SetText(it.from)
            local before = it.from ~= "" and m:GetStringWidth() or 0
            m:SetText(it.text)
            local w = math.max(m:GetStringWidth(), 8)
            local x, y = strip:Out(-W / 2 + l + before + w / 2, -H / 2 + t + h / 2)
            local hover = slot.links:Next()
            hover:SetFrameLevel(strip:GetFrameLevel() + 5)
            hover.item = it
            hover:ClearAllPoints()
            hover:SetPoint("CENTER", host, "TOPLEFT", x, -y)
            hover:SetSize(w, h)
        end
    end
    slot.links:Finish()
end

-- Sets `slot` (a note of the pool) to say `note`, lying at `tilt` degrees;
-- an epic's tacked (RULE).
-- Lit by the table's lamp, and shadowed from its height (UI/Dungeon/
-- Heights.lua): on the sheet, and on the world under it (`ground`, the
-- sheet's ground layer) where it sticks out past the paper.
local function Say(slot, note, tilt, ground)
    slot.note = note
    local tack = note.tier == "epic" or nil
    local shadow, soft, under = DungeonPage.StripShadows(tack, ground)
    slot.strip:SetNote({ name = note.name, what = note.what, guid = note.guid, onClick = ToPerson,
        strong = true, seed = note.seed, tilt = tilt, tack = tack, shadow = shadow, soft = soft, ground = under,
        light = true })
end

-- The heading's underlines (RULE): once for a rare drop for you, twice
-- for an epic, under the name as the strip lies; once under the part of
-- it a pair's second strip marks (`mark`: "Finally!", "Brom snagged it"),
-- measured in the name's own hand (`measure`).
local function Underline(slot, measure)
    local tier, mark = slot.note.tier, slot.note.mark
    local n = mark and 1 or tier == "epic" and 2 or tier == "rare" and 1 or 0
    local strip = slot.strip
    local l, t = strip:Pad()
    local W, H = strip.box[3], strip.box[4]
    local w = Surface.Width(strip.name)
    if mark and measure then
        measure:SetText(mark)
        w = math.min(w, Surface.Width(measure))
    end
    slot.underlineWidth = n > 0 and w or nil
    local h = strip.name:GetStringHeight() or 14
    local I = Style.INK_STRONG
    for k, rule in ipairs(slot.rules) do
        if k <= n then
            local length = w * (k == 1 and 1 or RULE.short)
            rule:SetColorTexture(I[1], I[2], I[3], RULE.alpha)
            strip:Lay(rule, -W / 2 + l + length / 2 + (k - 1) * w * 0.05, -H / 2 + t + h + RULE.under + (k - 1) * RULE.gap,
                length, RULE.width[k], RULE.tilt[k])
            rule:Show()
        else
            rule:Hide()
        end
    end
    slot.underlines = n
end

-- The first strip of a snagged item struck out by hand (STRIKE): a stroke
-- across its heading and each line under it, in a few pieces a little off
-- line, seeded; or none.
local function Strike(slot, struck)
    slot.strikes:Begin()
    if struck then
        local strip = slot.strip
        local l, t = strip:Pad()
        local W, H = strip.box[3], strip.box[4]
        local x0 = -W / 2 + l
        local U = ns.UI.Pen.Random(Surface.Seed(slot.note.seed .. ":strike"))
        local I = Style.INK_STRONG
        local function Across(y, w)
            local a, b = x0 - STRIKE.over, x0 + w + STRIKE.over
            local n = STRIKE.pieces
            local prevY = y + (U() - 0.5) * 2 * STRIKE.wobble
            for k = 1, n do
                local f0, f1 = (k - 1) / n, k / n
                local nextY = y + (U() - 0.5) * 2 * STRIKE.wobble
                local px0, px1 = a + (b - a) * f0, a + (b - a) * f1
                local piece = slot.strikes:Next()
                piece:SetColorTexture(I[1], I[2], I[3], STRIKE.alpha)
                local len = math.sqrt((px1 - px0) ^ 2 + (nextY - prevY) ^ 2)
                strip:Lay(piece, (px0 + px1) / 2, (prevY + nextY) / 2, len + 0.6, STRIKE.width,
                    -math.atan2(nextY - prevY, px1 - px0))
                prevY = nextY
            end
        end
        local nh = strip.name:GetStringHeight() or 14
        Across(-H / 2 + t + nh / 2, Surface.Width(strip.name))
        local y = -H / 2 + t + nh + 1
        for _, line in ipairs(strip:WhatLines()) do
            local lh = line:GetStringHeight() or 11
            Across(y + lh / 2, Surface.Width(line))
            y = y + lh
        end
    end
    slot.strikes:Finish()
end

-- A piece of chalk over four points of the sheet, and its faint dark
-- stroke (CHALK.under) offset under it; a stroke along its middle where
-- corners cannot move.
local function Twice(P, pool, under, c, a, x1, y1, x2, y2, x3, y3, x4, y4)
    local U = DungeonPage.CHALK.under
    for _, layer in ipairs({ { under, Style.INK, U.alpha, U.offset }, { pool, c, a, 0 } }) do
        local p, colour, alpha, o = layer[1], layer[2], layer[3], layer[4]
        if not P.Quad(p, colour, alpha, x1 + o, y1 + o, x2 + o, y2 + o, x3 + o, y3 + o, x4 + o, y4 + o) then
            P.Stroke(p, (x1 + x4) / 2 + o, (y1 + y4) / 2 + o, (x2 + x3) / 2 + o, (y2 + y3) / 2 + o, LEADER.width, colour, alpha)
        end
    end
end

-- The leader from `from` (the strip's edge, { x, y } on the sheet) to the
-- mark t ({ x, y, r }): a pencil line, bowed a little, ending in an
-- arrowhead `gap` short of the mark's edge, drawn through the sheet's
-- placer P (UI/Dungeon/Sheet.lua) from `pool`, its faint dark stroke from
-- `under`. Returns its tip, or nil when the strip lies too close to the
-- mark for one.
local function Leader(P, pool, under, from, t, bend)
    local Pen = ns.UI.Pen
    local dx, dy = t.x - from[1], t.y - from[2]
    local len = math.sqrt(dx * dx + dy * dy)
    local H = LEADER.head
    if len < t.r + LEADER.gap + H[1] + 4 then return nil end
    local ux, uy = dx / len, dy / len
    local tx, ty = t.x - ux * (t.r + LEADER.gap), t.y - uy * (t.r + LEADER.gap)
    local bx, by = tx - ux * H[1], ty - uy * H[1]
    local reach = len - t.r - LEADER.gap - H[1]
    local points = { from[1], from[2],
        from[1] + ux * reach / 2 - uy * reach * LEADER.bow * bend, from[2] + uy * reach / 2 + ux * reach * LEADER.bow * bend,
        bx, by }
    local L = Pen.Resample(Pen.Chaikin(points, 3), LEADER.step)
    if #L >= 2 then
        local prims = {}
        local function Half(i)
            local taper = LEADER.taper + (1 - LEADER.taper) * math.min(1, L[i].s / LEADER.over)
            return LEADER.width / 2 * taper
        end
        Pen.Stroke(prims, 0, L, Pen.Mitres(L), Half, function() return 0 end, function() return LEADER.alpha end,
            LEADER.colour, nil, LEADER.budget)
        for _, q in ipairs(prims) do
            Twice(P, pool, under, { q.r, q.g, q.b }, q.a, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4)
        end
    end
    -- The head: a filled triangle; two strokes where corners cannot move.
    local px, py = -uy * H[2] / 2, ux * H[2] / 2
    Twice(P, pool, under, LEADER.colour, LEADER.alpha, tx, ty, tx, ty, bx + px, by + py, bx - px, by - py)
    return tx, ty
end

-- A strip close to its mark: a short chalk tick from its edge toward it.
local function Tick(P, pool, under, from, t)
    local dx, dy = t.x - from[1], t.y - from[2]
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then return end
    local k = math.min(LEADER.tick.length, math.max(0, len - t.r - LEADER.gap)) / len
    local hx, hy = -dy / len * LEADER.width / 2, dx / len * LEADER.width / 2
    local ex, ey = from[1] + dx * k, from[2] + dy * k
    Twice(P, pool, under, LEADER.colour, LEADER.alpha, from[1] + hx, from[2] + hy, ex + hx, ey + hy, ex - hx, ey - hy,
        from[1] - hx, from[2] - hy)
end

DungeonPage.Say, DungeonPage.PlaceLinks, DungeonPage.Leader = Say, PlaceLinks, Leader

--------------------------------------------------------------------------
-- Where they lie
--------------------------------------------------------------------------

-- Whether the box b ({ x0, y0, x1, y1 }) comes within `pad` of the disc
-- at x, y of radius r.
local function NearDisc(b, x, y, r, pad)
    local cx, cy = math.max(b[1], math.min(b[3], x)), math.max(b[2], math.min(b[4], y))
    return (cx - x) ^ 2 + (cy - y) ^ 2 < (r + pad) ^ 2
end

-- Whether two boxes come within `pad` of each other.
local function NearBox(a, b, pad)
    return a[1] < b[3] + pad and b[1] < a[3] + pad and a[2] < b[4] + pad and b[2] < a[4] + pad
end

-- Whether the line from a to b passes within `pad` of the disc at x, y
-- of radius r.
local function CrossesDisc(a, b, x, y, r, pad)
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local l2 = dx * dx + dy * dy
    local t = l2 > 0 and math.max(0, math.min(1, ((x - a[1]) * dx + (y - a[2]) * dy) / l2)) or 0
    local px, py = a[1] + dx * t, a[2] + dy * t
    return (px - x) ^ 2 + (py - y) ^ 2 < (r + pad) ^ 2
end

-- A strip w by h lying with its middle at cx, cy of the sheet, turned j
-- (radians, as SetRotation) over it: its box on the sheet, and the point
-- of its edge nearest x, y.
local function Lying(cx, cy, w, h, j, tapeW)
    local c, s = math.cos(j), math.sin(j)
    local hx, hy = (w * math.abs(c) + h * math.abs(s)) / 2, (w * math.abs(s) + h * math.abs(c)) / 2
    local box = { cx - hx, cy - hy, cx + hx, cy + hy }
    -- Its tape's corners on the sheet.
    local tx = -w / 2 + math.max(TAPE.inset, TAPE.at * (tapeW or w))
    local tape = {}
    for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local px, py = Surface.Turned(cx, cy, tx + k[1] * TAPE.w / 2, -h / 2 + k[2] * TAPE.h / 2, c, s)
        tape[#tape + 1] = { px, py }
    end
    local function Nearest(x, y)
        local dx, dy = x - cx, y - cy
        local u, v = dx * c - dy * s, dx * s + dy * c
        local hw, hh = w / 2, h / 2
        u, v = math.max(-hw, math.min(hw, u)), math.max(-hh, math.min(hh, v))
        if math.abs(u) < hw and math.abs(v) < hh then
            if hw - math.abs(u) < hh - math.abs(v) then u = u < 0 and -hw or hw else v = v < 0 and -hh or hh end
        end
        return Surface.Turned(cx, cy, u, v, c, s)
    end
    return box, Nearest, tape
end

-- Whether a strip with box b and tape corners `tape` lies on the paper (W
-- by H) enough: a third of it, its tape `tape` px inside; and on the
-- screen (`screen`, as the spread says where it is: { w, h } of it and the
-- sheet's middle `lie` from its middle, all the spread's units; the sheet's
-- toolkit K turns a point of it onto the screen), where known.
local function OnPaper(b, tape, W, H, K, screen, lie)
    local ix = math.max(0, math.min(b[3], W) - math.max(b[1], 0))
    local iy = math.max(0, math.min(b[4], H) - math.max(b[2], 0))
    if ix * iy < PLACE.third * (b[3] - b[1]) * (b[4] - b[2]) - 1e-9 then return false end
    local m = PLACE.tape
    for _, p in ipairs(tape) do
        if p[1] < m or p[2] < m or p[1] > W - m or p[2] > H - m then return false end
    end
    if screen and lie then
        local hw, hh = screen.w / 2 - PLACE.screen, screen.h / 2 - PLACE.screen
        for _, p in ipairs({ { b[1], b[2] }, { b[3], b[2] }, { b[3], b[4] }, { b[1], b[4] } }) do
            local X, Y = K.Screen(p[1], p[2])
            X, Y = X + lie[1], Y + lie[2]
            if X < -hw or X > hw or Y < -hh or Y > hh then return false end
        end
    end
    return true
end

-- The marks a strip keeps off (`spots`, { x, y, r }: the faces, their
-- numbers, the crosses, the way in, each with its halo, and the moments
-- drawn round them), the faces a
-- leader never crosses, and the inked way's stretches.
local function Keep(plan)
    local spots, faces, ink = {}, {}, {}
    for _, mark in ipairs(plan.marks) do
        local t = plan.targets[mark.name]
        if t then
            spots[#spots + 1] = { x = t.x, y = t.y, r = math.max(t.r, DungeonPage.KILL.halo / 2) }
            faces[#faces + 1] = { x = t.x, y = t.y, r = t.r, name = mark.name }
        end
        if mark.number then
            spots[#spots + 1] = { x = mark.number.x, y = mark.number.y, r = DungeonPage.KILL.number.halo / 2 }
        end
    end
    for _, c in ipairs(plan.crosses or {}) do spots[#spots + 1] = { x = c.x, y = c.y, r = DungeonPage.DEATH.halo / 2 } end
    if plan.door then spots[#spots + 1] = { x = plan.door.x, y = plan.door.y, r = DungeonPage.KILL.halo / 2 } end
    -- The moments in the hand: a drop's loop, a scribble, the pen at rest,
    -- the blood, a level-up's star and its scrawl (Print.lua's Flavour).
    for _, f in ipairs(plan.flavour or {}) do spots[#spots + 1] = { x = f.x, y = f.y, r = f.r } end
    local path = plan.route and plan.path
    if path then
        for k = 2, path.reached or 0 do
            if path.pts[k - 1] and path.pts[k] and not path.route[k].pair then ink[#ink + 1] = { path.pts[k - 1], path.pts[k] } end
        end
    end
    return spots, faces, ink
end

-- How many stretches of the inked way pass over box b.
local function OverInk(b, ink)
    local n = 0
    for _, seg in ipairs(ink) do
        local a, c = seg[1], seg[2]
        local len = math.sqrt((c[1] - a[1]) ^ 2 + (c[2] - a[2]) ^ 2)
        local steps = math.max(1, math.floor(len / 4))
        for k = 0, steps do
            local x, y = a[1] + (c[1] - a[1]) * k / steps, a[2] + (c[2] - a[2]) * k / steps
            if x > b[1] and x < b[3] and y > b[2] and y < b[4] then
                n = n + 1
                break
            end
        end
    end
    return n
end

-- The folds across and down, each { at, sign } (1 a ridge, -1 a valley),
-- in order (UI/Paper/Sheet.lua's K.Lines).
local function Folds(K)
    local X, Y, folds = K.Lines()
    local xs, ys = {}, {}
    for k, f in pairs(folds.columns) do xs[#xs + 1] = { at = X[k], sign = f.sign } end
    for k, f in pairs(folds.rows) do ys[#ys + 1] = { at = Y[k], sign = f.sign } end
    table.sort(xs, function(a, b) return a.at < b.at end)
    table.sort(ys, function(a, b) return a.at < b.at end)
    return xs, ys
end

-- Whether box b lies clear of every valley by `fold` px, and how many
-- ridges it lies across (a ridge it does not lie across it keeps `fold`
-- px clear of too).
local function OnFolds(b, xs, ys)
    local ridges = 0
    for axis, list in ipairs({ xs, ys }) do
        local lo, hi = axis == 1 and b[1] or b[2], axis == 1 and b[3] or b[4]
        for _, f in ipairs(list) do
            if f.at > lo - PLACE.fold and f.at < hi + PLACE.fold then
                -- On the fold or too near it: only a ridge, lain across.
                if f.sign < 0 or f.at < lo + PLACE.fold or f.at > hi - PLACE.fold then return false end
                ridges = ridges + 1
            end
        end
    end
    return true, ridges
end

-- Where the note's strip, w by h turned j, lies for mark t: the free place
-- with the least cost (its distance, and PLACE.route for each stretch of
-- the inked way under it) round the mark, else along the paper's edge.
-- Returns its middle, its box and its nearest point to the mark, or nil.
local function Spot(t, w, h, j, ctx, tapeW)
    local best
    local function Try(cx, cy, cost, edge)
        local box, Nearest, tape = Lying(cx, cy, w, h, j, tapeW)
        if not OnPaper(box, tape, ctx.W, ctx.H, ctx.K, ctx.screen, ctx.lie) then return end
        local fits, ridges = OnFolds(box, ctx.xs, ctx.ys)
        if not fits then return end
        for _, s in ipairs(ctx.spots) do
            if NearDisc(box, s.x, s.y, s.r, PLACE.clear) then return end
        end
        for _, b in ipairs(ctx.taken) do
            if NearBox(box, b, PLACE.apart) then return end
        end
        local fx, fy = Nearest(t.x, t.y)
        for _, f in ipairs(ctx.faces) do
            if (f.x ~= t.x or f.y ~= t.y) and CrossesDisc({ fx, fy }, { t.x, t.y }, f.x, f.y, f.r, 2) then return end
        end
        cost = cost + PLACE.route * OverInk(box, ctx.ink) + PLACE.ridge * ridges
        if ctx.banner and box[1] < ctx.banner[3] and box[3] > ctx.banner[1] and box[2] < ctx.banner[4] then
            cost = cost + PLACE.banner.cost
        end
        if not best or cost < best.cost then
            best = { cost = cost, x = cx, y = cy, box = box, from = { fx, fy }, edge = edge, tape = tape }
        end
    end
    local c, s = math.cos(j), math.sin(j)
    local hx, hy = (w * math.abs(c) + h * math.abs(s)) / 2, (w * math.abs(s) + h * math.abs(c)) / 2
    for gi, gap in ipairs(PLACE.gap) do
        for hi, deg in ipairs(PLACE.headings) do
            local a = math.rad(deg)
            local ux, uy = math.cos(a), math.sin(a)
            local d = t.r + gap + math.abs(ux) * hx + math.abs(uy) * hy
            -- Slid along its side facing the mark: across for a strip
            -- over or under it, up and down for one beside it.
            local sx, sy = -uy, ux
            local along = math.abs(sx) * 2 * hx + math.abs(sy) * 2 * hy
            for si, k in ipairs(PLACE.slide) do
                Try(t.x + ux * d + sx * along * k, t.y + uy * d + sy * along * k, gap + gi + hi * 0.01 + si * 4)
            end
        end
    end
    -- Along each edge of the paper, sticking out past it: as good as any,
    -- by the length of its leader.
    local W, H = ctx.W, ctx.H
    local function Far(cx, cy)
        local _, Nearest = Lying(cx, cy, w, h, j)
        local fx, fy = Nearest(t.x, t.y)
        return math.sqrt((fx - t.x) ^ 2 + (fy - t.y) ^ 2) - t.r
    end
    for _, o in ipairs(PLACE.out) do
        -- Its middle this far in from the edge: its half depth, less what
        -- sticks out.
        local inX, inY = hx - o * 2 * hx, hy - o * 2 * hy
        for x = 0, W, PLACE.step do
            Try(x, inY, Far(x, inY), true)
            Try(x, H - inY, Far(x, H - inY), true)
        end
        for y = 0, H, PLACE.step do
            Try(inX, y, Far(inX, y), true)
            Try(W - inX, y, Far(W - inX, y), true)
        end
    end
    return best
end

-- The mark a note is about, on the floor shown (plan.targets), or nil.
local function Target(plan, note)
    if note.when and not note.boss then return DungeonPage.Anchor(plan, note.when) end
    local t = plan.targets
    return (note.door and t.door) or (note.wipe and t["wipe:" .. note.wipe]) or (note.near and t["near:" .. note.near])
        or (note.boss and t[note.boss.name]) or nil
end

-- Lays the run's notes on the map sheet `view` (UI/Dungeon/Sheet.lua: its
-- notes' host and pool, its leaders' pool, its size and its floors'
-- label), for `plan` as inked (UI/Dungeon/Print.lua), through its placer P
-- and toolkit K. Kept for the tests: view.noteStrips ({ note, strip, box
-- (on the sheet), middle, target, from, tip (the arrow's, or nil),
-- leader ("arrow" or "tick"), edge (along the paper's edge), tape (its
-- corners on the sheet) }), view.notesMore,
-- view.notesAbout (how many were about this floor).
function DungeonPage.LayNotes(view, plan, P, K)
    local W, H = view.w, view.h
    local list = DungeonPage.Choose(plan.visit, plan.notes, view.guid)
    local about = {}
    for _, note in ipairs(list) do
        local t = Target(plan, note)
        if t then about[#about + 1] = { note = note, t = t } end
    end
    view.notesAbout = #about

    -- What is kept free before any strip: the marks, the label, the count.
    local spots, faces, ink = Keep(plan)
    local xs, ys = Folds(K)
    local taken = {}
    if view.labelBox then taken[#taken + 1] = view.labelBox end
    -- The party's cards in their stack over the map's edge (UI/Dungeon/
    -- Cards.lua).
    if view.stack then taken[#taken + 1] = view.stack.keep end
    -- The pencil's slip over its top edge (UI/Dungeon/Way.lua).
    if view.wayKeep then taken[#taken + 1] = view.wayKeep end
    local moreY = (view.labelBox and view.labelBox[2] or H - MORE.inset) - MORE.over
    local moreBox = { W - MORE.inset - MORE.w, moreY - MORE.h / 2, W - MORE.inset, moreY + MORE.h / 2 }
    taken[#taken + 1] = moreBox
    local ctx = { spots = spots, faces = faces, ink = ink, xs = xs, ys = ys, taken = taken, W = W, H = H, K = K,
        screen = view.screen, lie = view.lie }
    -- The map's own title, where drawn and client art print it.
    local f = plan.floor
    if f and not (f.yards or f.combined) then
        local B = PLACE.banner
        ctx.banner = { W * (1 - B.wide) / 2, 0, W * (1 + B.wide) / 2, H * B.top }
    end

    -- The sheet's own turn, and where the strips' frame has it: a strip
    -- that cannot turn (laid flat, or text that cannot) lies straight on it.
    local flat = ns.Setting("flatSheets") == true
    local angle = view.angle or 0

    view.notes:Begin()
    view.leaders:Begin()
    view.leaderUnder:Begin()
    view.noteStrips = {}
    local shown = 0
    local host = view.notesHost
    -- As wide as a heading needs, within reason.
    local function Width(slot, name)
        local m = host.nameMeasure
        m:SetText(name or "")
        local l, _, r = slot.strip:Pad()
        return math.max(NOTES.width, math.min(NOTES.wide, (m:GetUnboundedStringWidth() or 0) + l + r + 4))
    end
    -- A strip laid with its middle at cx, cy of the sheet.
    local function LayAt(slot, cx, cy, w, h, width, level)
        slot.strip:SetFrameLevel(host:GetFrameLevel() + level)
        local X, Y = K.Screen(cx, cy)
        slot.strip:Layout(X - w / 2, -Y - h / 2, width)
        PlaceLinks(host, slot)
        Underline(slot, host.nameMeasure)
    end
    for i, a in ipairs(about) do
        if shown >= NOTES.most then break end
        local slot = view.notes:Next()
        local seed = Surface.Seed(a.note.seed)
        local own = (Style.Noise(seed + 0.5) - 0.5) * 2 * math.rad(PLACE.jitter)
        local j = (flat or not slot.strip.turnsText) and -angle or own
        Say(slot, a.note, math.deg(angle + own), view.ground)
        -- Measured where it does not matter, then laid where it goes.
        local width = Width(slot, a.note.name)
        local w, h = slot.strip:Layout(0, 0, width)
        -- A pair: the second strip measured too, the two placed as one.
        local top, topW, tw, th, more, ox, oy, pairAt
        local uw, uh = w, h
        if a.note.top then
            top = view.notes:Next()
            local tnote = { name = a.note.top.name, what = a.note.top.what, guid = a.note.top.guid,
                mark = a.note.top.mark, seed = a.note.seed .. ":top" }
            -- With the clock: its left end, over the first, the higher.
            more = -math.rad(PAIR.turn)
            Say(top, tnote, math.deg(angle + own + more), view.ground)
            topW = Width(top, tnote.name)
            tw, th = top.strip:Layout(0, 0, topW)
            -- In the first's frame, from its top left: the second's middle,
            -- its highest corner just under the first's writing.
            local _, _, _, bottom = slot.strip:Pad()
            local cm, sm = math.cos(more), math.sin(more)
            ox = w * PAIR.x
            oy = h - bottom + PAIR.clear + math.abs(tw / 2 * sm) + th / 2 * cm
            -- Its corners there, and the two together.
            local x0, y0, x1, y1 = 0, 0, w, h
            for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
                local px, py = Surface.Turned(ox + tw / 2, oy, k[1] * tw / 2, k[2] * th / 2, cm, sm)
                x0, y0, x1, y1 = math.min(x0, px), math.min(y0, py), math.max(x1, px), math.max(y1, py)
            end
            local mx, my = (x0 + x1) / 2, (y0 + y1) / 2
            uw, uh = x1 - x0 + PAIR.pad, y1 - y0 + PAIR.pad
            pairAt = { ax = w / 2 - mx, ay = h / 2 - my, bx = ox + tw / 2 - mx, by = oy - my }
        end
        local spot = Spot(a.t, uw, uh, j, ctx, w)
        if spot then
            local c, sn = math.cos(j), math.sin(j)
            -- The first where the pair puts it (alone, in the middle).
            local ax, ay = spot.x, spot.y
            if pairAt then ax, ay = Surface.Turned(spot.x, spot.y, pairAt.ax, pairAt.ay, c, sn) end
            LayAt(slot, ax, ay, w, h, width, 1)
            Strike(slot, a.note.struck)
            taken[#taken + 1] = spot.box
            local fx, fy = spot.from[1], spot.from[2]
            local gap = math.sqrt((a.t.x - fx) ^ 2 + (a.t.y - fy) ^ 2) - a.t.r
            local entry = { note = a.note, strip = slot.strip, box = spot.box, middle = { spot.x, spot.y },
                target = a.t, from = spot.from, edge = spot.edge, gap = gap, tape = spot.tape, slot = slot }
            if top then
                local bx, by = Surface.Turned(spot.x, spot.y, pairAt.bx, pairAt.by, c, sn)
                LayAt(top, bx, by, tw, th, topW, 9)
                Strike(top, false)
                local boxA, _, tapeA = Lying(ax, ay, w, h, j)
                local boxB, _, tapeB = Lying(bx, by, tw, th, j + more)
                entry.top, entry.topSlot = top.strip, top
                entry.boxA, entry.boxB, entry.tapeA, entry.tapeB = boxA, boxB, tapeA, tapeB
                entry.firstMiddle, entry.topMiddle, entry.turnA, entry.turnB = { ax, ay }, { bx, by }, j, j + more
                entry.sizeA, entry.sizeB = { w, h }, { tw, th }
            end
            if gap < LEADER.tick.near then
                Tick(P, view.leaders, view.leaderUnder, spot.from, a.t)
                entry.leader = "tick"
            else
                local tx, ty = Leader(P, view.leaders, view.leaderUnder, spot.from, a.t, (i % 2 == 0) and 1 or -1)
                entry.leader, entry.tip = "arrow", tx and { tx, ty } or nil
            end
            view.noteStrips[#view.noteStrips + 1] = entry
            shown = shown + 1
        else
            slot:Hide()
            view.notes.used = view.notes.used - 1
            if top then
                top:Hide()
                view.notes.used = view.notes.used - 1
            end
        end
    end
    view.notes:Finish()
    view.leaders:Finish()
    view.leaderUnder:Finish()

    -- The rest, counted in chalk by the label.
    view.notesMore = #about - shown
    view.more:SetShown(view.notesMore > 0)
    if view.notesMore > 0 then
        view.more:SetText(DungeonPage.Words.More(view.notesMore))
        K.PlaceText(view.more, W - MORE.inset, moreY, "RIGHT")
    end
end

-- No notes on the sheet: the strips, their leaders and the count put away.
function DungeonPage.ClearNotes(view)
    view.notes:Begin()
    view.notes:Finish()
    for _, pool in ipairs({ view.leaders, view.leaderUnder }) do
        pool:Begin()
        pool:Finish()
    end
    view.more:Hide()
    view.noteStrips, view.notesMore, view.notesAbout = {}, 0, 0
end
