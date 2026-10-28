-- The page tests (PAGE-9): renders every angle thousands of times against
-- generated facts and holds the output to account, without a client.
--
--   luajit tests/prose/run.lua [root] [--samples out.txt] [--angle name] [--n 400]
--
-- What it checks
--   errors    a piece no generated facts ever made eligible (its needs can't
--             be met within the contract, or it names a missing fact), an
--             unknown slot or bank, and any output with leftover syntax
--             ({, }, <, >, [a|b]), "nil", doubled spaces or punctuation, a
--             sentence that starts in lower case, or a doubled word
--   warnings  a piece that was eligible but never drawn, a or an before the
--             wrong sound, "one" before a plural, a sentence over 45 words
--
-- Fixtures live in tests/prose/fixtures/<angle>.lua and return
--   { angle = "reunion", n = 400, gen = function(P) return facts end }
-- where P is the helper below (people, items, places, a seeded random).
-- Sample pages live in tests/prose/pages/*.lua and return a list of plans, each
-- rendered in sequence with one memory, as a diary would.

local root = arg[1] and not arg[1]:match("^%-%-") and arg[1] or "."
local opts = { n = nil }
for i = 1, #arg do
    if arg[i] == "--samples" then opts.samples = arg[i + 1] end
    if arg[i] == "--angle" then opts.angle = arg[i + 1] end
    if arg[i] == "--n" then opts.n = tonumber(arg[i + 1]) end
    if arg[i] == "--quiet" then opts.quiet = true end
    if arg[i] == "--show" then opts.show = tonumber(arg[i + 1]) end
    if arg[i] == "--load" then opts.load = arg[i + 1] end
end

--------------------------------------------------------------------------
-- Loading the addon's page files as the client would
--------------------------------------------------------------------------

local FILES = {
    "UI/Words/Pages/English.lua",
    "Core/Pages/Render.lua",
    "UI/Words/Pages/Slots.lua",
    "UI/Words/Pages/Lexicon.lua",
}

local function ListDir(dir, pattern)
    local list = {}
    local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
    if p then
        for line in p:lines() do
            if line:match(pattern) then list[#list + 1] = line end
        end
        p:close()
    end
    table.sort(list)
    return list
end

-- --load Reunion,Rescue loads only the angle files whose names contain one
-- of these, so a half-written file elsewhere can't stop a run.
local function Wanted(file)
    if not opts.load then return true end
    for part in opts.load:gmatch("[^,]+") do
        if file:lower():find(part:lower(), 1, true) then return true end
    end
    return false
end

for _, file in ipairs(ListDir(root .. "/UI/Words/Pages/Angles", "%.lua$")) do
    if Wanted(file) then FILES[#FILES + 1] = "UI/Words/Pages/Angles/" .. file end
end

local ns = { _test = {} }
for _, file in ipairs(FILES) do
    local chunk, err = loadfile(root .. "/" .. file)
    if not chunk then
        print("LOAD ERROR " .. err)
        os.exit(2)
    end
    local ok, runErr = pcall(chunk, "SocialDiary", ns)
    if not ok then
        print("RUN ERROR " .. file .. ": " .. tostring(runErr))
        os.exit(2)
    end
end

local Pages = ns.Pages
local errors, warnings = {}, {}
local function Err(msg) errors[#errors + 1] = msg end
local function Warn(msg) warnings[#warnings + 1] = msg end

for _, e in ipairs(Pages.ERRORS) do Err("declare: " .. e) end

-- Every bank a piece draws on exists.
local function CheckBanks(p, where)
    for _, name in ipairs(p.banks or {}) do
        if not Pages.BANKS[name] then Err(where .. ": unknown bank <" .. name .. "> in \"" .. p.text .. "\"") end
    end
end
for name, bank in pairs(Pages.BANKS) do
    for _, p in ipairs(bank) do CheckBanks(p, "bank " .. name) end
end
for aname, a in pairs(Pages.ANGLES) do
    for mname, m in pairs(a.moves) do
        for _, kind in ipairs({ "stems", "clauses", "fragments", "tails", "wholes" }) do
            for _, p in ipairs(m[kind]) do CheckBanks(p, aname .. "/" .. mname) end
        end
    end
end

--------------------------------------------------------------------------
-- The fixture helper
--------------------------------------------------------------------------

local NOW = os.time({ year = 2026, month = 10, day = 26, hour = 22, min = 40 })
local DAY = 86400

local function NewHelper(seed)
    local rng = Pages.NewRng(seed)
    local P = { now = NOW, DAY = DAY }

    function P.float() return rng.float() end
    function P.int(a, b) return a + rng.int(b - a + 1) - 1 end
    function P.chance(p) return rng.float() < p end
    function P.pick(list) return list[rng.int(#list)] end
    function P.maybe(p, v) if rng.float() < p then return v end return nil end

    P.NAMES = { "Brennick", "Ilyra", "Thandor", "Kaelith", "Morthis", "Sylwen", "Grubnak", "Tessaly",
        "Orwin", "Zuljin", "Maelis", "Dorrek", "Fenwyck", "Ashka", "Velune", "Hobbs", "Elandra", "Quill" }
    P.RACES_A = { "Human", "Dwarf", "Night Elf", "Gnome", "Draenei", "Worgen" }
    P.RACES_H = { "Orc", "Undead", "Tauren", "Troll", "Blood Elf", "Goblin" }
    P.CLASSES = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" }
    P.ZONES = { "Ashenvale", "Stonetalon Mountains", "The Barrens", "Duskwood", "Redridge Mountains",
        "Wetlands", "Hillsbrad Foothills", "Arathi Highlands", "Stranglethorn Vale", "Darkshore",
        "Westfall", "Loch Modan", "Desolace", "Thousand Needles", "Elwynn Forest", "Feralas" }
    P.SUBZONES = { "Astranaar", "Sun Rock Retreat", "the Crossroads", "Darkshire", "Lakeshire",
        "Menethil Harbor", "Southshore", "Refuge Pointe", "Booty Bay", "Auberdine", "Sentinel Hill",
        "Thelsamar", "Lake Falathim", "Raven Hill", "Goldshire" }
    P.FOES = { "Thistlefur Shaman", "Defias Pillager", "Murloc Tidehunter", "Elder Mottled Boar",
        "Skeletal Warder", "Kolkar Stormer", "Venture Co. Logger", "Ogre Mage", "Owlbeast" }
    P.RARES = { "Mor'Ladim", "Rak'shiri", "Foreman Rigger", "Old Grizzlegut", "Sister Riven" }
    P.ITEMS = { "[Lesser Healing Potion]", "[Silk Cloth]", "[Mageweave Cloth]", "[Elixir of Agility]",
        "[Linen Bandage]", "[Iron Ore]", "[Heavy Leather]", "[Oozing Bag]", "[Swiftthistle]",
        "[Earthroot]", "[Arcane Crystal]", "[Major Healing Potion]" }
    P.INSTANCES = { "Shadowfang Keep", "the Deadmines", "Wailing Caverns", "Blackfathom Deeps",
        "Razorfen Kraul", "the Scarlet Monastery", "Uldaman", "Zul'Farrak", "Maraudon" }
    P.RELATIONSHIPS = { "levelling buddy", "my brother", "friend from Redridge", "guild healer",
        "the paladin who saved me in Duskwood", "our raid leader", "fishing partner", "Guildmaster" }

    local nextId = 0
    -- A person; `spec` fixes any field ("diary", "named", "sex", "hostile", ...).
    function P.person(spec)
        spec = spec or {}
        nextId = nextId + 1
        local hostile = spec.hostile
        if hostile == nil then hostile = P.chance(0.15) end
        local p = {
            id = "Player-" .. nextId,
            name = P.pick(P.NAMES),
            sex = P.pick({ 2, 3, 2, 3, nil }),
            race = P.pick(hostile and P.RACES_H or P.RACES_A),
            class = P.pick(P.CLASSES),
            level = P.int(5, 60),
            hostile = hostile,
            diary = P.chance(0.5),
            tags = {},
        }
        if not p.diary then p.named = P.chance(0.3) end
        if p.diary and P.chance(0.6) then p.relationship = P.pick(P.RELATIONSHIPS) end
        if P.chance(0.1) then p.race = nil end
        if P.chance(0.05) then p.class = nil end
        p.familiar = (not p.diary and not p.named) and P.chance(0.4) or nil
        for k, v in pairs(spec) do p[k] = v end
        if spec.sex == false then p.sex = nil end
        return p
    end

    function P.items(max)
        local list = {}
        for i = 1, P.int(1, max or 3) do
            list[i] = { link = P.pick(P.ITEMS), count = P.pick({ 1, 1, 1, 2, 5, 10, 20 }) }
        end
        return list
    end

    function P.foe(rankSpec)
        local rank = rankSpec or P.pick({ "normal", "normal", "normal", "elite", "rare", "rareelite" })
        local named = rank == "rare" or rank == "rareelite" or rank == "worldboss"
        return { name = P.pick(named and P.RARES or P.FOES), rank = rank, npcID = P.int(100, 9000) }
    end

    -- The session the page is about.
    function P.page(spec)
        spec = spec or {}
        local part = P.pick({ "evening", "evening", "night", "afternoon", "morning" })
        local zones = {}
        local n = P.int(1, 3)
        for i = 1, n do
            local z = P.pick(P.ZONES)
            local dup = false
            for j = 1, #zones do if zones[j] == z then dup = true end end
            if not dup then zones[#zones + 1] = z end
        end
        local levelStart = P.int(5, 59)
        local gained = P.pick({ 0, 0, 1, 1, 2, 3 })
        local page = {
            part = part,
            seconds = P.int(20, 300) * 60,
            zones = zones,
            zoneFirst = zones[1],
            zoneLast = zones[#zones],
            levelStart = levelStart,
            levelEnd = math.min(60, levelStart + gained),
            levelCap = 60,
        }
        page.levelsGained = page.levelEnd - page.levelStart
        for k, v in pairs(spec) do page[k] = v end
        return page
    end

    return P
end

--------------------------------------------------------------------------
-- Holding output to account
--------------------------------------------------------------------------

local A_OK = { "a one", "a uni", "a use", "a usu", "a uti", "a ure", "a uri", "a eu", "a ewe" }
local AN_OK = { "an hour", "an honest", "an hon", "an heir", "an 8", "an 11", "an 18" }

local function StartsAny(s, list)
    for i = 1, #list do
        if s:sub(1, #list[i]) == list[i] then return true end
    end
    return false
end

local function Check(text, where)
    local visible = Pages.En.Visible(text)
    local function E(msg) Err(where .. ": " .. msg .. "\n      " .. text) end
    local function W(msg) Warn(where .. ": " .. msg .. "\n      " .. text) end

    if visible:find("[{}<>]") then E("leftover syntax") end
    if visible:find("%[[^%]]*|") then E("leftover alternation") end
    if visible:find("%f[%a]nil%f[%A]") then E("nil in text") end
    if visible:find("  ") then E("double space") end
    if visible:find(" [,%.;:!%?]") then E("space before punctuation") end
    if visible:find(",,") or visible:find(",%.") or visible:find("%.%.") then E("doubled punctuation") end
    if visible:find("[%.!%?] %l") then E("sentence starts in lower case") end
    if visible:find("^%l") then E("page starts in lower case") end
    for a, b in visible:gmatch("%f[%a](%a+) (%a+)%f[%A]") do
        if a:lower() == b:lower() and a:lower() ~= "had" and a:lower() ~= "that" then E("doubled word '" .. a .. "'") end
    end
    local lower = visible:lower()
    -- A subject pronoun where an object belongs: "with she", "saw he". The
    -- piece should have used {ref.obj}.
    local OBJECT_BEFORE = { "with", "to", "for", "of", "by", "from", "beside", "behind", "without", "about",
        "against", "towards", "toward", "saw", "see", "met", "meet", "beat", "thanked", "joined", "helped",
        "watched", "caught", "followed", "found", "leave", "left", "into", "past", "near", "beat" }
    for _, word in ipairs(OBJECT_BEFORE) do
        for pron in (" " .. lower):gmatch("[^%a]" .. word .. " (s?he)%f[%A]") do
            E("'" .. word .. " " .. pron .. "' (should be {ref.obj})")
        end
    end
    if visible:find("%f[%a]Him%f[%A]") or visible:find("[%.!%?] Her [a-z]+ed%f[%A]") then
        E("object pronoun as a subject (should be {ref})")
    end
    if lower:find("the last nearly") or lower:find("the last over") or lower:find("the past nearly")
        or lower:find("the past over") then
        E("rounded span after 'the last' (use {daysx})")
    end
    if visible:find("%f[%a][Hh]e again%.") or visible:find("%f[%a][Ss]he again%.") then
        E("note-style pronoun ('He again.'): use {ref.short}")
    end
    for article, word in lower:gmatch("%f[%a](an?) ([%w']+)") do
        local pair = article .. " " .. word
        if article == "a" and word:match("^[aeiou]") and not StartsAny(pair, A_OK) then W("'" .. pair .. "'") end
        if article == "an" and not word:match("^[aeiou]") and not StartsAny(pair, AN_OK) then W("'" .. pair .. "'") end
    end
    for noun in (" " .. lower):gmatch("[^%a%-]one (%a+s)%f[%A]") do
        if not noun:match("ss$") and noun ~= "was" and noun ~= "has" and noun ~= "is" and noun ~= "this" and noun ~= "us" then
            W("'one " .. noun .. "'")
        end
    end
    for sentence in visible:gmatch("[^%.!%?]+") do
        local words = 0
        for _ in sentence:gmatch("%S+") do words = words + 1 end
        if words > 45 then W("sentence of " .. words .. " words") end
    end
end

--------------------------------------------------------------------------
-- Rendering every angle
--------------------------------------------------------------------------

local VOICES = { "plain", "warm", "wry", "terse" }
local eligible, chosen, outputs = {}, {}, {}

local fixtureFiles = ListDir(root .. "/tests/prose/fixtures", "%.lua$")
local covered = {}

for _, file in ipairs(fixtureFiles) do
    local fixture = dofile(root .. "/tests/prose/fixtures/" .. file)
    local angleName = fixture.angle
    local wantedAngle = not opts.angle
    for part in (opts.angle or ""):gmatch("[^,]+") do
        if part == angleName then wantedAngle = true end
    end
    if Pages.ANGLES[angleName] then covered[angleName] = true end
    if wantedAngle and (Pages.ANGLES[angleName] or not opts.load) then
        local angle = Pages.ANGLES[angleName]
        if not angle then
            Err("fixture " .. file .. ": no angle " .. angleName)
        else
            local P = NewHelper(Pages.Hash(angleName))
            local n = opts.n or fixture.n or 400
            outputs[angleName] = {}
            for i = 1, n do
                local facts, page = fixture.gen(P, i)
                page = page or P.page()
                local voice = VOICES[(i % #VOICES) + 1]
                for _, moveName in ipairs(angle.order) do
                    local m = angle.moves[moveName]
                    local f = {}
                    for k, v in pairs(facts) do f[k] = v end
                    f.page = page
                    Pages.Reachable(m, f, voice, eligible)
                end
                local plan = {
                    key = "test-" .. angleName .. "-" .. i, now = NOW, page = page,
                    paragraphs = { { { angle = angleName, facts = facts, moves = fixture.moves } } },
                }
                local text, report = Pages.Render(plan, { voice = voice })
                for _, combo in pairs(report.picks) do
                    for id in combo:gmatch("[^+]+") do chosen[id] = (chosen[id] or 0) + 1 end
                end
                if text ~= "" then
                    Check(text, angleName .. " #" .. i .. " (" .. voice .. ")")
                    outputs[angleName][#outputs[angleName] + 1] = text
                end
            end
        end
    end
end

-- Coverage, move by move.
local summary = {}
local totals = { pieces = 0, never = 0, unchosen = 0 }
local angleNames = {}
for name in pairs(Pages.ANGLES) do angleNames[#angleNames + 1] = name end
table.sort(angleNames)

local function AngleWanted(name)
    if not opts.angle then return true end
    for part in opts.angle:gmatch("[^,]+") do
        if part == name then return true end
    end
    return false
end

for _, aname in ipairs(angleNames) do
    if AngleWanted(aname) then
        local a = Pages.ANGLES[aname]
        if not covered[aname] then Warn(aname .. ": no fixture, so nothing of it was rendered") end
        local distinct = {}
        for _, t in ipairs(outputs[aname] or {}) do distinct[t] = true end
        local nd = 0
        for _ in pairs(distinct) do nd = nd + 1 end
        local line = string.format("%-12s", aname)
        local counts = {}
        for _, mname in ipairs(a.order) do
            local m = a.moves[mname]
            counts[#counts + 1] = mname .. " " .. m.pieces
            for _, kind in ipairs({ "stems", "clauses", "fragments", "tails", "wholes" }) do
                for _, p in ipairs(m[kind]) do
                    totals.pieces = totals.pieces + 1
                    if covered[aname] then
                        if not eligible[p.id] then
                            totals.never = totals.never + 1
                            Err(p.id .. ": never eligible: \"" .. p.text .. "\"")
                        elseif not chosen[p.id] then
                            totals.unchosen = totals.unchosen + 1
                            Warn(p.id .. ": eligible " .. eligible[p.id] .. "x, never drawn: \"" .. p.text .. "\"")
                        end
                    end
                end
            end
        end
        summary[#summary + 1] = line .. table.concat(counts, ", ") .. "  | " .. nd .. " distinct outputs"
    end
end

local bankEntries = 0
for _, bank in pairs(Pages.BANKS) do bankEntries = bankEntries + #bank end

-- --show N prints N of each angle's outputs, for reading.
if opts.show then
    for _, aname in ipairs(angleNames) do
        local list = outputs[aname]
        if list and #list > 0 then
            print("\n== " .. aname .. " ==")
            local step = math.max(1, math.floor(#list / opts.show))
            -- Voices cycle every four renders: a step that is a multiple of
            -- four would show one voice only.
            if step % 4 == 0 then step = step + 1 end
            local shown = 0
            for i = 1, #list, step do
                if shown >= opts.show then break end
                print("  " .. list[i])
                shown = shown + 1
            end
        end
    end
    print("")
end

--------------------------------------------------------------------------
-- Sample pages
--------------------------------------------------------------------------

local samples = {}
for _, file in ipairs(ListDir(root .. "/tests/prose/pages", "%.lua$")) do
    local plans = dofile(root .. "/tests/prose/pages/" .. file)
    for _, voice in ipairs(VOICES) do
        local memory = Pages.Memory({})
        samples[#samples + 1] = "=== " .. file .. " (" .. voice .. ") ==="
        for i, plan in ipairs(plans) do
            plan.now = plan.now or NOW
            local text, report = Pages.Render(plan, { voice = voice, memory = memory, commit = true })
            Check(text, "page " .. file .. " #" .. i .. " (" .. voice .. ")")
            samples[#samples + 1] = "--- " .. (plan.title or plan.key) .. " ---"
            samples[#samples + 1] = text
            if #report.skipped > 0 then
                samples[#samples + 1] = "    (skipped: " .. table.concat(report.skipped, "; ") .. ")"
            end
            samples[#samples + 1] = ""
        end
    end
end

if opts.samples then
    local out = assert(io.open(opts.samples, "w"))
    out:write(table.concat(samples, "\n"), "\n")
    out:close()
end

--------------------------------------------------------------------------
-- Report
--------------------------------------------------------------------------

print("Angles and moves (pieces per move):")
for _, line in ipairs(summary) do print("  " .. line) end
print(string.format("\n%d pieces in moves, %d bank entries; %d never eligible, %d never drawn",
    totals.pieces, bankEntries, totals.never, totals.unchosen))

local function Show(list, label, limit)
    if #list == 0 then return end
    print("\n" .. #list .. " " .. label .. ":")
    for i = 1, math.min(#list, limit) do print("  " .. list[i]) end
    if #list > limit then print("  ... and " .. (#list - limit) .. " more") end
end
Show(errors, "errors", opts.quiet and 15 or 60)
Show(warnings, "warnings", opts.quiet and 15 or 60)

os.exit(#errors == 0 and 0 or 1)
