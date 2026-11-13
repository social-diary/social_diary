-- The lucky card (Features/Hunts/LuckyCard.lua, JRN-27): good luck with a quest's
-- drops, the drop tables' "expected 58" printed and struck out, a tag
-- of fresher paper taped over it saying what happened instead. Its words
-- in every size, its sizes by the room it has and its steps down, the
-- strike and the underline, the hunt it is for, its rank in the margin
-- (after the close call, before the slow hunt), the caption that counts
-- the rest of the luck; and S, on a light plate's print: the item's icon
-- stuck on the slip's right edge (60 % on it, 40 % past it), clear of the
-- tag, everything on the print but the tag's foot, and the tucked print
-- (F+L) given up where S will not go on it. Laid flat as well.
--
-- The mock measures every string at 6 px a byte: the sizes asserted here
-- are the mock's, not the client's (in the client Friz and Neuton run a
-- little narrower, and the cards a size larger).

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local Lucky = ns.Hunts.LuckyCard
local NB = "\194\160"

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local KOLKAR = { kills = 4, need = 7, item = "Kolkar Booty Key", name = "Kolkar Marauder", npcID = 3275,
    questID = 4021, title = "Counterattack!", expected = 58.3, level = 14, t = now - 3600 }
local HEZRUL = { kills = 1, need = 1, item = "Hezrul's Head", itemID = 5025, name = "Hezrul Bloodmark", npcID = 3396,
    questID = 852, title = "Hezrul's Head", expected = 10, level = 14, t = now - 4000 }
local MANY = { kills = 14, need = 10, item = "Kolkar Booty Key", name = "Kolkar Marauder", expected = 121 }
local HORNS = { kills = 2, need = 5, item = "Intact Raptor Horn", name = "Sunscale Scytheclaw", expected = 24,
    byKind = { [3256] = { n = 1, name = "Sunscale Scytheclaw" }, [3254] = { n = 1, name = "Sunscale Lashtail" } } }
mock.itemInfo[5025] = { icon = 134169, quality = 1 }

local function Lines(list)
    local parts = {}
    for _, line in ipairs(list) do parts[#parts + 1] = line.text .. (line.under and ("[" .. line.under .. "]") or "") end
    return table.concat(parts, "/")
end

--------------------------------------------------------------------------
Section("the words, every size")

Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "XL")), "dropped[dropped]/after just four", "XL: two lines, \"just\"")
Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "L")), "dropped after just four[dropped]", "L: one line")
Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "M1")), "dropped after four[dropped]", "M1: no \"just\"")
Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "M2")), "dropped[dropped]/after four", "M2: two lines")
Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "M2s")), "dropped[dropped]/after four", "M2s: as M2, beside")
Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "S")), "after four[four]", "S: the count underlined (13 Oct)")
Eq(Lines(ns.Hunts.LuckyTag(KOLKAR, "S-")), "four[four]", "S-: the count alone")
Eq(Lines(ns.Hunts.LuckyTag(HEZRUL, "XL")), "dropped[dropped]/on the first", "one kill, XL")
Eq(Lines(ns.Hunts.LuckyTag(HEZRUL, "L")), "dropped on the first[dropped]", "one kill, L")
Eq(Lines(ns.Hunts.LuckyTag(HEZRUL, "S")), "on the first[first]", "one kill, S")
Eq(Lines(ns.Hunts.LuckyTag(HEZRUL, "S-")), "the first[first]", "one kill, S-")
Eq(Lines(ns.Hunts.LuckyTag(MANY, "L")), "dropped after just 14" .. NB .. "kills[dropped]", "past ten, a figure with its noun")
Eq(Lines(ns.Hunts.LuckyTag(MANY, "S-")), "14" .. NB .. "kills[14" .. NB .. "kills]", "past ten at S-")
Eq(Lines(ns.Hunts.LuckyTag({ kills = 10, expected = 90 }, "M1")), "dropped after ten[dropped]", "ten is still a word")
Eq(ns.Hunts.LuckyKind(KOLKAR), "Kolkar Marauders", "the creature's line")
Eq(ns.Hunts.LuckyKind(HEZRUL), "Hezrul Bloodmark", "one kill keeps the name singular")
Eq(ns.Hunts.LuckyKind(HORNS), "Sunscale Scytheclaws and others", "several kinds")
Eq(ns.Hunts.LuckyKind({ kills = 3 }), nil, "a nameless creature has no line")
Eq(ns.Hunts.LuckyCaption(KOLKAR), "7" .. NB .. "Kolkar Booty Keys from Kolkar Marauders", "the print's caption")
Eq(ns.Hunts.LuckyCaption(HEZRUL), "Hezrul's Head from Hezrul Bloodmark", "one item")
Eq(ns.Hunts.LuckyCaption({ need = 3, kills = 4, item = "Thunder Lizard Blood", name = "Thunder Lizard" }),
    "3" .. NB .. "Thunder Lizard Blood from Thunder Lizards", "what is not counted keeps its name")
Eq(ns.Hunts.LuckyCaption({ need = 1, kills = 2, item = "Stolen Silver" }), "Stolen Silver", "nameless: the item alone")
Eq(ns.Hunts.ExpectedLabel(KOLKAR), "expected 58", "the struck words")
for _, form in ipairs({ "XL", "L", "M1", "M2", "S", "S-" }) do
    for _, hunt in ipairs({ KOLKAR, HEZRUL, MANY }) do
        local said = Lines(ns.Hunts.LuckyTag(hunt, form))
        Check(not said:find("[&!]") and not said:find("%d%d?$"), "a bare figure or loud mark: " .. said)
    end
end

--------------------------------------------------------------------------
Section("the caption, with the card and with the print")

mock.mapNames[2665] = "Zephras Isle"
local function Moment(kind, hunt) return { kind = kind, t = now - 100, hunt = hunt } end
local plate = { mapID = 1413, moments = { Moment("death"), Moment("fortune", KOLKAR), Moment("fortune", HEZRUL) } }
Eq(Text.PlateCaption(plate), "A death, and two lucky hunts.", "without a card, as before")
Eq(Text.PlateCaption(plate, nil, { fortune = { hunt = KOLKAR } }), "A death, and another lucky hunt.",
    "the card's hunt leaves the words, the other is counted")
plate.moments[#plate.moments + 1] = Moment("fortune", MANY)
Eq(Text.PlateCaption(plate, nil, { fortune = { hunt = KOLKAR } }), "A death, and two more lucky hunts.",
    "two more counted")
local alone = { mapID = 2665, moments = { Moment("fortune", KOLKAR), { kind = "arrive", t = now - 50 } } }
Eq(Text.PlateCaption(alone, nil, { fortune = { hunt = KOLKAR } }),
    "Into Zephras Isle for the first time.", "with its only luck on the card, the words go on to what else")
Eq(Text.PlateCaption(alone, nil, { fortune = { hunt = KOLKAR, print = true } }),
    "7" .. NB .. "Kolkar Booty Keys from Kolkar Marauders.", "on the print: the item and who dropped it")
alone.moments[#alone.moments + 1] = Moment("fortune", HEZRUL)
Eq(Text.PlateCaption(alone, nil, { fortune = { hunt = KOLKAR, print = true } }),
    "7" .. NB .. "Kolkar Booty Keys from Kolkar Marauders, and another lucky hunt.", "and the rest counted")
Eq(Text.PlateCaption(alone), "Two lucky hunts.", "nothing shown: as before")

--------------------------------------------------------------------------
Section("which hunt")

local function Mark(list, x, y) return { list = list, x = x, y = y, at = { x + 100, y + 100 } } end
local chosen = Lucky.Choose({ Mark({ { hunt = HEZRUL } }, 1, 1), Mark({ { hunt = KOLKAR } }, 2, 2) })
Eq(chosen.hunt, KOLKAR, "4 for 58 is luckier than 1 for 10")
Check(chosen.mark[1] == 102 and chosen.x == 2, "its star: on the page and on the card")
local twin = { kills = 4, expected = 58.3, t = now }
Eq(Lucky.Choose({ Mark({ { hunt = KOLKAR }, { hunt = twin } }, 1, 1) }).hunt, twin, "the latest of equals")
Check(Lucky.Choose({}) == nil and Lucky.Choose({ Mark({ { kind = "fortune" } }, 1, 1) }) == nil, "no hunt, no card")
Eq(Lucky.Ratio({ kills = 3 }), math.huge, "no rates, no luck")

--------------------------------------------------------------------------
Section("the strike and the underline")

-- A single pass of the pen through the words (13 Nov: the scribble's
-- zigzag was too strong over them): left to right, never turning back,
-- from before the words to past them, inside the figures' cap band with
-- its own width, nearly level, and one line thick wherever it is cut.
local S = Lucky.STRIKE
local function Struck(seed, x0, mid, w, size)
    local P, half = Lucky.Strike(seed, x0, mid, w, size)
    Eq(half, S.cap * size / 2, "the cap band: " .. seed)
    for k = 2, #P do
        Check(P[k].x > P[k - 1].x, "the strike turns back: " .. seed .. ", " .. k)
    end
    local first, last = P[1], P[#P]
    Check(first.x <= x0 - S.lead[1] + 1e-9 and first.x >= x0 - S.lead[2] - 1e-9, "the strike's start: " .. seed)
    Check(last.x >= x0 + w + S.tail[1] - 1e-9 and last.x <= x0 + w + S.tail[2] + 1e-9, "the strike's end: " .. seed)
    for k, p in ipairs(P) do
        Check(math.abs(p.y - mid) + S.width / 2 * S.nib.thick <= half, "the strike leaves the words: " .. seed .. ", " .. k)
    end
    Check(math.abs(last.y - first.y) <= 2 * (S.keep * half + S.jitter) + 1e-9, "the strike's tilt: " .. seed)
    -- One line, not a zigzag: its run is hardly longer than its span.
    local run = 0
    for k = 2, #P do run = run + math.sqrt((P[k].x - P[k - 1].x) ^ 2 + (P[k].y - P[k - 1].y) ^ 2) end
    Check(run <= (last.x - first.x) * 1.02, "the strike wanders: " .. seed .. ", " .. run)
    Check(#P - 1 >= 3 and #P - 1 <= S.most, "the strike's pieces: " .. seed .. ", " .. (#P - 1))
    return P
end
local P = Struck("lucky:4021:1413:14:s", 0, 10, 66, 13)
-- "expected 58" at 13 px: a piece every `step`, about 18 (the scribble
-- took 25).
Check(#P - 1 >= 16 and #P - 1 <= 20, "the strike's pieces: " .. (#P - 1))
local rising = 0
for k = 1, 40 do
    for _, size in ipairs({ 13, 11 }) do
        local Q = Struck("seed:" .. k .. ":" .. size, 30, 40, 20 + 9 * k, size)
        if Q[#Q].y < Q[1].y then rising = rising + 1 end
    end
end
Check(rising > 40, "a hand's strike mostly rises: " .. rising .. " of 80")
local again = Lucky.Strike("lucky:4021:1413:14:s", 0, 10, 66, 13)
Check(again[5].x == P[5].x and again[9].y == P[9].y, "the same seed strikes differently")
local other = Lucky.Strike("lucky:852:1413:14:s", 0, 10, 66, 13)
Check(other[5].x ~= P[5].x or other[5].y ~= P[5].y, "another seed strikes the same")
local prims = Lucky.Pen(P, S)
Eq(#prims, #P - 1, "a quad a piece")
Check(math.abs(prims[1].a - S.alpha) < 1e-9 and prims[1].r == ns.Style.INK_STRONG[1], "the strike's ink")
-- The pen's line as drawn: under the underline's width everywhere, landing
-- and lifting thinner than it runs.
local function Thick(q) return math.sqrt((q.x2 - q.x3) ^ 2 + (q.y2 - q.y3) ^ 2) end
local widest = 0
for _, q in ipairs(prims) do widest = math.max(widest, Thick(q)) end
Check(widest < Lucky.UNDER.width and widest > 0.8, "the strike's width: " .. widest)
Check(Thick(prims[#prims]) < 0.6 * widest, "the strike does not thin as the pen lifts")
Eq(Lucky.UNDER.nib, S.nib, "the underline is the strike's pen")
local U = Lucky.Underline("u", 10, 50, 20)
Check(#U - 1 <= Lucky.UNDER.most and #U >= 4, "the underline's pieces: " .. #U)
Check(U[1].y > 20 and U[#U].y > 20 and U[#U].y < U[1].y, "the underline is not under the baseline, rising off")
Check(U[1].x < 10 and U[#U].x > 50, "the underline does not run past the word")

--------------------------------------------------------------------------
Section("the card's sizes, and its steps down")

ns.UI.ShowJournal()
local page = ns.UI.JourneyPage()
local function New(hunt, width)
    local c = Lucky.New(page.right)
    c:SetHunt({ hunt = hunt, mark = { 0, 0 } }, "lucky:test", now)
    c:Layout(10, 10, width)
    return c
end
-- (The mock's 6 px a byte: XL for Kolkar wants 221.)
local xl = New(KOLKAR, 260)
Eq(xl.plan.form, "XL", "a wide box: the tag beside the struck words")
Eq(xl.box[3], 221, "XL's width in the mock")
Eq(xl:Preferred(), 221, "the card's wish is XL's width")
Eq(Lucky.Preferred({ hunt = KOLKAR }), 221, "measured apart")
Eq(xl:Tag(), "dropped/after just four", "XL's tag")
Eq(xl.plan.creature and xl.plan.creature.text, "Kolkar Marauders", "XL names the creature")
Check(xl.kind:IsShown() and xl.kind:GetText() == "Kolkar Marauders", "the creature's line is not written")
Eq(xl.name:GetText(), "Kolkar Booty Keys", "the heading")
Eq(xl.struck:GetText(), "expected 58", "the struck words")
Eq(xl.count:GetText(), "7", "the stack count")
Check(xl.icon:IsShown() and xl.plan.icon == ns.Hunts.HuntCard.ICON.size, "the icon at its full size")
local tag = xl.plan.tag
Check(tag.x >= xl.plan.struck.x + xl.plan.struck.w + S.tail[2] + Lucky.LUCKY.clear - 1e-9,
    "the tag lies on the struck words")
Eq(xl.plan.W - xl.plan.Wb, Lucky.FORMS.XL.over, "XL's tag hangs past the card")
Check(xl.tag.box and xl.tag.box[1] == tag.x and xl.tag.box[3] == tag.w, "the tag is not laid where planned")
Check(xl.pieces == #xl.strike - 1 and xl.pieces >= 3 and xl.pieces <= S.most, "the strike drawn: " .. xl.pieces)
-- On the card (points from its middle): from before the struck words to
-- short of the tag, inside the struck row.
do
    local st, plan = xl.plan.struck, xl.plan
    local x0, x1 = xl.strike[1].x + plan.Wb / 2, xl.strike[#xl.strike].x + plan.Wb / 2
    Check(x0 < st.x and x1 > st.x + st.w and x1 < plan.tag.x, "the strike's span on the card: " .. x0 .. ", " .. x1)
    for _, p in ipairs(xl.strike) do
        local y = p.y + plan.Hb / 2
        Check(y > plan.rowTop and y < plan.rowTop + plan.rowH, "the strike off the struck row: " .. y)
    end
end
local n = 0
for _, t in ipairs(xl.tag.ink) do if t:IsShown() then n = n + 1 end end
Check(n >= 4, "the underline is not drawn: " .. n)
Check(not xl.overfull, "XL overfull")

local l = New(KOLKAR, 200)
Eq(l.plan.form, "L", "a column of 200: L")
Eq(l.box[3], 200, "L fills its box")
Eq(l:Tag(), "dropped after just four", "L's tag")
Check(l.plan.tag.y + l.plan.tag.h > l.plan.Hb and l.plan.tag.x + l.plan.tag.w > l.plan.Wb,
    "under the struck words the tag does not hang past the card's foot and edge")
Eq(l.plan.Hb - l.plan.tag.y, Lucky.LUCKY.land, "the tag lies `land` on the card")
Check(l.plan.creature == nil and not l.kind:IsShown(), "L names the creature")
local m1 = New(KOLKAR, 176)
Eq(m1.plan.form, "M1", "176 in the mock: M1")
Eq(m1:Tag(), "dropped after four", "M1's tag")
local m2 = New(KOLKAR, 142)
Eq(m2.plan.form, "M2", "a row's box: M2")
Eq(m2:Tag(), "dropped/after four", "M2's tag")
local narrow = New(KOLKAR, 122)
Eq(narrow.plan.form, "M2", "the 122 px column: M2")
Eq(narrow.plan.icon, ns.Hunts.HuntCard.ICON.narrow, "the narrow icon under 140 px")
local tight = New(KOLKAR, 100)
Check(tight.overfull, "nothing fits 100 px, but the card is not overfull")
local one = New(HEZRUL, 200)
Check(not one.count:IsShown(), "one item has a stack count")
Eq(one.icon.recorded.calls.SetTexture[1], 134169, "the item's icon")

-- Steps: the creature's line, then the icon (the tag beside the words
-- tried again after XL); then none.
local s = New(KOLKAR, 260)
local h0, hb0 = s.box[4], s.plan.Hb
Check(s:Smaller(), "no first step")
s:Layout(10, 10, 260)
Check(s.plan.form == "XL" and s.plan.creature == nil, "the first step keeps the creature")
Check(s.plan.Hb < hb0 and s.box[4] <= h0, "the first step is not shorter: " .. hb0 .. ", " .. s.plan.Hb)
Check(s:Smaller(), "no second step")
s:Layout(10, 10, 260)
Check(not s.icon:IsShown() and s.plan.icon == 0, "the second step keeps the icon")
Check(not s:Smaller(), "a third step")
local m = New(KOLKAR, 176)
local hm = m.box[4]
Check(m:Smaller() and m.step == 2, "a step with nothing to give up is not passed over: " .. tostring(m.step))
m:Layout(10, 10, 176)
Eq(m.plan.form, "M2s", "without its icon at 176 the tag goes beside the words")
Check(m.box[4] < hm, "the step is not shorter: " .. hm .. ", " .. m.box[4])
m:SetHunt({ hunt = KOLKAR, mark = { 0, 0 } }, "lucky:test", now)
m:Layout(10, 10, 176)
Eq(m.plan.form, "M1", "a card set again is not whole again")

-- The leader leaves the slip nearest the star: the tag, where it is
-- nearer.
local cx, cy = l:Nearest(10 + 400, 10 + l.plan.tag.y + l.plan.tag.h / 2)
Check(cx > 10 + l.plan.Wb, "the leader leaves the card under the tag")

-- Under the mouse: the item's own tooltip over the icon, the card's over
-- the rest, the tag included.
GameTooltip.text, GameTooltip.link = nil, nil
one.item.scripts.OnEnter(one.item)
Eq(GameTooltip.link, "item:5025", "the icon's tooltip is not the item's")
one.item.scripts.OnLeave(one.item)
Check(one.tag.tip and one.tag.tip()[1][1] == ns.Hunts.Line(HEZRUL), "the tag has not the card's tooltip")

-- Laid flat: both slips square, no shadow under the icon; the tag still
-- over the card's right side, the strike still drawn.
ns.SetSetting("flatSheets", true)
local flat = New(KOLKAR, 260)
Check(flat.turn == 0 and flat.tag.turn == 0, "laid flat, a slip turns")
Check(not flat.iconShadow:IsShown(), "laid flat, the icon has a shadow")
Check(flat.plan.W > flat.plan.Wb and flat.tag.box[1] < flat.plan.Wb, "laid flat, the tag no longer overlaps")
Eq(flat.pieces, #flat.strike - 1, "laid flat, the strike")
ns.SetSetting("flatSheets", false)
local turned = New(KOLKAR, 260)
Check(turned.turn ~= 0 and turned.tag.turn ~= 0 and (turned.turn > 0) ~= (turned.tag.turn > 0),
    "the tag is not turned against the card")
local deg = math.abs(math.deg(turned.tag.turn))
Check(deg >= Lucky.TAG.turn[1] - 1e-6 and deg <= Lucky.TAG.turn[2] + 1e-6, "the tag's turn: " .. deg)

--------------------------------------------------------------------------
Section("S on a print: its wordings, the icon on the slip's right edge")

local Look = ns.UI.JourneyLook
local LAYOUT = Look.LAYOUT
local function Room(slot)
    local a, b = Lucky.PrintRoom(slot)
    return b - a, a
end
Eq(Room(LAYOUT.LF[1]), 136, "a snapshot with four photo corners")
Eq(Room(LAYOUT.FL[2]), 150, "a snapshot its corner come unstuck")
local tuckedRoom, tuckedLeft = Room(LAYOUT["F+L"][2])
Eq(tuckedRoom, 116, "the tucked print")
Eq(tuckedLeft, LAYOUT["F+L"][2].pc + 2, "it starts past the photo corner")

-- (In the mock "expected 58" is 66 px: with the icon "after four" wants
-- 174 px, "four" 138.)
Eq(Lucky.PrintPlan(KOLKAR, 174).form, "S", "room for \"after four\"")
local q = Lucky.PrintPlan(KOLKAR, 150)
Eq(q.form, "S-", "less room: the count alone")
Eq(q.W, 138, "S-'s width in the mock")
Eq(Lucky.PrintPlan(KOLKAR, 136), nil, "no room: not drawn")
Eq(Lucky.PrintPlan(KOLKAR, 116), nil, "the tucked print is too small")
local ic = q.icon
Check(math.abs((q.Wb - ic.x) / ic.box - 0.6) < 0.05, "60 % of the icon is not on the slip: "
    .. (q.Wb - ic.x) / ic.box)
Check(math.abs((q.W - q.Wb) / ic.box - 0.4) < 0.05, "40 % of it does not hang past: "
    .. (q.W - q.Wb) / ic.box)
Eq(ic.x + ic.box, q.W, "the icon is not S's right end")
Check(q.tag.x + q.tag.w < ic.x, "the tag runs into the icon")
Eq(ic.x - (q.tag.x + q.tag.w), Lucky.PRINT.gap, "the gap between the tag and the icon")
Check(q.tag.x >= q.struck.x + q.struck.w + S.tail[2], "the tag lies on the struck words")
Eq(q.tag.y + q.tag.h - q.Hb - Lucky.PRINT.bottom, 4, "the tag does not hang 4 px past the print's foot")
Check(ic.y >= 0 and ic.y + ic.box <= q.Hb, "the icon is taller than the slip")
-- One kill: "on the first" and "the first" are long.
Eq(Lucky.PrintPlan(HEZRUL, 150), nil, "one kill fits 150 px in the mock")
Eq(Lucky.PrintPlan(HEZRUL, 175).form, "S-", "one kill: the first")

--------------------------------------------------------------------------
Section("on the page: the margin's rank, which hunt, the caption")

local A = F.STRANGER.guid
local t0 = now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 10,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 10, levelTo = 11 })
j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
local CALL = { t = t0 + 900, mapID = 1412, x = 0.42, y = 0.58, level = 10, pct = 6, seconds = 42, npcID = 2955,
    foeLevel = 7, name = "Plainstrider", foes = 3 }
-- A slow hunt (bad luck, with the rates) and two lucky ones: the beaks
-- (2 for 20, 0.10) are luckier than the claw (1 for 9, 0.11).
local SLOW = { t = t0 + 1500, mapID = 1412, x = 0.38, y = 0.62, level = 10, questID = 1, title = "Break Sharptusk!",
    item = "Plainstrider Meat", need = 5, kills = 30, expected = 12, npcID = 2955, name = "Plainstrider" }
local BEAKS = { t = t0 + 1600, mapID = 1412, x = 0.41, y = 0.61, level = 10, questID = 2, title = "Beaks",
    item = "Plainstrider Beak", need = 2, kills = 2, expected = 20, npcID = 2956, name = "Adult Plainstrider" }
local CLAW = { t = t0 + 1700, mapID = 1412, x = 0.43, y = 0.59, level = 10, questID = 3, title = "Claws",
    item = "Sharptalon's Claw", need = 1, kills = 1, expected = 9, npcID = 3425, name = "Sharptalon" }
j.closeCalls, j.hunts = { CALL }, { SLOW, BEAKS, CLAW }
ns.Journey.Touch()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")

local function Open(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.open = i
            page.mode = "plates"
            ns.UI.RedrawJourneyPage()
            return e
        end
    end
end
local function Cards(pool)
    local list = {}
    for i = 1, page[pool].used do
        if page[pool][i]:IsShown() then list[#list + 1] = page[pool][i] end
    end
    return list
end
local function Caption() return page.captionPool[1]:GetText() end

local e = Open(10)
Eq(#e.fortunes, 2, "setup: the level's good luck")
plate = page.plates[1]
Eq(plate.counts.fortunes, 2, "the two stars")
Check(plate.lucky and plate.lucky.hunt == BEAKS, "the card is not for the luckiest hunt")
local cards = Cards("luckyPool")
Eq(#cards, 1, "one lucky card a plate")
local card = cards[1]
Eq(card.hunt, BEAKS, "the card's hunt")
Eq(page.luckyWritten, 1, "the page's count of lucky cards")
local ranks, kinds = {}, {}
for _, it in ipairs(plate.margin) do
    ranks[it.kind] = it.rank
    kinds[#kinds + 1] = it.kind
end
Check(ranks.foe and ranks.lucky and ranks.hunt and ranks.foe < ranks.lucky and ranks.lucky < ranks.hunt,
    "the lucky card is not after the close call and before the slow hunt: " .. table.concat(kinds, ","))
local link
for _, lk in ipairs(page.links) do if lk.strip == card then link = lk end end
Check(link and link.mark == plate.lucky.mark, "the card has no leader to its star")
local words = Caption()
Check(not words:find("Beak"), "the caption tells the card's hunt: " .. words)
Check(words:find("another lucky hunt"), "the caption does not count the other: " .. words)
Check(not words:find("Sharptalon"), "the counted hunt is told whole: " .. words)

-- Short of room the slow hunt's card goes first, then the lucky card,
-- before the close call's; a lucky card left off gives its words back.
local C = Look.CAPTION
local limit, offLimit = C.limit, C.offLimit
local luckyOff, order = false, true
for L = 528, 360, -2 do
    C.limit, C.offLimit = L, L
    ns.UI.RedrawJourneyPage()
    local lucky, slow, foe = #Cards("luckyPool") > 0, #Cards("huntPool") > 0, false
    for _, k in ipairs(Cards("killerPool")) do if k.foe then foe = true end end
    if slow and not lucky then order = false end
    if lucky and not foe then order = false end
    if not lucky then
        luckyOff = true
        Check(Caption():find("two lucky hunts"), "a left-off lucky card is not in the words at " .. L .. ": "
            .. Caption())
    end
end
Check(luckyOff, "the lucky card was never left off")
Check(order, "the cards were not left off slow hunt first, then good luck, then the close call")
C.limit, C.offLimit = limit, offLimit
ns.UI.RedrawJourneyPage()

-- Laid flat on the page: the card and its tag square, the tag still over.
ns.SetSetting("flatSheets", true)
ns.UI.RedrawJourneyPage()
card = Cards("luckyPool")[1]
Check(card and card.turn == 0 and card.tag.turn == 0 and card.plan.W > card.plan.Wb, "laid flat on the page")
ns.SetSetting("flatSheets", false)
ns.UI.RedrawJourneyPage()

--------------------------------------------------------------------------
Section("S on the page: a light plate's print, and the tucked print given up")

ns.Characters.Observe(A, { first = "Bram", surname = "Redfen", level = 11, faction = "Horde" })
ns.Diary.Add(A, { source = "test" })
-- Mulgore with Bram, then a first visit to Zephras Isle: FL, its print
-- tucked into the full plate's row (F+L) where nothing is lost by it.
local LUCK = { mapID = 2665, x = 0.5, y = 0.5, level = 12, questID = 9, title = "Isle Eggs", item = "Isle Egg",
    need = 2, kills = 2, expected = 20, npcID = 7, name = "Isle Raptor" }
local function Road(luck)
    local t5 = now - 50000
    ns.db.journey[SELF.guid] = nil
    j = ns.Journey.Begin(SELF.guid, t5, 12, 1412)
    j.hunts = {}
    Seg({ kind = "stop", from = t5, to = t5 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 30, seconds = 1800,
        levelFrom = 12, levelTo = 12 })
    ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t5 + 600, endedAt = t5 + 1500,
        participants = { [A] = { since = t5 + 600, last = t5 + 1500, seconds = 900, levelStart = 12 } } })
    Seg({ kind = "flight", from = t5 + 1800, to = t5 + 2100, mapID1 = 1412, x1 = 0.5, y1 = 0.5, mapID2 = 2665,
        x2 = 0.5, y2 = 0.5, levelFrom = 12, levelTo = 12 })
    Seg({ kind = "stop", from = t5 + 2100, to = t5 + 3900, mapID = 2665, x = 0.5, y = 0.5, r = 30, seconds = 1800,
        levelFrom = 12, levelTo = 12 })
    if luck then
        luck.t = t5 + 3000
        j.hunts = { luck }
    end
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(false)
    return Open(12)
end

e = Road(nil)
Eq(page.pattern, "F+L", "setup: without the luck the print is tucked in")
e = Road(LUCK)
Eq(e.pattern, "FL", "setup: a full plate and a light one")
Check(e.plates[2].light, "the luck made the print full")
Eq(page.pattern, "FL", "the tucked print kept where S will not go on it")
local onPrint = page.plates[2]
Check(onPrint.slot == LAYOUT.FL[2], "the print is not FL's snapshot")
Check(onPrint.print, "S is not drawn on the print")
Eq(onPrint.print.form, "S-", "S's wording on the snapshot, in the mock")
Eq(onPrint.print.hunt, LUCK, "S's hunt")
for _, it in ipairs(onPrint.margin or {}) do Check(it.kind ~= "lucky", "a light plate has a lucky card in its margin") end
Eq(#Cards("luckyPool"), 0, "a lucky card beside the print")
Eq(page.luckyWritten, 1, "the page does not count S")
local said = page.captionPool[2]:GetText()
Check(said:find("2" .. NB .. "Isle Eggs from Isle Raptors.", 1, true) and not said:find("expected"),
    "the print's caption: " .. said)

-- Where it lies, on the card from its top left: along the foot, on the
-- print but for the tag's foot, the icon clear of the tag and on the
-- slip's right edge.
local sp = onPrint.print.s
local slot = onPrint.slot
local function Span(list, k)
    local lo, hi = math.huge, -math.huge
    for _, pt in ipairs(list) do lo, hi = math.min(lo, pt[k]), math.max(hi, pt[k]) end
    return lo, hi
end
Eq(sp.left, slot.pc + 2, "S is not at the foot's left end")
for _, part in ipairs({ "label", "icon" }) do
    local x0, x1 = Span(sp[part], 1)
    local y0, y1 = Span(sp[part], 2)
    Check(x0 >= 0 and x1 <= slot.w and y0 >= 0 and y1 <= slot.h, "S's " .. part .. " leaves the print")
end
local _, tagFoot = Span(sp.tag, 2)
Check(tagFoot > slot.h and tagFoot <= slot.h + 5, "the tag does not hang just past the foot: " .. tagFoot)
local _, tagRight = Span(sp.tag, 1)
local iconLeft, iconRight = Span(sp.icon, 1)
local _, labelRight = Span(sp.label, 1)
Check(tagRight < iconLeft, "the tag and the icon collide")
Check(iconLeft < labelRight and labelRight < iconRight, "the icon is not on the slip's right edge")
local _, rightEnd = Lucky.PrintRoom(slot)
Check(iconRight <= rightEnd + 1, "S runs past its room")
Check(onPrint.print.box[2] + onPrint.print.box[4] < LAYOUT.FL[2].cap.y, "S runs into the caption under the print")
Check(onPrint.print.box[2] + onPrint.print.box[4] < 512, "S over the not-kept line")
-- Its leader up to the star, which lies well above it.
link = nil
for _, lk in ipairs(page.links) do if lk.strip == onPrint.print then link = lk end end
Check(onPrint.print.far and link and link.mark == onPrint.lucky.mark, "S has no leader to its star")
-- Under the mouse: the star's tooltip, and the item's over the icon.
GameTooltip.text = nil
onPrint.printHit.scripts.OnEnter(onPrint.printHit)
Eq(GameTooltip.text, ns.Hunts.Line(LUCK), "S's tooltip")
onPrint.printHit.scripts.OnLeave(onPrint.printHit)
Check(onPrint.printItem:IsShown(), "S's icon takes no mouse")

-- The star under S: S goes to the foot's right end.
local a0, b0 = Lucky.PrintRoom(slot)
local placed = Lucky.Print({ Place = function() end, Quad = function() return true end,
    Texture = function() return CreateFrame("Frame"):CreateTexture() end,
    Text = function() return ns.Style.Text(UIParent, ns.Style.FONT.small) end },
    { hunt = LUCK, x = a0 + 20, y = slot.h - 12 }, slot, "t", false)
Eq(placed.left, b0 - placed.plan.W, "the star under S, but S stays at the left")

-- Laid flat: S square on the print, the tag still hanging past the foot.
ns.SetSetting("flatSheets", true)
ns.UI.RedrawJourneyPage()
sp = page.plates[2].print and page.plates[2].print.s
Check(sp ~= nil, "laid flat, S is not drawn")
if sp then
    local y0, y1 = Span(sp.label, 2)
    Check(math.abs(sp.label[1][2] - sp.label[2][2]) < 1e-6, "laid flat, the slip is turned on the print")
    Check(math.abs(sp.tag[1][2] - sp.tag[2][2]) < 1e-6, "laid flat, the tag is turned")
    local _, foot = Span(sp.tag, 2)
    Check(foot > y1, "laid flat, the tag does not hang past the slip")
end
ns.SetSetting("flatSheets", false)
ns.UI.RedrawJourneyPage()

-- A lifted print with no luck that fits: the caption keeps the words.
e = Road({ mapID = 2665, x = 0.5, y = 0.5, level = 12, questID = 9, title = "Isle Eggs", item = "Isle Egg",
    need = 1, kills = 1, expected = 9, npcID = 7, name = "Isle Raptor Matriarch of the Northern Shore" })
Check(page.plates[2].print == nil, "S drawn where it does not fit")
Check(page.captionPool[2]:GetText():find("fewer than expected"), "the words left off with S not drawn: "
    .. page.captionPool[2]:GetText())
