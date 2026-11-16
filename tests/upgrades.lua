-- Upgrades (Features/Upgrades/): an item the diary saw arrive and then saw
-- worn for two minutes of play is one; what was had before, what comes
-- out of the bank, what is bought back or comes home by letter, and what
-- was put on out of sight never are; how each came; the seconds kept
-- across a swap and a logout; which one an entry leads with.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq

-- The client's loot lines (enUS), its mailbox and its buy-back, hooked as
-- the client's hooksecurefunc does. Set before the addon loads (the hooks
-- are made at load).
_G.LOOT_ITEM_CREATED_SELF = "You create: %s."
_G.LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
_G.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
local inbox, returned, buyback = {}, {}, {}
_G.GetInboxItemLink = function(index, attachment) return inbox[index] and inbox[index][attachment] end
_G.GetInboxHeaderInfo = function(index)
    return nil, nil, "Sender", "Subject", 0, 0, 30, 1, false, returned[index] == true
end
_G.TakeInboxItem = function() end
_G.AutoLootMailItem = function() end
_G.GetBuybackItemLink = function(index) return buyback[index] end
_G.BuybackItem = function() end
_G.hooksecurefunc = function(name, fn)
    local before = _G[name]
    _G[name] = function(...)
        local r = before(...)
        fn(...)
        return r
    end
end

local ns = T.Boot()

local J = ns.Journey
local Upgrades = ns.Upgrades
local Forget = ns._test.Upgrades.Forget
local SELF, GIVER = F.SELF, F.STRANGER
local MULGORE = 1412
local WORN = Upgrades.T.worn

-- A link as the client writes one: the suffix its 7th field, the
-- character's level its 9th.
local function Link(id, name, color, suffix, level, enchant)
    return ("|cff%s|Hitem:%d:%s:::::%s::%d:::::|h[%s]|h|r"):format(color or "ffffff", id, enchant or "",
        suffix or "", level or 10, name)
end
local GREEN, BLUE = "1eff00", "0070dd"

local OLD_BRACERS = Link(1423, "Worn Leather Bracers")
local BRACERS = Link(6070, "Wolfskin Bracers", GREEN)
local OLD_SET = Link(6071, "Tanking Bracers", GREEN)
local RING = Link(6072, "Brass Ring", GREEN)
local CLOAK = Link(6449, "Glowing Lizardscale Cloak", BLUE)
local SHIRT = Link(6073, "Fine Green Shirt", GREEN)
local POLE = Link(6074, "Lucky Fishing Pole", GREEN)
local WHITE = Link(6075, "Plain Vest")
local BELT = Link(6076, "Girdle of the Whale", GREEN, 1200)
local BOOTS = Link(6077, "Marsh Boots", GREEN)
local HELM = Link(6078, "Bog Helm", GREEN)
-- What the character wears before the diary looks, in every slot the
-- tests put something new into: an upgrade is measured against the last
-- thing of its kind worn there, and over nothing there is none.
local OLD_BELT = Link(6090, "Frayed Belt")
local OLD_BOOTS = Link(6091, "Frayed Shoes")
local OLD_HELM = Link(6092, "Frayed Cap")
local OLD_RING = Link(6093, "Copper Band")
local OLD_CLOAK = Link(6094, "Frayed Cloak")
for id, loc in pairs({ [6090] = "INVTYPE_WAIST", [6091] = "INVTYPE_FEET", [6092] = "INVTYPE_HEAD",
    [6093] = "INVTYPE_FINGER", [6094] = "INVTYPE_CLOAK" }) do
    mock.itemInfo[id] = { classID = 4, subclassID = 1, equipLoc = loc }
end
for id, loc in pairs({ [1423] = "INVTYPE_WRIST", [6070] = "INVTYPE_WRIST", [6071] = "INVTYPE_WRIST",
    [6072] = "INVTYPE_FINGER", [6449] = "INVTYPE_CLOAK", [6073] = "INVTYPE_BODY", [6075] = "INVTYPE_CHEST",
    [6076] = "INVTYPE_WAIST", [6077] = "INVTYPE_FEET", [6078] = "INVTYPE_HEAD" }) do
    mock.itemInfo[id] = { classID = 4, subclassID = 2, equipLoc = loc }
end
mock.itemInfo[6074] = { classID = 2, subclassID = 20, equipLoc = "INVTYPE_2HWEAPON" }

-- Item levels, as the client has them once an item is cached.
local ILVL = { [1423] = 5, [6070] = 17, [6449] = 23, [6076] = 16, [6090] = 10 }
_G.C_Item.GetDetailedItemLevelInfo = function(link)
    return ILVL[tonumber(tostring(link):match("item:(%d+)"))]
end

local function Put(slot, link, quality)
    mock.bags[0][slot] = link and { link = link, quality = quality or 1 } or nil
end

local function Wear(slot, link, quality)
    mock.equipped[slot] = link and { link = link, quality = quality or 1 } or nil
    mock.fire("PLAYER_EQUIPMENT_CHANGED", slot, link ~= nil)
end

local function Bags()
    mock.fire("BAG_UPDATE_DELAYED")
end

-- Play goes by, the waiting check run as the client's timer would.
local function Pass(seconds)
    mock.now = mock.now + seconds
    mock.RunTimers()
end

-- A session ends (as far as the capture knows) and another begins.
local function Login(away)
    mock.fire("PLAYER_LOGOUT")
    Forget()
    mock.now = mock.now + (away or 3600)
    mock.fire("PLAYER_ENTERING_WORLD")
    mock.RunTimers()
end

--------------------------------------------------------------------------
Section("an item's key")

Eq(Upgrades.Key(BRACERS), "6070:0", "a plain item")
Eq(Upgrades.Key(BELT), "6076:1200", "a random suffix is part of it")
Eq(Upgrades.Key(Link(6070, "Wolfskin Bracers", GREEN, nil, 37)), "6070:0", "the character's level is part of it")
Eq(Upgrades.Key(Link(6070, "Wolfskin Bracers", GREEN, nil, 10, 41)), "6070:0", "an enchant is part of it")
Eq(Upgrades.Key("|cff1eff00|Hitem:6070::::::::10::::2:501:502:|h[Wolfskin Bracers]|h|r"), "6070:0:501:502",
    "bonus IDs are not part of it")
Eq(Upgrades.Key("|cffffffff|Hspell:17|h[Shield]|h|r"), nil, "a spell has a key")
Eq(Upgrades.Key(nil), nil, "nothing has a key")

--------------------------------------------------------------------------
Section("what could be an upgrade")

Check(Upgrades.Counts({ quality = 2, equipLoc = "INVTYPE_WRIST", classID = 4 }), "a green is left out")
Check(not Upgrades.Counts({ quality = 1, equipLoc = "INVTYPE_CHEST", classID = 4 }), "a white counts")
Check(not Upgrades.Counts({ quality = 2, equipLoc = "INVTYPE_BODY", classID = 4 }), "a shirt counts")
Check(not Upgrades.Counts({ quality = 3, equipLoc = "INVTYPE_TABARD", classID = 4 }), "a tabard counts")
Check(not Upgrades.Counts({ quality = 2, equipLoc = "INVTYPE_BAG", classID = 1 }), "a bag counts")
Check(not Upgrades.Counts({ quality = 2, equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 20 }),
    "a fishing pole counts")
Check(not Upgrades.Counts({ quality = 2, equipLoc = "", classID = 15 }), "something not worn counts")
Check(not Upgrades.Counts({ equipLoc = "INVTYPE_WRIST" }), "an item of no known quality counts")

--------------------------------------------------------------------------
Section("what was had before the diary looked never counts")

-- Two sets, both old: one worn, one in the bags.
mock.equipped[9] = { link = OLD_BRACERS, quality = 1 }
for slot, link in pairs({ [6] = OLD_BELT, [8] = OLD_BOOTS, [1] = OLD_HELM, [11] = OLD_RING, [15] = OLD_CLOAK }) do
    mock.equipped[slot] = { link = link, quality = 1 }
end
Put(1, OLD_SET, 2)
mock.fire("PLAYER_ENTERING_WORLD")
local j = ns.db.journey[SELF.guid]
Check(j, "setup: no route")
-- A slot changing as the character loads does not arm.
mock.fire("PLAYER_EQUIPMENT_CHANGED", 9, true)
Put(2, RING, 2)
mock.RunTimers()
Eq(#(j.fitting or {}), 0, "what was held at the first look became a candidate")
-- Swapped, however often.
Put(1, OLD_BRACERS)
Wear(9, OLD_SET, 2)
Bags()
Pass(WORN + 5)
Put(1, OLD_SET, 2)
Wear(9, OLD_BRACERS)
Bags()
Eq(#(j.fitting or {}), 0, "a swap of old gear made a candidate")
Eq(#Upgrades.List(j), 0, "a swap of old gear was an upgrade")
Put(1, nil)
Put(2, nil)
Bags()

--------------------------------------------------------------------------
Section("seen arriving, put on, worn two minutes")

mock.now = mock.now + 600
mock.fire("LOOT_OPENED")
Put(1, BRACERS, 2)
Bags()
mock.fire("LOOT_CLOSED")
local found = mock.now
local cand = j.fitting and j.fitting[1]
Check(cand, "a green seen arriving is no candidate")
Eq(cand.key, "6070:0", "which item")
Eq(cand.from, "loot", "how it came")
Eq(cand.on, nil, "a candidate in the bags is put on")
Eq(#Upgrades.List(j), 0, "an item in the bags is an upgrade")

mock.now = mock.now + 300
mock.position = { x = 0.5, y = 0.25 }
Put(1, OLD_BRACERS)
Wear(9, BRACERS, 2)
Bags()
local put = mock.now
Check(cand.on, "the candidate was not put on")
Eq(cand.on.was, OLD_BRACERS, "what it took the place of")
Pass(WORN - 30)
Eq(#Upgrades.List(j), 0, "an upgrade before its two minutes")
mock.position = { x = 0.9, y = 0.9 }
Pass(40)
local up = Upgrades.List(j)[1]
Check(up, "worn two minutes, it is no upgrade")
Eq(up.t, put, "dated when it was first put on")
Eq(up.mapID, MULGORE, "the zone it was put on in")
Eq(up.x, 0.5, "placed where it was put on, not where the minutes ended")
Eq(up.link, BRACERS, "which item")
Eq(up.key, "6070:0", "its key")
Eq(up.quality, 2, "its quality")
Eq(up.slot, 9, "its slot")
Eq(up.from, "loot", "how it came")
Eq(up.found, found, "when it arrived")
Eq(up.ilvl, 17, "its item level")
Eq(up.was and up.was.link, OLD_BRACERS, "what it replaced")
Eq(up.was and up.was.ilvl, 5, "the replaced item's level")
Check(up.level, "the level it was put on at")
Eq(#j.fitting, 0, "an upgrade is still a candidate")
Eq(Upgrades.Gain(up), 12, "its gain")

-- Nothing counts twice: sold, bought again as new.
Put(1, nil)
Wear(9, OLD_BRACERS)
Bags()
Put(1, BRACERS, 2)
Bags()
Eq(#j.fitting, 0, "an upgrade arriving again is a candidate again")
Put(1, nil)
Bags()

--------------------------------------------------------------------------
Section("the seconds are kept across a swap")

Put(2, BELT, 2)
Bags()
cand = Upgrades.Candidate(j, "6076:1200")
Check(cand, "setup: no candidate")
Put(2, nil)
Wear(6, BELT, 2)
Bags()
local first = mock.now
Pass(50)
-- Taken off for a fight.
Wear(6, nil)
Put(2, BELT, 2)
Bags()
Eq(cand.worn, 50, "the seconds worn before it was taken off")
Pass(900)
Eq(cand.worn, 50, "seconds counted while it was off")
Eq(#Upgrades.List(j), 1, "an upgrade while it was off")
Put(2, nil)
Wear(6, BELT, 2)
Bags()
Pass(WORN - 50 - 10)
Eq(#Upgrades.List(j), 1, "an upgrade ten seconds early")
Pass(15)
up = Upgrades.List(j)[2]
Check(up, "two minutes in two goes are no upgrade")
Eq(up.t, first, "dated at the first put-on, not the second")
Eq(up.was and up.was.link, OLD_BELT, "what it took the place of")
Eq(Upgrades.Gain(up), 6, "its gain")

--------------------------------------------------------------------------
Section("the seconds are kept across a logout, and time away is not play")

mock.fire("QUEST_COMPLETE")
Put(3, BOOTS, 2)
Bags()
mock.fire("QUEST_FINISHED")
cand = Upgrades.Candidate(j, "6077:0")
Eq(cand and cand.from, "quest", "a quest's reward, how it came")
Put(3, nil)
Wear(8, BOOTS, 2)
Bags()
Pass(70)
Login(86400)
Eq(cand.worn, 70, "the seconds written down at logout")
Eq(#Upgrades.List(j), 2, "a day away counted as worn")
Pass(WORN - 70 - 10)
Eq(#Upgrades.List(j), 2, "an upgrade ten seconds early, after a login")
Pass(15)
Eq(#Upgrades.List(j), 3, "worn on over a logout, it is no upgrade")
Eq(Upgrades.List(j)[3].ilvl, nil, "an item level the client did not give")
Eq(Upgrades.Gain(Upgrades.List(j)[3]), nil, "with no level read there is a gain")

--------------------------------------------------------------------------
Section("put on or gone out of sight")

Put(3, HELM, 2)
Bags()
Check(Upgrades.Candidate(j, "6078:0"), "setup: no candidate")
-- Put on while the diary was not watching.
mock.fire("PLAYER_LOGOUT")
Forget()
Put(3, nil)
mock.equipped[1] = { link = HELM, quality = 2 }
mock.fire("PLAYER_ENTERING_WORLD")
mock.RunTimers()
Eq(Upgrades.Candidate(j, "6078:0"), nil, "a candidate put on out of sight is kept")
Pass(WORN + 5)
Eq(#Upgrades.List(j), 3, "put on out of sight, it is an upgrade")
mock.equipped[1] = nil

-- Gone while the diary was not watching.
Put(3, RING, 2)
Bags()
Check(Upgrades.Candidate(j, "6072:0"), "setup: no candidate")
mock.fire("PLAYER_LOGOUT")
Forget()
Put(3, nil)
mock.fire("PLAYER_ENTERING_WORLD")
mock.RunTimers()
Eq(Upgrades.Candidate(j, "6072:0"), nil, "a candidate gone out of sight is kept")

-- Sold in sight.
Put(3, RING, 2)
Bags()
Check(Upgrades.Candidate(j, "6072:0"), "setup: no candidate")
Put(3, nil)
Bags()
Eq(Upgrades.Candidate(j, "6072:0"), nil, "a candidate that left the bags is kept")

-- A slot that reads empty for a moment is not "gone".
Put(3, RING, 2)
Bags()
Put(3, nil)
Wear(11, RING, 2)
Bags()
mock.equipped[11] = nil
Bags()
Check(Upgrades.Candidate(j, "6072:0"), "a worn candidate was given up when its slot read empty")
mock.equipped[11] = { link = RING, quality = 2 }
Bags()
Pass(WORN + 5)
Eq(#Upgrades.List(j), 4, "the ring, worn on, is no upgrade")

--------------------------------------------------------------------------
Section("the bank")

_G.BANK_CONTAINER = -1
local function Bank(open)
    mock.bags[-1] = open and (mock.bank or { size = 24 }) or nil
    if not open then mock.bank = nil end
    mock.fire(open and "BANKFRAME_OPENED" or "BANKFRAME_CLOSED")
end
local function Banked(slot, link, quality)
    mock.bags[-1][slot] = link and { link = link, quality = quality or 1 } or nil
end

-- Old gear in the bank, taken out and put on.
mock.bank = { size = 24, [1] = { link = OLD_SET, quality = 2 } }
Bank(true)
Banked(1, nil)
Put(4, OLD_SET, 2)
Bags()
Eq(Upgrades.Candidate(j, "6071:0"), nil, "what came out of the bank is a candidate")
-- A reward taken beside the banker is an arrival all the same.
mock.fire("QUEST_COMPLETE")
Put(5, CLOAK, 3)
Bags()
mock.fire("QUEST_FINISHED")
cand = Upgrades.Candidate(j, "6449:0")
Check(cand, "an arrival with the bank open is no candidate")
-- A candidate put into the bank stays one, and comes out as one.
Put(5, nil)
Banked(2, CLOAK, 3)
Bags()
Check(Upgrades.Candidate(j, "6449:0") == cand, "a candidate put into the bank was given up")
Eq(cand.banked, true, "a candidate in the bank is not marked so")
mock.bank = mock.bags[-1]
Bank(false)
mock.bags[-1] = nil
Login()
Check(Upgrades.Candidate(j, "6449:0") == cand, "a banked candidate was given up at login")
mock.bank = { size = 24, [2] = { link = CLOAK, quality = 3 } }
Bank(true)
Banked(2, nil)
Put(5, CLOAK, 3)
Bags()
Eq(cand.banked, nil, "a candidate out of the bank is still marked banked")
Eq(#j.fitting, 1, "a candidate out of the bank arrived a second time")
Bank(false)
Put(4, nil)
Put(5, nil)
Bags()
Eq(#j.fitting, 0, "setup: candidates left over")

-- Where the bank's contents do not read, the open window says it.
_G.BANK_CONTAINER = nil
mock.fire("BANKFRAME_OPENED")
Put(4, HELM, 2)
Bags()
Eq(Upgrades.Candidate(j, "6078:0"), nil, "an arrival at an unreadable bank is a candidate")
mock.fire("BANKFRAME_CLOSED")
Put(4, nil)
Bags()

--------------------------------------------------------------------------
Section("old gear coming home, and a letter")

-- Bought back.
mock.fire("MERCHANT_SHOW")
buyback[1] = HELM
BuybackItem(1)
Put(4, HELM, 2)
Bags()
Eq(Upgrades.Candidate(j, "6078:0"), nil, "what was bought back is a candidate")
Put(4, nil)
Bags()
-- Bought.
mock.now = mock.now + 60
mock.fire("CHAT_MSG_LOOT", ("You receive item: %s."):format(HELM), "", "", "", "", "", "", "", "", "", 1, SELF.guid)
Put(4, HELM, 2)
Bags()
cand = Upgrades.Candidate(j, "6078:0")
Eq(cand and cand.from, "vendor", "something bought, how it came")
mock.fire("MERCHANT_CLOSED")
Put(4, nil)
Bags()

-- A letter come back to its sender.
mock.now = mock.now + 60
inbox[1], returned[1] = { HELM }, true
TakeInboxItem(1, 1)
Put(4, HELM, 2)
Bags()
Eq(Upgrades.Candidate(j, "6078:0"), nil, "a returned letter's item is a candidate")
Put(4, nil)
Bags()
-- A letter.
mock.now = mock.now + 60
returned[1] = nil
AutoLootMailItem(1)
Put(4, HELM, 2)
Bags()
cand = Upgrades.Candidate(j, "6078:0")
Eq(cand and cand.from, "mail", "a letter's item, how it came")
Put(4, nil)
Bags()

--------------------------------------------------------------------------
Section("a gift that was worn")

mock.now = mock.now + 60
local CAPE = Link(6079, "Traveller's Cape", BLUE)
mock.itemInfo[6079] = { classID = 4, subclassID = 1, equipLoc = "INVTYPE_CLOAK" }
ns.Fire("SD_TRADE_COMPLETED", GIVER.guid, { { link = CAPE, count = 1 } })
Put(4, CAPE, 3)
Bags()
cand = Upgrades.Candidate(j, "6079:0")
Eq(cand and cand.from, "trade", "a gift, how it came")
Eq(cand and cand.guid, GIVER.guid, "who gave it")
Put(4, nil)
Wear(15, CAPE, 3)
Bags()
local worn = mock.now
Pass(WORN + 5)
up = Upgrades.List(j)[#Upgrades.List(j)]
Eq(up.key, "6079:0", "the gift, worn, is no upgrade")
Eq(up.guid, GIVER.guid, "the upgrade's giver")
local rows = ns.db.interactions[GIVER.guid] or {}
local row = rows[#rows]
Eq(row and row.type, "gift_worn", "no row on the giver")
Eq(row and row.time, worn, "the row is at the first put-on")
Eq(row and row.context and row.context.link, CAPE, "the row's item")
Check(type(ns.Rows.Get("gift_worn").text(row)) == "string", "the row has no words")

-- PRV-3: the giver forgotten leaves the record, and a gift stays a gift.
ns.Fire("SD_TRADE_COMPLETED", GIVER.guid, { { link = SHIRT, count = 1 }, { link = WHITE, count = 1 },
    { link = POLE, count = 1 } })
Put(4, SHIRT, 2)
Put(5, WHITE, 1)
Put(6, POLE, 2)
Bags()
Eq(#j.fitting, 0, "a shirt, a white or a fishing pole is a candidate")
local GLOVES = Link(6080, "Mossy Gloves", GREEN)
mock.itemInfo[6080] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_HAND" }
ns.Fire("SD_TRADE_COMPLETED", GIVER.guid, { { link = GLOVES, count = 1 } })
Put(7, GLOVES, 2)
Bags()
Eq(Upgrades.Candidate(j, "6080:0").guid, GIVER.guid, "setup: the candidate's giver")
J.LISTS.upgrades.forget(j, GIVER.guid)
Eq(up.guid, nil, "a forgotten giver is still on the upgrade")
Eq(up.from, "trade", "a forgotten giver's gift is no gift")
Eq(Upgrades.Candidate(j, "6080:0").guid, nil, "a forgotten giver is still on the candidate")

--------------------------------------------------------------------------
Section("measured against the last thing of its own kind")

-- A warrior's hands (the user, 16 Nov): two old swords, and an old
-- shield put on to tank. Each item to the bags' slot `bag` and from there
-- into `slot`, what was there going to the bags, as the client does it.
local SWORD_A, SWORD_B = Link(7001, "Notched Sword"), Link(7002, "Rusty Sword")
local OLD_SHIELD, SHIELD = Link(7003, "Battered Buckler"), Link(7004, "Ironbound Shield", GREEN)
local SWORD_C, GREATSWORD, SWORD_E = Link(7005, "Keen Blade", GREEN), Link(7006, "Greatsword", GREEN),
    Link(7007, "Fine Blade", GREEN)
local RING_2, WRIST_X, WRIST_Y = Link(7008, "Silver Band", GREEN), Link(7009, "Spiked Bracers", GREEN),
    Link(7010, "Studded Bracers", GREEN)
for id, v in pairs({ [7001] = { 2, 7, "INVTYPE_WEAPON" }, [7002] = { 2, 7, "INVTYPE_WEAPON" },
    [7003] = { 4, 6, "INVTYPE_SHIELD" }, [7004] = { 4, 6, "INVTYPE_SHIELD" }, [7005] = { 2, 7, "INVTYPE_WEAPON" },
    [7006] = { 2, 8, "INVTYPE_2HWEAPON" }, [7007] = { 2, 7, "INVTYPE_WEAPON" }, [7008] = { 4, 0, "INVTYPE_FINGER" },
    [7009] = { 4, 2, "INVTYPE_WRIST" }, [7010] = { 4, 2, "INVTYPE_WRIST" } }) do
    mock.itemInfo[id] = { classID = v[1], subclassID = v[2], equipLoc = v[3] }
end
ILVL[7001], ILVL[7002], ILVL[7003], ILVL[7004], ILVL[7005], ILVL[7007], ILVL[7010] = 20, 20, 18, 26, 24, 25, 20
local function Swap(slot, link, bag)
    local old = mock.equipped[slot]
    Put(bag, old and old.link or nil, old and old.quality)
    Wear(slot, link, 2)
    Bags()
end
local function Looted(bag, link)
    mock.fire("LOOT_OPENED")
    Put(bag, link, 2)
    Bags()
    mock.fire("LOOT_CLOSED")
end
local function Measure(slot, kind) return Upgrades.Before(j, slot, kind) end
local count = #Upgrades.List(j)

-- What the character had: put on before the diary looked.
mock.fire("PLAYER_LOGOUT")
Forget()
mock.equipped[16] = { link = SWORD_A, quality = 1 }
mock.equipped[17] = { link = SWORD_B, quality = 1 }
Put(10, OLD_SHIELD)
mock.fire("PLAYER_ENTERING_WORLD")
mock.RunTimers()
Eq(Measure(16, "one-hand"), SWORD_A, "the main hand's sword, worn at the first look, is no measure")
local fitting = #j.fitting

-- 1. Old gear swapped for a dungeon and back: nothing.
Swap(17, OLD_SHIELD, 10)
Pass(1800)
Swap(17, SWORD_B, 10)
Eq(#j.fitting, fitting, "old gear swapped made a candidate")
Eq(#Upgrades.List(j), count, "old gear swapped made an upgrade")
Eq(Measure(17, "shield"), OLD_SHIELD, "the old shield is no measure for shields")
Eq(Measure(17, "one-hand"), SWORD_B, "the shield took the sword's place as the measure for swords")

-- 2. A sword found while tanking, put on after the dungeon over the shield.
Swap(17, OLD_SHIELD, 10)
Looted(11, SWORD_C)
Pass(1800)
Put(11, nil)
Swap(17, SWORD_C, 10)
Pass(WORN + 5)
local rec = Upgrades.List(j)[#Upgrades.List(j)]
Eq(rec and rec.key, "7005:0", "the sword worn after the dungeon is no upgrade")
Eq(rec and rec.was and rec.was.link, SWORD_B, "a sword put on over the shield took the shield's place")
Eq(Upgrades.Gain(rec), 4, "the sword's gain over the sword")
Eq(Measure(17, "one-hand"), SWORD_C, "the upgrade is not the measure from now")
count = #Upgrades.List(j)

-- 3. A new shield, worn only to tank: it takes the old shield's place.
Looted(12, SHIELD)
Put(12, nil)
Swap(17, SHIELD, 12)
Pass(1800)
Swap(17, SWORD_C, 12)
rec = Upgrades.List(j)[#Upgrades.List(j)]
Eq(rec and rec.key, "7004:0", "a shield worn for a dungeon is no upgrade")
Eq(rec and rec.was and rec.was.link, OLD_SHIELD, "a shield put on over the sword took the sword's place")
Eq(Upgrades.Gain(rec), 8, "the shield's gain over the shield")
count = #Upgrades.List(j)

-- 4. A first two-hander: nothing of its kind before, no upgrade; it is
-- the measure for two-handers from now.
Looted(13, GREATSWORD)
Put(13, nil)
local offHand = mock.equipped[17]
mock.equipped[17] = nil
Put(14, offHand.link, offHand.quality)
Swap(16, GREATSWORD, 13)
Eq(Upgrades.Candidate(j, "7006:0"), nil, "a first two-hander is still a candidate")
Pass(WORN + 5)
Eq(#Upgrades.List(j), count, "a first two-hander is an upgrade")
Eq(Measure(16, "two-hand"), GREATSWORD, "the first two-hander is no measure for two-handers")

-- 5. A week with the two-hander, then back to swords with a new one in
-- the off hand: it took the place of the last sword worn there.
Login(7 * 86400)
Looted(15, SWORD_E)
Swap(16, SWORD_A, 13)
Put(14, nil)
Swap(17, SWORD_E, 15)
Pass(WORN + 5)
rec = Upgrades.List(j)[#Upgrades.List(j)]
Eq(rec and rec.key, "7007:0", "the new off-hand sword is no upgrade")
Eq(rec and rec.was and rec.was.link, SWORD_C, "it was not measured against the sword worn before the two-hander")
count = #Upgrades.List(j)

-- An empty finger: nothing to measure against.
Looted(13, RING_2)
Put(13, nil)
Wear(12, RING_2, 2)
Bags()
Eq(Upgrades.Candidate(j, "7008:0"), nil, "a ring on an empty finger is still a candidate")
Eq(Measure(12, "piece"), RING_2, "the ring on the empty finger is no measure there")

-- A ring moved to the other hand is still worn: the new one took no
-- one's place.
local onLeft = mock.equipped[11]
mock.equipped[11] = nil
Wear(12, onLeft.link, onLeft.quality)
Looted(13, Link(7011, "Gold Band", GREEN))
mock.itemInfo[7011] = { classID = 4, subclassID = 0, equipLoc = "INVTYPE_FINGER" }
Put(13, nil)
Put(14, RING_2, 2)
Wear(11, Link(7011, "Gold Band", GREEN), 2)
Bags()
Eq(Upgrades.Candidate(j, "7011:0"), nil, "a ring measured against one still worn is a candidate")
Put(14, nil)
Bags()

-- A piece tried on and taken off again is never the measure.
Looted(13, WRIST_X)
Put(13, nil)
Put(14, OLD_BRACERS)
Wear(9, WRIST_X, 2)
Bags()
Pass(30)
Put(14, WRIST_X, 2)
Wear(9, OLD_BRACERS)
Bags()
Eq(Measure(9, "piece"), OLD_BRACERS, "a piece tried on is the measure")
Looted(15, WRIST_Y)
Put(15, nil)
Wear(9, WRIST_Y, 2)
Put(14, OLD_BRACERS)
Bags()
-- The old bracers' level is read as they are taken off: the client may
-- have lost it by the time the minutes are up.
ILVL[1423] = nil
Pass(WORN + 5)
ILVL[1423] = 5
rec = Upgrades.List(j)[#Upgrades.List(j)]
Eq(rec and rec.key, "7010:0", "setup: the bracers are no upgrade")
Eq(rec and rec.was and rec.was.link, OLD_BRACERS, "measured against a piece only tried on")
Eq(Upgrades.Gain(rec), 15, "the old piece's level, read at the put-on, was lost")
Put(13, nil)
Put(14, nil)
Bags()

--------------------------------------------------------------------------
Section("a swap read half done")

-- Equipping from the bags, the client changes the bag slot and the worn
-- slot one at a time; PLAYER_EQUIPMENT_CHANGED may read between the two,
-- with the new piece nowhere (seen in the client, 16 Nov). Only the
-- bags' own update, which follows, tells what came and went.
local LEGS_OLD = Link(7020, "Hunting Trousers", GREEN)
local LEGS_NEW = Link(7021, "Scouting Trousers", GREEN)
mock.itemInfo[7020] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_LEGS" }
mock.itemInfo[7021] = { classID = 4, subclassID = 2, equipLoc = "INVTYPE_LEGS" }
Swap(7, LEGS_OLD, 16)
Put(16, nil)
Bags()
count = #Upgrades.List(j)
Looted(16, LEGS_NEW)
Check(Upgrades.Candidate(j, "7021:0"), "setup: the new trousers are no candidate")
-- Half done: the old pair is in the bag slot, the new one not yet worn.
Put(16, LEGS_OLD, 2)
mock.fire("PLAYER_EQUIPMENT_CHANGED", 7, true)
Check(Upgrades.Candidate(j, "7021:0"), "a piece read nowhere mid-swap was given up")
-- Done.
Wear(7, LEGS_NEW, 2)
Bags()
Pass(WORN + 5)
rec = Upgrades.List(j)[#Upgrades.List(j)]
Eq(#Upgrades.List(j), count + 1, "the trousers swapped in are no upgrade")
Eq(rec and rec.was and rec.was.link, LEGS_OLD, "they were not measured against the pair taken off")
-- And an old piece read nowhere mid-swap does not come back as arriving.
Put(16, LEGS_NEW, 2)
mock.fire("PLAYER_EQUIPMENT_CHANGED", 7, true)
Wear(7, LEGS_OLD, 2)
Bags()
Eq(Upgrades.Candidate(j, "7020:0"), nil, "an old piece read nowhere mid-swap became a candidate")

--------------------------------------------------------------------------
Section("which one an entry leads with")

local function Rec(t, quality, level, ilvl, was)
    return { t = t, quality = quality, level = level, ilvl = ilvl, was = was and { ilvl = was } or nil }
end
Check(Upgrades.Opens(Rec(1, 2, 20)), "a green at level 20 opens no plate")
Check(not Upgrades.Opens(Rec(1, 2, 21)), "a green at level 21 opens a plate")
Check(Upgrades.Opens(Rec(1, 3, 45)), "a blue at level 45 opens no plate")
Check(Upgrades.Opens(Rec(1, 4, 60)), "an epic opens no plate")

local a, b, c = Rec(100, 2, 12, 20, 15), Rec(200, 2, 12, 22, 10), Rec(300, 3, 12, 25, 20)
Eq(Upgrades.Best({ a, b, c }), b, "the largest gain does not lead")
Eq(Upgrades.Best({ a, Rec(150, 3, 12, 30, 25) }).quality, 3, "at the same gain, the better quality does not lead")
Eq(Upgrades.Best({ Rec(150, 2, 12, 30, 25), a }), a, "at the same gain and quality, the earlier does not lead")
Eq(Upgrades.Best({}), nil, "the best of none")
Eq(Upgrades.Best({ Rec(100, 4, 12, 30), a }), a, "a gain that did not read led over one that did")

local k = { upgrades = { a, b, c, Rec(5000, 2, 30, 40, 30), Rec(5100, 2, 30, 42, 41) } }
local lead, pieces = Upgrades.Split(k, 0, 1000)
Eq(lead, b, "an entry's lead")
Eq(#pieces, 2, "the others are not its pieces")
-- A green after level 20 leads nothing: all of them are pieces.
lead, pieces = Upgrades.Split(k, 4000, 6000)
Eq(lead, nil, "a green after level 20 leads an entry")
Eq(#pieces, 2, "the greens after level 20 are not pieces")
lead, pieces = Upgrades.Split(k, 9000, 9999)
Eq(lead, nil, "an entry with no upgrade has a lead")
Eq(#pieces, 0, "an entry with no upgrade has pieces")
