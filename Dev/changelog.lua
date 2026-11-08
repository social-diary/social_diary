-- The in-game changelog's data (Core/ChangelogData.lua), written from
-- CHANGELOG.md. Run from the addon folder after the changelog changes, and
-- as a step of every release (.claude/skills/release-version):
--
--   /opt/homebrew/bin/luajit Dev/changelog.lua
--
-- Not loaded by the game (not in the TOC); tests/changelog.lua reads the
-- parser below to check the data still matches CHANGELOG.md.
--
-- What it reads, as .claude/rules/changelog.md shapes it:
--
--   ## [2.4.0]                a release (## [Unreleased] is left out)
--   This Update brings ...    its summary: the lines before the first ###
--   ### Fixes                 a group of entries
--   - An entry (thanks Name)  an entry, with the player it thanks
--     - A sub-entry           under the entry above
--
-- Only the newest KEEP releases go in: older ones are pruned from the
-- game's copy (CHANGELOG.md keeps them all).

local M = {}

M.KEEP = 5
M.SOURCE = "CHANGELOG.md"
M.TARGET = "Core/ChangelogData.lua"

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- "Text (thanks Name)" -> { text = "Text", thanks = "Name" }.
local function Entry(line)
    local text, who = line:match("^(.-)%s*%(thanks%s+([^)]+)%)%s*$")
    if text then return { text = Trim(text), thanks = Trim(who) } end
    return { text = Trim(line) }
end

-- CHANGELOG.md's text -> the releases, newest first, every one of them.
function M.Parse(source)
    local releases, release, group, entry = {}, nil, nil, nil
    local summary
    local function Close()
        if release and summary and #summary > 0 then release.summary = Trim(table.concat(summary, " ")) end
        summary = nil
    end
    for line in (source .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local version = line:match("^##%s+%[([^%]]+)%]")
        if version then
            Close()
            if version:lower() == "unreleased" then
                release = nil
            else
                release = { version = version, groups = {} }
                releases[#releases + 1] = release
                summary = {}
            end
            group, entry = nil, nil
        elseif line:match("^##%s") then
            Close()
            release, group, entry = nil, nil, nil
        elseif release then
            local heading = line:match("^###%s+(.-)%s*$")
            local sub = line:match("^%s%s+[-*]%s+(.+)$")
            local top = line:match("^[-*]%s+(.+)$")
            if heading then
                if summary then Close() end
                group = { heading = heading, entries = {} }
                release.groups[#release.groups + 1] = group
                entry = nil
            elseif top and group then
                entry = Entry(top)
                group.entries[#group.entries + 1] = entry
            elseif sub and entry then
                entry.sub = entry.sub or {}
                entry.sub[#entry.sub + 1] = Entry(sub)
            elseif summary and Trim(line) ~= "" then
                summary[#summary + 1] = Trim(line)
            end
        end
    end
    Close()
    return releases
end

-- The newest `keep` releases.
function M.Newest(releases, keep)
    local out = {}
    for i = 1, math.min(keep or M.KEEP, #releases) do out[i] = releases[i] end
    return out
end

local function Q(s) return string.format("%q", s) end

local function WriteEntry(out, e, indent)
    local parts = { "text = " .. Q(e.text) }
    if e.thanks then parts[#parts + 1] = "thanks = " .. Q(e.thanks) end
    if e.sub then
        local subs = {}
        for _, s in ipairs(e.sub) do
            subs[#subs + 1] = "{ text = " .. Q(s.text) .. (s.thanks and (", thanks = " .. Q(s.thanks)) or "") .. " }"
        end
        parts[#parts + 1] = "sub = { " .. table.concat(subs, ", ") .. " }"
    end
    out[#out + 1] = indent .. "{ " .. table.concat(parts, ", ") .. " },"
end

-- The releases as Core/ChangelogData.lua.
function M.Render(releases)
    local out = {
        "-- The in-game changelog (Settings > About > Changelog,",
        "-- UI/Settings/Sections/Changelog.lua): the newest releases of CHANGELOG.md.",
        "-- Written by Dev/changelog.lua; do not edit by hand. Run it again after",
        "-- CHANGELOG.md changes (tests/changelog.lua fails until you do).",
        "",
        "local addonName, ns = ...",
        "",
        "ns.Changelog = {",
    }
    for _, r in ipairs(releases) do
        out[#out + 1] = "    {"
        out[#out + 1] = "        version = " .. Q(r.version) .. ","
        if r.summary and r.summary ~= "" then out[#out + 1] = "        summary = " .. Q(r.summary) .. "," end
        out[#out + 1] = "        groups = {"
        for _, g in ipairs(r.groups) do
            out[#out + 1] = "            { heading = " .. Q(g.heading) .. ", entries = {"
            for _, e in ipairs(g.entries) do WriteEntry(out, e, "                ") end
            out[#out + 1] = "            } },"
        end
        out[#out + 1] = "        },"
        out[#out + 1] = "    },"
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n") .. "\n"
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end
M.Read = Read

-- Run as a script (not dofile'd by a test): write the data file.
if arg and arg[0] and arg[0]:match("changelog%.lua$") then
    local releases = M.Newest(M.Parse(Read(M.SOURCE)))
    local f = assert(io.open(M.TARGET, "wb"))
    f:write(M.Render(releases))
    f:close()
    local versions = {}
    for _, r in ipairs(releases) do
        versions[#versions + 1] = r.version .. (r.summary and "" or " (no summary!)")
    end
    print(("Wrote %s: %s"):format(M.TARGET, table.concat(versions, ", ")))
end

return M
