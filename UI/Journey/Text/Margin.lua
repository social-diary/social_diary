-- What a person's margin note says in Your Diary (ns.UI.JourneyText): who
-- it is with (Text.MarginWho) and what happened with them on the plate
-- (Text.MarginWhat). Their note's quote is UI/Journey/Text/Notes.lua's; a
-- feature's card writes its own words (Features/<Name>/).
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local Glue, Duration, NUMBER, Short = Text.Glue, Text.Duration, Text.NUMBER, Text.Short
local L, Fmt = ns.L, ns.Fmt

-- What happened with one person on one plate, for their margin note:
-- "35 min together and a note", "killed you", "first seen, and you'd meet
-- again at level 4". A stranger's note has only fights (JRN-22). The
-- short phrases are held together by no-break spaces as a time is ("a
-- note", "killed you"), so a strip's last line is never "note" alone
-- (10 Oct, in the client: "3 h 20 min together and a / note"); the strip
-- balances its lines as well (UI/Paper/Strip.lua's STRIP.balance). Where
-- the strip quotes their note (Text.MarginQuote), the quote says it: no
-- "a note", only the others counted ("35 min together and one more note").
function Text.MarginWhat(moments, level)
    local parts, together, notes = {}, 0, 0
    for _, m in ipairs(moments) do
        if m.kind == "session" then together = together + (m.seconds or 0)
        elseif m.kind == "note" then notes = notes + 1 end
    end
    local quoted = notes > 0 and Text.MarginQuote(moments) ~= nil
    if quoted then notes = notes - 1 end
    -- A feature's moment that is this person's too (its `person`, Core/
    -- JourneyRecap.lua's RegisterMoment: say, something they gave you)
    -- first: a strip keeps STRIP.lines lines and cuts the rest, and that
    -- is what this person is remembered by here.
    for _, m in ipairs(moments) do
        if m.person and m.person.say then parts[#parts + 1] = m.person.say(m) end
    end
    if together > 0 then
        parts[#parts + 1] = Fmt(L["%s together"], together >= 60 and Duration(together) or L["a moment"])
    end
    if notes > 0 and quoted then
        parts[#parts + 1] = Glue(ns.Plural(notes, L["one more note|%s more notes##plural"], NUMBER[notes] or notes))
    elseif notes > 0 then
        parts[#parts + 1] = Glue(ns.Plural(notes, L["a note|%s notes##plural"], NUMBER[notes] or notes))
    end
    for _, m in ipairs(moments) do
        if m.kind == "fight" then
            if m.outcome == "lost" then
                parts[#parts + 1] = m.guid and Glue(L["killed you"]) or L["a fight, lost"]
            else
                parts[#parts + 1] = m.guid and L["you won the fight"] or L["a fight, won"]
            end
        end
    end
    for _, m in ipairs(moments) do
        if m.kind == "first" then
            local again = m.metLevel and level and m.metLevel > level
                and Fmt(L["you'd meet again at level %d"], m.metLevel) or L["you'd meet again"]
            parts[#parts + 1] = Fmt(L["first seen, and %s"], again)
        end
    end
    -- Each part after the one before, as one whole phrase: "35 min
    -- together and a note and killed you".
    local text = parts[1]
    for i = 2, #parts do text = Fmt(L["%1$s and %2$s"], text, parts[i]) end
    return text or ""
end

-- The name a margin note is headed by, so the note reads as who you were
-- with: "with Koko", or "with someone" for a stranger whose name the
-- buffer no longer has.
function Text.MarginWho(guid)
    local name = guid and Short(guid)
    if not name then return L["with someone"] end
    return Fmt(L["with %s"], name)
end
