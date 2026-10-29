-- SavedVariables bootstrap.
--
-- DAT-1: each character keeps a diary of its own, unless the user shares one
-- between all of them (the Memory settings). Two files hold it:
--
--   SocialDiaryDB      account-wide: the account settings, the user's own
--                      characters, and the shared diary once there is one.
--   SocialDiaryCharDB  per character: that character's settings, and its own
--                      diary while the diary is not shared.
--
-- The settings themselves are per character, all but ACCOUNT_SETTINGS below.
-- .claude/rules/settings.md says how to choose for a new one.
--
-- Everything else reads ns.db, which is the diary loaded this login with
-- `settings` laid over it, so no other file needs to know which file a value
-- lives in. DAT-2 splits storage into an always-loaded core and a
-- load-on-demand archive; only the core lives here. The archive is a separate
-- addon and does not exist yet.

local addonName, ns = ...

-- Three version numbers, each saved as `schema` in what it numbers: a diary
-- (the shared one, or a character's own), the account file around it, and
-- the per-character file. They move apart: a file can be converted at one
-- login while a diary that is not loaded waits for its next. Bump one with a
-- step in its list below.
local SCHEMA_VERSION = 5     -- a diary
local ACCOUNT_SCHEMA = 1     -- SocialDiaryDB, apart from the shared diary
local CHARACTER_SCHEMA = 2   -- SocialDiaryCharDB, apart from its own diary

-- One diary: everything recorded about other players, and the roads of the
-- characters who write into it. Each record notes which of the user's
-- characters was there (`me`, `addedBy`, or keyed by their GUID), so a shared
-- diary can still tell them apart.
local DIARY = {
    schema = SCHEMA_VERSION,

    characters = {},    -- [guid]      = every character ever observed
    diary = {},         -- [guid]      = characters the user added (DIA-1)
    persons = {},       -- [personId]  = manual alt groupings (DIA-8)
    sessions = {},      -- [sessionId] = open and recent together sessions
    instances = {},     -- [visitId]   = instance visits (INS-1)
    interactions = {},  -- rolling buffer, 7 days (INT-2)
    sightings = {},     -- recent raw sightings, rolled up after 30 days (SIG-7)
    around = {},        -- [guid] = "seen around" stretches of diary entries (SES-9)
    notes = {},         -- [noteId]    = what the user wrote into the diary (DIA-11)
    -- Your Diary (8.11): [charGUID] = the user's own route, per character
    -- (Core/Journey.lua).
    journey = {},
    journeyRaw = {},    -- JRN-18: raw breadcrumbs, a ring buffer, only with debug on

    -- Bookkeeping that is about the addon rather than about other players.
    meta = {
        lastLogin = nil,
        -- [guid] = when that character began this diary, for the bookplate
        -- on the front matter (UI/Journal/Front.lua): { time, zone, level }.
        begun = {},

        nextSessionId = 1,
        openSession = nil,  -- id of the one open together session (SES-1)
        nextVisitId = 1,    -- Core/Instances.lua's ids (INS-1)
        openVisit = nil,    -- id of the one open visit (Core/Instances.lua)
        nextNoteId = 1,     -- Core/Notes.lua's ids (DIA-11)

        -- The group as last seen, so a /reload does not read every member as
        -- having just joined (SES-3). `time` keeps it honest across a logout.
        roster = { members = {} },

        -- [guid] = when they last got a reunion toast, for the cooldown. Saved
        -- so a /reload does not reset it.
        greeted = {},
    },
}

-- The settings that belong to the person at the keyboard rather than to one
-- character. Every key not listed here is per character.
local ACCOUNT_SETTINGS = {
    -- DAT-1: one diary for every character instead of one each. Read at
    -- login only: a change applies after a /reload (ns.ShareDiary).
    shareDiary = false,
    -- PRV-4: the book's front matter, which says what is kept, has been
    -- read. Until it has, the parcel asks for it at every login
    -- (UI/Windows/Intro/Parcel.lua) and the journal opens on it.
    frontRead = false,
    -- The introduction turned through to its end, or its label under
    -- the book dismissed: the label stops asking (UI/Journal/IntroLabel.lua).
    introDone = false,
    debug = false,
}

local CHARACTER_SETTINGS = {
    storeChat = true,   -- INT-3: chat storage can be switched off
    chatLines = 50,     -- INT-3: lines of chat kept per character...
    chatUnlimited = false,  -- ...or every line
    -- INT-2 and SIG-7 in one: interactions with people outside the diary
    -- are deleted after this, and raw sightings of anyone roll up into
    -- per-person summaries. One window, so the Recently nearby page never
    -- lists a day whose "dealt with" marks are already gone. Decision D3.
    bufferDays = 30,
    toasts = true,      -- REU-1
    nearbyToasts = true,  -- REU-5
    toastCooldownMinutes = 10,  -- at most one toast per person this often
    foeToastsUncooled = false,  -- ...except for foes, if asked (world PvP)
    -- toastAt: where the toast lies, { x, y } of its top from the
    -- screen's top middle, once moved (UI/Windows/Reunion/Toast.lua). Unset is
    -- the default place.
    foeAlert = false,   -- a raid warning when a foe comes into view (Core/Reunions.lua)
    tooltips = true,    -- REU-4
    tooltipSeen = false,  -- REU-6: "Seen N times" for people outside the diary
    bookStack = true,   -- the journal's page stack grows with the diary and turns with the page
    flatSheets = false,  -- "Flat paper only": loose sheets (the map, notes) without folds, bends or grime
    revealMap = false,  -- "Always show the whole map": the map sheets fill in unexplored areas too (UI/Map/Art.lua)
    dungeonRoute = true,  -- MAP-4: a run's map draws the usual way through (UI/Dungeon/Print.lua)
    -- The parcel at login has been torn open: from then on it comes back
    -- torn, the diary's note beside the book (UI/Windows/Intro/Parcel.lua).
    parcelOpened = false,
    detectSightings = true,  -- SIG-1: passive detection in the open world
    keepRoute = true,   -- JRN-17: Your Diary keeps the character's own route
    peopleSort = "lastMet",  -- the People list's sort, a preference (People.SORTS)

    -- SIG-5: where passive detection pauses. Map ids (Classic's capital
    -- maps) and, as a fallback, zone names. A removed default is stored
    -- as false rather than nil, or the defaults would bring it back.
    cities = {
        [1453] = true,  -- Stormwind City
        [1454] = true,  -- Orgrimmar
        [1455] = true,  -- Ironforge
        [1456] = true,  -- Thunder Bluff
        [1457] = true,  -- Darnassus
        [1458] = true,  -- Undercity
    },
}

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- The migration steps, by the version each one reaches: STEPS.diary[5]
-- takes a diary from 4 to 5. A step gets the table as saved, before any
-- default is filled in, so a renamed key is still under its old name and the
-- new one is not yet there. Diary schema 4 and file schema 1 (11 Oct
-- 2026) began the per-character files without carrying older diaries
-- forward, as nobody but the developer had one; the steps start after.
local STEPS = { diary = {}, account = {}, character = {} }

-- 5 (28 Oct 2026): each character's route gains its sittings
-- (Core/Sittings.lua), filled once from the route's own gaps.
STEPS.diary[5] = function(t)
    if type(t.journey) ~= "table" then return end
    for _, j in pairs(t.journey) do
        if type(j) == "table" and j.sittings == nil then
            j.sittings = ns.Sittings.Lines(ns.Sittings.FromRoute(j))
        end
    end
end

-- 2 (29 Oct 2026): the session gap is no longer a setting
-- (Core/Sessions.lua), so its saved value goes.
STEPS.character[2] = function(t)
    if type(t.settings) == "table" then t.settings.sessionGapMinutes = nil end
end

-- Oldest first, bumping `schema` after each step, so a table that skipped
-- versions still walks every one. A table with no number is new, and so
-- current already.
local function Migrate(t, current, steps)
    t.schema = t.schema or current
    for version = t.schema + 1, current do
        if steps[version] then steps[version](t) end
        t.schema = version
    end
end

ns._test.Migrate = Migrate
ns._test.DiarySteps = STEPS.diary
ns._test.CharacterSteps = STEPS.character

-- Before schema 4 the account file was the one diary, every character's.
-- It is kept as the shared diary rather than thrown away, so turning sharing
-- on finds it again; each character's own diary starts empty.
local function KeepOldDiary(account)
    if type(account.diary) ~= "table" or account.shared ~= nil then return end
    local old = {}
    for key, value in pairs(account) do
        old[key] = value
        account[key] = nil
    end
    account.own = old.meta and old.meta.characters
    if old.meta then old.meta.characters = nil end
    old.settings = nil
    account.shared = old
end

-- What is loaded this login: the diary in use and the two settings tables,
-- set by InitDB.
local account, character, diary

local function SettingsHome(key)
    return ACCOUNT_SETTINGS[key] ~= nil and account.settings or character.settings
end

-- ns.db: the diary, with `settings` reading and writing whichever file each
-- key lives in. Neither table is saved itself, so the metatables never reach
-- a SavedVariables file.
local function View()
    local settings = setmetatable({}, {
        __index = function(_, key) return SettingsHome(key)[key] end,
        __newindex = function(_, key, value) SettingsHome(key)[key] = value end,
    })
    return setmetatable({ settings = settings }, { __index = diary, __newindex = diary })
end

-- Whether the client handed back saved data this load.
--
-- Session 2 found a beta build that did not restore SavedVariables across
-- `/reload`: the file on disk was written correctly and came back empty on
-- the next load. Fixed in the client since, but the flag stays: it is cheap,
-- and the failure is invisible otherwise, since an empty database looks
-- exactly like a first run. Core/Events.lua reports it with debug on.
function ns.InitDB()
    local function Saved(t) return type(t) == "table" and next(t) ~= nil end
    local restored = Saved(SocialDiaryDB) or Saved(SocialDiaryCharDB)

    SocialDiaryDB = type(SocialDiaryDB) == "table" and SocialDiaryDB or {}
    SocialDiaryCharDB = type(SocialDiaryCharDB) == "table" and SocialDiaryCharDB or {}
    account, character = SocialDiaryDB, SocialDiaryCharDB
    KeepOldDiary(account)

    Migrate(account, ACCOUNT_SCHEMA, STEPS.account)
    Migrate(character, CHARACTER_SCHEMA, STEPS.character)
    ApplyDefaults(account, { settings = ACCOUNT_SETTINGS, own = {} })
    ApplyDefaults(character, { settings = CHARACTER_SETTINGS })

    -- Read once: the diary in use stays the same until the next load.
    ns.diaryShared = account.settings.shareDiary == true
    local home = ns.diaryShared and account or character
    local key = ns.diaryShared and "shared" or "data"
    if type(home[key]) ~= "table" then home[key] = {} end
    diary = home[key]
    Migrate(diary, SCHEMA_VERSION, STEPS.diary)
    ApplyDefaults(diary, DIARY)

    ns.db = View()
    ns.dbRestored = restored
    ns.Touch()
    return ns.db
end

-- DAT-1: share one diary between all of the user's characters, or keep one
-- each. Takes effect at the next load, which the settings page does at once.
-- Nothing is copied either way: each diary is kept where it is, so switching
-- back finds it as it was.
function ns.ShareDiary(on)
    account.settings.shareDiary = on and true or false
end

-- The user's own characters, account-wide in either case, so that an alt is
-- never a stranger in another character's diary: [guid] = { first, surname,
-- realm, level, lastLogin }.
function ns.OwnCharacters()
    return account.own
end

-- The user's settings, for the surfaces that read or set one by name (the
-- intro, the Recently nearby page, the toasts), so they do not reach into
-- the saved table's layout. SettingDefault is the shipped value, for a
-- reader that has to fall back on it.
function ns.Setting(key)
    return ns.db.settings[key]
end

function ns.SetSetting(key, value)
    ns.db.settings[key] = value
end

function ns.SettingDefault(key)
    if ACCOUNT_SETTINGS[key] ~= nil then return ACCOUNT_SETTINGS[key] end
    return CHARACTER_SETTINGS[key]
end

-- Whether a setting is the account's rather than this character's.
function ns.IsAccountSetting(key)
    return ACCOUNT_SETTINGS[key] ~= nil
end

-- A setting that must be a positive number to mean anything (a window, a
-- gap), read with its default standing in for anything else: a hand-edited
-- SavedVariables file or an old build's value must not turn into "keep
-- nothing" or "never close".
function ns.PositiveSetting(key)
    local value = ns.db.settings[key]
    if type(value) ~= "number" or value <= 0 then return ns.SettingDefault(key) end
    return value
end

-- INT-2 and SIG-7's one window (D3), in days.
function ns.BufferDays()
    return ns.PositiveSetting("bufferDays")
end

-- The oldest time still inside the window: anything before it is pruned or
-- rolled up. `days` overrides the setting.
function ns.Cutoff(now, days)
    return (now or ns.Now()) - (days or ns.BufferDays()) * ns.DAY
end

-- PRV-3's "delete everything": the diary in use, this character's own or
-- the shared one. The settings stay, because they are the user's preferences
-- rather than data about anybody, and so does the list of the user's own
-- characters. The table is emptied in place rather than replaced, since it
-- is the object the client writes back at logout.
function ns.WipeData()
    for key in pairs(diary) do diary[key] = nil end
    ApplyDefaults(diary, DIARY)
    -- The saved tables are fresh already. This reaches what is kept in memory
    -- only: sighting encounters, the capture queue, waiting toasts, the
    -- picker's recent list.
    ns.ForgetEverywhere(nil)
    ns.TouchOwnCharacter()
    ns.Touch()
end

-- DAT-3: "settings show the current size". A rough walk, not a
-- serialisation: strings by length, numbers and booleans at a flat rate, and
-- a per-entry overhead for the Lua syntax around each value. Good to within a
-- factor that does not matter for "is this getting big".
local function Size(value, depth)
    local kind = type(value)
    if kind == "string" then return #value + 4 end
    if kind ~= "table" or depth > 20 then return 8 end

    local total = 4
    for key, inner in pairs(value) do
        total = total + Size(key, depth + 1) + Size(inner, depth + 1) + 6
    end
    return total
end

-- The diary in use, not the account file around it: this character's whole
-- file while it keeps its own, the shared diary alone while it shares one.
function ns.EstimateSize()
    return Size(ns.diaryShared and diary or character, 0)
end

-- The same walk over one part of it: a character's route (Journey.Size).
function ns.EstimateSizeOf(value)
    return Size(value, 0)
end

-- Past this the Memory settings warn: the whole file is read at every login
-- and /reload (NFR-2), and diary history is never pruned.
ns.SIZE_WARNING = 20 * 1024 * 1024

-- A character whose bookplate stamp was taken this login before the client
-- knew the zone (TouchOwnCharacter).
local begunPending

-- The same login, once the client knows where it is: the zone the stamp
-- missed. On PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA (Core/Events.lua).
function ns.FillBegunZone()
    if not begunPending then return end
    local begun = ns.db.meta.begun[begunPending]
    local zone = ns.Where().zone
    if type(begun) ~= "table" then
        begunPending = nil
    elseif zone and zone ~= "" then
        begun.zone = begun.zone or zone
        begunPending = nil
    end
end

-- Records which of the user's own characters is logged in, so later records
-- can note who was present (DAT-1).
function ns.TouchOwnCharacter()
    local guid = ns.Plain(UnitGUID("player"))
    if not guid then return end

    -- Through the normalizer like every other name: build 70009 was seen to
    -- hand back the surname where UnitFullName used to put the realm, and the
    -- old code stored "Nye" as this character's realm.
    local first, surname = ns.NameFromUnit("player")
    local own = ns.OwnCharacters()
    local entry = own[guid] or {}

    entry.first = first or entry.first
    entry.surname = surname or entry.surname
    entry.realm = ns.Plain(GetRealmName())
    entry.level = ns.Plain(UnitLevel("player"), entry.level)
    entry.lastLogin = ns.Now()
    own[guid] = entry

    -- When this character began this diary: the first login it was seen at,
    -- and where, and at what level.
    local meta = ns.db.meta
    local begun = meta.begun[guid]
    if type(begun) ~= "table" then
        local where = ns.Where()
        begun = { time = entry.lastLogin, zone = where.zone, level = entry.level }
        meta.begun[guid] = begun
        -- At login the client may not know the zone yet (in the client,
        -- 9 Oct 2026, it said ""): FillBegunZone takes it once it does.
        if begun.zone == "" then begun.zone = nil end
        if not begun.zone then begunPending = guid end
    end

    meta.lastLogin = entry.lastLogin
    ns.ownGUID = guid
end
