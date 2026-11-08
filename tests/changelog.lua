-- The in-game changelog's data (Core/ChangelogData.lua) against
-- CHANGELOG.md: written by Dev/changelog.lua, the newest releases only,
-- each with its summary. Fails until the script is run again after the
-- changelog changes.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local here = (arg and arg[0] or "tests/run.lua"):match("^(.*)[/\\]") or "."
local root = here .. "/.."
local Gen = dofile(root .. "/Dev/changelog.lua")

--------------------------------------------------------------------------
Section("the parser")

local sample = table.concat({
    "# Changelog", "", "## [Unreleased]", "", "- not yet", "",
    "## [1.2.0]", "", "A big Update: _Plates_ and more.", "",
    "### Shiny new Things", "", "- A thing (thanks Wendla Morrow)", "  - Its extra", "",
    "### Fixes", "", "- A fix", "",
    "## [1.1.0]", "", "### Fixes", "", "- Older (thanks Brannoc Ashby)", "",
}, "\n")
local parsed = Gen.Parse(sample)
Eq(#parsed, 2, "two releases, Unreleased left out")
Eq(parsed[1].version, "1.2.0", "newest first")
Eq(parsed[1].summary, "A big Update: _Plates_ and more.", "the summary under the heading")
Eq(parsed[2].summary, nil, "no summary where there is none")
Eq(parsed[1].groups[1].heading, "Shiny new Things", "a group's heading")
local e = parsed[1].groups[1].entries[1]
Eq(e.text, "A thing", "the credit is taken off the entry's text")
Eq(e.thanks, "Wendla Morrow", "...and kept as its thanks")
Eq(e.sub and e.sub[1].text, "Its extra", "a sub-entry under its entry")
Eq(parsed[1].groups[2].entries[1].thanks, nil, "no thanks where there is none")
Eq(#Gen.Newest(parsed, 1), 1, "pruned to the newest")

--------------------------------------------------------------------------
Section("Core/ChangelogData.lua matches CHANGELOG.md")

local data = ns.Changelog
Check(type(data) == "table", "ns.Changelog is loaded")
local want = Gen.Newest(Gen.Parse(Gen.Read(root .. "/CHANGELOG.md")))
Eq(#data, math.min(Gen.KEEP, #want), "the newest releases, at most " .. Gen.KEEP)
Eq(Gen.Render(data), Gen.Render(want),
    "out of date with CHANGELOG.md: run /opt/homebrew/bin/luajit Dev/changelog.lua")
for _, r in ipairs(data) do
    Check(r.summary and r.summary ~= "", "release " .. r.version .. " has no summary")
end
