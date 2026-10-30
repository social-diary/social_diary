-- Namespace bootstrap. Every file in the TOC receives this table as its
-- second vararg, so nothing is exported into _G except what the TOC needs.

local addonName, ns = ...

ns.addonName = addonName
ns.version = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or "0.0.0"

-- Hooks for the smoke tests, which have no frames, menus or trade window to
-- drive. Nothing in the addon reads from here; keeping them in one place
-- means a test-only function never passes for part of the API.
ns._test = {}

local CHAT_PREFIX = "|cff7db8ffSocial Diary|r "

function ns.Print(msg, ...)
    if select("#", ...) > 0 then
        msg = msg:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. msg)
end

-- Whether debug output is on (/sd debug). It also decides whether /sd help
-- lists the development commands.
function ns.DebugOn()
    return (ns.db and ns.db.settings.debug) and true or false
end

function ns.Debug(msg, ...)
    if not ns.DebugOn() then return end
    if select("#", ...) > 0 then
        msg = msg:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(CHAT_PREFIX .. "|cff808080" .. msg .. "|r")
end

-- Secret-value safety (NFR-4, INT-5).
--
-- A secret must never be compared, boolean-tested, used as a table key or
-- written to SavedVariables. Every read of a value that the API can guard
-- goes through one of these two helpers first: IsSecret answers the question
-- without touching the value, Plain hands back a usable substitute.

local issecretvalue = issecretvalue

function ns.IsSecret(value)
    if not issecretvalue then return false end
    return issecretvalue(value)
end

-- Returns `value` when it is safe to use, otherwise `fallback` (nil by default).
function ns.Plain(value, fallback)
    if issecretvalue and issecretvalue(value) then
        return fallback
    end
    return value
end

-- `text` in at most `limit` bytes, never through the middle of a UTF-8
-- character: a cut that lands on a continuation byte steps back to its start.
function ns.CutBytes(text, limit)
    if #text <= limit then return text end
    local stop = limit
    while stop > 0 do
        local byte = text:byte(stop + 1)
        if byte < 0x80 or byte >= 0xC0 then break end
        stop = stop - 1
    end
    return text:sub(1, stop)
end

-- DAT-4: one clock for everything that gets stored.
function ns.Now()
    return GetServerTime()
end

ns.DAY = 24 * 60 * 60

-- Local midnight at or before `t`. Close enough across a DST change, which
-- only moves a time near midnight to the neighbouring day.
function ns.DayStart(t)
    local d = date("*t", t)
    return t - (d.hour * 3600 + d.min * 60 + d.sec)
end

-- The data version: a counter that moves on every write the derived views
-- read (diary edits, sessions, a diary entry's rows, a rename). Whatever is
-- built from the stores -- People's index today -- keeps the version it was
-- built at and rebuilds when that differs, so no write has to know who caches
-- what, and a read after no write rebuilds nothing. In memory only: a fresh
-- load has no cache to be stale.
--
-- Here rather than in Events.lua because the stores that call it load first.
ns.dataVersion = 0

function ns.Touch()
    ns.dataVersion = ns.dataVersion + 1
end

-- Moves when anyone at all is seen anew or dealt with, diary or not: what
-- can make a stranger matter (JRN-23). Kept apart from the data version so
-- the People index does not rebuild for every passer-by.
ns.seenVersion = 0

function ns.TouchSeen()
    ns.seenVersion = ns.seenVersion + 1
end

-- How many keys a table has. The stores are keyed by GUID or id, so `#`
-- says nothing about them.
function ns.CountKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- The list a per-GUID store keeps under `key`, created empty on first use.
-- The buffer, the sightings and "seen around" are all { [guid] = { ... } },
-- and a GUID with nothing on record has no key at all.
function ns.ListFor(store, key)
    local list = store[key]
    if not list then
        list = {}
        store[key] = list
    end
    return list
end

-- PRV-3: every store that holds something about other players registers
-- how to forget one of them (`guid`) or everyone (nil). Characters.Forget
-- and WipeData both walk this one list, so a store added later is forgotten
-- by both or by neither -- never by one and not the other.
local stores = {}

function ns.RegisterStore(name, forget)
    stores[#stores + 1] = { name = name, forget = forget }
end

-- In registration order, which is load order.
function ns.ForgetEverywhere(guid)
    for i = 1, #stores do stores[i].forget(guid) end
end
