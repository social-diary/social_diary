-- Settings: Feedback (UI/Settings/Sections/Feedback.lua), listed right above
-- About: the two web addresses on read-only slips to copy (Style.CopyField),
-- the version a bug report asks for, and /sd debug.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

local ISSUES = "https://github.com/social-diary/social_diary/issues"
local COMMENTS = "https://www.curseforge.com/wow/addons/social-diary/comments"

--------------------------------------------------------------------------
Section("settings: Feedback, the way to report a bug")

mock.RunTimers()
local P = ns.UI.SettingsPage()

-- Registered, and listed directly above About, after Memory.
local list = ns.UI.Settings.Sections()
local at = {}
for i, s in ipairs(list) do at[s.key] = i end
Check(at.feedback ~= nil, "no Feedback section")
Eq(at.about, (at.feedback or 0) + 1, "Feedback is not directly above About")
Eq(at.memory, (at.feedback or 0) - 1, "Feedback is not directly under Memory")
local function NavY(key) return P.nav[key].recorded.points[1].args[2] end
Check(NavY("memory") > NavY("feedback") and NavY("feedback") > NavY("about"),
    "the Feedback row is not placed between Memory and About")
Eq(P.nav.feedback.label:GetText(), "Feedback", "the Feedback row's name")
Eq(P.nav.feedback.about:GetText(), "Bugs, ideas and comments", "the Feedback row's small print")

P.nav.feedback:Click()
Eq(P:Section(), "feedback", "clicking Feedback did not open it")
Check(P.panes.feedback:IsShown() and not P.panes.about:IsShown(), "the Feedback page did not open")

-- Both addresses, exactly, each on its own slip on the Feedback page.
local issues, comments = P.feedbackLinks.issues, P.feedbackLinks.comments
Eq(issues.box:GetText(), ISSUES, "the GitHub issues address")
Eq(comments.box:GetText(), COMMENTS, "the CurseForge comments address")
Eq(issues.parent, P.panes.feedback, "the issues slip is not on the Feedback page")
Eq(comments.parent, P.panes.feedback, "the comments slip is not on the Feedback page")
Eq(issues.box.frameType, "EditBox", "the address is not in a box to copy from")
Eq(P.feedbackCopyHint:GetText(), "Copy and Paste this link", "the hint under the addresses")

-- Selected whole on the cursor and on a click, for Ctrl+C.
local function Highlights(box)
    local h = box.recorded.calls.HighlightText
    return h ~= nil and h.n == 0, h
end
local box = issues.box
box.recorded.calls.HighlightText = nil
box:SetFocus()
box.scripts.OnEditFocusGained(box)
Check(Highlights(box), "the cursor in the box did not select the address")
box.recorded.calls.HighlightText = nil
box.scripts.OnMouseUp(box, "LeftButton")
Check(Highlights(box), "a click on the box did not select the address")

-- Typed into, cut or pasted over: the address comes back, still selected.
box.recorded.calls.HighlightText = nil
box.text = ISSUES .. "x"
box.scripts.OnTextChanged(box, true)
Eq(box:GetText(), ISSUES, "a letter typed changed the address")
Check(Highlights(box), "the address was not selected again after typing")
box.text = ""
box.scripts.OnTextChanged(box, true)
Eq(box:GetText(), ISSUES, "cutting the address emptied the box")

-- Enter and Escape let go; letting go puts it back too, unselected.
box.scripts.OnEnterPressed(box)
Check(not box:HasFocus(), "Enter did not let go of the box")
box:SetFocus()
box.scripts.OnEscapePressed(box)
Check(not box:HasFocus(), "Escape did not let go of the box")
box.text = "hello"
box.scripts.OnEditFocusLost(box)
Eq(box:GetText(), ISSUES, "letting go left a changed address")
local h = box.recorded.calls.HighlightText
Check(h and h[1] == 0 and h[2] == 0, "letting go left the address selected")

-- The other slip is its own: editing one leaves the other alone.
comments.box.text = "x"
comments.box.scripts.OnTextChanged(comments.box, true)
Eq(comments.box:GetText(), COMMENTS, "the comments address was not put back")
Eq(issues.box:GetText(), ISSUES, "the issues address changed with the other")

-- The version, and the advice on what to write down.
Check(P.feedbackVersion:GetText():find(ns.version, 1, true), "the version is not shown")
Check(P.feedbackDebug:GetText():find("write down", 1, true), "the advice on reporting is not shown")
