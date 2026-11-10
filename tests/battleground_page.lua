-- A battleground's pages in Your Diary (.claude/ui-proposal/battleground-page.md,
-- round 2; .claude/battleground-plan.md; UI/Journey/Match.lua): the pure
-- plan (Core/MatchPage.lua: nothing past the page, no two strips meeting,
-- the stand-out always kept, the roll's faces), the index of who was where
-- (the same counts as Matches.Meetings), then the pages in the book on
-- /sd testdata's evening of four (three Warsongs and an Alterac) and its
-- lone Arathi left early: the left page's lines under their sittings, the
-- overview and its tickets, a match's board (diary people underlined in
-- rubric, the stand-out's strip, the way back), the Alterac's faces, the
-- no-board slip, a rolled-up board's lost records, "Flat paper only".
-- Then with the pad: every part reached, A and B as the run's page has
-- them, the mouse taking over, the Gamepad UI off.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local MatchPage = ns.MatchPage
local MATCH, EVENING = MatchPage.MATCH, MatchPage.EVENING
local Text = ns.UI.JourneyText
local Matches = ns.Matches

-- Two boxes ({ x, y, w, h }) meet.
local function Meet(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

--------------------------------------------------------------------------
Section("the board: one face where it fits, turned over where it does not")

local B = MATCH.board
for _, case in ipairs({ { 10, 10, 1 }, { 15, 15, 2 }, { 40, 40, 5 }, { 39, 40, 5 }, { 1, 0, 1 }, { 0, 0, 1 } }) do
    local f = MatchPage.BoardFaces(case[1], case[2])
    Eq(f.faces, case[3], ("faces for %d against %d"):format(case[1], case[2]))
    for face = 1, f.faces do
        local plan = MatchPage.Board(case[1], case[2], face)
        local foot = B.y + plan.h
        Check(foot <= (plan.turns and B.turned or B.foot) + 0.01,
            ("the board of %d/%d ends at %.1f, face %d"):format(case[1], case[2], foot, face))
        local seen = { with = 0, against = 0 }
        local last = -1
        for _, r in ipairs(plan.rows) do
            Check(r.y > last, "rows out of order")
            last = r.y
            seen[r.side] = seen[r.side] + 1
        end
        Check(seen.with <= f.per and seen.against <= f.per, "more rows a side than a face holds")
    end
end
-- Every row is on some face, once.
do
    local n = 0
    local f = MatchPage.BoardFaces(40, 37)
    for face = 1, f.faces do n = n + #MatchPage.Board(40, 37, face).rows end
    Eq(n, 77, "every row of an Alterac on a face, once")
end
-- A rolled-up board leaves a side with nobody kept off, and its lost
-- records still fit.
do
    local plan = MatchPage.Board(2, 0, 1, true)
    Check(plan.heads.with and not plan.heads.against, "a rolled-up board keeps an empty side's heading")
    Check(plan.lost and plan.lost < plan.h, "the lost records not on the board")
end
-- The slip of names: fifteen a column a face.
Eq(MatchPage.Slip(14, 13).faces, 1, "a no-board slip of fifteen a side turns over")
Eq(MatchPage.Slip(40, 30).faces, 3, "forty names a side not over three faces")
Check(MATCH.slip.y + MatchPage.Slip(15, 15).h <= B.foot, "the slip past the board's foot")

--------------------------------------------------------------------------
Section("the margin: strips in their rows' order, never meeting, the stand-out kept")

for seed = 1, 60 do
    local marks = {}
    local y = B.y + 40
    for i = 1, 1 + seed % 12 do
        y = y + 6 + (seed * 7 + i * 13) % 40
        marks[i] = { y = y, h = 30 + (seed + i) % 3 * 13 }
    end
    local placed = MatchPage.Strips(marks)
    Check(#placed <= MATCH.strips.most, "more strips than the margin takes")
    for k, b in ipairs(placed) do
        Check(b.y + b.h <= MATCH.strips.bottom, "a strip past the margin's foot")
        Check(b.x >= B.x + B.w + 10 and b.x + b.w <= 466 - 10, "a strip off the margin")
        if k > 1 then
            Check(not Meet(placed[k - 1], b), "two strips meet")
            Check(placed[k - 1].i < b.i, "strips out of their rows' order")
        end
    end
end
do
    -- Eight repeats and the stand-out at the foot: the stand-out keeps its strip.
    local notes = {}
    for i = 1, 8 do notes[i] = { y = 180 + i * 12.5, h = 43, rank = 98 } end
    notes[9] = { y = 340, h = 43, rank = 0, standout = true }
    local chosen, placed = MatchPage.Choose(notes)
    Eq(#chosen, #placed, "chosen notes without a strip")
    local kept = false
    for _, n in ipairs(chosen) do kept = kept or n.standout == true end
    Check(kept, "the stand-out lost its strip to the repeats")
    for k = 2, #chosen do Check(chosen[k - 1].y <= chosen[k].y, "chosen not in their rows' order") end
end
Eq(MatchPage.NoteY(300), MATCH.note.y, "your note not at the foot under a short board")
Eq(MatchPage.NoteY(470), MATCH.note.most, "your note past its lowest")

--------------------------------------------------------------------------
Section("the order on the board: diary, you, repeats, the stand-out, the game's")

do
    local rows = {
        { side = "with", index = 1 }, { side = "with", index = 2, me = true },
        { side = "with", index = 3, meets = 2 }, { side = "with", index = 4, diary = "g" },
        { side = "with", index = 5, meets = 4 }, { side = "against", index = 6 },
        { side = "against", index = 7, standout = true }, { index = 8 },
    }
    local o = MatchPage.Order(rows)
    local w = {}
    for _, r in ipairs(o.with) do w[#w + 1] = r.index end
    Eq(table.concat(w, ","), "4,2,5,3,1", "your side's order")
    local a = {}
    for _, r in ipairs(o.against) do a[#a + 1] = r.index end
    Eq(table.concat(a, ","), "7,6,8", "their side's order (a side unread last)")
end

--------------------------------------------------------------------------
Section("the overview's tickets and roll stay on the page")

for n = 1, 12 do
    local tickets, top = MatchPage.Tickets(n, 99)
    Eq(#tickets, math.min(n, EVENING.tickets.most), "tickets for " .. n)
    for i, b in ipairs(tickets) do
        Check(b.x >= 10 and b.x + b.w <= 456, "a ticket off the page")
        for k = 1, i - 1 do Check(not Meet(tickets[k], b), "two tickets meet") end
        Check(b.y + b.h < top, "a ticket over the roll")
    end
    local cols = MatchPage.Columns(n)
    Check(cols[#cols] <= EVENING.roll.colEnd, "a column past the roll's end")
    for k = 2, #cols do Check(cols[k] - cols[k - 1] >= 14, "columns too close for a ring") end
    -- Many people by hand and in print: nothing past the roll's foot.
    local hand = { { h = 24 } }
    for i = 1, n * 3 do hand[#hand + 1] = { h = 18 } end
    local faces = MatchPage.Roll(top, hand, n * 40)
    local placedHand, placedPrint = 0, 0
    for _, face in ipairs(faces) do
        for _, at in ipairs(face.hand) do
            placedHand = placedHand + 1
            Check(at.y + hand[at.i].h <= EVENING.roll.bottom, "a hand line past the roll's foot")
        end
        if face.print then
            local p = face.print
            placedPrint = placedPrint + p.to - p.from + 1
            local _, y = MatchPage.PrintAt(p, p.to - p.from + 1)
            Check(y + EVENING.roll.printH <= EVENING.roll.bottom + 0.01, "print past the roll's foot")
            Check(p.to - p.from + 1 <= p.rows * EVENING.roll.cols, "more print than a face holds")
        end
    end
    Eq(placedHand, #hand, "a hand line lost")
    Eq(placedPrint, n * 40, "a printed name lost")
end

--------------------------------------------------------------------------
Section("who was where: the index counts as Matches.Meetings does")

SlashCmdList.SOCIALDIARY("testdata")
local all = Matches.All(ns.ownGUID)
Eq(#all, 5, "setup: testdata's five matches")
local index = MatchPage.Index(all)
local checked = 0
for _, m in ipairs(all) do
    for _, p in ipairs(Matches.Players(m)) do
        if p.guid and p.guid ~= ns.ownGUID and (p.index % 5 == 1 or p.name == "Feivel Ashgrove") then
            local side = Matches.Side(m, p)
            Eq(MatchPage.Count(index, p, m, side), Matches.Meetings(p.guid, m, side),
                "the index's count for " .. tostring(p.name) .. " in match " .. m.id)
            checked = checked + 1
        end
    end
end
Check(checked > 10, "setup: rows checked")

--------------------------------------------------------------------------
Section("the left page: the evening one line, the lone match its own")

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YD = ns.UI.YourDiary
local evening, lone
for _, s in ipairs(Matches.Sessions(ns.ownGUID)) do
    if Matches.HasOverview(s) then evening = s else lone = s end
end
Check(evening and #evening.matches == 4, "setup: the evening of four")
Check(lone and #lone.matches == 1 and lone.matches[1].state == "left", "setup: the lone Arathi left early")

local function Line(pred)
    for k, item in ipairs(page.items) do
        if item.bg and pred(item) then return item, k end
    end
end
local eveningLine, at = Line(function(item) return item.bg.key == evening.key end)
Check(eveningLine and not eveningLine.match, "the evening has no line of its own")
Eq(eveningLine.label, Text.EveningLine(4), "the evening's line")
Check(not Line(function(item) return item.match and item.bg.key == evening.key end),
    "a match of an evening with an overview has its own line")
local loneLine = Line(function(item) return item.match == lone.matches[1] end)
Check(loneLine, "the lone match has no line")
Eq(loneLine.label, "Arathi Basin, left early", "the lone match's line")
-- Under the sitting it began in.
local above = at - 1
while above > 0 and (page.items[above].run or page.items[above].bg) do above = above - 1 end
Check(page.items[above].sitting ~= nil, "the evening's line is not under a sitting")
local piece = page.recap.entries[eveningLine.entry].pieces[page.items[above].sitting]
local found = false
for _, s in ipairs(piece.battlegrounds) do found = found or s.key == evening.key end
Check(found, "the evening is listed under another sitting than the one it began in")
Check(not page.recap.entries[eveningLine.entry].spliced, "an entry with a battleground spliced")
Check(YD.Opens(eveningLine), "the evening's line opens nothing")

--------------------------------------------------------------------------
Section("the overview: tickets, the roll, your note")

YD.OpenItem(eveningLine)
Eq(page.mode, "matches", "the evening's line does not open its overview")
Eq(page.session, evening.key, "the overview of another session")
local bg = page.bg
Check(bg and bg.board:IsShown(), "the overview not drawn")
Eq(bg.title[1]:GetText(), "Battlegrounds", "the overview's title")
local kinds = {}
for _, part in ipairs(YD.MatchParts()) do kinds[part.pad.kind] = (kinds[part.pad.kind] or 0) + 1 end
Eq(kinds.ticket, 4, "a ticket a match")
Eq(kinds.title, 1, "the title")
Eq(kinds.note, 1, "your note")
Eq(kinds.turn, 1, "the roll does not turn over")
Check((kinds.hand or 0) >= 2, "the people who matter not by hand")
Eq(bg.rollFaces, 3, "the evening's roll not on three faces")
-- The hand rows: Tester (diary) and Feivel (the stand-out).
local tester, feivel
for _, part in ipairs(YD.MatchParts()) do
    if part.pad.kind == "hand" and part.pad.kept then tester = part end
    if part.pad.kind == "hand" and part.pad.words and (part.pad.words:GetText() or ""):find("^Feivel") then feivel = part end
end
Check(tester and tester.frame.guid == ns.TestData.GUID, "Tester (in the diary) not by hand, opening their page")
Check(feivel, "Feivel (against you in all four) not by hand")
local R = ns.Style.RUBRIC
local fr, fg, fb = feivel.pad.words:GetTextColor()
Check(math.abs(fr - R[1]) < 0.01 and math.abs(fg - R[2]) < 0.01, "the stand-out not in rubric")
-- The roll turns; the tickets stay.
local function Turn()
    for _, part in ipairs(YD.MatchParts()) do
        if part.pad.kind == "turn" then part.frame:Click("LeftButton") return true end
    end
end
Check(Turn(), "setup: the turn link")
Eq(bg.faces["roll:" .. evening.key], 2, "the roll did not turn over")
kinds = {}
for _, part in ipairs(YD.MatchParts()) do kinds[part.pad.kind] = (kinds[part.pad.kind] or 0) + 1 end
Eq(kinds.ticket, 4, "the tickets turned with the roll")
Turn()
Turn()
Eq(bg.faces["roll:" .. evening.key], 1, "the roll does not come round to its first face")
-- A ticket's tooltip and click.
local ticket
for _, part in ipairs(YD.MatchParts()) do
    if part.pad.kind == "ticket" and part.pad.match == evening.matches[1].id then ticket = part end
end
ticket.frame.scripts.OnEnter(ticket.frame)
Check(GameTooltip.shown, "a ticket's tooltip")
Check(bg.columns[1]:IsShown(), "a ticket does not underline its column")
ticket.frame.scripts.OnLeave(ticket.frame)
Check(not bg.columns[1]:IsShown(), "a ticket's column still underlined")
ticket.frame:Click("LeftButton")
Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. evening.matches[1].id, "a ticket does not open its match")

--------------------------------------------------------------------------
Section("a match: the board, the diary underlined in rubric, the stand-out's strip, the way back")

local function Strips(kind)
    local list = bg.used["strip:" .. kind]
    return list and list.n > 0 and list[1] or nil
end
local function Rubric(strip)
    local n = 0
    for _, seg in ipairs(strip.bg.lines) do
        local c = seg.recorded.calls.SetColorTexture
        if seg:IsShown() and c and math.abs(c[1] - R[1]) < 0.01 and math.abs(c[2] - R[2]) < 0.01 then n = n + 1 end
    end
    return n
end
local clip = Strips("clip")
Check(clip, "the board not clipped in")
Check(Rubric(clip) > 0, "Tester (in the diary) not underlined in rubric")
kinds = {}
local backHit, rowHit, stripHits = nil, nil, 0
for _, part in ipairs(YD.MatchParts()) do
    kinds[part.pad.kind] = (kinds[part.pad.kind] or 0) + 1
    if part.pad.kind == "back" then backHit = part.frame end
    if part.pad.kind == "row" then rowHit = part.frame end
    if part.pad.kind == "strip" then stripHits = stripHits + 1 end
end
Eq(YD.MatchParts()[1].pad.kind, "title", "the title not first (the pad lands on it)")
Check(backHit, "no way back to the evening")
Eq(kinds.row, 1, "Tester's row not reached (and only theirs: a stranger's row is the mouse's)")
Eq(stripHits, 1, "the stand-out's strip: Feivel, who killed you")
local note = bg.used["strip:note1"][1]
Check(note.bg.texts[1]:GetText():find("Feivel") ~= nil, "the strip is not Feivel's")
Check(note.bg.texts[1]:GetText():find("killed you") ~= nil, "Feivel's strip does not say he killed you")
-- No honour, rank or title anywhere on the board.
for _, fs in ipairs(clip.bg.texts) do
    if fs:IsShown() then Check(not (fs:GetText() or ""):lower():find("honour"), "honour on the board") end
end
-- Every player a row.
Eq(#bg.plan.rows, #Matches.Players(evening.matches[1]), "a player without a row")
-- A diary person's row opens their page.
local went
local was = YD.ToPerson
YD.ToPerson = function(guid) went = guid end
rowHit:Click("LeftButton")
YD.ToPerson = was
Eq(went, ns.TestData.GUID, "a diary person's row does not open their page")
-- The way back.
backHit:Click("LeftButton")
Eq(page.mode .. ":" .. tostring(page.session), "matches:" .. evening.key, "the way back does not open the overview")

-- Repeats: the third Warsong's strips say which match it was with them.
YD.OpenMatch(evening.matches[3].id)
local sayings = {}
for k = 1, 5 do
    local list = bg.used["strip:note" .. k]
    local s = list and list.n > 0 and list[1]
    if s and s:IsShown() then
        local words = {}
        for _, fs in ipairs(s.bg.texts) do if fs:IsShown() then words[#words + 1] = fs:GetText() end end
        sayings[#sayings + 1] = table.concat(words, " ")
    end
end
Check(#sayings >= 2, "the third Warsong has no repeats' strips")
local third = false
for _, words in ipairs(sayings) do third = third or (words:find("third match against") ~= nil) end
Check(third, "Feivel's third match against you not told")

--------------------------------------------------------------------------
Section("the Alterac turns over in faces; the lone Arathi is the no-board slip")

local av = evening.matches[4]
YD.OpenMatch(av.id)
Eq(bg.plan.faces, 5, "forty a side not on five faces")
Eq(bg.plan.face, 1, "the Alterac not on its first face")
local turned
for _, part in ipairs(YD.MatchParts()) do if part.pad.kind == "turn" then turned = part.frame end end
turned:Click("LeftButton")
Eq(bg.faces["match:" .. av.id], 2, "the board did not turn over")
Eq(page.mode .. ":" .. page.matchId, "match:" .. av.id, "turning the board left the match")

YD.OpenItem(loneLine)
Eq(page.mode .. ":" .. tostring(page.matchId), "match:" .. lone.matches[1].id, "the lone match's line does not open it")
Eq(page.matchBack, nil, "a lone match has a way back to an evening")
Check(Strips("slip") and not Strips("clip"), "a match with no board not the slip of names")
local said = Strips("slip").bg.texts[1]:GetText()
Eq(said, Text.MATCH.unwritten, "the slip's line")
for _, part in ipairs(YD.MatchParts()) do Check(part.pad.kind ~= "back", "a lone match has the back link") end
local foot = bg.used.noteText[2]:GetText()
Eq(foot, Text.MATCH_REST, "the no-board note does not say the rest went unwritten")

--------------------------------------------------------------------------
Section("a rolled-up match: its diary people stay, the strangers are lost records")

Matches.Rollup(nil, 0)
local first = evening.matches[1]
Check(first.rolled and first.lost > 0, "setup: the first Warsong rolled up")
YD.OpenMatch(first.id)
Check(bg.plan.lost ~= nil, "the lost records not drawn")
local lostSaid
for _, fs in ipairs(Strips("clip").bg.texts) do
    if fs:IsShown() and (fs:GetText() or ""):find("rubbed out") then lostSaid = fs:GetText() end
end
Eq(lostSaid, Text.MatchLost(first.lost), "the lost records' count")
kinds = {}
for _, part in ipairs(YD.MatchParts()) do kinds[part.pad.kind] = (kinds[part.pad.kind] or 0) + 1 end
Eq(kinds.row, 1, "Tester's row lost in the roll-up")
Eq(kinds.lost, 1, "the lost records not told on hover")

--------------------------------------------------------------------------
Section("Flat paper only: everything lies flat")

ns.db.settings.flatSheets = true
YD.OpenMatch(evening.matches[2].id)
for _, kind in ipairs({ "clip", "note1" }) do
    local s = Strips(kind)
    if s then Eq(s.turn or 0, 0, kind .. " turned with Flat paper only") end
end
YD.OpenMatches(evening.key)
Eq(Strips("ticket1").turn or 0, 0, "a ticket turned with Flat paper only")
ns.db.settings.flatSheets = nil

--------------------------------------------------------------------------
Section("a piece with no plates and only battlegrounds opens on them")

do
    -- (Page.lua's ViewOf, asked of the evening's sitting with its plates and
    -- runs taken away: a capped week spent in battlegrounds)
    local e = page.recap.entries[eveningLine.entry]
    local k = page.items[above].sitting
    local p = e.pieces[k]
    local plates, runs = p.plates, p.runs
    p.plates, p.runs = {}, {}
    YD.OpenPiece(eveningLine.entry, k)
    Eq(page.mode .. ":" .. tostring(page.session), "matches:" .. evening.key, "it does not open on the evening's overview")
    p.plates, p.runs = plates, runs
    YD.OpenPiece(eveningLine.entry, k)
    Check(page.mode ~= "matches", "a piece with plates opens on its battlegrounds")
end
