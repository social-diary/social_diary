-- The person's page's paper (the person-page proposal, variant A,
-- "Clippings"): every slip taped onto their page, each a paper strip
-- (ns.UI.PaperStrip, UI/Paper/Strip.lua) laid its own way through the
-- strip's card hooks, so it turns, casts its shadow and lies flat as every
-- strip does:
--   Fact      a fact beside the plate: a heading in the hand, a subtitle
--             in Friz under it, and where asked a tally beside the heading
--             ("First met 11 October / at level 17", "Met 5 times / 4 h
--             45 min together"); the long heading or, where it will not
--             fit, its short form
--   Level     the level tag: their level then printed and struck through
--             in the hand, their level now written beside it
--   Written   a slip with lines of writing on it: your note pasted over
--             the plate's corner, a note on the timeline
--   Day       a day's label on the timeline, in Goodmountain, rubric
-- The words are UI/Words/Person.lua's and the timeline's; the page lays
-- them (UI/Journal/Clippings.lua, UI/Journal/Timeline.lua).
--
-- Slips turn at most about 1.3 degrees (the proposal's rule for a long
-- list), every one of them seeded, so a page lies the same way each time.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local Surface = ns.UI.Surface
local Width, Seed = Surface.Width, Surface.Seed

local Strips = {}
ns.UI.PersonStrips = Strips

-- The look:
--   turn     how far a slip turns at most (degrees, either way)
--   tag      tag paper: a fresher, lighter stock than a strip's (the
--            mockup's), for the level tag and the written slips
--   gates    px from a heading's end to its tally
--   tape     where a slip's tape goes other than across its top: at its
--            top left corner (`corner`, slanted about 45 degrees) or down
--            its left end (`left`, nearly upright, `y` of its height from
--            the top, at most `most` px), `w` by `h`, give or take
--            `jitter` degrees (seeded)
--   written  a written slip's margins (left, top, right, bottom), a line
--            of the hand `line` px, at most `most` lines unless told
--   level    the level tag: `pad` px either end, `gap` between the
--            printed level and the hand's, `h` tall, the hand at `hand` px
--   overhang px more room past the measured end of writing in the hand or
--            in Goodmountain: their last strokes lean or swash past the
--            advance the client measures (20 Oct, in the client: "First
--            met 11 October" touched its strip's right edge, a note its
--            slip's, the mockup's metrics being narrower than the client's)
-- Every slip is as wide as its writing measures (Surface.Width) plus these
-- margins, up to the width it is given; only past that does its writing
-- wrap, and the slip grows taller, never narrower than its words.
local LOOK = {
    turn = 1.2,
    tag = { 0.98, 0.95, 0.87 },
    gates = 9,
    tape = { corner = { w = 22, h = 10, slant = 45, jitter = 6 },
        left = { w = 22, h = 10, slant = 82, jitter = 4, y = 0.36, most = 12 } },
    written = { pad = { 9, 4, 9, 4 }, line = 19, most = 2 },
    level = { pad = 9, gap = 7, h = 28, hand = 18 },
    overhang = 3,
}
-- The tally's strokes, as the hunt card draws them (Features/Hunts/
-- HuntCard.lua's TALLY): uprights `gap` apart, `h` tall, leaning `lean`,
-- `jitter` each; the fifth across from the lower left, `over` past the
-- outer two, rising `rise`; `width` px; gates `apart` px apart; in ink at
-- `alpha`.
local TALLY = { gap = 2.5, h = 10, lean = 0.5, jitter = { 0, 0.6, -0.4, 0.3 }, over = 1.6, rise = 7.2, width = 1.3,
    apart = 3.5, alpha = 0.92 }
-- The hand striking the old level out: one pen line zigzagging over the
-- figures, `lead` px before them to `tail` past, its turns `cap` of the
-- type's size above and below the middle and `over` px more, `width` px
-- in ink at `alpha`. Thin and open, so the struck figures still read (the
-- lucky card's lesson: a denser scribble blacked the words out).
local STRIKE = { lead = 2, tail = 3, cap = 0.35, over = 1.2, width = 1.0, alpha = 0.92 }
Strips.LOOK, Strips.TALLY, Strips.STRIKE = LOOK, TALLY, STRIKE

local function Noise(n) return Style.Noise(n) end

-- A tape at a slip's top left corner or down its left end, for a strip's
-- `tapeAt` ({ x, y, slant, w, h }, from the slip's top left); nil for the
-- strip's own, across its top.
function Strips.Tape(kind, h, seed)
    local T = LOOK.tape[kind]
    if not T then return nil end
    local slant = T.slant + (Noise(Seed(seed) + 7) - 0.5) * 2 * T.jitter
    if kind == "corner" then return { x = 1, y = 1, w = T.w, h = T.h, slant = slant } end
    return { x = 0, y = math.min(h * T.y, T.most), w = T.w, h = T.h, slant = slant }
end

-- A gate of `k` strokes (1 to 5) is this wide; `n` strokes in gates of
-- five are this long.
local function GateW(k)
    if k >= 5 then return 2 * TALLY.over + 3 * TALLY.gap end
    return TALLY.over + (k - 1) * TALLY.gap + TALLY.width
end
local function RowW(n)
    local w, first = 0, true
    while n > 0 do
        local k = math.min(5, n)
        w = w + (first and 0 or TALLY.apart) + GateW(k)
        first, n = false, n - k
    end
    return w
end
Strips.TallyWidth = RowW

-- Straight strokes of ink on a strip, from a pool of its own: Begin, then
-- Stroke(x1, y1, x2, y2, width) on the strip (from its middle, y down),
-- then Finish hides the rest.
local function Strokes(strip)
    local pool = { used = 0 }
    function pool:Begin() self.used = 0 end
    function pool:Stroke(x1, y1, x2, y2, width, alpha)
        self.used = self.used + 1
        local t = self[self.used]
        if not t then
            t = strip:CreateTexture(nil, "ARTWORK", nil, 2)
            self[self.used] = t
        end
        local I = Style.INK_STRONG
        t:SetColorTexture(I[1], I[2], I[3], alpha or TALLY.alpha)
        local dx, dy = x2 - x1, y2 - y1
        strip:Lay(t, (x1 + x2) / 2, (y1 + y2) / 2, math.sqrt(dx * dx + dy * dy) + 0.3, width,
            math.atan2(-dy, dx))
        t:Show()
    end
    function pool:Finish()
        for i = self.used + 1, #self do self[i]:Hide() end
    end
    return pool
end

-- `n` strokes in gates of five, from x (their left) about the middle y.
local function Tally(pool, x, y, n)
    local T = TALLY
    while n > 0 do
        local k = math.min(5, n)
        for i = 1, math.min(k, 4) do
            local u, h = x + T.over + (i - 1) * T.gap, T.h + (T.jitter[i] or 0)
            pool:Stroke(u - T.lean / 2, y + h / 2, u + T.lean / 2, y - h / 2, T.width)
        end
        if k >= 5 then pool:Stroke(x, y + T.rise / 2, x + GateW(5), y - T.rise / 2, T.width) end
        x, n = x + GateW(k) + T.apart, n - k
    end
end
Strips.Tally = Tally

--------------------------------------------------------------------------
-- A fact
--------------------------------------------------------------------------

-- strip:SetNote({ name (the heading), short (its short form, or nil), what
-- (the subtitle, or nil), gates (strokes to draw beside the heading, or
-- nil), seed, tip (its tooltip, or nil) }), then Layout(x, y, width) as
-- any strip's: as wide as its heading and tally measure, with the hand's
-- overhang (LOOK.overhang), up to `width`. The short form is taken where
-- the long one will not fit `width` (person-page-copy.md: the long form
-- first, the column widened for it where it can be); where even that will
-- not, the heading wraps at words, its rest a line at a time in the hand
-- under it (the strip's room under the name), and the strip grows taller.
-- strip.headingLines says how many lines it took (for the tests).
function Strips.Fact(parent)
    local strokes
    -- The heading's lines after the first: font strings in the hand, and
    -- what they say as laid.
    local rests, tails, tailH = {}, {}, 0
    local hooks = {}
    function hooks.plan(strip, note, width)
        local l, _, r = strip:Pad()
        local tally = note.gates and (LOOK.gates + RowW(note.gates)) or 0
        local function Need(text, more)
            strip.name:SetText(text)
            return Width(strip.name) + 2 + LOOK.overhang + (more or 0) + l + r
        end
        local heading = note.name or ""
        if note.short and Need(heading, tally) > width then heading = note.short end
        -- Past `width` still: as many words as fit on the first line (the
        -- tally beside it), the rest in lines as wide as the strip.
        tails = {}
        if Need(heading, tally) > width and heading:find(" ") then
            local words = {}
            for word in heading:gmatch("%S+") do words[#words + 1] = word end
            local n = #words - 1
            while n > 1 and Need(table.concat(words, " ", 1, n), tally) > width do n = n - 1 end
            heading = table.concat(words, " ", 1, n)
            local line
            for i = n + 1, #words do
                local try = line and (line .. " " .. words[i]) or words[i]
                if line and Need(try) > width then
                    tails[#tails + 1] = line
                    line = words[i]
                else
                    line = try
                end
            end
            if line then tails[#tails + 1] = line end
        end
        local least = Need(heading, tally)
        local rw = 0
        tailH = 0
        for i, tail in ipairs(tails) do
            local text = rests[i] or Style.Text(strip, FONT.noteWritten)
            rests[i] = text
            text:SetText(tail)
            rw = math.max(rw, Width(text) + 2)
            tailH = math.max(tailH, math.ceil(text:GetStringHeight() or 0), 14)
        end
        note.under = #tails > 0 and { w = rw, h = tailH * #tails, gap = 0, after = 1 } or nil
        if #tails > 0 then least = math.max(least, rw + LOOK.overhang + l + r) end
        strip.name:SetText(heading)
        strip.headingLines = 1 + #tails
        note.least = math.ceil(least)
        note.turn = LOOK.turn
    end
    function hooks.draw(strip, _, w, h)
        strokes = strokes or Strokes(strip)
        strokes:Begin()
        local note = strip.note or {}
        local box = strip.nameBox
        if note.gates and note.gates > 0 and box then
            Tally(strokes, box[3] + LOOK.gates, (box[2] + box[4]) / 2 + 1, note.gates)
        end
        strokes:Finish()
        -- The heading's rest, where it wrapped: in the room under the name,
        -- a line at a time (turned text is laid so).
        local under = note.under and strip.under
        local lift = math.abs(math.sin(strip.turn or 0))
        for i, text in ipairs(rests) do
            local shown = under ~= nil and i <= #tails
            text:SetShown(shown)
            if shown then
                local lw = Width(text) + 2
                strip:Lay(text, under.lx - under.w / 2 + lw / 2, under.ly - under.h / 2 + (i - 0.5) * tailH, lw,
                    tailH + lw * lift + 4)
            end
        end
    end
    local strip = ns.UI.PaperStrip(parent, hooks)
    -- Its heading as written, every line (for the tests).
    function strip:Heading()
        local parts = { self.name:GetText() or "" }
        for i = 1, (self.headingLines or 1) - 1 do parts[#parts + 1] = rests[i]:GetText() or "" end
        return table.concat(parts, " ")
    end
    return strip
end

--------------------------------------------------------------------------
-- The level tag
--------------------------------------------------------------------------

-- The hand's line through printed figures from x0, `w` wide, about the
-- middle y of type `size` px, seeded: points along it, its turns above and
-- below the figures.
local function Strike(seed, x0, w, mid, size)
    local S = STRIKE
    local half = S.cap * size + S.over
    local xs, xe = x0 - S.lead, x0 + w + S.tail
    local n = 3
    local pts, up = { { xs, mid + half * 0.4 } }, true
    for k = 1, n do
        local x = xs + (xe - xs) * k / n + (k < n and (Noise(seed + k) - 0.5) * 2 or 0)
        local y = mid + (up and -1 or 1) * (half + (Noise(seed + 10 + k) - 0.5))
        pts[#pts + 1] = { x, y }
        up = not up
    end
    return pts
end
Strips.Strike = Strike

-- strip:SetNote({ level = { then, now }, seed, tip }), then Layout: a tag
-- the size of what is written on it, "Level 17" printed with "17" struck
-- out, "22" in the hand beside it.
function Strips.Level(parent)
    local printed, hand, strokes
    local hooks = {}
    function hooks.plan(strip, note)
        local L = LOOK.level
        if not printed then
            printed = Style.Text(strip, FONT.small)
            hand = Style.Text(strip, FONT.noteWritten)
            hand:SetFont(Style.NEUTON_ITALIC, L.hand, "")
        end
        local lv = note.level or {}
        printed:SetText("Level " .. tostring(lv[1] or ""))
        hand:SetText(tostring(lv[2] or ""))
        local w = math.ceil(L.pad + Width(printed) + 2 + L.gap + Width(hand) + 2 + LOOK.overhang + L.pad)
        note.size = { w, L.h }
        note.paper = LOOK.tag
        note.tapeAt = Strips.Tape("left", L.h, (note.seed or "") .. ":tape")
        note.turn = LOOK.turn
        note.name = ""
        strip.name:SetText("")
    end
    function hooks.draw(strip, _, w, h)
        local L = LOOK.level
        strokes = strokes or Strokes(strip)
        strokes:Begin()
        local left = -w / 2 + L.pad
        local pw, ph = Width(printed) + 2, math.max(math.ceil(printed:GetStringHeight() or 0), 11)
        local hw, hh = Width(hand) + 2, math.max(math.ceil(hand:GetStringHeight() or 0), 14)
        strip:Lay(printed, left + pw / 2, 1, pw, ph + 4)
        printed:Show()
        strip:Lay(hand, left + pw + L.gap + hw / 2, -1, hw, hh + 4)
        hand:Show()
        -- Through the old figures, not the word.
        local note = strip.note or {}
        local figures = tostring((note.level or {})[1] or "")
        printed:SetText("Level ")
        local lead = Width(printed)
        printed:SetText("Level " .. figures)
        local fw = math.max(1, Width(printed) - lead)
        local pts = Strike(Seed(note.seed or "level"), left + lead, fw, 1, 11)
        for k = 1, #pts - 1 do
            strokes:Stroke(pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2], STRIKE.width, STRIKE.alpha)
        end
        strokes:Finish()
        -- For the tests: what it says, and where the strike is.
        strip.struck, strip.written = figures, hand:GetText()
    end
    return ns.UI.PaperStrip(parent, hooks)
end

--------------------------------------------------------------------------
-- A written slip
--------------------------------------------------------------------------

local ELLIPSIS = "\226\128\166"

-- A word wider than a line, broken at characters into pieces that fit
-- (a whole UTF-8 character at a time); a word that fits, as it is.
local function Pieces(measure, word, width)
    measure:SetText(word)
    if Width(measure) <= width then return { word } end
    local pieces, piece = {}, ""
    for char in word:gmatch("[\1-\127\192-\255][\128-\191]*") do
        measure:SetText(piece .. char)
        if piece ~= "" and Width(measure) > width then
            pieces[#pieces + 1] = piece
            piece = char
        else
            piece = piece .. char
        end
    end
    if piece ~= "" then pieces[#pieces + 1] = piece end
    return pieces
end

-- `text` in lines no wider than `width` on `measure` (in the slip's font),
-- word by word (a word wider than a line broken at characters), at most
-- `most`: the last line kept ends in an ellipsis where there was more. The
-- lines, and whether it was cut.
local function Wrap(measure, text, width, most)
    local lines, line = {}, nil
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do
        for _, piece in ipairs(Pieces(measure, word, width)) do words[#words + 1] = piece end
    end
    for _, word in ipairs(words) do
        local try = line and (line .. " " .. word) or word
        measure:SetText(try)
        if line and Width(measure) > width then
            lines[#lines + 1] = line
            line = word
        else
            line = try
        end
    end
    if line then lines[#lines + 1] = line end
    local cut = #lines > most
    if cut then
        for i = #lines, most + 1, -1 do lines[i] = nil end
        local last = lines[most] .. ELLIPSIS
        measure:SetText(last)
        -- Shortened a word at a time to fit with it, or a character at a
        -- time where it is one word (a long one, broken).
        while Width(measure) > width and #lines[most] > 1 do
            if lines[most]:find(" ") then
                lines[most] = lines[most]:gsub("%s+%S+$", "")
            else
                lines[most] = lines[most]:gsub("[\1-\127\192-\255][\128-\191]*$", "")
            end
            last = lines[most] .. ELLIPSIS
            measure:SetText(last)
        end
        lines[most] = last
    end
    return lines, cut
end
Strips.Wrap = Wrap

-- How wide a written slip's lines may measure on a slip at most `width`
-- wide: its margins, the hand's overhang and the font string's 2 px off.
function Strips.WrittenRoom(width)
    local W = LOOK.written
    return width - W.pad[1] - W.pad[3] - LOOK.overhang - 2
end

-- strip:SetNote({ text, font (FONT.noteWritten unless given), most (lines),
-- tape ("corner", "left", or nil for across its top), tilt (an exact turn,
-- degrees, or nil for a seeded one), seed, paper (tag paper unless
-- given), tip }), then Layout(x, y, width): the slip as wide as its
-- longest line. strip.cut says whether the writing was cut short (its
-- tooltip has the rest).
function Strips.Written(parent)
    local measure, lines = nil, {}
    local wrapped = {}
    local hooks = {}
    function hooks.plan(strip, note, width)
        local W = LOOK.written
        local font = note.font or FONT.noteWritten
        if not measure then
            measure = Style.Text(strip, font)
            measure:Hide()
        end
        measure:SetFontObject(font)
        local inner = Strips.WrittenRoom(width)
        local cut
        wrapped, cut = Wrap(measure, note.text, inner, note.most or W.most)
        local widest = 0
        for _, words in ipairs(wrapped) do
            measure:SetText(words)
            widest = math.max(widest, Width(measure) + 2)
        end
        local w = math.min(width, math.ceil(widest + W.pad[1] + W.pad[3] + LOOK.overhang))
        local h = W.pad[2] + math.max(1, #wrapped) * W.line + W.pad[4]
        note.size = { w, h }
        note.paper = note.paper or LOOK.tag
        note.tapeAt = Strips.Tape(note.tape, h, (note.seed or "") .. ":tape")
        if note.tilt == nil then note.turn = LOOK.turn end
        note.name = ""
        strip.name:SetText("")
        strip.cut, strip.font = cut, font
    end
    function hooks.draw(strip, _, w, h)
        local W = LOOK.written
        -- (The widest line as written, for the tests.)
        strip.widest = 0
        for i, words in ipairs(wrapped) do
            local line = lines[i]
            if not line then
                line = Style.Text(strip, strip.font)
                lines[i] = line
            end
            line:SetFontObject(strip.font)
            line:SetText(words)
            local lw = Width(line) + 2
            strip.widest = math.max(strip.widest, lw)
            strip:Lay(line, -w / 2 + W.pad[1] + lw / 2, -h / 2 + W.pad[2] + (i - 0.5) * W.line, lw, W.line + 4)
            line:Show()
        end
        for i = #wrapped + 1, #lines do lines[i]:Hide() end
        strip.writtenLines = #wrapped
    end
    local strip = ns.UI.PaperStrip(parent, hooks)
    -- What it says, its lines joined (for the tests).
    function strip:Written()
        local parts = {}
        for i = 1, self.writtenLines or 0 do parts[#parts + 1] = lines[i]:GetText() end
        return table.concat(parts, " ")
    end
    return strip
end

--------------------------------------------------------------------------
-- A day's label
--------------------------------------------------------------------------

-- strip:SetNote({ name (the day, as Format.DayLabel writes it: mixed case,
-- never capitals), seed, tilt }), then Layout: the label in Goodmountain,
-- rubric, taped down its left end, the strip as wide as the label
-- measures with Goodmountain's overhang (LOOK.overhang).
function Strips.Day(parent)
    local hooks = {}
    function hooks.plan(strip, note)
        strip.name:SetFontObject(FONT.dayLabel)
        local R = Style.RUBRIC
        strip.name:SetTextColor(R[1], R[2], R[3])
        local l, t, r, b = strip:Pad()
        local h = t + math.max(math.ceil(strip.name:GetStringHeight() or 0), 14) + b
        note.tapeAt = Strips.Tape("left", h, (note.seed or "") .. ":tape")
        note.least = math.ceil(Width(strip.name) + 2 + LOOK.overhang + l + r)
    end
    return ns.UI.PaperStrip(parent, hooks)
end
