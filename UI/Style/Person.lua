-- A person's pieces (Style, from UI/Style/Tokens.lua): the round
-- portrait, the heading on their page and loose sheet (Style.HEADING), a
-- dungeon run's medallion and its boss marks, a boss's portrait on a
-- dungeon's map, and the rubricated heading
-- the onboarding pages share. Loaded after UI/Style/Book.lua, whose brass
-- rings the medallions; the other widgets are in UI/Style/Widgets.lua.

local addonName, ns = ...

local Style = ns.Style
-- The cover's brass (UI/Style/Book.lua), for the medallions' rings.
local BRASS_LIGHT, BRASS_MID, BRASS_DARK = Style.BRASS_LIGHT, Style.BRASS_MID, Style.BRASS_DARK

local PORTRAIT_ZOOM = 1.4

-- Discs inside each other, outermost first, each { inset, { r, g, b } }, and
-- an icon in the last, cropped round by a mask. The icon is drawn `zoom`
-- times that disc, so art with its own border and padding overhangs and
-- loses them; without a mask it cannot overhang.
local function RoundFrame(frame, size, rings, zoom)
    local circle = Style.Art("circle")
    for i, ring in ipairs(rings) do
        local inset, color = ring[1], ring[2]
        local disc = frame:CreateTexture(nil, "BACKGROUND", nil, i - 1)
        disc:SetPoint("TOPLEFT", inset, -inset)
        disc:SetPoint("BOTTOMRIGHT", -inset, inset)
        Style.Disc(disc, color[1], color[2], color[3], 1)
    end

    local pad = rings[#rings][1] + 1
    local inner = size - 2 * pad
    local icon = frame:CreateTexture(nil, "ARTWORK")
    if circle and frame.CreateMaskTexture then
        local overhang = (inner * zoom - inner) / 2
        icon:SetPoint("TOPLEFT", pad - overhang, -pad + overhang)
        icon:SetPoint("BOTTOMRIGHT", -pad + overhang, pad - overhang)

        local mask = frame:CreateMaskTexture()
        mask:SetTexture(circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetPoint("TOPLEFT", pad, -pad)
        mask:SetPoint("BOTTOMRIGHT", -pad, pad)
        icon:AddMaskTexture(mask)
    else
        icon:SetPoint("TOPLEFT", pad, -pad)
        icon:SetPoint("BOTTOMRIGHT", -pad, pad)
    end
    return icon
end

-- A round, gold-trimmed portrait: the person's race icon, else class icon.
-- The race icons carry their own rounded frame and padding, hence the zoom.
function Style.Portrait(parent, size)
    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetSize(size, size)
    portrait.icon = RoundFrame(portrait, size, {
        { 0, { 0, 0, 0 } }, { 2, { 0.72, 0.58, 0.33 } }, { 4, { 0, 0, 0 } }, { 5, { 0.22, 0.15, 0.08 } },
    }, PORTRAIT_ZOOM)

    function portrait:SetCharacter(record)
        if Style.SetRaceIcon(self.icon, record) then return end
        if Style.SetClassIcon(self.icon, record and record.class) then return end
        Style.SetTexture(self.icon, "book", 0.3, 0.22, 0.12, 1)
        self.icon:SetTexCoord(unpack(Style.ICON_CROP))
    end

    return portrait
end

-- A person's heading, on their page in the journal and on the loose sheet:
-- the round portrait, their name in capitals beside it, and the "who" line
-- under the name. HEADING is its measure: the portrait, how far in the name
-- and who line start, the name line's height and the gap under it.
local HEADING_PORTRAIT = 56
Style.HEADING = { portrait = HEADING_PORTRAIT, indent = HEADING_PORTRAIT + 12, name = 28, gap = 4 }

-- Builds it on `parent`, `width` wide, keeping `right` free at the end of
-- the name line (for Edit, or the close button). The pieces go on `owner`
-- as owner.portrait, owner.name and owner.who: the sheet keeps them on its
-- panel, above the content frame they sit in.
function Style.PersonHeading(owner, parent, width, right)
    local H = Style.HEADING
    owner.portrait = Style.Portrait(parent, H.portrait)
    owner.portrait:SetPoint("TOPLEFT", -4, 4)

    owner.name = Style.Text(parent, Style.FONT.title)
    owner.name:SetPoint("TOPLEFT", H.indent, 0)
    owner.name:SetPoint("RIGHT", parent, "RIGHT", -right, 0)
    owner.name:SetHeight(H.name)
    owner.name:SetWordWrap(false)
    owner.nameRoom = width - right - H.indent

    owner.who = Style.Text(parent, Style.FONT.body)
    owner.who:SetPoint("TOPLEFT", owner.name, "BOTTOMLEFT", 0, -H.gap)
    owner.who:SetPoint("RIGHT", parent, "RIGHT")
    owner.who:SetWordWrap(false)
end

-- Fills the heading Style.PersonHeading put on `owner`. The name is set in
-- Morpheus capitals: its lowercase is hard to read ("Eatmorchikin"). A long
-- name steps down a size rather than lose its end.
function Style.SetPersonHeading(owner, record, name, who)
    owner.portrait:SetCharacter(record)
    owner.name:SetFontObject(Style.FONT.title)
    owner.name:SetText(name:upper())
    if owner.name:GetUnboundedStringWidth() > owner.nameRoom then
        owner.name:SetFontObject(Style.FONT.titleSmall)
    end
    owner.who:SetText(who)
end

-- A creature's face on `icon`: from its display (the client's 2D portrait
-- of it, cropped in to BOSS_FACE.crop, as Dungeon Crawler Forever does) or
-- else a portrait texture (a FileDataID). How it came ("display" or
-- "portrait"), or nil with neither, no client call for one, or a texture
-- the client would not set.
local BOSS_FACE = { crop = { 0.1, 0.9, 0.1, 0.9 }, faded = 0.55 }

local function SetFace(icon, display, portrait)
    if display and type(SetPortraitTextureFromCreatureDisplayID) == "function"
        and pcall(SetPortraitTextureFromCreatureDisplayID, icon, display) then
        icon:SetTexCoord(unpack(BOSS_FACE.crop))
        return "display"
    end
    if portrait and icon:SetTexture(portrait) ~= false then
        icon:SetTexCoord(0, 1, 0, 1)
        return "portrait"
    end
end

-- A dungeon run's medallion: the instance's own picture in a brass ring (gilt
-- for a raid), standing a little proud of the page, so it casts a small
-- shadow down and to the right. Without the picture (a Forever dungeon has
-- none; a file the client does not have sets nothing), the face it is
-- given (`face` = { display, portrait }: its last boss's, the caller's
-- choice), as the map's boss medallions show it; without either, the
-- name's initial as a drop cap in red, over the face, so it is never
-- hidden under it. `how` says which: "art", "face" or "initial".
local MEDALLION_RINGS = {
    party = { { 0, BRASS_DARK }, { 1, BRASS_MID }, { 3, BRASS_DARK } },
    raid = { { 0, BRASS_DARK }, { 1, { 0.86, 0.68, 0.36 } }, { 2, BRASS_LIGHT }, { 3, BRASS_DARK } },
}

function Style.Medallion(parent, size)
    local medallion = CreateFrame("Frame", nil, parent)
    medallion:SetSize(size, size)

    local circle = Style.Art("circle")
    local shadow = medallion:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetSize(size, size)
    shadow:SetPoint("CENTER", 1.5, -1.5)
    if circle then
        Style.Disc(shadow, Style.INK[1], Style.INK[2], Style.INK[3], 0.35)
    else
        shadow:Hide()
    end

    local faces = {}
    for kind, rings in pairs(MEDALLION_RINGS) do
        local face = CreateFrame("Frame", nil, medallion)
        face:SetAllPoints()
        face.icon = RoundFrame(face, size, rings, 1)
        face:Hide()
        faces[kind] = face
    end

    local cap = CreateFrame("Frame", nil, medallion)
    cap:SetAllPoints()
    cap:SetFrameLevel(medallion:GetFrameLevel() + 3)
    medallion.initial = Style.Text(cap, Style.FONT.title)
    medallion.initial:SetPoint("CENTER", 0, -1)
    medallion.initial:SetJustifyH("CENTER")
    medallion.initial:SetTextColor(Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3])

    function medallion:SetVisit(visit, face)
        local kind = visit.instanceType == "raid" and "raid" or "party"
        for k, f in pairs(faces) do f:SetShown(k == kind) end
        local icon, path = faces[kind].icon, Style.InstanceArt(visit)
        icon:SetVertexColor(1, 1, 1, 1)
        if path and icon:SetTexture(path) ~= false then
            icon:SetTexCoord(0, 1, 0, 1)
            self.how = "art"
        elseif face and SetFace(icon, face.display, face.portrait) then
            self.how = "face"
        else
            icon:SetColorTexture(Style.PAPER[1] * 0.92, Style.PAPER[2] * 0.92, Style.PAPER[3] * 0.92, 1)
            local name = (visit.name or "?"):gsub("^The ", "")
            self.initial:SetText(name:sub(1, 1):upper())
            self.how = "initial"
        end
        self.initial:SetShown(self.how == "initial")
    end

    return medallion
end

-- A boss's portrait on a dungeon's map (UI/Dungeon/Print.lua): the face
-- round in a ring that says how the run left it. "killed" in the
-- medallions' brass, standing a little proud of the print with its shadow;
-- "rare" the same in silver, for a rare that was killed; "standing" flat
-- in a ring of pencil, the face greyed and faded: still there. Each ring's
-- middle has a colour of its own (deep red, slate, the print's stock), so
-- a face slow to come never leaves a hole. :SetBoss(look, display,
-- portrait) shows the face from a creature display (the client's 2D
-- portrait of it, cropped in, as Dungeon Crawler Forever does) or else a
-- portrait texture (a FileDataID), and returns how ("display" or
-- "portrait"), or nil with neither or no client call for one: the caller
-- marks the boss plainer then.
local SILVER_LIGHT, SILVER_MID, SILVER_DARK = { 0.90, 0.90, 0.87 }, { 0.64, 0.64, 0.63 }, { 0.24, 0.24, 0.26 }
local BOSS_RINGS = {
    killed = { { 0, BRASS_DARK }, { 0.8, BRASS_MID }, { 2, BRASS_DARK }, { 2.5, { 0.36, 0.09, 0.05 } } },
    rare = { { 0, SILVER_DARK }, { 0.8, SILVER_MID }, { 1.4, SILVER_LIGHT }, { 2, SILVER_DARK },
        { 2.5, { 0.20, 0.22, 0.27 } } },
    standing = { { 0, Style.GRAPHITE }, { 1, { 0.90, 0.85, 0.70 } } },
}
-- A face (SetFace, above, and its BOSS_FACE): still standing, it is
-- greyed and drawn at BOSS_FACE.faded.

function Style.BossMedallion(parent, size)
    local medallion = CreateFrame("Frame", nil, parent)
    medallion:SetSize(size, size)

    local circle = Style.Art("circle")
    local shadow = medallion:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetSize(size, size)
    shadow:SetPoint("CENTER", 1.2, -1.2)
    if circle then Style.Disc(shadow, Style.INK[1], Style.INK[2], Style.INK[3], 0.4) end

    local faces = {}
    for look, rings in pairs(BOSS_RINGS) do
        local face = CreateFrame("Frame", nil, medallion)
        face:SetAllPoints()
        face.icon = RoundFrame(face, size, rings, 1)
        face:Hide()
        faces[look] = face
    end

    function medallion:SetBoss(look, display, portrait)
        for k, face in pairs(faces) do face:SetShown(k == look) end
        shadow:SetShown(circle ~= nil and look ~= "standing")
        local icon = faces[look].icon
        local how = SetFace(icon, display, portrait)
        icon:SetDesaturated(look == "standing")
        icon:SetAlpha(look == "standing" and BOSS_FACE.faded or 1)
        self.look, self.face, self.icon = look, how, icon
        return how
    end

    return medallion
end

-- Bosses as marks: a small turned square each, filled in red for a kill and
-- left as an outline for the rest. At most `max`; the tooltip counts past
-- that. Returns how wide the marks came out.
local PIP, PIP_STEP = 7, 11

-- How wide `killed` of `total` bosses come out as marks, at most `max`
-- (what pips:Set returns), for what lays them out before drawing them.
function Style.PipsWidth(killed, total, max)
    local n = math.min(math.max(total or 0, killed or 0), max)
    return n > 0 and (n - 1) * PIP_STEP + PIP + 2 or 0
end

function Style.Pips(parent, max)
    local pips = CreateFrame("Frame", nil, parent)
    pips:SetHeight(PIP + 4)
    local marks = {}
    for i = 1, max do
        local outer = pips:CreateTexture(nil, "ARTWORK", nil, 0)
        outer:SetSize(PIP, PIP)
        outer:SetPoint("CENTER", pips, "LEFT", PIP / 2 + 1 + (i - 1) * PIP_STEP, 0)
        outer:SetRotation(math.pi / 4)
        local inner = pips:CreateTexture(nil, "ARTWORK", nil, 1)
        inner:SetSize(PIP - 3, PIP - 3)
        inner:SetPoint("CENTER", outer)
        inner:SetRotation(math.pi / 4)
        inner:SetColorTexture(Style.PAPER[1], Style.PAPER[2], Style.PAPER[3], 1)
        marks[i] = { outer = outer, inner = inner }
    end

    function pips:Set(killed, total)
        local n = math.min(math.max(total or 0, killed), max)
        for i, mark in ipairs(marks) do
            local shown, kill = i <= n, i <= killed
            mark.outer:SetShown(shown)
            mark.inner:SetShown(shown and not kill)
            if kill then
                mark.outer:SetColorTexture(Style.RUBRIC[1], Style.RUBRIC[2], Style.RUBRIC[3], 1)
            else
                mark.outer:SetColorTexture(Style.INK[1], Style.INK[2], Style.INK[3], 0.55)
            end
        end
        local width = n > 0 and (n - 1) * PIP_STEP + PIP + 2 or 0
        self:SetWidth(math.max(width, 1))
        return width
    end

    return pips
end

-- A heading rubricated like a day on the timeline: a paraph (lapis or red),
-- the words in red capitals, and a red rule out to `width`, fading as it
-- goes. For the onboarding pages' sections (UI/Journal/Front.lua,
-- UI/Journal/Empty.lua). :SetText(text, lapis) sets the words and the
-- paraph's colour.
local RUBRIC = { height = 16, paraph = 6, indent = 13, gap = 6, ruleAlpha = 0.40 }

function Style.Rubric(parent, width)
    local heading = CreateFrame("Frame", nil, parent)
    heading:SetSize(width, RUBRIC.height)

    heading.text = Style.Text(heading, Style.FONT.headingRubric)
    heading.text:SetPoint("LEFT", RUBRIC.indent, 0)

    heading.paraph = heading:CreateTexture(nil, "ARTWORK")
    heading.paraph:SetSize(RUBRIC.paraph, RUBRIC.paraph)
    heading.paraph:SetRotation(math.pi / 4)
    heading.paraph:SetPoint("CENTER", heading.text, "LEFT", -RUBRIC.indent / 2 - 1, 0)

    local rule = heading:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", heading.text, "RIGHT", RUBRIC.gap, 0)
    rule:SetPoint("RIGHT", heading, "RIGHT")
    local R = Style.RUBRIC
    Style.Shade(rule, "HORIZONTAL", R[1], R[2], R[3], RUBRIC.ruleAlpha, 0)

    function heading:SetText(text, lapis)
        self.text:SetText(text:upper())
        local colour = lapis and Style.LAPIS or Style.RUBRIC
        self.paraph:SetColorTexture(colour[1], colour[2], colour[3], 1)
    end

    return heading
end
