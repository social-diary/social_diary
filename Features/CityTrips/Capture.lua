-- City trips: a visit to a capital, from arriving to leaving, and the
-- errands run on it, read off the client as they happen (Kind.lua has what
-- is kept; the signals, and what the client round still has to prove, are
-- in .claude/features/city-trips.md). Nothing here is proven in the
-- client: the probe has not run. Every client call is looked up before it
-- is made, every value it hands back goes through ns.Plain before it is
-- compared or kept, and a call this build lacks only means that errand is
-- not written down.
--
-- The trip's life. It opens on arriving: the first reading that finds the
-- player in a city (ns.City, the settings' list), on foot (not on a taxi)
-- and outside an instance. Arriving rather than at the first errand,
-- because two things a trip keeps are only true then: the purse the
-- player came with, and each profession's rank before the first craft. A
-- trip in which nothing was done (passing through, a vendor, the purse
-- alone) is dropped as it closes, so opening early writes nothing that
-- lasts. It closes:
--   - on leaving the city: a reading finds another place (ZONE_CHANGED_
--     NEW_AREA, the heartbeat, or any errand's own reading);
--   - on a taxi taking off (PLAYER_CONTROL_LOST, then the heartbeat) and on
--     entering an instance (PLAYER_ENTERING_WORLD): neither is "in a city";
--   - on the route no longer being kept (ns.Journey.Kept);
--   - when the player was away longer than a sitting's gap (ns.Sittings.GAP:
--     AFK in town for an evening, the client left open), at the last moment
--     it was seen, and a new trip opens if they are still in town;
--   - at logout. PLAYER_LOGOUT comes for a /reload too, and the two cannot
--     be told apart there, so the logout writes the end (`to`) and leaves
--     the trip unsettled (`seen`); the next load settles it: still in the
--     same city within T.resume of that moment, it carries on (a /reload,
--     a relog to change a setting), else it ended where it was last seen.
-- A load only settles a trip once the world has (SD_WORLD_SETTLED): during
-- the loading screen the map may not read yet, and a city read as "not
-- yet anywhere" would cut a reloaded trip in two. Errands in those few
-- seconds are not written down. One trip is open at most, always the last
-- on the list.
--
-- The errands, each from its own signal, and only inside a trip (an errand
-- in the field, cooking at a fire or a letter at a small town's box, is
-- not this feature's business):
--   - auctions put up: C_AuctionHouse.PostItem / PostCommodity, hooked,
--     for the item (from its bag location) and how many; written when
--     AUCTION_HOUSE_AUCTION_CREATED confirms it. As Syndicator learns its
--     postings on this client (Tracking/AuctionCacheModern.lua);
--   - auctions bought: C_AuctionHouse.PlaceBid, hooked, read through
--     GetAuctionInfoByID while the auction is still listed (the item, how
--     many, the bid paid, the seller where a single one is named), written
--     when AUCTION_HOUSE_PURCHASE_COMPLETED names the same auction (a bid
--     that is not a buyout never gets one here; won later, its letter says
--     so); ConfirmCommoditiesPurchase for a commodity, written on
--     COMMODITY_PURCHASE_SUCCEEDED, paid by the purse's drop between the
--     two where it dropped;
--   - letters, read at the moment something is taken out of one, in the
--     TakeInboxMoney / TakeInboxItem / AutoLootMailItem post-hooks, when
--     the server has not answered yet and the letter still holds it (as
--     Firsts and Upgrades read theirs): GetInboxHeaderInfo, and
--     GetInboxInvoiceInfo for the auction house's. A sale's invoice is a
--     lot sold (the coin taken from it, the buyer); a purchase's invoice a
--     lot won, unless it was bought on this trip already; "Auction
--     expired" or "Auction cancelled" (the client's own subjects) a lot
--     come back; a letter a player can be answered is a letter from them.
--     The rest (a returned letter of one's own, an NPC's letter, a sale
--     still pending) is none of these. Each letter counts once, however
--     many takes empty it, and its coin and each attachment once;
--   - letters sent: SendMail, hooked, for the recipient's name and what is
--     attached then (GetSendMailItem, GetSendMailMoney), written when
--     MAIL_SEND_SUCCESS confirms it (MAIL_FAILED drops it);
--   - crafting: the client's "You create" loot line (LOOT_ITEM_CREATED_
--     SELF and its _MULTIPLE), parsed exactly as Firsts and Upgrades parse
--     it: the signal already working in this addon.
--     TRADE_SKILL_ITEM_CRAFTED_RESULT is unproven here, and counting from
--     both would count twice;
--   - professions: every rank read on opening (GetProfessions,
--     GetProfessionInfo, as Profession caps reads them) and again, a burst
--     gathered into one reading, on SKILL_LINES_CHANGED / CHAT_MSG_SKILL
--     (the line is a cue, never read: its words can be secret); a rank
--     above the opening one is a climb. A new recipe: NEW_RECIPE_LEARNED;
--   - quests: SD_QUEST_ACCEPTED and SD_QUEST_TURNED_IN (fired by the route
--     once it counted them), the title from C_QuestLog.GetTitleForQuestID,
--     and for one handed in, who of the party was on it
--     (C_QuestLog.IsUnitOnQuest on party1 to party4);
--   - the purse: GetMoney on opening, on PLAYER_MONEY and on leaving.
--
-- People. A name off a letter, an invoice or an auction is looked up among
-- the player's own characters (ns.OwnCharacters) and the people the diary
-- knows (Characters.FindByName); one it does not know, or knows twice, is
-- counted and its name dropped on the spot. Names live only in this file's
-- memory, for the few seconds between a hook and its confirmation, and in
-- a letter's fingerprint for the trip (so it counts once): never saved.
--
-- Hooks are the client's hooksecurefunc only (a post-hook: the game's call
-- has run, untouched, before ours), each through Safe, so an error in ours
-- goes to the error handler and never back into the game's call. Nothing
-- protected is replaced or called.
--
-- Event order. This file is in the TOC's features block, before
-- Capture/, checked event by event (24 Nov):
--   - CHAT_MSG_LOOT is also Firsts', Upgrades', Hunts' and Capture/
--     Instances.lua's; each keeps its own state and none reads j.trips;
--   - SKILL_LINES_CHANGED and CHAT_MSG_SKILL are also Profession caps',
--     which reads the same ranks into its own memory and writes j.skillCaps
--     only;
--   - SD_QUEST_ACCEPTED / SD_QUEST_TURNED_IN are also Quest finales',
--     which writes j.chainStarts and j.finales only; the route's own count
--     comes before both messages are fired, whatever the TOC says;
--   - SD_WORLD_SETTLED is also Firsts', Upgrades', Profession caps' and
--     the hunter's, none of which writes anything read here;
--   - PLAYER_ENTERING_WORLD is also Core/Events.lua's (the first zone),
--     Capture/Journey.lua's (it starts the route's timer, and may begin the
--     route itself on a first login, which only makes Journey.Kept give a
--     route a moment sooner: the trip then opens at SD_WORLD_SETTLED),
--     Capture/Matches.lua's, Capture/Instances.lua's, Capture/Group.lua's,
--     Hunts' and Campfire's; ZONE_CHANGED_NEW_AREA also Core/Events.lua's,
--     Capture/Matches.lua's, Capture/Instances.lua's and Capture/
--     Together.lua's; PLAYER_LOGOUT also Capture/Together.lua's and
--     Upgrades'. This file reads none of what they write (it reads the
--     city list, the map, the taxi and instance flags, and the route's
--     gate) and they read nothing of its;
--   - the TakeInboxItem and AutoLootMailItem hooks are also Firsts' and
--     Upgrades'; every hook only reads the letter, so their order is free;
--   - PLAYER_MONEY, PLAYER_CONTROL_LOST / _GAINED, NEW_RECIPE_LEARNED,
--     MAIL_SEND_SUCCESS, MAIL_FAILED, AUCTION_HOUSE_AUCTION_CREATED,
--     AUCTION_HOUSE_PURCHASE_COMPLETED, COMMODITY_PURCHASE_SUCCEEDED, and
--     the TakeInboxMoney, SendMail and C_AuctionHouse hooks have no other
--     listener.
-- So every order is free and the file could sit anywhere in the block:
-- no order binds it, so no test pins it. tests/citytrips.lua drives a
-- quest through the client's own QUEST_ACCEPTED, the route's count and
-- its message, end to end, and the skill events beside Profession caps'
-- reading of them.
--
-- Watching is the route's, as every feature's is (ns.Journey.Kept).

local addonName, ns = ...

local CityTrips = ns.CityTrips
local T = CityTrips.T

-- The trip under way and the route it is on; nil between trips.
local trip, tripJ
-- Whether the world has settled since this load: no trip is opened,
-- carried on or written to before (see the header).
local settled = false
-- This trip's letters already counted: { sender, subject, expires, kind,
-- entry, coin, items = { [attachment] = true } }. Memory only.
local letters = {}
-- Each profession's rank as the trip began (or as first read after a
-- load): { [line] = { rank, name } }.
local base
-- What a hook said, waiting on the event that confirms it: an auction
-- being put up { id, n }; bids placed, by auction id { id, n, paid, name };
-- a commodity being bought { id, n, money }; a letter being sent { name,
-- items, coin }.
local posting, bids, buying, sending = nil, {}, nil, nil
-- Whether a skill reading is already waiting on its timer.
local skillsDue = false

--------------------------------------------------------------------------
-- Reading the client
--------------------------------------------------------------------------

local function Number(v)
    v = ns.Plain(v)
    return type(v) == "number" and v or nil
end

local function Text(v)
    v = ns.Plain(v)
    return type(v) == "string" and v ~= "" and v or nil
end

local function Level()
    return Number(UnitLevel and UnitLevel("player"))
end

local function Money()
    return Number(GetMoney and GetMoney())
end

local function ItemID(link)
    link = ns.Plain(link)
    return tonumber(type(link) == "string" and link:match("item:(%d+)") or nil)
end

-- Where a trip can be: the city's map (the city list's own id, else the
-- zone map a sanctuary or a city listed by name lies on), or nil when the
-- player is not in a city, is on a taxi or is inside an instance.
local function Here()
    if UnitOnTaxi and ns.Plain(UnitOnTaxi("player")) == true then return nil end
    if IsInInstance and ns.Plain((IsInInstance())) == true then return nil end
    local city = ns.City()
    if not city then return nil end
    if type(city) == "number" then return city end
    return (ns.ZoneWhere())
end

-- At the game, not away from the keyboard: only then is the trip seen.
local function Present()
    return not (UnitIsAFK and ns.Plain(UnitIsAFK("player")) == true)
end

-- Every profession the character has, by its id; nil where the client has
-- no such API (Features/ProfessionCaps/Capture.lua reads them the same way).
local function Professions()
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local list = {}
    for _, index in pairs({ GetProfessions() }) do
        local name, _, rank, _, _, _, line = GetProfessionInfo(index)
        rank, line = Number(rank), Number(line)
        if line and rank then list[line] = { rank = rank, name = Text(name) } end
    end
    return list
end

-- A name read off a letter, an invoice or an auction, as a person the
-- diary knows: their GUID and whether they are one of the player's own
-- characters, or nil. The third value says whether a name was read at all,
-- so an unknown one can be counted. The name itself goes no further.
local function Person(name)
    name = Text(name)
    if not name then return nil, nil, false end
    local first, surname = ns.NormalizeName(name)
    if not first then return nil, nil, true end
    local lower, lowerSur = first:lower(), surname and surname:lower()
    local own = ns.OwnCharacters and ns.OwnCharacters() or {}
    local hit, hits = nil, 0
    for guid, e in pairs(own) do
        if type(e) == "table" and type(e.first) == "string" and e.first:lower() == lower
            and (not lowerSur or (type(e.surname) == "string" and e.surname:lower() == lowerSur)) then
            hit, hits = guid, hits + 1
        end
    end
    if hits == 1 then return hit, true, true end
    if hits > 1 then return nil, nil, true end
    local guid = ns.Characters.FindByName(first, surname)
    if not guid then return nil, nil, true end
    local record = ns.db.characters[guid]
    return guid, (own[guid] ~= nil or (record and record.isSelf)) or nil, true
end

-- A unit's GUID, when the diary knows them; the second value whether there
-- was a player there at all.
local function Known(unit)
    local guid = ns.SafeGUID(UnitGUID and UnitGUID(unit))
    if not guid then return nil, false end
    return ns.db.characters[guid] and guid or nil, true
end

--------------------------------------------------------------------------
-- The trip's life
--------------------------------------------------------------------------

local function Forget()
    trip, tripJ, base = nil, nil, nil
    letters, posting, bids, buying, sending = {}, nil, {}, nil, nil
end

-- The trip ends `at`; `reading`: the purse is read now (else it stays as
-- last read).
local function Close(at, reading)
    if not trip then return end
    CityTrips.Close(tripJ, trip, at, reading and Money() or nil)
    Forget()
end

local function Open(j, here, now)
    trip = CityTrips.Open(j, here, { t = now, level = Level(), came = Money(), seen = now })
    tripJ = j
    base = Professions()
end

-- After a load: the route's last trip, left unsettled, carries on if the
-- player is still in that city and it was seen lately; else it ended
-- where it was last seen.
local function Settle(j, now)
    local list = j.trips
    local last = list and list[#list]
    if not (last and last.seen) then return end
    if Here() == last.mapID and now - last.seen <= T.resume then
        last.to = nil
        trip, tripJ = last, j
        base = Professions()
    else
        CityTrips.Close(j, last, last.seen, nil)
    end
end

-- Where the player is now, for the trip: closes the one that ended, opens
-- one on arriving, notes that it is still going on. Returns the trip under
-- way, or nil.
local function Check()
    if not settled then return nil end
    local now = ns.Now()
    local j = ns.Journey.Kept()
    if trip and j ~= tripJ then Close(now, true) end
    if not j then return nil end
    if not trip then Settle(j, now) end
    local here = Here()
    if trip then
        if now - (trip.seen or trip.t) > ns.Sittings.GAP then
            Close(trip.seen or trip.t)
        elseif here ~= trip.mapID then
            Close(now, true)
        end
    end
    -- Away from the keys, a trip goes on but none begins: arriving is
    -- read again on the first beat back.
    local present = Present()
    if here and not trip and present then Open(j, here, now) end
    if trip and present then trip.seen = now end
    return trip
end

ns.On("SD_WORLD_SETTLED", function()
    settled = true
    Check()
end)
ns.On("PLAYER_ENTERING_WORLD", function() Check() end)
ns.On("ZONE_CHANGED_NEW_AREA", function() Check() end)
-- A taxi taking off takes the controls; landing gives them back.
ns.On("PLAYER_CONTROL_LOST", function() Check() end)
ns.On("PLAYER_CONTROL_GAINED", function() Check() end)
if ns.Every then ns.Every(T.beat, function() Check() end) end

-- The end is written now, the trip left to the next load to settle (a
-- /reload carries on).
ns.On("PLAYER_LOGOUT", function()
    if not trip then return end
    local now = ns.Now()
    trip.to, trip.seen = now, now
    trip.left = Money() or trip.left
end)

ns.On("PLAYER_MONEY", function()
    local t = Check()
    if t then t.left = Money() or t.left end
end)

--------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------

-- `fn` with its errors kept from the caller: to the error handler where
-- there is one, else dropped.
local function Safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            local handle = geterrorhandler and geterrorhandler()
            if handle then pcall(handle, err) end
        end
    end
end
CityTrips.Safe = Safe

-- A post-hook on `owner[name]` (a global function where `owner` is nil),
-- where the client has both the function and hooksecurefunc.
local function Hook(owner, name, fn)
    if type(hooksecurefunc) ~= "function" then return end
    if owner == nil then
        if type(_G[name]) == "function" then hooksecurefunc(name, Safe(fn)) end
    elseif type(owner) == "table" and type(owner[name]) == "function" then
        hooksecurefunc(owner, name, Safe(fn))
    end
end

--------------------------------------------------------------------------
-- Auctions
--------------------------------------------------------------------------

-- The item at a bag location, where there is one: the client's item calls
-- raise an error on an empty location, and an error in a hook, though kept
-- from the game's call (Safe), would still show in the player's error
-- window. So it is asked first whether anything is there.
local function LocationItem(location)
    local C = C_Item
    if not (C and C.GetItemID) then return nil end
    if C.DoesItemExist and ns.Plain(C.DoesItemExist(location)) ~= true then return nil end
    return Number(C.GetItemID(location))
end

local function Posted(location, _, quantity)
    local id = LocationItem(location)
    posting = id and { id = id, n = Number(quantity) or 1 } or nil
end

-- A bid placed: what the auction is while it is still listed.
local function Bid(auctionID, bidAmount)
    local A = C_AuctionHouse
    auctionID = Number(auctionID)
    if not (auctionID and A and A.GetAuctionInfoByID) then return end
    local info = A.GetAuctionInfoByID(auctionID)
    if type(info) ~= "table" then return end
    local key = type(info.itemKey) == "table" and info.itemKey or {}
    local id = Number(key.itemID) or ItemID(info.itemLink)
    if not id then return end
    local owners = type(info.owners) == "table" and info.owners or {}
    bids[auctionID] = { id = id, n = Number(info.quantity) or 1, paid = Number(bidAmount),
        name = #owners == 1 and Text(owners[1]) or nil }
end

local function Commodity(itemID, quantity)
    local id = Number(itemID)
    buying = id and { id = id, n = Number(quantity) or 1, money = Money() } or nil
end

-- What a person read off an auction or invoice is on an item entry.
local function Extra(name, coin, key)
    local guid, _, read = Person(name)
    return { [key] = coin, who = guid, stranger = read and not guid or nil }
end

ns.On("AUCTION_HOUSE_AUCTION_CREATED", function()
    local p = posting
    posting = nil
    local t = p and Check()
    if t then CityTrips.Item(t, "up", { id = p.id }, p.n) end
end)

ns.On("AUCTION_HOUSE_PURCHASE_COMPLETED", function(_, auctionID)
    auctionID = Number(auctionID)
    local b = auctionID and bids[auctionID]
    if not b then return end
    bids[auctionID] = nil
    local t = Check()
    if t then CityTrips.Item(t, "bought", { id = b.id }, b.n, Extra(b.name, b.paid, "paid")) end
end)

ns.On("COMMODITY_PURCHASE_SUCCEEDED", function()
    local b = buying
    buying = nil
    local t = b and Check()
    if not t then return end
    local now = Money()
    local paid = b.money and now and b.money - now or nil
    CityTrips.Item(t, "bought", { id = b.id }, b.n, { paid = paid and paid > 0 and paid or nil })
end)

if C_AuctionHouse then
    Hook(C_AuctionHouse, "PostItem", Posted)
    Hook(C_AuctionHouse, "PostCommodity", Posted)
    Hook(C_AuctionHouse, "PlaceBid", Bid)
    Hook(C_AuctionHouse, "ConfirmCommoditiesPurchase", Commodity)
end

--------------------------------------------------------------------------
-- The mailbox
--------------------------------------------------------------------------

-- A letter's header, as far as it reads.
local function Header(index)
    if type(GetInboxHeaderInfo) ~= "function" then return nil end
    local _, _, sender, subject, money, _, daysLeft, _, _, wasReturned, _, canReply, isGM = GetInboxHeaderInfo(index)
    return { sender = Text(sender), subject = Text(subject), money = Number(money) or 0, days = Number(daysLeft),
        returned = ns.Plain(wasReturned) == true, canReply = ns.Plain(canReply) == true, gm = ns.Plain(isGM) == true }
end

-- The client's own subjects for a lot that came back.
local function CameBack(subject)
    if not subject then return false end
    for _, key in ipairs({ "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_REMOVED_MAIL_SUBJECT" }) do
        if ns.ReadString(_G[key], subject) then return true end
    end
    return false
end

-- Which letter this is, counted once a trip: the same sender and subject,
-- running out at the same moment (to two minutes: daysLeft is read as a
-- fraction that moves while the box is open), and not yet emptied. An
-- emptied letter is gone from the box, so a second sale of the same thing
-- in the same minute, its letter alike in every way, is a letter of its
-- own.
local function Seen(index, h)
    local expires = h.days and ns.Now() + h.days * 86400 or nil
    for _, s in ipairs(letters) do
        if not s.done and s.sender == h.sender and s.subject == h.subject
            and (s.expires == nil or expires == nil or math.abs(s.expires - expires) <= 120) then
            return s
        end
    end
    local s = { sender = h.sender, subject = h.subject, expires = expires, items = {} }
    -- What it is, read once, the first time something is taken from it.
    -- The invoice's returns, in the order the game's own mail frame reads
    -- them (Blizzard_MailFrame/MailFrame.lua in this build, 24 Nov):
    -- invoiceType, itemName, playerName, bid, buyout, deposit, consignment,
    -- moneyDelay, etaHour, etaMin, count, commerceAuction. `count` is the
    -- eleventh; playerName is nil where a lot had several buyers or
    -- sellers (a commodity), which is then nobody to name or to count.
    local invoice, itemName, playerName, bid, count
    if type(GetInboxInvoiceInfo) == "function" then
        invoice, itemName, playerName, bid, _, _, _, _, _, _, count = GetInboxInvoiceInfo(index)
        invoice = Text(invoice)
    end
    if invoice == "seller" or invoice == "buyer" then
        s.kind = invoice == "seller" and "sold" or "won"
        s.item, s.name, s.bid, s.count = Text(itemName), Text(playerName), Number(bid), Number(count) or 1
    elseif invoice then
        s.kind = nil                -- a sale still pending: its coin comes in a letter of its own
    elseif h.returned then
        s.kind = nil                -- one of the player's own, come back
    elseif CameBack(h.subject) then
        s.kind = "back"
    elseif h.canReply and not h.gm then
        s.kind = "letter"
    end
    letters[#letters + 1] = s
    return s, true
end

-- The name of item `id`, as the client has it cached.
local function ItemName(id)
    local C = C_Item
    if C and C.GetItemNameByID then return Text(C.GetItemNameByID(id)) end
    if GetItemInfo then return Text((GetItemInfo(id))) end
    return nil
end

-- An invoice names its item; the trip keeps an id where one can be found,
-- which is smaller and draws in any language: the client's instant info
-- (it knows a name for what is in the bags), else a lot of that name put
-- up on this or an earlier trip. Else the name is kept.
local function Thing(name)
    local C = C_Item
    local id = C and C.GetItemInfoInstant and Number((C.GetItemInfoInstant(name)))
    if id then return { id = id } end
    local list = tripJ and tripJ.trips or {}
    for i = #list, math.max(1, #list - 20), -1 do
        for _, e in ipairs(list[i].up or {}) do
            if e.id and ItemName(e.id) == name then return { id = e.id } end
        end
    end
    return { name = name }
end

-- A won lot's letter: the purchase already on the list (by its item's
-- name) takes the seller; else it is a purchase of its own.
local function Won(t, s)
    if not s.item then return end
    local guid, _, read = Person(s.name)
    for _, e in ipairs(t.bought or {}) do
        if not e.rest and (e.name == s.item or (e.id and ItemName(e.id) == s.item)) then
            if guid then
                e.who = e.who or {}
                for _, g in ipairs(e.who) do
                    if g == guid then return end
                end
                if #e.who < T.who then e.who[#e.who + 1] = guid end
            end
            return
        end
    end
    CityTrips.Item(t, "bought", Thing(s.item), s.count, { paid = s.bid, who = guid,
        stranger = read and not guid or nil })
end

-- Something taken out of letter `index`: its coin (`coin` true) and the
-- attachments listed in `slots` (true: all of them).
local function Took(index, coin, slots)
    index = Number(index)
    if not index then return end
    local t = Check()
    if not t then return end
    local h = Header(index)
    if not h then return end
    local s, first = Seen(index, h)
    local money = 0
    if coin and not s.coin and h.money > 0 then
        money, s.coin = h.money, true
    end
    local things = 0
    local from, to = 1, 0
    if slots == true then
        to = ATTACHMENTS_MAX_RECEIVE or 16
    elseif slots then
        from, to = slots, slots
    end
    for a = from, to do
        if not s.items[a] then
            local name, _, _, count
            if type(GetInboxItem) == "function" then name, _, _, count = GetInboxItem(index, a) end
            local link = type(GetInboxItemLink) == "function" and ns.Plain(GetInboxItemLink(index, a)) or nil
            if Text(name) or link then
                s.items[a] = true
                things = things + (Number(count) or 1)
            end
        end
    end
    -- Emptied: nothing left in it that this trip has not taken.
    local left = h.money > 0 and not s.coin
    for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        if not left and not s.items[a] then
            local name = type(GetInboxItem) == "function" and Text((GetInboxItem(index, a))) or nil
            local link = type(GetInboxItemLink) == "function" and ns.Plain(GetInboxItemLink(index, a)) or nil
            if name or link then left = true end
        end
    end
    s.done = not left
    if s.kind == "letter" then
        local guid, own = Person(s.sender)
        CityTrips.Letter(t, "letters", guid, own, first, things, money)
    elseif s.kind == "sold" then
        if first then
            local extra = Extra(s.name, money, "got")
            if s.item then s.entry = CityTrips.Item(t, "sold", Thing(s.item), s.count, extra) end
        elseif s.entry and money > 0 then
            s.entry.got = (s.entry.got or 0) + money
        end
    elseif s.kind == "won" and first then
        Won(t, s)
    elseif s.kind == "back" and first then
        CityTrips.Back(t)
    end
end

Hook(nil, "TakeInboxMoney", function(index) Took(index, true, nil) end)
Hook(nil, "TakeInboxItem", function(index, attachment) Took(index, false, Number(attachment) or 1) end)
-- Everything in it (the client's "Open All" too): the coin with the things.
Hook(nil, "AutoLootMailItem", function(index) Took(index, true, true) end)

-- A letter being sent: to whom and what goes with it, read as the call is
-- made, written when the server says it went.
Hook(nil, "SendMail", function(recipient)
    local items = 0
    if type(GetSendMailItem) == "function" then
        for a = 1, ATTACHMENTS_MAX_SEND or 12 do
            local name, _, _, count = GetSendMailItem(a)
            if Text(name) then items = items + (Number(count) or 1) end
        end
    end
    sending = { name = Text(recipient), items = items, coin = Number(GetSendMailMoney and GetSendMailMoney()) or 0 }
end)

ns.On("MAIL_SEND_SUCCESS", function()
    local s = sending
    sending = nil
    local t = s and Check()
    if not t then return end
    local guid, own = Person(s.name)
    CityTrips.Letter(t, "sent", guid, own, true, s.items, s.coin)
end)
ns.On("MAIL_FAILED", function() sending = nil end)

--------------------------------------------------------------------------
-- Crafting and professions
--------------------------------------------------------------------------

-- The client's own line for something the player made, the many first
-- (the one's pattern would take "x12" as part of the item).
local CREATED = { "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }
ns.OnChat("CHAT_MSG_LOOT", function(text)
    text = Text(text)
    if not text then return end
    for _, key in ipairs(CREATED) do
        local args = ns.ReadString(_G[key], text)
        if args then
            local id = ItemID(args[1])
            local t = id and Check()
            if t then CityTrips.Item(t, "made", { id = id }, tonumber(args[2]) or 1) end
            return
        end
    end
end)

local function ReadSkills()
    skillsDue = false
    local t = Check()
    local now = t and Professions()
    if not now then return end
    base = base or {}
    for line, s in pairs(now) do
        local b = base[line]
        if not b then
            base[line] = s        -- a profession learnt on the trip: its climb starts here
        elseif s.rank > b.rank then
            CityTrips.Climbed(t, line, s.name or b.name, b.rank, s.rank)
        end
    end
end

-- Only on a trip: a skill-up in the field (a mining run) asks for nothing.
local function SkillsChanged()
    if skillsDue or not trip then return end
    skillsDue = true
    ns.After(T.settle, ReadSkills)
end
ns.On("SKILL_LINES_CHANGED", SkillsChanged)
ns.On("CHAT_MSG_SKILL", SkillsChanged)

ns.On("NEW_RECIPE_LEARNED", function(_, recipeID)
    local id = Number(recipeID)
    local t = id and Check()
    if t then CityTrips.Learnt(t, id) end
end)

--------------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------------

local function Title(questID)
    local Q = C_QuestLog
    return Q and Q.GetTitleForQuestID and Text(Q.GetTitleForQuestID(questID)) or nil
end

-- Who of the party was on quest `questID`, as the client says: the GUIDs
-- the diary knows, and how many more there were.
local function Party(questID)
    local Q = C_QuestLog
    if not (Q and Q.IsUnitOnQuest) then return nil, 0 end
    local with, others = {}, 0
    for i = 1, 4 do
        local unit = "party" .. i
        local guid, there = Known(unit)
        if there and ns.Plain(Q.IsUnitOnQuest(unit, questID)) == true then
            if guid then with[#with + 1] = guid else others = others + 1 end
        end
    end
    return with, others
end

ns.On("SD_QUEST_ACCEPTED", function(_, questID)
    local t = Check()
    if t then CityTrips.Quest(t, questID, Title(questID), false) end
end)

ns.On("SD_QUEST_TURNED_IN", function(_, questID)
    local t = Check()
    if not t then return end
    local with, others = Party(questID)
    CityTrips.Quest(t, questID, Title(questID), true, with, others)
end)

--------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------

ns._test.CityTrips = {
    Check = Check,
    -- What a /reload loses: this file's memory, the world not yet settled.
    Reset = function()
        Forget()
        settled, skillsDue = false, false
    end,
    State = function() return { trip = trip, settled = settled, letters = letters, base = base } end,
}
