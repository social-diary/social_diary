-- Fishing in the book (Features/Fishing/): the mark's tooltip, told for a
-- single catch, a shore fished again and again, and a long run of different
-- fish; and on Your Diary's plates the marks of /sd testdata's catches,
-- drawn through the plate's kit.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Plate = ns.UI.JourneyPlate

local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local function Catch(name, t) return { name = name, t = t or now - 600 } end
local function Moment(c) return { kind = "fished", t = c.t, catch = c } end
local function Of(...)
    local list = {}
    for _, c in ipairs({ ... }) do list[#list + 1] = Moment(c) end
    return list
end
local function Clock(t) return date("%H:%M", t) end

--------------------------------------------------------------------------
Section("the tooltip")

local title, lines = ns.Fishing.Tip(Catch("Raw Spotted Yellowtail"), now)
Eq(title, "Fished up Raw Spotted Yellowtail", "a catch's title")
Eq(lines[1], "Today at " .. Clock(now - 600), "when, once")
Eq(#lines, 1, "a lone catch: only when")
Eq(ns.Fishing.Tip(Catch(nil), now), "Fished something up", "a catch with no item")

local spec = Plate.MARKS.fished
Check(spec ~= nil, "the mark is not registered")

-- A shore fished three times: one account, each name once, each time.
title, lines = spec.tips(Of(Catch("Raw Spotted Yellowtail", now - 900), Catch("Raw Spotted Yellowtail", now - 600),
    Catch("Tangled Fishing Line", now - 300)), now)
Eq(title, "Fished here 3 times", "three catches")
Eq(lines[1], "Raw Spotted Yellowtail and Tangled Fishing Line", "each name once")
Eq(lines[2], "Today at " .. Clock(now - 900) .. ", " .. Clock(now - 600) .. " and " .. Clock(now - 300),
    "every time, the day once")
Eq(#lines, 2, "no line twice")

title = spec.tips(Of(Catch("Raw Spotted Yellowtail", now - 600), Catch("Raw Spotted Yellowtail", now - 300)), now)
Eq(title, "Fished here twice", "twice")

-- Many different fish: four named, then how many more.
title, lines = spec.tips(Of(Catch("A", now - 600), Catch("B", now - 500), Catch("C", now - 400), Catch("D", now - 300),
    Catch("E", now - 200), Catch("F", now - 100)), now)
Eq(title, "Fished here 6 times", "six catches")
Eq(lines[1], "A, B, C and 3 more", "four names, the last saying how many more")

--------------------------------------------------------------------------
Section("/sd testdata: catches on the plates")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function Open(i)
    page.open = i
    page.mode = "plates"
    ns.UI.RedrawJourneyPage()
end
local function Entry(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then return i, e end
    end
end

local j = ns.Journey.For(ns.ownGUID)
Eq(#ns.Fishing.List(j), 5, "setup: testdata's catches")

-- Level 15: four catches on one shore are one mark, one more from another
-- bank a second.
do
    Open(Entry(15))
    local p = page.plates[1]
    Eq(p.counts.catches, 2, "level 15's catches: one mark for the shore, one for the other bank")
end
