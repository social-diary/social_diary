-- Crafter detection's capture (Kind.lua says what is kept, and why this is
-- Stage 1; .claude/features/crafter-detection.md has the probe facts).
--
-- The book, written only while the route is kept (Journey.Kept), as every
-- feature's capture is:
--   made     TRADE_SKILL_ITEM_CRAFTED_RESULT (probed 27 Nov 2026: a table
--            with itemID, itemGUID, hyperlink, quantity, isEnchant), for
--            worn gear only; never an enchant.
--   handed   a trade (SD_TRADE_COMPLETED's `given`, Features/Trade): an
--            item given whose id matches a craft still in the user's hands,
--            the oldest such, goes to that GUID. By id, not by the item's
--            own GUID: the trade's links don't carry it (the user, 27 Nov:
--            rely on the working trade capture). Or an auction sale (the
--            seller's letter, GetInboxInvoiceInfo "seller": the item's name
--            and the buyer's): the craft of that name goes to that name,
--            until someone of that name is met. The buyer reads as "" for a
--            moment after the letter arrives (probe round 4: filled in on
--            the next MAIL_INBOX_UPDATE, before the letter is opened), and
--            nil for "multiple buyers" (a stack: never gear). The letter
--            stays in the inbox and is read again at every update, so a
--            craft keeps the letter's key and a key used hands nothing more.
--   got      a trade's `received`: worn gear from that GUID. An auction
--            won (the buyer's letter: the item's name and the seller's)
--            is noted by name (`bought`) until an item of that name is put
--            on, and then becomes `got` from that name. A letter's own
--            attachments are never read: the name on the letter, matched
--            when the thing is worn, says the same without hooking the
--            mail.
--   worn     the user's worn slots (1-19), on SD_WORLD_SETTLED and
--            PLAYER_EQUIPMENT_CHANGED. Only what is worn now counts (the
--            user, 27 Nov): a `got` once worn and then taken off is let go.
--
-- Meeting people. NAME_PLATE_UNIT_ADDED, PLAYER_TARGET_CHANGED and
-- UPDATE_MOUSEOVER_UNIT, everywhere but in an instance (unit identity is
-- secret there), cities included: the sightings' handlers are switched off
-- in a city (SIG-5), but ns.Off drops only theirs, and these stay. Each
-- costs a GUID read and a lookup in the book's small index; a name is read
-- only while the book waits on one.
--   - Someone the book knows by name only (an auction's buyer or seller)
--     is known by their GUID from then on.
--   - "yours": they gave or sold the user something the user wears now.
--     Seeing them is enough (the user, 27 Nov: "seeing nearby as a
--     stranger is already enough").
--   - "theirs": the user handed them a craft not yet found on them. A
--     target or a mouseover (not a nameplate: the scope's "target +
--     mouseover") asks the inspect queue.
--
-- The inspect queue (probe round 3, 27 Nov, in the client): one ask at a
-- time, T.gap apart, given up after T.timeout; the answer's GUID checked;
-- never while Blizzard's Inspect frame is open (it asks in bursts of its
-- own; then the queue only reads along, whoever asked); never in combat or
-- in an instance; the same person at most every T.again. Who may be asked
-- is one gate, CrafterDetection.INSPECT_EVERYONE (Kind.lua): Stage 2 opens
-- it to everyone, Stage 1 asks only those with a craft of the user's.
--
-- A connection, found either way, is one row on the person (`crafted`),
-- one record on the route (j.craftMeets) and one toast (SD_TOAST "crafter";
-- the kind registers with the UI, phase 8), once ever: Connected says
-- whether that row is there already.
--
-- Event order. This file is listed after Capture/, as Witnesses' is: on
-- the nameplate, target and mouseover events it writes the person's record
-- and a row (ns.Characters.ObserveUnit, Interactions.Add), and
-- Capture/Nearby.lua's reunion toast snapshots that person on the same
-- events. After it, the reunion still says what it said before (the lesson
-- of tests/witnesses.lua, "after the reunion toast"). Its other events
-- (the craft result, INSPECT_READY) are its alone; MAIL_INBOX_UPDATE,
-- PLAYER_EQUIPMENT_CHANGED and SD_TRADE_COMPLETED are also City trips',
-- Upgrades' and Firsts', which only read what this writes nothing of.

local addonName, ns = ...

local CrafterDetection = ns.CrafterDetection
local Journey = ns.Journey
local T = CrafterDetection.T
local THEIRS, YOURS = CrafterDetection.THEIRS, CrafterDetection.YOURS
local ItemID, ItemName, Wearable = CrafterDetection.ItemID, CrafterDetection.ItemName, CrafterDetection.Wearable

local Book = CrafterDetection.Book

--------------------------------------------------------------------------
-- The index: who the book waits on, so a meeting costs a lookup
--------------------------------------------------------------------------

local index = { guids = {}, names = {}, any = false }
local worn = { ids = {}, names = {} }  -- the user's worn slots, now

-- Rebuilt whenever the book or the worn slots change. A GUID is in it for
-- a craft handed to them and not yet found on them ("theirs") or a got
-- from them that is worn now ("yours"); a name for either, not yet met.
local function Reindex()
    index = { guids = {}, names = {}, any = false }
    local book = Book(Journey.Kept())
    if not book then return end
    for _, craft in pairs(book.made) do
        if not craft.met and not craft.gone then
            if craft.to then index.guids[craft.to] = true end
            if craft.toName then index.names[craft.toName] = true end
        end
    end
    for id, got in pairs(book.got) do
        if worn.ids[id] then
            if got.from then index.guids[got.from] = true end
            if got.fromName then index.names[got.fromName] = true end
        end
    end
    index.any = next(index.guids) ~= nil or next(index.names) ~= nil
end

--------------------------------------------------------------------------
-- A connection
--------------------------------------------------------------------------

local function Connect(guid, dir, id, link, how, unit)
    if CrafterDetection.Connected(guid, dir, id) then return false end
    if unit then ns.Characters.ObserveUnit(unit) end
    ns.Interactions.Add(guid, "crafted", {
        context = { dir = dir, id = id, link = link, how = how, proof = "handoff" },
    })
    local j = Journey.Kept()
    if j then
        Journey.Append(j, "craftMeets", { guid = guid, dir = dir, id = id, link = link, how = how })
    end
    ns.Fire("SD_TOAST", "crafter", guid, { dir = dir, id = id, link = link, how = how })
    return true
end

--------------------------------------------------------------------------
-- Made
--------------------------------------------------------------------------

local function Made(result)
    if type(result) ~= "table" then return end
    local j = Journey.Kept()
    if not j or ns.Plain(result.isEnchant) == true then return end
    local id = ns.Plain(result.itemID)
    local key = ns.Plain(result.itemGUID)
    local link = ns.Plain(result.hyperlink)
    if type(id) ~= "number" or type(key) ~= "string" or not Wearable(id) then return end

    local book = Book(j)
    if book.made[key] then return end
    book.made[key] = { id = id, name = ItemName(link), link = type(link) == "string" and link or nil, t = ns.Now() }

    -- At most T.made still in hand: the oldest of those go.
    local unhanded = {}
    for _, craft in ipairs(CrafterDetection.Crafts(book)) do
        if CrafterDetection.Unhanded(craft) then unhanded[#unhanded + 1] = craft end
    end
    for i = 1, #unhanded - T.made do
        for k, craft in pairs(book.made) do
            if craft == unhanded[i] then book.made[k] = nil end
        end
    end
end

ns.On("TRADE_SKILL_ITEM_CRAFTED_RESULT", function(_, result) Made(result) end)

-- The oldest craft still in hand that `match` accepts, or nil.
local function OldestInHand(book, match)
    for _, craft in ipairs(CrafterDetection.Crafts(book)) do
        if CrafterDetection.Unhanded(craft) and match(craft) then return craft end
    end
    return nil
end

--------------------------------------------------------------------------
-- A trade: handed, and got
--------------------------------------------------------------------------

ns.On("SD_TRADE_COMPLETED", function(_, guid, received, given)
    local j = Journey.Kept()
    if not j or not guid then return end
    local book = Book(j)
    local now = ns.Now()
    for _, item in ipairs(given or {}) do
        local id = ItemID(item.link)
        local craft = id and OldestInHand(book, function(c) return c.id == id end)
        if craft then craft.to, craft.how, craft.handed = guid, "trade", now end
    end
    for _, item in ipairs(received or {}) do
        local id = ItemID(item.link)
        if id and Wearable(id) then
            book.got[id] = { from = guid, how = "trade", t = now, link = item.link }
        end
    end
    Reindex()
end)

--------------------------------------------------------------------------
-- The auction house's letters
--------------------------------------------------------------------------

local function Letters()
    local j = Journey.Kept()
    if not j or type(GetInboxNumItems) ~= "function" or type(GetInboxInvoiceInfo) ~= "function" then return end
    local book = Book(j)
    local now = ns.Now()
    local changed = false
    for i = 1, ns.Plain(GetInboxNumItems()) or 0 do
        local kind, item, who, bid = GetInboxInvoiceInfo(i)
        kind, item, who, bid = ns.Plain(kind), ns.Plain(item), ns.Plain(who), ns.Plain(bid)
        -- "" not loaded yet (read again at the next update), nil "multiple
        -- buyers": either way nobody to note.
        if type(item) == "string" and type(who) == "string" and who ~= "" then
            if kind == "seller" then
                local key = table.concat({ item, who, tostring(bid) }, "|")
                local used = false
                for _, craft in pairs(book.made) do
                    if craft.letter == key then used = true end
                end
                local craft = not used and OldestInHand(book, function(c) return c.name == item end)
                if craft then
                    craft.toName, craft.how, craft.handed, craft.letter = who, "auction", now, key
                    changed = true
                end
            elseif kind == "buyer" then
                local key = item .. "|" .. who
                if not book.bought[key] then
                    book.bought[key] = { name = item, fromName = who, t = now }
                    changed = true
                end
            end
        end
    end
    if changed then Reindex() end
end

ns.On("MAIL_INBOX_UPDATE", Letters)

--------------------------------------------------------------------------
-- The worn slots
--------------------------------------------------------------------------

local SLOTS = 19

local function Worn()
    worn = { ids = {}, names = {} }
    for slot = 1, SLOTS do
        local link = ns.Plain(GetInventoryItemLink("player", slot))
        local id = ItemID(link)
        if id then
            worn.ids[id] = link
            local name = ItemName(link)
            if name then worn.names[name] = id end
        end
    end

    local book = Book(Journey.Kept())
    if book then
        -- Won at auction, now put on: from the seller, by name.
        for key, bought in pairs(book.bought) do
            local id = worn.names[bought.name]
            if id and not book.got[id] then
                book.got[id] = { fromName = bought.fromName, how = "auction", t = bought.t, link = worn.ids[id] }
                book.bought[key] = nil
            end
        end
        -- Only what is worn now counts: once worn and taken off, let go.
        for id, got in pairs(book.got) do
            if worn.ids[id] then
                got.worn = true
            elseif got.worn then
                book.got[id] = nil
            end
        end
    end
    Reindex()
end

ns.On("SD_WORLD_SETTLED", Worn)
ns.On("PLAYER_EQUIPMENT_CHANGED", Worn)

--------------------------------------------------------------------------
-- The inspect queue
--------------------------------------------------------------------------

local pending       -- { guid, unit, at } while an ask is out
local lastAsk = -math.huge
local asked = {}    -- [guid] = when they were last read

local function InspectOpen()
    return InspectFrame ~= nil and InspectFrame:IsShown() and true or false
end

local function Away()
    return (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) or false
end

-- Whether to ask after `guid` at all: Stage 2 everyone, Stage 1 those
-- with a craft of the user's not yet found on them (Kind.lua's gate).
local function Wanted(guid, book)
    if CrafterDetection.INSPECT_EVERYONE then return true end
    for _, craft in pairs(book.made) do
        if craft.to == guid and not craft.met and not craft.gone then return true end
    end
    return false
end

-- What `unit` (whose GUID is `guid`) wears, read once an inspect answered.
local function Read(unit, guid)
    local j = Journey.Kept()
    local book = j and Book(j)
    if not book then return end
    local ids, n = {}, 0
    for slot = 1, SLOTS do
        local id = ItemID(ns.Plain(GetInventoryItemLink(unit, slot)))
        if id then ids[id], n = true, n + 1 end
    end
    -- Nothing read is no answer (a cold cache, someone out of reach): not
    -- counted as having looked, so the next meeting asks again.
    if n == 0 then return end
    asked[guid] = ns.Now()
    local found = false
    for _, craft in ipairs(CrafterDetection.Crafts(book)) do
        if craft.to == guid and not craft.met and not craft.gone and ids[craft.id] then
            craft.met = ns.Now()
            Connect(guid, THEIRS, craft.id, craft.link, craft.how, unit)
            found = true
        end
    end
    if found then Reindex() end
end

local function Ask(unit, guid)
    local now = ns.Now()
    local j = Journey.Kept()
    local book = j and Book(j)
    if not book or Away() or InspectOpen() then return end
    if pending and now - pending.at < T.timeout then return end
    if now - lastAsk < T.gap then return end
    if asked[guid] and now - asked[guid] < T.again then return end
    if not Wanted(guid, book) then return end
    if type(CanInspect) ~= "function" or type(NotifyInspect) ~= "function" then return end
    local ok, can = pcall(CanInspect, unit)
    if not ok or not ns.Plain(can) then return end

    lastAsk = now
    pending = { guid = guid, unit = unit, at = now }
    NotifyInspect(unit)
    C_Timer.After(T.timeout, function()
        if pending and pending.guid == guid and ns.Now() - pending.at >= T.timeout then pending = nil end
    end)
end

-- The unit token that is `guid` now, of those the queue asks by.
local function TokenOf(guid)
    for _, unit in ipairs({ "target", "mouseover" }) do
        if ns.SafeGUID(UnitGUID(unit)) == guid then return unit end
    end
    return nil
end

ns.On("INSPECT_READY", function(_, guid)
    guid = ns.SafeGUID(guid)
    if not guid then return end
    local unit
    if pending and pending.guid == guid then
        unit = ns.SafeGUID(UnitGUID(pending.unit)) == guid and pending.unit or TokenOf(guid)
        pending = nil
    elseif InspectOpen() then
        -- Someone else asked (the Inspect frame, another addon): read along.
        unit = TokenOf(guid)
    end
    if unit then Read(unit, guid) end
end)

--------------------------------------------------------------------------
-- Meeting people
--------------------------------------------------------------------------

local function Met(unit, inspect)
    if not index.any and not CrafterDetection.INSPECT_EVERYONE then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    if IsInInstance and IsInInstance() then return end
    local guid = ns.SafeGUID(UnitGUID(unit))
    if not guid or guid == ns.ownGUID then return end
    local j = Journey.Kept()
    local book = j and Book(j)
    if not book then return end

    -- Known by name only until now: by GUID from here on.
    if next(index.names) then
        local name = ns.JoinName(ns.NameFromUnit(unit))
        if name and index.names[name] then
            for _, craft in pairs(book.made) do
                if craft.toName == name then craft.to, craft.toName = guid, nil end
            end
            for _, got in pairs(book.got) do
                if got.fromName == name then got.from, got.fromName = guid, nil end
            end
            Reindex()
        end
    end

    -- "yours": they gave or sold the user what the user wears now.
    if index.guids[guid] then
        for id, got in pairs(book.got) do
            if got.from == guid and worn.ids[id] then
                Connect(guid, YOURS, id, worn.ids[id] or got.link, got.how, unit)
            end
        end
    end

    -- "theirs": a craft of the user's on them? Ask.
    if inspect then Ask(unit, guid) end
end

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) Met(unit, false) end)
ns.On("PLAYER_TARGET_CHANGED", function() Met("target", true) end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() Met("mouseover", true) end)

-- For the tests.
ns._test.CrafterDetection = {
    Reindex = Reindex,
    Worn = Worn,
    Index = function() return index end,
    Pending = function() return pending end,
    Reset = function()
        pending, lastAsk, asked = nil, -math.huge, {}
        worn = { ids = {}, names = {} }
        index = { guids = {}, names = {}, any = false }
    end,
}
