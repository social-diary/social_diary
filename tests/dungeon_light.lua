-- One light for the table spread (UI/Paper/Light.lua, the house light the
-- map sheet obeyed first; the heights in UI/Dungeon/Heights.lua): every
-- shadow cast from its height, further out and paler the higher it is,
-- darker and wider on the game world under the spread than on paper,
-- falling on what is really under it (the sheet, the card beneath, or the
-- world through the sheet's ground layer); cards, strips, the deck and the
-- bookmark lit across as the sheet's facets are. Where things lie is
-- tests/dungeon_spread.lua's and tests/dungeon_cards.lua's.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Page = ns.UI.DungeonPage
local Light = ns.UI.Light
local LIFT, GROUND, CAST, SHEEN = Light.LIFT, Light.GROUND, Light.CAST, Light.SHEEN
local H = Page.HEIGHT

local function Near(a, b, e) return math.abs(a - b) < (e or 1e-6) end
-- What a texture was last painted: its gradient's ends ({ r, g, b, a }
-- each), or its flat colour as both.
local function Paint(t)
    local c = t.recorded.calls
    local g, flat = c.SetGradient, c.SetColorTexture
    if g and (not flat or g.seq > flat.seq) then return g[2], g[3], g[1] end
    if flat then
        local f = { r = flat[1], g = flat[2], b = flat[3], a = flat[4] }
        return f, f
    end
end
-- Every widget made on `parent`.
local function On(parent)
    local out = {}
    for _, w in ipairs(mock.frames) do
        if w.parent == parent then out[#out + 1] = w end
    end
    return out
end
-- The relative frame a region is anchored to.
local function Anchor(t) return t.recorded.points[1] and t.recorded.points[1].args[1] end

--------------------------------------------------------------------------
Section("the house light: the sheet's own fall, higher further out and paler")

-- The numbers the map sheet was tuned with in the client, unchanged.
for k, v in pairs({ base = 1, gain = 0.22, alpha = 0.32, fade = 0.04, reach = 1.8, extra = 1.5, soft = 0.35 }) do
    Eq(LIFT[k], v, "the sheet's fall changed: " .. k)
end
local off, alpha = Light.Fall(0)
Check(Near(off, 1) and Near(alpha, 0.32), "flat on what it lies on: not close and dark")
local lastOff, lastAlpha = -1, 1
for h = 0, 12, 2 do
    local o, a = Light.Fall(h)
    local so, sa = Light.Fall(h, true)
    Check(o > lastOff and a < lastAlpha, "higher, not further out and paler: " .. h)
    Check(so > o and sa < a, "the soft edge not further and paler than the core: " .. h)
    lastOff, lastAlpha = o, a
end
-- On the world: darker, black, its soft edge wider.
local _, paper = Light.Fall(2)
local _, world = Light.Fall(2, false, GROUND.world)
Check(Near(world, paper * GROUND.world.strength), "the world's shadow not the paper's, darker")
Check(world >= 0.5, "a shadow on the world too faint to read: " .. world)
Check(select(1, Light.Fall(2, true, GROUND.world)) > select(1, Light.Fall(2, true)), "the world's edge not wider")
local C = GROUND.world.colour
Check(C[1] + C[2] + C[3] < 0.1, "the world's shadow not black")
-- An outline's stack: as dark as the core where all lie, as the soft edge
-- where only the last reaches, each further out and grown more.
for _, ground in ipairs({ "paper", "world" }) do
    for _, h in ipairs({ 1, 2.5, 6 }) do
        local layers = Light.Cast(h, ground)
        Eq(#layers, CAST.layers, "the shadow's layers")
        local left = 1
        for i, L in ipairs(layers) do
            left = left * (1 - L[4])
            Check(L[4] > 0 and L[4] < 1, "a layer's alpha: " .. L[4])
            if i > 1 then Check(L[1] > layers[i - 1][1] and L[3] > layers[i - 1][3], "a layer not further out") end
        end
        local _, core = Light.Fall(h, false, GROUND[ground])
        local _, soft = Light.Fall(h, true, GROUND[ground])
        Check(Near(1 - left, core), ground .. "'s stack not as dark as the core: " .. (1 - left) .. " " .. core)
        Check(Near(layers[#layers][4], soft), ground .. "'s last layer not the soft edge")
        Eq(layers[1][3], 0, "the contact shadow grown")
    end
end
Check(Light.Cast(2, "world")[1][4] > Light.Cast(2, "paper")[1][4], "the world's stack not darker")
-- The light across something flat: as painted at its top left, darker
-- toward its bottom right, inside the sheet's facets' range.
Check(SHEEN.top <= 1 and SHEEN.bottom < SHEEN.top and SHEEN.right > SHEEN.left, "the sheen not lit from the top left")
Check(SHEEN.bottom * (1 - SHEEN.right) >= 0.86, "the sheen darker than the folds' darkest facet")

--------------------------------------------------------------------------
-- The test data's run out on the table.
mock.now = 1795000000
SlashCmdList.SOCIALDIARY("testdata")
local G = ns.TestData.GUID
local panel = _G.SocialDiaryJournalFrame
panel.GetCenter = function() return 682.5, 384 end
UIParent.width, UIParent.height = 1365, 768
local RFK
for _, visit in ipairs(ns.Instances.For(G)) do
    if visit.instanceID == 47 and visit.endedAt > mock.now - 86400 then RFK = visit end
end
Check(RFK, "the test data's Razorfen Kraul")
ns.UI.OpenVisit(RFK.id, G)
local host = Page.Spread()
local map = host.map

--------------------------------------------------------------------------
Section("the map sheet: its shadow on the world, under everything that lies over its edge")

Check(map.ground and map.ground:GetFrameLevel() > map:GetFrameLevel()
    and map.ground:GetFrameLevel() < map.sheet:GetFrameLevel(), "the ground layer not under the sheet")
Check(host.back:GetFrameLevel() > map.ground:GetFrameLevel(), "the bookmark under the ground's shadows")
local cores, darkest = 0, 0
for _, t in ipairs(On(map.sheet)) do
    if t.frameType == "Texture" and t.recorded.layer == "BACKGROUND" and t.recorded.sublevel == -7 and t.shown then
        local from, to = Paint(t)
        if from and from.a then
            cores = cores + 1
            darkest = math.max(darkest, from.a, to.a)
            Check(Near(from.r, C[1]) and Near(from.g, C[2]), "the sheet's shadow not the world's colour")
        end
    end
end
Check(cores > 0, "no bent shadow under the sheet")
Check(darkest > LIFT.alpha * 1.25 and darkest <= 0.9, "the sheet's shadow not the world's: " .. darkest)

--------------------------------------------------------------------------
Section("strips: lit across, a tight shadow on the sheet, a darker wider one on the world under it")

Check(#map.noteStrips > 0, "no strips on the test run")
local contact, soft, under = Page.StripShadows(false, map.ground)
local tackedContact = Page.StripShadows(true)
Check(tackedContact[1] > contact[1] and tackedContact[3] < contact[3], "a tacked strip not standing higher")
local near, dark = Light.Fall(H.strip)
Check(Near(contact[1], near) and Near(contact[3], dark), "a taped strip's shadow not from its height")
for _, e in ipairs(map.noteStrips) do
    local strip = e.strip
    Check(strip.sheen:IsShown() and strip.sheen.recorded.calls.SetGradient, "a strip not lit across")
    local from = Paint(strip.paper)
    Check(from and from.r < strip:Paper()[1], "a strip's paper not shaded toward its foot")
    -- Its contact shadow from its height over the sheet.
    local want = Page.StripShadows(strip.tacked)
    Check(Near(strip.contact[1], want[1]) and Near(strip.contact[3], want[3]), "a strip's shadow not from its height")
    -- On the world: under the sheet, on the strip, in the world's shadow.
    local n = 0
    for _, g in ipairs(strip.grounds) do
        if g.shown then
            n = n + 1
            Eq(g.parent, map.ground, "a strip's shadow on the world not on the ground layer")
            Eq(Anchor(g), strip, "a strip's shadow on the world not where the strip lies")
            local f = Paint(g)
            Check(Near(f.r, C[1]), "a strip's shadow on the world not the world's")
        end
    end
    Eq(n, CAST.layers, "a strip's shadow on the world")
    local left = 1
    for i = 1, CAST.layers do left = left * (1 - Paint(strip.grounds[i]).a) end
    Check(1 - left > strip.contact[3], "the world's shadow not darker than the paper's")
end
-- Hidden with the strip.
local s1 = map.noteStrips[1].strip
s1:Hide()
for _, g in ipairs(s1.grounds) do Check(not g.shown, "a strip's shadow left on the world") end
s1:Show()

--------------------------------------------------------------------------
Section("cards: lit across, shadowed on what is under them and on the world, lying in the stack or fanned")

Check(#host.cards >= 2, "too few cards on the test run")
-- The alphas of a card's shadow on the world, in order.
local function GroundAlphas(card)
    local out = {}
    for i = 1, card.grounds.used do
        local c = card.grounds[i].recorded.calls
        local v, f = c.SetVertexColor, c.SetColorTexture
        out[i] = (v and (not f or v.seq > f.seq)) and v[4] or f[4]
    end
    return out
end
-- In the stack: lying on the world, a few cards thick, each casting its
-- shadow there from the stack's height (the sheet covers what falls on it).
for _, card in ipairs(host.cards) do
    local label = card.person.first or "?"
    Eq(card.height, H.stack, label .. "'s card in the stack not lying low")
    Check(card.groundFrame:IsShown(), label .. "'s card in the stack casts no shadow on the world")
    local want = Page.Cast(H.stack, "world")
    local got = GroundAlphas(card)
    for i = 1, #want do Check(Near(got[i], want[i][4]), label .. "'s shadow in the stack not from its height") end
end
-- Fanned: held up over the map, all at one height.
Page.Fan(host, true, true)
for _, card in ipairs(host.cards) do Eq(card.height, H.fan, "a fanned card not held up") end
local front = host.cards[1]
for _, card in ipairs(host.cards) do
    local label = card.person.first or "?"
    -- On the card or the sheet under it, from its height over that.
    local layers = Page.Cast(H.onCard, "paper")
    local under_, lit = 0, false
    for i = 1, card.textures.used do
        local t = card.textures[i]
        local r = t.recorded
        if r.sublevel == -8 and (r.layer == "BORDER" or r.layer == "BACKGROUND") then under_ = under_ + 1 end
        if (r.layer == "BORDER" and r.sublevel == -6) or (r.layer == "BACKGROUND" and r.sublevel == -4) then
            lit = lit or r.calls.SetGradient ~= nil
        end
    end
    Check(under_ >= #layers, label .. "'s card casts no shadow on what is under it")
    Check(lit, label .. "'s card not lit across")
    -- On the world, from its height over that: on the sheet's ground
    -- layer, on a frame that lies where the card lies, as big as it is.
    local want = Page.Cast(card.height, "world")
    Check(card.groundFrame:IsShown(), label .. "'s fanned card casts no shadow on the world")
    Eq(card.groundFrame.parent, map.ground, label .. "'s shadow on the world not on the ground layer")
    Eq(Anchor(card.groundFrame), card, label .. "'s shadow on the world not where the card lies")
    Eq(card.groundFrame:GetScale(), card:GetScale(), label .. "'s shadow on the world not the card's size")
    Check(card.grounds.used >= #want, label .. "'s card casts no shadow on the world")
    local got = GroundAlphas(card)
    for i = 1, #want do
        local g = card.grounds[i]
        Eq(g.parent, card.groundFrame, label .. "'s shadow on the world not on its frame")
        Eq(Anchor(g), card.groundFrame, label .. "'s shadow on the world not where the card lies")
        Check(Near(got[i], want[i][4]), label .. "'s shadow on the world not from its height: " .. tostring(got[i]))
    end
    -- A slip under its foot: its own shadow on the world.
    if card.jot and card.jot.slip then
        Eq(card.grounds.used, 2 * #want, label .. "'s slip casts no shadow on the world")
    end
end
-- Picked up, higher: its shadow on the world falls further out and paler.
local lying = front.grounds[CAST.layers].recorded.points[1].args[3]
front.scripts.OnEnter(front)
Check(front.grounds[CAST.layers].recorded.points[1].args[3] > lying, "a lifted card's shadow not further out")
front.scripts.OnLeave(front)
-- Gathered again: back down to the stack's height.
Page.Fan(host, false, true)
for _, card in ipairs(host.cards) do
    Eq(card.height, H.stack, "a card gathered into the stack still held up")
    local want, got = Page.Cast(H.stack, "world"), GroundAlphas(card)
    Check(Near(got[1], want[1][4]), "a gathered card's shadow not from the stack's height")
end
-- Laid flat: plain card, no light across it; its shadows stay, as the
-- sheet's do.
ns.SetSetting("flatSheets", true)
ns.UI.OpenVisit(RFK.id, G)
ns.UI.OpenVisit(RFK.id, G)
for _, card in ipairs(host.cards) do Check(card.grounds.used > 0, "a card in the stack laid flat lost its shadow") end
Page.Fan(host, true, true)
for _, card in ipairs(host.cards) do
    for i = 1, card.textures.used do
        local r = card.textures[i].recorded
        Check(not (r.layer == "BORDER" and r.sublevel == -6), "a card lit across laid flat")
    end
    Check(card.grounds.used > 0, "a card laid flat lost its shadow on the world")
end
for _, e in ipairs(map.noteStrips) do Check(not e.strip.sheen:IsShown(), "a strip lit across laid flat") end
Check(#host.back.shadows > 0, "the bookmark lost its shadow laid flat")
ns.SetSetting("flatSheets", false)
Page.Close(true)

--------------------------------------------------------------------------
Section("a raid's deck: a small stack, its shadow on the sheet and on the world")

local raid = { { guid = G, first = "Tester" }, { guid = ns.ownGUID } }
for i = 1, 10 do
    local guid = ("Player-0000-7E57E6%02d"):format(i)
    raid[#raid + 1] = { guid = guid, first = "Raider" .. string.char(64 + i) }
    ns.Characters.Observe(guid, { first = "Raider" .. string.char(64 + i), class = "MAGE", race = "Human",
        level = 60, sex = 2, time = mock.now - 3600 })
end
local big = ns.Instances.New({ instanceID = 47, name = "Razorfen Kraul", instanceType = "raid", members = raid,
    bossesKilled = { "Roogug" }, startedAt = mock.now - 3000, endedAt = mock.now - 1000, test = true })
ns.UI.OpenVisit(big.id, G)
local deck = host.deck
Check(deck:IsShown(), "no deck")
-- At the bottom of the stack: its shadow on the world from the stack's height.
Check(deck.groundFrame:IsShown(), "the deck in the stack casts no shadow on the world")
Eq(deck.height, H.stack, "the deck in the stack not lying low")
local lowAt = deck.grounds[CAST.layers].recorded.points[1].args[3]
Page.Fan(host, true, true)
Check(deck.groundFrame:IsShown(), "the fanned deck casts no shadow on the world")
Eq(deck.height, H.fan, "the fanned deck not held up")
Eq(deck.groundFrame.parent, map.ground, "the deck's shadow on the world not on the ground layer")
Eq(Anchor(deck.groundFrame), deck, "the deck's shadow on the world not where it lies")
for k = 1, CAST.layers do
    local sh, g = deck.shadows[k], deck.grounds[k]
    Check(sh.shown and g.shown, "the deck's shadows not out")
    Eq(g.parent, deck.groundFrame, "the deck's shadow on the world not on its frame")
end
local inner = deck.shadows[CAST.layers].recorded.points[1].args[3]
local outer = deck.grounds[CAST.layers].recorded.points[1].args[3]
Check(outer > inner, "the deck's shadow on the world not further out than on the sheet")
Check(outer > lowAt, "the fanned deck's shadow not further out than in the stack")
Check(deck.shade.shown and deck.shade.recorded.calls.SetGradient, "the deck's top card not lit across")
Page.Close(true)
deck:Hide()
Check(not deck.groundFrame:IsShown(), "the deck's shadow left on the world")
ns.Instances.Remove(big.id)

--------------------------------------------------------------------------
Section("the bookmark: on the world, lit, picked up under the mouse")

ns.UI.OpenVisit(RFK.id, G)
local mark = host.back
Eq(#mark.shadows, CAST.layers, "the bookmark's shadow")
local lyingAlpha = {}
for i, t in ipairs(mark.shadows) do
    local f = Paint(t)
    Check(Near(f.r, C[1]), "the bookmark's shadow not the world's")
    lyingAlpha[i] = f.a
end
local want = Page.Cast(H.bookmark, "world")
for i = 1, #want do Check(Near(lyingAlpha[i], want[i][4]), "the bookmark's shadow not from its height") end
Check(mark.paper.recorded.calls.SetGradient, "the bookmark's paper not lit across")
local lyingAt = mark.shadows[CAST.layers].recorded.points[1].args[3]
mark.scripts.OnEnter(mark)
local liftedAt = mark.shadows[CAST.layers].recorded.points[1].args[3]
Check(liftedAt > lyingAt, "picked up, the bookmark's shadow not further out")
Check(Paint(mark.shadows[1]).a < lyingAlpha[1], "picked up, the bookmark's shadow not paler")
mark.scripts.OnLeave(mark)
Page.Close(true)

SlashCmdList.SOCIALDIARY("testdata remove")
ns.UI.CloseJournal()
