-- Resting: walking into an inn and out again, its door, a reload and a night
-- logged out inside, logging in rested, totals, the window, /tl log and
-- /tl stats.
local ns = M.Login()

local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function rest(resting, subzone)
	M.resting, M.subzone = resting, subzone
	M.fire("PLAYER_UPDATE_RESTING")
end

M.zone, M.subzone = "Elwynn Forest", "Goldshire"
M.tick(20)

-- Into the inn: logged where it started, once it has held for 5 s.
local entered = M.now
rest(true, "Lion's Pride Inn")
M.subzone = "Goldshire"
M.tick(4)
check(count("rest") == 0, "not yet")
M.tick(1)
local e = last("rest")
check(count("rest") == 1 and e.subzone == "Lion's Pride Inn" and e.time == entered, "entered where it started")
check(ns.Describe(e) == "Started resting in Lion's Pride Inn", "described: " .. ns.Describe(e))
check(TravelLogCharDB.rest and ns.stats.rests == 1, "stay kept and counted")

-- Stepping out of the door and back in isn't a stay.
M.tick(60)
rest(false, "Goldshire")
M.tick(2)
rest(true, "Lion's Pride Inn")
M.tick(10)
check(count("rest") == 1 and count("restleave") == 0, "the door ignored")

-- A reload and a night logged out inside are the same stay; time logged
-- out doesn't count.
M.tick(600)
ns = M.Reload()
M.tick(100)
local out = M.now
M.Logout()
M.advance(8 * 3600)
ns = M.Login()
local back = M.now
M.tick(300)
check(count("rest") == 1 and ns.stats.rests == 1, "same stay after a reload and a relog")

-- Out again: how long, and the rested XP you left with.
M.rested = 1200
local leaving = M.now
rest(false, "Goldshire")
M.tick(5)
local left = last("restleave")
local seconds = (out - entered) + (leaving - back)
check(count("restleave") == 1 and left.subzone == "Goldshire", "left")
check(left.seconds == seconds and left.rested == 1200, "time and rested XP: " .. tostring(left.seconds))
check(ns.Describe(left) == "Stopped resting after 17m, 1,200 XP rested", "described: " .. ns.Describe(left))
check(not TravelLogCharDB.rest and ns.stats.restTime == seconds, "stay over and counted")

-- Logging in rested, even when the client knows a moment late, starts a
-- stay without an entry.
M.Logout()
M.resting = false
ns = M.Login()
M.tick(3)
rest(true, "Lion's Pride Inn")
M.tick(10)
check(count("rest") == 1 and TravelLogCharDB.rest, "a stay from the login, not logged")
rest(false, "Goldshire")
M.tick(5)
check(count("restleave") == 2 and last("restleave").seconds == 10 and ns.stats.rests == 1, "leaving it is")

-- Under Travel, in /tl stats, /tl log and the Totals.
check(ns.LogGroup(e) == "Travel" and ns.LogTypeLabel(e) == "Resting" and ns.LogTypeLabel(left) == "Resting ended", "labels")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("rested stays .-, screenshots") end
check(line == "rested stays 1, 18m resting, screenshots", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 5 resting")
check(#M.out == 4 and M.out[3]:find("Stopped resting after 17m, 1,200 XP rested", 1, true), "/tl log")
SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("Resting\n1 stays, 18m", 1, true), "Resting row")
