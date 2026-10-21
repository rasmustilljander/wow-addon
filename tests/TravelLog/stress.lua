-- Long sessions: speed, file size and map drawing with six hours of
-- non-stop movement recorded every second. Prints the numbers it measures.

-- Only the declared globals may be created while loading.
local leaked = {}
local allowed = { TravelLog = true, TravelLogDB = true, TravelLogCharDB = true, TravelLogPathDB = true, TravelLogPathAccountDB = true,
	TravelLogNodesDB = true, SLASH_TRAVELLOG1 = true, SLASH_TRAVELLOG2 = true, TravelLogMinimapButton = true }
setmetatable(_G, { __newindex = function(t, k, v)
	if not allowed[k] then leaked[#leaked + 1] = k end
	rawset(t, k, v)
end })
local ns = M.Login()
setmetatable(_G, nil)
check(#leaked == 0, "no stray globals: " .. table.concat(leaked, ", "))
local path = M.ns("TravelLog_Path")

-- Chat patterns built from other locales' strings
local p = ns.ToPattern("Vous recevez le butin : %1$sx%2$d.")
local item, n = ("Vous recevez le butin : [Lin]x3."):match(p)
check(item == "[Lin]" and n == "3", "positional %1$s formats")
p = ns.ToPattern("%s stirbt, Ihr bekommt %d Erfahrung.", true)
check(("Kobold stirbt, Ihr bekommt 45 Erfahrung. (+22 Erholung)"):match(p) == "Kobold", "open-ended pattern")
p = ns.ToPattern("100% (sure) [x] + a-b * c? ^$ %s")
check(("100% (sure) [x] + a-b * c? ^$ hello"):match(p) == "hello", "magic characters escaped")

-- Six hours of walking in loops at one point a second, jumping every 7 s
ns.settings.interval = 1
local t0 = os.clock()
for i = 1, 6 * 3600 do
	M.x = 0.2 + 0.6 * ((i % 600) / 600); M.y = 0.5 + 0.1 * math.sin(i / 50)
	M.wb = -100 - (i % 600) * 2; M.wa = -9000 + 50 * math.sin(i / 50)
	M.tick(1)
	if i % 7 == 0 then M.frame(); JumpOrAscendStart() end
end
local cpu = os.clock() - t0
local points = path.CountRecords(path.session.track, path.track.buffer)
io.write(("  6 h simulated in %.2f s CPU: %d points, %d jumps\n"):format(cpu, points, ns.stats.jumps))
check(cpu < 10, "recording stays cheap")
check(points == 6 * 3600, "a point every second while moving")

M.Logout()
local size = M.savedSize("TravelLog_Path")
io.write(("  path file after 6 h: %.0f KB, TravelLog's own: %.1f KB\n"):format(size / 1024, M.savedSize("TravelLog", true) / 1024))
check(size < 1.5 * 1048576, "file stays compact")

local t1 = os.clock()
ns = M.Login()
local loadTime = os.clock() - t1
io.write(("  login with that file: %.3f s\n"):format(loadTime))

SlashCmdList.TRAVELLOG("trail all")
M.viewMap = 1429
local t2 = os.clock(); M.frame(); local first = os.clock() - t2
M.viewMap = 1415
local t3 = os.clock(); M.frame(); local second = os.clock() - t3
local overlay = M.mapOverlay(2010)
io.write(("  map: first draw %.3f s (parsing), continent redraw %.3f s, %d lines, %d dots\n"):format(
	first, second, #M.shown(overlay.lines), #M.shown(overlay.textures)))
check(second < 0.2, "redraw from parsed data is fast")
check(#M.shown(overlay.textures) < 500, "jump dots on top of each other are merged")

-- With the map open, new points are added without redrawing everything
M.viewMap = 1429
M.frame()
local t4 = os.clock()
for _ = 1, 60 do
	M.x = M.x + 0.001; M.wb = M.wb - 4
	M.tick(1)
	M.frame()
end
local live = os.clock() - t4
io.write(("  60 s walking with the map open: %.3f s\n"):format(live))
check(live < 0.5, "live map updates are incremental")
