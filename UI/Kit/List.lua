-- The virtual list and its scrollbar, pencilled down the page's margin.
-- Its siblings: Panel, Label and Button (UI/Kit/Chrome.lua), the text
-- helpers (UI/Words/Format.lua).

local addonName, ns = ...

--------------------------------------------------------------------------
-- The virtual list (JNL-6)
--------------------------------------------------------------------------
--
-- A fixed pool of row frames over an array of any length: scrolling moves an
-- offset and rewrites the visible rows, so 10,000 timeline items cost the
-- same frames as ten. Hand-rolled rather than Blizzard's ScrollBox for the
-- reason at the top of UI/Kit/Chrome.lua, and because this build's
-- templates are unverified where plain widgets are not.
--
-- `build(list, index)` makes one row; `update(row, item)` fills it.

local SCROLLBAR_WIDTH = 12
ns.UI.SCROLLBAR_WIDTH = SCROLLBAR_WIDTH  -- for column headings that line up with rows

-- The scrollbar, as something of the book's rather than the screen's: a
-- line pencilled down the page's margin, and riding on it a thumb index,
-- a small tab of leather like the ones cut into a ledger's fore-edge,
-- lit from the top left as everything in the book is.
--
-- `track`: the pencil line, `width` px, centred in the bar's
-- SCROLLBAR_WIDTH (which stays the bar's whole width, to take the mouse);
-- its pressure uneven down its length, alpha `top`, `middle`, `bottom`,
-- as a hand rules a line, fading at both ends over `fade` px.
-- `tab`: the leather, `w` x `h` px, centred on the line; its hold on the
-- mouse is the bar's whole width and `grab` px taller. Its colour is the
-- one SetBarColors gives, `lit` lighter at the top and `shade` darker at
-- the bottom; a `light` px edge catches the light on its top and left
-- (alpha `lightAlpha`), a dark edge falls on its bottom and right
-- (`darkAlpha`); `grooves` tooled lines pressed across it, `groove` px
-- apart, each a dark lip over a light one, the grip. Under the mouse its
-- lit edge brightens to `hotAlpha`. It casts a shadow on the page `cast`
-- px down and to the right at `castAlpha`.
-- Flat paper only (the flatSheets setting): a plain tab, no shading,
-- edges, grooves or shadow.
local SCROLLBAR = {
    track = { width = 1, top = 0.22, middle = 0.42, bottom = 0.30, fade = 10 },
    tab = { w = 9, h = 26, grab = 4, lit = 1.25, shade = 0.70, light = 1, lightAlpha = 0.35, darkAlpha = 0.45,
        grooves = 2, groove = 4, hotAlpha = 0.6, cast = 1.5, castAlpha = 0.22 },
}
ns.UI.SCROLLBAR = SCROLLBAR

-- A colour scaled toward black or white by `k`, as { r, g, b, a }.
local function Tone(c, k, a)
    local function One(x) return math.max(0, math.min(1, x * k)) end
    return { One(c[1]), One(c[2]), One(c[3]), a }
end

-- A gradient down a texture, `top` to `bottom`; the Style files' where
-- they have loaded (they load after this one), else a flat average.
local function Down(texture, top, bottom)
    if ns.Style and ns.Style.Gradient then
        ns.Style.Gradient(texture, "VERTICAL", bottom, top)
    else
        texture:SetColorTexture((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2,
            (top[4] + bottom[4]) / 2)
    end
end

-- The pencil line and the leather tab on `bar`, coloured by `pencil` and
-- `leather` ({ r, g, b, a }; only their colour is taken, SCROLLBAR holds
-- the rest). Returns the thumb texture (the tab's hold on the mouse), a
-- function to colour it, one to paint it again (flat or not), and its
-- parts (for the tests).
local function BookScrollbar(bar)
    local T, B = SCROLLBAR.track, SCROLLBAR.tab
    local pencil, leather = { 0.24, 0.16, 0.07 }, { 0.45, 0.31, 0.14 }

    local upper = bar:CreateTexture(nil, "BACKGROUND")
    upper:SetWidth(T.width)
    upper:SetPoint("TOP", bar, "TOP", 0, 0)
    upper:SetPoint("BOTTOM", bar, "CENTER", 0, 0)
    local lower = bar:CreateTexture(nil, "BACKGROUND")
    lower:SetWidth(T.width)
    lower:SetPoint("TOP", bar, "CENTER", 0, 0)
    lower:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    local capTop = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    capTop:SetSize(T.width, T.fade)
    capTop:SetPoint("TOP", bar, "TOP", 0, 0)
    local capBottom = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    capBottom:SetSize(T.width, T.fade)
    capBottom:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

    -- The thumb the slider moves: clear, the bar's width, the tab on it.
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0, 0, 0, 0)
    thumb:SetSize(SCROLLBAR_WIDTH, B.h + B.grab)
    bar:SetThumbTexture(thumb)

    local cast = bar:CreateTexture(nil, "ARTWORK", nil, 0)
    cast:SetSize(B.w, B.h)
    cast:SetPoint("CENTER", thumb, "CENTER", B.cast, -B.cast)
    local body = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    body:SetSize(B.w, B.h)
    body:SetPoint("CENTER", thumb, "CENTER", 0, 0)
    local function Edge(sublevel, a, b, w, h)
        local t = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)
        t:SetPoint(a, body, a)
        t:SetPoint(b, body, b)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        return t
    end
    local lightTop = Edge(3, "TOPLEFT", "TOPRIGHT", nil, B.light)
    local lightLeft = Edge(3, "TOPLEFT", "BOTTOMLEFT", B.light, nil)
    local darkBottom = Edge(2, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    local darkRight = Edge(2, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    local grooves = {}
    for i = 1, B.grooves do
        local y = (i - (B.grooves + 1) / 2) * B.groove
        local dark = bar:CreateTexture(nil, "ARTWORK", nil, 4)
        dark:SetSize(B.w - 4, 1)
        dark:SetPoint("CENTER", body, "CENTER", 0, y + 0.5)
        local light = bar:CreateTexture(nil, "ARTWORK", nil, 4)
        light:SetSize(B.w - 4, 1)
        light:SetPoint("CENTER", body, "CENTER", 0, y - 0.5)
        grooves[#grooves + 1] = { dark, light }
    end

    local hot = false
    local function Paint()
        local flat = ns.Setting and ns.Setting("flatSheets") == true
        local p = pencil
        Down(upper, { p[1], p[2], p[3], T.top }, { p[1], p[2], p[3], T.middle })
        Down(lower, { p[1], p[2], p[3], T.middle }, { p[1], p[2], p[3], T.bottom })
        -- The line fades in and out at its ends, over the page's colour.
        Down(capTop, { p[1], p[2], p[3], 0 }, { p[1], p[2], p[3], T.top })
        Down(capBottom, { p[1], p[2], p[3], T.bottom }, { p[1], p[2], p[3], 0 })
        upper:SetPoint("TOP", bar, "TOP", 0, -T.fade)
        lower:SetPoint("BOTTOM", bar, "BOTTOM", 0, T.fade)

        local l = leather
        if flat then
            body:SetColorTexture(l[1], l[2], l[3], 1)
        else
            Down(body, Tone(l, B.lit, 1), Tone(l, B.shade, 1))
        end
        local lit = hot and B.hotAlpha or B.lightAlpha
        for _, t in ipairs({ lightTop, lightLeft }) do
            t:SetColorTexture(1, 0.93, 0.78, lit)
            t:SetShown(not flat)
        end
        for _, t in ipairs({ darkBottom, darkRight }) do
            t:SetColorTexture(0.08, 0.05, 0.02, B.darkAlpha)
            t:SetShown(not flat)
        end
        for _, g in ipairs(grooves) do
            g[1]:SetColorTexture(0.08, 0.05, 0.02, B.darkAlpha)
            g[2]:SetColorTexture(1, 0.93, 0.78, B.lightAlpha * 0.7)
            g[1]:SetShown(not flat)
            g[2]:SetShown(not flat)
        end
        cast:SetColorTexture(0.08, 0.05, 0.02, B.castAlpha)
        cast:SetShown(not flat)
    end

    -- Under the mouse, the tab's lit edge brightens: it is there to take.
    bar:SetScript("OnEnter", function() hot = true Paint() end)
    bar:SetScript("OnLeave", function() hot = false Paint() end)
    bar:SetScript("OnShow", Paint)

    local function Colour(track, tab)
        if track then pencil = track end
        if tab then leather = tab end
        Paint()
    end
    Paint()
    return thumb, Colour, Paint, { body = body, cast = cast, line = upper, lit = lightTop, grooves = grooves }
end

--
-- `numRows` rows are built up front; SetNumRows shows fewer of them, for a
-- list whose space depends on what sits above it.

function ns.UI.VirtualList(parent, rowHeight, numRows, build, update)
    local list = CreateFrame("Frame", nil, parent)
    list:SetHeight(rowHeight * numRows)
    list.rows, list.data, list.offset = {}, {}, 0
    local maxRows = numRows

    for i = 1, numRows do
        local row = build(list, i)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetPoint("RIGHT", list, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
        list.rows[i] = row
    end

    local bar = CreateFrame("Slider", nil, list)
    bar:SetWidth(SCROLLBAR_WIDTH)
    bar:SetPoint("TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:EnableMouse(true)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local thumb, colour, paint, parts = BookScrollbar(bar)
    list.bar, list.thumb, list.barParts = bar, thumb, parts

    -- The pencil's and the leather's colours, each as { r, g, b, a } (the
    -- alpha is SCROLLBAR's own): the book's ink and a leather brown by
    -- default.
    function list:SetBarColors(trackColor, thumbColor)
        colour(trackColor, thumbColor)
    end

    -- An item may set its own height (`item.height`): shorter for spacing,
    -- taller for an entry that needs room. The list shows the items that fit
    -- in numRows rows' worth of height, so a tall one means fewer below it
    -- and a short one more, up to the rows built.
    local function HeightOf(item)
        return item.height or rowHeight
    end

    -- Smooth (list:SetSmooth): scrolled by the pixel, not by the item, in a
    -- list `smooth` px tall that cuts off what lies past its edges, so a
    -- tall item slides away under whatever lies over the list's top (the
    -- person's page: its timeline under the clipped name sheet, the
    -- person-page proposal, variant A, round 2). `pos` is how far down it
    -- is scrolled, `tops[i]` where item i starts, `total` all of them;
    -- `offset` stays the number of items before the first one shown, so
    -- SetOffset(n) still scrolls to item n + 1.
    local smooth, tops, total = nil, {}, 0
    list.pos = 0

    local function Measure()
        tops, total = {}, 0
        for i = 1, #list.data do
            tops[i] = total
            total = total + HeightOf(list.data[i])
        end
    end
    local function MaxPos()
        return math.max(0, math.floor(total - smooth + 0.5))
    end
    -- The first item whose foot lies below `pos`.
    local function FirstAt(pos)
        local lo, hi = 1, #list.data
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if tops[mid] + HeightOf(list.data[mid]) <= pos then lo = mid + 1 else hi = mid end
        end
        return lo
    end

    -- Scrolled all the way down, the last items fill the list: the offset
    -- is however many come before the ones that fit.
    local function MaxOffset()
        local room, used, i = rowHeight * numRows, 0, #list.data
        while i >= 1 and used + HeightOf(list.data[i]) <= room do
            used = used + HeightOf(list.data[i])
            i = i - 1
        end
        return math.max(i, 0)
    end

    -- Smooth: the items from the one at `pos`, the first a part of it cut
    -- off above the list's top, until the list's foot.
    local function RefreshSmooth(self)
        local first = #self.data > 0 and FirstAt(self.pos) or 1
        self.offset = first - 1
        local y = (tops[first] or 0) - self.pos
        for i = 1, maxRows do
            local row = self.rows[i]
            local item = self.data[first + i - 1]
            if item and y < smooth then
                local height = HeightOf(item)
                row:SetHeight(height)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", self, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
                y = y + height
                row.item = item
                update(row, item)
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
    end

    function list:Refresh()
        if smooth then return RefreshSmooth(self) end
        local y, room, full = 0, rowHeight * numRows, false
        for i = 1, maxRows do
            local row = self.rows[i]
            local item = self.data[self.offset + i]
            if item and (full or y + HeightOf(item) > room) then
                full, item = true, nil
            end
            if item then
                local height = HeightOf(item)
                row:SetHeight(height)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", self, "RIGHT", -SCROLLBAR_WIDTH - 2, 0)
                y = y + height
                row.item = item
                update(row, item)
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
    end

    -- Smooth: scrolled `pos` px down, within what there is.
    function list:SetPosition(pos)
        pos = math.max(0, math.min(math.floor(pos + 0.5), MaxPos()))
        if pos == self.pos and self.shownOnce then return end
        self.pos, self.shownOnce = pos, true
        if bar:GetValue() ~= pos then bar:SetValue(pos) end
        self:Refresh()
    end

    function list:SetOffset(offset)
        if smooth then
            local n = math.max(0, math.floor(offset + 0.5))
            return self:SetPosition(tops[n + 1] or total)
        end
        offset = math.max(0, math.min(math.floor(offset + 0.5), MaxOffset()))
        if offset == self.offset and self.shownOnce then return end
        self.offset, self.shownOnce = offset, true
        if bar:GetValue() ~= offset then bar:SetValue(offset) end
        self:Refresh()
    end

    -- `keep` holds the scroll position, for refreshes that are not a new list.
    function list:SetData(data, keep)
        self.data = data or {}
        paint()
        if smooth then
            Measure()
            bar:SetMinMaxValues(0, MaxPos())
            bar:SetShown(MaxPos() > 0)
            self.shownOnce = false
            self:SetPosition(keep and self.pos or 0)
            return
        end
        bar:SetMinMaxValues(0, MaxOffset())
        bar:SetShown(MaxOffset() > 0)
        self.shownOnce = false
        self:SetOffset(keep and self.offset or 0)
    end

    -- Scrolled by the pixel from now on, `height` px tall, what lies past
    -- its top and foot cut off (Smooth, above). Call before SetData; the
    -- rows built stay the most it shows.
    function list:SetSmooth(height)
        smooth = height
        self:SetHeight(height)
        self:SetClipsChildren(true)
        self.smooth = height
    end

    -- Call before SetData. Never more than were built.
    function list:SetNumRows(n)
        numRows = math.max(1, math.min(n, maxRows))
        self.numRows = numRows
        -- A smooth list keeps the height it was given.
        if not smooth then self:SetHeight(rowHeight * numRows) end
    end
    list.numRows = numRows

    bar:SetScript("OnValueChanged", function(_, value)
        if smooth then list:SetPosition(value) else list:SetOffset(value) end
    end)

    -- Rows take the mouse (clicks, tooltips), so they pass the wheel on rather
    -- than rely on it reaching the list underneath. A notch is three rows'
    -- worth, by the item or (smooth) by the pixel.
    local function Wheel(_, delta)
        if smooth then
            list:SetPosition(list.pos - delta * 3 * rowHeight)
        else
            list:SetOffset(list.offset - delta * 3)
        end
    end
    list.Wheel = Wheel
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", Wheel)
    for i = 1, maxRows do
        list.rows[i]:EnableMouseWheel(true)
        list.rows[i]:SetScript("OnMouseWheel", Wheel)
    end

    return list
end
