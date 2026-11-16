-- Gathering's words on Your Diary's plates: the mark's tooltip. Copy changes
-- go through the copywriter skill, as every player-read word does.

local addonName, ns = ...

local Gathering = ns.Gathering
local Text = ns.UI.JourneyText
local List = Text.List
local L, Fmt = ns.L, ns.Fmt

-- What a node's verb is: herbs are picked, ore is mined.
local function Verb(kind)
    return kind == "herb" and "picked" or "mined"
end

-- The tooltip's title for the nodes on one spot (a list of one for a node
-- gathered once): "Mined Copper Vein", "Picked Peacebloom", where the
-- client gave no name "Mined some ore" and "Picked an herb"; for several
-- of a kind "Mined here twice", "Picked here 3 times", and "Gathered here 3
-- times" where a herb and ore share the spot.
local function Title(nodes)
    local first = nodes[1]
    local kind = first.kind
    for _, node in ipairs(nodes) do
        if node.kind ~= kind then kind = nil end
    end
    if #nodes == 1 then
        if first.name then
            return Fmt(first.kind == "herb" and L["Picked %s"] or L["Mined %s"], first.name)
        end
        return first.kind == "herb" and L["Picked an herb"] or L["Mined some ore"]
    end
    local times = ns.UI.Format.Times(#nodes)
    if not kind then return Fmt(L["Gathered here %s##times"], times) end
    return Fmt(Verb(kind) == "picked" and L["Picked here %s##times"] or L["Mined here %s##times"], times)
end

-- The nodes' tooltip (the mark's, a spot's nodes told together): the title,
-- then, for several, each name once, and last when and at what level, as
-- every mark's tooltip on the plates ends (the core's Text.Foot): "Today at
-- 12:47 and 15:10, level 20".
function Gathering.Tips(nodes, now)
    local names, seen = {}, {}
    local ts, lo, hi = {}, nil, nil
    local j = ns.Journey.For and ns.Journey.For(ns.ownGUID)
    for _, node in ipairs(nodes) do
        local name = node.name
        if name and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
        ts[#ts + 1] = node.t or 0
        local level = j and ns.JourneyRecap and ns.JourneyRecap.LevelAt(j, node.t or 0) or nil
        if level then
            lo = (not lo or level < lo) and level or lo
            hi = (not hi or level > hi) and level or hi
        end
    end
    local lines = {}
    if #nodes > 1 and names[1] then lines[#lines + 1] = List(names) end
    lines[#lines + 1] = Text.Foot({ times = ts, levelFrom = lo, levelTo = hi }, now)
    return Title(nodes), lines
end

-- One node's tooltip, as its spot's alone (Gathering.Tips).
function Gathering.Tip(node, now)
    return Gathering.Tips({ node }, now)
end
