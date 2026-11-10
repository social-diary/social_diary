-- Settings: Credits, About's last subpage (UI/Settings/Page.lua lists the
-- sections; About is UI/Settings/Sections/About.lua; the controls are
-- UI/Settings/Kit.lua's): thanks to those who helped, and Licensing: the
-- addon's licence and the credits for what it ships, as README.md's Credits
-- and Licence sections give them. The drawn maps'
-- artists come from the dungeon data (ns.Dungeons.Credits), each once.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt
local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local INDENT = Kit.INDENT

-- The thanks, in the order they were given.
local TESTERS = { "Tabi Lorang", "Gunther Guntherino", "Mooguy Mooperson", "Koko Skybluff" }

-- Licensing's lines before and after the map art: the addon's own, then
-- what it ships.
local LICENCE = {
    L["Social Diary is released under the GNU General Public License v3 or later. Versions up to 1.7.0 were under the MIT License."],
    L["Dungeon maps, bosses, routes and loot tables: Dungeon Crawler Forever by Per, GPL v3 or later."],
    L["Creature positions along dungeon routes: TrinityCore and VMaNGOS, via advocaite/TrinityCore, GPL v2 or later."],
}
local FONTS = L["The Neuton Italic font: SIL Open Font License 1.1."]
-- Read while the game runs, never shipped: a credit under the thanks.
local QUESTIE = L["Questie and QuestieDB, which Social Diary reads from while the game runs, if you have them installed."]

-- A line of the page, wrapped to the column, `indent` in.
local function Line(pane, c, text, font, indent, gap)
    local line = Style.Text(pane, font or FONT.body)
    line:SetWidth(BOOK.RIGHT_W - (indent or 0))
    line:SetWordWrap(true)
    line:SetText(text)
    return c:Place(line, line:GetStringHeight(), indent, gap or 6)
end

-- "Map art by Santiago Reyes - Atlas de Azeroth: Forever, for The Hall of
-- Thanes and Ruins of Lordaeron", from a credit as the data gives it ("Map
-- art: …"). The artist first: a dungeon's name may hold a colon of its own.
local function MapArt(credit)
    local who = credit.text:gsub("^Map art:%s*", "")
    local dungeons = ns.UI.Format.List(credit.dungeons)
    return dungeons and Fmt(L["Map art by %1$s, for %2$s."], who, dungeons) or Fmt(L["Map art by %s."], who)
end

local function BuildCredits(pane, c)
    local page = SettingsUI.page

    c:Heading(L["Thanks"])
    Line(pane, c, L["Willing impromptu Beta Testers:"], FONT.body, 0, 8)
    page.testers = {}
    for i, name in ipairs(TESTERS) do
        local line = Style.Text(pane, FONT.strong)
        line:SetText(name)
        page.testers[i] = c:Place(line, line:GetStringHeight(), INDENT, 4)
    end
    page.questieCredit = Line(pane, c, QUESTIE, FONT.body, 0, 8)

    c:Heading(L["Licensing"])
    page.licensing = {}
    local function Add(text) page.licensing[#page.licensing + 1] = Line(pane, c, text) end
    for _, text in ipairs(LICENCE) do Add(text) end
    for _, credit in ipairs(ns.Dungeons.Credits()) do Add(MapArt(credit)) end
    Add(FONTS)
end

SettingsUI.RegisterSection("credits", { order = 58, label = L["Credits"], parent = "about",
    about = L["Testers, sources and licences"], build = BuildCredits })
