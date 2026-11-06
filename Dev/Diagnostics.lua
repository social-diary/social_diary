-- Development tooling: what the client and the database look like from
-- inside. /sd env reports the client's real interface version and probes for
-- the APIs the PRD's feasibility column depends on, so the M0 findings can be
-- checked against each build; the rest look at the store and the name APIs.
--
-- Listed in /sd help only while debug is on (Core/Slash.lua). Not part of a
-- release: the TOC's Dev/ block goes.

local addonName, ns = ...

-- Each entry is { api path, requirement it backs }.
local PROBES = {
    ["Secret values (NFR-4, INT-5)"] = {
        { "issecretvalue" },
        { "scrubsecretvalues" },
        { "C_Secrets" },
    },
    ["Identity and roster (B1-B4, DIA-5)"] = {
        { "UnitGUID" },
        { "UnitFullName" },
        { "C_PartyInfo.IsGUIDInGroup" },
        { "C_PlayerInfo.GUIDIsPlayer" },
    },
    ["Sightings (SIG-1, SIG-3)"] = {
        { "C_NamePlate.GetNamePlates" },
        { "C_Map.GetBestMapForUnit" },
        { "C_Map.GetPlayerMapPosition" },
        { "C_Map.GetMapArtLayers" },
        { "C_Map.GetMapArtLayerTextures" },
        { "C_MapExplorationInfo.GetExploredMapTextures" },
        { "C_Map.GetMapInfo" },
    },
    ["Group context (C1, C4, INS-3)"] = {
        { "GetInstanceInfo" },
        { "C_LFGInfo.IsInLFGFollowerDungeon" },
        { "C_PartyInfo.IsDelveInProgress" },
        { "C_ChallengeMode.GetChallengeCompletionInfo" },
    },
    ["Outcomes (E1, E3, E5)"] = {
        { "C_DamageMeter.GetAvailableCombatSessions" },
        { "C_EncounterTimeline" },
    },
    ["Backfill (INT-6)"] = {
        { "C_RecentAllies" },
    },
    ["UI surfaces (DIA-2, REU-4, JNL-4, PRV-2)"] = {
        { "Menu.ModifyMenu" },
        { "TooltipDataProcessor.AddTooltipPostCall" },
        { "AddonCompartmentFrame" },
        { "Settings.RegisterAddOnCategory" },
        { "Settings.RegisterCanvasLayoutCategory" },
        { "Settings.OpenToCategory" },
        { "MenuUtil.CreateContextMenu" },
        { "C_Timer.NewTicker" },
        { "InCombatLockdown" },
    },
    ["Storage (DAT-2, DAT-5)"] = {
        { "C_AddOns.LoadAddOn" },
        { "C_EncodingUtil.SerializeCBOR" },
    },
}

local PROBE_ORDER = {
    "Secret values (NFR-4, INT-5)",
    "Identity and roster (B1-B4, DIA-5)",
    "Sightings (SIG-1, SIG-3)",
    "Group context (C1, C4, INS-3)",
    "Outcomes (E1, E3, E5)",
    "Backfill (INT-6)",
    "UI surfaces (DIA-2, REU-4, JNL-4, PRV-2)",
    "Storage (DAT-2, DAT-5)",
}

local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = rawget(value, part)
        if value == nil then return nil end
    end
    return value
end

local function ReportEnvironment()
    local version, build, date, toc = GetBuildInfo()

    ns.Print("client |cffffffff%s|r build |cffffffff%s|r (%s)", version, build, date)
    ns.Print("interface version: |cffffffff%s|r  -- this is the number the TOC needs", tostring(toc))
    ns.Print("locale %s, realm %s", GetLocale(), GetRealmName())

    local present, missing = 0, 0
    for _, group in ipairs(PROBE_ORDER) do
        ns.Print("|cffffd100%s|r", group)
        for _, probe in ipairs(PROBES[group]) do
            local path = probe[1]
            if Resolve(path) ~= nil then
                present = present + 1
                DEFAULT_CHAT_FRAME:AddMessage("   |cff40c040yes|r  " .. path)
            else
                missing = missing + 1
                DEFAULT_CHAT_FRAME:AddMessage("   |cffc04040no |r  " .. path)
            end
        end
    end

    ns.Print("%d of %d probed APIs present.", present, present + missing)
end

local function ReportDB()
    if not ns.db then
        ns.Print("database not initialised.")
        return
    end

    local Count = ns.CountKeys

    ns.Print("schema v%d, saved data %s this load", ns.db.schema,
        ns.dbRestored and "|cff40c040restored|r" or "|cffc04040not restored|r")
    ns.Print("characters %d, diary %d, sessions %d, instances %d",
        Count(ns.db.characters), ns.Diary.Count(),
        Count(ns.db.sessions), Count(ns.db.instances))
    local rows, characters = ns.Interactions.Totals()
    ns.Print("interactions %d row(s) across %d character(s), kept %d days",
        rows, characters, ns.BufferDays())
    local sightings, seen = ns.Sightings.Count()
    ns.Print("sightings %d row(s) across %d character(s), own characters %d",
        sightings, seen, Count(ns.OwnCharacters()))
end

-- Renders a value for the eyes, never for logic. The secret test has to come
-- first: comparing a secret to nil is one of the operations that errors.
local function Show(value)
    if ns.IsSecret(value) then return "|cffc04040<secret>|r" end
    if value == nil then return "|cff808080nil|r" end
    if type(value) == "string" then return '"' .. value .. '"' end
    return tostring(value)
end

-- NAM-1's in-game check. Prints what each name API actually returns for a
-- unit next to what the normalizer made of it, so the disagreement documented
-- in Core/Identity.lua can be confirmed or corrected against this client.
local function ReportUnit(unit)
    if not UnitExists(unit) then
        ns.Print("|cffffd100%s|r  |cff808080-- nothing there|r", unit)
        return
    end

    local guid = ns.SafeGUID(UnitGUID(unit))
    local first, surname = ns.NameFromUnit(unit)

    ns.Print("|cffffd100%s|r  %s", unit, Show(guid))

    local a, b = UnitName(unit)
    DEFAULT_CHAT_FRAME:AddMessage(("   UnitName            %s, %s"):format(Show(a), Show(b)))

    a, b = UnitFullName(unit)
    DEFAULT_CHAT_FRAME:AddMessage(("   UnitFullName        %s, %s"):format(Show(a), Show(b)))

    if guid then
        local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
        DEFAULT_CHAT_FRAME:AddMessage(("   GetPlayerInfoByGUID %s, %s"):format(Show(name), Show(realm)))
    end

    DEFAULT_CHAT_FRAME:AddMessage(("   |cff40c040normalized|r         first %s  surname %s  -> %s")
        :format(Show(first), Show(surname), Show(ns.JoinName(first, surname))))
end

local function ReportWho()
    for _, unit in ipairs({ "player", "target", "mouseover", "focus" }) do
        ReportUnit(unit)
    end
end

-- Observes whatever is targeted or moused over and prints the stored record,
-- so the store can be exercised without waiting for a capture path to exist.
local function ReportObserve()
    local record = ns.Characters.ObserveUnit("target") or ns.Characters.ObserveUnit("mouseover")
    if not record then
        ns.Print("no player targeted or moused over.")
        return
    end

    ns.Print("stored |cffffffff%s|r  %s", ns.Characters.FullName(record.guid) or "?", record.guid)
    ns.Print("   level %s, %s %s, %s, names on record: %d",
        tostring(record.level), tostring(record.race), tostring(record.class),
        tostring(record.faction), #record.names)
end

local function ReportCharacters()
    local n = 0
    for guid in pairs(ns.db.characters) do
        n = n + 1
        if n <= 20 then
            DEFAULT_CHAT_FRAME:AddMessage(("   %-22s %s%s"):format(
                ns.Characters.FullName(guid) or "?", guid,
                ns.Diary.IsDiary(guid) and "  |cffffd100[diary]|r" or ""))
        end
    end
    ns.Print("%d character%s observed%s.", n, n == 1 and "" or "s",
        n > 20 and " (first 20 shown)" or "")
end

-- A reunion toast now, to look at the card without waiting for someone to
-- come by: for the name typed, else the target, else someone in the diary.
-- "group" first says they joined; nearby otherwise. Their cooldown is
-- cleared first; the switches in Settings still hold.
local function ShowToast(rest)
    local reason, name = "nearby", rest
    local first, others = rest:match("^(%S+)%s*(.*)$")
    if first == "group" or first == "nearby" then reason, name = first, others end

    local guid = ns.Slash.ResolveArgument(name, true)
    if not guid and name ~= "" then return end
    if guid and not ns.Diary.IsDiary(guid) then
        ns.Print("|cffffffff%s|r is not in the diary.", ns.Characters.FullName(guid) or guid)
        return
    end
    guid = guid or next(ns.db.diary)
    if not guid then
        ns.Print("the diary is empty: add someone first.")
        return
    end

    ns.db.meta.greeted[guid] = nil
    ns.UI.Reunion(guid, reason)
    if not ns.UI.ReunionShowing() then
        ns.Print("no toast: switched off in Settings, in combat, or (nearby) they are in your group.")
    end
end

-- SES-1 to SES-5's in-game check (out of Core/Slash.lua before launch: the
-- journal shows sessions). With a
-- name, only that character's sessions.
local function CommandSessions(text)
    local list
    if text and text ~= "" then
        local guid = ns.Slash.ResolveArgument(text, false)
        if not guid then return end
        list = ns.Sessions.For(guid)
    else
        list = ns.Sessions.All()
    end

    for i = 1, math.min(#list, 10) do
        local s = list[i]

        local names = {}
        for guid, p in pairs(s.participants) do
            local quests = p.quests and #p.quests or 0
            local rares = p.rares and #p.rares or 0
            names[#names + 1] = ("%s (%d min, lvl %s-%s%s%s%s)"):format(
                ns.Characters.FullName(guid) or guid,
                math.floor(p.seconds / 60),
                tostring(p.levelStart), tostring(p.levelEnd),
                quests > 0 and (", " .. quests .. " quests") or "",
                rares > 0 and (", " .. rares .. " rares") or "",
                p.near and (", near " .. #p.near .. "x: " .. table.concat(p.zones or {}, " > ")) or "")
        end

        DEFAULT_CHAT_FRAME:AddMessage(("   |cffffd100#%d|r %s  %d min  %s%s  |cff808080%s|r"):format(
            s.id, date("%d %b %H:%M", s.startedAt),
            math.floor(ns.Sessions.Duration(s) / 60),
            s.source, s.endedAt and "" or " |cff40c040open|r",
            table.concat(ns.Timeline.Unique(s.zones), " > ")))
        DEFAULT_CHAT_FRAME:AddMessage(("      %s; +%d others, %d death(s), %d highlight(s), you lvl %s-%s"):format(
            table.concat(names, ", "), s.others, ns.Sessions.DeathCount(s), #ns.Sessions.Highlights(s),
            tostring(s.myLevelStart), tostring(s.myLevelEnd)))
    end

    ns.Print("%d session%s%s.", #list, #list == 1 and "" or "s",
        #list > 10 and " (newest 10 shown)" or "")
end

local Register = ns.Slash.Register
local DEV = { dev = true }

Register("env", ReportEnvironment, "client build, interface version and API probe", DEV)
Register("who", ReportWho, "what every name API returns for the units around you (NAM-1)", DEV)
Register("observe", ReportObserve, "store your target or mouseover and show the record", DEV)
Register("chars", ReportCharacters, "list observed characters", DEV)
Register("db", ReportDB, "what the database currently holds", DEV)
Register("sessions", CommandSessions, "together sessions, or |cffffd100/sd sessions <name>|r", DEV)
Register("toast", ShowToast, "a reunion toast now: |cffffd100/sd toast [group] [name]|r, else your target", DEV)
