-- Creature names, for a while: a service on the route (Core/Journey.lua)
-- that the deaths, close calls and hunts (Features/) note and read.
--
-- The death recap may give a mob a made-up surname ("Murloc Forager
-- Olwynne" for a Murloc Forager), and where it names the mob only once
-- there is nothing to take it off by (the deaths' capture tries: names in
-- common).
-- A creature's name as read off a unit (target, mouseover, a nameplate)
-- puts it right. They are kept on the route by npcID, j.names[npcID] =
-- { name, when last read }, for NAMES.days and at most NAMES.most, the
-- least recent dropped first: a name only has to outlive the recap, and a
-- record it puts right keeps it (a list registered `named`,
-- Journey.RegisterList).
-- Where the user runs QuestieDB, it knows every creature's name by its id
-- (EXT-1), so a creature never read off a unit is put right too.
--
--   Of(j, npcID)           the name a creature goes by
--   Clean(j, npcID, name)  a recap's name without its surname
--   Note(npcID, name, now) a name read off a unit now
--   Prune(j, now)          at login (Journey.Prune): put right, then dropped

local addonName, ns = ...

local CreatureNames = {}
ns.CreatureNames = CreatureNames

local Journey = ns.Journey

local NAMES = { days = 3, most = 60 }

-- Whether `long` is `name` with words tacked on.
local function Surnamed(long, name)
    return type(long) == "string" and type(name) == "string" and #long > #name + 1
        and long:sub(1, #name + 1) == name .. " "
end

-- The name a creature of kind `npcID` goes by: as last read off a unit,
-- else as QuestieDB has it, where the user runs it (EXT-1), else as a
-- list registered `readNames` kept it (the lists in the order they
-- registered: the newest of its records first, or as the list's own
-- function reads them). Nil where none says.
function CreatureNames.Of(j, npcID)
    if not (j and npcID) then return nil end
    local known = j.names and j.names[npcID]
    if known then return known[1] end
    local db = ns.QuestieBridge and ns.QuestieBridge.NpcName(npcID)
    if db then return db end
    for _, name in ipairs(Journey.READ_NAMES) do
        local read = Journey.LISTS[name].readNames
        if type(read) == "function" then
            local found = read(j, npcID)
            if found then return found end
        else
            local list = j[name] or {}
            for i = #list, 1, -1 do
                if list[i].npcID == npcID and list[i].name then return list[i].name end
            end
        end
    end
    return nil
end

-- `name`, as the recap gave a creature of kind `npcID`, without the
-- surname where its own name is known.
function CreatureNames.Clean(j, npcID, name)
    local known = CreatureNames.Of(j, npcID)
    if known and Surnamed(name, known) then return known end
    return name
end

-- The records of the lists registered `named` put down to a creature of
-- kind `npcID` (every kind when nil) under a surname, put right. Whether
-- any was.
local function Mend(j, npcID)
    local any = false
    for name, spec in pairs(Journey.LISTS) do
        if spec.named then
            for _, d in ipairs(j[name] or {}) do
                if d.npcID and d.name and (not npcID or d.npcID == npcID) then
                    local clean = CreatureNames.Clean(j, d.npcID, d.name)
                    if clean ~= d.name then d.name, any = clean, true end
                end
            end
        end
    end
    if any then Journey.Touch() end
    return any
end

-- A creature's name read off a unit now: kept a while (NAMES), and every
-- record of a `named` list put down to its kind under a surname put right.
function CreatureNames.Note(npcID, name, now)
    name = ns.Plain(name)
    local j = Journey.Kept()
    if not (j and type(npcID) == "number" and type(name) == "string" and name ~= "") then return end
    j.names = j.names or {}
    j.names[npcID] = { name, now or ns.Now() }
    local n, least, at = 0, nil, nil
    for id, rec in pairs(j.names) do
        n = n + 1
        if not at or rec[2] < at then least, at = id, rec[2] end
    end
    if n > NAMES.most then j.names[least] = nil end
    Mend(j, npcID)
end

-- The creature a name typed by the player means (Core/Custom.lua), by the
-- records this character keeps of it, whatever the case: its npcID, and a
-- display where one was read, so a card can draw it. The newest record with a
-- display first. Nil where no record knows it.
function CreatureNames.Find(j, name)
    if not (j and type(name) == "string") then return nil end
    name = name:lower()
    local id
    for list, spec in pairs(Journey.LISTS) do
        if spec.named or spec.readNames then
            local records = j[list] or {}
            for i = #records, 1, -1 do
                local rec = records[i]
                if rec.npcID and type(rec.name) == "string" and rec.name:lower() == name then
                    if rec.display then return rec.npcID, rec.display end
                    id = id or rec.npcID
                end
            end
        end
    end
    return id
end

-- The names past NAMES.days dropped, once what they put right is mended.
function CreatureNames.Prune(j, now)
    Mend(j)
    for id, rec in pairs(j.names or {}) do
        if now - rec[2] > NAMES.days * 24 * 60 * 60 then j.names[id] = nil end
    end
    if j.names and next(j.names) == nil then j.names = nil end
end
