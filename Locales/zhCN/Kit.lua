-- 简体中文（中国大陆）：UI/Kit、UI/Map、UI/Pad、UI/Paper（确认弹窗、按键绑定栏、热力图、手柄提示与纸片界面）
-- Voice: .claude/skills/translate/voices/zhCN.md
local addonName, ns = ...
if not ns.Locale.Is("zhCN") then return end

ns.Locale.Add("zhCN", {
    -- UI/Kit/Confirm.lua
    ["Delete"] = "删除",
    ["Cancel"] = "取消",
    ["Delete everything Social Diary knows about %s?\n\nThis cannot be undone."] = "要删除Social Diary里关于%s的一切吗？\n\n此操作无法撤销。",
    ["Remove %s from the diary?\n\nTheir history can stay as an ordinary character, where the buffer's retention rules apply to it again."] = "要把%s从日记里移除吗？\n\n对方的历史可以留作普通角色，重新按缓冲区的保留规则保存。",
    ["Keep history"] = "保留历史",
    ["Delete everything"] = "全部删除",
    -- UI/Kit/Keys.lua
    ["That key stays with the game. Choose another."] = "这个按键归游戏保留，换一个。",
    ["Not during a fight. Try again after it."] = "战斗中不行，结束后再试。",
    ["%1$s is set to %2$s.\n\nUse it for %3$s instead?"] = "%1$s已用于%2$s。\n\n改用于%3$s吗？",
    ["Use it"] = "改用它",
    ["It was %s until now."] = "此前是%s。",
    ["press a key"] = "按一个键",
    ["Escape to cancel"] = "按Esc取消",
    ["Change"] = "修改",
    ["no key"] = "无按键",
    ["Choose one"] = "选一个",
    -- UI/Map/HeatSheet.lua
    ["Map %d"] = "地图%d",
    ["%1$s (%2$d)"] = "%1$s（%2$d）",
    ["Show map"] = "显示地图",
    ["Everyone"] = "所有人",
    ["ALSO SEEN IN"] = "还见于",
    ["Your diary was seen here %d time|Your diary was seen here %d times##plural"] = "你的日记在此记下%d次照面",
    ["Seen here %d time|Seen here %d times##plural"] = "在此记下%d次照面",
    ["Just %s"] = "仅%s",
    ["Just them"] = "仅对方",
    ["No maps yet"] = "还没有地图",
    ["Nobody from your diary seen on a map yet."] = "日记里还没人在地图上出现过。",
    ["Not seen on a map yet.\nThis fills in as you see them nearby."] = "还没在地图上见过。\n你在附近见到对方时，这里就会填上。",
    -- UI/Pad/Controls.lua
    ["Write"] = "写",
    ["Done writing"] = "写完",
    ["Choose"] = "选择",
    ["Add the tag"] = "添加标签",
    ["Take the tag off"] = "去掉标签",
    ["Unlink them"] = "取消关联",
    ["Choose a keyboard key"] = "选一个键盘按键",
    ["Pick it up"] = "拿起",
    ["Stop listening"] = "停止监听",
    ["Tick"] = "勾选",
    ["Untick"] = "取消勾选",
    -- UI/Pad/Menu.lua
    ["See the choices"] = "查看选项",
    ["Put the menu away"] = "收起菜单",
    ["Back to the menu"] = "返回菜单",
    -- UI/Paper/LinkSheet.lua
    ["WITH THEM THEN"] = "当时在一起",
    ["WITH THEM BEFORE"] = "之前在一起",
    ["EVERYONE ELSE"] = "其他所有人",
    ["Link others"] = "关联其他人",
    ["Search names, tags, notes"] = "搜索名字、标签、便条",
    ["Nobody in the diary matches."] = "日记里没有相符的人。",
    ["%d linked"] = "已关联%d人",
    -- UI/Paper/NoteSheet.lua
    ["Unlink %s"] = "取消与%s的关联",
    ["ABOUT"] = "关于谁",
    ["What happened? Write it down while you remember it."] = "发生了什么？趁还记得，写下来。",
    ["Delete this note"] = "删除这张便条",
    ["Save"] = "保存",
    ["Link who it is about"] = "关联所写的人",
    ["A new note"] = "新便条",
    ["Your note"] = "你的便条",
    ["Written %1$s %2$s##zone"] = "%1$s%2$s写下",
    ["Written %s"] = "%s写下",
    -- UI/Paper/Strip.lua
    ["“##quote open"] = "“",
    ["”##quote close"] = "”",
})
