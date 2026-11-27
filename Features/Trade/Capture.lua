-- Trade capture (INT-1, Must; verified in Session 1 as T-E8): a completed
-- trade, written as a row of its kind (Kind.lua) on the person traded with.
--
-- The first interaction source, and the best one to build first: it is
-- self-contained, it was verified end to end in this client, and it is the
-- spine of flow 2 -- trade with a stranger, walk away, add them an hour later
-- and find the trade already on their profile.
--
-- The awkward part is that the trade window's contents are gone by the time
-- the trade is confirmed, so the snapshot is rebuilt on every change while
-- the window is open and only committed when the client says the trade
-- completed. Session 1 observed that confirmation as UI_INFO_MESSAGE 251 and
-- the cancellation as 250.
--
-- Rebuilding on every change has a trap: completing the trade empties the
-- slots, and those change events can land before the confirmation, so the
-- last reading is an empty window (seen in the client, 6 Oct: a completed
-- trade stored with an empty context). So the contents are also fixed the
-- moment either side accepts -- any later change resets the acceptance and
-- with it that copy -- and nothing is read after the window closes.
--
-- LOC-1: the outcome is read from the numeric message id, never from the
-- English text ("Trade complete."), which would break in any other locale.

local addonName, ns = ...

-- Prefer the client's own constants; fall back to what Session 1 observed.
local TRADE_COMPLETE = LE_GAME_ERR_TRADE_COMPLETE or 251
local TRADE_CANCELLED = LE_GAME_ERR_TRADE_CANCELLED or 250

-- The last trade slot is the "will not be traded" slot.
local function TradeSlots()
    return (MAX_TRADE_ITEMS or 7) - 1
end

-- Held only while a trade is in flight. Never persisted: it is rebuilt from
-- the live window on every change.
local pending = nil

local function ReadSide(infoFn, linkFn)
    local items = nil

    for slot = 1, TradeSlots() do
        local name, _, count = infoFn(slot)
        name = ns.Plain(name)

        if name then
            items = items or {}
            items[#items + 1] = {
                link = ns.Plain(linkFn and linkFn(slot)) or name,
                count = ns.Plain(count) or 1,
            }
        end
    end

    return items
end

-- Rebuilt wholesale rather than patched, because the change events say that
-- something changed but not what.
local function Snapshot()
    if not pending or pending.closed then return end

    pending.contents = {
        given = ReadSide(GetTradePlayerItemInfo, GetTradePlayerItemLink),
        received = ReadSide(GetTradeTargetItemInfo, GetTradeTargetItemLink),
        moneyGiven = ns.Plain(GetPlayerTradeMoney and GetPlayerTradeMoney()) or 0,
        moneyReceived = ns.Plain(GetTargetTradeMoney and GetTargetTradeMoney()) or 0,
    }
end

-- Numbers in the classic API, booleans in some newer builds.
local function Accepted(value)
    value = ns.Plain(value)
    return value == 1 or value == true
end

-- The trade partner sits on the "NPC" unit token, which is also where
-- Blizzard's own trade frame reads the name from.
local function Open()
    local record = ns.Characters.ObserveUnit("NPC")
    if not record then
        ns.Debug("trade opened but the partner could not be identified")
        pending = nil
        return
    end

    pending = {
        guid = record.guid,
        level = record.level,
        started = ns.Now(),
    }
    Snapshot()
end

local function Commit()
    if not pending then return end

    local guid = pending.guid
    local c = pending.agreed or pending.contents or {}

    ns.Interactions.Add(guid, "trade", {
        theirLevel = pending.level,
        context = {
            given = c.given,
            received = c.received,
            moneyGiven = c.moneyGiven ~= 0 and c.moneyGiven or nil,
            moneyReceived = c.moneyReceived ~= 0 and c.moneyReceived or nil,
        },
    })

    -- The picker's "you traded with them" (Core/Candidates.lua).
    ns.Recent.Set("trade", guid)
    -- For whoever cares what was received from whom, or given to whom
    -- (SD_TRADE_COMPLETED, Core/Events.lua), as the trade is stored.
    ns.Fire("SD_TRADE_COMPLETED", guid, c.received, c.given)
    ns.Debug("trade completed with %s: gave %d item(s) and %dc, got %d item(s) and %dc (%s)",
        ns.Characters.FullName(guid) or guid, c.given and #c.given or 0, c.moneyGiven or 0,
        c.received and #c.received or 0, c.moneyReceived or 0,
        pending.agreed and "as accepted" or "last reading")
    pending = nil
end

ns.On("TRADE_SHOW", Open)
ns.On("TRADE_PLAYER_ITEM_CHANGED", Snapshot)
ns.On("TRADE_TARGET_ITEM_CHANGED", Snapshot)
ns.On("TRADE_MONEY_CHANGED", Snapshot)

-- Either side accepting fixes what the trade is; (0, 0) means a change
-- reset both, and the next accept fixes it again.
ns.On("TRADE_ACCEPT_UPDATE", function(_, player, target)
    if not pending or pending.closed then return end
    Snapshot()
    if Accepted(player) or Accepted(target) then
        pending.agreed = pending.contents
    else
        pending.agreed = nil
    end
end)

-- TRADE_CLOSED fires on the way out of a completed trade as well as an
-- abandoned one, so it cannot be the signal to discard. The snapshot is left
-- standing and the confirmation message decides its fate; the timer is the
-- backstop for a trade that ends without either message arriving.
ns.On("TRADE_CLOSED", function()
    if not pending then return end

    -- From here the window only shows emptied slots.
    pending.closed = true

    -- Without a timer this runs at once and drops the snapshot, which is
    -- all the backstop can do then.
    local expiring = pending
    ns.After(5, function()
        if pending == expiring then
            ns.Debug("trade window closed without a result; snapshot dropped")
            pending = nil
        end
    end)
end)

ns.On("UI_INFO_MESSAGE", function(_, messageType)
    if pending == nil then return end

    messageType = ns.Plain(messageType)
    if messageType == TRADE_COMPLETE then
        Commit()
    elseif messageType == TRADE_CANCELLED then
        pending = nil
    end
end)

ns._test.TradeCapturePending = function() return pending end
