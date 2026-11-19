-- Custom cards (.claude/features/custom-cards.md): what the player says
-- happened, over or beside what the addon saw. It is their diary, so nothing
-- here is checked against the route: a conflict is their decision.
--
-- Two shapes, both on the character's route:
--
--   rec.custom   a detected record, edited or hidden: the changed fields only,
--                `false` for one cleared, or { hidden = true }. The detected
--                values stay as they were, so Reset is taking `custom` off,
--                and what writes to a record later (a name put right, its
--                creature's display) carries on underneath. Never write a
--                typed name onto the record itself: CreatureNames.Of reads
--                the lists raw, and it would rename that creature elsewhere.
--   j.custom     the cards the player inserted, any kind, oldest first:
--                { kind, t, mapID, x, y, level, <the kind's fields> }. `kind`
--                is the registered moment's. A list of its own because not
--                every kind keeps a list (j.firsts is one record a kind, a
--                death's cross comes from the route), and so that nothing
--                goes back-dated into a list kept oldest first, under its cap.
--
-- Both are read through Recap's Gather as copies (Read, Inserted) carrying
-- `customOf`, the saved record, so what reads a card (its mark, its card, the
-- caption, the prose) needs no telling, and a card custom in any way can be
-- found (`rec.customOf`) by what must treat it differently: a custom card
-- outranks everything for its place on the page and is never replaced. The
-- page shows no difference: they look the same as automatic ones, the user's
-- call, 1 Nov.
--
-- A kind opts in on its moment (Recap.RegisterMoment's `custom`):
--
--   fields   the list of what the player may set, which the editor is built
--            from too: { key, type = "text" (most: bytes, default TEXT_MOST;
--            lines: how many lines it may keep, default one)
--            | "number" (min, max) | "choice" (values, a list) | "person"
--            | "people" (count: at most, default PEOPLE_MOST) | "item" (id)
--            | "icon" | "flag", optional }. A field left empty or out of its
--            type is cleared. A person is one
--            text line over the People search: `key` keeps the name as written,
--            and `guid` (the key to keep it under, default key .. "Guid") the
--            diary entry it was picked from, nil for a name only typed. Typing
--            over a picked name lets the entry go. Forgetting someone takes the
--            GUID and leaves the name (Forget, below).
--            People is a list of such: { { name, guid }, ... }, each as a
--            person's, the nameless left out, one entry once, `count` at most;
--            an empty list is none. Forgetting takes the GUID inside the list.
--            An item keeps its name under `key` (what the card shows) and its
--            item ID under `id` (default key .. "ID"); never the link, whose
--            `|` codes a card must not wear. A link given as the value (a
--            shift-click) is read for both (Custom.ItemOf). No name, no item.
--            An icon is one of the note icons' keys (ns.NoteIcons.KEYS, asked
--            when cleaned); anything else is the first of them, and an inserted
--            card always has one. A flag is true or absent.
--            `optional`: the form offers it behind a "+ Add" (CardSheet); here
--            it only means what every field does, that left empty it is absent.
--            For the form: `add`, an optional field's strip's words ("+ Add
--            mob"; "+ Add <label>" where nil)
--   values   optional function(values, rec): for the form, what a detected card
--            shows but does not keep under its field's key (an opponent's name
--            from their GUID, an item's from its link). `rec` is the saved record.
--            Only shown: a field left as it was is not written
--   wrap     optional function(rec) → what the kind's e[entry] holds, where its
--            entries are not its records (the firsts': { kind, rec })
--   timeOf   optional function(entry) → its time, with `wrap`, where an entry
--            has no `t` of its own
--   defaults optional: the fields an inserted card starts with
--   creature optional, the key of the field naming a creature: a name this
--            character's records know brings that creature's npcID and display
--            (CreatureNames.Find), for the card's picture
--   label    what the picker titles it, in title case: "Close Call"
--   heading  optional: the form's heading, "A close call"; `label` where nil
--   group    its type in the picker, by key: combat, lore (Quests and Lore),
--            social, other. Any other is treated as other. The words are the
--            picker's (UI/Journey/CardSheet.lua), so a kind cannot make a type
--   at       optional: its place within its type, lowest first (0 where nil);
--            by kind after that. Its map mark (Plate.RegisterMark) is drawn on its
--            card, asked without an `arg`
--   describe optional function(rec) → a menu's line for one card, where a spot
--            merges several or one is hidden; `label` where nil
--   offer    optional function() → whether the logged-in character may insert
--            a card of this kind now: a class's moments only on that class
--            (asked at call time; offered where nil). It gates inserting only:
--            a card already on the route is still edited, hidden and reset
-- and each field, for its row on the form (UI/Journey/CardSheet.lua): label;
-- hint (optional: beside a number, under a text while it is empty); for a
-- choice names (value → words). A choice is shown as a box per value, at most
-- one ticked, none ticked being no value.

local addonName, ns = ...

local Custom = {}
ns.Custom = Custom

local Journey = ns.Journey

local TEXT_MOST = 60
-- People on one card at most, where its field does not say.
local PEOPLE_MOST = 4
Custom.TEXT_MOST, Custom.PEOPLE_MOST = TEXT_MOST, PEOPLE_MOST

local function SpecOf(kind)
    local moment = ns.JourneyRecap.MOMENTS[kind]
    return moment and moment.custom or nil
end

-- The kinds that may be custom, and their specs: the editor's to read.
Custom.Spec = SpecOf

-- Whether a card of `kind` may be inserted now (its spec's `offer`).
function Custom.Offered(kind)
    local spec = SpecOf(kind)
    return spec ~= nil and (spec.offer == nil or spec.offer() == true)
end

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

local function Copy(rec)
    local copy = {}
    for key, value in pairs(rec) do copy[key] = value end
    return copy
end

-- A record as the page reads it: as it is with nothing custom, nil when
-- hidden, else a copy with the changes laid over it, `customOf` the record.
function Custom.Read(rec)
    local changes = rec.custom
    if not changes then return rec end
    if changes.hidden then return nil end
    local copy = Copy(rec)
    copy.custom = nil
    for key, value in pairs(changes) do
        if value == false then copy[key] = nil else copy[key] = value end
    end
    copy.customOf = rec
    return copy
end

-- A card's values as the editor shows them, hidden or not: Read's, which has
-- nothing to show for one hidden.
function Custom.Values(rec)
    local saved = rec.customOf or rec
    local copy = Copy(saved)
    copy.custom = nil
    for key, value in pairs(saved.custom or {}) do
        if value == false then copy[key] = nil else copy[key] = value end
    end
    copy.hidden = nil
    return copy
end

-- j's inserted cards of `kind` within a..b, as the page reads them, oldest
-- first.
function Custom.Inserted(j, kind, a, b)
    local list = {}
    for _, rec in ipairs(j and j.custom or {}) do
        if rec.kind == kind and rec.t >= a and rec.t < b then
            local copy = Copy(rec)
            copy.customOf, copy.inserted = rec, true
            list[#list + 1] = copy
        end
    end
    return list
end

local function Position(j, rec)
    for i, other in ipairs(j and j.custom or {}) do
        if other == rec then return i end
    end
    return nil
end

--------------------------------------------------------------------------
-- What the player typed
--------------------------------------------------------------------------

-- A typed line as a card can wear it: on one line, without the client's
-- escape sequences (a stray colour code would run on over the card), short.
-- Where a person's field keeps the diary entry it was picked from.
function Custom.GuidKey(field)
    return field.guid or (field.key .. "Guid")
end

-- The people the search offers for what is typed so far (`most` of them): { name,
-- guid }, by the People list's order. A search on tags and notes too, so the
-- caller shows the name, which may not hold what was typed.
function Custom.FindPeople(text, most)
    local found = {}
    if type(text) ~= "string" or not text:find("%S") then return found end
    for _, s in ipairs(ns.People.Query({ search = text })) do
        found[#found + 1] = { name = s.name, guid = s.guid }
        if #found >= most then break end
    end
    return found
end

-- Where an item field keeps the item's ID.
function Custom.ItemKey(field)
    return field.id or (field.key .. "ID")
end

--------------------------------------------------------------------------
-- Items
--------------------------------------------------------------------------

local function Plain(value)
    return ns.Plain(value)
end

-- `fn`(...) where the client has it, guarded: its values, or nothing.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return Plain(a), Plain(b), Plain(c), Plain(d), Plain(e)
end

local function IdOfLink(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- What the client knows of an item's name now: its cache, never waited for.
-- An item it does not know yet is asked for, so a later search may find it.
local function NameOfId(itemID)
    local name = C_Item and Ask(C_Item.GetItemNameByID, itemID)
    if type(name) ~= "string" and GetItemInfo then name = Ask(GetItemInfo, itemID) end
    if type(name) == "string" and name ~= "" then return name end
    if C_Item then Ask(C_Item.RequestLoadItemDataByID, itemID) end
    return nil
end

-- A shift-clicked item link as a card keeps it: { itemID, name }, the name
-- as the link says it (else the client's cache). Nil for anything not an
-- item, or an item with no name to show yet.
function Custom.ItemOf(link)
    link = Plain(link)
    local itemID = IdOfLink(link)
    if not itemID then return nil end
    local name = link:match("|h%[(.-)%]|h") or NameOfId(itemID)
    if type(name) ~= "string" or name == "" then return nil end
    return { itemID = itemID, name = name }
end

-- Where the diary keeps items of the character's own, beside the bags and
-- what is worn: features register a source (Custom.RegisterItems), function(j)
-- → a list of links or item IDs, from the route `j`. The core's own: what
-- the character looted in dungeons (the visits' loot, their own lines).
local itemSources = {}
function Custom.RegisterItems(key, fn)
    itemSources[key] = fn
end

local function DungeonLoot()
    local list, me = {}, ns.ownGUID
    for _, visit in pairs(ns.db and ns.db.instances or {}) do
        if type(visit) == "table" and (visit.me or me) == me then
            for _, entry in ipairs(visit.loot or {}) do
                if entry.guid == me then list[#list + 1] = entry.item or entry.itemID end
            end
        end
    end
    return list
end

-- Every item the character has or the diary holds for them, by item ID:
-- { itemID, name (nil where not known yet), link, quality }.
local function OwnItems()
    local items, order = {}, {}
    local function Add(thing, quality)
        thing = Plain(thing)
        local itemID = type(thing) == "number" and thing or IdOfLink(thing)
        if not itemID then return end
        local it = items[itemID]
        if not it then
            it = { itemID = itemID }
            items[itemID] = it
            order[#order + 1] = it
        end
        if type(thing) == "string" then
            it.link = it.link or thing
            it.name = it.name or thing:match("|h%[(.-)%]|h")
        end
        quality = Plain(quality)
        if type(quality) == "number" then it.quality = it.quality or quality end
    end
    local C = C_Container
    if C and C.GetContainerNumSlots then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local size = Ask(C.GetContainerNumSlots, bag)
            for slot = 1, type(size) == "number" and size or 0 do
                local info = Ask(C.GetContainerItemInfo, bag, slot)
                if type(info) == "table" then Add(info.hyperlink or info.itemID, info.quality) end
            end
        end
    end
    if GetInventoryItemLink then
        for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
            Add(Ask(GetInventoryItemLink, "player", slot), GetInventoryItemQuality and Ask(GetInventoryItemQuality, "player", slot))
        end
    end
    local j = Journey.Mine()
    if j then
        local keys = {}
        for key in pairs(itemSources) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local ok, list = pcall(itemSources[key], j)
            for _, thing in ipairs(ok and type(list) == "table" and list or {}) do Add(thing) end
        end
    end
    for _, thing in ipairs(DungeonLoot()) do Add(thing) end
    return order
end

-- How well `name` answers `text` (both lower case), lowest best: the whole
-- name, its start, a word's start, anywhere in it, its letters in order
-- (a fuzzy "thsash" for "Thistle Sash"); nil for not at all.
local function Match(name, text)
    if name == text then return 0 end
    local at = name:find(text, 1, true)
    if at == 1 then return 1 end
    if at then
        -- A word's start: after anything not a letter or digit.
        local from = 1
        while true do
            local found = name:find(text, from, true)
            if not found then break end
            if found == 1 or name:sub(found - 1, found - 1):find("[%s%p]") then return 2 end
            from = found + 1
        end
        return 3
    end
    local pos = 1
    for i = 1, #text do
        local ch = text:sub(i, i)
        if not ch:find("%s") then
            pos = name:find(ch, pos, true)
            if not pos then return nil end
            pos = pos + 1
        end
    end
    return 4
end

-- The items the search offers for what is typed so far (`most` of them):
-- { itemID, name, icon, quality }, from the bags, what is worn and what the
-- diary holds for this character, the best matches first (then the shorter
-- name, then by name). An item whose name the client does not know yet is
-- left out: it is asked for, and the next keystroke may find it.
function Custom.FindItems(text, most)
    local found = {}
    if type(text) ~= "string" or not text:find("%S") then return found end
    local want = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, it in ipairs(OwnItems()) do
        local name = it.name or NameOfId(it.itemID)
        local score = type(name) == "string" and name ~= "" and Match(name:lower(), want)
        if score then
            local icon = C_Item and Ask(C_Item.GetItemIconByID, it.itemID)
            local quality = it.quality or (C_Item and Ask(C_Item.GetItemQualityByID, it.itemID))
                or ns.Timeline.Quality(it.link)
            found[#found + 1] = { itemID = it.itemID, name = name, icon = icon, quality = quality, score = score }
        end
    end
    table.sort(found, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if #a.name ~= #b.name then return #a.name < #b.name end
        if a.name ~= b.name then return a.name < b.name end
        return a.itemID < b.itemID
    end)
    for i = #found, 1, -1 do
        if i > (most or #found) then found[i] = nil else found[i].score = nil end
    end
    return found
end

--------------------------------------------------------------------------
-- Cleaning
--------------------------------------------------------------------------

-- The note icons' keys, asked when needed (Features/Note/Icons.lua loads
-- after this file), and the one a card has where it names none.
local function IconKeys()
    local icons = ns.NoteIcons
    local keys = icons and type(icons.KEYS) == "table" and icons.KEYS
    return keys and keys[1] and keys or { "meeting" }
end
function Custom.DefaultIcon()
    return IconKeys()[1]
end

-- A typed line as a card can wear it: on one line, without the client's
-- escape sequences, short. A text with `lines` above one keeps that many
-- lines, each trimmed, the rest run on into the last.
local function CleanText(text, most, lines)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|", "")
    if type(lines) == "number" and lines > 1 then
        text = text:gsub("\r\n?", "\n"):gsub("[%c]", function(c) return c == "\n" and "\n" or " " end)
        local kept = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            line = line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")
            if line ~= "" then
                if #kept < lines then kept[#kept + 1] = line else kept[#kept] = kept[#kept] .. " " .. line end
            end
        end
        text = table.concat(kept, "\n")
    else
        text = text:gsub("[%c]+", " ")
    end
    return ns.Diary.Clean(text, most or TEXT_MOST)
end

-- A diary entry a name may link to: only one in the diary.
local function Linkable(guid)
    guid = ns.SafeGUID(guid)
    return guid and ns.Diary.IsDiary(guid) and guid or nil
end

local function CleanPeople(field, value)
    if type(value) ~= "table" then return nil end
    local list, seen = {}, {}
    for _, p in ipairs(value) do
        local name = CleanText(type(p) == "table" and p.name or p, field.most)
        local guid = name and type(p) == "table" and Linkable(p.guid) or nil
        local same = (guid or (name and name:lower())) or nil
        if name and not seen[same] then
            seen[same] = true
            list[#list + 1] = { name = name, guid = guid }
            if #list >= (field.count or PEOPLE_MOST) then break end
        end
    end
    return list[1] and list or nil
end

local function CleanField(field, value)
    if field.type == "text" or field.type == "person" then
        return CleanText(value, field.most, field.type == "text" and field.lines or nil)
    elseif field.type == "people" then
        return CleanPeople(field, value)
    elseif field.type == "icon" then
        for _, key in ipairs(IconKeys()) do
            if key == value then return value end
        end
        return Custom.DefaultIcon()
    elseif field.type == "flag" then
        return (value == true or value == 1 or value == "1" or value == "true") or nil
    elseif field.type == "number" then
        value = tonumber(value)
        if not value then return nil end
        value = math.floor(value + 0.5)
        if field.min then value = math.max(field.min, value) end
        if field.max then value = math.min(field.max, value) end
        return value
    elseif field.type == "choice" then
        for _, choice in ipairs(field.values) do
            if choice == value then return value end
        end
    end
    return nil
end

-- `fields` kept to what the kind says, each cleaned: a value, or false for
-- one given but empty or not of its type. Fields not given are not in it.
local function Cleaned(spec, fields)
    local out = {}
    for _, field in ipairs(spec.fields) do
        local value = fields[field.key]
        if value ~= nil then
            local clean = CleanField(field, value)
            if clean == nil then clean = false end
            out[field.key] = clean
            -- Only a diary entry can be linked to, and no name, no link.
            if field.type == "person" then
                local key = Custom.GuidKey(field)
                out[key] = clean and Linkable(fields[key]) or false
            end
        end
        -- An item: its name and ID, from a link where one was given (a
        -- shift-click), else the name as written and the ID picked with it.
        -- No name, no item; an ID with no name takes the client's.
        if field.type == "item" then
            local idKey = Custom.ItemKey(field)
            if value ~= nil or fields[idKey] ~= nil then
                local name, itemID
                local link = type(value) == "string" and value:find("item:%d+") and Custom.ItemOf(value)
                if link then
                    name, itemID = CleanText(link.name, field.most), link.itemID
                else
                    itemID = tonumber(fields[idKey])
                    itemID = itemID and itemID > 0 and itemID == math.floor(itemID) and itemID or nil
                    name = CleanText(value, field.most) or (itemID and value == nil and CleanText(NameOfId(itemID), field.most))
                end
                out[field.key] = name or false
                out[idKey] = name and itemID or false
            end
        end
    end
    return out
end

-- The creature a typed name means, by what this character's records know
-- of it. A name they do not know has neither id nor picture: `false` clears
-- what a detected record would otherwise lend it.
local function Creature(j, spec, values)
    local key = spec.creature
    if not key or values[key] == nil then return end
    local npcID, display = ns.CreatureNames.Find(j, values[key])
    values.npcID, values.display = npcID or false, display or false
end

--------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------

-- The time on the route, within a..b, when it passed nearest the spot on
-- `mapID`; a stop's or a road's. The middle of a..b where it never came
-- this way. The player is never asked: it says which sitting a card falls in,
-- and the caption's "Twenty minutes later".
function Custom.TimeNear(j, mapID, x, y, a, b)
    local best, at
    local function Try(px, py, t)
        if not (px and py) then return end
        local dx, dy = px - x, py - y
        local far = dx * dx + dy * dy
        if not best or far < best then best, at = far, t end
    end
    local last = b - 1
    for _, seg in ipairs(Journey.All(j)) do
        local from, to = math.max(seg.from, a), math.min(seg.to, last)
        if seg.mapID == mapID and from <= to then
            if seg.kind == "stop" then
                Try(seg.x, seg.y, (from + to) / 2)
            elseif seg.kind == "road" then
                local pts = Journey.Points(seg)
                local n = #pts / 2
                for i = 1, n do
                    local t = n > 1 and seg.from + (seg.to - seg.from) * (i - 1) / (n - 1) or seg.from
                    if t >= from and t <= to then Try(pts[2 * i - 1], pts[2 * i], t) end
                end
            end
        end
    end
    return math.floor(at or (a + b) / 2)
end

-- A card of `kind` the player inserted, on the logged-in character's route
-- (Journey.Mine rather than Kept: it is their writing, not capture, so it
-- does not stop with "Keep my own route" off). `where` = { mapID, x, y, from,
-- to }: the spot on a zone map, and the open page's time, which it stays
-- within. Returns the saved record, or nil where the kind cannot be or there
-- is no route.
function Custom.Insert(kind, fields, where)
    local spec, j = SpecOf(kind), Journey.Mine()
    if not (spec and Custom.Offered(kind) and j and where and where.mapID and where.x and where.y and where.from
            and where.to) then
        return nil
    end
    local t = Custom.TimeNear(j, where.mapID, where.x, where.y, where.from, where.to)
    local rec = { kind = kind, t = t, mapID = where.mapID, x = where.x, y = where.y,
        level = ns.JourneyRecap.LevelAt(j, t) }
    for key, value in pairs(Cleaned(spec, spec.defaults or {})) do
        if value ~= false then rec[key] = value end
    end
    local values = Cleaned(spec, fields or {})
    Creature(j, spec, values)
    for key, value in pairs(values) do
        if value == false then rec[key] = nil else rec[key] = value end
    end
    -- An icon the card must have: the first, where none was given.
    for _, field in ipairs(spec.fields) do
        if field.type == "icon" and not field.optional and rec[field.key] == nil then
            rec[field.key] = Custom.DefaultIcon()
        end
    end
    j.custom = j.custom or {}
    local at = #j.custom + 1
    while at > 1 and j.custom[at - 1].t > t do at = at - 1 end
    table.insert(j.custom, at, rec)
    Journey.Touch()
    -- What the "Something missing?" hint teaches, done (Core/Hints.lua).
    ns.Hints.Retire("custom-events")
    return rec
end

-- The saved record behind a card, however it was read.
local function Saved(rec)
    return rec.customOf or rec
end

-- Fields changed on a card of `kind`. An inserted card takes them outright. A
-- detected one keeps them apart; a value back at what was detected is no
-- change, and with no change left its `custom` goes, as Reset's would.
function Custom.Edit(kind, rec, fields)
    local spec, j = SpecOf(kind), Journey.Mine()
    if not (spec and j and rec) then return false end
    local saved = Saved(rec)
    local values = Cleaned(spec, fields or {})
    Creature(j, spec, values)
    if Position(j, saved) then
        for key, value in pairs(values) do
            if value == false then saved[key] = nil else saved[key] = value end
        end
    else
        local changes = saved.custom or {}
        changes.hidden = nil
        for key, value in pairs(values) do
            local same = saved[key] == value or (value == false and saved[key] == nil)
            if same then changes[key] = nil else changes[key] = value end
        end
        saved.custom = next(changes) ~= nil and changes or nil
    end
    Journey.Touch()
    ns.Hints.Retire("custom-events")
    return true
end

-- A card moved on its map. It keeps its time, so it stays on its page.
function Custom.Move(rec, mapID, x, y)
    local j = Journey.Mine()
    if not (rec and mapID and x and y) then return false end
    local saved = Saved(rec)
    if Position(j, saved) then
        saved.mapID, saved.x, saved.y = mapID, x, y
    else
        local changes = saved.custom or {}
        changes.hidden = nil
        changes.mapID, changes.x, changes.y = mapID, x, y
        saved.custom = changes
    end
    Journey.Touch()
    return true
end

-- A detected card off the page, its record and any changes kept. Gather lists
-- it (e.hidden), so it can be brought back (Show): it has no mark left to open
-- it by.
function Custom.Hide(rec)
    if not rec then return false end
    local saved = Saved(rec)
    local changes = saved.custom or {}
    changes.hidden = true
    saved.custom = changes
    Journey.Touch()
    return true
end

-- A hidden card back on the page, with the changes it had.
function Custom.Show(rec)
    if not rec then return false end
    local saved = Saved(rec)
    if saved.custom then
        saved.custom.hidden = nil
        if next(saved.custom) == nil then saved.custom = nil end
    end
    Journey.Touch()
    return true
end

-- A detected card as it was detected.
function Custom.Reset(rec)
    if not rec then return false end
    Saved(rec).custom = nil
    Journey.Touch()
    return true
end

-- An inserted card gone. A detected one is never removed: Hide.
function Custom.Remove(rec)
    local j = Journey.Mine()
    local at = rec and Position(j, Saved(rec))
    if not at then return false end
    table.remove(j.custom, at)
    Journey.Touch()
    return true
end

--------------------------------------------------------------------------
-- Forgetting (PRV-3)
--------------------------------------------------------------------------

-- Someone forgotten leaves every card that was linked to them, nil being
-- everyone. The card and the name as written stay: the player wrote them, and
-- they are no longer anyone in the diary.
local function ForgetOn(j, guid)
    local function Clear(t, spec)
        for _, field in ipairs(spec.fields) do
            if field.type == "person" then
                local key = Custom.GuidKey(field)
                if t[key] and (guid == nil or t[key] == guid) then t[key] = nil end
            elseif field.type == "people" and type(t[field.key]) == "table" then
                for _, p in ipairs(t[field.key]) do
                    if type(p) == "table" and p.guid and (guid == nil or p.guid == guid) then p.guid = nil end
                end
            end
        end
    end
    for _, rec in ipairs(j.custom or {}) do
        local spec = SpecOf(rec.kind)
        if spec then Clear(rec, spec) end
    end
    for _, moment in pairs(ns.JourneyRecap.MOMENTS) do
        if moment.custom and moment.list then
            for _, rec in ipairs(j[moment.list] or {}) do
                if rec.custom then Clear(rec.custom, moment.custom) end
            end
        end
    end
end

Journey.RegisterList("custom", { forget = ForgetOn })
