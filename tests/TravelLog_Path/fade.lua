-- Trail fade: lines and jumps fading by played time, eased in between,
-- refaded with the map open, not over time logged out, calendar days from
-- their end, markers left alone, the width floor, /tl fade, the window's
-- buttons and a reload.
local HOUR, MIN = 3600, 60
M.installed = { "TravelLog", "TravelLog_Path" }
M.now = os.time({ year = 2025, month = 10, day = 9, hour = 8 })
local ns = M.Login()
ns.settings.interval = 1
M.viewMap = 1429

local function said(pattern)
	for _, line in ipairs(M.out) do
		if line:find(pattern) then return true end
	end
	return false
end

local function Lines()
	M.frame()
	return M.shown(M.mapOverlay(2010).lines)
end

-- Shown dots by color, so jumps (white) and notes (pale yellow) apart.
local function Dots(r, g, b)
	M.frame()
	local list = {}
	for _, d in ipairs(M.shown(M.mapOverlay(2010).textures)) do
		if d.color[1] == r and d.color[2] == g and d.color[3] == b then list[#list + 1] = d end
	end
	return list
end

local function Walk(seconds)
	for _ = 1, seconds do
		M.x, M.wb = M.x + 0.005, M.wb - 10
		M.tick(1)
	end
end

local function Near(a, b)
	return math.abs(a - b) < 0.005
end

local defaults = M.ns("TravelLog_Path").TRAIL_FADE
check(ns.settings.trailFade and next(ns.settings.trailFade) == nil and defaults.on, "on by default, nothing saved")

--------------------------------------------------------------------------------
-- Fresh, then fading as you play
--------------------------------------------------------------------------------

Walk(6)
JumpOrAscendStart()
SlashCmdList.TRAVELLOG("note camp")
Walk(6)
local lines = Lines()
local first = lines[1]
check(#lines > 5 and Near(first.color[4], 0.9) and first.thickness == 2.5 and first.sublevel == 1,
	"fresh: full opacity and width, above the rest: " .. first.color[4])
check(#Dots(1, 1, 1) == 1 and Near(Dots(1, 1, 1)[1].color[4], 0.8), "a fresh jump")

-- Halfway through the opacity fade (15 to 120 min), before the width's.
M.advance(67.5 * MIN)
lines = Lines()
check(Near(lines[1].color[4], 0.9 * 0.75) and lines[1].thickness > 2.45 and lines[1].sublevel == 0,
	"halfway: three quarters opacity, eased, width only starting: " .. lines[1].color[4])
check(lines[1].color[4] <= lines[#lines].color[4], "older is fainter")

-- Past both: the floor.
M.advance(3 * HOUR)
lines = Lines()
check(Near(lines[1].color[4], 0.45) and Near(lines[#lines].color[4], 0.45) and Near(lines[1].thickness, 1.5),
	"after 3 h: half opacity, 60% width: " .. lines[1].color[4] .. " " .. lines[1].thickness)
local jump = Dots(1, 1, 1)[1]
check(Near(jump.color[4], 0.4) and Near(jump.w, 1.8), "the jump faded too: " .. jump.color[4] .. " " .. jump.w)
local note = Dots(1, 1, 0.6)
check(#note == 1 and note[1].color[4] == 1 and note[1].w == 9, "the note marker doesn't fade")

-- New walking is fresh again, and on top.
Walk(6)
M.advance(4)
lines = Lines()
check(Near(lines[#lines].color[4], 0.9) and lines[#lines].sublevel == 1 and lines[1].sublevel == 0,
	"a new walk fresh, the old one under it")

--------------------------------------------------------------------------------
-- Logged out doesn't count; refading with the map open
--------------------------------------------------------------------------------

SlashCmdList.TRAVELLOG("fade 12h")
lines = Lines()
local before = lines[1].color[4]
check(before > 0.45 and before < 0.9, "12h: the old walk partly faded: " .. before)
M.Logout()
M.advance(8 * HOUR)
ns = M.Login()
check(Near(Lines()[1].color[4], before), "a night logged out doesn't fade it further")

-- Two played hours with the map open and nothing new recorded.
M.advance(2 * HOUR)
check(Lines()[1].color[4] < before - 0.05, "refaded in place while the map is open: " .. Lines()[1].color[4])

--------------------------------------------------------------------------------
-- A calendar day fades from its own end
--------------------------------------------------------------------------------

-- A last walk this evening, then four hours played tomorrow.
SlashCmdList.TRAVELLOG("fade default")
Walk(6)
M.Logout()
M.advance(14 * HOUR)
ns = M.Login()
M.advance(4 * HOUR)
SlashCmdList.TRAVELLOG("trail yesterday")
lines = Lines()
check(#lines > 15 and Near(lines[#lines].color[4], 0.9), "yesterday: its last walk fresh, as of its end")
check(Near(lines[1].color[4], 0.45), "and its first, hours of play before that end, faded")
SlashCmdList.TRAVELLOG("trail 2d")
lines = Lines()
check(Near(lines[#lines].color[4], 0.45), "the same walk in a range ending now: faded")

--------------------------------------------------------------------------------
-- /tl fade
--------------------------------------------------------------------------------

SlashCmdList.TRAVELLOG("fade off")
check(ns.settings.trailFade.on == false and Near(Lines()[1].color[4], 0.9) and Lines()[1].thickness == 2.5,
	"off: everything full")
M.out = {}
SlashCmdList.TRAVELLOG("fade")
check(said("map trail fade: off"), "shows the setting: " .. tostring(M.out[1]))
SlashCmdList.TRAVELLOG("fade on")
check(next(ns.settings.trailFade) == nil, "on again: the default, nothing saved")

M.out = {}
SlashCmdList.TRAVELLOG("fade opacity 0-60 30")
local f = ns.settings.trailFade
check(f.alphaFrom == 0 and f.alphaTo == 60 and f.alpha == 30 and f.widthTo == nil, "opacity set: only it saved")
check(said("opacity to 30%% from 0 to 60 min, width to 60%% from 60 to 180 min"), "and described")
check(Near(Lines()[1].color[4], 0.27), "drawn with it")
SlashCmdList.TRAVELLOG("fade width 0-60 30")
check(Lines()[1].thickness == 1, "never thinner than a pixel: " .. Lines()[1].thickness)

for _, bad in ipairs({ "opacity 60-30 50", "opacity 0-60 5", "width 0-60 20", "width 0-20000 50", "speed 0-60 50", "2h" }) do
	M.out = {}
	SlashCmdList.TRAVELLOG("fade " .. bad)
	check(f.alpha == 30 and f.width == 30 and said("/tl fade on|off"), "rejected: " .. bad)
end

SlashCmdList.TRAVELLOG("fade 1h")
check(f.alphaFrom == 5 and f.alphaTo == 40 and f.widthFrom == 20 and f.widthTo == 60 and f.alpha == 30,
	"1h: the default shape squeezed, floors kept")
SlashCmdList.TRAVELLOG("fade default")
check(next(ns.settings.trailFade) == nil, "default: nothing saved")

--------------------------------------------------------------------------------
-- The window's buttons, and a reload
--------------------------------------------------------------------------------

SlashCmdList.TRAVELLOG("")
local function Button(text)
	for _, child in ipairs(M.descendants(ns.window)) do
		if child.kind == "Button" and child:GetText() == text then return child end
	end
end
Button("6h"):Click()
f = ns.settings.trailFade
check(f.alphaFrom == 30 and f.alphaTo == 240 and f.widthFrom == 120 and f.widthTo == 360, "window button sets it")
ns = M.Reload()
check(ns.settings.trailFade.widthTo == 360, "kept over a reload")
SlashCmdList.TRAVELLOG("")
Button("3h"):Click()
check(next(ns.settings.trailFade) == nil, "3h is the default")
