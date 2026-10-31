-- The next level: XP to go and how long at your recent XP per hour (across
-- sessions, AFK left out by the setting), max level, an unreadable bar; the
-- Totals row. The Levels view: a row per level with time played, what
-- happened, money and the main zone, its tooltip, the level recording began
-- at, a reload.
local ns = M.Login()
M.tick(1)
local loggedIn = date("%Y-%m-%d")

local function Stat(w, label)
	local all = M.descendants(w)
	for i, r in ipairs(all) do
		if r.kind == "FontString" and r:GetText() == label then return all[i + 1]:GetText() end
	end
end
local function Rows(list)
	local out = {}
	for _, row in ipairs(M.shown(list.rows)) do
		out[#out + 1] = table.concat({ row.what:GetText(), row.when:GetText(), row.where:GetText(), row.kind:GetText() }, " | ")
	end
	return out
end
-- Moves the clock to `hours` after this session began.
local function At(hours)
	M.advance(ns.session.start + hours * 3600 - time())
end

-- No rate before 10 minutes of play.
check(ns.NextLevelText() == "2,800 xp to go (0%)", "no rate yet: " .. tostring(ns.NextLevelText()))

-- Level 5: a quest, a kill and money in Elwynn Forest, half the bar in an hour.
M.fire("QUEST_TURNED_IN", 54, 250, 0)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.money = M.money + 12000
M.fire("PLAYER_MONEY")
M.xp = 1400
M.fire("PLAYER_XP_UPDATE", "player")
At(1)
check(ns.NextLevelText() == "1,400 xp to go (50%), about 1h 0m at 1,400 xp/h", "estimate: " .. tostring(ns.NextLevelText()))

-- AFK time is left out of the rate, or kept by the setting.
M.afk = true
M.fire("PLAYER_FLAGS_CHANGED", "player")
At(2)
check(ns.NextLevelText() == "1,400 xp to go (50%), about 1h 0m at 1,400 xp/h", "AFK left out: " .. tostring(ns.NextLevelText()))
ns.settings.ratesSkipAFK = false
check(ns.NextLevelText() == "1,400 xp to go (50%), about 2h 0m at 700 xp/h", "AFK kept: " .. tostring(ns.NextLevelText()))
ns.settings.ratesSkipAFK = true
M.afk = false
M.fire("PLAYER_FLAGS_CHANGED", "player")

-- Level 6: two kills and money spent in Westfall, and a death back in Elwynn
-- Forest.
M.xp, M.xpMax = 200, 3000
M.levelUp({ hp = 18 })
M.fire("PLAYER_XP_UPDATE", "player")
M.tick(1)
local reached6 = date("%Y-%m-%d %H:%M")
local up = TravelLogCharDB.log[#TravelLogCharDB.log]
check(up.type == "level" and up.level == 6 and up.took, "level-up logged with its time")
M.zone, M.subzone = "Westfall", "Sentinel Hill"
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Defias Thug dies, you gain 60 experience.")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Defias Thug dies, you gain 60 experience.")
M.money = M.money - 500
M.fire("PLAYER_MONEY")
M.zone, M.subzone = "Elwynn Forest", "Goldshire"
M.fire("PLAYER_DEAD")
At(3)
-- 3,000 xp in 2 hours not AFK.
check(ns.NextLevelText() == "2,800 xp to go (6%), about 1h 52m at 1,500 xp/h", "after the level-up: " .. tostring(ns.NextLevelText()))

-- The Totals row.
SlashCmdList.TRAVELLOG("")
local w = ns.window
check(Stat(w, "Next level") == "2,800 xp to go (6%), about 1h 52m at 1,500 xp/h", "totals row: " .. tostring(Stat(w, "Next level")))

-- The Levels view, after Events and Sessions.
w.Tabs[3]:Click()
local history = w.pages[3]
check(history.viewButtons[3]:GetText() == "Levels", "levels button")
history.viewButtons[3]:Click()
local view = history.views[3]
check(view:IsShown() and view.next:GetText() == "Next level: 2,800 xp to go (6%), about 1h 52m at 1,500 xp/h",
	"header: " .. tostring(view.next:GetText()))
local _, atLevel = ns.Played()
local rows = Rows(view.levels)
check(#rows == 2, "two levels: " .. #rows)
check(rows[1] == ("Level 6, %s played so far | |cff20ff20Now|r, %s | 2 XP kills, 1 death, -5s 0c | Westfall"):format(ns.Duration(atLevel), reached6),
	"current level: " .. tostring(rows[1]))
check(rows[2] == ("Level 5 in %s played | from %s | 1 quest, 1 XP kill, +1g 20s 0c | Elwynn Forest"):format(ns.Duration(up.took), loggedIn),
	"level recording began at: " .. tostring(rows[2]))

-- Hovering a level: XP by source, what it gave and the zones.
local shown = M.shown(view.levels.rows)
M.script(shown[1], "OnEnter")
check(GameTooltip.shown and table.concat(GameTooltip.lines, "; ") == "XP: kills 120; Gave: +18 health; Mostly in Westfall, Elwynn Forest",
	"current level's tooltip: " .. table.concat(GameTooltip.lines, "; "))
M.script(shown[1], "OnLeave")
M.script(shown[2], "OnEnter")
check(table.concat(GameTooltip.lines, "; ") == "XP: quests 250, kills 45; Mostly in Elwynn Forest",
	"older level's tooltip: " .. table.concat(GameTooltip.lines, "; "))
M.script(shown[2], "OnLeave")

-- After a reload the rate still counts the last session; a level reached
-- since shows its time.
ns = M.Reload()
M.tick(1)
check(ns.NextLevelText() == "2,800 xp to go (6%), about 1h 52m at 1,500 xp/h", "rate across sessions: " .. tostring(ns.NextLevelText()))
M.xp, M.xpMax = 100, 3200
M.levelUp()
M.fire("PLAYER_XP_UPDATE", "player")
M.tick(1)
local up7 = TravelLogCharDB.log[#TravelLogCharDB.log]
SlashCmdList.TRAVELLOG("")
ns.window.Tabs[3]:Click()
history = ns.window.pages[3]
history.viewButtons[3]:Click()
rows = Rows(history.views[3].levels)
check(#rows == 3 and rows[1] == "Level 7, under a minute played so far | |cff20ff20Now|r, " .. date("%Y-%m-%d %H:%M", up7.time) .. " |  | ",
	"new level, nothing yet: " .. tostring(rows[1]))
check(rows[2] == ("Level 6 in %s played | %s | 2 XP kills, 1 death, -5s 0c | Westfall"):format(ns.Duration(up7.took), reached6),
	"level left: " .. tostring(rows[2]))

-- Max level, and a bar that can't be read.
M.maxLevel = 7
check(ns.NextLevelText() == "max level", "max level")
M.maxLevel = 60
M.secrets[M.xp] = true
check(ns.NextLevelText() == nil, "unreadable bar")
SlashCmdList.TRAVELLOG("")
SlashCmdList.TRAVELLOG("")
check(Stat(ns.window, "Next level") == "not known", "row without a bar: " .. tostring(Stat(ns.window, "Next level")))
M.secrets[M.xp] = nil

-- A new character: the level it's at, from its first entry.
M.Logout()
M.player = { name = "Altie", realm = "Forever" }
ns = M.Login()
SlashCmdList.TRAVELLOG("")
ns.window.Tabs[3]:Click()
history = ns.window.pages[3]
history.viewButtons[3]:Click()
rows = Rows(history.views[3].levels)
check(#rows == 1 and rows[1] == "Level 7 | |cff20ff20Now|r, from " .. date("%Y-%m-%d") .. " |  | Elwynn Forest",
	"a new character: " .. tostring(rows[1]))
