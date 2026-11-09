-- House copy rules that hold for every string a player reads, checked
-- over the sources (the copywriter skill, .claude/skills/copywriter/).
--
-- No middle dots, ever (the user, 9 Nov 2026): never join words with a
-- dot ("·", written "\194\183" in Lua, spaced or not). Say it as words
-- instead: a comma, "and", its own line, or its own sentence. Comments may
-- still quote the old forms; code and strings may not. Vendor/ is copied
-- as it ships and is left alone.

local T = ...
local Section, Check = T.Section, T.Check

local function Ls(cmd)
    local list, p = {}, assert(io.popen(cmd))
    for line in p:lines() do list[#list + 1] = line end
    p:close()
    return list
end

-- The dot as the client gets it, and the ways a Lua source may write it.
local DOTS = { "\194\183", "\\194\\183", "\\xC2\\xB7", "\\xc2\\xb7", "\\u{B7}", "\\u{b7}", "\\u{00B7}", "\\u{00b7}" }

-- A line's code, its comment cut off; inside a --[[ ]] block, nothing.
local function Code(line, state)
    if state.block then
        local close = line:find("]]", 1, true)
        if not close then return "" end
        state.block = false
        line = line:sub(close + 2)
    end
    local at = line:find("--", 1, true)
    if not at then return line end
    if line:sub(at + 2, at + 3) == "[[" then
        local close = line:find("]]", at + 4, true)
        if not close then state.block = true end
        return line:sub(1, at - 1) .. (close and Code(line:sub(close + 2), state) or "")
    end
    return line:sub(1, at - 1)
end

Section("no middle dots in anything a player reads")

local files = Ls("find Core Capture UI Features Dev -name '*.lua' 2>/dev/null | sort")
Check(#files >= 50, "the sources not found from " .. (os.getenv("PWD") or "?"))
-- Read in the client as they are: the changelog page, the AddOns list.
for _, extra in ipairs({ "CHANGELOG.md", "social_diary.toc" }) do files[#files + 1] = extra end

local found = {}
for _, file in ipairs(files) do
    local f = assert(io.open(file, "r"))
    local lua, state, n = file:match("%.lua$"), {}, 0
    for line in f:lines() do
        n = n + 1
        local code = lua and Code(line, state) or line
        for _, dot in ipairs(DOTS) do
            if code:find(dot, 1, true) then
                found[#found + 1] = ("%s:%d: %s"):format(file, n, line:gsub("^%s+", ""))
                break
            end
        end
    end
    f:close()
end
Check(#found == 0, "a middle dot in player text (say it with words: a comma, \"and\", its own line):\n  "
    .. table.concat(found, "\n  "))

-- The check itself: a dot in code is found, one in a comment is not.
local state = {}
Check(Code('x = "a \\194\\183 b" -- c', state):find("\\194\\183", 1, true), "a dot in a string is missed")
Check(not Code('x = 1 -- "a \194\183 b"', state):find("\194\183", 1, true), "a dot in a comment is caught")
