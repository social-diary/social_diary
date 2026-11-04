-- Slash commands: /sd and /socialdiary.
--
-- One dispatcher, and one ordered list per command level that both it and
-- /sd help read, so a command cannot be listed without being reachable or
-- the other way round. Each file registers the commands it owns:
--
--   ns.Slash.Register(name, fn, help, opts)
--
--   name   the word after /sd, lower case
--   fn     fn(rest, name): rest is everything after the name, trimmed; name
--          is the word typed, which tells aliases apart
--   help   the line /sd help shows
--   opts   dev    development tooling (Dev/): runs as any command, but /sd
--                 help lists it only while debug is on
--          alias  more names for the same command, not listed
--          usage  what help shows in place of the name ("of <name>")
--          under  "sightings" for a subcommand of /sd sightings
--
-- The user's commands are here. The diagnostics live in Dev/ and register
-- themselves, so dropping that folder drops them and nothing else.

local addonName, ns = ...

local Slash = {}
ns.Slash = Slash

local function Group(prefix, header)
    return { prefix = prefix, header = header, list = {}, byName = {} }
end

local groups = {
    [""] = Group("/sd", "commands:"),
    sightings = Group("/sd sightings"),
}

function Slash.Register(name, fn, help, opts)
    opts = opts or {}
    local group = groups[opts.under or ""]
    if not group then error(("no /sd command group %q"):format(tostring(opts.under)), 2) end

    local names = { name }
    for _, alias in ipairs(opts.alias or {}) do names[#names + 1] = alias end

    local command = { name = name, names = names, fn = fn, help = help,
        dev = opts.dev == true, usage = opts.usage or name }

    for _, key in ipairs(names) do
        if group.byName[key] then
            error(("%s %s is registered twice"):format(group.prefix, key), 2)
        end
        group.byName[key] = command
    end

    group.list[#group.list + 1] = command
    return command
end

-- The user's commands first, in registration order; the development ones
-- after them, and only while debug is on.
local function Usage(group)
    if group.header then ns.Print(group.header) end
    local passes = ns.DebugOn() and 2 or 1
    for pass = 1, passes do
        for _, command in ipairs(group.list) do
            if command.dev == (pass == 2) then
                DEFAULT_CHAT_FRAME:AddMessage(("   |cffffd100%s %s|r  -- %s")
                    :format(group.prefix, command.usage, command.help))
            end
        end
    end
end

-- Anything unknown, "help" included, answers with the list.
local function Dispatch(group, input)
    local name, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    name = name:lower()
    local command = group.byName[name]
    if command then
        command.fn(rest, name)
    else
        Usage(group)
    end
end

-- For the smoke tests: the registered commands of a level, in order.
function ns._test.SlashCommands(under)
    return groups[under or ""].list
end

--------------------------------------------------------------------------
-- The diary (DIA-2's slash-command entry point)
--------------------------------------------------------------------------

-- Resolves what the user typed, or falls back to their target. Returns the
-- GUID, or nil after having explained why.
local function ResolveArgument(text, unitFallback)
    if text and text ~= "" then
        local guid, hits = ns.Characters.FindByName(text)
        if guid then return guid end

        if hits == 0 then
            ns.Print("no character called |cffffffff%s|r on record.", text)
        else
            ns.Print("|cffffffff%s|r matches %d characters -- add the surname.", text, hits)
        end
        return nil
    end

    if unitFallback and UnitExists("target") and UnitIsPlayer("target") then
        local guid = ns.SafeGUID(UnitGUID("target"))
        if guid and guid ~= ns.ownGUID then return guid, "target" end
    end

    return nil
end

Slash.ResolveArgument = ResolveArgument

local function CommandAdd(text)
    local guid, unit = ResolveArgument(text, true)

    if not guid then
        if not text or text == "" then
            -- Nothing typed and nothing targeted: the picker is the answer.
            ns.UI.ShowPicker()
        end
        return
    end

    ns.UI.Remember(guid, { unit = unit, source = "slash" })
end

local function CommandRemove(text)
    local guid = ResolveArgument(text, true)
    if not guid then
        ns.Print("usage: |cffffd100/sd remove <name>|r, or target them first.")
        return
    end

    if not ns.Diary.IsDiary(guid) then
        ns.Print("|cffffffff%s|r is not in the diary.", ns.Characters.FullName(guid) or guid)
        return
    end

    -- DIA-7's choice lives in the popup, so both entry points offer it.
    ns.UI.ConfirmRemove(guid)
end

local function CommandList()
    local entries = ns.Diary.List()

    for i = 1, #entries do
        local entry = entries[i]
        local tags = #entry.tags > 0 and ("  |cffffd100" .. table.concat(entry.tags, ", ") .. "|r") or ""
        DEFAULT_CHAT_FRAME:AddMessage(("   %-22s %s%s"):format(
            ns.Characters.FullName(entry.guid) or entry.guid,
            date("%d %b %Y", entry.addedAt), tags))
    end

    ns.Print("%d diary entr%s.", #entries, #entries == 1 and "y" or "ies")
end

-- PRV-3: any character, in the diary or not. Name only: forgetting whoever
-- happens to be targeted is too easy to do by accident.
local function CommandForget(text)
    if not text or text == "" then
        ns.Print("usage: |cffffd100/sd forget <name>|r")
        return
    end
    local guid = ResolveArgument(text, false)
    if guid then ns.UI.ConfirmForget(guid) end
end

--------------------------------------------------------------------------
-- Sightings (M2), until the journal shows them
--------------------------------------------------------------------------
--
-- The status report, the nameplate scan, the tooltip walk-through and seen
-- around are diagnostics: Dev/SightingsDebug.lua registers them.

local MapName = ns.MapName

local function RowZone(row)
    return ns.RowZone(row) or (row.mapID and ("map " .. row.mapID)) or "?"
end

-- JNL-3's data: the last 24 hours (or `hours`), grouped by zone.
local function SightingRecent(text)
    local hours = tonumber(text) or 24
    local now = ns.Now()
    local list = ns.Sightings.Since(now - hours * 3600)

    local zones, order = {}, {}
    for i = 1, #list do
        local zone = RowZone(list[i].row)
        if not zones[zone] then
            zones[zone] = {}
            order[#order + 1] = zone
        end
        local group = zones[zone]
        group[#group + 1] = list[i]
    end

    for _, zone in ipairs(order) do
        local group = zones[zone]
        DEFAULT_CHAT_FRAME:AddMessage(("   |cffffd100%s|r  %d"):format(zone, #group))
        for i = 1, math.min(#group, 8) do
            local entry = group[i]
            local row = entry.row
            -- Wide enough for "yesterday at 18:02" and "on 12 Sep at 18:02".
            DEFAULT_CHAT_FRAME:AddMessage(("      %-22s lvl %-3s %-18s %s%s%s"):format(
                ns.Characters.FullName(entry.guid) or entry.guid,
                tostring(row.level or "?"), ns.UI.Format.At(ns.Sightings.Last(row), now), row.src or "",
                row.hostile and "  |cffc04040hostile|r" or "",
                ns.Diary.IsDiary(entry.guid) and "  |cffffd100[diary]|r" or ""))
        end
        if #group > 8 then
            DEFAULT_CHAT_FRAME:AddMessage(("      |cff808080and %d more|r"):format(#group - 8))
        end
    end

    ns.Print("%d character%s seen in the last %s hour%s.", #list, #list == 1 and "" or "s",
        tostring(hours), hours == 1 and "" or "s")
end

local function SightingsOf(text)
    local guid = ResolveArgument(text, true)
    if not guid then
        if not text or text == "" then ns.Print("usage: |cffffd100/sd sightings of <name>|r, or target them.") end
        return
    end

    local name = ns.Characters.FullName(guid) or guid
    local summary = ns.Sightings.Summary(guid)
    if not summary then
        ns.Print("no sightings of |cffffffff%s|r.", name)
        return
    end

    local zones = {}
    for key, n in pairs(summary.zones or {}) do
        zones[#zones + 1] = ("%s %d"):format(type(key) == "number" and (MapName(key) or key) or key, n)
    end

    ns.Print("|cffffffff%s|r: %d sighting(s), %s to %s, level %s-%s%s", name, summary.count,
        date("%d %b %Y", summary.first), date("%d %b %Y %H:%M", summary.last),
        tostring(summary.levelMin or "?"), tostring(summary.levelMax or "?"),
        summary.hostile and (", hostile %d time(s)"):format(summary.hostile) or "")
    DEFAULT_CHAT_FRAME:AddMessage("   " .. table.concat(zones, ", "))

    local rows = ns.Sightings.For(guid)
    for i = #rows, math.max(1, #rows - 9), -1 do
        local row = rows[i]
        DEFAULT_CHAT_FRAME:AddMessage(("   %s%s  %s%s  lvl %s  %s%s"):format(
            date("%d %b %H:%M", row.time),
            row.last and date("-%H:%M", row.last) or "      ",
            (row.subZone and (row.subZone .. ", ") or "") .. RowZone(row),
            row.x and (" (you at %.1f, %.1f)"):format(row.x * 100, row.y * 100) or "",
            tostring(row.level or "?"), row.src or "",
            row.hostile and "  |cffc04040hostile|r" or ""))
    end
end

local function SightingCity(text)
    local Capture = ns.SightingCapture
    local verb, arg = text:match("^(%S*)%s*(.-)$")
    verb = verb:lower()

    if verb == "add" or verb == "remove" then
        local key = tonumber(arg)
        if not key and arg ~= "" then key = arg end
        if not key then
            key = (verb == "remove" and ns.City())
                or ns.Plain(C_Map.GetBestMapForUnit("player"))
        end
        if key == nil or key == "sanctuary" then
            ns.Print("nothing to %s here.", verb)
            return
        end

        Capture.SetCity(key, verb == "add")
        ns.Print("%s %s the city list.", type(key) == "number" and (MapName(key) or key) .. " (" .. key .. ")" or key,
            verb == "add" and "added to" or "removed from")
    end

    local here = ns.City()
    for _, city in ipairs(Capture.Cities()) do
        local key = city.key
        DEFAULT_CHAT_FRAME:AddMessage(("   %s %-8s %s%s"):format(
            city.on and "|cff40c040on |r" or "|cff808080off|r", tostring(key),
            type(key) == "number" and (MapName(key) or "") or "",
            here == key and "  |cffffd100<- you are here|r" or ""))
    end
    ns.Print("here: map %s, %s -- %s.", tostring(ns.Plain(C_Map.GetBestMapForUnit("player"))),
        tostring(ns.Plain(GetRealZoneText())), here and "a city" or "not a city")
end

-- The switch answers with the status report when Dev/ is loaded.
--------------------------------------------------------------------------
-- The list, in /sd help's order
--------------------------------------------------------------------------

local Register = Slash.Register

-- JNL-4: the bare command is the journal, like every addon's main window.
Register("journal", function() ns.UI.ToggleJournal() end,
    "open the journal (also plain |cffffd100/sd|r)", { alias = { "" } })
Register("add", CommandAdd, "add your target to the diary, or |cffffd100/sd add <name>|r")
Register("remember", function() ns.UI.TogglePicker() end, "open the Remember this picker")
Register("list", CommandList, "list diary entries")
Register("remove", CommandRemove, "remove <name> from the diary")
Register("sightings", function(rest) Dispatch(groups.sightings, rest) end,
    "sighting capture; |cffffd100/sd sightings help|r for more")
Register("settings", function() ns.UI.ShowSettings() end, "open the settings")
Register("about", function() ns.UI.ShowIntro() end, "show the introduction again")
Register("forget", CommandForget, "delete everything about <name>, in the diary or not")
-- Not a dev command: the extra chat messages (ns.Debug) a bug report
-- wants, in a release too. In development it also lists the dev commands.
Register("debug", function()
    ns.db.settings.debug = not ns.db.settings.debug
    ns.Print("debug %s.", ns.db.settings.debug and "on" or "off")
end, "turn extra chat messages on or off, for reporting a bug")

local function Sub(name, fn, help, opts)
    opts = opts or {}
    opts.under = "sightings"
    Register(name, fn, help, opts)
end

Sub("recent", SightingRecent, "who was seen in the last 24 hours, by zone", { usage = "recent [hours]" })
Sub("of", SightingsOf, "one character's sightings, or your target's", { usage = "of <name>" })
-- No "add|remove": |r is the client's colour reset and would eat the r.
Sub("city", SightingCity, "the city list; without an id, the map you are on",
    { usage = "city [add or remove] [mapID]" })
SLASH_SOCIALDIARY1 = "/sd"
SLASH_SOCIALDIARY2 = "/socialdiary"

SlashCmdList.SOCIALDIARY = function(input)
    Dispatch(groups[""], input)
end
