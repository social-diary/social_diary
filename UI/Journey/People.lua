-- The people on a plate of Your Diary (JRN-22): one margin note each, by
-- their marks' height (People); who a note names (NoteGuid, Named, for the
-- caption not to name them again); a rival's ring (Rival); and how much a
-- person's note matters in the margin, by what they did there (Tier).
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local YourDiary = ns.UI.YourDiary

-- The people on a plate (JRN-22): one note per person, a stranger never
-- grouped with another, ordered by their marks' height so the leaders do
-- not cross. Each { guid, moments, marks (page points), top }.
--
-- A fight whose mark names no one (a stranger then: Journey.Fight keeps only
-- a diary person's GUID) but whose foe the buffer still knows, and who is in
-- the diary now, is theirs here: inked in after the fights, they get one
-- strip, not one a fight (20 Nov 2026). The moment keeps its own GUID (nil):
-- the moments' keys are the curation's saved data (Core/JourneyRecap.lua).
local function Whose(m, index)
    if m.guid or m.kind ~= "fight" or not m.mark then return m.guid end
    local who = ns.Journey.FightWho(m.mark, index)
    return who and ns.Diary.IsDiary(who) and who or nil
end

local function People(plate)
    local groups, byGuid = {}, {}
    local page = YourDiary.page
    local index = page and page.fights or {}
    for _, m in ipairs(plate.people or {}) do
        local at = plate.where[m]
        local guid = Whose(m, index)
        local g = guid and byGuid[guid]
        if not g then
            g = { guid = guid, moments = {}, marks = {}, top = at[2] }
            groups[#groups + 1] = g
            if guid then byGuid[guid] = g end
        end
        g.moments[#g.moments + 1] = m
        local known = false
        for _, p in ipairs(g.marks) do
            if p[1] == at[1] and p[2] == at[2] then known = true end
        end
        if not known then g.marks[#g.marks + 1] = at end
        g.top = math.min(g.top, at[2])
    end
    table.sort(groups, function(a, b) return a.top < b.top end)
    return groups
end

-- Who a note names: its person, if the diary knows them, else no one
-- (a stranger, "someone").
local function NoteGuid(g)
    return g.guid and ns.db.characters[g.guid] ~= nil and g.guid or nil
end

-- Who the first `n` notes name, for the caption not to name them again
-- (Text.PlateCaption's `named`).
--
-- The caption tells a fight by its moment's GUID, which a fight with
-- someone inked in later has not (People's Whose): such fights on a named
-- note count as `someone` too, one each, so the caption knows them told.
local function Named(groups, n)
    local named = { someone = 0 }
    for i = 1, math.min(n, #groups) do
        local guid = NoteGuid(groups[i])
        if guid then
            named[guid] = true
            for _, m in ipairs(groups[i].moments) do
                if m.kind == "fight" and not m.guid then named.someone = named.someone + 1 end
            end
        else
            named.someone = named.someone + 1
        end
    end
    return named
end

-- Whether `guid` is a rival: a diary entry tagged "foe".
local function Rival(guid)
    local entry = guid and ns.db.diary[guid]
    for _, tag in ipairs(entry and entry.tags or {}) do
        if tag == "foe" then return true end
    end
    return false
end

-- How much a person's note matters in the margin, by what they did there:
-- 1 for something done together (time in a group, a fight, a note), 2 for
-- a first sighting seen in hindsight, 3 for paths only crossed; a
-- feature's moment joined to theirs says its own (its `person.tier`, Core/
-- JourneyRecap.lua's RegisterMoment: something they gave you is 1). A
-- person is their best moment's tier. (11 Oct, in the client: two first
-- sightings took the column and the killer card was left off.)
local TIER = { session = 1, fight = 1, note = 1, added = 1, first = 2, crossed = 3 }

local function Tier(g)
    local best = 3
    for _, m in ipairs(g.moments) do
        best = math.min(best, TIER[m.kind] or (m.person and m.person.tier) or 2)
    end
    return best
end

YourDiary.People, YourDiary.NoteGuid, YourDiary.Named, YourDiary.Rival, YourDiary.Tier = People, NoteGuid, Named, Rival, Tier
