-- Where each translation stands, for translators. Run from the addon folder:
--
--   luajit Dev/Locale/status.lua          every locale: how much is written,
--                                         what is missing, what is left over,
--                                         and files WoW could not load
--   luajit Dev/Locale/status.lua deDE     one locale: the missing keys, by the
--                                         file they belong in, ready to paste,
--                                         and the keys to delete
--
-- Paste a block into the file it names, near the key it names, and write
-- the words in place of the English. A key with its "-- " still in front
-- is not read, so nothing changes until it is translated. `--context` in
-- Dev/Locale/extract.lua shows the code round each key, for what its
-- values are.
--
-- A file is checked with luac5.1 where it is installed: WoW runs Lua 5.1,
-- which refuses what LuaJIT (the tests) lets through, like a key with an
-- umlaut written bare (küste = "f") or a missing comma. A file that fails
-- here loads none of its words in the game.
--
-- Reads only: it writes nothing. Uses Dev/Locale/extract.lua as a library.

-- "--lib": the module, not its own run (which would rewrite enUS.lua).
local Extract = assert(loadfile("Dev/Locale/extract.lua"))("--lib")
local root = "."

-- The locales the TOC loads, in its order, with their files.
local function Locales()
    local list, files = {}, {}
    for line in io.lines(root .. "/social_diary.toc") do
        local id, file = line:match("^Locales/(%a%a%a%a)/([%w_]+%.lua)%s*$")
        if id then
            if not files[id] then files[id] = {}; list[#list + 1] = id end
            table.insert(files[id], "Locales/" .. id .. "/" .. file)
        end
    end
    return list, files
end

-- Each file's own words, run without the game the way Extract.Locale runs
-- them all, so a key can be traced to the file that holds it. A file that
-- does not load is returned in `broken` with its error.
local function Words(id, files)
    local byFile, all, broken = {}, {}, {}
    for _, file in ipairs(files) do
        local mine = {}
        local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
        ns.Locale = {
            id = id, grammar = {},
            Is = function(other) return other == id end,
            Offer = function() end,
            Add = function(other, list)
                if other ~= id then return false end
                for k, v in pairs(list) do mine[k] = v end
                return true
            end,
        }
        local chunk, err = loadfile(root .. "/" .. file)
        local ok, runErr = false, err
        if chunk then ok, runErr = pcall(chunk, "social_diary", ns) end
        if not ok then broken[#broken + 1] = { file = file, err = tostring(runErr) } end
        byFile[file] = mine
        for k in pairs(mine) do all[k] = file end
    end
    return all, byFile, broken
end

-- Lua 5.1's verdict on a file, or nil where luac5.1 is not installed.
local LUAC
local function Luac51(file)
    if LUAC == nil then
        local probe = io.popen("command -v luac5.1 2>/dev/null")
        LUAC = probe and probe:read("*l") or false
        if probe then probe:close() end
        if LUAC == "" then LUAC = false end
    end
    if not LUAC then return nil end
    local p = io.popen(("%s -p %q 2>&1"):format(LUAC, root .. "/" .. file))
    local out = p:read("*a")
    p:close()
    return out ~= "" and (out:gsub("%s+$", "")) or true
end

-- The code's keys in the order Locales/enUS.lua lists them: by the file
-- and line of their first use.
local function EnglishOrder(keys, order)
    local sorted = {}
    for i, k in ipairs(order) do sorted[i] = k end
    local function Where(k)
        local file, line = keys[k]:match("^(.-):(%d+)$")
        return file, tonumber(line)
    end
    table.sort(sorted, function(a, b)
        local fa, la = Where(a)
        local fb, lb = Where(b)
        if fa ~= fb then return fa < fb end
        if la ~= lb then return la < lb end
        return a < b
    end)
    return sorted
end

local function Quote(text)
    return (("%q"):format(text):gsub("\\\n", "\\n"))
end

-- Everything that keeps a locale's files from loading: Lua 5.1's errors,
-- and errors running them.
local function Problems(files, broken)
    local list = {}
    for _, b in ipairs(broken) do list[#list + 1] = b.file .. ": " .. b.err end
    for _, file in ipairs(files) do
        local verdict = Luac51(file)
        if type(verdict) == "string" then list[#list + 1] = verdict .. "   (Lua 5.1, as in WoW)" end
    end
    return list
end

local keys, order = Extract.Keys(root)
local ids, filesOf = Locales()
local total = #order

local id = arg and arg[1]
if not id then
    print(("%-6s %18s %9s %9s  %s"):format("locale", "translated", "missing", "unused", "files"))
    local anyBroken = false
    for _, loc in ipairs(ids) do
        local all, _, broken = Words(loc, filesOf[loc])
        local have, unused = 0, 0
        for _, k in ipairs(order) do if all[k] then have = have + 1 end end
        for k in pairs(all) do if not keys[k] then unused = unused + 1 end end
        local problems = Problems(filesOf[loc], broken)
        anyBroken = anyBroken or #problems > 0
        print(("%-6s %8d/%-5d %3d%% %9d %9d  %s"):format(loc, have, total, math.floor(have * 100 / total),
            total - have, unused, #problems == 0 and "ok" or (#problems .. " BROKEN")))
        for _, p in ipairs(problems) do print("         " .. p) end
    end
    if LUAC == false then print("\n(luac5.1 is not installed: files were not checked as WoW reads them)") end
    print("\nOne locale in detail: luajit Dev/Locale/status.lua <locale>")
    os.exit(anyBroken and 1 or 0)
end

if not filesOf[id] then
    print(id .. ": no files for it in social_diary.toc. Known: " .. table.concat(ids, ", "))
    os.exit(1)
end

local all, _, broken = Words(id, filesOf[id])
local problems = Problems(filesOf[id], broken)
if #problems > 0 then
    print("== Files WoW cannot load (none of their words show in the game)\n")
    for _, p in ipairs(problems) do print("  " .. p) end
    print("")
end

-- Each missing key goes into the file that holds the key before it in
-- enUS.lua's order (else the one after it): its neighbours in the game.
local sorted = EnglishOrder(keys, order)
local blocks, current = {}, nil
for i, k in ipairs(sorted) do
    if not all[k] then
        if not current then
            local file, near
            for j = i - 1, 1, -1 do
                if all[sorted[j]] then file, near = all[sorted[j]], "after " .. Quote(sorted[j]); break end
            end
            if not file then
                for j = i + 1, #sorted do
                    if all[sorted[j]] then file, near = all[sorted[j]], "before " .. Quote(sorted[j]); break end
                end
            end
            current = { file = file or filesOf[id][#filesOf[id]], near = near or "anywhere", keys = {} }
            blocks[#blocks + 1] = current
        end
        table.insert(current.keys, k)
    else
        current = nil
    end
end

local missing = 0
for _, b in ipairs(blocks) do missing = missing + #b.keys end
print(("== %d of %d keys have no %s words\n"):format(missing, total, id))
for _, b in ipairs(blocks) do
    print(("-- into %s, %s"):format(b.file, b.near))
    local last
    for _, k in ipairs(b.keys) do
        local src = keys[k]:match("^(.-):")
        if src ~= last then print("    -- " .. src); last = src end
        print(("    -- [%s] = %s,"):format(Quote(k), Quote((k:gsub("##.*$", "")))))
    end
    print("")
end

local stale = {}
for k, file in pairs(all) do if not keys[k] then stale[#stale + 1] = { k = k, file = file } end end
table.sort(stale, function(a, b) return a.file == b.file and a.k < b.k or a.file < b.file end)
if #stale > 0 then
    print(("== %d keys the code no longer uses (reworded or removed): delete them\n"):format(#stale))
    for _, s in ipairs(stale) do print(("  %s  %s"):format(s.file, Quote(s.k))) end
    print("")
end

print("The code round each missing key: luajit Dev/Locale/extract.lua --context " .. id)
os.exit(#problems > 0 and 1 or 0)
