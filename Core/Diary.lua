-- The diary itself (DIA-1 to DIA-7).
--
-- DIA-1 is the rule the whole module exists to enforce: a character enters the
-- diary because the user said so, never because the addon inferred it. Every
-- function here is reached from a user action, and nothing in Capture/ calls
-- Add.
--
-- DIA-5 says an entry arrives with the character's buffered interactions
-- already attached. It does that by *not* copying them: interactions already
-- live under the character's GUID, and Interactions.Prune skips anyone in the
-- diary, so adding somebody promotes their existing buffer to permanent
-- history in one assignment. Removing them (DIA-7, "keep") demotes it again.

local addonName, ns = ...

local Diary = {}
ns.Diary = Diary

-- DIA-6. Custom tags are allowed alongside these.
Diary.PRESET_TAGS = { "friend", "helper", "foe", "avoid" }

local MAX_TAGS = 12
local MAX_TAG_CHARS = 24
local MAX_NOTE_CHARS = 2000
local MAX_RELATIONSHIP_CHARS = 60

--------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------

function Diary.Get(guid)
    guid = ns.SafeGUID(guid)
    if not guid then return nil end
    return ns.db.diary[guid]
end

-- db.diary is the single source of truth for membership. The character record
-- deliberately carries no isDiary flag: two copies of the same fact drift, and
-- this one decides whether a person's history is kept forever or pruned.
function Diary.IsDiary(guid)
    return Diary.Get(guid) ~= nil
end

function Diary.Count()
    return ns.CountKeys(ns.db.diary)
end

-- Every entry, in no order: `for guid, entry in Diary.Each() do`. For the
-- derived views (People, Heat) that visit them all and sort their own way.
function Diary.Each()
    return pairs(ns.db.diary)
end

-- Everyone, newest first, for /sd list. The journal's People list (JNL-1)
-- filters and sorts through People.Index instead.
function Diary.List()
    local list = {}
    for _, entry in pairs(ns.db.diary) do
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        if a.addedAt ~= b.addedAt then return a.addedAt > b.addedAt end
        return a.guid < b.guid
    end)
    return list
end

--------------------------------------------------------------------------
-- Adding
--------------------------------------------------------------------------

local function CaptureGuild(unit)
    if not unit or not GetGuildInfo or not UnitExists(unit) then return nil end
    return ns.Plain((GetGuildInfo(unit)))
end

-- DIA-5's "when, where and from which entry point", kept as one table so a
-- profile can say "added from the target menu in Mulgore at level 12".
-- `where` is where the user met them, when that is not here and now: an add
-- from the Recently nearby page passes the sighting's place.
local function AddedContext(source, record, where)
    where = where or ns.Where()

    return {
        source = source or "unknown",
        zone = where.zone,
        mapID = where.mapID,
        x = where.x,
        y = where.y,
        instanceID = where.instanceID,
        myLevel = ns.Plain(UnitLevel("player")),
        theirLevel = record and record.level or nil,
    }
end

-- The entry `guid` would get, read now, without adding it; nil when the
-- character cannot be identified. Also whether they are right here, for
-- Insert. A draft keeps this until Done, so the unit token is read once, at
-- the moment the user asked: by Done the target may be somebody else.
local function Prepare(guid, opts)
    -- A unit token is the richer source, so prefer it and fall back to the
    -- GUID alone (the chat-name path, DIA-2a).
    local record
    if opts.unit then
        record = ns.Characters.ObserveUnit(opts.unit)
    end
    if not record then
        record = ns.Characters.ObserveGUID(guid) or ns.Characters.Get(guid)
    end
    if not record then return nil end

    local entry = {
        guid = record.guid,
        addedAt = ns.Now(),
        addedBy = ns.ownGUID,  -- DAT-1: which of the user's characters added them
        addedContext = AddedContext(opts.source, record, opts.where),
        tags = {},
        note = nil,
        relationship = nil,
        personId = nil,

        -- DIA-5: identity as it was at the moment of adding. The character
        -- record keeps the live values; these are the snapshot.
        guildAtAdd = CaptureGuild(opts.unit),
        class = record.class,
        race = record.race,
        sex = record.sex,
        faction = record.faction,
    }

    -- Added off a unit token (target, mouseover, a unit frame in range): they
    -- are right here.
    local here = opts.unit and UnitIsVisible and UnitIsVisible(opts.unit) and true or false
    return entry, here
end

-- Writes a prepared entry into the diary, unless they are in it already.
local function Insert(entry, here)
    local guid = entry.guid
    local existing = ns.db.diary[guid]
    if existing then return existing, false end

    ns.db.diary[guid] = entry
    ns.Touch()
    -- Where they were seen before they were added, then where they are now.
    ns.Heat.Backfill(guid, entry.addedAt)
    ns.Characters.SeenFromSightings(guid)
    if here then ns.Characters.Seen(guid) end

    ns.Print("added |cffffffff%s|r to the diary.", ns.Characters.FullName(guid) or guid)
    ns.Debug("%d buffered interaction(s) came with them",
        ns.Interactions.Count(guid))

    return entry, true
end

-- The one way in. `opts` may carry unit, source, where, note, tags and relationship;
-- all of them are optional, because DIA-4 wants adding to cost two actions and
-- everything else to be fillable afterwards.
--
-- Returns the entry and true when it was newly added, or the existing entry
-- and false when the character was already in the diary.
function Diary.Add(guid, opts)
    opts = opts or {}

    local prepared, here = Prepare(guid, opts)
    if not prepared then return nil, false end

    local entry, added = Insert(prepared, here)
    if not added then return entry, false end

    guid = entry.guid
    if opts.note then Diary.SetNote(guid, opts.note) end
    if opts.relationship then Diary.SetRelationship(guid, opts.relationship) end
    if opts.tags then
        for i = 1, #opts.tags do Diary.AddTag(guid, opts.tags[i]) end
    end

    return entry, true
end

-- Entries added off a sighting before Insert filled `seen` (up to 1.5.0)
-- still read "Not seen nearby yet.". Run at login, before the roll-up folds
-- the rows away; only touches entries with no `seen`, so repeating is free.
function Diary.FillSeen()
    for guid in pairs(ns.db.diary) do
        local record = ns.Characters.Get(guid)
        if record and not record.seen then ns.Characters.SeenFromSightings(guid) end
    end
end

--------------------------------------------------------------------------
-- Editing (DIA-6)
--------------------------------------------------------------------------

local function Clean(text, limit)
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    return ns.CutBytes(text, limit)
end

-- For the other things the user writes (Core/Notes.lua), so every piece of
-- text the user types is trimmed and capped the same way.
Diary.Clean = Clean
Diary.MAX_NOTE_CHARS = MAX_NOTE_CHARS

-- The edits, on an entry table: one in the diary, or a draft's (below).
local Edit = {}

function Edit.HasTag(entry, tag)
    if type(tag) ~= "string" then return false end

    tag = tag:lower()
    for i = 1, #entry.tags do
        if entry.tags[i] == tag then return true end
    end
    return false
end

function Edit.SetNote(entry, note)
    entry.note = Clean(note, MAX_NOTE_CHARS)
    return true
end

function Edit.SetRelationship(entry, relationship)
    entry.relationship = Clean(relationship, MAX_RELATIONSHIP_CHARS)
    return true
end

function Edit.AddTag(entry, tag)
    tag = Clean(tag, MAX_TAG_CHARS)
    if not tag then return false end
    tag = tag:lower()

    if Edit.HasTag(entry, tag) then return false end
    if #entry.tags >= MAX_TAGS then return false end

    entry.tags[#entry.tags + 1] = tag
    return true
end

function Edit.RemoveTag(entry, tag)
    if type(tag) ~= "string" then return false end

    tag = tag:lower()
    for i = #entry.tags, 1, -1 do
        if entry.tags[i] == tag then
            table.remove(entry.tags, i)
            return true
        end
    end
    return false
end

-- What a tag button does.
function Edit.ToggleTag(entry, tag)
    if Edit.HasTag(entry, tag) then
        Edit.RemoveTag(entry, tag)
        return false
    end
    Edit.AddTag(entry, tag)
    return Edit.HasTag(entry, tag)
end

function Diary.HasTag(guid, tag)
    local entry = Diary.Get(guid)
    return entry ~= nil and Edit.HasTag(entry, tag)
end

-- An edit, by GUID, on the diary's entry: false when they are not in it.
local function OnDiary(edit)
    return function(guid, ...)
        local entry = Diary.Get(guid)
        if not entry then return false end
        local result = edit(entry, ...)
        ns.Touch()
        return result
    end
end

Diary.SetNote = OnDiary(Edit.SetNote)
Diary.SetRelationship = OnDiary(Edit.SetRelationship)
Diary.AddTag = OnDiary(Edit.AddTag)
Diary.RemoveTag = OnDiary(Edit.RemoveTag)
Diary.ToggleTag = OnDiary(Edit.ToggleTag)

--------------------------------------------------------------------------
-- Drafts: somebody being written up, not added yet
--------------------------------------------------------------------------

-- The add page writes on a draft until Done (UI/Windows/Entry.lua), so closing
-- it without Done adds nobody (DIA-1: they enter because the user said so).
-- A draft answers the same calls as Diary -- Get, HasTag and the edits, by
-- GUID -- on an entry of its own; Save adds the person as written. `opts`
-- is Add's, read now. Nil when the character cannot be identified.
function Diary.Draft(guid, opts)
    local entry, here = Prepare(guid, opts or {})
    if not entry then return nil end
    guid = entry.guid

    local draft = { guid = guid }

    local function Own(edit)
        return function(g, ...)
            if ns.SafeGUID(g) ~= guid then return false end
            return edit(entry, ...)
        end
    end

    function draft.Get(g)
        if ns.SafeGUID(g) == guid then return entry end
    end
    draft.HasTag = Own(Edit.HasTag)
    draft.SetNote = Own(Edit.SetNote)
    draft.SetRelationship = Own(Edit.SetRelationship)
    draft.AddTag = Own(Edit.AddTag)
    draft.RemoveTag = Own(Edit.RemoveTag)
    draft.ToggleTag = Own(Edit.ToggleTag)

    -- Like Add: the entry, and whether it is new. Somebody added meanwhile
    -- (a menu, a command) keeps their entry, with what was written here
    -- put on it.
    function draft.Save()
        local saved, added = Insert(entry, here)
        if not added then
            if entry.note then saved.note = entry.note end
            if entry.relationship then saved.relationship = entry.relationship end
            for _, tag in ipairs(entry.tags) do Edit.AddTag(saved, tag) end
            ns.Touch()
        end
        return saved, added
    end

    return draft
end

-- Quiet nearby: no toast when they come into view (REU-5), for the people
-- you play with so often that it would only nag. Joining your group still
-- toasts. Kept on the entry, so it goes when they leave the diary.
function Diary.IsQuietNearby(guid)
    local entry = Diary.Get(guid)
    return entry ~= nil and entry.quietNearby == true
end

function Diary.SetQuietNearby(guid, quiet)
    local entry = Diary.Get(guid)
    if not entry then return false end
    entry.quietNearby = quiet and true or nil
    ns.Touch()
    return true
end

--------------------------------------------------------------------------
-- Removing (DIA-7)
--------------------------------------------------------------------------

-- PRV-3: the entries, as one of the stores Characters.Forget walks.
ns.RegisterStore("diary", function(guid)
    if guid == nil then wipe(ns.db.diary) else ns.db.diary[guid] = nil end
end)

-- Two outcomes, and the user picks:
--
--   "keep"   the diary entry goes; the character stays as an ordinary
--            character and the buffer's retention rules start applying to
--            their interactions again on the next prune.
--   "purge"  everything the addon knows about them is deleted.
function Diary.Remove(guid, mode)
    guid = ns.SafeGUID(guid)
    if not guid or not ns.db.diary[guid] then return false end

    local name = ns.Characters.FullName(guid) or guid
    ns.db.diary[guid] = nil
    ns.Touch()
    -- Their heat so far is counted: added again, only what came after
    -- folds in (Heat.Backfill).
    local record = ns.Characters.Get(guid)
    if record then record.heatFrom = ns.Now() end

    if mode == "purge" then
        ns.Characters.Forget(guid)
        ns.Print("deleted everything about |cffffffff%s|r.", name)
    else
        ns.Print("removed |cffffffff%s|r from the diary; their history is now"
            .. " kept under the buffer's retention rules.", name)
    end

    return true
end
