-- Custom cards: the witness kind (.claude/features/custom-cards.md). A witness
-- the player writes in: its fields, the card read with no row behind it, its mark
-- and caption, and that it leaves the real witnesses and the People rows alone.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Custom, Recap, J, W = ns.Custom, ns.JourneyRecap, ns.Journey, ns.Witnesses
local Text = ns.UI.JourneyText

mock.now = 1791000000
local now = mock.now
SELF.level = 11
mock.SetUnit("player", SELF)
ns.TouchOwnCharacter()

local t0 = now - 7200
local MAP = 1412
J.Begin(ns.ownGUID, t0, 10, MAP)
local j = J.Mine()
j.segments = {}
j.open = nil
j.segments[1] = { kind = "stop", from = t0, to = t0 + 4000, mapID = MAP, x = 0.40, y = 0.60, r = 30, seconds = 4000,
    levelFrom = 10, levelTo = 10 }
j.levels[11] = { at = t0 + 4000, mapID = MAP, x = 0.40, y = 0.60 }
J.Touch()

local FRIEND = "Player-1-0AAAAAAA"
ns.db.characters[FRIEND] = { guid = FRIEND, names = { { first = "Brannoc", surname = "" } } }
ns.db.diary[FRIEND] = { tags = {}, addedAt = now }

-- Every row in the buffer, however it is held: what "writes no People row" counts.
local function Rows()
    local n = 0
    local function Walk(t)
        for _, v in pairs(t) do
            if type(v) == "table" then
                if v.type and v.time then n = n + 1 else Walk(v) end
            end
        end
    end
    Walk(ns.db.interactions or {})
    return n
end

local function Where(x, y)
    return { mapID = MAP, x = x or 0.42, y = y or 0.58, from = t0, to = t0 + 4000 }
end

--------------------------------------------------------------------------
Section("what it registers")

do
    local moment = Recap.MOMENTS.witnessed
    Eq(moment.order, 25, "the moment's order")
    Eq(Recap.RANK.witnessed, 3, "ranks with the deaths")
    Eq(moment.list, nil, "keeps no list of its own")
    Eq(Recap.LIGHT.witnessed, nil, "a full plate: it has a card")
    Eq(moment.custom.label, "Witness", "the picker's title")
    Eq(moment.custom.group, "social", "its type")
    Eq(ns.UI.JourneyPlate.MARKS.witnessed.order, 34, "the mark's order")
    Eq(ns.UI.JourneyMargin.KINDS.witnessCustom.order, 3, "the custom margin's order")
    Check(Custom.Spec("witness") == nil, "a detected witness is not a kind that can be edited")
    Eq(ns.UI.JourneyMargin.KINDS.witness.custom, nil, "and its card has no right click")
end

--------------------------------------------------------------------------
Section("adapted to what the card reads, with no row")

do
    local function Deed(rec) return W.Deed(W.Written(rec)) end
    Eq(Deed({ deed = "saw", t = 1 }), "saw you die", "saw")
    Eq(Deed({ deed = "tried", t = 1 }), "tried to save you", "tried")
    Eq(Deed({ deed = "saved", t = 1 }), "saved you", "saved")
    Eq(Deed({ t = 1 }), "saw you die", "no box ticked says the plainest")
    Eq(W.Written({ deed = "saw", t = 1 }).row, nil, "no row behind it")

    Eq(W.Foe(W.Written({ deed = "saw", creature = "Young Wolf" })), "to a Young Wolf", "a death's creature")
    Eq(W.Foe(W.Written({ deed = "saved", creature = "Old Tom", rank = "rare" })), "from Old Tom", "a rare goes bare")
    Eq(W.Foe(W.Written({ deed = "saved" })), nil, "no creature, no line")

    Eq(W.Card.Evidence(W.Written({ deed = "saved", pct = 6 })), "chart", "a rescue's chart")
    Eq(W.Card.Evidence(W.Written({ deed = "saved" })), nil, "with no health, no chart")
    Eq(W.Card.Evidence(W.Written({ deed = "saw", pct = 6 })), nil, "health left over on a watcher draws no chart")
    Eq(W.Card.Evidence(W.Written({ deed = "tried", pct = 6 })), nil, "nor on one who tried")
    Check(W.Card.Blood(W.Written({ deed = "saw" })) == W.Card.BLOOD.amount.saw, "a watcher's card has its stain")
    Eq(W.Card.Blood(W.Written({ deed = "saved" })), nil, "a helper's none")

    Eq(W.Name(W.Written({ name = "Old Friend" })), "Old Friend", "a typed name")
    Eq(W.Name(W.Written({})), "Someone", "nobody named")
    Eq(W.Name({ guid = FRIEND }), "Brannoc", "a detected witness by their record, as ever")

    local name, lines = W.Tip(W.Written({ deed = "saw", name = "Old Friend", creature = "Young Wolf", t = t0, level = 10 }), now)
    Eq(name, "Old Friend", "the tooltip's title")
    Eq(lines[1], "Saw you die to a Young Wolf", "says what happened")
    local all = table.concat(lines, "|")
    Check(not all:find("Watched for"), "no seconds nobody timed")
    Check(not all:find("Not in a fight"), "nothing capture would have had to see")
    Check(all:find("at level 10"), "when")
    local _, saved = W.Tip(W.Written({ deed = "saved", pct = 6, t = t0 }), now)
    Check(table.concat(saved, "|"):find("6%%"), "a rescue's health")
    local _, bare = W.Tip(W.Written({ deed = "saved", t = t0 }), now)
    Check(not table.concat(bare, "|"):find("came out"), "no health, no line about it")
end

--------------------------------------------------------------------------
Section("inserted, read, edited, removed")

local function Read()
    return Recap.Gather(j, t0, t0 + 4000, Recap.Context(ns.ownGUID, now)).witnessed
end

do
    Eq(#Read(), 0, "an old-shaped route has none")
    local rowsBefore = Rows()
    local rec = Custom.Insert("witnessed", { name = "Old Friend", creature = "Young Wolf", pct = 400, junk = 1 }, Where())
    Eq(j.custom[1], rec, "on the inserted list")
    Eq(rec.deed, "saw", "starts as the kind's default")
    Eq(rec.pct, 100, "health within its range")
    Eq(rec.junk, nil, "only the kind's fields")
    Eq(rec.guid, nil, "a typed name links to nobody")
    Eq(Read()[1].customOf, rec, "gathered, knowing its record")

    Custom.Edit("witnessed", Read()[1], { deed = "" })
    Eq(rec.deed, nil, "a box unticked clears it")
    Eq(W.Written(Read()[1]).type, W.WATCHED, "and it still reads")

    Custom.Edit("witnessed", rec, { name = "Brannoc", guid = FRIEND, deed = "saved", pct = 6 })
    Eq(rec.guid, FRIEND, "a picked name links")
    Custom.Edit("witnessed", rec, { name = "Brannoc the Second" })
    Eq(rec.guid, nil, "typing over it lets the entry go")
    Custom.Edit("witnessed", rec, { name = "Brannoc", guid = FRIEND })
    Eq(Rows(), rowsBefore, "no People row written")
    Eq(Custom.Spec("witnessed").describe(rec), "Brannoc saved you", "a menu's line")

    ns.ForgetEverywhere(FRIEND)
    Eq(rec.guid, nil, "forgotten: the link goes")
    Eq(rec.name, "Brannoc", "the name as written stays")
    Check(Custom.Remove(rec), "removed")
    Eq(#Read(), 0, "gone")
    ns.db.characters[FRIEND] = { guid = FRIEND, names = { { first = "Brannoc", surname = "" } } }
    ns.db.diary[FRIEND] = { tags = {}, addedAt = now }
end

--------------------------------------------------------------------------
Section("on the plate: its card, its mark, its links")

ns.UI.ShowJournal()
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local CardSheet = ns.UI.YourDiary.CardSheet

local function Open()
    J.Touch()
    ns.UI.RefreshJourneyPage(true)
    for i, entry in ipairs(page.recap.entries) do
        if entry.level == 10 then T.OpenDiaryPage(page, i) end
    end
end

local function Cards()
    local list = {}
    for i = 1, page.witnessPool.used do
        local card = page.witnessPool[i]
        if card:IsShown() then list[#list + 1] = card end
    end
    return list
end

local function CardOf(name)
    for _, card in ipairs(Cards()) do
        if card.witness and W.Name(card.witness) == name then return card end
    end
end

do
    local typed = Custom.Insert("witnessed", { name = "Old Friend", deed = "saved", creature = "Old Tom", rank = "rare",
        pct = 6 }, Where())
    local linked = Custom.Insert("witnessed", { name = "Brannoc", guid = FRIEND, deed = "saw" }, Where(0.44, 0.56))
    Open()
    Eq(page.customWitnessesWritten, 2, "a card each")
    local plate = page.plates[1]
    Eq(plate.counts.witnesses, 2, "a mark each")
    Eq(plate.counts.deaths or 0, 0, "the crosses are not deaths")
    Eq(plate.counts.closeCalls or 0, 0, "the outline is no close call")
    Eq(plate.witness, nil, "no real witness made of them")

    local rescue = CardOf("Old Friend")
    Eq(rescue:Deed(), "saved you", "the deed on the card")
    Eq(rescue:Foe(), "from an Old Tom", "the creature, with no way now to say it is one of a kind")
    Eq(rescue.plan.row and rescue.plan.row.kind, "chart", "the chart")
    Eq(rescue.guid, nil, "a typed name has no link")
    Eq(CardOf("Brannoc").guid, FRIEND, "a picked one links to their page")
    Check(CardOf("Brannoc").blood ~= nil, "a watcher's blood")
    local list = rescue.tip()
    local tip = {}
    for _, line in ipairs(list) do tip[#tip + 1] = line[1] or line.text or "" end
    Check(not table.concat(tip, "|"):find("Click"), "nothing to click on a typed name")

    -- The form, from the card: its record, and the guid a saved form keeps.
    Check(not CardSheet.View() or not CardSheet.View():IsShown(), "no form yet")
    rescue.link.scripts.OnMouseUp(rescue.link, "RightButton")
    local view = CardSheet.View()
    Check(view:IsShown(), "a right click on the card opens the form")
    Eq(view.title:GetText(), "A witness", "its heading")
    Eq(view.rec.customOf, typed, "its record")
    Check(view.remove:IsShown(), "it can be removed")
    Check(not view.hide:IsShown(), "not hidden: that is a detected card's")
    view.cancel.scripts.OnClick(view.cancel)

    -- The mark: right click opens it, a rescue's outline and a watcher's cross.
    local marks = plate.witnessedMarks
    Eq(#marks, 2, "kept")
    local args = {}
    for _, mark in ipairs(marks) do args[mark.list[1].witnessed.name] = mark.arg end
    Eq(args["Old Friend"], "saved", "the rescue's outline")
    Eq(args["Brannoc"], nil, "the watcher's cross")
    local button
    for i = 1, plate.hover.used do
        local b = plate.hover[i]
        if b.spot and b.spot.kind == "witnessed" then button = b end
    end
    Check(button ~= nil, "its mark can be hovered")
    button.scripts.OnMouseUp(button, "RightButton")
    Check(CardSheet.View():IsShown(), "a right click on the mark opens the form")
    CardSheet.View().cancel.scripts.OnClick(CardSheet.View().cancel)

    -- Asked with no arg, as the picker asks, through the picker's kit.
    local frame = CreateFrame("Frame")
    local kit = ns.UI.JourneyPlate.MarkKit(frame, function() end, function() return false end, { 1, 1, 1 })
    kit:Begin()
    ns.UI.JourneyPlate.MARKS.witnessed.draw(kit, 1, 1)
    Check(kit.inner.used > 0, "draws without an arg")
    Eq(kit.ink.used, 0, "the solid cross, what a new card starts as")
    ns.UI.JourneyPlate.MARKS.witnessed.draw(kit, 1, 1, "saved")
    Check(kit.ink.used > 0, "and the outlined one for a rescue")
    kit:Finish()

    Custom.Remove(typed)
    Custom.Remove(linked)
end

--------------------------------------------------------------------------
Section("left off, the caption says so")

do
    local w = W.Written({ deed = "tried", name = "Old Friend", t = t0 })
    local plate = { moments = {}, t = t0, mapID = MAP }
    local words = Text.PlateCaption(plate, false, { witnessed = { w } })
    Check(words:find("Old Friend tried to save you.", 1, true), "told in a sentence: " .. words)
    words = Text.PlateCaption(plate, false, {})
    Check(not words:find("Old Friend"), "with its card shown, nothing")

    local spec = ns.UI.JourneyMargin.KINDS.witnessCustom
    local plateWith = { customWitnesses = { w } }
    local said = {}
    spec.say(said, {}, plateWith)
    Eq(said.witnessed and said.witnessed[1], w, "no room: told")
    said = {}
    spec.say(said, { { witness = w } }, plateWith)
    Eq(said.witnessed, nil, "shown: not")
end

--------------------------------------------------------------------------
Section("beside a real witness: nobody's place taken")

do
    local STRANGER = "Player-1-0CCCCCCC"
    ns.db.characters[STRANGER] = { guid = STRANGER, names = { { first = "Numa", surname = "" } } }
    local call = { t = t0 + 900, mapID = MAP, x = 0.42, y = 0.58, level = 10, pct = 6, npcID = 2955,
        name = "Plainstrider", foeLevel = 7 }
    j.closeCalls = { call }
    ns.Interactions.Add(STRANGER, W.SAVED, { time = t0 + 900, context = { pct = 6, name = "Plainstrider", npcID = 2955 } })
    local before, index = Rows(), #J.WitnessIndex()
    local deathsBefore = #(j.deaths or {})
    local mine = Custom.Insert("witnessed", { name = "Old Friend", deed = "saved", pct = 3 }, Where(0.43, 0.57))
    Eq(mine.t, Custom.TimeNear(j, MAP, 0.43, 0.57, t0, t0 + 4000), "its time is the route's")
    -- Laid on the real witness's own second: nothing in its time may tell.
    mine.t = t0 + 900
    Open()
    local plate = page.plates[1]
    Check(plate.witness ~= nil and plate.witness.guid == STRANGER, "the real witness is still chosen")
    Check(plate.witness.written == nil, "and not the written one")
    Eq(plate.foe, nil, "the real one takes the close call's card, as ever")
    Eq(#plate.customWitnesses, 1, "the written one keeps its own")
    Eq(page.witnessesWritten, 1, "the real card")
    Eq(page.customWitnessesWritten, 1, "the written card")
    Check(CardOf("Numa") ~= nil and CardOf("Old Friend") ~= nil, "both in the margin")

    -- A pool's card reused: the detected one is told it has no right click.
    Check(CardOf("Old Friend").onRight ~= nil, "the written card opens the form")
    Eq(CardOf("Numa").onRight, nil, "a right click on a detected witness does nothing new")

    Eq(Rows(), before, "no row written or taken")
    Eq(#J.WitnessIndex(), index, "no witness added to the index the real ones are found by")
    Eq(#(j.deaths or {}), deathsBefore, "no death on the route")
    Eq(#j.closeCalls, 1, "no close call on the route")
    Custom.Remove(mine)
    j.closeCalls = {}
end

--------------------------------------------------------------------------
Section("more than the margin has room for")

do
    local mine = {}
    for i = 1, 12 do
        mine[i] = Custom.Insert("witnessed", { name = "Wren" .. i, deed = "tried" }, Where(0.30 + i * 0.012, 0.58))
        mine[i].t = t0 + i * 10
    end
    Open()
    local plate = page.plates[1]
    Eq(plate.counts.witnesses, 12, "every one keeps its mark")
    Check(page.customWitnessesWritten < 12, "some left off")
    Check(page.customWitnessesWritten > 0, "some kept")
    local words = {}
    for k = 1, page.captionPool.used do
        local w = page.captionPool[k]
        if w:IsShown() then words[#words + 1] = w:GetText() or "" end
    end
    words = table.concat(words, " ")
    -- The oldest are the ones left off, as the newest are laid first.
    Check(words:find("Wren1 tried to save you.", 1, true), "the oldest told in the words: " .. words)
    Check(not words:find("Wren12 tried", 1, true), "the newest on its card, not in them")
    for _, rec in ipairs(mine) do Custom.Remove(rec) end
end

--------------------------------------------------------------------------
Section("from the menu to the page")

do
    Open()
    local plate = page.plates[1]
    local S, s = plate.sheet, plate.slot
    S.GetCenter = function() return 500, 400 end
    local px, py = plate:OnPage(0.42, 0.58)
    mock.pointer = { 500 + px - (s.x + s.w / 2), 400 + s.y + s.h / 2 - py }
    mock.contextMenu = nil
    plate.clip.scripts.OnMouseUp(plate.clip, "RightButton")
    Check(mock.contextMenu ~= nil, "the map's menu")
    Check(mock.MenuClick("Add custom event..."), "offered")
    local picked
    for _, row in ipairs(CardSheet.View().list.rows) do
        for _, cell in ipairs(row.item and row.cells or {}) do
            if cell.kind == "witnessed" then picked = cell end
        end
    end
    Check(picked ~= nil, "the picker offers it")
    picked.strip.link.scripts.OnClick(picked.strip.link)
    local view = CardSheet.View()
    Eq(view.title:GetText(), "A witness", "its form")
    local rows = {}
    for _, row in ipairs(view.rows) do rows[row.field.key] = row end
    Eq(rows.deed:Get(), "saw", "starts ticked at the default")
    rows.name:Set("Old Friend")
    rows.deed:Set("saved")
    rows.creature:Set("Young Wolf")
    rows.pct:Set("4")
    view.save.scripts.OnClick(view.save)
    local rec = j.custom[#j.custom]
    Eq(rec.kind, "witnessed", "saved as its kind")
    Eq(rec.name, "Old Friend", "who")
    Eq(rec.deed, "saved", "what")
    Eq(rec.creature, "Young Wolf", "against what")
    Eq(rec.pct, 4, "and the health")
    Eq(rec.guid, nil, "with no link")
    Open()
    Eq(page.customWitnessesWritten, 1, "on the page")
    Custom.Remove(rec)
end

--------------------------------------------------------------------------
Section("the article's box")

do
    local spec, W = ns.Custom.Spec("witnessed"), ns.Witnesses
    local bare
    for _, field in ipairs(spec.fields) do
        if field.key == "bare" then bare = field end
        Check(field.key ~= "rank", "no rank on the form")
    end
    Check(bare and #bare.values == 1, "one box")
    Eq(W.Foe(W.Written({ deed = "saved", creature = "Hogger" })), "from a Hogger", "unticked, an article")
    Eq(W.Foe(W.Written({ deed = "saved", creature = "Hogger", bare = "yes" })), "from Hogger", "ticked, none")
end
