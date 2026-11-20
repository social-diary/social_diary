-- Auto-add (the Recording setting "Auto-Add Players", `autoAdd`, off by default).
--
-- DIA-1 says a character enters the diary because the user said so. This is
-- the one exception, and the user says so once, by switching it on: from
-- then on the player's own rules add people without asking
-- (.claude/features/auto-add-rules-plan.md, 19 Nov 2026).
--
-- A rule (settings.autoAddRules[i], per character, at most MAX_RULES):
--
--   { id, on, trigger, amount, option, filters, tag, preset }
--
--   id       per character, never reused (settings.autoAddNextId)
--   trigger  a key registered with RegisterTrigger: what has to happen
--   amount   how much of it: minutes for grouped, a count for the rest
--   option   the trigger's one extra choice, if its spec has one: a value
--            of its choices ("either"), or for a `multi` option a set of
--            them (grouped's places, { world = true, dungeon = true })
--   filters  each optional, all of them must pass (absent = no filter):
--              guild   = true                    same guild as me
--              faction = "mine" | "other"
--              level   = { min =, max = } | { within = n }   (of my level)
--              class   = { WARRIOR = true, ... }
--            Unknown data fails a filter: a stranger whose guild, level or
--            faction was never read is not let through (decision 8).
--   tag      the tag the person gets, or nil
--   preset   the preset it came from, or nil (only for the UI)
--
-- The list is never a default: ApplyDefaults would bring a deleted preset
-- back. It is seeded once, when it is nil: an existing character by
-- STEPS.character[3] (Core/DB.lua) from the old switch, a new one by Seed.
--
-- Triggers are registered (RegisterTrigger), the way row kinds are: the
-- core's two, grouped and seen, here; the rest by their own features
-- (Features/Trade, Chat, WorldPvP, Duels). A counting trigger counts what
-- the buffers still hold (interactions 7 days, sightings 30; decision 4).
--
-- A person is weighed only when something new happens with them: a group
-- tick (CheckGroup, grouped rules only), a new row (Wake, from
-- Interactions.Add and the features that update a row in place), a new
-- sighting (Sighted). The first rule in list order that they pass adds
-- them and gives its tag (decision 6). Nothing is backfilled without
-- asking: the people who already pass are offered on a paper sheet
-- (Waiting, AddWaiting; the sheet is UI/Windows/AutoAdd.lua's).
--
-- Someone the user takes out of the diary is never added back
-- (meta.declined, written by Diary.Remove). Nor is anyone on the game's
-- ignore list.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local AutoAdd = {}
ns.AutoAdd = AutoAdd

AutoAdd.MAX_RULES = 10

local function On()
    return ns.db and ns.db.settings.autoAdd == true
end

AutoAdd.On = On

-- PRV-3: "Delete all data" forgets the list too. Forgetting one person keeps
-- their bare GUID here, though: "delete everything about them" is not "add
-- them back the next time they pass".
ns.RegisterStore("declined", function(guid)
    if guid == nil then wipe(ns.db.meta.declined) end
end)

function AutoAdd.Decline(guid)
    guid = ns.SafeGUID(guid)
    if guid then ns.db.meta.declined[guid] = true end
end

function AutoAdd.Declined(guid)
    guid = ns.SafeGUID(guid)
    return guid ~= nil and ns.db.meta.declined[guid] == true
end

local function Ignored(guid)
    local FriendList = C_FriendList
    if not (FriendList and FriendList.IsIgnoredByGuid) then return false end
    return ns.Plain(FriendList.IsIgnoredByGuid(guid)) == true
end

local function Eligible(guid)
    guid = ns.SafeGUID(guid)
    if not guid or guid == ns.ownGUID then return nil end
    if ns.Diary.IsDiary(guid) or AutoAdd.Declined(guid) or Ignored(guid) then return nil end
    return guid
end

AutoAdd.Eligible = Eligible

--------------------------------------------------------------------------
-- The trigger registry
--------------------------------------------------------------------------
--
-- AutoAdd.RegisterTrigger(key, spec), spec:
--
--   order     position in the form's choice
--   label     the form's word for it
--   amount    { min, max, default, steps = { ... }, unit = word }
--   option    nil, or { key, label, choices = { { value, label }, ... },
--             default, multi } -- `multi`: the rule's option is a set of the
--             values, at least one of them; `default` is then a set too.
--             `label` heads its row on the rule sheet (UI/Settings/Rules.lua),
--             `note` is small print under its choices there
--   sides     nil, or the one side it can ever count ("mine", "other"): a
--             faction filter of the other side makes a rule that adds
--             nobody, which the rule sheet says (seen counts friendly
--             sightings only; open-world PvP is the other faction's)
--   kinds     the row kinds (or "sighting") that wake it (Wake)
--   count     function(guid, rule, ctx) -> how many qualifying events are
--             stored; ctx is { now, place } (CheckGroup's), or nil
--   backfill  whether the backfill sheet may ask about it (grouped: false)
--   describe  function(rule) -> "Whispered 3 times, either way"
--   source    the entry's addedContext.source ("auto_whisper")

local triggers, ordered, byKind = {}, {}, {}

function AutoAdd.RegisterTrigger(key, spec)
    spec.key = key
    if not triggers[key] then ordered[#ordered + 1] = spec end
    for i, s in ipairs(ordered) do
        if s.key == key then ordered[i] = spec end
    end
    triggers[key] = spec
    table.sort(ordered, function(a, b)
        if (a.order or 0) ~= (b.order or 0) then return (a.order or 0) < (b.order or 0) end
        return a.key < b.key
    end)
    byKind = {}
    for _, s in ipairs(ordered) do
        for _, kind in ipairs(s.kinds or {}) do byKind[kind] = byKind[kind] or {}; byKind[kind][s.key] = true end
    end
    return spec
end

function AutoAdd.Trigger(key) return triggers[key] end

-- Every trigger, in the form's order.
function AutoAdd.Triggers() return ordered end

local function CopyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = CopyValue(v) end
    return copy
end

--------------------------------------------------------------------------
-- The rules
--------------------------------------------------------------------------

local PRESET_NAMES = {
    group = L["Group mates"],
    dungeon = L["Dungeon and raid companions"],
    seen = L["Familiar faces"],
}

local PRESET_ORDER = { "group", "dungeon", "seen" }

-- A tag as Diary.Edit.AddTag would store it.
local function CleanTag(tag)
    return ns.Diary.CleanTag(tag)
end

-- The three presets, in the list's order, without ids, all off unless `on`
-- names them ({ group = true, seen = true }). The tags are in the login
-- language (decision 7). Shared by STEPS.character[3] and Seed.
function AutoAdd.Presets(on)
    on = on or {}
    local all = { world = true, dungeon = true, raid = true }
    return {
        { on = on.group == true, trigger = "grouped", amount = 5, option = CopyValue(all),
            tag = CleanTag(L["group##autotag"]), preset = "group" },
        { on = on.dungeon == true, trigger = "grouped", amount = 5, option = { dungeon = true, raid = true },
            tag = CleanTag(L["dungeon##autotag"]), preset = "dungeon" },
        { on = on.seen == true, trigger = "seen", amount = 3,
            tag = CleanTag(L["seen##autotag"]), preset = "seen" },
    }
end

-- One preset, by key, as Presets writes it (switched on): for "+ New rule".
function AutoAdd.Preset(key)
    for i, k in ipairs(PRESET_ORDER) do
        if k == key then
            local rule = AutoAdd.Presets()[i]
            rule.on = true
            return rule
        end
    end
    return nil
end

function AutoAdd.PresetKeys() return PRESET_ORDER end

function AutoAdd.PresetName(key) return PRESET_NAMES[key] end

-- The next id in `settings` (a raw table or ns.db.settings).
local function NextId(settings)
    local id = tonumber(settings.autoAddNextId) or 1
    -- (a hand-edited file: never hand out an id in use)
    for _, rule in ipairs(type(settings.autoAddRules) == "table" and settings.autoAddRules or {}) do
        if type(rule) == "table" and type(rule.id) == "number" and rule.id >= id then id = rule.id + 1 end
    end
    settings.autoAddNextId = id + 1
    return id
end

-- Seeds `settings` (a character's, raw or ns.db's) with the presets, once:
-- only when it has no list yet. `on` as Presets'. Returns whether it seeded.
function AutoAdd.SeedInto(settings, on)
    if type(settings) ~= "table" or settings.autoAddRules ~= nil then return false end
    local rules = AutoAdd.Presets(on)
    settings.autoAddRules = {}
    local list = settings.autoAddRules
    for i, rule in ipairs(rules) do
        rule.id = NextId(settings)
        list[i] = rule
    end
    return true
end

-- At login, after the defaults (ns.InitDB): a new character's presets, all
-- off. An existing character was seeded by its schema step.
function AutoAdd.Seed()
    return AutoAdd.SeedInto(ns.db.settings, nil)
end

-- The character's list, in order (seeded if it never was).
function AutoAdd.Rules()
    local settings = ns.db.settings
    if type(settings.autoAddRules) ~= "table" then
        settings.autoAddRules = nil
        AutoAdd.SeedInto(settings, nil)
    end
    return settings.autoAddRules
end

function AutoAdd.RuleById(id)
    for _, rule in ipairs(AutoAdd.Rules()) do
        if rule.id == id then return rule end
    end
    return nil
end

-- A new rule at the foot of the list, with an id of its own: the trigger's
-- defaults, with `fields` laid over them (a preset's, a duplicate's). Starts
-- off unless `fields` says otherwise. nil at MAX_RULES or for a trigger
-- nobody registered.
function AutoAdd.NewRule(trigger, fields)
    local rules = AutoAdd.Rules()
    local spec = triggers[trigger]
    if not spec or #rules >= AutoAdd.MAX_RULES then return nil end
    local rule = {
        on = false,
        trigger = trigger,
        amount = spec.amount and spec.amount.default or 1,
        option = spec.option and CopyValue(spec.option.default) or nil,
    }
    for k, v in pairs(fields or {}) do rule[k] = CopyValue(v) end
    rule.trigger = trigger
    rule.id = NextId(ns.db.settings)
    rules[#rules + 1] = rule
    return rule
end

--------------------------------------------------------------------------
-- Snapshots and widening (for the rule sheet's backfill question)
--------------------------------------------------------------------------

-- A deep copy of the list (or of one rule), as the sheet takes it when it
-- opens.
function AutoAdd.Snapshot(rules)
    return CopyValue(rules or AutoAdd.Rules())
end

-- Whether a filter of `after` lets through someone `before`'s did not.
local function FilterWidened(key, b, a)
    if a == nil then return true end                  -- removed
    if key == "guild" then return false end
    if key == "faction" then return a ~= b end        -- a different side
    if key == "level" then
        if type(a) ~= "table" or type(b) ~= "table" then return true end
        if (a.within ~= nil) ~= (b.within ~= nil) then return true end
        if a.within ~= nil then return (a.within or 0) > (b.within or 0) end
        return (a.min or 0) < (b.min or 0) or (a.max or math.huge) > (b.max or math.huge)
    end
    if key == "class" then
        if type(a) ~= "table" or type(b) ~= "table" then return true end
        for class in pairs(a) do
            if a[class] and not b[class] then return true end
        end
        return false
    end
    return a ~= b
end

-- Whether `after` would add someone `before` would not: a new rule, another
-- trigger, a lower amount, a place added, another or a broader option
-- ("either"), a filter removed or loosened. Switching on is not widening
-- (AskAbout weighs that); a filter added or tightened, a tag, are not.
function AutoAdd.Widened(before, after)
    if not after then return false end
    if not before then return true end
    if before.trigger ~= after.trigger then return true end
    if (tonumber(after.amount) or 0) < (tonumber(before.amount) or 0) then return true end

    local b, a = before.option, after.option
    if type(a) == "table" then
        for value, set in pairs(a) do
            if set and not (type(b) == "table" and b[value]) then return true end
        end
    elseif a ~= b and b ~= "either" then
        return true
    end

    local bf, af = before.filters or {}, after.filters or {}
    for key, value in pairs(bf) do
        if FilterWidened(key, value, af[key]) then return true end
    end
    return false
end

-- The rules the backfill question is for, after a visit to the sheet that
-- began with `snapshot`: on, and new, switched on, or widened since. A rule
-- switched on and off again asks nothing.
function AutoAdd.AskAbout(snapshot, rules)
    local before = {}
    for _, rule in ipairs(snapshot or {}) do before[rule.id] = rule end
    local out = {}
    for _, rule in ipairs(rules or AutoAdd.Rules()) do
        local spec = triggers[rule.trigger]
        local was = before[rule.id]
        if rule.on and spec and spec.backfill
            and (not was or not was.on or AutoAdd.Widened(was, rule)) then
            out[#out + 1] = rule
        end
    end
    return out
end

--------------------------------------------------------------------------
-- Checking
--------------------------------------------------------------------------

local function MyFaction()
    return UnitFactionGroup and ns.Plain((UnitFactionGroup("player"))) or nil
end

local function MyLevel()
    local level = ns.Plain(UnitLevel("player"))
    if type(level) ~= "number" or level <= 0 then return nil end
    return level
end

local function MyGuild()
    if not GetGuildInfo then return nil end
    local guild = ns.Plain((GetGuildInfo("player")))
    if type(guild) ~= "string" or guild == "" then return nil end
    return guild
end

-- Same guild as me: their record says my guild's name, or a group scan
-- said so (UnitIsInMyGuild, a group_join row's context.guild).
local function SameGuild(guid, record)
    local mine = MyGuild()
    if not mine then return false end
    if record and record.guild == mine then return true end
    for _, row in ipairs(ns.Interactions.For(guid) or {}) do
        if row.context and row.context.guild == true then return true end
    end
    return false
end

local FILTERS = {
    guild = function(guid, record, value)
        if not value then return true end
        return SameGuild(guid, record)
    end,
    faction = function(_, record, value)
        local theirs, mine = record and record.faction, MyFaction()
        if not theirs or not mine then return false end
        if value == "mine" then return theirs == mine end
        if value == "other" then return theirs ~= mine end
        return false
    end,
    level = function(_, record, value)
        local level = record and record.level
        if type(level) ~= "number" or level <= 0 or type(value) ~= "table" then return false end
        if value.within ~= nil then
            local mine = MyLevel()
            if not mine then return false end
            return math.abs(level - mine) <= (tonumber(value.within) or 0)
        end
        return level >= (tonumber(value.min) or 1) and level <= (tonumber(value.max) or math.huge)
    end,
    class = function(_, record, value)
        local class = record and record.class
        return class ~= nil and type(value) == "table" and value[class] == true
    end,
}

AutoAdd.FILTER_KEYS = { "guild", "faction", "level", "class" }

-- Whether `guid` passes `rule`: the trigger's count reaches the amount and
-- every filter passes. On or off is Match's. `ctx` as a trigger's count.
function AutoAdd.Passes(guid, rule, ctx)
    local spec = type(rule) == "table" and triggers[rule.trigger]
    if not spec or not spec.count then return false end
    guid = ns.SafeGUID(guid)
    if not guid then return false end
    local amount = tonumber(rule.amount) or (spec.amount and spec.amount.default) or 1
    if (spec.count(guid, rule, ctx) or 0) < amount then return false end

    if type(rule.filters) == "table" then
        local record = ns.Characters.Get(guid)
        for key, value in pairs(rule.filters) do
            local test = FILTERS[key]
            if not test or not test(guid, record, value) then return false end
        end
    end
    return true
end

-- The first rule that is on, in list order, whose trigger `test` lets in
-- and that `guid` passes.
local function First(guid, test, ctx)
    for _, rule in ipairs(AutoAdd.Rules()) do
        local spec = rule.on and triggers[rule.trigger]
        if spec and test(spec) and AutoAdd.Passes(guid, rule, ctx) then return rule end
    end
    return nil
end

-- The first rule that is on, in list order, that `guid` passes. `kinds` is
-- a row kind ("trade"), a set of them, or nil for every trigger: only the
-- triggers those kinds wake are weighed.
function AutoAdd.Match(guid, kinds)
    if kinds == nil then return First(guid, function() return true end) end
    if type(kinds) == "string" then kinds = { [kinds] = true } end
    return First(guid, function(spec)
        for kind in pairs(kinds) do
            if byKind[kind] and byKind[kind][spec.key] then return true end
        end
        return false
    end)
end

--------------------------------------------------------------------------
-- Adding
--------------------------------------------------------------------------

-- What a rule says, for the chat line and the settings' summary.
function AutoAdd.Describe(rule)
    local spec = rule and triggers[rule.trigger]
    if not (spec and spec.describe) then return "" end
    return spec.describe(rule)
end

-- Adds `guid` by `rule`: its source, its id (addedContext.rule, for Count)
-- and its tag. `quiet` leaves the chat line out (the backfill says one for
-- the lot). Returns the entry, or nil when nobody was added.
function AutoAdd.Add(guid, rule, quiet)
    guid = Eligible(guid)
    local spec = guid and rule and triggers[rule.trigger]
    if not spec then return nil end
    local entry, added = ns.Diary.Add(guid, {
        source = spec.source,
        rule = rule.id,
        tags = rule.tag and { rule.tag } or nil,
        quiet = true,
    })
    if not added then return nil end
    if not quiet then
        ns.Print(Fmt(L["added |cffffffff%1$s|r to the diary automatically: %2$s."],
            ns.Characters.FullName(entry.guid) or entry.guid, AutoAdd.Describe(rule)))
    end
    return entry
end

-- How many entries `ruleId` added for this character (addedBy): the "N
-- added" by a rule.
function AutoAdd.Count(ruleId)
    local n = 0
    if ruleId == nil then return 0 end
    for _, entry in ns.Diary.Each() do
        local c = entry.addedContext
        if c and c.rule == ruleId and entry.addedBy == ns.ownGUID then n = n + 1 end
    end
    return n
end

-- Something new happened with `guid`: a row of `kind` was written or
-- updated (Interactions.Add, Duels.Added, WorldPvP.Resolve), or a sighting
-- ("sighting"). Only the triggers `kind` wakes are weighed, only with the
-- master switch on, only for someone not in the diary. Returns the entry
-- added, or nil.
function AutoAdd.Wake(guid, kind)
    if not On() or not byKind[kind] then return nil end
    guid = Eligible(guid)
    if not guid then return nil end
    local rule = AutoAdd.Match(guid, kind)
    return rule and AutoAdd.Add(guid, rule) or nil
end

-- After the sighting store wrote a new row for them (Capture/Sightings.lua).
function AutoAdd.Sighted(guid)
    return AutoAdd.Wake(guid, "sighting")
end

--------------------------------------------------------------------------
-- Grouped (core: the roster is core)
--------------------------------------------------------------------------

-- When their latest stretch in the group began: the newest group_join row,
-- if no group_leave came after it.
local function JoinedAt(guid)
    local rows = ns.Interactions.For(guid)
    if not rows then return nil end
    for i = #rows, 1, -1 do
        local kind = rows[i].type
        if kind == "group_leave" then return nil end
        if kind == "group_join" then return rows[i].time end
    end
    return nil
end

-- Where the user is, as grouped's places say it: "world", "dungeon",
-- "raid", or nil (a battleground, an arena, a scenario: never).
local PLACES = { none = "world", party = "dungeon", raid = "raid" }

local function PlaceNow()
    if ns.InBattleground() then return nil end
    return PLACES[ns.Where().instanceType or "none"]
end

AutoAdd.PlaceNow = PlaceNow

AutoAdd.RegisterTrigger("grouped", {
    order = 10,
    label = L["Grouped with you"],
    amount = { min = 1, max = 60, default = 5, steps = { 1, 2, 3, 4, 5, 10, 15, 20, 30, 45, 60 },
        unit = L["minutes in a row##autounit"] },
    option = { key = "places", multi = true, label = L["Where##autooption"], note = L["Battlegrounds never count."],
        choices = { { "world", L["Open world##autoplace"] }, { "dungeon", L["Dungeons##autoplace"] },
            { "raid", L["Raids##autoplace"] } },
        default = { world = true, dungeon = true, raid = true } },
    kinds = {},
    backfill = false,
    source = "auto_group",
    -- Whole minutes in the group without a break, here and now; 0 where the
    -- rule's places don't take in where the user is.
    count = function(guid, rule, ctx)
        local place
        if ctx and ctx.place ~= nil then place = ctx.place else place = PlaceNow() end
        local places = type(rule.option) == "table" and rule.option or nil
        if not place or not (places and places[place]) then return 0 end
        local joined = JoinedAt(guid)
        if not joined then return 0 end
        return math.floor(((ctx and ctx.now or ns.Now()) - joined) / 60)
    end,
    describe = function(rule)
        local o = type(rule.option) == "table" and rule.option or {}
        local key = (o.world and "w" or "") .. (o.dungeon and "d" or "") .. (o.raid and "r" or "")
        local n = tonumber(rule.amount) or 0
        if key == "wdr" then
            return ns.Plural(n, L["grouped with you for %d minute|grouped with you for %d minutes##plural"])
        end
        local where = ({
            w = L["in the open world##autoplace"],
            d = L["in dungeons##autoplace"],
            r = L["in raids##autoplace"],
            wd = L["in the open world and dungeons##autoplace"],
            wr = L["in the open world and raids##autoplace"],
            dr = L["in dungeons and raids##autoplace"],
        })[key] or L["nowhere##autoplace"]
        return ns.Plural(n, L["grouped with you for %1$d minute %2$s|grouped with you for %1$d minutes %2$s##plural"], n, where)
    end,
})

-- Every member of the group as last scanned, against the grouped rules.
-- Run on the together tick (Capture/Together.lua); returns how many it
-- added.
function AutoAdd.CheckGroup(now)
    if not On() or ns.InBattleground() then return 0 end
    local ctx = { now = now or ns.Now(), place = PlaceNow() }
    if not ctx.place then return 0 end

    local function Grouped(spec) return spec.key == "grouped" end
    local n = 0
    for guid in pairs(ns.Roster.Members()) do
        guid = Eligible(guid)
        local rule = guid and First(guid, Grouped, ctx)
        if rule and AutoAdd.Add(guid, rule) then n = n + 1 end
    end
    return n
end

--------------------------------------------------------------------------
-- Seen (core: sightings are core)
--------------------------------------------------------------------------

-- Rows of the sighting store (one per zone-hour, the count "Seen N times"
-- says) within its window, not counting hostile ones: a returning face, not
-- an enemy passing through.
local function TimesSeen(guid)
    local n = 0
    for _, row in ipairs(ns.Sightings.For(guid)) do
        if not row.hostile then n = n + 1 end
    end
    return n
end

AutoAdd.RegisterTrigger("seen", {
    order = 20,
    label = L["Seen near you"],
    amount = { min = 2, max = 20, default = 3, steps = { 2, 3, 4, 5, 6, 8, 10, 15, 20 },
        unit = L["times##autounit"] },
    kinds = { "sighting" },
    sides = "mine",
    backfill = true,
    source = "auto_seen",
    count = function(guid) return TimesSeen(guid) end,
    describe = function(rule)
        local n = tonumber(rule.amount) or 0
        return ns.Plural(n, L["seen %d time|seen %d times##plural"])
    end,
})

--------------------------------------------------------------------------
-- Backfill, asked when the switch goes on or the rule sheet is put away
--------------------------------------------------------------------------

local function ByName(a, b)
    local x, y = ns.Characters.FullName(a.guid) or a.guid, ns.Characters.FullName(b.guid) or b.guid
    if x ~= y then return x < y end
    return a.guid < b.guid
end

-- Everyone already passing one of `rules` (nil: every rule that is on) who
-- would be added the next time something happened: { { guid, rule }, ... }
-- by name, each person once, with the first of those rules in list order.
-- Only the rules that are on and can be backfilled (grouped never is).
-- Candidates are the people the buffers hold.
function AutoAdd.Waiting(rules)
    local asking = {}
    if rules then
        for _, rule in ipairs(rules) do asking[rule] = true end
    end
    local list = {}
    for _, rule in ipairs(AutoAdd.Rules()) do
        local spec = triggers[rule.trigger]
        if rule.on and spec and spec.backfill and (not rules or asking[rule]) then
            list[#list + 1] = rule
        end
    end
    -- (rules passed that are no longer in the list: weighed after, in
    -- their own order)
    for _, rule in ipairs(rules or {}) do
        local spec = triggers[rule.trigger]
        local listed = false
        for _, r in ipairs(list) do if r == rule then listed = true end end
        if not listed and rule.on and spec and spec.backfill then
            list[#list + 1] = rule
        end
    end

    local out = {}
    if #list == 0 then return out end
    local seen = {}
    local function Consider(guid)
        if seen[guid] then return end
        seen[guid] = true
        guid = Eligible(guid)
        if not guid then return end
        for _, rule in ipairs(list) do
            if AutoAdd.Passes(guid, rule) then
                out[#out + 1] = { guid = guid, rule = rule }
                return
            end
        end
    end
    for guid in pairs(ns.db.sightings) do Consider(guid) end
    for guid in pairs(ns.db.interactions) do Consider(guid) end
    table.sort(out, ByName)
    return out
end

-- Adds them all, quietly, with one line in chat for the lot, each by the
-- rule it came with. Still checks each: the sheet may have been open while
-- one of them was added or removed. Returns how many were added.
function AutoAdd.AddWaiting(list)
    local n = 0
    for _, item in ipairs(list or AutoAdd.Waiting()) do
        local guid = Eligible(item.guid)
        if guid and AutoAdd.Passes(guid, item.rule) and AutoAdd.Add(guid, item.rule, true) then
            n = n + 1
        end
    end
    if n > 0 then
        ns.Print(ns.Plural(n, L["added %d person to the diary by your rules.|added %d people to the diary by your rules.##plural"]))
    end
    return n
end
