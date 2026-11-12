-- Suggest a better wording: a player on a translation picks a line in the
-- diary and sends a correction as a GitHub issue. The whole of it lives in
-- this folder (UI/Windows/Suggest/), and it only ever reads the rest of the
-- addon: deleting the folder and its TOC lines takes it out entirely.
--
--   Lookup.lua  this file: ns.UI.Suggest, a shown line's text cleaned, the
--               key and English found back from it, the issue's address
--   Pick.lua    the picking: a full-screen overlay, the diary's own visible
--               lines under the cursor, Escape or right-click to stop
--   Sheet.lua   the sheet a picked line opens on: the line, its English,
--               the player's wording, the address to copy
--   Strip.lua   the small strip on the book's top edge that starts it, and
--               nowhere else: only where the diary reads a translation, and
--               not with the pad in hand (typing and copying want a keyboard)
--
-- The reverse lookup is built only when a line is picked, from the words
-- the diary reads now (ns.L: every key, with the active locale's words laid
-- over the English, Locales/Locale.lua). In turn: the text exactly; then
-- each template as a pattern (its %s, %d and %1$s as captures); then each
-- form of a plural on its own ("a|b##plural"); gendered forms (<1:a/b>)
-- expand to each of theirs. A line no single key wrote may be several put
-- together ("A long stay" and "%d min" in "%1$s, %2$s", a plate's caption):
-- then it is taken apart at each joining template (one of values and
-- punctuation only) and its parts looked up, the same way. Nothing found is
-- fine: the line is sent as it is shown, without a key.

local addonName, ns = ...

local Locale = ns.Locale

local Suggest = {}
ns.UI.Suggest = Suggest

-- Where an issue goes, and its form (.github/ISSUE_TEMPLATE/translation.yml:
-- the field ids are the query's names).
Suggest.ISSUE = "https://github.com/social-diary/social_diary/issues/new"
Suggest.TEMPLATE = "translation.yml"
Suggest.FIELDS = { locale = "locale", version = "addon-version", english = "english",
    current = "current", suggestion = "suggestion" }
-- At most this many bytes of each text go into the address (cut on a
-- character, an ellipsis after), so it stays a sane length even in
-- Cyrillic, where every letter is six characters encoded.
Suggest.MAX = { title = 60, english = 200, current = 200, suggestion = 240 }

local ELLIPSIS = "\226\128\166"

--------------------------------------------------------------------------
-- A line's text as the player reads it
--------------------------------------------------------------------------

-- WoW's escapes out: colours, textures and atlases, links (their shown
-- part kept), |n; whitespace collapsed and trimmed, a no-break space (a
-- figure glued to its unit, "11 Min.") as a plain one, as the words have it.
function Suggest.Clean(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|n", " ")
        :gsub("||", "|"):gsub("\194\160", " ")
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

--------------------------------------------------------------------------
-- The reverse lookup
--------------------------------------------------------------------------

-- `text` with each gendered choice (<1:er/sie>, <you:a/b>, <they:a/b/c>)
-- taken every way, at most `MOST` ways.
local MOST = 16
local function Expand(text, out)
    out = out or {}
    if #out >= MOST then return out end
    local s, e, forms = text:find("<[%w]+:([^<>]*)>")
    if not s then
        out[#out + 1] = text
        return out
    end
    for form in (forms .. "/"):gmatch("([^/]*)/") do
        Expand(text:sub(1, s - 1) .. form .. text:sub(e + 1), out)
    end
    return out
end

-- How the diary shows a value's text, before anything is filled in: the
-- reader's braces ("{you}") as the reader's own word, a locale's marks
-- for its last pass (grammar.Agree: "<f>") left out.
local function Shown(text)
    return Suggest.Clean((text:gsub("{(.-)}", "%1"):gsub("<%a+>", "")))
end

local PLACEHOLDER = "%%%d*%$?[-+ #0]*%d*%.?%d*[sdifgxXc]"

-- A template as an anchored Lua pattern, its placeholders captures; how
-- many letters it holds besides them (a template of nothing but values,
-- "%1$s %2$s", would match any line: those only join others); and how
-- many placeholders, and how many of them a word's.
local function Pattern(template)
    local parts, letters, values, words, pos = {}, 0, 0, 0, 1
    template = template:gsub("%%%%", "\1")
    while true do
        local s, e = template:find(PLACEHOLDER, pos)
        local literal = template:sub(pos, (s or 0) - 1)
        if not s then literal = template:sub(pos) end
        literal = literal:gsub("\1", "%%")
        letters = letters + #(literal:gsub("[%s%p]", ""))
        parts[#parts + 1] = literal:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        if not s then break end
        -- A figure's place takes a figure only ("%d Min." is not every
        -- line that ends in "Min."); a word's takes anything.
        local figure = template:sub(e, e):find("[difgxX]") ~= nil
        parts[#parts + 1] = figure and "(%-?%d[%d%.,]*)" or "(.-)"
        values = values + 1
        if not figure then words = words + 1 end
        pos = e + 1
    end
    return "^" .. table.concat(parts) .. "$", letters, values, words
end

-- built on the first pick: { exact = { [text] = entry }, patterns = {
-- entry... }, joins = { { pattern, literal }... } }
local index

-- The English of `key` for its `n`th form (a plural's forms in the locale
-- may be more than English has: the last English form stands for the rest).
local function English(key, n, plural)
    local english = Locale.English(key)
    if not plural then return english end
    local forms = Locale.Forms(english)
    return forms[math.min(n or 1, #forms)] or english
end

local function Build()
    local exact, patterns, joins, joined = {}, {}, {}, {}
    for key, text in pairs(ns.L) do
        if type(key) == "string" and type(text) == "string" then
            local plural = key:find("##plural", 1, true) ~= nil
            local forms = plural and Locale.Forms(text) or { text }
            for n, form in ipairs(forms) do
                for _, variant in ipairs(Expand(form)) do
                    local shown = Shown(variant)
                    if shown ~= "" then
                        local entry = { key = key, english = English(key, n, plural),
                            kind = plural and "plural" or nil }
                        if shown:find(PLACEHOLDER) then
                            local pattern, letters, values, words = Pattern(shown)
                            -- Figures alone beside a short unit ("%d h")
                            -- match little else: one letter is enough.
                            if letters >= 3 or (words == 0 and letters >= 1) then
                                entry.pattern, entry.letters = pattern, letters
                                entry.kind = entry.kind or "template"
                                patterns[#patterns + 1] = entry
                            elseif values >= 2 and not joined[pattern] then
                                -- Values and punctuation only, two values or
                                -- more: what joins other lines ("%1$s, %2$s").
                                -- Several keys read alike: one of each.
                                joined[pattern] = true
                                joins[#joins + 1] = { pattern = pattern,
                                    literal = #(shown:gsub(PLACEHOLDER, ""):gsub("%s", "")) }
                            end
                        elseif not exact[shown] then
                            entry.kind = entry.kind or "exact"
                            exact[shown] = entry
                        end
                    end
                end
            end
        end
    end
    -- The most particular template first: more of its own words to match.
    table.sort(patterns, function(a, b)
        if a.letters ~= b.letters then return a.letters > b.letters end
        return a.key < b.key
    end)
    -- The join that says most of its own first (", " before " ").
    table.sort(joins, function(a, b)
        if a.literal ~= b.literal then return a.literal > b.literal end
        return a.pattern < b.pattern
    end)
    return { exact = exact, patterns = patterns, joins = joins }
end

-- Drops the index, for the next pick to build afresh (and the tests).
function Suggest.Forget() index = nil end

-- `text` as shown (escapes and all) back to what it was written from:
-- { key, english, kind = "exact" | "template" | "plural" | "joined" }, or
-- nil where nothing matched. `kind` "plural" for a plural's form, filled or
-- not.
-- `kind` "joined" for a line put together from several: `parts` holds each
-- one found ({ key, english, kind }, in the order shown), `key` their keys a
-- line each, `english` their English side by side.
local DEEP = 3      -- a joined line's parts may be joined too, this deep

-- One key's line: the text exactly, then the templates.
local function Whole(shown)
    local hit = index.exact[shown]
    if hit then return hit end
    for _, entry in ipairs(index.patterns) do
        if shown:match(entry.pattern) then return entry end
    end
    return nil
end

-- The parts of `shown` found, taken apart at the join that finds them
-- best; nil where none finds any. A join of spaces alone would part any
-- two words: it counts only where every part is found.
local function Apart(shown, depth)
    local best, most, whole
    for _, join in ipairs(index.joins) do
        local pieces = { shown:match(join.pattern) }
        if #pieces > 0 then
            -- `hits` pieces with something found in them, `full` of those
            -- found through and through.
            local parts, hits, full = {}, 0, 0
            for _, piece in ipairs(pieces) do
                piece = Suggest.Clean(piece)
                local hit = piece ~= "" and Whole(piece) or nil
                if hit then
                    parts[#parts + 1] = hit
                    hits, full = hits + 1, full + 1
                elseif piece ~= "" and depth < DEEP then
                    local inner, all = Apart(piece, depth + 1)
                    if inner then
                        for _, p in ipairs(inner) do parts[#parts + 1] = p end
                        hits = hits + 1
                        if all then full = full + 1 end
                    end
                end
            end
            -- Every piece found through and through before some; then the
            -- most found; then the fewest pieces (a line cut no finer than
            -- it needs).
            local all = full == #pieces
            if hits > 0 and (join.literal > 0 or all) then
                local score = (all and 10000 or 0) + full * 100 + hits * 10 - #pieces
                if not most or score > most then best, most, whole = parts, score, all end
            end
        end
    end
    return best, whole
end

function Suggest.Lookup(text)
    local shown = Suggest.Clean(text)
    if shown == "" then return nil end
    index = index or Build()
    local hit = Whole(shown)
    if hit then return hit end
    local parts = Apart(shown, 1)
    if not parts then return nil end
    local keys, english = {}, {}
    for i, part in ipairs(parts) do keys[i], english[i] = part.key, part.english end
    return { kind = "joined", parts = parts, key = table.concat(keys, "\n"),
        english = table.concat(english, " / ") }
end

--------------------------------------------------------------------------
-- The issue's address
--------------------------------------------------------------------------

-- At most `most` bytes of `text`, cut where a character begins, with an
-- ellipsis where it was cut.
function Suggest.Truncate(text, most)
    text = text or ""
    if #text <= most then return text end
    local cut = most - #ELLIPSIS
    -- Back off a UTF-8 continuation byte (10xxxxxx): never half a letter.
    while cut > 0 do
        local b = text:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return text:sub(1, cut) .. ELLIPSIS
end

-- Percent-encoded for a query: every byte but the unreserved ones, so
-- UTF-8 goes byte by byte (RFC 3986).
function Suggest.Encode(text)
    return ((text or ""):gsub("[^%w%-%._~]", function(c) return ("%%%02X"):format(c:byte()) end))
end

-- The new issue's address, its form filled from `f`: { locale, version,
-- key, english, current, suggestion }. The key goes where it is known
-- (the English as the translators look it up), else nothing.
function Suggest.URL(f)
    local M, F, E = Suggest.MAX, Suggest.FIELDS, Suggest.Encode
    local current = Suggest.Truncate(f.current or "", M.current)
    local title = ("[%s] %s"):format(f.locale or "", Suggest.Truncate(f.current or "", M.title))
    local parts = {
        "template=" .. E(Suggest.TEMPLATE),
        "title=" .. E(title),
        F.locale .. "=" .. E(f.locale or ""),
        F.version .. "=" .. E(f.version or ""),
        F.english .. "=" .. E(Suggest.Truncate(f.key or f.english or "", M.english)),
        F.current .. "=" .. E(current),
        F.suggestion .. "=" .. E(Suggest.Truncate(f.suggestion or "", M.suggestion)),
    }
    return Suggest.ISSUE .. "?" .. table.concat(parts, "&")
end
