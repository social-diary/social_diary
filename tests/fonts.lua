-- The fonts as families (UI/Style/Tokens.lua): the file itself is run again
-- on a table of its own, under a client that has CreateFontFamily, one that
-- has not, and one that won't give the roman font back. The mock has none, so
-- every other test file runs the plain fonts, as before.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
T.Boot()

local MORPHEUS, FRIZ = "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF"

local function FakeFont(name, members)
    local font = { name = name, members = members }
    function font:GetFont() return self.file end
    function font:SetFont(file, size, flags) self.file, self.size, self.flags = file, size, flags end
    function font:SetTextColor(...) self.color = { ... } end
    function font:SetShadowOffset(x, y) self.shadow = { x, y } end
    function font:SetShadowColor(...) self.shadowColor = { ... } end
    return font
end

local function Run(env)
    local saved = {}
    for _, key in ipairs({ "CreateFont", "CreateFontFamily", "GetLocale" }) do saved[key] = _G[key] end
    _G.CreateFont = FakeFont
    _G.CreateFontFamily, _G.GetLocale = env.family, env.locale
    local chunk = assert(loadfile("UI/Style/Tokens.lua"))
    local ns = {}
    chunk("social_diary", ns)
    for key, value in pairs(saved) do _G[key] = value end
    return ns.Style
end

local function RealFamily(name, members)
    local family = FakeFont(name, members)
    family.file, family.size, family.flags = members[1].file, members[1].height, members[1].flags
    family.alphabets = {}
    function family:GetFontObjectForAlphabet(alphabet)
        self.alphabets[alphabet] = self.alphabets[alphabet] or FakeFont()
        return self.alphabets[alphabet]
    end
    return family
end
local function English() return "enUS" end

--------------------------------------------------------------------------
Section("no CreateFontFamily: the plain fonts")

local plain = Run({ locale = English })
Eq(plain.FONT.body.name, "SocialDiaryFontBody", "the plain font's name")
Eq(plain.FONT.body.file, FRIZ, "the plain font's file")
Eq(plain.FONT.body.size, 13, "the plain font's size")
Eq(plain.FONT.body.flags, "", "the plain font's flags")
Check(plain.FONT.body.members == nil, "a plain font with members")

--------------------------------------------------------------------------
Section("with it: a family per font, its Latin the same")

local fam = Run({ family = RealFamily, locale = English })
for key, font in pairs(fam.FONT) do
    local same = plain.FONT[key]
    Eq(font:GetFont(), same.file, key .. "'s file")
    Eq(font.size, same.size, key .. "'s size")
    Eq(font.flags, same.flags, key .. "'s flags")
    Eq(font.name, same.name, key .. "'s name")
    Eq(table.concat(font.color, ","), table.concat(same.color, ","), key .. "'s ink")
    Eq(font.shadow[1], same.shadow[1], key .. "'s shadow")
    if key ~= "cover" then
        Eq(#font.members, 5, key .. "'s members")
        Eq(font.members[1].alphabet, "roman", key .. "'s first member")
        for _, member in ipairs(font.members) do
            Eq(member.height, same.size, key .. "'s " .. member.alphabet .. " height")
            Eq(member.flags, "", key .. "'s " .. member.alphabet .. " flags")
        end
        -- Each member is inked as the family is.
        for alphabet, object in pairs(font.alphabets) do
            Eq(table.concat(object.color, ","), table.concat(same.color, ","), key .. "'s " .. alphabet .. " ink")
        end
        Eq(next(font.alphabets) ~= nil, true, key .. "'s members were not inked")
    end
end
Check(fam.FONT.cover.members == nil, "the cover is a family")
Eq(fam.FONT.cover.shadowColor[4], 0.6, "the cover's shadow")

local function Member(font, alphabet)
    for _, member in ipairs(font.members) do
        if member.alphabet == alphabet then return member.file end
    end
end
Eq(Member(fam.FONT.body, "russian"), "Fonts\\FRIZQT___CYR.TTF", "Friz's Cyrillic")
Eq(Member(fam.FONT.body, "korean"), "Fonts\\2002.TTF", "Friz's Korean")
Eq(Member(fam.FONT.body, "simplifiedchinese"), "Fonts\\ARKai_T.ttf", "Friz's Simplified")
Eq(Member(fam.FONT.body, "traditionalchinese"), "Fonts\\blei00d.TTF", "Friz's Traditional")
Eq(Member(fam.FONT.title, "russian"), "Fonts\\MORPHEUS_CYR.TTF", "Morpheus's Cyrillic")
Eq(Member(fam.FONT.title, "korean"), "Fonts\\K_Pagetext.TTF", "Morpheus's Korean")
Eq(fam.FONT.title:GetFont(), MORPHEUS, "Morpheus stays roman")
Eq(Member(fam.FONT.personName, "russian"), "Fonts\\FRIZQT___CYR.TTF", "Goodmountain's Cyrillic is not Morpheus's")

--------------------------------------------------------------------------
Section("what can't be a family stays plain")

-- A client on another alphabet would read our Latin through its member.
for _, locale in ipairs({ "koKR", "zhCN", "zhTW", "ruRU" }) do
    local style = Run({ family = RealFamily, locale = function() return locale end })
    Check(style.FONT.body.members == nil, "a family on a " .. locale .. " client")
    Eq(style.FONT.body.file, FRIZ, "the plain font on a " .. locale .. " client")
end
local failing = Run({ family = function() error("no") end, locale = English })
Eq(failing.FONT.note.file, FRIZ, "a family that errors leaves no plain font")
local without = Run({ family = function(name) return FakeFont(name) end, locale = English })
Eq(without.FONT.note.file, FRIZ, "a family without its roman font was kept")
