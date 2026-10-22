-- Trade (INT-1): a trade the client confirmed, a row on the person traded
-- with, saying what changed hands. A feature in a folder of its own
-- (.claude/skills/new-feature/folder.md), and a People row
-- and nothing else, as Chat is: no route list, no moment on the plates, no
-- mark, no margin note, no caption words.
--
--   Kind.lua     what a trade is to the diary: its row kind, its words and
--                icon on the timeline
--   Capture.lua  the trade window watched, and what is stored once the
--                client says the trade completed
--   Dev.lua      its part of /sd testdata: Tester's three trades (never
--                packaged)
--
-- Everything is registered into the core's and the UI's registries, so no
-- file outside this folder declares the trade row. Its own names are on
-- ns.Trade, made here, the first of its files the TOC loads.
--
-- What stays core, because it is the diary's substrate and not this
-- feature's detection:
--   - the timeline's activity "trade" (Core/Timeline.lua's RANK, Tally's
--     trade sums: items and money given and received over an episode) and
--     its headline words ("Traded", "N trades"; UI/Words/Timeline.lua), keyed
--     by activity, not by row kind;
--   - item quality (Timeline.TradeQuality, Timeline.UNCOMMON, TLN-5), which
--     the episodes read as well as this kind's `moment`;
--   - the "trade" art (UI/Style/Art.lua), the activity's icon too;
--   - the "trade" mark on Recently nearby's day (`dealt`; Core/Sightings.lua's
--     DEALT_RANK, UI/Journal/Nearby.lua's words);
--   - ns.Recent's "trade" (Core/Candidates.lua's RECENT_KINDS: the picker's
--     "you traded with them"), which Capture.lua sets through ns.Recent.Set;
--   - SD_TRADE_COMPLETED (guid, received), the message Capture.lua fires
--     as it stores a trade (Core/Events.lua), for whoever cares what was
--     received from whom; this feature does not know who listens.
--
-- This file: the kind, whole (Core/Rows.lua's spec in one call, words and
-- icon included).

local addonName, ns = ...

local Trade = {}
ns.Trade = Trade

--------------------------------------------------------------------------
-- The People row
--------------------------------------------------------------------------
--
-- Within arm's reach, so a live row is "last seen" too and opens a
-- together session with a diary entry; it counts as meeting them outside a
-- session, leaves the "trade" mark on Recently nearby's day, makes a person
-- matter, and is the timeline's "trade" activity. A trade is a moment of
-- its own when something of note changed hands.
--
-- Its words: "Traded: gave 10x [Linen Cloth]; got 5s", or "Traded" where
-- the window was empty.

local Items = ns.UI.TimelineText.Items

ns.Rows.Register("trade", { proximity = true, plate = 7, opens = true, meeting = true, dealt = "trade", matters = true,
    activity = "trade",
    moment = function(row) return ns.Timeline.TradeQuality(row) >= ns.Timeline.UNCOMMON end,
    text = function(row)
        local c = row.context or {}
        local parts = {}
        if c.given then parts[#parts + 1] = "gave " .. Items(c.given) end
        if c.moneyGiven then parts[#parts + 1] = "gave " .. ns.UI.Format.Money(c.moneyGiven) end
        if c.received then parts[#parts + 1] = "got " .. Items(c.received) end
        if c.moneyReceived then parts[#parts + 1] = "got " .. ns.UI.Format.Money(c.moneyReceived) end
        if #parts == 0 then return "Traded" end
        return "Traded: " .. table.concat(parts, "; ")
    end,
    icon = "trade" })
