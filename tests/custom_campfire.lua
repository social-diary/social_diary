-- Custom cards: the campfire kind (.claude/features/custom-cards.md). A fire
-- changed, hidden and written by the player: the one line of its form, what the
-- tooltip and the caption read of it, and a slip of its own that is not filler,
-- so it stays where the plate's one detected slip is the first to go.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Campfire, Recap, J = ns.Custom, ns.Campfire, ns.JourneyRecap, ns.Journey
local Slip = Campfire.Slip

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local MAP = 1412
local t0 = now - 7200
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = {}
j.open = nil
j.segments[1] = { kind = "stop", from = t0, to = t0 + 4000, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 4000,
    levelFrom = 10, levelTo = 10 }
j.segments[2] = { kind = "stop", from = t0 + 4200, to = t0 + 5000, mapID = MAP, x = 0.70, y = 0.30, r = 30,
    seconds = 800, levelFrom = 11, levelTo = 11 }
j.levels[11] = { at = t0 + 4100, mapID = MAP, x = 0.70, y = 0.30 }
J.Touch()

local function Fire(t, sub, x, y)
    return { t = t, mapID = MAP, x = x or 0.42, y = y or 0.58, subZone = sub, zone = "Durotar" }
end
local function Fires(a, b)
    local e = Recap.Gather(j, a or t0, b or now + 1, Recap.Context(ns.ownGUID, now))
    return e.campfires, e
end
local WHERE = { mapID = MAP, x = 0.44, y = 0.56, from = t0, to = t0 + 4000 }

--------------------------------------------------------------------------
Section("the kind in the picker")

do
    local spec = Custom.Spec("campfire")
    Eq(spec.label, "Campfire", "its title")
    Eq(spec.heading, "A campfire", "its form's heading")
    Eq(spec.group, "other", "its type")
    Eq(#spec.fields, 1, "one line on its form")
    Eq(spec.fields[1].key, "subZone", "saved under the name a detected record uses")
    local kinds = {}
    for _, k in ipairs(ns.UI.YourDiary.CardSheet.Kinds()) do kinds[k.kind] = k end
    Check(kinds.campfire ~= nil, "not in the picker")
    Eq(kinds.campfire.words, "Other", "under its type's words")
end

--------------------------------------------------------------------------
Section("an old-shaped route reads as it did")

j.campfires = { Fire(t0 + 900, "Razor Hill") }
local rec = j.campfires[1]
do
    local fires, e = Fires()
    Eq(fires[1], rec, "a record with nothing custom is read as it is, no copy")
    Eq(#e.hidden, 0, "nothing hidden")
    Eq(j.custom, nil, "reading writes no list")
end

--------------------------------------------------------------------------
Section("a detected fire edited, cleared, hidden and reset")

do
    Check(Custom.Edit("campfire", rec, { subZone = "Skull Rock", zone = "Elsewhere" }), "the edit")
    local read = Fires()[1]
    Eq(read.subZone, "Skull Rock", "the place is read")
    Eq(read.customOf, rec, "the copy knows its record")
    Eq(rec.subZone, "Razor Hill", "the detected place stays")
    Eq(read.zone, "Durotar", "a field the form does not ask is left alone")
    Eq(rec.custom.zone, nil, "and never written")
    local title, lines = Campfire.Tip(read, now)
    Eq(title, "Sat by a campfire", "the tooltip's title")
    Eq(lines[1], "In Skull Rock", "the tooltip says the place as edited")

    Custom.Edit("campfire", read, { subZone = "" })
    read = Fires()[1]
    Eq(read.subZone, nil, "an empty line clears the place")
    Check(read.customOf == rec, "and that is a change")
    Check(not select(2, Campfire.Tip(read, now))[1]:find("^In "), "no place in the tooltip")

    Custom.Edit("campfire", read, { subZone = "|cffff0000Skull\nRock|r" })
    Eq(Fires()[1].subZone, "cffff0000Skull Rockr", "no escape sequence, one line")
    Custom.Edit("campfire", rec, { subZone = ("x"):rep(80) })
    Eq(#Fires()[1].subZone, 40, "held to its line's length")

    Custom.Edit("campfire", rec, { subZone = "Razor Hill" })
    Eq(rec.custom, nil, "back at what was detected is no change")

    Custom.Edit("campfire", rec, { subZone = "Skull Rock" })
    Custom.Hide(Fires()[1])
    local fires, e = Fires()
    Eq(#fires, 0, "off the page")
    Eq(#e.hidden, 1, "listed to bring back")
    Eq(e.hidden[1].kind, "campfire", "its kind")
    Check(Custom.Spec("campfire").describe(Custom.Values(e.hidden[1].rec)):find("^Skull Rock, "),
        "the menu's line names it")
    Custom.Show(e.hidden[1].rec)
    Eq(Fires()[1].subZone, "Skull Rock", "back with its changes")
    Custom.Reset(Fires()[1])
    Eq(rec.custom, nil, "Reset takes the changes off")
    Eq(Fires()[1], rec, "exactly the detected card")
end

--------------------------------------------------------------------------
Section("a fire inserted")

do
    local made = Custom.Insert("campfire", { subZone = "Sen'jin Village" }, WHERE)
    Eq(j.custom[1], made, "on its own list")
    Eq(#j.campfires, 1, "not on the feature's")
    Eq(made.kind, "campfire", "its kind")
    Eq(made.level, 10, "the level then")
    local fires = Fires()
    Eq(#fires, 2, "gathered with the detected")
    Eq(fires[2].inserted, true, "and known as inserted")
    Eq(fires[2].customOf, made, "knows its record")
    Eq(#Fires(t0, made.t), 1, "not on a page outside its time")
    local bare = Custom.Insert("campfire", {}, WHERE)
    Check(bare ~= nil, "a fire needs no place")
    Eq(bare.subZone, nil, "and has none")
    Check(Custom.Spec("campfire").describe(bare):find("^A campfire, "), "the menu's line for it")
    Custom.Edit("campfire", Fires()[2], { subZone = "Tiragarde Keep" })
    Check(j.custom[1].subZone == "Tiragarde Keep" or j.custom[2].subZone == "Tiragarde Keep", "taken outright")
    Custom.Remove(bare)
    Custom.Remove(made)
    Eq(#j.custom, 0, "removed")

    ns.SetSetting("keepRoute", false)
    Check(Custom.Edit("campfire", rec, { subZone = "Skull Rock" }), "an edit with the route off")
    local off = Custom.Insert("campfire", {}, WHERE)
    Check(off ~= nil, "an insert with the route off")
    Custom.Remove(off)
    Custom.Reset(rec)
    ns.SetSetting("keepRoute", true)
end

--------------------------------------------------------------------------
Section("the cap passes over a fire the player changed")

do
    local list = {}
    for i = 1, 3 do list[i] = Fire(t0 + i) end
    j.campfires = list
    list[1].custom = { subZone = "Skull Rock" }
    local cap = J.T.campfires
    J.T.campfires = 3
    J.Append(j, "campfires", Fire(t0 + 4), { mapID = MAP, x = 0.5, y = 0.5 })
    J.Append(j, "campfires", Fire(t0 + 5), { mapID = MAP, x = 0.5, y = 0.5 })
    Eq(list[1].t, t0 + 1, "the changed one stays")
    Eq(list[2].t, t0 + 3, "the oldest unchanged goes")
    J.T.campfires = cap
    j.campfires = { rec }
end

--------------------------------------------------------------------------
Section("it outranks everything, and the detected slip does not tell it")

do
    local function M(fire) return { kind = "campfire", campfire = fire, mapID = MAP, x = 0.5, y = 0.5, t = t0 } end
    Eq(Recap.Rank(M({ t = t0 })), 5.5, "a detected fire's own rank")
    Check(Recap.Rank(M({ t = t0, customOf = {} })) < Recap.RANK.session, "a custom one's, above the people")

    local plain, edited, inserted = { t = 1 }, { t = 2, customOf = {} }, { t = 3, customOf = {}, inserted = true }
    local a, b = { 10, 20 }, { 30, 40 }
    local marks = {
        { at = a, x = 1, y = 2, list = { { t = 1, campfire = plain }, { t = 2, campfire = edited } } },
        { at = b, x = 3, y = 4, list = { { t = 3, campfire = inserted } } },
    }
    local chosen = Slip.Choose(marks)
    Eq(#chosen.list, 1, "the plate's one slip is the detected fires'")
    Eq(chosen.list[1].campfire, plain, "that fire")
    Eq(#chosen.marks, 1, "its leader goes to no mark holding only the player's")
    Eq(chosen.marks[1], a, "the detected fire's")
    local customs = Slip.Customs(marks)
    Eq(#customs, 2, "a slip each")
    Eq(customs[1].fire, inserted, "the newest first")
    Eq(customs[1].mark, b, "its leader goes to its own mark")
    Eq(#customs[1].list, 1, "its tooltip tells its own sitting")
    Eq(Slip.Choose({ marks[2] }), nil, "with only the player's, no detected slip")
    Eq(#Slip.Customs({ { at = a, list = { { t = 1, campfire = plain } } } }), 0, "none custom, none")
end

--------------------------------------------------------------------------
Section("on the page, a custom slip is a slip like any other")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local YourDiary = ns.UI.YourDiary
local CardSheet = YourDiary.CardSheet

local function OpenLevel(level)
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, entry in ipairs(page.recap.entries) do
        if entry.level == level then
            T.OpenDiaryPage(page, i)
            return i
        end
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
local function Words()
    local said = {}
    for k = 1, page.captionPool.used do said[#said + 1] = page.captionPool[k]:GetText() or "" end
    return (table.concat(said, " | "):gsub("\194\160", " "))
end
local function KindsOf(p)
    local kinds = {}
    for _, it in ipairs(p.margin or {}) do kinds[#kinds + 1] = it.kind end
    return kinds
end
local function Press(button) button.scripts.OnClick(button) end

do
    Custom.Reset(rec)
    Custom.Insert("campfire", { subZone = "Sen'jin Village" }, WHERE)
    OpenLevel(10)
    Eq(page.customCampfiresWritten, 1, "the player's fire has its slip")
    Eq(page.campfiresWritten, 1, "and the detected one its own")
    local slips = Slips()
    Eq(#slips, 2, "both shown")
    for _, s in ipairs(slips) do
        Eq(s:Words(), "sat by a campfire", "exactly its words")
        Check(s.onRight ~= nil, "a right click opens its form")
    end
    local p = page.plates[1]
    local order = KindsOf(p)
    Check(table.concat(order, " "):find("campfire"), "in the margin")
    Check(not Words():find("campfire"), "with its slip shown the words do not say it: " .. Words())

    -- The right click: its own record, its own line.
    local custom
    for _, s in ipairs(slips) do
        if s.chosen.fire then custom = s end
    end
    custom.link.scripts.OnMouseUp(custom.link, "RightButton")
    local view = CardSheet.View()
    Check(view:IsShown(), "the form did not open")
    Eq(view.title:GetText(), "A campfire", "its heading")
    Eq(#view.rows, 1, "one row")
    Eq(view.rows[1]:Get(), "Sen'jin Village", "its place")
    Check(view.remove:IsShown(), "an inserted card can be deleted")
    Check(not view.hide:IsShown(), "and not left out")
    Press(view.cancel)

    -- The detected slip opens the fire it stands for.
    local detected
    for _, s in ipairs(slips) do
        if not s.chosen.fire then detected = s end
    end
    detected.link.scripts.OnMouseUp(detected.link, "RightButton")
    Eq(view.rec, rec, "the detected fire's raw record")
    Check(view.hide:IsShown(), "a detected card can be left out")
    Press(view.hide)
    Check(rec.custom and rec.custom.hidden, "left out")
    Eq(page.campfiresWritten, 0, "its slip goes")
    Eq(page.customCampfiresWritten, 1, "the player's stays")
    Custom.Show(rec)
    Custom.Reset(rec)
    Custom.Remove(j.custom[1])
    Check(CardSheet.View() ~= nil, "the form stays built")
end

Section("the form opens and saves a fire from the picker")

do
    OpenLevel(10)
    local p = page.plates[1]
    Check(p ~= nil, "setup: a plate")
    local before = #(j.custom or {})
    CardSheet.Edit("campfire", rec)
    local view = CardSheet.View()
    view.rows[1]:Set("Skull Rock")
    Press(view.save)
    Eq(rec.custom and rec.custom.subZone, "Skull Rock", "an edit saved")
    Eq(#(j.custom or {}), before, "and nothing inserted")
    CardSheet.Edit("campfire", Fires()[1])
    Press(view.reset)
    Eq(rec.custom, nil, "reset from the form")
end

--------------------------------------------------------------------------
Section("custom slips stay where the detected one goes, and the words say what has no slip")

do
    local Margin = ns.UI.JourneyMargin
    local spec, auto = Margin.KINDS.campfireCustom, Margin.KINDS.campfire
    Eq(spec.order, 9, "the table's order")
    Eq(spec.filler, nil, "not filler")
    Eq(auto.filler, true, "the detected slip still is")
    Check(spec.order < auto.order, "before the detected")
    Check(spec.order < Margin.PEOPLE.close, "and before the people")

    local plate = { campfire = { list = {} }, campfireMarks = { { at = { 1, 1 }, x = 1, y = 1,
        list = { { t = 1, campfire = { t = 1, customOf = {} } } } } } }
    local said = {}
    spec.say(said, {}, plate)
    auto.say(said, {}, plate)
    Eq(said.campfire, true, "left off, the words say it")
    said = {}
    spec.say(said, {}, { campfireMarks = plate.campfireMarks })
    Eq(said.campfire, true, "with no detected fire beside it, its own say tells them")
    said = {}
    spec.say(said, { {} }, plate)
    auto.say(said, {}, plate)
    Eq(said.campfire, nil, "a slip of the player's shown says it for the detected left off")
    said = {}
    spec.say(said, {}, { campfireMarks = {} })
    auto.say(said, {}, { campfire = { list = {} }, campfireMarks = {} })
    Eq(said.campfire, true, "no slip of the player's, the detected left off: as it always was")
    said = {}
    spec.say(said, {}, { campfireMarks = {} })
    Eq(said.campfire, nil, "no fire at all: nothing")
end

--------------------------------------------------------------------------
Section("/sd testdata: the player's slip on a full margin, and on a print with no room")

ns.TestData.Write()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")

-- Captions wrap roughly as the client's do, as tests/campfire_ui.lua has them.
do
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
end

local function OpenWhole(level)
    ns.UI.RefreshJourneyPage(true)
    for i, e in ipairs(page.recap.entries) do
        if e.level == level then
            page.open, page.mode = i, "plates"
            ns.UI.RedrawJourneyPage()
            return e
        end
    end
end

-- A fire of the player's on the spot of a plate's own, on that page.
local function InsertOn(p, e, sub)
    local mark = p.campfireMarks[1]
    local m = mark.list[1]
    return Custom.Insert("campfire", { subZone = sub },
        { mapID = m.mapID, x = m.x, y = m.y, from = e.from, to = e.to })
end

-- Level 15's margin is full: the detected slip is left off and the words say
-- it (tests/campfire_ui.lua). Written by the player, one stays on that page, and
-- the words have no need to say it.
do
    local e = OpenWhole(15)
    local p = page.plates[1]
    Eq(page.campfiresWritten, 0, "setup: level 15's detected slip is left off")
    Check(Words():find("and a campfire%.$"), "setup: level 15's words say it: " .. Words())
    local made = InsertOn(p, e, "Skull Rock")
    OpenWhole(15)
    p = page.plates[1]
    Eq(page.customCampfiresWritten, 1, "the player's stays on a full margin")
    Eq(page.campfiresWritten, 0, "the detected is still the one left off")
    Eq(Slips()[1]:Words(), "sat by a campfire", "its words")
    Check(not Words():find("campfire"), "its slip on the page, the words leave it: " .. Words())
    Custom.Remove(made)
end

-- Level 11's print has no room under its caption: the player's slip is left off
-- too, the words say it, and its mark stays.
do
    local e = OpenWhole(11)
    Eq(page.pattern, "FL", "setup: level 11's page")
    local p = page.plates[2]
    local made = InsertOn(p, e, "Skull Rock")
    OpenWhole(11)
    local found
    for _, plate in ipairs(page.plates) do
        for _, mark in ipairs(plate.campfireMarks or {}) do
            for _, m in ipairs(mark.list) do found = found or m.campfire.customOf == made and plate end
        end
    end
    Check(found, "its mark is on a plate")
    Eq(page.customCampfiresWritten, 0, "no room for its slip")
    Check(Words():find("and campfires%.$"), "the words say it, its place being another: " .. Words())
    Check(found.captionFoot <= 528, "past the page's foot: " .. found.captionFoot)
    Custom.Remove(made)
end

-- Every fire on every page written by the player: its slip or the words tell it,
-- and telling it never runs the words past their foot. Level 13's print, whose
-- words are long, is why (tests/campfire_ui.lua): its detected fire is left to
-- its mark, and a card the player wrote must not be.
do
    local tried = 0
    for _, at in ipairs(T.DiaryPages(page)) do
        T.OpenDiaryPage(page, at.i, at.k)
        local e = page.recap.entries[at.i]
        local where
        for _, p in ipairs(page.plates) do
            if p:IsShown() and p.campfireMarks and p.campfireMarks[1] then where = where or p end
        end
        if where then
            local made = InsertOn(where, e, "Skull Rock")
            ns.UI.RefreshJourneyPage(true)
            T.OpenDiaryPage(page, at.i)
            local told = page.customCampfiresWritten > 0 or Words():find("campfire") ~= nil
            local plate
            for _, p in ipairs(page.plates) do
                for _, mark in ipairs(p:IsShown() and p.campfireMarks or {}) do
                    for _, m in ipairs(mark.list) do
                        if m.campfire.customOf == made then plate = p end
                    end
                end
            end
            if plate then
                tried = tried + 1
                Check(told, "level " .. tostring(e.level or e.week) .. ": nothing tells the player's fire: " .. Words())
                Check((plate.captionFoot or 0) <= 528, "level " .. tostring(e.level or e.week) .. " runs past the foot: "
                    .. tostring(plate.captionFoot) .. " " .. Words())
            end
            Custom.Remove(made)
            ns.UI.RefreshJourneyPage(true)
        end
    end
    Check(tried >= 3, "fewer pages than expected: " .. tried)
end
