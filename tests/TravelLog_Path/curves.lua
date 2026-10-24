-- Trail curves: straight lines at 0, a rounded corner through the recorded
-- points otherwise, straight walks left as single lines, more pieces when
-- zoomed in, live drawing matching a full redraw, the command, the window's
-- buttons and a reload.
M.installed = { "TravelLog", "TravelLog_Path" }
local ns = M.Login()
ns.settings.interval = 1
M.viewMap = 1429

-- East for 6 s, then south for 6 s: 10 canvas units a step.
local function Corner(each)
	for _ = 1, 6 do
		M.x, M.wb = M.x + 0.01, M.wb - 20
		M.tick(1)
		if each then each() end
	end
	for _ = 1, 6 do
		M.y, M.wa = M.y + 0.015, M.wa - 20
		M.tick(1)
		if each then each() end
	end
end

-- The visible trail lines' ends, copied since lines are reused.
local function Lines()
	M.frame()
	local list = {}
	for i, l in ipairs(M.shown(M.mapOverlay(2010).lines)) do
		list[i] = { start = { l.start[1], l.start[2] }, stop = { l.stop[1], l.stop[2] } }
	end
	return list
end

local function Near(a, b)
	return math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6
end

-- Each line starts where the one before it ends.
local function Joined(lines)
	for i = 2, #lines do
		if not Near(lines[i].start, lines[i - 1].stop) then return false end
	end
	return true
end

local function Key(l)
	return ("%.4f,%.4f,%.4f,%.4f"):format(l.start[1], l.start[2], l.stop[1], l.stop[2])
end

check(ns.settings.smooth == 50, "curves on by default: " .. ns.settings.smooth)
local x0, y0 = M.x * 1000, M.y * 667
Corner()
local corner = { x0 + 60, -y0 }

--------------------------------------------------------------------------------
-- Off: one straight line per segment
--------------------------------------------------------------------------------

SlashCmdList.TRAVELLOG("smooth 0")
local straight = Lines()
local axis = true
for _, l in ipairs(straight) do
	if math.abs(l.start[1] - l.stop[1]) > 1e-6 and math.abs(l.start[2] - l.stop[2]) > 1e-6 then axis = false end
end
check(#straight == 11 and axis and Joined(straight), "0: straight lines between points: " .. #straight)

--------------------------------------------------------------------------------
-- On: the corner is rounded, through the same points
--------------------------------------------------------------------------------

M.out = {}
SlashCmdList.TRAVELLOG("smooth 50")
check(M.out[1]:find("map trail curves: 50%%"), "command answers: " .. tostring(M.out[1]))
local curved = Lines()
check(#curved > #straight and Joined(curved), "50: the corner in more, joined pieces: " .. #curved)
check(Near(curved[1].start, straight[1].start) and Near(curved[#curved].stop, straight[#straight].stop),
	"same start and end")
local throughCorner, diagonal = false, 0
for _, l in ipairs(curved) do
	if Near(l.stop, corner) then throughCorner = true end
	if math.abs(l.start[1] - l.stop[1]) > 1e-6 and math.abs(l.start[2] - l.stop[2]) > 1e-6 then diagonal = diagonal + 1 end
end
check(throughCorner, "passes through the recorded corner")
check(diagonal > 0 and #curved - diagonal >= 8, "only near the corner does it bend: " .. diagonal)

SlashCmdList.TRAVELLOG("smooth 100")
check(#Lines() >= #curved, "rounder needs no fewer pieces")

WorldMapFrame.scale = 4
M.advance(1)
local zoomed = #Lines()
WorldMapFrame.scale = 1
M.advance(1)
check(zoomed > #Lines(), "zoomed in, more pieces: " .. zoomed)

M.out = {}
SlashCmdList.TRAVELLOG("smooth 150")
check(ns.settings.smooth == 100 and not M.out[1]:find("map trail curves"), "out of range refused")

--------------------------------------------------------------------------------
-- Live drawing with the map open matches a full redraw
--------------------------------------------------------------------------------

local function Live()
	M.advance(4)
	M.frame()
end
Corner(Live)
Corner(Live)
local live = {}
for _, l in ipairs(Lines()) do live[#live + 1] = Key(l) end
M.ns("TravelLog_Path").RefreshTrail()
local full = {}
for _, l in ipairs(Lines()) do full[#full + 1] = Key(l) end
table.sort(live)
table.sort(full)
check(#live > #curved and table.concat(live, ";") == table.concat(full, ";"),
	("live curves match a full redraw: %d vs %d"):format(#live, #full))

--------------------------------------------------------------------------------
-- The window's buttons, and a reload
--------------------------------------------------------------------------------

SlashCmdList.TRAVELLOG("")
local button
for _, child in ipairs(M.descendants(ns.window)) do
	if child.kind == "Button" and child:GetText() == "25" then button = child end
end
button:Click()
check(ns.settings.smooth == 25, "window button sets it")
ns = M.Reload()
check(ns.settings.smooth == 25, "kept over a reload")
