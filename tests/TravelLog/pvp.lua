-- PvP: duels you challenge and are challenged to (won, lost, fled, without a
-- winner, declined), others' duels nearby, honorable kills from chat and
-- from the kill count when chat is hidden, honor awards, your rank going up
-- and down (online, offline, a new season), battlegrounds won, lost, drawn and
-- left; stats, the window, /tl log and a reload.
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
-- The client sends DUEL_FINISHED, then the result line to everyone nearby.
local function finish(result)
	M.fire("DUEL_FINISHED")
	if result then M.chat("CHAT_MSG_SYSTEM", result) end
	M.tick(3)
end

-- You challenge your target and win.
M.units.target = { name = "Ann", player = true }
StartDuel("target")
finish("Rasmus has defeated Ann in a duel")
local d = last("duel")
check(count("duel") == 1 and d.opponent == "Ann" and d.result == "won" and d.challenger == "you" and not d.fled, "won your challenge")
check(ns.Describe(d) == "Won a duel against Ann (you challenged)", "won described: " .. ns.Describe(d))

-- Bob challenges you, you accept and run off.
M.fire("DUEL_REQUESTED", "Bob")
AcceptDuel()
M.fire("DUEL_OUTOFBOUNDS")
finish("Rasmus has fled from Bob in a duel")
d = last("duel")
check(count("duel") == 2 and d.opponent == "Bob" and d.result == "lost" and d.fled and d.challenger == "opponent", "fled from Bob")
check(ns.Describe(d) == "Lost a duel to Bob (you fled, they challenged)", "fled described: " .. ns.Describe(d))

-- /duel Cid, who runs off; the result line can come before DUEL_FINISHED too.
StartDuel("Cid")
M.chat("CHAT_MSG_SYSTEM", "Cid has fled from Rasmus in a duel")
finish()
d = last("duel")
check(count("duel") == 3 and d.opponent == "Cid" and d.result == "won" and d.fled, "Cid fled")
check(ns.Describe(d) == "Won a duel against Cid (they fled, you challenged)", "their flight described: " .. ns.Describe(d))

-- Declined challenges, both ways, aren't duels.
M.fire("DUEL_REQUESTED", "Dan")
CancelDuel()
finish()
StartDuel("target")
finish()
check(count("duel") == 3, "declined challenges not logged")

-- Ended without a winner: one you accepted, and one you challenged where
-- someone crossed the edge of the duel area.
M.fire("DUEL_REQUESTED", "Eve")
AcceptDuel()
finish()
d = last("duel")
check(count("duel") == 4 and d.opponent == "Eve" and d.result == "interrupted", "interrupted duel")
check(ns.Describe(d) == "Duel with Eve ended without a winner (they challenged)", "interrupted described: " .. ns.Describe(d))
StartDuel("target")
M.fire("DUEL_OUTOFBOUNDS")
M.fire("DUEL_INBOUNDS")
finish()
check(count("duel") == 5 and last("duel").opponent == "Ann" and last("duel").result == "interrupted", "interrupted challenge")

-- Others' duels nearby, an unreadable line, and a duel with someone from
-- another realm (and no challenge seen, as after a reload).
finish("Bob has defeated Ann in a duel")
M.secrets["Rasmus has defeated Bob in a duel"] = true
finish("Rasmus has defeated Bob in a duel")
check(count("duel") == 5, "others' duels and secret lines ignored")
finish("Zed-Otherrealm has defeated Rasmus in a duel")
d = last("duel")
check(count("duel") == 6 and d.opponent == "Zed-Otherrealm" and d.result == "lost" and not d.challenger, "lost to another realm")
check(ns.Describe(d) == "Lost a duel to Zed-Otherrealm", "without a challenger described: " .. ns.Describe(d))

-- A duel to the death, on Hardcore realms.
M.fire("DUEL_TO_THE_DEATH_REQUESTED", "Gor")
AcceptDuel()
finish("Rasmus has defeated Gor in a duel")
check(count("duel") == 7 and last("duel").opponent == "Gor" and last("duel").challenger == "opponent", "duel to the death")

--------------------------------------------------------------------------------
-- Honor
--------------------------------------------------------------------------------

-- A kill's chat line, then the kill count: one kill.
M.chat("CHAT_MSG_COMBAT_HONOR_GAIN", "Grok dies (Honorable Kill: Sergeant). You gain 45 Honor.")
M.honorKills = 1
M.fire("PLAYER_PVP_KILLS_CHANGED", "player")
M.tick(3)
local hk = last("honorkill")
check(count("honorkill") == 1 and hk.name == "Grok" and hk.rank == "Sergeant" and hk.honor == 45, "honorable kill")
check(ns.Describe(hk) == "Honorable kill: Grok (Sergeant), +45 honor", "honorable kill described: " .. ns.Describe(hk))

-- The count first, then an unranked victim with a bonus.
M.honorKills = 2
M.fire("PLAYER_PVP_KILLS_CHANGED", "player")
M.chat("CHAT_MSG_COMBAT_HONOR_GAIN", "Zug dies (Honorable Kill). You gain 12 Honor (6 Rested bonus).")
M.tick(3)
hk = last("honorkill")
check(count("honorkill") == 2 and hk.name == "Zug" and not hk.rank and hk.honor == 12, "unranked kill, counted once")
check(ns.Describe(hk) == "Honorable kill: Zug, +12 honor", "unranked described: " .. ns.Describe(hk))

-- Two kills whose lines are hidden (a battleground): from the count, without names.
M.secrets["Mok dies (Honorable Kill: Scout). You gain 30 Honor."] = true
M.chat("CHAT_MSG_COMBAT_HONOR_GAIN", "Mok dies (Honorable Kill: Scout). You gain 30 Honor.")
M.honorKills = 4
M.fire("PLAYER_PVP_KILLS_CHANGED", "player")
M.fire("PLAYER_PVP_KILLS_CHANGED", "party1")
M.tick(3)
hk = last("honorkill")
check(count("honorkill") == 4 and not hk.name and not hk.honor, "hidden kills from the count")
check(ns.Describe(hk) == "Honorable kill", "nameless kill described")

-- Bonus honor, and the count starting over at the daily reset.
M.chat("CHAT_MSG_COMBAT_HONOR_GAIN", "You have been awarded 100 Honor.")
check(count("honor") == 1 and last("honor").honor == 100, "honor award")
check(ns.Describe(last("honor")) == "Awarded 100 honor", "award described")
M.honorKills = 0
M.fire("PLAYER_PVP_KILLS_CHANGED", "player")
M.tick(3)
check(count("honorkill") == 4, "daily reset isn't a kill")

--------------------------------------------------------------------------------
-- Battlegrounds
--------------------------------------------------------------------------------

local function enter(name, id)
	M.instance, M.instanceInfo = name and "pvp" or nil, name and { name = name, maxPlayers = 10, instanceID = id }
	M.zone, M.subzone = name or "Elwynn Forest", ""
	M.fire("PLAYER_ENTERING_WORLD", false, false)
end

-- A win, with your scoreboard line; a reload before leaving doesn't log it
-- twice, and leaving after the end is no desertion.
enter("Warsong Gulch", 489)
M.pvpScore = { killingBlows = 3, honorableKills = 12, deaths = 2, honorGained = 340 }
M.fire("PVP_MATCH_COMPLETE", 1, 1380)
local bg = last("battleground")
check(count("battleground") == 1 and bg.name == "Warsong Gulch" and bg.result == "won" and bg.seconds == 1380
	and bg.killingBlows == 3 and bg.honorableKills == 12 and bg.deaths == 2 and bg.honor == 340, "battleground won")
check(ns.Describe(bg) == "Won Warsong Gulch after 23m: 3 killing blows, 12 honorable kills, 2 deaths, +340 honor",
	"win described: " .. ns.Describe(bg))
ns = M.Reload()
M.fire("PVP_MATCH_COMPLETE", 1, 1380)
enter(nil)
check(count("battleground") == 1 and last("instanceleave").name == "Warsong Gulch", "logged once, left after the end")

-- A loss to the Horde without a scoreboard, a draw with a secret line, and
-- one left before the end.
M.pvpScore = nil
enter("Arathi Basin", 529)
M.fire("PVP_MATCH_COMPLETE", 0, 1800)
check(count("battleground") == 2 and last("battleground").result == "lost", "battleground lost")
check(ns.Describe(last("battleground")) == "Lost Arathi Basin after 30m", "loss described: " .. ns.Describe(last("battleground")))
enter(nil)
M.pvpScore = { killingBlows = 0, honorableKills = 4, deaths = 1, honorGained = 77 }
M.secrets[77] = true
enter("Warsong Gulch", 489)
M.fire("PVP_MATCH_COMPLETE", 255, 1500)
M.secrets[77] = nil
bg = last("battleground")
check(count("battleground") == 3 and bg.result == "draw" and not bg.honor and bg.deaths == 1, "draw, secret honor left out")
check(ns.Describe(bg) == "Draw in Warsong Gulch after 25m: 0 killing blows, 4 honorable kills, 1 death", "draw described: " .. ns.Describe(bg))
enter(nil)
enter("Alterac Valley", 30)
enter(nil)
bg = last("battleground")
check(count("battleground") == 4 and bg.name == "Alterac Valley" and bg.result == "left" and not bg.seconds, "left before the end")
check(ns.Describe(bg) == "Left Alterac Valley before the end", "desertion described")

-- Dungeons aren't battlegrounds.
M.instance, M.instanceInfo = "party", { name = "The Deadmines", maxPlayers = 5, instanceID = 36 }
M.fire("PLAYER_ENTERING_WORLD", false, false)
enter(nil)
check(count("battleground") == 4, "leaving a dungeon isn't a battleground")

--------------------------------------------------------------------------------
-- Totals, /tl log, the window and a reload
--------------------------------------------------------------------------------

local st = ns.stats
check(st.duels.won == 3 and st.duels.lost == 2 and st.duels.interrupted == 2, "duels counted")
check(st.honorKills == 4 and st.honor == 157, "honor counted: " .. tostring(st.honor))
check(st.battlegrounds.won == 1 and st.battlegrounds.lost == 1 and st.battlegrounds.draw == 1 and st.battlegrounds.left == 1,
	"battlegrounds counted")
for _, kind in ipairs({ "duel", "honorkill", "honor", "battleground" }) do
	check(ns.LogGroup(last(kind)) == "Life", kind .. " under Life")
end
check(ns.LogTypeLabel(last("duel")) == "Duel" and ns.LogTypeLabel(last("honorkill")) == "Honorable kill"
	and ns.LogTypeLabel(last("honor")) == "Honor" and ns.LogTypeLabel(last("battleground")) == "Battleground", "labels")

M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Duels .*") end
check(line == "Duels won 3, lost 2, no winner 2; battlegrounds won 1, lost 1, drawn 1, left 1; honorable kills 4, honor 157",
	"stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 2 duel")
check(#M.out == 3 and M.out[2]:find("Lost a duel to Zed-Otherrealm", 1, true)
	and M.out[3]:find("Won a duel against Gor (they challenged)", 1, true), "/tl log")
M.out = {}
SlashCmdList.TRAVELLOG("log 1 sergeant")
check(#M.out == 2 and M.out[2]:find("Honorable kill: Grok (Sergeant), +45 honor", 1, true), "/tl log finds the rank")

SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("PvP\n3 duels won, 2 lost, 2 no winner, 4 honorable kills, 157 honor\nBattlegrounds\n1 won, 1 lost, 1 drawn, 1 left", 1, true),
	"PvP and Battlegrounds rows")
M.out = {}
SlashCmdList.TRAVELLOG("log 1 draw")
check(#M.out == 2 and M.out[2]:find("Draw in Warsong Gulch after 25m", 1, true), "/tl log finds the result")

ns = M.Reload()
check(count("duel") == 7 and count("honorkill") == 4 and count("battleground") == 4 and ns.stats.duels.won == 3
	and ns.stats.honor == 157 and ns.stats.battlegrounds.won == 1, "kept after a reload")
-- The day's count is read again at login, so it isn't counted twice.
M.honorKills = 1
M.fire("PLAYER_PVP_KILLS_CHANGED", "player")
M.tick(3)
check(count("honorkill") == 5 and ns.stats.honorKills == 5, "one more kill after the reload")

--------------------------------------------------------------------------------
-- Your rank
--------------------------------------------------------------------------------

-- The rank at the first login is remembered, not logged.
check(count("pvprank") == 0 and TravelLogCharDB.pvpRank.rank == 0 and TravelLogCharDB.pvpRank.season == 1, "first rank remembered")

-- Up to rank 3; another faction's renown and repeated events change nothing.
M.pvpRank = 3
M.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2800, 3, 0)
M.fire("PLAYER_PVP_RANK_CHANGED", "player")
M.fire("UPDATE_FACTION")
M.fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2600, 5, 4)
local r = last("pvprank")
check(count("pvprank") == 1 and r.rank == 3 and r.old == 0 and r.title == "Sergeant" and r.season == 1 and not r.newSeason, "rank up")
check(ns.Describe(r) == "PvP rank 3, Sergeant (up from 0)", "rank up described: " .. ns.Describe(r))
check(ns.LogGroup(r) == "Life" and ns.LogTypeLabel(r) == "PvP rank", "rank under Life")

-- Only PLAYER_PVP_RANK_CHANGED, to a rank without a known title.
M.pvpRank = 4
M.fire("PLAYER_PVP_RANK_CHANGED", "target")
check(count("pvprank") == 1, "another unit's rank ignored")
M.fire("PLAYER_PVP_RANK_CHANGED", "player")
r = last("pvprank")
check(count("pvprank") == 2 and r.rank == 4 and not r.title, "rank without a title")
check(ns.Describe(r) == "PvP rank 4 (up from 3)", "untitled described: " .. ns.Describe(r))

-- Kept across a reload without being logged again.
ns = M.Reload()
check(count("pvprank") == 2 and TravelLogCharDB.pvpRank.rank == 4, "rank kept after a reload")

-- A new season while offline, seen at the next login.
M.Logout()
M.pvpRank, M.pvpSeason = 0, 2
ns = M.Login()
r = last("pvprank")
check(count("pvprank") == 3 and r.rank == 0 and r.old == 4 and r.title == "No Rank" and r.season == 2 and r.newSeason, "new season")
check(ns.Describe(r) == "PvP rank 0, No Rank (down from 4, new season)", "new season described: " .. ns.Describe(r))

-- Faction data that arrives after login.
M.Logout()
M.pvpRank = nil
ns = M.Login()
check(count("pvprank") == 3 and TravelLogCharDB.pvpRank.rank == 0, "no data, nothing changed")
M.pvpRank = 1
M.fire("UPDATE_FACTION")
r = last("pvprank")
check(count("pvprank") == 4 and r.rank == 1 and r.title == "Private" and not r.newSeason, "rank once faction data arrives")

M.out = {}
SlashCmdList.TRAVELLOG("log 1 pvp rank")
check(#M.out == 2 and M.out[2]:find("PvP rank 1, Private (up from 0)", 1, true), "/tl log finds the rank change")
