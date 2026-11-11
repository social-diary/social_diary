-- A battleground's pages in Your Diary (.claude/ui-proposal/battleground-page.md,
-- round 2, with Jan's later changes in .claude/battleground-plan.md, which
-- win): the right page given to one match (C, "the board, clipped"), and,
-- for a session of three matches or more, the evening's overview in front
-- of them ("Battlegrounds", B).
--
-- C: the map's name hand-lettered across the top with its medallion as a
-- seal, the result and the time under it; the game's final board cut out
-- and pasted in, a masthead ("FINAL" and Warsong's flags), your side over
-- theirs (theirs printed fainter), every player a row: class, name, kills,
-- deaths (no honour, rank or title anywhere: Jan). The people in your
-- diary are underlined in rubric on their row (Jan, 9 Nov: not margin
-- strips; this overrides "one rubric a page" for these underlines), your
-- own row in ink. Strips in the margin keep the other notes: the stand-out
-- (who killed you, from match.killers; else the opponent you have met
-- most) and the repeats ("your fourth match against them", counting every
-- saved match). A pencil tick at the row's end leads through the gutter
-- only, so a leader never crosses a figure. Forty a side turns over in
-- faces. A board that never read is the diary's own slip of the names read
-- during play ("The score went unwritten"). A rolled-up match keeps its
-- diary people's rows and shows the strangers it let go as lost records:
-- a count, the rows faded on the paper, never as nothing. Your note at the
-- foot: a cross, the tally, "you fell n times", what you did.
--
-- B: the title and seal, the count, the won, the time in matches; a ticket
-- per match (its numeral, the map's short name, the result, Warsong's
-- flags, the minutes) opening that match's page; then the roll: everyone
-- who was there, the people who matter by hand (your diary's, underlined
-- in rubric; anyone in two or more of the matches; the stand-out in
-- rubric), with a tick (with you) or a pencil ring (against you) under
-- each match's numeral, then everyone else in print. Only the roll turns
-- over; the title, the tickets and your note stay.
--
-- Where everything goes is Core/MatchPage.lua's plan (pure, tested
-- offline); what it says is UI/Journey/Text/Match.lua's. The record is
-- Core/Matches.lua's (read only). Drawn once as the page opens, from
-- pieces made once and handed out again, as the run's page
-- (UI/Journey/Run.lua) is: pasted things are paper strips written on
-- through strip:Lay, so they turn, shade and lie flat ("Flat paper only")
-- as every slip does. What the pad stands on is told on each hit as
-- `hit.pad` (YourDiary.MatchParts; UI/Journey/Pad.lua's group `match`).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local YourDiary = ns.UI.YourDiary
local Text = ns.UI.JourneyText
local Surface = ns.UI.Surface
local MatchPage = ns.MatchPage
local RUN = ns.RunPage.RUN
local MATCH, EVENING = MatchPage.MATCH, MatchPage.EVENING

-- The look, beside the plan's places:
--   paper    the stocks: the clipping's (the plates' photo stock, a little
--            whiter: the game's board printed), the no-board slip's and the
--            margin strips' (a strip's), a ticket's and the stand-out's
--            strip (the lucky card's fresher tag)
--   board    the clipping's print: Friz `size` pt, their side in faded ink
--            (fainter print: Style.INK_FADED); the class icon `icon` px;
--            the masthead's rule `rule` px
--   under    the rubric underline under a diary person's name: `under` px
--            under the row's middle, `width` px, sagging `sag`; yours in
--            ink, across the row, `mine` px wide
--   tick     the pencil tick at a noted row's end and the leader: `width`
--            px, graphite at `alpha`; the leader's elbow `elbow` px left of
--            the strip
--   strip    a margin strip: the heading in the hand at `head` pt (`lh`
--            between lines), what it says in Friz at `sub` pt (`subLh`),
--            `pad` px round the writing, its tape
--   ticket   a ticket: its numeral and map in Friz (`small`), the result
--            in the hand (`result`), the minutes in Friz; the perforation
--            down its left (`holes` holes); the flags' scale `flag`
--   roll     the hand's sizes: a side's heading `head`, a person `name`, the
--            stand-out's words `words`; print in Friz `print`; a tick's and
--            a ring's pen `pen` px; the heading's rule's alpha `rule`
--   words    the slip's line and headings, the names on it, your note's
--            lines, the links (Friz `link`)
--   tally    your note's tally (the run's: UI/Journey/Run.lua's LOOK.tally)
--   level    how far over the board each kind of paper lies: strips pasted
--            over (`strip`) above the clipping (`clip`); hits at 20
--   ghost    a lost record's faded row: `n` bars, graphite at `alpha`
local LOOK = {
    paper = { clip = { 0.95, 0.92, 0.83 }, slip = { 0.95, 0.91, 0.79 }, tag = { 0.98, 0.95, 0.87 } },
    board = { size = 11, icon = 9, rule = 1.1 },
    under = { under = 6, width = 1.3, sag = 0.8, mine = 1.2 },
    tick = { width = 1, alpha = 0.8, elbow = 7 },
    strip = { head = 15, lh = 16, sub = 11, subLh = 13, pad = 7 },
    ticket = { small = 11, result = 17, holes = 6, flag = 0.7 },
    roll = { head = 14, name = 16, words = 13, print = 11, pen = 1.4, rule = 0.45 },
    words = { say = 14, heads = 12, names = 13, fell = 15, deeds = 14, lh = 16, sub = 15, link = 11 },
    tally = { h = 12, gap = 3.6, width = 1.3, apart = 8, cross = 9, most = 25 },
    level = { clip = 1, strip = 3 },
    ghost = { n = 3, alpha = 0.16 },
}
YourDiary.MATCH_LOOK = LOOK

-- Turned writing gets `room` px more round it (UI/Journey/Run.lua's TURNED).
local TURNED = { room = 4 }

--------------------------------------------------------------------------
-- The sessions of a piece
--------------------------------------------------------------------------

-- The battleground sessions of `e`: a piece's own (`battlegrounds`, the
-- sessions begun in it, Recap.Pieces), else none (an entry is never drawn
-- whole with one: Recap.Pieces does not splice it).
function YourDiary.SessionsOf(e)
    return e and e.battlegrounds or {}
end

-- The session of `e` keyed `key` (its first match's id), or nil.
function YourDiary.SessionOf(e, key)
    for _, s in ipairs(YourDiary.SessionsOf(e)) do
        if s.key == key then return s end
    end
end

-- The match `id` of `e`, and its session and numeral in it, or nil.
function YourDiary.MatchOf(e, id)
    for _, s in ipairs(YourDiary.SessionsOf(e)) do
        for i, m in ipairs(s.matches) do
            if m.id == id then return m, s, i end
        end
    end
end

--------------------------------------------------------------------------
-- The pieces, made once and handed out again (as the run's page's)
--------------------------------------------------------------------------

local function Board()
    local page = YourDiary.page
    if page.bg then return page.bg end
    local board = CreateFrame("Frame", nil, page.right)
    board:SetAllPoints(page.right)
    board:SetFrameLevel(page.right:GetFrameLevel() + 2)
    local bg = { board = board, used = {}, planes = {}, faces = {} }
    page.bg = bg
    bg.seal = Style.Medallion(board, RUN.title.seal)
    bg.title = { Style.Text(board, FONT.noteWritten), Style.Text(board, FONT.noteWritten) }
    bg.sub = Style.Text(board, FONT.noteWritten)
    bg.measure = Style.Text(board, FONT.small)
    bg.measure:Hide()
    return bg
end

local function Begin(bg)
    for _, list in pairs(bg.used) do list.n = 0 end
end
local function Next(bg, kind, make)
    local list = bg.used[kind] or { n = 0 }
    bg.used[kind] = list
    list.n = list.n + 1
    local piece = list[list.n]
    if not piece then
        piece = make()
        list[list.n] = piece
    end
    piece:Show()
    return piece
end
local function Finish(bg)
    for _, list in pairs(bg.used) do
        for i = list.n + 1, #list do list[i]:Hide() end
    end
end

local function Font(fs, path, size, colour, alpha)
    fs:SetFont(path, size, "")
    if colour then fs:SetTextColor(colour[1], colour[2], colour[3], alpha or colour[4] or 1) end
    return fs
end

local function Measure(bg, words, path, size)
    local m = bg.measure
    m:SetFont(path, size, "")
    m:SetText(words)
    m:SetSize(0, 0)
    return Surface.Width(m)
end

-- `words` in lines no wider than `width`, at most `most` (the last cut
-- short with an ellipsis).
local ELLIPSIS = "\226\128\166"
local function Wrap(bg, words, path, size, width, most)
    local lines, cur = {}, ""
    for word in tostring(words or ""):gmatch("%S+") do
        local next = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and Measure(bg, next, path, size) > width then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = next
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    if #lines > most then
        local last = table.concat(lines, " ", most)
        while #last > 1 and Measure(bg, last .. ELLIPSIS, path, size) > width do last = last:sub(1, -2) end
        for i = #lines, most, -1 do lines[i] = nil end
        lines[most] = last:gsub("%s+$", "") .. ELLIPSIS
    end
    if #lines == 0 then lines[1] = "" end
    return lines
end

-- A font string straight on the board: its left (or middle, or right) at
-- x, its middle at y.
local function Words(bg, kind, path, size, colour, words, x, y, justify, alpha)
    local fs = Next(bg, kind, function() return Style.Text(bg.board, FONT.noteWritten) end)
    Font(fs, path, size, colour, alpha)
    fs:SetText(words)
    fs:SetSize(0, 0)
    fs:SetJustifyH(justify or "LEFT")
    if fs.SetRotation then fs:SetRotation(0) end
    fs:ClearAllPoints()
    local point = justify == "CENTER" and "CENTER" or justify == "RIGHT" and "RIGHT" or "LEFT"
    fs:SetPoint(point, bg.board, "TOPLEFT", x, -y)
    return fs, Measure(bg, words, path, size)
end

-- A turned plane on the board about x, y, turned `deg`.
local function Plane(bg, key, x, y, deg)
    local holder = bg.planes[key]
    if not holder then
        holder = CreateFrame("Frame", nil, bg.board)
        holder:SetSize(1, 1)
        holder.plane = Surface.New(holder)
        bg.planes[key] = holder
    end
    local flat = ns.Setting("flatSheets") == true
    local t = (flat or not bg.measure.SetRotation) and 0 or math.rad(deg or 0)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", bg.board, "TOPLEFT", x, -y)
    holder.plane.Set(t, x, y, false)
    holder:Show()
    return holder.plane, t
end

local function PlaceText(plane, turn, fs, lx, ly)
    fs:SetSize(0, 0)
    local w = Surface.Width(fs) + 2
    local h = math.max(fs:GetStringHeight() or 0, 12)
    fs:SetJustifyH("LEFT")
    plane.Place(fs, lx + w / 2, ly, w, h + w * math.abs(math.sin(turn)) + TURNED.room)
    return w
end

-- A pen stroke on the board (y down).
local function Stroke(bg, x1, y1, x2, y2, width, colour, alpha)
    local t = Next(bg, "stroke", function() return bg.board:CreateTexture(nil, "ARTWORK") end)
    local dx, dy = x2 - x1, y2 - y1
    t:ClearAllPoints()
    t:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, width)
    t:SetPoint("CENTER", bg.board, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    t:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
    if t.SetRotation then t:SetRotation(math.atan2(-dy, dx)) end
    return t
end

-- A hand-drawn line under words on the board, sagging, tapering.
local function Underline(bg, x0, x1, y, sag, width, colour, pieces)
    local n = pieces or 10
    local prev
    for i = 0, n do
        local t = i / n
        local px, py = x0 + (x1 - x0) * t, y + math.sin(t * math.pi) * sag - t * sag * 0.6
        if prev then
            local taper = 0.35 + 0.65 * math.sin((i - 0.5) / n * math.pi)
            Stroke(bg, prev[1], prev[2], px, py, width * taper, colour, 0.9)
        end
        prev = { px, py }
    end
end

-- A pencil ring round a point on the board: an ellipse rx by ry, its ends
-- overlapping a little where the pencil came round, seeded.
local function Ring(bg, cx, cy, rx, ry, seed, colour, width)
    local n, a0 = 14, Style.Noise(seed) * 6
    local prev
    for i = 0, n do
        local a = a0 + i / n * (2 * math.pi + 0.5)
        local wob = 1 + (Style.Noise(seed + i) - 0.5) * 0.12
        local px, py = cx + math.cos(a) * rx * wob, cy + math.sin(a) * ry * wob
        if prev then Stroke(bg, prev[1], prev[2], px, py, width, colour, 0.85) end
        prev = { px, py }
    end
end

-- A tick on the board at x, y: the pen's two strokes.
local function Tick(bg, x, y, colour, width)
    Stroke(bg, x - 5, y, x - 1.5, y + 4, width, colour, 0.95)
    Stroke(bg, x - 1.5, y + 4, x + 6, y - 6, width * 0.85, colour, 0.95)
end

-- A blank strip of `kind`, made once per place, lying `level` over the
-- board; its own pieces in `strip.bg`.
local function Strip(bg, kind, level)
    local s = Next(bg, "strip:" .. kind, function()
        local strip = ns.UI.PaperStrip(bg.board)
        strip.bg = { texts = {}, lines = {}, n = 0, t = 0 }
        return strip
    end)
    s:SetFrameLevel(bg.board:GetFrameLevel() + level)
    return s
end

local function LayStrip(s, b, seed, paper, extra)
    local note = { size = { b.w, b.h }, tilt = b.turn, paper = paper, seed = seed }
    for k, v in pairs(extra or {}) do note[k] = v end
    s:SetNote(note)
    s:Layout(b.x, b.y, b.w)
    local p = s.bg
    p.n, p.t = 0, 0
end

-- A font string written on strip `s`: its left (or middle, or right end,
-- `justify`) at lx, its middle at ly, from the strip's middle (y down).
local function StripText(s, path, size, colour, words, lx, ly, justify, alpha)
    local p = s.bg
    p.n = p.n + 1
    local fs = p.texts[p.n]
    if not fs then
        fs = Style.Text(s, FONT.small, "OVERLAY")
        p.texts[p.n] = fs
    end
    Font(fs, path, size, colour, alpha)
    fs:SetText(words)
    fs:Show()
    fs:SetSize(0, 0)
    local w = Surface.Width(fs) + 2
    local h = math.max(fs:GetStringHeight() or 0, 12)
    fs:SetJustifyH(justify or "LEFT")
    local mx = justify == "CENTER" and lx or justify == "RIGHT" and lx - w / 2 or lx + w / 2
    s:Lay(fs, mx, ly, w, h + w * math.abs(math.sin(s.turn or 0)) + TURNED.room)
    return fs, w
end

-- A line on strip `s` from lx0, ly0 to lx1, ly1 (from its middle, y down).
local function StripLine(s, lx0, ly0, lx1, ly1, width, colour, alpha)
    local p = s.bg
    p.t = p.t + 1
    local seg = p.lines[p.t]
    if not seg then
        seg = s:CreateTexture(nil, "OVERLAY")
        p.lines[p.t] = seg
    end
    seg:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
    local dx, dy = lx1 - lx0, ly1 - ly0
    s:Lay(seg, (lx0 + lx1) / 2, (ly0 + ly1) / 2, math.sqrt(dx * dx + dy * dy) + 0.4, width, math.atan2(-dy, dx))
    seg:Show()
    return seg
end

-- A hand-drawn underline on strip `s`, sagging, tapering, in `pieces`.
local function StripUnder(s, lx0, lx1, ly, sag, width, colour, pieces)
    local n = pieces or 6
    for i = 1, n do
        local t0, t1 = (i - 1) / n, i / n
        local taper = 0.4 + 0.6 * math.sin((i - 0.5) / n * math.pi)
        StripLine(s, lx0 + (lx1 - lx0) * t0, ly + math.sin(t0 * math.pi) * sag,
            lx0 + (lx1 - lx0) * t1, ly + math.sin(t1 * math.pi) * sag, width * taper, colour, 0.9)
    end
end

-- A texture on strip `s` (a class icon), made once per place.
local function StripIcon(s, class, lx, ly, size)
    local p = s.bg
    p.icons = p.icons or {}
    p.i = (p.i or 0) + 1
    local t = p.icons[p.i]
    if not t then
        t = s:CreateTexture(nil, "OVERLAY")
        p.icons[p.i] = t
    end
    Style.ClassIconOrInk(t, class)
    s:Lay(t, lx, ly, size, size)
    t:Show()
end

-- The strip's own pieces past what this laying used, hidden.
local function StripDone(s)
    local p = s.bg
    for i = p.n + 1, #p.texts do p.texts[i]:Hide() end
    for i = p.t + 1, #p.lines do p.lines[i]:Hide() end
    for i = (p.i or 0) + 1, #(p.icons or {}) do p.icons[i]:Hide() end
    p.i = 0
end

-- A pennant (Warsong's flag) on strip `s` at lx, ly (its pole's foot's
-- top), `k` its scale: ours filled in ink, theirs drawn in pencil.
local function Pennant(s, lx, ly, ours, k)
    local INK, G = Style.INK_STRONG, Style.GRAPHITE
    StripLine(s, lx, ly, lx, ly + 13 * k, 1.1 * k, ours and INK or G, 1)
    if ours then
        for j = 0, 4 do
            local y = ly + (1 + j * 1.6) * k
            local len = (10 - j * 2) * k
            StripLine(s, lx, y, lx + len, y, 1.8 * k, INK, 0.95)
        end
    else
        StripLine(s, lx, ly + 0.5 * k, lx + 10 * k, ly + 4 * k, 0.9, G, 0.95)
        StripLine(s, lx + 10 * k, ly + 4 * k, lx, ly + 8 * k, 0.9, G, 0.95)
    end
end

-- A hit box over a piece of the page, above everything, with its hover and
-- click. What the pad stands on is told on it after, as `hit.pad`:
--   kind   "title", "back", "row", "strip", "turn", "note", "lost",
--          "ticket", "hand"
--   key    what it is, the same however often the page is drawn again
--   words  the FontString the pen boxes; strip + heading: a pasted thing
--   kept   a diary person's row (A opens their page)
-- and a link's `label` and `line`.
local function Hit(bg, b, onEnter, onClick)
    local hit = Next(bg, "hit", function()
        local button = CreateFrame("Button", nil, bg.board)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return button
    end)
    hit:SetFrameLevel(bg.board:GetFrameLevel() + 20)
    hit:ClearAllPoints()
    hit:SetPoint("TOPLEFT", bg.board, "TOPLEFT", b.x, -b.y)
    hit:SetSize(math.max(1, b.w), math.max(1, b.h))
    hit:SetScript("OnEnter", onEnter)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hit:SetScript("OnClick", onClick)
    hit.box = b
    hit.pad, hit.label, hit.line, hit.guid = nil, nil, nil, nil
    return hit
end

-- A link straight on the page, in Friz with the house link's hairline: its
-- left (or middle, `centre`) at x, its middle at y. Darker under the mouse.
local function LinkWord(bg, words, x, y, centre, onEnter, onClick)
    local size = LOOK.words.link
    local w = Measure(bg, words, Style.FRIZ, size)
    local x0 = centre and x - w / 2 or x
    local fs = Words(bg, "link", Style.FRIZ, size, Style.GRAPHITE, words, x0, y)
    local G, I = Style.GRAPHITE, Style.INK_STRONG
    local line = Stroke(bg, x0, y + size / 2 + 1, x0 + w, y + size / 2 + 1, 1, G, Style.HAIRLINE)
    local hit = Hit(bg, { x = x0 - 2, y = y - size / 2 - 2, w = w + 4, h = size + 5 }, function(self)
        fs:SetTextColor(I[1], I[2], I[3], 1)
        line:SetColorTexture(I[1], I[2], I[3], Style.HAIRLINE_HOT)
        if onEnter then onEnter(self) end
    end, onClick)
    hit:SetScript("OnLeave", function()
        GameTooltip:Hide()
        fs:SetTextColor(G[1], G[2], G[3], 1)
        line:SetColorTexture(G[1], G[2], G[3], Style.HAIRLINE)
    end)
    hit.label, hit.line = fs, line
    hit.pad = { words = fs }
    return hit
end

local function Tip(self, title, lines, hint)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1, 1, true)
    for _, l in ipairs(lines or {}) do GameTooltip:AddLine(l, nil, nil, nil, true) end
    if hint then GameTooltip:AddLine(hint) end
    GameTooltip:Show()
end

--------------------------------------------------------------------------
-- The title, as the run's page has it (RUN.title)
--------------------------------------------------------------------------

-- The title hand-lettered, its seal, its underline and the subtitle.
-- `art` = { name, instanceID } for the seal (the battleground's picture
-- where the client has one, else its initial). Returns the title's box and
-- its first line's font string.
local function Title(bg, name, art, sub)
    local L = LOOK
    local size, two = ns.RunPage.TitleSize(function(s) return Measure(bg, name, Style.GOODMOUNTAIN, s) end)
    local T = RUN.title
    local lines = two and Wrap(bg, name, Style.GOODMOUNTAIN, size, T.most, 2) or { name }
    local tw = 0
    for _, l in ipairs(lines) do tw = math.max(tw, Measure(bg, l, Style.GOODMOUNTAIN, size)) end
    local tx = T.x - tw / 2
    for i, fs in ipairs(bg.title) do
        local words = lines[i]
        fs:SetShown(words ~= nil)
        if words then
            Font(fs, Style.GOODMOUNTAIN, size, Style.INK_STRONG)
            fs:SetText(words)
            fs:SetSize(0, 0)
            fs:SetJustifyH("LEFT")
            if fs.SetRotation then fs:SetRotation(0) end
            local base = two and T.lines[i] or T.base
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", bg.board, "TOPLEFT", tx, -(base - size * 0.32))
        end
    end
    local last = two and T.lines[2] or T.base
    local U = YourDiary.RUN_LOOK.title
    Underline(bg, tx - U.lead, tx + tw + U.run, last + U.under, -U.sag, U.width, Style.INK_STRONG, U.pieces)
    bg.seal:SetVisit(art)
    bg.seal:ClearAllPoints()
    bg.seal:SetPoint("CENTER", bg.board, "TOPLEFT", tx - T.sealX, -(two and T.sealTwo or T.sealY))
    bg.seal:Show()
    local shift = two and T.shift or 0
    local s = bg.sub
    Font(s, Style.NEUTON_ITALIC, L.words.sub, Style.INK)
    s:SetText(sub)
    s:SetSize(0, 0)
    s:SetJustifyH("CENTER")
    s:ClearAllPoints()
    s:SetPoint("CENTER", bg.board, "TOPLEFT", RUN.sub.x, -(RUN.sub.y + shift - L.words.sub * 0.32))
    local top = (two and T.lines[1] or T.base) - size
    return { x = tx - T.sealX - T.seal / 2, y = top, w = tw + T.sealX + T.seal / 2, h = last - top + 6 },
        not two and bg.title[1] or nil
end

--------------------------------------------------------------------------
-- Reading a match
--------------------------------------------------------------------------

-- The user's own row of a match.
local function MyRow(match, players)
    local me = match.me or ns.ownGUID
    for _, p in ipairs(players) do
        if p.guid and p.guid == me then return p end
    end
end

-- The flags taken by each side (Warsong's stat 42, summed), or nil where
-- the board said nothing of them.
local function Flags(match, players)
    if match.map ~= 489 then return nil end
    local us, them, any = 0, 0, false
    for _, p in ipairs(players) do
        local n = p.stats and p.stats[ns.Matches.STAT.FLAG_CAPTURED]
        if n then
            any = true
            if ns.Matches.Side(match, p) == "with" then us = us + n else them = them + n end
        end
    end
    return any and { us = us, them = them } or nil
end

-- What you did, from your row: flags taken and returned, killing blows.
local function Deeds(p)
    if not p then return nil end
    local S = ns.Matches.STAT
    return p.stats and p.stats[S.FLAG_CAPTURED], p.stats and p.stats[S.FLAG_RETURNED], p.kb
end

-- How many of the user's deaths in `match` row `p` dealt, by name.
local function Killed(match, p)
    local n = 0
    for _, name in pairs(match.killers or {}) do
        if ns.Matches.SameName(name, p.name) then n = n + 1 end
    end
    return n
end

-- A name's first part: "Feivel" of "Feivel Ashgrove".
local function First(name)
    return name and name:match("^(%S+)") or name or "?"
end

-- The rows of `match`, each { p, side, diary, me, meets, killed, standout,
-- index, noted }: `noted` where it earns a strip (the stand-out, a repeat
-- not in your diary). `ctx` = { names (Matches.DiaryNames), index
-- (MatchPage.Index) }.
local function Rows(match, ctx)
    local players = ns.Matches.Players(match)
    local me = match.me or ns.ownGUID
    local rows = {}
    for _, p in ipairs(players) do
        local r = { p = p, side = ns.Matches.Side(match, p), index = p.index }
        r.me = p.guid ~= nil and p.guid == me
        if not r.me then
            r.diary = ns.Matches.Who(p, ctx.names)
            r.meets = r.side and MatchPage.Count(ctx.index, p, match, r.side) or 0
            r.killed = Killed(match, p)
        end
        rows[#rows + 1] = r
    end
    -- The stand-out: who killed you most; else the opponent met most (two
    -- matches or more, counting every saved one).
    local best
    for _, r in ipairs(rows) do
        if (r.killed or 0) > 0 and (not best or r.killed > best.killed) then best = r end
    end
    if not best then
        for _, r in ipairs(rows) do
            if r.side == "against" and (r.meets or 0) >= 2 and (not best or r.meets > best.meets) then best = r end
        end
    end
    if best then best.standout = true end
    for _, r in ipairs(rows) do
        r.noted = not r.me and not r.diary and (r.standout or (r.meets or 0) >= 2) or nil
    end
    return rows, players
end

-- The context every row is judged in: the diary's names and who was where.
local function Context(match)
    return { names = ns.Matches.DiaryNames(), index = MatchPage.Index(ns.Matches.All(match.me)) }
end

--------------------------------------------------------------------------
-- Your note at the foot
--------------------------------------------------------------------------

-- A cross, the tally, "you fell n times", then `deeds` on the next line,
-- turned on a plane at x, y. Returns its box.
-- `said`, where given, is the first line's words in place of "you fell n
-- times" (the v2 page's foot, Text.StoryFoot).
local function FootNote(bg, x, y, turnDeg, deaths, deeds, said)
    local L, T = LOOK, LOOK.tally
    local plane, turn = Plane(bg, "note", x, y, turnDeg)
    local function Bar(lx, ly, w, h, colour, more)
        local t = Next(bg, "noteBar", function() return bg.board:CreateTexture(nil, "ARTWORK") end)
        t:SetColorTexture(colour[1], colour[2], colour[3], 1)
        plane.Place(t, lx, ly, w, h, more)
    end
    local function Line()
        return Next(bg, "noteText", function() return Style.Text(bg.board, FONT.noteWritten) end)
    end
    local G, INK = Style.GRAPHITE, Style.INK_STRONG
    local lx = 0
    if deaths > 0 then
        Bar(6, 8, 2.6, T.cross, INK)
        Bar(6, 8 - T.cross * 0.18, T.cross * 0.66, 2.4, INK)
        lx = 18
        if deaths <= T.most then
            local left = deaths
            while left > 0 do
                local k = math.min(5, left)
                for j = 1, math.min(k, 4) do Bar(lx + 1 + (j - 1) * T.gap, 8, T.width, T.h, G, math.rad(-6)) end
                if k == 5 then Bar(lx + 1.5 * T.gap, 8, 4 * T.gap + 4, T.width, G, math.rad(24)) end
                lx = lx + 4 * T.gap + T.apart
                left = left - k
            end
        end
        lx = lx + 2
    end
    local head = Font(Line(), Style.NEUTON_ITALIC, L.words.fell, G)
    head:SetText(said or Text.MatchFell(deaths))
    local w = PlaceText(plane, turn, head, lx, 8)
    local h = 20
    if deeds then
        local fs = Font(Line(), Style.NEUTON_ITALIC, L.words.deeds, Style.INK)
        fs:SetText(deeds)
        w = math.max(w + lx, PlaceText(plane, turn, fs, 0, 8 + L.words.lh + 4))
        h = h + L.words.lh + 4
    else
        w = w + lx
    end
    return { x = x - 4, y = y - 4, w = math.min(w + 8, 430), h = h + 4 }, head
end

-- The tooltip of your note: each death's minute in, and who dealt it.
local function DeathsTip(self, match)
    local list = {}
    for k, t in ipairs(match.deaths or {}) do
        local minute = math.max(0, math.floor((t - (match.startedAt or t)) / 60 + 0.5))
        list[#list + 1] = Text.MatchDeathLine(k, minute, match.killers and match.killers[k])
    end
    Tip(self, Text.Capital(Text.MatchFell(#(match.deaths or {}))), list)
end

--------------------------------------------------------------------------
-- C: the match page
--------------------------------------------------------------------------

-- Who a strip is for: its heading and what it says (`sub` may be nil).
local function StripWords(r)
    local name = First(r.p.name)
    local head = (r.standout and (r.killed or 0) > 0) and Text.MatchKilled(name, r.killed) or (r.p.name or name)
    local sub = (r.meets or 0) >= 2 and Text.MatchMeeting(r.meets, r.side) or nil
    return head, sub
end

-- A margin strip at `b` for row `r`, its leader from `from` (the tick's
-- end on the page) through the gutter.
local function NoteStrip(bg, k, b, r, lines, subs, from, match)
    local L, S = LOOK, LOOK.strip
    local s = Strip(bg, "note" .. k, L.level.strip)
    local paper = r.standout and L.paper.tag or L.paper.slip
    LayStrip(s, b, "match:" .. match.id .. ":note:" .. tostring(r.p.guid or r.p.name), paper,
        { tapeAt = { x = 10, y = 3, slant = -40, w = 22, h = 10 } })
    local lx, y = -b.w / 2 + S.pad, -b.h / 2 + S.pad
    local head
    for _, l in ipairs(lines) do
        local fs = StripText(s, Style.NEUTON_ITALIC, S.head, r.standout and Style.RUBRIC or Style.INK_STRONG, l, lx,
            y + S.lh / 2)
        head = head or fs
        y = y + S.lh
    end
    for _, l in ipairs(subs) do
        StripText(s, Style.FRIZ, S.sub, Style.INK, l, lx, y + S.subLh / 2)
        y = y + S.subLh
    end
    StripDone(s)
    -- The leader: from the tick's end, through the gutter only, to the
    -- strip's left edge at its heading.
    local tx, ty = b.x - 1, b.y + S.pad + S.lh / 2
    local ex = b.x - L.tick.elbow
    local G = Style.GRAPHITE
    Stroke(bg, from[1], from[2], ex, from[2] + (ty - from[2]) * 0.4, 0.9, G, L.tick.alpha)
    Stroke(bg, ex, from[2] + (ty - from[2]) * 0.4, tx, ty, 0.9, G, L.tick.alpha)
    local hit = Hit(bg, b, function(self)
        local title, rest = Text.MatchRowTip(r.p, match)
        Tip(self, lines[1] .. (lines[2] and (" " .. lines[2]) or ""), { title, unpack(rest) })
    end)
    hit.pad = { kind = "strip", key = "strip:" .. tostring(r.p.guid or r.p.name), strip = s, heading = head }
    return s
end

-- The clipping: the board's face `face`. Returns its strip, the rows shown
-- (each { r, ly, page y }) and the plan.
local function Clipping(bg, match, order, players, face)
    local L, B = LOOK, MATCH.board
    local nW, nA = #order.with, #order.against
    local lost = match.rolled and (match.lost or 0) > 0
    local plan = MatchPage.Board(nW, nA, face, lost)
    local s = Strip(bg, "clip", L.level.clip)
    local box = { x = B.x, y = B.y, w = B.w, h = plan.h, turn = B.turn }
    LayStrip(s, box, "match:" .. match.id .. ":clip", L.paper.clip)
    local left, top = -B.w / 2, -plan.h / 2
    local size = L.board.size
    local INK, FAINT = Style.INK_STRONG, Style.INK_FADED
    -- The masthead: "FINAL", Warsong's flags, a rule.
    StripText(s, Style.FRIZ, size, Style.INK, Text.MATCH.final, left + 10, top + 15)
    -- (a rolled-up board's flags would be its kept rows' only: left off)
    local flags = not match.rolled and Flags(match, players) or nil
    if flags then
        local k = 0.8
        local us, them = math.min(flags.us, 3), math.min(flags.them, 3)
        -- A side that took none says so in print, "0", rather than
        -- leaving "to" hanging (9 Nov, in the render: "flags to" and
        -- nothing after it).
        local x = left + B.w - 10 - (math.max(us, 1) + math.max(them, 1)) * 11 - 22
        if us == 0 then
            StripText(s, Style.FRIZ, size, Style.INK, "0", x + 2, top + 15)
            x = x + 11
        end
        for _ = 1, us do
            Pennant(s, x, top + 8, true, k)
            x = x + 11
        end
        local _, w = StripText(s, Style.FRIZ, size, Style.INK, Text.MATCH.to, x + 2, top + 15)
        x = x + w + 6
        if them == 0 then
            StripText(s, Style.FRIZ, size, Style.GRAPHITE, "0", x + 2, top + 15)
        end
        for _ = 1, them do
            Pennant(s, x, top + 8, false, k)
            x = x + 11
        end
    end
    StripLine(s, left + 10, top + 25, left + B.w - 10, top + 25, L.board.rule, Style.INK, 0.8)
    -- Each side: its heading and columns, its rows.
    local shown = {}
    for side, at in pairs(plan.heads) do
        local list = order[side]
        local ink = side == "with" and INK or FAINT
        local alpha = 1
        local hy = top + at
        local faction = side == "with" and match.faction or (match.faction and (1 - match.faction))
        -- (a rolled-up board's count would be its kept rows': the side alone)
        StripText(s, Style.FRIZ, size, ink, Text.MatchSide(faction, not match.rolled and #list or nil), left + 10, hy,
            nil, alpha)
        StripText(s, Style.FRIZ, size, ink, Text.MATCH.kills, left + B.kills, hy, "RIGHT", alpha)
        StripText(s, Style.FRIZ, size, ink, Text.MATCH.deaths, left + B.deaths, hy, "RIGHT", alpha)
        StripLine(s, left + 10, hy + 7, left + B.w - 10, hy + 7, 0.6, ink, 0.6 * alpha)
    end
    for _, at in ipairs(plan.rows) do
        local r = order[at.side][at.i]
        local p = r.p
        local ly = top + at.y
        local ink = at.side == "with" and INK or FAINT
        local alpha = 1
        StripIcon(s, p.class, left + B.icon, ly, L.board.icon)
        local name = p.name or "?"
        local nameFs, nw = StripText(s, Style.FRIZ, size, (r.me or r.diary) and INK or ink, name, left + B.name, ly,
            nil, (r.me or r.diary) and 1 or alpha)
        StripText(s, Style.FRIZ, size, ink, p.kb and tostring(p.kb) or "", left + B.kills, ly, "RIGHT", alpha)
        StripText(s, Style.FRIZ, size, ink, p.deaths and tostring(p.deaths) or "", left + B.deaths, ly, "RIGHT", alpha)
        local U = L.under
        if r.diary then
            -- (Jan, 9 Nov: a diary person is underlined in rubric on their row)
            StripUnder(s, left + B.name - 1, left + B.name + nw - 2, ly + U.under, U.sag, U.width, Style.RUBRIC, 6)
        elseif r.me then
            StripUnder(s, left + B.name - 1, left + B.deaths + 2, ly + U.under, U.sag * 0.6, U.mine, Style.INK_STRONG, 10)
        end
        if r.strip then StripLine(s, left + B.tick, ly, left + B.tickEnd, ly, L.tick.width, Style.GRAPHITE, 1) end
        local _, py = s:Out(0, ly)
        shown[#shown + 1] = { r = r, ly = ly, y = py, fs = nameFs, side = at.side }
    end
    -- The lost records: faded rows, and how many.
    if plan.lost then
        local ly = top + plan.lost
        local G = Style.GRAPHITE
        for j = 1, L.ghost.n do
            local y = ly - 8 + (j - 1) * 3.2
            local w = 70 + Style.Noise(match.id * 3 + j) * 120
            StripLine(s, left + B.name, y, left + B.name + w, y, 1.6, G, L.ghost.alpha)
        end
        StripText(s, Style.NEUTON_ITALIC, LOOK.words.names, G, Text.MatchLost(match.lost), left + B.name, ly + 6)
    end
    StripDone(s)
    return s, shown, plan, box
end

-- The no-board slip: the names read during play, by hand, in two columns.
local function NoBoard(bg, match, order, face)
    local L, S = LOOK, MATCH.slip
    local plan = MatchPage.Slip(#order.with, #order.against, face)
    local s = Strip(bg, "slip", L.level.clip)
    local box = { x = S.x, y = S.y, w = S.w, h = plan.h, turn = S.turn }
    LayStrip(s, box, "match:" .. match.id .. ":slip", L.paper.slip)
    local left, top = -S.w / 2, -plan.h / 2
    local G = Style.GRAPHITE
    StripText(s, Style.NEUTON_ITALIC, L.words.say, G, Text.MATCH.unwritten, left + 10, top + S.say)
    StripText(s, Style.NEUTON_ITALIC, L.words.heads, G, Text.MATCH.withYou, left + S.cols[1], top + S.heads)
    StripText(s, Style.NEUTON_ITALIC, L.words.heads, G, Text.MATCH.againstYou, left + S.cols[2], top + S.heads)
    StripLine(s, left + S.cols[1], top + S.heads + 5, left + S.w - 14, top + S.heads + 5, 0.6, G, 0.5)
    local shown = {}
    for c, side in ipairs({ "with", "against" }) do
        local span = plan[side]
        local k = 0
        for i = span.from, span.to do
            local r = order[side][i]
            local ly = top + S.first + k * S.lh
            k = k + 1
            local ink = (side == "with" or r.diary) and Style.INK_STRONG or G
            local fs, w = StripText(s, Style.NEUTON_ITALIC, L.words.names, ink, r.p.name or "?", left + S.cols[c], ly)
            if r.diary then
                StripUnder(s, left + S.cols[c] - 1, left + S.cols[c] + w - 2, ly + L.under.under, L.under.sag,
                    L.under.width, Style.RUBRIC, 6)
            end
            if r.strip then
                StripLine(s, left + MATCH.board.tick, ly, left + MATCH.board.tickEnd, ly, L.tick.width, G, 1)
            end
            local _, py = s:Out(0, ly)
            shown[#shown + 1] = { r = r, ly = ly, y = py, fs = fs, side = side, col = c }
        end
    end
    StripDone(s)
    return s, shown, plan, box
end

-- Draws match `match` of piece `e` across the right page. `back`: the
-- session's key where it has an overview (its way back). Returns how many
-- plates it shows (none).
-- A Warsong told by time (Core/MatchStory.lua's story) is drawn as the v2
-- page instead (UI/Journey/MatchStory.lua, YourDiary.DrawStory), and this
-- board is its "board view", opened from the page's corner stub
-- (page.matchBoard): there "Back to the match" leads back to the story.
function YourDiary.DrawMatch(e, match, back)
    local page = YourDiary.page
    local boardView = page and page.matchBoard == match.id
    if not boardView and YourDiary.DrawStory and ns.MatchStory and ns.MatchStory.Has(match) then
        local shown = YourDiary.DrawStory(e, match, back)
        if shown then return shown end
    end
    local bg = Board()
    bg.board:Show()
    Begin(bg)
    bg.match, bg.session, bg.story = match, nil, nil
    local L = LOOK

    -- The title first (the pad lands on it as the page opens).
    local titleBox, titleFs = Title(bg, Text.MatchMap(match), { name = Text.MatchMap(match), instanceID = match.map },
        Text.MatchSubtitle(match))
    local ctx = Context(match)
    local rows, players = Rows(match, ctx)
    local mine = MyRow(match, players)
    local tipTitle = Text.MatchMap(match)
    local tipLine = Text.MatchSubtitle(match)
    Hit(bg, titleBox, function(self) Tip(self, tipTitle, { tipLine }) end).pad =
        { kind = "title", key = "title", words = titleFs }

    -- The way back to the evening, only where the session has one.
    if back then
        local B = MATCH.back
        local link = LinkWord(bg, Text.MATCH.back, B.x, B.y, false, nil, function()
            Style.PlaySound("pageTurn")
            YourDiary.OpenMatches(back)
        end)
        link.pad.kind, link.pad.key = "back", "back"
    end

    -- The board view of a Warsong told by time: its way back to the story,
    -- at the top's right end, where the story's stub lay.
    if boardView then
        local words = YourDiary.STORY_WORDS.backToMatch
        local w = Measure(bg, words, Style.FRIZ, L.words.link)
        local B = ns.MatchStoryPage.STORY.stub
        local link = LinkWord(bg, words, B.x + B.w - w, MATCH.back.y, false, nil, function()
            Style.PlaySound("pageTurn")
            YourDiary.OpenMatchBoard(false)
        end)
        link.pad.kind, link.pad.key = "story", "story"
    end

    -- The board, or the slip of names where it never read.
    local order = MatchPage.Order(rows)
    local faceKey = "match:" .. match.id
    local face = bg.faces[faceKey] or 1
    local board = match.board or match.state == "complete"

    -- Which noted rows of this face get a strip in the margin (the
    -- stand-out first, then the repeats met most; MatchPage.Choose), worked
    -- out from the plan before the board is drawn, so only they get the
    -- pencil tick a leader leaves from.
    local S = LOOK.strip
    local ahead = board and MatchPage.Board(#order.with, #order.against, face, match.rolled and (match.lost or 0) > 0)
        or MatchPage.Slip(#order.with, #order.against, face)
    local top0 = board and MATCH.board.y or MATCH.slip.y
    local notes = {}
    for _, r in ipairs(rows) do r.strip = nil end
    for _, at in ipairs(ahead.rows) do
        local r = order[at.side][at.i]
        if r.noted then
            local head, sub = StripWords(r)
            local lines = Wrap(bg, head, Style.NEUTON_ITALIC, S.head, MATCH.strips.w - 2 * S.pad, 2)
            local subs = sub and Wrap(bg, sub, Style.FRIZ, S.sub, MATCH.strips.w - 2 * S.pad, 2) or {}
            notes[#notes + 1] = { r = r, y = top0 + at.y, h = 2 * S.pad + #lines * S.lh + #subs * S.subLh + 2,
                rank = r.standout and 0 or (100 - (r.meets or 0)) + (r.side == "with" and 0.5 or 0),
                lines = lines, subs = subs }
        end
    end
    local chosen = MatchPage.Choose(notes)
    for _, n in ipairs(chosen) do n.r.strip = true end

    local s, shown, plan, box
    if board then
        s, shown, plan, box = Clipping(bg, match, order, players, face)
    else
        s, shown, plan, box = NoBoard(bg, match, order, face)
    end
    bg.faces[faceKey] = plan.face
    bg.plan = plan
    local bottom = box.y + box.h

    -- Every row's hover (its whole row), a diary person's click (their page).
    local B = MATCH.board
    for _, at in ipairs(shown) do
        local r = at.r
        local guid = r.diary
        local hb = at.col and { x = box.x + (at.col == 1 and 8 or 134), y = at.y - 7, w = 126, h = 14 }
            or { x = box.x + 4, y = at.y - B.lh / 2, w = box.w - 8, h = B.lh }
        local hit = Hit(bg, hb, function(self)
            local title, lines = Text.MatchRowTip(r.p, match)
            if guid then lines[#lines + 1] = Text.MATCH.fromDiary end
            Tip(self, title, lines, guid and Text.MATCH.open or nil)
        end, guid and function()
            Style.PlaySound("pageTurn")
            YourDiary.ToPerson(guid)
        end or nil)
        hit.guid = guid
        if guid then hit.pad = { kind = "row", key = "row:" .. guid, words = at.fs, kept = true } end
    end

    -- The lost records' count, told on hover.
    if plan.lost then
        local _, py = s:Out(0, -box.h / 2 + plan.lost)
        Hit(bg, { x = box.x + 20, y = py - 12, w = box.w - 40, h = 22 }, function(self)
            Tip(self, Text.MatchLost(match.lost), { Text.MatchLostTip(match.lost) })
        end).pad = { kind = "lost", key = "lost" }
    end

    -- Turning the board over.
    if plan.turns then
        local words = Text.MatchTurn(plan.face, plan.faces)
        local link = LinkWord(bg, words, box.x + box.w / 2, bottom + 12, true, nil, function()
            Style.PlaySound("pageTurn")
            bg.faces[faceKey] = plan.face % plan.faces + 1
            ns.UI.RedrawJourneyPage()
        end)
        link.pad.kind, link.pad.key = "turn", "turn"
        bottom = bottom + 20
    end

    -- The margin: the strips chosen, in their rows' order, placed from
    -- where the rows were drawn (the board's turn moves them a little).
    local where = {}
    for _, at in ipairs(shown) do where[at.r] = at end
    local marks = {}
    for k, n in ipairs(chosen) do marks[k] = { y = where[n.r] and where[n.r].y or n.y, h = n.h } end
    local placed = MatchPage.Strips(marks)
    for k, b in ipairs(placed) do
        local n = chosen[b.i]
        local at = where[n.r]
        if at then
            b.turn = (Style.Noise(Surface.Seed(tostring(n.r.p.name)) + k) - 0.5) * 2 * MATCH.strips.turn
            local from = { s:Out(-box.w / 2 + B.tickEnd, at.ly) }
            NoteStrip(bg, k, b, n.r, n.lines, n.subs, from, match)
        end
    end
    bg.strips = placed

    -- Your note at the foot.
    local deaths = #(match.deaths or {})
    local deeds
    if match.board or match.state == "complete" then
        deeds = Text.MatchDeeds(Deeds(mine))
    else
        deeds = Text.MATCH_REST
    end
    local noteBox, noteHead = FootNote(bg, 30, MatchPage.NoteY(bottom), MATCH.note.turn, deaths, deeds)
    Hit(bg, noteBox, function(self) DeathsTip(self, match) end).pad = { kind = "note", key = "note", words = noteHead }

    Finish(bg)
    return 0
end

--------------------------------------------------------------------------
-- B: the evening's overview
--------------------------------------------------------------------------

-- Everyone in the session, by key: { key, name, guid, side, ins (the
-- matches' numerals they were in), diary, killedIn, rows }, and the user's
-- deaths and deeds summed.
local function Roll(session, ctx)
    local people, list = {}, {}
    local sum = { deaths = 0, caps = 0, returns = 0, kb = 0 }
    for i, m in ipairs(session.matches) do
        local players = ns.Matches.Players(m)
        local me = m.me or ns.ownGUID
        sum.deaths = sum.deaths + #(m.deaths or {})
        for _, p in ipairs(players) do
            if p.guid and p.guid == me then
                local caps, returns, kb = Deeds(p)
                sum.caps, sum.returns, sum.kb = sum.caps + (caps or 0), sum.returns + (returns or 0), sum.kb + (kb or 0)
            else
                local key = MatchPage.KeyOf(p)
                if key then
                    local who = people[key]
                    if not who then
                        who = { key = key, name = p.name, guid = p.guid, side = ns.Matches.Side(m, p), ins = {},
                            rows = {}, killedIn = 0, diary = ns.Matches.Who(p, ctx.names), first = i, index = #list + 1 }
                        people[key] = who
                        list[#list + 1] = who
                    end
                    if who.ins[#who.ins] ~= i then
                        who.ins[#who.ins + 1] = i
                        who.rows[i] = p
                        if Killed(m, p) > 0 then who.killedIn = who.killedIn + 1 end
                    end
                end
            end
        end
    end
    -- The stand-out: who killed you in the most of them.
    local best
    for _, who in ipairs(list) do
        if who.killedIn > 0 and (not best or who.killedIn > best.killedIn) then best = who end
    end
    if best then best.standout = true end
    return list, sum
end

-- A ticket at `b` for match `m`, the `i`-th; `more` > 0: it stands for
-- the rest ("and 3 more"), opening the first of them.
local function Ticket(bg, i, b, m, more, session)
    local L, K = LOOK, LOOK.ticket
    local s = Strip(bg, "ticket" .. i, L.level.strip)
    LayStrip(s, b, "ticket:" .. m.id, L.paper.tag,
        i % 2 == 0 and { tapeAt = { x = b.w - 12, y = 3, slant = 40, w = 20, h = 9 } } or nil)
    local left, top = -b.w / 2, -b.h / 2
    -- The perforation down its left.
    local P = Style.PAPER
    for k = 0, K.holes - 1 do
        local y = top + 7 + k * 10
        StripLine(s, left + 5, y, left + 7.4, y, 2.4, P, 1)
    end
    local players = ns.Matches.Players(m)
    local head
    if more > 0 then
        head = StripText(s, Style.NEUTON_ITALIC, K.result, Style.INK_STRONG, Text.TicketsMore(more), left + 13, 0)
    else
        StripText(s, Style.FRIZ, K.small, Style.INK_FADED, Text.TicketHead(i, m), left + 13, top + 12)
        head = StripText(s, Style.NEUTON_ITALIC, K.result, Style.INK_STRONG, Text.TicketResult(m), left + 13, top + 31)
        local flags = m.state ~= "left" and Flags(m, players) or nil
        if flags then
            for k = 1, math.min(flags.us, 3) do Pennant(s, left + 54 + (k - 1) * 8, top + 20, true, K.flag) end
            for k = 1, math.min(flags.them, 3) do Pennant(s, left + 54 + (k - 1) * 8, top + 32, false, K.flag) end
        end
        StripText(s, Style.FRIZ, K.small, Style.INK, Text.TicketTime(m.duration), left + 13, top + 52)
    end
    StripDone(s)
    local hit = Hit(bg, b, function(self)
        local me = MyRow(m, players)
        local line, you = Text.TicketTip(m, me, #(m.deaths or {}))
        Tip(self, line, { you }, Text.MATCH.ticketOpen)
        if bg.columns and bg.columns[i] then bg.columns[i]:Show() end
    end, function()
        Style.PlaySound("pageTurn")
        YourDiary.OpenMatch(m.id, nil, session.key)
    end)
    hit:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if bg.columns and bg.columns[i] then bg.columns[i]:Hide() end
    end)
    hit.pad = { kind = "ticket", key = "ticket:" .. m.id, strip = s, heading = head, match = m.id }
    return hit
end

-- Draws the overview of `session` (piece `e`'s) across the right page.
function YourDiary.DrawEvening(e, session)
    local bg = Board()
    bg.board:Show()
    Begin(bg)
    bg.match, bg.session = nil, session
    local L, R = LOOK, EVENING.roll
    local ms = session.matches
    local n = #ms
    local won, seconds = 0, 0
    for _, m in ipairs(ms) do
        if ns.Matches.Won(m) then won = won + 1 end
        seconds = seconds + (m.duration or 0)
    end
    local titleBox, titleFs = Title(bg, Text.MATCH.title, { name = "Battleground" }, Text.EveningSubtitle(n, won, seconds))
    local tipLine = Text.EveningSubtitle(n, won, seconds)
    Hit(bg, titleBox, function(self) Tip(self, Text.MATCH.title, { tipLine }) end).pad =
        { kind = "title", key = "title", words = titleFs }

    -- The tickets.
    local tickets, top = MatchPage.Tickets(n, Surface.Seed("evening:" .. session.key))
    local cols = MatchPage.Columns(n)
    bg.columns = {}
    for i, b in ipairs(tickets) do
        local more = (i == #tickets and n > #tickets) and (n - #tickets + 1) or 0
        Ticket(bg, i, b, ms[i], more, session)
    end

    -- The roll: who matters by hand, everyone else in print.
    local ctx = Context(ms[1])
    local people, sum = Roll(session, ctx)
    local hand, rest = {}, {}
    local rows = {}
    for _, who in ipairs(people) do
        local matters = who.diary or #who.ins >= 2 or who.standout
        if matters then
            rows[#rows + 1] = { who = who, side = who.side, diary = who.diary, meets = #who.ins, standout = who.standout,
                index = who.index }
        else
            rest[#rest + 1] = who
        end
    end
    local order = MatchPage.Order(rows)
    for _, side in ipairs({ "with", "against" }) do
        if #order[side] > 0 then
            if #hand > 0 then hand[#hand + 1] = { h = R.gap } end
            hand[#hand + 1] = { h = R.headH, head = side }
            for _, r in ipairs(order[side]) do hand[#hand + 1] = { h = R.rowH, r = r } end
        end
    end
    table.sort(rest, function(a, b)
        local sa, sb = a.side == "with" and 0 or 1, b.side == "with" and 0 or 1
        if sa ~= sb then return sa < sb end
        if a.first ~= b.first then return a.first < b.first end
        return (a.name or "") < (b.name or "")
    end)
    local faces = MatchPage.Roll(top, hand, #rest)
    local faceKey = "roll:" .. session.key
    local face = math.min(bg.faces[faceKey] or 1, #faces)
    bg.faces[faceKey] = face
    bg.rollFaces = #faces
    local F = faces[face]

    -- Its first line: the turn link and the numerals.
    local lineY = top + 4
    if #faces > 1 then
        local words = Text.RollTurn(face, #faces)
        local link = LinkWord(bg, words, R.x, lineY, false, nil, function()
            Style.PlaySound("pageTurn")
            bg.faces[faceKey] = face % #faces + 1
            ns.UI.RedrawJourneyPage()
        end)
        link.pad.kind, link.pad.key = "turn", "turn"
    end
    for i, x in ipairs(cols) do
        Words(bg, "numeral", Style.FRIZ, L.roll.print, Style.INK_FADED, Text.MatchNumeral(i), x,
            lineY, "CENTER")
        -- The pen's line under a ticket's column, shown while it is hovered.
        local under = Stroke(bg, x - 9, lineY + 8, x + 9, lineY + 8, 1.2, Style.INK_STRONG, 0.9)
        under:Hide()
        bg.columns[i] = under
    end

    -- By hand.
    local G = Style.GRAPHITE
    for _, at in ipairs(F.hand) do
        local line = hand[at.i]
        local y = at.y + line.h / 2
        if line.head then
            Words(bg, "rollHead", Style.NEUTON_ITALIC, L.roll.head, G,
                line.head == "with" and Text.MATCH.withYou or Text.MATCH.againstYou, R.x, y)
            Stroke(bg, R.x, y + 6, 436, y + 5, 0.7, G, L.roll.rule)
        elseif line.r then
            local who = line.r.who
            local ink = who.standout and Style.RUBRIC or who.diary and Style.INK_STRONG or G
            -- (the stand-out's words never reach the first column: where
            -- the whole name leaves no room, the first name alone)
            local name = who.name or "?"
            if who.standout then
                local words = Text.RollKilled(who.killedIn, n)
                local room = cols[1] - 12 - R.nameX - 8 - Measure(bg, words, Style.NEUTON_ITALIC, L.roll.words)
                if Measure(bg, name, Style.NEUTON_ITALIC, L.roll.name) > room then name = First(name) end
            end
            local fs, w = Words(bg, "rollName", Style.NEUTON_ITALIC, L.roll.name, ink, name, R.nameX, y)
            if who.diary then
                Underline(bg, R.nameX - 1, R.nameX + w - 2, y + 8, 0.8, 1.3, Style.RUBRIC, 6)
            end
            if who.standout then
                Words(bg, "rollWords", Style.NEUTON_ITALIC, L.roll.words, Style.RUBRIC, Text.RollKilled(who.killedIn, n),
                    R.nameX + w + 8, y + 1)
            end
            local inIt = {}
            for _, i in ipairs(who.ins) do inIt[i] = true end
            for i, x in ipairs(cols) do
                if inIt[i] then
                    local side = ns.Matches.Side(ms[i], who.rows[i])
                    if side == "with" then
                        Tick(bg, x, y - 1, Style.INK_STRONG, L.roll.pen)
                    else
                        Ring(bg, x, y - 1, 6, 5, Surface.Seed(who.key) + i, G, 1.1)
                    end
                end
            end
            local guid = who.diary
            local hit = Hit(bg, { x = R.nameX - 4, y = y - R.rowH / 2, w = 436 - R.nameX, h = R.rowH }, function(self)
                local with, against = {}, {}
                for _, i in ipairs(who.ins) do
                    local side = ns.Matches.Side(ms[i], who.rows[i])
                    if side == "with" then with[#with + 1] = i else against[#against + 1] = i end
                end
                Tip(self, who.name or "?", Text.RollTip(with, against, n, guid ~= nil), guid and Text.MATCH.open or nil)
            end, guid and function()
                Style.PlaySound("pageTurn")
                YourDiary.ToPerson(guid)
            end or nil)
            hit.guid = guid
            hit.pad = { kind = "hand", key = "hand:" .. who.key, words = fs, kept = guid ~= nil }
        end
    end

    -- In print.
    if F.head then
        local y = F.head + R.printHead / 2
        Words(bg, "rollHead", Style.NEUTON_ITALIC, L.roll.head, G, Text.RollEveryone(#rest), R.x, y)
        Stroke(bg, R.x, y + 6, 436, y + 5, 0.7, G, L.roll.rule)
    end
    if F.print then
        for k = F.print.from, F.print.to do
            local who = rest[k]
            local x, y = MatchPage.PrintAt(F.print, k - F.print.from + 1)
            local ink = who.side == "with" and Style.INK_STRONG or Style.INK_FADED
            local nums = {}
            for j, i in ipairs(who.ins) do nums[j] = Text.MatchNumeral(i) end
            local words = ns.Fmt(ns.L["%1$s  %2$s##roll"], who.name or "?", "|cff705936" .. table.concat(nums, " ") .. "|r")
            Words(bg, "print", Style.FRIZ, L.roll.print, ink, words, x, y + R.printH / 2)
            local i = who.ins[1]
            Hit(bg, { x = x, y = y, w = R.colPW - 6, h = R.printH }, function(self)
                local title, lines = Text.MatchRowTip(who.rows[i], ms[i])
                table.insert(lines, 1, Text.TicketHead(i, ms[i]))
                Tip(self, title, lines)
            end)
        end
    end

    -- Your note, one line for the session.
    local N = EVENING.note
    local plane, turn = Plane(bg, "eveningNote", N.x, N.y, N.turn)
    local fs = Next(bg, "noteText", function() return Style.Text(bg.board, FONT.noteWritten) end)
    Font(fs, Style.NEUTON_ITALIC, L.words.deeds, Style.INK)
    fs:SetText(Text.EveningNote(sum.deaths, sum.caps, sum.returns, sum.kb))
    local w = PlaceText(plane, turn, fs, 0, 0)
    Hit(bg, { x = N.x - 4, y = N.y - 10, w = math.min(w + 8, 430), h = 20 }, function(self)
        local lines = {}
        for i, m in ipairs(ms) do
            lines[#lines + 1] = ns.Fmt(ns.L["%1$s  %2$s##ticket"], Text.MatchNumeral(i), Text.MatchFell(#(m.deaths or {})))
        end
        Tip(self, Text.EveningNote(sum.deaths, sum.caps, sum.returns, sum.kb), lines)
    end).pad = { kind = "note", key = "note", words = fs }

    Finish(bg)
    for _, under in ipairs(bg.columns) do under:Hide() end
    return 0
end

--------------------------------------------------------------------------
-- The kit, for the v2 page drawn on the same board (UI/Journey/MatchStory.lua)
--------------------------------------------------------------------------

-- The same pieces, pools and hits: the story's page is drawn on this board,
-- so what one page leaves unused the other's Finish hides, and the pad finds
-- both pages' hits the one way (MatchParts).
YourDiary.MatchKit = {
    Board = Board, Begin = Begin, Next = Next, Finish = Finish, Font = Font, Measure = Measure, Wrap = Wrap,
    Words = Words, Stroke = Stroke, Strip = Strip, LayStrip = LayStrip, StripText = StripText,
    StripLine = StripLine, StripUnder = StripUnder, StripIcon = StripIcon, StripDone = StripDone,
    Pennant = Pennant, Hit = Hit, LinkWord = LinkWord, Tip = Tip, Title = Title, FootNote = FootNote,
    DeathsTip = DeathsTip, LOOK = LOOK,
}

--------------------------------------------------------------------------
-- For the page and the pad
--------------------------------------------------------------------------

-- What the pad may stand on on a battleground's page as drawn now: {
-- frame = hit, box = hit.box, pad = hit.pad }, in the order drawn (the
-- title first). Empty with neither page open.
function YourDiary.MatchParts()
    local page = YourDiary.page
    local bg = page and (page.mode == "match" or page.mode == "matches") and page.bg
    local out = {}
    if not (bg and bg.board:IsShown()) then return out end
    local hits = bg.used.hit
    for i = 1, hits and hits.n or 0 do
        local hit = hits[i]
        if hit.pad and hit.pad.key then out[#out + 1] = { frame = hit, box = hit.box, pad = hit.pad } end
    end
    return out
end

-- The battleground's page hidden (another page on the right).
function YourDiary.HideMatch()
    local page = YourDiary.page
    if page and page.bg then page.bg.board:Hide() end
end
