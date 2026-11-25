-- City trips (Features/CityTrips/): a visit to a capital opens on
-- arriving and closes at each of its ends, carries on across a /reload,
-- and keeps the errands run in it (auctions, letters, crafting,
-- professions, quests, the purse), merged and capped so a heavy one stays
-- small; people only as GUIDs the diary knows, strangers counted; nothing
-- outside a city; a client without the calls, or a hook that errs, never
-- breaks the game's call.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq

local MULGORE, ORGRIMMAR, THUNDER_BLUFF = 1412, 1454, 1456
local ALT = "Player-4707-0A1700001"

-- The client as this feature reads it, made before the addon loads (the
-- hooks are made at load) and again after every fresh client (a reload).
local money = 10000
local inbox, sendSlots, sendMoney = {}, {}, 0
local auctions = {}
local onQuest = {}
local function Client(opts)
    opts = opts or {}
    _G.LOOT_ITEM_CREATED_SELF = "You create: %s."
    _G.LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
    _G.AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
    _G.AUCTION_REMOVED_MAIL_SUBJECT = "Auction cancelled: %s"
    _G.GetMoney = function() return money end
    -- hooksecurefunc as the client's: the call first, then the hook; on a
    -- global by name or on a table's field.
    if not opts.bare then
        _G.hooksecurefunc = function(a, b, c)
            local owner, name, fn = _G, a, b
            if type(a) == "table" then owner, name, fn = a, b, c end
            local before = owner[name]
            owner[name] = function(...)
                local r = { before(...) }
                fn(...)
                return unpack(r)
            end
        end
        _G.C_AuctionHouse = {
            PostItem = function() end, PostCommodity = function() end,
            PlaceBid = function() end, ConfirmCommoditiesPurchase = function() end,
            GetAuctionInfoByID = function(id) return auctions[id] end,
        }
        _G.GetInboxHeaderInfo = function(i)
            local l = inbox[i]
            if not l then return nil end
            return nil, nil, l.sender, l.subject, l.money or 0, 0, l.days or 29.5, #(l.items or {}), false,
                l.returned or false, false, l.canReply or false, false
        end
        _G.GetInboxInvoiceInfo = function(i)
            local v = inbox[i] and inbox[i].invoice
            if not v then return nil end
            -- (the client's order: invoiceType, itemName, playerName, bid,
            -- buyout, deposit, consignment, moneyDelay, etaHour, etaMin,
            -- count, commerceAuction; etaMin is 0 on a settled sale, so a
            -- count read one place early would come out as nought)
            return v.kind, v.item, v.player, v.bid, 0, 0, 0, 0, 0, 0, v.count, false
        end
        _G.GetInboxItem = function(i, a)
            local it = inbox[i] and inbox[i].items and inbox[i].items[a]
            if not it then return nil end
            return it.name, it.id, 134400, it.count or 1, 1, false
        end
        _G.GetInboxItemLink = function(i, a)
            local it = inbox[i] and inbox[i].items and inbox[i].items[a]
            return it and ("|Hitem:%d|h[%s]|h"):format(it.id, it.name) or nil
        end
        _G.TakeInboxMoney = function() end
        _G.TakeInboxItem = function() end
        _G.AutoLootMailItem = function() end
        _G.SendMail = function() end
        _G.GetSendMailItem = function(a)
            local it = sendSlots[a]
            if not it then return nil end
            return it.name, it.id, 134400, it.count or 1, 1
        end
        _G.GetSendMailMoney = function() return sendMoney end
    end
    -- The item a bag location holds; the quest log's titles and who is on
    -- a quest. Fresh tables, so nothing leaks into the next file.
    local item = {}
    for k, v in pairs(_G.C_Item) do item[k] = v end
    item.GetItemID = function(location) return location and location.itemID end
    _G.C_Item = item
    local quests = {}
    for k, v in pairs(_G.C_QuestLog) do quests[k] = v end
    quests.GetTitleForQuestID = function(id) return "Quest " .. id end
    quests.IsUnitOnQuest = function(unit, id) return onQuest[unit] == id end
    _G.C_QuestLog = quests
end

Client()
local ns = T.Boot()
local C = ns.CityTrips
local Test = ns._test.CityTrips
local SELF, FRIEND, STRANGER, STRANGER2 = F.SELF, F.FRIEND, F.STRANGER, F.STRANGER2

-- The world settles (the route's own timer fires SD_WORLD_SETTLED).
local function Settle()
    mock.fire("PLAYER_ENTERING_WORLD")
    mock.RunTimers()
end

local function Go(mapID)
    mock.mapID = mapID
    mock.fire("ZONE_CHANGED_NEW_AREA")
end

local function Pass(seconds) mock.now = mock.now + seconds end

local function Made(name, id, n)
    local link = ("|cffffffff|Hitem:%d::::::::16:::::|h[%s]|h|r"):format(id, name)
    local text = n and ("You create: %sx%d."):format(link, n) or ("You create: %s."):format(link)
    mock.fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, SELF.guid)
end

mock.position = { x = 0.5, y = 0.6 }
mock.mapID = MULGORE
Settle()
local j = ns.db.journey[SELF.guid]
Check(j, "setup: no route")
local function Trips() return j.trips or {} end
local function Last() return Trips()[#Trips()] end

-- The diary knows Numa (a diary entry) and two Tulluses; not Bram.
ns.Characters.Observe(FRIEND.guid, { first = "Numa", surname = "Pompilius" })
ns.Diary.Add(FRIEND.guid, { source = "test" })
ns.Characters.Observe(STRANGER2.guid, { first = "Tullus", surname = "Hostilius" })
ns.Characters.Observe("Player-4620-00BBBB03", { first = "Tullus", surname = "Marcius" })
-- One of the player's own characters.
ns.OwnCharacters()[ALT] = { first = "Mirsha", surname = "Nye" }

--------------------------------------------------------------------------
Section("a trip opens on arriving; one with nothing done is dropped")

Go(ORGRIMMAR)
Eq(#Trips(), 1, "arriving in Orgrimmar opened no trip")
local trip = Last()
Eq(trip.mapID, ORGRIMMAR, "the city's map")
Eq(trip.t, mock.now, "when it began")
Eq(trip.to, nil, "a trip under way has an end")
Eq(trip.came, 10000, "the purse on arriving")
Eq(trip.level, SELF.level, "the level on arriving")
money = 9000
mock.fire("PLAYER_MONEY")
Eq(trip.left, 9000, "the purse not followed")
Pass(60)
Go(MULGORE)
Eq(#Trips(), 0, "a trip with nothing done (a vendor's coin alone) was kept")
Eq(Test.State().trip, nil, "the trip still open after leaving")

--------------------------------------------------------------------------
Section("nothing is written outside a city")

Made("Bolt of Linen Cloth", 2996)
ns.Fire("SD_QUEST_ACCEPTED", 100)
C_AuctionHouse.PostItem({ itemID = 2996 }, 1, 2)
mock.fire("AUCTION_HOUSE_AUCTION_CREATED", 1)
mock.fire("NEW_RECIPE_LEARNED", 3915)
inbox[1] = { sender = "Numa", subject = "Hello", money = 500, canReply = true }
TakeInboxMoney(1)
Eq(#Trips(), 0, "an errand in Mulgore made a trip")
inbox = {}

--------------------------------------------------------------------------
Section("crafting: one entry an item, counted")

Go(ORGRIMMAR)
for _ = 1, 12 do Made("Bolt of Linen Cloth", 2996) end
Made("Bolt of Linen Cloth", 2996, 5)
Made("Linen Bag", 4238)
trip = Last()
Eq(#trip.made, 2, "twelve bolts one at a time were not one entry")
Eq(trip.made[1].id, 2996, "the bolts' item")
Eq(trip.made[1].n, 17, "the bolts made, one at a time and five at once")
Eq(trip.made[2].n, 1, "the bag")
-- Someone else's line is not the player's.
mock.fire("CHAT_MSG_LOOT", "Bram creates: |Hitem:2996|h[Bolt of Linen Cloth]|h.", "", "", "", "", "", 0, 0, "", 0, 2,
    STRANGER.guid)
Eq(trip.made[1].n, 17, "another player's craft was counted")

--------------------------------------------------------------------------
Section("each end: leaving, a taxi, an instance, the route off, away too long")

Pass(300)
money = 12000
Go(MULGORE)
Eq(trip.to, mock.now, "leaving the city did not end the trip")
Eq(trip.left, 12000, "the purse on leaving")
Eq(trip.seen, nil, "a closed trip keeps its working state")
Eq(#C.List(j), 1, "the ended trip is not listed")

Go(ORGRIMMAR)
Made("Linen Bag", 4238)
Pass(30)
mock.onTaxi = true
mock.fire("PLAYER_CONTROL_LOST")
Eq(Last().to, mock.now, "a taxi taking off did not end the trip")
Eq(#Trips(), 2, "the taxi's trip")
-- Over the city on the taxi: no trip.
mock.fire("PLAYER_CONTROL_GAINED")
Test.Check()
Eq(#Trips(), 2, "flying over the city opened a trip")
mock.onTaxi = false

Test.Check()
Made("Linen Bag", 4238)
mock.inInstance = true
Pass(10)
mock.fire("PLAYER_ENTERING_WORLD")
Eq(#Trips(), 3, "the third trip")
Eq(Last().to, mock.now, "entering an instance did not end the trip")
mock.inInstance = false

Test.Check()
Made("Linen Bag", 4238)
ns.db.settings.keepRoute = false
Pass(10)
Test.Check()
Eq(Last().to, mock.now, "the route no longer kept did not end the trip")
Made("Linen Bag", 4238)
Eq(#Trips(), 4, "a trip opened on a route not kept")
ns.db.settings.keepRoute = true

Test.Check()
Made("Linen Bag", 4238)
local seen = mock.now
Eq(Last().seen, seen, "the trip not seen")
mock.afk = true
-- Beats while away do not count as seen.
Pass(ns.Sittings.GAP / 2)
Test.Check()
Eq(Last().seen, seen, "a beat away from the keys counted as seen")
Pass(ns.Sittings.GAP / 2 + 60)
Test.Check()
Eq(#Trips(), 5, "a trip opened away from the keys")
Eq(Trips()[5].to, seen, "away longer than a sitting's gap: not ended where it was last seen")
mock.afk = false
Test.Check()
Eq(#Trips(), 6, "back at the keys in town, no new trip")
Eq(Last().to, nil, "the new trip is not under way")
Go(MULGORE)
Eq(#Trips(), 5, "the empty new trip was kept")

--------------------------------------------------------------------------
Section("a /reload in the middle carries the trip on; a logout ends it")

local function Reload(after, mapID)
    local saved, savedChar, now = _G.SocialDiaryDB, _G.SocialDiaryCharDB, mock.now
    mock.fire("PLAYER_LOGOUT")
    mock.Reset()
    _G.SocialDiaryDB, _G.SocialDiaryCharDB = saved, savedChar
    Client()
    mock.now = now + after
    mock.position = { x = 0.5, y = 0.6 }
    mock.mapID = mapID
    ns = T.Boot()
    C, Test = ns.CityTrips, ns._test.CityTrips
    j = ns.db.journey[SELF.guid]
    Settle()
end

Go(ORGRIMMAR)
Made("Bolt of Woolen Cloth", 2997)
trip = Last()
local began = trip.t
Pass(40)
mock.fire("PLAYER_LOGOUT")
Eq(trip.to, mock.now, "a logout wrote no end")
Reload(20, ORGRIMMAR)
trip = Last()
Eq(#Trips(), 6, "the reload split the trip")
Eq(trip.t, began, "the reloaded trip's start")
Eq(trip.to, nil, "the reloaded trip is not under way again")
Made("Bolt of Woolen Cloth", 2997)
Eq(trip.made[1].n, 2, "a craft after the reload did not join the trip's")
Eq(Test.State().trip, trip, "the capture did not take the trip back")

-- A logout, back an hour later: it ended at the logout.
Pass(30)
local out = mock.now
Reload(3600, ORGRIMMAR)
Eq(Trips()[6].to, out, "a trip left at logout did not end there")
Eq(Trips()[6].seen, nil, "the old trip still unsettled")
Eq(#Trips(), 7, "logging in in town opened no trip of its own")
Eq(Last().t, mock.now, "the new trip's start")

-- A reload landing elsewhere ends it too.
Made("Linen Bag", 4238)
Pass(30)
Reload(5, MULGORE)
Eq(Trips()[7].to, mock.now - 5, "a reload outside the city did not end the trip")
Eq(Test.State().trip, nil, "a trip under way outside the city")

-- Before the world settles, nothing: the map may not read yet.
Test.Reset()
Go(ORGRIMMAR)
Made("Linen Bag", 4238)
Eq(#Trips(), 7, "a trip opened before the world settled")
Settle()
Eq(#Trips(), 8, "the settled world opened no trip")
Made("Linen Bag", 4238)

--------------------------------------------------------------------------
Section("auctions: put up, bought, a commodity")

Go(MULGORE)
Go(ORGRIMMAR)
trip = Last()
C_AuctionHouse.PostItem({ itemID = 4238, bagID = 0, slotIndex = 1 }, 2, 3, 1000, 2000)
Eq(trip.up, nil, "an auction put up before the house confirmed it")
mock.fire("AUCTION_HOUSE_AUCTION_CREATED", 77)
Eq(trip.up[1].id, 4238, "the lot's item")
Eq(trip.up[1].n, 3, "how many")
Eq(trip.up[1].ask, nil, "an asking price kept")
C_AuctionHouse.PostCommodity({ itemID = 4238 }, 2, 2, 500)
mock.fire("AUCTION_HOUSE_AUCTION_CREATED", 78)
Eq(trip.up[1].n, 5, "a second posting of the same item not merged")
mock.fire("AUCTION_HOUSE_AUCTION_CREATED", 79)
Eq(trip.up[1].n, 5, "a confirmation with nothing posted was counted")

-- A buyout from someone the diary knows, one from a stranger, a bid that
-- never completes.
auctions[501] = { itemKey = { itemID = 2589 }, quantity = 20, owners = { "Numa" } }
auctions[502] = { itemKey = { itemID = 2589 }, quantity = 5, owners = { "Bram" } }
auctions[503] = { itemKey = { itemID = 2592 }, quantity = 1, owners = { "Numa" } }
C_AuctionHouse.PlaceBid(501, 800)
C_AuctionHouse.PlaceBid(502, 200)
C_AuctionHouse.PlaceBid(503, 50)
mock.fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 501)
mock.fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 502)
mock.fire("AUCTION_HOUSE_PURCHASE_COMPLETED", 999)
Eq(#trip.bought, 1, "two purchases of one item not merged, or a bid counted")
local b = trip.bought[1]
Eq(b.id, 2589, "the purchase's item")
Eq(b.n, 25, "how many bought")
Eq(b.paid, 1000, "what was paid")
Eq(b.who and b.who[1], FRIEND.guid, "the known seller")
Eq(#b.who, 1, "the stranger named")
Eq(b.others, 1, "the stranger not counted")

-- A commodity: paid by the purse's drop.
money = 20000
C_AuctionHouse.ConfirmCommoditiesPurchase(2320, 10)
money = 19700
mock.fire("COMMODITY_PURCHASE_SUCCEEDED")
Eq(trip.bought[2].id, 2320, "the commodity's item")
Eq(trip.bought[2].n, 10, "how many")
Eq(trip.bought[2].paid, 300, "what it cost")

--------------------------------------------------------------------------
Section("the mailbox: letters, a sale, a won lot, a lot back, sent")

inbox = {
    { sender = "Numa", subject = "For the road", money = 2500, canReply = true,
        items = { { id = 2589, name = "Linen Cloth", count = 10 }, { id = 2320, name = "Coarse Thread", count = 1 } } },
    { sender = "Auction House", subject = "Auction successful: Linen Bag", money = 380,
        invoice = { kind = "seller", item = "Linen Bag", player = "Bram", bid = 400, count = 1 } },
    { sender = "Auction House", subject = "Auction won: Linen Cloth", items = { { id = 2589, name = "Linen Cloth", count = 20 } },
        invoice = { kind = "buyer", item = "Linen Cloth", player = "Numa", bid = 800, count = 20 } },
    { sender = "Auction House", subject = "Auction expired: Linen Bag", items = { { id = 4238, name = "Linen Bag" } } },
    { sender = "Mirsha", subject = "back", returned = true, items = { { id = 4238, name = "Linen Bag" } } },
    { sender = "Thrall", subject = "A gift", items = { { id = 6948, name = "Hearthstone" } } },
    { sender = "Tullus", subject = "Hi", money = 100, canReply = true },
    { sender = "Bram", subject = "Hi", money = 70, canReply = true },
    { sender = "Auction House", subject = "Auction won: Woolen Cloth", items = { { id = 2592, name = "Woolen Cloth", count = 4 } },
        invoice = { kind = "buyer", item = "Woolen Cloth", player = "Bram", bid = 120, count = 4 } },
    { sender = "Auction House", subject = "Auction cancelled: Linen Bag", items = { { id = 4238, name = "Linen Bag" } } },
}
mock.itemInfo[2589] = { name = "Linen Cloth" }
-- Numa's letter: the coin, then one thing, then all (the coin and the
-- first thing only once).
TakeInboxMoney(1)
TakeInboxItem(1, 1)
TakeInboxMoney(1)
AutoLootMailItem(1)
Eq(#trip.letters, 1, "Numa's letter not one entry")
local l = trip.letters[1]
Eq(l.from, FRIEND.guid, "the sender known")
Eq(l.n, 1, "one letter counted more than once")
Eq(l.coin, 2500, "the coin taken")
Eq(l.items, 11, "the things taken (a stack counts its size)")
for i = 2, 10 do AutoLootMailItem(i) end
Eq(trip.sold[1].name, "Linen Bag", "the sale's item")
Eq(trip.sold[1].n, 1, "how many sold")
Eq(trip.sold[1].got, 380, "what it fetched")
Eq(trip.sold[1].who, nil, "an unknown buyer named")
Eq(trip.sold[1].others, 1, "the unknown buyer not counted")
Eq(trip.bought[1].n, 25, "a lot won already bought on the trip counted again")
Eq(#trip.bought, 3, "a lot won by letter not a purchase of its own")
Eq(trip.bought[3].name, "Woolen Cloth", "the won lot's item")
Eq(trip.bought[3].paid, 120, "the won lot's price")
Eq(trip.bought[3].others, 1, "its unknown seller not counted")
Eq(trip.back, 2, "the expired and the cancelled lot")
Eq(#trip.letters, 2, "the returned, the NPC's or the strangers' letters miscounted")
Eq(trip.letters[2].from, nil, "an ambiguous or unknown sender named")
Eq(trip.letters[2].n, 2, "the two unknown letters")
Eq(trip.letters[2].coin, 170, "their coin")

-- Sent: to the player's own character, to a stranger, one that failed.
sendSlots = { { id = 4238, name = "Linen Bag", count = 1 }, nil, { id = 2589, name = "Linen Cloth", count = 5 } }
sendMoney = 1000
SendMail("Mirsha", "bags", "")
mock.fire("MAIL_SEND_SUCCESS")
sendSlots, sendMoney = { { id = 4238, name = "Linen Bag" } }, 0
SendMail("Bram", "a bag", "")
mock.fire("MAIL_SEND_SUCCESS")
SendMail("Numa", "never", "")
mock.fire("MAIL_FAILED")
mock.fire("MAIL_SEND_SUCCESS")
Eq(#trip.sent, 2, "the sent letters")
Eq(trip.sent[1].to, ALT, "the own character not found")
Eq(trip.sent[1].own, true, "the own character not flagged")
Eq(trip.sent[1].items, 6, "the things sent")
Eq(trip.sent[1].coin, 1000, "the coin sent")
Eq(trip.sent[2].to, nil, "a stranger named")
Eq(trip.sent[2].n, 1, "a failed letter counted")

-- A sale of a thing the client can put an id to (here: a lot of that name
-- put up earlier) keeps the id, not the name. Its letter is alike in every
-- way to the sale's above, which was emptied: a letter of its own.
mock.itemInfo[4238] = { name = "Linen Bag" }
inbox[11] = { sender = "Auction House", subject = "Auction successful: Linen Bag", money = 400,
    invoice = { kind = "seller", item = "Linen Bag", player = "Numa", bid = 420, count = 1 } }
TakeInboxMoney(11)
Eq(trip.sold[2].id, 4238, "a sold lot's item not put to its id")
Eq(trip.sold[2].name, nil, "a sold lot kept its name beside its id")
Eq(trip.sold[2].who and trip.sold[2].who[1], FRIEND.guid, "the known buyer")
mock.itemInfo[4238] = nil

--------------------------------------------------------------------------
Section("professions, recipes, quests")

-- On a fresh trip, so the ranks are read on arriving.
Go(MULGORE)
mock.professions = { { name = "Tailoring", rank = 148, max = 150, line = 197 } }
Go(ORGRIMMAR)
trip = Last()
mock.professions[1].rank = 150
mock.fire("CHAT_MSG_SKILL", "Your skill in Tailoring has increased to 150.")
mock.fire("SKILL_LINES_CHANGED")
-- One reading of the trip's and one of Profession caps'.
Eq(#mock.timers, 2, "a burst of skill changes read more than once")
mock.RunTimers()
Eq(trip.skills[1].from, 148, "the rank on arriving")
Eq(trip.skills[1].to, 150, "the rank reached")
mock.professions[1].rank, mock.professions[1].max = 165, 225
mock.fire("SKILL_LINES_CHANGED")
mock.RunTimers()
Eq(#trip.skills, 1, "a second climb not one entry")
Eq(trip.skills[1].to, 165, "the last rank")
Eq(trip.skills[1].name, "Tailoring", "the profession's name")
mock.fire("NEW_RECIPE_LEARNED", 3915)
mock.fire("NEW_RECIPE_LEARNED", 3915)
mock.fire("NEW_RECIPE_LEARNED", 3914)
Eq(#trip.recipes, 2, "a recipe learnt twice counted twice")

mock.fire("QUEST_ACCEPTED", 1065)
Eq(trip.quests and trip.quests[1].id, 1065, "a quest taken through the client's event")
Eq(trip.quests[1].title, "Quest 1065", "its title")
Eq(trip.quests[1].out, nil, "a quest taken read as handed in")
mock.SetUnit("party1", FRIEND)
mock.SetUnit("party2", STRANGER)
mock.SetUnit("party3", STRANGER2)
onQuest = { party1 = 1064, party2 = 1064 }
ns.Fire("SD_QUEST_TURNED_IN", 1064)
local q = trip.quests[2]
Eq(q.out, true, "a quest handed in")
Eq(q.with and q.with[1], FRIEND.guid, "who of the party was on it")
Eq(#q.with, 1, "one not on it, or a stranger, named")
Eq(q.others, 1, "the stranger on it not counted")
mock.ClearUnits()
mock.SetUnit("player", SELF)
onQuest = {}

--------------------------------------------------------------------------
Section("names never kept: only GUIDs the diary knows")

local function Dump(v, out)
    out = out or {}
    if type(v) == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do
            out[#out + 1] = type(k) == "number" and "[" .. k .. "]=" or '["' .. k .. '"]='
            Dump(v[k], out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif type(v) == "string" then
        out[#out + 1] = '"' .. v .. '"'
    else
        out[#out + 1] = tostring(v)
    end
    return out
end
local saved = table.concat(Dump(Trips()))
for _, name in ipairs({ "Numa", "Pompilius", "Bram", "Redfen", "Tullus", "Hostilius", "Marcius", "Mirsha", "Thrall",
    "Auction House" }) do
    Check(not saved:find(name, 1, true), "a name kept on a trip: " .. name)
end
Check(saved:find(FRIEND.guid, 1, true) ~= nil, "the known person's GUID not kept")

--------------------------------------------------------------------------
Section("a heavy trip stays small: merged by item, capped with the rest counted")

Go(MULGORE)
Go(ORGRIMMAR)
trip = Last()
for round = 1, 4 do
    for id = 3000, 3011 do Made("Thing " .. id, id) end
    for id = 3000, 3009 do
        C_AuctionHouse.PostItem({ itemID = id }, 2, 1)
        mock.fire("AUCTION_HOUSE_AUCTION_CREATED", id)
    end
end
Eq(#trip.made, C.T.items + 1, "made: the cap and one last entry")
Eq(trip.made[C.T.items].n, 4, "a kind of thing within the cap")
Eq(trip.made[#trip.made].rest, true, "the last entry not the rest")
Eq(trip.made[#trip.made].n, (12 - C.T.items) * 4, "the rest's count lost something")
Eq(trip.up[#trip.up].n, (10 - C.T.items) * 4, "the lots past the cap lost")
inbox = {}
for i = 1, 30 do
    inbox[i] = { sender = (i % 2 == 0) and "Numa" or ("Nobody" .. i), subject = "Letter " .. i, money = 10, canReply = true,
        items = { { id = 2589, name = "Linen Cloth" } } }
    AutoLootMailItem(i)
end
Eq(#trip.letters, 2, "thirty letters from two kinds of sender not two entries")
Eq(trip.letters[1].n + trip.letters[2].n, 30, "letters lost")
for i = 1, 30 do ns.Fire("SD_QUEST_TURNED_IN", 2000 + i) end
Eq(#trip.quests, C.T.quests, "quests past the cap")
Eq(trip.quests.more, 30 - C.T.quests, "the quests past the cap not counted")
for id = 1, 20 do mock.fire("NEW_RECIPE_LEARNED", 4000 + id) end
Eq(trip.recipes.more, 20 - C.T.recipes, "recipes past the cap not counted")
local bytes = #table.concat(Dump(trip))
-- Every list at its cap at once, quest titles and all: the worst a trip
-- can be, about 1.2 KB written tight (24 Nov: 1219 bytes).
Check(bytes < 1400, ("a heavy trip is %d bytes"):format(bytes))
Go(MULGORE)
Eq(Last().to, mock.now, "the heavy trip did not end")

--------------------------------------------------------------------------
Section("forgetting someone, and the login's pruning (PRV-3)")

local LIST = ns.Journey.LISTS.trips
Check(LIST and LIST.forget and LIST.prune, "trips registered without forget and prune")
local function Count(guid)
    return select(2, table.concat(Dump(Trips())):gsub(guid:gsub("%-", "%%-"), ""))
end
Check(Count(FRIEND.guid) > 0, "setup: Numa on no trip")
-- Pruning: Numa is in the diary, the own character is never pruned.
ns.Journey.Prune(mock.now + 365 * T.DAY)
Check(Count(FRIEND.guid) > 0, "a diary entry pruned off a trip")
Check(Count(ALT) > 0, "the player's own character pruned off a trip")
local letterTrip
for _, rec in ipairs(Trips()) do
    if rec.letters and rec.letters[1].from == FRIEND.guid and rec.letters[2] then letterTrip = rec end
end
Check(letterTrip, "setup: a trip with Numa's letter and the unknown's")
local before = letterTrip.letters[1].n + letterTrip.letters[2].n
LIST.forget(j, FRIEND.guid)
Eq(Count(FRIEND.guid), 0, "a forgotten person still on a trip")
Eq(#letterTrip.letters, 1, "a forgotten sender did not join the unknown")
Eq(letterTrip.letters[1].n, before, "letters lost when a sender was forgotten")
Eq(letterTrip.bought[1].others, 2, "a forgotten seller not counted with the unknown")
-- A stranger by now (out of the diary): pruned once old.
ns.Characters.Observe(STRANGER.guid, { first = "Bram", surname = "Redfen" })
local old = Trips()[1]
old.quests = { { id = 1, title = "Quest 1", out = true, with = { STRANGER.guid } } }
ns.Journey.Prune(old.t + 1)
Eq(old.quests[1].with and old.quests[1].with[1], STRANGER.guid, "someone pruned inside the buffer")
ns.Journey.Prune(mock.now + 365 * T.DAY)
Eq(old.quests[1].with, nil, "a stranger kept past the buffer")
Eq(old.quests[1].others, 1, "a pruned stranger not counted")
LIST.forget(j, nil)
Eq(Count(ALT), 0, "forgetting everyone left someone")

--------------------------------------------------------------------------
Section("a route kept before trips (no j.trips)")

local older = { startedAt = mock.now, levels = {}, segments = {}, marks = {} }
Eq(#C.List(older), 0, "an old route has trips")
LIST.forget(older, FRIEND.guid)
LIST.prune(older, mock.now)
Eq(older.trips, nil, "forget or prune wrote onto an old route")
j.trips = nil
Go(ORGRIMMAR)
Made("Linen Bag", 4238)
Eq(#Trips(), 1, "a trip not kept on a route that had none")
Go(MULGORE)

--------------------------------------------------------------------------
Section("a hook that errs never reaches the game's call")

Go(ORGRIMMAR)
local header = _G.GetInboxHeaderInfo
_G.GetInboxHeaderInfo = function() error("the client said no") end
local ok = pcall(TakeInboxMoney, 1)
Check(ok, "an error in the mail hook reached TakeInboxMoney's caller")
local caught
_G.geterrorhandler = function() return function(err) caught = err end end
-- (TakeInboxMoney: no other feature hooks it, and Upgrades' own hook on
-- the item calls read the header unguarded.)
Check(pcall(TakeInboxMoney, 1), "with an error handler, the error reached TakeInboxMoney's caller")
Check(caught and tostring(caught):find("the client said no", 1, true), "the error never reached the error handler")
_G.geterrorhandler = nil
_G.GetInboxHeaderInfo = header
auctions[600] = setmetatable({}, { __index = function() error("no auction") end })
Check(pcall(C_AuctionHouse.PlaceBid, 600, 1), "an error in the bid hook reached PlaceBid's caller")
Go(MULGORE)

--------------------------------------------------------------------------
Section("a client without the calls")

local saved2, savedChar2, now2 = _G.SocialDiaryDB, _G.SocialDiaryCharDB, mock.now
mock.Reset()
_G.SocialDiaryDB, _G.SocialDiaryCharDB = saved2, savedChar2
Client({ bare = true })
_G.GetMoney = nil
_G.GetProfessions = nil
mock.now = now2 + 10
mock.position = { x = 0.5, y = 0.6 }
mock.mapID = MULGORE
ns = T.Boot()
j = ns.db.journey[SELF.guid]
Settle()
local n = #Trips()
Go(ORGRIMMAR)
for _, event in ipairs({ "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "COMMODITY_PURCHASE_SUCCEEDED", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "PLAYER_MONEY", "SKILL_LINES_CHANGED",
    "NEW_RECIPE_LEARNED" }) do
    mock.fire(event, 1)
end
mock.RunTimers()
Eq(#Trips(), n + 1, "no trip without the purse or the auction house")
Eq(Last().came, nil, "a purse made up")
Made("Linen Bag", 4238)
Eq(Last().made[1].n, 1, "crafting lost with the auction house gone")
Go(THUNDER_BLUFF)
Eq(Last().mapID, THUNDER_BLUFF, "another city, another trip")
Eq(Trips()[n + 1].to, mock.now, "a trip into another city did not end the first")
