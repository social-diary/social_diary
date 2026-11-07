-- The player's own words in Your Diary (ns.UI.JourneyText): cleaned of the
-- client's escapes (Written), cut at a word (Cut), their first note at a
-- level quoted (Text.Note) and their latest about someone quoted on the
-- margin note (Text.MarginQuote). The quote is theirs, set in their hand.
--
-- The module and its siblings: UI/Journey/Text/Grammar.lua.

local addonName, ns = ...

local Text = ns.UI.JourneyText
local L, Fmt = ns.L, ns.Fmt

-- The player's words as a font string is to show them, and only them: the
-- client's escape codes taken out (a colour, a texture; a link keeps its
-- "[name]"), any other bar shown as a bar, so nothing typed into a note
-- turns into a link or a colour on the page; line breaks and runs of
-- spaces folded into one space.
local function Written(text)
    text = tostring(text or ""):gsub("||", "\1")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
    text = text:gsub("|n", " "):gsub("|", "\1"):gsub("\1", "||")
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
Text.Written = Written

-- Written words cut to `most` bytes at the end of a word (at a whole
-- character where one word is longer than that), with an ellipsis; as
-- they are where they fit. Whether they were cut, too.
local ELLIPSIS = "\226\128\166"

local function Cut(text, most)
    if #text <= most then return text, false end
    local short = text:sub(1, most + 1):match("^(.*%S)%s")
        or text:sub(1, most):gsub("[\192-\255][\128-\191]*$", "")
    -- Never half of a shown bar ("||"), nor a comma before the ellipsis.
    short = short:gsub("|+$", function(bars) return bars:sub(1, #bars - #bars % 2) end)
    return short:gsub("[%s,;:]+$", "") .. ELLIPSIS, true
end

-- The player's own words at this level: their first note, quoted as they
-- wrote it (`most` bytes, cut at a whole character), and how many more
-- there are ("And one more note."), or nil without one. The quote is
-- theirs, set in the handwriting; the count is the diary's.
local NOTE = { most = 140 }

function Text.Note(e)
    local note = e.notes and e.notes[1]
    if not note or not note.text then return nil end
    local text = Written(note.text)
    if #text > NOTE.most then
        text = text:sub(1, NOTE.most - 2):gsub("[\192-\255][\128-\191]*$", ""):gsub("%s+$", "") .. "\226\128\166"
    end
    local more = #e.notes > 1 and (#e.notes == 2 and L["And one more note."] or Fmt(L["And %d more notes."], #e.notes - 1))
        or nil
    -- In the book's curly quotes, the reader's language's own.
    return Fmt(L["\226\128\156%s\226\128\157"], text), more
end

-- The player's own words on a person's margin note: their latest note
-- about them on the plate (a note moment's `note`, Core/JourneyRecap.lua),
-- as written (Written), for the strip to quote in their hand under the
-- name. Cut at a word past QUOTE.most bytes, for the strip to cut again to
-- its lines; and to QUOTE.tip for the strip's tooltip, where it was cut.
-- Returns the quote, whether it was cut, and the tooltip's words; nil
-- without a note that says anything.
local QUOTE = { most = 160, tip = 500 }

-- The note moment Text.MarginQuote quotes, or nil: the strip's leader
-- goes to its mark (12 Oct, in the client: a quote written in the south
-- under a leader to the north, where the time together was).
function Text.MarginQuoted(moments)
    local latest
    for _, m in ipairs(moments) do
        if m.kind == "note" and m.note and type(m.note.text) == "string"
            and (not latest or (m.t or 0) >= (latest.t or 0)) then
            latest = m
        end
    end
    local text = latest and Written(latest.note.text)
    if not text or text == "" then return nil end
    return latest, text
end

function Text.MarginQuote(moments)
    local _, text = Text.MarginQuoted(moments)
    if not text then return nil end
    local quote, cut = Cut(text, QUOTE.most)
    return quote, cut, (Cut(text, QUOTE.tip))
end
Text.QUOTE = QUOTE
