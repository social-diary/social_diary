-- The person's page as laid (the person-page proposal, variant A,
-- "Clippings"): the name sheet clipped at the page's top edge, the list
-- passing under it, and every strip, slip and card as wide as its words.
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
local SHEET, CLIP, EDIT = H.SHEET, H.CLIP, H.EDIT
local h = P.header
Check(P:IsShown() and h, "the test entry's page is not open")

--------------------------------------------------------------------------
Section("the name sheet hangs from its clip at the page's top edge")

-- The page's paper runs BOOK.TOP above its frame: its top edge, here.
local EDGE = -J.BOOK.TOP
local tl, tr, br, bl = h.corners[1], h.corners[2], h.corners[3], h.corners[4]
Check(Near(h.turn, math.rad(SHEET.turn)), "the sheet is not turned 1.6 degrees")
Check(tr[2] < tl[2], "its right end does not rise (counter-clockwise)")
Check(tr[2] > EDGE and tr[2] < EDGE + 3, ("its top right corner is not just inside the page's top edge: %.1f"):format(tr[2]))
-- Its inked edge (a px out) inside too.
Check(tr[2] - 1 > EDGE, "the sheet's cut edge runs past the page's top")
Check(tl[2] - EDGE < 16, "the sheet still floats under the page's top at its clip")
Check(tr[1] + 1 <= J.BOOK.RIGHT_W - 8, "the sheet's right end is not well inside the page (the close box is past it)")

-- Only the clip's front shows: its jaw from the page's top edge down to
-- its lip on the sheet, nothing over the edge but a pixel or so of the
-- roll where it turns over (Dev/clip_art.py's EDGE, roll, lip).
local top = h.clipAt[2] - CLIP.size / 2
Check(math.abs(top + CLIP.edge - EDGE) < 1, "the clip's art is not laid with its edge on the page's top edge")
Check(top + CLIP.roll >= EDGE - 1.5, "more of the clip than its roll stands over the page's top edge")
Check(top + CLIP.lip > tl[2] + 2, "the clip's lip does not bite into the sheet")
Check(top + CLIP.lip < tl[2] + 12, "the clip's lip bites too far into the sheet")

-- Edit, straight, on the sheet near its right end, under its top edge.
local function SheetTop(x) return tl[2] + (tr[2] - tl[2]) * (x - tl[1]) / (tr[1] - tl[1]) end
-- (EDIT.y is down the page, as the sheet's corners are.)
Check(EDIT.y > SheetTop(EDIT.x) + 2, "Edit is not on the sheet, under its top edge")
Check(EDIT.x + Width(h.edit.label) + 4 < tr[1], "Edit runs off the sheet's right end")

-- The list starts behind the sheet at every x, and its first writing at
-- the sheet's foot.
Check(SHEET.listTop > math.max(tl[2], tr[2]) + 4, "the list's top is above the sheet")
Check(SHEET.listTop < math.min(bl[2], br[2]) - 4, "the list's top is below the sheet's foot")
Check(SHEET.first >= math.max(bl[2], br[2]), "the list's first line starts over the sheet's foot")
Check(SHEET.first - math.max(bl[2], br[2]) < 6, "the list's first line starts well under the sheet's foot")
Eq(P.timeline.recorded.points[1].args[4], -SHEET.listTop, "the list does not start behind the sheet")
Eq(ns.UI.Clippings.BLOCK.pad, SHEET.first - SHEET.listTop, "the top block does not start at the sheet's foot")

-- Its foot throws its shadow on what passes under it; the wear shows.
for name, t in pairs(h.shadows) do Check(t:IsShown(), "the sheet's " .. name .. " shadow does not show") end
Check(h.dent:IsShown(), "the dent under the clip's jaw does not show")
-- The jaw's mark: under the lip, kept to the clip's corner, clear of the
-- name and over the who line's row; turned with the sheet.
local D = H.DENT
local lipY = CLIP.at[2] - CLIP.size / 2 + CLIP.lip
Check(D.y < lipY and D.y + D.h > lipY + 8, "the dent's box does not reach under the clip's lip")
Check(D.x >= 0 and D.x + D.w <= H.NAME.x - 6, "the dent runs off the sheet or into the name")
Check(D.y + D.h <= H.WHO.y, "the dent runs into the who line's row")
Check(Near(h.dent.recorded.calls.SetRotation[1], h.turn), "the dent is not turned with the sheet")
Check(h.clip:IsShown(), "no clip")
Check(h.clipShadow:IsShown(), "no shadow under the clip")

-- The clip's art: baked, 128 px square, 32 bits (not in every checkout).
local SIZES = { ["Art/Paper/clip.tga"] = { 128, 128 }, ["Art/Paper/clip_shadow.tga"] = { 128, 128 },
    ["Art/Paper/clip_dent.tga"] = { 128, 64 } }
for file, want in pairs(SIZES) do
    local f = io.open(file, "rb")
    if f then
        local head = f:read(18)
        f:close()
        local w, ht = head:byte(13) + 256 * head:byte(14), head:byte(15) + 256 * head:byte(16)
        Eq(head:byte(3), 2, file .. " is not an uncompressed true-colour TGA")
        Check(w == want[1] and ht == want[2] and head:byte(17) == 32, file .. " is not its size in 32 bits")
    end
end

--------------------------------------------------------------------------
Section("laid flat, or where text cannot turn: straight, from the same clip")

ns.SetSetting("flatSheets", true)
h:Lay()
Eq(h.turn, 0, "laid flat, the sheet is turned")
Check(Near(h.corners[1][2], h.corners[2][2]), "laid flat, the sheet's top is not level")
Check(h.corners[2][2] > EDGE and h.corners[3][2] <= SHEET.first, "laid flat, the sheet leaves the page or the list's room")
Check(SHEET.listTop > h.corners[1][2] and SHEET.listTop < h.corners[4][2], "laid flat, the list does not start under the sheet")
Check(not h.clipShadow:IsShown(), "laid flat, the clip still throws a shadow")
Check(not h.dent:IsShown() and not h.corner:IsShown(), "laid flat, the sheet still shows its wear")
Check(h.shadows.core:IsShown() and not h.shadows.soft:IsShown(), "laid flat, not a hair of shadow under the sheet")
Check(h.clip:IsShown(), "laid flat, the clip went")
ns.SetSetting("flatSheets", false)

h.turnsText = false
h:Lay()
Eq(h.turn, 0, "where text cannot turn, the sheet is turned")
Check(h.shadows.soft:IsShown(), "where text cannot turn, the sheet lost its shadow")
h.turnsText = true
h:Lay()
Check(Near(h.turn, math.rad(SHEET.turn)), "the sheet does not turn again")

--------------------------------------------------------------------------
Section("the name's ink inside the sheet at every size")

-- Goodmountain's tall ascenders reach over its line's box: at each size,
-- however the client scales the font (one em to the size, or the line to
-- it), the name's ink lies inside the sheet, clear of its edge and over
-- the who line.
local NAME, WHO, GOOD = H.NAME, H.WHO, H.GOOD
for _, step in ipairs(NAME.sizes) do
    local size = step[2]
    for _, measured in ipairs({ 0, size, size * GOOD.line, 14 }) do
        local boxTop, lineH, inkTop, inkFoot = H.NameLine(size, measured)
        Check(inkTop >= 3, ("the name's ink at %d rises out of the sheet: %.1f"):format(size, inkTop))
        Check(inkFoot <= WHO.y, ("the name's ink at %d runs into the who line: %.1f"):format(size, inkFoot))
        Check(boxTop >= 0 and boxTop + lineH <= WHO.y + 1, ("the name's line at %d is off the sheet"):format(size))
    end
end
Check(WHO.y + WHO.h <= SHEET.h - 2, "the who line runs off the sheet's foot")
Check(H.PORTRAIT.y >= 2 and H.PORTRAIT.y + H.PORTRAIT.size <= SHEET.h - 2, "the portrait is off the sheet")
h:Set(ns.People.Stats(G).record, "Feivel Emmenthal", "Level 20 Tauren Druid", ns.Diary.Get(G), false)
Check(h.nameInk[1] >= 3 and h.nameInk[2] <= WHO.y, "the name as laid is not inside its sheet")
-- The tags on the who line, centred on it (in the sheet's turned plane),
-- right-aligned, well under Edit (its label and dashed underline about 15
-- px from its top).
local diaryEntry = ns.Diary.Get(G)
local tags, relationship = diaryEntry.tags, diaryEntry.relationship
diaryEntry.tags, diaryEntry.relationship = { "friend", "guild" }, nil
h:Set(ns.People.Stats(G).record, "Feivel Emmenthal", "Level 16 Human Warrior", diaryEntry, false)
Eq(h.shownTags, 2, "the tags are not shown")
Check(math.abs(h.tagsBox[3] - h.whoBox[3]) <= 1, "the tags are not centred on the who line")
Check(math.abs(h.tagsBox[2] - (SHEET.w - H.TAGS.right)) < 0.5, "the tags are not at the sheet's right end")
Check(SheetTop(SHEET.x + h.tagsBox[2]) + H.TAGS.y >= EDIT.y + 15 + 8, "the tags crowd Edit")
-- ... and as drawn: the client turns a font string about its left end
-- (its box's left middle) and a texture about its middle, so a wide line
-- of writing laid by its middle is drawn (w/2) sin t off where it was
-- planned. (21 Oct, in the client: the chip sat some 6 px under the
-- who line though the planned middles agreed.) Where each is drawn, from
-- the anchors as recorded, y up from the sheet's middle:
local function Drawn(region)
    local pt = region.recorded.points[1]
    local X, Y = pt.args[3], pt.args[4]
    if region.frameType == "FontString" and pt.point == "CENTER" then X = X - (region.recorded.width or 0) / 2 end
    return X, Y, pt.point
end
local wx, wy = Drawn(h.who)
local cx, cy = Drawn(h.chips[1].edge)
local lx, ly = Drawn(h.chips[1].label)
local slope = math.tan(h.turn)
Check(math.abs(cy - (wy + slope * (cx - wx))) <= 1,
    ("the chip is not drawn on the who line: %.1f px off it"):format(cy - (wy + slope * (cx - wx))))
Check(math.abs(ly - (wy + slope * (lx - wx))) <= 1, "the chip's label is not drawn on the who line")
-- A long who line gives way to them, never the tags.
h:Set(ns.People.Stats(G).record, "Feivel Emmenthal",
    "Level 60 Human Warrior · Alliance · <The Exceedingly Long Guild of Westfall Farmers>", diaryEntry, false)
Eq(h.shownTags, 2, "a long who line pushed a tag off")
Check(h.whoBox[1] + h.whoBox[2] + H.TAGS.clear <= h.tagsBox[1] + 0.5, "a long who line runs into the tags")
Check(math.abs(h.tagsBox[3] - h.whoBox[3]) <= 1, "with a long who line the tags left its line")
diaryEntry.tags, diaryEntry.relationship = tags, relationship
ns.UI.RefreshJournal()

--------------------------------------------------------------------------
Section("a long name steps down, then stays in its room")

local entry = ns.Diary.Get(G)
local record = ns.People.Stats(G).record
h:Set(record, "Bartholomew Thistlewaite", "Level 20 Tauren Druid", entry, false)
Check(Width(h.name) + 2 <= H.NAME.room, "a long name runs past its room")
h:Set(record, ("Bartholomew Thistlewaite "):rep(3), "Level 20 Tauren Druid", entry, false)
Eq(h.nameSize, "personNameLeast", "a name too long for its room is not at the smallest size")
local size = h.name.recorded.calls.SetSize
local nameW = size and size[1] or (h.name.GetWidth and h.name:GetWidth())
Check(nameW and nameW <= H.NAME.room, "a name too long for its room is laid wider than it")
Check(h.shownTags ~= nil, "the tags were not laid after a long name")
ns.UI.RefreshJournal()

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
