-- Sessions: where they start and end, experience gained (across a level-up),
-- money, time AFK and rates without it (or with, by the setting), what
-- happened in each, /tl sessions and the History tab's Sessions view, across
-- a reload.
local ns = M.Login()
local loggedIn = date("%m-%d %H:%M")

local function Said(pattern, plain)
	for _, line in ipairs(M.out) do
		if line:find(pattern, 1, plain) then return line end
	end
end
local function Rows(list)
	local out = {}
	for _, row in ipairs(M.shown(list.rows)) do
		out[#out + 1] = table.concat({ row.what:GetText(), row.when:GetText(), row.where:GetText(), row.kind:GetText() }, " | ")
	end
	return out
end

-- Where it started.
local s = ns.session
check(s.zone == "Elwynn Forest" and s.subzone == "Goldshire" and s.map == 1429 and s.x == 42 and s.y == 65,
	"login place: " .. tostring(s.subzone) .. " " .. tostring(s.x))

-- Experience: gains add up, a level-up's wrap is counted, other units' updates aren't.
M.xp = 1000
M.fire("PLAYER_XP_UPDATE", "player")
check(ns.session.xp == 1000, "xp gained: " .. tostring(ns.session.xp))
M.xp, M.xpMax, M.level = 500, 3000, 6
M.fire("PLAYER_LEVEL_UP", 6)
M.fire("PLAYER_XP_UPDATE", "player")
check(ns.session.xp == 3300, "xp across a level-up: " .. tostring(ns.session.xp))
M.fire("PLAYER_XP_UPDATE", "party1")
check(ns.session.xp == 3300, "other units ignored")

-- What happened: money, a quest, an XP kill and a death.
M.money = M.money + 12000
M.fire("PLAYER_MONEY")
M.fire("QUEST_TURNED_IN", 54, 250, 75)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.fire("PLAYER_DEAD")

-- An hour of the two AFK: half an hour back at the keyboard in between, and
-- still AFK now. Others' flags don't count.
local function AFK(on)
	M.afk = on
	M.fire("PLAYER_FLAGS_CHANGED", "player")
end
M.advance(1800)
AFK(true)
M.advance(1800)
M.fire("PLAYER_FLAGS_CHANGED", "party1")
AFK(false)
check(ns.session.afk == 1800, "afk time: " .. tostring(ns.session.afk))
M.advance(1800)
AFK(true)
M.fire("PLAYER_FLAGS_CHANGED", "player")
M.advance(1800)
M.zone, M.subzone, M.mapID, M.x, M.y = "Stormwind City", "Trade District", 1453, 0.6, 0.7

M.out = {}
SlashCmdList.TRAVELLOG("sessions")
check(Said("Last 1 session:"), "sessions heading")
local line = Said("Now")
check(line == "  " .. loggedIn .. "  |cff20ff20Now|r, 2h 0m (1h 0m AFK), level 5 to 6, Goldshire to Trade District  +1g 20s 0c (1g 20s 0c/h), 3,300 xp (3,300/h)  1 quest, 1 XP kill, 1 death",
	"current session, rates without AFK: " .. tostring(line))
ns.settings.ratesSkipAFK = false
M.out = {}
SlashCmdList.TRAVELLOG("sessions")
check(Said("Now", true) and Said("(60s 0c/h), 3,300 xp (1,650/h)", true), "rates with AFK: " .. tostring(Said("Now")))

-- After a reload while AFK: the first session is closed and kept with its AFK
-- time, the setting too, and a new one starts AFK.
ns = M.Reload()
local reloaded = date("%Y-%m-%d %H:%M")
local first = TravelLogCharDB.sessions[1]
check(#TravelLogCharDB.sessions == 2 and first.stop == first.start + 7200 and first.xp == 3300
	and first.levelEnd == 6 and first.moneyEnd == 22000 and first.afk == 3600, "first session saved")
check(ns.settings.ratesSkipAFK == false, "setting saved")
check(first.zone == "Elwynn Forest" and first.zoneEnd == "Stormwind City" and first.subzoneEnd == "Trade District"
	and first.mapEnd == 1453 and first.xEnd == 60 and first.yEnd == 70, "logout place saved")
check(ns.session.zone == "Stormwind City" and ns.session.subzone == "Trade District", "next session starts there")
M.advance(60)
AFK(false)
check(ns.session.afk == 60, "afk since login: " .. tostring(ns.session.afk))
M.advance(120)
M.xp = 600
M.fire("PLAYER_XP_UPDATE", "player")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")

M.out = {}
SlashCmdList.TRAVELLOG("sessions 1")
check(Said("Last 1 session:") and Said("Now|r, 3m %(1m AFK%), level 6, Trade District  100 xp  2 XP kills$"),
	"short sessions show no rates: " .. tostring(Said("Now")))
M.out = {}
SlashCmdList.TRAVELLOG("sessions")
check(Said("Last 2 sessions:") and Said("  " .. loggedIn .. "  2h 0m (1h 0m AFK), level 5 to 6, Goldshire to Trade District  ", true), "older session listed")
M.out = {}
SlashCmdList.TRAVELLOG("sessions lots")
check(Said("/tl sessions %[n%]"), "a bad count shows the help")

-- The Sessions view, newest first.
SlashCmdList.TRAVELLOG("")
local history = ns.window.pages[3]
ns.window.Tabs[3]:Click()
check(history.viewButtons[2]:GetText() == "Sessions", "sessions button")
history.viewButtons[2]:Click()
local view = history.views[2]
check(view:IsShown() and not history.views[1]:IsShown(), "sessions view shown")
local rows = Rows(view.sessions)
check(#rows == 2 and rows[1] == "|cff20ff20Now|r, 3m (1m AFK), level 6, Trade District | " .. reloaded .. " | 100 xp | 2 XP kills",
	"current session row: " .. tostring(rows[1]))
check(rows[2] == "2h 0m (1h 0m AFK), level 5 to 6, Goldshire to Trade District | " .. date("%Y-%m-%d %H:%M", first.start) .. " | +1g 20s 0c (60s 0c/h), 3,300 xp (1,650/h) | 1 quest, 1 XP kill, 1 death",
	"older session row: " .. tostring(rows[2]))
check(view.found:GetText() == "2 sessions, 2h 3m in all", "total: " .. view.found:GetText())

-- The setting's checkbox turns AFK time back out of the rates, and the view follows.
ns.window.Tabs[2]:Click()
local skip
for _, r in ipairs(M.descendants(ns.window)) do
	if r.kind == "CheckButton" and r.Text:GetText() == "Leave AFK time out of gold and XP per hour" then skip = r end
end
check(skip and not skip:GetChecked(), "setting checkbox, off")
skip:Click()
check(ns.settings.ratesSkipAFK == true, "setting on")
ns.window.Tabs[3]:Click()
check(Rows(view.sessions)[2]:find("(1g 20s 0c/h), 3,300 xp (3,300/h)", 1, true), "rates without AFK again: " .. Rows(view.sessions)[2])

-- A zone still unknown at login is filled in at the first loading screen, and
-- later loading screens don't move it. Sessions without places show none.
M.zone, M.subzone = "", ""
ns = M.Reload()
check(ns.session.zone == nil and ns.session.map == 1453, "zone unknown at login")
M.out = {}
SlashCmdList.TRAVELLOG("sessions 1")
check(Said("Now|r, under a minute, level 6  "), "no place, no route: " .. tostring(Said("Now")))
M.zone, M.subzone = "Stormwind City", "Old Town"
M.fire("PLAYER_ENTERING_WORLD", false, false)
check(ns.session.zone == "Stormwind City" and ns.session.subzone == "Old Town", "filled in at the loading screen")
M.zone, M.subzone = "Elwynn Forest", "Goldshire"
M.fire("PLAYER_ENTERING_WORLD", false, false)
check(ns.session.subzone == "Old Town", "kept after the next loading screen")
