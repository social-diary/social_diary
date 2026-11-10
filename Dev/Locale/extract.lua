-- The translation keys, read from the source (Locales/Locale.lua).
--
--   luajit Dev/Locale/extract.lua           writes Locales/enUS.lua
--   luajit Dev/Locale/extract.lua --check   only reports: keys the code uses
--                                           that enUS.lua lacks, and the other way
--   luajit Dev/Locale/extract.lua --missing deDE
--                                           the keys deDE has no words for
--   luajit Dev/Locale/extract.lua --context deDE [path]
--                                           the same keys, each with the code
--                                           round its first use (what its
--                                           values are, where it shows), for
--                                           a translator; `path` keeps to the
--                                           files under it ("Features/Hunts")
--   luajit Dev/Locale/extract.lua --context all [path]
--                                           every key that way
--
-- A key is the literal in L["..."] or ns.T("...") (double quotes, Lua
-- escapes allowed), in every file the TOC loads outside Vendor/, Dev/ and
-- Locales/. Run from the addon folder. tests/locale.lua uses Keys() and
-- Locale() as a library (`dofile` returns the module when given "--lib").

local M = {}

local SKIP = { "^Vendor/", "^Dev/", "^Locales/" }

local function Skipped(file)
    for _, p in ipairs(SKIP) do if file:find(p) then return true end end
    return false
end

function M.Files(root)
    root = root or "."
    local files = {}
    for line in io.lines(root .. "/social_diary.toc") do
        local file = line:match("^([%w_]+/[%w_/]+%.lua)%s*$")
        if file and not Skipped(file) then files[#files + 1] = file end
    end
    return files
end

-- A Lua double-quoted literal's text, its escapes read as Lua reads them.
local function Decode(body)
    local chunk = assert(loadstring('return "' .. body .. '"'))
    return chunk()
end

-- Where a key's literal opens: `L["` (not part of a longer name), `ns.L["` and `ns.T("`.
local OPENERS = { '%f[%w_%.]L%["', 'ns%.L%["', 'ns%.T%("' }

-- The literal's body from `i` (just past its opening quote) to its
-- closing quote, and where that quote is; nil when the line ends first.
local function Literal(code, i)
    local j = i
    while j <= #code do
        local c = code:sub(j, j)
        if c == "\\" then j = j + 2
        elseif c == '"' then return code:sub(i, j - 1), j
        else j = j + 1 end
    end
    return nil
end

-- Every key and where it is first used: { [key] = "file:line" }, plus the
-- keys in their order of first use.
function M.Keys(root)
    root = root or "."
    local keys, order = {}, {}
    local function Note(body, file, n)
        local key = Decode(body)
        if not keys[key] then
            keys[key] = file .. ":" .. n
            order[#order + 1] = key
        end
    end
    for _, file in ipairs(M.Files(root)) do
        local n = 0
        for line in io.lines(root .. "/" .. file) do
            n = n + 1
            local code = line:gsub("^%s*%-%-.*$", "")
            for _, opener in ipairs(OPENERS) do
                local from = 1
                while true do
                    local s, e = code:find(opener, from)
                    if not s then break end
                    local body, after = Literal(code, e + 1)
                    if body then Note(body, file, n) end
                    from = (after or e) + 1
                end
            end
        end
    end
    return keys, order
end

-- A locale file set's words, read without the game: each file is run with
-- a namespace whose Locale.Add keeps everything. `files` relative to root.
function M.Locale(root, id)
    root = root or "."
    local words = {}
    local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
    ns.Locale = {
        id = id, grammar = {},
        Is = function(other) return other == id end,
        Add = function(other, list)
            if other ~= id then return false end
            for k, v in pairs(list) do words[k] = v end
            return true
        end,
    }
    for line in io.lines(root .. "/social_diary.toc") do
        local file = line:match("^(Locales/[%w_/]+%.lua)%s*$")
        if file and file ~= "Locales/Locale.lua" then
            local chunk = assert(loadfile(root .. "/" .. file))
            chunk("social_diary", ns)
        end
    end
    return words, ns.Locale.grammar
end

-- A template's placeholders, as a comparable signature: "s,d" for plain
-- ones in order, "1s,2d" (sorted) for positional ones. %% is no placeholder.
function M.Signature(text)
    local plain, positional = {}, {}
    local s = text:gsub("%%%%", "")
    for flags, spec in s:gmatch("%%([%d%$%-+ #%.]*)([%a])") do
        local pos = flags:match("^(%d+)%$")
        if pos then
            positional[#positional + 1] = pos .. ((spec == "i") and "d" or spec)
        else
            plain[#plain + 1] = (spec == "i") and "d" or spec
        end
    end
    if #positional > 0 then
        -- a positional template is compared by what it takes, in value order
        table.sort(positional)
        return table.concat(positional, ","), #plain > 0
    end
    return table.concat(plain, ","), false
end

-- The same signature for a key, written in positional form ("1s,2d").
function M.PositionalOf(text)
    local sig = M.Signature(text)
    local out, i = {}, 0
    for spec in sig:gmatch("[^,]+") do
        i = i + 1
        out[#out + 1] = i .. spec
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function Write(root, order, keys)
    local out = {
        "-- Generated by Dev/Locale/extract.lua from the source; do not edit by hand.",
        "-- Every key the addon looks up (Locales/Locale.lua), as the code writes it,",
        "-- where it is first used. A translation adds the same keys in Locales/<id>/.",
        "",
        "local addonName, ns = ...",
        "",
        "ns.Locale.Add(\"enUS\", {",
    }
    local sorted = {}
    for _, k in ipairs(order) do sorted[#sorted + 1] = k end
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
    local last
    for _, key in ipairs(sorted) do
        local file = keys[key]:match("^(.-):")
        if file ~= last then
            out[#out + 1] = "    -- " .. file
            last = file
        end
        local lit = ("%q"):format(key):gsub("\\\n", "\\n")
        local en = ("%q"):format((key:gsub("##.*$", ""))):gsub("\\\n", "\\n")
        out[#out + 1] = ("    [%s] = %s,"):format(lit, en)
    end
    out[#out + 1] = "})"
    out[#out + 1] = ""
    local f = assert(io.open(root .. "/Locales/enUS.lua", "w"))
    f:write(table.concat(out, "\n"))
    f:close()
    return #sorted
end

if (arg and arg[1] == "--lib") or select(1, ...) == "--lib" then return M end

local root = "."
local keys, order = M.Keys(root)
if arg and arg[1] == "--check" then
    local en = M.Locale(root, "enUS")
    local bad = 0
    for _, k in ipairs(order) do
        if en[k] == nil then print("not in enUS.lua: " .. ("%q"):format(k) .. "  (" .. keys[k] .. ")"); bad = bad + 1 end
    end
    for k in pairs(en) do
        if not keys[k] then print("unused in enUS.lua: " .. ("%q"):format(k)); bad = bad + 1 end
    end
    print(bad == 0 and "enUS.lua is up to date" or (bad .. " differences: run luajit Dev/Locale/extract.lua"))
    os.exit(bad == 0 and 0 or 1)
elseif arg and arg[1] == "--context" then
    -- A key with the lines round its first use: the comment block above
    -- it (the file's own account of the sentence) and the lines up to the
    -- call's end, so the values of %1$s, %2$s can be read off the code.
    local id, under = arg[2] or "all", arg[3]
    local words = id ~= "all" and M.Locale(root, id) or {}
    local cache = {}
    local function Lines(file)
        if not cache[file] then
            local list = {}
            for line in io.lines(root .. "/" .. file) do list[#list + 1] = line end
            cache[file] = list
        end
        return cache[file]
    end
    local n = 0
    for _, k in ipairs(order) do
        local file, line = keys[k]:match("^(.-):(%d+)$")
        line = tonumber(line)
        if words[k] == nil and (not under or file:sub(1, #under) == under) then
            n = n + 1
            local lines = Lines(file)
            local from = line
            -- up through the comment block that leads to this line, 12 lines at most
            local top = line - 1
            while top >= 1 and line - top <= 12 and not lines[top]:find("^%s*%-%-") and lines[top]:find("%S") do top = top - 1 end
            while top >= 1 and line - top <= 12 and lines[top]:find("^%s*%-%-") do from = top; top = top - 1 end
            if from == line then from = math.max(1, line - 2) end
            print(("%q"):format(k))
            print(("  %s:%d"):format(file, line))
            for i = from, math.min(#lines, line + 2) do
                print(("  %s %4d  %s"):format(i == line and ">" or " ", i, lines[i]))
            end
            print("")
        end
    end
    print(n .. " keys" .. (id ~= "all" and (" without " .. id .. " words") or "") .. (under and (" under " .. under) or ""))
elseif arg and arg[1] == "--missing" then
    local id = arg[2] or "deDE"
    local words = M.Locale(root, id)
    local n = 0
    for _, k in ipairs(order) do
        if words[k] == nil then print(("%q  (%s)"):format(k, keys[k])); n = n + 1 end
    end
    print(n .. " of " .. #order .. " keys have no " .. id .. " words")
else
    print("Locales/enUS.lua: " .. Write(root, order, keys) .. " keys")
end
