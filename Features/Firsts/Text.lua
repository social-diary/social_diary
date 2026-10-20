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

-- What each first is called: on a plate ("a first bag") and in a sentence
-- ("your first bag").
local FIND = { bag = "bag", shoulder = "shoulders", uncommon = "green", rare = "blue", epic = "epic" }

local function Words(kind)
    local word = FIND[kind] or "find"
    return (kind == "shoulder" and "first " or "a first ") .. word, "your first " .. word
end
Firsts.Words = Words

-- The item's name, out of its link.
local function ItemName(link)
    return type(link) == "string" and (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")) or nil
end
Firsts.ItemName = ItemName

-- A first found card's heading (Card.lua), in the diary's hand:
-- "Your first green item!", "Your first bag!". `what` is one kind or a
-- list of them, for one item that was the first of several ("Your first
-- bag and first green item!", a green bag), told bag, shoulders, then by
-- quality. `short` drops "item" for a narrow margin ("Your first green!").
local HEADING = { bag = "bag", shoulder = "shoulders", uncommon = "green", rare = "blue", epic = "epic" }
local HEADING_ORDER = { bag = 1, shoulder = 2, uncommon = 3, rare = 4, epic = 5 }
function Firsts.Heading(what, short)
    local list = type(what) == "table" and { unpack(what) } or { what }
    table.sort(list, function(a, b) return (HEADING_ORDER[a] or 9) < (HEADING_ORDER[b] or 9) end)
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
        if name then return "from " .. name end
    end
    return "a gift"
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
    local in_ = zone and (" in " .. zone) or ""
    local text
    if rec.from == "trade" then
        local giver = Giver(rec)
        text = giver and (Who(giver) .. " gave you " .. yours) or (Capital(yours) .. " was a gift")
    elseif rec.from == "quest" then
        text = "A quest gave you " .. yours
    elseif rec.from == "vendor" then
        text = "Bought " .. yours .. in_
    elseif rec.from == "craft" then
        text = "Made " .. yours .. in_
    elseif rec.from == "mail" then
        text = Capital(yours) .. " came by mail"
    else
        text = "Found " .. yours .. in_
    end
    local name = ItemName(rec.link)
    return text .. (name and (": " .. name) or "") .. "."
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
function Firsts.Tip(m, now, bare)
    local rec = m.find or m
    local _, yours = Words(m.what or m.kind)
    local how = ({ quest = "a quest's reward", vendor = "bought", craft = "made by hand", mail = "by mail",
        loot = "looted" })[rec.from]
    if rec.from == "trade" then
        local giver = Giver(rec)
        how = giver and ("from " .. Who(giver)) or "a gift"
    end
    local parts = { not bare and ItemName(rec.link) or nil, how or "found",
        (rec.level and ("at level " .. rec.level) or nil), Day(rec.t, now) }
    local list = {}
    for i = 1, 4 do
        if parts[i] then list[#list + 1] = parts[i] end
    end
    return Capital(yours), table.concat(list, ", ")
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
        return "gave you " .. Glue(yours)
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
        if giver and ns.Diary.IsDiary(giver) then return text .. " from " .. Short(giver), true end
        return text, false
    end
    Text.RegisterCaption("find", {
        moment = "find",
        lead = { at = 20, say = function(finds, c)
            local m = finds[1]
            local name = #finds == 1 and not c.of.death and not m.gift and not Shown(m, c)
                and ItemName((m.find or m).link)
            local words = {}
            for _, f in ipairs(finds) do words[#words + 1] = (Found(f, c)) end
            local text = Capital(List(words)) .. (name and (": " .. name) or "")
            if #finds == 1 and m.gift and not select(2, Found(m, c)) then text = text .. ", a gift" end
            return text
        end },
        tail = { at = 10, say = function(finds, c)
            local words = {}
            for _, m in ipairs(finds) do words[#words + 1] = (Found(m, c)) end
            return words
        end },
    })
end
