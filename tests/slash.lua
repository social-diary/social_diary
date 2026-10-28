-- The slash dispatcher: one ordered list per command level, read by both the
-- dispatch and /sd help; aliases; and the development commands in Dev/,
-- which run as any other but are listed only while debug is on.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Commands = ns._test.SlashCommands
local Slash = SlashCmdList.SOCIALDIARY

-- What the addon printed while fn ran, one line per message.
local function Said(fn)
    local lines, was = {}, DEFAULT_CHAT_FRAME.AddMessage
    DEFAULT_CHAT_FRAME.AddMessage = function(self, msg)
        lines[#lines + 1] = tostring(msg)
        was(self, msg)
    end
    local ok, err = pcall(fn)
    DEFAULT_CHAT_FRAME.AddMessage = was
    assert(ok, err)
    return lines
end

local function Names(under, dev)
    local list = {}
    for _, command in ipairs(Commands(under)) do
        if command.dev == dev then list[#list + 1] = command.name end
    end
    return table.concat(list, ",")
end

local function Has(lines, text)
    for i, line in ipairs(lines) do
        if line:find(text, 1, true) then return i end
    end
    return nil
end

--------------------------------------------------------------------------
Section("one list per level, dev commands marked")

Eq(Names(nil, false), "journal,add,remember,list,remove,sessions,sightings,settings,about,forget,debug",
    "the user's commands, in help order")
Eq(Names(nil, true), "prose,art,env,who,observe,chars,db,toast,probe,handtest,cardrace,journey,pen,testdata", "the development commands")
Eq(Names("sightings", false), "recent,of,city,on,rollup,reset", "the user's sighting commands")
Eq(Names("sightings", true), "status,scan,around,tooltip", "the sighting diagnostics")

Check(not pcall(ns.Slash.Register, "add", function() end, "again"), "a name registered twice")
Check(not pcall(ns.Slash.Register, "x", function() end, "x", { alias = { "" } }),
    "an alias that is taken was accepted")
Check(not pcall(ns.Slash.Register, "x", function() end, "x", { under = "nowhere" }),
    "a subcommand of a level that does not exist")
Eq(Names(nil, false), "journal,add,remember,list,remove,sessions,sightings,settings,about,forget,debug",
    "a refused registration was listed anyway")

--------------------------------------------------------------------------
Section("every registered name is reachable")

-- Each command's own fn is swapped for a probe, so the dispatch is tested
-- without running anything. Case is ignored, the rest is trimmed, and the
-- name typed comes along so aliases can be told apart.
for _, under in ipairs({ "", "sightings" }) do
    local prefix = under == "" and "" or under .. " "
    for _, command in ipairs(Commands(under)) do
        local was, got = command.fn, nil
        command.fn = function(rest, name) got = { rest = rest, name = name } end
        for _, name in ipairs(command.names) do
            got = nil
            -- The empty alias is the level on its own: no room for a rest.
            Slash("  " .. prefix .. (name == "" and "" or name:upper() .. "  Some Args  "))
            local what = ("/sd %s%s"):format(prefix, name)
            Check(got, what .. " did not reach its command")
            if name ~= "" then
                Eq(got.rest, "Some Args", what .. ": the rest")
            end
            Eq(got.name, name, what .. ": the name typed")
        end
        command.fn = was
    end
end

-- JNL-4: plain /sd is the journal, through the dispatch like the rest.
Slash("")
Check(_G.SocialDiaryJournalFrame:IsShown(), "plain /sd did not open the journal")
Slash("journal")
Check(not _G.SocialDiaryJournalFrame:IsShown(), "/sd journal did not toggle it shut")

--------------------------------------------------------------------------
Section("/sd help lists dev commands only while debug is on")

ns.db.settings.debug = false
local help = Said(function() Slash("help") end)
Eq(#help, 1 + 11, "help without debug: the header and the user's commands")
Check(help[1]:find("commands:", 1, true), "the header")
Eq(help[2], "   |cffffd100/sd journal|r  -- open the journal (also plain |cffffd100/sd|r)", "the first line")
Check(Has(help, "/sd forget|r"), "a user command is missing")
Check(not Has(help, "/sd env|r") and not Has(help, "/sd testdata|r"),
    "a development command listed without debug")
Check(Has(help, "/sd debug|r"), "/sd debug, the way to the dev commands, is not listed")

-- Anything unknown answers with the same list.
local unknown = Said(function() Slash("nonsense words") end)
Eq(table.concat(unknown, "\n"), table.concat(help, "\n"), "an unknown command")

ns.db.settings.debug = true
help = Said(function() Slash("help") end)
Eq(#help, 1 + 25, "help with debug: every command")
Check(Has(help, "/sd testdata|r") and Has(help, "/sd art|r"), "a development command is missing")
Check(Has(help, "/sd forget|r") < Has(help, "/sd art|r"), "the dev commands are not after the user's")

local sub = Said(function() Slash("sightings help") end)
Eq(#sub, 10, "sightings help with debug")
Eq(sub[#sub - 3], "   |cffffd100/sd sightings |r  -- status: listening or paused, nameplate settings,"
    .. " counters, frame cost", "the bare status line")

ns.db.settings.debug = false
sub = Said(function() Slash("sightings help") end)
Eq(#sub, 6, "sightings help without debug: no header, the user's six")
Eq(sub[4], "   |cffffd100/sd sightings on | off|r  -- switch passive detection", "the switch's line")
Check(not Has(sub, "scan|r"), "a sighting diagnostic listed without debug")
Eq(table.concat(Said(function() Slash("sightings what") end), "\n"), table.concat(sub, "\n"),
    "an unknown sighting command")

--------------------------------------------------------------------------
Section("dev commands run without debug")

ns.db.settings.debug = false
Slash("testdata")
Check(ns.Diary.IsDiary(ns.TestData.GUID), "/sd testdata did nothing with debug off")
Slash("testdata remove")
Eq(ns.Diary.IsDiary(ns.TestData.GUID), false, "/sd testdata remove")
ns.UI.CloseJournal()

-- The switch still answers with the status report, which is Dev's.
local said = Said(function() Slash("sightings off") end)
Eq((ns.SightingCapture.State()), "off", "/sd sightings off")
Check(Has(said, "sightings |cffc04040switched off"), "the switch did not report the status")
Slash("sightings on")
Eq((ns.SightingCapture.State()), "active", "/sd sightings on")

Slash("debug")
Eq(ns.DebugOn(), true, "/sd debug did not switch it on")
Slash("debug")
Eq(ns.DebugOn(), false, "/sd debug did not switch it off")

--------------------------------------------------------------------------
Section("the module calls behind the commands")

local Capture = ns.SightingCapture

-- SIG-1's switch.
Capture.SetEnabled(false)
Eq(ns.db.settings.detectSightings, false, "SetEnabled(false) not saved")
Eq((Capture.State()), "off", "SetEnabled(false)")
Capture.SetEnabled(true)
Eq((Capture.State()), "active", "SetEnabled(true)")

-- SIG-5's list: Mulgore (1412) becomes a city, then stops being one.
Eq((Capture.SetCity(1412, true)), "city", "SetCity did not re-evaluate")
local cities, found = Capture.Cities(), nil
for i, city in ipairs(cities) do
    if city.key == 1412 then found = city end
    if i > 1 then
        Check(tostring(cities[i - 1].key) < tostring(city.key), "the city list is not sorted")
    end
end
Check(found and found.on == true, "Cities() does not list the new city")
Capture.SetCity(1412, false)
Eq(ns.db.settings.cities[1412], false, "a removed city is stored as nil, and the defaults bring it back")
Eq((Capture.State()), "active", "SetCity(false) did not re-evaluate")
Capture.SetCity("Some Town", true)
Eq(ns.db.settings.cities["Some Town"], true, "a city by zone name")
Capture.SetCity("Some Town", false)

-- DIA-7's popup, shared by the sheet and /sd remove.
local GUID = F.STRANGER.guid
ns.Characters.Observe(GUID, { first = "Bram", surname = "Redfen" })
ns.Diary.Add(GUID, { source = "test" })
local before = #mock.popups
ns.UI.ConfirmRemove(GUID)
Eq(#mock.popups, before + 1, "ConfirmRemove did not ask")
local popup = mock.popups[#mock.popups]
Eq(popup.which, "SOCIAL_DIARY_REMOVE", "ConfirmRemove's popup")
Eq(popup.data, GUID, "the popup does not carry the GUID")
Eq(popup.args[1], "Bram Redfen", "the popup does not name them")
Check(mock.AnswerPopup("alt"), "the popup has no 'delete everything'")
Eq(ns.Diary.IsDiary(GUID), false, "'delete everything' left the entry")
