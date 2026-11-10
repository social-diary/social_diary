-- Settings: Battlegrounds (UI/Settings/Page.lua lists the sections; the
-- controls are UI/Settings/Kit.lua's): how many matches keep their whole
-- scoreboard before the oldest roll up (Core/Matches.lua's Rollup), how
-- far that is now, and the warnings before it starts (Core/Hints.lua's
-- notice, UI/Journal/Hints.lua's "board-rollup").

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local BOOK = ns.UI.Journal.BOOK
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch, Number = Kit.Switch, Kit.Number

-- Retention, like Memory's bufferDays: wide enough for an evening's worth
-- and for years of them. Four digits is all the field holds.
local MIN_BOARDS, MAX_BOARDS = 10, 1000

-- Where the boards stand now: how many are whole, and how far it is to
-- the first fading. Empty before the first match.
local function StateText()
    local Matches = ns.Matches
    if #Matches.All() == 0 then return "" end
    local keep, left = Matches.Keep(), Matches.UntilRollup()
    if left > 0 then
        return ("%d of %d kept whole so far. In %s, the oldest begin to lose their strangers.")
            :format(keep - left, keep, ns.UI.Format.Count(left, "match", "matches"))
    end
    return ("The newest %d are kept whole. Older ones keep only the people from your diary."):format(keep)
end
SettingsUI.BattlegroundState = StateText

local function BuildBattlegrounds(pane, c)
    local page = SettingsUI.page

    c:Heading("Scoreboards")
    page.battlegroundBoards = Number(c, "Keep the whole scoreboard for this many matches", "",  -- (no unit: "matches" overflows its 34 px)
        "battlegroundBoards", MIN_BOARDS, MAX_BOARDS, function()
            -- A smaller number applies now: the boards past it roll up.
            ns.Matches.Rollup()
            if ns.Touch then ns.Touch() end
            ns.UI.Settings.Refresh()
        end)
    c:Hint("Older matches keep their map, result and times, and the people from your diary."
        .. " Everyone else is rubbed out, leaving only a count.")

    -- Room for two lines kept, so nothing below moves as the numbers do.
    page.battlegroundState = Style.Text(pane, FONT.small)
    page.battlegroundState:SetWidth(BOOK.RIGHT_W)
    page.battlegroundState:SetText(StateText())
    c:Place(page.battlegroundState, 28, 0, 8)
    function page.battlegroundState:Refresh() self:SetText(StateText()) end
    page.controls[#page.controls + 1] = page.battlegroundState

    c:Heading("Warnings")
    -- The notice's switch (Core/Hints.lua's `setting`): an account setting,
    -- so it says so.
    page.boardWarnings = Switch(c, "Warn me before old scoreboards lose their strangers", "boardWarnings", nil, nil,
        "A hint in the diary 25 matches before, and again as it nears. Applies to every character.")
end

SettingsUI.RegisterSection("battlegrounds", { order = 45, label = "Battlegrounds",
    about = "How many whole scoreboards are kept", build = BuildBattlegrounds })
