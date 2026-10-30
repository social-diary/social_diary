-- Right-click entry points (DIA-2) and their GUID resolution (DIA-2a).
--
-- Session 1's awkward finding: neither MENU_UNIT_PLAYER nor MENU_UNIT_FRIEND
-- supplies a GUID. The target frame gives unit="target" and nothing else; a
-- chat name gives neither unit nor guid, only a playerLocation. So every menu
-- entry has to resolve identity itself, and it has to do it while the menu is
-- open -- the unit token may be gone by the time the button is clicked, so the
-- callback closes over a resolved GUID rather than over the context.
--
-- Whether C_PlayerInfo.GetGUIDFromPlayerLocation works in this build is not
-- yet known, which is why Resolve reports the path it took under /sd debug and
-- says so out loud when every path fails.

local addonName, ns = ...

-- Every surface the PRD asks for that exists in this build. Battle.net menus
-- are left out: PRV-5 keeps real IDs out of the diary, and a BNet friend has
-- no character GUID until they are on one.
local MENU_TAGS = {
    "MENU_UNIT_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER",
    "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_RAID",
    "MENU_UNIT_FRIEND",
    "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS",
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
}

--------------------------------------------------------------------------
-- Resolution (DIA-2a)
--------------------------------------------------------------------------

local INCLUDE_SELF = { includeSelf = true }

-- Returns guid, unit, path.
local function Resolve(contextData)
    if not contextData then return nil end

    local unit = ns.Plain(contextData.unit)
    local guid = ns.SafeGUID(contextData.guid)
    if guid then return guid, unit, "guid" end

    -- includeSelf: the user's own GUID resolves, so OnMenu can see it is
    -- them and offer nothing, rather than falling through to "failed".
    guid = ns.PlayerGUIDFromUnit(unit, INCLUDE_SELF)
    if guid then return guid, unit, "unit" end

    if contextData.playerLocation and C_PlayerInfo and C_PlayerInfo.GetGUIDFromPlayerLocation then
        local ok, located = pcall(C_PlayerInfo.GetGUIDFromPlayerLocation, contextData.playerLocation)
        if ok then
            guid = ns.SafeGUID(located)
            if guid then return guid, nil, "playerLocation" end
        end
    end

    -- The last resort: a name the addon has already seen. Ambiguous names
    -- resolve to nothing rather than to the wrong person.
    guid = ns.Characters.FindByName(contextData.name, contextData.surname)
    if guid then return guid, nil, "name" end

    return nil, nil, "failed"
end

-- The probe that answers the open question: under /sd debug, every menu open
-- and which path won, or what the context held when none did.
local function Report(tag, contextData, path)
    if path ~= "failed" then
        ns.Debug("%s resolved via %s", tag, path)
        return
    end

    local keys = {}
    for key in pairs(contextData or {}) do keys[#keys + 1] = key end
    table.sort(keys)

    ns.Debug("%s: could not identify that character (context: %s)",
        tag, #keys > 0 and table.concat(keys, ", ") or "empty")
end

-- Whether the menu is on somebody the client keeps secret (instanced maps).
local function Secret(contextData)
    if ns.IsSecret(contextData.name) then return true end
    local unit = ns.Plain(contextData.unit)
    return unit ~= nil and ns.Plain(UnitExists(unit)) and ns.IsSecret(UnitGUID(unit)) or false
end

--------------------------------------------------------------------------
-- The menu entry
--------------------------------------------------------------------------

-- The menu is only touched when there is a player to offer. On a secret
-- unit the menu's title is secret, and so is its size; Blizzard may do
-- arithmetic on that size, but not once anything this addon added to the
-- menu has tainted the layout (FrameUtil's GetUnscaledFrameRect errors on
-- every right-click of the target frame in a dungeon). So a secret or
-- unidentified unit, NPCs included, gets the menu exactly as Blizzard
-- built it.
local function OnMenu(tag, _, rootDescription, contextData)
    if not contextData then return end
    -- Never offer to remember yourself.
    if ns.Plain(contextData.isSelf) then return end

    if Secret(contextData) then
        ns.Debug("%s on a secret unit, left alone", tag)
        return
    end

    local guid, unit, path = Resolve(contextData)
    Report(tag, contextData, path)
    if not guid or guid == ns.ownGUID then return end

    rootDescription:CreateDivider()

    if ns.Diary.IsDiary(guid) then
        rootDescription:CreateButton("Social Diary: open entry", function()
            ns.UI.ShowEntry(guid)
        end)
    else
        rootDescription:CreateButton("Social Diary: remember this", function()
            -- The token only while it is still them: the party slots or the
            -- target can move while the menu is open.
            local still = unit and ns.Plain(UnitGUID(unit)) == guid and unit or nil
            ns.UI.Remember(guid, { unit = still, source = "menu:" .. tag })
        end)
    end
end

if Menu and Menu.ModifyMenu then
    for i = 1, #MENU_TAGS do
        local tag = MENU_TAGS[i]
        Menu.ModifyMenu(tag, function(owner, rootDescription, contextData)
            OnMenu(tag, owner, rootDescription, contextData)
        end)
    end
end

ns._test.ResolveMenuContext = Resolve
