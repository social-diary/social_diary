-- Trade capture: only a trade the client confirms is stored, with what was
-- in the window when both sides accepted.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Latest, Pending = ns._test.LatestInteraction, ns._test.TradeCapturePending

--------------------------------------------------------------------------
Section("trade capture (INT-1, T-E8)")

local GUID = F.STRANGER.guid
mock.SetUnit("NPC", F.STRANGER)
mock.trade = {
    given = { { name = "Tough Jerky", link = "|Hitem:117|h[Tough Jerky]|h", count = 3 } },
    received = { { name = "Linen Cloth", link = "|Hitem:2589|h[Linen Cloth]|h", count = 5 } },
    moneyGiven = 0,
    moneyReceived = 1234,
}

-- As a trade is stored, it is told (SD_TRADE_COMPLETED, Core/Events.lua):
-- who it was with, and what was received and given, as the row keeps it.
local told = {}
ns.On("SD_TRADE_COMPLETED", function(_, guid, received, given)
    told[#told + 1] = { guid = guid, received = received, given = given }
end)

mock.fire("TRADE_SHOW")
Check(Pending(), "trade snapshot not opened")
mock.fire("TRADE_MONEY_CHANGED")

-- Nothing is stored until the client confirms the trade went through.
Eq(ns.Interactions.Count(GUID), 0, "trade stored before it completed")

mock.fire("TRADE_CLOSED")
mock.fire("UI_INFO_MESSAGE", 251)

local row = Latest(GUID, "trade")
Check(row, "completed trade not recorded")
Eq(row.context.given[1].count, 3, "items given")
Eq(row.context.given[1].link, "|Hitem:117|h[Tough Jerky]|h", "item link given")
Eq(row.context.received[1].link, "|Hitem:2589|h[Linen Cloth]|h", "item link received")
Eq(row.context.moneyReceived, 1234, "money received")
Eq(row.context.moneyGiven, nil, "zero money should not be stored")
Eq(row.theirLevel, 1, "partner level")
Eq(ns.Recent.Get("trade"), GUID, "last trade partner not remembered (DIA-3)")
Eq(Pending(), nil, "snapshot not cleared after committing")
Eq(#told, 1, "the completed trade was not told")
Eq(told[1] and told[1].guid, GUID, "who the trade told of was with")
Check(told[1] and told[1].received == row.context.received, "what the trade told of is not what its row received")
Check(told[1] and told[1].given == row.context.given, "what the trade told of is not what its row gave")

-- Completing a trade empties its slots, and those change events can arrive
-- before the confirmation: the contents as accepted are what is stored.
ns.db.interactions = {}
local tradeContents = mock.trade
mock.fire("TRADE_SHOW")
mock.fire("TRADE_ACCEPT_UPDATE", 1, 0)
mock.trade = { given = {}, received = {}, moneyGiven = 0, moneyReceived = 0 }
mock.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
mock.fire("TRADE_TARGET_ITEM_CHANGED", 1)
mock.fire("TRADE_MONEY_CHANGED")
mock.fire("UI_INFO_MESSAGE", 251)
row = Latest(GUID, "trade")
Check(row.context.given and row.context.given[1].count == 3, "the emptied window overwrote what was given")
Eq(row.context.moneyReceived, 1234, "the emptied window overwrote the money")

-- A change after accepting resets the acceptance, and the next accept counts.
mock.trade = tradeContents
mock.fire("TRADE_SHOW")
mock.fire("TRADE_ACCEPT_UPDATE", 1, 0)
mock.trade = { given = {}, received = tradeContents.received, moneyGiven = 0, moneyReceived = 0 }
mock.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
mock.fire("TRADE_ACCEPT_UPDATE", 0, 0)
mock.fire("TRADE_ACCEPT_UPDATE", 0, 1)
mock.fire("UI_INFO_MESSAGE", 251)
row = Latest(GUID, "trade")
Eq(row.context.given, nil, "an item taken back after accepting was stored")
Eq(row.context.received[1].count, 5, "the re-accepted contents")

-- Without any accept event, nothing read after the window closed counts.
mock.trade = tradeContents
mock.fire("TRADE_SHOW")
mock.fire("TRADE_CLOSED")
mock.trade = { given = {}, received = {}, moneyGiven = 0, moneyReceived = 0 }
mock.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
mock.fire("UI_INFO_MESSAGE", 251)
row = Latest(GUID, "trade")
Check(row.context.given and row.context.given[1].count == 3, "a reading after the window closed was stored")
mock.trade = tradeContents
Eq(ns.Interactions.Count(GUID), 3, "trades stored")

-- A cancelled trade leaves nothing behind.
mock.fire("TRADE_SHOW")
mock.fire("UI_INFO_MESSAGE", 250)
Eq(Pending(), nil, "cancelled trade kept its snapshot")
Eq(ns.Interactions.Count(GUID), 3, "cancelled trade was stored")
Eq(#told, 4, "a cancelled trade was told as completed")

-- A window that closes with no verdict at all expires on the backstop timer.
mock.fire("TRADE_SHOW")
mock.fire("TRADE_CLOSED")
Check(Pending(), "snapshot dropped on TRADE_CLOSED, before the verdict")
mock.RunTimers()
Eq(Pending(), nil, "stale snapshot never expired")
Eq(ns.Interactions.Count(GUID), 3, "an abandoned trade was stored")
