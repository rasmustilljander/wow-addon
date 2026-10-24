-- Rested bonus XP: counted from the rested pool going down (two pool points
-- per bonus XP, a partly rested last kill too), not from it going up, an
-- unreadable pool, max level or a reload; taken out of kills (or other) in
-- XP by source; /tl stats, /tl sessions, the Totals row, the Sessions
-- tooltip, and sessions saved without it.
M.rested = 1000
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
local function Kill(xp, pool, poolFirst)
	M.xp, M.rested = M.xp + xp, pool
	if poolFirst then M.fire("UPDATE_EXHAUSTION") end
	M.fire("PLAYER_XP_UPDATE", "player")
	if not poolFirst then M.fire("UPDATE_EXHAUSTION") end
	M.fire("CHAT_MSG_COMBAT_XP_GAIN", ("Kobold Worker dies, you gain %d experience."):format(xp))
end

-- A rested kill: 45 XP doubled uses 90 pool points. The pool can change
-- before or after the XP bar; it's counted once either way.
Kill(90, 910, true)
check(ns.session.rested == 45 and ns.stats.experience.rested == 45, "rested kill: " .. tostring(ns.session.rested))
Kill(90, 820, false)
check(ns.session.rested == 90 and ns.stats.experience.rested == 90, "pool after the bar: " .. tostring(ns.session.rested))

-- The pool going up (resting) is a new baseline, and so is an unreadable one.
M.rested = 2000
M.fire("UPDATE_EXHAUSTION")
M.secrets[1500] = true
M.rested = 1500
M.fire("UPDATE_EXHAUSTION")
M.secrets = {}
M.rested = 30
M.fire("UPDATE_EXHAUSTION")
check(ns.session.rested == 90, "baselines only: " .. tostring(ns.session.rested))

-- A partly rested last kill: the last 30 pool points give 15 bonus XP, and
-- the game then says no pool (nil).
Kill(60, nil, true)
check(ns.session.rested == 105, "partly rested kill: " .. tostring(ns.session.rested))
-- A plain kill and a quest add none.
Kill(45, nil, true)
M.xp = M.xp + 300
M.fire("PLAYER_XP_UPDATE", "player")
M.fire("QUEST_TURNED_IN", 54, 300, 0)
check(ns.session.rested == 105 and ns.session.xp == 585, "no rest left: " .. tostring(ns.session.xp))

-- Rested comes out of kill XP; other is what's left.
local xp = ns.stats.experience
check(xp.total == 585 and xp.kills == 285 and xp.quests == 300 and xp.rested == 105, "totals: " .. ns.XPText(xp))
check(ns.XPText(xp) == "585: quests 300, kills 180, rested 105", "xp text: " .. ns.XPText(xp))
-- Kills the chat hid (in dungeons) are in other, so rested beyond the kills
-- read from chat comes out of other. It never goes past the bar's gain.
check(ns.XPText({ total = 400, kills = 50, rested = 100 }) == "400: other 300, rested 100", "rested out of other")
check(ns.XPText({ total = 100, quests = 80, rested = 50 }) == "100: quests 80, rested 20", "rested capped")

M.out = {}
SlashCmdList.TRAVELLOG("stats")
check(Said("XP: 585: quests 300, kills 180, rested 105"), "/tl stats")
M.out = {}
SlashCmdList.TRAVELLOG("sessions 1")
check(Said("585 xp: quests 300, kills 180, rested 105  1 quest, 4 XP kills"), "/tl sessions: " .. tostring(Said("Now")))
SlashCmdList.TRAVELLOG("")
local w = ns.window
check(Stat(w, "XP") == "585: quests 300, kills 180, rested 105", "totals row: " .. tostring(Stat(w, "XP")))
w.Tabs[3]:Click()
w.pages[3].viewButtons[2]:Click()
M.script(M.shown(w.pages[3].views[2].sessions.rows)[1], "OnEnter")
check(GameTooltip.lines[1] == "585 xp: quests 300, kills 180, rested 105", "session tooltip: " .. tostring(GameTooltip.lines[1]))

-- At max level the pool going away isn't bonus XP.
M.level = 60
M.rested = 500
M.fire("UPDATE_EXHAUSTION")
M.rested = nil
M.fire("UPDATE_EXHAUSTION")
check(ns.session.rested == 105, "max level: " .. tostring(ns.session.rested))
M.level = 5

-- Saved with the session. After a reload the pool is a new baseline, even
-- if it went down while logged out; a session saved without rested shows
-- none.
M.rested = 800
M.advance(60)
ns = M.Reload()
check(TravelLogCharDB.sessions[1].rested == 105 and ns.session.rested == nil, "saved: " .. tostring(TravelLogCharDB.sessions[1].rested))
M.rested = 700
M.advance(60)
ns = M.Reload()
check(ns.session.rested == nil and ns.stats.experience.rested == 105, "reload is a baseline")
TravelLogCharDB.sessions[1].rested = nil
M.out = {}
SlashCmdList.TRAVELLOG("sessions 3")
check(Said("585 xp: quests 300, kills 285  1 quest, 4 XP kills"), "old session without rested: " .. tostring(Said("585 xp")))
