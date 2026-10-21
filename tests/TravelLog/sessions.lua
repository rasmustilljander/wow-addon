-- Sessions: experience gained (across a level-up), money, what happened in
-- each, /tl sessions and the History tab's Sessions view, across a reload.
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
M.advance(2 * 3600)

M.out = {}
SlashCmdList.TRAVELLOG("sessions")
check(Said("Last 1 session:"), "sessions heading")
local line = Said("Now")
check(line == "  " .. loggedIn .. "  |cff20ff20Now|r, 2h 0m, level 5 to 6  +1g 20s 0c (60s 0c/h), 3,300 xp (1,650/h)  1 quest, 1 XP kill, 1 death",
	"current session: " .. tostring(line))

-- After a reload: the first session is closed and kept, a new one starts.
ns = M.Reload()
local reloaded = date("%Y-%m-%d %H:%M")
local first = TravelLogCharDB.sessions[1]
check(#TravelLogCharDB.sessions == 2 and first.stop == first.start + 7200 and first.xp == 3300
	and first.levelEnd == 6 and first.moneyEnd == 22000, "first session saved")
M.advance(120)
M.xp = 600
M.fire("PLAYER_XP_UPDATE", "player")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")

M.out = {}
SlashCmdList.TRAVELLOG("sessions 1")
check(Said("Last 1 session:") and Said("Now|r, 2m, level 6  100 xp  2 XP kills$"),
	"short sessions show no rates: " .. tostring(Said("Now")))
M.out = {}
SlashCmdList.TRAVELLOG("sessions")
check(Said("Last 2 sessions:") and Said("  " .. loggedIn .. "  2h 0m, level 5 to 6", true), "older session listed")
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
check(#rows == 2 and rows[1] == "|cff20ff20Now|r, 2m, level 6 | " .. reloaded .. " | 100 xp | 2 XP kills",
	"current session row: " .. tostring(rows[1]))
check(rows[2] == "2h 0m, level 5 to 6 | " .. date("%Y-%m-%d %H:%M", first.start) .. " | +1g 20s 0c (60s 0c/h), 3,300 xp (1,650/h) | 1 quest, 1 XP kill, 1 death",
	"older session row: " .. tostring(rows[2]))
check(view.found:GetText() == "2 sessions, 2h 2m in all", "total: " .. view.found:GetText())
