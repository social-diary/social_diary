-- The smoke tests' plumbing: checks, the per-file fresh start, and the run.
--
-- Every test file gets its own copy of the addon, loaded into a reset mock,
-- and its own copy of the fixtures. A file can therefore lean on what its
-- own earlier sections did, but never on another file: the order in run.lua
-- is for reading, not for setup.
--
-- A test file is a chunk that receives the context T:
--
--   local T = ...
--   local mock, F = T.mock, T.F
--   local Section, Check, Eq = T.Section, T.Check, T.Eq
--   local ns = T.Boot()

local H = {}

local here, root
local mock

local checks, section = 0, nil
local verbose = false

--------------------------------------------------------------------------
-- Checks
--------------------------------------------------------------------------

local function Section(name)
    section = name
    if verbose then print("--- " .. name .. " ---") end
end

-- Counted once they pass, so a failing run's count is the checks that held.
local function Check(ok, what)
    if not ok then
        error(("FAILED [%s] %s"):format(section or "?", what), 2)
    end
    checks = checks + 1
end

local function Eq(actual, expected, what)
    if actual ~= expected then
        error(("FAILED [%s] %s: expected %s, got %s")
            :format(section or "?", what, tostring(expected), tostring(actual)), 2)
    end
    checks = checks + 1
end

--------------------------------------------------------------------------
-- What the addon prints
--------------------------------------------------------------------------
--
-- ns.Print and ns.Debug end at the chat frame. A green run keeps them to
-- itself; a failing file shows the tail of what the addon said first, which
-- is usually the quickest way to the cause.

local said = {}

local function CaptureChat()
    DEFAULT_CHAT_FRAME.AddMessage = function(_, msg)
        said[#said + 1] = tostring(msg)
        if verbose then print(msg) end
    end
end

--------------------------------------------------------------------------
-- One file's context
--------------------------------------------------------------------------

local function Context()
    local T = { mock = mock, Section = Section, Check = Check, Eq = Eq }
    T.F = dofile(here .. "/fixtures.lua")
    T.DAY = 24 * 60 * 60

    -- The addon as the client loads it, before any event.
    function T.Load()
        T.ns = mock.LoadAddon(root)
        return T.ns
    end

    -- ... and logged in as the user's own character, which is where nearly
    -- every test starts.
    function T.Boot()
        local ns = T.Load()
        mock.SetUnit("player", T.F.SELF)
        mock.fire("ADDON_LOADED", ns.addonName)
        -- A reader who has read the front matter, so the book opens on
        -- People; the onboarding tests set it back (tests/settings.lua).
        ns.db.settings.frontRead = true
        mock.fire("PLAYER_LOGIN")
        return ns
    end

    -- Your Diary's right pages of plates as a reader opens them: an entry
    -- drawn whole where it is spliced, else each of its pieces, one a
    -- sitting (Recap.Pieces). Each { i = entry index, k = piece index or
    -- nil, e = the entry }, in the recap's order.
    function T.DiaryPages(page)
        local ns, list = T.ns, {}
        local j = ns.Journey.For(ns.ownGUID)
        for i, e in ipairs(page.recap.entries) do
            local pieces = ns.JourneyRecap.Pieces(j, e, page.ctx or {})
            if e.spliced then
                list[#list + 1] = { i = i, e = e }
            else
                for k in ipairs(pieces) do list[#list + 1] = { i = i, k = k, e = e } end
            end
        end
        return list
    end

    -- That page's plates drawn (never a run's page, as a test of plates
    -- wants them).
    function T.OpenDiaryPage(page, i, k)
        page.open, page.piece, page.pieceOf = i, k, page.recap.entries[i]
        page.mode, page.runVisit, page.fullMap = "plates", nil, nil
        T.ns.UI.RedrawJourneyPage()
    end

    -- Nobody in the diary, nothing buffered or written, no session open,
    -- nobody in the group. Characters, sightings and settings are left alone.
    function T.BlankDiary()
        local db = T.ns.db
        db.diary, db.interactions, db.sessions, db.notes = {}, {}, {}, {}
        db.meta.openSession = nil
        db.meta.roster = { members = {} }
    end

    -- Chat events by position. The payload positions are the whole risk:
    -- lineID is 11 and guid is 12, and getting them the wrong way round
    -- fails silently.
    function T.Whisper(event, text, sender, lineID, guid)
        mock.fire(event, text, sender, nil, nil, nil, nil, nil, nil, nil, nil, lineID, guid)
    end

    -- How many of someone's buffered rows are of one type.
    function T.Rows(guid, kind)
        local n = 0
        for _, r in ipairs(T.ns.Interactions.For(guid) or {}) do
            if r.type == kind then n = n + 1 end
        end
        return n
    end

    return T
end

--------------------------------------------------------------------------
-- The run
--------------------------------------------------------------------------

local function Wanted(name, only)
    if #only == 0 then return true end
    for i = 1, #only do
        if name == only[i] or name .. ".lua" == only[i] then return true end
    end
    return false
end

-- files: names under tests/, without ".lua". args: the command line;
-- "-v" prints sections and the addon's output, anything else picks files.
function H.Run(dir, files, args)
    here, root = dir, dir .. "/.."

    local only = {}
    for i = 1, #(args or {}) do
        if args[i] == "-v" then verbose = true else only[#only + 1] = args[i] end
    end

    mock = dofile(here .. "/wowmock.lua")
    CaptureChat()

    local failed, ran = {}, 0
    for _, name in ipairs(files) do
        if Wanted(name, only) then
            ran = ran + 1
            mock.Reset()
            said, section = {}, nil
            local before = checks

            if verbose then print("=== " .. name .. ".lua ===") end
            local chunk = assert(loadfile(here .. "/" .. name .. ".lua"))
            local ok, err = xpcall(function() chunk(Context()) end, debug.traceback)
            local count = checks - before

            if ok then
                print(("  ok    %-16s %4d checks"):format(name, count))
            else
                failed[#failed + 1] = name
                print(("  FAIL  %-16s %4d checks passed first"):format(name, count))
                if not verbose and #said > 0 then
                    print("        last of what the addon printed:")
                    for i = math.max(1, #said - 10), #said do print("          " .. said[i]) end
                end
                print(err)
            end
        end
    end

    if ran == 0 then
        print("no test file matches " .. table.concat(only, ", "))
        os.exit(1)
    end

    if #failed > 0 then
        print(("\n%d OF %d FILES FAILED (%s); %d checks passed")
            :format(#failed, ran, table.concat(failed, ", "), checks))
        os.exit(1)
    end
    print(("\nALL %d CHECKS PASSED"):format(checks))
end

return H
