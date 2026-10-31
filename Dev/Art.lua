-- /sd art: which journal art this client resolved, and the paper and grain
-- trials (Style.NextPaper in UI/Style/Art.lua, Style.SetGrain in
-- UI/Style/Book.lua). Development tooling, listed in /sd help only while
-- debug is on.

local addonName, ns = ...

local Style = ns.Style

function Style.ReportArt()
    local keys = {}
    for key, list in pairs(Style.ART) do
        if #list > 0 then keys[#keys + 1] = key end
    end
    table.sort(keys)
    ns.Print("journal art (first existing candidate wins):")
    for _, key in ipairs(keys) do
        local path = Style.Art(key)
        DEFAULT_CHAT_FRAME:AddMessage(("   %s  %s  %s"):format(
            path and "|cff40c040yes|r" or "|cffc04040no |r", key, path or ""))
    end
    if not GetFileIDFromPath then
        ns.Print("GetFileIDFromPath is missing, so every first candidate is assumed.")
    end
end

ns.Slash.Register("art", function(rest)
    local percent = rest:match("^grain%s+(%d+)$")
    if percent then
        Style.SetGrain(tonumber(percent))
        ns.Print("paper grain at %d%%.", Style.GrainStrength() * 100)
    elseif rest == "paper" then
        Style.NextPaper()
    else
        Style.ReportArt()
    end
end, "which journal art this client has; |cffffd100/sd art paper|r tries the next paper, "
    .. "|cffffd100/sd art grain 0-300|r sets the paper grain in percent", { dev = true })
