-- The "Remember this" picker (DIA-3, DIA-4).
--
-- Opened by the slash command. It lists everyone the client can still name,
-- and one click opens the page to add them on; its Done adds them -- two
-- actions total, which is the DIA-4 budget.
--
-- It must work in combat, so it does no work that combat forbids: no secure
-- frames, no protected calls, and every identity read goes through the same
-- gates the rest of the addon uses.

local addonName, ns = ...

local L = ns.L

local MAX_ROWS = 12
local ROW_HEIGHT = ns.Style.ROW_HEIGHT

local picker

local function BuildRow(panel, index)
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(344, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 18, -52 - (index - 1) * ROW_HEIGHT)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.12)

    row.name = ns.UI.Chrome.Label(row, "", "GameFontNormal")
    row.name:SetPoint("LEFT", 2, 0)

    row.why = ns.UI.Chrome.Label(row, "", "GameFontDisableSmall")
    row.why:SetPoint("RIGHT", -2, 0)
    row.why:SetJustifyH("RIGHT")

    row:SetScript("OnClick", function(self)
        if not self.guid then return end
        ns.UI.ClosePicker()

        if ns.Diary.IsDiary(self.guid) then
            ns.UI.ShowEntry(self.guid)
        else
            ns.UI.Remember(self.guid, { unit = self.unit, source = "picker" })
        end
    end)

    return row
end

local function Build()
    local panel = ns.UI.Chrome.Panel("SocialDiaryPickerFrame", 380,
        52 + MAX_ROWS * ROW_HEIGHT + 40, L["Remember this"])

    panel.rows = {}
    for i = 1, MAX_ROWS do
        panel.rows[i] = BuildRow(panel, i)
    end

    panel.empty = ns.UI.Chrome.Label(panel, "", "GameFontDisableSmall")
    panel.empty:SetPoint("TOPLEFT", 18, -56)

    panel.hint = ns.UI.Chrome.Label(panel,
        "|cff808080" .. L["Click somebody to add them. Already in the diary opens their entry."] .. "|r",
        "GameFontDisableSmall")
    panel.hint:SetPoint("BOTTOMLEFT", 18, 18)
    panel.hint:SetPoint("RIGHT", -18, 0)

    return panel
end

local function Refresh()
    if not picker then return end

    local candidates = ns.Candidates()

    for i = 1, MAX_ROWS do
        local row = picker.rows[i]
        local candidate = candidates[i]

        if candidate then
            row.guid = candidate.guid
            row.unit = candidate.unit

            local marker = candidate.inDiary and " |cffffd100*|r" or ""
            row.name:SetText(ns.UI.Format.ClassColor(candidate.guid) .. candidate.name .. "|r" .. marker)
            row.why:SetText(candidate.why)
            row:Show()
        else
            row.guid, row.unit = nil, nil
            row:Hide()
        end
    end

    if #candidates == 0 then
        picker.empty:SetText(L["Nobody to remember right now. Target someone, or interact with them first."])
    else
        picker.empty:SetText("")
    end
end

function ns.UI.ShowPicker()
    picker = picker or Build()
    Refresh()
    picker:Show()
    picker:Raise()
end

function ns.UI.ClosePicker()
    if picker then picker:Hide() end
end

function ns.UI.TogglePicker()
    if picker and picker:IsShown() then
        ns.UI.ClosePicker()
    else
        ns.UI.ShowPicker()
    end
end
