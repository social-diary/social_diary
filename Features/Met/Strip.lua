-- Someone you met, in the margin: see Kind.lua.

local addonName, ns = ...

local Met = ns.Met
local YourDiary = ns.UI.YourDiary

-- Each card on the plate, newest first, so where the margin runs out it is the
-- oldest that is left to its mark and the caption.
local function Items(plate)
    local items = {}
    for _, mark in ipairs(plate.metMarks or {}) do
        for _, m in ipairs(mark.list or {}) do
            items[#items + 1] = { rec = m.met, mark = mark.at, top = mark.at[2], x = mark.at[1] }
        end
    end
    table.sort(items, function(a, b) return (a.rec.t or 0) > (b.rec.t or 0) end)
    return items
end

-- A strip of the people's own pool, so it is one by construction: the same
-- SetNote and the same seed's shape as MarginNote's. Margin order 2: before
-- every automatic person (10), past whatever picks one card a plate, and with
-- nothing replacing it, as the custom cards' rule asks.
ns.UI.JourneyMargin.Register("met", {
    order = 2, pool = "notePool", count = "metWritten", personLike = true,
    new = function() return YourDiary.NewNote() end,
    items = Items,
    write = function(strip, it, c)
        local rec = it.rec
        local guid = Met.Guid(rec)
        local what = rec.what or ""
        strip:SetNote({ name = Met.Who(rec), what = what, guid = guid, rival = YourDiary.Rival(guid),
            onClick = c.ToPerson,
            -- A line longer than the strip's three lines keeps the rest here, as
            -- a quote cut short does.
            tip = function()
                if strip:What() == what then return nil end
                return { { what, 1, 1, 1, true } }
            end,
            seed = c.Seed(guid or Met.Name(rec) or "someone", rec.t) })
    end,
    mark = function(it) return it.mark end,
    custom = function(it) return "met", it.rec end,
    -- Told who its strips name, so the words do not name them again; said.met,
    -- the cards themselves, since a typed name has no GUID to go by.
    assume = function(said, plate)
        said.met = {}
        for _, it in ipairs(Items(plate)) do
            said.met[it.rec] = true
            local guid = Met.Guid(it.rec)
            if guid then said.named[guid] = true end
        end
    end,
    say = function(said, shown)
        said.met = {}
        for _, it in ipairs(shown) do
            said.met[it.rec] = true
            local guid = Met.Guid(it.rec)
            if guid then said.named[guid] = true end
        end
    end,
})
