-- "Link others" for a note (DIA-11): a small card laid over the note's sheet
-- (UI/Paper/NoteSheet.lua), on the same paper (UI/Paper/Sheet.lua).
--
-- It lists everyone in the diary but the person the note is on, the likely
-- ones first:
--
--   WITH THEM THEN    in a together session with them at the note's time:
--                     the group the note is likely about (Notes.Companions)
--   WITH THEM BEFORE  in any other session with them, the latest first
--                     (Notes.Together)
--   EVERYONE ELSE     the rest of the diary, by name
--
-- The search at the top, the People list's own (Style.PageSearch), narrows
-- all three to what matches, through the same haystack (People.Stats):
-- names, old names, tags, relationship, note. It does not take the cursor
-- on opening, so its hint shows and the likely people are what you see
-- first. A click on a row links or unlinks them at once; nothing waits on
-- Done, so a click beside the card puts it away too.

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local L, Fmt = ns.L, ns.Fmt

-- The card and what is on it, in its own coordinates (x right, y down),
-- in steps of 4 from the top: the title's middle; the search field's top
-- and height, close under the title as one header; the list, a clear gap
-- below it; the rule that closes the list off; the footer's middle.
local SHEET = { w = 330, h = 420, margin = 24, title = 34, search = 56, searchH = 24, list = 96,
    rule = 372, footer = 396 }
SHEET.listH = SHEET.rule - 12 - SHEET.list
local ROW_H, HEADER_H, PORTRAIT = 30, 24, 26
-- Not folded: a card with its corners curling a little, like the note's.
local CREASE = {
    columns = { 0, 0.08, 0.92, 1 },
    rows = { 0, 0.08, 0.92, 1 },
    folds = { columns = {}, rows = {} },
    crumple = 0.5, drift = 0.4, edge = 0.6, wander = 0,
    curl = { lift = 4, pull = 2 },
}

-- The sections, in order, from what the note is on.
local function Sections(ctx)
    local seen = {}
    if ctx.guid then seen[ctx.guid] = true end
    local function Fresh(list)
        local out = {}
        for _, guid in ipairs(list) do
            if not seen[guid] then
                seen[guid] = true
                out[#out + 1] = guid
            end
        end
        return out
    end

    local sections = {
        { title = L["WITH THEM THEN"], list = Fresh(ns.Notes.Companions(ctx.guid, ctx.time)) },
        { title = L["WITH THEM BEFORE"], list = Fresh(ns.Notes.Together(ctx.guid)) },
    }
    local rest = {}
    for guid in ns.Diary.Each() do rest[#rest + 1] = guid end
    local function Name(guid) return (ns.Characters.FullName(guid) or guid):lower() end
    table.sort(rest, function(a, b) return Name(a) < Name(b) end)
    sections[3] = { title = L["EVERYONE ELSE"], list = Fresh(rest) }
    return sections
end

local function Matches(guid, search)
    if search == "" then return true end
    local s = ns.People.Stats(guid)
    local haystack = s and s.haystack or (ns.Characters.FullName(guid) or ""):lower()
    return haystack:find(search, 1, true) ~= nil
end

ns.UI.LinkSheet = {}

-- `parent` is the book. Returns the card; :Open(ctx) lays it over the note,
-- where ctx = { guid, time, linked(guid), toggle(guid) }: whom the note is
-- on and when it is about, and how to ask and change who is linked.
-- `onClose` runs when it is put away.
function ns.UI.LinkSheet.New(parent)
    local W, H, M = SHEET.w, SHEET.h, SHEET.margin
    local view, K = ns.UI.LooseSheet(parent, W, H, { crease = CREASE, straight = true, level = 60 })
    local S = view.sheet

    function view:Close()
        self.search:ClearFocus()
        self:Hide()
        if self.onClose then self.onClose() end
    end
    view.onPutAway = function() view:Close() end

    view.title = Style.Text(S, FONT.page)
    view.title:SetText(L["Link others"])

    local Fill

    view.search = Style.PageSearch(S, M, -SHEET.search, W - 2 * M, L["Search names, tags, notes"],
        function() Fill() end)

    ----------------------------------------------------------------------
    -- The list: section headings and people, a tick box on each person

    local function BuildRow(list)
        local row = CreateFrame("Button", nil, list)

        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(1, 0.95, 0.8, 0.18)

        row.heading = Style.Text(row, FONT.heading)
        row.heading:SetPoint("BOTTOMLEFT", 2, 4)

        row.portrait = Style.Portrait(row, PORTRAIT)
        row.portrait:SetPoint("LEFT", 2, 0)
        row.name = Style.Text(row, FONT.body)
        row.name:SetPoint("LEFT", row.portrait, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        row.name:SetWordWrap(false)
        row.tick = Style.Tick(row)
        row.tick:SetPoint("RIGHT", -4, 0)

        row:SetScript("OnClick", function(self)
            if not self.guid then return end
            view.ctx.toggle(self.guid)
            Fill(true)
        end)
        Style.Tooltip(row, function(self)
            if not self.guid then return nil end
            local who = ns.UI.Format.WhoLine(ns.Characters.Get(self.guid))
            return { { ns.Characters.FullName(self.guid) or self.guid, 1, 1, 1 }, { who, 0.8, 0.8, 0.8 } }
        end, "ANCHOR_RIGHT", function(self, hot) if self.guid then self.tick:SetHot(hot) end end)
        return row
    end

    local function UpdateRow(row, item)
        local person = item.guid ~= nil
        row.guid = item.guid
        row.heading:SetShown(not person)
        row.portrait:SetShown(person)
        row.name:SetShown(person)
        row.tick:SetShown(person)
        row.hover:SetShown(person)
        row:EnableMouse(person)
        if person then
            row.portrait:SetCharacter(ns.Characters.Get(item.guid))
            row.name:SetText(ns.Characters.FullName(item.guid) or item.guid)
            row.tick:SetChecked(view.ctx.linked(item.guid))
            row.tick:SetHot(false)
        else
            row.heading:SetText(item.heading)
        end
    end

    -- As many rows as fit in full: the list never runs past its rule.
    -- Headings are shorter than rows, so a list with them simply ends a
    -- little higher.
    local listH = SHEET.listH
    view.list = ns.UI.Journal.List(S, ROW_H, math.floor(listH / ROW_H), BuildRow, UpdateRow)

    view.empty = Style.Text(S, FONT.faded)
    view.empty:SetText(L["Nobody in the diary matches."])

    -- The rule between the list and the footer, fading out at both ends
    -- like the profile's (Style.Rule).
    local INK = Style.INK
    view.rule = {}
    for i, alpha in ipairs({ { 0, Style.HAIRLINE }, { Style.HAIRLINE, 0 } }) do
        local half = K.Texture("ARTWORK", 0)
        Style.Shade(half, "HORIZONTAL", INK[1], INK[2], INK[3], alpha[1], alpha[2])
        view.rule[i] = half
    end

    view.count = Style.Text(S, FONT.small)
    view.done = K.Link(FONT.strong, function() view:Close() end)
    view.done:SetText(L["Done"])

    -- The list for the search as it stands. `keep` holds the scroll, for a
    -- tick changing under the mouse.
    function Fill(keep)
        local ctx = view.ctx
        if not ctx then return end
        local search = (view.search:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local data, linked = {}, 0
        for _, section in ipairs(Sections(ctx)) do
            local first = true
            for _, guid in ipairs(section.list) do
                if Matches(guid, search) then
                    if first then
                        data[#data + 1] = { heading = section.title, height = HEADER_H }
                        first = false
                    end
                    data[#data + 1] = { guid = guid }
                end
                if ctx.linked(guid) then linked = linked + 1 end
            end
        end
        view.list:SetData(data, keep)
        view.empty:SetShown(#data == 0)
        view.count:SetText(linked > 0 and Fmt(L["%d linked"], linked) or "")
        K.PlaceText(view.count, M, SHEET.footer)
    end

    local function Lay()
        K.Lay()
        K.PlaceText(view.title, M, SHEET.title)
        K.PlaceButton(view.search.holder, M, SHEET.search, W - 2 * M, SHEET.searchH)
        K.PlaceButton(view.list, M, SHEET.list, W - 2 * M, listH)
        K.PlaceText(view.empty, W / 2, SHEET.list + 30, "CENTER")
        local half = (W - 2 * M) / 2
        K.Place(view.rule[1], M, SHEET.rule, half, 1)
        K.Place(view.rule[2], M + half, SHEET.rule, half, 1)
        view.done:PlaceAt(W - M, SHEET.footer, "RIGHT")
        view.done:Show()
    end

    function view:Open(ctx)
        self.ctx = ctx
        self.search:SetText("")
        self.search:UpdateHint()
        K.Fall(ctx.guid)
        self:Show()
        Lay()
        Fill()
    end

    view:Hide()
    return view
end
