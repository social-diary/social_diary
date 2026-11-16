-- Gathering in the book (Features/Gathering/): the mark's tooltip, told for
-- a node gathered once, again and again, and herbs and ore together; and on
-- Your Diary's plates the marks of /sd testdata's nodes, drawn through the
-- plate's kit.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Plate = ns.UI.JourneyPlate

local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local function Node(kind, name, t) return { kind = kind, name = name, t = t or now - 600 } end
local function Moment(node) return { kind = "gathered", t = node.t, node = node } end
local function Clock(t) return date("%H:%M", t) end

--------------------------------------------------------------------------
Section("the tooltip")

local title, lines = ns.Gathering.Tip(Node("ore", "Copper Vein"), now)
Eq(title, "Mined Copper Vein", "an ore's title")
Eq(lines[1], "Today at " .. Clock(now - 600), "when, once")
Eq(#lines, 1, "a lone node: only when")

title = ns.Gathering.Tip(Node("herb", "Peacebloom"), now)
Eq(title, "Picked Peacebloom", "a herb's title")
Eq(ns.Gathering.Tip(Node("ore", nil), now), "Mined some ore", "an ore with no name")
Eq(ns.Gathering.Tip(Node("herb", nil), now), "Picked an herb", "a herb with no name")

local spec = Plate.MARKS.gathered
Check(spec ~= nil, "the mark is not registered")
local function Of(...)
    local list = {}
    for _, node in ipairs({ ... }) do list[#list + 1] = Moment(node) end
    return list
end

-- A vein worked three times: one account, the name once, each time.
local copper = Of(Node("ore", "Copper Vein", now - 900), Node("ore", "Copper Vein", now - 600),
    Node("ore", "Copper Vein", now - 300))
title, lines = spec.tips(copper, now)
Eq(title, "Mined here 3 times", "three times at one vein")
Eq(lines[1], "Copper Vein", "its name once")
Eq(lines[2], "Today at " .. Clock(now - 900) .. ", " .. Clock(now - 600) .. " and " .. Clock(now - 300),
    "every time, the day once")
Eq(#lines, 2, "no line twice")

title = spec.tips(Of(Node("herb", "Peacebloom", now - 600), Node("herb", "Peacebloom", now - 300)), now)
Eq(title, "Picked here twice", "a herb twice")

title, lines = spec.tips(Of(Node("ore", "Tin Vein", now - 600), Node("herb", "Peacebloom", now - 300)), now)
Eq(title, "Gathered here twice", "a herb and ore on one spot")
Eq(lines[1], "Tin Vein and Peacebloom", "both names")

--------------------------------------------------------------------------
Section("which shape a mark wears")

Eq(spec.arg(Of(Node("ore", "Tin Vein"))), "ore", "an ore")
Eq(spec.arg(Of(Node("herb", "Peacebloom"))), "herb", "a herb")
Eq(spec.arg(Of(Node("herb", "Peacebloom"), Node("herb", "Silverleaf"), Node("ore", "Tin Vein"))), "herb",
    "more herbs than ore")
Eq(spec.arg(Of(Node("ore", "Tin Vein"), Node("ore", "Tin Vein"), Node("herb", "Peacebloom"))), "ore",
    "more ore than herbs")
Eq(spec.arg(Of(Node("herb", "Peacebloom"), Node("ore", "Tin Vein"))), "herb", "as many of each: the first")

--------------------------------------------------------------------------
Section("/sd testdata: nodes on the plates")

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
Eq(#ns.Gathering.List(j), 10, "setup: testdata's nodes")

-- Level 15: three copper veins in one spot are one mark, a tin vein another,
-- and a herb, a vein and a herb on one spot the third.
do
    Open(Entry(15))
    local p = page.plates[1]
    Eq(p.counts.gatherings, 3, "level 15's nodes: one mark for the vein worked three times")
end

-- Level 12: its three herbs. (The mock's map tree does not know the crag's
-- zone, so it places them on the route's spot, as it does the campfire: one
-- mark here, three in the client.)
do
    Open(Entry(12))
    local drawn = 0
    for _, p in ipairs(page.plates) do
        if p:IsShown() then drawn = drawn + (p.counts.gatherings or 0) end
    end
    Check(drawn >= 1, "level 12's herbs are not drawn")
end
