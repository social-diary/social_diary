-- Your Diary's profession caps (JRN-29) on the page: their words (the
-- prose, the plates' captions, the mark's tooltip), and their mark on a
-- plate, a flight of stairs, only on the open level's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local P = ns.ProfessionCaps
local OPEN, CLOSE = "\226\128\156", "\226\128\157"

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)

local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern) then return true end
    end
    return false
end

local FIRST_AID, MINING = 129, 186
local AID = { t = now - 3600, mapID = 1454, x = 0.55, y = 0.67, level = 11, skillLine = FIRST_AID,
    name = "First Aid", rank = 75 }
local ORE = { t = now - 1800, mapID = 1442, x = 0.73, y = 0.59, level = 12, skillLine = MINING, name = "Mining",
    rank = 150 }

--------------------------------------------------------------------------
Section("the words")

Eq(P.Words(AID), "First Aid at 75", "a cap in a few words")
Eq(P.Words({ rank = 75 }), "a profession at 75", "a cap with no name")
Eq(P.Words({ name = "Mining" }), "Mining at its cap", "a cap with no rank")

Eq(P.Sentence(AID), "First Aid reached 75, as far as an Apprentice goes.", "an Apprentice's cap")
Eq(P.Sentence(ORE), "Mining reached 150, as far as a Journeyman goes.", "a Journeyman's cap")
Eq(P.Sentence({ name = "Tailoring", rank = 225 }), "Tailoring reached 225, as far as an Expert goes.",
    "an Expert's cap")
Eq(P.Sentence({ name = "Herbalism", rank = 300 }), "Herbalism reached 300, as far as an Artisan goes.",
    "an Artisan's cap")
Eq(P.Sentence({ name = "Mining", rank = 375 }), "Mining reached 375.", "a cap with no trainer's title")
Eq(P.Sentence({ rank = 75 }), "A profession reached 75, as far as an Apprentice goes.", "a cap with no name")
Eq(P.Sentence({ name = "", rank = 150 }), "A profession reached 150, as far as a Journeyman goes.",
    "a cap with an empty name")

-- The level's prose: one sentence each; the same profession again
-- straight after only counts on.
local AID2 = { t = AID.t + 600, skillLine = FIRST_AID, name = "First Aid", rank = 150 }
Eq(P.Lines({ skillCaps = { AID } }), "First Aid reached 75, as far as an Apprentice goes.", "one cap")
Eq(P.Lines({ skillCaps = { AID, ORE } }), "First Aid reached 75, as far as an Apprentice goes. Mining "
    .. "reached 150, as far as a Journeyman goes.", "two professions")
Eq(P.Lines({ skillCaps = { AID, AID2 } }), "First Aid reached 75, as far as an Apprentice goes. Then 150, "
    .. "as far as a Journeyman goes.", "one profession twice")
Eq(P.Lines({ skillCaps = { { rank = 75 }, { rank = 150 } } }), "A profession reached 75, as far as an "
    .. "Apprentice goes. A profession reached 150, as far as a Journeyman goes.", "two caps with no names")
Check(P.Lines({ skillCaps = {} }) == nil and P.Lines({}) == nil, "no caps says something")

-- In the level's paragraphs: after the chains finished, before the close
-- calls.
do
    local e = { kind = "level", level = 11, seconds = 0, from = now - DAY, to = now, places = {}, stops = {},
        flights = {}, people = {}, fights = {}, finds = {}, closeCalls = { { name = "Plainstrider", pct = 6 } },
        hunts = {}, fortunes = {}, finales = { { title = "The Demon Seed", n = 7, t = now } }, skillCaps = { AID } }
    local lines = Text.Lines(e, now, {})
    local at = {}
    for i, line in ipairs(lines) do
        if line:find("The end of", 1, true) then at.finale = i end
        if line:find("First Aid reached 75", 1, true) then at.skill = i end
        if line:find("Got away from", 1, true) then at.close = i end
    end
    Check(at.skill, "the cap is not in the prose: " .. table.concat(lines, " / "))
    Check(at.finale and at.close and at.finale < at.skill and at.skill < at.close,
        "the cap is out of order: " .. table.concat(lines, " / "))
end

-- The tooltip: the words, how far the training goes, when.
local title, lines = P.Tip(AID, now)
Eq(title, "First Aid at 75", "the tooltip's heading")
Eq(lines[1], "As far as an Apprentice goes", "the tooltip's rank")
Check(#lines == 2 and lines[2]:find("at level 11$"), "the tooltip's when, last: " .. tostring(lines[2]))
title, lines = P.Tip({ rank = 375, t = now, level = 60 }, now)
Eq(title, "A profession at 375", "a nameless cap's heading")
Check(#lines == 1 and lines[1]:find("at level 60$"), "a cap with no title says only when")

--------------------------------------------------------------------------
Section("the captions")

local function Caption(moments)
    return Text.PlateCaption({ moments = moments })
end
local SKILL = { kind = "skill", cap = AID }
local LEVEL = { kind = "level", level = 11 }
local FINALE = { kind = "finale", finale = { title = "The Demon Seed", n = 7 } }

Eq(Caption({ SKILL }), "First Aid at 75.", "a cap alone leads")
Eq(Caption({ { kind = "skill", cap = { rank = 75 } } }), "A profession at 75.", "a nameless cap alone")
Eq(Caption({ LEVEL, SKILL }), "First Aid at 75.", "the level and a cap: the cap leads")
Eq(Caption({ FINALE, SKILL }), "The end of " .. OPEN .. "The Demon Seed" .. CLOSE .. ", and First Aid at 75.",
    "a finale leads, the cap after it")
Eq(Caption({ SKILL, { kind = "death" } }), "First Aid at 75, and a death.", "a cap leads before a death")
Eq(Caption({ LEVEL, SKILL, { kind = "death" } }), "First Aid at 75, and a death.",
    "the level, a cap and a death")
Eq(Caption({ LEVEL, SKILL, { kind = "skill", cap = ORE } }), "Two professions at their cap.",
    "two professions are counted")
Eq(Caption({ SKILL, { kind = "skill", cap = ORE } }), "Two professions at their cap.", "two professions lead")
Eq(Caption({ SKILL, { kind = "skill", cap = AID2 } }), "First Aid at 75, then 150.", "one profession twice")
Eq(Caption({ { kind = "skill", cap = { name = "Mining", rank = 75 } }, { kind = "skill", cap = { name = "Mining",
    rank = 150 } } }),
    "Mining at 75, then 150.", "one profession twice, by name alone")
-- A first found leads over a cap; the cap comes after it.
Eq(Caption({ { kind = "find", what = "bag", t = now, find = { t = now } }, SKILL }),
    "A first bag, and First Aid at 75.", "a first found leads, the cap after it")
-- What ranks below a cap never leads over it.
Eq(Caption({ { kind = "close", call = { name = "Plainstrider", pct = 6 } }, SKILL }),
    "First Aid at 75, and a close call with a Plainstrider.", "a close call after the cap")

--------------------------------------------------------------------------
Section("on the plate")

ns.UI.ShowJournal()
local page = ns.UI.JourneyPage()
local t0 = now - 2 * DAY
ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
local function Seg(seg)
    j.segments[#j.segments + 1] = seg
    return seg
end
Seg({ kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60, r = 50, seconds = 1800,
    act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 })
Seg({ kind = "road", from = t0 + 1800, to = t0 + 2400, mapID = 1412, levelFrom = 10, levelTo = 10,
    pts = { 0.40, 0.60, 0.45, 0.55, 0.50, 0.50, 0.55, 0.52, 0.60, 0.45 } })
Seg({ kind = "stop", from = t0 + 2400, to = t0 + 4200, mapID = 1412, x = 0.60, y = 0.45, r = 30, seconds = 1800,
    act = { resting = 1500 }, subZone = "Bloodhoof Village", levelFrom = 10, levelTo = 11 })
j.levels[11] = { at = t0 + 4000, mapID = 1412, x = 0.60, y = 0.45 }
Seg({ kind = "stop", from = t0 + 5000, to = t0 + 6000, mapID = 1412, x = 0.62, y = 0.44, r = 20, seconds = 1000,
    levelFrom = 11, levelTo = 11 })
j.skillCaps = { { t = t0 + 1000, mapID = 1412, x = 0.42, y = 0.58, level = 10, skillLine = FIRST_AID,
    name = "First Aid", rank = 75 } }
ns.Journey.Touch()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")

local function Open(level)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.entries:SetOffset(page.rubrics[i] - 1)
            for _, row in ipairs(page.entries.rows) do
                if row:IsShown() and row.item and row.item.title and row.item.entry == i then row:Click() end
            end
            return e
        end
    end
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

local e = Open(10)
Eq(#e.skillCaps, 1, "the level's cap")
local plate = page.plates[1]
Eq(plate.counts.skills, 1, "the cap's stairs are not drawn")
local tips = Tips(plate)
Check(Any(tips, "^First Aid at 75|As far as an Apprentice goes|[^|]*at level 10$"),
    "the stairs' tooltip: " .. table.concat(tips, "; "))
-- It claims its room, apart from the other marks.
local spots = 0
for _, spot in ipairs(plate.spots) do
    if spot[3] > 6 then spots = spots + 1 end
end
Check(spots >= 1, "the stairs claimed no room")
-- The prose says it.
local said = {}
for _, item in ipairs(page.items) do
    if item.text then said[#said + 1] = item.text end
end
Check(Any(said, "First Aid reached 75, as far as an Apprentice goes%."), "the prose has no cap")
local caption = page.captionPool[1]:GetText()
Check(caption:find("First Aid at 75", 1, true), "the caption: " .. tostring(caption))

-- Another level's are not on this one's plate (only the open level).
Open(11)
Eq(page.plates[1].counts.skills or 0, 0, "level 10's cap is on level 11's plate")

--------------------------------------------------------------------------
Section("/sd testdata: the made-up caps show at levels 11 and 12")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
page = ns.UI.JourneyPage()
do
    local flights, marked, words, prose = {}, {}, {}, {}
    for _, at in ipairs(T.DiaryPages(page)) do
        local entry = at.e
        T.OpenDiaryPage(page, at.i, at.k)
        local level = entry.level or "week"
        for _, p in ipairs(page.plates) do
            if p:IsShown() then
                if (p.counts.skills or 0) > 0 then
                    flights[#flights + 1] = level .. ":" .. p.mapID .. "x" .. p.counts.skills
                end
                for _, tip in ipairs(Tips(p)) do marked[#marked + 1] = level .. ": " .. tip end
            end
        end
        for k = 1, page.captionPool.used do
            local w = page.captionPool[k]
            if w:IsShown() then words[#words + 1] = level .. ": " .. (w:GetText() or "") end
        end
        for _, line in ipairs(Text.Lines(entry, page.now or ns.Now(), {})) do
            prose[#prose + 1] = level .. ": " .. line
        end
    end
    -- One flight of stairs each, on the plate of the zone it was reached in.
    Eq(table.concat(flights, ","), "11:1454x1,12:1442x1", "the caps' stairs")
    Check(Any(marked, "^11: First Aid at 75|As far as an Apprentice goes|[^|]*at level 11$"),
        "level 11's stairs' tooltip: " .. table.concat(marked, "; "))
    Check(Any(marked, "^12: Mining at 150|As far as a Journeyman goes|[^|]*at level 12$"),
        "level 12's stairs' tooltip: " .. table.concat(marked, "; "))
    Check(Any(words, "^11: .*First Aid at 75"), "the cap is not in level 11's words: " .. table.concat(words, "; "))
    Check(Any(words, "^12: .*Mining at 150"), "the cap is not in level 12's words: " .. table.concat(words, "; "))
    Check(Any(prose, "^11: First Aid reached 75, as far as an Apprentice goes%."), "the cap is not in level 11's prose")
    Check(Any(prose, "^12: Mining reached 150, as far as a Journeyman goes%."), "the cap is not in level 12's prose")
end
ns.TestData.Remove()
