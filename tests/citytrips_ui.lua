-- City trips on Your Diary's right page (Features/CityTrips/Sheet.lua,
-- Text.lua, the moment in Kind.lua): only a real round opens a sheet; the
-- usual and the heavy /sd testdata trips draw on their leaves; the city's
-- stay is told once, by the sheet; the stops run in their order and the
-- purse is last; a name the diary knows is underlined, opens their page
-- and has their tooltip; strangers are counted and never named; the heavy
-- trip folds and a counted part's tooltip lists what it merged, while a
-- trip that fits never folds; flat paper; the pad goes in among the names
-- and gives every colour back when the mouse takes over. Invented names.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local YD = ns.UI.YourDiary
local CityTrips, Recap = ns.CityTrips, ns.JourneyRecap
local NBSP = "\194\160"

SlashCmdList.SOCIALDIARY("testdata")
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()
local j = ns.Journey.Mine()
local TESTER = ns.TestData.GUID

-- The items' names as the client would have them cached (the mock knows
-- none until told).
local NAMES = { [2589] = "Linen Cloth", [2996] = "Bolt of Linen Cloth", [2592] = "Wool Cloth",
    [2997] = "Bolt of Woolen Cloth", [4238] = "Linen Bag", [4241] = "Woolen Bag", [4307] = "Heavy Linen Gloves",
    [2569] = "Linen Boots", [2320] = "Coarse Thread", [2568] = "Brown Linen Vest", [2580] = "Reinforced Linen Cape",
    [4329] = "Star Belt", [4313] = "Red Woolen Bracers", [90411] = "Dustwalker Vest" }
for id, name in pairs(NAMES) do mock.itemInfo[id] = { name = name } end

local trips = j.trips or {}
local USUAL, HEAVY, THIN = trips[1], trips[2], trips[3]
local function Plain(s) return (s:gsub(NBSP, " ")) end

--------------------------------------------------------------------------
Section("the moment gathers only real rounds")

Check(USUAL and HEAVY and THIN, "setup: the testdata's three trips")
Check(CityTrips.Real(USUAL), "the usual trip is not a real round")
Check(CityTrips.Real(HEAVY), "the heavy trip is not a real round")
Check(not CityTrips.Real(THIN), "the thin trip (a quest in, the next taken) is a real round")
-- Three lines of one errand are not a round; a second errand makes one.
local crafted = { t = 1, to = 2, made = { { id = 2996, n = 3 } }, skills = { { line = 197, name = "Tailoring", from = 1, to = 9 } },
    recipes = { 3915 } }
Eq(select(1, CityTrips.Lines(crafted)), 3, "a craft's three lines")
Check(not CityTrips.Real(crafted), "three lines of crafting alone are a real round")
crafted.quests = { { id = 1, title = "Of Rats", out = true } }
Check(CityTrips.Real(crafted), "crafting and a quest handed in are no round")
local gathered = {}
local ctx = Recap.Context(ns.ownGUID, mock.now)
for _, at in ipairs(T.DiaryPages(page)) do
    local pieces = Recap.Pieces(j, at.e, page.ctx or ctx)
    local p = at.k and pieces[at.k] or at.e
    for _, m in ipairs(Recap.Moments(j, p, page.ctx or ctx)) do
        if m.kind == "trip" then
            gathered[m.trip] = true
            Eq(m.from, m.trip.t, "the moment's span begins with the trip")
            Eq(m.to, m.trip.to, "the moment's span ends with the trip")
            -- Kept, so the room rule keeps it on its page (testdata's level
            -- 11 is FL already, which leaves a sheet no room unless kept).
            ns.Chosen.Keep(j, m)
        end
    end
end
Check(gathered[USUAL] and gathered[HEAVY], "a real round is no moment")
Check(not gathered[THIN], "the thin trip made a moment")

--------------------------------------------------------------------------
-- The pages that hold a sheet.

local sheets = {}
local function Find()
    sheets = {}
    for _, at in ipairs(T.DiaryPages(page)) do
        T.OpenDiaryPage(page, at.i, at.k)
        for i = 1, page.layout or 0 do
            local leaf = YD.SheetAt(i)
            if leaf and leaf.trip then sheets[leaf.trip.rec] = { at = at, index = i } end
        end
    end
end
Find()
local function Open(rec)
    local s = sheets[rec]
    T.OpenDiaryPage(page, s.at.i, s.at.k)
    return YD.SheetAt(s.index), s.index
end

--------------------------------------------------------------------------
Section("the sheet draws on the usual and the heavy trip")

Check(sheets[USUAL] ~= nil, "no sheet for the usual trip")
Check(sheets[HEAVY] ~= nil, "no sheet for the heavy trip")
Check(sheets[THIN] == nil, "a sheet for the thin trip")
local S = CityTrips.SHEET
for _, rec in ipairs({ USUAL, HEAVY }) do
    local leaf = Open(rec)
    local tr = leaf.trip
    Check(leaf:IsShown(), "the leaf is not shown")
    Check(page.pattern:find("H", 1, true) ~= nil, "the page's key has no sheet: " .. tostring(page.pattern))
    Check(leaf.heading and leaf.heading:GetText():find("Orgrimmar", 1, true), "the heading does not name the city")
    Check(tr.counts.stay, "how long the stay was is not at the heading's end")
    Check(tr.counts.pen > 40, "the pen drew little: " .. tr.counts.pen)
    Check(tr.counts.drawings >= 3, "too few drawings at the stops: " .. tr.counts.drawings)
    for _, p in ipairs(tr.plan.places) do
        Check(p.y + p.rows * S.lead <= S.foot + 0.01, "a line past the leaf's foot: " .. p.line.text)
        for _, atom in ipairs(p.atoms) do
            Check(atom.x + atom.w <= S.width + 0.5, ("a word past its half: %s (%.1f)"):format(atom.text or "->", atom.x + atom.w))
        end
    end
end

--------------------------------------------------------------------------
Section("the city's stay is told once")

for _, rec in ipairs({ USUAL, HEAVY }) do
    local _, index = Open(rec)
    local e = YD.ShownPiece()
    local sheetPlate = e.plates[index]
    local told = false
    for _, m in ipairs(sheetPlate.moments) do told = told or m.kind == "stay" end
    Check(told, "the sheet does not tell its visit's stay")
    for i, p in ipairs(e.plates) do
        if i ~= index then
            for _, m in ipairs(p.moments) do
                local seg = m.seg or {}
                local overlaps = m.kind == "stay" and m.mapID == rec.mapID and (seg.from or m.t) <= rec.to
                    and (seg.to or m.t) >= rec.t
                Check(not overlaps, "the visit's stay opened a map plate beside its sheet")
            end
        end
    end
end

--------------------------------------------------------------------------
Section("an upgrade put on in town: told on the sheet, off the plates")

-- The vest put on during the usual trip (Features/Upgrades/Dev.lua),
-- offered to the sheet as an errand ("worn"): while the sheet is on the
-- page it is in the sheet's plate, and no map plate has its tunic or its
-- note; the sheet left out, it is back on Orgrimmar's plate as ever.
local function Vest(m)
    return m.upgrade and type(m.upgrade.link) == "string" and m.upgrade.link:find("Dustwalker Vest", 1, true) ~= nil
end
local function VestOnPlates()
    local marks, notes = 0, 0
    for i = 1, page.layout or 0 do
        local plate = page.plates[i]
        if plate and plate:IsShown() and not YD.SheetAt(i) then
            for _, key in ipairs({ "upgradeMarks", "pieceMarks" }) do
                for _, mark in ipairs(plate[key] or {}) do
                    for _, m in ipairs(mark.list or {}) do if Vest(m) then marks = marks + 1 end end
                end
            end
            for _, it in ipairs(plate.pieces and plate.pieces.list or {}) do
                if it.m and Vest(it.m) then notes = notes + 1 end
            end
            if plate.upgrade and plate.upgrade.m and Vest(plate.upgrade.m) then notes = notes + 1 end
        end
    end
    return marks, notes
end
do
    local _, index = Open(USUAL)
    local e = YD.ShownPiece()
    local sheetPlate = e.plates[index]
    local told, trip
    for _, m in ipairs(sheetPlate.moments) do
        if Vest(m) then told = m end
        if m.kind == "trip" then trip = m end
    end
    Check(told ~= nil, "the vest put on in town is not in the sheet's plate")
    Check(trip and trip.errands and #trip.errands == 1, "the trip's moment does not carry the vest as its errand")
    Eq(trip and trip.errands[1].errand.from, "auction", "the errand says where the vest came from")
    for i, p in ipairs(e.plates) do
        if i ~= index then
            for _, m in ipairs(p.moments) do Check(not Vest(m), "the vest on a map plate beside the sheet") end
        end
    end
    local marks, notes = VestOnPlates()
    Eq(marks, 0, "the vest's tunic on a plate while the sheet tells it")
    Eq(notes, 0, "the vest's note on a plate while the sheet tells it")
    -- The sheet left out (the ticklist's untick): the vest is back.
    local at = sheets[USUAL].at
    ns.Chosen.Leave(j, trip)
    ns.UI.RefreshJourneyPage(false)
    T.OpenDiaryPage(page, at.i, at.k)
    Check(not (page.pattern or ""):find("H", 1, true), "setup: the sheet left out: " .. tostring(page.pattern))
    marks = VestOnPlates()
    Eq(marks, 1, "the sheet left out, the vest's tunic is not back on its plate")
    ns.Chosen.Keep(j, trip)
    ns.UI.RefreshJourneyPage(false)
    Find()
    Check(sheets[USUAL] ~= nil, "setup: the usual sheet back")
end

-- Matched by span and map: outside the trip, or on another map, no errand.
do
    local list = ns.Upgrades.List(j)
    local vest
    for _, rec in ipairs(list) do if rec.link:find("Dustwalker Vest", 1, true) then vest = rec end end
    Check(vest ~= nil, "setup: the vest in the testdata")
    local function Offered()
        local ctx1 = Recap.Context(ns.ownGUID, mock.now)
        for _, at in ipairs(T.DiaryPages(page)) do
            local pieces = Recap.Pieces(j, at.e, page.ctx or ctx1)
            local p = at.k and pieces[at.k] or at.e
            if p.errands and p.errands[vest] then return true end
        end
        return false
    end
    -- (Recap.Pieces caches on the entry: a fresh recap each time)
    local function Fresh()
        ns.Journey.Touch()
        ns.UI.RefreshJourneyPage(false)
    end
    Check(Offered(), "the vest is offered to no sheet")
    local t, map = vest.t, vest.mapID
    vest.t = USUAL.to + 120
    Fresh()
    Check(not Offered(), "a vest put on after the trip is offered to it")
    vest.t, vest.mapID = t, 1413 -- (The Barrens: a map the mock knows)
    Fresh()
    Check(not Offered(), "a vest put on in another zone is offered to the trip")
    vest.mapID = map
    Fresh()
    Check(Offered(), "setup: the vest offered again")
end

-- The round: a thing put on is a kind of its own. A purchase and the
-- thing put on are two lines of two kinds; a quest handed in makes three.
do
    local worn = { { kind = "worn", from = "auction", link = "[Dustwalker Vest]" } }
    local trip = { t = 1, to = 2, bought = { { id = 90411, n = 1, paid = 1450 } } }
    local lines, kinds = CityTrips.Lines(trip, worn)
    Eq(lines, 2, "a purchase and a thing put on: lines")
    Eq(kinds, 2, "a purchase and a thing put on: kinds")
    Check(not CityTrips.Real(trip, worn), "two lines are a round")
    trip.quests = { { id = 1, title = "Of Rats", out = true } }
    Check(CityTrips.Real(trip, worn), "bought, put on and a quest handed in are no round")
    Check(not CityTrips.Real(trip), "without the thing put on, two lines are a round")
    -- An errand of a kind the sheet does not read counts for nothing.
    Check(not CityTrips.Real(trip, { { kind = "sung" } }), "an errand of an unknown kind counted")
end

--------------------------------------------------------------------------
Section("the stops in their order, the purse last")

local ORDER = {}
for k, stop in ipairs(CityTrips.STOPS) do ORDER[stop.key] = k end
for _, rec in ipairs({ USUAL, HEAVY }) do
    local leaf = Open(rec)
    local places = leaf.trip.plan.places
    local last = 0
    local prevCol, prevY = 1, -1
    for _, p in ipairs(places) do
        Check(ORDER[p.stop.key] >= last, "a stop out of order: " .. p.stop.key)
        last = ORDER[p.stop.key]
        -- down the left half, then the right: never back
        Check(p.col > prevCol or (p.col == prevCol and p.y > prevY), "a line laid above the one before")
        prevCol, prevY = p.col, p.y
    end
    Eq(places[#places].stop.key, "purse", "the purse is not last")
    Check(places[#places].line.text:find("^Left with") or places[#places].line.text:find("^Came and went"),
        "the purse's last line: " .. places[#places].line.text)
    -- The purse follows the last errand at once (not pinned to the foot).
    local purse
    for k, p in ipairs(places) do if p.stop.key == "purse" and not purse then purse = k end end
    local before = places[purse - 1]
    if before.col == places[purse].col then
        Check(places[purse].y - (before.y + before.rows * S.lead) <= S.gap + 2 + S.lead, "the purse is not right after the last errand")
    end
end
-- The usual round as laid: the post first, the quests after the auction
-- house, every line whole.
local usual = Open(USUAL)
local texts = {}
for _, p in ipairs(usual.trip.plan.places) do texts[#texts + 1] = Plain(p.line.text) end
Eq(texts[1], "Tester bought your Linen Bag for 4s", "the first line")
Eq(texts[2], "A lot came back unsold", "what came back")
Eq(texts[3], "A parcel from Tester with one thing and 25s", "the letter from Tester")
Eq(texts[4], "Sent a letter to a stranger", "the letter sent to a stranger")
Eq(texts[5], "Bought twenty Linen Cloth for 2s", "the purchase (a stranger seller unsaid)")
Eq(texts[6], "Bought one Dustwalker Vest for 15s", "the vest bought at the auction house")
Eq(texts[7], "Put up four Bolts of Linen Cloth and two Linen Bags", "what was put up (Bolts, not Bolt)")
-- The upgrade put on in town (Features/Upgrades/Dev.lua), offered to the
-- sheet as an errand: its own stop after the workbench, saying where it
-- came from.
Eq(texts[8], "Put on Dustwalker Vest, off the auction house", "the vest put on, from the auction house")
Eq(texts[9], "Handed in “Conscript of the Horde” with Tester", "the quest with Tester on it")
Eq(texts[10], "Came with 41s", "the purse came with")
Eq(texts[11], "Left with 64s", "the purse left with")

--------------------------------------------------------------------------
Section("a name: underlined, its click opens their page, its tooltip")

local opened
local toPerson = YD.ToPerson
YD.ToPerson = function(guid) opened = guid end
usual = Open(USUAL)
local nameStops = {}
for _, stop in ipairs(usual:Stops()) do
    if tostring(stop.key):find("^name:") then nameStops[#nameStops + 1] = stop end
end
Eq(#nameStops, 3, "Tester's three names on the usual sheet are not three stops")
local stop = nameStops[1]
Eq(stop.words:GetText(), "Tester", "the name's words")
local r, g, b = stop.words:GetTextColor()
local I = ns.Style.INK_STRONG
Check(math.abs(r - I[1]) < 0.01 and math.abs(g - I[2]) < 0.01 and math.abs(b - I[3]) < 0.01, "a name not in strong ink")
stop.press()
Eq(opened, TESTER, "a name's click did not open their page")
opened = nil
stop.frame:Click("LeftButton")
Eq(opened, TESTER, "the mouse on a name did not open their page")
local tip = stop.tip()
Eq(tip[1][1], ns.UI.JourneyText.Who(TESTER), "the tooltip's title is not their name")
Eq(tip[2][1], "Click to open their page.", "the tooltip's hint")
YD.ToPerson = toPerson
-- Underlined: one pen line under each name, besides the city's.
Check(usual.trip.counts.names == 3, "names counted: " .. usual.trip.counts.names)

--------------------------------------------------------------------------
Section("strangers are counted, never named")

local STRANGER = "Player-4707-00EE0001"
ns.db.characters[STRANGER] = { firstSeen = mock.now, names = {} }
local rec = {
    t = USUAL.t, to = USUAL.to, mapID = USUAL.mapID, came = 10000, left = 12000,
    sold = { { id = 4241, n = 4, got = 4400, who = { TESTER }, others = 3 } },
    bought = { { id = 2589, n = 20, paid = 800, others = 1 } },
    letters = { { n = 2, items = 3 } },
    sent = { { n = 1, items = 1 } },
}
local people = { traded = { guids = { TESTER }, strangers = 1, seen = {} }, strangers = 1 }
local stops = CityTrips.Stops(rec, { people = people }, {})
local lines = {}
for _, st in ipairs(stops) do
    for _, line in ipairs(st.lines) do
        lines[#lines + 1] = Plain(line.text)
        for _, m in ipairs(line.marks) do
            if m.kind == "name" then Eq(m.guid, TESTER, "someone other than Tester named: " .. tostring(m.s)) end
        end
    end
end
Eq(lines[1], "Tester bought your Woolen Bag for 11s", "the known buyer's line")
Eq(lines[2], "Three more sold for 33s, to three strangers", "the strangers counted on a sale")
Eq(lines[3], "Two parcels from strangers", "strangers' parcels counted")
Eq(lines[4], "Sent a letter to a stranger", "a letter to a stranger")
Eq(lines[5], "Bought twenty Linen Cloth for 8s", "a stranger seller is not mentioned")
Eq(lines[6], "Traded with Tester and a stranger", "the people round the trip")
-- The People rows inside the trip's span, read as the sheet is drawn.
ns.db.interactions[STRANGER] = { { time = USUAL.t + 30, type = "trade", me = ns.ownGUID } }
local round = CityTrips.Round(USUAL, ns.ownGUID)
Check(round.traded and round.traded.strangers == 1 and #round.traded.guids == 0, "a trader with no name not counted")
ns.db.interactions[STRANGER] = nil

--------------------------------------------------------------------------
Section("the heavy trip folds; a counted part's tooltip lists what it merged")

local heavy = Open(HEAVY)
local folds = heavy.trip.folds
Check(folds.n > 0, "the heavy trip did not fold")
Check(not folds.dropped, "the heavy trip lost lines past every fold")
local tail, counted
for _, p in ipairs(heavy.trip.plan.places) do
    for _, m in ipairs(p.line.marks) do
        if m.kind == "tail" and m.tip then tail = tail or { line = p.line, mark = m } end
    end
    if p.line.tip then counted = counted or p.line end
end
Check(tail ~= nil, "no counted tail on the heavy sheet")
if tail then
    Eq(Plain(tail.line.text), "Bought 60 Wool Cloth, and one other thing", "the purchases folded")
    local list = tail.mark.tip
    Eq(list[1][1], "Bought", "the tail's tooltip title")
    Eq(Plain(list[2][1]), "Bought 60 Wool Cloth for 18s", "the first merged line")
    -- (the core's ItemWord counts thread: "Coarse Threads", reported)
    Eq(Plain(list[3][1]), "Bought twenty " .. CityTrips.ItemWord(20, "Coarse Thread") .. " for 2s", "the second merged line")
    local found
    for _, st in ipairs(heavy:Stops()) do
        if tostring(st.key):find("^tail:") then found = st end
    end
    Check(found and found.tip() == list, "the tail is no stop with its tooltip")
    Check(found and found.press == nil, "a counted part offers a click")
end
Check(counted ~= nil, "no counted line on the heavy sheet")
-- The heavy round with three things put on as well (one a gift from
-- Tester): it still folds within the leaf, the things put on folded to one
-- line and a tail, joined to the stop before, the gift's giver named.
do
    local worn = {
        { errand = { kind = "worn", from = "auction", link = "|cff1eff00|Hitem:90411|h[Dustwalker Vest]|h|r" } },
        { errand = { kind = "worn", from = "vendor", link = "|cff1eff00|Hitem:90413|h[Gritwalker Boots]|h|r" } },
        { errand = { kind = "worn", from = "trade", guid = TESTER, link = "|cff0070dd|Hitem:90414|h[Ashen Cloak]|h|r" } },
    }
    local ctx2 = { people = CityTrips.Round(HEAVY), errands = worn }
    local plan, stops, folds2 = CityTrips.Plan(heavy, HEAVY, ctx2)
    Check(not plan.over, "the heavy round with things put on runs past the leaf")
    -- (The heavy round is at every cap and took every fold before it had
    -- anything put on; with them, in the mock's widths, one line past every
    -- fold still goes from the end, the quests', never a name or the purse.
    -- An open point for the client round: .claude/features/city-trips.md.)
    Check((folds2.dropped or 0) <= 1, "the heavy round with things put on lost more than a line: " .. tostring(folds2.dropped))
    Check(folds2.wornFold and folds2.wornJoin, "the things put on did not fold on the heavy round")
    local laid = {}
    for _, x in ipairs(plan.places) do laid[#laid + 1] = Plain(x.line.text) end
    laid = table.concat(laid, " / ")
    Check(laid:find("Put on Ashen Cloak, a gift from Tester", 1, true), "the folded put-on line not laid: " .. laid)
    Check(laid:find("Left with", 1, true), "the purse not laid: " .. laid)
    local wornLines, giver = {}, false
    for _, stop in ipairs(stops) do
        for _, line in ipairs(stop.lines) do
            if line.text:find("^Put on") then
                wornLines[#wornLines + 1] = Plain(line.text)
                for _, m in ipairs(line.marks) do giver = giver or (m.kind == "name" and m.guid == TESTER) end
            end
        end
    end
    Eq(wornLines[1], "Put on Ashen Cloak, a gift from Tester, and two other things", "the things put on, folded")
    Check(giver, "the gift's giver not named on the folded line")
    -- Unfolded, each says where it came from.
    local full = CityTrips.Stops(HEAVY, { errands = worn }, {})
    local said = {}
    for _, stop in ipairs(full) do
        if stop.key == "worn" then for _, line in ipairs(stop.lines) do said[#said + 1] = Plain(line.text) end end
    end
    Eq(said[1], "Put on Dustwalker Vest, off the auction house", "a thing put on, from the auction house")
    Eq(said[2], "Put on Gritwalker Boots, from a merchant", "a thing put on, from a merchant")
    Eq(said[3], "Put on Ashen Cloak, a gift from Tester", "a gift put on, its giver named")
    -- A stranger's gift names no one.
    local stranger = CityTrips.Stops(HEAVY, { errands = { { errand = { kind = "worn", from = "trade",
        link = "|cff0070dd|Hitem:90414|h[Ashen Cloak]|h|r" } } } }, {})
    for _, stop in ipairs(stranger) do
        if stop.key == "worn" then Eq(Plain(stop.lines[1].text), "Put on Ashen Cloak, a gift", "a stranger's gift") end
    end
    Open(HEAVY)
end
-- Tester stays named however much is folded.
local named = 0
for _, st in ipairs(heavy:Stops()) do
    if tostring(st.key):find("name:" .. TESTER, 1, true) == 1 then named = named + 1 end
end
Check(named >= 2, "Tester folded away on the heavy sheet")
-- The purse and the rank line are never folded.
local rank, purse = false, 0
for _, p in ipairs(heavy.trip.plan.places) do
    rank = rank or p.line.rank ~= nil
    if p.stop.key == "purse" then purse = purse + 1 end
end
Check(rank, "the rank line folded away")
Eq(purse, 2, "the purse's two lines")

--------------------------------------------------------------------------
Section("a trip that fits never folds")

usual = Open(USUAL)
Eq(usual.trip.folds.n, 0, "the usual trip folded")
local plan, _, thinFolds = CityTrips.Plan(usual, THIN, {})
Eq(thinFolds.n, 0, "the thin trip folded")
Check(not plan.over, "the thin trip overflows")

--------------------------------------------------------------------------
Section("the words' helpers")

Eq(CityTrips.ItemWord(12, "Bolt of Woolen Cloth"), "Bolts of Woolen Cloth", "a bolt of cloth, more than one")
Eq(CityTrips.ItemWord(20, "Linen Cloth"), "Linen Cloth", "cloth is not counted")
Eq(Plain(CityTrips.Coin(28037)), "2g 80s", "coin rounded to the silver")
Eq(Plain(CityTrips.Coin(28077)), "2g 81s", "coin rounded up to the silver")
Eq(CityTrips.Coin(45), "45c", "copper under a silver")
Eq(CityTrips.Coin(28037):find(" ", 1, true), nil, "coin not held together")
Eq(Plain(CityTrips.Exact(28037)), "2g 80s 37c", "the exact sum")
Eq(Plain(CityTrips.Label({ from = 0, to = 38 * 60, trip = USUAL })), "Errands, 38 min", "the ticklist row's words")
Eq(CityTrips.Tip(), "What you did in town, on half a page", "the row's tooltip")
-- The heading always names its city, even counting on from a plate before
-- it on the same map.
local plate = { mapID = USUAL.mapID, t = USUAL.t }
local line = CityTrips.Heading(plate, mock.now, { mapID = USUAL.mapID, t = USUAL.t - 600 })
Check(line:find("Orgrimmar", 1, true) ~= nil, "the heading after a plate on the same map names no city: " .. line)
-- Runs: names found by a plain search, a whole word preferred.
local runs = CityTrips.Runs("Ann bought Annabel's bag from Anna", { { s = "Anna", kind = "name" } })
Eq(runs[#runs][1], "Anna", "the whole word not preferred")
-- The purse when the sums round the same.
local same = CityTrips.Stops({ t = 1, to = 2, came = 8640, left = 8620, back = 1 }, {}, {})
Eq(Plain(same[#same].lines[1].text), "Came and went with 86s", "came and went")

--------------------------------------------------------------------------
Section("the thread stays in its column")

-- Every thread the pen draws on a sheet, as asked of Scribble.Thread: its
-- runs ({ x, y0, y1 }), each a column's x. One call is one thread; none
-- may hold runs in both columns (it once ran from the left column's foot
-- to the right one's top, an arrow across the leaf: the user, 25 Nov 2026,
-- "the arrow that connects the two cols is irritating"). The right
-- column's thread starts at its top only where its first line goes on
-- with a broken stop; where it opens a new stop, at that stop's drawing.
local Scribble = ns.UI.Scribble
local thread = Scribble.Thread
local function Threads(rec)
    local calls = {}
    Scribble.Thread = function(seed, runs)
        calls[#calls + 1] = runs
        return thread(seed, runs)
    end
    local ok, leaf = pcall(Open, rec)
    Scribble.Thread = thread
    assert(ok, leaf)
    return leaf, calls
end
local X1, X2 = S.cols[1].X, S.cols[2].X
local seen = {}
local function CheckThreads(label, leaf, calls)
    local plan = leaf.trip.plan
    local top2
    for _, runs in ipairs(calls) do
        local x = runs[1][1]
        Check(x == X1 or x == X2, label .. ": a thread off both columns at x " .. tostring(x))
        for _, run in ipairs(runs) do
            Eq(run[1], x, label .. ": a thread runs across from one column to the other")
            Check(run[3] >= run[2], label .. ": a thread runs upward")
            if x == X2 then top2 = math.min(top2 or math.huge, run[2]) end
        end
    end
    if plan.cols ~= 2 then
        for _, runs in ipairs(calls) do Eq(runs[1][1], X1, label .. ": a thread in an unused column") end
        return
    end
    local first2
    for _, p in ipairs(plan.places) do
        if p.col == 2 then first2 = p break end
    end
    if not top2 then return end
    if first2.first then
        seen.new = true
        Check(top2 >= first2.y + S.drawing.room[1] - 0.01,
            label .. ": a stub of thread over the right column's first stop (" .. top2 .. ")")
        -- and the left column's thread ends at its last drawing (or a
        -- lot's cross under it), not trailing on toward its foot
        local lastDrawing
        for _, p in ipairs(plan.places) do
            if p.col == 1 and p.first and p.stop.icon then lastDrawing = p.y + S.drawing.room[1] end
            if p.col == 1 and p.line.cross then lastDrawing = p.y + S.cross.room[1] end
        end
        for _, runs in ipairs(calls) do
            for _, run in ipairs(runs) do
                if run[1] == X1 and lastDrawing then
                    Check(run[3] <= lastDrawing + 0.01, label .. ": the left column's thread trails past its last stop")
                end
            end
        end
    else
        seen.broken = true
        Check(top2 <= S.top, label .. ": a broken stop's thread does not run from the right column's top")
    end
end
for _, pair in ipairs({ { "usual", USUAL }, { "heavy", HEAVY } }) do
    CheckThreads(pair[1], Threads(pair[2]))
end
-- Both ways into the right column, whatever the testdata breaks at: the
-- foot moved up a row at a time until the right column has been seen both
-- opening a new stop and going on with a broken one.
local foot = S.foot
for step = 1, 8 do
    S.foot = foot - step * S.lead
    for _, pair in ipairs({ { "usual", USUAL }, { "heavy", HEAVY } }) do
        CheckThreads(pair[1] .. " at foot " .. S.foot, Threads(pair[2]))
    end
end
S.foot = foot
Open(USUAL)
Check(seen.new, "the right column never opened a new stop: the case untested")
Check(seen.broken, "the right column never went on with a broken stop: the case untested")

--------------------------------------------------------------------------
Section("flat paper")

ns.SetSetting("flatSheets", true)
local flat = Open(HEAVY)
Check(flat.flat, "the leaf not laid flat")
Eq(flat.turn, 0, "a flat leaf turned")
Check(flat.trip and flat.trip.counts.pen > 40, "the pen draws little on flat paper")
Check(flat.trip.counts.drawings >= 3, "no drawings on flat paper")
ns.SetSetting("flatSheets", false)

--------------------------------------------------------------------------
Section("the pad goes in among the names; the mouse takes every colour back")

local Pad = ns.UI.Pad
local book = ns.UI.JournalFrame()
mock.pad.ui, mock.pad.enabled, mock.pad.devices = true, true, { 1 }
mock.fire("GAME_PAD_ACTIVE_CHANGED", true)
opened = nil
YD.ToPerson = function(guid) opened = guid end
local leaf = Open(USUAL)
local catcher = Pad.Catcher(book)
local function Press(key)
    mock.PadPress(catcher, key, true)
    return mock.PadPress(catcher, key, false)
end
local function Scope() return Pad.Top() end
local function At() return Scope().focus:Current() end
local function Items(group) return Scope().focus.groups[group].items end
local function Red(fs)
    local rr, gg, bb = fs:GetTextColor()
    local R = ns.Style.RUBRIC
    return math.abs(rr - R[1]) < 0.01 and math.abs(gg - R[2]) < 0.01 and math.abs(bb - R[3]) < 0.01
end
Eq(Scope().key, "yourdiary", "the top scope")
Press("PAD1")
Eq(At().group, "page", "A on the rubric did not cross to the right page")
local sheetItem
for _, item in ipairs(Items("page")) do if item.sheet then sheetItem = item end end
Check(sheetItem ~= nil, "the sheet is no item of the page")
Scope().focus:Set(sheetItem)
Check(Red(leaf.heading), "the sheet's heading is not red")
Press("PAD1")
Eq(At().group, "stops", "A on the sheet did not go in among its names")
local stopCount = #Items("stops")
Eq(stopCount, #leaf:Stops(), "the pad's stops are not the sheet's")
local nameItem
for _, item in ipairs(Items("stops")) do
    if item.hasClick and not nameItem then nameItem = item end
end
Check(nameItem ~= nil, "no name among the pad's stops")
Scope().focus:Set(nameItem)
Check(nameItem.words and Red(nameItem.words), "the name's words are not red")
Press("PAD1")
Eq(opened, TESTER, "A on a name did not open their page")
-- The purse is a stop with its tooltip only.
local purseItem
for _, item in ipairs(Items("stops")) do
    if item.key == "stop:purse" then purseItem = item end
end
Check(purseItem ~= nil and not purseItem.hasClick, "the purse is no stop, or offers a click")
Press("PAD2")
Eq(At().group, "page", "B among the names did not come back to the page")
-- The mouse takes over: nothing stays red.
Scope().focus:Set(nameItem)
mock.pad.ui, mock.pad.enabled, mock.pad.devices = false, false, {}
mock.fire("GAME_PAD_ACTIVE_CHANGED", false)
Check(not Red(leaf.heading), "the sheet's heading stays red with the mouse")
for _, st in ipairs(leaf:Stops()) do
    Check(not Red(st.words), "a stop's words stay red with the mouse: " .. tostring(st.words:GetText()))
end
Check(not catcher:IsGamePadButtonEnabled(), "the catcher on with the Gamepad UI off")
YD.ToPerson = toPerson

--------------------------------------------------------------------------
-- What the sheets cost (for the report; printed with -v).
for _, pair in ipairs({ { "usual", USUAL }, { "heavy", HEAVY } }) do
    local l = Open(pair[2])
    local c = l.trip.counts
    print(("%s: %d pen quads, %d drawing textures, %d names, %d folds"):format(pair[1], c.pen, c.sketch, c.names,
        l.trip.folds.n))
end

-- SD_CT_DUMP=1 luajit tests/run.lua -v citytrips_ui: each sheet's rows as
-- laid ("@" a stop's drawing; [n:] a name, [t:] a counted tail, [s:]/[r:] the
-- purse struck and ringed), the plates' render tool drawing a sheet blank.
if os.getenv("SD_CT_DUMP") then
    for _, rec in ipairs({ USUAL, HEAVY }) do
        local l = Open(rec)
        print("HEADING", l.heading:GetText())
        for _, p in ipairs(l.trip.plan.places) do
            local rows = {}
            for _, a in ipairs(p.atoms) do
                rows[a.row] = (rows[a.row] or "") .. (a.space and " " or "") .. (a.mark and ("[" .. a.mark.kind:sub(1, 1) .. ":" .. a.text .. "]") or a.arrow and "->" or a.text)
            end
            for r = 1, p.rows do
                print(("c%d y%3d %s%s"):format(p.col, p.y + (r - 1) * 17, (r == 1 and p.first and p.stop.icon) and "@ " or "  ", Plain(rows[r] or "")))
            end
        end
    end
end
