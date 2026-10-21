-- The Colors tab: changing trail and marker colors with the color picker,
-- cancelling, going back to the defaults, and a reload.
M.installed = { "TravelLog", "TravelLog_Path" }
local ns = M.Login()

local function Walk(seconds)
	for _ = 1, seconds do
		M.x, M.wb = M.x + 0.01, M.wb - 20
		M.tick(1)
	end
end

-- Visible trail line colors on the shown map, by color.
local function LineColors()
	M.frame()
	local colors = {}
	for _, l in ipairs(M.shown(M.mapOverlay(2010).lines)) do
		local c = table.concat(l.color, ",")
		colors[c] = (colors[c] or 0) + 1
	end
	return colors
end
local function DotColors()
	M.frame()
	local colors = {}
	for _, t in ipairs(M.shown(M.mapOverlay(2010).textures)) do colors[table.concat(t.color, ",")] = true end
	return colors
end

-- A row of the tab by its label: the swatch, its color and the Default button.
local function Row(page, label)
	for _, fs in ipairs(page.fontStrings) do
		if fs:GetText() == label then
			local x, y = fs.point[2], fs.point[3]
			local swatch, reset
			for _, child in ipairs(page.children) do
				if child.point[2] == x + 112 and child.point[3] == y + 2 then swatch = child end
				if child.point[3] == y + 3 and child:GetText() == "Default" and child.point[2] > x then
					reset = reset or child
				end
			end
			return swatch, swatch.textures[3], reset
		end
	end
end
local function Button(page, text)
	for _, child in ipairs(page.children) do
		if child:GetText() == text then return child end
	end
end

-- On foot, then mounted, with a jump.
Walk(10)
JumpOrAscendStart()
M.mounted = true
Walk(10)
M.mounted = false
M.viewMap = 1429
local before = LineColors()
check(before["1,0.82,0,0.9"] and before["1,0.5,0.1,0.9"], "default foot and mount colors")
check(DotColors()["1,1,1,0.8"], "default jump marker")

SlashCmdList.TRAVELLOG("window")
local w = ns.window
check(w.Tabs[4]:GetText() == "Colors", "Colors tab after Log")
w.Tabs[4]:Click()
local page = w.pages[4]
check(page:IsShown(), "Colors tab open")
local foot, footColor, footReset = Row(page, "On foot")
check(foot and table.concat(footColor.color, ",") == "1,0.82,0,0.9", "swatch shows the default")
check(not footReset:IsEnabled(), "Default off while unchanged")
check(Row(page, "Death") and Row(page, "First ride") and Row(page, "Ghost"), "a row per trail mode and marker")

-- Dragging in the picker recolors the trail right away, rounded.
foot:Click()
local info = ColorPickerFrame.info
check(ColorPickerFrame.shown and info.r == 1 and info.g == 0.82 and info.b == 0 and info.opacity == 0.9
	and info.hasOpacity, "picker opens on the current color, with opacity")
M.pickColor(0.123456, 0.5, 1, 0.4)
local now = LineColors()
check(now["0.123,0.5,1,0.4"] == before["1,0.82,0,0.9"] and not now["1,0.82,0,0.9"], "foot lines recolored")
check(now["1,0.5,0.1,0.9"] == before["1,0.5,0.1,0.9"], "mounted lines unchanged")
check(table.concat(footColor.color, ",") == "0.123,0.5,1,0.4" and footReset:IsEnabled(), "swatch follows, Default on")

-- Cancel puts back the color from before.
M.closeColorPicker(false)
check(ns.settings.trailColors.foot == nil and LineColors()["1,0.82,0,0.9"], "cancel restores the default")
check(not footReset:IsEnabled(), "Default off again")

-- Okay keeps it; picking the default again saves nothing.
foot:Click()
M.pickColor(0.2, 0.6, 0.2, 1)
M.closeColorPicker(true)
check(table.concat(ns.settings.trailColors.foot, ",") == "0.2,0.6,0.2,1", "foot color saved")
local jump = Row(page, "Jump")
jump:Click()
M.pickColor(1, 0, 1, 1)
M.closeColorPicker(true)
check(DotColors()["1,0,1,1"] and not DotColors()["1,1,1,0.8"], "jump marker recolored")
local mount = Row(page, "Mounted")
mount:Click()
M.pickColor(1, 0.5, 0.1, 0.9)
M.closeColorPicker(true)
check(ns.settings.trailColors.mount == nil, "the default color isn't saved")
check(ns.settings.markerColors.mount == nil, "trail mount and marker mount kept apart")

-- Saved across a reload.
ns = M.Reload()
M.viewMap = 1429
check(LineColors()["0.2,0.6,0.2,1"] and DotColors()["1,0,1,1"], "colors kept after reload")

-- Default resets one, All defaults the rest.
SlashCmdList.TRAVELLOG("window")
w = ns.window
w.Tabs[4]:Click()
page = w.pages[4]
local _, _, reset = Row(page, "On foot")
reset:Click()
check(ns.settings.trailColors.foot == nil and LineColors()["1,0.82,0,0.9"], "Default resets the foot color")
check(ns.settings.markerColors.jump, "jump color still changed")
Button(page, "All defaults"):Click()
check(next(ns.settings.markerColors) == nil and DotColors()["1,1,1,0.8"], "All defaults resets the markers")
