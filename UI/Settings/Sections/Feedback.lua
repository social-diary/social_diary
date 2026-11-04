-- Settings: Feedback, above About (UI/Settings/Page.lua lists the sections;
-- the controls are UI/Settings/Kit.lua's): where to report a bug or leave
-- an idea or a comment, and what a bug report wants. The client cannot open
-- a web address, so each is written on a slip to copy (Style.CopyField).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings

-- Where each goes, in the order the page gives them.
local LINKS = {
    { key = "issues", heading = "Bugs and ideas",
      line = "Report a bug or suggest an idea on GitHub.",
      url = "https://github.com/social-diary/social_diary/issues" },
    { key = "comments", heading = "Comments",
      line = "Leave a comment on CurseForge.",
      url = "https://www.curseforge.com/wow/addons/social-diary/comments" },
}

local COPY_HINT = "Copy and Paste this link"

-- The version the bug form asks for, and the extra chat messages that help.
local function VersionText()
    return ("You are on version |cff%s%s|r."):format(Style.HEX.strong, ns.version)
end
local DEBUG_TEXT = ("If something breaks, try to write down what happened as precisely as possible!"):format(Style.HEX.strong)

-- A line of the page, wrapped to the column.
local function Line(pane, c, text, font, gap)
    local line = Style.Text(pane, font or FONT.body)
    line:SetWidth(BOOK.RIGHT_W)
    line:SetWordWrap(true)
    line:SetText(text)
    return c:Place(line, line:GetStringHeight(), 0, gap or 6)
end

local function BuildFeedback(pane, c)
    local page = SettingsUI.page

    page.feedbackLinks = {}
    for i, link in ipairs(LINKS) do
        c:Heading(link.heading)
        Line(pane, c, link.line, FONT.body, 8)
        local field = Style.CopyField(pane, BOOK.RIGHT_W, link.url)
        page.feedbackLinks[link.key] = field
        c:Place(field, field.height, 0, 8)
        -- Said once, under the first slip, where it is wanted.
        if i == 1 then page.feedbackCopyHint = c:Hint(COPY_HINT) end
    end

    c:Heading("Reporting a bug")
    page.feedbackVersion = Line(pane, c, VersionText(), FONT.body, 8)
    page.feedbackDebug = Line(pane, c, DEBUG_TEXT, FONT.body, 8)
end

SettingsUI.RegisterSection("feedback", { order = 55, label = "Feedback",
    about = "Bugs, ideas and comments", build = BuildFeedback })
