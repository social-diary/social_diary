-- "Choose what's on this page" (.claude/features/choose-page.md, Phase 3 and
-- "Stable list"; UI/Journey/Choose.lua): the link under the open level, the
-- ticklist in place of the left page, its zones and rows and looks, the cap
-- line's frames, no map numbers anywhere (the user's, 18 Nov), a tick leaving
-- a zone out and keeping one (the right page drawn again, the list unmoved,
-- the rows' plates following the grouping, "came off to make room"), a row left out, the block
-- (the red line, the box and the frames shaking, nothing written), the page's
-- layout (header, list, footer), the hover between a row
-- and its mark, Done, leaving by another level or the ribbon, and no link
-- with the pad in hand. Construction and logic only: how it looks is for the
-- client. Invented names only.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local YD = ns.UI.YourDiary
local J, Chosen = ns.Journey, ns.Chosen
local WORDS = YD.CHOOSE_WORDS
local C = YD.CHOOSE

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

-- Five zones, a stop in each (as tests/choices.lua's): the three longest
-- (a death, a fight, a long stay) are on the page, the first next in line,
-- the last no room.
local FOE = "Player-1111-0000BBBB"
local t0 = now - 20000
J.Begin(ns.ownGUID, t0, 12, 1411)
local j = J.Mine()
local function Stop(from, seconds, mapID, act)
    return { kind = "stop", from = from, to = from + seconds, mapID = mapID, x = 0.5, y = 0.5, r = 30,
        seconds = seconds, levelFrom = 12, levelTo = 12, act = act }
end
j.segments = { Stop(t0, 1000, 1411), Stop(t0 + 2000, 2000, 1412, { deaths = 1 }), Stop(t0 + 5000, 3000, 1413),
    Stop(t0 + 9000, 4000, 1415), Stop(t0 + 14000, 500, 1416) }
j.open = nil
j.marks = { { kind = "fight", outcome = "won", guid = FOE, t = t0 + 6000, mapID = 1413, x = 0.52, y = 0.5 } }
J.Touch()

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function LinkItem()
    for _, item in ipairs(page.items) do
        if item.choose then return item end
    end
end
local function EntryRow(test)
    for _, row in ipairs(page.entries.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
end
local function Row(test)
    for _, row in ipairs(page.chooser.list.rows) do
        if row:IsShown() and row.item and test(row.item) then return row end
    end
end
local function ZoneRow(mapID)
    return Row(function(item) return item.zone ~= nil and item.zone.mapID == mapID end)
end
local function MomentRow(mapID, kind)
    return Row(function(item) return item.card ~= nil and item.card.zone.mapID == mapID and item.card.kind == kind end)
end
local function Zone(mapID)
    for _, zone in ipairs(page.choices.zones) do
        if zone.mapID == mapID then return zone end
    end
end
-- The list as it reads: every row's words and time, in order.
local function Reading()
    local out = {}
    for _, item in ipairs(page.chooser.list.data) do
        out[#out + 1] = (item.zone and "" or "  ") .. item.label .. (item.time and (" " .. item.time) or "")
    end
    return table.concat(out, "\n")
end
local function Shown()
    local list = {}
    for i = 1, page.layout or 0 do
        if page.plates[i] and page.plates[i]:IsShown() then list[#list + 1] = page.plates[i].mapID end
    end
    table.sort(list)
    return table.concat(list, " ")
end
local function Red(fs)
    local r, g, b = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(r - R[1]) < 0.01 and math.abs(g - R[2]) < 0.01 and math.abs(b - R[3]) < 0.01
end
-- A stroke's or a string's ink: whether it is the rubric's, and its alpha.
local function IsRed(c)
    local R = ns.Style.RUBRIC
    return math.abs(c[1] - R[1]) < 0.01 and math.abs(c[2] - R[2]) < 0.01 and math.abs(c[3] - R[3]) < 0.01
end
local function StrokeInk(stroke)
    local c = stroke.recorded.calls.SetColorTexture
    return IsRed(c), c[4] or 1
end
local function TextAlpha(fs)
    return select(4, fs:GetTextColor())
end
local function Frames()
    local out = {}
    for k, f in ipairs(page.chooser.frames) do out[k] = f.kind or "free" end
    return table.concat(out, " ")
end
local function Copy(t)
    local copy = {}
    for k, v in pairs(t or {}) do copy[k] = v end
    return copy
end
local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

--------------------------------------------------------------------------
Section("the link under the open level, with the mouse")

Eq(Shown(), "1412 1413 1415", "setup: the three busiest places on the page")
local link = LinkItem()
Check(link ~= nil, "no link to the ticklist under the open level")
Eq(link and link.label, WORDS.title, "the link's words")
Eq(page.items[page.rubrics[page.open] + 1], link, "the link straight under the rubric of a level drawn whole")
local linkRow = EntryRow(function(item) return item.choose == true end)
Check(linkRow and linkRow.zone:IsShown() and linkRow.zone:GetText() == WORDS.title, "the link's row not written")
Check(YD.Opens(link), "the link does nothing")

--------------------------------------------------------------------------
Section("the ticklist in place of the left page")

linkRow:Click()
local ch = page.chooser
Check(page.choosing and ch and ch:IsShown(), "the link did not open the ticklist")
Check(not page.entries:IsShown() and not page.name:IsShown(), "the left page still shown under it")
Eq(ch.title:GetText(), WORDS.title, "the title")
Eq(ch.rubric:GetText(), "LEVEL 12", "the level's rubric")
Eq(ch.cap:GetText(), WORDS.cap, "the cap line")
Eq(ch.note:GetText(), "", "the line under it, empty")
Eq(Frames(), "diary diary diary", "three frames, faded: all the diary's")
Eq(ch.frames[2].number, nil, "a frame with a number in it (the numerals were dropped)")
local order = {}
for _, item in ipairs(ch.list.data) do
    if item.zone then order[#order + 1] = item.zone.mapID end
end
Eq(table.concat(order, " "), "1411 1412 1413 1415 1416", "every zone, in time order")
for i, item in ipairs(ch.list.data) do
    Check(item.height == (item.zone and C.place or C.card) or item.height == (item.zone and C.place or C.card) + C.gap,
        "a row of its own height: " .. item.label)
    if item.card then
        local before = ch.list.data[i - 1]
        Check(before.zone == item.card.zone or (before.card and before.card.zone == item.card.zone),
            "a row not under its zone")
    end
end
Check(Row(function(item) return item.card ~= nil and item.card.zone.mapID == 1411 end) ~= nil,
    "a zone off the page closed: its rows not listed")
local next, noRoom = ZoneRow(1411), ZoneRow(1416)
Eq(next.placeBox.look, "diaryOff", "a zone off the page: an empty box")
Check(not next.placeBox.tick[1]:IsShown() and not next.placeBox.dash[1]:IsShown(), "an empty box ticked")
Check(next.why == nil, "a row with a second line")
-- Off the page recedes: faded words, a faint box; on the page in ink.
Check(TextAlpha(next.name) < 1, "a zone off the page not faded")
Check(not StrokeInk(next.placeBox.outline[1]) and select(2, StrokeInk(next.placeBox.outline[1])) == C.faded.off,
    "an empty box not faint")
local on = ZoneRow(1413)
Eq(on.placeBox.look .. "/" .. on.placeBox.state, "diary/all", "a zone on the page: the diary's tick")
Check(on.placeBox.tick[1]:IsShown() and not on.placeBox.dash[1]:IsShown() and not on.placeBox.cross[1]:IsShown(),
    "the diary's pick not ticked")
Eq(TextAlpha(on.name), 1, "a zone on the page not in full ink")
Check(not Red(on.name), "a zone on the page in red")
Check(not StrokeInk(on.placeBox.tick[1]) and not StrokeInk(on.placeBox.outline[1]), "the diary's tick in red")
Eq(on.placeBox.tick[1].recorded.height, C.faded.tickW, "the diary's tick as heavy as the player's")
local fightRow = MomentRow(1413, "fight")
Check(fightRow and fightRow.cardBox:IsShown() and not fightRow.placeBox:IsShown(), "a moment's row has no small box")
Eq(fightRow and fightRow.name:GetText(), ns.Characters.Name(FOE) or ns.Characters.FullName(FOE) or "Someone",
    "a person's row: their name")
Eq(fightRow.time:GetText(), ns.UI.Format.Clock(t0 + 6000), "a row's time: its moment's")
-- No map numbers (the user's, 18 Nov): no marker column on the rows, no
-- label on the plates; the plate a row is on is only for its ring.
Eq(fightRow.mark, nil, "a row with a marker column")
Eq(fightRow.item.mark, nil, "a row's item with a map's number")
Eq(fightRow.item.card.plate, 2, "the fight on the second map (for its ring)")
Eq(MomentRow(1412, "death").item.card.plate, 1, "the death on the first")
for i = 1, page.layout do
    Eq(page.plates[i].chosenNumber, nil, "plate " .. i .. " wears a number")
end
-- Why it is off the page, in its tooltip; an on row's is its words alone.
local function TipOf(row)
    GameTooltip:Hide()
    row.scripts.OnEnter(row)
    local lines = { GameTooltip.text or "" }
    for _, l in ipairs(GameTooltip.lines or {}) do lines[#lines + 1] = l[1] end
    local text = table.concat(lines, "\n")
    row.scripts.OnLeave(row)
    return text
end
Check(TipOf(next):find(WORDS.reason.next, 1, true) ~= nil, "the best zone left off: next in line, in its tooltip")
Check(TipOf(noRoom):find(WORDS.reason.noRoom, 1, true) ~= nil, "the rest: no room")
Eq(WORDS.on, nil, "the words still have a map's number")
Eq(TipOf(fightRow), fightRow.item.label, "an on row's tooltip: more than its words")
Eq(j.chosen, nil, "opening the ticklist wrote something")

--------------------------------------------------------------------------
Section("a row and its mark: the ring, and the rows lit")

do
    local plate = page.plates[2]
    fightRow.scripts.OnEnter(fightRow)
    Check(plate.ringAt ~= nil and plate.ringAt.mapID == 1413, "a row under the mouse does not ring its mark")
    Check(math.abs(plate.ringAt.x - 0.52) < 1e-6, "the ring not at the fight's spot")
    fightRow.scripts.OnLeave(fightRow)
    Eq(plate.ringAt, nil, "the ring stays after the mouse left")
    MomentRow(1411, "arrive").scripts.OnEnter(MomentRow(1411, "arrive"))
    for i = 1, page.layout do Eq(page.plates[i].ringAt, nil, "a row off the page rang a mark") end
    MomentRow(1411, "arrive").scripts.OnLeave(MomentRow(1411, "arrive"))
    -- The fight's mark under the mouse: its row lit.
    local mark
    for i = 1, plate.hover.used do
        local b = plate.hover[i]
        for _, m in ipairs(b.moments or {}) do
            if m.kind == "fight" then mark = b end
        end
    end
    Check(mark ~= nil, "setup: the fight's mark on its plate")
    Eq(fightRow.name:GetTextColor(), ns.Style.INK[1], "setup: the row in ink")
    mark.scripts.OnEnter(mark)
    Check(page.chooseLit ~= nil and page.chooseLit[fightRow.item.card.key], "the mark did not light its row")
    Eq(select(1, fightRow.name:GetTextColor()), ns.Style.INK_STRONG[1], "its row not darkened")
    mark.scripts.OnLeave(mark)
    Eq(page.chooseLit, nil, "the rows stay lit after the mark")
end

--------------------------------------------------------------------------
Section("the page's layout: the header, the list, the footer")

-- (the user's, 18 Nov: the top out of balance, a hole under the cap line,
-- Done too dim. The feedback line moved to the footer beside Done.)
do
    local BOOK_H = ns.UI.Journal.BOOK.BOOK_H
    local FONT = ns.Style.FONT
    local function Y(region) return select(3, region:GetPoint(1)) end
    Eq(ch.title.recorded.calls.SetFontObject[1], FONT.noteWrittenLarge, "the title not a size up in the hand")
    Check(FONT.noteWrittenLarge ~= FONT.noteWritten, "the title in the zones' own font")
    Eq(Y(ch.title), -C.title, "the title's place")
    Eq(Y(ch.frames[1]), -C.cap, "the cap line's place")
    Check(C.rubric < C.title and C.title < C.cap and C.cap + C.frameH < C.list, "the header out of order")
    Eq(C.list, YD.HEAD.list, "the list does not begin where the entries do")
    -- The meter: three maps, their words after them, the inks stepping down.
    Eq(WORDS.cap, "Three maps fit a page.", "the cap line's words")
    Check(C.frameMin >= C.frameH, "the narrowest frame narrower than it is tall")
    Check(C.cap >= C.title + 26, "the meter under the title's descenders")
    local capX = select(4, ch.cap:GetPoint(1))
    Eq(capX, C.meter + C.capGap, "the words not just past the meter")
    local FR = C.frames
    Check(FR.mine > FR.diary and FR.diary > FR.free, "the frames' inks do not step down: the player's, the diary's, none")
    Eq(FR.free, C.faded.off, "an empty frame not as faint as a box off the page")

    Eq(Y(ch.list), -C.list, "the list's place")
    -- The footer: the rule under the list, the line at its left, Done at its right.
    Check(BOOK_H - C.bottom <= BOOK_H - C.foot.rule, "the list runs into the footer's rule")
    Eq(Y(ch.footRule[1]), -(BOOK_H - C.foot.rule), "the footer's rule")
    Eq(Y(ch.note), -(BOOK_H - C.foot.note), "the footer's line")
    Eq(C.foot.note - C.noteH, C.done, "the line's foot not on Done's")
    Eq((ch.done:GetPoint(1)), "TOPRIGHT", "Done not at the footer's right")
    Eq(Y(ch.done), -(BOOK_H - C.done - 18), "Done's place")
    Check(ch.note:GetWidth() + C.foot.gap + ch.done:GetWidth() <= ns.UI.Journal.BOOK.LEFT_W - 2,
        "the line runs under Done")
    Check(ch.done.label and ch.done.line, "Done not a link the pad finds (its label and line)")
    Eq(ch.done.label.recorded.calls.SetFontObject[1], FONT.strong, "Done not in strong type")
    ch.done.scripts.OnEnter(ch.done)
    ch.done.scripts.OnLeave(ch.done)
    Eq(select(1, ch.done.label:GetTextColor()), ns.Style.INK_STRONG[1], "Done fades after the mouse left")
    -- A list too short to scroll: its rows take the scrollbar's room.
    Check(not ch.list.bar:IsShown(), "setup: a list that does not scroll")
    Eq(select(2, fightRow.time:GetPoint(1)), ns.UI.SCROLLBAR_WIDTH - 2, "the time not over the scrollbar's room")
end

--------------------------------------------------------------------------
Section("the meter and the rows: a frame lights its rows, a row its frame")

do
    local function Hot()
        local out = {}
        for k, f in ipairs(ch.frames) do out[k] = f.hot and "hot" or "-" end
        return table.concat(out, " ")
    end
    Eq(Hot(), "- - -", "setup: no frame lit")
    fightRow.scripts.OnEnter(fightRow)
    Eq(Hot(), "- hot -", "a row under the mouse does not light its map's frame")
    fightRow.scripts.OnLeave(fightRow)
    Eq(Hot(), "- - -", "the frame stays lit after the row")
    local zoneRow = ZoneRow(1413)
    zoneRow.scripts.OnEnter(zoneRow)
    Eq(Hot(), "- hot -", "a zone's row does not light the frame of its map")
    zoneRow.scripts.OnLeave(zoneRow)
    local offRow = MomentRow(1411, "arrive")
    offRow.scripts.OnEnter(offRow)
    Eq(Hot(), "- - -", "a row off the page lit a frame")
    offRow.scripts.OnLeave(offRow)
    local f = ch.frames[2]
    f.scripts.OnEnter(f)
    Eq(Hot(), "- hot -", "the frame under the mouse not lit")
    Check(page.chooseLit ~= nil and page.chooseLit[fightRow.item.card.key], "the frame did not light its map's row")
    Eq(select(1, fightRow.name:GetTextColor()), ns.Style.INK_STRONG[1], "its row not darkened")
    Check(not page.chooseLit[MomentRow(1412, "death").item.card.key], "the frame lit another map's row")
    f.scripts.OnLeave(f)
    Eq(page.chooseLit, nil, "the rows stay lit after the frame")
    Eq(Hot(), "- - -", "the frame stays lit after the mouse left")
end

--------------------------------------------------------------------------
Section("the meter: the right page's room as its plates share it")

-- (the user's, 18 Nov: "move on from 3 simple slots to what is happening on
-- the right side"; one plate may take the whole page.)
do
    local LAYOUT = ns.UI.JourneyLook.LAYOUT
    local Widths = YD.MeterWidths
    local function Sum(w)
        local total = 0
        for _, v in ipairs(w) do total = total + v end
        return total + (#w - 1) * C.frameGap
    end
    local function Of(slots)
        local list = {}
        for i, s in ipairs(slots) do list[i] = { w = s.w, h = s.h } end
        return list
    end
    local cases = {
        { "one plate", LAYOUT[1] }, { "one plate, caption over it", { LAYOUT[1][1].top } },
        { "FF", LAYOUT.FF or LAYOUT[2] }, { "LL", LAYOUT.LL or LAYOUT[2] }, { "three", LAYOUT[3] },
        { "FL", LAYOUT.FL }, { "LF", LAYOUT.LF }, { "F+L", LAYOUT.FL.tucked }, { "LFF", LAYOUT.LFF },
        { "FFL", LAYOUT.FFL },
    }
    for _, case in ipairs(cases) do
        local name, slots = case[1], Of(case[2])
        local w = Widths(slots)
        Eq(#w, #slots, name .. ": a frame for each plate")
        Eq(Sum(w), C.meter, name .. ": the frames not the meter's width")
        for i = 1, #w do
            Check(w[i] >= C.frameMin and w[i] == math.floor(w[i]), name .. ": a frame too narrow, or not whole px")
            for k = 1, #w do
                local a, b = slots[i].w * slots[i].h, slots[k].w * slots[k].h
                if a > b * 1.15 then Check(w[i] >= w[k], name .. ": a larger plate's frame narrower") end
            end
        end
    end
    Eq(Widths(Of(LAYOUT[1]))[1], C.meter, "one plate not one frame the whole width")
    local tucked = Widths(Of(LAYOUT.FL.tucked))
    Check(tucked[2] < tucked[1], "F+L's tucked print not the narrower frame")
    local empty = Widths({})
    Eq(#empty == 1 and empty[1], C.meter, "no plates: not one frame the whole width")

    -- On the page: a frame for each plate, by the slots it was drawn in.
    local piece = YD.ShownPiece()
    Eq(#piece.drawnSlots, page.layout, "the piece does not keep the slots its plates were drawn in")
    for i = 1, page.layout do
        Eq(piece.drawnSlots[i].w, page.plates[i].slot.w, "a kept slot not the plate's")
    end
    local want = Widths(piece.drawnSlots)
    local shown = 0
    for k, f in ipairs(ch.frames) do
        if f:IsShown() then
            shown = shown + 1
            Eq(f.w, want[k], "frame " .. k .. " not its plate's share")
            Eq(f:GetWidth(), want[k], "frame " .. k .. " not drawn at its share")
        end
    end
    Eq(shown, page.layout, "not a frame for each plate on the page")
    -- Its tooltip: the zone, and whose choice.
    local function FrameTip(f)
        GameTooltip:Hide()
        f.scripts.OnEnter(f)
        local lines = { GameTooltip.text or "" }
        for _, l in ipairs(GameTooltip.lines or {}) do lines[#lines + 1] = l[1] end
        f.scripts.OnLeave(f)
        return table.concat(lines, "\n")
    end
    Eq(FrameTip(ch.frames[2]), ns.UI.JourneyText.MapName(page.plates[2].mapID) .. "\n" .. WORDS.forYou,
        "a frame's tooltip: not its zone and who chose it")

    -- A tick that changes the page eases the frames to their new widths
    -- (the right page's glide); the frames' own widths are final at once.
    -- (The page's slots stood in for: one plate become the whole page.)
    local kept = piece.drawnSlots
    piece.drawnSlots = { { w = 300, h = 300 }, { w = 100, h = 100 }, { w = 100, h = 100 } }
    page.chooseEase = true
    YD.FillChoose()
    local to = Widths(piece.drawnSlots)
    Check(ch.meterEase.scripts.OnUpdate ~= nil, "a changed page: the frames do not ease")
    Eq(ch.frames[1].w, to[1], "the frame's width not final at once")
    Eq(ch.frames[1]:GetWidth(), want[1], "the frame does not ease from where it stood")
    ch.meterEase.scripts.OnUpdate(ch.meterEase, C.ease / 2)
    local mid = ch.frames[1]:GetWidth()
    Check(mid > math.min(want[1], to[1]) and mid < math.max(want[1], to[1]), "the frame not on its way")
    ch.meterEase.scripts.OnUpdate(ch.meterEase, C.ease)
    Eq(ch.meterEase.scripts.OnUpdate, nil, "the ease never stops")
    Eq(ch.frames[1]:GetWidth(), to[1], "the frame not at its width after the ease")
    Eq(select(2, ch.frames[2]:GetPoint(1)), to[1] + C.frameGap, "a frame not at its place after the ease")
    -- The same widths again: nothing eases. Laid flat: nothing eases.
    YD.FillChoose()
    Eq(ch.meterEase.scripts.OnUpdate, nil, "frames eased that did not change")
    piece.drawnSlots = kept
    ns.SetSetting("flatSheets", true)
    YD.FillChoose()
    ns.SetSetting("flatSheets", false)
    Eq(ch.meterEase.scripts.OnUpdate, nil, "\"Flat paper only\": the frames eased")
    Eq(ch.frames[1]:GetWidth(), want[1], "laid flat: the frame not at its width at once")
    page.chooseEase = nil
    YD.FillChoose()
end

--------------------------------------------------------------------------
Section("a tick on a zone on the page: left out, the list unmoved")

local READING = Reading()
on:Click()
Check(page.choosing and ch:IsShown(), "the ticklist closed with a tick")
Check(not page.entries:IsShown() and not page.name:IsShown(), "the left page shown again over the ticklist after a tick")
Eq(Shown(), "1411 1412 1415", "the right page not drawn again: the zone left out, the next in")
Eq(Reading(), READING, "the list moved")
local out = ZoneRow(1413)
Eq(out.placeBox.look, "out", "a zone left out: a red cross")
Check(out.placeBox.cross[1]:IsShown() and not out.placeBox.tick[1]:IsShown(), "the cross not drawn")
Check(out.strike:IsShown(), "its name not struck through")
Check(StrokeInk(out.placeBox.cross[1]), "the player's cross not in red")
Check(not StrokeInk(out.placeBox.outline[1]), "a zone left out in a red box: the kept rows' look")
Check(not Red(out.name) and TextAlpha(out.name) < 1, "a name left out not faded")
Check(not StrokeInk(out.strike) and select(2, StrokeInk(out.strike)) < 1, "the strike not in the name's faded ink")
Eq(MomentRow(1413, "fight").cardBox.look, "out", "its rows left out with it")
-- The rows' plates follow the grouping (the ring's target): the first map is
-- the next one in now.
Eq(MomentRow(1411, "arrive").item.card.plate, 1, "the zone come in not on the first map")
Eq(MomentRow(1412, "death").item.card.plate, 2, "the death's plate not moved on")
Eq(MomentRow(1413, "fight").item.card.plate, nil, "a row left out still on a plate")
local saved = 0
for _, v in pairs(j.chosen or {}) do
    Eq(v, "out", "a zone left out: out on its moments")
    saved = saved + 1
end
Check(saved > 0, "nothing written for a zone left out")
Eq(Frames(), "diary diary diary", "the frames: still the diary's three")

--------------------------------------------------------------------------
Section("a tick on a zone off the page: kept, and the diary's weakest makes room")

ZoneRow(1416):Click()
Eq(Reading(), READING, "the list moved")
local kept = Zone(1416)
Eq(kept.look, "keep", "a zone kept: the player's")
Check(kept.on, "a zone kept not on the page")
Check(Shown():find("1416") ~= nil, "the right page without the zone kept")
Eq(ZoneRow(1416).placeBox.look, "keep", "its box: a red tick")
Check(StrokeInk(ZoneRow(1416).placeBox.tick[1]) and StrokeInk(ZoneRow(1416).placeBox.outline[1]),
    "a zone kept: its tick and box not red")
Eq(ZoneRow(1416).placeBox.tick[1].recorded.height, C.bold, "the player's tick not bold")
Eq(Frames(), "diary diary mine", "the frames: the last map the player's")
local bumped
for _, zone in ipairs(page.choices.zones) do
    if zone.reason == "madeRoom" then bumped = zone end
end
Check(bumped ~= nil, "no zone made room")
Eq(ch.note:GetText(), WORDS.bumped:format(ns.UI.JourneyText.MapName(bumped.mapID) or "A stop"),
    "the line under the cap line does not say what came off")
Check(TipOf(ZoneRow(bumped.mapID)):find(WORDS.madeRoom:format(ns.UI.JourneyText.MapName(1416) or "A stop"), 1, true)
    ~= nil, "its tooltip: made room for the zone kept")

--------------------------------------------------------------------------
Section("a row left out: the zone's dash")

local stay = MomentRow(1412, "stay")
Check(stay and stay.item.card.on, "setup: a stay on the page")
stay:Click()
Eq(Reading(), READING, "the list moved")
local partly = ZoneRow(1412)
Eq(partly.placeBox.state, "some", "the zone partly on the page")
Check(partly.placeBox.dash[1]:IsShown() and not partly.placeBox.tick[1]:IsShown(), "not a dash")
Check(StrokeInk(partly.placeBox.dash[1]), "the player's doing, not in red")
local cardOut = MomentRow(1412, "stay")
Check(StrokeInk(cardOut.cardBox.cross[1]) and not StrokeInk(cardOut.cardBox.outline[1]),
    "a row left out: not a red cross in a faint box")
Check(cardOut.strike:IsShown() and TextAlpha(cardOut.name) < 1, "a row left out: not struck and faded")
cardOut.scripts.OnEnter(cardOut)
Eq(TextAlpha(cardOut.name), 1, "a row off the page does not come up under the mouse")
cardOut.scripts.OnLeave(cardOut)
Check(TextAlpha(cardOut.name) < 1, "a row off the page stays up after the mouse left")
MomentRow(1412, "stay"):Click()
Eq(MomentRow(1412, "stay").cardBox.look, "keep", "kept again: a red tick")

--------------------------------------------------------------------------
Section("three maps the player's, and a fourth blocked")

ZoneRow(1412):Click()  -- (the death's zone, showing: left out)
ZoneRow(1412):Click()  -- (and kept)
ZoneRow(1415):Click()
ZoneRow(1415):Click()
Eq(Frames(), "mine mine mine", "three of the player's")
do
    local f = ch.frames[1]
    GameTooltip:Hide()
    f.scripts.OnEnter(f)
    local line = GameTooltip.lines and GameTooltip.lines[1] and GameTooltip.lines[1][1]
    f.scripts.OnLeave(f)
    Eq(line, WORDS.yours, "a frame of the player's: its tooltip does not say so")
end
local off
for _, zone in ipairs(page.choices.zones) do
    if not zone.on then off = zone end
end
Check(off ~= nil, "setup: a zone off the page")
local before = Copy(j.chosen)
local offRow = ZoneRow(off.mapID)
offRow:Click()
Check(Same(before, j.chosen or {}), "a blocked tick wrote something")
Eq(ch.note:GetText(), WORDS.blocked, "the footer's line does not say why")
Check(Red(ch.note), "it is not red")
Eq(ch.cap:GetText(), WORDS.cap, "the cap line changed")
Eq(Reading(), READING, "the list moved")
Check(offRow.placeBox.scripts.OnUpdate ~= nil, "the box does not shake")
for _ = 1, 30 do
    local f = offRow.placeBox.scripts.OnUpdate
    if f then f(offRow.placeBox, 0.05) end
end
Check(offRow.placeBox.scripts.OnUpdate == nil, "the box never stops shaking")
Check(ch.frames[1].scripts.OnUpdate ~= nil, "the cap line's frames do not shake")
for _ = 1, 30 do
    for _, f in ipairs(ch.frames) do
        local fn = f.scripts.OnUpdate
        if fn then fn(f, 0.05) end
    end
end
Check(ch.frames[3].scripts.OnUpdate == nil, "the frames never stop shaking")
Eq(select(3, ch.frames[3]:GetPoint(1)), -C.cap, "a frame not back in its place")
Eq(select(2, ch.frames[3]:GetPoint(1)), ch.frames[1].w + ch.frames[2].w + 2 * C.frameGap, "a frame not back in its place")
ZoneRow(1415):Click()  -- (room again: a zone of the player's left out)
Check(not Red(ch.note) and ch.note:GetText() ~= WORDS.blocked, "the line still red after a tick that went through")

--------------------------------------------------------------------------
Section("Done, another level, the ribbon: the left page given back")

ch.done:Click()
Check(not page.choosing and not ch:IsShown(), "Done did not close the ticklist")
Check(page.entries:IsShown() and page.name:IsShown(), "Done did not give the left page back")
YD.Choose()
Check(page.choosing, "setup: the ticklist open again")
YD.OpenLevel(page.open)
Check(not page.choosing and not ch:IsShown() and page.entries:IsShown(), "opening a level left it open")
YD.Choose()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
Check(not page.choosing and not ch:IsShown() and page.entries:IsShown(), "the ribbon left it open")

--------------------------------------------------------------------------
Section("a plate's whole map from the ticklist: the ticklist stays, and back")

-- (the user's, in the client, 18 Nov: "when you are in the choose view, click
-- on a plate, and exit again, you would expect to be in the choose view";
-- and "while inside the expanded plate view, the left page still moves to
-- the standard left page")
YD.Choose()
local pieceWas = YD.ShownPiece().from
local mapID = page.plates[1] and page.plates[1].mapID
Check(mapID ~= nil, "setup: a plate on the page")
YD.OpenFull(mapID)
Check(page.mode == "full", "the whole map not opened")
Check(page.choosing and ch:IsShown(), "the ticklist gone with the whole map open")
Check(not page.entries:IsShown() and not page.name:IsShown(), "the left page shown over the ticklist on the whole map")
do
    -- The meter still the plates' page's while a plate's whole map is open.
    local want = YD.MeterWidths(YD.ShownPiece().drawnSlots or {})
    local shown = 0
    for k, f in ipairs(ch.frames) do
        if f:IsShown() then shown = shown + 1 Eq(f.w, want[k], "the whole map open: frame " .. k .. " not its plate's") end
    end
    Eq(shown, #page.choices.plates, "the whole map open: not a frame for each plate of the page")
end
-- A tick there: the whole map stays, the ticklist with it.
local fullRow = Row(function(item) return item.card ~= nil end)
Check(fullRow ~= nil, "setup: a card row")
local fullKey = fullRow.item.card.key
fullRow:Click()
Check(page.mode == "full" and page.choosing and ch:IsShown(), "a tick on the whole map left it or the ticklist")
Check(not page.entries:IsShown(), "the left page shown again after a tick on the whole map")
do
    -- (the recap built again: the slots its page gives, as many as its plates)
    local shown, total = 0, 0
    for _, f in ipairs(ch.frames) do
        if f:IsShown() then shown, total = shown + 1, total + f.w end
    end
    Eq(shown, math.max(#page.choices.plates, 1), "a tick on the whole map: not a frame for each plate")
    Eq(total + (shown - 1) * C.frameGap, C.meter, "a tick on the whole map: the frames not the meter's width")
end
fullRow = Row(function(item) return item.card ~= nil and item.card.key == fullKey end)
fullRow:Click()
YD.FullBack()
Check(page.mode == "plates" and page.choosing and ch:IsShown(), "back from the whole map: the ticklist not there")
Eq(YD.ShownPiece().from, pieceWas, "back on another sitting")
Check(not page.entries:IsShown(), "the left page shown under the ticklist come back")
-- Anything else opened from the whole map gives the left page back.
YD.OpenFull(mapID)
YD.OpenLevel(page.open)
Check(not page.choosing, "the ticklist kept on a level opened from the whole map")
YD.Choose()
YD.OpenFull(mapID)
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
Check(not page.choosing, "the ticklist kept after the ribbon")
-- The whole map opened without the ticklist: back is the plates, as ever.
YD.OpenFull(mapID)
YD.FullBack()
Check(not page.choosing, "the ticklist opened where it was not open")

--------------------------------------------------------------------------
Section("the right-click menus: a place left out, someone left off")

-- (Phase 4: a plate's "Leave this place out" and "Choose what's on this
-- page...", a person's strip's "Leave <name> off this page"; the menu only
-- hides, so neither is ever listed under "Left out of this page")
local CARD = YD.CardSheet
local MW = {
    leavePlace = ns.L["Leave this place out"], choose = ns.L["Choose what's on this page..."],
    hidden = "Left out of this page",   -- (gone from the menu, 18 Nov)
}
ns.Characters.Observe(FOE, { first = "Wrenna", surname = "Tallowbrook" })
j.chosen = nil
J.Touch()
ns.UI.RefreshJourneyPage(false)
Eq(Shown(), "1412 1413 1415", "setup: the diary's three again")
local function PlateOf(mapID)
    for i = 1, page.layout or 0 do
        if page.plates[i].mapID == mapID then return page.plates[i] end
    end
end
local function Menu(owner)
    mock.contextMenu = nil
    owner()
    local out = {}
    for _, child in ipairs(mock.contextMenu and mock.contextMenu.children or {}) do
        if child.text then out[child.text] = child.kind end
    end
    return out
end
local function PersonStrip()
    for i = 1, page.notePool.used do
        local strip = page.notePool[i]
        if strip:IsShown() and strip.guid == FOE then return strip end
    end
end

local lines = Menu(function() PlateOf(1413):Right() end)
Eq(lines[MW.leavePlace], "button", "no \"Leave this place out\" on a plate's menu")
Eq(lines[MW.choose], "button", "no \"Choose what's on this page...\" on a plate's menu")
Eq(lines[MW.hidden], nil, "a list of cards left out with nothing hidden")

-- Choose...: the ticklist, as the link opens it; not offered while it is open.
mock.MenuClick(MW.choose)
Check(page.choosing and page.chooser:IsShown(), "\"Choose what's on this page...\" did not open the ticklist")
lines = Menu(function() PlateOf(1413):Right() end)
Eq(lines[MW.choose], nil, "\"Choose...\" offered with the ticklist open")
Eq(lines[MW.leavePlace], "button", "\"Leave this place out\" gone with the ticklist open")
page.chooser.done:Click()

-- Someone's strip: their menu, the mouse's alone.
local strip = PersonStrip()
Check(strip ~= nil, "setup: the fight's person has a strip")
Check(strip.onRight ~= nil and strip.rightMouse == true, "a person's strip has no menu, or the pad's Y takes it")
lines = Menu(function() strip.onRight() end)
local leaveHer = ns.Fmt(ns.L["Leave %1$s off this page"], "Wrenna")
Eq(leaveHer, "Leave Wrenna off this page", "the person's line in words")
Eq(lines[leaveHer], "button", "no \"Leave <name> off this page\" on their strip")
mock.MenuClick(leaveHer)
Eq(PersonStrip(), nil, "their strip still on the page")
local theirs = 0
for key, v in pairs(j.chosen or {}) do
    if key:find(FOE, 1, true) then
        Eq(v, "out", "a person left off: out on their moments")
        theirs = theirs + 1
    end
end
Check(theirs > 0, "nothing written for a person left off")

-- A place left out: off the page, the next one in.
local before = Shown()
lines = Menu(function() PlateOf(1412):Right() end)
Eq(lines[MW.hidden], nil, "someone left off listed under \"Left out of this page\"")
mock.MenuClick(MW.leavePlace)
Eq(PlateOf(1412), nil, "the place left out still on the page")
Eq(page.layout, 3, "the next place did not come in")
Check(Shown() ~= before and Shown():find("1411") ~= nil, "not the next in line that came in: " .. Shown())
for i = 1, page.layout do
    lines = Menu(function() page.plates[i]:Right() end)
    Eq(lines[MW.hidden], nil, "a place left out listed under \"Left out of this page\"")
end

-- With the pad's Y, none of these: no menu, nothing written.
local was = Copy(j.chosen)
mock.contextMenu = nil
Eq(CARD.PadRight(page.plates[1], nil, true), nil, "the pad's Y offered on a plate (nothing to add here)")
CARD.PadRight(page.plates[1], nil, false)
Eq(mock.contextMenu, nil, "the pad's Y opened the mouse's menu")
Check(Same(was, j.chosen or {}), "the pad's Y wrote a choice")
j.chosen = nil
J.Touch()
ns.UI.RefreshJourneyPage(false)

--------------------------------------------------------------------------
Section("with the pad in hand: no link, and the ticklist given back")

YD.Choose()
Check(page.choosing, "setup: the ticklist open")
local Pad = ns.UI.Pad
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
Check(Pad.Input.Active(), "setup: the pad in hand")
Check(not page.choosing and not ch:IsShown(), "the ticklist stayed open with the pad picked up")
Check(page.entries:IsShown(), "the left page not given back for the pad")
Eq(LinkItem(), nil, "the link offered with the pad in hand")
YD.Choose()
Check(not page.choosing, "the ticklist opened with the pad in hand")
mock.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Check(not Pad.Input.Active(), "setup: the mouse took over")
Check(LinkItem() ~= nil, "the link not back with the mouse")
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}

--------------------------------------------------------------------------
Section("a card kept that the margin had no room for comes into it")

-- (/sd testdata: a level whose first plate's margin leaves a duel off)
SlashCmdList.SOCIALDIARY("testdata")
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
do
    local function Off()
        for _, p in ipairs(T.DiaryPages(page)) do
            T.OpenDiaryPage(page, p.i, p.k)
            for i = 1, page.layout or 0 do
                for _, it in ipairs(page.plates[i].leftOff or {}) do
                    if it.kind == "duel" and it.moments and it.moments[1] then return p, i, it.moments[1] end
                end
            end
        end
    end
    local p, i, m = Off()
    Check(m ~= nil, "setup: testdata has a duel the margin left off")
    if m then
        local function InMargin()
            for _, it in ipairs(page.plates[i].margin or {}) do
                if it.kind == "duel" then return true end
            end
            return false
        end
        Check(not InMargin(), "setup: the duel not in the margin")
        local tj = J.For(ns.ownGUID)
        Chosen.Keep(tj, m)
        ns.UI.RefreshJourneyPage(false)
        T.OpenDiaryPage(page, p.i, p.k)
        Check(InMargin(), "the duel kept is still left off the margin")
        Eq(page.plates[i].margin[1].kind, "duel", "the card kept not laid first")
        tj.chosen = nil
        J.Touch()
    end
end

--------------------------------------------------------------------------
Section("a row's words: short, and never its time again")

-- (the user's, 18 Nov: "Tarren Mill, yesterday at…", "Dun Garok Soldier,
-- 1% h…". A mark's `label` says the row; its day and time are the time
-- column's, its tooltip says the rest.)
Eq(ns.Campfire.Label({ subZone = "Tarren Mill" }), "Tarren Mill", "a campfire's row: not its place alone")
Eq(ns.Campfire.Label({}), "A campfire", "a campfire with no place to name")
Eq(ns.CloseCalls.Label({ name = "Dun Garok Soldier", pct = 1 }), "Dun Garok Soldier, 1%", "a close call's row lost its health")
Eq(ns.Met.Label({ who = "Old Tom", what = "fished off the pier all evening" }), "Old Tom", "a meeting's row: more than who")
Check(ns.UI.JourneyPlate.MARKS.campfire.label and ns.UI.JourneyPlate.MARKS.close.label
    and ns.UI.JourneyPlate.MARKS.met.label, "a mark without its row's label")
do
    local kinds, rows = {}, 0
    for _, p in ipairs(T.DiaryPages(page)) do
        T.OpenDiaryPage(page, p.i, p.k)
        YD.Choose()
        if page.choosing then
            for _, item in ipairs(page.chooser.list.data) do
                local m = item.card and item.card.moment
                if m then
                    rows = rows + 1
                    kinds[m.kind] = true
                    Check(not item.label:find(item.time, 1, true), "a row says its time twice: " .. item.label)
                    Check(not item.label:find("yesterday", 1, true) and not item.label:find(" on %d"),
                        "a row says its day: " .. item.label)
                    if m.kind == "close" then
                        Check(item.label:find("%d+%%$") ~= nil and not item.label:find("health", 1, true),
                            "a close call's row not short, with its health: " .. item.label)
                    elseif m.kind == "campfire" then
                        Eq(item.label, ns.Campfire.Label(m.campfire), "a campfire's row not its place")
                    end
                end
            end
            YD.Unchoose(true)
        end
    end
    Check(rows > 0 and kinds.close and kinds.campfire, "setup: testdata's close calls and campfires in the ticklist")
end

--------------------------------------------------------------------------
Section("the meter of a page with every place left out: one empty frame")

do
    local tj = J.For(ns.ownGUID)
    local p = T.DiaryPages(page)[1]
    T.OpenDiaryPage(page, p.i, p.k)
    YD.Choose()
    Check(page.choosing, "setup: the ticklist open")
    for _ = 1, 40 do
        local on
        for _, row in ipairs(page.chooser.list.rows) do
            if row:IsShown() and row.item and row.item.zone and row.item.row.on then on = row end
        end
        if not on then break end
        on:Click()
    end
    Eq(#page.choices.plates, 0, "setup: no plate left on the page")
    local shown = {}
    for k, f in ipairs(page.chooser.frames) do if f:IsShown() then shown[#shown + 1] = k end end
    Eq(table.concat(shown, " "), "1", "an empty page: not one frame")
    local f = page.chooser.frames[1]
    Eq(f.w, C.meter, "the empty frame not the whole width")
    Eq(f.kind, nil, "the empty frame not empty")
    GameTooltip:Hide()
    f.scripts.OnEnter(f)
    Eq(GameTooltip.text, WORDS.noMaps, "the empty frame's tooltip")
    f.scripts.OnLeave(f)
    YD.Unchoose(true)
    tj.chosen = nil
    J.Touch()
end
