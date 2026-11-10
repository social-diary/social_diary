-- Firsts found's words (JRN-24): a first in a sentence, the level's prose
-- (Text.RegisterLines, UI/Journey/Text/Prose.lua), the plates' caption words
-- (Text.RegisterCaption), the pouch's tooltip (Mark.lua), the card's
-- heading and the line under its item (Card.lua), and a giver's words on
-- their margin note (Firsts.PERSON). Copy changes go through the
-- copywriter skill, as every player-read word does.

local addonName, ns = ...

local Firsts = ns.Firsts
local Text = ns.UI.JourneyText
local Capital, MapName, Who, Day, Glue = Text.Capital, Text.MapName, Text.Who, Text.Day, Text.Glue
local L, Fmt = ns.L, ns.Fmt
-- A locale's own grammar (Locales/Locale.lua): FirstsHeading, where a
-- locale has replaced it.
local G = ns.Locale.grammar

-- What each first is called: on a plate ("a first bag") and in a sentence
-- ("your first bag"), whole, as a translation's article goes with its noun.
local PLATE = { bag = L["a first bag"], shoulder = L["first shoulders"], uncommon = L["a first green"],
    rare = L["a first blue"], epic = L["a first epic"] }
local YOURS = { bag = L["your first bag"], shoulder = L["your first shoulders"], uncommon = L["your first green"],
    rare = L["your first blue"], epic = L["your first epic"] }

local function Words(kind)
    return PLATE[kind] or L["a first find"], YOURS[kind] or L["your first find"]
end
Firsts.Words = Words

-- The item's name, out of its link.
local function ItemName(link)
    return type(link) == "string" and (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")) or nil
end
Firsts.ItemName = ItemName

-- What a first's item is called: as the player typed it (Core/Custom.lua), else
-- out of its link.
local function Name(rec)
    return rec and (rec.name or ItemName(rec.link)) or nil
end
Firsts.Name = Name

-- A first found card's heading (Card.lua), in the diary's hand:
-- "Your first green item!", "Your first bag!". `what` is one kind or a
-- list of them, for one item that was the first of several ("Your first
-- bag and first green item!", a green bag), told bag, shoulders, then by
-- quality. `short` drops "item" for a narrow margin ("Your first green!").
-- The words below are the English grammar of it: a locale writes its own
-- whole (ns.Locale.grammar.FirstsHeading, given the sorted kinds and `short`).
local HEADING = { bag = "bag", shoulder = "shoulders", uncommon = "green", rare = "blue", epic = "epic" }
local HEADING_ORDER = { bag = 1, shoulder = 2, uncommon = 3, rare = 4, epic = 5 }
function Firsts.Heading(what, short)
    local list = type(what) == "table" and { unpack(what) } or { what }
    table.sort(list, function(a, b) return (HEADING_ORDER[a] or 9) < (HEADING_ORDER[b] or 9) end)
    if G.FirstsHeading then return G.FirstsHeading(list, short) end
    local words = {}
    for i, kind in ipairs(list) do
        local word = HEADING[kind] or "find"
        local quality = HEADING_ORDER[kind] and HEADING_ORDER[kind] >= 3
        -- "item" once, at the end: "first green item", never "green item
        -- and first blue item".
        if quality and not short and i == #list then word = word .. " item" end
        words[#words + 1] = (i == 1 and "" or "first ") .. word
    end
    local text = words[1]
    if #words > 1 then
        text = table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words]
    end
    return "Your first " .. text .. "!"
end

-- The line under a first found card's item, for a gift whose giver has
-- no margin note of their own beside the plate (`named`, as
-- Text.PlateCaption takes it): "from Koko" for someone in the diary, "a
-- gift" for anyone else; nil for what was not given, or whose giver's
-- note says so already.
function Firsts.GiftLine(rec, named)
    if not rec or rec.from ~= "trade" then return nil end
    local giver = rec.guid and ns.db.characters[rec.guid] and rec.guid or nil
    if giver and named and named[giver] then return nil end
    if giver and ns.Diary.IsDiary(giver) then
        local name = Text.Short(giver)
        if name then return Fmt(L["from %s"], name) end
    end
    return L["a gift"]
end

-- Who gave a first, while the diary still knows them.
local function Giver(rec)
    return rec.from == "trade" and rec.guid and ns.db.characters[rec.guid] and rec.guid or nil
end

-- One first in a sentence, how it came and where: "Found your first
-- green in Mulgore: Wolfskin Bracers." `kind`, `rec` as Firsts.List
-- gives them.
function Firsts.Sentence(kind, rec)
    local _, yours = Words(kind)
    local zone = MapName(rec.mapID)
    zone = zone and ns.ZoneIn(rec.mapID, zone)
    local text
    if rec.from == "trade" then
        local giver = Giver(rec)
        text = giver and Fmt(L["%1$s gave you %2$s"], Who(giver), yours) or Capital(Fmt(L["%s was a gift"], yours))
    elseif rec.from == "quest" then
        text = Fmt(L["A quest gave you %s"], yours)
    elseif rec.from == "vendor" then
        text = zone and Fmt(L["Bought %1$s %2$s##zone"], yours, zone) or Fmt(L["Bought %s"], yours)
    elseif rec.from == "craft" then
        text = zone and Fmt(L["Made %1$s %2$s##zone"], yours, zone) or Fmt(L["Made %s"], yours)
    elseif rec.from == "mail" then
        text = Capital(Fmt(L["%s came by mail"], yours))
    else
        text = zone and Fmt(L["Found %1$s %2$s##zone"], yours, zone) or Fmt(L["Found %s"], yours)
    end
    local name = Name(rec)
    if name then return Fmt(L["%1$s: %2$s."], text, name) end
    return Fmt(L["%s."], text)
end

-- The entry's firsts (e.finds, the recap's), a sentence each: its
-- paragraph in the level's prose.
function Firsts.Lines(e)
    local lines = {}
    for _, f in ipairs(e.finds or {}) do lines[#lines + 1] = Firsts.Sentence(f.kind, f.rec) end
    if #lines == 0 then return nil end
    return table.concat(lines, " ")
end

-- A first's mark on a plate, for its tooltip: the heading ("Your first
-- bag") and the line under it, the sentence without the heading's words
-- ("Small Brown Pouch, bought at level 5, 6 October"); `bare` leaves the
-- item's name out, for under the item's own tooltip (Card.lua).
-- How a first came, for its tooltip: "looted", "bought", "from Koko
-- Skybluff", "a gift"; "found" where it could not be told.
local HOW = { quest = L["a quest's reward"], vendor = L["bought"], craft = L["made by hand"], mail = L["by mail"],
    loot = L["looted"] }

local function How(rec)
    if rec.from == "trade" then
        local giver = Giver(rec)
        return giver and Fmt(L["from %s"], Who(giver)) or L["a gift"]
    end
    return HOW[rec.from] or L["found"]
end

function Firsts.Tip(m, now, bare)
    local rec = m.find or m
    local _, yours = Words(m.what or m.kind)
    local how = How(rec)
    local parts = { not bare and Name(rec) or nil, how,
        (rec.level and Fmt(L["at level %d"], rec.level) or nil), Day(rec.t, now) }
    local list = {}
    for i = 1, 4 do
        if parts[i] then list[#list + 1] = parts[i] end
    end
    return Capital(yours), ns.UI.TimelineText.Join(list)
end

-- The firsts on a tooltip's title, in the order given: "Your first bag",
-- "Your first bag and first green" (a green bag), "Your first blue, first
-- bag and first green". As the card's heading says them (Firsts.Heading)
-- but quiet: no "item", no exclamation mark.
-- The firsts after the first one, in the title's list ("... and first
-- green"), whole as Words' are.
local AFTER = { bag = L["first bag"], shoulder = L["first shoulders"], uncommon = L["first green"],
    rare = L["first blue"], epic = L["first epic"] }

function Firsts.TipHeading(whats)
    local words = {}
    for i, kind in ipairs(whats) do
        if i == 1 then
            local _, yours = Words(kind)
            words[i] = yours
        else
            words[i] = AFTER[kind] or L["first find"]
        end
    end
    return Capital(Text.List(words) or select(2, Words(nil)))
end

-- A tooltip's last line for everything under one mark, as the core says
-- it for every mark (Text.Foot, UI/Journey/Text/Tips.lua): when, from the
-- first to the last ("Today at 12:47", "Today from 12:47 to 13:20"), then
-- the level or levels ("Level 20", "Levels 19 to 20"). `list` is records
-- with `t` and `level`.
local function Foot(list, now)
    local a = {}
    for _, r in ipairs(list) do
        if r.t then a.from, a.to = math.min(a.from or r.t, r.t), math.max(a.to or r.t, r.t) end
        if r.level then
            a.levelFrom, a.levelTo = math.min(a.levelFrom or r.level, r.level), math.max(a.levelTo or r.level, r.level)
        end
    end
    return Text.Foot(a, now)
end

-- The firsts of `list` (moments, or { what, find }) an item each, in the
-- order given: { rec, whats }. A green bag is two firsts and one item.
local ORDER = { bag = 1, shoulder = 2, uncommon = 3, rare = 4, epic = 5 }

local function ByItem(list)
    local items, by = {}, {}
    for _, m in ipairs(list) do
        local rec = m.find or m
        local key = rec.link or rec
        local item = by[key]
        if not item then
            item = { rec = rec, whats = {} }
            by[key] = item
            items[#items + 1] = item
        end
        item.whats[#item.whats + 1] = m.what or m.kind
    end
    for _, item in ipairs(items) do
        table.sort(item.whats, function(a, b) return (ORDER[a] or 9) < (ORDER[b] or 9) end)
    end
    return items
end

-- What an item's line says: its name and how it came, "Small Brown
-- Pouch, looted"; `bare` (under the item's own tooltip, which names it)
-- how alone.
local function ItemLine(rec, bare)
    local name = not bare and Name(rec)
    return name and Fmt(L["%1$s, %2$s"], name, How(rec)) or Capital(How(rec))
end

-- The tooltip of a pouch (Mark.lua's `tips`) and of a find card's slip
-- (Card.lua): every first on it told once together (9 Nov 2026; before,
-- each first's Firsts.Tip was stacked under the last, so a green bag said
-- its name, how it came and when twice). The firsts it was, the best
-- item's first (`list` comes sorted so); then each item once, its name
-- and how it came (more than three, their names on one line); then when
-- and at what level. `bare` leaves the item's name out where its own
-- tooltip names it (one item: the slip's box).
function Firsts.Tips(list, now, bare)
    local items, whats, recs, lines = ByItem(list), {}, {}, {}
    for _, item in ipairs(items) do
        for _, what in ipairs(item.whats) do whats[#whats + 1] = what end
        recs[#recs + 1] = item.rec
    end
    if #items <= 3 then
        for _, item in ipairs(items) do lines[#lines + 1] = ItemLine(item.rec, bare and #items == 1) end
    else
        local names = {}
        for _, item in ipairs(items) do names[#names + 1] = Name(item.rec) or L["an item"] end
        lines[1] = Text.List(names)
    end
    lines[#lines + 1] = Foot(recs, now)
    return Firsts.TipHeading(whats), lines
end

-- A gift is its giver's moment too (Kind.lua's moment: `person`): on
-- their margin note it is something done together (tier 1, as time
-- together is), and the first thing said under their name, "gave you
-- your first blue" (UI/Journey/Text/Margin.lua's MarginWhat), held together by
-- no-break spaces as the note's other phrases are.
Firsts.PERSON = {
    tier = 1,
    say = function(m)
        local _, yours = Words(m.what)
        return Fmt(L["gave you %s"], Glue(yours))
    end,
}

--------------------------------------------------------------------------
-- The level's prose
--------------------------------------------------------------------------

-- The firsts found, a sentence each, after who was there (the diary's
-- people, 30) and before a chain's finales (50).
Text.RegisterLines("find", { at = 40, lines = function(e) return Firsts.Lines(e) end })

--------------------------------------------------------------------------
-- The plates' caption words
--------------------------------------------------------------------------

-- Firsts found, told beside the plate on their cards (Card.lua).
-- `said.find` is the firsts whose cards are drawn beside the plate,
-- [moment] = true (or [its record] = true, as a plate's marks and its
-- moments are not the same tables): their card shows the item and says
-- who gave it, so the words only name the first ("A first green."); one
-- with no card keeps its item's name here ("A first green: Wolfskin
-- Bracers."), unless a death is told with it. A first in a few words: "a
-- first bag", "a first bag from Koko" when Koko gave it and no margin
-- note of hers says so already. They lead after the people (20), and are
-- the first of the tail (10): ", a first bag, and two deaths".
do
    local List, Short = Text.List, Text.Short
    local function Shown(m, c)
        local shown = c.said.find or {}
        return shown[m] or (m.find ~= nil and shown[m.find]) or false
    end
    -- The second value: whether who gave it is said, here or on her note.
    local function Found(m, c)
        local text = Words(m.what)
        local giver = m.gift and Giver(m.find or m)
        if m.gift and Shown(m, c) then return text, true end
        if giver and c.named[giver] then return text, true end
        if giver and ns.Diary.IsDiary(giver) then return Fmt(L["%1$s from %2$s"], text, Short(giver)), true end
        return text, false
    end
    Text.RegisterCaption("find", {
        moment = "find",
        lead = { at = 20, say = function(finds, c)
            local m = finds[1]
            local name = #finds == 1 and not c.of.death and not m.gift and not Shown(m, c)
                and Name(m.find or m)
            local words = {}
            for _, f in ipairs(finds) do words[#words + 1] = (Found(f, c)) end
            local text = Capital(List(words))
            if name then text = Fmt(L["%1$s: %2$s"], text, name) end
            if #finds == 1 and m.gift and not select(2, Found(m, c)) then text = Fmt(L["%s, a gift"], text) end
            return text
        end },
        tail = { at = 10, say = function(finds, c)
            local words = {}
            for _, m in ipairs(finds) do words[#words + 1] = (Found(m, c)) end
            return words
        end },
    })
end
