-- The page writer (PAGE-1): turns a plan into a page of prose.
--
-- What a page says is decided before it gets here (the planner: which
-- people, which angles, in which order, what to leave out). This file only
-- decides how to say it, from the words the UI/Words/Pages/ files declare.
-- No frames, no saved variables read directly, so the page tests
-- (tests/prose/run.lua) can render thousands of pages without a client.
--
-- The words
-- ---------
-- An angle ("reunion", "rescue", ...) has moves, one sentence each, in
-- order. A move's words come in five kinds, declared additively with
-- Pages.Words(angle, move, spec), the way Rows.Register adds to a kind, so
-- several files can add variants to one move:
--
--   stems      an opening that leads into a clause: "After {days:gapDays}
--              away, "
--   clauses    a full clause with its subject, which can follow a stem:
--              "{ref} turned up again"
--   fragments  diary shorthand that stands alone, never after a stem: "Ran
--              into {ref.obj} again"
--   tails      what can follow a clause or fragment: ", the longest we've
--              gone without crossing paths"
--   wholes     a sentence or two that is complete as it stands
--
-- A sentence is a whole, or [stem] + clause + [tail], or fragment + [tail].
-- Pieces are combined only where nothing is said twice (each piece knows
-- what it says, below) and everything the move must say is said.
--
-- A piece is a string, or a table with the text first and any of:
--   needs   conditions on the facts ("?flag" is a guard: it must hold, but
--           unlike a bare flag the piece doesn't say it): "isRecordGap", "!who.diary",
--           "pct<10", "foe.rank==elite", "page.part==evening",
--           "seen>@groupedWith" (another fact), "#page.zones>=2" (a length)
--   says    tags it says beyond its slots; a tag starting with "_" only
--           keeps pieces of one sentence apart, and isn't remembered for the page
--   voice   "warm", "wry" or "terse": only drawn when the page's voice is
--           that one, and then drawn more often
--   bonus   added to its specificity, to prefer it (or less, negative)
--   lead    a whole that may take a lead ("Later, ")
--   final   a clause or fragment that takes no tail (it ends in its own
--           "which ..." or the like)
--
-- The text
-- --------
--   {slot}            a slot: words from the facts (UI/Words/Pages/Slots.lua)
--   {slot.mod:arg}    with modifiers (.cap, .a, .obj, .poss, ...) and arguments
--   [a|b|c]           one of these, chosen per page; may nest and hold slots
--   <bank>            one entry of a bank (UI/Words/Pages/Lexicon.lua)
--
-- A slot's facts are needed automatically: "{num:quests}" makes the piece
-- wait for a truthy `quests` (so never "no quests"), and says "quests". A
-- slot inside [a|b] counts as needed whichever way the choice falls.
-- Slot values are inserted after the text is expanded and never read
-- again, so an item link's | and [ ] are safe.
--
-- Choosing
-- --------
-- Among the combinations that fit, the most specific (the sum of their
-- pieces' own conditions and bonuses, slots aside) win, with everything
-- within SPREAD of the best still in the draw, so the special line usually
-- wins and the page still varies. The shape of the sentence (a whole, a
-- stem and clause, a fragment and tail...) is drawn first, by the voice's
-- SHAPES weights, then the words within it. A piece used on a recent page is drawn less, one used
-- earlier on this page almost never. Every draw is seeded by the page's key,
-- so the same plan with the same memory always writes the same page.

local addonName, ns = ...

local Pages = ns.Pages or {}
ns.Pages = Pages

Pages.ANGLES = Pages.ANGLES or {}
Pages.BANKS = Pages.BANKS or {}
Pages.SLOTS = Pages.SLOTS or {}
Pages.LEADS = Pages.LEADS or {}

-- Combinations this close to the most specific stay in the draw.
local SPREAD = 1.5
-- A piece used this many pages ago is fully fresh again...
local RECENT_PAGES = 12
-- ...and one used on the page just before is drawn this much as often.
local FRESH_FLOOR = 0.08
-- A piece already used on this page.
local SAME_PAGE = 0.02
-- How much more often a piece in the page's voice is drawn.
local VOICE_BOOST = 1.8

local KINDS = { "stems", "clauses", "fragments", "tails", "wholes" }

-- How often each shape of sentence is drawn, before specificity and
-- freshness, by voice. Without this the long shapes would win by sheer
-- numbers: twenty stems, thirty clauses and twenty tails make twelve
-- thousand long sentences against thirty wholes.
Pages.SHAPES = {
    plain = { whole = 4, clause = 1.5, stem_clause = 2, clause_tail = 2, stem_clause_tail = 1, fragment = 1.2, fragment_tail = 1 },
    warm  = { whole = 4, clause = 1, stem_clause = 2, clause_tail = 2.5, stem_clause_tail = 1.2, fragment = 0.8, fragment_tail = 1 },
    wry   = { whole = 5, clause = 1.5, stem_clause = 1.5, clause_tail = 2, stem_clause_tail = 0.8, fragment = 1.2, fragment_tail = 1 },
    terse = { whole = 3, clause = 2, stem_clause = 0.8, clause_tail = 0.8, stem_clause_tail = 0.2, fragment = 3, fragment_tail = 1 },
}
-- A beat marked short: one piece, nothing joined.
Pages.SHORT_SHAPES = { whole = 3, clause = 3, stem_clause = 0.3, clause_tail = 0.3, stem_clause_tail = 0, fragment = 3, fragment_tail = 0.3 }

local floor = math.floor
local unpack = unpack or table.unpack

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- djb2, kept under 2^31 so it is exact in Lua 5.1's doubles.
local function Hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return h
end
Pages.Hash = Hash

-- Park-Miller: small, exact in doubles, and the same on every client.
local function NewRng(seed)
    local state = (seed % 2147483646) + 1
    local rng = {}
    function rng.float()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
    function rng.int(n)
        return floor(rng.float() * n) + 1
    end
    return rng
end
Pages.NewRng = NewRng

--------------------------------------------------------------------------
-- Conditions
--------------------------------------------------------------------------

local OPS = { ">=", "<=", "==", "~=", "!=", ">", "<" }

local function ParseValue(s)
    local n = tonumber(s)
    if n then return n end
    if s == "true" then return true end
    if s == "false" then return false end
    return s
end

local function ParseCond(text)
    local s = Trim(text)
    local neg = false
    -- "?flag" is a guard: it must hold, but the piece doesn't say it.
    local guard = false
    if s:sub(1, 1) == "?" then
        guard, s = true, Trim(s:sub(2))
    end
    if s:sub(1, 1) == "!" and s:sub(2, 2) ~= "=" then
        neg, s = true, Trim(s:sub(2))
    end
    for i = 1, #OPS do
        local a, b = s:find(OPS[i], 1, true)
        if a then
            local op = OPS[i] == "!=" and "~=" or OPS[i]
            return { path = Trim(s:sub(1, a - 1)), op = op, value = ParseValue(Trim(s:sub(b + 1))), neg = neg, guard = guard, text = text }
        end
    end
    return { path = s, neg = neg, guard = guard, text = text }
end
Pages.ParseCond = ParseCond

-- "who.level" reads a nested fact; "#page.zones" is the length of a list.
local function Get(root, path)
    local count = path:sub(1, 1) == "#"
    if count then path = path:sub(2) end
    local v = root
    for seg in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[seg]
    end
    if count then return type(v) == "table" and #v or nil end
    return v
end
Pages.Get = Get

local function Truthy(v)
    if v == nil or v == false or v == 0 or v == "" then return false end
    if type(v) == "table" and next(v) == nil then return false end
    return true
end
Pages.Truthy = Truthy

local function Eval(cond, f)
    local v = Get(f, cond.path)
    local want = cond.value
    -- "seen>@groupedWith" compares with another fact.
    if type(want) == "string" and want:sub(1, 1) == "@" then
        want = Get(f, want:sub(2))
        if want == nil then return cond.neg and true or false end
    end
    local ok
    if not cond.op then
        ok = Truthy(v)
    elseif v == nil then
        ok = false
    elseif cond.op == "==" then
        ok = v == want
    elseif cond.op == "~=" then
        ok = v ~= want
    elseif type(v) ~= "number" or type(want) ~= "number" then
        ok = false
    elseif cond.op == ">=" then ok = v >= want
    elseif cond.op == "<=" then ok = v <= want
    elseif cond.op == ">" then ok = v > want
    else ok = v < want end
    if cond.neg then ok = not ok end
    return ok
end
Pages.Eval = Eval

--------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------

-- "ref.obj.cap:by" -> "ref", { obj = true, cap = true }, { "by" }
local function ParseSlot(spec)
    local head, rest = spec:match("^([^:]*)(.*)$")
    local name, modstr = head:match("^([%w_]+)(.*)$")
    local mods = {}
    for m in (modstr or ""):gmatch("%.([%w_]+)") do mods[m] = true end
    local args = {}
    for a in rest:gmatch(":([^:]*)") do args[#args + 1] = a end
    return name, mods, args
end
Pages.ParseSlot = ParseSlot

-- Declares a slot: def.fn(env, args, mods) returns its words, or nil when
-- the facts can't say it (the combination is then dropped). def.needs and
-- def.says take the slot's args and return lists of fact paths and tags.
function Pages.Slot(name, def)
    Pages.SLOTS[name] = def
end

-- Declares a formatter: a slot whose first argument is the fact it reads
-- ("{num:quests}"), which it needs and says. fn(value, env, args, mods).
function Pages.Format(name, fn, opts)
    opts = opts or {}
    Pages.SLOTS[name] = {
        needs = function(args)
            local list = { args[1] }
            for i = 1, #(opts.alsoNeeds or {}) do list[#list + 1] = opts.alsoNeeds[i] end
            return list
        end,
        says = function(args)
            if opts.says == false then return {} end
            return { args[1] }
        end,
        fn = function(env, args, mods)
            if not args[1] then return nil end
            local v = Get(env.f, args[1])
            if v == nil then return nil end
            return fn(v, env, args, mods)
        end,
    }
end

--------------------------------------------------------------------------
-- Declaring words
--------------------------------------------------------------------------

local function Angle(name)
    local a = Pages.ANGLES[name]
    if not a then
        a = { name = name, order = {}, moves = {} }
        Pages.ANGLES[name] = a
    end
    return a
end

-- Sets an angle's move order, or anything else about it (`about`, for the
-- tests' report).
function Pages.Angle(name, spec)
    local a = Angle(name)
    for k, v in pairs(spec or {}) do
        if k == "order" then
            a.order = {}
            for i = 1, #v do a.order[i] = v[i] end
        else
            a[k] = v
        end
    end
    return a
end

-- Reads a piece's text for the slots it uses and the banks it draws on.
local function Scan(text)
    local slots, banks = {}, {}
    for spec in text:gmatch("{([^}]*)}") do slots[#slots + 1] = spec end
    for name in text:gmatch("<([%w_%.]+)>") do banks[#banks + 1] = name end
    return slots, banks
end

Pages.ERRORS = Pages.ERRORS or {}

local function Fail(where, message)
    Pages.ERRORS[#Pages.ERRORS + 1] = where .. ": " .. message
end

local function Compile(raw, where, kind)
    local piece = type(raw) == "string" and { raw } or raw
    local text = piece[1]
    if type(text) ~= "string" then
        Fail(where, "a piece without text")
        return nil
    end
    local p = {
        text = text,
        kind = kind,
        voice = piece.voice,
        bonus = piece.bonus or 0,
        lead = piece.lead,
        final = piece.final,
        conds = {},
        says = {},
        where = where,
    }
    p.id = where .. ":" .. string.format("%x", Hash(text))

    local seen = {}
    local function Need(path)
        if path and path ~= "" and not seen[path] then
            seen[path] = true
            p.conds[#p.conds + 1] = ParseCond(path)
        end
    end
    -- Explicit conditions make the piece specific; a bare flag ("isRecordGap",
    -- not "who.diary" or "pct<10") is also something the piece says, so two
    -- pieces that both say "a long absence" never meet in one sentence.
    local explicit = 0
    for _, c in ipairs(piece.needs or {}) do
        local cond = ParseCond(c)
        seen[c] = true
        p.conds[#p.conds + 1] = cond
        local flag = not cond.op and not cond.neg and not cond.guard
        -- A flag is news ("our longest gap yet"); a comparison or a negation
        -- is a guard that keeps the wording true, and counts for little.
        explicit = explicit + (flag and 1 or 0.25)
        if flag and not cond.path:find(".", 1, true) then
            p.says[cond.path] = true
        end
    end

    local slots, banks = Scan(text)
    p.banks = banks
    for _, spec in ipairs(slots) do
        local name, _, args = ParseSlot(spec)
        local def = name and Pages.SLOTS[name]
        if not def then
            Fail(where, "unknown slot {" .. spec .. "} in \"" .. text .. "\"")
        else
            for _, path in ipairs(def.needs and def.needs(args) or {}) do Need(path) end
            for _, tag in ipairs(def.says and def.says(args) or {}) do p.says[tag] = true end
        end
    end
    for _, tag in ipairs(piece.says or {}) do p.says[tag] = true end

    -- Two colons in one sentence read as a stutter ("PvP in Ashenvale: no
    -- doubt about it: ..."), and so do two semicolons: a piece holding one
    -- never meets another that does.
    local plain = text:gsub("{[^}]*}", ""):gsub("<[^>]*>", "")
    if plain:find(":", 1, true) then p.says["_colon"] = true end
    if plain:find(";", 1, true) then p.says["_semicolon"] = true end
    -- Nor do two clause joins of a kind: ", and ... , and ...".
    local lower = " " .. plain:lower()
    if lower:find(", and ", 1, true) or lower:find(", and$") then p.says["_and"] = true end
    if lower:find(", but ", 1, true) or lower:find("^%s*but ") then p.says["_but"] = true end
    if lower:find("though", 1, true) then p.says["_though"] = true end

    -- Specificity: what the piece asks of the facts beyond its slots. A slot's
    -- own needs don't count, or every long sentence would outrank every
    -- short one just by having more slots.
    p.spec = explicit + p.bonus
    return p
end

-- Adds words to a move. `spec` holds any of the five kinds, plus:
--   must    tags the sentence must say ("gapDays"); "a|b" is said when
--           either is
--   needs   conditions the whole move needs before it is tried
--   rel     the lead the move takes when it follows another in its angle
function Pages.Words(angle, move, spec)
    local a = Angle(angle)
    local m = a.moves[move]
    if not m then
        m = { name = move, angle = angle, must = {}, needs = {}, pieces = 0 }
        for _, kind in ipairs(KINDS) do m[kind] = {} end
        a.moves[move] = m
        local listed = false
        for i = 1, #a.order do if a.order[i] == move then listed = true end end
        if not listed then a.order[#a.order + 1] = move end
    end
    for _, tag in ipairs(spec.must or {}) do m.must[#m.must + 1] = tag end
    for _, c in ipairs(spec.needs or {}) do m.needs[#m.needs + 1] = ParseCond(c) end
    if spec.rel then m.rel = spec.rel end
    for _, kind in ipairs(KINDS) do
        for _, raw in ipairs(spec[kind] or {}) do
            local p = Compile(raw, angle .. "/" .. move .. "/" .. kind, kind)
            if p then
                m[kind][#m[kind] + 1] = p
                m.pieces = m.pieces + 1
            end
        end
    end
    return m
end

-- Adds entries to a bank. Entries are pieces (text plus needs and voice).
function Pages.Bank(name, entries)
    local bank = Pages.BANKS[name]
    if not bank then
        bank = {}
        Pages.BANKS[name] = bank
    end
    for _, raw in ipairs(entries) do
        local p = Compile(raw, "bank/" .. name, "bank")
        if p then bank[#bank + 1] = p end
    end
    return bank
end

-- Which bank leads a sentence that stands in this relation to the one
-- before: Pages.Lead("then", "lead.then").
function Pages.Lead(rel, bank)
    Pages.LEADS[rel] = bank
end

--------------------------------------------------------------------------
-- Memory
--------------------------------------------------------------------------
--
-- What the diary has already written, so pages vary and callbacks are safe:
-- which pieces were used on which page, and which beats were told about
-- whom. The store is a plain table (ns.db.pages.memory in the client).

local Memory = {}
Memory.__index = Memory

function Pages.Memory(store)
    store = store or {}
    store.page = store.page or 0
    store.used = store.used or {}
    store.told = store.told or {}
    return setmetatable({ store = store }, Memory)
end

-- Pages since the piece was last used, or nil.
function Memory:Age(id)
    local at = self.store.used[id]
    return at and (self.store.page - at) or nil
end

function Memory:Use(id)
    self.store.used[id] = self.store.page
end

-- Starts a new page.
function Memory:Turn()
    self.store.page = self.store.page + 1
end

function Memory:Tell(who, tag)
    local t = self.store.told[who]
    if not t then
        t = {}
        self.store.told[who] = t
    end
    t[tag] = self.store.page
end

function Memory:Told(who, tag)
    local t = self.store.told[who]
    return t and t[tag]
end

local NO_MEMORY = Pages.Memory({})

--------------------------------------------------------------------------
-- Expanding text
--------------------------------------------------------------------------

local Expand

local function Fresh(env, id)
    if env.ctx.usedHere[id] or env.staged.used[id] then return SAME_PAGE end
    local age = env.memory:Age(id)
    if not age then return 1 end
    if age >= RECENT_PAGES then return 1 end
    return FRESH_FLOOR + (1 - FRESH_FLOOR) * age / RECENT_PAGES
end

-- Splits "[a|b[c|d]|e]" at its top-level bars; returns the index of the
-- closing bracket and the parts.
local function ParseAlt(s, start)
    local depth, parts, from = 0, {}, start + 1
    local i = start
    while i <= #s do
        local c = s:sub(i, i)
        if c == "{" then
            i = s:find("}", i, true) or #s
        elseif c == "[" then
            depth = depth + 1
        elseif c == "]" then
            depth = depth - 1
            if depth == 0 then
                parts[#parts + 1] = s:sub(from, i - 1)
                return i, parts
            end
        elseif c == "|" and depth == 1 then
            parts[#parts + 1] = s:sub(from, i - 1)
            from = i + 1
        end
        i = i + 1
    end
    return nil
end

local function Pick(env, list, weight)
    local total = 0
    local weights = {}
    for i = 1, #list do
        weights[i] = weight(list[i])
        total = total + weights[i]
    end
    if total <= 0 then return nil end
    local r = env.rng.float() * total
    for i = 1, #list do
        r = r - weights[i]
        if r <= 0 then return i end
    end
    return #list
end

local function Eligible(p, f, voice)
    if p.voice and p.voice ~= voice then return false end
    for i = 1, #p.conds do
        if not Eval(p.conds[i], f) then return false end
    end
    return true
end

local function ExpandBank(name, env, depth)
    local bank = Pages.BANKS[name]
    if not bank then return nil end
    local list = {}
    for i = 1, #bank do
        if Eligible(bank[i], env.f, env.voice) then list[#list + 1] = bank[i] end
    end
    while #list > 0 do
        local i = Pick(env, list, function(p)
            local w = Fresh(env, p.id)
            if p.voice then w = w * VOICE_BOOST end
            return w
        end)
        if not i then return nil end
        local p = table.remove(list, i)
        local out = Expand(p.text, env, depth + 1)
        if out then
            env.staged.used[p.id] = true
            return out
        end
    end
    return nil
end

local function Slot(spec, env)
    local name, mods, args = ParseSlot(spec)
    local def = name and Pages.SLOTS[name]
    if not def then return nil end
    local v = def.fn(env, args, mods)
    if v == nil then return nil end
    v = tostring(v)
    local Lang = Pages.Lang
    if mods.a then v = Lang.A(v) end
    if mods.lower then v = v:lower() end
    if mods.cap then v = Lang.CapFirst(v) end
    return v
end

Expand = function(s, env, depth)
    depth = depth or 0
    if depth > 12 then return nil end
    local out = {}
    local i, n = 1, #s
    while i <= n do
        local c = s:sub(i, i)
        if c == "[" then
            local close, parts = ParseAlt(s, i)
            if not close then return nil end
            local choice = parts[env.rng.int(#parts)]
            local sub = Expand(choice, env, depth + 1)
            if not sub then return nil end
            out[#out + 1] = sub
            i = close + 1
        elseif c == "<" then
            local close = s:find(">", i, true)
            if not close then return nil end
            local sub = ExpandBank(s:sub(i + 1, close - 1), env, depth)
            if not sub then return nil end
            out[#out + 1] = sub
            i = close + 1
        elseif c == "{" then
            local close = s:find("}", i, true)
            if not close then return nil end
            local sub = Slot(s:sub(i + 1, close - 1), env)
            if not sub then return nil end
            out[#out + 1] = sub
            i = close + 1
        else
            local stop = s:find("[%[<{]", i) or n + 1
            out[#out + 1] = s:sub(i, stop - 1)
            i = stop
        end
    end
    return table.concat(out)
end
Pages.Expand = Expand

--------------------------------------------------------------------------
-- People in sentences
--------------------------------------------------------------------------
--
-- A person is a table the planner fills: { id, name, sex (2 male, 3
-- female, as UnitSex), race, class, relationship, diary, named, familiar,
-- hostile, level, tags }. Named people (diary entries, or `named`) go by
-- name; everyone else by what they look like ("a night elf hunter").
-- The first mention of a diary entry with a relationship carries it as an
-- epithet ("Brennick, my levelling buddy,"). A later mention in the same
-- paragraph is a pronoun when the person was the last one mentioned and
-- nobody else in the paragraph shares their pronoun.

local PRONOUNS = {
    [2] = { subj = "he", obj = "him", poss = "his" },
    [3] = { subj = "she", obj = "her", poss = "her" },
}
Pages.PRONOUNS = PRONOUNS

-- Race names in prose: "night elf hunter" rather than "Night Elf hunter".
Pages.LOWER_RACES = true

local function Key(p)
    return p.id or p.name or tostring(p)
end

local function IsNamed(p)
    return p.name and (p.diary or p.named) and true or false
end

function Pages.Describe(p)
    local Lang = Pages.Lang
    local race = p.race and (Pages.LOWER_RACES and Lang.Lower(p.race) or p.race)
    local class = p.class and Lang.Lower(p.class)
    if race and class then return race .. " " .. class end
    return class or race or (p.hostile and "enemy" or "stranger")
end

local function ShortDescribe(p)
    local Lang = Pages.Lang
    if p.class then return Lang.Lower(p.class) end
    if p.race then return Pages.LOWER_RACES and Lang.Lower(p.race) or p.race end
    return p.hostile and "enemy" or "stranger"
end

local DETERMINERS = { "my ", "our ", "the ", "a ", "an ", "his ", "her ", "their " }

function Pages.Epithet(p)
    local rel = p.relationship and Trim(p.relationship)
    if not rel or rel == "" then return nil end
    local lower = rel:lower()
    for i = 1, #DETERMINERS do
        if lower:sub(1, #DETERMINERS[i]) == DETERMINERS[i] then
            return lower:sub(1, #DETERMINERS[i]) .. rel:sub(#DETERMINERS[i] + 1)
        end
    end
    return "my " .. rel
end

local function Mentioned(env, key)
    return env.ctx.mentioned[key] or env.staged.mentioned[key]
end

local function Last(env)
    if env.staged.last ~= nil then return env.staged.last end
    return env.ctx.last
end

local function Pronounable(env, p, key)
    if not PRONOUNS[p.sex] then return false end
    if Last(env) ~= key then return false end
    for _, para in ipairs({ env.ctx.para, env.staged.para }) do
        for other, q in pairs(para) do
            if other ~= key and q.sex == p.sex then return false end
        end
    end
    return true
end

local function Mention(env, key, p)
    env.staged.mentioned[key] = true
    env.staged.last = key
    env.staged.para[key] = p
end

-- The words for person `p` in `case` ("subj", "obj" or "poss").
-- mods: full (name and epithet), noun (no pronoun), short (no epithet and
-- no pronoun: the plain name, for notes like "Brennick again").
function Pages.Refer(env, p, case, mods)
    local Lang = Pages.Lang
    local key = Key(p)
    local first = not Mentioned(env, key)
    local words

    if not mods.noun and not mods.short and not mods.full and not first and Pronounable(env, p, key) then
        words = PRONOUNS[p.sex][case]
    elseif IsNamed(p) then
        words = p.name
        local epithet = Pages.Epithet(p)
        local wantEpithet = mods.full or (first and env.epithets and not mods.short)
        if case ~= "poss" and epithet and wantEpithet
            and not env.ctx.epithet[key] and not env.staged.epithet[key] then
            words = words .. ", " .. epithet .. ","
            env.staged.epithet[key] = true
        elseif case == "poss" then
            words = Lang.Possessive(words)
        end
    else
        if first or mods.full then
            local desc = Pages.Describe(p)
            words = p.familiar and ("the " .. desc) or Lang.A(desc)
        else
            words = "the " .. ShortDescribe(p)
        end
        if case == "poss" then words = Lang.Possessive(words) end
    end

    Mention(env, key, p)
    return words
end

--------------------------------------------------------------------------
-- Rendering a move
--------------------------------------------------------------------------

local function Overlaps(a, b)
    for tag in pairs(a) do
        if b[tag] then return true end
    end
    return false
end

-- Whether the pieces say `tag`; "received|moneyReceived" is said when any
-- one of them is.
local function HasTag(tag, a, b, c)
    if tag:find("|", 1, true) then
        for one in tag:gmatch("[^|]+") do
            if a.says[one] or (b and b.says[one]) or (c and c.says[one]) then return true end
        end
        return false
    end
    return a.says[tag] or (b and b.says[tag]) or (c and c.says[tag]) or false
end

local NONE = {}

-- Shapes as numbers, so combinations can live in flat arrays.
local SHAPE_NAMES = { "whole", "clause", "clause_tail", "stem_clause", "stem_clause_tail", "fragment", "fragment_tail" }

-- The pieces of each kind that fit the facts, or nil when the move's own
-- needs fail.
local function Usable(m, f, voice, said)
    for i = 1, #m.needs do
        if not Eval(m.needs[i], f) then return nil end
    end
    local ok = {}
    for _, kind in ipairs(KINDS) do
        local list = {}
        for _, p in ipairs(m[kind]) do
            if Eligible(p, f, voice) and not Overlaps(p.says, said) then list[#list + 1] = p end
        end
        ok[kind] = list
    end
    return ok
end

-- Calls fn(shape, a, b, c, spec) for every combination that fits, its
-- pieces in order (b and c may be nil). Nothing is allocated per
-- combination: a move can have tens of thousands.
local function EachCombo(m, ok, must, fn)
    local mmust = m.must
    local function Try(shape, a, b, c)
        if b and Overlaps(a.says, b.says) then return end
        if c and (Overlaps(a.says, c.says) or Overlaps(b.says, c.says)) then return end
        for i = 1, #mmust do
            if not HasTag(mmust[i], a, b, c) then return end
        end
        for i = 1, #must do
            if not HasTag(must[i], a, b, c) then return end
        end
        -- One special piece is enough to make a sentence special; stacking
        -- more counts for a little, so specifics don't crowd out the rest.
        local best, sum = a.spec, a.spec
        if b then
            sum = sum + b.spec
            if b.spec > best then best = b.spec end
        end
        if c then
            sum = sum + c.spec
            if c.spec > best then best = c.spec end
        end
        fn(shape, a, b, c, best + 0.25 * (sum - best))
    end

    for _, w in ipairs(ok.wholes) do Try(1, w) end
    for _, cl in ipairs(ok.clauses) do
        Try(2, cl)
        if not cl.final then
            for _, t in ipairs(ok.tails) do Try(3, cl, t) end
        end
        for _, st in ipairs(ok.stems) do
            Try(4, st, cl)
            if not cl.final then
                for _, t in ipairs(ok.tails) do Try(5, st, cl, t) end
            end
        end
    end
    for _, fr in ipairs(ok.fragments) do
        Try(6, fr)
        if not fr.final then
            for _, t in ipairs(ok.tails) do Try(7, fr, t) end
        end
    end
end

local function MakeCombo(shape, a, b, c, spec)
    local pieces = { a }
    if b then pieces[2] = b end
    if c then pieces[3] = c end
    local says = {}
    for i = 1, #pieces do
        for tag in pairs(pieces[i].says) do says[tag] = true end
    end
    return {
        shape = SHAPE_NAMES[shape], pieces = pieces, says = says, spec = spec,
        leadable = a.kind == "clauses" or (a.kind == "wholes" and a.lead) or false,
    }
end

local function ComboKeyOf(a, b, c)
    local key = a.id
    if b then key = key .. "+" .. b.id end
    if c then key = key .. "+" .. c.id end
    return key
end

local function ComboKey(combo)
    return ComboKeyOf(combo.pieces[1], combo.pieces[2], combo.pieces[3])
end

-- Every combination of `m`'s pieces that fits the facts, as tables. For the
-- tests; rendering never builds this list.
function Pages.Combos(m, f, voice, said, must)
    local ok = Usable(m, f, voice, said or NONE)
    if not ok then return {} end
    local out = {}
    EachCombo(m, ok, must or NONE, function(shape, a, b, c, spec)
        out[#out + 1] = MakeCombo(shape, a, b, c, spec)
    end)
    return out
end

-- Counts, into `counts`, every piece that takes part in some combination
-- that fits. For the tests' coverage report, without building combinations.
function Pages.Reachable(m, f, voice, counts)
    local ok = Usable(m, f, voice, NONE)
    if not ok then return counts end
    local seen = {}
    EachCombo(m, ok, NONE, function(_, a, b, c)
        seen[a] = true
        if b then seen[b] = true end
        if c then seen[c] = true end
    end)
    for p in pairs(seen) do counts[p.id] = (counts[p.id] or 0) + 1 end
    return counts
end

local function NewStaged()
    return { mentioned = {}, para = {}, epithet = {}, used = {}, last = nil }
end

local function Commit(env, combo)
    local ctx, staged = env.ctx, env.staged
    for k in pairs(staged.mentioned) do ctx.mentioned[k] = true end
    for k, p in pairs(staged.para) do ctx.para[k] = p end
    for k in pairs(staged.epithet) do ctx.epithet[k] = true end
    for k in pairs(staged.used) do ctx.usedHere[k] = true end
    if staged.last ~= nil then ctx.last = staged.last end
    for i = 1, #combo.pieces do ctx.usedHere[combo.pieces[i].id] = true end
    local said = ctx.said[env.whoKey]
    if not said then
        said = {}
        ctx.said[env.whoKey] = said
    end
    -- Tags starting with "_" only keep two pieces of one sentence apart;
    -- the rest are remembered for the page, per person.
    for tag in pairs(combo.says) do
        if tag:sub(1, 1) ~= "_" then said[tag] = true end
    end
end

-- Writes one combination as a sentence, or nil when a bank or slot can't.
local function Write(combo, env, rel)
    env.staged = NewStaged()
    local Lang = Pages.Lang
    local parts = {}
    for i = 1, #combo.pieces do
        local text = Expand(combo.pieces[i].text, env, 0)
        if not text then return nil end
        parts[#parts + 1] = text
    end
    local sentence = table.concat(parts)
    if rel and combo.leadable then
        local bank = Pages.LEADS[rel]
        local lead = bank and ExpandBank(bank, env, 0)
        if lead and lead ~= "" then sentence = lead .. sentence end
    end
    sentence = Lang.Clean(Lang.Close(sentence))
    return Lang.CapFirst(sentence)
end

local function PickIndex(env, weights, n)
    local total = 0
    for i = 1, n do total = total + weights[i] end
    if total <= 0 then return nil end
    local r = env.rng.float() * total
    for i = 1, n do
        r = r - weights[i]
        if r <= 0 and weights[i] > 0 then return i end
    end
    for i = n, 1, -1 do
        if weights[i] > 0 then return i end
    end
    return nil
end

local function RenderMove(m, f, env, rel, pinned)
    env.staged = NewStaged()
    local ok = Usable(m, f, env.voice, env.ctx.said[env.whoKey] or NONE)
    if not ok then return nil end
    local must = env.must or NONE

    -- A page written before is written again exactly as it was.
    if pinned then
        local found
        EachCombo(m, ok, must, function(shape, a, b, c, spec)
            if not found and ComboKeyOf(a, b, c) == pinned then found = MakeCombo(shape, a, b, c, spec) end
        end)
        if found then
            local text = Write(found, env, rel)
            if text then return text, found end
        end
    end

    -- One pass: every combination that fits, by shape, in flat arrays, with
    -- the best specificity on offer.
    local A, B, C, S = {}, {}, {}, {}
    for i = 1, #SHAPE_NAMES do
        A[i], B[i], C[i], S[i] = {}, {}, {}, {}
    end
    local best = -math.huge
    EachCombo(m, ok, must, function(shape, a, b, c, spec)
        local n = #A[shape] + 1
        A[shape][n], B[shape][n], C[shape][n], S[shape][n] = a, b or false, c or false, spec
        if spec > best then best = spec end
    end)
    if best == -math.huge then return nil end
    local floorSpec = best - SPREAD

    -- Each piece's own weight, freshness and voice, worked out once; a
    -- combination's weight is theirs times how far above the floor it is.
    local pw = {}
    local function PW(p)
        if not p then return 1 end
        local w = pw[p]
        if not w then
            w = Fresh(env, p.id) * (p.voice and VOICE_BOOST or 1)
            pw[p] = w
        end
        return w
    end
    local W, top = {}, {}
    for si = 1, #SHAPE_NAMES do
        local weights, specs, best = {}, S[si], 0
        for i = 1, #specs do
            local spec = specs[i]
            local w = 0
            if spec >= floorSpec then
                w = (1 + spec - floorSpec) * PW(A[si][i]) * PW(B[si][i]) * PW(C[si][i])
            end
            weights[i] = w
            if w > best then best = w end
        end
        W[si], top[si] = weights, best
    end

    -- The shape first, by the voice's weights and the best each shape can
    -- do, then the words within it.
    local shapes = env.short and Pages.SHORT_SHAPES or (Pages.SHAPES[env.voice] or Pages.SHAPES.plain)
    local shapeWeights = {}
    for i = 1, #SHAPE_NAMES do
        shapeWeights[i] = (#A[i] > 0) and (shapes[SHAPE_NAMES[i]] or 1) * top[i] or 0
    end

    while true do
        env.staged = NewStaged()
        local si = PickIndex(env, shapeWeights, #SHAPE_NAMES)
        if not si then return nil end
        local weights, n = W[si], #A[si]
        while true do
            env.staged = NewStaged()
            local i = PickIndex(env, weights, n)
            if not i then break end
            local combo = MakeCombo(si, A[si][i], B[si][i] or nil, C[si][i] or nil, S[si][i])
            local text = Write(combo, env, rel)
            if text then return text, combo end
            weights[i] = 0
        end
        shapeWeights[si] = 0
    end
end

--------------------------------------------------------------------------
-- Rendering a page
--------------------------------------------------------------------------

local function Copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = v end
    return c
end

local function Snapshot(ctx)
    return {
        mentioned = Copy(ctx.mentioned), para = Copy(ctx.para), epithet = Copy(ctx.epithet),
        usedHere = Copy(ctx.usedHere), last = ctx.last,
        said = (function()
            local s = {}
            for k, v in pairs(ctx.said) do s[k] = Copy(v) end
            return s
        end)(),
    }
end

local function Restore(ctx, snap)
    for k, v in pairs(snap) do ctx[k] = v end
end

-- plan = {
--   key = "2026-10-26",       the page's identity; seeds every choice
--   now = <time>,             the page's own time, for "yesterday" and "on the 12th"
--   page = { ... },           facts about the session itself, read as page.* everywhere
--   paragraphs = {
--     { -- one paragraph: beats in order
--       { angle = "reunion", facts = { who = <person>, gapDays = 19, ... },
--         moves = { "gap" },    optional: which moves, else the angle's order
--         rel = "then",         optional: how its first sentence follows the last
--         short = true,         optional: prefer the shortest sentences
--         epithets = false,     optional: no relationship epithets in this beat
--                                 (someone met today has no history to name)
--         must = { "isRecordGap" }, optional: tags every sentence of the beat must say
--                                 (the point of the beat; flags count as said)
--         required = { "gap" }, optional: drop the beat if these can't be said
--       },
--     },
--   },
-- }
-- opts = {
--   voice = "plain",          "plain", "warm", "wry", "terse", or "mixed" (drawn per page)
--   memory = Pages.Memory(t), what earlier pages used; nothing remembered without it
--   commit = true,            record this page in memory (once, when it is first written)
--   picks = report.picks,     re-write a page exactly as before
--   epithets = true,          relationship text on a diary entry's first mention
-- }
-- Returns the page's text (paragraphs separated by a blank line) and a
-- report: picks (to re-write it), skipped beats and moves, and a trace.
-- The mix a "mixed" diary draws each page's voice from.
Pages.VOICE_MIX = { { "plain", 5 }, { "warm", 2 }, { "wry", 2 }, { "terse", 1 } }

-- The voice for a page: the one asked for, or for "mixed", one drawn by the
-- page's key, so a page keeps its voice however often it is written.
function Pages.VoiceFor(plan, voice)
    if voice ~= "mixed" then return voice or "plain" end
    local rng = NewRng(Hash((plan.key or "") .. "/voice"))
    local total = 0
    for i = 1, #Pages.VOICE_MIX do total = total + Pages.VOICE_MIX[i][2] end
    local r = rng.float() * total
    for i = 1, #Pages.VOICE_MIX do
        r = r - Pages.VOICE_MIX[i][2]
        if r <= 0 then return Pages.VOICE_MIX[i][1] end
    end
    return "plain"
end

function Pages.Render(plan, opts)
    opts = opts or {}
    local memory = opts.memory or NO_MEMORY
    local voice = Pages.VoiceFor(plan, opts.voice)
    local report = { picks = {}, skipped = {}, trace = {} }
    local ctx = { mentioned = {}, para = {}, epithet = {}, usedHere = {}, said = {}, last = nil }
    local paragraphs = {}

    for pi, para in ipairs(plan.paragraphs or {}) do
        ctx.para, ctx.last = {}, nil
        local sentences = {}
        for bi, beat in ipairs(para) do
            local angle = Pages.ANGLES[beat.angle]
            if not angle then
                report.skipped[#report.skipped + 1] = beat.angle .. " (no such angle)"
            else
                local f = Copy(beat.facts or {})
                f.page = f.page or plan.page
                local who = f.who
                local env = {
                    f = f, ctx = ctx, memory = memory, voice = voice,
                    epithets = opts.epithets ~= false and beat.epithets ~= false, plan = plan, short = beat.short,
                    must = beat.must,
                    whoKey = who and Key(who) or "page",
                }
                local snap = Snapshot(ctx)
                local written = {}
                local required = {}
                for _, r in ipairs(beat.required or {}) do required[r] = true end
                local failed = false

                for mi, moveName in ipairs(beat.moves or angle.order) do
                    local m = angle.moves[moveName]
                    local key = plan.key .. "/" .. pi .. "/" .. bi .. "/" .. beat.angle .. "/" .. moveName
                    env.rng = NewRng(Hash(key .. "/" .. env.whoKey))
                    local rel = (mi == 1 and beat.rel) or (mi > 1 and m and m.rel) or nil
                    local text, combo
                    if m then
                        text, combo = RenderMove(m, f, env, rel, opts.picks and opts.picks[key])
                    end
                    if text then
                        Commit(env, combo)
                        written[#written + 1] = text
                        report.picks[key] = ComboKey(combo)
                        report.trace[#report.trace + 1] = key .. " = " .. ComboKey(combo)
                    else
                        report.skipped[#report.skipped + 1] = key
                        if required[moveName] then
                            failed = true
                            break
                        end
                    end
                end

                if failed then
                    Restore(ctx, snap)
                    report.skipped[#report.skipped + 1] = "beat " .. pi .. "/" .. bi .. " (" .. beat.angle .. ")"
                else
                    for i = 1, #written do sentences[#sentences + 1] = written[i] end
                end
            end
        end
        if #sentences > 0 then paragraphs[#paragraphs + 1] = table.concat(sentences, " ") end
    end

    if opts.commit and opts.memory then
        memory:Turn()
        for id in pairs(ctx.usedHere) do memory:Use(id) end
    end
    report.voice = voice
    return table.concat(paragraphs, "\n\n"), report
end
