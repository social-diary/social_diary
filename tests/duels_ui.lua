-- Duels on Your Diary's plates (.claude/ui-proposal/duels.md, signed 15
-- Oct): one filled flag where a series began, won or lost alike, its
-- tooltip telling which; one note a plate for its biggest series, S only
-- and words only: in a full plate's margin (order 85, after the people
-- only seen, before the campfire), under a light plate's caption, or glued
-- across a light plate's print where good luck's S is not; the caption's
-- words where it found no room, filler, never past their foot; the recap
-- moment light and below a stay's rank, so it opens no plate of its own.
--
-- The mock measures every string at 6 px a byte: the sizes asserted here
-- are the mock's, not the client's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate
local Duels = ns.Duels
local Slip = Duels.Slip
local NB = "\194\160"

local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local BARRENS = 1413
local BRAM = "Player-0000-7E57D001"
ns.Characters.Observe(BRAM, { first = "Bram", surname = "Redfen", class = "WARRIOR", race = "Orc", level = 12,
    sex = 2, time = now })

local function Rec(counts, extra)
    local rec = { t = now - 600, ended = now - 480, mapID = BARRENS, x = 0.5, y = 0.5, subZone = "Raptor Grounds",
        zone = "The Barrens" }
    for k, v in pairs(counts) do rec[k] = v end
    for k, v in pairs(extra or {}) do rec[k] = v end
    return rec
end

--------------------------------------------------------------------------
Section("the recap's moment: light, and below a stay")

local Recap = ns.JourneyRecap
Eq(Recap.RANK.duel, 6.5, "a duel's rank")
Check(Recap.RANK.duel > Recap.RANK.stay and Recap.RANK.duel < Recap.RANK.road, "a duel's rank is not between a "
    .. "stay and the road")
Eq(Recap.LIGHT.duel, true, "a duel is not a light kind")
Eq(Recap.MOMENTS.duel.list, "duels", "a duel's list")
Eq(Recap.MOMENTS.duel.field, "duel", "a duel's field")

--------------------------------------------------------------------------
Section("the caption's words")

local function M(kind, extra)
    local m = { kind = kind, t = now - 600 }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end
local function Plated(moments) return { mapID = BARRENS, moments = moments } end
local function Caption(p, said)
    local s = { named = {}, find = {} }
    for k, v in pairs(said or {}) do s[k] = v end
    return (Text.PlateCaption(p, nil, s):gsub(NB, " "))
end
local won, lost = Rec({ won = 1, last = "won" }), Rec({ lost = 1, last = "lost" })
local alone = Plated({ M("duel", { duel = won }) })
Eq(Caption(alone, { duel = true }), "A duel won in Raptor Grounds.", "a duel alone, its note left off")
Eq(Caption(alone, {}), "Raptor Grounds.", "a duel alone, its note beside it: the place, for the note to finish")
local bare = Plated({ M("duel", { duel = Rec({ lost = 1, last = "lost" }, { subZone = "The Barrens" }) }) })
Eq(Caption(bare, { duel = true }), "A duel lost.", "a subzone with the zone's own name is no place")
Eq(Caption(bare, {}), "On the road.", "no place, the note beside it")
local both = Plated({ M("duel", { duel = won }), M("duel", { duel = Rec({ lost = 3, won = 1, last = "lost" },
    { subZone = "The Stagnant Oasis" }) }) })
Eq(Caption(both, { duel = true }), "Duels mostly lost.", "two places, mostly lost")
local died = Plated({ M("death"), M("duel", { duel = lost }) })
Eq(Caption(died, { duel = true }), "A death, and a duel lost.", "after a death")
Eq(Caption(died, {}), "A death.", "its note beside it")
local fire = { t = now - 500, mapID = BARRENS, x = 0.5, y = 0.5, subZone = "Raptor Grounds" }
local camped = Plated({ M("death"), M("duel", { duel = won }), M("campfire", { campfire = fire }) })
Eq(Caption(camped, { duel = true, campfire = true }), "A death, a duel won, and a campfire.",
    "before the campfire, as in the margin")
local stayed = Plated({ M("stay", { seg = { subZone = "Raptor Grounds", mapID = BARRENS }, seconds = 1500 }),
    M("duel", { duel = won }) })
Eq(Caption(stayed, { duel = true }), "Raptor Grounds, 25 min, and a duel won.", "after a stay")

--------------------------------------------------------------------------
Section("the flag: one for every duel, after the road's deaths")

local spec = Plate.MARKS.duel
Check(spec ~= nil, "no flag registered")
Eq(spec.order, 65, "the flag's order")
Check(spec.order > Plate.ROAD_DEATHS and spec.order < Plate.MARKS.campfire.order,
    "the flag is not between the road's deaths and the campfire")
Eq(spec.arg, nil, "the flag is drawn by its outcome")
Eq(Plate.CAP.duels, 20, "the flag's cap")
do
    -- Through a kit that records what is drawn.
    local drawn = { box = 0, dot = 0, quad = 0, place = 0, fill = 0 }
    local function Kit(quads)
        local pool = { Next = function() return CreateFrame("Frame"):CreateTexture() end }
        return { ink = pool, inner = pool, halo = pool, INK_STRONG = ns.Style.INK_STRONG, P = { 1, 1, 1 },
            Box = function() drawn.box = drawn.box + 1 end, Dot = function() drawn.dot = drawn.dot + 1 end,
            Fill = function() drawn.fill = drawn.fill + 1 end, Light = function() return 1 end,
            Quad = function() drawn.quad = drawn.quad + 1 return quads end,
            Place = function() drawn.place = drawn.place + 1 end }
    end
    spec.draw(Kit(true), 50, 50)
    Eq(drawn.box, 1, "the pole")
    Eq(drawn.dot, 1, "the stake's dot")
    Eq(drawn.quad, 2, "the cloth's two halves, split at the notch")
    Eq(drawn.place, 0, "a box for the cloth where corners move")
    drawn = { box = 0, dot = 0, quad = 0, place = 0, fill = 0 }
    spec.draw(Kit(false), 50, 50)
    Eq(drawn.quad, 1, "the cloth's lower half tried where corners cannot move")
    Eq(drawn.place, 1, "no box for the cloth where corners cannot move")
    -- The tooltip: the outcome under the mouse, as the flag no longer shows it.
    local title, lines = spec.tip({ kind = "duel", duel = Rec({ won = 3, lost = 1, last = "won" }, { guid = BRAM }) },
        now)
    Eq(title, "Duelled Bram", "the flag's tooltip names the opponent")
    Eq(lines[1], "Won 3, lost 1", "the flag's tooltip tells the outcome")
    Eq(lines[2], "In Raptor Grounds", "the flag's tooltip tells where")
end

--------------------------------------------------------------------------
Section("the note: one a plate, the biggest series")

do
    local small = Rec({ won = 1, last = "won" }, { t = now - 900 })
    local big = Rec({ won = 2, lost = 3, last = "lost" }, { t = now - 2000, guid = BRAM })
    local late = Rec({ fled = 2, theyFled = 3, last = "fled" }, { t = now - 100 })
    local marks = { { x = 10, y = 10, at = { 100, 100 }, list = { { kind = "duel", duel = small }, { kind = "duel", duel = big } } },
        { x = 40, y = 10, at = { 300, 100 }, list = { { kind = "duel", duel = late } } } }
    local chosen = Slip.Choose(marks)
    Eq(chosen.rec, late, "five duels, the latest of equals")
    Eq(chosen.mark[1], 300, "its leader goes to its own flag")
    Eq(#chosen.recs, 3, "every series on the plate")
    Eq(chosen.recs[1], big, "the series oldest first")
    marks[2] = nil
    Eq(Slip.Choose(marks).rec, big, "the series with the most duels")
    Eq(Slip.Choose({}), nil, "a note with no duel")

    local parent = CreateFrame("Frame")
    local slip = Slip.New(parent)
    slip:SetDuel({ rec = big, mark = { 100, 100 } }, "seed", now)
    local w, h = slip:Layout(250, 90, 176)
    Eq(slip:Words(), "lost to Bram 3 to 2", "the note's words, named")
    Check(not slip.overfull and w <= 176 and h > 0, "the note does not fit a 176 px column")
    slip:Layout(250, 90, 122)
    Eq(slip:Words(), "lost 3 duels to 2", "too long for the narrowest column in the mock: nameless")
    Check(not slip.overfull, "the nameless note does not fit 122 px")
    slip:Layout(250, 90, 60)
    Check(slip.overfull, "a note wider than its box is not overfull")
    slip:Layout(250, 90, 176)
    Eq(slip:Words(), "lost to Bram 3 to 2", "laid wider again, named again")
    local tip = slip.tip()
    Eq(tip[1][1], "Duelled Bram", "the note's tooltip, its series'")
    ns.SetSetting("flatSheets", true)
    slip:Layout(250, 90, 176)
    Eq(slip.turn, 0, "laid flat, the note turns")
    ns.SetSetting("flatSheets", false)

    -- On a print: named where it fits, else nameless, else not at all.
    local plan = Slip.PrintPlan(big, 136)
    Eq(plan and plan.words, "lost to Bram 3 to 2", "the snapshot's room, named")
    Eq(plan.Hb, Slip.PRINT.height, "the print's slip height")
    Eq(Slip.PrintPlan(big, 116).words, "lost 3 duels to 2", "the tucked print's room, in the mock: nameless")
    Eq(Slip.PrintPlan(big, 40), nil, "no room on the print")
    local SNAP = ns.UI.JourneyLook.LAYOUT.FL[2]
    local l, r = Slip.PrintRoom(SNAP)
    Eq(l, SNAP.pc + 2, "past the lower-left photo corner")
    Eq(r, SNAP.w - Slip.PRINT.edge, "to the print's edge where its corner came unstuck")
end

--------------------------------------------------------------------------
Section("on a light plate's print, and good luck keeping it")

ns.Diary.Add(BRAM, { source = "test" })
local page
local LAYOUT = ns.UI.JourneyLook.LAYOUT
local j
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
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
local function Shown(pool)
    local list = {}
    for i = 1, (page[pool] and page[pool].used or 0) do
        if page[pool][i]:IsShown() then list[#list + 1] = page[pool][i] end
    end
    return list
end
local function LinkOf(strip)
    for _, link in ipairs(page.links) do
        if link.strip == strip then return link end
    end
end

-- Mulgore with Bram, then a first visit to Zephras Isle, where you
-- duelled Bram: a full plate and a light one, F+L where it holds. `luck`
-- puts good luck on the isle as well.
local LUCK = { mapID = 2665, x = 0.5, y = 0.5, level = 12, questID = 9, title = "Isle Eggs", item = "Isle Egg",
    need = 2, kills = 2, expected = 20, npcID = 7, name = "Isle Raptor" }
local function Road(duel, luck)
    local t5 = now - 50000
    ns.db.journey[SELF.guid] = nil
    j = ns.Journey.Begin(SELF.guid, t5, 12, 1412)
    Seg({ kind = "stop", from = t5, to = t5 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 30, seconds = 1800,
        levelFrom = 12, levelTo = 12 })
    ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t5 + 600, endedAt = t5 + 1500,
        participants = { [BRAM] = { since = t5 + 600, last = t5 + 1500, seconds = 900, levelStart = 12 } } })
    Seg({ kind = "flight", from = t5 + 1800, to = t5 + 2100, mapID1 = 1412, x1 = 0.5, y1 = 0.5, mapID2 = 2665,
        x2 = 0.5, y2 = 0.5, levelFrom = 12, levelTo = 12 })
    Seg({ kind = "stop", from = t5 + 2100, to = t5 + 3900, mapID = 2665, x = 0.5, y = 0.5, r = 30, seconds = 1800,
        levelFrom = 12, levelTo = 12 })
    j.duels, j.hunts = {}, {}
    if duel then
        duel.t, duel.ended, duel.mapID, duel.x, duel.y = t5 + 2700, t5 + 2900, 2665, 0.5, 0.5
        j.duels[1] = duel
    end
    if luck then
        luck.t = t5 + 3000
        j.hunts = { luck }
    end
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(false)
    return Open(12)
end

ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()

do
    local DUEL = { won = 1, last = "won", guid = BRAM, subZone = "Zephras Isle" }
    local e = Road(DUEL)
    Check(e.plates[2] and e.plates[2].light, "setup: the duel's plate is light")
    Eq(page.pattern, "F+L", "a duel on the print keeps the print tucked in")
    local onPrint = page.plates[2]
    local s = onPrint.duelPrint
    Check(s ~= nil, "the duel is not on the tucked print")
    Eq(s and s.rec, DUEL, "the print's series")
    Eq(s and s.words, Duels.Note(DUEL, false), "the tucked print's words, nameless in the mock")
    for _, it in ipairs(onPrint.margin or {}) do Check(it.kind ~= "duel", "a duel note in the print's margin too") end
    Eq(#Shown("duelPool"), 0, "a margin note beside the print")
    Eq(page.duelsWritten, 1, "the page does not count the print's note")
    -- Where it lies: along the foot, on the print, clear of the caption.
    local sp, slot = s.s, onPrint.slot
    for _, pt in ipairs(sp.label) do
        Check(pt[1] >= 0 and pt[1] <= slot.w and pt[2] >= 0 and pt[2] <= slot.h, "the note leaves the print")
    end
    Check(sp.top + sp.plan.Hb <= slot.h - Slip.PRINT.bottom + 0.01, "the note is not at the print's foot")
    Check(s.box[2] + s.box[4] < slot.cap.y, "the note runs into the caption under the print")
    -- Its leader up to the flag, well above it in the print's middle.
    local link = LinkOf(s)
    Check(s.far and link and link.mark == onPrint.duel.mark, "the print's note has no leader to its flag")
    -- Under the mouse: the flag's tooltip.
    GameTooltip.text = nil
    onPrint.duelHit.scripts.OnEnter(onPrint.duelHit)
    Eq(GameTooltip.text, "Duelled Bram", "the print's note's tooltip")
    onPrint.duelHit.scripts.OnLeave(onPrint.duelHit)
    -- The words: the note says it, so they don't.
    local said = page.captionPool[2]:GetText()
    Check(not said:find("duel"), "the print's words say the duel beside its note: " .. said)
    Eq(onPrint.duelTold, false, "the words told a duel on the print")

    -- The flag under the note: the note goes to the foot's right end.
    local a0, b0 = Slip.PrintRoom(slot)
    local placed = Slip.Print({ Place = function() end, Texture = function() return CreateFrame("Frame"):CreateTexture() end,
        Text = function() return ns.Style.Text(UIParent, ns.Style.FONT.small) end },
        { rec = DUEL, x = a0 + 10, y = slot.h - 10 }, slot, "t", false)
    Eq(placed.left, b0 - placed.plan.Wb, "the flag under the note, but the note stays at the left")

    -- Laid flat: square on the print.
    ns.SetSetting("flatSheets", true)
    ns.UI.RedrawJourneyPage()
    s = page.plates[2].duelPrint
    Check(s and math.abs(s.s.label[1][2] - s.s.label[2][2]) < 1e-6, "laid flat, the print's note is turned")
    ns.SetSetting("flatSheets", false)
    ns.UI.RedrawJourneyPage()

    -- Good luck on the isle as well: it is not filler, so it keeps the
    -- print (FL, its S not on the tucked one); the duel has no room under
    -- FL's print's caption, so the words say it, or, where that would run
    -- them past the foot, the flag alone.
    e = Road({ won = 1, last = "won", guid = BRAM, subZone = "Zephras Isle" }, LUCK)
    Eq(page.pattern, "FL", "setup: the luck gives up the tucked print")
    onPrint = page.plates[2]
    Check(onPrint.print ~= nil, "setup: good luck on the print")
    Eq(onPrint.duelPrint, nil, "the duel took the print from good luck")
    Eq(#Shown("duelPool"), 0, "a duel note under FL's print")
    said = page.captionPool[2]:GetText():gsub(NB, " ")
    if onPrint.duelTold then
        Check(said:find("a duel won", 1, true), "the words do not say the duel: " .. said)
    else
        Check(not said:find("duel"), "the words say the duel they were not told: " .. said)
    end
    Check(onPrint.captionFoot <= 528, "the print's words run past the foot: " .. onPrint.captionFoot)
    Eq(page.duelsWritten, 0, "a duel note counted that was left off")
end

--------------------------------------------------------------------------
Section("/sd testdata: duels on the plates")

ns.TestData.Write()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()

-- Captions wrap roughly as the client's do (as the plates' render tool
-- has them, .claude/skills/plates/tools/plate_dump.lua).
local function Patch(fs, per, line)
    if fs.patched then return end
    fs.patched = true
    fs.GetStringHeight = function(self)
        local width = (self.width or 0) > 0 and self.width or 1e9
        if not self.text or self.text == "" then return 0 end
        return line * math.max(1, math.ceil(#self.text * per / width))
    end
    fs.GetUnboundedStringWidth = function(self) return #(self.text or "") * per end
end
for _, pair in ipairs({ { "headingPool", 7, 18 }, { "captionPool", 6.6, 15 } }) do
    local pool = page[pair[1]]
    local next = pool.Next
    pool.Next = function(self)
        local fs = next(self)
        Patch(fs, pair[2], pair[3])
        return fs
    end
end
local function OpenAt(i)
    page.open = i
    page.mode = "plates"
    ns.UI.RedrawJourneyPage()
end
local function Entry(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then return i, e end
    end
end
local function Words()
    local said = {}
    for k = 1, page.captionPool.used do
        if page.captionPool[k]:IsShown() then said[#said + 1] = (page.captionPool[k]:GetText() or ""):gsub(NB, " ") end
    end
    return table.concat(said, " | ")
end

-- Wherever a note is shown: one a plate at most, in its margin, its words
-- its series' (named or not), its leader to that series' flag.
local shown = 0
for i in ipairs(page.recap.entries) do
    OpenAt(i)
    local inMargins = 0
    for _, p in ipairs(page.plates) do
        if p:IsShown() then
            local n = 0
            for _, it in ipairs(p.margin or {}) do
                if it.kind == "duel" then
                    n = n + 1
                    local words = it.note:Words()
                    Check(words == Duels.Note(it.duel.rec, true) or words == Duels.Note(it.duel.rec, false),
                        "a note's words are not its series': " .. words)
                    local link = LinkOf(it.note)
                    Check(link and link.mark == p.duel.mark, "a note's leader goes elsewhere than its flag")
                    -- Before the campfire, after everyone else.
                    local after = false
                    for _, other in ipairs(p.margin) do
                        if other == it then after = true elseif after then
                            Check(other.kind == "campfire", "a note before " .. other.kind)
                        end
                    end
                end
            end
            Check(n <= 1, "more than one duel note on a plate")
            inMargins = inMargins + n
        end
    end
    Eq(#Shown("duelPool"), inMargins, "a duel note shown that is not in a margin")
    shown = shown + inMargins
end
Check(shown >= 2, "fewer duel notes on the testdata pages than expected: " .. shown)

-- Level 12: the crag's duel won against someone the diary never read, in
-- the narrowest column (122 px) after the lucky card, before the campfire.
do
    OpenAt(Entry(12))
    local p = page.plates[2]
    Eq(p.counts.duels, 1, "level 12's flag")
    local kinds = {}
    for _, it in ipairs(p.margin or {}) do kinds[#kinds + 1] = it.kind end
    Eq(table.concat(kinds, ","), "lucky,duel,campfire", "level 12's margin")
    Eq(Shown("duelPool")[1]:Words(), "won a duel", "level 12's note, nameless")
    Eq(page.duelsWritten, 1, "level 12's notes")
end

-- Level 11: two won and one lost against Tester in the valley, on FL's
-- print, where no slip finds room under the caption: the note lies across
-- the print's foot (variant D), and counts as written.
do
    OpenAt(Entry(11))
    local onPrint
    for _, p in ipairs(page.plates) do
        if p:IsShown() and p.duelPrint then onPrint = p end
    end
    Check(onPrint ~= nil, "level 11's duel note not on its print")
    Eq(onPrint and onPrint.duelPrint.words, "beat Tester 2 to 1", "level 11's print note")
    Eq(onPrint and onPrint.print, nil, "setup: level 11's print has good luck on it")
    Eq(#Shown("duelPool"), 0, "level 11's note in the margin as well")
end

-- Level 15: a flight each way by the raptors, two flags; the margin is
-- full (a find, a close call, a slow hunt), so the note is left off and
-- the words say it, before the campfire's.
do
    OpenAt(Entry(15))
    local p = page.plates[1]
    Eq(p.counts.duels, 2, "level 15's two flags, a few yards apart")
    Eq(#Shown("duelPool"), 0, "setup: level 15's note found room")
    Eq(page.duelsWritten, 0, "a note counted that was left off")
    Eq(p.duelTold, true, "level 15's words left the duels out")
    Check(Words():find("duels won and lost, and a campfire.", 1, true), "level 15's words: " .. Words())
    local a, b = p.duelMarks[1], p.duelMarks[2]
    Check(math.abs(a.x - b.x) + math.abs(a.y - b.y) > Plate.MARK.merge, "the two flags are one mark")
end

-- The week of the oasis: the series with Tester on the full plate, its own
-- note beside Tester's (never folded into it), lost 3 to 2.
do
    -- Its sitting with Tester is a page of its own (F) since the pages go
    -- by sitting: the page whose plate has Tester's time together.
    local full
    for _, at in ipairs(T.DiaryPages(page)) do
        T.OpenDiaryPage(page, at.i, at.k)
        for _, p in ipairs(page.plates) do
            if p:IsShown() and (p.counts.duels or 0) > 0 and at.e.kind == "week" then full = p end
        end
        if full then break end
    end
    Check(full ~= nil, "setup: no page of the oasis week with its duel")
    local person, duel
    for _, it in ipairs(full.margin or {}) do
        if it.kind == "person" then person = it end
        if it.kind == "duel" then duel = it end
    end
    Check(person and duel, "the week's full plate has Tester's note and the duel's apart")
    -- (On its own page the plate is alone, its notes in the row of three
    -- under it, where Tester's name does not go beside the score: the
    -- nameless words, his own note beside it naming him.)
    Eq(duel and duel.note:Words(), "lost 3 duels to 2", "the week's note")
    Eq(full.counts.duels, 1, "the week's flag")
end

-- Laid flat, the notes lie square.
ns.SetSetting("flatSheets", true)
OpenAt(Entry(12))
for _, s in ipairs(Shown("duelPool")) do Eq(s.turn, 0, "laid flat, a note turns") end
ns.SetSetting("flatSheets", false)
