-- Settings: Memory (UI/Settings/Page.lua lists the sections; the controls
-- are UI/Settings/Kit.lua's): how long it keeps people, your data and where
-- it is, and deleting. Its size and data lines are read again with the page.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Number = Kit.Number

local function SizeText(bytes)
    local rows = ns.Interactions.Totals()

    return ("%d in the diary  ·  %d characters known  ·  %d sessions  ·  %d interactions"
        .. "  ·  %d sightings.  About %d KB on disk.")
        :format(ns.Diary.Count(), ns.Characters.Count(), ns.CountKeys(ns.db.sessions), rows,
            ns.CountKeys(ns.db.sightings), math.ceil(bytes / 1024))
end

-- Past ns.SIZE_WARNING: what it costs, and what to turn down. Empty below.
local function SizeWarning(bytes)
    if bytes <= ns.SIZE_WARNING then return "" end
    return ("Over %d MB: a lot to read at every login and /reload. Your diary keeps"
        .. " its history for good, so lowering the maximum chat lines (Recording) or"
        .. " deleting sightings is what brings it down.")
        :format(ns.SIZE_WARNING / (1024 * 1024))
end

-- DAT-1: which diary is in use, and so which file it is in, read from the
-- mode loaded this session (ns.diaryShared), not from the choice saved for
-- the next load.
local DIARY_FILE = {
    shared = "WTF\\Account\\<account>\\SavedVariables\\social_diary.lua",
    own = "WTF\\Account\\<account>\\<realm>\\<character>\\SavedVariables\\social_diary.lua",
}

-- PRV-1: said plainly, where the user will look for it.
local function DataText()
    if ns.diaryShared then
        return ("The shared diary is stored only on this computer, in %s. Nothing is sent to"
            .. " other players or to any server."):format(DIARY_FILE.shared)
    end
    return ("This character's diary is stored only on this computer, in %s. Nothing is sent"
        .. " to other players or to any server."):format(DIARY_FILE.own)
end

-- PRV-3: "delete everything" is the diary in use, so it says whose.
local function WipeText()
    if ns.diaryShared then
        return "Delete the shared diary?\n\nEvery diary entry, note, session and interaction"
            .. " your characters wrote in it goes, and every character's road in it. Your"
            .. " settings, and any diary a character keeps of its own, are kept. This cannot"
            .. " be undone."
    end
    return "Delete this character's diary?\n\nEvery diary entry, note, session and interaction"
        .. " it recorded goes, and its road. Your settings, and your other characters'"
        .. " diaries, are kept. This cannot be undone."
end

-- The switch's question, asked before the interface reloads: what the
-- character will see after it, and that nothing moves.
local function ShareText(on)
    if on then
        return "Share one diary between all your characters?\n\nThe interface reloads, and"
            .. " every character then uses the shared diary (empty if they never shared one)."
            .. " Nothing is copied or deleted: each character's own diary stays as it"
            .. " is, for if you switch back."
    end
    return "Give every character its own diary again?\n\nThe interface reloads, and this"
        .. " character then uses its own diary, empty if it never had one. Nothing is"
        .. " copied or deleted: the shared diary stays as it is, for if you share again."
end

-- Entry.Close announces SD_DIARY_CHANGED, which refreshes the journal and
-- this page with it.
local function AfterDelete()
    ns.UI.Entry.Close()
end

local function BuildMemory(pane, c)
    local page = SettingsUI.page

    c:Heading("Forgetting")
    page.bufferDays = Number(c, "Forget people outside the diary after", "days", "bufferDays", 1, 365,
        function()
            -- A shorter window applies now, to both.
            ns.Interactions.Prune()
            ns.Sightings.Rollup()
            ns.Characters.Prune()
        end)
    c:Hint("Imagine adding a stranger to your diary after you've met them many times already."
        .. " This setting pre-saves stranger's data for this so interaction data is available even though they were always strangers. Data for people in your diary are kept indefinitely.")

    c:Heading("Your data")
    -- DAT-1: the page's one account setting, so it says so. Ticked is the
    -- diary loaded this session: a click puts the box back and asks, and
    -- only Reload saves the choice, which a load must read (ns.ShareDiary).
    page.shareDiary = c:Checkbox("Share one diary between all my characters",
        function() return ns.diaryShared end,
        function()
            local on = not ns.diaryShared
            page.shareDiary:SetChecked(ns.diaryShared)
            ns.UI.Dialog.Confirm(ShareText(on), function()
                ns.ShareDiary(on)
                if ReloadUI then ReloadUI() end
            end, "Reload")
        end, nil, "Switching requires a reload.")
    page.controls[#page.controls + 1] = page.shareDiary

    -- Its text is the mode's; the mode stays until the next load.
    page.dataHint = c:Hint(DataText())

    page.size = Style.Text(pane, FONT.small)
    page.size:SetWidth(BOOK.RIGHT_W)
    c:Place(page.size, 28, 0, 8)  -- two lines, whatever the numbers

    local ACCENT = Style.ACCENT
    page.sizeWarning = Style.Text(pane, FONT.small)
    page.sizeWarning:SetWidth(BOOK.RIGHT_W)
    page.sizeWarning:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
    c:Place(page.sizeWarning, 28, 0, 8)  -- room kept, so nothing below moves

    c:Heading("Deleting")
    c:Hint(("One person: Remove on their page, or type |cff%s/sd forget <name>|r for anyone"
        .. " else."):format(Style.HEX.strong))

    page.wipeSightings = Style.Link(pane, FONT.body, function()
        ns.UI.Dialog.Confirm("Delete all sightings?\n\nDiary entries, sessions and interactions"
            .. " are kept.", function()
            ns.Sightings.DeleteAll()
            ns.Print("all sightings deleted.")
            AfterDelete()
        end)
    end)
    page.wipeSightings:SetText("Delete all sightings...")
    page.wipeSightings:SetColor(ACCENT[1], ACCENT[2], ACCENT[3])
    c:Place(page.wipeSightings, 18)

    page.wipeAll = Style.Link(pane, FONT.body, function()
        local shared = ns.diaryShared
        ns.UI.Dialog.Confirm(WipeText(), function()
            ns.WipeData()
            ns.Print(shared and "the shared diary deleted." or "this character's diary deleted.")
            AfterDelete()
        end)
    end)
    page.wipeAll:SetText("Delete everything...")
    page.wipeAll:SetColor(ACCENT[1], ACCENT[2], ACCENT[3])
    page.wipeAll:SetPoint("LEFT", page.wipeSightings, "RIGHT", 18, 0)

    -- PRV-7: this character's road alone. Kept on, it begins again from
    -- here, with a prologue at today's level.
    page.wipeRoute = Style.Link(pane, FONT.body, function()
        ns.UI.Dialog.Confirm("Delete this character's road?\n\nEvery stop, road, flight and level"
            .. " Your Diary kept for them goes. Diary entries, notes and sessions are kept.", function()
            ns.Journey.Delete(ns.ownGUID)
            if ns.JourneyCapture.On() then ns.JourneyCapture.SetEnabled(true) end
            ns.Print("this character's road deleted.")
            AfterDelete()
        end)
    end)
    page.wipeRoute:SetText("Delete this character's road...")
    page.wipeRoute:SetColor(ACCENT[1], ACCENT[2], ACCENT[3])
    c:Place(page.wipeRoute, 18, 0, 8)
end

-- The size and where the diary is kept, read again with the page
-- (UI/Settings/Page.lua's RefreshPage).
SettingsUI.SizeText, SettingsUI.SizeWarning, SettingsUI.DataText = SizeText, SizeWarning, DataText

SettingsUI.RegisterSection("memory", { order = 50, label = "Memory",
    about = "How long it keeps things, and deleting", build = BuildMemory })
