-- Someone you met, in words: see Kind.lua.

local addonName, ns = ...

local Met = ns.Met
local Text = ns.UI.JourneyText
local Capital, List, Short = Text.Capital, Text.List, Text.Short

-- Who the card names: a diary entry's current name, so a rename shows here as it
-- does on an automatic strip; else the name as written. Nil for nobody named.
function Met.Name(rec)
    local guid = Met.Guid(rec)
    return guid and Short(guid) or rec.who or nil
end

-- The strip's top line. An automatic strip's is "with Tester", or "with someone"
-- for a stranger (Text.MarginWho): the same, whether the name was picked or typed.
function Met.Who(rec)
    return "with " .. (Met.Name(rec) or "someone")
end

-- When the meetings were, and at what level, as every mark's tooltip on the
-- plates ends (the core's Text.Foot and Text.Moments, UI/Journey/Text/
-- Tips.lua): each time, a day said once for the times on it, past four
-- the first to the last, then the levels after a comma, "Today at 12:47
-- and 15:10, level 20", "Today from 12:47 to 19:02, levels 19 to 20".
-- The tames' tooltip says its times the same way, without the level.
local function Foot(ts, lo, hi, now)
    return Text.Foot({ times = ts, levelFrom = lo, levelTo = hi }, now)
end

-- The mark's tooltip: one account of every card on its spot (a list of one
-- for a lone card). Who, all of them named once, "With Old Tom", "With Old Tom
-- and Wenna", "With Old Tom and someone" (a stranger last); what happened, the
-- player's own lines, each once and each on its own line, with whose it was
-- where several are named ("Old Tom, fished off the pier", the menu's form,
-- Kind.lua's `describe`), and past three run on in one line; then when, and
-- at what level. A card with no line has none ("" is none).
function Met.Tips(recs, now)
    local names, seen, someone = {}, {}, false
    local whats, said = {}, {}
    local ts, lo, hi = {}, nil, nil
    for _, rec in ipairs(recs) do
        local name = Met.Name(rec)
        if not name then
            someone = true
        elseif not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
        ts[#ts + 1] = rec.t or 0
        local level = rec.level
        if level then
            lo = (not lo or level < lo) and level or lo
            hi = (not hi or level > hi) and level or hi
        end
    end
    if someone then names[#names + 1] = "someone" end
    for _, rec in ipairs(recs) do
        local what = rec.what
        if type(what) == "string" and what ~= "" then
            local line = #names > 1 and ((Met.Name(rec) or "someone") .. ", " .. what) or what
            if not said[line] then
                said[line] = true
                whats[#whats + 1] = line
            end
        end
    end
    local lines = whats
    if #whats > 3 then lines = { table.concat(whats, "; ") } end
    lines[#lines + 1] = Foot(ts, lo, hi, now)
    return "With " .. List(names), lines
end

-- One card's tooltip, as its mark's alone (Met.Tips).
function Met.Tip(rec, now)
    return Met.Tips({ rec }, now)
end

--------------------------------------------------------------------------
-- On a plate (Text.RegisterCaption)
--------------------------------------------------------------------------

-- As the core's people lead words a list of names.
local MOST = { max = 3, shown = 2, more = "others" }

-- The names no note beside the plate gives, and the words have not. said.met
-- holds the cards on strips ([record] = true, Strip.lua); said.named who any
-- strip names. A person who is also among the words' own people ("With Tester")
-- is not said twice.
local function Unsaid(list, c)
    local names, seen = {}, {}
    for _, rec in ipairs(list) do
        local guid = Met.Guid(rec)
        local onStrip = (c.said.met and c.said.met[rec]) or (guid and c.named[guid])
        local name = Met.Name(rec) or "someone"
        if not onStrip and not c.people[name] and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

-- Everyone on a strip, the words say what an automatic strip's plate says beside
-- its note: "In good company", further down the leads (`c.company`, read at 130).
-- Left off the margin, they are named as the people's lead names them, right
-- after it (15); or after it in the tail (5), first of all, where it led.
Text.RegisterCaption("met", {
    moment = "met",
    take = function(m) return m.met end,
    lead = { at = 15, say = function(list, c)
        local names = Unsaid(list, c)
        if names[1] then return "With " .. List(names, MOST) end
        c.company = c.company or "met"
        return nil
    end },
    tail = { at = 5, say = function(list, c)
        local names = Unsaid(list, c)
        return names[1] and ("with " .. List(names, MOST)) or nil
    end },
})
