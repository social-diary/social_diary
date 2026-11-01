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
--            from too: { key, type = "text" (most: bytes, default TEXT_MOST)
--            | "number" (min, max) | "choice" (values, a list) | "person" }. A
--            field left empty or out of its type is cleared. A person is one
--            text line over the People search: `key` keeps the name as written,
--            and `guid` (the key to keep it under, default key .. "Guid") the
--            diary entry it was picked from, nil for a name only typed. Typing
--            over a picked name lets the entry go. Forgetting someone takes the
--            GUID and leaves the name (Forget, below)
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
-- and each field, for its row on the form (UI/Journey/CardSheet.lua): label;
-- hint (optional: beside a number, under a text while it is empty); for a
-- choice names (value → words). A choice is shown as a box per value, at most
-- one ticked, none ticked being no value.

local addonName, ns = ...

local Custom = {}
ns.Custom = Custom

local Journey = ns.Journey

local TEXT_MOST = 60

local function SpecOf(kind)
    local moment = ns.JourneyRecap.MOMENTS[kind]
    return moment and moment.custom or nil
end

-- The kinds that may be custom, and their specs: the editor's to read.
Custom.Spec = SpecOf

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

local function CleanText(text, most)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|", ""):gsub("[%c]+", " ")
    return ns.Diary.Clean(text, most or TEXT_MOST)
end

local function CleanField(field, value)
    if field.type == "text" or field.type == "person" then
        return CleanText(value, field.most)
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
                local guid = clean and ns.SafeGUID(fields[key])
                out[key] = guid and ns.Diary.IsDiary(guid) and guid or false
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
    if not (spec and j and where and where.mapID and where.x and where.y and where.from and where.to) then
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
    j.custom = j.custom or {}
    local at = #j.custom + 1
    while at > 1 and j.custom[at - 1].t > t do at = at - 1 end
    table.insert(j.custom, at, rec)
    Journey.Touch()
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
