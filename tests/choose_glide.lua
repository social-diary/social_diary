-- The right page eased after a tick (UI/Journey/Glide.lua): the page final
-- at once, the motion only how it is seen. After a tick the plates, the
-- writing and the leaders run to exactly what an instant drawing gives; a
-- second tick mid-motion, any drawing, and Glide.Finish put everything at
-- its end; "Flat paper only" moves nothing; the page opened, turned or
-- drawn again eases nothing; plates are paired by what they hold. Invented
-- names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local YD = ns.UI.YourDiary
local J = ns.Journey
local Glide = YD.Glide

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

-- Five zones, a stop in each (as tests/choose_ui.lua's): three on the page.
local FOE = "Player-1111-0000CCCC"
local t0 = now - 20000
J.Begin(ns.ownGUID, t0, 12, 1411)
local j = J.Mine()
local function Stop(from, seconds, mapID, act, x, y)
    return { kind = "stop", from = from, to = from + seconds, mapID = mapID, x = x or 0.5, y = y or 0.5, r = 30,
        seconds = seconds, levelFrom = 12, levelTo = 12, act = act }
end
j.segments = { Stop(t0, 1000, 1411), Stop(t0 + 2000, 2000, 1412, { deaths = 1 }), Stop(t0 + 5000, 3000, 1413),
    Stop(t0 + 9000, 4000, 1415), Stop(t0 + 13200, 2000, 1415, nil, 0.44, 0.46), Stop(t0 + 16000, 500, 1416) }
j.open = nil
-- (and a fight at 1415's stop, and a second stop beside it on its plate:
-- that stop left out, the plate stays full in its slot and its picture
-- re-centres)
local FOE3 = "Player-1111-0000EEEE"
j.marks = { { kind = "fight", outcome = "won", guid = FOE, t = t0 + 6000, mapID = 1413, x = 0.52, y = 0.5 },
    { kind = "fight", outcome = "won", guid = FOE3, t = t0 + 9500, mapID = 1415, x = 0.5, y = 0.5 } }
J.Touch()

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
-- (mock frames start hidden: the page on the screen, as in the client)
page.right:Show()

local function Row(test)
    for _, row in ipairs(page.chooser.list.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
end
local function MomentRow(mapID, kind)
    return Row(function(item) return item.card ~= nil and item.card.zone.mapID == mapID and item.card.kind == kind end)
end
local function ZoneRow(mapID)
    return Row(function(item) return item.zone ~= nil and item.zone.mapID == mapID end)
end
local function Shown()
    local list = {}
    for i = 1, page.layout or 0 do list[#list + 1] = page.plates[i].mapID end
    return table.concat(list, " ")
end

local function N(v) return type(v) == "number" and ("%.2f"):format(v) or tostring(v) end
local function Anchor(region)
    local out = {}
    for _, v in ipairs({ region:GetPoint(1) }) do out[#out + 1] = N(v) end
    return table.concat(out, ",")
end
-- Everything the page shows as it is seen: each plate's slot, where its
-- card stands, its scale and alpha; whether any plate past the page's count
-- shows; every heading, caption and note's place and alpha; every leader's
-- strokes' alpha and its dot's place.
local function Seen()
    local out = {}
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        local s = plate.slot
        out[#out + 1] = ("plate %d %s %s %s %s|%s|%s|%s|%s"):format(i, tostring(plate.mapID), N(s.x), N(s.y), N(s.w),
            Anchor(plate.sheet), N(plate:GetScale()), N(plate:GetAlpha()), tostring(plate:IsShown()))
        out[#out + 1] = ("  picture %s|%s"):format(Anchor(plate.pivot), N(plate.content:GetScale()))
    end
    for i = (page.layout or 0) + 1, #page.plates do
        if page.plates[i]:IsShown() then out[#out + 1] = "a plate past the count shows: " .. i end
    end
    for p, pool in ipairs(page.rightPools) do
        for k = 1, pool.used do
            local item = pool[k]
            out[#out + 1] = ("pool %d.%d %s %s %s"):format(p, k, Anchor(item), N(item:GetAlpha()),
                tostring(item:IsShown()))
        end
    end
    return table.concat(out, "\n")
end
-- Nothing of the motion left on the page: every plate on it at scale 1 and
-- alpha 1, every heading, caption, note and leader at alpha 1 (nothing on
-- the right page sets its own alpha but the motion), and so the same after
-- an instant drawing, which sets neither.
local function Clean()
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        if plate:GetScale() ~= 1 or plate:GetAlpha() ~= 1 then return "plate " .. i end
        if plate.held or plate.content:GetScale() ~= 1 or select("#", plate.pivot:GetPoint(1)) ~= 3 then
            return "plate " .. i .. "'s picture held"
        end
    end
    for p, pool in ipairs(page.rightPools) do
        for k = 1, pool.used do
            if pool[k]:GetAlpha() ~= 1 then return ("pool %d.%d at %s"):format(p, k, N(pool[k]:GetAlpha())) end
        end
    end
    return "clean"
end
-- The driver run to the end, as the client's frames would.
local function Settle()
    for _ = 1, 40 do Glide.Step(1 / 30) end
end
-- What an instant drawing of the page as it is gives.
local function Instant()
    ns.UI.RedrawJourneyPage()
    return Seen()
end
local function Diff(a, b)
    local la, lb = {}, {}
    for l in a:gmatch("[^\n]+") do la[#la + 1] = l end
    for l in b:gmatch("[^\n]+") do lb[#lb + 1] = l end
    for k = 1, math.max(#la, #lb) do
        if la[k] ~= lb[k] then return ("line %d: %s ~= %s"):format(k, tostring(la[k]), tostring(lb[k])) end
    end
    return "same"
end

--------------------------------------------------------------------------
Section("opening, turning and drawing again ease nothing")

Eq(Shown(), "1412 1413 1415", "setup: the three busiest places on the page")
Check(not Glide.Moving(), "the page opened with motion")
local opened = Seen()
ns.UI.RedrawJourneyPage()
Check(not Glide.Moving(), "a drawing again moved")
Eq(Diff(Seen(), opened), "same", "drawn again, the page changed")
for i = 1, page.layout do Eq(page.plates[i]:GetScale(), 1, "a plate scaled with no tick") end

YD.Choose()
Check(page.choosing, "setup: the ticklist open")
Check(not Glide.Moving(), "the ticklist opened with motion")

--------------------------------------------------------------------------
Section("a tick: eased, and at its end exactly as an instant drawing")

local leaving = page.plates[2]  -- (1413's, left out below)
Eq(leaving.mapID, 1413, "setup: the zone to leave out on the second plate")
local staying = {}
for i = 1, page.layout do staying[page.plates[i].mapID] = page.plates[i] end
ZoneRow(1413):Click()
Eq(Shown(), "1411 1412 1415", "the zone left out, the next in")
Check(Glide.Moving(), "a tick did not ease")
-- The page is final at once: its count, its plates and slots.
Eq(page.layout, 3, "the page's count not final at once")
Eq(page.plates[2], staying[1412], "1412's plate not drawn on its own frame")
Eq(page.plates[3], staying[1415], "1415's plate not drawn on its own frame")
Check(page.plates[1] ~= leaving and page.plates[1] ~= staying[1412] and page.plates[1] ~= staying[1415],
    "the zone come in drawn on a frame that showed another")
Check(leaving:IsShown() and leaving.mapID == 1413, "the plate leaving did not keep its picture to fade from")
Eq(page.plates[1]:GetAlpha(), 0, "the plate coming in not faded in from nothing")
-- A plate that moved is held back where it was, and its leaders unseen.
local moved
for i = 2, 3 do
    if page.plates[i]:GetScale() ~= 1 then moved = page.plates[i] end
end
Check(moved ~= nil, "no plate held back at its old place and size")
for _, link in ipairs(page.links) do
    if link.plate == moved or link.plate == page.plates[1] then
        Eq(link.dot:GetAlpha(), 0, "a leader to a moving plate seen before it landed")
    end
end
Glide.Step(1 / 30)
local mid = moved:GetScale()
Check(mid ~= 1, "the plate already at its size after a frame")
Settle()
Check(not Glide.Moving(), "the motion never stopped")
Check(not leaving:IsShown() and leaving:GetAlpha() == 1, "the plate left not put away")
local eased = Seen()
Eq(Diff(eased, Instant()), "same", "the motion did not end as an instant drawing")
Eq(Clean(), "clean", "the motion left a scale or a fade on the page")

--------------------------------------------------------------------------
Section("a second tick mid-motion: the first put at its end, the next eased")

ZoneRow(1413):Click()  -- (kept again)
Check(Glide.Moving(), "setup: moving")
Glide.Step(1 / 30)
ZoneRow(1416):Click()
Check(Glide.Moving(), "the second tick did not ease")
for i = 1, #page.plates do
    local plate = page.plates[i]
    if i > page.layout then
        Check(not plate:IsShown() or plate:GetAlpha() > 0, "a plate of the first tick left half-faded")
    end
end
Glide.Finish()
Check(not Glide.Moving(), "Finish did not stop it")
Eq(Diff(Seen(), Instant()), "same", "put at its end, not as an instant drawing")
Eq(Clean(), "clean", "put at its end, a scale or a fade left")

-- Any drawing of the right page mid-motion starts from the page as drawn.
ZoneRow(1416):Click()
Check(Glide.Moving(), "setup: moving again")
local before = Seen()
ns.UI.RedrawJourneyPage()
Check(not Glide.Moving(), "a drawing mid-motion left it moving")
Check(before ~= Seen(), "setup: the motion was seen")
Eq(Diff(Seen(), Instant()), "same", "a drawing mid-motion not as an instant one")
Eq(Clean(), "clean", "a drawing mid-motion left a scale or a fade")

--------------------------------------------------------------------------
Section("the picture inside a plate that stays: eased from the old view")

do
    local function PlateOn(mapID)
        for i = 1, page.layout do
            if page.plates[i].mapID == mapID then return page.plates[i] end
        end
    end
    local plate = PlateOn(1415)
    Check(plate ~= nil, "setup: 1415 on the page")
    Eq(plate.under, nil, "an instant drawing printed wide")
    local slot, window = plate.slot, plate.window
    local function Fight()
        return Row(function(item) return item.card ~= nil and item.card.zone.mapID == 1415 and item.card.kind == "stay"
            and item.card.moment and item.card.moment.x == 0.44 end)
    end
    local fight = Fight()
    Check(fight ~= nil and fight.item.card.on, "setup: the second stop on 1415's plate")
    fight:Click()
    Eq(PlateOn(1415), plate, "1415 not drawn on its own frame")
    Eq(plate.slot, slot, "setup: the plate stays in its slot")
    local cx, ncx = (window[1] + window[3]) / 2, (plate.window[1] + plate.window[3]) / 2
    Check(math.abs(cx - ncx) > 1e-4, "setup: the picture re-centres")
    Check(Glide.Moving() and plate.held, "the picture not eased")
    Check(plate.under ~= nil, "the art not printed for the old view too")
    if plate.under then
        Check(plate.under[1] <= math.min(window[1], plate.window[1]) and plate.under[3] >= math.max(window[3],
            plate.window[3]), "the wider window does not hold the old view and the new")
    end
    local kx = (slot.w - 2 * slot.pad) / (plate.window[3] - plate.window[1])
    local function Offset() return select(4, plate.pivot:GetPoint(1)) or 0 end
    local start = (ncx - cx) * kx
    Check(math.abs(Offset() - start) < 0.5, ("the picture not held at the old view: %s, not %s"):format(
        tostring(Offset()), tostring(start)))
    Glide.Step(1 / 30)
    local mid = Offset()
    Check(math.abs(mid) < math.abs(start) and math.abs(mid) > 0 and mid * start > 0,
        "mid-motion the picture not between the old view and the new")
    Settle()
    Check(not plate.held, "the picture still held after the motion")
    Eq(select("#", plate.pivot:GetPoint(1)), 3, "the picture not back on the card's middle")
    Eq(plate.content:GetScale(), 1, "the picture still scaled")
    Eq(Clean(), "clean", "the motion left something held")
    Eq(Diff(Seen(), Instant()), "same", "the picture's motion did not end as an instant drawing")
    Eq(plate.under, nil, "a drawing after the motion still printed wide")
    Fight():Click()  -- (back on)
    Glide.Finish()
end

--------------------------------------------------------------------------
Section("flat paper only, and a page not on the screen: no motion")

ns.SetSetting("flatSheets", true)
ZoneRow(1412):Click()
Check(not Glide.Moving(), "flat paper eased")
Eq(Diff(Seen(), Instant()), "same", "flat paper: not as an instant drawing")
ZoneRow(1412):Click()
ns.SetSetting("flatSheets", false)
page.right:Hide()
ZoneRow(1415):Click()
Check(not Glide.Moving(), "a page not on the screen eased")
ZoneRow(1415):Click()
page.right:Show()

--------------------------------------------------------------------------
Section("the pairing: by the moments a plate holds")

do
    local function Plan(mapID, keys, box)
        local moments = {}
        for k, key in ipairs(keys) do moments[k] = { key = key, mapID = mapID } end
        return { mapID = mapID, moments = moments, x0 = box[1], y0 = box[2], x1 = box[3], y1 = box[4] }
    end
    local frames = { {}, {}, {} }
    local saved = page.plates
    page.plates = { frames[1], frames[2], frames[3] }
    local function From(list)
        local plates = {}
        for i, o in ipairs(list) do
            local keys = {}
            for _, m in ipairs(o.moments) do keys[m.key] = true end
            plates[i] = { i = i, frame = frames[i], slot = { x = 0, y = 0, w = 1, h = 1, t = 0 }, keys = keys,
                mapID = o.mapID, box = { o.x0, o.y0, o.x1, o.y1 } }
        end
        page.glideFrom = { plates = plates, writing = {}, links = {} }
    end
    -- Old: A (a, b, c) and B (d). New: a regroup splitting A, and B whole:
    -- the larger share keeps A's photo.
    From({ Plan(1, { "a", "b", "c" }, { 0.1, 0.1, 0.3, 0.3 }), Plan(2, { "d" }, { 0.5, 0.5, 0.6, 0.6 }) })
    Glide.Assign({ Plan(1, { "a" }, { 0.1, 0.1, 0.1, 0.1 }), Plan(1, { "b", "c" }, { 0.2, 0.2, 0.3, 0.3 }),
        Plan(2, { "d" }, { 0.5, 0.5, 0.6, 0.6 }) })
    local to = page.glideTo
    Eq(to.match[2] and to.match[2].frame, frames[1], "the larger share not on the old photo")
    Eq(to.match[3] and to.match[3].frame, frames[2], "the place whole not on its own photo")
    Eq(to.match[1], nil, "the smaller share paired")
    Eq(page.plates[1], frames[3], "the plate come anew not on the spare frame")
    Eq(page.plates[2], frames[1], "paired plates not drawn on their frames")
    -- None shared, one zone overlapping: paired; another zone: not.
    From({ Plan(1, { "a" }, { 0.1, 0.1, 0.3, 0.3 }), Plan(2, { "d" }, { 0.5, 0.5, 0.6, 0.6 }) })
    Glide.Assign({ Plan(1, { "x" }, { 0.2, 0.2, 0.4, 0.4 }), Plan(3, { "d2" }, { 0.5, 0.5, 0.6, 0.6 }) })
    to = page.glideTo
    Eq(to.match[1] and to.match[1].frame, frames[1], "one zone, overlapping, not paired")
    Eq(to.match[2], nil, "another zone paired")
    Eq(#to.leaving, 1, "the plate unpaired not leaving")
    page.glideTo, page.plates = nil, saved
end
