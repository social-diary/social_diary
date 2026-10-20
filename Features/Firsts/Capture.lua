-- Firsts found (JRN-24): the first bag, shoulders, green, blue and epic,
-- read off the bags as they change, and how each came.
--
-- Found, not worn: the moment it came into the bags. Everything comes in
-- by the bags (a bag the client puts in a bag slot itself still changes
-- them), so each BAG_UPDATE_DELAYED reads them all, and what is worn,
-- until every kind is found; after that nothing is read.
--
-- What is held the first time the bags are read after the diary was not
-- watching (a login, a /reload, the route's capture back on) was had out
-- of sight, never a first (Firsts.Held, Kind.lua). That reading waits a
-- few seconds after entering the world (SD_WORLD_SETTLED, Core/Events.lua:
-- fired by Capture/Journey.lua, whose own bag reading this was, in a
-- timer queued straight before the message's), or for the bags' own
-- update, and an empty backpack is not read at all: bags not yet loaded
-- are not "none".
--
-- How a first came, by what said so about that very item: a trade
-- completed just before, which held it (from whom: SD_TRADE_COMPLETED,
-- fired by the trade's capture as it stores the trade, with who it was
-- with and what was received); a letter's attachment taken (the client's
-- TakeInboxItem and AutoLootMailItem, hooked); the client's own loot line
-- ("You create: ..." made it, "You receive loot: ..." looted it, "You
-- receive item: ..." was handed over: a quest's reward or a purchase, by
-- whichever of those windows was open). An open mailbox alone says
-- nothing: a quest's reward, or something made, beside a mailbox once
-- read "came by mail" (bug, 20 Oct). With no word on the item, whichever
-- of the quest, vendor and loot windows was open or had just closed; a
-- line arriving after the bags changed still puts its word in.
--
-- Event order. This file is in the TOC's features' block, before
-- Capture/, where the reading was a block of Capture/Journey.lua; checked
-- event by event (15 Oct): BAG_UPDATE_DELAYED, MERCHANT_SHOW/CLOSED,
-- QUEST_COMPLETE and QUEST_FINISHED have no other listener; CHAT_MSG_LOOT
-- (20 Oct) is also the dungeons' and the hunts', which keep nothing this
-- reads; LOOT_OPENED is also the hunts' (Features/Hunts/Capture.lua,
-- after Capture/, so still after this), and here it only notes the
-- window's state, which nothing else reads; LOOT_CLOSED has no other. The
-- login reading is the first listener of SD_WORLD_SETTLED (Firsts load
-- before Profession caps, the other one), so it runs where its own timer
-- ran, straight before the message, as before. The trade's hand-off
-- comes at the point the trade's capture set it (synchronous), and is
-- read only here. So every order is the old one.
--
-- Watching is the route's: firsts are kept only while the route is
-- (ns.Journey.Kept: "Keep my own route" on, the logged-in character's own
-- route and not /sd testdata's), and the diary stops watching while it is
-- not, so the first reading after it comes back only arms.

local addonName, ns = ...

local Firsts = ns.Firsts

local FIRSTS = {
    source = 10,   -- how fresh a trade, a line or a closed window still says how it came
}

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

local watching = false
-- How the next find may have come: each window's state (true while it is
-- open, else when it closed).
local windows = {}
-- The last trade completed: { guid, t, received } (SD_TRADE_COMPLETED).
local lastTrade
-- What was said about an item as it came, by item ID: { from, t }, `from`
-- "mail", "craft", "loot" or "push" (handed over: a quest's or a vendor's).
local said = {}
-- The firsts just found, for a line that comes after the bags changed:
-- each { itemID, t, recs }.
local found = {}

local function Window(kind, open)
    windows[kind] = open or ns.Now()
end

local function Fresh(kind, now)
    local w = windows[kind]
    return w == true or (w ~= nil and now - w <= FIRSTS.source)
end

local function ItemID(link)
    return tonumber(type(link) == "string" and link:match("item:(%d+)") or nil)
end

-- An item as Firsts.Kinds reads it, from its link: the instant info needs
-- no item cache.
local function Item(link, quality)
    link = ns.Plain(link)
    local id = ItemID(link)
    if not id or not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    return { link = link, itemID = id, quality = ns.Plain(quality), equipLoc = ns.Plain(equipLoc),
        classID = ns.Plain(classID), subclassID = ns.Plain(subclassID) }
end

local function Worn(slot)
    return Item(GetInventoryItemLink("player", slot), GetInventoryItemQuality("player", slot))
end

-- Everything in the bags, in the bag slots and worn; nil while the
-- backpack does not read.
local function Held()
    local C = C_Container
    if not (C and C.GetContainerNumSlots) or (ns.Plain(C.GetContainerNumSlots(0)) or 0) <= 0 then return nil end
    local items = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, ns.Plain(C.GetContainerNumSlots(bag)) or 0 do
            local info = C.GetContainerItemInfo(bag, slot)
            if info then items[#items + 1] = Item(info.hyperlink, info.quality) end
        end
        if bag > 0 and C.ContainerIDToInventoryID then items[#items + 1] = Worn(C.ContainerIDToInventoryID(bag)) end
    end
    for slot = 1, 19 do items[#items + 1] = Worn(slot) end
    return items
end

-- Handed over: a quest's reward or a purchase, by the window.
local function Handed(now)
    if Fresh("quest", now) then return "quest" end
    if Fresh("vendor", now) then return "vendor" end
    return nil
end

-- How `item` came, as far as can be told: received in a trade just now
-- (from whom), else what was said about it, else whichever window was
-- open or just closed.
local function Came(item, now)
    local trade = lastTrade
    if trade and now - trade.t <= FIRSTS.source then
        for _, r in ipairs(trade.received or {}) do
            if ItemID(r.link) == item.itemID then return "trade", trade.guid end
        end
    end
    local word = said[item.itemID]
    if word and now - word.t <= FIRSTS.source then
        if word.from == "push" then return Handed(now) end
        return word.from
    end
    for _, kind in ipairs({ "quest", "vendor", "loot" }) do
        if Fresh(kind, now) then return kind end
    end
    return nil
end

-- Something said about an item as it came. A line after the letter it
-- came out of does not unsay the letter; a first found just before the
-- line takes its word.
local function Said(itemID, from)
    if not itemID then return end
    local now = ns.Now()
    local word = said[itemID]
    if from == "push" and word and word.from ~= "push" and now - word.t <= FIRSTS.source then return end
    said[itemID] = { from = from, t = now }
    for i = #found, 1, -1 do
        local f = found[i]
        if now - f.t > FIRSTS.source then
            table.remove(found, i)
        elseif f.itemID == itemID then
            local how = from == "push" and Handed(now) or from
            for _, rec in ipairs(f.recs) do
                if how and rec.from ~= "trade" and rec.from ~= "mail" then rec.from = how end
            end
        end
    end
end

local function Read()
    local j = ns.Journey.Kept()
    if not j then
        watching = false
        return
    end
    if j.firsts and not Firsts.Looking(j) then return end
    local items = Held()
    if not items then return end
    if not watching or not j.firsts then
        local held = {}
        for _, item in ipairs(items) do
            for _, kind in ipairs(Firsts.Kinds(item)) do held[kind] = true end
        end
        Firsts.Held(j, held)
        watching = true
        return
    end
    local now = ns.Now()
    for _, item in ipairs(items) do
        local recs = {}
        for _, kind in ipairs(Firsts.Kinds(item)) do
            if j.firsts[kind] == nil then
                local from, guid = Came(item, now)
                recs[#recs + 1] = Firsts.Found(j, kind, { t = now, level = Level(), link = item.link, from = from, guid = guid })
            end
        end
        if #recs > 0 then found[#found + 1] = { itemID = item.itemID, t = now, recs = recs } end
    end
end

ns.On("BAG_UPDATE_DELAYED", Read)

for kind, events in pairs({ vendor = { "MERCHANT_SHOW", "MERCHANT_CLOSED" },
    quest = { "QUEST_COMPLETE", "QUEST_FINISHED" }, loot = { "LOOT_OPENED", "LOOT_CLOSED" } }) do
    ns.On(events[1], function() Window(kind, true) end)
    ns.On(events[2], function() Window(kind) end)
end

-- A letter's attachments taken: one (TakeInboxItem), or all of them
-- (AutoLootMailItem, the client's "Open All" too). Hooked after the call,
-- while the letter still holds them: the server has not answered yet.
local function Letter(index, attachment)
    if type(GetInboxItemLink) ~= "function" then return end
    for a = attachment or 1, attachment or ATTACHMENTS_MAX_RECEIVE or 16 do
        Said(ItemID(ns.Plain(GetInboxItemLink(index, a))), "mail")
    end
end
if hooksecurefunc then
    if type(TakeInboxItem) == "function" then hooksecurefunc("TakeInboxItem", Letter) end
    if type(AutoLootMailItem) == "function" then
        hooksecurefunc("AutoLootMailItem", function(index) Letter(index) end)
    end
end

-- The user's own loot lines, in the client's words: what each says of how
-- the item came.
local LINES = {
    { "LOOT_ITEM_CREATED_SELF_MULTIPLE", "craft" }, { "LOOT_ITEM_CREATED_SELF", "craft" },
    { "LOOT_ITEM_SELF_MULTIPLE", "loot" }, { "LOOT_ITEM_SELF", "loot" },
    { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "push" }, { "LOOT_ITEM_PUSHED_SELF", "push" },
}
ns.OnChat("CHAT_MSG_LOOT", function(text)
    if not watching then return end
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    for _, line in ipairs(LINES) do
        local args = ns.ReadString(_G[line[1]], text)
        if args then return Said(ItemID(args[1]), line[2]) end
    end
end)

-- A trade completed: a first found just after it, among what was
-- received, was a gift from who it was with.
ns.On("SD_TRADE_COMPLETED", function(_, guid, received)
    lastTrade = { guid = guid, t = ns.Now(), received = received }
end)

-- The first reading after entering the world, which only arms.
ns.On("SD_WORLD_SETTLED", function() Read() end)
