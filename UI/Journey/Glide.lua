-- The right page of Your Diary eased from one drawing to the next after a
-- tick (the user's, 18 Nov: "when we tick items on and off in the
-- ticklist, the plate maps jump; it would be nice if they eased into
-- position"). Only for what the player chose: a row or a zone ticked on the
-- ticklist (UI/Journey/Choose.lua's Tick), and the plate's and a person's
-- strip's right-click "leave out" lines (UI/Journey/CardSheet.lua). Opening
-- the diary, turning pages, a card written and every other drawing stay
-- instant, as before.
--
-- The page's state is final at once: the new page is drawn exactly as an
-- instant drawing would draw it (its plates in their slots, the captions,
-- notes and leaders where they belong), and only then are the frames held
-- back to where the eye last saw them and let go. Nothing reads the motion:
-- the tests, the pad's focus model and the ticklist see the page as drawn.
-- A second tick while it moves puts everything at its end first (Finish),
-- so the motion never lags behind the hand; so does any other drawing of
-- the right page (DrawRight), and the page hidden (the book closed, a
-- ribbon turned).
--
-- How the plates are told apart: by what they hold, not by their slot.
-- Before the drawing (Ask) each plate on the page is noted with the keys of
-- its moments (Chosen.Key); as the new page's plates are handed their frames
-- (Assign, from DrawPlates), each new plate is paired with the old one that
-- shares most keys with it (a regroup that splits or merges a place keeps
-- the larger share's photo), or failing any, one of the same zone whose
-- moments' box overlaps its own; pairs are taken best first, then nearest
-- in order. A paired plate is drawn on the very frame it was on, so a plate
-- that leaves keeps its frame, its picture untouched, to fade from.
--
-- What moves and what fades (GLIDE):
--   a plate that stays  slides and grows (or shrinks) from its old place
--                       to its new one, eased out, as a photo pushed into
--                       place in an album: the card's middle travels, and
--                       its size is scaled about it. Its turn is the new
--                       one from the start (a degree or two; the card's
--                       turn is laid in its mesh, not turned per frame).
--   its picture         eases from the old view to the new in the same
--                       motion (the user's, 18 Nov: a tick that takes a
--                       moment off re-centred the map in one jump): drawn
--                       at the new window, then held at the old view's
--                       middle and scale (plate:Glimpse, the full page's
--                       way of showing a view, Plate.lua's Picture) and
--                       let go with the card, the card's growth taken out
--                       so the map keeps its scale while the photo slides.
--                       Its marks, trail and crosses lie on the picture and
--                       travel with it. For that one drawing the art is
--                       printed for the old view and the new together
--                       (Under, DrawArt's `under`), so no bare paper shows
--                       at an edge; the few tiles more stay, clipped under
--                       the card's margin, until the plate is next drawn.
--   a plate that leaves fades out where it was, quicker (`out`).
--   a plate that comes  fades in where it lands (`enter`).
--   the writing         headings, captions, strips and cards: whatever is
--                       not exactly as it was (its place, width, words)
--                       fades in where it now stands (`words`), starting as
--                       the plates slow; what did not change stays.
--   the leaders         a leader whose plate moves, comes or whose line
--                       changed is not seen until its plate has all but
--                       landed (`leaders`), so no pencil line ever points at
--                       a mark that is not there yet; one that did not
--                       change, to a plate that did not move, stays.
-- "Flat paper only" moves nothing (as the tour and a loose sheet's arrival:
-- the setting is the house's reduced motion).
--
-- One OnUpdate on a small frame of the right page's, running only while
-- something moves and stopping itself; the tracks and their functions are
-- made once at the tick, nothing per frame but SetScale, SetPoint and
-- SetAlpha. No Blizzard frame is touched.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Style = ns.Style
local YourDiary = ns.UI.YourDiary

-- The timings, in seconds from the tick. `secs`: a plate's slide (short and
-- quiet, as the brief asked: about a quarter of a second). `out`: a plate
-- leaving fades over this (an exit is quicker than an entrance). `enter`:
-- a plate coming fades in from..to, a breath after the leaving one starts.
-- `words`: changed writing fades in from..to, starting as the plates have
-- done most of their way (eased out, at 0.12 s a plate has gone about 90%).
-- `leaders`: a leader to a moving plate fades in from..to, from the time
-- its plate is within a pixel or two of its place (0.22 of 0.28 s: 99.8%).
-- `still`: a plate whose slot moved by less than this many px (and kept
-- its size) does not move at all.
local GLIDE = {
    secs = 0.28,
    out = 0.2,
    enter = { 0.06, 0.28 },
    words = { 0.12, 0.34 },
    leaders = { 0.22, 0.38 },
    still = 0.5,
}
YourDiary.GLIDE = GLIDE

local Glide = {}
YourDiary.Glide = Glide

-- Eased out, quartic: the house's curve (a loose sheet's arrival,
-- UI/Paper/Sheet.lua; the tour's motion, UI/Windows/Intro/Tour.lua), never
-- past its end.
local function Ease(t) return 1 - (1 - t) ^ 4 end

--------------------------------------------------------------------------
-- The motion: tracks, one driver, finished at once
--------------------------------------------------------------------------

-- Each track: { from, to (s), fn(e) (e eased 0..1; fn(1) leaves it as
-- drawn), done }.
local tracks, clock, driver = {}, 0, nil

local function Stop()
    tracks, clock = {}, 0
    if driver then driver:SetScript("OnUpdate", nil) end
end

-- Everything at its end, at once: a second tick, any drawing of the right
-- page, the page hidden.
local function Finish()
    if not tracks[1] then return end
    local list = tracks
    Stop()
    for _, t in ipairs(list) do
        if not t.done then
            t.done = true
            t.fn(1)
        end
    end
end
Glide.Finish = Finish

local function Run(_, elapsed)
    clock = clock + (elapsed or 0)
    local live = false
    for _, t in ipairs(tracks) do
        if not t.done then
            local p = (clock - t.from) / math.max(t.to - t.from, 0.001)
            if p >= 1 then
                t.done = true
                t.fn(1)
            else
                live = true
                if p > 0 then t.fn(Ease(p)) end
            end
        end
    end
    if not live then Stop() end
end

local function Track(from, to, fn)
    tracks[#tracks + 1] = { from = from, to = to, fn = fn }
    fn(0)
end

-- Whether a track is running (the tests; nothing else asks).
function Glide.Moving() return tracks[1] ~= nil end

-- The driver's frame, one step as the client would run it (the tests).
function Glide.Step(elapsed)
    if tracks[1] then Run(driver, elapsed) end
end

--------------------------------------------------------------------------
-- What the eye saw: the plates, the writing, the leaders
--------------------------------------------------------------------------

local function Rect(s)
    return { x = s.x, y = s.y, w = s.w, h = s.h, t = s.t or 0, pad = s.pad or 0 }
end

local function KeysOf(plan)
    local keys = {}
    for _, m in ipairs(plan and plan.moments or {}) do keys[ns.Chosen.Key(m)] = true end
    return keys
end

-- A note, heading or caption as it stands: its anchor, width and words (a
-- strip's: its heading). Two the same are the
-- same writing in the same place, whichever of the pool's it is now.
local function Part(v)
    if type(v) == "number" then return ("%.1f"):format(v) end
    return tostring(v)
end
local function Sig(item)
    local out = {}
    for _, v in ipairs({ item:GetPoint(1) }) do out[#out + 1] = Part(v) end
    out[#out + 1] = Part(item:GetWidth() or 0)
    if item.GetText then out[#out + 1] = tostring(item:GetText() or "") end
    -- (a strip's heading, its public `name`: who or what it is written for)
    local name = rawget(item, "name")
    if type(name) == "table" and name.GetText then out[#out + 1] = tostring(name:GetText() or "") end
    return table.concat(out, "|")
end

local function LinkSig(link)
    local points = link.drawn and link.drawn > 0 and link.points
    if not points then return "-" end
    local out = {}
    for k, v in ipairs(points) do out[k] = ("%.1f"):format(v) end
    return table.concat(out, ",")
end

-- The pools of writing on the right page: all of its pools but the
-- leaders' strokes and dots (asked by their links).
local function Writing(page)
    local out = {}
    for _, pool in ipairs(page.rightPools or {}) do
        if pool ~= page.leaderPool and pool ~= page.dotPool then out[#out + 1] = pool end
    end
    return out
end

-- Whether the page eases at all: the plates' page, on the screen, not laid
-- flat.
local function Wanted(page)
    return page ~= nil and page.mode == "plates" and page.right ~= nil and page.right:IsVisible()
        and ns.Setting("flatSheets") ~= true
end

-- Before a drawing the player asked for by a tick: what the page shows now,
-- for the drawing to be eased from (page.glideFrom). Anything still moving
-- is put at its end first. Nothing where the page does not ease.
function Glide.Ask()
    local page = YourDiary.page
    Finish()
    if not page then return end
    page.glideFrom, page.glideTo = nil, nil
    if not Wanted(page) then return end
    local from = { plates = {}, writing = {}, links = {} }
    for i = 1, type(page.layout) == "number" and page.layout or 0 do
        local plate = page.plates[i]
        if plate and plate:IsShown() and plate.slot and plate.plan then
            local plan = plate.plan
            local w = plate.window
            from.plates[#from.plates + 1] = { i = i, frame = plate, slot = Rect(plate.slot), keys = KeysOf(plan),
                mapID = plan.mapID, box = { plan.x0, plan.y0, plan.x1, plan.y1 },
                drawn = plate.mapID, window = w and { w[1], w[2], w[3], w[4] } }
        end
    end
    for _, pool in ipairs(Writing(page)) do
        for k = 1, pool.used or 0 do from.writing[Sig(pool[k])] = true end
    end
    for _, link in ipairs(page.links or {}) do from.links[LinkSig(link)] = true end
    page.glideFrom = from
end

--------------------------------------------------------------------------
-- The new plates paired with the old, and given their frames
--------------------------------------------------------------------------

-- How much new plate `p` is old plate `o`: the keys they share, or a
-- quarter where they share none but lie on one zone, their moments' boxes
-- overlapping (a place whose moments were all ticked anew).
local function Score(o, p)
    local shared = 0
    for _, m in ipairs(p.moments or {}) do
        if o.keys[ns.Chosen.Key(m)] then shared = shared + 1 end
    end
    if shared > 0 then return shared end
    local b = o.box
    if o.mapID == p.mapID and b[1] and p.x0 and p.x0 <= b[3] and b[1] <= p.x1 and p.y0 <= b[4] and b[2] <= p.y1 then
        return 0.25
    end
    return 0
end

-- From DrawPlates, before it hands the plates their frames: the new
-- `plates` paired with the old (page.glideFrom), and page.plates ordered so
-- each paired plate is drawn on its old frame, a plate come anew on a frame
-- that showed nothing (or a new one), and a plate leaving keeps its frame
-- past the page's count, undrawn. Nothing without a tick's Ask.
function Glide.Assign(plates)
    local page = YourDiary.page
    local from = page and page.glideFrom
    if not from then return end
    page.glideFrom = nil
    local pairsOf = {}
    for _, o in ipairs(from.plates) do
        for j, p in ipairs(plates) do
            local score = Score(o, p)
            if score > 0 then pairsOf[#pairsOf + 1] = { o = o, j = j, score = score } end
        end
    end
    table.sort(pairsOf, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local da, db = math.abs(a.o.i - a.j), math.abs(b.o.i - b.j)
        if da ~= db then return da < db end
        if a.o.i ~= b.o.i then return a.o.i < b.o.i end
        return a.j < b.j
    end)
    local match, taken = {}, {}
    for _, pair in ipairs(pairsOf) do
        if not match[pair.j] and not taken[pair.o] then match[pair.j], taken[pair.o] = pair.o, true end
    end
    local leaving, mine = {}, {}
    for _, o in ipairs(from.plates) do
        mine[o.frame] = true
        if not taken[o] then leaving[#leaving + 1] = o.frame end
    end
    local spare = {}
    for _, f in ipairs(page.plates) do
        if not mine[f] then spare[#spare + 1] = f end
    end
    local frames = {}
    for j = 1, #plates do
        frames[j] = match[j] and match[j].frame or table.remove(spare, 1) or YourDiary.NewPlate()
    end
    for _, f in ipairs(leaving) do frames[#frames + 1] = f end
    for _, f in ipairs(spare) do frames[#frames + 1] = f end
    for k = 1, math.max(#frames, #page.plates) do page.plates[k] = frames[k] end
    -- (each frame told the view it showed, for its art to be printed wide
    -- enough to ease from it: Glide.Under)
    for k, f in ipairs(page.plates) do
        if type(f) == "table" then f.glideOld = k <= #plates and match[k] or nil end
    end
    page.glideTo = { match = match, leaving = leaving, from = from }
end

--------------------------------------------------------------------------
-- The picture inside a plate: eased from the old view
--------------------------------------------------------------------------

-- The card's growth from its old slot to `b` (its scale at the start of
-- the slide, about its middle), and the old view's middle and scale (card
-- px a map unit, across and down), where `old` showed the same map.
local function Grow(a, b)
    return math.sqrt((a.w / b.w) * (a.h / b.h))
end
local function OldView(old, mapID)
    local w, a = old and old.window, old and old.slot
    if not (w and a and old.drawn == mapID) then return nil end
    return (w[1] + w[3]) / 2, (w[2] + w[4]) / 2, (a.w - 2 * a.pad) / (w[3] - w[1]), (a.h - 2 * a.pad) / (w[4] - w[2])
end

-- From Plated, as a plate paired with one of the old page's is drawn at
-- `window` of `mapID` in its slot (plate.slot): the wider window its art is
-- printed for (DrawArt's `under`), so the picture eased from the old view
-- covers the art box all the way (the old view as it first shows: its
-- middle, at its scale, over the card's new art box grown as the slide
-- starts; the slide and the view's scale are eased together, so every
-- view on the way lies between that and the new one), with UNDER px more
-- round it. Nil where the window holds it already, the plate is not
-- paired, or showed another map: then nothing is printed but the window.
local UNDER = 2
function Glide.Under(plate, mapID, window)
    local old = plate.glideOld
    local b = plate.slot
    local ocx, ocy, okx, oky = OldView(old, mapID)
    if not (ocx and b) then return nil end
    local s0 = Grow(old.slot, b)
    local hw, hh = (b.w - 2 * b.pad) * s0 / 2 / okx, (b.h - 2 * b.pad) * s0 / 2 / oky
    local nkx, nky = (b.w - 2 * b.pad) / (window[3] - window[1]), (b.h - 2 * b.pad) / (window[4] - window[2])
    local mx, my = UNDER / nkx, UNDER / nky
    local u = { math.min(window[1], ocx - hw - mx), math.min(window[2], ocy - hh - my),
        math.max(window[3], ocx + hw + mx), math.max(window[4], ocy + hh + my) }
    if u[1] >= window[1] and u[2] >= window[2] and u[3] <= window[3] and u[4] <= window[4] then return nil end
    return u
end

--------------------------------------------------------------------------
-- After the drawing: the frames held back and let go
--------------------------------------------------------------------------

local function Moved(a, b)
    local S = GLIDE.still
    return math.abs(a.x - b.x) >= S or math.abs(a.y - b.y) >= S or math.abs(a.w - b.w) >= S
        or math.abs(a.h - b.h) >= S
end

local function Fade(region, from, to)
    local alpha = region:GetAlpha() or 1
    Track(from, to, function(e) region:SetAlpha(alpha * e) end)
end

-- After the page was drawn for a tick: every frame eased from where the eye
-- last saw it (Ask, Assign) to where it now is. Nothing where the drawing
-- was not a tick's, or the page does not ease.
function Glide.Go()
    local page = YourDiary.page
    local to = page and page.glideTo
    if page then
        page.glideFrom, page.glideTo = nil, nil
        -- (asked by Plated for each drawing of the tick's, F+L's and TOP's
        -- tries too; no later drawing prints wide)
        for _, f in ipairs(page.plates) do f.glideOld = nil end
    end
    if not (to and Wanted(page)) then return end
    if not driver then
        driver = CreateFrame("Frame", nil, page.right)
        driver:SetSize(1, 1)
        driver:SetPoint("TOPLEFT")
        -- (a hidden frame hears no OnUpdate: the page hidden mid-motion
        -- puts everything at its end)
        driver:SetScript("OnHide", Finish)
    end
    driver:Show()
    Stop()

    local moving = {}
    for j = 1, page.layout or 0 do
        local plate = page.plates[j]
        local old = to.match[j]
        if plate and plate:IsShown() and plate.slot then
            if not old then
                moving[plate] = true
                Fade(plate, GLIDE.enter[1], GLIDE.enter[2])
            else
                local a, b = old.slot, Rect(plate.slot)
                local moves = Moved(a, b)
                local dx = (a.x + a.w / 2) - (b.x + b.w / 2)
                local dy = (a.y + a.h / 2) - (b.y + b.h / 2)
                local grow = moves and Grow(a, b) - 1 or 0
                -- The picture inside it, from the old view to the new: its
                -- middle and its scale on the map (screen px a map unit),
                -- eased with the card, the card's own growth taken out so
                -- the two read as one motion.
                local w = plate.window
                local ocx, ocy, okx = OldView(old, plate.mapID)
                local ncx, ncy, nkx
                if ocx and w then
                    ncx, ncy, nkx = (w[1] + w[3]) / 2, (w[2] + w[4]) / 2, (b.w - 2 * b.pad) / (w[3] - w[1])
                    -- (a card that slides and grows always: its picture
                    -- kept at its scale on the map, not grown with it)
                    if not moves and math.abs(ocx - ncx) * nkx < GLIDE.still
                        and math.abs(ocy - ncy) * nkx < GLIDE.still and math.abs(okx - nkx) < 1e-6 * nkx then
                        ocx = nil
                    end
                end
                if moves or ocx then
                    moving[plate] = true
                    Track(0, GLIDE.secs, function(e)
                        local k = 1 - e
                        if k <= 0 then
                            plate:Shift()
                            plate:Glimpse()
                            return
                        end
                        local s = 1 + grow * k
                        if moves then plate:Shift(dx * k, dy * k, s) end
                        if ocx then
                            plate:Glimpse(ocx + (ncx - ocx) * e, ocy + (ncy - ocy) * e, (okx + (nkx - okx) * e) / (s * nkx))
                        end
                    end)
                end
            end
        end
    end
    for _, frame in ipairs(to.leaving) do
        frame:Show()
        Track(0, GLIDE.out, function(e)
            if e >= 1 then
                frame:Hide()
                frame:SetAlpha(1)
            else
                frame:SetAlpha(1 - e)
            end
        end)
    end

    local W = GLIDE.words
    for _, pool in ipairs(Writing(page)) do
        for k = 1, pool.used or 0 do
            local item = pool[k]
            if not to.from.writing[Sig(item)] then Fade(item, W[1], W[2]) end
        end
    end
    for _, link in ipairs(page.links or {}) do
        local late = moving[link.plate]
        if late or not to.from.links[LinkSig(link)] then
            local span = late and GLIDE.leaders or W
            for _, stroke in ipairs(link.strokes) do Fade(stroke, span[1], span[2]) end
            Fade(link.dot, span[1], span[2])
        end
    end
    if tracks[1] then
        clock = 0
        driver:SetScript("OnUpdate", Run)
    end
end

-- A drawing for a tick, eased: Ask, `draw` (the page drawn again, final),
-- Go.
function Glide.Around(draw)
    Glide.Ask()
    draw()
    Glide.Go()
end
