-- A Warsong told by time: the match's v2 page in Your Diary
-- (.claude/ui-proposal/battleground-page-v2.md, round 8, S1 approved by
-- Jan; its mockup, battleground-page-v2-mockup.html, is the visual spec;
-- the decisions in .claude/features/battlegrounds.md). It takes the board's
-- place as the match's page wherever Core/MatchStory.lua tells a story
-- (Story.Has: a Warsong with flag lines or fights); the board (v1's page C,
-- UI/Journey/Match.lua) becomes the board view, opened from the corner stub
-- and closed by its "Back to the match" (or B, onto the stub). A match with
-- no story (the other maps, old records) keeps the board as its page.
--
--   head    the way back (as v1), the title and seal, "Won in 7 minutes"
--           under it (Text.StorySub); in the corner the stub of the board's
--           clipping: VICTORY or DEFEAT, the score as pennants, "See the board"
--   lines   the match in two, at one scale, the phases' names in graphite
--           over their stretches and the zerg's (Text.StoryPhase/StoryZerg);
--           the branches, stains, crosses and circled scores as
--           Core/MatchStoryPage.lua lays them; a moved fight's pencil
--           outline where it sat (STORY.moved)
--   strips  S1: a band of paper strips under each line, three at most, each
--           pinned to its second by a pencil leader (Text.StoryStrip's words:
--           the hand, the print, the graphite); a diary person's name
--           underlined in rubric, their strip opening their page
--   foot    your line: the cross, the tally, Text.StoryFoot
--
-- Everything is drawn on the board v1 draws on, from its kit
-- (YourDiary.MatchKit): the same pools (what one page leaves unused, the
-- other's Finish hides) and hits (YourDiary.MatchParts, so the pad finds
-- both pages the one way: UI/Journey/Pad.lua's BuildMatch). A line's marks
-- (its branches' forks, scores, stains and crosses) are hits too, told
-- `kind = "mark"`: the mouse's tooltips, and what the pad walks along a
-- line once A has taken it in (YourDiary.StoryLines). Drawn once as the
-- page opens, never per frame.

local addonName, ns = ...

local Style = ns.Style
local YourDiary = ns.UI.YourDiary
local Text = ns.UI.JourneyText
local Surface = ns.UI.Surface
local SP = ns.MatchStoryPage
local STORY = SP.STORY
local K = YourDiary.MatchKit
local L, Fmt = ns.L, ns.Fmt

local floor, min, max, abs, cos, sin, pi = math.floor, math.min, math.max, math.abs, math.cos, math.sin, math.pi

-- The page's tooltips and the board view's way back (/copywriter, 11 Nov;
-- the pad's prompts are in UI/Journey/Pad.lua). Every time is the match's
-- clock ("6:42"), so a fight's title says so: "A fight, 6:30 into the
-- match"; a death under it, "Koko fell to Hesk at 6:42".
local WORDS = {
    backToMatch = L["Back to the match"],
    fight = L["A fight, %1$s into the match##story"],
    sides = L["%1$d of us against %2$d of them##story"],
    fell = L["%1$s fell at %2$s##story"],
    fellTo = L["%1$s fell to %3$s at %2$s##story"],
    ours = L["%1$s carried their flag##story"],
    theirs = L["%1$s carried our flag##story"],
    home = L["Brought home at %1$s##story"],
    back = L["Brought back at %1$s##story"],
    out = L["Still out when the match ended##story"],
}
YourDiary.STORY_WORDS = WORDS

-- The look, beside the plan's places (Core/MatchStoryPage.lua's STORY):
--   line     the base line by the pen: `width` px in strong ink; the start's
--            tick `tick` px either way
--   branch   ours `ours` px in strong ink, theirs `theirs` px in faded ink
--            (fainter: Jan, "ours above in ink, theirs below fainter"), at
--            `alpha`; the return's stroke `back` px in the returning side's
--            ink; a stroke sampled every `step` px, jittered `jitter`
--   dots     the flag lying: pencil dots `size` px at `alpha`
--   ring     the circled score: the pen `width` px, `n` points round, its
--            figures Friz `size`
--   name     a phase's name in the hand, `size` pt, graphite
--   cross    a death: its arms `w` by `h` px (and `bar` across), yours
--            `you` times that on a dot of paper `halo` px; nobody named is
--            a small hollow ring
--   stain    the trail's rust (Ink.TINT.fighting); at most `cap` pieces of
--            blot on the page (the plates' CAP.dabs share, drawn once)
--   strip    a strip's writing: the hand `head` pt (`lh` a line), `small` at
--            three lines; what the diary remembers `sub` pt; the print Friz
--            `print` pt; the graphite `graphite` pt; `pad` px round it; the
--            class icon `icon` px. Paper: the friend who killed you and the
--            nemesis on the tag's fresher stock (the mockup's), the rest a
--            slip's
--   leader   graphite `width` px at `alpha`, ending `stop` px short in a dot
--            `dot` px; under the mouse or the pad, in strong ink at `hot`
--   moved    a moved fight's outline: dashes `dash` px, `gap` apart, `width`
--            px graphite at `alpha`, `ry` px tall
--   hit      a mark's hover square, `mark` px; a stain's at least that tall
--   level    how far over the board the stub and the strips lie; the marks'
--            hits over the strips' (`marks`, over the board's 20)
local INK, STRONG, FADED, GRAPHITE, RUBRIC = Style.INK, Style.INK_STRONG, Style.INK_FADED, Style.GRAPHITE,
    Style.RUBRIC
local LOOK = {
    line = { width = 1.5, tick = 6 },
    branch = { ours = 1.9, theirs = 1.6, alpha = 0.96, back = 1.7, step = 3.5, jitter = 0.9 },
    dots = { size = 1.7, alpha = 0.9 },
    ring = { width = 1.25, n = 26, size = 11 },
    name = { size = 14 },
    cross = { w = 1.7, h = 7, bar = 5.2, you = 1.25, halo = 9 },
    stain = { cap = 1000 },
    strip = { head = 16, lh = 18, small = 14, smallLh = 16, sub = 14, subLh = 16, print = 11, printLh = 13,
        graphite = 13, gLh = 15, pad = 7, icon = 9, top = 4, foot = 6 },
    leader = { width = 1.1, alpha = 0.8, stop = 4, dot = 3.6, hot = 1 },
    moved = { dash = 2, gap = 2.4, width = 0.8, alpha = 0.55, ry = 5 },
    hit = { mark = 12 },
    level = { stub = 3, strip = 3, marks = 21 },
}
YourDiary.STORY_LOOK = LOOK

-- The pen's nib for the lines: nearly even (a steel dip pen, not the
-- trail's broad nib), so a straight line reads as one weight.
local NIB = { angle = 40, thin = 0.85, thick = 1.1 }

--------------------------------------------------------------------------
-- Drawing on the board
--------------------------------------------------------------------------

-- What was drawn, for the render (tests/battleground_story_ui.lua,
-- YourDiary.storyTrace set): quads, discs, boxes, words and strips on the
-- page, in px from its top left.
local function Trace(bg, item)
    if bg.trace then bg.trace[#bg.trace + 1] = item end
end

local function Texture(bg, kind, layer, sub)
    local t = K.Next(bg, kind, function() return bg.board:CreateTexture(nil, layer, nil, sub or 0) end)
    return t
end

-- A quad of the pen's (UI/Ink/Pen.lua's primitive) on the board; where the
-- client cannot move corners, a turned rectangle along its middle.
local function Quad(bg, q, kind, layer, sub)
    local t = Texture(bg, kind or "storyQuad", layer or "OVERLAY", sub)
    if t.SetDrawLayer then t:SetDrawLayer(layer or "OVERLAY", sub or 0) end
    t:SetVertexColor(1, 1, 1, 1)
    t:SetColorTexture(q.r, q.g, q.b, q.a)
    if not Style.Quad(t, bg.board, q.x1, q.y1, q.x2, q.y2, q.x3, q.y3, q.x4, q.y4) then
        local sx, sy = (q.x1 + q.x4) / 2, (q.y1 + q.y4) / 2
        local ex, ey = (q.x2 + q.x3) / 2, (q.y2 + q.y3) / 2
        local dx, dy = ex - sx, ey - sy
        local w = (math.sqrt((q.x1 - q.x4) ^ 2 + (q.y1 - q.y4) ^ 2) + math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2)) / 2
        t:ClearAllPoints()
        t:SetSize(math.sqrt(dx * dx + dy * dy) + 0.4, max(w, 0.5))
        t:SetPoint("CENTER", bg.board, "TOPLEFT", (sx + ex) / 2, -(sy + ey) / 2)
        if t.SetRotation then t:SetRotation(math.atan2(-dy, dx)) end
    end
    Trace(bg, { k = "q", q = q })
    return t
end

-- A line by the pen along flat points (x, y, ...): resampled, mitred and
-- stroked into quads (as the leaders are, UI/Journey/Leaders.lua), `width`
-- px. Returns its textures (a leader recolours them under the mouse).
local function PenLine(bg, pts, width, colour, alpha, step, kind)
    local Pen = ns.UI.Pen
    local P = Pen.Resample(pts, step or 3)
    local made = {}
    if #P < 2 then return made end
    local M = Pen.Mitres(P)
    local n = #P
    local prims = {}
    Pen.Stroke(prims, 0, P, M, function(i)
        local a, b = P[max(i - 1, 1)], P[min(i + 1, n)]
        return width / 2 * Pen.Nib(b.x - a.x, b.y - a.y, NIB)
    end, function() return 0 end, function() return alpha end, colour)
    for _, q in ipairs(prims) do made[#made + 1] = Quad(bg, q, kind) end
    return made
end

-- A round dot of `d` px at x, y.
local function Dot(bg, x, y, d, colour, alpha, kind, layer)
    local t = Texture(bg, kind or "storyDot", layer or "OVERLAY", 1)
    Style.Disc(t, colour[1], colour[2], colour[3], alpha or 1)
    t:ClearAllPoints()
    t:SetSize(d, d)
    t:SetPoint("CENTER", bg.board, "TOPLEFT", x, -y)
    if t.SetRotation then t:SetRotation(0) end
    Trace(bg, { k = "d", x = x, y = y, d = d, c = colour, a = alpha or 1 })
    return t
end

-- A flat box w by h with its middle at x, y.
local function Box(bg, x, y, w, h, colour, alpha)
    local t = Texture(bg, "storyBox", "OVERLAY", 3)
    t:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
    t:ClearAllPoints()
    t:SetSize(w, h)
    t:SetPoint("CENTER", bg.board, "TOPLEFT", x, -y)
    if t.SetRotation then t:SetRotation(0) end
    Trace(bg, { k = "b", x = x, y = y, w = w, h = h, c = colour, a = alpha or 1 })
    return t
end

-- Words straight on the board (K.Words), traced.
local function Words(bg, kind, path, size, colour, words, x, y, justify, alpha)
    local fs, w = K.Words(bg, kind, path, size, colour, words, x, y, justify, alpha)
    Trace(bg, { k = "t", x = x, y = y, w = w, size = size, text = words, c = colour, justify = justify,
        hand = path ~= Style.FRIZ })
    return fs, w
end

-- A death's cross at x, y (the plates' death mark: an upright and a bar
-- high on it), `k` its scale; on a dot of paper where `halo`.
local function Cross(bg, x, y, k, colour, halo)
    local C = LOOK.cross
    if halo then Dot(bg, x, y, C.halo * k, Style.PAPER, 0.8, "storyHalo") end
    Box(bg, x, y + 0.5 * k, C.w * k, C.h * k, colour, 1)
    Box(bg, x, y - 1.5 * k, C.bar * k, C.w * k, colour, 1)
end

-- The pen's ring round a point: an ellipse rx by ry, its ends overlapping a
-- little where the pen came round (seeded), as the mockup's.
local function Ring(bg, cx, cy, rx, ry, seed, colour)
    local R = LOOK.ring
    local rand = ns.UI.Pen.Random(seed)
    local a0 = 3.6 + rand() * 0.4
    local pts = {}
    for i = 0, R.n do
        local a = a0 + i / (R.n - 2) * pi * 2
        local k = 1 + (i / R.n) * 0.07 + (rand() - 0.5) * 0.04
        pts[#pts + 1] = cx + cos(a) * rx * k
        pts[#pts + 1] = cy + sin(a) * ry * k
    end
    PenLine(bg, pts, R.width, colour, 0.95, 2)
end

-- A hit over a mark of a line (`kind = "mark"`): the mouse's tooltip, the
-- pad's stop once it is in the line. Over the strips' hits.
local function Mark(bg, line, key, b, tip)
    local hit = K.Hit(bg, b, tip)
    hit:SetFrameLevel(bg.board:GetFrameLevel() + LOOK.level.marks)
    hit.pad = { kind = "mark", key = "mark:" .. line.i .. ":" .. key, line = line.i }
    line.marks[#line.marks + 1] = hit
    return hit
end

--------------------------------------------------------------------------
-- What the marks say (their tooltips)
--------------------------------------------------------------------------

local function First(name)
    return name and name:match("^(%S+)") or name
end

-- A reference's first name: "You" for yours ("you" mid-line, `mid`); a
-- name rubbed out or never read is "one of ours" / "one of theirs" by
-- `side` ("us" or "them"), else "someone".
local function Named(story, ref, side, mid)
    if ref == "0" then return mid and L["you##story"] or Text.MATCH.you end
    local n = ref and First(story.Name(ref))
    if n then return n end
    if side == "us" then return mid and L["one of ours##story"] or L["One of ours##story"] end
    if side == "them" then return mid and L["one of theirs##story"] or L["One of theirs##story"] end
    return mid and L["someone##story"] or L["Someone##story"]
end

local function Other(side)
    return side == "us" and "them" or side == "them" and "us" or nil
end

local function FightTip(self, story, g)
    local list = {}
    for _, x in ipairs(g.fights) do
        list[#list + 1] = Fmt(WORDS.sides, #x.us, #x.them)
        for _, d in ipairs(x.deaths or {}) do
            local by = d.killer and Named(story, d.killer, Other(d.side), true)
            list[#list + 1] = by and Fmt(WORDS.fellTo, Named(story, d.who, d.side), Text.StoryClock(d.t), by)
                or Fmt(WORDS.fell, Named(story, d.who, d.side), Text.StoryClock(d.t))
        end
    end
    local title = Fmt(WORDS.fight, Text.StoryClock(g.a))
    if g.zerg and story.zerg then title = Text.StoryZerg() end
    K.Tip(self, title, list)
end

local function CarryTip(self, story, c)
    local who = {}
    for _, h in ipairs(c.holds) do
        local n = h.who and Named(story, h.who, c.side, #who > 0)
        if n and who[#who] ~= n then who[#who + 1] = n end
    end
    local names = ns.UI.Format.List(who) or Named(story, nil, c.side)
    local title = Fmt(c.side == "us" and WORDS.ours or WORDS.theirs, names)
    local list = {}
    if c.ends == "captured" then list[1] = Fmt(WORDS.home, Text.StoryClock(c.to))
    elseif c.ends == "returned" then list[1] = Fmt(WORDS.back, Text.StoryClock(c.to))
    elseif c.ends == "open" then list[1] = WORDS.out end
    K.Tip(self, title, list)
end

local function CrossTip(self, story, d)
    local who = Named(story, d.who, d.side)
    local by = (d.killer and Named(story, d.killer, Other(d.side), true)) or (d.killerName and First(d.killerName))
    K.Tip(self, by and Fmt(WORDS.fellTo, who, Text.StoryClock(d.t), by) or Fmt(WORDS.fell, who, Text.StoryClock(d.t)))
end

-- Words on strip `s` (K.StripText), traced at their place on the page.
local function Write(bg, s, path, size, colour, words, lx, ly, justify)
    local fs, w = K.StripText(s, path, size, colour, words, lx, ly, justify)
    if bg.trace then
        local px, py = s:Out(lx + (justify == "CENTER" and 0 or w / 2), ly)
        Trace(bg, { k = "t", x = px - w / 2, y = py, w = w, size = size, text = words, c = colour,
            hand = path ~= Style.FRIZ, turn = s.turn })
    end
    return fs, w
end

--------------------------------------------------------------------------
-- The corner stub
--------------------------------------------------------------------------

-- The stub of the board's clipping, tucked in the corner: VICTORY or
-- DEFEAT, the flags each side took as pennants, "See the board" (opens the
-- board view).
local function Stub(bg, story, match)
    local S = STORY.stub
    local s = K.Strip(bg, "stub", LOOK.level.stub)
    local b = { x = S.x, y = S.y, w = S.w, h = S.h, turn = S.turn }
    K.LayStrip(s, b, "match:" .. match.id .. ":stub", K.LOOK.paper.clip,
        { tapeAt = { x = S.w - 34, y = 3, slant = 24, w = 24, h = 10 } })
    local left, top = -S.w / 2, -S.h / 2
    local x = left + S.pad
    local word = Text.StoryResult(story)
    if word then
        local _, w = Write(bg, s, Style.FRIZ, S.word, STRONG, word, x, top + S.wordY)
        x = x + w + 6
    end
    local score = story.score or { us = 0, them = 0 }
    for _ = 1, min(score.us, 3) do
        K.Pennant(s, x, top + S.wordY - 5, true, S.pennant)
        x = x + S.step
    end
    x = x + 4
    for _ = 1, min(score.them, 3) do
        K.Pennant(s, x, top + S.wordY - 5, false, S.pennant)
        x = x + S.step
    end
    local see = Text.StorySeeBoard()
    local link, lw = Write(bg, s, Style.FRIZ, S.link, INK, see, left + S.pad, top + S.linkY)
    local line = K.StripLine(s, left + S.pad, top + S.linkY + S.link / 2 + 1, left + S.pad + lw - 2,
        top + S.linkY + S.link / 2 + 1, 1, GRAPHITE, Style.HAIRLINE)
    K.StripDone(s)
    Trace(bg, { k = "strip", s = s, b = b, paper = K.LOOK.paper.clip })
    local hit = K.Hit(bg, b, function(self)
        link:SetTextColor(STRONG[1], STRONG[2], STRONG[3], 1)
        line:SetColorTexture(STRONG[1], STRONG[2], STRONG[3], Style.HAIRLINE_HOT)
        K.Tip(self, see, { Text.MatchSubtitle(match) })
    end, function()
        Style.PlaySound("pageTurn")
        YourDiary.OpenMatchBoard(true)
    end)
    hit:SetScript("OnLeave", function()
        GameTooltip:Hide()
        link:SetTextColor(INK[1], INK[2], INK[3], 1)
        line:SetColorTexture(GRAPHITE[1], GRAPHITE[2], GRAPHITE[3], Style.HAIRLINE)
    end)
    hit.pad = { kind = "stub", key = "stub", strip = s, heading = link }
    return s
end

--------------------------------------------------------------------------
-- A strip in the band
--------------------------------------------------------------------------

-- The class of a diary person on the board, for the strip's icon.
local function ClassOf(match, guid)
    if not guid then return nil end
    for _, p in ipairs(ns.Matches.Players(match)) do
        if p.guid == guid then return p.class end
    end
end

-- A strip's small drawing (the mockup's glyph): { kind, n, m, w }.
local function Glyph(bg, s)
    local k = s.kind
    local function Tally(n) return floor(n / 5) * (4 * 3.6 + 8) + (n % 5) * 3.6 + 2 end
    if k == "friend" or k == "nemesis" then
        local n = #(s.times or {})
        if n > 0 then return { kind = "tally", n = n, crosses = n, w = Tally(n) + 6 + n * 8 } end
    elseif k == "zerg" then
        if (s.fights or 0) > 0 then return { kind = "tally", n = s.fights, crosses = 0, w = Tally(s.fights) + 2 } end
    elseif k == "duel" then
        return { kind = "dots", n = 1, m = 1, w = 7 + 5 + 7 + 2 }
    elseif k == "outnumbered" then
        local n, m = min(s.us or 0, 6), min(s.them or 0, 8)
        return { kind = "dots", n = n, m = m, w = n * 7 + 5 + m * 7 + 2 }
    elseif k == "revenge" then
        return { kind = "crosses", n = 1, faded = true, w = 12 }
    elseif k == "together" then
        return { kind = "crosses", n = 2, w = 21 }
    elseif k == "carry" then
        return { kind = "pennant", w = 14 }
    elseif k == "return" then
        return { kind = "back", w = 21 }
    elseif k == "evening" and s.count then
        local t = Text.MatchNumeral(s.count)
        return { kind = "numeral", text = t, w = K.Measure(bg, t, Style.FRIZ, LOOK.strip.print) + 5 }
    end
    return nil
end

-- Where everything on a strip `w` px wide goes, before it is laid (its
-- height is the plan's): { h, head = { lines, size, lh }, sub, print,
-- graphite (lines), glyph, icon }. Taller than the band, it gives up its
-- graphite, then what the diary remembers, then a line of the print.
local function StripPlan(bg, s, story, w, match)
    local S = LOOK.strip
    local words = Text.StoryStrip(s, story)
    local W = w - 2 * S.pad - 1
    local class = (s.kind == "acquaintance" or s.kind == "person") and ClassOf(match, s.guid) or nil
    local ix = class and 14 or 0
    local function Lines(t, path, size, width, most)
        if not t or t == "" then return {} end
        return K.Wrap(bg, t, path, size, width, most)
    end
    local plan = { words = words, class = class, ix = ix }
    local size, lh = S.head, S.lh
    local head = Lines(words.head, Style.NEUTON_ITALIC, size, W - ix, 3)
    if #head > 2 then
        size, lh = S.small, S.smallLh
        head = Lines(words.head, Style.NEUTON_ITALIC, size, W - ix, 3)
    end
    plan.head = { lines = head, size = size, lh = lh }
    plan.sub = Lines(words.sub, Style.NEUTON_ITALIC, S.sub, W, 2)
    plan.glyph = Glyph(bg, s)
    local gw = plan.glyph and plan.glyph.w or 0
    plan.print = Lines(words.print, Style.FRIZ, S.print, W - gw - (gw > 0 and 4 or 0), 2)
    plan.graphite = Lines(words.graphite, Style.NEUTON_ITALIC, S.graphite, W, 2)
    local function Height()
        local h = S.top + #plan.head.lines * plan.head.lh + #plan.sub * S.subLh
        if plan.glyph or #plan.print > 0 then h = h + max(15, #plan.print * S.printLh + 2) end
        return h + #plan.graphite * S.gLh + S.foot
    end
    local most = STORY.band.h
    if Height() > most then plan.graphite = {} end
    if Height() > most then plan.sub = {} end
    if Height() > most and #plan.print > 1 then plan.print = { plan.print[1] } end
    plan.h = Height()
    return plan
end

-- A disc on strip `s` (its own pool on the strip's pieces, hidden after).
local function StripDisc(s, lx, ly, d, colour, alpha, hollow)
    local p = s.bg
    p.discs = p.discs or {}
    p.d = (p.d or 0) + 1
    local t = p.discs[p.d]
    if not t then
        t = s:CreateTexture(nil, "OVERLAY")
        p.discs[p.d] = t
    end
    Style.Disc(t, colour[1], colour[2], colour[3], alpha or 1)
    s:Lay(t, lx, ly, d, d)
    t:Show()
    if hollow then
        -- (theirs: a ring, the paper's dot inside the ink's)
        p.d = p.d + 1
        local inner = p.discs[p.d]
        if not inner then
            inner = s:CreateTexture(nil, "OVERLAY", nil, 1)
            p.discs[p.d] = inner
        end
        local paper = s.Paper and s:Paper() or Style.PAPER
        Style.Disc(inner, paper[1], paper[2], paper[3], 1)
        s:Lay(inner, lx, ly, d - 2.2, d - 2.2)
        inner:Show()
    end
end

local function StripDiscsDone(s)
    local p = s.bg
    for i = (p.d or 0) + 1, #(p.discs or {}) do p.discs[i]:Hide() end
    p.d = 0
end

-- A strip's small drawing from lx (its left), its middle at ly.
local function DrawGlyph(s, g, lx, ly)
    if g.kind == "tally" then
        local x = lx
        local left = g.n
        while left > 0 do
            local k = min(5, left)
            for j = 1, min(k, 4) do K.StripLine(s, x + (j - 1) * 3.6, ly - 4.5, x + (j - 1) * 3.6 + 0.6, ly + 4.5, 1.3, STRONG, 1) end
            if k == 5 then K.StripLine(s, x - 1.5, ly + 3, x + 4 * 3.6 - 1, ly - 3, 1.2, STRONG, 1) end
            x = x + (k == 5 and (4 * 3.6 + 8) or k * 3.6)
            left = left - k
        end
        x = x + 6
        for _ = 1, g.crosses or 0 do
            K.StripLine(s, x + 3, ly - 3.5, x + 3, ly + 4, 1.5, STRONG, 1)
            K.StripLine(s, x + 0.6, ly - 1.3, x + 5.4, ly - 1.3, 1.5, STRONG, 1)
            x = x + 8
        end
    elseif g.kind == "dots" then
        local x = lx + 3
        for _ = 1, g.n do StripDisc(s, x, ly, 5.2, STRONG, 1) x = x + 7 end
        x = x + 5
        for _ = 1, g.m do StripDisc(s, x, ly, 5, FADED, 1, true) x = x + 7 end
    elseif g.kind == "crosses" then
        local colour = g.faded and FADED or STRONG
        local x = lx
        for _ = 1, g.n do
            K.StripLine(s, x + 4, ly - 4, x + 4, ly + 4, 1.6, colour, 1)
            K.StripLine(s, x + 1.4, ly - 1.6, x + 6.6, ly - 1.6, 1.6, colour, 1)
            x = x + 9
        end
    elseif g.kind == "pennant" then
        K.Pennant(s, lx + 2, ly - 7, true, 0.8)
    elseif g.kind == "back" then
        -- (the branch coming back down onto the line: the glyph of a return)
        K.StripLine(s, lx, ly + 4, lx + 17, ly + 4, 0.9, GRAPHITE, 0.8)
        K.StripLine(s, lx, ly - 5, lx + 5, ly - 5, 1.6, STRONG, 1)
        local px, py = lx + 5, ly - 5
        for i = 1, 8 do
            local k = i / 8
            local x, y = lx + 5 + 7 * k, ly - 5 + 9 * (0.5 - 0.5 * cos(pi * k))
            K.StripLine(s, px, py, x, y, 1.6, STRONG, 1)
            px, py = x, y
        end
        K.StripLine(s, px, py, lx + 17, ly + 4, 1.6, STRONG, 1)
    elseif g.kind == "numeral" then
        K.StripText(s, Style.FRIZ, LOOK.strip.print, STRONG, g.text, lx, ly)
    end
end

-- A strip of the band at box `b`, written from its plan; its leader to x, y
-- (its moment on the line). Returns its hit.
local function BandStrip(bg, k, b, s, plan, story, match, tx, ty)
    local S, LD = LOOK.strip, LOOK.leader
    local strip = K.Strip(bg, "story" .. k, LOOK.level.strip)
    local tag = STORY.sizes[s.kind] == "L"
    local paper = tag and K.LOOK.paper.tag or K.LOOK.paper.slip
    K.LayStrip(strip, b, "match:" .. match.id .. ":story:" .. s.kind .. ":" .. floor(s.t or 0), paper,
        { tapeAt = { x = b.w * (tag and 0.8 or 0.2), y = 3, slant = tag and 30 or -30, w = 22, h = 10 } })
    local left, top = -b.w / 2, -b.h / 2
    local y = top + S.top
    local lx = left + S.pad
    local heading
    local name = s.guid and First(s.name)
    for i, l in ipairs(plan.head.lines) do
        local ly = y + plan.head.lh / 2
        if i == 1 and plan.class then K.StripIcon(strip, plan.class, lx + 4, ly + 1, S.icon) end
        local hx = lx + plan.ix
        local fs = Write(bg, strip, Style.NEUTON_ITALIC, plan.head.size, STRONG, l, hx, ly)
        heading = heading or fs
        -- (a diary person's name underlined in rubric, as on the board)
        local at = name and l:find(name, 1, true)
        if at then
            local a = K.Measure(bg, l:sub(1, at - 1), Style.NEUTON_ITALIC, plan.head.size)
            local w = K.Measure(bg, name, Style.NEUTON_ITALIC, plan.head.size)
            K.StripUnder(strip, hx + a - 1, hx + a + w - 2, ly + plan.head.size * 0.42, 0.8, 1.3, RUBRIC, 6)
        end
        y = y + plan.head.lh
    end
    for _, l in ipairs(plan.sub) do
        Write(bg, strip, Style.NEUTON_ITALIC, S.sub, INK, l, lx, y + S.subLh / 2)
        y = y + S.subLh
    end
    if plan.glyph or #plan.print > 0 then
        local gw = plan.glyph and plan.glyph.w or 0
        if plan.glyph then DrawGlyph(strip, plan.glyph, lx, y + 8) end
        for i, l in ipairs(plan.print) do
            Write(bg, strip, Style.FRIZ, S.print, INK, l, lx + gw + (gw > 0 and 4 or 0), y + 8 + (i - 1) * S.printLh)
        end
        y = y + max(15, #plan.print * S.printLh + 2)
    end
    for _, l in ipairs(plan.graphite) do
        Write(bg, strip, Style.NEUTON_ITALIC, S.graphite, GRAPHITE, l, lx, y + S.gLh / 2)
        y = y + S.gLh
    end
    K.StripDone(strip)
    StripDiscsDone(strip)
    Trace(bg, { k = "strip", s = strip, b = b, paper = paper })

    -- The leader: out of the strip's nearest edge to its moment, in pencil.
    local pts, ex, ey = SP.Leader(b, tx, ty, LD.stop)
    local strokes = PenLine(bg, pts, LD.width, GRAPHITE, LD.alpha, 3, "storyLeader")
    local dot = Dot(bg, ex, ey, LD.dot, GRAPHITE, 0.9, "storyLeaderDot")
    local function Ink(hot)
        local c, a = hot and STRONG or GRAPHITE, hot and LD.hot or LD.alpha
        for _, t in ipairs(strokes) do t:SetColorTexture(c[1], c[2], c[3], a) end
        dot:SetVertexColor(c[1], c[2], c[3], hot and 1 or 0.9)
    end

    local guid = s.guid
    local words = plan.words
    local hit = K.Hit(bg, b, function(self)
        Ink(true)
        local lines = {}
        if words.print then lines[#lines + 1] = words.print end
        if words.graphite then lines[#lines + 1] = words.graphite end
        if guid then lines[#lines + 1] = Text.MATCH.fromDiary end
        K.Tip(self, words.head or "", lines, guid and Text.MATCH.open or nil)
    end, guid and function()
        Style.PlaySound("pageTurn")
        YourDiary.ToPerson(guid)
    end or nil)
    hit:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Ink(false)
    end)
    hit.guid = guid
    hit.pad = { kind = "strip", key = "story:" .. s.kind .. ":" .. floor(s.t or 0), strip = strip, heading = heading,
        kept = guid ~= nil }
    return hit, strip
end

--------------------------------------------------------------------------
-- A line
--------------------------------------------------------------------------

-- The rust of a fight: Ink.Stain's blot (UI/Ink/Trail.lua) over each piece,
-- its primitives on the board under the lines.
local function Stain(bg, piece, seed)
    local Ink = ns.UI.InkTrail
    if bg.stainRoom <= 0 then return end
    local pool = { e = { x = piece.x, y = piece.y, a1 = piece.a1, a2 = piece.a2, theta = 0 }, F = piece.F,
        tint = Ink.TINT.fighting, stains = {} }
    for _, d in ipairs(piece.deaths) do pool.stains[#pool.stains + 1] = { e = { x = d.x, y = d.y } } end
    local out = {}
    local used = Ink.Stain(out, pool, seed % 9973, { dabs = min(Ink.STAIN.cap, bg.stainRoom) })
    bg.stainRoom = bg.stainRoom - used
    for _, prim in ipairs(out) do
        if prim.k == "q" then
            Quad(bg, prim, "storyStain", "ARTWORK", prim.layer)
        else
            local t = Texture(bg, "storyStainDisc", "ARTWORK", prim.layer)
            if t.SetDrawLayer then t:SetDrawLayer("ARTWORK", prim.layer) end
            Style.Disc(t, prim.r, prim.g, prim.b, prim.a)
            t:ClearAllPoints()
            t:SetSize(2 * prim.rx, 2 * prim.ry)
            t:SetPoint("CENTER", bg.board, "TOPLEFT", prim.x, -prim.y)
            if t.SetRotation then t:SetRotation(-prim.th) end
            Trace(bg, { k = "e", x = prim.x, y = prim.y, rx = prim.rx, ry = prim.ry, c = { prim.r, prim.g, prim.b }, a = prim.a })
        end
    end
end

-- A wobbling stroke from xa to xb along y = f(x) (seeded): the base line's
-- and a branch's.
local function Along(xa, xb, f, step, jitter, rand)
    local n = max(2, floor((xb - xa) / step + 0.5))
    local pts = {}
    for i = 0, n do
        local x = xa + (xb - xa) * i / n
        pts[#pts + 1] = x
        pts[#pts + 1] = f(x) + ((i > 0 and i < n) and (rand() - 0.5) * jitter or 0)
    end
    return pts
end

local function DrawLine(bg, story, ln, match, seed)
    local LL, B, LT = STORY.lines, LOOK.branch, LOOK.line
    local rand = ns.UI.Pen.Random(seed)
    local branches, by = SP.Branches(story, ln)
    local line = { i = ln.i, key = "line:" .. ln.i, marks = {}, ln = ln }
    bg.storyLines[ln.i] = line
    line.box = { x = 12, y = ln.top + 4, w = 442, h = ln.Y + LL.down - ln.top - 4 }

    -- The stains first, under everything.
    local stains = SP.Stains(story, ln, by)
    for gi, g in ipairs(stains) do
        for k, p in ipairs(g.pieces) do Stain(bg, p, seed * 31 + gi * 7 + k) end
    end

    -- Where a moved fight sat on the base line: a faint dashed outline.
    if STORY.moved then
        local M = LOOK.moved
        for _, x in ipairs(story.fights or {}) do
            if x.moved and x.from >= ln.from and x.from < ln.to then
                local cx = ln.X((x.from + x.to) / 2)
                local rx = (min(x.to, ln.to) - x.from) * ln.pps / 2 + 3
                local per = max(12, floor(pi * (rx + M.ry) / (M.dash + M.gap)))
                for i = 0, per - 1 do
                    local a0, a1 = i / per * 2 * pi, (i + M.dash / (M.dash + M.gap)) / per * 2 * pi
                    K.Stroke(bg, cx + cos(a0) * rx, ln.Y + sin(a0) * M.ry, cx + cos(a1) * rx, ln.Y + sin(a1) * M.ry,
                        M.width, GRAPHITE, M.alpha)
                    Trace(bg, { k = "l", x1 = cx + cos(a0) * rx, y1 = ln.Y + sin(a0) * M.ry, x2 = cx + cos(a1) * rx,
                        y2 = ln.Y + sin(a1) * M.ry, w = M.width, c = GRAPHITE, a = M.alpha })
                end
            end
        end
    end

    -- The base line, broken at each capture.
    for _, piece in ipairs(SP.Base(story, ln)) do
        if piece.xb - piece.xa > 1 then
            PenLine(bg, Along(piece.xa, piece.xb, function() return ln.Y end, LL.seg, LL.wobble, rand), LT.width, STRONG, 1, 3)
        end
    end
    if ln.from <= 0 then
        PenLine(bg, { ln.X0, ln.Y - LT.tick, ln.X0, ln.Y + LT.tick }, 1.3, STRONG, 1, 3)
    end

    -- The branches.
    for _, g in ipairs(branches) do
        local c = g.c
        local ours = g.s < 0
        local colour, width = ours and STRONG or FADED, ours and B.ours or B.theirs
        for k, h in ipairs(g.holds) do
            local xa = k == 1 and g.xa or h.xa
            local xb = max(h.xb, xa + 1)
            PenLine(bg, Along(xa, xb, function(x) return ln.Y + g.s * LL.lift * g.H(x) end, B.step, B.jitter, rand),
                width, colour, B.alpha, 2.5)
        end
        for _, l in ipairs(g.lying) do
            local D = LOOK.dots
            local x = l.xa + 2.2
            local stop = max(l.xb, l.xa + 4) - 0.5
            while x < stop do
                Dot(bg, x, ln.Y + g.s * LL.lift + (rand() - 0.5) * 0.6, D.size, GRAPHITE, D.alpha)
                x = x + STORY.branch.dots
            end
        end
        if g.back then
            -- Back down onto the line, forward in time, in the ink of the
            -- side that returned it (a flag is returned by its own side).
            local back = c.side == "us" and FADED or STRONG
            local pts = {}
            for i = 0, 10 do
                local k = i / 10
                pts[#pts + 1] = g.back.x0 + (g.back.x1 - g.back.x0) * k
                pts[#pts + 1] = g.back.y0 + (g.back.y1 - g.back.y0) * (0.5 - 0.5 * cos(pi * k))
            end
            PenLine(bg, pts, B.back, back, 0.97, 2)
        end
        if g.cap and c.score then
            local R = STORY.branch
            local col = ours and STRONG or FADED
            Ring(bg, g.cap.x, g.cap.y, R.rx, R.ry, Surface.Seed("ring:" .. match.id .. ":" .. floor(c.to)), col)
            Words(bg, "storyScore", Style.FRIZ, LOOK.ring.size, col, ("%d\226\128\147%d"):format(c.score.us, c.score.them),
                g.cap.x, g.cap.y, "CENTER")
            Mark(bg, line, "score:" .. floor(c.to), { x = g.cap.x - R.rx, y = g.cap.y - R.ry, w = 2 * R.rx, h = 2 * R.ry },
                function(self) CarryTip(self, story, c) end)
        end
        -- The fork: where the flag was picked up.
        local fx, fy = g.At(c.from + 1)
        if c.from >= ln.from then
            local H = LOOK.hit.mark
            Mark(bg, line, "carry:" .. c.n, { x = g.xa - 2, y = min(fy, ln.Y) - (ours and H / 2 or 2), w = H, h = H },
                function(self) CarryTip(self, story, c) end)
        end
    end

    -- The stains' hits, over the branches' strokes.
    for gi, g in ipairs(stains) do
        local H = LOOK.hit.mark
        local x0 = ln.X(g.a) - 3
        Mark(bg, line, "fight:" .. floor(g.a), { x = x0, y = g.y - H / 2, w = max(H, ln.X(g.b) - ln.X(g.a) + 6), h = H },
            function(self) FightTip(self, story, g) end)
    end

    -- The crosses.
    for _, d in ipairs(SP.Crosses(story, ln, branches, by)) do
        local C = LOOK.cross
        if d.who then
            local colour = d.you and STRONG or (d.side == "us" and INK or FADED)
            Cross(bg, d.x, d.y, d.you and C.you or 0.9, colour, d.you)
        else
            Dot(bg, d.x, d.y, 4.6, FADED, 1)
            Dot(bg, d.x, d.y, 2.8, Style.PAPER, 1)
        end
        Mark(bg, line, "death:" .. floor(d.t) .. ":" .. tostring(d.who), { x = d.x - 5, y = d.y - 6, w = 10, h = 12 },
            function(self) CrossTip(self, story, d) end)
    end

    -- The names over the line, in graphite.
    local function Name(key) return key == "zerg" and Text.StoryZerg() or Text.StoryPhase(key) or "" end
    line.names = SP.Names(story, ln, function(key)
        return K.Measure(bg, Name(key), Style.NEUTON_ITALIC, LOOK.name.size)
    end)
    for _, n in ipairs(line.names) do
        n.fs = Words(bg, "storyName", Style.NEUTON_ITALIC, LOOK.name.size, GRAPHITE, Name(n.key), n.x, n.y)
    end

    -- The band of strips, each led to its moment.
    line.strips = {}
    if ln.band then
        local row = SP.Row(ln.strips, function(s) return (SP.Where(ln, by, s.t or 0, s.carry)) end)
        for k, r in ipairs(row) do
            local s = r.s
            local plan = StripPlan(bg, s, story, r.w, match)
            local turns = STORY.band.turns
            local b = { x = r.x, y = ln.band, w = r.w, h = plan.h, turn = turns[(ln.i - 1) * 3 + k] or 0 }
            local tx, ty = SP.Where(ln, by, s.t or 0, s.carry)
            local hit, strip = BandStrip(bg, ln.i .. ":" .. k, b, s, plan, story, match, tx, ty)
            line.strips[#line.strips + 1] = { box = b, hit = hit, strip = strip, s = s, to = { tx, ty } }
        end
    end
    line.branches, line.stains = branches, stains
    return line
end

--------------------------------------------------------------------------
-- The page
--------------------------------------------------------------------------

-- Draws Warsong `match` of piece `e` as its story across the right page.
-- `back`: the session's key where it has an overview (its way back).
-- Returns how many plates it shows (none), or nil where the match tells no
-- story (the board is drawn then).
function YourDiary.DrawStory(e, match, back)
    local _, session = YourDiary.MatchOf(e, match.id)
    local own = ns.JoinName(ns.Characters.Name(match.me or ns.ownGUID))
    local story = ns.MatchStory.Build(match, { own = own, session = session })
    if not story then return nil end
    local bg = K.Board()
    bg.board:Show()
    K.Begin(bg)
    bg.match, bg.session, bg.story = match, nil, story
    bg.storyLines = {}
    bg.trace = YourDiary.storyTrace and {} or nil
    bg.stainRoom = LOOK.stain.cap

    -- The title first (the pad lands on it as the page opens).
    local sub = Text.StorySub(story)
    local titleBox, titleFs = K.Title(bg, Text.MatchMap(match), { name = Text.MatchMap(match), instanceID = match.map },
        sub)
    if bg.trace then
        local T = ns.RunPage.RUN
        Trace(bg, { k = "t", x = T.title.x, y = T.title.base - 14, w = 0, size = 38, text = Text.MatchMap(match),
            c = STRONG, justify = "CENTER", title = true })
        Trace(bg, { k = "t", x = T.sub.x, y = T.sub.y, w = 0, size = 15, text = sub, c = INK, justify = "CENTER", hand = true })
    end
    K.Hit(bg, titleBox, function(self) K.Tip(self, Text.MatchMap(match), { Text.MatchSubtitle(match) }) end).pad =
        { kind = "title", key = "title", words = titleFs }

    -- The way back to the evening, only where the session has one (v1's).
    if back then
        local B = STORY.back
        local link = K.LinkWord(bg, Text.MATCH.back, B.x, B.y, false, nil, function()
            Style.PlaySound("pageTurn")
            YourDiary.OpenMatches(back)
        end)
        link.pad.kind, link.pad.key = "back", "back"
        Trace(bg, { k = "t", x = B.x, y = B.y, w = 0, size = 11, text = Text.MATCH.back, c = GRAPHITE })
    end

    -- The corner stub: the board's clipping, its way in.
    Stub(bg, story, match)

    -- The two lines and their bands.
    local seed = Surface.Seed("story:" .. tostring(match.id))
    for _, ln in ipairs(SP.Lines(story)) do DrawLine(bg, story, ln, match, seed + ln.i) end

    -- Your line at the foot.
    local F = STORY.foot
    local noteBox, noteHead = K.FootNote(bg, F.x, F.y, F.turn, #(story.mine or {}), nil, Text.StoryFoot(story))
    K.Hit(bg, noteBox, function(self) K.DeathsTip(self, match) end).pad = { kind = "note", key = "note", words = noteHead }
    bg.storyFoot = noteBox
    Trace(bg, { k = "t", x = F.x + 18, y = F.y + 8, w = noteBox.w, size = 15, text = Text.StoryFoot(story), c = GRAPHITE,
        hand = true })

    K.Finish(bg)
    return 0
end

-- The board view of the match open (`on`), or back to its story.
function YourDiary.OpenMatchBoard(on)
    local page = YourDiary.page
    if not (page and page.mode == "match" and page.matchId) then return end
    GameTooltip:Hide()
    page.matchBoard = on and page.matchId or nil
    ns.UI.RedrawJourneyPage()
end

-- The story's lines as drawn now, for the pad (UI/Journey/Pad.lua): each {
-- i, key, box, marks (hits, `pad.kind` "mark"), strips, branches, stains,
-- names }. Empty with no story on the page.
function YourDiary.StoryLines()
    local page = YourDiary.page
    local bg = page and page.mode == "match" and page.bg
    if not (bg and bg.story and bg.board:IsShown()) then return {} end
    return bg.storyLines or {}
end
