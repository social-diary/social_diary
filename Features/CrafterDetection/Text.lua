-- Crafter detection's words: the toast card, the toast's switch, the card
-- on the plate, the item's and the needle's tooltips, the caption's tail
-- and the level's sentences. What is said where is the signed proposal's
-- (.claude/ui-proposal/crafter-detection.md); the row's own words are in
-- Kind.lua. Copy changes go through the copywriter skill, as every
-- player-read word does. Under the words (the UI build, phase 8): the
-- readers the mark, the card and the toast share, the person's phrase,
-- and the caption's and the level's registrations. No layout here.
--
-- Decided (the user, 27 Nov 2026):
--   - "theirs" (they wear what the player made and handed them) may say
--     "made"; "yours" (the player wears what they gave or sold) says
--     "gave you" / "sold you", never "made": a seller may be a reseller.
--   - No "at auction", "in a trade" or dates on the card or the toast
--     ("data noise"): how and when go only in the tooltips.
--   - The card's hand line says what the diary saw.
--
-- An item's name takes no pronoun after it ("them" or "it": the diary
-- cannot tell a pair of boots from a cloak), as Upgrades' words do, so a
-- line says "what you made" or puts the name in. Whole sentences, never
-- glued from parts. Your Diary and the toast speak to the character
-- playing, so they say a plain "you"; the row (Kind.lua) braces it.

local addonName, ns = ...

local CrafterDetection = ns.CrafterDetection
local L, Fmt = ns.L, ns.Fmt
local Text = ns.UI.JourneyText
local Capital, Who, Short, Day, NUMBER = Text.Capital, Text.Who, Text.Short, Text.Day, Text.NUMBER

-- By direction (CrafterDetection.THEIRS / YOURS) and, for yours, by how it
-- came ("trade": gave, "auction": sold). `%s` alone is the item (its link,
-- or its name in its quality's colour); with two values or more the
-- placeholders are positional, and say which is which beside them.
CrafterDetection.WORDS = {

    ----------------------------------------------------------------------
    -- The toast card (Toast.RegisterKind's `text`)
    ----------------------------------------------------------------------
    -- The heading, rubricated over the name. The story under the name
    -- carries the item, longest first for the card to take the first that
    -- fits; `%s` is the item's name in its quality's ink. The heading says
    -- which way it went, so the story need not say "gave" again.
    toast = {
        theirs = {
            heading = L["Wearing what you made"],
            stories = { L["You made them the %s they have on."], L["You made them the %s."] },
        },
        gave = {
            heading = L["Gave you what you wear"],
            stories = { L["The %s you have on came from them."], L["The %s came from them."] },
        },
        sold = {
            heading = L["Sold you what you wear"],
            stories = { L["The %s you have on came from them."], L["The %s came from them."] },
        },
    },

    -- The kind's switch on Settings' Toasts page (Toast.RegisterKind's
    -- `label`, setting `crafterToasts`), under "Show toasts". It wraps to
    -- two lines there, as a checkbox's label may.
    label = L["Show a toast when someone wears what you made them, or you wear what they gave or sold you"],

    ----------------------------------------------------------------------
    -- The card on the plate (M and L)
    ----------------------------------------------------------------------
    -- The heading is the two names round a drawn arrow, no words. Under
    -- the item box, the hand line: what the diary saw, in the past, as the
    -- plate's level is. At L the person's name (`%s`, the short name the
    -- heading shows); at M, where the heading's names already fill the
    -- arrow row, "them" in its place. No full stop: a card's line.
    hand = {
        L = {
            theirs = L["you saw %s wear what you made"],
            gave = L["you wore what %s gave you"],
            sold = L["you wore what %s sold you"],
        },
        M = {
            theirs = L["you saw them wear what you made"],
            gave = L["you wore what they gave you"],
            sold = L["you wore what they sold you"],
        },
    },

    ----------------------------------------------------------------------
    -- Tooltips
    ----------------------------------------------------------------------
    -- The gold line under the item's own tooltip on the card: how it went
    -- and when. %1$s the person's name, %2$s the day (Text.Day: "today",
    -- "Tuesday", "12 November"); `undated` where the day is not known.
    itemLine = {
        dated = {
            theirs = { trade = L["Given to %1$s in a trade, %2$s"], auction = L["Sold to %1$s at auction, %2$s"] },
            yours = { trade = L["Given to you by %1$s in a trade, %2$s"],
                auction = L["Bought from %1$s at auction, %2$s"] },
        },
        undated = {
            theirs = { trade = L["Given to %s in a trade"], auction = L["Sold to %s at auction"] },
            yours = { trade = L["Given to you by %s in a trade"], auction = L["Bought from %s at auction"] },
        },
    },

    -- The needle mark's tooltip (Style.TipList: a title, then lines, then
    -- the core's foot with the day and level, Text.Foot). One connection:
    -- the title says who and which way (`%s` the person's name), the line
    -- the item and how it went, joined by L["%1$s, %2$s"] ("Handstitched
    -- Leather Boots, sold to them at auction"). No full stops: a title and
    -- ledger lines.
    needle = {
        title = {
            theirs = L["%s wore what you made"],
            gave = L["You wore what %s gave you"],
            sold = L["You wore what %s sold you"],
        },
        how = {
            theirs = { trade = L["given to them in a trade"], auction = L["sold to them at auction"] },
            yours = { trade = L["given to you in a trade"], auction = L["bought from them at auction"] },
        },
        -- Several connections under one needle: a title counting them
        -- (ns.Plural, `%s` a number word, Text.NUMBER), then a line each,
        -- the item and how with whom, joined by L["%1$s, %2$s"]
        -- ("Linen Boots, bought from Bramwell Pike at auction").
        several = L["A piece of gear that changed hands|%s pieces of gear that changed hands##plural"],
        howWith = {
            theirs = { trade = L["given to %s in a trade"], auction = L["sold to %s at auction"] },
            yours = { trade = L["given to you by %s in a trade"], auction = L["bought from %s at auction"] },
        },
    },

    ----------------------------------------------------------------------
    -- The caption
    ----------------------------------------------------------------------
    -- The tail where no crafter card fits on a plate opened for it (the
    -- user, 27 Nov): the lead connection only, never a count. A clause
    -- with "you" understood, as a duel's tail is ("beat Kaelin in a
    -- duel"): "Ironforge, a first bag, and saw Kaelin Ashby wear what you
    -- made". `%s` the person's short name.
    caption = {
        theirs = L["saw %s wear what you made"],
        gave = L["wore what %s gave you"],
        sold = L["wore what %s sold you"],
    },

    ----------------------------------------------------------------------
    -- The level's prose (Your Diary's left page)
    ----------------------------------------------------------------------
    -- One sentence for each connection in the level, every one, after the
    -- people paragraph. Two shapes each, for the seeded pick so that
    -- several in one level don't read alike. %1$s the person's name (as
    -- Text.Who gives it), %2$s the item's name, %3$s the place's phrase
    -- (ns.ZoneIn: "in Ironforge", its preposition the locale's); `alone`
    -- where the place is not known.
    --   "You saw Kaelin Ashby in Ironforge, wearing the Handstitched
    --    Leather Boots you made them."
    --   "You wore the Linen Boots Bramwell Pike gave you when you met in
    --    Ironforge."
    prose = {
        placed = {
            theirs = { L["You saw %1$s %3$s, wearing the %2$s you made them.##zone"],
                L["%1$s wore the %2$s you made them when you met %3$s.##zone"] },
            gave = { L["You met %1$s %3$s, wearing the %2$s they gave you.##zone"],
                L["You wore the %2$s %1$s gave you when you met %3$s.##zone"] },
            sold = { L["You met %1$s %3$s, wearing the %2$s they sold you.##zone"],
                L["You wore the %2$s %1$s sold you when you met %3$s.##zone"] },
        },
        alone = {
            theirs = { L["You saw %1$s in the %2$s you made them."],
                L["%1$s wore the %2$s you made them when you met."] },
            gave = { L["You met %1$s in the %2$s they gave you."],
                L["You wore the %2$s %1$s gave you when you met."] },
            sold = { L["You met %1$s in the %2$s they sold you."],
                L["You wore the %2$s %1$s sold you when you met."] },
        },
    },
}

--------------------------------------------------------------------------
-- The readers the mark, the card, the toast and the words share
--------------------------------------------------------------------------
--
-- A connection is a j.craftMeets record (Kind.lua): { t, guid, dir, id,
-- link, how, mapID, x, y }. Its person is read by GUID (a packed stranger
-- is unpacked by the asking, Core/Strangers.lua); a record whose person
-- was forgotten has no `guid` and names nobody.

local THEIRS = CrafterDetection.THEIRS

-- Which of WORDS' three a connection takes: "theirs" (they wore what you
-- made), "gave" or "sold" (you wore what they handed you, by a trade or at
-- auction).
local function Way(rec)
    if rec.dir == THEIRS then return "theirs" end
    return rec.how == "auction" and "sold" or "gave"
end
CrafterDetection.Way = Way

-- The keys of WORDS' tables by direction and by how ("trade" where the
-- record does not say: the hand-off the diary sees most).
local function Dir(rec) return rec.dir == THEIRS and "theirs" or "yours" end
local function How(rec) return rec.how == "auction" and "auction" or "trade" end

-- The item's name (out of its link), the person's full name and first
-- name; nil where not known.
function CrafterDetection.Item(rec) return CrafterDetection.ItemName(rec.link) end
function CrafterDetection.Person(rec) return rec.guid and Who(rec.guid) or nil end
function CrafterDetection.First(rec) return rec.guid and Short(rec.guid) or nil end
local Item, Person = CrafterDetection.Item, CrafterDetection.Person

-- When the item changed hands, where the book still says (the record's
-- own `handed`, else the craft handed to them, else what you got from
-- them, on the character's route); nil where it does not: the tooltip
-- then says how without when.
function CrafterDetection.HandedAt(rec)
    if rec.handed then return rec.handed end
    local j = ns.Journey.Mine and ns.Journey.Mine()
    local book = j and j.crafter
    if not book then return nil end
    if rec.dir == THEIRS then
        local at
        for _, craft in pairs(book.made or {}) do
            if craft.id == rec.id and craft.to == rec.guid and craft.handed then at = math.max(at or 0, craft.handed) end
        end
        return at
    end
    local got = book.got and book.got[rec.id]
    return got and got.from == rec.guid and got.t or nil
end

-- The gold line under the item's own tooltip on the card: how it went and
-- when (WORDS.itemLine).
function CrafterDetection.ItemLine(rec, now)
    local W, name = CrafterDetection.WORDS.itemLine, Person(rec) or L["someone"]
    local at = CrafterDetection.HandedAt(rec)
    if at then return Fmt(W.dated[Dir(rec)][How(rec)], name, Day(at, now)) end
    return Fmt(W.undated[Dir(rec)][How(rec)], name)
end

-- The needle's tooltip (WORDS.needle), for every connection under it
-- together: one says who and which way, the item and how; several are
-- counted, a line each, the item and how with whom. Then the core's foot
-- (Text.Foot: when).
local function Foot(list, now)
    local a = {}
    for _, m in ipairs(list) do
        local t = (m.meet or m).t
        if t then a.from, a.to = math.min(a.from or t, t), math.max(a.to or t, t) end
    end
    return a.from and Text.Foot(a, now) or nil
end

function CrafterDetection.Tips(list, now)
    local W = CrafterDetection.WORDS.needle
    local lines = {}
    local function Line(rec, how)
        local item = Item(rec)
        return item and Fmt(L["%1$s, %2$s"], item, how) or Capital(how)
    end
    if #list == 1 then
        local rec = list[1].meet or list[1]
        lines[1] = Line(rec, W.how[Dir(rec)][How(rec)])
        lines[#lines + 1] = Foot(list, now)
        return Capital(Fmt(W.title[Way(rec)], Person(rec) or L["someone"])), lines
    end
    for _, m in ipairs(list) do
        local rec = m.meet or m
        lines[#lines + 1] = Line(rec, Fmt(W.howWith[Dir(rec)][How(rec)], Person(rec) or L["someone"]))
    end
    lines[#lines + 1] = Foot(list, now)
    return Capital(ns.Plural(#list, W.several, NUMBER[#list] or tostring(#list))), lines
end

--------------------------------------------------------------------------
-- The person's margin note
--------------------------------------------------------------------------

-- A connection with someone in the diary is their moment too (Kind.lua's
-- moment: `person`): on their margin note it is something done together
-- (tier 1, as a gift is), said with the row's own phrase, which tells
-- both directions at once ("wore what changed hands between you"). The
-- card beside it says which way and what. -- copy: the row's reason,
-- reused; to confirm with the copywriter.
CrafterDetection.PERSON = {
    tier = 1,
    say = function() return L["wore what changed hands between you"] end,
}

--------------------------------------------------------------------------
-- Registered: the caption's words, the level's prose
--------------------------------------------------------------------------

-- The tail (the user, 27 Nov 2026): only on a plate opened for a
-- connection where no crafter card fits, the lead connection, never a
-- count; otherwise the cards and the needles tell it. The margin decides
-- (Card.lua's `say`: said.crafted.lead, the earliest connection that
-- could have had a card, set only then). After a close call's words (50)
-- and before luck's (60), the margin's order.
Text.RegisterCaption("crafted", {
    moment = "crafted",
    tail = { at = 55, say = function(_, c)
        local lead = c.said.crafted and c.said.crafted.lead
        local name = lead and CrafterDetection.First(lead)
        if not name then return nil end
        return Fmt(CrafterDetection.WORDS.caption[Way(lead)], name)
    end },
})

-- The level's sentences: one for each connection in it, every one (the
-- prose has room, and each is once ever), in time order. Which of the two
-- shapes is the entry's seed's (as the time paragraph picks its way:
-- the same each time, different from its neighbour), so several in one
-- level don't read alike.
function CrafterDetection.Lines(e)
    local P = CrafterDetection.WORDS.prose
    local seed = (e.level or 0) + math.floor((e.week or 0) / ns.DAY)
    local out = {}
    for i, rec in ipairs(e.craftMeets or {}) do
        local who, item = Person(rec), Item(rec)
        if who and item then
            local way = Way(rec)
            local zone = rec.mapID and Text.MapName(rec.mapID)
            local shapes = zone and P.placed[way] or P.alone[way]
            local shape = shapes[(seed + i) % #shapes + 1]
            out[#out + 1] = zone and Fmt(shape, who, item, ns.ZoneIn(rec.mapID, zone)) or Fmt(shape, who, item)
        end
    end
    return #out > 0 and table.concat(out, " ") or nil
end

-- After the people (30) and the free card (35), before the firsts found
-- (40): who you met, then what changed hands between you.
Text.RegisterLines("crafted", { at = 37, lines = function(e) return CrafterDetection.Lines(e) end })

-- Its row in "Choose what's on this page" (the mark's `label`): at most 25
-- characters, what it is first, then who or what (UI/Journey/Choose.lua).
local ROW = { theirs = L["Made for %s"], sold = L["Bought from %s"], gave = L["Gift from %s"] }
function CrafterDetection.Row(rec)
    return Fmt(ROW[Way(rec)], CrafterDetection.First(rec) or L["someone"])
end
