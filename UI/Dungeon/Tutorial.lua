-- A note laid on the map the first time a run comes out on the table
-- (UI/Dungeon/Spread.lua), once per account: why the marks lie where they
-- lie, and what to do when they do not. A small loose sheet (UI/Paper/
-- Sheet.lua) over the map's middle, folded once, in its own words.
--
-- It counts as seen as it is laid (dungeonTutorialSeen, Core/DB.lua), so no
-- way out, its link, Escape, or the book shut under it, can bring it back.
-- While it is up it covers the screen and takes every click and the wheel;
-- only its link puts it away, or Escape: it holds the spread's one place in
-- UISpecialFrames (Spread.lua's StandIn), so a press takes the note and
-- leaves the map out. It goes with the spread, and is not left shown under
-- it to come back with the next run (TutorialGone).

local addonName, ns = ...

local Style = ns.Style
local FONT = Style.FONT
local DungeonPage = ns.UI.DungeonPage

-- The sheet in its own coordinates (x right, y down): `w` wide, as tall as
-- its words need; the title's middle; the first line's middle; a line every
-- `line` px, `gap` px more between the paragraphs; the link's middle `link`
-- px under the last line, `foot` px of paper under that. It lies `level`
-- over the spread: over everything on the map, the pencil's slip too.
local NOTE = { name = "SocialDiaryDungeonTutorial", w = 380, margin = 30, title = 36, body = 68, line = 18, gap = 10,
    link = 34, foot = 24, level = 100 }
-- Folded once across the middle and hardly crumpled, its corners curling a
-- little: the note sheet's (UI/Paper/NoteSheet.lua).
local CREASE = {
    columns = { 0, 0.07, 0.93, 1 },
    rows = { 0, 0.07, 0.5, 0.93, 1 },
    folds = { columns = {}, rows = { [3] = -1 } },
    crumple = 0.5, drift = 0.4, edge = 0.6, wander = 0, shift = 3, lean = 2,
    curl = { lift = 5, pull = 3 },
}
local WORDS = {
    title = "About this map",
    paragraphs = {
        "There is no navigation data inside dungeons, so the diary has to work out where things happened.",
        "It uses a default route, the usual way through, to pinpoint the spots.",
        "If you went another way on a run, use Adjust Path at the top of the map to draw your own.",
    },
    ok = "Got it",
}
DungeonPage.TUTORIAL = { NOTE = NOTE, WORDS = WORDS }

-- The note, built the first time it is due, which on most logins is never.
local note

local function Build(spread)
    local host = CreateFrame("Frame", NOTE.name, spread)
    host:SetAllPoints(spread)
    host:SetFrameLevel(spread:GetFrameLevel() + NOTE.level)
    host:Hide()

    -- Quiet: the map's own rustle says it came out, and a click beside it
    -- does nothing (no onPutAway).
    local view, K = ns.UI.LooseSheet(host, NOTE.w, 300, { crease = CREASE, quiet = true })
    local S = view.sheet
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function() end)
    host.view = view

    host.title = Style.Text(S, FONT.page)
    host.title:SetText(WORDS.title)
    host.lines = {}
    host.ok = K.Link(FONT.strong, function() host:Hide() end)
    host.ok:SetText(WORDS.ok)

    -- Laid on the map's middle, as tall as the words wrap to on this client.
    function host:Lay()
        local M, width = NOTE.margin, NOTE.w - 2 * NOTE.margin
        local wrapped = {}
        for i, paragraph in ipairs(WORDS.paragraphs) do
            wrapped[i] = K.Wrap(paragraph, width, FONT.body)
        end
        local y, at, used = NOTE.body, {}, 0
        for i, lines in ipairs(wrapped) do
            if i > 1 then y = y + NOTE.gap end
            for _, line in ipairs(lines) do
                used = used + 1
                at[used] = { line, y }
                y = y + NOTE.line
            end
        end
        y = y - NOTE.line
        local H = y + NOTE.link + NOTE.foot
        self.h = H
        K.Reshape(NOTE.w, H)
        K.Fall("dungeonTutorial", nil, spread.map.lie)
        K.Lay()
        K.PlaceText(self.title, M, NOTE.title)
        for i, spot in ipairs(at) do
            local text = self.lines[i] or Style.Text(S, FONT.body)
            self.lines[i] = text
            text:SetText(spot[1])
            K.PlaceText(text, M, spot[2])
            text:Show()
        end
        for i = used + 1, #self.lines do self.lines[i]:Hide() end
        self.ok:PlaceAt(NOTE.w - M, y + NOTE.link, "RIGHT")
    end

    -- Put away on its own, the map stays out and Escape is the spread's
    -- again. With the spread (its OnHide, either order), Spread.lua's Gone
    -- gives Escape back to the book.
    host:SetScript("OnHide", function()
        if not spread:IsShown() then return end
        DungeonPage.StandIn(DungeonPage.SPREAD.name)
        Style.PlaySound("sheetClose")
    end)

    -- As the spread's (Spread.lua's Above), now everything on it is made.
    host:SetFrameStrata(DungeonPage.LAYER.strata)
    if host.SetFixedFrameStrata then host:SetFixedFrameStrata(true) end
    return host
end

-- The run is out on `spread`, its map laid: the note, if it has never been
-- shown. A dungeon the diary has no map of has nothing to explain: it waits
-- for a run that has one.
function DungeonPage.Tutorial(spread)
    if ns.Setting("dungeonTutorialSeen") or not spread.map.box then return end
    ns.SetSetting("dungeonTutorialSeen", true)
    note = note or Build(spread)
    note:Show()
    note:Lay()
    DungeonPage.StandIn(NOTE.name)
end

-- The map laid again under it (the screen changed): where the map lies now.
function DungeonPage.TutorialLay()
    if note and note:IsShown() then note:Lay() end
end

-- The spread going: hidden itself, as a child left shown would come back
-- with the next run.
function DungeonPage.TutorialGone()
    if note and note:IsShown() then note:Hide() end
end

-- The note, for the tests: nil until it has been due.
function DungeonPage.TutorialNote() return note end
