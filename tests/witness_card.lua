-- The witness card (Features/Witnesses/Card.lua): someone who was there
-- when you died or nearly did, in the plate's margin, in the place of the
-- card they go before (the killer's, or a rescue's close
-- call's). Its words in every case (saw, watched, mercilessly watched,
-- tried to save you, saved you), "Ilsabet & two others" on the name's one
-- line or the name alone, a rescue's health charted, "mercilessly"
-- underlined twice, and on a watcher's card dried blood across its corner
-- and onto the page (a stain, not crumbs; under the ends of the lines
-- nearest its corner only, and there only its paler wash; never under the
-- name; more the longer they watched; the same every time; laid flat with
-- the card); its sizes by the room it has
-- and its step down, its rank in the margin and its leader, and the
-- caption: silent about what the card says, the creature named where the
-- card gave up its line, the witness told in a sentence of its own where
-- the card had no room.
--
-- The mock measures every string at 6 px a byte: the sizes asserted here
-- are the mock's, not the client's.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local SELF = F.SELF
local Text = ns.UI.JourneyText
local Card = ns.Witnesses.Card
local W = ns.Witnesses

mock.now = 1791000000
local now = mock.now
SELF.level = 12
mock.SetUnit("player", SELF)

local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern) then return true end
    end
    return false
end

local GRISHA = "Player-0000-7E57E599"
ns.Characters.Observe(GRISHA, { first = "Grisha", class = "ROGUE", race = "Orc", level = 17, sex = 3, time = now })

local WOLF = { npcID = 299, name = "Ragged Young Wolf" }
local function Watcher(seconds, extra)
    local w = { kind = "watched", type = "watched_death", guid = GRISHA, t = now - 600, watched = seconds,
        creature = WOLF, others = 0, death = { t = now - 600 }, mark = { 100, 100 } }
    for key, value in pairs(extra or {}) do w[key] = value end
    return w
end
local function Helper(kind, extra)
    local w = { kind = "helped", type = kind, guid = GRISHA, t = now - 600, others = 0,
        creature = { npcID = 448, name = "Hogger", rank = "rare" }, mark = { 100, 100 } }
    if kind == "saved_you" then w.pct, w.call = 6, { t = now - 600, pct = 6 } else w.death = { t = now - 600 } end
    for key, value in pairs(extra or {}) do w[key] = value end
    return w
end

--------------------------------------------------------------------------
Section("its words")

Eq(W.Deed(Watcher(0.8)), "saw you die", "a glance")
Eq(W.Deed(Watcher(1.5)), "watched you die", "from 1.5 s on, watching")
Eq(W.Deed(Watcher(4.9)), "watched you die", "under five seconds, watching")
local deed, under = W.Deed(Watcher(5))
Eq(deed, "mercilessly watched you die", "from five seconds on, merciless")
Eq(under, "mercilessly", "the word the hand underlines")
Eq(W.Deed(Watcher(nil)), "watched you die", "a row from before the watching was timed")
Eq(W.Deed(Helper("tried_to_help")), "tried to save you", "who tried")
Eq(W.Deed(Helper("saved_you")), "saved you", "who saved you")
Eq(W.Foe(Watcher(3)), "to a Ragged Young Wolf", "a death's creature")
Eq(W.Foe(Helper("saved_you")), "from Hogger", "a rescue's creature, a rare bare as a killer's")
Eq(W.Foe(Watcher(3, { creature = false })), nil, "no creature kept")
Eq(W.Others(0), nil, "alone")
Eq(W.Others(1), "& another", "one more, on the name's line")
Eq(W.Others(2), "& two others", "two more, on the name's line")
Eq(W.Others(2, true), "and two others", "two more, in a sentence")
Eq(W.Name(Watcher(3)), "Grisha", "their first name")
Eq(W.Name(Watcher(3, { guid = "Player-0000-00000000" })), "Someone", "a name the buffer lost")
Eq(W.Caption(Watcher(6.4, { others = 2 })), "Grisha and two others mercilessly watched you die.",
    "the caption's sentence")
Eq(W.Caption(Helper("tried_to_help")), "Grisha tried to save you.", "the caption's sentence, helped")

local title, lines = W.Tip(Watcher(6.43, { others = 1 }), now)
Eq(title, "Grisha", "the tooltip's title")
local tip = table.concat(lines, "|")
Check(tip:find("^Level 17 Orc Rogue|Watched for 6.4\194\160seconds|Not in a fight themselves|One other was there too|"),
    "the watcher's tooltip: " .. tip)
_, lines = W.Tip(Helper("saved_you"), now)
tip = table.concat(lines, "|")
Check(tip:find("|Joined your fight|You came out of it with 6\194\160health|", 1, true) ~= nil
    or tip:find("Joined your fight|You came out of it with 6%%\194\160health"), "the rescue's tooltip: " .. tip)

-- The caption: the witness in a sentence after the rest, only when given.
local plate = { mapID = 1411, moments = { { kind = "death", t = now - 600 } } }
Eq(Text.PlateCaption(plate, nil, { death = "a Ragged Young Wolf" }), "A death, to a Ragged Young Wolf.",
    "the caption without a witness")
Eq(Text.PlateCaption(plate, nil, { death = "a Ragged Young Wolf", witness = Watcher(6.4) }),
    "A death, to a Ragged Young Wolf. Grisha mercilessly watched you die.", "the caption with the witness left off")

--------------------------------------------------------------------------
Section("the card: its name line, chart and sizes")

local parent = CreateFrame("Frame", nil, UIParent)
local card = Card.New(parent)
local function Lay(w, width, key)
    card:SetWitness(w, key or "test", now, GRISHA, function() end)
    return card:Layout(10, 10, width)
end

-- No seconds on the card, in any case: the words carry it.
for _, s in ipairs({ 1.2, 3.7, 6.4 }) do
    Lay(Watcher(s), 176)
    Eq(card.plan.row, nil, s .. " s watched has a row under the words")
    Check(not card.figure:IsShown(), s .. " s watched has a figure")
end
Lay(Watcher(3.7), 176)
Eq(card.underlined, nil, "plain watching is underlined")
Lay(Watcher(6.4), 240)
Check(card.underlined ~= nil and (card.pieces or 0) > 0, "mercilessly is not underlined")
Eq(card:Deed(), "mercilessly watched you die", "the merciless deed")
Eq(card:Foe(), "to a Ragged Young Wolf", "the foe's line")
-- The underline runs under the word, not past its line.
local u = card.underlined
Check(u.x1 > u.x0 and u.x1 - u.x0 < 120, "the underline is not under the word")

-- A rescue: its health charted in rubric; one who tried: neither.
Lay(Helper("saved_you"), 176)
Eq(card.plan.row and card.plan.row.kind, "chart", "the rescue's health is not charted")
Check(card.barFill:IsShown() and card.figure:GetText() == "6%", "the chart is not drawn")
Eq(card.plan.row.bar, 70, "the bar's width in a wide column")
Lay(Helper("tried_to_help"), 176)
Eq(card.plan.row, nil, "one who tried has a chart")
Check(not card.barFill:IsShown() and not card.figure:IsShown(), "the last card's chart stayed")

-- The name and who else was there on one line, "Ilsabet & two others",
-- in every size; where that will not fit, the name alone, never a line of
-- its own.
Lay(Watcher(1.2, { others = 2 }), 220)
Eq(card.name:GetText(), "Grisha & two others", "the name line in XL")
Lay(Watcher(1.2, { others = 1 }), 142)
Eq(card.form .. ":" .. card.name:GetText(), "M:Grisha & another", "the name line in M")
local _, oneLine = card:Layout(10, 10, 142)
Lay(Watcher(1.2), 142)
local _, alone = card:Layout(10, 10, 142)
Eq(oneLine, alone, "who else was there costs the card a line")
-- (The mock measures 6 px a byte: "Grisha & two others" is 114 px, so a
-- 126 px box, 111 px inside, holds the name alone.)
Lay(Watcher(1.2, { others = 2 }), 126)
Eq(card.name:GetText(), "Grisha", "the name line too wide for the box keeps its others")
Eq(card.plan.others, nil, "the others left off are still planned")

-- Sizes by the room: XL in a wide box, L in a column, M in a narrow one;
-- the deed's hand a size down from XL, the name too in M.
Lay(Watcher(3.7), 220)
Eq(card.form, "XL", "a wide box")
Lay(Watcher(3.7), 176)
Eq(card.form, "L", "the 176 px column")
Lay(Watcher(3.7), 150)
Eq(card.form, "L", "the 150 px column")
Lay(Watcher(3.7), 142)
Eq(card.form, "M", "a row's 142 px box")
Lay(Helper("saved_you"), 122)
Eq(card.form, "M", "the 122 px column")
Eq(card.plan.row.bar, 56, "the bar's width in a narrow column")
-- The deed on one line in the hand's own size is XL's: where it will not
-- go (a box under XL's least, or in the client a long deed at 16 px), L.
Lay(Watcher(6.4), 176)
Eq(card.form, "L", "the merciless deed in the 176 px column")
Lay(Watcher(6.4), 240)
Eq(card.form, "XL", "the merciless deed in a wide box")
-- Too narrow for any: left off.
Lay(Watcher(3.7), 60)
Check(card.overfull, "a card in a box too narrow for it is not overfull")

-- Short of height: the foe's line, then nothing.
Lay(Watcher(3.7, { others = 2 }), 130)
local _, tall = card:Layout(10, 10, 130)
Check(card:Smaller(), "the foe's line is not given up")
local _, h1 = card:Layout(10, 10, 130)
Eq(card:Foe(), "", "the foe's line stayed")
Check(h1 < tall, "without the foe's line the card is no shorter")
Check(not card:Smaller(), "the card gives up more than its foe's line")
Lay(Watcher(3.7, { creature = false }), 176)
Check(not card:Smaller(), "a card with no foe gives something up")

-- Its preferred width is XL's, never under XL's least.
card:SetWitness(Helper("saved_you"), "test", now)
Check(card:Preferred() >= Card.FORMS.XL.least, "the preferred width is under XL's")

-- Its name opens their page.
Lay(Watcher(3.7), 176)
Eq(card.name:GetText(), "Grisha", "the card's name")
Eq(card.guid, GRISHA, "the name opens nobody's page")

--------------------------------------------------------------------------
Section("the card: blood on a watcher's")

local function Shown()
    local n = 0
    for _, t in ipairs(card.stain) do if t:IsShown() then n = n + 1 end end
    return n
end

-- None on a helper's card.
Lay(Helper("saved_you"), 176)
Eq(card.blood, nil, "a rescue's card has blood")
Eq(Shown(), 0, "a rescue's card shows blood")
Lay(Helper("tried_to_help"), 176)
Eq(card.blood, nil, "a helper's card has blood")

-- On every watcher's, more the longer they watched: by the stain's area
-- (the pieces' count is no measure, as InkBlot coarsens a large stain).
local function Area(quads)
    local area = 0
    for _, q in ipairs(quads) do
        area = area + math.abs((q[1] * q[4] - q[3] * q[2]) + (q[3] * q[6] - q[5] * q[4]) + (q[5] * q[8] - q[7] * q[6])
            + (q[7] * q[2] - q[1] * q[8])) / 2
    end
    return area
end
local areas = {}
for _, s in ipairs({ 1.2, 3.7, 6.4 }) do
    Lay(Watcher(s), 176, "blood")
    Check(card.blood and card.blood.drawn > 0, s .. " s watched has no blood")
    Eq(Shown(), card.blood.drawn, "the blood's pieces shown")
    areas[#areas + 1] = math.floor(Area(card.blood.stain.levels[1]))
end
Check(areas[1] < areas[2] and areas[2] < areas[3], "more blood the longer they watched: " .. table.concat(areas, ", "))
-- A stain, not crumbs (14 Oct, in the client): watched, at least 250 px²
-- of it (about a 18 px disc), mercilessly half as much again.
Check(areas[2] >= 250 and areas[3] >= 1.5 * areas[2], "the stains are crumbs: " .. table.concat(areas, ", "))

-- Under the writing (the user, 14 Oct: under the text's edge is fine): it
-- may run under the right end of the two lines nearest its corner (at most
-- 45 % of a line and 36 px of it), and there it is the wash alone, lighter.
-- Never under the name, the underlines or the rest of any line; never its
-- core or its rim under a word. Some on the slip, some on the page, none
-- further out than BLOOD.out and a hair.
local B = Card.BLOOD
local ranUnder = 0
for _, key in ipairs({ "a", "b", "c", "d", "e", "f", "g", "h" }) do
    for _, width in ipairs({ 142, 176, 240 }) do
        Lay(Watcher(6.4, { others = 2 }), width, key)
        local W, H = card.box[3], card.box[4]
        local blood = card.blood
        local hard, inked, on, off, far = 0, 0, 0, 0, 0
        local function Into(q, boxes) return Card.Under(q, boxes) end
        for _, piece in ipairs(blood.pieces) do
            do
                local q = piece.q
                if Into(q, blood.hard) then hard = hard + 1 end
                if piece.level > 1 and Into(q, blood.words) then inked = inked + 1 end
                local x, y = (q[1] + q[3] + q[5] + q[7]) / 4, (q[2] + q[4] + q[6] + q[8]) / 4
                if math.abs(x) <= W / 2 and math.abs(y) <= H / 2 then on = on + 1 else off = off + 1 end
                if x > W / 2 + B.out.side + 1 or math.abs(y) > H / 2 + B.out.foot + 1 or x < -W / 2 - 1 then
                    far = far + 1
                end
            end
        end
        local label = " (" .. key .. ", " .. width .. " px)"
        Eq(hard, 0, "blood under the name, an underline or the start of a line" .. label)
        -- The same, worked out here: nothing under the name, nor under any
        -- line but its last 45 % (36 px at most).
        local starts = { card.writing.name }
        for _, l in ipairs(card.writing.lines) do
            starts[#starts + 1] = { l[1], l[2], l[3] - math.min(36, 0.45 * (l[3] - l[1])), l[4] }
        end
        local under = 0
        for _, piece in ipairs(blood.pieces) do
            if Into(piece.q, starts) then under = under + 1 end
        end
        Eq(under, 0, "blood under the start of a line or the name" .. label)
        Eq(inked, 0, "the core or the rim under a word" .. label)
        Check(not Into(blood.stain.levels[1][1] or { 0, 0, 0, 0, 0, 0, 0, 0 }, { card.writing.name }),
            "blood under the name" .. label)
        Check(on > 0 and off > 0, "the blood is not across the slip's edge" .. label .. ": " .. on .. " on, " .. off
            .. " off")
        Eq(far, 0, "blood far past the slip" .. label)
        ranUnder = ranUnder + blood.under
    end
end
Check(ranUnder > 0, "the blood never runs under a line's end")
-- What is drawn under a word is the lighter wash, never the core or rim.
do
    local wrong, seen, light = 0, 0, 0
    for _, t in ipairs(card.stain) do
        if t:IsShown() then
            local c = t.recorded and t.recorded.calls and t.recorded.calls.SetColorTexture
            if c and c[4] then
                seen = seen + 1
                if c[4] == B.under then light = light + 1 end
                if c[4] ~= B.ink[1][4] and c[4] ~= B.ink[2][4] and c[4] ~= B.rimInk[4] and c[4] ~= B.under then
                    wrong = wrong + 1
                end
            end
        end
    end
    Check(seen > 0, "the blood's inks are not recorded")
    Eq(wrong, 0, "blood in another ink")
    Eq(light, card.blood.under, "what lies under a word is not the lighter wash")
end
-- The rule's own sums: the soft end of a line is its last 45 %, 36 px at most.
do
    local hard = Card.Keep({ name = { 0, 0, 40, 10 }, lines = { { 0, 12, 200, 24 }, { 0, 26, 50, 38 },
        { 0, 40, 120, 52 } }, marks = {} }, 104, 1)
    -- The two lines nearest the lower corner are the last two.
    Eq(table.concat({ hard[2][3], hard[3][3], hard[4][3] }, ","), "200,27.5,84", "the hard parts of the lines")
end

-- The same card bleeds the same every time, another card otherwise.
Lay(Watcher(6.4), 176, "same")
local first = card.blood.points
Lay(Watcher(6.4), 176, "same")
local again = card.blood.points
local same = #first == #again
for i = 1, math.min(#first, #again) do
    same = same and first[i].x == again[i].x and first[i].y == again[i].y and first[i].t == again[i].t
end
Check(same, "the same card bled differently")
Lay(Watcher(6.4), 176, "other")
local other = card.blood.points
Check(#other ~= #first or other[1].x ~= first[1].x or other[2].y ~= first[2].y, "another card bled the same")

-- Laid flat: the card square, its blood still there, square with it.
ns.SetSetting("flatSheets", true)
Lay(Watcher(6.4), 176, "same")
Eq(card.turn, 0, "laid flat, the card turns")
Check(card.blood and card.blood.drawn > 0, "laid flat, the blood is gone")
ns.SetSetting("flatSheets", false)
card:Hide()

--------------------------------------------------------------------------
Section("/sd testdata: the witnesses on the plates")

ns.TestData.Write()
ns.UI.ShowJournal()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
local page = ns.UI.JourneyPage()

local function Witnesses()
    local list = {}
    for k = 1, page.witnessPool.used do
        local c = page.witnessPool[k]
        if c:IsShown() then list[#list + 1] = c end
    end
    return list
end
local function Captions()
    local list = {}
    for k = 1, page.captionPool.used do
        local w = page.captionPool[k]
        if w:IsShown() then list[#list + 1] = w:GetText() or "" end
    end
    return list
end
local function Open(i)
    page.open = i
    page.mode = "plates"
    ns.UI.RedrawJourneyPage()
end

-- Every case and every size somewhere: by level (or week), what the card
-- says and the size it took.
local seen, margins = {}, {}
for _, at in ipairs(T.DiaryPages(page)) do
    local e = at.e
    T.OpenDiaryPage(page, at.i, at.k)
    for _, c in ipairs(Witnesses()) do
        seen[#seen + 1] = (e.level or "week") .. ":" .. c.name:GetText() .. ":" .. c:Deed() .. ":" .. c.form
    end
    for _, p in ipairs(page.plates) do
        if p:IsShown() and p.witness then
            local kinds = {}
            for _, it in ipairs(p.margin or {}) do kinds[#kinds + 1] = it.kind end
            margins[#margins + 1] = (e.level or "week") .. ":" .. table.concat(kinds, ",")
            -- No killer card where the witness of a death is, and no close
            -- call's where the rescue's is.
            if p.witness.death then Check(p.killer == nil, "a death's witness beside its killer's card") end
            if p.witness.call then Check(p.foe == nil, "a rescue beside its close call's card") end
        end
    end
end
table.sort(seen)
-- (The cap's weeks fall by the calendar: on this test's day Grisha's
-- oasis has a week's page, or level 16's, to itself, XL; it shared one
-- with the print before it, M, until the pages went by sitting. Brakk's
-- crag shares its sitting's page with the Barrens plate before it, M.)
Eq(table.concat(seen, ", "), "10:Wenna:tried to save you:M, 11:Numa:saved you:L, 13:Corvin:watched you die:L, "
    .. "14:Ilsabet & two others:saw you die:M, week:Brakk:tried to save you:M, week:Grisha:mercilessly watched you die:XL",
    "the made-up witnesses' cards")
-- In the margin where the killer's card would be: after the people and
-- the finds, ahead of the close call's card and the luck.
Check(Any(margins, "^11:person,find,witness,lucky$"), "level 11's margin: " .. table.concat(margins, "; "))
Check(Any(margins, "^14:witness,foe,lucky$"), "level 14's margin: " .. table.concat(margins, "; "))
Check(Any(margins, "^13:find,witness$"), "level 13's margin: " .. table.concat(margins, "; "))
-- (The oasis week's campfire, sat by with Tester, comes last of all: its
-- slip, Features/Campfire/Slip.lua, 14 Oct; the duels with Tester just
-- before it, Features/Duels/Slip.lua, 15 Oct. Since the pages go by
-- sitting, the evening with Tester is a page of its own, and the deaths
-- watched are on others, the witness ahead of the close call's card.)
Check(Any(margins, "^week:witness,foe$"), "the oasis week's margin: " .. table.concat(margins, "; "))
local tester
for _, at in ipairs(T.DiaryPages(page)) do
    T.OpenDiaryPage(page, at.i, at.k)
    for _, p in ipairs(page.plates) do
        if p:IsShown() and at.e.kind == "week" and (p.counts.duels or 0) > 0 then
            local kinds = {}
            for _, it in ipairs(p.margin or {}) do kinds[#kinds + 1] = it.kind end
            tester = table.concat(kinds, ",")
        end
    end
end
Eq(tester, "person,duel,campfire", "the evening with Tester's margin")

-- Level 13: the card's leader goes to the death's cross; the caption says
-- "a death" and leaves the creature and the watcher to the card.
for i, e in ipairs(page.recap.entries) do
    if e.level == 13 then Open(i) end
end
local plate13 = page.plates[1]
local leader
for _, link in ipairs(page.links) do
    if link.strip == Witnesses()[1] then leader = link end
end
Check(leader ~= nil, "the witness card has no leader")
Eq(leader and (leader.mark[1] .. "," .. leader.mark[2]), plate13.witness.mark[1] .. "," .. plate13.witness.mark[2],
    "the leader does not go to the death's cross")
local words = table.concat(Captions(), " | ")
Check(words:find("a death") and not words:find("Kolkar") and not words:find("Corvin"),
    "level 13's words say what the card says: " .. words)
Eq(page.witnessesWritten, 1, "the witness cards written")

-- With no room for the card at all, the words say it: the creature after
-- the death, the witness in a sentence of their own.
local least = {}
for name, form in pairs(Card.FORMS) do least[name], form.least = form.least, 10000 end
ns.UI.RedrawJourneyPage()
Eq(#Witnesses(), 0, "a card with no room is drawn")
words = table.concat(Captions(), " | ")
Check(words:find("a death, to a Kolkar Pack Runner") ~= nil, "the creature is not in the words: " .. words)
Check(words:find("Corvin watched you die.", 1, true) ~= nil, "the witness is not in the words: " .. words)
Eq(page.witnessesWritten, 0, "a card left off was counted")
for name, form in pairs(Card.FORMS) do form.least = least[name] end

-- Short of room for its foe's line, the card gives it up and the words
-- name the creature, not the witness.
local foeLine = Card.WITNESS.foeLine
Card.WITNESS.foeLine = 400
ns.UI.RedrawJourneyPage()
Eq(#Witnesses(), 1, "the card without its foe's line is left off")
Eq(Witnesses()[1] and Witnesses()[1]:Foe(), "", "the card kept its foe's line")
words = table.concat(Captions(), " | ")
Check(words:find("a death, to a Kolkar Pack Runner") ~= nil and not words:find("Corvin"),
    "the creature the card gave up is not in the words, or the witness is: " .. words)
Card.WITNESS.foeLine = foeLine

-- Level 11: the rescue in the close call's place; the caption names no
-- creature (the close call had none) and says "a close call".
for i, e in ipairs(page.recap.entries) do
    if e.level == 11 then Open(i) end
end
Check(page.plates[1].witness and page.plates[1].witness.call ~= nil, "level 11's rescue")
words = table.concat(Captions(), " | ")
Check(not words:find("Numa"), "the rescue is in level 11's words beside its card: " .. words)

ns.TestData.Remove()
Eq(ns.db.characters[ns.Witnesses.STRANGERS.grisha.guid], nil, "the made-up witnesses outlive the test data")
