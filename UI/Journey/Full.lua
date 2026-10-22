-- A zone's whole map across Your Diary's right page (JRN-14): one plate
-- the zone's height, centred on the open level's road (RoadMiddle), looked
-- at closer by the wheel and dragged (FULLZOOM, UI/Journey/Plate.lua), a
-- click on it the way back (Back); and the line under it, the zone's name,
-- who was met and how many fights (Company, Text.ZoneFoot) and the hint.
--
-- The module and its siblings: UI/Journey/Look.lua.

local addonName, ns = ...

local Style = ns.Style
local Text = ns.UI.JourneyText
local Plate = ns.UI.JourneyPlate
local YourDiary = ns.UI.YourDiary

local BOOK = ns.UI.Journal.BOOK
local RIGHT_W = BOOK.RIGHT_W

local FULL, FOOT = YourDiary.FULL, YourDiary.FOOT
local ArtSize, SheetOf, MomentsOf, PlateAt = YourDiary.ArtSize, YourDiary.SheetOf, YourDiary.MomentsOf, YourDiary.PlateAt

-- The middle of everything on a zone's road: where the full page centres.
local function RoadMiddle(sheet)
    local lx, hx, ly, hy = math.huge, -math.huge, math.huge, -math.huge
    local function Take(x, y)
        if x and y then
            lx, hx, ly, hy = math.min(lx, x), math.max(hx, x), math.min(ly, y), math.max(hy, y)
        end
    end
    for _, seg in ipairs(sheet.stops) do Take(seg.x, seg.y) end
    for _, road in ipairs(sheet.roads) do
        local pts = ns.Journey.Points(road)
        for k = 1, #pts - 1, 2 do Take(pts[k], pts[k + 1]) end
    end
    for _, seg in ipairs(sheet.dungeons) do Take(seg.x, seg.y) end
    if lx > hx then return 0.5, 0.5 end
    return (lx + hx) / 2, (ly + hy) / 2
end

-- Back from the full page to the level's plates: a click on the map.
local function Back()
    local page = YourDiary.page
    Style.PlaySound("pageTurn")
    YourDiary.OpenLevel(page.open)
end

-- The full page's plate drawn at a view (FULLZOOM, UI/Journey/Plate.lua):
-- `f` px on the screen a px of the map's art, round cx, cy; nil for the
-- fitted view (the zone's whole height, centred on the road). The window
-- is drawn with the whole zone round it, so a drag never runs off the art.
local function DrawFullPlate(e, view)
    local page = YourDiary.page
    local mapID = page.fullMap
    local plate = PlateAt(1)
    plate:SetSlot(FULL)
    local sheet = SheetOf(mapID)
    local aw, ah = ArtSize(FULL)
    local LW, LH = Plate.LayerSize(mapID)
    local rx, ry = RoadMiddle(sheet)
    local fit = Plate.Window(mapID, rx, ry, aw, ah, true)
    local f0, c0 = ah / ((fit[4] - fit[2]) * LH), { (fit[1] + fit[3]) / 2, (fit[2] + fit[4]) / 2 }
    local f, cx, cy = f0, c0[1], c0[2]
    if view then f, cx, cy = view.f, view.cx, view.cy end
    local window, box = Plate.Frame(mapID, f, cx, cy, aw, ah, FULL.pad, Plate.FULLZOOM.overscan)
    plate:Draw(sheet, e, window, { moments = MomentsOf(e), cap = 1, fights = page.fights,
        witnesses = page.witnesses, now = page.now, box = box })
    plate.share, plate.plan = 1, nil
    plate:SetClick(Back, false)
    plate:Look({ f = f, cx = cx, cy = cy, fit = f0, c0 = c0, LW = LW, LH = LH,
        redraws = view and view.redraws,
        onSettle = function(nf, ncx, ncy)
            DrawFullPlate(e, { f = nf, cx = ncx, cy = ncy,
                redraws = plate.look and plate.look.redraws })
        end })
    plate:Show()
    return plate, sheet
end

-- The diary people met on a zone, by their short names (not rivals), and
-- its fights: the full page's line (Text.ZoneFoot).
local function Company(sheet)
    local names, seen, fights = {}, {}, 0
    local function Add(guid)
        if not guid or seen[guid] or not ns.Diary.IsDiary(guid) then return end
        seen[guid] = true
        for _, tag in ipairs(ns.db.diary[guid].tags or {}) do
            if tag == "foe" then return end
        end
        local name = Text.Short(guid)
        if name then names[#names + 1] = name end
    end
    for _, m in ipairs(sheet.meetings) do
        if m.kind == "session" then
            local guids = {}
            for guid in pairs(m.session.participants or {}) do guids[#guids + 1] = guid end
            table.sort(guids)
            for _, guid in ipairs(guids) do Add(guid) end
        elseif m.kind == "note" then
            for guid in pairs(m.note.about or {}) do Add(guid) end
        elseif m.kind == "fight" then
            fights = fights + 1
        end
    end
    return names, fights
end

-- One zone's whole map across the page (JRN-14), the open level's road.
local function DrawFull(e)
    local page = YourDiary.page
    local mapID = page.fullMap
    local _, sheet = DrawFullPlate(e)
    page.layout = "full"

    local z
    for _, zone in ipairs(page.recap.zones) do
        if zone.mapID == mapID then z = zone end
    end
    local foot = page.foot
    foot.name:SetText((z and Text.ZoneName(z) or ns.MapName(mapID) or ("Map " .. mapID)):upper())
    local names, fights = Company(sheet)
    foot.meta:SetText(z and Text.ZoneFoot(z, names, fights) or "Nothing of your road is on this map yet.")
    -- On one line where it fits, else the line under the name; the hint
    -- under them both.
    local nameW = foot.name:GetUnboundedStringWidth() or 0
    local metaW = foot.meta:GetUnboundedStringWidth() or 0
    foot.meta:ClearAllPoints()
    foot.hint:ClearAllPoints()
    if 12 + nameW + FOOT.gap + metaW <= RIGHT_W - 10 then
        foot.meta:SetPoint("BOTTOMLEFT", foot.name, "BOTTOMRIGHT", FOOT.gap, 2)
        foot.hint:SetPoint("TOPLEFT", foot.name, "BOTTOMLEFT", 0, -FOOT.hint)
    else
        foot.meta:SetPoint("TOPLEFT", foot.name, "BOTTOMLEFT", 0, -FOOT.under)
        foot.hint:SetPoint("TOPLEFT", foot.meta, "BOTTOMLEFT", 0, -FOOT.hint)
    end
    for _, part in pairs({ foot.name, foot.meta, foot.hint }) do part:Show() end
    return 1
end

YourDiary.DrawFull = DrawFull
