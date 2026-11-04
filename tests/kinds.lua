-- Every feature registered whole, and core naming none of them.
--
-- A detection lives in Features/<Name>/ and plugs into the registries
-- (Core/Rows.lua, Journey.RegisterList, Recap.RegisterMoment,
-- Plate.RegisterMark and RegisterPass, JourneyMargin.Register,
-- Text.RegisterCaption and RegisterLines). A registration left half done
-- still loads, and the page quietly does without it: a People row reads
-- as its raw type, a moment opens a plate with no mark on it, two kinds
-- share a place in the margin. These checks catch that before the client
-- does, and catch core reaching into a feature by name again.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local function Sorted(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

--------------------------------------------------------------------------
Section("every People row kind reads and shows")

for _, kind in ipairs(ns.Rows.All()) do
    local k = ns.Rows.Get(kind)
    if not k.hidden then
        Check(type(k.text) == "function", kind .. " has no words on the timeline")
        Check(type(k.icon) == "string", kind .. " has no icon")
        Check(#(ns.Style.ART[k.icon] or {}) > 0, kind .. "'s icon " .. tostring(k.icon) .. " has no art")
        Check(k.activity ~= nil or k.moment ~= nil, kind .. " is neither an activity nor a moment")
        Check(k.observed or k.reason or k.activity, kind .. " has no reason for the picker")
    end
end

-- Recently nearby ranks and words only the marks it knows: a kind with
-- another `dealt` is refused as it registers, not at the first hover.
Check(not pcall(ns.Rows.Register, "kinds_test_dealt", { dealt = "hugged" }),
    "a kind registers a `dealt` Recently nearby cannot word")
Check(ns.Rows.Get("kinds_test_dealt").type == nil, "a refused kind is declared anyway")

--------------------------------------------------------------------------
Section("every recap moment is ranked, gathered and marked")

local Recap, Plate = ns.JourneyRecap, ns.UI.JourneyPlate
local orders = {}
for _, kind in ipairs(Sorted(Recap.MOMENTS)) do
    local spec = Recap.MOMENTS[kind]
    Check(type(Recap.RANK[kind]) == "number", kind .. " has no rank")
    Check(spec.entry ~= nil, kind .. " gathers into no entry field")
    Check(spec.gather ~= nil or (spec.list ~= nil and ns.Journey.LISTS[spec.list] ~= nil),
        kind .. " gathers from a list nobody registered")
    Check(spec.moment ~= nil or spec.field ~= nil, kind .. " puts its record in no field of the moment")
    Check(Plate.MARKS[kind] ~= nil, kind .. " has no mark on the plates")
    Check(not orders[spec.order], kind .. " shares its order with " .. tostring(orders[spec.order]))
    orders[spec.order or 0] = kind
end

--------------------------------------------------------------------------
Section("every mark draws in its own place")

local marks = {}
local markName = {}
for name, spec in pairs(Plate.MARKS) do markName[spec] = name end
for _, spec in ipairs(Plate.MARK_ORDER) do
    local kind = markName[spec] or "?"
    Check(type(spec.draw) == "function", kind .. "'s mark draws nothing")
    Check(type(spec.cap) == "number" and spec.count ~= nil, kind .. "'s mark has no cap or count")
    Eq(Plate.CAP[spec.count], spec.cap, kind .. "'s cap is not in CAP")
    Check(spec.order ~= Plate.ROAD_DEATHS, kind .. " is drawn on the road deaths' turn")
    Check(not marks[spec.order], kind .. " shares its order with " .. tostring(marks[spec.order]))
    marks[spec.order] = kind
end

--------------------------------------------------------------------------
Section("every margin note has its pool, words and leader, in its own place")

local Margin = ns.UI.JourneyMargin
local margin = {}
for name, at in pairs(Margin.PEOPLE) do margin[at] = "people (" .. name .. ")" end
for _, kind in ipairs(Sorted(Margin.KINDS)) do
    local spec = Margin.KINDS[kind]
    Check(type(spec.pool) == "string", kind .. "'s note has no pool")
    Check(type(spec.new) == "function" and type(spec.write) == "function", kind .. "'s note is never made or written")
    Check(type(spec.mark) == "function", kind .. "'s note has no leader to its mark")
    Check(spec.item ~= nil or spec.items ~= nil, kind .. "'s note takes nothing from the plate")
    Check(not margin[spec.order], kind .. " shares its margin place with " .. tostring(margin[spec.order]))
    margin[spec.order] = kind
end

--------------------------------------------------------------------------
Section("every caption's words have their own places")

local Text = ns.UI.JourneyText
local leads, tails = {}, {}
for _, key in ipairs(Sorted(Text.CAPTIONS)) do
    local spec = Text.CAPTIONS[key]
    Check(spec.moment == nil or Recap.MOMENTS[spec.moment] ~= nil or spec.moment == "death",
        key .. "'s caption gathers a moment kind nobody registered")
    if spec.lead then
        Check(not leads[spec.lead.at], key .. " leads at " .. spec.lead.at .. " with " .. tostring(leads[spec.lead.at]))
        leads[spec.lead.at] = key
    end
    if spec.tail then
        Check(not tails[spec.tail.at], key .. " tails at " .. spec.tail.at .. " with " .. tostring(tails[spec.tail.at]))
        tails[spec.tail.at] = key
    end
end
local paragraphs = {}
for _, p in ipairs(Text.Paragraphs()) do
    local at = tostring(p.at) .. ":" .. tostring(p.run or p.key)
    Check(not paragraphs[at], tostring(p.key) .. " shares its paragraph place with " .. tostring(paragraphs[at]))
    paragraphs[at] = p.key
end

--------------------------------------------------------------------------
Section("every feature's files load, and core names no feature")

local function Read(path)
    local f = assert(io.open(path, "r"), "cannot read " .. path)
    local s = f:read("*a")
    f:close()
    return s
end
local function Ls(cmd)
    local list, p = {}, assert(io.popen(cmd))
    for line in p:lines() do list[#list + 1] = line end
    p:close()
    return list
end

local toc = Read("social_diary.toc")
local packaged = toc:match("^(.-)#@do%-not%-package@") or toc

-- A feature is a folder of files: Features/<Name>/, or one level down in a
-- group, Features/<Group>/<Name>/ (Features/Classes/Hunter/: the moments of
-- one class). A group holds folders only, and makes no namespace of its
-- own; each feature in it makes ns.<Name>, so two features may not share a
-- name across groups.
local features, folders = {}, {}
for _, top in ipairs(Ls("ls -1 Features")) do
    local inner = Ls("find Features/" .. top .. " -mindepth 1 -maxdepth 1 -type d | sort")
    if #inner == 0 then
        features[#features + 1] = top
        folders[top] = "Features/" .. top
    else
        Check(#Ls("find Features/" .. top .. " -mindepth 1 -maxdepth 1 -type f") == 0,
            "Features/" .. top .. " holds folders and files: a group holds folders only")
        for _, dir in ipairs(inner) do
            local name = dir:match("([^/]+)$")
            Check(#Ls("find " .. dir .. " -mindepth 1 -type d") == 0, dir .. " is nested deeper than a group")
            Check(folders[name] == nil, dir .. " shares its name with " .. tostring(folders[name]))
            features[#features + 1] = name
            folders[name] = dir
        end
    end
end
Check(#features > 0, "no Features/ folder")
for _, name in ipairs(features) do
    for _, file in ipairs(Ls("ls -1 " .. folders[name])) do
        local path = folders[name] .. "/" .. file
        Check(toc:find(path, 1, true) ~= nil, path .. " is not in the TOC")
        if file == "Dev.lua" then
            Check(packaged:find(path, 1, true) == nil, path .. " would be packaged")
        end
    end
    Check(ns[name] ~= nil, folders[name] .. " makes no ns." .. name)
end
local pkgmeta = Read(".pkgmeta")
Check(pkgmeta:find("Features/*/Dev.lua", 1, true) ~= nil, ".pkgmeta does not leave the features' Dev.lua out")
Check(pkgmeta:find("Features/*/*/Dev.lua", 1, true) ~= nil, ".pkgmeta does not leave a group's features' Dev.lua out")

-- Every file under these folders, however deep (UI's areas are folders).
for _, dir in ipairs({ "Core", "UI", "Capture", "Dev" }) do
    for _, file in ipairs(Ls("find " .. dir .. " -name '*.lua' 2>/dev/null | sort")) do
        local code = Read(file)
        for _, name in ipairs(features) do
            Check(not code:find("ns%." .. name .. "[^%w_]"), file .. " names the feature ns." .. name)
        end
    end
end

--------------------------------------------------------------------------
Section("every feature's card keeps to the strip's contract")

-- A card on the paper strip (UI/Paper/Strip.lua, the comment over
-- ns.UI.PaperStrip) is laid through its hooks (plan, draw, again,
-- smaller, nearest) and uses only the strip's public fields and methods.
-- It does not patch the strip's methods (`local layout = card.Layout`,
-- `function card:Layout`, `:Smaller`, `:Nearest`), read the strip's
-- tables (ns.UI.PAPER_STRIP: PAPER_LOOK is the look, for drawings that are
-- not strips), or touch a field of the strip's own (`card.note`,
-- `self.lines`, ...), nor give one of its own fields a strip's name. The
-- strip's own fields are taken from a strip laid here with everything a
-- note can ask (so a new one is caught without this list knowing it),
-- less the fields the contract gives a card.
local PUBLIC = { name = true, picture = true, under = true, box = true, turn = true, flat = true, turnsText = true,
    overfull = true }
local probe = ns.UI.PaperStrip(UIParent)
probe:SetNote({ name = "Tester", what = "made up for the test", quote = "a note to quote, of a few words", guid = "g",
    rival = true, seed = "kinds", tip = function() return {} end, onClick = function() end,
    picture = { w = 20, h = 10 }, under = { w = 20, h = 10 }, soft = { out = 1, blur = 1, alpha = 0.1 } })
probe:Layout(0, 0, 160, 200)
local private = {}
for key, value in pairs(probe) do
    if type(key) == "string" and type(value) ~= "function" and not PUBLIC[key] then private[#private + 1] = key end
end
table.sort(private)
Check(#private > 10, "the strip's own fields were not found: " .. table.concat(private, ","))

-- What a feature's file may not say: the pattern, and why.
local BANNED = {
    { "PAPER_STRIP", "reads ns.UI.PAPER_STRIP (the strip's tables)" },
    { "[%w_]%.Layout%f[^%w_]", "reaches the strip's Layout (a card is laid through its hooks)" },
    { "function%s+[%w_]+:Layout%f[^%w_]", "defines its own :Layout on a strip" },
    { "function%s+[%w_]+:Smaller%f[^%w_]", "defines :Smaller on a strip (the `smaller` hook)" },
    { "function%s+[%w_]+:Nearest%f[^%w_]", "defines :Nearest on a strip (the `nearest` hook)" },
    { "[%w_]%.Smaller%s*=[^=]", "assigns a strip's Smaller" },
    { "[%w_]%.Nearest%s*=[^=]", "assigns a strip's Nearest" },
}
-- A strip in a card's file goes by one of these names (the card, its
-- slip, a tag of its own, `self` in its methods and hooks).
local STRIPS = { "card", "self", "slip", "strip", "tag" }
local function Conform(file, code)
    local wrong = {}
    for _, ban in ipairs(BANNED) do
        if code:find(ban[1]) then wrong[#wrong + 1] = ban[2] end
    end
    for _, key in ipairs(private) do
        for _, who in ipairs(STRIPS) do
            -- (Not a field of a field: plan.tag.lines is the plan's.)
            if code:find("%f[%w_%.]" .. who .. "%." .. key .. "%f[^%w_]") then
                wrong[#wrong + 1] = "touches the strip's own field " .. who .. "." .. key
            end
        end
    end
    Check(#wrong == 0, file .. " " .. table.concat(wrong, "; "))
end
for _, file in ipairs(Ls("find Features -name '*.lua' 2>/dev/null | sort")) do Conform(file, Read(file)) end
