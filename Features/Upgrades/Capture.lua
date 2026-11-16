-- Upgrades: the bags, the worn slots and the bank read as they change;
-- how each item came; and the two minutes of play an item is worn before
-- it is an upgrade (Kind.lua has what is kept; the rules, and what the
-- client round still has to confirm, are in .claude/features/upgrades.md).
--
-- The chain (the user, 15 Nov): an item counts only if the diary **saw it
-- arrive** and then saw it **put on**. So gear the character already had
-- never counts, however often two sets are swapped.
--
-- Arriving. Each reading counts what is held, by key (Upgrades.Key), in
-- the bags and on the character together, copies and all: a piece moving
-- between a bag and a slot changes nothing, and one more than before has
-- arrived, however it came (loot, a quest, a vendor, a letter, a trade,
-- something made: all of them land here). Green or better and gear
-- (Upgrades.Counts), it is a candidate, kept on the route (j.fitting), for
-- an item is often found long before it can be worn. Not an arrival:
--   - what comes out of the bank. While the bank is open its contents are
--     read too, and one more in hand with one fewer in the bank is the
--     same item; where the bank's contents do not read, the open window
--     alone says so. A candidate put into the bank stays one (`banked`);
--   - what is bought back from a vendor (the client's BuybackItem,
--     hooked), and a letter of the user's own come back (the letter's
--     `wasReturned`): old gear returning;
--   - what was an upgrade before (Upgrades.Known): nothing counts twice.
-- A letter from the user's own other character does count: it is new to
-- this one.
--
-- Going. A candidate that leaves the bags while the bank is closed, and
-- is not worn, is gone for good (sold, traded, destroyed, sent away) and
-- is given up. That is exact, so the list needs no cap.
--
-- Put on. The worn slots (Upgrades.SLOTS) are read with the bags and on
-- PLAYER_EQUIPMENT_CHANGED; the event's own payload is not relied on. A
-- candidate found in a slot is put on: the first time is kept, with where
-- it was, what it took the place of and both item levels. What it took
-- the place of is the last thing **of its own kind** worn in that slot
-- (Upgrades.Kind, j.lastWorn), not whatever the slot held a moment before
-- (the user, 16 Nov): a warrior who tanks puts a shield over their
-- off-hand sword and back, and a sword found while tanking goes on over
-- the shield; neither is the one replacing the other. Kept across
-- sessions, and only ever written with what is worn (a slot that reads
-- empty for a moment, or a piece taken off first, changes nothing). With
-- nothing of its kind worn there before (an empty slot, a first shield, a
-- first two-hander) there is nothing to measure it against, and it is
-- given up: it is the measure from then on ("we wait for comparable item
-- types"). So is one whose measure is still worn elsewhere (a ring moved
-- to the other hand): it took nobody's place.
--
-- Worn. While a candidate is on, a clock runs; taken off, the seconds go
-- onto the candidate (saved, so a logout or a weapon swapped for every
-- fight loses nothing), and at T.worn in all it is an upgrade
-- (Upgrades.Confirm), dated and placed at the first put-on. Only play
-- counts: the clock is this session's, and starts again at the next
-- login if the piece is still on.
--
-- Out of sight never counts (D10: nothing is made up). The first reading
-- after the diary was not watching (a login, a /reload, the route's
-- capture back on) only arms: what is held then is what was had. A
-- candidate found worn then, that the diary never saw put on, was put on
-- out of sight and is given up; one neither held, worn nor banked is
-- gone. That reading waits for SD_WORLD_SETTLED or the bags' own update,
-- and an empty backpack is not read at all, as the firsts' is not.
--
-- How it came, by what said so about that very item, as the firsts read
-- it (Features/Firsts/Capture.lua, whose readers are its own): a trade
-- completed just before which held it (and from whom), a letter's
-- attachment taken, the client's own loot line, else whichever of the
-- quest, vendor and loot windows was open or had just closed.
--
-- Event order. This file is in the TOC's features' block, after the
-- firsts. BAG_UPDATE_DELAYED, MERCHANT_SHOW/CLOSED, QUEST_COMPLETE/
-- FINISHED and LOOT_CLOSED are also the firsts'; LOOT_OPENED and
-- CHAT_MSG_LOOT also the firsts', the hunts' and (the line) the
-- dungeons'; SD_WORLD_SETTLED also the firsts', the profession caps' and
-- the hunter's; SD_TRADE_COMPLETED also the firsts'; PLAYER_LOGOUT also
-- Capture/Together.lua's. None of them keeps anything this reads, and
-- this writes only j.fitting, j.upgrades, j.lastWorn and a `gift_worn`
-- row, which none of them reads: every order is free.
-- PLAYER_EQUIPMENT_CHANGED and the bank's events have no other listener.
--
-- Watching is the route's, as the firsts' is (ns.Journey.Kept).

local addonName, ns = ...

local Upgrades = ns.Upgrades
local T = Upgrades.T

local UPGRADES = {
    source = 10,   -- how fresh a trade, a line or a closed window still says how it came
    slack = 1,     -- seconds past the two minutes the check waits, so it finds them done
}

local function Level()
    local level = ns.Plain(UnitLevel("player"))
    return type(level) == "number" and level or nil
end

local watching = false
-- The last reading: copies held by key, in the bags and worn together
-- (`held`), in the bags alone (`bagged`), and the keys worn (`wearing`).
local held, bagged, wearing = {}, {}, {}
-- The bank: whether its window is open, and its contents by key as last
-- read while it was (nil where they do not read).
local bankOpen, bank = false, nil
-- A worn candidate's clock: when it started, by key. This session's only.
local since = {}
-- Whether a check is already waiting on a timer.
local waiting = false

-- How the next arrival may have come (the firsts' way): each window's
-- state (true while open, else when it closed); the last trade completed
-- { guid, t, received }; what was said about an item as it came, by key:
-- { from, t }, `from` "mail", "returned", "buyback", "craft", "loot" or
-- "push" (handed over: a quest's or a vendor's); and the candidates just
-- made, for a line that comes after the bags changed: { key, t }.
local windows, lastTrade, said, made = {}, nil, {}, {}

local function Window(kind, open)
    windows[kind] = open or ns.Now()
end

local function Fresh(kind, now)
    local w = windows[kind]
    return w == true or (w ~= nil and now - w <= UPGRADES.source)
end

--------------------------------------------------------------------------
-- Reading the client
--------------------------------------------------------------------------

-- An item as Upgrades.Counts reads it, from its link: the instant info
-- needs no item cache.
local function Item(link, quality)
    link = ns.Plain(link)
    local key, id = Upgrades.Key(link)
    if not key or not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    quality = ns.Plain(quality)
    if type(quality) ~= "number" and C_Item.GetItemQualityByID then quality = ns.Plain(C_Item.GetItemQualityByID(id)) end
    return { link = link, key = key, quality = quality, equipLoc = ns.Plain(equipLoc), classID = ns.Plain(classID),
        subclassID = ns.Plain(subclassID) }
end

-- A container's items counted into `counts` (and each kept in `items`, by
-- key). Returns its size.
local function Count(bag, counts, items)
    local C = C_Container
    local size = ns.Plain(C.GetContainerNumSlots(bag))
    size = type(size) == "number" and size or 0
    for slot = 1, size do
        local info = C.GetContainerItemInfo(bag, slot)
        local item = info and Item(info.hyperlink, info.quality)
        if item then
            counts[item.key] = (counts[item.key] or 0) + 1
            if items then items[item.key] = item end
        end
    end
    return size
end

-- The bags: copies by key, and an item of each; nil while the backpack
-- does not read (bags not yet loaded are not "none").
local function Bags()
    local C = C_Container
    if not (C and C.GetContainerNumSlots) or (ns.Plain(C.GetContainerNumSlots(0)) or 0) <= 0 then return nil end
    local counts, items = {}, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do Count(bag, counts, items) end
    return counts, items
end

-- What is worn: the item in each slot read, by slot.
local function Worn()
    local on = {}
    for _, slot in ipairs(Upgrades.SLOTS) do
        on[slot] = Item(GetInventoryItemLink("player", slot), GetInventoryItemQuality("player", slot))
    end
    return on
end

-- The bank's contents by key, read while its window is open; nil where no
-- container of it reads. Which containers a bank is differs by client
-- (the old bank's own container and its bag slots; the new one's tabs),
-- so every one this client names is asked.
local function Bank()
    local C = C_Container
    if not (C and C.GetContainerNumSlots) then return nil end
    local ids, seen = {}, {}
    local function Add(id)
        id = ns.Plain(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    Add(BANK_CONTAINER)
    for i = 1, NUM_BANKBAGSLOTS or 0 do Add((NUM_BAG_SLOTS or 4) + i) end
    if C_Bank and C_Bank.FetchPurchasedBankTabIDs and Enum and Enum.BankType then
        local tabs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)
        if type(tabs) == "table" and not ns.IsSecret(tabs) then
            for _, id in ipairs(tabs) do Add(id) end
        end
    end
    local counts, read = {}, false
    for _, id in ipairs(ids) do
        if Count(id, counts) > 0 then read = true end
    end
    return read and counts or nil
end

-- An item's level, where the client has it. Asked as a candidate is put
-- on, when the new piece and the one it replaces have both just been in
-- the slot (the client has them then; an old piece sold before the
-- minutes are up may be gone from its cache by the confirming), and again
-- at the confirming for what did not read. The detailed level first, else
-- the item's own (Pawn reads them in that order too).
local function ItemLevel(link)
    if type(link) ~= "string" or not C_Item then return nil end
    local level
    if C_Item.GetDetailedItemLevelInfo then level = ns.Plain((C_Item.GetDetailedItemLevelInfo(link))) end
    if not (type(level) == "number" and level > 0) and C_Item.GetItemInfo then
        level = ns.Plain((select(4, C_Item.GetItemInfo(link))))
    end
    return type(level) == "number" and level > 0 and level or nil
end

--------------------------------------------------------------------------
-- How it came
--------------------------------------------------------------------------

-- Handed over: a quest's reward or a purchase, by the window.
local function Handed(now)
    if Fresh("quest", now) then return "quest" end
    if Fresh("vendor", now) then return "vendor" end
    return nil
end

-- How the item of `key` came, as far as can be told: received in a trade
-- just now (from whom), else what was said about it, else whichever
-- window was open or just closed.
local function Came(key, now)
    local trade = lastTrade
    if trade and now - trade.t <= UPGRADES.source then
        for _, r in ipairs(trade.received or {}) do
            if Upgrades.Key(r.link) == key then return "trade", trade.guid end
        end
    end
    local word = said[key]
    if word and now - word.t <= UPGRADES.source then
        if word.from == "push" then return Handed(now) end
        return word.from
    end
    for _, kind in ipairs({ "quest", "vendor", "loot" }) do
        if Fresh(kind, now) then return kind end
    end
    return nil
end

-- Old gear returning, which is no arrival.
local RETURNING = { buyback = true, returned = true }

-- Debug lines (/sd debug): what capture made of each arrival and each
-- piece put on, at once, not only when the two minutes are up. For the
-- in-client rounds; a player never sees them.
local function Note(msg, ...)
    if not ns.DebugOn() then return end
    local args = { ... }
    for i = 1, select("#", ...) do
        if type(args[i]) ~= "number" then args[i] = tostring(args[i]) end
    end
    ns.Debug("upgrades: " .. msg, unpack(args, 1, select("#", ...)))
end

-- "12 > 16 (+4)", "? > 16": the item levels as they read.
local function Levels(was, now)
    local gain = type(was) == "number" and type(now) == "number" and (" (%+d)"):format(now - was) or ""
    return ("%s > %s%s"):format(was or "?", now or "?", gain)
end

-- Seconds worn so far of the two minutes, the running clock counted.
local function SoFar(cand, now)
    local s = (cand.worn or 0) + (since[cand.key] and now - since[cand.key] or 0)
    return ("%d/%ds"):format(s, T.worn)
end

-- Something said about an item as it came. A line after the letter or the
-- buy-back it came by does not unsay them; a candidate made just before
-- the word takes it, and is given up where the word says it was old gear.
local function Said(key, from)
    if not key then return end
    local now = ns.Now()
    local word = said[key]
    if from == "push" and word and word.from ~= "push" and now - word.t <= UPGRADES.source then return end
    said[key] = { from = from, t = now }
    local j = ns.Journey.Kept()
    for i = #made, 1, -1 do
        local m = made[i]
        if now - m.t > UPGRADES.source then
            table.remove(made, i)
        elseif m.key == key and j then
            local cand = Upgrades.Candidate(j, key)
            local how = from == "push" and Handed(now) or from
            if cand and RETURNING[how] then
                Note("%s was old gear coming back (%s): given up", cand.link, how)
                Upgrades.Gone(j, key)
                since[key] = nil
            elseif cand and how and cand.from ~= "trade" and cand.from ~= "mail" then
                cand.from = how
            end
        end
    end
end

--------------------------------------------------------------------------
-- The reading
--------------------------------------------------------------------------

local Read

-- The clocks looked at: a worn candidate whose seconds are up is an
-- upgrade; for the others a check is left on a timer, one at a time.
local function Tick(j, on, now)
    local soonest
    for key, from in pairs(since) do
        local cand = Upgrades.Candidate(j, key)
        if not cand then
            since[key] = nil
        else
            local left = T.worn - (cand.worn or 0) - (now - from)
            if left <= 0 then
                since[key] = nil
                Upgrades.Wore(j, key, now - from)
                local link
                for _, item in pairs(on) do
                    if item.key == key then link = item.link end
                end
                local rec = Upgrades.Confirm(j, key, { link = link, ilvl = not cand.on.ilvl and ItemLevel(link or cand.link) or nil,
                    wasIlvl = not cand.on.wasIlvl and ItemLevel(cand.on.was) or nil })
                if rec then Note("UPGRADE confirmed (worn %ds): %s over %s, ilvl %s", T.worn, rec.link, rec.was.link,
                    Levels(rec.was.ilvl, rec.ilvl)) end
            elseif not soonest or left < soonest then
                soonest = left
            end
        end
    end
    if soonest and not waiting then
        waiting = true
        ns.After(soonest + UPGRADES.slack, function()
            waiting = false
            Read()
        end)
    end
end

-- The first reading after the diary was not watching: what is held is
-- what was had, and the candidates kept from before are put against it.
local function Arm(j, counts, on, now)
    local anyWorn = next(on) ~= nil
    for i = #(j.fitting or {}), 1, -1 do
        local cand = j.fitting[i]
        local worn = false
        for _, item in pairs(on) do worn = worn or item.key == cand.key end
        if worn then
            if cand.on then
                -- Still on from a session before: its clock goes on.
                since[cand.key] = now
            else
                -- Put on out of sight.
                table.remove(j.fitting, i)
            end
        elseif (counts[cand.key] or 0) > 0 then
            cand.banked = nil
        elseif not cand.banked and anyWorn then
            -- Neither held, worn nor in the bank: gone while the diary
            -- was not watching. (With nothing at all read as worn, the
            -- character's slots may not have loaded: nothing is given up
            -- on that reading.)
            table.remove(j.fitting, i)
        end
    end
    watching = true
end

-- `arm`: whether this reading may be the first (the bags' own update, or
-- the world settled; a slot changing as the character loads may not).
function Read(arm)
    local j = ns.Journey.Kept()
    if not j then
        -- Not watching: what was held is forgotten, as the route's own
        -- capture forgets (the clocks with it: seconds not yet written
        -- down are lost, never guessed).
        watching, since, bank = false, {}, nil
        return
    end
    local counts, items = Bags()
    if not counts then return end
    local on, now = Worn(), ns.Now()
    local total, wornNow = {}, {}
    for key, n in pairs(counts) do total[key] = n end
    for _, item in pairs(on) do
        total[item.key] = (total[item.key] or 0) + 1
        wornNow[item.key] = true
        items[item.key] = items[item.key] or item
    end

    if not watching then
        if not arm then return end
        since = {}
        Arm(j, counts, on, now)
        local n = 0
        for _ in pairs(counts) do n = n + 1 end
        Note("watching from now: %d kinds of item already held count as old, %d candidates kept", n, #(j.fitting or {}))
    else
        local banked = bankOpen and Bank() or nil
        -- With the bank open, whether an item of `key` moved between it
        -- and the character: by its contents where they read both times
        -- (`way` 1 into the bank, -1 out of it), else by the open window.
        local function Moved(key, way)
            if not bankOpen then return false end
            if not (bank and banked) then return true end
            return ((banked[key] or 0) - (bank[key] or 0)) * way > 0
        end

        -- Arrivals and departures are only told on a settled reading of
        -- the bags (`arm`: their own update, or the world settled). On a
        -- swap the client changes the slot and the bag one at a time, and
        -- PLAYER_EQUIPMENT_CHANGED can read between the two: the item
        -- read nowhere would be given up (or, back again, counted as
        -- arriving). The bags' own update always follows.
        if arm then
            -- Arrived: one more held than at the last reading.
            for key, n in pairs(total) do
                if n > (held[key] or 0) then
                    local cand = Upgrades.Candidate(j, key)
                    if Moved(key, -1) then
                        if cand then cand.banked = nil end
                        Note("%s came out of the bank: no arrival", items[key] and items[key].link or key)
                    elseif not cand and not Upgrades.Counts(items[key]) then
                        local it = items[key]
                        if it and type(it.quality) == "number" and it.quality >= 2 then
                            Note("arrived %s: not gear that counts (%s)", it.link, it.equipLoc or "no slot")
                        elseif it and type(it.quality) ~= "number" then
                            Note("arrived %s: its quality did not read, not counted", it.link)
                        end
                    elseif not cand then
                        local from, guid = Came(key, now)
                        local link = items[key].link
                        if RETURNING[from] then
                            Note("%s came back (%s): no arrival", link, from)
                        elseif Upgrades.Arrived(j, items[key], { t = now, level = Level(), from = from, guid = guid }) then
                            made[#made + 1] = { key = key, t = now }
                            Note("arrived %s (%s): waiting to be put on", link, from or "nothing said")
                        else
                            Note("arrived %s: already counted once, no candidate", link)
                        end
                    end
                end
            end

            -- Gone: a candidate no longer held at all. Into the bank, it
            -- stays one. One that was worn and now reads nowhere is left
            -- alone (a slot may read empty for a moment); one that left the
            -- bags is gone for good.
            for key, n in pairs(held) do
                if n > 0 and (total[key] or 0) == 0 then
                    local cand = Upgrades.Candidate(j, key)
                    if cand then
                        if Moved(key, 1) then
                            cand.banked = true
                            Note("%s went into the bank: still a candidate", cand.link)
                        elseif (bagged[key] or 0) > 0 or not wearing[key] then
                            Note("%s left the bags (sold, traded, destroyed): given up", cand.link)
                            Upgrades.Gone(j, key)
                            since[key] = nil
                        end
                    end
                end
            end
            if bankOpen then bank = banked end
        end

        -- Put on: a candidate found in a slot. The first time is kept,
        -- measured against the last thing of its kind worn there; with
        -- none, or with that one still worn, it is given up (the header).
        -- Every time after, its clock runs.
        for _, slot in ipairs(Upgrades.SLOTS) do
            local item = on[slot]
            local cand = item and Upgrades.Candidate(j, item.key)
            local newly = item and not wearing[item.key]
            if cand and not cand.on then
                local kind = Upgrades.Kind(item, slot)
                local was = Upgrades.Before(j, slot, kind)
                local wasKey = was and Upgrades.Key(was)
                if not was or wasKey == item.key or wornNow[wasKey] then
                    Note("put on %s (slot %d, %s): NO upgrade, %s", item.link, slot, kind,
                        not was and ("nothing of its kind worn there before; it is the measure from now")
                        or wasKey == item.key and "the same item as the last one there"
                        or ("the last of its kind there, %s, is still worn"):format(was))
                    Upgrades.Gone(j, item.key)
                    since[item.key] = nil
                    cand = nil
                else
                    local spot = ns.Journey.Spot()
                    spot.zone = ns.Where().zone
                    local ilvl, wasIlvl = ItemLevel(item.link), ItemLevel(was)
                    Upgrades.PutOn(j, item.key, { t = now, level = Level(), slot = slot, kind = kind, was = was,
                        ilvl = ilvl, wasIlvl = wasIlvl }, spot)
                    Note("put on %s (slot %d, %s): UPGRADE over %s, ilvl %s; counts once worn %ds", item.link, slot,
                        kind, was, Levels(wasIlvl, ilvl), T.worn)
                end
            elseif cand and newly then
                Note("put on %s again: candidate, %s worn", item.link, SoFar(cand, now))
            elseif newly then
                Note("put on %s (slot %d): no candidate, %s", item.link, slot,
                    Upgrades.Known(j, item.key) and "already counted once"
                    or not Upgrades.Counts(item) and "below green or not gear"
                    or "not seen arriving (held before, or a candidate given up)")
            end
            if cand then since[item.key] = since[item.key] or now end
        end

        -- Taken off: its seconds go onto the candidate.
        for key, from in pairs(since) do
            if not wornNow[key] then
                since[key] = nil
                local cand = Upgrades.Candidate(j, key)
                if Upgrades.Wore(j, key, now - from) then
                    local rec = Upgrades.Confirm(j, key, { ilvl = not cand.on.ilvl and ItemLevel(cand.link) or nil,
                        wasIlvl = not cand.on.wasIlvl and ItemLevel(cand.on.was) or nil })
                    if rec then Note("UPGRADE confirmed (worn %ds): %s over %s, ilvl %s", T.worn, rec.link,
                        rec.was.link, Levels(rec.was.ilvl, rec.ilvl)) end
                elseif cand then
                    Note("took off %s: %s worn, still a candidate", cand.link, SoFar(cand, now))
                end
            end
        end
    end

    -- What is worn and no candidate is the measure of its kind in its slot
    -- (a candidate becomes one when it is confirmed, Upgrades.Confirm).
    for slot, item in pairs(on) do
        if not Upgrades.Candidate(j, item.key) then Upgrades.Saw(j, slot, Upgrades.Kind(item, slot), item.link) end
    end
    if arm then held, bagged = total, counts end
    wearing = wornNow
    Tick(j, on, now)
end

ns.On("BAG_UPDATE_DELAYED", function() Read(true) end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function() Read(false) end)
-- The first reading after entering the world, which only arms.
ns.On("SD_WORLD_SETTLED", function() Read(true) end)

-- The bank's window, and its own slots changing (the bags' update may
-- not come for those).
ns.On("BANKFRAME_OPENED", function()
    bankOpen, bank = true, Bank()
end)
ns.On("BANKFRAME_CLOSED", function()
    bankOpen, bank = false, nil
end)
ns.On("PLAYERBANKSLOTS_CHANGED", function() Read(false) end)

-- Logging out (a /reload too): the running clocks' seconds are written
-- down, so the next session goes on from them.
ns.On("PLAYER_LOGOUT", function()
    local j = ns.Journey.Kept()
    local now = ns.Now()
    for key, from in pairs(since) do
        if j then Upgrades.Wore(j, key, now - from) end
    end
    since = {}
end)

--------------------------------------------------------------------------
-- What says how an item came
--------------------------------------------------------------------------

for kind, events in pairs({ vendor = { "MERCHANT_SHOW", "MERCHANT_CLOSED" },
    quest = { "QUEST_COMPLETE", "QUEST_FINISHED" }, loot = { "LOOT_OPENED", "LOOT_CLOSED" } }) do
    ns.On(events[1], function() Window(kind, true) end)
    ns.On(events[2], function() Window(kind) end)
end

-- A letter's attachments taken: one (TakeInboxItem), or all of them
-- (AutoLootMailItem, the client's "Open All" too). Hooked after the call,
-- while the letter still holds them: the server has not answered yet. A
-- letter come back to its sender (the header's tenth value) brings the
-- user's own things home.
local function Letter(index, attachment)
    if type(GetInboxItemLink) ~= "function" then return end
    local returned = type(GetInboxHeaderInfo) == "function" and ns.Plain((select(10, GetInboxHeaderInfo(index)))) == true
    for a = attachment or 1, attachment or ATTACHMENTS_MAX_RECEIVE or 16 do
        Said(Upgrades.Key(ns.Plain(GetInboxItemLink(index, a))), returned and "returned" or "mail")
    end
end

-- Something bought back from a vendor: hooked after the call, while the
-- buy-back list still holds it.
local function Buyback(index)
    if type(GetBuybackItemLink) ~= "function" then return end
    Said(Upgrades.Key(ns.Plain(GetBuybackItemLink(index))), "buyback")
end

if hooksecurefunc then
    if type(TakeInboxItem) == "function" then hooksecurefunc("TakeInboxItem", Letter) end
    if type(AutoLootMailItem) == "function" then
        hooksecurefunc("AutoLootMailItem", function(index) Letter(index) end)
    end
    if type(BuybackItem) == "function" then hooksecurefunc("BuybackItem", Buyback) end
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
        if args then return Said(Upgrades.Key(args[1]), line[2]) end
    end
end)

-- A trade completed: what arrives just after it, among what was received,
-- came from who it was with.
ns.On("SD_TRADE_COMPLETED", function(_, guid, received)
    lastTrade = { guid = guid, t = ns.Now(), received = received }
end)

-- For the tests: a session's end without the client's (what a login finds
-- is then read afresh), and the clocks.
ns._test.Upgrades = {
    Forget = function()
        watching, held, bagged, wearing, since, waiting = false, {}, {}, {}, {}, false
        bankOpen, bank, windows, lastTrade, said, made = false, nil, {}, nil, {}, {}
    end,
    Since = function() return since end,
}
