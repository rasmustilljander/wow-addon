-- Map replay: the trail and markers up to the slider's moment, your level
-- and gear then, the fade counting back from it, stepping forward drawing
-- on like a full redraw, stepping back, playing to the end, speeds, time
-- logged out skipped, other ranges, closing, a reload.
local HOUR = 3600
M.installed = { "TravelLog", "TravelLog_Path" }
M.now = os.time({ year = 2025, month = 10, day = 9, hour = 8 })
-- Gear is logged only once something was worn at the first login.
M.equipped = { [1] = "|cffffffff|Hitem:100::::::::5:::::|h[Cap]|h|r" }
local ns = M.Login()
ns.settings.interval = 1
M.viewMap = 1429
local MAIL = "|cff1eff00|Hitem:200::::::::5:::::|h[Chain Vest]|h|r"
M.items[200] = { quality = 2, level = 14 }

local function said(pattern)
	for _, line in ipairs(M.out) do
		if line:find(pattern) then return true end
	end
	return false
end

local function Walk(seconds)
	for _ = 1, seconds do
		M.x, M.wb = M.x + 0.004, M.wb - 14
		M.tick(1)
	end
end

-- Your visible trail lines, copied since lines are reused.
local function Lines()
	M.frame()
	local list = {}
	for _, l in ipairs(M.shown(M.mapOverlay(2010).lines)) do
		list[#list + 1] = { start = { l.start[1], l.start[2] }, stop = { l.stop[1], l.stop[2] }, alpha = l.color[4] }
	end
	return list
end

-- Shown dots of a color, or of a size.
local function Dots(match)
	M.frame()
	local list = {}
	for _, d in ipairs(M.shown(M.mapOverlay(2010).textures)) do
		if match(d) then list[#list + 1] = d end
	end
	return list
end
local function LevelDots() return Dots(function(d) return d.color[1] == 0.2 and d.color[2] == 1 end) end
local function NoteDots() return Dots(function(d) return d.color[1] == 1 and d.color[3] == 0.6 end) end
local function Head() return Dots(function(d) return d.w == 12 end)[1] end

local function Near(a, b)
	return math.abs(a - b) < 0.005
end

-- A morning walk, two hours idle, a level-up and a new chest piece, then
-- two more walks with a note between them.
Walk(60)
M.advance(2 * HOUR)
M.levelUp()
M.equip(5, MAIL)
Walk(60)
SlashCmdList.TRAVELLOG("note camp")
Walk(60)

local full = Lines()
check(#full > 120 and full[1].alpha < 0.5 and Near(full[#full].alpha, 0.9), "the whole trail, the first walk faded")
check(#LevelDots() == 1 and #NoteDots() == 1 and not Head(), "with its markers, no replay dot")

--------------------------------------------------------------------------------
-- Opening, and moving the slider
--------------------------------------------------------------------------------

M.out = {}
SlashCmdList.TRAVELLOG("replay")
local f = TravelLogReplayFrame
local path = M.ns("TravelLog_Path")
check(f and f:IsShown() and said("replaying today; open the world map"), "opens on your trail's range")
local _, total = f.slider:GetMinMaxValues()
check(total >= 2 * HOUR + 180 and total < 2 * HOUR + 190, "the slider spans the played time: " .. total)
check(f.slider:GetValue() == 0 and #Lines() == 0 and #LevelDots() == 0 and not Head(), "at the start: nothing yet")
check(f.speed:GetText() == "5 min/s" and f.play:GetText() == "Play", "paused, 5 minutes a second")

-- The end of the first walk: fresh as of then, level 5, nothing worn new.
f.slider:SetValue(60)
local walk = Lines()
check(#walk >= 45 and #walk <= 60 and Near(walk[1].alpha, 0.9), "the first walk, fresh then: " .. #walk)
check(#LevelDots() == 0 and #NoteDots() == 0, "no markers from later")
local head, last = Head(), walk[#walk].stop
check(head and head:IsShown() and Near(head.point[4], last[1]) and Near(head.point[5], last[2]),
	"a dot where you were")
check(f.now:GetText() == "Level 5", "your level then: " .. f.now:GetText())
check(f.when:GetText():find("^Thu 09 Oct 08:01, 1m of 2h 3m played"), f.when:GetText())

-- Into the second walk: drawn on, the first walk now two hours old.
f.slider:SetValue(total - 90)
local later = Lines()
check(#later > #walk + 20 and later[1].alpha < 0.5 and Near(later[#later].alpha, 0.9),
	"the second walk drawn on, the first faded behind it")
check(#LevelDots() == 1 and #NoteDots() == 0, "the level-up, not yet the note")
check(f.now:GetText() == "Level 6, item level 14", "level and item level then: " .. f.now:GetText())
M.script(f.hover, "OnEnter")
check(GameTooltip.lines[2] == "chest: " .. MAIL, "the gear on hover: " .. tostring(GameTooltip.lines[2]))

-- Drawing on matches drawing it all at once.
M.viewMap = 1415
M.frame()
M.viewMap = 1429
local redrawn = Lines()
local same = #redrawn == #later
for i = 1, #later do
	local a, b = later[i], redrawn[i]
	same = same and b and Near(a.start[1], b.start[1]) and Near(a.stop[2], b.stop[2]) and Near(a.alpha, b.alpha)
end
check(same, "drawn on like a full redraw: " .. #later .. " " .. #redrawn)

--------------------------------------------------------------------------------
-- Steps, playing, speeds
--------------------------------------------------------------------------------

f.speed:Click()
check(f.speed:GetText() == "20 min/s" and ns.settings.replaySpeed == 1200, "speed changed")
f.speed:Click()
f.speed:Click()
check(f.speed:GetText() == "1 min/s" and ns.settings.replaySpeed == 60, "and round to the slowest")
f.back:Click()
check(f.slider:GetValue() == total - 150 and #Lines() < #later, "a step back: a minute less")
f.forward:Click()
check(f.slider:GetValue() == total - 90 and #Lines() == #later, "and forward again")

f.play:Click()
check(f.play:GetText() == "Pause", "playing")
M.advance(0.5)
M.frame()
check(f.slider:GetValue() == total - 60, "half a second plays 30 s: " .. f.slider:GetValue())
check(#NoteDots() == 1, "past the note")
for _ = 1, 4 do
	M.advance(0.5)
	M.frame()
end
_, total = f.slider:GetMinMaxValues()
check(f.slider:GetValue() == total and f.play:GetText() == "Play", "stops at the end")
check(#Lines() == #full, "with the whole trail")
f.play:Click()
check(f.slider:GetValue() == 0 and f.play:GetText() == "Pause", "playing again starts over")
f.play:Click()

--------------------------------------------------------------------------------
-- Closing, other ranges, a reload
--------------------------------------------------------------------------------

f.CloseButton:Click()
check(not f:IsShown() and path.replayAt == nil, "closed")
check(#Lines() == #full and not Head(), "the whole trail again")

M.out = {}
SlashCmdList.TRAVELLOG("replay yesterday")
check(ns.settings.trail == os.date("%Y-%m-%d", M.now - 86400) and f:IsShown(), "another range")
check(f.when:GetText():find("^No path") and #Lines() == 0, "with nothing in it")
SlashCmdList.TRAVELLOG("trail today")
M.frame()
check(f.when:GetText():find("^Thu 09 Oct 08:00, under a minute of"), "a range changed while open starts over")
SlashCmdList.TRAVELLOG("replay")
check(not f:IsShown(), "/tl replay closes it")
M.out = {}
SlashCmdList.TRAVELLOG("replay someday")
check(said("/tl replay %[<range>%]"), "a bad range shows the help")

-- A night logged out isn't on the slider.
ns = M.Reload()
check(ns.settings.replaySpeed == 60, "the speed is kept")
M.Logout()
M.advance(8 * HOUR)
ns = M.Login()
ns.settings.interval = 1
Walk(10)
SlashCmdList.TRAVELLOG("replay")
f = TravelLogReplayFrame
local _, after = f.slider:GetMinMaxValues()
check(after >= total + 10 and after < total + 15, "time logged out skipped: " .. after - total)
f.slider:SetValue(total)
check(#Lines() == #full, "the first session's trail, up to its end")
f.forward:Click()
check(#Lines() > #full, "then the new session's")
