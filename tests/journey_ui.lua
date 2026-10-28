-- Your Diary's pages (JRN-11 to JRN-16, JRN-21 to JRN-23): the start page
-- with its entries, faces and zone rows, the empty page, and the map plates
-- glued into the right page, close-ups and a zone's full page.
-- Construction and logic only: how it looks is for the client.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF

mock.now = 1791000000
local now = mock.now
-- Levelling, below the cap: the entries are one per level.
SELF.level = 12
mock.SetUnit("player", SELF)

-- The shown hover squares of a plate, and what their tooltips say: the
-- title through GameTooltip, and title and lines joined with "|".
local function Tooltips(plate)
    local said = {}
    for i = 1, plate.hover.used do
        local button = plate.hover[i]
        GameTooltip.text = nil
        button.scripts.OnEnter(button)
        if GameTooltip.text then said[#said + 1] = GameTooltip.text end
        button.scripts.OnLeave(button)
    end
    return said
end

local function Tips(plate)
    local said = {}
    for i = 1, plate.hover.used do
        local list = plate.hover[i].tip and plate.hover[i].tip()
        if list then
            local parts = {}
            for _, line in ipairs(list) do parts[#parts + 1] = line[1] end
            said[#said + 1] = table.concat(parts, "|")
        end
    end
    return said
end

local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern) then return true end
    end
    return false
end

--------------------------------------------------------------------------
Section("the first ribbon, and the book opening on it (JRN-16)")

ns.UI.ShowJournal()
local J = _G.SocialDiaryJournalFrame
Eq(ns.UI.JournalView(), "journey", "the book does not open on Your Diary once the front matter is read")
Check(J.views.journey:IsShown() and not J.views.people:IsShown(), "Your Diary's page is not the one shown")
Check(J.ribbons.journey.active, "the green ribbon is not marked")
local order = {}
for _, key in ipairs({ "journey", "people", "nearby", "settings" }) do
    order[#order + 1] = J.ribbons[key].recorded.points[1].args[3]
end
for i = 2, #order do Check(order[i] > order[i - 1], "the ribbons are not in the order Your Diary, People, Nearby, Settings") end
Eq(J.ribbons.journey.label, "Your Diary", "the first ribbon's name")
local page = ns.UI.JourneyPage()
Check(page and page.parent == J.views.journey, "the page was not built into its container")
-- JRN-15: the zone index is gone; the zones are rows under the levels.
Check(page.zones == nil and page.indexHeading == nil and ns.UI.ZoneSheet == nil,
    "the zone index or the zone sheet is still built")

--------------------------------------------------------------------------
Section("no road yet: the empty page")

ns.db.journey[SELF.guid] = nil
ns.UI.RefreshJourneyPage()
Eq(page.state, "on", "no record with the setting on is not the fresh page")
Check(page.empty:IsShown() and not page.entries:IsShown() and not page.right:IsShown(),
    "the empty page does not stand in for the entries and the plates")
Check(page.empty.heading.text:GetText():find("STARTS HERE"), "the fresh page does not say the road starts here")
Check(page.empty.why:GetText():find("who you were with"), "the fresh page does not say what will appear")
Check(not page.empty.keep:IsShown(), "the keep link shows with the setting on")
Eq(page.name:GetText(), "ULVERSTON NYE", "the character's name is not at the top")
Check(page.who:GetText():find("Level 12") and page.who:GetText():find("Tauren Warrior"),
    "who they are and their level is not under the name")

-- The setting off: said honestly, with the way back.
ns.SetSetting("keepRoute", false)
ns.UI.RefreshJourneyPage()
Eq(page.state, "off", "capture off is not the off page")
Check(page.empty.heading.text:GetText():find("NOT KEEPING"), "the off page does not say the road is not kept")
Check(page.empty.keep:IsShown(), "the off page has no way to keep the road")
page.empty.keep:Click()
Eq(ns.db.settings.keepRoute, true, "Keep my own route did not switch the setting on")
Eq(page.state, "on", "the page did not follow the setting back on")
local begun = ns.Journey.Mine()
Check(begun and #begun.segments == 0, "switched on, the road did not begin empty")
Check(page.empty:IsShown(), "a record with no segments is not still the empty page")

--------------------------------------------------------------------------
Section("a road: entries, faces, zone rows, hindsight (JRN-11, JRN-13, JRN-15, JRN-22, JRN-23)")

local A = F.STRANGER.guid
ns.Characters.Observe(A, { first = "Bram", surname = "Redfen", level = 11, faction = "Horde" })
ns.Diary.Add(A, { source = "test" })

mock.mapNames[2665] = "Zephras Isle"
local t0 = now - 3 * DAY

-- Numa was first seen at Red Rocks at level 10 and only put in the diary
-- an hour and a half later: a first sighting in hindsight (JRN-23).
local N = F.FRIEND.guid
ns.Characters.Observe(N, { first = "Numa", surname = "Pompilius", level = 10, faction = "Horde" })
ns.Diary.Add(N, { source = "test" })
ns.db.characters[N].firstSeen = t0 + 300
ns.db.diary[N].addedAt = t0 + 5000

ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 11,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
j.levels[11] = { at = t0 + 2100, mapID = 1412, x = 0.50, y = 0.50 }
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 11, levelTo = 11 })
Seg({ kind = "flight", from = t0 + 4200, to = t0 + 4500, mapID1 = 1412, x1 = 0.60, y1 = 0.45,
    mapID2 = 1413, x2 = 0.50, y2 = 0.30, levelFrom = 11, levelTo = 11 })
Seg({ kind = "stop", from = t0 + 4500, to = t0 + 6000, mapID = 1413, x = 0.50, y = 0.30, r = 40, seconds = 1500,
    subZone = "The Crossroads", levelFrom = 11, levelTo = 11 })
Seg({ kind = "dungeon", from = t0 + 6000, to = t0 + 8000, mapID = 1413, x = 0.40, y = 0.70,
    name = "Wailing Caverns", instanceID = 43, instanceType = "party", seconds = 2000, levelFrom = 11, levelTo = 12 })
j.levels[12] = { at = t0 + 7000 }
Seg({ kind = "road", from = t0 + 8000, to = t0 + 8600, mapID = 1413, levelFrom = 12, levelTo = 12,
    pts = { 0.40, 0.70, 0.42, 0.66, 0.45, 0.60 } })
Seg({ kind = "stop", from = t0 + 9000, to = t0 + 9900, mapID = 2665, x = 0.5, y = 0.5, r = 20, seconds = 900,
    levelFrom = 12, levelTo = 12 })
ns.Journey.Fight(j, "won", nil, t0 + 1000, { mapID = 1412, x = 0.41, y = 0.61 })
ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t0 + 600, endedAt = t0 + 1500,
    participants = { [A] = { since = t0 + 600, last = t0 + 1500, seconds = 900, levelStart = 10 } } })
ns.Journey.Touch()

ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
Eq(page.state, "entries", "a road with segments is not shown as entries")
Check(page.entries:IsShown() and page.right:IsShown() and not page.empty:IsShown(), "the road's pages are not shown")

local function Titles()
    local titles = {}
    for _, item in ipairs(page.items) do
        if item.title then titles[#titles + 1] = item.title .. (item.aside and (" / " .. item.aside) or "") end
    end
    return titles
end
local function Texts()
    local texts = {}
    for _, item in ipairs(page.items) do
        if item.text then texts[#texts + 1] = item.text end
    end
    return texts
end
-- The shown row of the list for an item matching `test`.
local function RowFor(test)
    for _, row in ipairs(page.entries.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
    return nil
end

local titles = Titles()
Eq(titles[1], "LEVEL 10", "the oldest entry is not first")
Eq(titles[#titles], "LEVEL 12 / so far", "the level being played is not last, marked so far")
Eq(#titles, 3, "one entry per level")
for _, item in ipairs(page.items) do Check(item.height and item.height > 0, "an item has no height") end
Check(page.items[1].text and page.items[1].text:find("^This diary began at level 10"),
    "the prologue does not open the page")
Eq(page.open, 3, "the page did not fall open at the newest level")
Eq(page.entries.offset, math.min(page.rubrics[3] - 1, page.entries.bar.max), "the page did not open at the newest entry")
Check(page.entries.rows[1]:IsShown(), "no entry rows shown")
Check(not page.off:IsShown(), "the not-kept line shows while it is kept")

-- One level open at a time: only its prose is on the page.
local texts = Texts()
Check(not Any(texts, "With .*Bram Redfen"), "a closed level's prose is on the page")
Check(Any(texts, "Wailing Caverns") or Any(texts, "Zephras"), "the open level's prose is not on the page")

-- The list starts at a rubric: what shows under the character is never
-- another level's paragraphs or zone rows without their rubric over them.
local function StartsAtRubric()
    for _, row in ipairs(page.entries.rows) do
        local item = row:IsShown() and row.item
        if item then
            if item.title then return true end
            if item.zone or (item.text and item ~= page.items[1]) then return false end
        end
    end
    return true
end
Check(StartsAtRubric(), "the page opens on rows that have no rubric over them")

-- Under the open level only, its ledger of zones with their time
-- (JRN-15); a closed level is its rubric alone (journey-revamp-plan §3).
local function Zones()
    local zones = {}
    for _, item in ipairs(page.items) do
        if item.zone then
            zones[item.entry] = zones[item.entry] or {}
            table.insert(zones[item.entry], item.mapID or false)
        end
    end
    return zones
end
local zones = Zones()
Check(zones[1] == nil and zones[2] == nil, "a closed level shows its zone rows")
Check(zones[3] and #zones[3] >= 2, "level 12's zones")
-- The ledger: small type, dot leaders out to the time, the dungeon's
-- doorway only on a dungeon's row.
do
    local zrow = RowFor(function(item) return item.zone ~= nil and not item.zone.dungeon end)
    Check(zrow, "no zone row on the page")
    Eq(zrow.zone.recorded.calls.SetFontObject[1], ns.Style.FONT.small, "a zone row is not in small type")
    Check(zrow.dots:IsShown() and zrow.dots:GetText():find("^[ .]+$") and #zrow.dots:GetText() > 4,
        "a zone row has no dot leaders: " .. tostring(zrow.dots:GetText()))
    -- The leaders fill the row between the name and the time, no more.
    local rowW = ns.UI.Journal.BOOK.LEFT_W - ns.UI.SCROLLBAR_WIDTH - 2
    local used = zrow.zone:GetUnboundedStringWidth() + zrow.dots:GetUnboundedStringWidth()
        + zrow.time:GetUnboundedStringWidth()
    Check(used <= rowW - 13, "the dot leaders run past the row: " .. used .. " of " .. rowW)
    Check(not zrow.door[1]:IsShown(), "a zone's row has a dungeon's doorway")
    local drow = RowFor(function(item) return item.zone ~= nil and item.zone.dungeon ~= nil end)
    Check(drow and drow.zone:GetText() == "Wailing Caverns", "no dungeon row in level 12's ledger")
    Check(drow.door[1]:IsShown() and drow.door[2]:IsShown(), "a dungeon's row has no doorway in the margin")
    -- The doorway is the plates' arch, in ink: a square body, a round head
    -- as wide sitting in its top, never two posts and a lintel ("⊓").
    local body, head = drow.door[1], drow.door[2]
    Eq(#drow.door, 2, "the doorway is not a body and a head")
    local bw, bh = body.recorded.width, body.recorded.height
    local hw, hh = head.recorded.width, head.recorded.height
    Eq(hw, hh, "the doorway's head is not round")
    Check(math.abs(bw - hw) < 1e-6, "the doorway's head is not as wide as its body")
    Check(head.recorded.calls.SetVertexColor or head.recorded.calls.SetColorTexture, "the doorway's head has no ink")
    local by, hy = body.recorded.points[1].args[4], head.recorded.points[1].args[4]
    Check(hy > by and hy - hh / 2 < by + bh / 2 and hy + hh / 2 > by + bh / 2,
        "the doorway's head does not sit on its body's top: an arch")
    Check(math.max(by + bh / 2, hy + hh / 2) - math.min(by - bh / 2, hy - hh / 2) <= 11,
        "the doorway stands taller than the ledger's 11 pt line")
    local r, g, b = unpack(body.recorded.calls.SetColorTexture, 1, 3)
    Check(r < 0.3 and g < 0.3, "the doorway is not in ink")
    -- A zone's row under the mouse is marked as a reader marks a line: its
    -- name inked darker and a pencil line under it, never a filled box.
    local boxes = 0
    for _, w in ipairs(T.mock.frames) do
        if w.parent == zrow and w.frameType == "Texture" and w.recorded.layer == "HIGHLIGHT" then boxes = boxes + 1 end
    end
    Eq(boxes, 0, "a zone's row still lights a box under the mouse")
    Check(zrow.item.mapID and not zrow.underline:IsShown(), "a zone's row is marked before the mouse is on it")
    zrow.scripts.OnEnter(zrow)
    Check(zrow.underline:IsShown() and zrow.lip:IsShown(), "a zone's row under the mouse is not underlined")
    local uw = zrow.underline.recorded.width
    Eq(uw, zrow.zone:GetUnboundedStringWidth(), "the pencil line is not as long as the name")
    Check(zrow.underline.recorded.height <= 1.5, "the pencil line is a bar, not a line")
    local u = zrow.underline.recorded.calls.SetColorTexture
    Check(u[4] < 1 and math.abs(u[1] - ns.Style.GRAPHITE[1]) < 1e-6, "the line is not in pencil")
    Eq(zrow.zone.recorded.calls.SetTextColor[1], ns.Style.INK_STRONG[1], "the name is not inked darker")
    -- The light on the groove lies under the line (lit from the top left).
    Eq(zrow.lip.recorded.points[1].args[1], zrow.underline, "the light is not under the pencil line")
    zrow.scripts.OnLeave(zrow)
    Check(not zrow.underline:IsShown(), "the mark stays after the mouse left")
    Eq(zrow.zone.recorded.calls.SetTextColor[1], ns.Style.INK[1], "the name stays dark after the mouse left")
end

-- Closed rubrics are set close, a contents list; the open entry stands
-- apart (10 Oct, in the client: six closed ones filled half the page).
do
    local pitch, open
    for k, item in ipairs(page.items) do
        if item.title and not item.open and page.items[k + 1] and page.items[k + 1].title
            and not page.items[k + 1].open then
            pitch = item.height
        end
        if item.title and item.open then open = page.items[k - 1] end
    end
    Check(pitch and pitch <= 20, "closed rubrics are not set close: " .. tostring(pitch))
    Check(open and not open.title and open.height >= 10, "the open entry does not stand apart from the rubric above")
end

-- Level 10 opened by its rubric: its prose, a name a link, the faces.
local rubric = RowFor(function(item) return item.title == "LEVEL 10" end)
if not rubric then
    page.entries:SetOffset(0)
    rubric = RowFor(function(item) return item.title == "LEVEL 10" end)
end
Check(rubric, "level 10's rubric is not on the page")
rubric:Click()
Eq(page.open, 1, "clicking a rubric did not open its level")
Eq(page.mode, "plates", "an opened level does not show its plates")
texts = Texts()
Check(Any(texts, "With |Hsdperson:" .. A:gsub("%p", "%%%0") .. "|h"), "a name in the prose is not a link to their page")
Check(Any(texts, "Beat") or Any(texts, "Won"), "the fight is not in the entry")
Check(Any(texts, "^You first saw Numa in Mulgore%. You'd meet again at level 11%.$"),
    "the first sighting is not written in, in hindsight")
local later
for _, item in ipairs(page.items) do
    if item.later then later = item end
end
Eq(later and later.font, ns.Style.FONT.noteWritten, "the hindsight line is not in the diary's hand")

-- The player's own note: its own paragraph, quoted, in their hand (the
-- handwriting font), never "You wrote:" in the diary's type.
do
    local e1 = page.recap.entries[1]
    local kept = e1.notes
    e1.notes = { { text = "Bram knows every Kolkar camp." }, { text = "And the wells." } }
    RowFor(function(item) return item.title == "LEVEL 10" end):Click()
    local quote, count
    for k, item in ipairs(page.items) do
        if item.note then quote, count = item, page.items[k + 1] end
    end
    Eq(quote and quote.font, ns.Style.FONT.noteWritten, "the note is not in the player's hand")
    Eq(quote and quote.text, "\226\128\156Bram knows every Kolkar camp.\226\128\157", "the note as written")
    Eq(count and count.text, "And one more note.", "the count of more notes")
    Eq(count and count.font, ns.Style.FONT.small, "the count of more notes is not the diary's small type")
    Check(not Any(Texts(), "You wrote"), "the note is still introduced by the diary")
    e1.notes = kept
    RowFor(function(item) return item.title == "LEVEL 10" end):Click()
end
-- Paragraphs are set apart: the gap under one is well over the leading.
do
    local prose = RowFor(function(item) return item.text and item.font == ns.Style.FONT.body end)
    Check(prose and prose.item.height - 14 >= 8, "a paragraph's gap is too small to read as one")
end

rubric = RowFor(function(item) return item.title == "LEVEL 10" end)
local faces = rubric.item.faces
Eq(#faces, 2, "level 10's faces: Bram, and Numa first seen")
Check(rubric.faces[1] and rubric.faces[1]:IsShown() and rubric.faces[2]:IsShown(), "the faces are not drawn")
GameTooltip.text = nil
local faceOf = rubric.faces[1].guid == A and rubric.faces[1] or rubric.faces[2]
faceOf.scripts.OnEnter(faceOf)
Eq(GameTooltip.text, "Bram Redfen  \194\183  15 min together", "a face's tooltip")
Check(not faceOf.ring:IsShown(), "a face not tagged foe has a rival's ring")

-- A name in the prose opens their page in People.
local prose = RowFor(function(item) return item.text and item.text:find("|Hsdperson:") end)
Check(prose and prose.scripts.OnHyperlinkClick, "the prose row takes no link clicks")
prose.scripts.OnHyperlinkClick(prose, "sdperson:" .. A)
Eq(ns.UI.JournalView(), "people", "a name link did not turn to People")
Eq(ns.UI.Journal.selected, A, "a name link did not open their page")
J.ribbons.journey:Click()
Eq(ns.UI.JournalView(), "journey", "back on Your Diary")
Eq(page.open, 3, "turning back to Your Diary did not open the newest level")

-- Unchanged, a refresh while open keeps the reader's place and rebuilds
-- nothing.
local items = page.items
page.entries:SetOffset(0)
ns.Fire("SD_DIARY_CHANGED")
Check(page.items == items, "an unchanged recap was rebuilt")
Eq(page.entries.offset, 0, "a refresh while open lost the reader's place")
Eq(page.open, 3, "setup: level 12 is open")
Check(StartsAtRubric(), "turned back to, the page opens on rows without their rubric")

-- The scrollbar is the book's: a pencilled line and a leather thumb tab
-- on a clear thumb the bar's whole width, lit and shadowed, and laid flat
-- with Flat paper only.
do
    local bar, parts = page.entries.bar, page.entries.barParts
    local SB = ns.UI.SCROLLBAR
    Check(parts and parts.body and parts.cast and parts.line, "the scrollbar has no tab or line")
    Eq(page.entries.thumb.recorded.calls.SetColorTexture[4], 0, "the thumb's hold on the mouse is not clear")
    Eq(page.entries.thumb.recorded.width, ns.UI.SCROLLBAR_WIDTH, "the thumb is not the bar's width to grab")
    Eq(parts.body.recorded.width, SB.tab.w, "the tab's width")
    Eq(parts.line.recorded.width, SB.track.width, "the pencil line's width")
    Check(parts.cast:IsShown() and parts.lit:IsShown(), "the tab is not lit or casts no shadow")
    local quiet = parts.lit.recorded.calls.SetColorTexture[4]
    bar.scripts.OnEnter(bar)
    Check(parts.lit.recorded.calls.SetColorTexture[4] > quiet, "the tab does not answer the mouse")
    bar.scripts.OnLeave(bar)
    ns.SetSetting("flatSheets", true)
    bar.scripts.OnShow(bar)
    Check(not parts.cast:IsShown() and not parts.lit:IsShown() and not parts.grooves[1][1]:IsShown(),
        "laid flat, the tab still has its shadow, light or grooves")
    ns.SetSetting("flatSheets", false)
    bar.scripts.OnShow(bar)
    Check(parts.cast:IsShown(), "the tab's shadow did not come back")
end

--------------------------------------------------------------------------
Section("the open level's plates (JRN-21, JRN-22)")

local function Open(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.entries:SetOffset(page.rubrics[i] - 1)
            local row = RowFor(function(item) return item.title and item.entry == i end)
            row:Click()
            return page.recap.entries[i]
        end
    end
end

local e10 = Open(10)
Eq(page.layout, 1, "a level spent on one hillside is not one plate")
local plate = page.plates[1]
Check(plate:IsShown() and not (page.plates[2] and page.plates[2]:IsShown()), "the one plate is not alone")
Eq(plate.mapID, 1412, "level 10's plate is not of Mulgore")
-- Its caption is short (a heading and a line), so it is over the plate,
-- and the plate in the one plate's shorter slot under it (TOP).
local ONE = ns.UI.JourneyLook.LAYOUT[1][1]
Check(plate.captionOver, "a short caption is not over the one plate")
Check(plate.slot == ONE.top, "the one plate under its caption is not in its slot")
Eq(plate.slot.w .. "x" .. plate.slot.h, "444x343", "the one plate under its caption is not its size")
Check(math.abs(plate.turn - (-math.rad(-1.2))) < 1e-9, "the plate does not lie at its slot's turn")
Eq(#e10.plates, 1, "the plates are not kept on the entry")
-- At the art's own size: one pixel of the plate a pixel of the art.
local W = plate.window
Check(math.abs((W[3] - W[1]) * 1002 - (444 - 20)) < 1e-6 and math.abs((W[4] - W[2]) * 668 - (343 - 20)) < 1e-6,
    "a close-up is not at the art's own size")
Check(W[1] <= 0.40 and W[3] >= 0.41 and W[2] <= 0.60 and W[4] >= 0.61, "the window does not hold its moments")
Eq(plate.counts.meetings, 2, "the session and the fight are not marked")
Eq(plate.counts.firsts, 1, "the first sighting has no lozenge")
Eq(plate.counts.stops, 1, "only the open level's stop is inked")
Check(plate.counts.textures > 0 and plate.counts.textures < 2000, "the plate's textures: " .. plate.counts.textures)

-- The caption, and the people in the margin with their pencil leaders.
local heading = page.headingPool[1]
Check(heading:IsShown() and heading:GetText():find("^Mulgore, "), "the plate's heading: " .. heading:GetText())
Eq(heading.recorded.calls.SetFontObject[1], ns.Style.FONT.noteWritten, "the plate's heading is not by hand")
Check(not heading:GetText():find("\n"), "the plate's heading is broken over two lines")
local caption = page.captionPool[1]
Check(caption:IsShown() and caption:GetText():find("%.$"), "the plate has no caption")
-- Everyone on the plate has a note in the margin: the caption names no one.
Check(not caption:GetText():find("Bram") and not caption:GetText():find("Numa")
    and not caption:GetText():find("^With"), "the caption names who the notes name: " .. caption:GetText())
Eq(page.notesWritten, 3, "one margin note per person: Bram, someone, Numa")
local notes = {}
for i = 1, page.notePool.used do
    local note = page.notePool[i]
    if note:IsShown() then notes[#notes + 1] = note.name:GetText() .. ": " .. note:What() end
end
Check(Any(notes, "^with Bram: 15\194\160min together$"), "Bram's note: " .. table.concat(notes, "; "))
Check(Any(notes, "^with someone: a fight, won$"), "a stranger is not someone: " .. table.concat(notes, "; "))
-- Wrapped on its strip a line at a time; the lines joined here.
Check(Any(notes, "^with Numa: first seen  \194\183 +you'd meet again at"), "Numa's note: " .. table.concat(notes, "; "))
Check(page.leaderPool.used >= 1, "the notes have no leaders")

-- Over the plate, the caption leaves the page under it to the notes: a
-- row of boxes side by side, a note in each, left to right as their marks
-- lie across the plate, so the leaders do not cross.
local function Row()
    local laid = {}
    for _, link in ipairs(page.links) do
        if link.plate == page.plates[1] then laid[#laid + 1] = link end
    end
    table.sort(laid, function(a, b) return a.strip.box[1] < b.strip.box[1] end)
    return laid
end
do
    local TOP = ONE.top
    Check(plate.captionFoot < TOP.y, "the caption over the plate runs onto it: " .. plate.captionFoot)
    Eq(heading.recorded.points[1].args[4], -TOP.cap.y, "the heading is not over the plate")
    local laid = Row()
    Eq(#laid, 3, "the row's notes and their leaders")
    local columns = {}
    for k, link in ipairs(laid) do
        local box = link.strip.box
        Check(box[2] >= TOP.row[1].y, "a note of the row lies on the plate")
        local column
        for c, b in ipairs(TOP.row) do
            if box[1] >= b.x - 1 and box[1] + box[3] <= b.x + b.w + 1 then column = c end
        end
        Check(column and not columns[column], "the row's notes do not each have a box")
        columns[column or 0] = true
        if k > 1 then
            Check(laid[k - 1].mark[1] <= link.mark[1], ("the row's leaders cross: %.1f, then %.1f")
                :format(laid[k - 1].mark[1], link.mark[1]))
        end
    end
end

-- A caption longer than a line of words stays under the plate, the notes
-- in their column and under the words as on every other page. Its words
-- wrap here as the client's do (the mock's 6 px a letter).
do
    local Text = ns.UI.JourneyText
    local real = Text.PlateCaption
    Text.PlateCaption = function(...)
        return real(...) .. " And then the road went on a long way, past the mill and over the hill and home."
    end
    local heights = {}
    for i = 1, page.captionPool.used do
        heights[i] = page.captionPool[i].GetStringHeight
        page.captionPool[i].GetStringHeight = function(self)
            local width = (self.width or 0) > 0 and self.width or 1e9
            return self.text ~= "" and 14 * math.ceil(#self.text * 6 / width) or 0
        end
    end
    ns.UI.RedrawJourneyPage()
    local one = page.plates[1]
    Check(not one.captionOver, "a long caption is over the plate")
    Check(one.slot == ONE, "the one plate over a long caption is not in its slot")
    Check(page.headingPool[1].recorded.points[1].args[4] == -ONE.cap.y, "a long caption is not under the plate")
    Eq(page.notesWritten, 3, "the notes under a long caption")
    for _, link in ipairs(Row()) do
        Check(link.strip.box[2] >= math.min(ONE.cap.y, ONE.notes.y), "a note under a long caption lies by the plate")
    end
    -- Short as first written, but long once whoever had no room in the
    -- row is named in it: under the plate after all, decided once.
    Text.PlateCaption = function(p, began, said)
        local text = real(p, began, said)
        for key in pairs(said and said.named or {}) do
            if key ~= "someone" then return text end
        end
        return text .. " With everyone who was there, and everything that happened along the way."
    end
    local C = ns.UI.JourneyLook.CAPTION
    local limit, offLimit = C.limit, C.offLimit
    C.limit, C.offLimit = ONE.top.row[1].y + 10, ONE.top.row[1].y + 10
    ns.UI.RedrawJourneyPage()
    Check(not page.plates[1].captionOver, "a caption grown long with the row's left-off notes is over the plate")
    Check(page.plates[1].slot == ONE, "the plate under a caption grown long is not in its slot")
    C.limit, C.offLimit = limit, offLimit
    Text.PlateCaption = real
    for i = 1, #heights do page.captionPool[i].GetStringHeight = heights[i] end
    ns.UI.RedrawJourneyPage()
    Check(page.plates[1].captionOver, "a short caption does not go back over the plate")
end
-- Each leader is drawn with the route's pen as a pencil (10 Oct, in the
-- client: a .9 px hairline of four turned strokes vanished on the map and
-- showed its elbows; the user wants the pen, with no fading edges): flat
-- graphite pieces along its curve, sharing their edges, as many as it
-- needs of the link's, the rest hidden. A pencil, never a road: its nib's
-- thick and thin differ little, its width is modest, it starts lighter at
-- the strip.
do
    local L = ns.UI.JourneyLook.LEADER
    local Pen = L.pen
    Eq(page.leaderPool.used, #page.links * Pen.most, "a leader is not its pieces")
    Check(Pen.nib.thin / Pen.nib.thick >= 0.75 and Pen.width <= 2 and Pen.width >= 1.4,
        "a leader's pen reads as a road's, or as a hairline")
    for _, link in ipairs(page.links) do
        local q = link.prims
        Check(link.drawn >= 2 and link.drawn == #q, "a leader's pieces: " .. tostring(link.drawn))
        for k, stroke in ipairs(link.strokes) do
            Eq(stroke:IsShown(), k <= link.drawn, "a leader's piece " .. k .. " of " .. link.drawn)
            if k <= link.drawn then
                local c = stroke.recorded.calls
                Check(c.SetVertexOffset and not c.SetGradient, "a leader's piece is not a flat quad")
                Eq(c.SetColorTexture[4], L.alpha, "a leader's piece is faint or fades")
                Eq(c.SetColorTexture[1], L.colour[1], "a leader is not graphite")
            end
        end
        for k = 1, #q - 1 do
            Check(math.abs(q[k].x2 - q[k + 1].x1) < 1e-9 and math.abs(q[k].y3 - q[k + 1].y4) < 1e-9,
                "a leader's pieces do not share their edges")
        end
        local function Width(p) return math.sqrt((p.x1 - p.x4) ^ 2 + (p.y1 - p.y4) ^ 2) end
        Check(Width(q[1]) < Width(q[#q]), "a leader does not start lighter at its strip")
    end
end
-- Each leader is drawn by hand: a curve bowing a little, from its strip
-- onto the plate, ending in a pencil dot short of its mark.
do
    local L = ns.UI.JourneyLook.LEADER
    for _, link in ipairs(page.links) do
        local dot = link.dot
        Check(dot:IsShown(), "a leader has no dot at its end")
        local args = dot.recorded.points[1].args
        local tx, ty = args[3], -args[4]
        local d = math.sqrt((tx - link.mark[1]) ^ 2 + (ty - link.mark[2]) ^ 2)
        Check(math.abs(d - L.stop) < 1e-6, "a leader does not stop short of its mark: " .. d)
        -- Its strokes run on end to end, and bow: no longer than a fifth
        -- over the straight line, and not straight.
        local length, P = 0, link.points
        for k = 1, #P - 3, 2 do length = length + math.sqrt((P[k + 2] - P[k]) ^ 2 + (P[k + 3] - P[k + 1]) ^ 2) end
        Check(math.abs(P[#P - 1] - tx) < 1e-9 and math.abs(P[#P] - ty) < 1e-9, "a leader does not end at its dot")
        local sx, sy = link.strip:Nearest(link.mark[1], link.mark[2])
        local straight = math.sqrt((tx - sx) ^ 2 + (ty - sy) ^ 2)
        Check(length <= straight * 1.2 + 1e-6, "a leader wanders: " .. length .. " for " .. straight)
        Check(length > straight + 1e-6 or straight < 2, "a leader is dead straight")
    end
end
for m, at in pairs(plate.where) do
    local x, y = plate:SheetToPage(at.x, at.y)
    Check(math.abs(x - at[1]) < 1e-9 and math.abs(y - at[2]) < 1e-9, "a mark's place on the page")
end
-- A name in the margin opens their page; someone opens nothing.
local stranger
for i = 1, page.notePool.used do
    if page.notePool[i].name:GetText() == "with someone" then stranger = page.notePool[i] end
end
Check(stranger and stranger.guid == nil, "the stranger's note has someone to open")

-- One leader per strip (10 Oct, in the client: a person with two marks on
-- a plate had a long pencil line to each): Bram also fought you on the
-- plate, apart from your time together; their strip's one leader goes to
-- the fight, the likelier to matter (the plate's PRIORITY).
do
    local fight = ns.Journey.Fight(j, "lost", A, t0 + 1200, { mapID = 1412, x = 0.47, y = 0.67 })
    ns.UI.RefreshJourneyPage(false)
    Open(10)
    local p = page.plates[1]
    local per, babaStrip = {}, nil
    for _, link in ipairs(page.links) do per[link.strip] = (per[link.strip] or 0) + 1 end
    local marks = 0
    for _, m in ipairs(p.people or {}) do
        if m.guid == A then marks = marks + 1 end
    end
    Check(marks >= 2, "Bram has not two marks on the plate: " .. marks)
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() then
            Eq(per[strip] or 0, 1, "a strip has not one leader: " .. strip.name:GetText())
            if strip.guid == A then babaStrip = strip end
        end
    end
    local toFight
    for _, m in ipairs(p.people or {}) do
        if m.guid == A and m.kind == "fight" then toFight = p.where[m] end
    end
    for _, link in ipairs(page.links) do
        if link.strip == babaStrip then Eq(link.mark, toFight, "Bram's leader does not go to the fight") end
    end
    ns.Journey.Refight(j, fight, false)
    ns.UI.RefreshJourneyPage(false)
    Open(10)
end

-- Each note is a paper strip taped beside the plate (UI/Paper/Strip.lua),
-- turned a little its own way, the same every drawing; strips touch
-- neither each other nor a plate.
local STRIP = ns.UI.PAPER_STRIP.STRIP
local function Strips()
    local list = {}
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() then list[#list + 1] = strip end
    end
    return list
end
local function Overlap(a, b, grow)
    grow = grow or 0
    return a[1] - grow < b[1] + b[3] and b[1] < a[1] + a[3] + grow and a[2] - grow < b[2] + b[4] and b[2] < a[2] + a[4] + grow
end
local function Apart(where)
    local strips = Strips()
    for i, strip in ipairs(strips) do
        local box = strip.box
        Check(box[2] + box[4] <= 528, where .. ": a strip runs off the page's foot")
        for k = i + 1, #strips do
            Check(not Overlap(box, strips[k].box, 2), where .. ": two strips overlap")
        end
        for _, p in ipairs(page.plates) do
            if p:IsShown() then
                local s = p.slot
                Check(not Overlap(box, { s.x, s.y, s.w, s.h }, 6), where .. ": a strip lies on a plate")
            end
        end
    end
    return strips
end
local turns = {}
for _, strip in ipairs(Apart("level 10")) do
    Check(strip.turn ~= 0 and math.abs(strip.turn) <= math.rad(STRIP.turn) + 1e-9, "a strip is not turned a little")
    Check(strip.shadow:IsShown() and strip.tape:IsShown(), "a strip has no shadow or tape")
    turns[strip.name:GetText()] = strip.turn
end
ns.UI.RedrawJourneyPage()
for _, strip in ipairs(Strips()) do
    Eq(strip.turn, turns[strip.name:GetText()], "a strip turned another way when drawn again")
end
-- No word alone on a strip's last line (10 Oct, in the client: "3 h 20
-- min together and a / note"), and the tape never on the name's letters:
-- a strip laid at every width a margin column can give it.
do
    local strip = ns.UI.PaperStrip(page.right)
    local Text = ns.UI.JourneyText
    local TAPE = ns.UI.PAPER_LOOK.tape
    local pad = { strip:Pad() }
    -- As the strip wrapped before it balanced its lines: greedy, by the
    -- mock's widths (6 px a byte).
    local function Greedy(text, width)
        local lines, line = {}, ""
        for word in text:gmatch("%S+") do
            local try = line == "" and word or (line .. " " .. word)
            if line ~= "" and #try * 6 > width then
                lines[#lines + 1] = line
                line = word
            else
                line = try
            end
        end
        if line ~= "" then lines[#lines + 1] = line end
        return lines
    end
    local whats = {
        Text.MarginWhat({ { kind = "session", seconds = 12000 }, { kind = "note" } }, 5),
        "twenty minutes together and you won the fight",
        "first seen  \194\183  you'd meet again at level 14",
    }
    local orphaned, laid, alone, taped = 0, 0, {}, {}
    for _, what in ipairs(whats) do
        -- The margin columns are 122 to 260 px (LAYOUT's captions).
        for width = 110, 260, 2 do
            strip:SetNote({ name = "Tester", what = what, guid = A, seed = "Tester:" .. width })
            strip:Layout(0, 0, width)
            local old = Greedy(what, width - pad[1] - pad[3])
            if #old >= 2 and #old <= STRIP.lines and not old[#old]:find("%s") then orphaned = orphaned + 1 end
            local n = strip.shownLines
            if n >= 2 and #old <= STRIP.lines then
                laid = laid + 1
                local last = strip.lines[n]:GetText()
                if not last:find("%s") then alone[#alone + 1] = width .. " px: " .. last end
            end
            if strip.tapeClear and strip.tapeClear < -1e-9 then taped[#taped + 1] = width .. " px" end
        end
    end
    Check(orphaned > 0 and laid > 0, "no width would have left a word alone: the check checks nothing")
    Eq(table.concat(alone, "; "), "", "a word alone on a strip's last line")
    Eq(table.concat(taped, "; "), "", "the tape lies on the name")
    -- Laid flat, the tape lies square and still clear of the name.
    ns.SetSetting("flatSheets", true)
    strip:SetNote({ name = "Tester", what = whats[1], guid = A, seed = "flat" })
    strip:Layout(0, 0, 140)
    Check(strip.tapeClear == nil or strip.tapeClear >= -1e-9, "laid flat, the tape lies on the name")
    ns.SetSetting("flatSheets", false)
    -- The tape is old matte tape, seen: more yellow than the slip and
    -- denser than before (10 Oct: { .92, .84, .60 } at .50 was too faint).
    Check(TAPE.alpha >= 0.6 and TAPE.tint[3] < TAPE.tint[1] - 0.3 and TAPE.edgeAlpha >= 0.45,
        "the tape is too faint to see")
    Check(ns.UI.PAPER_LOOK.shadow[3] >= 0.35 and STRIP.soft.alpha >= 0.25, "the strip's shadow is too faint")
    strip:Hide()
end
-- Their own note quoted on the strip (11 Oct, the user: not "a note" but
-- what it says): in their hand a size down, between the name and what
-- happened, the opening quote hung in the margin; a long note cut at a
-- word in at most STRIP.quote.lines lines, never wider than the strip,
-- and fewer lines where the page asks or the margin is short.
do
    local strip = ns.UI.PaperStrip(page.right)
    local Q, pad = STRIP.quote, { strip:Pad() }
    local function Lay(quote, width, lines)
        strip:SetNote({ name = "Tester", what = "35\194\160min together", quote = quote, quoteLines = lines,
            guid = A, seed = "quote" })
        return strip:Layout(0, 0, width)
    end
    local function Top(region) return -region.recorded.points[1].args[4] end
    local function Left(region) return region.recorded.points[1].args[3] - region.recorded.width / 2 end
    local _, plainH = Lay(nil, 200)
    Eq(strip.quoteLines, 0, "a strip without a note quotes one")
    local _, h = Lay("Saved me from the murlocs.", 200)
    Eq(strip:Quote(), Q.open .. "Saved me from the murlocs." .. Q.close, "a short note as quoted")
    Check(not strip.quoteCut and strip.quoteLines >= 1, "a short note was cut")
    Eq(strip.said[1].recorded.calls.SetFontObject[1], ns.Style.FONT.noteQuoted, "the quote is not in their hand")
    Eq(strip:What(), "35\194\160min together", "what happened went with the quote")
    Check(h > plainH, "the quote took no room on the strip")
    Check(Left(strip.said[1]) <= Left(strip.name) - 3, "the opening quote does not hang left of the name")
    Check(Top(strip.name) < Top(strip.said[1]) and Top(strip.said[1]) < Top(strip.lines[1]),
        "the quote is not between the name and what happened")
    local long = ("murlocs again and again "):rep(12) .. "at the coast."
    local cutAt, wide = {}, {}
    for width = 110, 260, 10 do
        Lay(long, width)
        local n = strip.quoteLines
        if n > Q.lines or not strip.quoteCut or not strip.said[n]:GetText():find(Q.cut .. Q.close .. "$") then
            cutAt[#cutAt + 1] = width .. " px: " .. strip:Quote()
        end
        for i = 1, n do
            local w = #strip.said[i]:GetText() * 6
            if w > width - pad[1] - pad[3] then wide[#wide + 1] = width .. " px: " .. strip.said[i]:GetText() end
        end
    end
    Eq(table.concat(cutAt, "; "), "", "a long note is not cut to its lines")
    Eq(table.concat(wide, "; "), "", "a quoted line runs past the strip")
    -- One word wider than the strip ends the quote there, cut.
    Lay(("x"):rep(60) .. " more", 140)
    Check(strip.quoteLines == 1 and strip.quoteCut and #strip.said[1]:GetText() * 6 <= 140 - pad[1] - pad[3],
        "a word too wide for the strip: " .. strip:Quote())
    -- Fewer lines where the page asks; a line at a time where the margin
    -- is short (strip:Smaller), never none.
    Lay(long, 200, 1)
    Eq(strip.quoteLines, 1, "the page's fewer lines for a quote")
    Lay(long, 200)
    local full = strip.quoteLines
    Check(full == Q.lines and strip:Smaller(), "a long quote gave up no line")
    strip:Layout(0, 0, 200)
    Eq(strip.quoteLines, full - 1, "a smaller quote kept its lines")
    while strip:Smaller() do strip:Layout(0, 0, 200) end
    Eq(strip.quoteLines, Q.least, "a quote gave up its last line")
    -- Its next note has it whole again.
    Lay(long, 200)
    Eq(strip.quoteLines, Q.lines, "a strip's next note kept the last one's fewer lines")
    strip:Hide()
end
-- On the page: a note about Bram written there is quoted on her strip,
-- not counted; a link typed into it shows as its name.
do
    local at
    for _, m in ipairs(page.plates[1].people or {}) do
        if m.guid == A then at = at or m.t end
    end
    local note = ns.Notes.Add(A, "Showed me |cff1eff00|Hitem:2589::::::::10:::::::|h[Linen Cloth]|h|r\nby the well.",
        { time = at, where = { mapID = 1412, x = 0.47, y = 0.67 } })
    ns.UI.RefreshJourneyPage(false)
    Open(10)
    local quoted
    for _, strip in ipairs(Strips()) do
        if strip.guid == A then quoted = strip end
    end
    Eq(quoted and quoted:Quote(), STRIP.quote.open .. "Showed me [Linen Cloth] by the well." .. STRIP.quote.close,
        "Bram's strip does not quote her note")
    Check(quoted and not quoted:What():find("note"), "Bram's strip still says a note: " .. (quoted and quoted:What() or ""))
    Check(quoted and quoted.tip and quoted.tip() == nil, "a whole quote has a tooltip")
    -- Her leader goes to where the quoted note was written, not to the
    -- time together (12 Oct, in the client: a quote from the south under
    -- a leader to the north).
    local p, toNote, toSession = page.plates[1], nil, nil
    for _, m in ipairs(p.people or {}) do
        if m.guid == A and m.kind == "note" then toNote = p.where[m] end
        if m.guid == A and m.kind == "session" then toSession = p.where[m] end
    end
    Check(toNote and toSession and (toNote[1] ~= toSession[1] or toNote[2] ~= toSession[2]),
        "the note is not apart from the time together")
    for _, link in ipairs(page.links) do
        if link.strip == quoted then Eq(link.mark, toNote, "Bram's leader does not go to the quoted note") end
    end
    ns.Notes.Delete(note.id)
    ns.UI.RefreshJourneyPage(false)
    Open(10)
end
-- A leader leaves from the strip's edge.
local bram
for _, strip in ipairs(Strips()) do
    if strip.guid == A then bram = strip end
end
local ex, ey = bram:Nearest(bram.box[1] - 50, bram.box[2] + 10)
Check(ex <= bram.box[1] + 1 and ex >= bram.box[1] - 2, "the nearest edge of a strip to its left is not its left side")
-- A rival's strip has its foot in rubric; no one else's.
Check(not bram.rival:IsShown(), "a friend's strip is marked as a rival's")
local tags = ns.db.diary[A].tags
ns.db.diary[A].tags = { "foe" }
ns.UI.RedrawJourneyPage()
for _, strip in ipairs(Strips()) do
    if strip.guid == A then bram = strip end
end
Check(bram.rival:IsShown(), "a rival's strip has no rubric foot")
ns.db.diary[A].tags = tags
-- Laid flat: straight, no shadow, the tape a plain band; text unturned.
ns.SetSetting("flatSheets", true)
ns.UI.RedrawJourneyPage()
for _, strip in ipairs(Strips()) do
    Eq(strip.turn, 0, "laid flat, a strip is turned")
    Check(not strip.shadow:IsShown() and strip.tape:IsShown() and not strip.tapeEnds[1]:IsShown(),
        "laid flat, a strip keeps its shadow or its tape's ends")
end
ns.SetSetting("flatSheets", false)
ns.UI.RedrawJourneyPage()
-- Under the mouse, a strip's tape lifts at its free end: brighter, a
-- hair of shadow under it, the slip's own shadow a touch darker, the
-- name underlined. A short OnUpdate runs it and stops itself; nothing
-- moves; leaving lays it down exactly as it was.
for _, strip in ipairs(Strips()) do
    if strip.guid == A then bram = strip end
end
local HOVER = ns.UI.PAPER_STRIP.TAPE.hover
local function Look(strip)
    local function C(t) return table.concat({ unpack(t.recorded.calls.SetColorTexture, 1, 4) }, ",") end
    local parts = { C(strip.tape), C(strip.tapeEnds[2]), C(strip.shadow), C(strip.tapeShadow),
        tostring(strip.tapeShadow:IsShown()), tostring(strip.underline:IsShown()) }
    for _, region in ipairs({ strip.name, strip.lines[1], strip.tape }) do
        local point = region.recorded.points[1]
        parts[#parts + 1] = table.concat({ point.args[3], point.args[4] }, ",")
    end
    return table.concat(parts, " | ")
end
local lying = Look(bram)
Eq(bram.lift, 0, "a strip lies lifted before the mouse came")
bram.link.scripts.OnEnter(bram.link)
Check(bram.scripts.OnUpdate, "the hover does not run")
Check(bram.underline:IsShown(), "the name is not underlined with the hover")
bram.scripts.OnUpdate(bram, HOVER.time / 2)
Check(bram.lift > 0 and bram.lift < 1, "the hover is not on its way: " .. bram.lift)
bram.scripts.OnUpdate(bram, HOVER.time)
Eq(bram.lift, 1, "the tape did not lift")
Check(bram.scripts.OnUpdate == nil, "the hover's OnUpdate did not stop itself")
Check(bram.tapeShadow:IsShown(), "the lifted tape throws no shadow")
local lifted = Look(bram)
Check(lifted ~= lying, "the hover changed nothing")
Check(select(4, unpack(bram.tape.recorded.calls.SetColorTexture)) > ns.UI.PAPER_LOOK.tape.alpha,
    "the lifted tape is not brighter")
-- Nothing moved: the writing and the tape lie where they lay.
local function Places(look) return look:match("^.-|.-|.-|.-|.-|.-| (.*)$") end
Eq(Places(lifted), Places(lying), "the hover moved the writing or the tape")
bram.link.scripts.OnLeave(bram.link)
bram.scripts.OnUpdate(bram, HOVER.time * 2)
Eq(bram.lift, 0, "leaving did not lay the tape down")
Eq(Look(bram), lying, "leaving did not restore the strip exactly")
Check(bram.scripts.OnUpdate == nil, "the hover kept running after it was laid down")
-- Put away or drawn again mid-hover: lying at once, nothing left running.
bram.link.scripts.OnEnter(bram.link)
bram.scripts.OnUpdate(bram, HOVER.time / 2)
ns.UI.RedrawJourneyPage()
Check(bram.lift == 0 and bram.scripts.OnUpdate == nil and not bram.underline:IsShown(),
    "a strip drawn again mid-hover kept its hover")
bram.link.scripts.OnEnter(bram.link)
bram.scripts.OnUpdate(bram, HOVER.time / 2)
bram:Hide()
Check(bram.lift == 0 and bram.scripts.OnUpdate == nil, "a strip put away mid-hover kept its hover")
ns.UI.RedrawJourneyPage()
for _, strip in ipairs(Strips()) do
    if strip.guid == A then bram = strip end
end
-- A stranger's strip opens nothing, so it has no hover.
local someone
for _, strip in ipairs(Strips()) do
    if strip.guid == nil then someone = strip end
end
local before = Look(someone)
someone:Hover(true)
Check(someone.scripts.OnUpdate == nil and someone.lift == 0 and Look(someone) == before,
    "a stranger's strip has a hover")
-- Laid flat: the tape's tone only, no lift and no shadow.
ns.SetSetting("flatSheets", true)
ns.UI.RedrawJourneyPage()
for _, strip in ipairs(Strips()) do
    if strip.guid == A then bram = strip end
end
bram.link.scripts.OnEnter(bram.link)
bram.scripts.OnUpdate(bram, HOVER.time)
Check(bram.lift == 1 and not bram.tapeShadow:IsShown() and not bram.shadow:IsShown(),
    "laid flat, the hover lifts or shadows")
Eq(select(4, unpack(bram.tape.recorded.calls.SetColorTexture)), HOVER.flatAlpha, "laid flat, the tape's tone")
bram.link.scripts.OnLeave(bram.link)
bram.scripts.OnUpdate(bram, HOVER.time)
ns.SetSetting("flatSheets", false)
ns.UI.RedrawJourneyPage()

-- The name on a strip, and the strip round it, open their page.
for _, strip in ipairs(Strips()) do
    if strip.guid == A then bram = strip end
end
-- The mouse finds the whole strip as drawn, its tape included, over the
-- plates and the leaders (round 5: the plates' view, all over the page,
-- took the mouse first).
local hit, tape = bram.hitRect, bram.tapeRect
Check(hit[1] <= tape[1] and hit[2] <= tape[2] and hit[3] >= tape[3] and hit[4] >= tape[4],
    "the strip's hit area does not hold its tape")
Check(hit[1] <= bram.box[1] and hit[2] <= bram.box[2] and hit[3] >= bram.box[1] + bram.box[3]
    and hit[4] >= bram.box[2] + bram.box[4], "the strip's hit area does not hold the slip")
Eq(bram.link.recorded.width, hit[3] - hit[1], "the hit button is not the hit area")
local level = bram.link:GetFrameLevel()
Check(level > page.leaders:GetFrameLevel(), "the strip's button lies under the leaders")
for _, p in ipairs(page.plates) do
    Check(level > p:GetFrameLevel() and level > p.sheet:GetFrameLevel(), "the strip's button lies under a plate")
    Check(p.scripts.OnMouseDown == nil and p.recorded.calls.EnableMouse[1] == false,
        "a plate's view takes the mouse")
end
bram.link:Click()
Eq(ns.UI.JournalView(), "people", "a strip's name did not turn to People")
Eq(ns.UI.Journal.selected, A, "a strip's name did not open their page")
J.ribbons.journey:Click()
e10 = Open(10)
plate = page.plates[1]

-- The plate's tooltips: the pools say their ink, the lozenge the sighting.
local said = Tips(plate)
Check(Any(said, "^Red Rocks|Fought here, 30 min"), "a pool's tooltip does not say its ink: " .. table.concat(said, " / "))
-- Numa's first sighting and Bram's session share one spot: one mark,
-- the session on top, its tooltip telling both (marks never touch).
Eq(plate.counts.marks, 2, "the people's spots: the shared one and the fight")
Check(Any(said, "^With Bram Redfen.*|First seen: Numa Pompilius|"), "the shared mark's tooltip: " .. table.concat(said, " / "))
Check(Any(said, "^With Bram Redfen"), "the session mark's tooltip does not say who")
Check(Any(said, "^Won a fight") or Any(said, "^Beat"), "the fight mark's tooltip")

-- Under the mouse a plate leans in (ZOOM): its picture grows about the
-- card's middle, clipped to the box the turned art covers, the card, its
-- corners and mat staying put; the leaders follow their marks.
do
    local ZOOM = ns.UI.JourneyPlate.ZOOM
    plate = page.plates[1]
    local clip, content, over = plate.clip, plate.content, plate.over
    Check(clip and content and over and content.parent == clip, "the plate has no clipped picture frame")
    Eq(clip.recorded.calls.SetClipsChildren[1], true, "the picture is not clipped")
    Eq(clip.recorded.calls.EnableMouse[1], true, "a plate that opens a full page does not take the mouse")
    local inContent, inOver = 0, 0
    for _, w in ipairs(mock.frames) do
        if w.frameType == "Texture" and w:IsShown() then
            if w.parent == content and w.recorded.layer == "BORDER" then inContent = inContent + 1 end
            if w.parent == over and w.recorded.layer == "OVERLAY" and w.recorded.sublevel == 7 then inOver = inOver + 1 end
        end
    end
    Check(inContent > 0, "the art is not in the picture frame")
    Eq(inOver, 3, "the photo corners are not over the picture")
    Check(over:GetFrameLevel() > content:GetFrameLevel(), "the mat and corners lie under the picture")
    local stroke = page.leaderPool[1]
    local function At() return table.concat({ unpack(stroke.recorded.points[1].args, 3, 4) }, ",") end
    local resting = At()

    clip.mouseOver = true
    clip.scripts.OnEnter(clip)
    Check(clip.scripts.OnUpdate, "entering the plate does not lean it in")
    clip.scripts.OnUpdate(clip, ZOOM.time / 2)
    Check(plate.zoom > 0 and plate.zoom < 1, "leaning in is not on its way")
    clip.scripts.OnUpdate(clip, ZOOM.time)
    Eq(plate.zoom, 1, "the plate did not lean in")
    Eq(content.recorded.calls.SetScale[1], ZOOM.scale, "the picture did not grow")
    Check(clip.scripts.OnUpdate == nil, "the zoom's OnUpdate did not stop itself")
    Check(At() ~= resting, "a leader did not follow its mark")
    -- Onto a mark: still over the plate, still leaned in.
    local mark = plate.hover[1]
    clip.scripts.OnLeave(clip)
    mark.scripts.OnEnter(mark)
    Check(clip.scripts.OnUpdate == nil and plate.zoom == 1, "moving onto a mark let the plate go")
    -- Off the plate from the mark: back, exactly.
    clip.mouseOver = false
    mark.scripts.OnLeave(mark)
    clip.scripts.OnUpdate(clip, ZOOM.time * 2)
    Eq(plate.zoom, 0, "leaving did not lay the plate back")
    Eq(content.recorded.calls.SetScale[1], 1, "the picture kept its zoom")
    Eq(At(), resting, "a leader did not come back to its mark")
    -- Drawn again or put away mid-lean: back at once, nothing running.
    clip.mouseOver = true
    clip.scripts.OnEnter(clip)
    clip.scripts.OnUpdate(clip, ZOOM.time / 2)
    ns.UI.RedrawJourneyPage()
    Check(plate.zoom == 0 and content.recorded.calls.SetScale[1] == 1, "a plate drawn again mid-lean kept its zoom")
    -- Still under the mouse, it leans in again from the start; away, it
    -- stays as drawn and nothing keeps running.
    clip.mouseOver = false
    if clip.scripts.OnUpdate then clip.scripts.OnUpdate(clip, ZOOM.time) end
    Check(plate.zoom == 0 and clip.scripts.OnUpdate == nil, "a redrawn plate kept running")
    clip.mouseOver = true
    clip.scripts.OnEnter(clip)
    clip.scripts.OnUpdate(clip, ZOOM.time / 2)
    plate:Hide()
    Check(plate.zoom == 0 and clip.scripts.OnUpdate == nil, "a plate put away mid-lean kept its zoom")
    clip.mouseOver = false
    ns.UI.RedrawJourneyPage()
end

-- Level 11 travelled: Mulgore, then The Barrens and its dungeon's door.
Open(11)
Check(page.layout >= 2, "a level that travelled has one plate")
local maps = {}
for i = 1, page.layout do maps[#maps + 1] = page.plates[i].mapID end
Check(maps[1] == 1412 and maps[#maps] == 1413, "the plates are not in time order: " .. table.concat(maps, ","))
local slots = {}
for i = 1, page.layout do
    slots[#slots + 1] = page.plates[i].slot.w
    Check(page.plates[i].share < 1 or page.layout == 1, "a smaller plate takes the whole of the caps")
end
Apart("level 11, " .. page.layout .. " plates")
Check(ns.UI.JourneyPlate.Share({ w = 214, h = 138 }) == ns.UI.JourneyPlate.SHARE.least,
    "a small plate is not at its least share")

-- A click on a plate opens its zone's whole map; a click on that goes
-- back to the level's plates.
local function Click(p)
    p.CursorScreen = function() return 0, 0 end
    p.clip.scripts.OnMouseDown(p.clip, "LeftButton")
    p.clip.scripts.OnMouseUp(p.clip, "LeftButton")
end
Click(page.plates[page.layout])
Eq(page.mode, "full", "a plate does not open its zone's full page")
Eq(page.fullMap, 1413, "the full page is not the plate's zone")
Eq(page.foot.back, nil, "the full page still has a back link")
Click(page.plates[1])
Eq(page.mode, "plates", "a click on the full page did not return to the level's plates")

--------------------------------------------------------------------------
Section("a zone's full page (JRN-14)")

-- Mulgore explored in part: one area two tiles wide, its last cut from a
-- 64-pixel file, and one shown only under the mouse.
mock.explored[1412] = {
    { textureWidth = 300, textureHeight = 200, offsetX = 300, offsetY = 200, fileDataIDs = { 9001, 9002 } },
    { textureWidth = 100, textureHeight = 100, offsetX = 100, offsetY = 100, fileDataIDs = { 9003 },
        isShownByMouseOver = true },
}
Open(10)
local row = RowFor(function(item) return item.zone and item.entry == 1 end)
row:Click()
Eq(page.mode, "full", "clicking a zone row did not show its full page")
plate = page.plates[1]
Check(plate:IsShown() and not page.plates[2]:IsShown(), "the full page is not one plate")
Eq(plate.mapID, 1412, "the full page is not the zone clicked")
Eq(plate.slot.w .. "x" .. plate.slot.h, "446x484", "the full page's slot")
Check(math.abs(plate.window[4] - plate.window[2] - 1) < 1e-9, "the full page does not fit the zone's height")
Check(math.abs((plate.window[1] + plate.window[3]) / 2 - 0.5) < 0.01, "the full page is not centred on the road")
Check(RowFor(function(item) return item.zone and item.current end), "the zone row shown is not marked")
Check(plate.tileCount > 0 and plate.hasArt, "the map art was not printed")
Eq(plate.exploredCount, 2, "the explored area was not printed over the art")
-- Each explored piece over the base's tiles, and the narrow one only from
-- its file's first 44 of 64 pixels across and 200 of 256 down.
local narrow, mouseOver = 0, 0
for _, region in ipairs(mock.frames) do
    local rec = region.shown and region.recorded
    local file = rec and rec.calls.SetTexture and rec.calls.SetTexture[1]
    if file == 9002 then
        narrow = narrow + 1
        Eq(rec.layer .. rec.sublevel, "BORDER3", "an explored piece is not over the base's tiles")
        local u0, u1, v0, v1 = unpack(rec.calls.SetTexCoord)
        Check(u0 >= -1e-6 and u1 <= 44 / 64 + 1e-6 and v0 >= -1e-6 and v1 <= 200 / 256 + 1e-6,
            "the narrow piece is cut past its pixels: " .. u0 .. " " .. u1 .. " " .. v0 .. " " .. v1)
    elseif file == 9003 then
        mouseOver = mouseOver + 1
    end
end
Check(narrow > 0, "the area's narrow tile was not printed")
Eq(mouseOver, 0, "an area shown only under the mouse was printed")

-- A window of the art (a plate's close-up, JRN-21): a piece cut by it
-- takes only its part of its file, at the window's scale. One 256 px tile
-- at 0,0 and the window 100..300 by 50..150 printed 400 px wide: 2 px a
-- pixel, the tile's part 100..256 by 50..150.
do
    local printed = {}
    local fakeK = {
        Split = function(x0, y0, x1, y1, fn) fn(x0, y0, x1, y1, 1) end,
        Bend = function(piece, a, b, c, d) piece.box = { a, b, c, d } end,
    }
    local pool = { Next = function()
        local piece = { SetTexture = function(self, f) self.file = f end,
            SetTexCoord = function(self, ...) self.tc = { ... } end, SetVertexColor = function() end }
        printed[#printed + 1] = piece
        return piece
    end }
    local layer = { layerWidth = 512, layerHeight = 256 }
    local pieces = { { file = 1, x = 0, y = 0, w = 256, h = 256, fw = 256, fh = 256 },
        { file = 2, x = 256, y = 0, w = 256, h = 256, fw = 256, fh = 256 } }
    local tiles = ns.UI.MapArt.Print(layer, pieces, { 100, 50, 300, 150 }, 0, 0, 400, { 1, 1, 1 }, fakeK, pool, pool)
    Eq(tiles, 2, "a window across two tiles prints both")
    local a = printed[1]
    local u0, u1, v0, v1 = unpack(a.tc)
    Check(math.abs(u0 - 100 / 256) < 1e-9 and math.abs(u1 - 1) < 1e-9, "a windowed piece's u: " .. u0 .. " " .. u1)
    Check(math.abs(v0 - 50 / 256) < 1e-9 and math.abs(v1 - 150 / 256) < 1e-9, "a windowed piece's v: " .. v0 .. " " .. v1)
    Eq(a.box[3], 312, "the first tile's right edge on the plate (2 px a pixel)")
    local b = printed[2]
    Check(math.abs(b.tc[2] - 44 / 256) < 1e-9, "the second tile's part: " .. b.tc[2])
    Eq(b.box[1], 312, "the second tile starts where the first ended")
    -- The number form is still the old symmetric crop.
    local x0, y0, x1, y1 = ns.UI.MapArt.Window(layer, 0.25)
    Eq(x0 .. "," .. y0 .. "," .. x1 .. "," .. y1, "128,64,384,192", "a number is no longer a crop all round")
end

-- A road cut at a window's edge: the stretches inside, their time shared
-- out by length, the ends not where the road began or ended.
do
    local Plate = ns.UI.JourneyPlate
    local road = { kind = "road", from = 100, to = 200, mapID = 1, pts = { 0.1, 0.5, 0.5, 0.5, 0.9, 0.5 } }
    local out = {}
    Plate.Pieces(road, { 0.3, 0, 0.7, 1 }, out)
    Eq(#out, 1, "a road across a window is one piece inside it")
    local p = out[1]
    Check(math.abs(p.pts[1] - 0.3) < 1e-9 and math.abs(p.pts[#p.pts - 1] - 0.7) < 1e-9, "the piece is not cut at the edges")
    Check(math.abs(p.from - 125) < 1e-9 and math.abs(p.to - 175) < 1e-9, "the piece's time: " .. p.from .. " " .. p.to)
    out = {}
    Plate.Pieces(road, { 0, 0, 1, 1 }, out)
    Check(#out == 1 and out[1] == road, "a road wholly inside was copied")
    out = {}
    Plate.Pieces(road, { 0, 0.6, 1, 1 }, out)
    Eq(#out, 0, "a road outside the window was drawn")
end

-- "Always show the whole map" adds every area the client's tables have
-- (UI/Map/OverlayData.lua), each once, explored or not.
local data = ns.UI.MapOverlayData[1412]
Check(data and #data > 10, "no overlay data for Mulgore")
Eq(select(3, ns.UI.MapArt.For(1412)), 1, "areas shown with only the explored")
Eq(select(3, ns.UI.MapArt.For(1412, true)), 1 + #data, "areas shown with the whole map")
local first = data[1]
table.insert(mock.explored[1412], { textureWidth = first[1], textureHeight = first[2],
    offsetX = first[3], offsetY = first[4], fileDataIDs = first[5] })
Eq(select(3, ns.UI.MapArt.For(1412, true)), 1 + #data, "an explored area was shown twice")
local explored = plate.exploredCount
ns.SetSetting("revealMap", true)
ns.UI.OpenZoneSheet(1412)
local revealed = plate.exploredCount
Check(revealed > explored, "the setting did not fill in the whole map")
ns.SetSetting("revealMap", false)
ns.UI.OpenZoneSheet(1412)
Check(plate.exploredCount > explored and plate.exploredCount < revealed,
    "turned off, the plate does not show just the two explored areas: " .. plate.exploredCount)
mock.explored[1412] = nil

-- OpenZoneSheet shows the full page, at the open level when it was there.
ns.UI.OpenZoneSheet(1412)
Eq(page.mode, "full", "OpenZoneSheet does not show the full page")
Eq(page.open, 1, "the full page left the open level that was there")
Eq(page.foot.name:GetText(), "MULGORE", "the full page's line has no zone")
Check(page.foot.meta:GetText():find("levels 10 to 11") and page.foot.meta:GetText():find("with Bram")
    and page.foot.meta:GetText():find("a fight"), "the full page's line: " .. page.foot.meta:GetText())
Check(page.foot.hint:IsShown() and page.foot.hint:GetText():find("click the map to go back"),
    "the full page does not say how to go back")
Eq(plate.counts.stops, 1, "level 10's stop was not inked")
Eq(plate.counts.roads, 1, "the road was not drawn")
Check(plate.counts.quads > 4, "the road is not a stroke of quads: " .. plate.counts.quads)
Eq(plate.counts.fallback, 0, "a quad fell back where corners can move")
Check(type(plate.buildMs) == "number", "the drawing was not timed")
-- The flight out is level 11's (after it was reached): not on level 10's.
Eq(plate.counts.flights, 0, "level 11's flight is on level 10's map")
Eq(plate.counts.meetings, 2, "the session and the fight are not marked")
-- Level 10 ends where level 11 was reached: its pin, in rubric.
Eq(plate.counts.pins, 1, "where level 10 ended has no pin")
Eq(plate.pinMarks[1].pin.level, 11, "the pin at level 10's end is not level 11's")
Check(not plate.pinMarks[1].start, "the level reached is drawn as where a level began")
Eq(plate.counts.labels, 0, "an area is labelled on the map")

-- Looking closer (FULLZOOM): the wheel zooms toward the point under the
-- cursor, from the fitted view to the art's own size; each notch draws the
-- picture at once where it is going, and eases it in from where it was.
do
    local FZ, DRAG = ns.UI.JourneyPlate.FULLZOOM, ns.UI.JourneyPlate.DRAG
    local pivot, content, clip = plate.pivot, plate.content, plate.clip
    local look = plate.look
    local f0 = (484 - 20) / 668
    Check(look and math.abs(look.f - f0) < 1e-9, "the full page does not open fitted")
    Check(plate.window[1] == 0 and plate.window[3] == 1, "fitted, the zone was not drawn whole round the window")
    Eq(clip.recorded.calls.EnableMouseWheel[1], true, "the full page does not take the wheel")
    local c0x = look.c0[1]
    local qx, qy = 80, -40
    local mx, my = look.cx + qx / (look.f * 1002), look.cy + qy / (look.f * 668)
    plate:Wheel(1, qx, qy)
    look = plate.look
    Eq(look.redraws, 1, "a notch did not draw the picture at once")
    Check(math.abs(look.drawn.f - f0 * FZ.step) < 1e-9, "a notch was drawn at another zoom than its own")
    Check(math.abs(content.recorded.calls.SetScale[1] - 1 / FZ.step) < 1e-9,
        "drawn at the notch's zoom, the picture did not ease in from where it was")
    -- The print's darkened edges stay at the neat line while it is scaled.
    local band = plate.vignettes[1]
    Check(band and band.home, "the full page has no darkened edges to keep")
    Check(math.abs(band.recorded.width / FZ.step - band.home[3]) < 1e-6,
        "the darkened edges were scaled with the picture")
    Check(math.abs(band.recorded.points[1].args[3] / FZ.step - band.home[1]) < 1e-6,
        "the darkened edges moved with the picture's scale")
    Check(pivot.scripts.OnUpdate, "the wheel does not ease")
    pivot.scripts.OnUpdate(pivot, FZ.time)
    look = plate.look
    Check(math.abs(look.f - f0 * FZ.step) < 1e-9, "a notch is not a step closer: " .. look.f)
    Check(math.abs(look.cx + qx / (look.f * 1002) - mx) < 1e-9 and math.abs(look.cy + qy / (look.f * 668) - my) < 1e-9,
        "the point under the cursor moved")
    Eq(content.recorded.calls.SetScale[1], 1, "eased in, the picture kept a scale")
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    look = plate.look
    Eq(look.redraws, 1, "the picture was drawn again once the wheel was still")
    Check(pivot.scripts.OnUpdate == nil, "the wheel's OnUpdate did not stop itself")
    Check(plate.window[3] - plate.window[1] > (446 - 20) / (look.f * 1002), "the window was not drawn with room to pan")
    Check(plate.window[1] == 0 and plate.window[2] == 0 and plate.window[3] == 1 and plate.window[4] == 1,
        "zoomed in, the zone was not drawn whole round the window: a drag runs off the art")
    -- ... and drawn there, past the card's edge, not cut to the card.
    local sheet, K = ns.UI.LooseSheet(UIParent, 200, 100, { glued = true, shadows = {} })
    K.Fall("split")
    K.Lay()
    local function Area(open)
        local area = 0
        K.Split(-300, -300, 500, 400, function(a, b, c, d) area = area + (c - a) * (d - b) end, open)
        return area
    end
    Eq(Area(false), 200 * 100, "a split not open reached past the sheet")
    Eq(Area(true), 800 * 700, "an open split was cut to the sheet: the picture round a zoomed window is lost")
    sheet:Hide()
    -- Clamped: no closer than the art's own size, no further than fitted.
    for _ = 1, 12 do plate:Wheel(1, 0, 0) end
    Eq(plate.look.goal.f, FZ.native, "the zoom passed the art's own size")
    for _ = 1, 20 do plate:Wheel(-1, 0, 0) end
    Eq(plate.look.goal.f, f0, "the zoom passed the fitted view")
    -- Out at the fit, the view stays where the wheel took it (no jump back
    -- to the road), kept on the map.
    local fhw0 = (446 - 20) / 2 / (f0 * 1002)
    Check(plate.look.goal.cx ~= c0x and plate.look.goal.cx >= fhw0 - 1e-9 and plate.look.goal.cx <= 1 - fhw0 + 1e-9,
        "zoomed out, the fitted view jumped or left the map: " .. plate.look.goal.cx)
    Check(math.abs(plate.look.goal.cy - 0.5) < 1e-9, "zoomed out, the fit is not the zone's whole height")
    Check(plate.window[1] == 0 and plate.window[3] == 1, "on the way out to the fit, the zone was not drawn whole")
    pivot.scripts.OnUpdate(pivot, FZ.time)
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    Check(plate.window[1] == 0 and plate.window[3] == 1, "back at the fit, the zone was not drawn whole round it")
    -- Zoomed in, a drag pans (kept on the map) and does not go back.
    plate:Wheel(1, 0, 0)
    plate:Wheel(1, 0, 0)
    pivot.scripts.OnUpdate(pivot, FZ.time)
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    local cx = plate.look.cx
    local at = { 0, 0 }
    plate.CursorScreen = function() return at[1], at[2] end
    clip.scripts.OnMouseDown(clip, "LeftButton")
    at[1] = 30
    clip.scripts.OnUpdate(clip, 0.016)
    Check(plate.look.cx < cx, "a drag to the right did not pan the map with it")
    for _ = 1, 50 do
        at[1] = at[1] + 400
        clip.scripts.OnUpdate(clip, 0.016)
    end
    local hw = (446 - 20) / 2 / (plate.look.f * 1002)
    Check(plate.look.cx >= hw - 1e-9, "a drag panned past the map's edge")
    clip.scripts.OnMouseUp(clip, "LeftButton")
    Eq(page.mode, "full", "a drag went back")
    Check(clip.scripts.OnUpdate == nil and pivot.scripts.OnUpdate, "the drag did not let go and wait to draw sharp")
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    -- The wheel turned while the map is held: the new zoom is drawn at
    -- once, and the drag goes on over it; only a new zoom, not the pan.
    local before = plate.look.redraws or 0
    at[1], at[2] = 0, 0
    clip.scripts.OnMouseDown(clip, "LeftButton")
    plate:Wheel(-1, 0, 0)
    Check(plate.look.goal.f > plate.look.fit, "a notch out from the art's own size went back to fitted")
    Eq(plate.look.redraws, before + 1, "a new zoom was not drawn while the map was held")
    Check(plate.window[1] == 0 and plate.window[3] == 1, "drawn while held, the zone was not drawn whole")
    Check(plate.look.pressed and clip.scripts.OnUpdate, "drawn while held, the drag was let go")
    pivot.scripts.OnUpdate(pivot, FZ.time)
    at[1] = -30
    clip.scripts.OnUpdate(clip, 0.016)
    local held = plate.look.cx
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    Eq(plate.look.redraws, before + 1, "held, a pan was drawn again")
    at[1] = -60
    clip.scripts.OnUpdate(clip, 0.016)
    Check(plate.look.cx > held, "after the drawing, the drag did not go on panning")
    clip.scripts.OnMouseUp(clip, "LeftButton")
    Eq(page.mode, "full", "a drag over a drawing went back")
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    Eq(plate.look.redraws, before + 2, "let go, the pan was not drawn again")
    -- Held still after a pan's drawing: nothing drawn while held.
    clip.scripts.OnMouseDown(clip, "LeftButton")
    at[1] = -100
    clip.scripts.OnUpdate(clip, 0.016)
    Check(pivot.scripts.OnUpdate == nil, "a pan alone started a drawing while held")
    clip.scripts.OnMouseUp(clip, "LeftButton")
    pivot.scripts.OnUpdate(pivot, FZ.settle)
    -- A press that hardly moves is a click: back.
    at[1], at[2] = 0, 0
    clip.scripts.OnMouseDown(clip, "LeftButton")
    at[1] = DRAG.threshold - 1
    clip.scripts.OnUpdate(clip, 0.016)
    clip.scripts.OnMouseUp(clip, "LeftButton")
    Eq(page.mode, "plates", "a click on a zoomed full page did not go back")
    -- Opened again: fitted.
    ns.UI.OpenZoneSheet(1412)
    look = plate.look
    Check(math.abs(look.f - f0) < 1e-9 and look.cx == look.c0[1], "the full page did not open fitted again")
    -- Fitted, a drag pans too (the zone runs past the card's sides) and
    -- does not go back.
    do
        local cx0 = look.cx
        local fat = { 0, 0 }
        plate.CursorScreen = function() return fat[1], fat[2] end
        clip.scripts.OnMouseDown(clip, "LeftButton")
        fat[1] = 30
        clip.scripts.OnUpdate(clip, 0.016)
        Check(plate.look.cx < cx0, "fitted, a drag to the right did not pan the map with it")
        Check(math.abs(plate.look.f - f0) < 1e-9, "fitted, a drag zoomed")
        for _ = 1, 50 do
            fat[1] = fat[1] + 400
            clip.scripts.OnUpdate(clip, 0.016)
        end
        local fhw = (446 - 20) / 2 / (f0 * 1002)
        Check(plate.look.cx >= fhw - 1e-9, "fitted, a drag panned past the map's edge")
        Check(math.abs(plate.look.cy - 0.5) < 1e-9, "fitted, a drag moved the zone's whole height")
        clip.scripts.OnMouseUp(clip, "LeftButton")
        Eq(page.mode, "full", "fitted, a drag went back")
        pivot.scripts.OnUpdate(pivot, FZ.settle)
        Check(plate.window[1] == 0 and plate.window[3] == 1, "panned fitted, the zone was not drawn whole round it")
        ns.UI.OpenZoneSheet(1412)
        look = plate.look
    end
    -- Drawn again or put away mid-wheel or mid-drag: nothing left running.
    plate:Wheel(1, 0, 0)
    pivot.scripts.OnUpdate(pivot, FZ.time / 2)
    ns.UI.RedrawJourneyPage()
    Check(pivot.scripts.OnUpdate == nil and content.recorded.calls.SetScale[1] == 1
        and math.abs(plate.look.f - f0) < 1e-9, "drawn again mid-wheel, the zoom stuck")
    plate:Wheel(1, 0, 0)
    pivot.scripts.OnUpdate(pivot, FZ.time / 2)
    clip.scripts.OnMouseDown(clip, "LeftButton")
    plate:Hide()
    Check(pivot.scripts.OnUpdate == nil and clip.scripts.OnUpdate == nil and plate.look == nil,
        "put away mid-zoom, something stuck")
    ns.UI.OpenZoneSheet(1412)
    -- A click on a mark goes back too.
    local mark = plate.hover[1]
    mark.scripts.OnMouseDown(mark, "LeftButton")
    mark.scripts.OnMouseUp(mark, "LeftButton")
    Eq(page.mode, "plates", "a click on a mark of the full page did not go back")
    ns.UI.OpenZoneSheet(1412)
    plate.CursorScreen = function() return 0, 0 end
end

said = Tooltips(plate)
-- At this scale the fight and the session are one spot: the fight on top.
Check(Any(said, "^Won a fight") or Any(said, "^Beat"), "the fight mark's tooltip")
Check(Any(Tips(plate), "|With Bram Redfen|"), "the shared mark's tooltip does not say who")
-- Only the open level is drawn, and the next level where it ended.
Check(Any(said, "^Level 11"), "the pin at level 10's end has no tooltip")
Check(not Any(said, "^Flew to The Barrens"), "level 11's flight is on level 10's map")
Check(Any(said, "Red Rocks"), "the stop's tooltip")

-- Level 11's own Mulgore: its pin, and none of level 10's meetings.
Open(11)
row = RowFor(function(item) return item.zone and item.entry == 2 and item.mapID == 1412 end)
row:Click()
Eq(plate.counts.pins, 1, "the level reached here has no pin")
Check(plate.pinMarks[1].start, "where level 11 began is not drawn in ink round paper")
Eq(plate.counts.meetings, 0, "level 10's meetings are inked on level 11")
Eq(plate.counts.flights, 1, "the flight out was not drawn")
Check(plate.counts.dashes > 0, "the flight to another zone has no dashes toward it")
said = Tooltips(plate)
Check(Any(said, "^Level 11"), "the level pin's tooltip")
Check(not Any(said, "^With Bram Redfen"), "level 10's meeting is on level 11's map")
Check(Any(said, "^Flew to The Barrens"), "the flight's tooltip")

-- The zone row under level 11 for The Barrens.
row = RowFor(function(item) return item.zone and item.entry == 2 and item.mapID == 1413 end)
row:Click()
Eq(plate.mapID, 1413, "the zone row did not turn to its zone")
Eq(plate.counts.dungeons, 1, "the dungeon has no door at its entry spot")
Eq(plate.counts.flights, 1, "the flight in was not drawn")
said = Tooltips(plate)
Check(Any(said, "^Wailing Caverns"), "the dungeon's tooltip")
Check(Any(said, "^Flew in from Mulgore"), "the landing's tooltip")

-- The full page opens nothing new: it never leans in.
do
    local clip = plate.clip
    clip.mouseOver = true
    clip.scripts.OnEnter(clip)
    Check(clip.scripts.OnUpdate == nil and plate.zoom == 0, "the full page leans in")
    Check(not plate.leans, "the full page leans in")
    clip.mouseOver = false
end

-- A zone without art is plain paper, and still the road.
ns.UI.OpenZoneSheet(2665)
Check(plate:IsShown(), "the artless zone's full page did not open")
Eq(page.open, 3, "the artless zone did not open at the level that was there")
Check(not plate.hasArt and plate.tileCount == 0, "art was printed for a zone without any")
Eq(plate.counts.stops, 1, "the artless zone's stop was not inked")

-- A zone the road never touched says so, without errors.
ns.UI.OpenZoneSheet(1454)
Eq(plate.counts.stops + plate.counts.roads + plate.counts.meetings, 0, "marks on a zone with no road")
Eq(page.foot.meta:GetText(), "Nothing of your road is on this map yet.", "an empty full page says nothing")

-- Turning to another page and back: the plates go with the page, and it
-- opens again at the newest level's plates.
ns.UI.OpenZoneSheet(1412)
J.ribbons.people:Click()
Check(not J.views.journey:IsShown(), "Your Diary stayed open past its page")
J.ribbons.journey:Click()
Eq(page.mode, "plates", "turning back did not open the plates")

-- Flat paper: no turn, no glue, no lift; the corners lie flat. The same
-- trail, its quads still on their corners.
ns.SetSetting("flatSheets", true)
ns.UI.OpenZoneSheet(1412)
Check(plate.flat and plate.turn == 0, "laid flat, the plate is turned")
Eq(plate.counts.glue, 0, "laid flat, the plate is glued")
Eq(plate.counts.lift, 0, "laid flat, a corner is lifted")
Eq(plate.counts.corners, 3, "laid flat, the photo corners are gone")
Check(plate.counts.roads > 0 and plate.counts.quads > 0, "laid flat, the road was not drawn")
Eq(plate.counts.fallback, 0, "laid flat, the quads fell back")
ns.SetSetting("flatSheets", false)
ns.UI.OpenZoneSheet(1412)
Check(plate.turn ~= 0 and plate.counts.glue > 0 and plate.counts.lift > 0, "glued again, no turn, glue or lift")
Eq(plate.counts.corners, 3, "the photo corners glued again")

-- Where the client cannot move corners, every piece is a turned rectangle,
-- the photo corners an L of strips, and a texture bent before has its
-- corners put back as it is placed (K.Place). The mock keeps only a
-- method's last call: count them here.
local roadLayer = ns.UI.InkTrail.LAYER.road
local bent
for _, w in ipairs(mock.frames) do
    if w.frameType == "Texture" and w.recorded.sublevel == roadLayer and w.bent and w:IsShown() then
        bent = w
        break
    end
end
Check(bent, "no road quad was bent")
local offsets, SetVertexOffset = {}, bent.SetVertexOffset
bent.SetVertexOffset = function(self, corner, x, y)
    offsets[#offsets + 1] = { corner, x, y }
    return SetVertexOffset(self, corner, x, y)
end
plate.canBend = false
ns.UI.RedrawJourneyPage()
Check(plate.counts.fallback > 0 and plate.counts.fallback >= plate.counts.quads,
    "without corners, the quads did not fall back to rectangles")
Check(plate.counts.roads > 0 and bent:IsShown(), "without corners, the road was not drawn")
Eq(plate.counts.corners, 3 * 2, "without corners, the photo corners are not L strips")
Eq(#offsets, 4, "the bent texture's corners were not put back")
local zeroed = {}
for _, o in ipairs(offsets) do
    if o[2] == 0 and o[3] == 0 then zeroed[o[1]] = true end
end
Check(zeroed[1] and zeroed[2] and zeroed[3] and zeroed[4] and not bent.bent, "a texture bent before kept its corners")
plate.canBend = true
bent.SetVertexOffset = SetVertexOffset

--------------------------------------------------------------------------
Section("bounded: a long road is capped, its step grown, one seamless line")

local pts = {}
for i = 0, 1999 do
    pts[#pts + 1] = 0.25 + 0.5 * (i % 100) / 100
    pts[#pts + 1] = 0.1 + 0.8 * math.floor(i / 100) / 20
end
Seg({ kind = "road", from = t0 + 10000, to = t0 + 12000, mapID = 1412, levelFrom = 12, levelTo = 12, pts = pts })
ns.Journey.Touch()
ns.UI.RefreshJourneyPage(false)
Open(12)
ns.UI.OpenZoneSheet(1412)
Eq(page.open, 3, "the long road's level")
Check(plate.counts.quads <= ns.UI.InkTrail.CAP.quads, "the road pieces passed their cap")
Check(plate.counts.step > ns.UI.InkTrail.ROAD.step, "a long road's step did not grow")
-- Consecutive pieces of a road share their edges: breaks only between
-- roads, or where a road hands over to a pool.
local shared, breaks, previous = 0, 0, nil
for _, prim in ipairs(plate.prims) do
    if prim.k == "q" and prim.layer == ns.UI.InkTrail.LAYER.road then
        if previous then
            if math.abs(previous.x2 - prim.x1) < 1e-9 and math.abs(previous.y2 - prim.y1) < 1e-9
                and math.abs(previous.x3 - prim.x4) < 1e-9 and math.abs(previous.y3 - prim.y4) < 1e-9 then
                shared = shared + 1
            else
                breaks = breaks + 1
            end
        end
        previous = prim
    end
end
Check(shared > 100 and breaks <= 2 * plate.counts.roads,
    ("the road's pieces do not share their edges: %d shared, %d breaks"):format(shared, breaks))

--------------------------------------------------------------------------
Section("the ink trail: ground sets the size, time the ink; droplets, pins, marks apart")

local Ink = ns.UI.InkTrail
mock.mapNames[1411], mock.mapArt[1411] = "Durotar", true
local t1 = t0 + 20000
-- Durotar's road, within the middle of the map the full page shows.
local function X(x) return 0.2 + 0.5 * x end
local function Stop(x, y, seconds, act, subZone, shape, r)
    local seg = Seg({ kind = "stop", from = t1, to = t1 + seconds, mapID = 1411, x = X(x), y = y, r = r or 20,
        seconds = seconds, act = act, subZone = subZone, levelFrom = 12, levelTo = 12 })
    if shape then seg.sdx, seg.sdy, seg.rho = shape[1], shape[2], shape[3] end
    t1 = t1 + seconds + 60
    return seg
end
-- A road walked in to the fight's spot, ending on it.
Seg({ kind = "road", from = t1, to = t1 + 60, mapID = 1411, levelFrom = 12, levelTo = 12,
    pts = { X(0.05), 0.05, X(0.12), 0.12, X(0.2), 0.2 } })
t1 = t1 + 60
local fought = Stop(0.2, 0.2, 200, { combat = 120 }, "Razor Hill", { 0.01, 0.01, 0 })
local quest = Stop(0.45, 0.35, 40, { questsIn = 1 }, "Quest Giver Camp")
Stop(0.4505, 0.3505, 35, { questsOut = 1 })  -- the same quest giver again: part of it
local rest = Stop(0.6, 0.5, 600, { resting = 500 }, "Razor Hill Inn", { 0.02, 0.006, 0.4 })
local stayed = Stop(0.8, 0.65, 300, nil, nil)
local died = Stop(0.2, 0.8, 90, { combat = 60, deaths = 1 }, "Tiragarde Keep")
-- Same time, different ground; same ground, different time.
local wide = Stop(0.3, 0.55, 600, nil, "Wide", { 0.025, 0.025, 0 })
local narrow = Stop(0.75, 0.3, 600, nil, "Narrow", { 0.005, 0.005, 0 })
local hour = Stop(0.5, 0.85, 3600, { combat = 2400 }, "Long grind", { 0.01, 0.01, 0 })
local brief = Stop(0.85, 0.85, 300, { combat = 200 }, "Short fight", { 0.01, 0.01, 0 })
local minute = Stop(0.65, 0.15, 60, nil, "A minute", { 0.01, 0.01, 0 })
-- Saved before shapes were kept: only its radius in yards.
local old = Stop(0.1, 0.45, 600, nil, "Old camp", nil, 300)
j.levels[13] = { at = t1, mapID = 1411, x = X(0.8), y = 0.65 }  -- reached right on a pool
ns.Journey.Touch()
ns.UI.OpenZoneSheet(1411)
Eq(plate.counts.stops, 12, "every stop was not considered")
Eq(plate.counts.areas, 11, "the same quest giver twice is not one pool")
Eq(plate.pools, plate.areas, "the pools are not also the areas")
local by = {}
for _, pool in ipairs(plate.pools) do by[pool.seg] = pool end
for _, key in ipairs({ "quads", "dots", "dabs", "pools", "droplets", "stops", "areas", "roads", "step", "flights",
    "dashes", "pins", "pinsMoved", "meetings", "dungeons", "labels", "marks", "fallback", "textures" }) do
    Check(type(plate.counts[key]) == "number", "the plate does not count its " .. key)
end

-- Short stops without a death are droplets: one dot of tint, a tooltip.
local drop = by[quest]
Check(drop and drop.droplet and drop.kind == "questing", "a 40 s quest stop is not a droplet")
Eq(drop.more, 1, "the second visit is not counted in the droplet")
Check(by[minute].droplet, "a minute's stay is not a droplet")
Check(by[died] and not by[died].droplet, "a stop with a death became a droplet")
local dropDiscs, deathless = 0, true
for _, pool in ipairs(plate.pools) do
    deathless = deathless and pool.droplet == (pool.seconds < Ink.POOL.droplet and pool.deaths == 0)
end
Check(deathless, "a droplet is not exactly a short stay without a death")
for _, prim in ipairs(plate.prims) do
    if prim.of == drop then dropDiscs = dropDiscs + 1 end
end
Eq(dropDiscs, 1, "a droplet is not one dot")
said = Tooltips(plate)
Check(Any(said, "^Quest Giver Camp"), "the droplet has no tooltip")
Check(Any(said, "^Razor Hill$") and Any(said, "^Razor Hill Inn"), "the pools have no tooltips")
-- No key on the plates: each pool's ink in words (Decision 7).
local tips = Tips(plate)
Check(Any(tips, "^Razor Hill Inn|Rested here, 10 min|"), "a rested pool's tooltip: " .. table.concat(tips, " / "))
Check(Any(tips, "^Quest Giver Camp|Quested here, under a minute|"), "a droplet's tooltip says its ink")
Check(Any(tips, "^Long grind|Fought here, 1 h"), "a fought pool's tooltip")

-- Ground sets the size, at true scale: 2 sigma of the spread in pixels,
-- and r over root 2 at the map's yards for an old stop.
local fullW, fullH = plate.fullW, plate.fullH
Check(math.abs(fullH - (484 - 20)) < 1e-6 and math.abs(fullW / fullH - 1002 / 668) < 1e-6,
    "the full page's scale is not the zone's height")
Check(math.abs(by[wide].e.a1 - 2 * 0.025 * fullW) < 0.01 and math.abs(by[wide].e.a2 - 2 * 0.025 * fullH) < 0.01,
    "the wide pool is not its measured spread at 2 sigma: " .. by[wide].e.a1)
Check(math.abs(by[narrow].e.a1 - 2 * 0.005 * fullW) < 0.01, "the narrow pool is not its spread at 2 sigma")
Check(by[wide].e.a1 * by[wide].e.a2 > 4 * by[narrow].e.a1 * by[narrow].e.a2,
    "a wide stop is not bigger than a narrow one of the same time")
local yards = ns.Journey.MapYards(1411) or Ink.FOOT.yards
Check(math.abs(by[old].e.a1 - 300 / math.sqrt(2) * fullW / yards) < 0.01 and by[old].e.a1 == by[old].e.a2,
    "an old stop is not r / root 2 at the map's yards: " .. by[old].e.a1)
for _, pool in ipairs(plate.pools) do
    Check(pool.e.a1 >= 3 and pool.e.a2 >= 3 and pool.e.a1 <= 40 and pool.e.a1 <= 4 * pool.e.a2 + 1e-9,
        "a footprint outside its least, most or aspect")
end

-- Time never touches the ground: a minute, five and an hour on the same
-- spread are the same size. It goes into the ink.
local long, short = by[hour], by[brief]
Check(long.e.a1 == short.e.a1 and long.e.a2 == short.e.a2, "an hour's pool is larger than five minutes'")
Check(by[minute].e.a1 == long.e.a1 and by[minute].e.a2 == long.e.a2, "a minute's footprint is not an hour's")
Check(long.T > short.T + 0.3, ("an hour is not inked darker: %.2f against %.2f"):format(long.T, short.T))
local function Ink_(pool)
    local passes, wash = 0, 0
    for _, prim in ipairs(plate.prims) do
        if prim.of == pool and prim.layer == Ink.LAYER.dab then passes = passes + 1 end
        if prim.of == pool and prim.layer == Ink.LAYER.wash then wash = prim.a end
    end
    return passes, wash
end
local longPasses, longWash = Ink_(long)
local shortPasses, shortWash = Ink_(short)
Check(longPasses > shortPasses and longWash > shortWash, "a long stay has no more passes or a paler wash")

-- No pool's ink leaves its ground: no disc past its footprint by more
-- than its anti-aliased edge; a fight's streaks reach 12 % past it.
local worst, streak = -math.huge, 0
for _, prim in ipairs(plate.prims) do
    local e = prim.of and prim.of.e
    if e and prim.k == "d" then
        for k = 0, 15 do
            local a = 2 * math.pi * k / 16
            local c, s = math.cos(prim.th), math.sin(prim.th)
            local u, v = prim.rx * math.cos(a), prim.ry * math.sin(a)
            local x, y = prim.x + u * c - v * s, prim.y + u * s + v * c
            -- Along the ray from the middle: never less than the true gap.
            local dx, dy = x - e.x, y - e.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 1e-9 and prim.of.e.a1 == prim.of.e.a2 then
                worst = math.max(worst, d - Ink.Extent(e, dx / d, dy / d))
            end
        end
    elseif e and prim.k == "q" then
        Eq(prim.of.kind, "fighting", "a pool's quad that is not a fight's streak")
        for k = 1, 4 do streak = math.max(streak, Ink.Reach(e, prim["x" .. k], prim["y" .. k])) end
    end
end
Check(worst <= Ink.POOL.edge + 1e-6, ("a dab reached %.2f px past its footprint"):format(worst))
Check(streak > 1 and streak <= Ink.POOL.streak + 0.05, "a fight's streaks: " .. streak)

-- The spread's form: the inn's pool along its measured angle, longer than wide.
local sx, sy = 0.02 * fullW, 0.006 * fullH
local A2, C2, B2 = sx * sx, sy * sy, 0.4 * sx * sy
local inn = by[rest]
Check(math.abs(inn.e.theta - 0.5 * math.atan2(2 * B2, A2 - C2)) < 1e-6, "the pool is not turned to the spread")
Check(inn.e.a1 > 1.5 * inn.e.a2 and inn.e.a1 <= 4 * inn.e.a2 + 0.01, "the pool's aspect is not the data's")
Check(by[stayed].e.a1 == by[stayed].e.a2, "a stop without a shape is not round")

-- The same trail every drawing.
local firstPrims = {}
for i = 1, math.min(80, #plate.prims) do firstPrims[i] = { plate.prims[i].x or plate.prims[i].x1, plate.prims[i].a } end
ns.UI.OpenZoneSheet(1411)
by = {}
for _, pool in ipairs(plate.pools) do by[pool.seg] = pool end
local same = true
for i, f in ipairs(firstPrims) do
    local prim = plate.prims[i]
    same = same and (prim.x or prim.x1) == f[1] and prim.a == f[2]
end
Check(same, "the trail moved between drawings")

-- A sparse zone's only stop stays its own size.
mock.mapNames[1447] = "Feralas"
local lone = Seg({ kind = "stop", from = t1, to = t1 + 1800, mapID = 1447, x = 0.5, y = 0.5, r = 20,
    seconds = 1800, sdx = 0.003, sdy = 0.003, rho = 0, levelFrom = 12, levelTo = 12 })
t1 = t1 + 1900
ns.Journey.Touch()
ns.UI.OpenZoneSheet(1447)
Check(plate.pools[1].seg == lone and plate.pools[1].e.a1 < 6, "a sparse zone's only stop was inflated")
ns.UI.OpenZoneSheet(1411)
by = {}
for _, pool in ipairs(plate.pools) do by[pool.seg] = pool end

-- No kind's glyph on a plate (at close-up scale they read as letters):
-- the ink's tint and the pool's tooltip say what was done there.
for _, pool in ipairs(plate.pools) do Check(pool.glyph == nil, "a pool on a plate has a glyph") end
Eq(plate.counts.glyphs, nil, "the plate counts glyphs it does not draw")
-- A death's cross just outside at the upper left.
local dead = by[died]
local ddx, ddy = dead.cx - dead.e.x, dead.cy - dead.e.y
Check(ddx < 0 and ddy < 0 and Ink.Reach(dead.e, dead.cx, dead.cy) > 1, "the death's cross is not outside at the upper left")
Eq(plate.counts.labels, 0, "the pools are named on the map")

-- Marks never touch: each keeps its room, so none reads as a letter
-- beside another (9 Oct, in the client: "O8", "14" over "1").
local function Touching(p)
    local list = p.spots
    for i = 1, #list do
        for k = i + 1, #list do
            local a, b = list[i], list[k]
            local d = math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
            if d < a[3] + b[3] then return ("%.1f,%.1f and %.1f,%.1f"):format(a[1], a[2], b[1], b[2]) end
        end
    end
    return nil
end
Check(#plate.spots >= 2, "the marks were not spaced")
Eq(Touching(plate), nil, "two marks touch on Durotar")
-- Another level's pin on the same spot is not drawn at all.
local pinsBefore = plate.counts.pins
j.levels[14] = { at = t1 + 10 * DAY, mapID = 1411, x = X(0.8), y = 0.65 }
ns.Journey.Touch()
ns.UI.OpenZoneSheet(1411)
Eq(plate.counts.pins, pinsBefore, "another level's pin is drawn")
j.levels[14] = nil
ns.Journey.Touch()
ns.UI.OpenZoneSheet(1411)

-- The level pin reached right on the quiet pool moved out past its footprint.
Eq(plate.counts.pinsMoved, 1, "the pin on a pool was not moved off it")
local mark = plate.pinMarks[1]
Check(mark.host and mark.host.seg == stayed, "the pin's pool")
Check(Ink.Reach(mark.host.e, mark.x, mark.y) > 1, "the moved pin still lies on its pool")

-- The words for the tooltips.
Eq(ns.UI.JourneyText.StopLabel(fought, 200), "Razor Hill \194\183 3 min", "a stop's short form")
local _, lines = ns.UI.JourneyText.Stop(quest, now, 1)
local joined = table.concat(lines, "|")
Check(joined:find("Took a quest") and joined:find("one more short stay"), "the droplet's tooltip: " .. joined)

-- A busy zone: hundreds of stops and a dense road stay within the caps.
mock.mapNames[1441] = "Thousand Needles"
local t2 = t0 + 40000
local dense = {}
for i = 0, 1499 do
    dense[#dense + 1] = 0.2 + 0.6 * (i % 50) / 49
    dense[#dense + 1] = 0.05 + 0.9 * math.floor(i / 50) / 29
end
Seg({ kind = "road", from = t2, to = t2 + 3000, mapID = 1441, levelFrom = 12, levelTo = 12, pts = dense,
    act = { combat = 300 } })
t2 = t2 + 3000
for i = 1, 450 do
    local act = i % 3 == 0 and { combat = 20 } or (i % 3 == 1 and { questsIn = 1 } or nil)
    Seg({ kind = "stop", from = t2, to = t2 + 40 + i, mapID = 1441, x = 0.21 + 0.58 * (i % 25) / 24,
        y = 0.04 + 0.92 * math.floor((i - 1) / 25) / 17, r = 15, seconds = 40 + i, act = act,
        levelFrom = 12, levelTo = 12 })
    t2 = t2 + 300
end
ns.Journey.Touch()
ns.UI.OpenZoneSheet(1441)
local cap = Ink.CAP
Eq(plate.counts.stops, cap.stops, "the stops passed their cap")
Check(plate.counts.areas <= cap.stops and plate.counts.areas > 50, "the pools of a busy zone")
Check(plate.counts.droplets > 0 and plate.counts.pools > 0,
    ("a busy zone: %d droplets, %d pools"):format(plate.counts.droplets, plate.counts.pools))
Check(plate.counts.quads <= cap.quads and plate.counts.dots <= cap.dots and plate.counts.dabs <= cap.dabs,
    ("a cap was passed: %d quads, %d dots, %d dabs"):format(plate.counts.quads, plate.counts.dots, plate.counts.dabs))
Check(plate.counts.dabs > cap.dabs - Ink.POOL.perPool, "the busy zone did not reach its dabs: " .. plate.counts.dabs)
Check(plate.counts.step > Ink.ROAD.step, "the dense road's step did not grow")
Eq(plate.counts.labels, 0, "a busy zone's pools are named on the map")
Check(plate.hover.used <= 200 + plate.counts.pins + plate.counts.meetings + plate.counts.flights + 10,
    "more hover squares than the cap")

-- A small plate takes its share of the caps (JRN-21).
do
    local small = ns.UI.JourneyPlate(page.right, { x = 0, y = 0, w = 214, h = 138, t = 2, pad = 7, pc = 20,
        corners = {}, lift = "bl" })
    local share = ns.UI.JourneyPlate.Share(small.slot)
    small:Draw(ns.JourneyRecap.SheetFor(SELF.guid, 1441), page.recap.entries[3],
        ns.UI.JourneyPlate.Window(1441, 0.5, 0.5, 200, 124, true), { cap = share })
    Check(small.counts.quads <= math.floor(cap.quads * share) and small.counts.dabs <= math.floor(cap.dabs * share)
        and small.counts.stops <= math.floor(cap.stops * share),
        ("a small plate passed its share: %d quads, %d dabs"):format(small.counts.quads, small.counts.dabs))
    Eq(small.counts.corners, 0, "a plate held by glue alone has corners")
    Check(small.counts.glue > 0 and small.counts.lift > 0, "a glued plate's glue and lifted corner")
end

-- /sd journey reports the plates on the page and their textures.
local printed, AddMessage = {}, DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) printed[#printed + 1] = tostring(msg) end
SlashCmdList.SOCIALDIARY("journey")
DEFAULT_CHAT_FRAME.AddMessage = AddMessage
Check(Any(printed, ("plate 1, Thousand Needles: drawn in [%%d.]+ ms; %d textures; %d quads, %d dots, %d dabs"):format(
    plate.counts.textures, plate.counts.quads, plate.counts.dots, plate.counts.dabs)),
    "/sd journey does not report the plate's drawing")
Check(Any(printed, "right page: a zone's full page"), "/sd journey does not say what the right page shows")

--------------------------------------------------------------------------
Section("states: no road kept, the setting off, weeks past the cap (JRN-12, JRN-17, JRN-21)")

-- A level the route never saw: no plate, one faded line.
j.levels[9] = nil
ns.Journey.Touch()
ns.UI.RefreshJourneyPage()
local quiet = { kind = "level", level = 99, from = now, to = now, places = {}, stops = {}, dungeons = {}, flights = {},
    people = {}, fights = {}, notes = {}, deaths = {}, seconds = 0, faces = {}, hindsight = {} }
table.insert(page.recap.entries, quiet)
page.entries:SetOffset(0)
ns.UI.RefreshJourneyPage(false)
do
    local i = #page.recap.entries
    page.open = i
    ns.UI.RedrawJourneyPage()
end
Eq(page.layout, 0, "a level with no road has a plate")
Check(page.nothing:IsShown() and page.nothing:GetText() == "Nothing of this level's road was kept.",
    "a level with no road does not say so")
Check(not page.plates[1]:IsShown(), "a plate stayed up for a level with no road")
table.remove(page.recap.entries)
page.open = #page.recap.entries
ns.UI.RedrawJourneyPage()
Check(not page.nothing:IsShown(), "the nothing-kept line stayed")

ns.JourneyCapture.SetEnabled(false)
ns.UI.RefreshJourneyPage()
Eq(page.state, "entries", "the road kept so far was hidden with the setting off")
Check(page.off:IsShown() and page.keep:IsShown(), "the page does not say the road is not being kept")
Eq(page.off.recorded.points[1].args[3], 246, "the not-kept line is not under the plates")
page.keep:Click()
Eq(ns.db.settings.keepRoute, true, "Keep it again did not switch the setting on")
Check(not page.off:IsShown(), "the not-kept line stayed")

mock.maxLevel = 12
ns.Journey.Touch()
ns.UI.RefreshJourneyPage()
local week = false
for _, item in ipairs(page.items) do
    if item.title and item.title:find("^WEEK OF") then week = true end
end
Check(week, "past the cap, the entries are not by week")
Eq(page.recap.entries[page.open].kind, "week", "past the cap, the page does not open at the newest week")
Check(page.layout >= 1, "a week has no plates")
ns.UI.OpenZoneSheet(1441)
Click(page.plates[1])
Eq(page.mode, "plates", "a week's full page does not go back to its plates")
Eq(page.recap.entries[page.open].kind, "week", "a week's full page went back to another entry")
mock.maxLevel = 60

--------------------------------------------------------------------------
Section("a page by its plates' weights: a light place is a small print (plate-weight proposal)")

-- The page is picked by the plates' weights in time order (F full, L
-- light), as LayoutFor reads them: FL, LF and FLF, FFL, LFF, LFL have a
-- page of their own; any other pattern is the page for that many plates.
-- Here on plates as Recap.Plates gives them, each one spot (a span of
-- nothing holds in any slot) unless `spread` (px of art across) says.
do
    local Look = ns.UI.JourneyLook
    local LAYOUT, LayoutFor = Look.LAYOUT, Look.LayoutFor
    local perPx = ns.UI.JourneyPlate.Cover(1412, 1, 1)
    local function Plates(weights, spread)
        local list = {}
        for i = 1, #weights do
            list[i] = { mapID = 1412, x0 = 0.5, x1 = 0.5 + (spread and spread[i] or 0) * perPx, y0 = 0.5, y1 = 0.5,
                light = weights:sub(i, i) == "L" }
        end
        return list
    end
    for _, key in ipairs({ "FL", "LF", "FLF", "FFL", "LFF", "LFL" }) do
        local layout, got = LayoutFor(Plates(key))
        Eq(got, key, "the pattern of " .. key)
        Check(layout == LAYOUT[key] and layout ~= LAYOUT[#key], key .. " does not have its own page")
        Eq(#layout, #key, key .. "'s slots")
        -- A light plate's slot is a snapshot, 176 by 124 (its art 162 by
        -- 110); a full one's is a 256 to 260 px column.
        for i, slot in ipairs(layout) do
            local light = key:sub(i, i) == "L"
            if light then
                Eq(slot.w .. "x" .. slot.h .. "/" .. slot.pad, "176x124/7", key .. "'s print " .. i)
            else
                Check(slot.w >= 256 and slot.w <= 260 and slot.h > 124, key .. "'s full slot " .. i .. ": " .. slot.w)
            end
            Check(slot.cap and slot.cap.w >= 176, key .. "'s caption " .. i .. " is narrower than a print")
        end
    end
    -- The tucked page is FL's to try, not a pattern of its own.
    Check(LAYOUT.FL.tucked == LAYOUT["F+L"], "FL does not try the tucked page")
    local tucked = LAYOUT["F+L"]
    Check(tucked[1].whole and #tucked[1].row == 2 and tucked[2].w == 140 and tucked[2].h == 100,
        "the tucked page is not a plate over a row of two with a print beside it")
    -- Unlisted patterns: the page for that many, as before; one plate,
    -- light or not, is the one plate's page with its `top`.
    for _, key in ipairs({ "F", "L", "FF", "LL", "FFF", "FLL", "LLF", "LLL" }) do
        local layout, got = LayoutFor(Plates(key))
        Eq(got, key, "the pattern of " .. key)
        Check(layout == LAYOUT[#key], key .. " is not the page for " .. #key .. " plates")
    end
    Check(LAYOUT[1][1].top, "the one plate's page lost its caption over the plate")
    -- A light plate a snapshot cannot hold (a level's pin far from the
    -- first spot) is drawn full: FL becomes FF, LFL becomes FFL.
    local wide = 0.8 * 162 + 6
    local layout, got = LayoutFor(Plates("FL", { 0, wide }))
    Eq(got, "FF", "a light plate too wide for a print is not drawn full")
    Check(layout == LAYOUT[2], "FL with a wide light plate is not the two-plate page")
    layout, got = LayoutFor(Plates("LFL", { wide, 0, 0 }))
    Eq(got, "FFL", "the first light plate too wide for a print is not drawn full")
    Check(layout == LAYOUT.FFL, "LFL with its first print too wide is not FFL's page")
    -- A full plate wider than its slot holds: no page at this window (the
    -- plates are grouped again, smaller).
    Eq(LayoutFor(Plates("FL", { 0.8 * 244 + 6, 0 })), nil, "a full plate too wide for FL's slot")
    Eq(select(2, LayoutFor({})), "", "no plates, no pattern")
end

-- On the page: a fresh road at level 12, the open level. Mulgore with
-- Bram (a full plate), then Zephras Isle, a first visit and a stay (a
-- light one).
do
    local Look = ns.UI.JourneyLook
    local LAYOUT = Look.LAYOUT
    local perPx = select(2, ns.UI.JourneyPlate.Cover(1412, 1, 1))
    -- Each road begins after the last one's sessions, so none of them is
    -- settled on the new road.
    local t5 = now - 60000
    local function Road(places, extra)
        t5 = t5 + 8000
        ns.db.journey[SELF.guid] = nil
        j = ns.Journey.Begin(SELF.guid, t5, 12, places[1])
        local t = t5
        for i, mapID in ipairs(places) do
            if i > 1 then
                Seg({ kind = "flight", from = t, to = t + 300, mapID1 = places[i - 1], x1 = 0.5, y1 = 0.5,
                    mapID2 = mapID, x2 = 0.5, y2 = 0.5, levelFrom = 12, levelTo = 12 })
                t = t + 300
            end
            local x, y = mapID == 1412 and 0.40 or 0.5, mapID == 1412 and 0.60 or 0.5
            Seg({ kind = "stop", from = t, to = t + 1800, mapID = mapID, x = x, y = y, r = 30, seconds = 1800,
                levelFrom = 12, levelTo = 12 })
            if mapID == 1412 then
                ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t + 600, endedAt = t + 1500,
                    participants = { [A] = { since = t + 600, last = t + 1500, seconds = 900, levelStart = 12 } } })
                if extra then extra(t) end
            end
            t = t + 1800
        end
        ns.Journey.Touch()
        ns.UI.RefreshJourneyPage(false)
        return Open(12)
    end
    local function Slots()
        local list = {}
        for i = 1, page.layout do list[i] = page.plates[i].slot end
        return list
    end

    -- FL, with its print tucked in (F+L): the caption short, Bram's strip
    -- in the row, both plates held by the tucked page's windows.
    local e = Road({ 1412, 2665 })
    Eq(page.layout, 2, "a full plate and a light one")
    Eq(e.pattern, "FL", "Mulgore with Bram, then a first visit, is not FL")
    Check(e.layout == LAYOUT.FL, "the entry does not keep FL's page")
    Eq(page.pattern, "F+L", "FL's print is not tucked in under a short caption")
    local slots = Slots()
    Check(slots[1] == LAYOUT["F+L"][1] and slots[2] == LAYOUT["F+L"][2], "the tucked page's slots")
    Check(page.plates[1].captionOver, "the tucked page's caption is not over its plate")
    Check(page.plates[2].captionOver == false, "the print's caption is not under it")
    Eq(page.notesWritten, 1, "Bram's strip in the row")
    Check(page.plates[1].captionFoot < LAYOUT["F+L"][1].y, "the caption runs onto the plate")
    -- The print, drawn small: its art 128 by 88, held by photo corners,
    -- its lifted corner's shadow on the page.
    local print = page.plates[2]
    Eq(print.mapID, 2665, "the print is not of Zephras Isle")
    Check(print.counts.corners > 0 and print.counts.lift > 0, "the print has no corners or no lifted corner")
    local W = print.window
    Check(math.abs((W[3] - W[1]) - 128 * ns.UI.JourneyPlate.Cover(2665, 1, 1)) < 1e-9, "the print's window")
    Eq(page.layout, 2, "the page's layout is not its count of plates")

    -- (a) A caption that will not stay short: FL, decided once.
    local Text = ns.UI.JourneyText
    local real = Text.PlateCaption
    Text.PlateCaption = function(p, ...)
        local text = real(p, ...)
        if p.mapID ~= 1412 then return text end
        return text .. " And then the road went on a long way, past the mill and over the hill and home."
    end
    local heights = {}
    for i = 1, page.captionPool.used do
        heights[i] = page.captionPool[i].GetStringHeight
        page.captionPool[i].GetStringHeight = function(self)
            local width = (self.width or 0) > 0 and self.width or 1e9
            return self.text ~= "" and 14 * math.ceil(#self.text * 6 / width) or 0
        end
    end
    ns.UI.RedrawJourneyPage()
    Eq(page.pattern, "FL", "a long caption kept the tucked page")
    slots = Slots()
    Check(slots[1] == LAYOUT.FL[1] and slots[2] == LAYOUT.FL[2], "a long caption's FL is not FL's page")
    Check(not page.plates[1].captionOver, "a long caption is over the plate")
    Eq(page.notesWritten, 1, "Bram's strip beside the plate")
    Text.PlateCaption = real
    for i = 1, #heights do page.captionPool[i].GetStringHeight = heights[i] end
    ns.UI.RedrawJourneyPage()
    Eq(page.pattern, "F+L", "a short caption again does not tuck the print in")

    -- (b) Something of the full plate's margin with no room in the row
    -- (the page's foot just under it): FL, where nothing is left off for
    -- the print's sake.
    local C = Look.CAPTION
    local limit, offLimit = C.limit, C.offLimit
    C.limit, C.offLimit = LAYOUT["F+L"][1].row[1].y + 10, LAYOUT["F+L"][1].row[1].y + 10
    ns.UI.RedrawJourneyPage()
    Eq(page.pattern, "FL", "the tucked page kept with its margin left off")
    Check(page.plates[1].slot == LAYOUT.FL[1] and not page.plates[1].captionOver, "the margin left off is not FL")
    C.limit, C.offLimit = limit, offLimit
    ns.UI.RedrawJourneyPage()
    Eq(page.pattern, "F+L", "the row with room again does not tuck the print in")

    -- (c) A full plate taller than the tucked page's window but held by
    -- FL's: a fight 224 px of art under the stay (FL's art is 302 tall,
    -- the tucked plate's 258; a plate's moments span 0.8 of it at most).
    e = Road({ 1412, 2665 }, function(t)
        ns.Journey.Fight(j, "won", nil, t + 900, { mapID = 1412, x = 0.40, y = 0.60 + 224 * perPx })
    end)
    Eq(e.pattern, "FL", "setup: the tall plate's pattern")
    Eq(#e.plates[1].moments >= 3 and e.plates[1].y1 - e.plates[1].y0 > 0.8 * 258 * perPx, true,
        "setup: the fight is not on the plate, or not far enough")
    Eq(page.pattern, "FL", "a plate the tucked page cannot hold was tucked")
    Check(page.plates[1].slot == LAYOUT.FL[1] and page.plates[2].slot == LAYOUT.FL[2], "the tall plate's FL")

    -- LF: the first visit first; and three plates, LFL.
    e = Road({ 2665, 1412 })
    Eq(page.pattern, "LF", "a first visit, then Mulgore with Bram, is not LF")
    slots = Slots()
    Check(slots[1] == LAYOUT.LF[1] and slots[2] == LAYOUT.LF[2], "LF's slots")
    Eq(page.plates[1].slot.w, 176, "LF's print is not a snapshot")
    e = Road({ 2665, 1412, 1413 })
    Eq(page.layout, 3, "three places, three plates")
    Eq(page.pattern, "LFL", "light, full, light is not LFL")
    slots = Slots()
    Check(slots[1] == LAYOUT.LFL[1] and slots[2] == LAYOUT.LFL[2] and slots[3] == LAYOUT.LFL[3], "LFL's slots")
    Eq(page.plates[1].mapID .. "," .. page.plates[2].mapID .. "," .. page.plates[3].mapID, "2665,1412,1413",
        "the plates are not in time order")
end

--------------------------------------------------------------------------
Section("a plate's marks by kind (Plate.RegisterMark)")

do
    local Plate = ns.UI.JourneyPlate
    local kinds = {}
    for _, spec in ipairs(Plate.MARK_ORDER) do kinds[#kinds + 1] = spec.kind end
    Eq(table.concat(kinds, " "), "find finale skill close luck fortune duel campfire", "the registered marks' draw order")
    Check(Plate.MARKS.fortune.order < Plate.ROAD_DEATHS and Plate.ROAD_DEATHS < Plate.MARKS.campfire.order,
        "the deaths on the road are not drawn between good luck and the fires")
    for kind, key in pairs({ find = "finds", finale = "finales", skill = "skills", close = "closeCalls",
        luck = "hunts", fortune = "fortunes", campfire = "campfires" }) do
        Eq(Plate.CAP[key], Plate.MARKS[kind].cap, kind .. "'s cap is not in CAP under " .. key)
    end

    -- A kind registered after this file loaded, as a feature's is: drawn
    -- in its order, merged on a spot, capped, counted, kept (with its
    -- arg) and chosen; a moment of it that is someone's too joins their
    -- marks (`join`).
    local drawn = {}
    Plate.RegisterMark("tested", { order = 45, cap = 1, count = "tested", radius = 6, halo = 14, hover = 15,
        keep = "testedMarks", chosen = "tested",
        tip = function(m) return "Tested " .. m.n end,
        arg = function(list) return #list end,
        join = function(m) return m.joins end,
        choose = function(marks) return marks[1] end,
        draw = function(kit, x, y, n)
            drawn[#drawn + 1] = { x, y, n }
            kit.Dot(kit.ink, x, y, 6, kit.INK_STRONG, 1)
        end })
    Eq(Plate.MARK_ORDER[6].kind, "tested", "a kind at 45 is not drawn between bad and good luck")
    Eq(Plate.CAP.tested, 1, "the kind's cap is not in CAP")

    local mapID = 1441
    local perX, perY = Plate.Cover(mapID, 1, 1)
    local moments = {
        { kind = "tested", mapID = mapID, x = 0.5, y = 0.5, t = now, n = 1 },
        { kind = "tested", mapID = mapID, x = 0.5 + 2 * perX, y = 0.5, t = now, n = 2, joins = true },
        { kind = "tested", mapID = mapID, x = 0.5 + 40 * perX, y = 0.5 + 20 * perY, t = now, n = 3 },
    }
    local p = Plate(page.right, { x = 0, y = 0, w = 214, h = 138, t = 0, pad = 7, pc = 20, corners = {} })
    p:Draw(ns.JourneyRecap.SheetFor(SELF.guid, mapID), nil, Plate.Window(mapID, 0.5, 0.5, 200, 124),
        { moments = moments })
    Eq(#drawn, 1, "the kind's cap of one mark")
    Eq(drawn[1] and drawn[1][3], 2, "two moments on one spot are not one mark, its arg from both")
    Eq(p.counts.tested, 1, "the kind's count")
    Eq(#p.testedMarks, 1, "the kind's marks are not kept")
    Eq(#p.testedMarks[1].list, 2, "the kept mark's moments")
    Check(type(p.testedMarks[1].at[1]) == "number", "the kept mark has no place on the page")
    Eq(p.testedMarks[1].arg, 2, "the kept mark does not keep its arg")
    local joined = p.where[moments[2]]
    Check(joined and joined[1] == p.testedMarks[1].at[1] and joined[2] == p.testedMarks[1].at[2],
        "a moment that joins a person's marks is not kept at its mark (plate.where)")
    Eq(p.where[moments[1]], nil, "a moment that does not join is kept with the people's marks")
    local inPeople = 0
    for _, m in ipairs(p.people) do
        if m == moments[2] then inPeople = inPeople + 1 elseif m == moments[1] then inPeople = inPeople + 10 end
    end
    Eq(inPeople, 1, "only the moment that joins is among the plate's people")
    Check(p.tested == p.testedMarks[1], "the kind's card is not chosen")
    Check(Any(Tips(p), "^Tested 1|Tested 2$"), "the mark's tooltip does not tell each moment")
    local room
    for _, s in ipairs(p.spots) do
        if s[1] == drawn[1][1] and s[2] == drawn[1][2] then room = s[3] end
    end
    Eq(room, 6, "the mark does not claim its radius")

    -- Gone again, so nothing after this draws it: out of the order, its
    -- cap with it, and off the plate drawn again.
    Plate.RemoveMark("tested")
    kinds = {}
    for _, spec in ipairs(Plate.MARK_ORDER) do kinds[#kinds + 1] = spec.kind end
    Eq(table.concat(kinds, " "), "find finale skill close luck fortune duel campfire", "the kind taken out stayed")
    Eq(Plate.MARKS.tested, nil, "the kind taken out is still registered")
    Eq(Plate.CAP.tested, nil, "the kind taken out left its cap")
    drawn = {}
    p:Draw(ns.JourneyRecap.SheetFor(SELF.guid, mapID), nil, Plate.Window(mapID, 0.5, 0.5, 200, 124),
        { moments = moments })
    Eq(#drawn, 0, "the kind taken out is still drawn")
    Eq(p.counts.tested, nil, "the kind taken out is still counted")

    -- The core's marks stand at their fixed turns among the kinds (the
    -- registry's core entries): a door before a kind ordered before all,
    -- and the deaths on the road after a kind at their own number. The
    -- first down keeps its spot; the later steps aside (Apart).
    local at = {}
    Plate.RegisterMark("early", { order = -1000, cap = 5, count = "early",
        draw = function(_, x, y) at.early = { x, y } end })
    Plate.RegisterMark("tied", { order = Plate.ROAD_DEATHS, cap = 5, count = "tied",
        draw = function(_, x, y) at.tied = { x, y } end })
    local road = { kind = "road", mapID = mapID }
    local spot = { 0.5, 0.5 }
    local other = { 0.5 + 60 * perX, 0.5 + 30 * perY }
    local function Marks(list)
        at = {}
        p:Draw(ns.JourneyRecap.SheetFor(SELF.guid, mapID), nil, Plate.Window(mapID, 0.5, 0.5, 200, 124),
            { moments = list })
        return at
    end
    local EARLY = { kind = "early", mapID = mapID, x = spot[1], y = spot[2], t = now }
    local DOOR = { kind = "dungeon", mapID = mapID, x = spot[1], y = spot[2], t = now, seg = { name = "A door" } }
    local TIED = { kind = "tied", mapID = mapID, x = other[1], y = other[2], t = now }
    local DEATH = { kind = "death", mapID = mapID, x = other[1], y = other[2], t = now, seg = road }
    local alone = Marks({ EARLY, TIED })
    local function Moved(a, b) return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) > 1 end
    Marks({ DEATH })
    Check(p.crosses[1] ~= nil, "a death on the road drew no cross")
    local crossAlone = { p.crosses[1].x, p.crosses[1].y }
    local both = Marks({ EARLY, DOOR, TIED, DEATH })
    Check(both.early and both.tied and p.crosses[1], "the marks for the order were not drawn")
    Check(Moved(both.early, alone.early), "a kind ordered before all did not step aside from a core door")
    Check(not Moved(both.tied, alone.tied), "a kind at the road deaths' number stepped aside from them")
    Check(Moved({ p.crosses[1].x, p.crosses[1].y }, crossAlone),
        "the deaths on the road did not step aside from a kind at their own number")
    Plate.RemoveMark("early")
    Plate.RemoveMark("tied")
    Eq(Plate.MARKS.early or Plate.MARKS.tied, nil, "the order's kinds are still registered")
    p:Hide()
end

Section("a flight master is one ring, every flight drawn from it")

do
    local Plate = ns.UI.JourneyPlate
    local mapID = 1412   -- Mulgore in the mock: 5000 yards across, 3333 down
    local function Sheet(flights)
        return { mapID = mapID, stops = {}, roads = {}, flights = flights, dungeons = {}, pins = {}, meetings = {} }
    end
    local t = now - 4000
    local function Flight(m1, x1, y1, m2, x2, y2)
        t = t + 600
        return { kind = "flight", from = t, to = t + 300, mapID1 = m1, x1 = x1, y1 = y1, mapID2 = m2, x2 = x2,
            y2 = y2, levelFrom = 12, levelTo = 12 }
    end
    -- One flight master: two take-offs a few yards apart (the last spot
    -- seen before the taxi) and a landing a little way off its feet, all
    -- to and from one spot in The Barrens.
    local flights = {
        Flight(mapID, 0.500, 0.500, 1413, 0.50, 0.30),
        Flight(1413, 0.50, 0.30, mapID, 0.506, 0.497),
        Flight(mapID, 0.497, 0.504, 1413, 0.50, 0.30),
    }
    local p = Plate(page.right, { x = 0, y = 0, w = 214, h = 138, t = 0, pad = 7, pc = 20, corners = {} })
    local window = Plate.Window(mapID, 0.5, 0.5, 200, 124)
    p:Draw(Sheet(flights), nil, window, { moments = {} })
    Eq(p.counts.flightNodes, 1, "three flights from one flight master are not one ring")
    Eq(p.counts.flights, 3, "the flights with a ring on the plate")
    Eq(p.hover.used, 1, "the flight master's ring has more than one hover")
    local rings = 0
    for _, s in ipairs(p.spots) do
        if s[3] == Plate.FLIGHT.ring / 2 + 1 then rings = rings + 1 end
    end
    Eq(rings, 1, "more than one ring was placed (Apart)")
    local node = p.flightNodes[1]
    Eq(#node.flights, 3, "the ring does not keep every flight")
    Eq(#p.flightLines, 3, "a flight has no line")
    local dashed = 0
    for i, line in ipairs(p.flightLines) do
        Check(line.node == node and line.x1 == node.x and line.y1 == node.y,
            "flight " .. i .. "'s dashes do not start at the ring")
        dashed = dashed + line.dashes
    end
    Check(p.flightLines[1].dashes > 0, "the route to The Barrens is not dashed")
    Eq(dashed, p.flightLines[1].dashes, "one route flown three times is dashed more than once")
    Eq(p.counts.dashes, dashed, "the dashes counted")
    local tips = Tips(p)
    Eq(#tips, 1, "the ring has no tooltip")
    local _, out = (tips[1] or ""):gsub("Flew to The Barrens", "")
    local _, back = (tips[1] or ""):gsub("Flew in from The Barrens", "")
    Check(out == 2 and back == 1, "the ring's tooltip does not tell each flight: " .. tostring(tips[1]))
    Check((tips[1] or ""):find("^Flew to The Barrens|"), "the ring's tooltip is not in time order")

    -- A second flight master 300 yards off, flown to within the zone: its
    -- own ring, and the flight's dashes from one ring into the other.
    flights[4] = Flight(mapID, 0.502, 0.499, mapID, 0.56, 0.45)
    p:Draw(Sheet(flights), nil, window, { moments = {} })
    Eq(p.counts.flightNodes, 2, "two flight masters are not two rings")
    Eq(p.hover.used, 2, "a ring each, a hover each")
    local line = p.flightLines[4]
    local a, b = p.flightNodes[1], p.flightNodes[2]
    Check(line and line.x1 == a.x and line.y1 == a.y and line.x2 == b.x and line.y2 == b.y,
        "the flight within the zone is not dashed from ring to ring")
    Check(line and line.dashes > 0, "the flight within the zone has no dashes")
    tips = Tips(p)
    Check(Any(tips, "|A flight|") or Any(tips, "^A flight|"), "the flight within the zone is not told at its ring")

    -- A third master just past FLIGHT.node yards: its own ring, which
    -- lands on the first and steps aside (Apart); its flight's dashes
    -- start where the ring went, not where it belonged.
    flights[5] = Flight(mapID, 0.512, 0.500, 1413, 0.50, 0.30)
    p:Draw(Sheet(flights), nil, window, { moments = {} })
    Eq(p.counts.flightNodes, 3, "a master 60 yards off is not its own ring")
    local c = p.flightNodes[3]
    local cx, cy = p.At(c.mx, c.my)
    Check(c.x and math.abs(c.x - cx) + math.abs(c.y - cy) > 1, "the third ring did not step aside")
    line = p.flightLines[5]
    Check(line and line.x1 == c.x and line.y1 == c.y, "a ring stepped aside, its flight's dashes start where it was")
    p:Hide()
end

ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a level by sitting: its sittings under its rubric, a page each (.claude/sittings-plan.md)")

-- /sd testdata's weeks past the cap were played over several sittings
-- (read from its route's gaps); its levels each in one.
SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
do
    local YD = ns.UI.YourDiary
    local Text = ns.UI.JourneyText
    local entries = page.recap.entries
    local n = #entries
    local newest = entries[n]
    local function Lines(key)
        local list = {}
        for _, item in ipairs(page.items) do
            if item[key] then list[#list + 1] = item end
        end
        return list
    end
    local function Shows(row)
        page.entries:SetOffset(0)
        for k, item in ipairs(page.items) do
            if item == row then page.entries:SetOffset(math.max(0, k - 2)) end
        end
        return RowFor(function(item) return item == row end)
    end

    -- Fallen open on the newest week's newest sitting.
    Eq(page.open, n, "setup: the newest week open")
    Eq(newest.spliced, false, "setup: the newest week was played over several sittings")
    Check(#newest.pieces >= 2, "setup: the newest week has its sittings")
    local sits = Lines("sitting")
    Eq(#sits, #newest.pieces, "a line for each sitting of the open week")
    for k, item in ipairs(sits) do
        Eq(item.sitting, k, "the sittings oldest first")
        Eq(item.label, Text.SittingLabel(newest.pieces[k], page.now), "a sitting's line is its date")
        Eq(item.entry, n, "a sitting's line is the open week's")
        Eq(item.aside, newest.pieces[k].current and "so far" or nil, "\"so far\" on the sitting being played alone")
    end
    Eq(page.items[page.rubrics[n] + 1], sits[1], "the sittings straight under the rubric, over the prose")
    Eq(sits[#sits].chosen, true, "the newest sitting is the open one")
    Eq(sits[#sits].current, true, "and inked under: its plates are on the right page")
    Eq(newest.plates, nil, "a week read by sitting is never drawn whole")
    Check(newest.pieces[#newest.pieces].plates ~= nil, "the newest sitting's plates are drawn")

    -- The tick in the margin at the sitting open, on its row alone.
    local row = Shows(sits[#sits])
    Check(row and row.tick:IsShown() and row.zone:GetText() == sits[#sits].label, "the open sitting is not ticked")
    -- An older sitting with plates of its own.
    local at
    for k = 1, #newest.pieces - 1 do
        if not at and #YD.PlatesOf(newest.pieces[k]) > 0 then at = k end
    end
    Check(at ~= nil, "setup: an older sitting with plates")
    row = Shows(sits[at])
    Check(row and not row.tick:IsShown(), "a sitting not open is ticked")

    -- A sitting's line opens that sitting's plates.
    row:Click()
    Eq(page.piece, at, "a sitting's line does not open that sitting")
    Eq(page.mode, "plates", "a sitting opens on its plates")
    local first = newest.pieces[at]
    Eq(page.layout, #first.plates, "the right page is not the sitting's plates")
    Eq(page.plates[1].plan, first.plates[1], "the first plate drawn is not the sitting's")
    Eq(Lines("sitting")[at].chosen, true, "the sitting opened is not the one ticked")

    -- Its zone's whole map stays the week's, and the way back is to it.
    local mapID = first.plates[1].mapID
    Click(page.plates[1])
    Eq(page.mode .. ":" .. tostring(page.fullMap), "full:" .. mapID, "a sitting's plate does not open its zone's map")
    Eq(page.piece, at, "the full page forgot the sitting open")
    Click(page.plates[1])
    Eq(page.mode, "plates", "the full page did not go back to the plates")
    Eq(page.piece, at, "the full page went back to another sitting than the one open")
    Eq(page.plates[1].plan, first.plates[1], "back, the plates are not the sitting's")

    -- A rubric opens its newest sitting, never a run.
    YD.OpenLevel(n)
    Eq(page.piece, #newest.pieces, "a rubric does not open its newest sitting")
    Eq(page.mode, "plates", "a rubric opened a run")

    -- A level played in one sitting is spliced: no lines, drawn whole.
    local spliced
    for i, e in ipairs(entries) do
        if e.kind == "level" and not spliced then
            YD.PiecesOf(e)
            if e.spliced then spliced = i end
        end
    end
    Check(spliced ~= nil, "setup: a level played in one sitting")
    YD.OpenLevel(spliced)
    Eq(#Lines("sitting") + #Lines("run"), 0, "a spliced level lists its sittings")
    Check(entries[spliced].plates ~= nil, "a spliced level is not drawn whole")
    -- Nor does a closed entry list any.
    YD.OpenLevel(n)
    for _, item in ipairs(Lines("sitting")) do Eq(item.entry, n, "a closed entry lists its sittings") end

    -- Runs: a line under the sitting they began in, indented, each a run
    -- with a boss killed (RunWorthy).
    local holder, visit
    for k, p in ipairs(newest.pieces) do
        if p.runs[1] and not visit then holder, visit = k, p.runs[1] end
    end
    Check(visit ~= nil, "setup: a sitting of the newest week has a run")
    local runs = Lines("run")
    local line
    for k, item in ipairs(page.items) do
        if item.run == visit then line = k end
    end
    Check(line ~= nil, "a run has no line")
    local above = line and line - 1
    while above and above > 0 and page.items[above].run do above = above - 1 end
    Eq(above and page.items[above].sitting, holder, "a run's line is not under its sitting")
    for _, item in ipairs(runs) do
        Check(ns.JourneyRecap.RunWorthy(item.run), "a run with no boss killed has a line")
    end
    row = Shows(page.items[line])
    Check(row and row.door[1]:IsShown() and row.zone:GetText() == (visit.name or "An instance"),
        "a run's line is not its dungeon's name behind a doorway")
    row:Click()
    Eq(page.mode .. ":" .. tostring(page.runVisit), "run:" .. visit.id, "a run's line does not open its page")
    Eq(page.piece, holder, "a run's page is not in its sitting")

    -- Its boss kills taken away: no line, no page; its ledger row opens
    -- the dungeon's map instead.
    local kills, inferred = visit.bossesKilled, visit.inferred
    visit.bossesKilled, visit.inferred = {}, nil
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(false)
    YD.OpenLevel(#page.recap.entries)
    for _, item in ipairs(Lines("run")) do Check(item.run.id ~= visit.id, "a run with no boss killed has a line") end
    for _, p in ipairs(page.recap.entries[#page.recap.entries].pieces) do
        for _, v in ipairs(p.runs) do Check(v.id ~= visit.id, "a run with no boss killed is a sitting's page") end
    end
    local ledger
    for _, item in ipairs(page.items) do
        if item.zone and item.zone.dungeon and item.zone.dungeon.visit and item.zone.dungeon.visit.id == visit.id then
            ledger = item
        end
    end
    Check(ledger ~= nil, "setup: the run's row in the ledger")
    if ledger then
        row = Shows(ledger)
        row:Click()
        Eq(page.mode .. ":" .. tostring(page.fullMap), "full:" .. tostring(ledger.mapID),
            "a run with no boss killed: its ledger row does not open the dungeon's map")
    end
    YD.OpenRun(visit.id)
    Check(page.mode ~= "run", "OpenRun opened a run with no boss killed")
    visit.bossesKilled, visit.inferred = kills, inferred
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(false)
end
ns.UI.CloseJournal()
