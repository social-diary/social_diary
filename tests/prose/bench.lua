-- How long a page takes to write: luajit tests/prose/bench.lua [root] [rounds]
-- Renders tests/prose/pages/week.lua `rounds` times with fresh memory and prints
-- the slowest and average page, and the slowest moves.

local root = arg[1] or "."
local rounds = tonumber(arg[2] or 20)

local files = { "UI/Words/Pages/English.lua", "Core/Pages/Render.lua", "UI/Words/Pages/Slots.lua", "UI/Words/Pages/Lexicon.lua" }
local p = io.popen('ls "' .. root .. '/UI/Words/Pages/Angles"')
for line in p:lines() do
    if line:match("%.lua$") then files[#files + 1] = "UI/Words/Pages/Angles/" .. line end
end
p:close()

local ns = { _test = {} }
for _, file in ipairs(files) do assert(loadfile(root .. "/" .. file))("SocialDiary", ns) end
local Pages = ns.Pages

local plans = dofile(root .. "/tests/prose/pages/week.lua")
local times, slowest, total, n = {}, 0, 0, 0
for r = 1, rounds do
    local memory = Pages.Memory({})
    for i, plan in ipairs(plans) do
        plan.key = plan.key:gsub("#.*", "") .. "#" .. r
        local t0 = os.clock()
        Pages.Render(plan, { voice = ({ "plain", "warm", "wry", "terse" })[(r % 4) + 1], memory = memory, commit = true })
        local dt = (os.clock() - t0) * 1000
        total, n = total + dt, n + 1
        if dt > slowest then slowest = dt end
    end
end

local pieces = 0
for _, a in pairs(Pages.ANGLES) do
    for _, m in pairs(a.moves) do pieces = pieces + m.pieces end
end
print(string.format("%d pieces; %d pages: average %.1f ms, slowest %.1f ms", pieces, n, total / n, slowest))
