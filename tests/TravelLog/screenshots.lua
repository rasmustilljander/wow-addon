-- Screenshots: the file name from the time the picture was taken, where you
-- were, a failed one, totals, the window, /tl log and a reload.
local ns = M.Login()

local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end
local function last()
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == "screenshot" then return log[i] end
	end
end

-- Saved a second after it was taken: named after when it was taken.
M.zone, M.subzone, M.x, M.y = "Elwynn Forest", "Goldshire", 0.42, 0.65
local taken = M.now
M.fire("SCREENSHOT_STARTED")
M.tick(1)
M.fire("SCREENSHOT_SUCCEEDED")
local e = last()
local file = date("WoWScrnShot_%m%d%y_%H%M%S", taken)
check(count("screenshot") == 1 and e.file == file, "file name: " .. tostring(e.file))
check(e.zone == "Elwynn Forest" and e.subzone == "Goldshire" and e.x == 42 and e.y == 65, "where it was taken")
check(ns.Describe(e) == "Screenshot " .. file, "described: " .. ns.Describe(e))

-- A failed one isn't logged and doesn't name the next.
M.tick(5)
M.fire("SCREENSHOT_STARTED")
M.fire("SCREENSHOT_FAILED")
M.tick(5)
M.fire("SCREENSHOT_SUCCEEDED")
check(count("screenshot") == 2 and last().file == date("WoWScrnShot_%m%d%y_%H%M%S", M.now), "failed one skipped")

check(ns.stats.screenshots == 2, "counted")
check(ns.LogGroup(e) == "Travel" and ns.LogTypeLabel(e) == "Screenshot", "under Travel")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("screenshots %d+") end
check(line == "screenshots 2", "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 5 wowscrnshot")
check(#M.out == 3 and M.out[2]:find("Screenshot " .. file, 1, true), "/tl log finds the file name")

SlashCmdList.TRAVELLOG("")
local values = {}
for _, fs in ipairs(M.descendants(TravelLogFrame.pages[1])) do values[#values + 1] = fs.text end
check(table.concat(values, "\n"):find("Screenshots\n2", 1, true), "Screenshots row")

local second = last().file
ns = M.Reload()
check(count("screenshot") == 2 and last().file == second and ns.stats.screenshots == 2, "kept after a reload")
