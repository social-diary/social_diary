-- The person's page as laid (the person-page proposal, variant A,
-- "Clippings", and the person-header proposal, layout B): the header written
-- on the page, its name on an arc, scrolling with the list, and every strip,
-- slip and card as wide as its words.
--
-- The mock measures every string at about 6 px a character, whatever its
-- font, so the checks here compare a piece's writing with the room inside
-- it, never with fixed pixels.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local function Near(a, b, d) return math.abs(a - b) <= (d or 0.01) end
local function Width(text) return ns.UI.Surface.Width(text) end

mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local J = ns.UI.Journal
local P = _G.SocialDiaryJournalFrame.profile
local H = ns.UI.PersonHeader
local SHEET = H.SHEET
local h = P.header
Check(P:IsShown() and h, "the test entry's page is not open")

--------------------------------------------------------------------------
Section("the header is written on the page and scrolls with the list")

local EDGE = -J.BOOK.TOP
local NAME, WHO, GOOD = H.NAME, H.WHO, H.GOOD
local DIARY_ENTRY = ns.Diary.Get(G)
local RECORD = ns.People.Stats(G).record
-- No paper, no clip: nothing of the old sheet is left to draw.
for _, gone in ipairs({ "paper", "edge", "sheen", "grain", "dent", "clip", "clipShadow", "shadows", "edit" }) do
    Eq(h[gone], nil, "the header still has its " .. gone)
end
-- The list starts at the paper's top edge, its first writing under the header.
Eq(SHEET.listTop, EDGE, "the list does not start at the paper's top edge")
Eq(P.timeline.recorded.points[1].args[4], -SHEET.listTop, "the list is not placed at its top")
Eq(ns.UI.Clippings.BLOCK.pad, SHEET.first - SHEET.listTop, "the top block does not start under the header")
Check(WHO.y + WHO.h <= SHEET.first, "the who line runs into the first writing")
-- Centred on the ink: the name's letters at 27 to the who line's foot.
local inkTop, inkFoot = NAME.baseline - GOOD.ascent * 27, WHO.y + WHO.h / 2 + WHO.ink
Check(Near(H.PORTRAIT.y + H.PORTRAIT.size / 2, (inkTop + inkFoot) / 2), "the portrait is not centred on the name and who line")
Eq(H.PORTRAIT.y, 2.5, "the portrait's place moved")
Check(H.PORTRAIT.y >= EDGE and H.PORTRAIT.y + H.PORTRAIT.size <= SHEET.first, "the portrait is off its place")
-- The header is on the list, on the line that holds the block, so it goes
-- when that line does and comes back with it.
Eq(h.sheet.parent, P.timeline, "the header is not on the list")
local held = h.row
Check(held and held.item and held.item.clippings, "the header is not on the list's first line")
local at = h.sheet.recorded.points[#h.sheet.recorded.points]
Eq(at.args[1], held, "the header is not anchored to its line")
Eq(at.args[4], SHEET.listTop, "the header is not at the page's frame on its line")
Check(h.sheet:IsShown(), "the header does not show")
P.timeline:SetPosition(ns.UI.Clippings.BLOCK.pad + 400)
Eq(h.row, nil, "the header stayed when its line scrolled away")
Check(not h.sheet:IsShown(), "the header still shows, scrolled away")
P.timeline:SetPosition(0)
Check(h.row and h.sheet:IsShown(), "the header did not come back")
-- The scrollbar starts under the writing.
Eq(P.timeline.bar.recorded.points[#P.timeline.bar.recorded.points - 1].args[4], -(SHEET.first - SHEET.listTop),
    "the scrollbar does not start under the header")

--------------------------------------------------------------------------
Section("the arc")

local Near1 = function(a, b) return Near(a, b, 0.0001) end
Check(Near1(H.ArcAngle(0), -5), "the arc does not start at -5 degrees")
Check(Near1(H.ArcAngle(0.30), -1), "the arc is not at -1 degree at 0.30")
Check(Near1(H.ArcAngle(1), 0), "the arc does not end level")
Check(Near1(H.ArcAngle(0.15), -3), "the arc is not a straight line to its middle stop")
Check(Near1(H.ArcAngle(0.65), -0.5), "the arc is not a straight line from its middle stop")

-- By UTF-8 sequence, not by byte.
local L1 = H.Letters("Zoë Ñandú")
Eq(#L1, 9, "not split by letter")
Eq(L1[3], "ë", "a two-byte letter was split")
Eq(L1[5], "Ñ", "a two-byte capital was split")
Eq(table.concat(L1), "Zoë Ñandú", "letters lost")
Eq(#H.Letters("日本語"), 3, "three-byte letters were split")

-- With kerning by prefixes: a pair that kerns moves the second letter in.
local function Kerned(text)
    local w = #H.Letters(text) * 10
    if text:find("AV", 1, true) then w = w - 2 end
    return w
end
local placed, L = H.ArcPlace(H.Letters("AVA"), Kerned)
Eq(L, 28, "the name's length is not measured whole")
Eq(#placed, 3, "a place a letter")
-- The letters' angles follow the curve, climbing to level.
Check(placed[1].deg < placed[2].deg and placed[2].deg < placed[3].deg, "the arc does not level off")
Check(placed[1].y > placed[3].y, "the name does not climb")
Check(math.abs(placed[3].y + placed[3].adv * math.sin(math.rad(placed[3].deg)) - NAME.baseline) < 1,
    "the name's end is not on its baseline")
Check(placed[2].x - placed[1].x < 10, "kerning was lost")

h:Set(RECORD, "Feivel Emmenthal", "Level 16 Human Warrior", DIARY_ENTRY, false)
Check(h.arced, "the name is not on the arc")
Eq(h.name:GetText(), "Feivel Emmenthal", "the whole name is not kept")
Eq(h.name:GetAlpha(), 0, "the whole name shows under the arc")
Eq(#h.placed, 15, "not a font string a letter, spaces left out")
for i, place in ipairs(h.placed) do
    local letter = h.letters[i]
    Check(letter:IsShown(), "a letter does not show")
    Eq(letter:GetText(), place.letter, "a letter out of place")
    Check(Near(letter.recorded.calls.SetRotation[1], math.rad(-place.deg), 1e-6), "a letter not turned to the curve")
    Check(letter.recorded.calls.SetRotation[1] >= 0, "a letter turned the wrong way")
    local pt = letter.recorded.points[#letter.recorded.points]
    Eq(pt.point, "LEFT", "a letter is not anchored by its left end")
    -- Its line's middle along the normal from its baseline's left end.
    local d = (GOOD.ascent - GOOD.line / 2) * (14 < 27 * GOOD.line and 27 or 14 / GOOD.line)
    local r = math.rad(place.deg)
    Check(Near(pt.args[3], place.x + math.sin(r) * d, 0.01) and Near(-pt.args[4], place.y - math.cos(r) * d, 0.01),
        "a letter is not anchored at its baseline's normal")
    Check(letter.recorded.width > place.adv, "a letter's box is not wider than its advance")
end
Check(not h.letters[16]:IsShown(), "a letter left over from nothing shows")

--------------------------------------------------------------------------
Section("flat: one straight string in the same place")

local arcY = h.name.recorded.points[#h.name.recorded.points].args[4]
ns.SetSetting("flatSheets", true)
h:Set(RECORD, "Feivel Emmenthal", "Level 16 Human Warrior", DIARY_ENTRY, false)
Check(not h.arced, "laid flat, the name still arcs")
Eq(h.name:GetAlpha(), 1, "laid flat, the whole name does not show")
for _, letter in ipairs(h.letters) do Check(not letter:IsShown(), "laid flat, a letter still shows") end
Eq(h.name.recorded.points[#h.name.recorded.points].args[4], arcY, "laid flat, the name moved")
ns.SetSetting("flatSheets", false)
h.turnsText = false
h:Set(RECORD, "Feivel Emmenthal", "Level 16 Human Warrior", DIARY_ENTRY, false)
Check(not h.arced and h.name:GetAlpha() == 1, "where text cannot turn, the name still arcs")
h.turnsText = true
-- More letters than the pool: straight, not cut.
h:Set(RECORD, ("Thistle"):rep(4), "Level 16 Human Warrior", DIARY_ENTRY, false)
Check(not h.arced and h.name:GetAlpha() == 1, "a name past the pool is not straight")
h:Set(RECORD, "Feivel Emmenthal", "Level 16 Human Warrior", DIARY_ENTRY, false)
Check(h.arced, "the arc did not come back")

--------------------------------------------------------------------------
Section("the who line and the tags")

local record16 = { level = 16, race = "Human", class = "WARRIOR", faction = "Alliance" }
Eq(ns.UI.Format.WhoLine(record16, nil, "always"), "Level 16 Human Warrior", "the faction on the header's who line")
ns.Characters.Get(G).faction = "Alliance"
ns.UI.RefreshJournal()
Check(not h.who:GetText():find("Alliance", 1, true), "the page's who line still names the faction: " .. h.who:GetText())
-- Other readers still get it.
Check(ns.UI.Format.WhoLine(record16):find("Alliance", 1, true), "the faction went from the other who lines")

-- The chips after the who line, on its middle; the relationship on the
-- name's line at the right.
local tags, relationship = DIARY_ENTRY.tags, DIARY_ENTRY.relationship
DIARY_ENTRY.tags, DIARY_ENTRY.relationship = { "friend", "guild" }, "Good Guy"
h:Set(RECORD, "Feivel Emmenthal", "Level 16 Human Warrior", DIARY_ENTRY, false)
Eq(h.shownTags, 2, "the tags are not shown")
Check(math.abs(h.tagsBox[3] - h.whoBox[3]) <= 1, "the tags are not centred on the who line")
Eq(h.tagsBox[1], WHO.x + h.whoBox[2] + H.TAGS.clear, "the tags do not follow the who line")
Check(h.tagsBox[2] <= SHEET.right, "the tags run off the page")
Check(h.relationship:IsShown(), "the relationship does not show")
Eq(h.relationship.recorded.points[#h.relationship.recorded.points].args[3], SHEET.right, "the relationship is not at the right")
-- A long who line gives way to them, never the tags.
h:Set(RECORD, "Feivel Emmenthal", "Level 60 Human Warrior <The Exceedingly Long Guild of Westfall Farmers and Friends>",
    DIARY_ENTRY, false)
Eq(h.shownTags, 2, "a long who line pushed a tag off")
Check(h.whoBox[1] + h.whoBox[2] + H.TAGS.clear <= h.tagsBox[1] + 0.5, "a long who line runs into the tags")
Check(h.tagsBox[2] <= SHEET.right + 0.5, "with a long who line the tags ran off the page")
-- A long name takes the room; the relationship is cut at it, or goes.
h:Set(RECORD, ("Thistle"):rep(9), "Level 20 Tauren Druid", DIARY_ENTRY, false)
Check(h.relationship:IsShown(), "a short relationship went beside a long name")
DIARY_ENTRY.relationship = ("A very good friend of mine "):rep(3)
h:Set(RECORD, ("Thistle"):rep(9), "Level 20 Tauren Druid", DIARY_ENTRY, false)
Check(h.relationship:IsShown(), "a long relationship went while it had room")
Eq(h.relationship.recorded.width, SHEET.right - (NAME.x + NAME.room + H.RELATION.gap), "a long relationship not cut at the name")
DIARY_ENTRY.tags, DIARY_ENTRY.relationship = tags, relationship
ns.UI.RefreshJournal()

--------------------------------------------------------------------------
Section("the name steps down and stays in its room")

for _, step in ipairs(NAME.sizes) do
    local size = step[2]
    for _, measured in ipairs({ 0, size, size * GOOD.line, 14 }) do
        local boxTop, lineH, inkTop, inkFoot = H.NameLine(size, measured)
        Check(inkTop >= EDGE, ("the name's ink at %d rises out of the page: %.1f"):format(size, inkTop))
        Check(inkFoot <= WHO.y, ("the name's ink at %d runs into the who line: %.1f"):format(size, inkFoot))
        Check(boxTop + lineH <= WHO.y + 1, ("the name's line at %d runs into the who line"):format(size))
    end
end
local entry = ns.Diary.Get(G)
local record = ns.People.Stats(G).record
h:Set(record, "Bartholomew Thistlewaite", "Level 20 Tauren Druid", entry, false)
Check(Width(h.name) + 2 <= H.NAME.room, "a long name runs past its room")
h:Set(record, ("Bartholomew Thistlewaite "):rep(3), "Level 20 Tauren Druid", entry, false)
Eq(h.nameSize, "personNameLeast", "a name too long for its room is not at the smallest size")
local nameW = h.name.recorded.width
Check(nameW and nameW <= H.NAME.room, "a name too long for its room is laid wider than it")
Check(not h.arced, "a name past its room is arced")
ns.UI.RefreshJournal()

--------------------------------------------------------------------------
Section("the edit tab")

local tab = P.tabEdit
Eq(h.edit, nil, "the Edit link is still on the header")
Check(not tab.selected, "the edit tab is lit on their story")
Eq(tab.recorded.points[1].args[1], P.tabNote, "the edit tab is not with its siblings")
tab:GetScript("OnEnter")(tab)
Eq(GameTooltip.text, "edit", "the edit tab's words")
tab:GetScript("OnLeave")(tab)
tab:Click()
Check(J.editing and P.form:IsShown(), "the edit tab did not turn the page to writing mode")
Check(tab.selected and not P.tabStory.selected and not P.tabMap.selected and not P.tabNote.selected,
    "the tabs do not say writing mode is open")
-- In writing mode the list is away and the header on the page, over the form.
Check(not P.timeline:IsShown(), "the list shows while writing")
Eq(h.sheet.parent, P, "the header is not on the page while writing")
Check(h.sheet:IsShown(), "the header went while writing")
Eq(h.sheet.recorded.points[#h.sheet.recorded.points].args[1], P, "the header is not anchored to the page while writing")
tab:Click()
Check(not J.editing and not tab.selected and P.tabStory.selected, "a second click did not go back to their story")
Eq(h.sheet.parent, P.timeline, "the header did not go back on the list")
Check(h.sheet:IsShown() and h.row, "the header did not come back on its line")
-- From a loose sheet: the sheet goes and stays gone after.
P.tabMap:Click()
tab:Click()
Check(not P.map:IsShown() and tab.selected and not P.tabMap.selected, "the map lay over writing mode")
tab:Click()
Check(not P.map:IsShown() and P.tabStory.selected and not P.tabMap.selected, "the map came back after writing")
-- Anyone else's page leaves writing mode, the tab unlit.
tab:Click()
ns.UI.SelectPerson(G)
Check(not J.editing and not tab.selected, "selecting a person left the edit tab lit")

--------------------------------------------------------------------------
Section("strips, slips and cards as wide as their words")

-- A first meeting long ago (the longest heading: "First met 30 September
-- 2025"), a long note, a long dungeon name.
local first = os.time({ year = 2025, month = 9, day = 30, hour = 18 })
ns.Interactions.Add(G, "trade", { time = first })
entry.note = "Saved me in the Jasperlode mine when the kobolds came round the corner three at a time"
local visit
for _, v in pairs(ns.db.instances) do
    if v.name == "Razorfen Kraul" then visit = v end
end
Check(visit, "no dungeon run in the test data")
visit.name = "The Hall of Thanes and Its Vaults"
ns.Touch()
ns.UI.RefreshJournal()

local CL = P.clippings
local C = ns.UI.Clippings.BLOCK.column
local l, _, r = CL.first:Pad()
local overhang = ns.UI.PersonStrips.LOOK.overhang

Eq(CL.first:Heading(), "First met 30 September 2025", "the long form was not kept where the column has room")
local box = CL.first.box
Check(Width(CL.first.name) + 2 + overhang + l + r <= box[3], "the first-met heading runs to its strip's edge")
Check(box[1] >= C.least and box[1] + box[3] <= C.right, "the first-met strip is off the column")
-- Each strip within the column, its writing inside it.
for _, key in ipairs({ "tally", "level" }) do
    local strip = CL[key]
    if strip:IsShown() then
        Check(strip.box[1] >= C.least and strip.box[1] + strip.box[3] <= C.right, "the " .. key .. " strip is off the column")
    end
end
if CL.tally:IsShown() then
    local need = Width(CL.tally.name) + 2 + overhang + l + r + 9 + ns.UI.PersonStrips.TallyWidth(CL.tally.note.gates or 0)
    Check(need <= CL.tally.box[3] + 0.5, "the tally strip is narrower than its heading and gates")
end

-- Your note: wrapped inside its slip, never to its edge.
local W = ns.UI.PersonStrips.LOOK.written
local note = CL.note
Check(note.writtenLines >= 2, "the long note is not wrapped")
Check(note.widest + W.pad[1] + W.pad[3] + overhang <= note.box[3] + 0.5, "the note's writing runs to its slip's edge")
Check(note.box[1] + note.box[3] <= C.right, "the note's slip runs off the page")
-- Under the facts, never over them.
local lowest = 0
for _, key in ipairs({ "first", "tally", "level" }) do
    if CL[key]:IsShown() then lowest = math.max(lowest, CL[key].box[2] + CL[key].box[4]) end
end
Check(note.box[2] >= lowest, "the note's slip lies over the facts")

-- Where even the short form will not fit, the heading wraps and the strip
-- grows taller, its lines each inside it.
CL.first:SetNote({ name = "First met somewhere beyond the long road to the far side of everything", strong = true,
    seed = "wrap" })
local w1, h1 = CL.first:Layout(C.least, 10, 120)
Check(CL.first.headingLines >= 2, "a heading too long for its strip does not wrap")
Check(Width(CL.first.name) + 2 + overhang + l + r <= w1, "the wrapped heading's first line runs past its strip")
Check(CL.first.under and CL.first.under.w + overhang + l + r <= w1, "the wrapped heading's rest runs past its strip")
CL.first:SetNote({ name = "First met today", strong = true, seed = "wrap" })
local _, h0 = CL.first:Layout(C.least, 10, 120)
Check(h1 > h0, "the wrapped strip did not grow taller")
CL:Forget()
ns.UI.RefreshJournal()

-- A word wider than a slip is broken, not run past its edge.
local slip = ns.UI.PersonStrips.Written(P)
slip:SetNote({ text = ("Thistlewaite"):rep(8), seed = "word" })
slip:Layout(0, 0, 120)
Check(slip.widest + W.pad[1] + W.pad[3] + overhang <= slip.box[3] + 0.5, "a long word runs past its slip")
slip:Hide()

-- The day labels on their strips.
local days = 0
for _, row in ipairs(P.timeline.rows) do
    if row:IsShown() and row.day and row.day:IsShown() then
        days = days + 1
        local dl, _, dr = row.day:Pad()
        Check(Width(row.day.name) + 2 + overhang + dl + dr <= row.day.box[3], "a day's label runs to its strip's edge: "
            .. tostring(row.day.name:GetText()))
    end
end
Check(days > 0, "no day labels on the page")

-- The run's card: its title on one line, as wide as it needs.
local V, card = J.VISIT, nil
for _, line in ipairs(P.timeline.data) do
    if line.visit and line.text == visit.name then card = line end
end
Check(card, "the long dungeon is not on the page")
local info = card.visit
Eq(info.nameTop, nil, "a dungeon name the card has room for wraps")
local m = P.timeline.measure
m:SetFontObject(card.font)
m:SetWidth(0)
m:SetText(card.text)
local titleW = m:GetStringWidth()
local pipsW = ns.Style.PipsWidth(#(info.visit.bossesKilled or {}), info.visit.bossTotal, V.pips)
local inner = info.cardW - (V.padX + V.medallion + V.gutter) - V.padX
Check(titleW + V.overhang + (pipsW > 0 and pipsW + V.spread or 0) <= inner + 0.5,
    "the run's title and its marks do not fit their card")
m:SetFontObject(ns.Style.FONT.small)
m:SetText(info.aside .. "  ·  " .. info.losses)
Check(m:GetStringWidth() <= inner + 0.5, "the run's time and losses do not fit their card")

--------------------------------------------------------------------------
Section("a session's zones: one the client had no name for is left out")

local tl = ns.Timeline.For(G)
local session
for _, item in ipairs(tl) do
    if item.kind == "session" then session = item break end
end
Check(session, "no session on the test timeline")
local zones = session.zones
-- Without the user's road for the stretch, the session's own zones name it.
local road = ns.db.journey
ns.db.journey = {}
session.zones = { "", "Stormwind City", "Elwynn Forest" }
local _, text = ns.UI.DescribeItem(session, G)
Check(text:find(" in Stormwind City and Elwynn Forest", 1, true), "an empty zone is listed: " .. text)
Check(not text:find(" ,", 1, true) and not text:find("through ,", 1, true), "an empty zone left a comma: " .. text)
session.zones = { "", "Mulgore" }
_, text = ns.UI.DescribeItem(session, G)
Check(text:find(" in Mulgore", 1, true), "one named zone among empty ones is not 'in': " .. text)
session.zones = { "" }
_, text = ns.UI.DescribeItem(session, G)
Check(not text:find(" in ", 1, true) and not text:find("through", 1, true), "no named zone still names a place: " .. text)
session.zones = zones
ns.db.journey = road
