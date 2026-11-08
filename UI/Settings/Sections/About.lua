-- Settings: About, the last section (UI/Settings/Page.lua lists them): a
-- group with no pane of its own, its row the name alone. Its subpages hang
-- under it only while it or one of them is open (`collapsed`), so the left
-- page stays short: Feedback (Feedback.lua), Changelog (Changelog.lua) and
-- Credits (Credits.lua). Turning to About opens Feedback, the first.

local addonName, ns = ...

ns.UI.Settings.RegisterSection("about", { order = 55, label = "About", collapsed = true })
