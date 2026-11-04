-- The slip a hint is written on (UI/Journal/Hints.lua lays it; Core/Hints.lua
-- says when): a small piece of paper laid against the book's fore-edge,
-- below the index tabs, tucked over the right page's empty margin and
-- standing out past the cover, as a note slipped into a book stands out of
-- it. So it lies over nothing the page works with: not Your Diary's map
-- (which the custom-events hint asks the player to right-click), not the
-- People page's profile or its tabs.
--
-- It does not block. Its frame is the slip's size and no larger: clicks
-- and the wheel beside it reach the page as before, and the wheel over it
-- too (it takes clicks only). One click on it puts it away; its link, where
-- it has one, does what it says and puts it away. Escape stays the book's.
--
-- It does not pop in place: it is set down from the right, a few px out
-- and up, and comes up from nothing as it settles (ARRIVE), with its own
-- sound (Style.SOUNDS.hint), a soft paper sound that is not the page turning
-- nor a sheet laid across the book. Laid flat (the flatSheets setting) it
-- lies straight and only fades in, as a loose sheet laid flat does not
-- move as it comes.
--
--   HintSlip.Show(container, page, words, onGone)
--       container  the page's container (J.journal.views[page]), the book's size
--       page       "journey", "people", ...: where on the edge it lies (PLACE)
--       words      { title, body, link?, onLink? }
--       onGone     called once when the player puts it away (a click on it,
--                  or its link); it may call Hide itself
--   HintSlip.Hide()   takes it away, at once and quietly; safe to call again
--   HintSlip.Shown()  whether it is out

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local HintSlip = {}
ns.UI.HintSlip = HintSlip

-- The slip in its own coordinates (x right, y down): `w` wide, as tall as
-- its words wrap to. `margin` each side; the title's middle `title` down,
-- after a lozenge `lozenge` across; the first line's middle `body` down,
-- a line every `line`; the link's middle `link` under the last line; `foot`
-- of paper under that (under the last line where it has no link). The close
-- mark's middle `close` in from the top right. Turned `turn` degrees
-- (clockwise is negative, as SetRotation).
local SLIP = { w = 200, margin = 14, title = 19, lozenge = 5, body = 42, line = 16, link = 22, foot = 15,
    close = 11, turn = -1.4, level = 60 }
-- Where it lies: its left edge `tuck` px inside the book's right edge, over
-- the right page's empty margin (26 px wide, UI/Journal/Book.lua), and its
-- top `y` px down the book, below the profile's index tabs (they end about
-- 180 px down). The same on both pages for now, each its own to tune.
local PLACE = {
    journey = { tuck = 18, y = 318 },
    people = { tuck = 18, y = 318 },
    default = { tuck = 18, y = 318 },
}
-- Never off the screen: where the book lies so far right that it would be,
-- it comes in over the page by as much, `pad` px clear of the screen's edge.
local SCREEN = { pad = 8 }
-- Its arrival: over `time` seconds, from `dx` px right and `dy` px up to
-- where it lies, eased out (quartic); its alpha reaches 1 by `fade` of the
-- way. Laid flat, `flatTime` of fading only.
local ARRIVE = { time = 0.38, dx = 26, dy = 6, fade = 0.6, flatTime = 0.2 }
-- A slip off a pad: no folds, hardly crumpled, its corners curling a little.
local CREASE = {
    columns = { 0, 0.1, 0.9, 1 },
    rows = { 0, 0.16, 0.84, 1 },
    folds = { columns = {}, rows = {} },
    crumple = 0.35, drift = 0.3, edge = 0.5, nick = 0, wander = 0, shift = 0, lean = 0,
    curl = { lift = 3, pull = 2 },
}
-- Its stock: a touch lighter than the page, so it reads as its own piece
-- where it lies over the page's margin.
local STOCK = { 0.91, 0.84, 0.66 }
local CLOSE = "\195\151"   -- ×

HintSlip.SLIP, HintSlip.PLACE, HintSlip.ARRIVE = SLIP, PLACE, ARRIVE

-- The slip, built the first time a hint comes.
local host, onGone

local function Gone()
    local fn = onGone
    onGone = nil
    if fn then fn() end
    HintSlip.Hide()
end

local function Build(container)
    local frame = CreateFrame("Frame", nil, container)
    frame:Hide()

    local Lamp = ns.UI.Light
    local view, K = ns.UI.LooseSheet(frame, SLIP.w, 100, { crease = CREASE, quiet = true, paper = STOCK,
        ground = Lamp and Lamp.GROUND.world })
    local S = view.sheet
    frame.view, frame.K = view, K
    -- A click on its curled corners, just off the paper, is a click on it.
    view.onPutAway = function() Gone() end
    S:SetScript("OnMouseUp", function() Gone() end)

    frame.lozenge = Style.Lozenge(S, "ARTWORK", SLIP.lozenge, Style.RUBRIC)
    frame.title = Style.Text(S, FONT.headingRubric)
    frame.close = Style.Text(S, FONT.small)
    frame.close:SetText(CLOSE)
    frame.lines = {}
    frame.link = K.Link(FONT.strong, function()
        local run = frame.onLink
        Gone()
        if run then run() end
    end)

    -- The close mark darkens while the mouse is on the slip: it can go.
    local FADED, STRONG = Style.INK_FADED, Style.INK_STRONG
    S:SetScript("OnEnter", function() frame.close:SetTextColor(STRONG[1], STRONG[2], STRONG[3]) end)
    S:SetScript("OnLeave", function() frame.close:SetTextColor(FADED[1], FADED[2], FADED[3]) end)

    function frame:Write(words)
        local M, width = SLIP.margin, SLIP.w - 2 * SLIP.margin
        local flat = ns.Setting("flatSheets") == true
        local lines = K.Wrap(words.body or "", width, FONT.body)
        local y = SLIP.body + (#lines - 1) * SLIP.line
        local H = y + (words.link and SLIP.link or 0) + SLIP.foot
        self.h = H
        self:SetSize(SLIP.w, H)
        K.Reshape(SLIP.w, H)
        K.Fall("hint", flat and 0 or math.rad(SLIP.turn))
        K.Lay()

        K.Place(self.lozenge, M, SLIP.title - SLIP.lozenge / 2, SLIP.lozenge, SLIP.lozenge, math.pi / 4)
        self.title:SetText((words.title or ""):upper())
        K.PlaceText(self.title, M + SLIP.lozenge + 6, SLIP.title)
        K.PlaceText(self.close, SLIP.w - SLIP.close + 4, SLIP.close, "RIGHT")
        for i, line in ipairs(lines) do
            local text = self.lines[i] or Style.Text(S, FONT.body)
            self.lines[i] = text
            text:SetText(line)
            K.PlaceText(text, M, SLIP.body + (i - 1) * SLIP.line)
            text:Show()
        end
        for i = #lines + 1, #self.lines do self.lines[i]:Hide() end

        self.onLink = words.onLink
        if words.link then
            self.link:SetText(words.link)
            self.link:PlaceAt(SLIP.w - M, y + SLIP.link, "RIGHT")
            self.link:Show()
        else
            self.link:Hide()
        end
    end

    return frame
end

-- Where it lies on `container`, for `page`: x right and y down from the
-- container's top left.
local function Rest(container, page)
    local place = PLACE[page] or PLACE.default
    local BOOK = ns.UI.Journal and ns.UI.Journal.BOOK
    local x = (BOOK and BOOK.BOOK_W or container:GetWidth() or 0) - place.tuck
    -- Off the right of the screen, it comes in by as much.
    local right = container:GetRight()
    local edge = UIParent:GetRight()
    if right and edge then
        local scale = (container:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        local over = (right - place.tuck + SLIP.w + SCREEN.pad) * scale - edge
        if over > 0 then x = x - over / scale end
    end
    return x, place.y
end

local function Arriving(self, elapsed)
    local A = ARRIVE
    self.t = math.min(1, self.t + (elapsed or 0) / self.time)
    local t = self.t
    local ease = 1 - (1 - t) ^ 4
    local x, y = self.rest[1], self.rest[2]
    if not self.flat then
        x, y = x + A.dx * (1 - ease), y - A.dy * (1 - ease)
    end
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", self.container, "TOPLEFT", x, -y)
    self:SetAlpha(self.flat and ease or math.min(1, ease / A.fade))
    if t >= 1 then self:SetScript("OnUpdate", nil) end
end
HintSlip.Arriving = Arriving

function HintSlip.Show(container, page, words, gone)
    HintSlip.Hide()
    host = host or Build(container)
    if host.container ~= container then host:SetParent(container) end
    host.container = container
    host:SetFrameLevel(container:GetFrameLevel() + SLIP.level)
    onGone = gone
    host.page = page
    host:Write(words or {})
    local x, y = Rest(container, page)
    host.rest = { x, y }
    host.flat = ns.Setting("flatSheets") == true
    host.time = host.flat and ARRIVE.flatTime or ARRIVE.time
    host.t = 0
    Arriving(host, 0)
    host:SetScript("OnUpdate", Arriving)
    host:Show()
    Style.PlaySound("hint")
end

function HintSlip.Hide()
    onGone = nil
    if not host then return end
    host:SetScript("OnUpdate", nil)
    if host:IsShown() then host:Hide() end
end

function HintSlip.Shown()
    return host ~= nil and host:IsShown()
end

-- The slip's frame, for the tests: nil until a hint has come.
function HintSlip.Frame() return host end
