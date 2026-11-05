-- A stranger's glimpse (the stranger-glimpse proposal, 5 Nov 2026): what
-- the diary has pencilled in about someone not in it (Core/Glimpse.lua),
-- the loose print on their page (Core/PersonPlate.lua's Glimpse), the page
-- itself on the People page's right page (UI/Journal/Glimpse.lua), the
-- routing every name goes through (SelectPerson, ToPerson), the way on
-- (adding them inks the page where it lies), and the strips that lead
-- there. On the Numa fixture of tests/journey_ui.lua, with Numa left out
-- of the diary and a group join at t0 + 5000. Construction and logic only:
-- how it looks is for the client.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern) then return true end
    end
    return false
end

-- A tooltip list's first fields, joined with "|".
local function Joined(list)
    local parts = {}
    for _, line in ipairs(list or {}) do parts[#parts + 1] = line[1] end
    return table.concat(parts, "|")
end

--------------------------------------------------------------------------
-- The fixture: Your Diary's road of journey_ui.lua, Numa never added.

local t0 = now - 3 * DAY
local N = F.FRIEND.guid
ns.Characters.Observe(N, { first = "Numa", surname = "Pompilius", level = 12, class = "DRUID", race = "Tauren",
    faction = "Horde" })
ns.db.characters[N].firstSeen = t0 + 300
ns.db.characters[N].lastSeen = t0 + 9000
-- Their first raw sighting is the first sighting itself, at level 10.
ns.db.sightings[N] = { { time = t0 + 300, last = t0 + 600, level = 10, mapID = 1412, x = 0.40, y = 0.60,
    subZone = "Red Rocks", me = SELF.guid } }

ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg) j.segments[#j.segments + 1] = seg end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 11,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
j.levels[11] = { at = t0 + 2100, mapID = 1412, x = 0.50, y = 0.50 }
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 6000, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 3600,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 11, levelTo = 11 })
Seg({ kind = "flight", from = t0 + 6000, to = t0 + 6300, mapID1 = 1412, x1 = 0.60, y1 = 0.45,
    mapID2 = 1413, x2 = 0.50, y2 = 0.30, levelFrom = 11, levelTo = 11 })
Seg({ kind = "stop", from = t0 + 6300, to = t0 + 9900, mapID = 1413, x = 0.50, y = 0.30, r = 40, seconds = 3600,
    subZone = "The Crossroads", levelFrom = 11, levelTo = 12 })
ns.Journey.Touch()

-- What they did: grouped in Bloodhoof at t0 + 5000 (the hinge, 4,700 s on),
-- then a whisper, a trade, a word said and a whisper back, and an observed
-- level-up, which does not matter.
local rows = {
    { type = "group_join", time = t0 + 5000, me = SELF.guid, myLevel = 11, theirLevel = 11,
        zone = "Mulgore", mapID = 1412, x = 0.45, y = 0.55 },
    { type = "level_up", time = t0 + 5500, me = SELF.guid, context = { level = 12 } },
    { type = "whisper_in", time = t0 + 6500, me = SELF.guid, excerpt = "ty! inviting", zone = "The Barrens" },
    { type = "trade", time = t0 + 7000, me = SELF.guid, zone = "The Barrens", mapID = 1413, x = 0.5, y = 0.3,
        context = { gave = {}, got = {} } },
    { type = "say", time = t0 + 8000, me = SELF.guid, excerpt = "hello", zone = "The Barrens", mapID = 1413 },
    { type = "whisper_out", time = t0 + 9000, me = SELF.guid, excerpt = "see you", zone = "The Barrens" },
}
ns.db.interactions[N] = rows
ns.TouchSeen()

--------------------------------------------------------------------------
Section("Recap.Hinge: what made them matter, and Matters reads through it")

local R = ns.JourneyRecap
local ctx = { diary = ns.db.diary, interactions = ns.db.interactions, characters = ns.db.characters }
local hinge, at, how = R.Hinge(N, ctx)
Eq(hinge, rows[1], "the hinge is not the group join")
Eq(at, t0 + 5000, "the hinge's time")
Eq(how, "row", "the hinge is not a row")
Eq(R.Matters(N, ctx), at, "Matters does not read through Hinge")
local first = R.FirstSightingOf(N, now)
Check(first and first.t == t0 + 300 and first.subZone == "Red Rocks", "the plate's first sighting is not Numa's")

--------------------------------------------------------------------------
Section("Glimpse.Of: first seen, the hinge, after that, seen, until")

local G = ns.Glimpse
local g = G.Of(N, now)
Check(g ~= nil, "Numa has no glimpse")
Eq(g.name, "Numa Pompilius", "the glimpse's name")
Eq(g.first.t, t0 + 300, "first seen")
Eq(g.first.subZone, "Red Rocks", "first seen at Red Rocks")
Eq(g.first.mapID, 1412, "first seen in Mulgore")
Eq(g.first.level, 10, "your level at the first sighting")
Eq(g.first.theirLevel, 10, "their level at the first sighting (the first raw row)")
Eq(g.hinge, rows[1], "the glimpse's hinge is not the group join")
Eq(g.hinge.time - g.first.t, 4700, "the hinge is not 4,700 s on")
Eq(#g.after, 3, "after that: three lines at most")
Eq(g.after[1], rows[6], "after that is not newest first")
Eq(g.after[3], rows[4], "after that's third line")
Eq(g.more, 1, "the rest is not counted")
for _, row in ipairs(g.after) do Check(row.type ~= "level_up", "an observed row is in after that") end
Check(g.seen and g.seen.days == 1 and g.seen.since == t0 + 300, "the sightings' summary")
Eq(g["until"], t0 + 9000 + ns.BufferDays() * DAY, "until is not the latest row or sighting plus the buffer")
Eq(G.Until(N), g["until"], "Glimpse.Until")
-- A sighting later than every row moves it.
ns.db.sightings[N][2] = { time = t0 + 9500, last = t0 + 9800, mapID = 1413, me = SELF.guid }
Eq(G.Until(N), t0 + 9800 + ns.BufferDays() * DAY, "a later sighting does not move until")
table.remove(ns.db.sightings[N], 2)

-- Nobody's glimpse: your own character, a diary entry, no record.
Eq(G.Of(SELF.guid), nil, "your own character has a glimpse")
Eq(G.Of("Player-0000-NOBODY01"), nil, "no record has a glimpse")
local B = F.STRANGER.guid
ns.Characters.Observe(B, { first = "Bram", surname = "Redfen", level = 11, faction = "Horde" })
ns.Diary.Add(B, { source = "test" })
Eq(G.Of(B), nil, "a diary entry has a glimpse")
ns.Diary.Remove(B, "keep")
Check(G.Of(B) ~= nil, "someone removed with their history kept has no glimpse")
Eq(G.Of(B).hinge, nil, "a thin glimpse has a hinge")

-- Trimmed past MAX_ROWS from the front (Interactions.Add drops a
-- stranger's oldest): the hinge moves to the next row that matters.
local trimmed = table.remove(ns.db.interactions[N], 1)
local moved = G.Of(N)
Eq(moved.hinge, rows[2], "trimmed, the hinge did not move on")
Eq(moved.hinge.type, "whisper_in", "trimmed, the hinge is not the whisper")
table.insert(ns.db.interactions[N], 1, trimmed)
Eq(G.Of(N).hinge, rows[1], "the group join is not the hinge again")

--------------------------------------------------------------------------
Section("where adding them says they were met (decision 2)")

local where = G.Where(g)
Eq(where.zone, "Mulgore", "the hinge row's zone")
Eq(where.mapID, 1412, "the hinge row's map")
Eq(where.x, 0.45, "the hinge row's x")
-- A row with a zone but no spot: placed by the route at its time.
local loose = { type = "say", time = t0 + 7000, me = SELF.guid, zone = "The Barrens" }
local w2 = G.Where({ hinge = loose })
Eq(w2.zone, "The Barrens", "a zone-only row keeps its zone")
Eq(w2.mapID, 1413, "a zone-only row is not placed by the route")
Eq(w2.x, 0.50, "a zone-only row's x from the route")
-- Inside an instance: the zone alone, never the route.
local inside = G.Where({ hinge = { type = "say", time = t0 + 7000, me = SELF.guid, zone = "Wailing Caverns",
    instanceID = 43 } })
Eq(inside.zone, "Wailing Caverns", "an instance's zone")
Eq(inside.x, nil, "an instance row was placed")
-- No place at all, through a loading screen: the route; off it, nothing
-- (Diary.Add takes ns.Where()).
local w3 = G.Where({ hinge = { type = "say", time = t0 + 300, me = SELF.guid } })
Eq(w3.mapID, 1412, "a placeless row is not placed by the route")
Eq(G.Where({ hinge = { type = "say", time = now + DAY, me = SELF.guid } }), nil, "a row off every road was placed")
Eq(G.Where({}), nil, "no hinge has a place")

--------------------------------------------------------------------------
Section("PersonPlate.Glimpse: the print")

local pick = ns.PersonPlate.Glimpse(N, g)
Check(pick ~= nil, "Numa's glimpse has no print")
Eq(pick.mapID, 1412, "the print is not of Mulgore")
Eq(pick.x, 0.40, "the print is not centred on the first sighting")
Eq(pick.t, t0 + 300, "the print's time")
Check(pick.hinge and pick.hinge.mapID == 1412 and pick.hinge.x == 0.45, "the hinge is not among its marks")
Check(pick.road and pick.road.from == t0 + 300 and pick.road.to == t0 + 5000 and pick.road.me == SELF.guid,
    "the road's times")
Eq(ns.PersonPlate.Glimpse(N, g), pick, "the print is not cached")
-- First seen where no road was: no print.
local O = "Player-0000-OFFROAD1"
ns.Characters.Observe(O, { first = "Ferro", surname = "Vane", level = 20, faction = "Horde" })
ns.db.characters[O].firstSeen = now + 2 * DAY
Eq(ns.PersonPlate.GlimpsePick(O, G.Of(O)), nil, "a sighting off every road has a print")

--------------------------------------------------------------------------
Section("the words")

local PT = ns.UI.PersonText
local GW = PT.GLIMPSE
local h1, l1, s1 = PT.GlimpseFirst(g.first, now)
Eq(h1, "First seen", "note 1's heading")
Eq(l1, "Red Rocks, Mulgore", "note 1's line")
Check(s1:find("^on %d+ %a+ at %d%d:%d%d$"), "note 1's sub line: " .. tostring(s1))
local h2, l2, s2, long2 = PT.GlimpseHinge(g.hinge, g.first, true, now, N)
Eq(h2, "1 h 18 min later", "note 2's heading")
Eq(l2, "Grouped", "note 2's line is not the row's own words")
Eq(s2, "you at level 11, they at 11", "note 2's sub line on the print")
Eq(long2, nil, "on the print, no place joined")
local _, _, s3, long3 = PT.GlimpseHinge(rows[3], g.first, false, now, N)
Eq(s3, "you were in The Barrens", "a whisper off the print places only you")
Eq(long3, nil, "a whisper with no levels has levels joined")
local _, _, s4 = PT.GlimpseHinge(rows[4], g.first, false, now, N)
Eq(s4, "in The Barrens", "a trade off the print was not beside you")
Eq(PT.GlimpseAfter(t0, t0 + 30, now), "Moments later", "within a minute")
Eq(PT.GlimpseAfter(t0 + 5000, t0, now), "1 h 23 min earlier", "the hinge first is not mirrored")
Eq(PT.GlimpseAfter(ns.DayStart(t0) + 3600, ns.DayStart(t0) + DAY + 20 * 3600, now), "The next day", "the next day")
Eq(PT.GlimpseAfter(ns.DayStart(t0), ns.DayStart(t0) + 5 * DAY, now), "5 days later", "days later")
Eq(PT.GlimpseMore(6), "and 6 more", "the ledger's more")
Eq(PT.GlimpseSeen(g, now), "Not seen nearby yet.", "never seen nearby (no record.seen)")
local fname, _, fwords, flink = PT.GlimpseFoot(g, "Numa", "30 days", now)
Check(fname:find("^Pencilled in until %d+ %a+"), "the foot strip's name: " .. fname)
Eq(fwords, "Strangers are forgotten after 30 days. Once in your diary, all of this is kept for good.",
    "the foot strip's words")
Eq(flink, "Add Numa to your diary", "the foot strip's link")
Eq(Joined(PT.GlimpseTip("Numa Pompilius")), "Numa Pompilius|" .. GW.notYet .. "|" .. GW.click, "the strip's tooltip")

--------------------------------------------------------------------------
Section("Your Diary: a stranger's strip and hindsight line lead to the glimpse")

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local J = ns.UI.Journal
local book = _G.SocialDiaryJournalFrame
local glimpse = book.glimpse
Check(glimpse and glimpse.frame, "the People page has no glimpse")
Eq(ns.Diary.Count(), 0, "setup: the diary is not empty")
local page = ns.UI.JourneyPage()
local function RowFor(test)
    for _, row in ipairs(page.entries.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
    return nil
end
for i, e in ipairs(page.recap.entries) do
    if e.level == 10 then
        page.entries:SetOffset(page.rubrics[i] - 1)
        RowFor(function(item) return item.title and item.entry == i end):Click()
    end
end
-- The hindsight line: its words as they were, the name a link to her.
local later
for _, item in ipairs(page.items) do
    if item.later and item.later.guid == N then later = item end
end
Check(later ~= nil, "Numa's hindsight line is not on level 10")
Check(later.text:find("^You first saw Numa in Mulgore%."), "the hindsight line's words: " .. later.text)
Check(later.linked and later.linked:find("|Hsdperson:" .. N .. "|h", 1, true), "the hindsight name is not a link")
-- Her strip in the margin: plain ink, a link, the stranger's tooltip.
local numa
for i = 1, page.notePool.used do
    local note = page.notePool[i]
    if note:IsShown() and note.guid == N then numa = note end
end
Check(numa ~= nil, "Numa has no strip in the margin")
Check(numa.note.plain, "a stranger's margin strip is not in plain ink")
Eq(numa.name.recorded.calls.SetTextColor[1], ns.Style.INK[1], "a stranger's margin name is not in plain ink")
Eq(Joined(numa.tip()), "Numa Pompilius|" .. ns.UI.PersonText.GLIMPSE.notYet .. "|"
    .. ns.UI.PersonText.GLIMPSE.click, "a stranger's margin strip's tooltip")
numa.link.scripts.OnClick(numa.link)
Eq(J.glimpse, N, "her strip's click did not open her glimpse")
Eq(ns.UI.JournalView(), "people", "her strip's click did not turn to People")

--------------------------------------------------------------------------
Section("an empty diary: the welcome's left page, the glimpse on the right")

ns.UI.SetJournalView("journey")
Eq(J.glimpse, nil, "Your Diary kept the glimpse")
ns.UI.YourDiary.ToPerson(N)
Eq(ns.UI.JournalView(), "people", "Numa's name did not turn to People")
Eq(J.selected, nil, "a stranger is selected")
Eq(J.glimpse, N, "Numa's glimpse is not open")
Check(glimpse:IsShown(), "the glimpse is not shown")
Check(not book.profile:IsShown(), "the profile shows for a stranger")
Check(not book.emptyProfile:IsShown(), "Choose someone shows under the glimpse")
Check(book.welcome:IsShown(), "the welcome's left page is gone")
Check(not book.welcome.strip:IsShown(), "the welcome's right strip shows under the glimpse")

--------------------------------------------------------------------------
Section("the page, pencilled in")

Eq(glimpse.name:GetText(), "Numa Pompilius", "the name in pencil")
Eq(glimpse.nameFont, "pencilName", "a short name stepped down")
Check(glimpse.who:GetText():find("Level 12") and glimpse.who:GetText():find("Tauren"), "the who line: "
    .. glimpse.who:GetText())
Check(not glimpse.who:GetText():find("Horde"), "your own faction is on the who line")
Check(glimpse.plated, "the print is not laid")
Eq(glimpse.print.slot, ns.UI.PersonPlate.LOOSE, "the print is not lying loose")
Eq(glimpse.print.counts.corners, 0, "the loose print has photo corners")
Eq(glimpse.print.counts.glue, 0, "the loose print is glued")
Check(glimpse.print.counts.shadow > 0, "the loose print casts no shadow")
Eq(glimpse.print.leans, nil, "the loose print leans in")
Eq(glimpse.print.onClick, nil, "the loose print opens something")
Eq(glimpse.first.heading:GetText(), "FIRST SEEN", "note 1's heading in capitals")
Eq(glimpse.first.line:GetText(), "Red Rocks, Mulgore", "note 1's line")
Eq(glimpse.hinge.heading:GetText(), "1 H 18 MIN LATER", "note 2's heading")
Eq(glimpse.hinge.line:GetText(), "Grouped", "note 2's line")
Check(glimpse.print:MarkOf("first") ~= nil, "the first sighting has no mark on the print")
Check(glimpse.print.links.first.drawn > 0, "note 1 has no leader")
Check(glimpse.print:MarkOf("hinge") ~= nil and glimpse.print.links.hinge.drawn > 0, "note 2 has no leader")
Eq(glimpse.ledgerHeading:GetText(), "AFTER THAT", "the ledger's heading")
Check(glimpse.ledgerHeading:IsShown(), "the ledger is not shown")
Check(glimpse.rows[1].words:GetText():find("^You whispered"), "the ledger's first line: "
    .. glimpse.rows[1].words:GetText())
Eq(glimpse.rows[1].day:GetText(), glimpse.rows[1].day:GetText():upper(), "the ledger's day is not in capitals")
Check(glimpse.more:IsShown() and glimpse.more:GetText():find("^and %d more$"), "the ledger's more")
Check(glimpse.seen:GetText():find("%.$"), "the seen line is not a sentence")
local strip = glimpse.strip
Check(strip:IsShown(), "the foot strip is not taped on")
Check(strip.note.name:find("^Pencilled in until "), "the foot strip's name")
Eq(strip.note.foot.text, "Add Numa to your diary", "the foot strip's link")
Check(strip.note.foot.arrow, "the foot strip's link has no arrow")
Eq(strip.note.seed, "glimpse:" .. N, "the foot strip is not seeded per person")
local sx, sy, sw, sh = unpack(strip.box)
Check(sx + sw <= 452.5, "the foot strip runs past its right edge: " .. (sx + sw))
Check(sy >= 400, "the foot strip stands above the page's last line")
Check(sy + sh <= J.BOOK.RIGHT_H, "the foot strip runs off the page: " .. (sy + sh))
-- The hinge's line keeps all of itself in its tooltip.
Check(glimpse.hinge.hover:IsShown() and Joined(glimpse.hinge.hover.tip()) == "Grouped", "note 2's tooltip")
-- Nothing on it is a link but the strip's: the print and the notes open
-- nothing.
Check(not glimpse.print.clip:IsMouseClickEnabled(), "the print takes the mouse")

--------------------------------------------------------------------------
Section("the leaf and its life")

-- The leaf: a glimpse takes none (decision 1, the simplest that breaks
-- nothing): People's own, nobody's page given out for it.
Eq(J.Page("people").leaves(), nil, "a glimpse took a leaf")
ns.UI.SetJournalView("journey")
Eq(J.glimpse, nil, "turning to Your Diary kept the glimpse")
Check(not glimpse:IsShown() or not book.views.people:IsShown(), "the glimpse shows on another page")
ns.UI.SetJournalView("people")
Eq(J.glimpse, nil, "turning back reopened the glimpse")
Check(not glimpse:IsShown(), "the glimpse is still shown without J.glimpse")
ns.UI.SetJournalView("journey")
ns.UI.YourDiary.ToPerson(N)
Eq(J.glimpse, N, "the glimpse did not open again")
book:Hide()
Eq(J.glimpse, nil, "closing the book kept the glimpse")
ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
-- A GUID with no record turns nothing.
ns.UI.YourDiary.ToPerson("Player-0000-NOBODY01")
Eq(ns.UI.JournalView(), "journey", "a name with nothing behind it turned the book")
Eq(J.Route("Player-0000-NOBODY01"), nil, "a GUID with no record has a route")
Eq(J.Route(N), "glimpse", "a stranger's route")
Eq(ns.UI.SelectPerson("Player-0000-NOBODY01"), nil, "SelectPerson routed nobody")
-- ShowJournal on a stranger opens their glimpse.
ns.UI.ShowJournal(N)
Eq(J.glimpse, N, "ShowJournal on a stranger did not open their glimpse")
Eq(J.selected, nil, "ShowJournal selected a stranger")

--------------------------------------------------------------------------
Section("the way on: the foot link adds them, and the page becomes theirs")

strip.foot:Click()
local entry = ns.Diary.Get(N)
Check(entry ~= nil, "the foot link did not add Numa")
Eq(entry.addedContext.source, "journey", "the add's source")
Eq(entry.addedContext.zone, "Mulgore", "the add is not at the hinge's place")
Eq(entry.addedContext.mapID, 1412, "the add's map")
Eq(entry.addedContext.x, 0.45, "the add's x")
Eq(J.selected, N, "Numa is not selected once added")
Eq(J.glimpse, nil, "the glimpse stayed open once added")
Check(book.profile:IsShown(), "her page is not shown")
Check(not glimpse:IsShown(), "the glimpse still shows over her page")
Check(not book.welcome:IsShown(), "the welcome still shows with someone in the diary")
local listed = false
for _, row in ipairs(book.people.rows) do
    if row:IsShown() and row.item and row.item.guid == N then listed = row.selected:IsShown() end
end
Check(listed, "her row on the list is not selected")

--------------------------------------------------------------------------
Section("removed with the history kept: back to the glimpse (decision 3)")

ns.Diary.Remove(N, "keep")
ns.UI.RefreshJournal()
Eq(J.selected, nil, "removed, she is still selected")
Eq(J.glimpse, N, "removed, her page did not fall back to the glimpse")
Check(glimpse:IsShown() and not book.profile:IsShown(), "removed, the glimpse does not show")
-- Added through the entry sheet's Done (any path that fires
-- SD_DIARY_CHANGED) while the glimpse lies open: the same promotion.
ns.Diary.Add(N, { source = "test" })
ns.Fire("SD_DIARY_CHANGED")
Eq(J.selected, N, "added elsewhere, the glimpse did not become her page")
Check(book.profile:IsShown() and not glimpse:IsShown(), "added elsewhere, her page is not shown")
-- Deleted outright: nobody, "Choose someone" (the diary not empty).
ns.Characters.Observe(B, { first = "Bram", surname = "Redfen", level = 11, faction = "Horde" })
ns.Diary.Add(B, { source = "test" })
ns.Diary.Remove(N, "purge")
ns.UI.RefreshJournal()
Eq(J.glimpse, nil, "deleted, a glimpse is open")
Eq(G.Of(N), nil, "deleted, a glimpse is read")
Check(book.emptyProfile:IsShown(), "deleted, the page is not Choose someone")
ns.UI.YourDiary.ToPerson(N)
Check(book.emptyProfile:IsShown() and not glimpse:IsShown(), "a forgotten name opened something")

--------------------------------------------------------------------------
Section("the strips: plain ink to a glimpse, strong ink to a page")

local parent = CreateFrame("Frame", nil, UIParent)
local s1s = ns.UI.PaperStrip(parent)
s1s:SetNote({ name = "with Ferro", guid = O, plain = true, onClick = function() end })
local INK, STRONG = ns.Style.INK, ns.Style.INK_STRONG
Eq(s1s.name.recorded.calls.SetTextColor[1], INK[1], "a stranger's name is not in plain ink")
Check(s1s.link:IsMouseClickEnabled(), "a stranger's strip does not take the mouse")
s1s.link.scripts.OnEnter(s1s.link)
Check(s1s.underline:IsShown(), "a stranger's strip does not underline under the mouse")
s1s.link.scripts.OnLeave(s1s.link)
local s2s = ns.UI.PaperStrip(parent)
s2s:SetNote({ name = "with Bram", guid = B, onClick = function() end })
Eq(s2s.name.recorded.calls.SetTextColor[1], STRONG[1], "a diary person's name is not in strong ink")

-- The witness card's line for a stranger, and for a diary person.
local card = ns.Witnesses.Card.New(parent)
local w = { kind = "helped", type = "tried_to_help", guid = O, t = now - 600, others = 0,
    creature = { npcID = 448, name = "Hogger", rank = "rare" }, mark = { 100, 100 }, death = { t = now - 600 } }
card:SetWitness(w, "test", now, O, function() end)
local said = card.tip()
Eq(said[#said][1], GW.click, "the witness card's line for a stranger")
w.guid = B
card:SetWitness(w, "test", now, B, function() end)
said = card.tip()
Eq(said[#said][1], "Click to open their page in the diary", "the witness card's line for a diary person")

--------------------------------------------------------------------------
Section("Flat paper only: the print straight and unshadowed, the strip square")

ns.SetSetting("flatSheets", true)
ns.UI.SetJournalView("journey")
ns.UI.YourDiary.ToPerson(O)
Eq(J.glimpse, O, "Ferro's glimpse did not open")
Check(not glimpse.plated, "a glimpse off every road has a print")
Check(glimpse.first.heading:IsShown(), "a thin glimpse's first note is gone")
Check(strip:IsShown() and strip.flat, "laid flat, the strip is not flat")
ns.UI.YourDiary.ToPerson(nil)
ns.Characters.Observe(N, { first = "Numa", surname = "Pompilius", level = 12, class = "DRUID", faction = "Horde" })
ns.db.characters[N].firstSeen = t0 + 300
ns.db.interactions[N] = { rows[1] }
ns.TouchSeen()
ns.UI.SetJournalView("journey")
ns.UI.YourDiary.ToPerson(N)
Eq(J.glimpse, N, "Numa's glimpse did not open laid flat")
Check(glimpse.plated, "laid flat, the print is gone")
Eq(glimpse.print.turn, 0, "laid flat, the print is turned")
Eq(glimpse.print.counts.shadow, 0, "laid flat, the print casts a shadow")
Eq(glimpse.ledgerHeading:IsShown(), false, "nothing after the hinge, and a ledger")
ns.SetSetting("flatSheets", false)
