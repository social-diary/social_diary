-- Reunion toasts (REU-1 to REU-3).
--
-- When a diary entry joins the user's group, a toast says who, with their
-- tags, when and where you last met, and how often. Core/Roster.lua fires
-- SD_REUNION *before* the join reaches Sessions, so "last met" is the
-- previous meeting rather than the one that is starting now.
--
-- REU-3: the addon's own frame, never Blizzard's alert system. The alert
-- system is shared, secure-adjacent machinery, and a taint there surfaces in
-- somebody else's code.
--
-- The toast is a card from the diary rather than a window: a loose sheet
-- (UI/Paper/Sheet.lua) laid over the game like the first-run slip
-- (UI/Windows/Intro/), with the timeline's rubricated heading, the profile's
-- portrait and name in capitals, and the last meeting in a sentence. It is
-- quiet: no sound and no motion, as it comes during play.
--
-- REU-5: the same toast when a diary entry comes into view (Capture/Nearby.lua),
-- never for someone already in the group.
--
-- Both kinds share one per-person cooldown. Whether a toast is due -- the
-- settings, the cooldown, the stamps it keeps -- is Core/Reunions.lua's.
--
-- This file is the card: its frame, where it lies, its layout and how it is
-- filled (ns.UI.Toast.Build). Its siblings, loaded after it:
--   UI/Windows/Reunion/Words.lua    what the card says (ns.UI.ReunionText)
--                                   and the snapshot it is said from
--   UI/Windows/Reunion/Queue.lua    the queue, "and N more", the combat
--                                   gate, forgetting, and the entry point
--                                   (ns.UI.Reunion, SD_REUNION)
--   UI/Windows/Reunion/Placing.lua  laying a sample card to be dragged
--                                   (ns.UI.PlaceToast and friends)
--
-- What they share is on the module (ns.UI.Toast):
--   .queue               the toasts waiting, oldest first
--   .more, .moreReason   the overflow past the queue's cap, and why
--   .showing             the snapshot on the card now, else nil
--   .shown               which showing that is, a number, for its timers
--   .toast               the card's frame (SocialDiaryToastFrame), once built
--   .hovered, .overdue   the mouse on the card, and a card past its time
--                        waiting for it to leave
--   .placing             while the card is being placed: { onDone }. No
--                        toast shows meanwhile
--   .heldDone            an onDone a fight held back, until the fight ends
--   .Build               this file's; .Snapshot Words.lua's; .Dismiss,
--                        .Hover, .Pump, .InCombat Queue.lua's

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT

local Toast = {
    queue = {},
    more = 0, moreReason = nil,
    showing = nil,
    toast = nil,
    hovered = false, overdue = false,
    placing = nil,
}
ns.UI.Toast = Toast

-- The card: a slip kept between the diary's leaves, laid over the game near
-- the top of the screen, a little askew, the same way each time for the
-- same person (LooseSheet's Fall). In its own coordinates (x right, y down
-- from its top left): the margin; the middle of the heading's line, its
-- paraph's size and the darkness its rule starts at; the portrait's size
-- and top; how far in the name and the line under it start, beside the
-- portrait; the middle of the name, of that line and of the story's first
-- line, the step to the next and how many lines it may take. The story runs
-- the card's full measure, under the portrait. The margins leave a clear 11
-- pixels or more inside the warning's double rule (WARN_RULE ends 9 in), on
-- every card, so the warning only adds the rule and moves nothing.
local CARD = { w = 320, h = 135, top = -120, margin = 20,
    heading = 26, paraph = 6, rule = 0.40,
    portrait = 40, portraitTop = 36, indent = 70,
    name = 48, about = 67, story = 92, line = 16, lines = 2 }
-- Never folded: kept flat in the book, so no creases and no grime along
-- them, only paper a little uneven and corners curling up off the game.
local CREASE = {
    columns = { 0, 0.1, 0.5, 0.9, 1 }, rows = { 0, 0.5, 1 },
    folds = { columns = {}, rows = {} },
    crumple = 0.8, drift = 0.4, edge = 0.5, wander = 0.03,
    curl = { lift = 3, pull = 1.5 },
}

-- The double rule, printed on the paper so it bends and takes the light
-- with it: how far in from the edge, the outer line's width, the gap, the
-- inner line's width, and how dark the red ink is.
local WARN_RULE = { inset = 4, outer = 2, gap = 2, inner = 1, alpha = 0.85 }

--------------------------------------------------------------------------
-- The card
--------------------------------------------------------------------------

-- Where the card lies (settings.toastAt): its top's offset from the top
-- middle of the screen, so it stays put across resolutions the way the
-- default does. Nil for the default, CARD.top below the top.
local function Anchor(host)
    local at = ns.Setting("toastAt")
    local x, y = 0, CARD.top
    if type(at) == "table" and type(at.x) == "number" and type(at.y) == "number" then x, y = at.x, at.y end
    host:ClearAllPoints()
    host:SetPoint("TOP", UIParent, "TOP", x, y)
end

-- Reads back where it was dragged to, keeps that, and anchors it there
-- again. The frame is the screen's child at the same scale, so the two
-- measure alike. Not the client's own record of a frame moved by hand:
-- that one the addon could not move or reset.
local function Remember(host)
    local x, top = host:GetCenter(), host:GetTop()
    local screenX, screenTop = UIParent:GetCenter(), UIParent:GetTop()
    if x and top and screenX and screenTop then
        ns.db.settings.toastAt = { x = math.floor(x - screenX + 0.5), y = math.floor(top - screenTop + 0.5) }
    end
    host:SetUserPlaced(false)
    Anchor(host)
end

local function Build()
    local host = CreateFrame("Frame", "SocialDiaryToastFrame", UIParent)
    host:SetSize(CARD.w + 60, CARD.h + 60)
    host:SetFrameStrata("HIGH")
    -- Dragged, it stays on the screen: the card itself, not the margin
    -- left round it for its shadow and turn.
    host:SetMovable(true)
    host:SetClampedToScreen(true)
    host:SetClampRectInsets(30, -30, -30, 30)
    Anchor(host)
    host:Hide()

    -- Quiet: a card that comes by itself all evening should not rustle.
    local view, K = ns.UI.LooseSheet(host, CARD.w, CARD.h, { crease = CREASE, quiet = true })
    -- Only the card takes the mouse, not the game around it.
    view:EnableMouse(false)
    local S, M = view.sheet, CARD.margin
    host.view = view

    host.heading = Style.Text(S, FONT.headingRubric)
    host.paraph = K.Texture("ARTWORK", 2)
    host.rule = K.Texture("ARTWORK", 1)
    local R = Style.RUBRIC
    Style.Shade(host.rule, "HORIZONTAL", R[1], R[2], R[3], CARD.rule, 0)

    -- The warning's double rule, cut along the paper's mesh and lit with it.
    local rules = K.Pool("ARTWORK", 0)
    host.rules = rules
    local function Rule(x0, y0, x1, y1)
        local R = Style.RUBRIC
        K.Split(x0, y0, x1, y1, function(a, b, c, d, light)
            local texture = rules:Next()
            texture:SetColorTexture(R[1] * light, R[2] * light, R[3] * light, WARN_RULE.alpha)
            K.Bend(texture, a, b, c, d)
        end)
    end
    local function Box(inset, width)
        local x0, y0, x1, y1 = inset, inset, CARD.w - inset, CARD.h - inset
        Rule(x0, y0, x1, y0 + width)
        Rule(x0, y1 - width, x1, y1)
        Rule(x0, y0 + width, x0 + width, y1 - width)
        Rule(x1 - width, y0 + width, x1, y1 - width)
    end

    host.portrait = Style.Portrait(S, CARD.portrait)
    host.name = Style.Text(S, FONT.page)
    host.tags = Style.Text(S, FONT.heading)
    host.relationship = Style.Text(S, FONT.noteWritten)
    host.who = Style.Text(S, FONT.body)
    host.lines = {}
    for i = 1, CARD.lines do host.lines[i] = Style.Text(S, FONT.body) end

    -- The whole card is one button: left-click opens them in the journal,
    -- right-click puts it away, and either way the next one comes. While it
    -- is being placed, it is dragged instead.
    local button = CreateFrame("Button", nil, S)
    button:SetFrameLevel(S:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, which)
        if Toast.placing then return end
        local snap = Toast.showing
        Toast.Dismiss()
        if which ~= "RightButton" and snap then ns.UI.ShowJournal(snap.guid) end
    end)
    button:SetScript("OnDragStart", function()
        if Toast.placing then host:StartMoving() end
    end)
    button:SetScript("OnDragStop", function()
        host:StopMovingOrSizing()
        if Toast.placing then Remember(host) end
    end)
    Style.Tooltip(button, function()
        if Toast.placing then return { { "Drag to move it", 1, 1, 1 } } end
        local showing = Toast.showing
        if not showing then return nil end
        return {
            { showing.guid and "Click to open their page in the diary" or "Click to open the diary", 1, 1, 1 },
            { "Right-click to put it away", 0.75, 0.75, 0.75 },
        }
    end, "ANCHOR_BOTTOM", function(_, over) Toast.Hover(over) end)
    host.button = button

    -- Only while it is being placed, on the story's second line: done, or
    -- back where it started.
    host.done = K.Link(FONT.strong, function() Toast.StopPlacing() end)
    host.done:SetText("Done")
    host.reset = K.Link(FONT.body, function()
        ns.db.settings.toastAt = nil
        Anchor(host)
    end)
    host.reset:SetText("Put it back")
    for _, link in ipairs({ host.done, host.reset }) do
        link:SetFrameLevel(button:GetFrameLevel() + 1)
    end

    local function Show(text, ...)
        text:SetShown(... ~= nil)
        if ... ~= nil then K.PlaceText(text, ...) end
    end

    -- Escape hides the frame itself while it is being placed.
    host:SetScript("OnHide", function()
        if Toast.placing then Toast.StopPlacing() end
    end)

    function host:Fill(snap)
        local text = ns.UI.ReunionText(snap)
        self.text = text
        K.Fall("toast" .. (snap.guid or ""))
        K.Lay()
        K.PlaceButton(button, 0, 0, CARD.w, CARD.h)

        rules:Begin()
        if text.warning then
            local W = WARN_RULE
            Box(W.inset, W.outer)
            Box(W.inset + W.outer + W.gap, W.inner)
        end
        rules:Finish()

        -- The heading: a paraph, red capitals, and a red rule fading out to
        -- the margin.
        self.heading:SetText(text.heading:upper())
        local left, width = K.PlaceText(self.heading, M + 13, CARD.heading)
        local P = text.warning and Style.RUBRIC or Style.LAPIS
        self.paraph:SetColorTexture(P[1], P[2], P[3], 1)
        K.Place(self.paraph, M + 3, CARD.heading - CARD.paraph / 2, CARD.paraph, CARD.paraph, math.pi / 4)
        -- A heading that fills the line goes without its rule.
        local ruleX = left + width + 6
        local ruleW = CARD.w - M - ruleX
        self.rule:SetShown(ruleW >= 12)
        if ruleW >= 12 then K.Place(self.rule, ruleX, CARD.heading, ruleW, 1) end

        -- Their portrait, else the diary's own book.
        self.portrait:SetCharacter(snap.record)
        K.Place(self.portrait, M, CARD.portraitTop, CARD.portrait, CARD.portrait)

        -- The name in capitals; the first name alone where the whole is too
        -- wide.
        local room = CARD.w - CARD.indent - M
        self.name:SetText(text.name:upper())
        if K.Width(self.name) > room then
            self.name:SetText((text.name:match("^(%S+)") or text.name):upper())
        end
        K.PlaceText(self.name, CARD.indent, CARD.name)

        -- Under it the tags, then the relationship in the user's hand, if it
        -- fits; or who they are, for an entry with neither.
        local x = CARD.indent
        self.tags:SetText(text.tags or "")
        if text.tags then
            Show(self.tags, x, CARD.about)
            x = x + K.Width(self.tags) + 10
        else
            Show(self.tags)
        end
        self.relationship:SetText(text.relationship or "")
        local fits = text.relationship and x + K.Width(self.relationship) <= CARD.w - M
        if fits then Show(self.relationship, x, CARD.about) else Show(self.relationship) end
        -- Who they are: the longest that fits.
        for _, who in ipairs(text.who or { "" }) do
            self.who:SetText(who)
            if K.Width(self.who) <= room then break end
        end
        if text.who then Show(self.who, CARD.indent, CARD.about) else Show(self.who) end

        -- The story: the longest that fits. Being placed, it keeps its
        -- second line for the links.
        local most = snap.place and 1 or CARD.lines
        local measure, lines = CARD.w - 2 * M, nil
        for _, story in ipairs(text.stories) do
            lines = K.Wrap(story, measure, FONT.body)
            if #lines <= most then break end
        end
        for i, fs in ipairs(self.lines) do
            local line = i <= most and lines[i] or nil
            fs:SetText(line or "")
            if line then Show(fs, M, CARD.story + (i - 1) * CARD.line) else Show(fs) end
        end

        self.done:SetShown(snap.place == true)
        self.reset:SetShown(snap.place == true)
        if snap.place then
            local y = CARD.story + CARD.line
            self.done:PlaceAt(M, y)
            self.reset:PlaceAt(M + K.Width(self.done.label) + 16, y)
        end
    end

    return host
end
Toast.Build = Build
