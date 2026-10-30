-- The table spread (.claude/dungeon-visits-prd.md §8, DGN-1 to DGN-3,
-- TLN-12): a dungeon run laid out on a table, not a page in the book: the
-- run's map, a big folded sheet (UI/Dungeon/Sheet.lua), with its strips
-- near what they are about (UI/Dungeon/Notes.lua), lying over the game
-- world under the one lamp the map obeys (UI/Paper/Light.lua; each thing's height in
-- UI/Dungeon/Heights.lua). Nothing is laid under them: the world shows
-- round the sheet, and what lies past its edge casts its shadow on it.
--
-- The book is put aside while the run is out (the user, 17 Oct: the book
-- showing round the map was irritating): nothing of it shows, its cover,
-- pages, ribbons, tabs and close button, as it is made see-through (Away)
-- and nothing else about it changes, so it comes back exactly as it was:
-- the same person, tab and timeline scroll, where it lay and at its size.
-- It stays open while it is away (so its own "shut" still closes the run,
-- and nothing it shows is torn down), and it takes no click, as the spread
-- covers the screen over it. The spread is the screen's, not the book's
-- (a child of the book would vanish with it), at the book's scale, so the
-- scene lies where the book lay: the sheet comes down on the book's
-- middle. Where that would take it off the screen (the book dragged to an
-- edge, a small screen), the sheet slides just as far as it must; only a
-- screen too small for the sheet at all shrinks the spread
-- (DungeonPage.Lie).
--
-- Opened by a click on the run's card on the timeline (UI/Journal/
-- Timeline.lua) through ns.UI.OpenVisit, the one way in (DGN-1; Your
-- Diary's super plate will take it too). Put away (DGN-2) by a click
-- beside the sheet, the bookmark lying by the map's top-left corner with "<their name>'s story" pencilled on
-- it (BOOKMARK: the dog-eared corner went with the book), Escape, the card
-- again, choosing someone else, turning the book to another page, or
-- shutting the book. Escape takes the spread away, and the book only with
-- the next press: while the spread is out it stands in the book's place in
-- UISpecialFrames (one place, swapped: StandIn). The first run ever laid
-- out brings a note about the map (UI/Dungeon/Tutorial.lua), which holds
-- that place while it is up.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local J = ns.UI.Journal
local DungeonPage = ns.UI.DungeonPage
local Surface = ns.UI.Surface

-- The spread on the screen: the sheet kept `edge` px inside it, its
-- shadow reaching `shadow` px past it.
local SPREAD = { name = "SocialDiaryTableSpread", book = "SocialDiaryJournalFrame", edge = 12, shadow = 8 }
-- The way back: a bookmark lying by the map's top-left corner,
-- its right end `tuck` px under the sheet's left edge, `down` px down that
-- edge from the corner, turned `turn` degrees (the other way to the map).
-- A slip of the diary's own page (Style.PAPER), `h` px tall and at least
-- `least` px long: `ribbon` px at its left for the ribbon's eyelet, then
-- the words in pencil (13 pt, the frontispiece's), `pad` px of paper after them; its cut edge in ink
-- at `edge`. The diary's red ribbon (Style.RIBBONS.red) comes out from
-- under its foot `tail.at` px from its left end, `tail.w` px wide and
-- `tail.len` long, hanging `tail.hang` degrees off straight down to the
-- left, its end cut in a swallowtail `tail.notch` px deep; it is threaded
-- through a brass eyelet (`eyelet` px across). It lies HEIGHT.bookmark
-- over the world (UI/Dungeon/Heights.lua), picked up HEIGHT.lifted more
-- under the mouse, where the words darken.
local BOOKMARK = { tuck = 10, down = 30, turn = -4, h = 28, least = 104, ribbon = 20, pad = 11, edge = 0.4,
    tail = { at = 8, w = 8, len = 34, hang = 22, notch = 4.5 }, eyelet = 6.5 }
-- Opened from Your Diary's run page (UI/Journey/Run.lua), the way back is
-- to the diary, not to a person's story: its words.
BOOKMARK.journey = "Your Diary"
DungeonPage.SPREAD, DungeonPage.BOOKMARK = SPREAD, BOOKMARK

-- The spread draws over all of the book, its side tabs too (16 Oct, in the
-- client: the tabs' icons lay over a strip sticking out past the sheet).
-- The host stands in `strata`, above the book's (HIGH), set again once
-- everything on it is made and each time it comes out, so it reaches every
-- frame on it, and fixed where the client can fix it.
local LAYER = { strata = "DIALOG" }
DungeonPage.LAYER = LAYER

-- The host, built the first time a run is laid out.
local spread

local function Above(host)
    host:SetFrameStrata(LAYER.strata)
    if host.SetFixedFrameStrata then host:SetFixedFrameStrata(true) end
end

--------------------------------------------------------------------------
-- Which visit
--------------------------------------------------------------------------

-- `guid`'s visit `id`, or nil: only a visit they were in opens from their
-- page.
function DungeonPage.Visit(guid, id)
    for _, visit in ipairs(ns.Instances.For(guid)) do
        if visit.id == id then return visit end
    end
end

--------------------------------------------------------------------------
-- Fitting it to the screen
--------------------------------------------------------------------------

-- Where a sheet w by h (the bare sheet's size by default; a map's is the
-- map's shape: UI/Dungeon/Sheet.lua) lies for a book whose middle is at
-- bx, by on a screen sw by sh (all in the book's own units, x right and y
-- up from the screen's bottom left; no book given, the screen's middle),
-- with `left` and `right` px more beside it (the bookmark: its room past
-- the sheet's edge): on the book's middle, the sheet's `down` under it,
-- slid along each way as far as it must to stay `edge` px inside the
-- screen, shadow, bookmark and all. Returns its middle's
-- offset from the screen's middle in the spread's own units (as SetPoint
-- takes it), the spread's own scale (1, unless the screen is too small for
-- the sheet at all: then just small enough), and whether it slid. A screen
-- of no size (not known yet) leaves it on the book.
function DungeonPage.Lie(sw, sh, bx, by, w, h, left, right)
    local S = DungeonPage.SHEET
    w, h = w or S.w, h or S.h
    left, right = left or 0, right or 0
    local a = math.rad(S.turn)
    local hw = (w * math.cos(a) + h * math.sin(a)) / 2 + SPREAD.shadow
    local hh = (w * math.sin(a) + h * math.cos(a)) / 2 + SPREAD.shadow
    if not (sw and sh and sw > 0 and sh > 0) then return 0, -S.down, 1, false end
    bx, by = bx or sw / 2, by or sh / 2
    local k = math.min(1, (sw - 2 * SPREAD.edge) / (2 * hw + left + right), (sh - 2 * SPREAD.edge) / (2 * hh))
    local function Along(want, size, lo, hi)
        lo, hi = SPREAD.edge + lo * k, size - SPREAD.edge - hi * k
        if lo >= hi then return (lo + hi) / 2 end
        return math.max(lo, math.min(hi, want))
    end
    local wantX, wantY = bx, by - S.down * k
    local cx, cy = Along(wantX, sw, hw + left, hw + right), Along(wantY, sh, hh, hh)
    local slid = math.abs(cx - wantX) > 1e-6 or math.abs(cy - wantY) > 1e-6
    return (cx - sw / 2) / k, (cy - sh / 2) / k, k, slid
end

-- Escape: one place in UISpecialFrames, held by the book, or the spread
-- while it is out, or the note on it while that is up: `to` of those, so
-- each press takes only the top one. Swapped in place, never added or removed, as the client may be
-- going through the list as it hides one: what stands in the place next
-- is not reached by the same press.
local function StandIn(to)
    for i, name in ipairs(UISpecialFrames) do
        if name == SPREAD.book or name == SPREAD.name or name == DungeonPage.TUTORIAL.NOTE.name then
            UISpecialFrames[i] = to
            return
        end
    end
    if to ~= SPREAD.book then UISpecialFrames[#UISpecialFrames + 1] = to end
end

DungeonPage.StandIn = StandIn

-- The book put aside while the run is out (`away`), and back as it was:
-- see-through, and nothing else about it touched. Its own alpha kept, to
-- give back.
local function Away(away)
    local book = J.journal
    if away then
        if spread.bookAlpha == nil then spread.bookAlpha = book:GetAlpha() end
        book:SetAlpha(0)
    elseif spread.bookAlpha ~= nil then
        book:SetAlpha(spread.bookAlpha)
        spread.bookAlpha = nil
    end
end

--------------------------------------------------------------------------
-- The bookmark: the way back
--------------------------------------------------------------------------

-- The bookmark on the sheet's view `map` (BOOKMARK): a button the size of
-- the turned slip's box, drawn on a turned plane (UI/Paper/Surface.lua).
-- :Set(first) writes the words, :LayAt(x, y) lays it, :Draw
-- (lifted) draws it lying or picked up.
local function Bookmark(map)
    local mark = CreateFrame("Button", nil, map)
    -- Beside the sheet, over the ground's shadows and under its edge
    -- (UI/Dungeon/Sheet.lua's levels).
    mark:SetFrameLevel(map:GetFrameLevel() + 2)
    local plane = Surface.New(mark)
    local Place, Quad = plane.Place, plane.Quad
    local probe = mark:CreateTexture(nil, "BACKGROUND")
    mark.canBend = probe.SetVertexOffset ~= nil
    probe:Hide()

    mark.textures = ns.UI.Pool.New(function()
        local t = mark:CreateTexture(nil, "ARTWORK")
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
        return t
    end)
    local function Tex(layer, sublevel)
        local t = mark.textures:Next()
        Surface.Unbend(t)
        t:SetTexture(nil)
        t:SetTexCoord(0, 1, 0, 1)
        t:SetVertexColor(1, 1, 1, 1)
        t:SetDrawLayer(layer, sublevel)
        return t
    end
    mark.words = Style.Text(mark, FONT.pencil)
    mark.turnsText = mark.words.SetRotation ~= nil

    -- A rectangle of the slip (from its middle, y down), turned with it.
    local function Rect(layer, sub, lx, ly, w, h, c, a)
        local t = Tex(layer, sub)
        t:SetColorTexture(c[1], c[2], c[3], a or 1)
        Place(t, lx, ly, w, h)
        return t
    end
    -- Four points of it (a triangle gives one twice); nothing where
    -- corners cannot move.
    local function Four(layer, sub, c, a, ...)
        local t = Tex(layer, sub)
        t:SetColorTexture(c[1], c[2], c[3], a or 1)
        if Quad(t, ...) then return t end
        t:Hide()
        mark.textures.used = mark.textures.used - 1
        return nil
    end

    -- The ribbon's tail: its middle line from under the slip's foot down
    -- and to the left, its two edges, and its swallowtail end; as points
    -- from the slip's middle, y down.
    local function Tail(W, H)
        local T = BOOKMARK.tail
        local a = math.rad(T.hang)
        local dx, dy = -math.sin(a), math.cos(a)
        local nx, ny = dy, -dx
        local ax, ay = -W / 2 + T.at + T.w / 2, H / 2 - 6
        local function At(t, side) return ax + dx * t + nx * side * T.w / 2, ay + dy * t + ny * side * T.w / 2 end
        return At, T.len, T.notch
    end

    -- The bookmark drawn, `lifted` under the mouse or lying: its shadows
    -- on the world (the slip's and the ribbon's), the ribbon under the slip,
    -- the slip lit, its cut edge, the eyelet and the words.
    function mark:Draw(lifted)
        local W, H = self.w, BOOKMARK.h
        local flat = ns.Setting("flatSheets") == true
        local turn = (flat or not self.turnsText) and 0 or math.rad(BOOKMARK.turn)
        plane.Set(turn, 0, 0, self.canBend and not flat)
        self.turn = turn
        mark.textures:Begin()
        local Hh = DungeonPage.HEIGHT
        local height = Hh.bookmark + (lifted and Hh.lifted or 0)
        self.height = height
        local layers, colour = DungeonPage.Cast(height, "world")
        local At, len, notch = Tail(W, H)
        local cloth = Style.RIBBONS.red
        self.shadows = {}
        for _, L in ipairs(layers) do
            local g = L[3]
            self.shadows[#self.shadows + 1] = Rect("BACKGROUND", -8, L[1], L[2], W + 2 * g, H + 2 * g, colour, L[4])
            local x1, y1 = At(0, -1)
            local x2, y2 = At(0, 1)
            local x3, y3 = At(len, 1)
            local x4, y4 = At(len, -1)
            Four("BACKGROUND", -8, colour, L[4], x1 + L[1] - g, y1 + L[2] - g, x2 + L[1] + g, y2 + L[2] - g,
                x3 + L[1] + g, y3 + L[2] + g, x4 + L[1] - g, y4 + L[2] + g)
        end
        -- The ribbon: satin, lit along its left edge, in shade along its
        -- right; the body to the notch, then the two points.
        local C, E = cloth.cloth, cloth.edge
        local function Satin(t)
            if t then Style.Gradient(t, "HORIZONTAL", { C[1] * 1.12, C[2] * 1.12, C[3] * 1.12, 1 }, { E[1], E[2], E[3], 1 }) end
            return t
        end
        local l1x, l1y = At(0, -1)
        local r1x, r1y = At(0, 1)
        local l2x, l2y = At(len - notch, -1)
        local r2x, r2y = At(len - notch, 1)
        local mx, my = At(len - notch, 0)
        local lex, ley = At(len, -1)
        local rex, rey = At(len, 1)
        self.ribbon = Satin(Four("BACKGROUND", -6, C, 1, l1x, l1y, r1x, r1y, r2x, r2y, l2x, l2y))
        Satin(Four("BACKGROUND", -6, C, 1, l2x, l2y, mx, my, mx, my, lex, ley))
        Satin(Four("BACKGROUND", -6, C, 1, mx, my, r2x, r2y, rex, rey, rex, rey))
        if not self.ribbon then
            -- Corners that cannot move: a turned band of cloth.
            local cx, cy = At(len / 2, 0)
            local t = Rect("BACKGROUND", -6, cx, cy, BOOKMARK.tail.w, len, C, 1)
            t:SetRotation(turn + math.rad(BOOKMARK.tail.hang))
            self.ribbon = t
        end
        -- The slip: its ink edge a hair out, the page's stock lit across.
        local I, P = Style.INK, Style.PAPER
        Rect("BORDER", -8, 0, 0, W + 1.2, H + 1.2, I, BOOKMARK.edge)
        self.paper = Rect("BORDER", -7, 0, 0, W, H, P, 1)
        if not flat then ns.UI.Light.Sheen(self.paper, Rect("BORDER", -6, 0, 0, W, H, P, 1), P) end
        -- The eyelet the ribbon is threaded through: brass, its hole, a
        -- glint up and to the left.
        local ex, ey = -W / 2 + BOOKMARK.tail.at + BOOKMARK.tail.w / 2, 0
        local e = BOOKMARK.eyelet
        for _, d in ipairs({ { Style.INK, 0.45, e + 1, 0.6, 0.6 }, { Style.BRASS_MID, 1, e, 0, 0 },
            { Style.INK_STRONG, 0.9, e * 0.42, 0, 0 }, { Style.BRASS_LIGHT, 0.55, e * 0.32, -e * 0.22, -e * 0.22 } }) do
            local t = Tex("ARTWORK", 0)
            Style.Disc(t, d[1][1], d[1][2], d[1][3], d[2])
            Place(t, ex + d[4], ey + d[5], d[3], d[3])
        end
        mark.textures:Finish()
        -- The words, in pencil, after the eyelet; darker under the mouse.
        local c = lifted and Style.INK_STRONG or Style.GRAPHITE
        self.words:SetTextColor(c[1], c[2], c[3])
        local tw = self.textW
        local th = math.max(self.words:GetStringHeight() or 0, 12)
        Place(self.words, -W / 2 + BOOKMARK.ribbon + tw / 2, 0.5, tw, th + tw * math.abs(math.sin(turn)) + 4)
    end

    -- "Tester's story" on it, its length to suit them; or its own `words`
    -- (opened from Your Diary: BOOKMARK.journey).
    function mark:Set(first, words)
        self.words:SetText(words or (first and ("%s's story"):format(first) or "Their story"))
        self.words:SetSize(0, 0)
        self.textW = (Surface.Width(self.words) or 0) + 2
        self.w = math.max(BOOKMARK.least, BOOKMARK.ribbon + self.textW + BOOKMARK.pad)
    end

    -- Laid with its middle at x, y of the spread (from the screen's
    -- middle, y up).
    function mark:LayAt(x, y)
        self.x, self.y = x, y
        local W, H = self.w, BOOKMARK.h
        local a = math.rad(BOOKMARK.turn)
        local hw = (W * math.abs(math.cos(a)) + H * math.abs(math.sin(a))) / 2
        local hh = (W * math.abs(math.sin(a)) + H * math.abs(math.cos(a))) / 2
        self:ClearAllPoints()
        self:SetPoint("CENTER", map, "CENTER", x, y)
        self:SetSize(2 * hw, 2 * hh)
        self:Draw(false)
        self:Show()
    end

    mark:SetScript("OnEnter", function(self) self:Draw(true) end)
    mark:SetScript("OnLeave", function(self) self:Draw(false) end)
    mark:SetScript("OnClick", function() DungeonPage.Close() end)
    return mark
end

-- Where the bookmark lies for a sheet w by h with its middle at dx, dy of
-- the spread (y up), turned SHEET.turn: its right end BOOKMARK.tuck px
-- under the sheet's left edge, BOOKMARK.down px down that edge from the
-- sheet's top-left corner. Its middle, in the spread's units.
function DungeonPage.BookmarkAt(dx, dy, w, h, length)
    local a = math.rad(DungeonPage.SHEET.turn)
    local c, s = math.cos(a), math.sin(a)
    local tlx, tly = dx - w / 2 * c - h / 2 * s, dy - w / 2 * s + h / 2 * c
    local d = BOOKMARK.down
    local px, py = tlx + d * s, tly - d * c
    return px + BOOKMARK.tuck - length / 2, py
end

-- How much room past the sheet's left edge the bookmark needs, for the
-- fit.
local function BookmarkFlank(mark)
    return (mark.w or BOOKMARK.least) - BOOKMARK.tuck + SPREAD.edge
end

--------------------------------------------------------------------------
-- Laying it out and putting it away
--------------------------------------------------------------------------

-- The sheet, w by h, laid where the book lies now (DungeonPage.Lie): as
-- it is shaped for each map and floor (the sheet's onMeasure). The spread
-- is the screen's at the book's scale, and shrinks only itself.
local function Fit(w, h)
    local book = J.journal
    local scale = book:GetScale()
    local bx, by = book:GetCenter()
    local S = DungeonPage.SHEET
    w, h = w or S.w, h or S.h
    local sw, sh = UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
    -- Room beside it for the bookmark by its top-left corner.
    local back = spread.back
    local flank = BookmarkFlank(back)
    local dx, dy, k, slid = DungeonPage.Lie(sw, sh, bx, by, w, h, flank, 0)
    spread.flank = flank
    spread:SetScale(scale * k)
    spread.lie = { dx, dy, scale = k, slid = slid }
    spread.map.lie = { dx, dy }
    -- The screen in the spread's own units, for a strip that sticks out
    -- past the sheet to stay on it (UI/Dungeon/Notes.lua); nil while its
    -- size is not known.
    spread.map.screen = (sw > 0 and sh > 0) and { w = sw / k, h = sh / k } or nil
    -- The bookmark by the sheet's top-left corner.
    back:LayAt(DungeonPage.BookmarkAt(dx, dy, w, h, back.w))
end

-- However the spread went (put away, Escape, the book shut): the run is
-- X
local function Gone()
    local open = J.visit ~= nil
    J.visit = nil
    DungeonPage.TutorialGone()
    -- The pen put down, what it drew kept (WAY-11).
    DungeonPage.WayPutDown(spread.map)
    spread.map:Hide(true)
    Away(false)
    StandIn(SPREAD.book)
    GameTooltip:Hide()
    -- The card's tooltip says what a click does now (Timeline.lua's
    -- VisitHint): open its map again.
    if open then J.RefreshTimelineList() end
    if open and not spread.quiet and J.journal:IsShown() then Style.PlaySound("sheetClose") end
    spread.quiet = nil
end

local function Build()
    local book = J.journal
    -- The screen's, not the book's: the book goes see-through under it.
    local host = CreateFrame("Frame", SPREAD.name, UIParent)
    host:SetAllPoints(UIParent)
    Above(host)
    host:Hide()
    spread = host

    host.map = DungeonPage.Sheet(host)
    host.map.onPutAway = function() DungeonPage.Close() end
    host.map.onMeasure = Fit
    -- The wheel stops at the table: the book under it, put aside, keeps
    -- its timeline where it was.
    host.map:EnableMouseWheel(true)
    host.map:SetScript("OnMouseWheel", function() end)
    host.back = Bookmark(host.map)
    Above(host)

    host:SetScript("OnHide", Gone)
    -- The screen changed under it: fitted again.
    host:RegisterEvent("UI_SCALE_CHANGED")
    host:RegisterEvent("DISPLAY_SIZE_CHANGED")
    host:SetScript("OnEvent", function(self)
        if self:IsShown() and J.visit then DungeonPage.Refresh() end
    end)
    -- Shut with the book; opened again, the book opens on the person.
    book:HookScript("OnHide", function() DungeonPage.Close(true) end)
    return host
end

-- Lays `visit` out on the table, opened from `guid`'s page (or from Your
-- Diary, `from` "journey", read as the user's own run): the book put
-- aside, the sheet laid where it lay.
local function Open(visit, guid, from)
    spread = spread or Build()
    if not spread:IsShown() then StandIn(SPREAD.name) end
    -- The bookmark's words, for its room beside the map.
    spread.back:Set(ns.Characters.Name(guid), from == "journey" and BOOKMARK.journey or nil)
    J.visit = { id = visit.id, guid = guid, from = from }
    -- Its card says a click puts it away, the timeline kept where it was.
    J.RefreshTimelineList()
    -- Nothing typed into the book while it is put aside (its search box).
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    local f = focus
    while f and f.GetParent do
        if f == J.journal then
            focus:ClearFocus()
            break
        end
        f = f:GetParent()
    end
    Away(true)
    Above(spread)
    spread:Show()
    spread:Raise()
    spread.map:Open(visit, guid)
    spread.map:Show()
    DungeonPage.Tutorial(spread)
end

-- Opens visit `visitId` from `guid`'s page (the selected person's by
-- default), or puts it away when it is out already: a second click on the
-- card. Opens the book on their page first where it is not open on it.
-- Returns whether the run is out now.
--
-- From Your Diary's run page (UI/Journey/Run.lua), `guid` is "journey": the
-- user's own run, read as theirs, the book left on the diary as it was, so
-- putting the run away gives back the same run's page; the bookmark says
-- so (BOOKMARK.journey).
function ns.UI.OpenVisit(visitId, guid)
    if guid == "journey" then
        if J.visit and J.visit.id == visitId and J.visit.from == "journey" then
            DungeonPage.Close()
            return false
        end
        local visit = ns.db.instances and ns.db.instances[visitId]
        if not visit then return false end
        GameTooltip:Hide()
        Open(visit, visit.me or ns.ownGUID, "journey")
        return true
    end
    guid = ns.SafeGUID(guid) or J.selected
    if J.visit and J.visit.id == visitId and J.visit.guid == guid then
        DungeonPage.Close()
        return false
    end
    local visit = guid and DungeonPage.Visit(guid, visitId)
    if not visit then return false end
    GameTooltip:Hide()
    if not (ns.UI.JournalShowing("people") and J.selected == guid) then ns.UI.ShowJournal(guid) end
    -- Their page as it is read: the story, not writing or a sheet.
    if J.editing then J.EndEdit() end
    if J.tab ~= "timeline" then
        J.tab = "timeline"
        J.RefreshProfile()
    end
    Open(visit, guid)
    return true
end

-- Puts the run away and gives the book back, the person's page as it was,
-- `quiet`ly (choosing someone else, the book turned or shut: another sound
-- says so). Returns whether a run was out.
function DungeonPage.Close(quiet)
    if not (spread and spread:IsShown()) then
        J.visit = nil
        return false
    end
    spread.quiet = quiet
    spread:Hide()
    return true
end

-- The run that is out laid again, as the settings are now (the usual way
-- through, UI/Settings/Sections/Dungeons.lua).
function DungeonPage.Refresh()
    if not (spread and spread:IsShown() and J.visit) then return end
    local visit = J.visit.from == "journey" and ns.db.instances[J.visit.id] or DungeonPage.Visit(J.visit.guid, J.visit.id)
    if visit then
        spread.map:Open(visit, J.visit.guid)
        DungeonPage.TutorialLay()
    else
        DungeonPage.Close(true)
    end
end

-- The host, for the tests: nil until a run has been laid out.
function DungeonPage.Spread() return spread end
