-- XP by source: quests, kills, discoveries and other in the totals, counted
-- from a character's saved sessions the first time, then as it happens;
-- /tl stats, the Totals row (one character and all), /tl sessions, the
-- Sessions view's tooltip, and a reload.
local ns = M.Login()

local function Said(pattern)
	for _, line in ipairs(M.out) do
		if line:find(pattern, 1, true) then return line end
	end
end
local function Stat(w, label)
	local all = M.descendants(w)
	for i, r in ipairs(all) do
		if r.kind == "FontString" and r:GetText() == label then return all[i + 1]:GetText() end
	end
end

-- A character from before XP by source: an old kill XP counter, a session
-- that recorded XP with a quest, a kill and a discovery in it, and an older
-- one that didn't, whose kill is left out.
local now = M.now
local char = TravelLogCharDB
table.insert(char.sessions, 1, { start = now - 7200, stop = now - 3600, xp = 900 })
table.insert(char.sessions, 1, { start = now - 20000, stop = now - 18000 })
for _, e in ipairs({
	{ type = "kill", time = now - 19000, name = "Old Wolf", xp = 50 },
	{ type = "questdone", time = now - 7000, id = 54, xp = 400, money = 0 },
	{ type = "kill", time = now - 6000, name = "Kobold Vermin", xp = 100 },
	{ type = "discover", time = now - 5000, place = "Jerod's Landing", xp = 30 },
	{ type = "kill", time = now - 3000, name = "Between Sessions", xp = 70 },
}) do
	table.insert(char.log, #char.log + 1, e)
end
table.sort(char.log, function(a, b) return a.time < b.time end)
ns.stats.experience, ns.stats.xp = nil, { kills = 999 }
ns = M.Reload()
local xp = ns.stats.experience
check(xp and xp.total == 900 and xp.quests == 400 and xp.kills == 100 and xp.discoveries == 30,
	"counted from saved sessions: " .. tostring(xp and xp.total) .. " " .. tostring(xp and xp.kills))
check(ns.stats.xp == nil, "old kill XP counter dropped")

-- Counted once: another login doesn't add the sessions again.
ns = M.Reload()
check(ns.stats.experience.total == 900 and ns.stats.experience.kills == 100, "not counted again")

-- As it happens: the bar's gain is the total, and each source its own.
M.xp = 1000
M.fire("PLAYER_XP_UPDATE", "player")
M.fire("QUEST_TURNED_IN", 60, 600, 0)
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
M.fire("UI_INFO_MESSAGE", 0, "Discovered Goldshire: 30 experience gained")
check(ns.stats.experience.total == 1900 and ns.stats.experience.quests == 1000 and ns.stats.experience.kills == 145
	and ns.stats.experience.discoveries == 60, "counted as it happens: " .. ns.stats.experience.total)

-- Other is what's left of the total; sources are largest first and empty ones left out.
check(ns.XPText(ns.stats.experience) == "1,900: quests 1,000, other 695, kills 145, discoveries 60",
	"xp text: " .. ns.XPText(ns.stats.experience))
check(ns.XPText({ total = 100, kills = 100 }) == "100: kills 100", "no other")
check(ns.XPText({ total = 50, quests = 80 }) == "50: quests 80", "sources beyond the bar's total")
check(ns.XPText(nil) == "0" and ns.XPText({}) == "0", "none")

M.out = {}
SlashCmdList.TRAVELLOG("stats")
check(Said("XP: 1,900: quests 1,000, other 695, kills 145, discoveries 60"), "/tl stats")

M.out = {}
SlashCmdList.TRAVELLOG("sessions 1")
check(Said("1,000 xp: quests 600, other 325, kills 45, discoveries 30  1 quest, 1 XP kill"),
	"/tl sessions: " .. tostring(Said("Now")))

-- The Totals row.
SlashCmdList.TRAVELLOG("")
local w = ns.window
check(Stat(w, "XP") == "1,900: quests 1,000, other 695, kills 145, discoveries 60", "totals row: " .. tostring(Stat(w, "XP")))

-- Hovering a session in the Sessions view: where its XP came from, and
-- nothing for one without XP.
w.Tabs[3]:Click()
local history = w.pages[3]
history.viewButtons[2]:Click()
local rows = M.shown(history.views[2].sessions.rows)
GameTooltip.shown = false
M.script(rows[1], "OnEnter")
check(GameTooltip.shown and GameTooltip.lines[1] == "1,000 xp: quests 600, other 325, kills 45, discoveries 30",
	"session tooltip: " .. tostring(GameTooltip.lines[1]))
M.script(rows[1], "OnLeave")
check(not GameTooltip.shown, "tooltip hidden")
M.script(rows[2], "OnEnter")
check(not GameTooltip.shown, "no tooltip without XP")

-- Saved, and an alt's first login counts its own; all characters add up.
ns = M.Reload()
check(ns.stats.experience.total == 1900 and ns.stats.experience.discoveries == 60, "saved")
M.Logout()
M.player = { name = "Altie", realm = "Forever" }
ns = M.Login()
check(ns.stats.experience and ns.stats.experience.total == 0, "an alt starts at 0")
M.xp = 1300
M.fire("PLAYER_XP_UPDATE", "player")
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience.")
check(ns.XPText(ns.StatsFor(nil).experience) == "2,200: quests 1,000, other 950, kills 190, discoveries 60",
	"all added up: " .. ns.XPText(ns.StatsFor(nil).experience))
