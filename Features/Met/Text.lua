-- Someone you met, in words: see Kind.lua.

local addonName, ns = ...

local Met = ns.Met
local Text = ns.UI.JourneyText
local List, Short, When = Text.List, Text.Short, Text.When

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

-- The mark's tooltip, as a meeting's reads (Text.Meeting): who, what, when.
function Met.Tip(rec, now)
    local lines = {}
    if rec.what then lines[1] = rec.what end
    lines[#lines + 1] = When(rec.t, rec.level, now)
    return "With " .. (Met.Name(rec) or "someone"), lines
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
