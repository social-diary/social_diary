-- Upgrades' words: the card's heading (how the item came), the slot's
-- phrase (the small note and the caption), the tooltips, a giver's words
-- on their margin note (Upgrades.PERSON), the caption's words and the
-- level's sentences. What is said where is the signed proposal's
-- (.claude/ui-proposal/upgrades.md, "Strings"). Copy changes go through
-- the copywriter skill, as every player-read word does.
--
-- No item level is ever said (the user, 15 Nov: "no ilvl").
--
-- Whole phrases, never glued from parts: a translation's article goes
-- with its noun.

local addonName, ns = ...

local Upgrades = ns.Upgrades
local Text = ns.UI.JourneyText
local Capital, Who, Day, Glue, Short, NUMBER = Text.Capital, Text.Who, Text.Day, Text.Glue, Text.Short, Text.NUMBER
local L, Fmt = ns.L, ns.Fmt

-- The item's name, out of its link.
local function ItemName(link)
    return type(link) == "string" and (link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")) or nil
end
Upgrades.ItemName = ItemName

-- What an upgrade's item is called, and what it took the place of.
local function Name(rec)
    return rec and ItemName(rec.link) or nil
end
Upgrades.Name = Name

local function WasName(rec)
    return rec and rec.was and ItemName(rec.was.link) or nil
end
Upgrades.WasName = WasName

-- Who gave an upgrade, while the diary still knows them.
local function Giver(rec)
    return rec.from == "trade" and rec.guid and ns.db.characters[rec.guid] and rec.guid or nil
end
Upgrades.Giver = Giver

--------------------------------------------------------------------------
-- The card's heading
--------------------------------------------------------------------------

-- How the item came, in the diary's hand, over the card. `short` is the
-- narrow form, tried where the full one does not fit. A gift always names
-- its giver (the user, 15 Nov: "always name them"), while the diary knows
-- them; nothing said how it came, and it is only "newly worn". The diary
-- speaks to "you", so what the player made is "yourself", never "myself".
local HEADING = { loot = L["Looted"], quest = L["A quest's reward"], vendor = L["Bought"],
    craft = L["Made it yourself"], mail = L["Came by mail"] }
local HEADING_SHORT = { quest = L["From a quest"], craft = L["Made by hand"], mail = L["By mail"] }

function Upgrades.Heading(rec, short)
    if rec.from == "trade" then
        local giver = Giver(rec)
        return giver and Fmt(L["From %s"], Who(giver)) or L["A gift"]
    end
    return short and HEADING_SHORT[rec.from] or HEADING[rec.from] or L["Newly worn"]
end

--------------------------------------------------------------------------
-- The slot's phrase
--------------------------------------------------------------------------

-- What was put on, by its slot: the small note's line for one piece, and
-- the caption's word ("new gloves": the user, 15 Nov). The off hand and
-- the ranged slot say what the item is where the client tells. Each is
-- whole, its article with it: the giver's margin note says it after "gave
-- you" (PERSON, below).
local SLOT = {
    [1] = L["a new helm"], [2] = L["a new necklace"], [3] = L["new shoulders"], [5] = L["a new chest piece"],
    [6] = L["a new belt"], [7] = L["new leggings"], [8] = L["new boots"], [9] = L["new bracers"],
    [10] = L["new gloves"], [11] = L["a new ring"], [12] = L["a new ring"], [13] = L["a new trinket"],
    [14] = L["a new trinket"], [15] = L["a new cloak"], [16] = L["a new weapon"], [17] = L["a new off-hand piece"],
    [18] = L["a new ranged weapon"],
}
-- The client's numbers: Enum.ItemClass.Weapon and its wand.
local WEAPON, WAND = 2, 19

function Upgrades.Slot(rec)
    if (rec.slot == 17 or rec.slot == 18) and C_Item and C_Item.GetItemInfoInstant then
        local _, id = Upgrades.Key(rec.link)
        if id then
            local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
            if rec.slot == 17 and equipLoc == "INVTYPE_SHIELD" then return L["a new shield"] end
            if rec.slot == 17 and classID == WEAPON then return L["a new off-hand weapon"] end
            if rec.slot == 18 and classID == WEAPON and subclassID == WAND then return L["a new wand"] end
            -- The ranged slot is a libram's, an idol's and a totem's too.
            if rec.slot == 18 and equipLoc == "INVTYPE_RELIC" then return L["a new relic"] end
        end
    end
    return SLOT[rec.slot] or L["a new piece"]
end

-- The small note's line for two pieces or more on a plate.
function Upgrades.Pieces(n)
    return ns.Plural(n, L["a new piece|%s new pieces##plural"], NUMBER[n] or tostring(n))
end

--------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------

-- How it came, for a list, in the words a first found's tooltip says it;
-- nil where nothing said.
local HOW = { loot = L["looted"], quest = L["a quest's reward"], vendor = L["bought"], craft = L["made by hand"],
    mail = L["by mail"] }

function Upgrades.How(rec)
    if rec.from == "trade" then
        local giver = Giver(rec)
        return giver and Fmt(L["from %s"], Who(giver)) or L["a gift"]
    end
    return HOW[rec.from]
end

local function Joined(parts, n)
    local list = {}
    for i = 1, n do
        if parts[i] then list[#list + 1] = parts[i] end
    end
    return ns.UI.TimelineText.Join(list)
end

-- One upgrade's mark: the slot's phrase, and under it the item, how it
-- came, the level and the day ("Wolfskin Bracers, a quest's reward, at
-- level 11, yesterday").
function Upgrades.Tip(m, now)
    local rec = m.upgrade or m
    return Capital(Upgrades.Slot(rec)), Joined({ Name(rec), Upgrades.How(rec),
        rec.level and Fmt(L["at level %d"], rec.level) or nil, Day(rec.t, now) }, 4)
end

-- A tooltip's last line for everything under one mark, as the core says
-- it for every mark (Text.Foot).
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

-- Every upgrade on one mark, told once together: the slot's phrase (or
-- how many), a line an item, then when and at what level. `bare` leaves
-- the item's name out where its own tooltip names it.
function Upgrades.Tips(list, now, bare)
    local recs, lines = {}, {}
    for _, m in ipairs(list) do recs[#recs + 1] = m.upgrade or m end
    for _, rec in ipairs(recs) do
        local name, how = not (bare and #recs == 1) and Name(rec) or nil, Upgrades.How(rec)
        if name and how then
            lines[#lines + 1] = Fmt(L["%1$s, %2$s"], name, how)
        elseif name or how then
            lines[#lines + 1] = name or Capital(how)
        end
    end
    lines[#lines + 1] = Foot(recs, now)
    local title = #recs == 1 and Upgrades.Slot(recs[1]) or Upgrades.Pieces(#recs)
    return Capital(title), lines
end

-- The line under the new item's own tooltip: how it came, the level, the
-- day, and what it took the place of ("From Brannoc, at level 14,
-- yesterday, in place of Ragged Leather Bracers").
function Upgrades.TipLine(rec, now)
    local line = Joined({ Upgrades.How(rec), rec.level and Fmt(L["at level %d"], rec.level) or nil,
        Day(rec.t, now) }, 3)
    local was = WasName(rec)
    if was then line = Fmt(L["%1$s, in place of %2$s"], line, was) end
    return Capital(line)
end

-- The line under the old item's own tooltip.
function Upgrades.WasLine(rec, now)
    return rec.level and Fmt(L["Worn until level %d"], rec.level) or L["Worn before"]
end

--------------------------------------------------------------------------
-- The giver's margin note
--------------------------------------------------------------------------

-- A gift that was worn is its giver's moment too (Kind.lua's moment:
-- `person`): on their margin note it is something done together (tier 1,
-- as a first they gave is). It says the slot's own phrase after "gave
-- you", as a first's note does ("gave you your first blue"): "gave you
-- new gloves", "gave you a new cloak". The slot's phrase is held together
-- by no-break spaces, as the note's other phrases are.
Upgrades.PERSON = {
    tier = 1,
    say = function(m)
        return Fmt(L["gave you %s"], Glue(Upgrades.Slot(m.upgrade or m)))
    end,
}

--------------------------------------------------------------------------
-- The caption's words
--------------------------------------------------------------------------

-- One upgrade in a plate's caption, and whether who gave it is said, here
-- or on the card. With its card beside the plate (`c.said.upgrade`: the
-- moments or records whose card is drawn) the slot's phrase is enough;
-- left off, the item is named; a gift whose giver the card does not name
-- (it is left off) names them, where the diary knows them and no margin
-- note of theirs is beside the plate ("new bracers", "new bracers:
-- Wolfskin Bracers", "new bracers from Brannoc": a first found's joins).
function Upgrades.Caption(m, c)
    local rec = m.upgrade or m
    local slot = Upgrades.Slot(rec)
    local shown = c.said.upgrade or {}
    if shown[m] or shown[rec] then return slot, m.gift == true end
    local giver = Giver(rec)
    if giver and c.named[giver] then return slot, true end
    if giver and ns.Diary.IsDiary(giver) then return Fmt(L["%1$s from %2$s"], slot, Short(giver)), true end
    local name = Name(rec)
    return name and Fmt(L["%1$s: %2$s"], slot, name) or slot, false
end

-- The filler pieces in a caption's tail, counted and never named.
function Upgrades.CaptionPieces(n)
    return ns.Plural(n, L["a new piece of gear|%s new pieces of gear##plural"], NUMBER[n] or tostring(n))
end

--------------------------------------------------------------------------
-- The level's entry
--------------------------------------------------------------------------

-- The leading upgrade in a sentence: the item, and what it took the place
-- of. `first`: the item is also a first found of the entry, whose
-- paragraph (just before this one) has named it and said how it came, so
-- this only says it went on.
--
-- An item's name takes no article and no pronoun after it: the diary
-- cannot tell "the Wolfskin Bracers ... them" from "the Tattered Cloak ...
-- it", and "the" sits badly before a name that is someone's ("Thornspike's
-- Hood"). So the old item is "your ...", the new one is said bare, and a
-- gift is "a gift from ...".
--
-- An upgrade always took the place of something of its kind (Kind.lua,
-- since 16 Nov); nil, so nothing is said of it, only where that item's
-- name does not read from its link.
function Upgrades.Sentence(rec, first)
    local name, was = Name(rec) or L["a new piece"], WasName(rec)
    if not was then return nil end
    if first then return Fmt(L["Your %s made way for it."], was) end
    local giver = Giver(rec)
    if giver then return Fmt(L["Your %1$s made way for %2$s, a gift from %3$s."], was, name, Who(giver)) end
    return Fmt(L["Your %1$s made way for %2$s."], was, name)
end

-- The other pieces, counted and never named. `alone`: the entry has no
-- leading upgrade, so this is all that is said ("You put on two new
-- pieces of gear."); after the leading one, "Two more pieces of gear went
-- on besides.", which does not say "you put on" twice running.
function Upgrades.More(n, alone)
    local number = NUMBER[n] or tostring(n)
    if alone then
        return Capital(ns.Plural(n,
            L["You put on a new piece of gear.|You put on %s new pieces of gear.##plural"], number))
    end
    return Capital(ns.Plural(n,
        L["one more piece of gear went on besides.|%s more pieces of gear went on besides.##plural"], number))
end

-- The entry's paragraph, or nil: the leading upgrade's sentence, then the
-- pieces counted. Whether the leading item is a first found of the same
-- entry is read off the firsts' own entry field (e.finds, each { kind,
-- rec }) by the item's key: the one thing here that looks at another
-- feature's, one way and at call time, so the two paragraphs do not name
-- one item twice.
function Upgrades.Lines(e)
    local lead, pieces = e.upgrades and e.upgrades[1], #(e[Upgrades.PIECES] or {})
    local lines = {}
    if lead then
        local first = false
        for _, f in ipairs(e.finds or {}) do
            first = first or (f.rec ~= nil and Upgrades.Key(f.rec.link) == lead.key)
        end
        lines[#lines + 1] = Upgrades.Sentence(lead, first)
    end
    if pieces > 0 then lines[#lines + 1] = Upgrades.More(pieces, not lead) end
    if #lines == 0 then return nil end
    return table.concat(lines, " ")
end

--------------------------------------------------------------------------
-- Registered: the level's prose, the plates' caption words
--------------------------------------------------------------------------

-- The upgrades' paragraph, straight after the firsts found (40) and
-- before a chain's finales (50): what was found, then what was put on.
Text.RegisterLines("upgrade", { at = 45, lines = function(e) return Upgrades.Lines(e) end })

-- "A first found wins" (the user, 15 Nov): an upgrade whose item is a
-- first found on the same plate is left to the first's words, as its card
-- is left to the first's card (Card.lua). Read off the caption's own list
-- of the plate's finds (c.lists.find, each a moment with its record's
-- link), by the item's key: one way, as the words are written.
local function Told(rec, c)
    for _, f in ipairs(c.lists.find or {}) do
        local link = type(f) == "table" and (f.find or f).link
        if link and Upgrades.Key(link) == rec.key then return true end
    end
    return false
end

-- The moments of `list` no first found tells.
local function Own(list, c)
    local own = {}
    for _, m in ipairs(list) do
        if not Told(m.upgrade or m, c) then own[#own + 1] = m end
    end
    return own
end

-- The leading upgrade (Upgrades.Caption): `said.upgrade` is the records
-- whose card is beside the plate (Card.lua's margin note), so the words
-- say the slot alone there and name the item where the card had no room.
-- It leads straight after a first found (20), and is second in the tail
-- (15, after a first's 10): ", a first bag, new bracers, and two deaths".
Text.RegisterCaption("upgrade", {
    moment = "upgrade",
    lead = { at = 25, say = function(list, c)
        local own = Own(list, c)
        if #own == 0 then return nil end
        local words = {}
        for _, m in ipairs(own) do words[#words + 1] = (Upgrades.Caption(m, c)) end
        return Capital(Text.List(words))
    end },
    tail = { at = 15, say = function(list, c)
        local words = {}
        for _, m in ipairs(Own(list, c)) do words[#words + 1] = (Upgrades.Caption(m, c)) end
        return #words > 0 and words or nil
    end },
})

-- The other pieces, counted (Upgrades.CaptionPieces), and only where
-- their small note found no room (`said.piece`, Card.lua's): filler, in
-- the tail alone, after a duel's words (85) and before a campfire's (90),
-- the margin's order. Where saying it would run the words past their foot
-- the page leaves it out (plate.pieceTold false).
Text.RegisterCaption("piece", {
    moment = "piece",
    tail = { at = 87, say = function(list, c)
        if not c.said.piece then return nil end
        local own = Own(list, c)
        return #own > 0 and Upgrades.CaptionPieces(#own) or nil
    end },
})
