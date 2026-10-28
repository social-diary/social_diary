-- Campfires in the book (.claude/ui-proposal/campfire.md, the user's
-- decisions of 14 Oct): the People page's row, "You and Bram sat by a
-- campfire together in Lushwater Oasis, The Barrens"; and on Your Diary's
-- plates the fire's ink mark (a flame on two crossed logs), one slip a
-- plate in the margin saying exactly "sat by a campfire" with no count,
-- last of the margin and the first left off, under a light plate's caption
-- where there is room, and where there is none the caption's words saying
-- it, FL kept as FL. Filler never runs the words past their foot.
--
-- The mock measures every string at 6 px a byte: the sizes asserted here
-- are the mock's, not the client's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local Slip = ns.Campfire.Slip
local Plate = ns.UI.JourneyPlate

-- The mock's own day, as the plates' render tool has it: the cap's weeks
-- fall by the calendar, and on this day the oasis week is LF.
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local BARRENS = 1413
local NB = "\194\160"

--------------------------------------------------------------------------
Section("the People page's row")

local BRAM = "Player-0000-7E57CF01"
ns.Characters.Observe(BRAM, { first = "Bram", class = "WARRIOR", race = "Orc", level = 12, sex = 2, time = now })
local function Row(zone, subZone)
    return { type = "campfire", time = now - 60, zone = zone, context = { subZone = subZone } }
end
local function Line(row, guid)
    local _, text = ns.UI.DescribeItem({ kind = "row", row = row }, guid)
    return (text:gsub(NB, " "))
end
Eq(Line(Row("The Barrens", "Lushwater Oasis"), BRAM),
    "You and Bram sat by a campfire together in Lushwater Oasis, The Barrens", "the row, the user's words")
Eq(Line(Row("The Barrens", nil), BRAM), "You and Bram sat by a campfire together in The Barrens", "no subzone")
Eq(Line(Row("The Barrens", ""), BRAM), "You and Bram sat by a campfire together in The Barrens", "an empty subzone")
Eq(Line(Row("Mulgore", "Mulgore"), BRAM), "You and Bram sat by a campfire together in Mulgore",
    "a subzone with the zone's name, said twice")
Eq(Line(Row(nil, "Bloodhoof Village"), BRAM), "You and Bram sat by a campfire together in Bloodhoof Village",
    "no zone")
Eq(Line(Row(nil, nil), nil), "Sat by a campfire together", "no one known and nowhere")
local _, _, _, icon = ns.UI.DescribeItem({ kind = "row", row = Row("The Barrens") }, BRAM)
Eq(icon, "campfire", "the row's icon")
Check(ns.Style.ART.campfire ~= nil, "no art for the row's icon")

-- The picker's reason, from a fresh row.
ns.Interactions.Add(BRAM, "campfire", { where = { zone = "The Barrens" }, context = { subZone = "Lushwater Oasis" } })
local why
for _, c in ipairs(ns.Candidates()) do
    if c.guid == BRAM then why = c.why end
end
Eq(why, "sat by a campfire together", "the picker's reason")
local row = ns._test.LatestInteraction(BRAM, "campfire")
Eq(Line(row, BRAM), "You and Bram sat by a campfire together in Lushwater Oasis, The Barrens", "a row as kept")

--------------------------------------------------------------------------
Section("the caption's words")

local function Fire(sub, t) return { t = t or now - 600, mapID = BARRENS, x = 0.5, y = 0.5, subZone = sub } end
local function Plated(moments) return { mapID = BARRENS, moments = moments } end
local function M(kind, extra)
    local m = { kind = kind, t = now - 600 }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end
local alone = Plated({ M("campfire", { campfire = Fire("Lushwater Oasis") }) })
Eq(Text.PlateCaption(alone, nil, { named = {}, find = {}, campfire = true }), "By a campfire in Lushwater Oasis.",
    "a fire alone, its slip left off")
Eq(Text.PlateCaption(alone, nil, { named = {}, find = {}, campfire = false }), "Lushwater Oasis.",
    "a fire alone, its slip beside it: the place, for the slip to finish")
local bare = Plated({ M("campfire", { campfire = Fire(nil) }) })
Eq(Text.PlateCaption(bare, nil, { named = {}, find = {}, campfire = false }), "On the road.",
    "a fire with no subzone, its slip beside it")
Eq(Text.PlateCaption(bare, nil, { named = {}, find = {}, campfire = true }), "By a campfire.", "no subzone, left off")
local twice = Plated({ M("campfire", { campfire = Fire("Lushwater Oasis") }),
    M("campfire", { campfire = Fire("Lushwater Oasis", now - 300) }) })
Eq(Text.PlateCaption(twice, nil, { named = {}, find = {}, campfire = true }), "By a campfire in Lushwater Oasis.",
    "one place sat by twice: no count")
local two = Plated({ M("campfire", { campfire = Fire("Lushwater Oasis") }),
    M("campfire", { campfire = Fire("The Stagnant Oasis", now - 300) }) })
Eq(Text.PlateCaption(two, nil, { named = {}, find = {}, campfire = true }), "By campfires.", "two places")
local died = Plated({ M("death"), M("campfire", { campfire = Fire("Lushwater Oasis") }) })
Eq(Text.PlateCaption(died, nil, { named = {}, find = {}, campfire = true }), "A death, and a campfire.",
    "last of the list")
Eq(Text.PlateCaption(died, nil, { named = {}, find = {}, campfire = false }), "A death.", "its slip beside it")
local stayed = Plated({ M("stay", { seg = { subZone = "Lushwater Oasis", mapID = BARRENS }, seconds = 1500 }),
    M("campfire", { campfire = Fire("Lushwater Oasis") }) })
local words = Text.PlateCaption(stayed, nil, { named = {}, find = {}, campfire = true }):gsub(NB, " ")
Eq(words, "Lushwater Oasis, 25 min, and a campfire.", "after a stay")
Eq(ns.Campfire.WORDS, "sat by a campfire", "the slip's words, the user's")
local title, lines = ns.Campfire.Tip(Fire("Lushwater Oasis"), now)
Eq(title, "Sat by a campfire", "the tooltip's title")
Eq(lines[1], "In Lushwater Oasis", "the tooltip's place")
Eq(#lines, 2, "the tooltip's lines")

--------------------------------------------------------------------------
Section("the slip: one a plate, its leader to the nearest fire")

do
    local marks = { { x = 10, y = 10, at = { 100, 100 }, list = { { kind = "campfire", t = 5 }, { kind = "campfire", t = 9 } } },
        { x = 40, y = 10, at = { 300, 100 }, list = { { kind = "campfire", t = 7 } } } }
    local chosen = Slip.Choose(marks)
    Eq(#chosen.list, 3, "every sitting on the plate")
    Eq(chosen.list[1].t, 5, "the sittings oldest first")
    Eq(chosen.mark[1], 100, "the latest fire stands in for the slip's place")
    Eq(#chosen.marks, 2, "every fire for the leader")
    Eq(Slip.Choose({}), nil, "a slip with no fire")
    local parent = CreateFrame("Frame")
    local slip = Slip.New(parent)
    slip:SetCampfire(chosen, "seed", now)
    local w, h = slip:Layout(250, 90, 176)
    Eq(slip:Words(), "sat by a campfire", "the slip's words")
    Check(not slip.overfull and w <= 176 and h > 0, "the slip does not fit a 176 px column")
    Check(w <= 122, "the slip is wider than the narrowest column (" .. w .. ")")
    Eq(Slip.Mark(chosen, slip)[1], 300, "the leader goes to the farther fire")
    slip:Layout(250, 90, 100)
    Check(slip.overfull, "a slip wider than its box is not overfull")
    local tip = slip.tip()
    Eq(#tip, 3 * 2, "the slip's tooltip tells each sitting")
    ns.SetSetting("flatSheets", true)
    slip:Layout(250, 90, 176)
    Eq(slip.turn, 0, "laid flat, the slip turns")
    ns.SetSetting("flatSheets", false)
end

--------------------------------------------------------------------------
Section("/sd testdata: campfires on the plates")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

-- Captions wrap roughly as the client's do (as the plates' render tool
-- has them, .claude/skills/plates/tools/plate_dump.lua): the body 6.6 px a
-- letter and 15 px a line, the hand 7 and 18; the body `wide` times that.
local wide = 1
local function Patch(fs, per, line)
    if fs.patched then return end
    fs.patched = true
    fs.GetStringHeight = function(self)
        local width = (self.width or 0) > 0 and self.width or 1e9
        if not self.text or self.text == "" then return 0 end
        local scale = line == 15 and wide or 1
        return line * math.max(1, math.ceil(#self.text * per * scale / width))
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
local function Slips()
    local list = {}
    for k = 1, page.campfirePool.used do
        local s = page.campfirePool[k]
        if s:IsShown() then list[#list + 1] = s end
    end
    return list
end
local function Fires(p)
    local n = 0
    for _, m in ipairs(p.plan and p.plan.moments or {}) do
        if m.kind == "campfire" then n = n + 1 end
    end
    return n
end
local function Last(p)
    local margin = p.margin or {}
    return margin[#margin] and margin[#margin].kind
end
local function Leader(slip)
    for _, link in ipairs(page.links) do
        if link.strip == slip then return link end
    end
end

-- Wherever a slip is shown: last of its margin, its words exactly, its
-- leader to one of its plate's fires.
local shown = 0
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    for _, s in ipairs(Slips()) do
        shown = shown + 1
        Eq(s:Words(), "sat by a campfire", "a slip's words")
        local link = Leader(s)
        Check(link ~= nil, "a slip has no leader")
        local on = false
        for _, p in ipairs(page.plates) do
            for _, mark in ipairs(p:IsShown() and p.campfireMarks or {}) do
                on = on or (link and link.mark == mark.at)
            end
        end
        Check(on, "a slip's leader goes elsewhere than a fire")
    end
    local slips = 0
    for _, p in ipairs(page.plates) do
        if p:IsShown() then
            for _, it in ipairs(p.margin or {}) do
                if it.kind == "campfire" then
                    slips = slips + 1
                    Eq(Last(p), "campfire", "a slip before the rest of its margin")
                end
            end
        end
    end
    Eq(#Slips(), slips, "a slip shown that is not in a margin")
end
Check(shown >= 3, "fewer slips on the testdata pages than expected: " .. shown)

-- Level 12: its fire on the full plate drawn in the narrowest column
-- (122 px), after the lucky card; the fire's mark counted.
do
    Open(Entry(12))
    local p = page.plates[2]
    Eq(p.counts.campfires, 1, "level 12's fire marks")
    Eq(Last(p), "campfire", "level 12's slip, after the lucky card")
    Eq(page.campfiresWritten, 1, "level 12's slips")
end

-- Level 15: two fires, the first sat by twice: two marks, one slip at
-- most, and every sitting in its tooltip. The margin is full, so the slip
-- is the first left off and the words say it.
do
    Open(Entry(15))
    local p = page.plates[1]
    Eq(Fires(p), 3, "level 15's sittings")
    Eq(p.counts.campfires, 2, "level 15's two fires, one sat by twice")
    Eq(#p.campfire.list, 3, "every sitting for the slip")
    Check(#Slips() <= 1, "more than one slip a plate")
    Eq(#Slips(), 0, "setup: level 15's slip found room")
    Eq(page.campfiresWritten, 0, "a slip counted that was left off")
    Check(#p.margin >= 3, "the slip cost a card its place: " .. #p.margin)
    local said = {}
    for k = 1, page.captionPool.used do said[#said + 1] = page.captionPool[k]:GetText() or "" end
    Check(table.concat(said, " | "):find("and a campfire%.$"), "the words leave the fire out: "
        .. table.concat(said, " | "))
    -- Each fire keeps its radius clear of every other mark (Apart).
    local a, b = p.campfireMarks[1], p.campfireMarks[2]
    Check(math.abs(a.x - b.x) + math.abs(a.y - b.y) > Plate.MARK.merge, "the two fires are one mark")
end

-- Over the plate (one plate, its caption across the top), the fire's words
-- never cost the caption its place: with a wider hand, level 15's words
-- would take two lines with the fire and one without, so they leave it.
do
    wide = 434 / (40 * 6.6)
    Open(Entry(15))
    local p = page.plates[1]
    Eq(p.captionOver, true, "level 15's caption went under the plate for its fire")
    Eq(p.camped, false, "level 15's words kept the fire over the plate")
    wide = 1
    Open(Entry(15))
    Eq(page.plates[1].camped, true, "setup: level 15's words leave the fire out")
end

-- Level 11: FL kept (never FF for a campfire); the print's slip has no
-- room under its caption, so the words say it.
do
    Open(Entry(11))
    Eq(page.pattern, "FL", "level 11's page")
    local p = page.plates[2]
    Eq(p.slot.light, true, "level 11's print is drawn full")
    Eq(Fires(p), 1, "setup: level 11's print has its fire")
    Eq(#Slips(), 0, "a slip under FL's print")
    Eq(p.camped, true, "the print's words do not say the fire")
    local said = page.captionPool[2]:GetText():gsub(NB, " ")
    Eq(said, "First Aid at 75, and a campfire.", "level 11's print's words")
end

-- Level 13: FL's print, its words long already; filler does not run them
-- a third line past the page's foot, so its mark alone tells it.
do
    Open(Entry(13))
    Eq(page.pattern, "FL", "level 13's page")
    local p = page.plates[2]
    Eq(Fires(p), 1, "setup: level 13's print has its fire")
    Eq(p.camped, false, "the words ran past their foot for a campfire")
    Check(p.captionFoot <= 528, "level 13's print's words end past the foot: " .. p.captionFoot)
    Eq(p.counts.campfires, 1, "level 13's fire mark")
end

-- The week of the oasis: a light print with its slip under its caption,
-- and the full plate's fire stepped aside from the time together's ring.
-- Its two sittings are two pages (an L, an F) since the pages go by
-- sitting, so it is read here as a week played in one: no sittings known,
-- every entry one piece, drawn whole (spliced), LF.
do
    local j = ns.Journey.For(ns.ownGUID)
    local kept = j.sittings
    j.sittings = {}
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(false)
    local week
    for i, e in ipairs(page.recap.entries) do
        Open(i)
        if page.pattern == "LF" then week = i break end
    end
    Check(week ~= nil, "setup: no LF week")
    local print, full = page.plates[1], page.plates[2]
    Eq(print.slot.light, true, "the week's print is light")
    Eq(Last(print), "campfire", "the print's slip, under its caption")
    local slip = Slips()[1]
    Check(slip and slip.box[2] >= print.captionFoot, "the print's slip is not under its caption")
    Check(slip and slip.box[1] >= print.slot.cap.x - 1
        and slip.box[1] + slip.box[3] <= print.slot.cap.x + print.slot.cap.w + 1,
        "the print's slip is out of its caption's column")
    Eq(Last(full), "campfire", "the full plate's slip, after its person")
    local ring
    for m, at in pairs(full.where or {}) do
        if m.kind == "session" then ring = at end
    end
    local fire = full.campfireMarks[1]
    Check(ring and fire, "setup: the ring and the fire")
    local d = math.sqrt((ring.x - fire.x) ^ 2 + (ring.y - fire.y) ^ 2)
    Check(d >= ns.Campfire.MARK.h / 2, "the fire lies on the ring: " .. d)
    j.sittings = kept
    ns.Journey.Touch()
    ns.UI.RefreshJourneyPage(false)
end

-- Laid flat, the slips lie square.
ns.SetSetting("flatSheets", true)
Open(Entry(12))
for _, s in ipairs(Slips()) do Eq(s.turn, 0, "laid flat, a slip turns") end
ns.SetSetting("flatSheets", false)
