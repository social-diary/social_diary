-- A dungeon run's page in Your Diary: the keepsake page
-- (.claude/ui-proposal/super-plate.md, B, round 5, 28 Oct; JRN-20 to
-- JRN-24). The right page given to one run, as a page you came home and
-- pasted things into: the dungeon's name hand-lettered across the top
-- with its medallion pressed beside it like a seal, the level span and the
-- time inside under it; the best of what came up with you pasted round
-- the middle as keepsakes (each item's icon in a paper mount, its name in
-- its quality's ink, whose it was in pencil), and the rest counted on a
-- slip pinned under the last of them; a torn scrap of the floor's map with
-- the boss strip pasted over its top edge; everyone who fell, named, in a
-- pencilled note; and the party's signatures along the foot.
--
-- Where everything goes is Core/RunPage.lua's plan (pure, tested
-- offline): fixed places taken in rank order, nothing searched, nothing
-- meeting. What it says is Core/DungeonRun.lua's (Inside, LevelSpan,
-- Bosses, Keepsakes, Fallen) in the words of UI/Journey/Text/Run.lua.
--
-- It is the run's own page, never a summary of its spread: a click on the
-- seal, the title or the map scrap lays the run out on the table
-- (ns.UI.OpenVisit(id, "journey"), UI/Dungeon/Spread.lua), whose bookmark
-- leads back here. A keepsake under the mouse shows the game's own item
-- tooltip; the slip, the rest in their inks; the fallen note, every death
-- and what killed them; a signature opens that person's page.
--
-- Interim (the user, 28 Oct, until the pages go by play session): a level
-- with recorded runs opens on its first run; its rubric steps on through
-- the runs to the plates and round again; the ledger's row of a run opens
-- that run (UI/Journey/Page.lua's OpenRun and OpenLevel).
--
-- Pasted things are paper strips (ns.UI.PaperStrip, blank, `size`) turned
-- as the plan says, written on through the strip (strip:Lay), so they turn,
-- shade and lie flat ("Flat paper only") as every slip in the diary does.
-- What is written straight on the page (the title, the subtitle, the
-- fallen note, the signatures) is turned through a plane of its own
-- (UI/Paper/Surface.lua). Drawn once as the page opens, from pieces made
-- once and handed out again; nothing per frame.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local YourDiary = ns.UI.YourDiary
local Text = ns.UI.JourneyText
local Surface = ns.UI.Surface
local RUN = ns.RunPage.RUN

-- The look, beside the plan's places (Core/RunPage.lua's RUN):
--   paper     the stocks: a keepsake's (the lucky card's fresher tag),
--             the scrap's (the plates' photo stock), the slips' (a strip's)
--   mount     the paper square round an icon: `pad` px each side, its
--             hairline in ink at `edge`; the icon cut in by `crop` (its
--             own border off, as the find card's)
--   name      an item's name: Friz, `big` pt on K1, `size` on the others
--   whose     whose it was: the hand, `size` pt, in graphite
--   tape      a keepsake's tape: at its top's middle (`at` of its width),
--             `w` by `h`, `slant` degrees
--   floor     the scrap's print: `inset` px of stock round it, greyed
--             `grey` and tinted `tint` at `alpha` (faint, a scrap kept)
--   title     the seal's size; the underline: `under` px under the last
--             baseline, from `lead` left of the words to `run` past them,
--             sagging `sag`, `width` px at its thickest, in `pieces`
--   words     the hand's size on the slips (`slip`, `bosses`), the fallen
--             note (`fell`, `names`, `lh` between lines), the quiet lines
--             (`quiet`), the strangers (`strangers`); the subtitle `sub`
--   full      "Full run"'s ink underline: `under` px under the baseline,
--             `width` px, sagging `sag`
--   tally     the fallen note's tally: strokes `h` px tall `gap` apart,
--             `width` px, gates of five `apart` px apart; a cross `cross`
--             px; no tally past `most`
--   sig       the signatures' inks, taken in turn
local LOOK = {
    paper = { keepsake = { 0.98, 0.95, 0.87 }, scrap = { 0.93, 0.89, 0.78 }, slip = { 0.95, 0.91, 0.79 } },
    mount = { pad = 5, edge = 0.30, crop = 0.07 },
    name = { big = 13, size = 12 },
    whose = { size = 14 },
    tape = { at = 0.5, w = 30, h = 11, slant = -8 },
    floor = { inset = 6, grey = 0.55, tint = { 0.86, 0.78, 0.62 }, alpha = 0.45 },
    title = { under = 12, lead = 4, run = 10, sag = 3, width = 1.6, pieces = 14 },
    words = { slip = 14, bosses = 15, fell = 15, names = 14, lh = 16, quiet = 15, strangers = 13, sub = 15 },
    full = { under = 4, width = 1.4, sag = 1.5 },
    tally = { h = 12, gap = 3.6, width = 1.3, apart = 8, cross = 9, most = 25 },
    sig = { Style.INK_STRONG, Style.INK, { 0.17, 0.21, 0.31 }, { 0.29, 0.16, 0.08 } },
}
YourDiary.RUN_LOOK = LOOK

-- Turned writing is drawn inside its own box, and the client cuts what the
-- turn takes out of it (UI/Paper/Strip.lua's TURNED): each line's box is
-- w * sin(turn) taller, and `room` px more.
local TURNED = { room = 4 }

--------------------------------------------------------------------------
-- What the page says
--------------------------------------------------------------------------

-- A member's first name in the run, else the client's, else "someone".
local function NameOf(visit, guid)
    for _, m in ipairs(visit.members or {}) do
        if m.guid == guid and m.first and m.first ~= "" then return m.first end
    end
    local first = ns.Characters and ns.Characters.Name(guid)
    return first or Text.RUN.someone
end
YourDiary.RunNameOf = NameOf

-- An item's ID and name from its link.
local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end
local function ItemName(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or link
end

-- An item's icon, cache-free where the client can (as the find card's,
-- Features/Firsts/Card.lua): nil where it cannot say yet (the page is
-- drawn again on GET_ITEM_INFO_RECEIVED).
local UNKNOWN = { [134400] = true, ["Interface\\Icons\\INV_Misc_QuestionMark"] = true }
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end
local function Icon(link, itemID)
    local id = itemID or ItemID(link)
    if not id then return nil end
    local Plain = ns.Plain or function(v) return v end
    local icon = C_Item and Plain(Call(C_Item.GetItemIconByID, id))
    if (icon == nil or UNKNOWN[icon]) and C_Item then icon = Plain(select(5, Call(C_Item.GetItemInfoInstant, id))) end
    if icon == nil or UNKNOWN[icon] then icon = Plain(Call(_G.GetItemIcon, id)) end
    if icon == nil or icon == 0 or icon == "" or UNKNOWN[icon] then return nil end
    return icon
end

-- The ink an item's name is written in: its quality's (re-inked for the
-- page), plain ink for common and poor.
local function Ink(q)
    return (q and q >= 2 and Style.QualityNameInk(q)) or Style.INK_STRONG
end

-- The runs recorded in entry `e`, each once, in the order they began.
function YourDiary.RunsOf(e)
    local out, seen = {}, {}
    for _, d in ipairs(e and e.dungeons or {}) do
        local visit = d.visit
        if visit and visit.id and not seen[visit.id] then
            seen[visit.id] = true
            out[#out + 1] = visit
        end
    end
    table.sort(out, function(a, b) return (a.startedAt or 0) < (b.startedAt or 0) end)
    return out
end

--------------------------------------------------------------------------
-- The pieces, made once and handed out again
--------------------------------------------------------------------------

-- The page's own frame over the right page, and its pieces.
local function Board()
    local page = YourDiary.page
    if page.run then return page.run end
    local board = CreateFrame("Frame", nil, page.right)
    board:SetAllPoints(page.right)
    board:SetFrameLevel(page.right:GetFrameLevel() + 2)
    local run = { board = board, strips = {}, texts = {}, strokes = {}, hits = {}, used = {} }
    page.run = run
    run.seal = Style.Medallion(board, RUN.title.seal)
    run.title = { Style.Text(board, FONT.noteWritten), Style.Text(board, FONT.noteWritten) }
    run.sub = Style.Text(board, FONT.noteWritten)
    run.measure = Style.Text(board, FONT.small)
    run.measure:Hide()
    -- What is written straight on the page and turned (the fallen note,
    -- the signatures): each its own plane on a holder of its own.
    run.planes = {}
    return run
end

-- Handed out in the order asked, then the rest hidden (Begin, Finish).
local function Begin(run)
    for _, list in pairs(run.used) do list.n = 0 end
end
local function Next(run, kind, make)
    local list = run.used[kind] or { n = 0 }
    run.used[kind] = list
    list.n = list.n + 1
    local piece = list[list.n]
    if not piece then
        piece = make()
        list[list.n] = piece
    end
    piece:Show()
    return piece
end
local function Finish(run)
    for _, list in pairs(run.used) do
        for i = list.n + 1, #list do list[i]:Hide() end
    end
end

-- A font string in `path` at `size`, coloured.
local function Font(fs, path, size, colour)
    fs:SetFont(path, size, "")
    if colour then fs:SetTextColor(colour[1], colour[2], colour[3], colour[4] or 1) end
    return fs
end

-- A turned plane on the board about x, y (y down), turned `deg` (as a
-- strip's tilt): Place(region, lx, ly, w, h) from that point.
local function Plane(run, key, x, y, deg)
    local holder = run.planes[key]
    if not holder then
        holder = CreateFrame("Frame", nil, run.board)
        holder:SetSize(1, 1)
        holder.plane = Surface.New(holder)
        run.planes[key] = holder
    end
    local flat = ns.Setting("flatSheets") == true
    local t = (flat or not run.measure.SetRotation) and 0 or math.rad(deg or 0)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", run.board, "TOPLEFT", x, -y)
    holder.plane.Set(t, x, y, false)
    holder:Show()
    return holder.plane, t
end

-- `fs` placed on `plane` with its left at lx and its middle at ly, its
-- box tall enough for its turn.
local function PlaceText(plane, turn, fs, lx, ly, justify)
    fs:SetSize(0, 0)
    local w = Surface.Width(fs) + 2
    local h = math.max(fs:GetStringHeight() or 0, 12)
    fs:SetJustifyH(justify or "LEFT")
    local x = justify == "CENTER" and lx or (justify == "RIGHT" and lx - w / 2 or lx + w / 2)
    plane.Place(fs, x, ly, w, h + w * math.abs(math.sin(turn)) + TURNED.room)
    return w
end

-- A pen stroke on the board from x1, y1 to x2, y2 (y down), `width` px,
-- in `colour` at `alpha`: a turned texture.
local function Stroke(run, x1, y1, x2, y2, width, colour, alpha)
    local t = Next(run, "stroke", function() return run.board:CreateTexture(nil, "ARTWORK") end)
    local dx, dy = x2 - x1, y2 - y1
    t:ClearAllPoints()
    t:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, width)
    t:SetPoint("CENTER", run.board, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    t:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
    if t.SetRotation then t:SetRotation(math.atan2(-dy, dx)) end
    return t
end

-- A hand-drawn line under words on the board: from x0 to x1 at y, sagging
-- `sag` px, tapering at both ends, in `pieces`.
local function Underline(run, x0, x1, y, sag, width, colour, pieces)
    local n = pieces or 10
    local prev
    for i = 0, n do
        local t = i / n
        local px, py = x0 + (x1 - x0) * t, y + math.sin(t * math.pi) * sag - t * sag * 0.6
        if prev then
            local taper = 0.35 + 0.65 * math.sin((i - 0.5) / n * math.pi)
            Stroke(run, prev[1], prev[2], px, py, width * taper, colour, 0.9)
        end
        prev = { px, py }
    end
end

-- A blank strip of `kind`, made once per place it is handed out to; its
-- own pieces in `strip.run` (made by `make(strip)` once).
local function Strip(run, kind, make)
    return Next(run, "strip:" .. kind, function()
        local strip = ns.UI.PaperStrip(run.board)
        strip.run = make and make(strip) or {}
        return strip
    end)
end

-- Lays strip `s` blank, b.w by b.h at b.x, b.y, turned b.turn, on `paper`.
local function LayStrip(s, b, seed, paper, extra)
    local note = { size = { b.w, b.h }, tilt = b.turn, paper = paper, seed = seed }
    for k, v in pairs(extra or {}) do note[k] = v end
    s:SetNote(note)
    s:Layout(b.x, b.y, b.w)
end

-- A font string on a strip, placed through it: its left at lx (or its
-- middle, `centre`), its middle at ly, from the strip's middle (y down).
local function StripText(s, fs, lx, ly, centre)
    fs:SetSize(0, 0)
    local w = Surface.Width(fs) + 2
    local h = math.max(fs:GetStringHeight() or 0, 12)
    fs:SetJustifyH(centre and "CENTER" or "LEFT")
    s:Lay(fs, centre and lx or lx + w / 2, ly, w, h + w * math.abs(math.sin(s.turn or 0)) + TURNED.room)
    return w
end

-- A hit box over a piece of the page (the turned piece's box as laid
-- flat), above everything, with its hover and click.
local function Hit(run, b, onEnter, onClick)
    local hit = Next(run, "hit", function()
        local button = CreateFrame("Button", nil, run.board)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return button
    end)
    hit:SetFrameLevel(run.board:GetFrameLevel() + 20)
    hit:ClearAllPoints()
    hit:SetPoint("TOPLEFT", run.board, "TOPLEFT", b.x, -b.y)
    hit:SetSize(math.max(1, b.w), math.max(1, b.h))
    hit:SetScript("OnEnter", onEnter)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hit:SetScript("OnClick", onClick)
    hit.box = b
    return hit
end

--------------------------------------------------------------------------
-- Measuring
--------------------------------------------------------------------------

-- `words` in lines no wider than `width` in `path` at `size`, at most
-- `most`: the last kept line cut by letters to end in "…" where the name
-- runs on (the item tooltip has it whole).
local ELLIPSIS = "\226\128\166"
local function Wrap(run, words, path, size, width, most)
    local m = run.measure
    m:SetFont(path, size, "")
    local function W(s)
        m:SetText(s)
        m:SetSize(0, 0)
        return Surface.Width(m)
    end
    local lines, cur = {}, ""
    for word in tostring(words or ""):gmatch("%S+") do
        local next = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and W(next) > width then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = next
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    if #lines > most then
        local last = table.concat(lines, " ", most)
        while #last > 1 and W(last .. ELLIPSIS) > width do last = last:sub(1, -2) end
        for i = #lines, most, -1 do lines[i] = nil end
        lines[most] = last:gsub("%s+$", "") .. ELLIPSIS
    end
    if #lines == 0 then lines[1] = "" end
    return lines
end

local function Measure(run, words, path, size)
    local m = run.measure
    m:SetFont(path, size, "")
    m:SetText(words)
    m:SetSize(0, 0)
    return Surface.Width(m)
end

--------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------

-- A keepsake card on strip `s`, `b` its plan: the mount and its icon, the
-- name's lines, whose it was.
local function Keepsake(run, s, b, it, lines, whose, seed)
    local L = LOOK
    LayStrip(s, b, seed, L.paper.keepsake, { tapeAt = { x = b.w * L.tape.at, y = 0, slant = L.tape.slant, w = L.tape.w, h = L.tape.h } })
    local p = s.run
    if not p.icon then
        p.edge = s:CreateTexture(nil, "ARTWORK", nil, 0)
        p.mount = s:CreateTexture(nil, "ARTWORK", nil, 1)
        p.icon = s:CreateTexture(nil, "ARTWORK", nil, 2)
        p.initial = Style.Text(s, FONT.small, "OVERLAY")
        p.names = {}
        p.whose = Style.Text(s, FONT.noteWritten, "OVERLAY")
    end
    local top = -b.h / 2
    local m = b.icon + 2 * L.mount.pad
    local my = top + 10 + m / 2
    local INK = Style.INK
    p.edge:SetColorTexture(INK[1], INK[2], INK[3], L.mount.edge)
    s:Lay(p.edge, 0, my, m + 2, m + 2)
    local P = L.paper.scrap
    p.mount:SetColorTexture(P[1], P[2], P[3], 1)
    s:Lay(p.mount, 0, my, m, m)
    local icon = Icon(it.item, it.itemID)
    p.icon:SetShown(icon ~= nil)
    p.initial:SetShown(icon == nil)
    if icon then
        p.icon:SetTexture(icon)
        local c = L.mount.crop
        p.icon:SetTexCoord(c, 1 - c, c, 1 - c)
        s:Lay(p.icon, 0, my, b.icon, b.icon)
    else
        run.waiting = true
        Font(p.initial, Style.FRIZ, b.icon * 0.6, Ink(it.quality))
        p.initial:SetText((ItemName(it.item) or "?"):sub(1, 1))
        StripText(s, p.initial, 0, my, true)
    end
    local size = b.big and L.name.big or L.name.size
    local y = top + 10 + m + 10 + b.lh / 2
    for i, words in ipairs(lines) do
        local fs = p.names[i]
        if not fs then
            fs = Style.Text(s, FONT.small, "OVERLAY")
            p.names[i] = fs
        end
        Font(fs, Style.FRIZ, size, Ink(it.quality))
        fs:SetText(words)
        fs:Show()
        StripText(s, fs, 0, y, true)
        y = y + b.lh
    end
    for i = #lines + 1, #p.names do p.names[i]:Hide() end
    Font(p.whose, Style.NEUTON_ITALIC, L.whose.size, Style.GRAPHITE)
    p.whose:SetText(whose)
    StripText(s, p.whose, 0, y + 2, true)
end

-- The map scrap on strip `s`: the run's main floor printed faint.
local function Scrap(run, s, b, visit, seed)
    local L = LOOK
    LayStrip(s, b, seed, L.paper.scrap)
    local p = s.run
    p.tiles = p.tiles or {}
    local floor = ns.Dungeons.MainFloor(visit, visit.wing)
    local n = 0
    if floor then
        local DungeonMap = ns.UI.DungeonMap
        local fw, fh, scale = DungeonMap.Fit(floor, b.w - 2 * L.floor.inset, b.h - 2 * L.floor.inset)
        local ox, oy = -fw / 2, -fh / 2
        for _, piece in ipairs(DungeonMap.Pieces(floor)) do
            n = n + 1
            local t = p.tiles[n]
            if not t then
                t = s:CreateTexture(nil, "ARTWORK", nil, 0)
                p.tiles[n] = t
            end
            t:SetTexture(piece.file)
            t:SetTexCoord(piece.u0, piece.u1, piece.v0, piece.v1)
            local T = L.floor.tint
            t:SetVertexColor(T[1], T[2], T[3], L.floor.alpha)
            -- Greyed part way where the client can (asked under pcall: a
            -- build without the method may raise on it, as the printer's).
            local asked, fn = pcall(function() return t.SetDesaturation end)
            if asked and type(fn) == "function" then t:SetDesaturation(L.floor.grey) end
            local x0, y0 = ox + piece.x0 * scale, oy + piece.y0 * scale
            local w, h = (piece.x1 - piece.x0) * scale, (piece.y1 - piece.y0) * scale
            s:Lay(t, x0 + w / 2, y0 + h / 2, w + 0.3, h + 0.3)
            t:Show()
        end
    end
    for i = n + 1, #p.tiles do p.tiles[i]:Hide() end
end

-- The words on a strip `s` of `b`, in the hand at `size`, from its left
-- pad; underlined in ink when `under`.
local function StripWords(s, b, words, size, under)
    local p = s.run
    if not p.words then
        p.words = Style.Text(s, FONT.noteWritten, "OVERLAY")
        p.under = {}
    end
    Font(p.words, Style.NEUTON_ITALIC, size, Style.INK_STRONG)
    p.words:SetText(words)
    local lx = -b.w / 2 + RUN.bosses.pad / 2
    local w = StripText(s, p.words, lx, 0)
    local F = LOOK.full
    local pieces = under and 8 or 0
    for i = 1, pieces do
        local seg = p.under[i]
        if not seg then
            seg = s:CreateTexture(nil, "OVERLAY")
            p.under[i] = seg
        end
        local t0, t1 = (i - 1) / pieces, i / pieces
        local x0, x1 = lx + w * t0, lx + w * t1
        local y0 = size / 2 + F.under - math.sin(t0 * math.pi) * F.sag
        local y1 = size / 2 + F.under - math.sin(t1 * math.pi) * F.sag
        local taper = 0.35 + 0.65 * math.sin((i - 0.5) / pieces * math.pi)
        local INK = Style.INK_STRONG
        seg:SetColorTexture(INK[1], INK[2], INK[3], 0.9)
        local dx, dy = x1 - x0, y1 - y0
        s:Lay(seg, (x0 + x1) / 2, (y0 + y1) / 2, math.sqrt(dx * dx + dy * dy) + 0.4, F.width * taper,
            math.atan2(-dy, dx))
        seg:Show()
    end
    for i = pieces + 1, #(p.under or {}) do p.under[i]:Hide() end
end

-- The fallen note: a cross and the tally, "we fell n times", then everyone
-- named; or "Nobody fell.".
local function FallenNote(run, visit)
    local F, L = RUN.fallen, LOOK
    local plane, turn = Plane(run, "fallen", F.x, F.y, F.turn)
    local fallen, deaths = ns.DungeonRun.Fallen(visit)
    local function Line(i)
        return Next(run, "fallenText", function() return Style.Text(run.board, FONT.noteWritten) end)
    end
    if deaths == 0 then
        local fs = Font(Line(), Style.NEUTON_ITALIC, L.words.fell, Style.GRAPHITE)
        fs:SetText(Text.RUN.nobody)
        PlaceText(plane, turn, fs, 0, 8)
        return { x = F.x, y = F.y, w = F.w, h = 20 }, fallen, deaths
    end
    local G, T = Style.GRAPHITE, L.tally
    -- The cross: the plates' death cross, upright, in ink.
    local INK = Style.INK_STRONG
    local function Bar(lx, ly, w, h, colour, alpha, more)
        local t = Next(run, "fallenBar", function() return run.board:CreateTexture(nil, "ARTWORK") end)
        t:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
        plane.Place(t, lx, ly, w, h, more)
    end
    Bar(6, 8, 2.6, T.cross, INK)
    Bar(6, 8 - T.cross * 0.18, T.cross * 0.66, 2.4, INK)
    local x = 18
    if deaths <= T.most then
        local left = deaths
        while left > 0 do
            local k = math.min(5, left)
            for j = 1, math.min(k, 4) do
                Bar(x + 1 + (j - 1) * T.gap, 8, T.width, T.h, G, 1, math.rad(-6))
            end
            if k == 5 then Bar(x + 1.5 * T.gap, 8, 4 * T.gap + 4, T.width, G, 1, math.rad(24)) end
            x = x + 4 * T.gap + T.apart
            left = left - k
        end
    end
    local fs = Font(Line(), Style.NEUTON_ITALIC, L.words.fell, G)
    fs:SetText(Text.RunFell(deaths))
    PlaceText(plane, turn, fs, x + 2, 8)
    -- Everyone who fell, to three lines; the rest counted ("and three
    -- others"); the tooltip has them all.
    local names = {}
    for _, f in ipairs(fallen) do
        names[#names + 1] = Text.RunFallenOne(f.me and Text.RUN.you or (f.first or NameOf(visit, f.guid)), f.times)
    end
    local words = Text.RunFallen(names, function(w)
        return #Wrap(run, w, Style.NEUTON_ITALIC, L.words.names, F.w, 99) <= F.lines
    end)
    local lines = Wrap(run, words, Style.NEUTON_ITALIC, L.words.names, F.w, F.lines)
    for i, l in ipairs(lines) do
        local line = Font(Line(), Style.NEUTON_ITALIC, L.words.names, Style.INK)
        line:SetText(l)
        PlaceText(plane, turn, line, 0, 8 + i * L.words.lh + 4)
    end
    run.fallenWords = words
    return { x = F.x - 4, y = F.y - 6, w = F.w + 8, h = 20 + #lines * L.words.lh + 8 }, fallen, deaths
end

-- The signatures: the party's diary entries, each in their own size and
-- ink; strangers counted after them. Returns their hit boxes' guids.
local function Signatures(run, visit)
    local S, L = RUN.sig, LOOK
    local me = visit.me or ns.ownGUID
    local signed, strangers, seen = {}, 0, {}
    for _, m in ipairs(visit.members or {}) do
        if m.guid and m.guid ~= me and not seen[m.guid] then
            seen[m.guid] = true
            if ns.Diary.IsDiary(m.guid) then signed[#signed + 1] = m else strangers = strangers + 1 end
        end
    end
    local x = S.x
    local out = {}
    for i, m in ipairs(signed) do
        local seed = Surface.Seed(m.guid)
        local size = S.size + Style.Noise(seed) * S.grow
        local deg = (Style.Noise(seed + 1) - 0.5) * 2 * S.turn
        local name = m.first or NameOf(visit, m.guid)
        local w = Measure(run, name, Style.NEUTON_ITALIC, size)
        if x + w > S.stop then
            strangers = strangers + (#signed - i + 1)
            break
        end
        local y = S.y + ((i % 2 == 0) and S.drop or 0)
        local plane, turn = Plane(run, "sig" .. i, x + w / 2, y - size * 0.32, deg)
        local fs = Next(run, "sig", function() return Style.Text(run.board, FONT.noteWritten) end)
        Font(fs, Style.NEUTON_ITALIC, size, L.sig[(i - 1) % #L.sig + 1])
        fs:SetText(name)
        PlaceText(plane, turn, fs, 0, 0, "CENTER")
        Stroke(run, x, y + 5, x + w + 4, y + 3, 0.7, Style.INK, 0.5)
        out[#out + 1] = { guid = m.guid, x = x, y = y - size, w = w, h = size + 6 }
        x = x + w + S.gap
    end
    if strangers > 0 then
        local fs = Next(run, "sig", function() return Style.Text(run.board, FONT.noteWritten) end)
        Font(fs, Style.NEUTON_ITALIC, L.words.strangers, Style.GRAPHITE)
        fs:SetText(Text.RunStrangers(strangers))
        fs:SetSize(0, 0)
        fs:ClearAllPoints()
        fs:SetJustifyH("LEFT")
        if fs.SetRotation then fs:SetRotation(0) end
        fs:SetPoint("LEFT", run.board, "TOPLEFT", x, -(S.y + 2 - L.words.strangers * 0.32))
    end
    return out
end

-- The item tooltip on a keepsake: the game's own, from its link.
local function ItemTip(self)
    local it = self.item
    if not it then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if ItemID(it.item) and pcall(GameTooltip.SetHyperlink, GameTooltip, it.item) then
        GameTooltip:Show()
        return
    end
    local c = Ink(it.quality)
    GameTooltip:SetText(ItemName(it.item) or "?", c[1], c[2], c[3])
    GameTooltip:Show()
end

-- Draws run `visit` of entry `e` across the right page. Returns how many
-- plates it shows (none).
function YourDiary.DrawRun(e, visit)
    local page = YourDiary.page
    local run = Board()
    run.board:Show()
    Begin(run)
    run.waiting = nil
    run.visit = visit
    local L = LOOK
    local DungeonRun = ns.DungeonRun
    local seed = Surface.Seed("run:" .. tostring(visit.id))

    -- The title: hand-lettered, as large as it goes on one line; else two.
    local name = visit.name or "A dungeon"
    local size, two = ns.RunPage.TitleSize(function(s) return Measure(run, name, Style.GOODMOUNTAIN, s) end)
    local T = RUN.title
    local titleLines = two and Wrap(run, name, Style.GOODMOUNTAIN, size, T.most, 2) or { name }
    local tw = 0
    for _, l in ipairs(titleLines) do tw = math.max(tw, Measure(run, l, Style.GOODMOUNTAIN, size)) end
    local tx = T.x - tw / 2
    for i, fs in ipairs(run.title) do
        local words = titleLines[i]
        fs:SetShown(words ~= nil)
        if words then
            Font(fs, Style.GOODMOUNTAIN, size, Style.INK_STRONG)
            fs:SetText(words)
            fs:SetSize(0, 0)
            fs:SetJustifyH("LEFT")
            if fs.SetRotation then fs:SetRotation(0) end
            local base = two and T.lines[i] or T.base
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", run.board, "TOPLEFT", tx, -(base - size * 0.32))
        end
    end
    local lastBase = two and T.lines[2] or T.base
    local U = L.title
    Underline(run, tx - U.lead, tx + tw + U.run, lastBase + U.under, -U.sag, U.width, Style.INK_STRONG, U.pieces)
    run.seal:SetVisit(visit)
    run.seal:ClearAllPoints()
    run.seal:SetPoint("CENTER", run.board, "TOPLEFT", tx - T.sealX, -(two and T.sealTwo or T.sealY))
    run.seal:Show()

    -- What it says: the level span and the time inside; the bosses; the
    -- keepsakes and the rest.
    local seconds = DungeonRun.Inside(visit)
    local from, to = DungeonRun.LevelSpan(visit, ns.Journey and ns.Journey.For(visit.me or ns.ownGUID))
    local k, m, full = DungeonRun.Bosses(visit)
    local keep = DungeonRun.Keepsakes(visit, ns.Diary.IsDiary)
    local n, more = #keep.shown, #keep.rest
    local floor = ns.Dungeons.MainFloor(visit, visit.wing)

    local sub = run.sub
    Font(sub, Style.NEUTON_ITALIC, L.words.sub, Style.INK)
    sub:SetText(Text.RunSubtitle(from, to, seconds))
    sub:SetSize(0, 0)
    sub:SetJustifyH("CENTER")
    sub:ClearAllPoints()

    -- The keepsakes' names, wrapped to what each slot allows.
    local wrapped, counts = {}, {}
    for i, it in ipairs(keep.shown) do
        local slot = RUN.K[i]
        local fsize = slot.big and L.name.big or L.name.size
        wrapped[i] = Wrap(run, ItemName(it.item), Style.FRIZ, fsize, slot.w - 14,
            ns.RunPage.Most(i, n, more, two))
        counts[i] = #wrapped[i]
    end
    local bossWords = m and Text.RunBosses(k, m, full) or nil
    local moreWords = more > 0 and Text.RunMore(more) or nil
    local plan = ns.RunPage.Plan({ n = n, more = more, lines = counts, map = floor ~= nil, total = m ~= nil,
        twoLines = two, seed = seed,
        bossW = bossWords and Measure(run, bossWords, Style.NEUTON_ITALIC, L.words.bosses) or 0,
        moreW = moreWords and Measure(run, moreWords, Style.NEUTON_ITALIC, L.words.slip) or 0 })
    run.plan = plan
    sub:SetPoint("CENTER", run.board, "TOPLEFT", plan.sub.x, -(plan.sub.y - L.words.sub * 0.32))

    local function Open()
        Style.PlaySound("pageTurn")
        ns.UI.OpenVisit(visit.id, "journey")
    end
    local names = {}
    for _, member in ipairs(visit.members or {}) do
        if member.guid ~= (visit.me or ns.ownGUID) and ns.Diary.IsDiary(member.guid) then
            names[#names + 1] = member.first or NameOf(visit, member.guid)
        end
    end
    local _, deathsAll = DungeonRun.Fallen(visit)
    local tip = Text.RunTip(visit, seconds, k, m, deathsAll, names)
    local hint = floor and Text.RUN.open or Text.RUN.sheet
    local function TitleTip(self)
        for _, fs in ipairs(run.title) do
            local S = Style.INK_STRONG
            fs:SetTextColor(S[1] * 0.6, S[2] * 0.6, S[3] * 0.6)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:AddLine(hint)
        GameTooltip:Show()
    end
    local titleTop = (two and T.lines[1] or T.base) - size
    local titleHit = Hit(run, { x = tx - T.sealX - T.seal / 2, y = titleTop, w = tw + T.sealX + T.seal / 2,
        h = lastBase - titleTop + 6 }, TitleTip, Open)
    local function TitleOff()
        GameTooltip:Hide()
        for _, fs in ipairs(run.title) do
            local S = Style.INK_STRONG
            fs:SetTextColor(S[1], S[2], S[3])
        end
    end
    titleHit:SetScript("OnLeave", TitleOff)

    -- The scrap, the boss strip pasted over its top edge.
    if plan.scrap then
        local s = Strip(run, "scrap")
        Scrap(run, s, plan.scrap, visit, "run:" .. visit.id .. ":scrap")
        Hit(run, plan.scrap, TitleTip, Open):SetScript("OnLeave", TitleOff)
    end
    if plan.boss then
        local s = Strip(run, "boss")
        LayStrip(s, plan.boss, "run:" .. visit.id .. ":boss", L.paper.slip, { tapeAt = { x = 8, y = 4, slant = -40, w = 22, h = 10 } })
        StripWords(s, plan.boss, bossWords, L.words.bosses, full)
    end

    -- The keepsakes, in rank order into their places.
    for i, it in ipairs(keep.shown) do
        local s = Strip(run, "keepsake" .. i)
        local b = plan.cards[i]
        Keepsake(run, s, b, it, wrapped[i], Text.RunWhose(it, NameOf(visit, it.guid)), "run:" .. visit.id .. ":k" .. i)
        local hit = Hit(run, b, ItemTip)
        hit.item = it
    end
    if plan.slip then
        local s = Strip(run, "slip")
        LayStrip(s, plan.slip, "run:" .. visit.id .. ":more", L.paper.slip, { tack = true })
        local p = s.run
        p.words = p.words or Style.Text(s, FONT.noteWritten, "OVERLAY")
        Font(p.words, Style.NEUTON_ITALIC, L.words.slip, Style.INK_STRONG)
        p.words:SetText(moreWords)
        StripText(s, p.words, 4, 0, true)
        local rest = keep.rest
        Hit(run, plan.slip, function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(moreWords)
            local shown = 0
            for _, it in ipairs(rest) do
                if shown >= 12 then
                    GameTooltip:AddLine(Text.RunMore(#rest - shown), 1, 1, 1)
                    break
                end
                local c = Style.QualityGameColour(it.quality) or Ink(it.quality)
                -- "Swinetusk Shank — Zuri's": the name in its quality's colour,
                -- whose it was in grey.
                GameTooltip:AddLine(("%s |cffb3b3b3\226\128\148 %s|r"):format(ItemName(it.item) or "?",
                    Text.RunWhose(it, NameOf(visit, it.guid))), c[1], c[2], c[3])
                shown = shown + 1
            end
            GameTooltip:Show()
        end)
    end
    if plan.quiet then
        local fs = Next(run, "quiet", function() return Style.Text(run.board, FONT.noteWritten) end)
        Font(fs, Style.NEUTON_ITALIC, L.words.quiet, Style.GRAPHITE)
        fs:SetText(Text.RUN.nothing)
        fs:SetSize(0, 0)
        fs:SetJustifyH("CENTER")
        if fs.SetRotation then fs:SetRotation(0) end
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", run.board, "TOPLEFT", plan.quiet.x, -(plan.quiet.y - L.words.quiet * 0.32))
    end

    -- The fallen, and every death on hover.
    local box, fallen, deaths = FallenNote(run, visit)
    if deaths > 0 then
        Hit(run, box, function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(Text.RunFell(deaths))
            local all = {}
            for _, f in ipairs(fallen) do
                for _, d in ipairs(f.deaths) do all[#all + 1] = { f = f, d = d } end
            end
            table.sort(all, function(a, b) return (a.d.time or 0) < (b.d.time or 0) end)
            for _, x in ipairs(all) do
                local who = x.f.me and Text.RUN.you or (x.f.first or NameOf(visit, x.f.guid))
                local killer = x.d.killer and x.d.killer.name
                local line = Text.RunDiedTo(who, killer)
                GameTooltip:AddLine(line:sub(1, 1):upper() .. line:sub(2), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
    end

    -- The signatures: a name opens their page.
    for _, sig in ipairs(Signatures(run, visit)) do
        local guid = sig.guid
        Hit(run, sig, function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(ns.Characters.FullName and ns.Characters.FullName(guid) or NameOf(visit, guid))
            GameTooltip:Show()
        end, function()
            Style.PlaySound("pageTurn")
            YourDiary.ToPerson(guid)
        end)
    end

    Finish(run)
    run.keepsakes = keep
    return 0
end

-- The run's page hidden (another page on the right).
function YourDiary.HideRun()
    local page = YourDiary.page
    if page and page.run then page.run.board:Hide() end
end

-- An item's icon came in from the server: the run's page drawn again
-- where it waited for one.
local listener = CreateFrame("Frame")
listener:RegisterEvent("GET_ITEM_INFO_RECEIVED")
listener:SetScript("OnEvent", function()
    local page = YourDiary.page
    if page and page.mode == "run" and page.run and page.run.waiting and page.run.board:IsVisible() then
        page.run.waiting = nil
        ns.UI.RedrawJourneyPage()
    end
end)
YourDiary.RunListener = listener
