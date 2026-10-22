-- The party's business cards on the table spread (UI/Dungeon/Cards.lua,
-- step 4): a card for everyone on the run, the user too, told by its
-- holder's race (never printed), with their name, level and class printed
-- and nothing else but a note jotted by hand (UI/Ink/Hand.lua) where one of
-- their facts of the run (Core/DungeonRun.lua's Person) has a baked note;
-- /sd handtest's stand-in note; the way into the diary for a stranger, the
-- way to their page for a diary person, neither for the user; resting in
-- a small stack by the map's bottom-left corner (no strip under it), the
-- page's person's on top, fanned out of it on a click: much bigger, a
-- column bending right as it rises, whole on the screen, shingled only as
-- far as it must, animated out and back one after the other, the same
-- every time; a raid's rest in a deck at the bottom of the stack and the
-- top of the fan, which spreads and gathers.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local J = ns.UI.Journal
local Page = ns.UI.DungeonPage
local CARD, DECK = Page.CARD, Page.DECK

mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local ME = ns.ownGUID
local panel = _G.SocialDiaryJournalFrame

local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 and visit.endedAt > mock.now - 86400 then RFK = visit end
end
Check(RFK, "the test data's Razorfen Kraul of today")

local BROM, ZURI, KAELITH = "Player-0000-7E57E572", "Player-0000-7E57E573", "Player-0000-7E57E571"
local bookAt = { 682.5, 384 }
panel.GetCenter = function() return bookAt[1], bookAt[2] end
UIParent.width, UIParent.height = 1365, 768

local function CardOf(host, guid)
    for _, card in ipairs(host.cards or {}) do
        if card.person.guid == guid then return card end
    end
end
-- Every line written on a card.
local function Written(card)
    local out = {}
    for i = 1, card.texts.used do out[#out + 1] = card.texts[i]:GetText() or "" end
    return table.concat(out, " | ")
end
-- Whether the table's point x, y (y down) lies on `card`.
local function Under(card, x, y)
    local u, v = card.plane.In(x, y)
    return math.abs(u) < CARD.w / 2 and math.abs(v) < CARD.h / 2
end

--------------------------------------------------------------------------
Section("a card for everyone on the run, told by race, in the order they lie")

Eq(Page.CardStyle("Gnome"), "gnome", "a gnome's card")
Eq(Page.CardStyle("Dwarf"), "dwarf", "a dwarf's card")
Eq(Page.CardStyle("NightElf"), "nightelf", "a night elf's card")
Eq(Page.CardStyle("Skyborne"), "skyborne", "a Skyborne's card")
Eq(Page.CardStyle("Human"), "human", "a human's card")
Eq(Page.CardStyle("Orc"), "plain", "an orc's card")
Eq(Page.CardStyle(nil), "plain", "a card for someone whose race was never seen")
Eq(Page.CardStyle(""), "plain", "a card for an empty race")
for key, style in pairs(Page.STYLES) do
    Check(type(style.art) == "table", "no art slots for the " .. key .. " card")
end

ns.UI.ShowJournal(G)
Eq(ns.UI.OpenVisit(RFK.id, G), true, "the run did not come out")
local host = Page.Spread()
local map = host.map
Eq(#host.cards, 5, "a card each for Tester, the user, Brom, Kaelith and Zuri")
Eq(host.cards[1].person.guid, G, "the page's own person not on top")
Eq(host.cards[2].person.guid, ME, "the user not next")
for i = 3, 5 do Check(not host.cards[i].person.inDiary, "a stranger before a diary person") end
local styles = {}
for _, card in ipairs(host.cards) do styles[card.person.guid] = card.style end
Eq(styles[BROM], "dwarf", "Brom's card")
Eq(styles[ZURI], "gnome", "Zuri's card")
Eq(styles[KAELITH], "nightelf", "Kaelith's card")
Eq(styles[G], "plain", "Tester's (an orc's) card")
Eq(styles[ME], "plain", "the user's (a tauren's) card")
Eq(CardOf(host, ME).person.race, "Tauren", "the user's race not the client's")

-- Name, level and class; never the race.
local RACE_WORDS = { "Dwarf", "Gnome", "Night", "Elf", "Orc", "Tauren", "Human", "Troll", "Undead", "Scourge" }
for _, card in ipairs(host.cards) do
    local text = Written(card)
    for _, word in ipairs(RACE_WORDS) do
        Check(not text:find(word), "a race on " .. card.person.first .. "'s card: " .. text)
    end
    Check(text:find("Level %d+"), "no level on " .. card.person.first .. "'s card: " .. text)
end
Check(Written(CardOf(host, BROM)):find("Warrior"), "no class on Brom's card")
Check(Written(CardOf(host, KAELITH)):find("Kaelith Dawnsong", 1, true), "Kaelith's name not first and surname, as written")
Check(CardOf(host, BROM).nameWords:find("BROM IRONHIDE", 1, true), "a dwarf's name set wide on its parchment")
Check(Written(CardOf(host, ZURI)):find("%d%d%d%d%-G"), "no employee number on the gnome's badge")
Check(not Written(CardOf(host, ZURI)):find("No.", 1, true), "the badge's number printed with a No.")

--------------------------------------------------------------------------
Section("printed: the name and the class; the rest a note jotted by hand")

-- What a card prints: its name and its level and class; a gnome's its
-- employee number too. No fact typed.
local PRINTED = { plain = 2, dwarf = 2, nightelf = 2, gnome = 3 }
for _, card in ipairs(host.cards) do
    local want = PRINTED[card.style]
    Eq(card.texts.used, want, card.person.first .. "'s card prints more than its name and class: " .. Written(card))
    for _, f in ipairs(card.person.facts) do
        local said = Page.Words.Fact(f, card.person.visit)
        Check(not said or not Written(card):find(said, 1, true), "a fact typed on " .. card.person.first .. "'s card")
    end
end
-- Zuri snagged the band from the user (the test data): her card has the
-- note, on a slip under her badge (no room for ink between its printed
-- fields), its item's tooltip over it; Brom's run (died twice, rolled a
-- 2) has no baked note, so his card has none.
local Hand = ns.UI.Hand
Check(Hand.Note("snagged"), "no baked note for a snagged item")
Eq(Page.JOTS.snagged, "snagged", "a snagged fact's note")
-- The middle of each design's level and class line (10 pt): a note keeps
-- under it.
local WHO = { plain = 36 }
local function JotInside(card, label)
    local jot = card.jot
    Check(jot and jot.pieces > 40, label .. ": no note drawn")
    if not (jot and jot.box) then return end
    -- A dwarf's and a gnome's on a slip, under the card's foot (the dwarf's
    -- section).
    if Page.STYLES[card.style].slip then
        Check(jot.slip and jot.box[2] >= CARD.h + Page.SLIP.top - 1, label .. ": the note not on a slip under the card")
        return
    end
    -- A ruled card's on the stock above its name (the ruled cards'
    -- sections).
    if Page.STYLES[card.style].lines then
        local A, b = Page.STYLES[card.style].jot, jot.box
        Check(b[1] >= 0.05 * CARD.w and b[3] <= A.right * CARD.w + 1 and b[4] <= A.foot * CARD.h + 1,
            ("%s: the note past its room (%.1f,%.1f..%.1f,%.1f)"):format(label, b[1], b[2], b[3], b[4]))
        Check(jot.size >= 5.5 and jot.size <= CARD.jot.size, label .. ": the note's size " .. jot.size)
        return
    end
    local b = jot.box
    local right = CARD.w
    Check(b[1] >= 4 and b[3] <= right - CARD.jot.room + 1, ("%s: the note past the card's sides (%.1f..%.1f)"):format(
        label, b[1], b[3]))
    Check(b[2] >= WHO[card.style] + 4.5 and b[4] <= CARD.h - CARD.jot.room + 1, ("%s: the note past the body (%.1f..%.1f)"):format(
        label, b[2], b[4]))
    Check(jot.size >= 7 and jot.size <= CARD.jot.size, label .. ": the note's size " .. jot.size)
end
local zuri0 = CardOf(host, ZURI)
Eq(zuri0.jot and zuri0.jot.key, "snagged", "Zuri's card has no note of the band she snagged")
Eq(zuri0.jot and zuri0.jot.fact.kind, "snagged", "Zuri's note not of her snagged fact")
JotInside(zuri0, "Zuri's card")
Eq(zuri0.hovers.used, 1, "no tooltip over Zuri's note")
local hover = zuri0.hovers[1]
Eq(hover.item, zuri0.jot.fact.item, "the note's tooltip not its item's")
hover.scripts.OnEnter(hover)
Eq(GameTooltip.link, zuri0.jot.fact.item, "the item's tooltip not shown over the note")
hover.scripts.OnLeave(hover)
-- The tooltip's box round the note's ink, on the table.
local hx0, hy0, hx1, hy1 = zuri0:Box(zuri0.jot.box[1], zuri0.jot.box[2], zuri0.jot.box[3] - zuri0.jot.box[1],
    zuri0.jot.box[4] - zuri0.jot.box[2])
Check(math.abs(hover.recorded.width - (hx1 - hx0)) < 0.01 and math.abs(hover.recorded.height - (hy1 - hy0)) < 0.01,
    "the tooltip's box not the note's")
-- Drawn as the pen's quads on the card's own textures (on its slip, under
-- the card's art).
local inked = 0
for i = 1, zuri0.textures.used do
    local t = zuri0.textures[i]
    if t:IsShown() and t.recorded.layer == "BACKGROUND" and t.recorded.sublevel == -5 then inked = inked + 1 end
end
Check(inked >= zuri0.jot.pieces, ("the note's pieces not on the card (%d of %d)"):format(inked, zuri0.jot.pieces))
for _, guid in ipairs({ BROM, KAELITH, G, ME }) do
    local card = CardOf(host, guid)
    Eq(card.jot, nil, card.person.first .. "'s card has a note with no baked note for it")
    Eq(card.hovers.used, 0, card.person.first .. "'s card has a tooltip without a note")
end
-- The note comes from the first of a person's facts that has one, past
-- the ones that do not; on every design, inside its body; seeded, so the
-- same card is jotted the same way every time.
local Person = ns.DungeonRun.Person
local LONG = "|cnIQ3:|Hitem:990002::::::::16:1491::::::::|h[Invented Leggings of the Very Long Name]|h|r"
ns.DungeonRun.Person = function()
    return { { kind = "rolled", roll = 1 }, { kind = "late" }, { kind = "snagged", item = LONG }, { kind = "early" } }
end
ns.UI.OpenVisit(RFK.id, G)
ns.UI.OpenVisit(RFK.id, G)
local seen = {}
for _, card in ipairs(host.cards) do
    Eq(card.jot and card.jot.fact.kind, "snagged", card.person.first .. "'s note not of the snagged fact")
    JotInside(card, card.style .. " card")
    Check(card.hovers.used == 1 and card.hovers[1].item:find("Very Long Name", 1, true), "the item's tooltip")
    seen[card.style] = true
    local box = { unpack(card.jot.box) }
    card:Draw()
    for k = 1, 4 do Eq(card.jot.box[k], box[k], card.person.first .. "'s note moved when drawn again") end
end
Check(seen.gnome and seen.dwarf and seen.nightelf and seen.plain, "a design not tried")
-- A gnome's badge stamped keeps its note where it was.
local zg = CardOf(host, ZURI)
local before = { unpack(zg.jot.box) }
zg.person.inDiary = true
zg:Draw()
Check(zg.stamped, "Zuri's badge not stamped")
for k = 1, 4 do Eq(zg.jot.box[k], before[k], "the note moved as the badge was stamped") end
zg.person.inDiary = false
zg:Draw()
-- Flat paper only: the card lies straight, the note is still turned up.
zg.flat = true
zg:Draw()
JotInside(zg, "a flat gnome card")
zg.flat = false
-- Two people are jotted two ways.
local a, b = host.cards[3].jot.box, host.cards[4].jot.box
Check(a[1] ~= b[1] or a[2] ~= b[2], "two cards jotted the same way")
ns.DungeonRun.Person = Person
ns.UI.OpenVisit(RFK.id, G)
ns.UI.OpenVisit(RFK.id, G)

--------------------------------------------------------------------------
Section("a dwarf's card: the user's art, its two slots, a note on a slip, the seal over a bracket")

do
    local D = Page.STYLES.dwarf
    local ART = "Interface\\AddOns\\social_diary\\Art\\Cards\\dwarf"
    Eq(D.art.stock, ART, "the dwarf's art")
    -- The placeholders are gone: no iron band, gold, soot or ale.
    for _, key in ipairs({ "iron", "gold", "soot", "ale", "stamp", "jot" }) do
        Eq(D[key], nil, "the dwarf's placeholder " .. key .. " still in its style")
    end
    Check(math.abs(CARD.w / CARD.h - 1.7832) < 0.01, "the card not the art's shape: " .. CARD.w / CARD.h)
    local brom0 = CardOf(host, BROM)
    -- The art, its part of the canvas, turned and bent with the card; its
    -- shadow the same art in ink; nothing else on the stone's layer.
    local arts, shadow = 0, 0
    for i = 1, brom0.textures.used do
        local t = brom0.textures[i]
        local c = t.recorded.calls
        if t.recorded.layer == "BORDER" then
            local tex = c.SetTexture
            Check(tex and tex[1] == ART and (not c.SetColorTexture or tex.seq > c.SetColorTexture.seq),
                "a placeholder drawn on the dwarf's stone")
            Eq(c.SetTexCoord[2], 0.8916, "the art's right edge in the canvas")
            Check(c.SetTexCoord[1] == 0 and c.SetTexCoord[3] == 0 and c.SetTexCoord[4] == 1, "the art's texcoords")
            Check(t.bent, "the art not bent with the card")
            arts = arts + 1
            local v = c.SetVertexColor
            if v and v.seq > tex.seq and v[1] < 0.5 then shadow = shadow + 1 end
        end
    end
    Eq(arts, 2 + ns.UI.Light.CAST.layers, "the dwarf's art, its light and its shadow")
    Eq(shadow, ns.UI.Light.CAST.layers, "the dwarf's shadow not the art in ink")

    -- A font string's box on the card, from its top left: x0, y0, x1, y1.
    local function BoxOf(card, fs)
        local pt = fs.recorded.points[1]
        local X, Y = pt.args[3], pt.args[4]
        local c, sn = math.cos(card.turn), math.sin(card.turn)
        local lx, ly = X * c + Y * sn, X * sn - Y * c
        local w = fs.recorded.width
        return lx + CARD.w / 2 - w / 2, ly + CARD.h / 2, lx + CARD.w / 2 + w / 2
    end
    local function InSlot(card, fs, slot, size, label, inset)
        local x0, my, x1 = BoxOf(card, fs)
        local sx0, sy0, sx1, sy1 = slot[1] * CARD.w, slot[2] * CARD.h, slot[3] * CARD.w, slot[4] * CARD.h
        Check(x0 >= sx0 + inset - 1 and x1 <= sx1 - inset + 1, ("%s past its slot's sides: %.1f..%.1f in %.1f..%.1f")
            :format(label, x0, x1, sx0, sx1))
        Check(math.abs(my - (sy0 + sy1) / 2) < 0.5, label .. " not in its slot's middle: " .. my)
        Check(size <= sy1 - sy0, label .. " taller than its slot: " .. size)
        Check(math.abs((x0 + x1) / 2 - (sx0 + sx1) / 2) < 0.5, label .. " not centred in its slot")
    end
    InSlot(brom0, brom0.nameText, D.slots.name, brom0.nameSize, "Brom's name", D.inset)
    InSlot(brom0, brom0.whoText, D.slots.who, brom0.whoSize, "Brom's level and class", D.who.inset)
    Eq(brom0.whoText:GetText(), "Level 22 Warrior", "Brom's level and class")
    Eq(brom0.nameText.recorded.calls.SetTextColor and brom0.nameText.recorded.calls.SetTextColor[1],
        Style and Style.INK_STRONG[1] or ns.Style.INK_STRONG[1], "the name not in ink on the parchment")
    -- A long name and class: fitted smaller, then cut short, in the slots.
    local long = { guid = BROM, first = "Brunhildegarde", surname = "Thunderbrewmantle", race = "Dwarf",
        classToken = "PALADIN", class = "Paladin", level = 60, facts = {}, inDiary = false }
    local was = brom0.person
    brom0.person = long
    brom0:Draw()
    InSlot(brom0, brom0.nameText, D.slots.name, brom0.nameSize, "a long name", D.inset)
    InSlot(brom0, brom0.whoText, D.slots.who, brom0.whoSize, "a long class", D.who.inset)
    Check(brom0.nameSize >= D.name.least and brom0.whoSize >= D.who.least, "a long name fitted too small")
    brom0.person = was
    brom0:Draw()

    -- The seal's place: in the top band, over the top right bracket, clear
    -- of the slots and the medallion.
    local E = D.seal
    local sx, sy, reach = E.x * CARD.w, E.y * CARD.h, E.r * 1.25
    Check(sy + reach <= D.slots.name[2] * CARD.h, "the seal reaches the name slot")
    Check(sx - reach >= D.slots.name[3] * CARD.w or sy + reach <= D.slots.name[2] * CARD.h, "the seal on the name slot")
    local M = D.medallion
    Check(math.sqrt((sx - M[1] * CARD.w) ^ 2 + (sy - M[2] * CARD.h) ^ 2) > reach + M[3] * CARD.w,
        "the seal on the medallion")
    Check(sx + E.r <= CARD.w + 1 and sy - E.r >= -1, "the seal off the card")
    Check(sx >= 0.89 * CARD.w and sy <= 0.19 * CARD.h, "the seal not over the top right bracket")
    -- Before: a chalk ring; added: the wax.
    local function Pieces(card, sub)
        local n = 0
        for i = 1, card.textures.used do
            local t = card.textures[i]
            if t.recorded.layer == "ARTWORK" and t.recorded.sublevel == sub then n = n + 1 end
        end
        return n
    end
    Check(not brom0.stamped and Pieces(brom0, 5) > 0 and Pieces(brom0, 7) == 0, "no chalk ring for the seal to come")
    Check(brom0.add.offer and brom0.add.box, "no way into the diary on Brom's card")
    brom0.person.inDiary = true
    brom0:Draw()
    Check(brom0.stamped and Pieces(brom0, 7) == 1, "the seal not pressed")
    brom0.person.inDiary = false
    brom0:Draw()

    -- A note on a slip under the foot: past the card, on the slip's paper,
    -- the size of the hand.
    local Person0 = ns.DungeonRun.Person
    ns.DungeonRun.Person = function(visit, guid)
        local f = Person0(visit, guid)
        if guid == BROM then table.insert(f, 1, { kind = "snagged", item = LONG }) end
        return f
    end
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    local b = CardOf(host, BROM)
    local slip = b.jot and b.jot.slip
    Check(slip, "no slip under Brom's card")
    if slip then
        local box = b.jot.box
        Check(box[2] >= CARD.h + 1, ("the note on the stone: its top at %.1f"):format(box[2]))
        Check(box[1] >= 2 and box[3] <= CARD.w - 2, "the note past the card's sides")
        local c, sn = math.cos(slip.turn), math.sin(slip.turn)
        for _, q in ipairs({ { box[1], box[2] }, { box[3], box[2] }, { box[3], box[4] }, { box[1], box[4] } }) do
            local dx, dy = q[1] - slip.cx, q[2] - slip.cy
            local u, v = dx * c - dy * sn, dx * sn + dy * c
            Check(math.abs(u) <= slip.w / 2 + 1 and math.abs(v) <= slip.h / 2 + 1, "the note off its slip")
        end
        Check(slip.cy - slip.h / 2 < CARD.h - 2, "the slip not tucked under the card")
        Check(b.jot.size >= Page.SLIP.least, "the note too small: " .. b.jot.size)
        Eq(slip.lead, 0, "the note not on one line")
        Check(math.abs(Page.CardTail(b.person) - slip.tail) < 1e-9 and slip.tail > 10, "the slip's tail")
        Eq(b.hovers.used, 1, "no tooltip over the slip's note")
        Eq(b.hovers[1].item, LONG, "the slip's tooltip not its item's")
        -- The slip under the card's stone, its ink over its paper.
        local paper, ink = 0, 0
        for i = 1, b.textures.used do
            local t = b.textures[i]
            if t.recorded.layer == "BACKGROUND" and t.recorded.sublevel == -7 then paper = paper + 1 end
            if t.recorded.layer == "BACKGROUND" and t.recorded.sublevel == -5 then ink = ink + 1 end
        end
        Check(paper == 1 and ink >= b.jot.pieces, "the slip's paper and ink")
    end
    -- Beside another card, its name slot and its seal clear of it.
    local i
    for k, card in ipairs(host.cards) do if card == b then i = k end end
    Check(i and i > 1, "Brom's card in front")
    -- (Fanned: the card under it in the column lies over its foot.)
    Page.Fan(host, true, true)
    local front = host.cards[i - 1]
    local N = D.slots.name
    for fx = N[1], N[3] + 1e-9, (N[3] - N[1]) / 8 do
        for _, fy in ipairs({ (N[2] + N[4]) / 2, N[4] - 0.01 }) do
            local x, y = b.plane.Out(fx * CARD.w - CARD.w / 2, fy * CARD.h - CARD.h / 2)
            Check(not Under(front, x, y), ("Brom's name slot under the card in front at %.2f,%.2f"):format(fx, fy))
        end
    end
    local ab = b.add.box
    for _, q in ipairs({ { ab[1], ab[2] }, { ab[3], ab[2] }, { ab[3], ab[4] }, { ab[1], ab[4] } }) do
        Check(not Under(front, q[1], q[2]), "Brom's seal under the card in front")
    end
    -- Brom first: on top of the stack, lowest in the fan; fanned, his
    -- slip on the screen; no strip under the stack.
    local Party = Page.Party
    Page.Party = function(visit, page)
        local list = Party(visit, page)
        for k, p in ipairs(list) do
            if p.guid == BROM then table.insert(list, 1, table.remove(list, k)) break end
        end
        return list
    end
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    local fb = host.cards[1]
    Eq(fb.person.guid, BROM, "Brom not first")
    local keep = map.stack.keep
    for _, e in ipairs(map.noteStrips) do
        local sb = e.box
        Check(sb[3] <= keep[1] or sb[1] >= keep[3] or sb[4] <= keep[2] or sb[2] >= keep[4], "a strip under the stack")
    end
    Page.Fan(host, true, true)
    local k = host:GetScale()
    local fs = fb.jot.slip
    for _, q in ipairs({ { -1, 1 }, { 1, 1 } }) do
        local c, sn = math.cos(fs.turn), math.sin(fs.turn)
        local u, v = q[1] * fs.w / 2, q[2] * fs.h / 2
        local px, py = fs.cx + u * c + v * sn, fs.cy - u * sn + v * c
        local _, y = fb.plane.Out(px - CARD.w / 2, py - CARD.h / 2)
        local sy = UIParent:GetHeight() / 2 + (map.lie[2] - y * fb.scaleK) * k
        Check(sy >= 0, "the first card's slip off the screen's foot")
    end
    Page.Party = Party
    ns.DungeonRun.Person = Person0
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
end

--------------------------------------------------------------------------
-- The ruled cards (a night elf's, a Skyborne's): the user's art, the name
-- and the level and class written on its rules, a note on the open stock
-- above the name, the design's own way into the diary in its top band.
-- `D`: { key, race, label, mark (the way in's word), flag (the card's
-- field once added), Before(card), After(card), Flat(card), OnArt (the
-- mark lies over the art: its box holds `at`, else it keeps off the art) }.
-- Kaelith is the card: a Skyborne's by a stand-in race (no test member is
-- one).
local function RuledCard(D)
    local E = Page.STYLES[D.key]
    local ART = "Interface\\AddOns\\social_diary\\Art\\Cards\\" .. D.key
    local Party = Page.Party
    Page.Party = function(visit, page)
        local list = Party(visit, page)
        for _, p in ipairs(list) do if p.guid == KAELITH then p.race = D.race end end
        return list
    end
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    Eq(Page.CardStyle(D.race), D.key, D.label .. "'s card")
    Eq(E.art.stock, ART, D.label .. "'s art")
    -- Nothing drawn in code for the design: no rule, laid lines, box, cog,
    -- slots or seal.
    for _, key in ipairs({ "rule", "laid", "box", "cog", "grid", "slots", "seal", "medallion" }) do
        Eq(E[key], nil, "a placeholder " .. key .. " in " .. D.label .. "'s style")
    end
    Check(math.abs(CARD.w / CARD.h - 1.7773) < 0.01, "the card not the art's shape: " .. CARD.w / CARD.h)
    local kae = CardOf(host, KAELITH)
    Eq(kae.style, D.key, "Kaelith's card")
    -- The art, its part of the canvas, turned and bent with the card; its
    -- shadow the same art in ink; nothing else on the card's own layers.
    local arts, shadow = 0, 0
    for i = 1, kae.textures.used do
        local t = kae.textures[i]
        local c = t.recorded.calls
        Check(t.recorded.layer ~= "BACKGROUND", "a stock drawn in code under " .. D.label .. "'s art")
        if t.recorded.layer == "BORDER" then
            local tex = c.SetTexture
            Check(tex and tex[1] == ART and (not c.SetColorTexture or tex.seq > c.SetColorTexture.seq),
                "a placeholder drawn on " .. D.label .. "'s card")
            Check(c.SetTexCoord[1] == 0 and c.SetTexCoord[2] == 0.8887 and c.SetTexCoord[3] == 0
                and c.SetTexCoord[4] == 1, "the art's texcoords")
            Check(t.bent, "the art not bent with the card")
            arts = arts + 1
            local v = c.SetVertexColor
            if v and v.seq > tex.seq and v[1] < 0.5 then shadow = shadow + 1 end
        end
    end
    Eq(arts, 2 + ns.UI.Light.CAST.layers, D.label .. "'s art, its light and its shadow")
    Eq(shadow, ns.UI.Light.CAST.layers, D.label .. "'s shadow not the art in ink")

    -- Boxes on the card, from its top left (x0, y0, x1, y1), and whether
    -- one is clear of another and of all the art the writing keeps off.
    local function Clear(a, b) return a[3] <= b[1] or a[1] >= b[3] or a[4] <= b[2] or a[2] >= b[4] end
    local function Frac(b) return { b[1] * CARD.w, b[2] * CARD.h, b[3] * CARD.w, b[4] * CARD.h } end
    local function OffArt(box, label)
        for _, v in ipairs(E.keep) do
            Check(Clear(box, Frac(v)), ("%s on the art at %.2f,%.2f (%.1f,%.1f..%.1f,%.1f)"):format(label, v[1], v[2],
                unpack(box)))
        end
        -- Inside the frame.
        Check(box[1] >= 0.04 * CARD.w and box[3] <= 0.96 * CARD.w and box[2] >= 0.068 * CARD.h
            and box[4] <= 0.93 * CARD.h, label .. " on the frame")
    end
    -- A line of writing's box on the card: from its left to its right, from
    -- its tallest letter to its tails (its middle and size), and its middle.
    local function Writing(card, fs, size)
        local pt = fs.recorded.points[1]
        local X, Y = pt.args[3], pt.args[4]
        local c, sn = math.cos(card.turn), math.sin(card.turn)
        local lx, ly = X * c + Y * sn, X * sn - Y * c
        local w = fs.recorded.width
        local x0, my = lx + CARD.w / 2 - w / 2, ly + CARD.h / 2
        return { x0, my - 0.5 * size, x0 + w, my + 0.6 * size }, my
    end
    -- On its rule: begun `inset` in from its left end (or centred on it,
    -- where the design's rules are), sitting on it (its middle `sit` of its
    -- size above), no further than its reach.
    local function OnLine(card, fs, size, line, F, label)
        local box, my = Writing(card, fs, size)
        if E.centre then
            Check(math.abs((box[1] + box[3]) / 2 - (line[1] + line[2]) / 2 * CARD.w) < 0.5,
                label .. " not centred on its rule")
            Check(box[1] >= F.reach[1] * CARD.w - 0.5 and box[3] <= F.reach[2] * CARD.w + 0.5,
                ("%s past its reach: %.1f..%.1f"):format(label, box[1], box[3]))
        else
            Check(math.abs(box[1] - (line[1] * CARD.w + E.inset)) < 0.5, label .. " not begun at its rule's left end")
            Check(box[3] <= F.reach * CARD.w + 0.5, ("%s past its reach: %.1f"):format(label, box[3]))
        end
        Check(math.abs(my - (line[3] * CARD.h - F.sit * size)) < 0.5,
            ("%s not sitting on its rule: its middle at %.2f"):format(label, my))
        Check(size >= F.least and size <= F.size, label .. "'s size " .. size)
        Eq(fs.recorded.calls.SetFont[1], F.font, label .. " not in the design's type")
        local c = fs.recorded.calls.SetTextColor
        Check(c[1] == E.ink[1] and c[2] == E.ink[2] and c[3] == E.ink[3], label .. " not in the holder's ink")
        OffArt(box, label)
        return box
    end
    local nameBox = OnLine(kae, kae.nameText, kae.nameSize, E.lines.name, E.name, "Kaelith's name")
    local whoBox = OnLine(kae, kae.whoText, kae.whoSize, E.lines.who, E.who, "Kaelith's level and class")
    Eq(kae.nameText:GetText(), E.name.caps == false and "Kaelith Dawnsong" or "KAELITH DAWNSONG",
        "Kaelith's name not as the design sets it")
    Eq(kae.whoText:GetText(), "Level 22 Druid", "Kaelith's level and class")
    Check(Clear(nameBox, whoBox), "the name on the level and class")
    -- A long name and class: smaller, then cut short at their reach.
    local was = kae.person
    kae.person = { guid = KAELITH, first = "Shalendrielle", surname = "Moonwhisperbough", race = D.race,
        classToken = "DRUID", class = "Druid", level = 60, facts = {}, inDiary = false }
    kae:Draw()
    OnLine(kae, kae.nameText, kae.nameSize, E.lines.name, E.name, "a long name")
    OnLine(kae, kae.whoText, kae.whoSize, E.lines.who, E.who, "a long class")
    Eq(kae.nameSize, E.name.least, "a long name not fitted down to its least")
    kae.person = was
    kae:Draw()

    -- The way in's place: in the top band, clear of the writing; on the art
    -- where it is the art's own (a gem), else clear of it.
    local ab = kae.add.box
    Check(kae.add.offer and ab, "no way into the diary on Kaelith's card")
    local mark
    do
        local u0, v0, u1, v1 = math.huge, math.huge, -math.huge, -math.huge
        for _, q in ipairs({ { ab[1], ab[2] }, { ab[3], ab[2] }, { ab[3], ab[4] }, { ab[1], ab[4] } }) do
            local u, v = kae.plane.In(q[1], q[2])
            u0, v0, u1, v1 = math.min(u0, u), math.min(v0, v), math.max(u1, u), math.max(v1, v)
        end
        mark = { u0 + CARD.w / 2, v0 + CARD.h / 2, u1 + CARD.w / 2, v1 + CARD.h / 2 }
        -- On the card itself, not its box on the turned table.
        local w_ = kae.way
        if w_ then mark = { w_.x, w_.y, w_.x + w_.w, w_.y + w_.h } end
    end
    Check(mark[4] <= nameBox[2], "the " .. D.mark .. " not above the name, in the top band")
    Check(mark[3] - mark[1] >= 12 and mark[4] - mark[2] >= 12, "the " .. D.mark .. " too small to click")
    Check(Clear(mark, nameBox) and Clear(mark, whoBox), "the " .. D.mark .. " on the writing")
    if D.OnArt then
        Check(mark[1] < D.OnArt[1] * CARD.w and mark[3] > D.OnArt[1] * CARD.w and mark[2] < D.OnArt[2] * CARD.h
            and mark[4] > D.OnArt[2] * CARD.h, "the " .. D.mark .. " not on its art")
    else
        OffArt({ mark[1] + 2.5, mark[2] + 2.5, mark[3] - 2.5, mark[4] - 2.5 }, "the " .. D.mark)
    end
    -- Before, and once added; the same every time; flat paper only.
    Check(not kae[D.flag] and D.Before(kae), "no " .. D.mark .. " to come")
    kae.person.inDiary = true
    kae:Draw()
    Check(kae[D.flag] and D.After(kae), "the " .. D.mark .. " not shown added")
    Check(not kae.add.offer, "the way in offered once added")
    local first = kae.add.box[1]
    kae:Draw()
    Eq(kae.add.box[1], first, "the " .. D.mark .. " moved when drawn again")
    kae.flat = true
    kae:Draw()
    Check(kae[D.flag] and D.Flat(kae), "no flat " .. D.mark .. " added")
    kae.flat = false
    kae.person.inDiary = false
    kae:Draw()
    Check(D.Before(kae), "the " .. D.mark .. " not as it was before")

    -- A note: on the stock above the name, clear of the art, the name and
    -- the way in, on one line.
    local Person0 = ns.DungeonRun.Person
    ns.DungeonRun.Person = function(visit, guid)
        local f = Person0(visit, guid)
        if guid == KAELITH then table.insert(f, 1, { kind = "snagged", item = LONG }) end
        return f
    end
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    local k = CardOf(host, KAELITH)
    local jot = k.jot
    Check(jot and jot.pieces > 40, "no note on Kaelith's card")
    if E.slip then
        -- On a slip under the card's foot, at the hand's own size.
        Check(jot.slip and jot.box[2] >= CARD.h + 1 and jot.size >= Page.SLIP.least, "the note not on a slip")
        Eq(k.hovers.used, 1, "no tooltip over Kaelith's note")
    else
        local jb = jot.box
        if E.rays then
            -- Its two lines unlike in length: each piece of ink clear of the art
            -- and the light, not the box round them.
            for i = 1, k.textures.used do
                local t = k.textures[i]
                if t:IsShown() and t.recorded.layer == "ARTWORK" and t.recorded.sublevel == 3 then
                    local pt = t.recorded.points[1]
                    local X, Y = pt.args[3], pt.args[4]
                    local c, sn = math.cos(k.turn), math.sin(k.turn)
                    local x, y = X * c + Y * sn + CARD.w / 2, X * sn - Y * c + CARD.h / 2
                    for _, v in ipairs(E.keep) do Check(Clear({ x, y, x, y }, Frac(v)), "the note's ink on the art") end
                    for _, v in ipairs(E.rays) do Check(Clear({ x, y, x, y }, Frac(v)), "the note's ink in the light") end
                end
            end
            Check(jb[2] >= E.jot.top * CARD.h - 1 and jb[1] >= 0.04 * CARD.w, "the note off the top of the wall")
        else
            OffArt(jb, "the note")
        end
        Check(jb[4] <= nameBox[2], ("the note on the name: its foot at %.1f, the name's top at %.1f"):format(jb[4], nameBox[2]))
        Check(Clear(jb, mark), ("the note on the %s: %.1f,%.1f..%.1f,%.1f / %.1f,%.1f..%.1f,%.1f turn %.3f"):format(D.mark, jb[1], jb[2], jb[3], jb[4], mark[1], mark[2], mark[3], mark[4], k.turn))
        Check(jot.size >= D.least, ("the note too small: %.2f"):format(jot.size))
        if E.jot.one then
            Check(jb[4] - jb[2] < 2.9 * jot.size, "the note not on one line")
        else
            Check(jb[4] - jb[2] > 3.5 * jot.size, "the note not on its two lines")
        end
        Eq(k.hovers.used, 1, "no tooltip over Kaelith's note")
        local inked = 0
        for i = 1, k.textures.used do
            local t = k.textures[i]
            if t:IsShown() and t.recorded.layer == "ARTWORK" and t.recorded.sublevel == 3 then inked = inked + 1 end
        end
        Check(inked >= jot.pieces, "the note's pieces not on the card")
    end

    -- Beside another card: the name and its tails and the way in clear of
    -- it.
    local i
    for n, card in ipairs(host.cards) do if card == k then i = n end end
    Check(i and i > 1, "Kaelith's card in front")
    -- (Fanned: the card under it in the column lies over its foot.)
    Page.Fan(host, true, true)
    local front = host.cards[i - 1]
    local nb = Writing(k, k.nameText, k.nameSize)
    for fx = nb[1], nb[3] + 1e-9, (nb[3] - nb[1]) / 8 do
        for _, fy in ipairs({ nb[2], E.lines.name[3] * CARD.h, nb[4] }) do
            local x, y = k.plane.Out(fx - CARD.w / 2, fy - CARD.h / 2)
            Check(not Under(front, x, y), ("Kaelith's name under the card in front at %.1f,%.1f"):format(fx, fy))
        end
    end
    local b = k.add.box
    for _, q in ipairs({ { b[1], b[2] }, { b[3], b[2] }, { b[3], b[4] }, { b[1], b[4] } }) do
        Check(not Under(front, q[1], q[2]), "Kaelith's " .. D.mark .. " under the card in front")
    end
    ns.DungeonRun.Person = Person0
    Page.Party = Party
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    return kae
end

-- How many of a card's textures are shown on ARTWORK at `sub`, and with
-- what added (a blend mode) where asked.
local function Pieces(card, sub, blend)
    local n = 0
    for i = 1, card.textures.used do
        local t = card.textures[i]
        if t:IsShown() and t.recorded.layer == "ARTWORK" and t.recorded.sublevel == sub then
            local b = t.recorded.calls.SetBlendMode
            if not blend or (b and b[1] == blend) then n = n + 1 end
        end
    end
    return n
end

--------------------------------------------------------------------------
Section("a night elf's card: the user's art, written on its lines, a note above, a leaf pressed")

RuledCard({ key = "nightelf", race = "NightElf", label = "the night elf", mark = "leaf", flag = "pressed", least = 5.5,
    -- Before: its outline in pencil, no leaf; added: the leaf, pressed; flat,
    -- a disc with its veins on it.
    Before = function(c) return Pieces(c, 4) > 10 and Pieces(c, 6) == 0 end,
    After = function(c) return Pieces(c, 6) >= 10 and Pieces(c, 7) >= 10 and Pieces(c, 4) == 0 end,
    Flat = function(c) return Pieces(c, 6) == 1 and Pieces(c, 7) >= 10 end })

--------------------------------------------------------------------------
Section("a Skyborne's card: the user's art, written on its lines, a note above, its gem kindled")

do
    local S = Page.STYLES.skyborne
    -- The gem's light over the art: before, a pencilled ring round it and
    -- no light; added, the light round its setting, its own light added,
    -- the glint; never a texture over the art's gem but these.
    local function Before(c) return Pieces(c, 4) >= S.gem.pencil.dashes * 5 and Pieces(c, 5) == 0 and Pieces(c, 6) == 0 end
    local function After(c)
        return Pieces(c, 4) == 0 and Pieces(c, 5) == S.gem.halo and Pieces(c, 6, "ADD") == 1 and Pieces(c, 7) == 5
    end
    local kae = RuledCard({ key = "skyborne", race = "Skyborne", label = "the Skyborne", mark = "gem", flag = "lit",
        least = 5.0, OnArt = { S.gem.x, S.gem.y }, Before = Before, After = After, Flat = After })
    -- The light stays on the card.
    local gx, gy = S.gem.x * CARD.w, S.gem.y * CARD.h
    Check(gx - S.gem.r >= 0 and gy - S.gem.r >= 0, "the gem's light past the card's edge")
    -- The ink: a cool dark, far darker than the marble.
    local lum = 0.3 * S.ink[1] + 0.59 * S.ink[2] + 0.11 * S.ink[3]
    Check(lum < 0.25 and S.ink[3] > S.ink[1], "the Skyborne's ink not a dark storm grey")
    -- A texture added once (the gem's light) blends as usual when the pool
    -- hands it out again.
    for i = 1, kae.textures.used do
        local t = kae.textures[i]
        local b = t.recorded.calls.SetBlendMode
        if t.recorded.sublevel ~= 6 then Check(not b or b[1] == "BLEND", "a texture left added") end
    end
    -- The switch to a slip under its foot: the note at the hand's size.
    local Party, Person0 = Page.Party, ns.DungeonRun.Person
    Page.Party = function(visit, page)
        local list = Party(visit, page)
        for _, p in ipairs(list) do if p.guid == KAELITH then p.race = "Skyborne" end end
        return list
    end
    ns.DungeonRun.Person = function(visit, guid)
        local f = Person0(visit, guid)
        if guid == KAELITH then table.insert(f, 1, { kind = "snagged", item = LONG }) end
        return f
    end
    S.slip = true
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    local k = CardOf(host, KAELITH)
    Check(k.jot and k.jot.slip and k.jot.size >= Page.SLIP.least and k.jot.box[2] >= CARD.h + 1,
        "no slip under a Skyborne's card with the switch")
    S.slip = nil
    Page.Party, ns.DungeonRun.Person = Party, Person0
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
end

--------------------------------------------------------------------------
Section("a human's card: the user's art, centred on its gold rules, a note above, a seal hung on the rod")

do
    local S = Page.STYLES.human
    -- Before: a pencilled ring where the seal will hang; after: the ribbon
    -- from the rod and the seal, blue wax and gold, and no ring; flat paper
    -- only the same (discs and strokes, no corners moved).
    local function Before(c) return Pieces(c, 4) >= S.pendant.dashes * 5 and Pieces(c, 6) == 0 end
    local function After(c)
        return Pieces(c, 4) == 0 and Pieces(c, 5) == 3 and Pieces(c, 6) == S.pendant.drops + 1 and Pieces(c, 7) >= 20
    end
    local kae = RuledCard({ key = "human", race = "Human", label = "the human", mark = "seal", flag = "sealed",
        least = 7.5, Before = Before, After = After, Flat = After })
    -- A herald's card: the name in the house's Morpheus capitals, the
    -- class in Neuton Italic, both in a deep blue-black.
    Eq(S.name.font, ns.Style.MORPHEUS, "the human's name not in Morpheus")
    Check(S.name.caps ~= false, "the human's name not in capitals")
    local lum = 0.3 * S.ink[1] + 0.59 * S.ink[2] + 0.11 * S.ink[3]
    Check(lum < 0.2 and S.ink[3] > S.ink[1], "the human's ink not a deep blue-black")
    -- The ribbon tied on the rod, beside the banner: its knot on the rod's
    -- end, the seal clear of the banner and its crest.
    local P = S.pendant
    Check(P.knot[1] > 0.19 and P.knot[1] < 0.23 and P.knot[2] < 0.05, "the ribbon not tied on the rod's end")
    Check((P.x * CARD.w - P.r) > 0.225 * CARD.w, "the seal on the banner")
    -- The jot's lines at the hand's own size, as near as the wall allows.
    local Person0 = ns.DungeonRun.Person
    ns.DungeonRun.Person = function(visit, guid)
        local f = Person0(visit, guid)
        if guid == KAELITH then table.insert(f, 1, { kind = "snagged", item = LONG }) end
        return f
    end
    local Party0 = Page.Party
    Page.Party = function(visit, page)
        local list = Party0(visit, page)
        for _, p in ipairs(list) do if p.guid == KAELITH then p.race = "Human" end end
        return list
    end
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    local k = CardOf(host, KAELITH)
    Check(k.jot and k.jot.size >= 7.5 and not k.jot.slip, ("the human's note too small: %.2f"):format(k.jot and k.jot.size or 0))
    Page.Party, ns.DungeonRun.Person = Party0, Person0
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
end

--------------------------------------------------------------------------
Section("an undead's card: the human's ruined, in bone on the dark wall, a note on a slip, a ruined seal")

do
    local S = Page.STYLES.undead
    Eq(Page.CardStyle("Scourge"), "undead", "an undead's card (UnitRace's Scourge)")
    -- Before: a ring in chalk (a dark stroke under it) where the seal will
    -- hang; after: the cord (one tail torn short), the purple wax, cracked.
    local function Before(c) return Pieces(c, 4) >= S.pendant.dashes * 5 and Pieces(c, 3) > 0 and Pieces(c, 6) == 0 end
    local function After(c)
        return Pieces(c, 4) == 0 and Pieces(c, 5) == 3 and Pieces(c, 6) == S.pendant.drops + 1 and Pieces(c, 7) >= 24
    end
    local kae = RuledCard({ key = "undead", race = "Scourge", label = "the undead", mark = "seal", flag = "sealed",
        least = 7, Before = Before, After = After, Flat = After })

    -- Light writing on the dark wall: bone, a dark stroke under it, and
    -- contrast enough against the wall behind it (WCAG's ratio, from the
    -- wall's luminance under the writing: measured from the art where it
    -- is here, else the style's measure).
    local function Lin(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    local function Lum(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
    local ink = Lum(S.ink)
    Check(ink > 0.7, "the undead's writing not light")
    for _, F in ipairs({ S.name, S.who }) do
        Check(F.shade and F.shade[6] >= 0.8 and Lum({ F.shade[3], F.shade[4], F.shade[5] }) < 0.01,
            "no dark stroke under the undead's writing")
    end
    local Party0 = Page.Party
    Page.Party = function(visit, page)
        local list = Party0(visit, page)
        for _, p in ipairs(list) do if p.guid == KAELITH then p.race = "Scourge" end end
        return list
    end
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    local k = CardOf(host, KAELITH)
    for _, fs in ipairs({ k.nameText, k.whoText }) do
        local sh = fs.recorded.calls.SetShadowOffset
        Check(sh and (sh[1] ~= 0 or sh[2] ~= 0), "the undead's writing without its dark stroke")
    end
    -- The wall under a line of writing, from the art (Art/ may not be in
    -- every checkout).
    local wall = { name = S.wall.name, who = S.wall.who }
    local f = io.open("Art/Cards/undead.tga", "rb")
    if f then
        local data = f:read("*a")
        f:close()
        local W, H = data:byte(13) + 256 * data:byte(14), data:byte(15) + 256 * data:byte(16)
        local top = data:byte(18) % 64 >= 32
        local AW, AH = 0.8887 * W, H
        local function Median(fs, size)
            local pt = fs.recorded.points[1]
            local X, Y = pt.args[3], pt.args[4]
            local c, sn = math.cos(k.turn), math.sin(k.turn)
            local mx, my = X * c + Y * sn + CARD.w / 2, X * sn - Y * c + CARD.h / 2
            local w = fs.recorded.width
            local ls = {}
            for x = mx - w / 2, mx + w / 2, 1 do
                for y = my - size * 0.5, my + size * 0.5, 1 do
                    local px, py = math.floor(x / CARD.w * AW), math.floor(y / CARD.h * AH)
                    if not top then py = H - 1 - py end
                    local o = 18 + (py * W + px) * 4
                    local b, g, r = data:byte(o + 1), data:byte(o + 2), data:byte(o + 3)
                    ls[#ls + 1] = Lum({ r / 255, g / 255, b / 255 })
                end
            end
            table.sort(ls)
            return ls[math.floor(#ls / 2) + 1]
        end
        wall.name, wall.who = Median(k.nameText, k.nameSize), Median(k.whoText, k.whoSize)
        Check(math.abs(wall.name - S.wall.name) < 0.03 and math.abs(wall.who - S.wall.who) < 0.03,
            ("the wall's measure in the style not the art's: %.3f, %.3f"):format(wall.name, wall.who))
    end
    local nameRatio, whoRatio = (ink + 0.05) / (wall.name + 0.05), (ink + 0.05) / (wall.who + 0.05)
    Check(nameRatio >= 3.5, ("the name too faint on the wall: %.2f"):format(nameRatio))
    Check(whoRatio >= 4.5, ("the level and class too faint on the wall: %.2f"):format(whoRatio))
    -- The ruined seal: tied on the rusty rod's end, clear of the banner.
    local P = S.pendant
    Check(P.chalk and P.frayed and P.crack, "the undead's seal not ruined")
    Check((P.x * CARD.w - P.r) > 0.195 * CARD.w, "the seal on the banner")
    Page.Party = Party0
    ns.UI.OpenVisit(RFK.id, G)
    ns.UI.OpenVisit(RFK.id, G)
    -- /sd cardrace: every card in one race's design, to see it on a real
    -- save; alone, back to each holder's own.
    local Print = ns.Print
    ns.Print = function() end
    SlashCmdList.SOCIALDIARY("cardrace Scourge")
    for _, card in ipairs(host.cards) do Eq(card.style, "undead", "a card not in the undead design with cardrace") end
    SlashCmdList.SOCIALDIARY("cardrace")
    Eq(CardOf(host, BROM).style, "dwarf", "cardrace not off")
    ns.Print = Print
end

--------------------------------------------------------------------------
Section("a gnome's card: the user's badge, its photo, class icon and printed fields, a stamp")

do
    local S = Page.STYLES.gnome
    local ART = "Interface\\AddOns\\social_diary\\Art\\Cards\\gnome"
    Eq(S.art.stock, ART, "the gnome's art")
    -- The old card drawn in code is gone: no copper rules, drafting grid,
    -- cog, stub or its words.
    for _, key in ipairs({ "rule", "grid", "cog", "stub", "perf", "teeth", "copper", "jot" }) do
        Eq(S[key], nil, "the old gnome card's " .. key .. " still in its style")
    end
    Eq(Page.Words.FILE, nil, "the stub's words still kept")
    -- The badge's corners keyed out of its white backdrop (where the art is
    -- here: Art/ may not be in every checkout).
    local f = io.open("Art/Cards/gnome.tga", "rb")
    if f then
        local data = f:read("*a")
        f:close()
        local W, H, top = data:byte(13) + 256 * data:byte(14), data:byte(15) + 256 * data:byte(16), data:byte(18) % 64 >= 32
        local function Alpha(x, y)
            if not top then y = H - 1 - y end
            return data:byte(18 + (y * W + x) * 4 + 4)
        end
        Check(W == 1024 and H == 512 and data:byte(17) == 32, "the badge's art not a 32-bit 1024x512 TGA")
        local aw = math.floor(0.8887 * W + 0.5)
        for _, c in ipairs({ { 0, 0 }, { aw - 1, 0 }, { 0, H - 1 }, { aw - 1, H - 1 } }) do
            Eq(Alpha(c[1], c[2]), 0, "a badge's corner not keyed out")
        end
        for _, c in ipairs({ { 455, 256 }, { 30, 256 }, { 880, 256 }, { 455, 20 }, { 455, 490 } }) do
            Eq(Alpha(c[1], c[2]), 255, "a hole in the badge")
        end
        Eq(Alpha(aw + 20, 256), 0, "the canvas past the art not clear")
    end

    local Person0, Party0 = ns.DungeonRun.Person, Page.Party
    local function Lay() ns.UI.OpenVisit(RFK.id, G) ns.UI.OpenVisit(RFK.id, G) return CardOf(host, ZURI) end
    -- Without a note, nothing of the card on the table's layer.
    ns.DungeonRun.Person = function() return {} end
    local zuri = Lay()
    Eq(zuri.style, "gnome", "Zuri's card")
    local arts, shadow = 0, 0
    for i = 1, zuri.textures.used do
        local t = zuri.textures[i]
        local c = t.recorded.calls
        Check(t.recorded.layer ~= "BACKGROUND", "a stock drawn in code under the badge")
        if t.recorded.layer == "BORDER" then
            local tex = c.SetTexture
            Check(tex and tex[1] == ART and (not c.SetColorTexture or tex.seq > c.SetColorTexture.seq),
                "a placeholder drawn on the badge")
            Check(c.SetTexCoord[1] == 0 and c.SetTexCoord[2] == 0.8887 and c.SetTexCoord[3] == 0
                and c.SetTexCoord[4] == 1, "the badge's texcoords")
            Check(t.bent, "the badge not bent with the card")
            arts = arts + 1
            local v = c.SetVertexColor
            if v and v.seq > tex.seq and v[1] < 0.5 then shadow = shadow + 1 end
        end
    end
    Eq(arts, 2 + ns.UI.Light.CAST.layers, "the badge, its light and its shadow")
    Eq(shadow, ns.UI.Light.CAST.layers, "the badge's shadow not the art in ink")
    ns.DungeonRun.Person = Person0

    local function Clear(a, b) return a[3] <= b[1] or a[1] >= b[3] or a[4] <= b[2] or a[2] >= b[4] end
    local function Frac(b) return { b[1] * CARD.w, b[2] * CARD.h, b[3] * CARD.w, b[4] * CARD.h } end
    local function Inside(a, b) return a[1] >= b[1] and a[2] >= b[2] and a[3] <= b[3] and a[4] <= b[4] end
    -- A region's middle on the card (from its top left), from its point.
    local function Middle(card, r)
        local pt = r.recorded.points[1]
        local X, Y = pt.args[3], pt.args[4]
        local c, sn = math.cos(card.turn), math.sin(card.turn)
        return X * c + Y * sn + CARD.w / 2, X * sn - Y * c + CARD.h / 2
    end
    local function Writing(card, fs, size)
        local mx, my = Middle(card, fs)
        local w = fs.recorded.width
        return { mx - w / 2, my - 0.5 * size, mx + w / 2, my + 0.6 * size }, my
    end

    -- The three fields, printed on their rules, in the badge's print.
    zuri = Lay()
    local function OnRule(fs, size, rule, F, label)
        local box, my = Writing(zuri, fs, size)
        Check(math.abs(box[1] - (rule[1] * CARD.w + S.inset)) < 0.5, label .. " not begun at its rule")
        Check(math.abs(my - (rule[3] * CARD.h - F.sit * size)) < 0.5, ("%s not on its rule: %.2f"):format(label, my))
        Check(box[3] <= rule[2] * CARD.w - S.inset + 0.5, ("%s past its rule: %.1f"):format(label, box[3]))
        Check(size >= F.least and size <= F.size, label .. "'s size " .. size)
        Eq(fs.recorded.calls.SetFont[1], ns.Style.FRIZ, label .. " not printed")
        local c = fs.recorded.calls.SetTextColor
        Check(c[1] == S.ink[1] and c[3] == S.ink[3], label .. " not in the badge's ink")
        for _, k in ipairs(S.keep) do
            Check(Clear(box, Frac(k)), ("%s on the art at %.2f,%.2f"):format(label, k[1], k[2]))
        end
        return box
    end
    local nameBox = OnRule(zuri.nameText, zuri.nameSize, S.fields.name, S.name, "Zuri's name")
    local whoBox = OnRule(zuri.whoText, zuri.whoSize, S.fields.who, S.print, "Zuri's level and class")
    OnRule(zuri.idText, zuri.idSize, S.fields.id, S.print, "Zuri's employee number")
    Eq(zuri.nameText:GetText(), "ZURI NIGHTFANG", "Zuri's name not in capitals")
    Eq(zuri.whoText:GetText(), "Level 21 Priest", "Zuri's level and class")
    Eq(zuri.idText:GetText(), Page.Words.Serial(ZURI), "Zuri's employee number")
    -- A long name and class: smaller, then cut short at their rules' ends.
    local was = zuri.person
    zuri.person = { guid = ZURI, first = "Fizzlebottom", surname = "Sprocketwhistle-Gearspanner", race = "Gnome",
        classToken = "WARLOCK", class = "Warlock", level = 60, facts = {}, inDiary = false }
    zuri:Draw()
    OnRule(zuri.nameText, zuri.nameSize, S.fields.name, S.name, "a long name")
    OnRule(zuri.whoText, zuri.whoSize, S.fields.who, S.print, "a long class")
    Eq(zuri.nameSize, S.name.least, "a long name not fitted down to its least")
    zuri.person = was
    zuri:Draw()

    -- The class's icon in the holographic disc, its rim showing round it
    -- (the client's class icons, here a stand-in for the mock's none).
    local D = S.disc
    local TC = _G.CLASS_ICON_TCOORDS
    _G.CLASS_ICON_TCOORDS = { PRIEST = { 0.5, 0.75, 0.25, 0.5 } }
    zuri:Draw()
    Check(ns.Style.Art("classes"), "no class icons to try")
    local icon
    for i = 1, zuri.textures.used do
        local t = zuri.textures[i]
        local tex = t.recorded.calls.SetTexture
        if t:IsShown() and tex and tex[1] == ns.Style.Art("classes") then icon = t end
    end
    Check(icon, "no class icon on the badge")
    if icon then
        local x, y = Middle(zuri, icon)
        Check(math.abs(x - D.x * CARD.w) < 0.5 and math.abs(y - D.y * CARD.h) < 0.5, "the class icon not in the disc")
        Check(icon.recorded.width / 2 <= D.r - 1, "the class icon over the disc's rim")
        Check(icon.recorded.width >= 14, "the class icon too small")
    end
    _G.CLASS_ICON_TCOORDS = TC
    zuri:Draw()

    -- The photo: the grey inside the gold frame; with no face to be had,
    -- the badge's blank head and shoulders, inside it.
    local P = Frac(S.photo)
    Check(Inside(P, Frac(S.keep[2])), "the photo's slot not inside its frame")
    Eq(zuri.photo, "blank", "a photo without a face to put in it")
    for i = 1, zuri.textures.used do
        local t = zuri.textures[i]
        if t:IsShown() and t.recorded.layer == "ARTWORK" and t.recorded.sublevel == 1 then
            local x, y = Middle(zuri, t)
            local w, h = t.recorded.width, t.recorded.height
            Check(Inside({ x - w / 2, y - h / 2, x + w / 2, y + h / 2 }, { P[1] - 0.5, P[2] - 0.5, P[3] + 0.5, P[4] + 0.5 }),
                ("the blank photo past its slot (%.1f,%.1f %.1fx%.1f)"):format(x, y, w, h))
        end
    end
    -- The race's portrait where the client has one (the largest it has),
    -- cropped like a photo from its part of the file.
    local CT = _G.C_Texture
    local asked = {}
    _G.C_Texture = { GetAtlasInfo = function(atlas)
        asked[#asked + 1] = atlas
        if atlas == "raceicon-gnome-male" then
            return { file = 123456, leftTexCoord = 0.5, rightTexCoord = 0.75, topTexCoord = 0.25, bottomTexCoord = 0.5 }
        end
    end }
    zuri:Draw()
    Eq(zuri.photo, "race", "no race portrait for the photo")
    Eq(asked[1], "raceicon128-gnome-male", "the largest portrait not asked first")
    local face
    for i = 1, zuri.textures.used do
        local t = zuri.textures[i]
        local tex = t.recorded.calls.SetTexture
        if t:IsShown() and tex and tex[1] == 123456 then face = t end
    end
    Check(face and face.bent, "the race portrait not laid on the badge")
    if face then
        local c, C = face.recorded.calls.SetTexCoord, S.crop
        Check(math.abs(c[1] - (0.5 + 0.25 * C[1])) < 1e-9 and math.abs(c[2] - (0.5 + 0.25 * C[2])) < 1e-9
            and math.abs(c[3] - (0.25 + 0.25 * C[3])) < 1e-9 and math.abs(c[4] - (0.25 + 0.25 * C[4])) < 1e-9,
            "the portrait not cropped like a photo")
        Eq(face.recorded.layer, "ARTWORK", "the portrait's layer")
    end
    -- Its crop the slot's shape, from a square portrait.
    local crop = S.crop
    Check(math.abs((crop[2] - crop[1]) / (crop[4] - crop[3]) - (P[3] - P[1]) / (P[4] - P[2])) < 0.03,
        "the photo's crop not the slot's shape")
    -- By sex: a woman's portrait for a woman; a man's where it is not known.
    local sex = zuri.person.sex
    asked = {}
    zuri.person.sex = 3
    zuri:Draw()
    Eq(asked[1], "raceicon128-gnome-female", "not a woman's portrait for a woman")
    asked = {}
    zuri.person.sex = nil
    zuri:Draw()
    Eq(asked[1], "raceicon128-gnome-male", "no portrait where the sex is not known")
    Eq(zuri.photo, "race", "no portrait where the sex is not known")
    zuri.person.sex = sex
    -- Live, where they are about: their own portrait.
    local SPT, Unit0 = _G.SetPortraitTexture, _G.UnitGUID
    _G.SetPortraitTexture = function(t, unit) t.portraitOf = unit end
    _G.UnitGUID = function(unit) if unit == "party2" then return ZURI end return Unit0(unit) end
    zuri:Draw()
    Eq(zuri.photo, "live", "no live portrait of Zuri in the party")
    local live
    for i = 1, zuri.textures.used do
        if zuri.textures[i]:IsShown() and zuri.textures[i].portraitOf == "party2" then live = zuri.textures[i] end
    end
    Check(live and live.bent, "the live portrait not laid on the badge")
    _G.SetPortraitTexture, _G.UnitGUID, _G.C_Texture = SPT, Unit0, CT
    zuri:Draw()
    Eq(zuri.photo, "blank", "the photo not back to the blank")

    -- The stamp: over the header's right end, clear of its words and the
    -- medallion, inside the band, in the card's top band.
    local E = S.stamp
    local sx, sy = E.x * CARD.w, E.y * CARD.h
    local reach = E.r + 1.2
    Check(sx - reach >= 0.83 * CARD.w and sx + reach <= CARD.w - 2, "the stamp on the header's words or off the badge")
    Check(sy - reach >= 0 and sy + reach <= 0.178 * CARD.h, "the stamp off the header band")
    Check(Clear({ sx - reach, sy - reach, sx + reach, sy + reach }, nameBox), "the stamp on the name")
    local function Pieces(card, sub)
        local n = 0
        for i = 1, card.textures.used do
            local t = card.textures[i]
            if t:IsShown() and t.recorded.layer == "ARTWORK" and t.recorded.sublevel == sub then n = n + 1 end
        end
        return n
    end
    Check(not zuri.stamped and Pieces(zuri, 4) == E.dots and Pieces(zuri, 5) == 0, "no dots where the stamp will go")
    Check(zuri.add.offer and zuri.add.box, "no way into the diary on Zuri's badge")
    zuri.person.inDiary = true
    zuri:Draw()
    Check(zuri.stamped and Pieces(zuri, 4) == 0 and Pieces(zuri, 5) >= E.teeth + 20 and Pieces(zuri, 6) == 2,
        "the badge not stamped")
    local first = zuri.add.box[1]
    zuri:Draw()
    Eq(zuri.add.box[1], first, "the stamp moved when drawn again")
    zuri.flat = true
    zuri:Draw()
    Check(zuri.stamped and Pieces(zuri, 6) == 2, "no stamp on a flat badge")
    zuri.flat = false
    zuri.person.inDiary = false
    zuri:Draw()

    -- Beside another card: the name and the stamp clear of it.
    local i
    for n, card in ipairs(host.cards) do if card == zuri then i = n end end
    Check(i and i > 1, "Zuri's card in front")
    -- (Fanned: the card under it in the column lies over its foot.)
    Page.Fan(host, true, true)
    local front = host.cards[i - 1]
    local nb = Writing(zuri, zuri.nameText, zuri.nameSize)
    for fx = nb[1], nb[3] + 1e-9, (nb[3] - nb[1]) / 8 do
        for _, fy in ipairs({ nb[2], S.fields.name[3] * CARD.h, nb[4] }) do
            local x, y = zuri.plane.Out(fx - CARD.w / 2, fy - CARD.h / 2)
            Check(not Under(front, x, y), ("Zuri's name under the card in front at %.1f,%.1f"):format(fx, fy))
        end
    end
    local b = zuri.add.box
    for _, q in ipairs({ { b[1], b[2] }, { b[3], b[2] }, { b[3], b[4] }, { b[1], b[4] } }) do
        Check(not Under(front, q[1], q[2]), "Zuri's stamp under the card in front")
    end
    -- Her note (the band she snagged) on a slip under the badge's foot.
    Check(zuri.jot and zuri.jot.slip and zuri.jot.box[2] >= CARD.h + 1 and zuri.jot.size >= Page.SLIP.least,
        "Zuri's note not on a slip under her badge")
    Page.Party = Party0
end

--------------------------------------------------------------------------
Section("/sd handtest: a won item's holder has the snagged note, for a try on a real save")

-- Brom won an item (the test data's run gives him none: given here).
ns.DungeonRun.Person = function(visit, guid)
    local f = Person(visit, guid)
    if guid == BROM or guid == ME then f[#f + 1] = { kind = "won", item = LONG, quality = 3 } end
    return f
end
ns.UI.OpenVisit(RFK.id, G)
ns.UI.OpenVisit(RFK.id, G)
Eq(CardOf(host, BROM).jot, nil, "Brom's won item jotted without the switch")
local said = {}
local Print = ns.Print
ns.Print = function(msg, ...) said[#said + 1] = msg:format(...) end
SlashCmdList.SOCIALDIARY("handtest")
Check(said[1] and said[1]:find("handtest on", 1, true), "no word that the switch is on")
Eq(CardOf(host, BROM).jot and CardOf(host, BROM).jot.key, "snagged", "the run not laid again with Brom's note")
Eq(CardOf(host, BROM).jot.fact.kind, "won", "Brom's note not of his won item")
Eq(CardOf(host, BROM).hovers[1].item, LONG, "Brom's note without his item's tooltip")
Eq(CardOf(host, ME).jot, nil, "the user's own card jotted")
Eq(CardOf(host, ZURI).jot.fact.kind, "snagged", "Zuri's own note given up for the switch's")
SlashCmdList.SOCIALDIARY("handtest")
Check(said[2] and said[2]:find("handtest off", 1, true), "no word that the switch is off")
Eq(CardOf(host, BROM).jot, nil, "Brom's note still there with the switch off")
ns.Print = Print
ns.DungeonRun.Person = Person
ns.UI.OpenVisit(RFK.id, G)
ns.UI.OpenVisit(RFK.id, G)

--------------------------------------------------------------------------
Section("into the diary from a card; a diary person's opens their page; never the user's")

-- In the stack the cards take no mouse, their ways in hidden; fanned they
-- do.
ns.UI.OpenVisit(RFK.id, G)
ns.UI.OpenVisit(RFK.id, G)
for _, card in ipairs(host.cards) do
    Check(card.held and card.recorded.calls.EnableMouse[1] == false, "a card in the stack takes the mouse")
    Check(not card.add:IsShown(), "a way into the diary shown on a card in the stack")
    for i = 1, card.hovers.used do Check(not card.hovers[i]:IsShown(), "a note's tooltip on a card in the stack") end
end
Page.Fan(host, true, true)
for _, card in ipairs(host.cards) do
    Check(not card.held and card.recorded.calls.EnableMouse[1] == true, "a fanned card takes no mouse")
    for i = 1, card.hovers.used do Check(card.hovers[i]:IsShown(), "a note's tooltip hidden on a fanned card") end
end
local me = CardOf(host, ME)
Check(not me.add:IsShown(), "a way into the diary on the user's own card")
Check(not me.stamped and not me.ticked and not me.pressed and not me.lit, "the user's card shows them added")
local tester = CardOf(host, G)
Check(tester.add:IsShown() and not tester.add.offer, "a diary person's card offers the diary")
Eq(tester.ticked, true, "Tester's card not shown added")
local zuri = CardOf(host, ZURI)
Check(not zuri.stamped, "a stranger's badge stamped")
Check(zuri.add.offer and zuri.add:IsShown(), "no way into the diary on Zuri's card")
local brom = CardOf(host, BROM)
Check(brom.add.offer and not brom.stamped, "Brom's card shown added")
-- The tooltip says what the click does.
brom.add.scripts.OnEnter(brom.add)
Eq(GameTooltip.text, Page.Words.ADD, "the way in's tooltip")
brom.add.scripts.OnLeave(brom.add)
local played = {}
local PlaySound = ns.Style.PlaySound
ns.Style.PlaySound = function(key, ...)
    played[#played + 1] = key
    return PlaySound(key, ...)
end
brom.add.scripts.OnClick(brom.add)
Check(ns.Diary.IsDiary(BROM), "Brom not added")
Eq(ns.Diary.Get(BROM).addedContext.source, "dungeon", "Brom's entry's source")
Eq(played[#played], "write", "no pen as Brom was added")
Eq(brom.stamped, true, "Brom's stamp not pressed")
Check(not brom.add.offer, "the way in still offered once added")
zuri.add.scripts.OnClick(zuri.add)
Eq(zuri.stamped, true, "Zuri's badge not stamped")
local kaelith = CardOf(host, KAELITH)
kaelith.add.scripts.OnClick(kaelith.add)
Eq(kaelith.pressed, true, "no leaf pressed on Kaelith's card")
ns.Style.PlaySound = PlaySound
-- A click on the user's own card or the way in does nothing.
played = {}
me.scripts.OnClick(me)
Check(host:IsShown(), "the user's card put the run away")
-- A diary person's card: their page, the run put away.
brom.scripts.OnClick(brom)
Check(not host:IsShown(), "the run still out after a click on Brom's card")
Eq(J.selected, BROM, "Brom's page not open")
Eq(J.visit, nil, "the run still open")
for _, guid in ipairs({ BROM, ZURI, KAELITH }) do ns.Diary.Remove(guid, "keep") end
ns.UI.ShowJournal(G)
ns.UI.OpenVisit(RFK.id, G)
Page.Fan(host, true, true)
tester = CardOf(host, G)
tester.scripts.OnClick(tester)
Check(not host:IsShown(), "the page's own person's card left the run out")
Eq(J.selected, G, "Tester's page not open")

--------------------------------------------------------------------------
Section("in a stack by the map's corner, fanned out of it: big, on the screen, the same every time")

local STACK, FAN = Page.STACK, Page.FAN
local function Lay(sw, sh, bx)
    UIParent.width, UIParent.height = sw, sh
    bookAt = { bx, sh / 2 }
    Page.Close(true)
    ns.UI.ShowJournal(G)
    ns.UI.OpenVisit(RFK.id, G)
end
local function Near(a, b, e) return math.abs(a - b) < (e or 1e-6) end
-- The corners of a box w by h (times k) turned `turn` with its middle at
-- x, y on the table (from the sheet's middle, y down).
local function Quad(x, y, w, h, turn)
    local c, sn = math.cos(turn), math.sin(turn)
    local out = {}
    for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
        local u, v = q[1] * w / 2, q[2] * h / 2
        out[#out + 1] = { x + u * c + v * sn, y - u * sn + v * c }
    end
    return out
end
-- A point of the table on the screen (x right, y up from the bottom left).
local function Screen(p, sw, sh)
    local k = host:GetScale() / (panel:GetScale() or 1)
    return sw / 2 + (map.lie[1] + p[1]) * k, sh / 2 + (map.lie[2] - p[2]) * k
end
-- A point of the table in the stack: from the top card's middle, x along
-- it, y down.
local function InStack(p)
    local at = map.stack
    local dx, dy = p[1] - at.x, p[2] - at.y
    local c, sn = math.cos(at.turn), math.sin(at.turn)
    return dx * c - dy * sn, dx * sn + dy * c
end
-- An item's corners where it lies now (FanMove's `at`).
local function Now(item)
    local at = item.at
    return Quad(at[1], at[2], CARD.w * at[3], CARD.h * at[3], item.turn)
end

-- Every check of a run laid on a screen sw by sh with `want` cards.
local function Stacked(label, sw, sh, want)
    Eq(#host.cards, want, "cards: " .. label)
    local stack, at = host.stack, map.stack
    Check(stack:IsShown(), "nothing to click on the stack: " .. label)
    -- On the screen, by the map's bottom-left corner, over the paper's edge
    -- by about STACK.overlap.
    local ang = map.angle or 0
    local most = -math.huge
    for _, item in ipairs(host.fanItems) do
        for _, c in ipairs(Now(item)) do
            local X, Y = Screen(c, sw, sh)
            local e = STACK.edge * host:GetScale() - 1
            Check(X >= e and X <= sw - e and Y >= e and Y <= sh - e, ("the stack off the screen (%s): %.0f,%.0f"):format(label, X, Y))
            local u = c[1] * math.cos(ang) - c[2] * math.sin(ang)
            most = math.max(most, u + map.w / 2)
        end
    end
    local bh = at.box[4] - at.box[2]
    Check(most > 0 and most <= STACK.overlap + bh / 2 * math.abs(math.sin(ang)) + 1.5,
        ("the stack not over the paper's edge (%s): %.1f"):format(label, most))
    local X0, Y0 = map.K.Screen(0, map.h)
    Check(at.box[4] <= -Y0 + 1 and at.y > -Y0 - map.h / 2, "the stack not by the bottom-left corner: " .. label)
    -- The button over it, round all of it.
    local sp = stack.recorded.points[1].args
    Check(sp[1] == host.cardTable and sp[3] <= at.box[1] and -sp[4] <= at.box[2]
        and sp[3] + stack.recorded.width >= at.box[3] and -sp[4] + stack.recorded.height >= at.box[4],
        "the stack's button not over it: " .. label)
    -- No strip under it.
    local keep = at.keep
    for _, e in ipairs(map.noteStrips) do
        local sb = e.box
        Check(sb[3] <= keep[1] or sb[1] >= keep[3] or sb[4] <= keep[2] or sb[2] >= keep[4], "a strip under the stack: " .. label)
    end
    -- In it: small, the front one on top and whole, each under it peeking
    -- out up and to the left of the one over it; none answers the mouse;
    -- each casting its shadow on the world from the stack's height.
    for i, item in ipairs(host.fanItems) do
        Eq(item.e, 0, "a card out of the stack: " .. label)
        Check(Near(item.at[3], STACK.scale), "a card in the stack not its resting size: " .. label)
        Check(item.frame:GetFrameLevel() < stack:GetFrameLevel(), "a card over the stack's button: " .. label)
        if i > 1 then
            local over = host.fanItems[i - 1]
            Check(item.frame:GetFrameLevel() < over.frame:GetFrameLevel(), "the front card not on top: " .. label)
            local tl, otl = { InStack(Now(item)[1]) }, { InStack(Now(over)[1]) }
            local bl, obl = { InStack(Now(item)[4]) }, { InStack(Now(over)[4]) }
            Check(tl[2] < otl[2] - 1 and bl[1] < obl[1] - 1, "a card in the stack not peeking out from under: " .. label)
            Check(math.abs(tl[1] - otl[1]) < 8 and otl[2] - tl[2] < 8, "a card in the stack too far off: " .. label)
            if not ns.Setting("flatSheets") then
                Check(Near(item.turn, over.turn - math.rad(FAN.turn)), "a card in the stack not fanned: " .. label)
            end
        end
        Check(item.frame.groundFrame:IsShown(), "a card in the stack casts no shadow on the world: " .. label)
    end
    -- Fanned: much bigger, a column from the stack bending right as it
    -- rises, each turned more with the clock; whole on the screen, over
    -- the stack's button and the catcher, the front one in front; each
    -- showing its name (and its level and class, unless shrunk to
    -- FAN.least); taking the mouse.
    Page.Fan(host, true, true)
    local plan = host.fanPlan
    local k = plan.k
    Check(k >= STACK.scale * 1.6, ("the fanned cards hardly bigger (%s): %.2f"):format(label, k))
    local h = CARD.h * k
    if want > 1 then
        Check(plan.step >= FAN.name * h - 1e-6, ("a card's name under the next (%s): %.2f"):format(label, plan.step / h))
        if k > FAN.least + 1e-6 then
            Check(plan.step >= FAN.show * h - 1e-6, ("shingled closer than FAN.show while big (%s)"):format(label))
        end
    end
    local front = stack:GetFrameLevel()
    for i, item in ipairs(host.fanItems) do
        Eq(item.e, 1, "a card not fanned: " .. label)
        Check(Near(item.at[3], k), "a fanned card not the fan's size: " .. label)
        for _, c in ipairs(Now(item)) do
            local X, Y = Screen(c, sw, sh)
            local e = FAN.edge * host:GetScale() - 1
            Check(X >= e and X <= sw - e and Y >= e and Y <= sh - e,
                ("%s's card off the screen fanned (%s): %.0f,%.0f"):format(item.card.person.first, label, X, Y))
        end
        Check(item.frame:GetFrameLevel() > host.catcher:GetFrameLevel() and host.catcher:GetFrameLevel() > front,
            "a fanned card under the catcher or the stack: " .. label)
        Check(item.frame.groundFrame:IsShown(), "a fanned card casts no shadow on the world: " .. label)
        Check(not item.card.held, "a fanned card takes no mouse: " .. label)
        if i > 1 then
            local below = host.fanItems[i - 1]
            Check(item.frame:GetFrameLevel() < below.frame:GetFrameLevel(), "a card over the one under it: " .. label)
            Check(item.fan[2] < below.fan[2], "the column not rising: " .. label)
            if not ns.Setting("flatSheets") then
                Check(Near(item.turn, below.turn - math.rad(FAN.turn)), "a card not turned more than the one under it")
            end
        end
    end
    if want > 2 and not ns.Setting("flatSheets") then
        Check(host.fanItems[want].fan[1] > host.fanItems[1].fan[1], "the column not bending right: " .. label)
    end
    Check(host.catcher:IsShown(), "nothing beside the fan to put them back: " .. label)
    Page.Fan(host, false, true)
    for _, item in ipairs(host.fanItems) do Eq(item.e, 0, "a card not back in the stack: " .. label) end
    Check(not host.catcher:IsShown(), "the catcher left out: " .. label)
end

-- Party sizes one to five (the test run's, cut short), on five screens,
-- the book in the middle, at the right edge and at the left.
local Party = Page.Party
local size
Page.Party = function(visit, page)
    local list = Party(visit, page)
    while size and #list > size do table.remove(list) end
    return list
end
for _, screen in ipairs({ { 1365, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 1024, 768 }, { 800, 600 } }) do
    for _, bx in ipairs({ screen[1] / 2, screen[1] - 420, 420 }) do
        for n = 1, 5 do
            size = n
            Lay(screen[1], screen[2], bx)
            Stacked(("%d cards, %dx%d, the book at %d"):format(n, screen[1], screen[2], bx), screen[1], screen[2], n)
        end
    end
end
size = nil
Page.Party = Party
-- Big where there is room: a big screen at FAN.scale and apart; 1365 by
-- 768, shingled at no less than FAN.least.
Lay(1920, 1080, 960)
Eq(host.lie.scale, 1, "the spread shrunk on a big screen")
Eq(host.fanPlan.k, FAN.scale, "the fan not at its full size on a big screen")
Lay(2560, 1440, 1280)
Check(host.fanPlan.step >= CARD.h * FAN.scale, "the fan shingled on a very big screen")
Lay(1365, 768, 682.5)
Check(host.fanPlan.k >= FAN.least - 1e-6, "the fan too small at 1365x768: " .. host.fanPlan.k)
Check(host.flank >= Page.StackFlank(map.w, map.h), "no room beside the map for the stack")
-- The same every time.
local was_ = {}
for i, item in ipairs(host.fanItems) do was_[i] = { item.rest[1], item.rest[2], item.fan[1], item.fan[2], item.turn } end
Page.Close(true)
ns.UI.OpenVisit(RFK.id, G)
for i, item in ipairs(host.fanItems) do
    local w = was_[i]
    Check(Near(item.rest[1], w[1]) and Near(item.rest[2], w[2]) and Near(item.fan[1], w[3]) and Near(item.fan[2], w[4])
        and Near(item.turn, w[5]), "a card not where it lay before")
end
-- Laid flat: nothing turned, a straight column.
ns.SetSetting("flatSheets", true)
Lay(1365, 768, 682.5)
Eq(map.stack.turn, 0, "the stack turned laid flat")
for _, item in ipairs(host.fanItems) do Eq(item.turn, 0, "a card turned laid flat") end
Stacked("laid flat", 1365, 768, 5)
ns.SetSetting("flatSheets", false)

--------------------------------------------------------------------------
Section("the fan animated: out one after the other, lifted off, then growing on an arc; back the same way")

Lay(1365, 768, 682.5)
local stack = host.stack
local items = host.fanItems
local n = #items
local function Tick(dt)
    local step = stack.scripts.OnUpdate
    if step then step(stack, dt) end
    return step ~= nil
end
mock.sounds = {}
stack.scripts.OnClick(stack)
Eq(host.fanned, true, "a click on the stack did not fan the cards")
Eq(tostring(mock.sounds[#mock.sounds] and mock.sounds[#mock.sounds][1]), "836", "the cards fanned without a sound")
Check(host.catcher:IsShown(), "no catcher beside the fan")
Check(stack.scripts.OnUpdate ~= nil, "no driver")
-- Each frame: the front card first, the others after it in turn; lifted
-- off the stack at its resting size, over the stack only once off it;
-- growing, rising, never jumping.
local t, last, order, seen = 0, {}, {}, {}
for i = 1, n do last[i] = { e = 0, k = STACK.scale } end
while Tick(1 / 60) do
    t = t + 1 / 60
    Check(t < 1, "the fan never stopped")
    if t >= 1 then break end
    for i, item in ipairs(items) do
        Check(item.e >= last[i].e - 1e-9, "a card went back on its way out")
        Check(item.at[3] >= last[i].k - 1e-9, "a card shrank on its way out")
        if item.e > 0 and not seen[i] then order[#order + 1], seen[i] = i, true end
        if item.e <= FAN.draw then
            Check(Near(item.at[3], STACK.scale), "a card grew on the stack")
            Check(item.frame:GetFrameLevel() < stack:GetFrameLevel(), "a card over the stack's button before it was off")
        else
            Check(item.frame:GetFrameLevel() > stack:GetFrameLevel(), "a card off the stack under its button")
            local ou, ov = InStack(item.out)
            local ru, rv = InStack(item.rest)
            Check(Near(ou, ru) and Near(rv - ov, STACK.hover), "a card not lifted straight off the stack")
        end
        last[i] = { e = item.e, k = item.at[3] }
    end
end
for i = 1, n do Eq(order[i], i, "the cards not out in turn, the front one first") end
local total = FAN.time + (n - 1) * FAN.stagger
Check(t <= total + 2 / 60 and t >= total - 2 / 60, ("the fan took %.3f s, not %.3f"):format(t, total))
Check(total >= 0.25 and total <= 0.42, "the fan not short: " .. total)
for _, item in ipairs(items) do
    Eq(item.e, 1, "a card not out")
    Check(not item.card.held, "a card out takes no mouse")
end
-- Half way along, the sideways part lags behind the rise: an arc.
local first = items[n]
local mid = (FAN.draw + 1) / 2
Page.FanMove(first, mid, 0)
local fx = first.out[1] + (first.fan[1] - first.out[1]) * 0.5
local fy = first.out[2] + (first.fan[2] - first.out[2]) * 0.5
Check(Near(first.at[2], fy) and (math.abs(first.fan[1] - first.out[1]) < 1 or math.abs(first.at[1] - first.out[1]) < math.abs(fx - first.out[1])),
    "the way out not an arc")
Page.FanMove(first, 1, 0)
-- Back the same way: the top card first, shrinking onto the stack.
mock.sounds = {}
stack.scripts.OnClick(stack)
Eq(host.fanned, false, "a second click did not put the cards back")
Eq(tostring(mock.sounds[#mock.sounds] and mock.sounds[#mock.sounds][1]), "836", "the cards went back without a sound")
Check(not host.catcher:IsShown(), "the catcher left out")
for _, item in ipairs(items) do Check(item.card.held, "a card on its way back takes the mouse") end
t, order, seen = 0, {}, {}
for i = 1, n do last[i] = { e = 1, k = host.fanPlan.k } end
while Tick(1 / 60) do
    t = t + 1 / 60
    if t >= 1 then break end
    for i, item in ipairs(items) do
        Check(item.e <= last[i].e + 1e-9 and item.at[3] <= last[i].k + 1e-9, "a card grew on its way back")
        if item.e < 1 and not seen[i] then order[#order + 1], seen[i] = i, true end
        last[i] = { e = item.e, k = item.at[3] }
    end
end
for i = 1, n do Eq(order[i], n - i + 1, "the cards not back in turn, the top one first") end
Check(t <= total + 2 / 60, "putting them back took too long")
for _, item in ipairs(items) do
    Eq(item.e, 0, "a card not back in the stack")
    Check(item.frame:GetFrameLevel() < stack:GetFrameLevel(), "a card back in the stack over its button")
end
Eq(stack.scripts.OnUpdate, nil, "the driver left running")
-- Turned back half way: each goes back from where it is, no jump.
Page.Fan(host, true)
for _ = 1, 9 do Tick(1 / 60) end
local before = {}
for i, item in ipairs(items) do before[i] = item.at end
Page.Fan(host, false)
Tick(1 / 240)
for i, item in ipairs(items) do
    local a, b = before[i], item.at
    Check(math.abs(a[1] - b[1]) < 4 and math.abs(a[2] - b[2]) < 4 and math.abs(a[3] - b[3]) < 0.05,
        "a card jumped as the fan turned back")
end
for _ = 1, 60 do Tick(1 / 60) end
for _, item in ipairs(items) do Eq(item.e, 0, "a card not back after turning back") end
-- Under the mouse, the cards in the stack rise a little; the tooltip says
-- what a click does.
local rest1 = { items[1].at[1], items[1].at[2] }
stack.scripts.OnEnter(stack)
Eq(GameTooltip.text, Page.Words.STACK, "the stack's tooltip")
Eq(Page.Words.STACK, "Click to fan out the cards.", "the stack's words")
for _ = 1, 30 do Tick(1 / 60) end
local lifted = math.sqrt((items[1].at[1] - rest1[1]) ^ 2 + (items[1].at[2] - rest1[2]) ^ 2)
Check(Near(lifted, STACK.hover, 1e-3), "the cards did not rise under the mouse: " .. lifted)
Check(items[1].at[2] < rest1[2], "the cards not up under the mouse")
stack.scripts.OnLeave(stack)
for _ = 1, 30 do Tick(1 / 60) end
Check(Near(items[1].at[1], rest1[1]) and Near(items[1].at[2], rest1[2]), "the cards not settled again")
-- A click beside the fan puts them back.
Page.Fan(host, true, true)
host.catcher.scripts.OnMouseDown(host.catcher)
Eq(host.fanned, false, "a click beside the fan did not put the cards back")
Page.Fan(host, false, true)
-- Laid again while fanned (the screen changed): still fanned, where the
-- new fit puts them.
Page.Fan(host, true, true)
UIParent.width = 1920
mock.fire("DISPLAY_SIZE_CHANGED")
Eq(host.fanned, true, "laid again, the fan closed")
for _, item in ipairs(host.fanItems) do
    Eq(item.e, 1, "laid again, a card not fanned")
    Check(Near(item.at[1], item.fan[1]) and Near(item.at[2], item.fan[2]), "laid again, a card not where the new fit puts it")
end
-- Put away fanned: the next run opens with the cards in their stack.
Page.Close(true)
Eq(host.fanned, false, "the fan left open with the spread put away")
ns.UI.OpenVisit(RFK.id, G)
for _, item in ipairs(host.fanItems) do Eq(item.e, 0, "a card fanned as the run came out again") end
UIParent.width = 1365

-- Lifted under the mouse, fanned, laid back after; its shadow on the
-- world lifted with it.
Page.Fan(host, true, true)
local back = host.cards[5]
local was = back:GetFrameLevel()
local L = ns.UI.Light.CAST.layers
local before_ = back.grounds[L].recorded.points[1].args[4]
back.scripts.OnEnter(back)
for i = 1, 4 do Check(back:GetFrameLevel() > host.cards[i]:GetFrameLevel(), "a card not lifted over the others") end
Check(back.add:GetFrameLevel() > back:GetFrameLevel(), "the way in under its card")
local lifted_ = back.grounds[L].recorded.points[1].args[4]
Check(lifted_ < before_, "the card's shadow on the world not lifted with it")
back.scripts.OnLeave(back)
Eq(back:GetFrameLevel(), was, "a card not laid back")
Check(Near(back.grounds[L].recorded.points[1].args[4], before_), "the card's shadow not laid back")
-- Put back while lifted: laid down first.
back.scripts.OnEnter(back)
Page.Fan(host, false, true)
Check(not back.lifted, "a card left lifted in the stack")
-- Over the sheet and every strip.
Page.Fan(host, true, true)
Check(host.cardTable:GetFrameLevel() > map.sheet:GetFrameLevel(), "the cards under the sheet")
for _, e in ipairs(map.noteStrips) do
    Check(host.cardTable:GetFrameLevel() > e.strip:GetFrameLevel(), "the cards under a strip")
end
Page.Close(true)

--------------------------------------------------------------------------
Section("a raid: five cards and a deck in the stack, the deck at the top of the fan, spread over the map and gathered")

local raid = { { guid = G, first = "Tester" }, { guid = ME } }
for i = 1, 10 do
    local guid = ("Player-0000-7E57E6%02d"):format(i)
    raid[#raid + 1] = { guid = guid, first = "Raider" .. string.char(64 + i) }
    ns.Characters.Observe(guid, { first = "Raider" .. string.char(64 + i), class = "MAGE", race = "Human",
        level = 60, sex = 2, time = mock.now - 3600 })
end
local big = ns.Instances.New({ instanceID = 47, name = "Razorfen Kraul", instanceType = "raid", members = raid,
    bossesKilled = { "Roogug" }, startedAt = mock.now - 3000, endedAt = mock.now - 1000, test = true })
Lay(1365, 768, 682.5)
Page.Close(true)
ns.UI.OpenVisit(big.id, G)
Check(host:IsShown(), "the raid not out")
Eq(#host.cards, DECK.most, "a raid's cards")
Eq(#host.rest, 12 - DECK.most, "a raid's deck")
Eq(#host.fanItems, DECK.most + 1, "no place for the deck")
local deck = host.deck
Check(deck:IsShown(), "no deck")
Eq(host.fanItems[#host.fanItems].frame, deck, "the deck not last")
-- In the stack, under every card; fanned, at the top, its band showing.
for _, card in ipairs(host.cards) do
    Check(card:GetFrameLevel() > deck:GetFrameLevel(), "the deck over a card")
end
Eq(deck.recorded.calls.EnableMouse[1], false, "the deck in the stack takes the mouse")
for _, screen in ipairs({ { 1365, 768 }, { 1920, 1080 }, { 1024, 768 } }) do
    UIParent.width, UIParent.height = screen[1], screen[2]
    bookAt = { screen[1] / 2, screen[2] / 2 }
    Page.Close(true)
    ns.UI.OpenVisit(big.id, G)
    Page.Fan(host, true, true)
    local items_ = host.fanItems
    local top, under = items_[#items_], items_[#items_ - 1]
    Check(top.fan[2] < under.fan[2], "the deck not at the top of the fan")
    Check(Near(under.fan[2] - top.fan[2], FAN.deck * CARD.h * host.fanPlan.k, 1)
        or under.fan[2] - top.fan[2] > FAN.deck * CARD.h * host.fanPlan.k, "the deck's band hidden")
    Check(deck:GetFrameLevel() < under.frame:GetFrameLevel(), "the deck over the card under it")
    for _, c in ipairs(Now(top)) do
        local X, Y = Screen(c, screen[1], screen[2])
        Check(X >= 0 and X <= screen[1] and Y >= 0 and Y <= screen[2], "the deck off the screen: " .. screen[1])
    end
    Eq(deck.recorded.calls.EnableMouse[1], true, "the fanned deck takes no mouse")
end
Lay(1365, 768, 682.5)
Page.Close(true)
ns.UI.OpenVisit(big.id, G)
Eq(deck.words:GetText(), "and 7 more", "the deck's band")
Eq(host.cards[1].person.guid, G, "the page's person not in front of a raid's")
Page.Fan(host, true, true)
deck.scripts.OnClick(deck)
Eq(host.spreadOut, true, "the deck did not spread")
Check(host.gather:IsShown(), "nothing to click beside the spread deck")
local shown = 0
for _, card in ipairs(host.gridCards) do
    if card:IsShown() then
        shown = shown + 1
        Check(card:GetFrameLevel() > host.cards[1]:GetFrameLevel() + CARD.raise, "a spread card under the fan")
        Check(card:GetFrameLevel() > host.gather:GetFrameLevel(), "a spread card under the click beside it")
        Check(host.gather:GetFrameLevel() > host.cards[1]:GetFrameLevel(), "the click beside the spread deck under the fan")
        -- On the map.
        local k = card.scaleK
        local X0, Y0 = map.K.Screen(0, 0)
        local X1, Y1 = map.K.Screen(map.w, map.h)
        local x, y = card.cx * k, -card.cy * k
        Check(x >= math.min(X0, X1) and x <= math.max(X0, X1) and y >= math.min(Y0, Y1) and y <= math.max(Y0, Y1),
            "a spread card off the map")
    end
end
Eq(shown, 7, "the spread deck's cards")
Check(host.gridScale <= 1 and host.gridScale > 0.3, "the spread cards' size: " .. host.gridScale)
host.gather.scripts.OnMouseDown(host.gather)
Eq(host.spreadOut, nil, "the deck not gathered")
Check(deck:IsShown() and not host.gather:IsShown(), "the deck not back")
for _, card in ipairs(host.gridCards) do Check(not card:IsShown(), "a spread card left out") end
Eq(host.fanned, true, "gathering the deck closed the fan")
-- The fan put back gathers a spread deck with it.
deck.scripts.OnClick(deck)
Page.Fan(host, false, true)
Eq(host.spreadOut, nil, "the deck left spread with the fan put back")
for _, card in ipairs(host.gridCards) do Check(not card:IsShown(), "a spread card left out with the fan put back") end
Page.Close(true)
Check(not deck:IsShown() or not host:IsShown(), "the deck left out")
ns.Instances.Remove(big.id)

SlashCmdList.SOCIALDIARY("testdata remove")
ns.UI.CloseJournal()

--------------------------------------------------------------------------
Section("a snagged fact names whom it was snagged from as the strips do")

local W = ns.UI.DungeonPage.Words
local fake = { me = ns.ownGUID, members = {} }
local fact = { kind = "snagged", item = "[Invented Band]" }
Eq(W.Fact(fact, fake), ("snagged %s from %s"):format(ns.Style.Inkify("[Invented Band]"), W.Whose(fake, fake.me)),
    "the card says it as the strip's Whose does")
Check(W.Fact(fact):find("from you$") ~= nil, "without a visit, 'you'")
