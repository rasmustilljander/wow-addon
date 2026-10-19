-- Pins on the world map where you've killed things. Kills close together are
-- one spot, so a grinding area is a single pin that grows with the count.
-- Hovering a pin lists what died there and when. "/kills map" turns them off
-- or shows just one mob.
local _, ns = ...

local CELL = 2         -- map coordinates (0-100); kills in one cell are one spot
local MIN_SIZE = 7     -- screen pixels, a spot with one kill
local MAX_SIZE = 16    -- screen pixels, the biggest spots
local SHOW_MOBS = 6    -- mobs listed in a pin's tooltip
local COLOR = { 0.95, 0.25, 0.2, 0.9 }

--------------------------------------------------------------------------------
-- Spots: kills per map and cell
--------------------------------------------------------------------------------

-- spots[map][cell] = { x, y (sums, for the average), count, last, mobs = { [name] = { count, last } } }
local spots
ns.version = 0

local function AddKill(name, map, x, y, t)
	if not (map and x and y) then
		return
	end
	local byMap = spots[map]
	if not byMap then
		byMap = {}
		spots[map] = byMap
	end
	local cell = math.floor(x / CELL) .. ":" .. math.floor(y / CELL)
	local spot = byMap[cell]
	if not spot then
		spot = { x = 0, y = 0, count = 0, last = 0, mobs = {} }
		byMap[cell] = spot
	end
	spot.x, spot.y, spot.count = spot.x + x, spot.y + y, spot.count + 1
	spot.last = math.max(spot.last, t)
	local mob = spot.mobs[name]
	if not mob then
		mob = { count = 0, last = 0 }
		spot.mobs[name] = mob
	end
	mob.count, mob.last = mob.count + 1, math.max(mob.last, t)
end

-- Reads every saved kill the first time the map needs them.
local function Spots()
	if not spots then
		spots = {}
		for name, mob in pairs(ns.db.mobs) do
			for _, rec in ipairs(mob.kills) do
				local t, map, x, y = strsplit(",", rec)
				AddKill(name, tonumber(map), tonumber(x), tonumber(y), tonumber(t))
			end
		end
	end
	return spots
end

-- Called by the recorder for each new kill.
function ns.MapAdd(name, w)
	ns.version = ns.version + 1
	if spots then
		AddKill(name, w.map, w.x, w.y, w.time)
	end
end

--------------------------------------------------------------------------------
-- Pins
--------------------------------------------------------------------------------

local overlay
local pins = {}
local drawnMap, drawnScale, drawnVersion, drawnAt = nil, nil, nil, 0

local function PinTooltip(pin)
	local spot, filter = pin.spot, ns.db.settings.mapFilter
	local list = {}
	for name, mob in pairs(spot.mobs) do
		if not filter or name == filter then
			list[#list + 1] = { name = name, count = mob.count, last = mob.last }
		end
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.name < b.name
	end)
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:AddLine(("%d kill%s here"):format(pin.count, pin.count == 1 and "" or "s"))
	GameTooltip:AddLine(("Last %s (%s ago)"):format(date("%Y-%m-%d %H:%M", pin.last), ns.Ago(pin.last)), 1, 1, 1)
	for i = 1, math.min(SHOW_MOBS, #list) do
		GameTooltip:AddDoubleLine(list[i].name, tostring(list[i].count), 0.9, 0.45, 0.45, 1, 1, 1)
	end
	if #list > SHOW_MOBS then
		GameTooltip:AddLine(("and %d more"):format(#list - SHOW_MOBS), 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function SetPin(i, spot, count, last, x, y, size)
	local pin = pins[i]
	if not pin then
		pin = CreateFrame("Frame", nil, overlay)
		pin:EnableMouse(true)
		pin:SetMouseClickEnabled(false) -- clicks still reach the map
		pin:SetScript("OnEnter", PinTooltip)
		pin:SetScript("OnLeave", HideTooltip)
		pin.icon = pin:CreateTexture(nil, "OVERLAY")
		pin.icon:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		pin.icon:SetVertexColor(COLOR[1], COLOR[2], COLOR[3], COLOR[4])
		pin.icon:SetAllPoints()
		pins[i] = pin
	end
	pin.spot, pin.count, pin.last = spot, count, last
	pin:SetSize(size, size)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
	pin:Show()
end

-- Pins are only drawn on their own zone's map; continent maps would be a
-- carpet of them.
local function Redraw()
	drawnMap, drawnScale, drawnVersion = WorldMapFrame:GetMapID(), WorldMapFrame:GetCanvasScale() or 1, ns.version
	drawnAt = GetTime()
	local n = 0
	local byMap = ns.db.settings.map and drawnMap and Spots()[drawnMap]
	if byMap then
		local filter = ns.db.settings.mapFilter
		local w, h = overlay:GetSize()
		for _, spot in pairs(byMap) do
			local count, last = spot.count, spot.last
			if filter then
				local mob = spot.mobs[filter]
				count, last = mob and mob.count or 0, mob and mob.last
			end
			if count > 0 then
				-- Grows with the log of the count: 1, 10 and 100 kills look different.
				local size = math.min(MIN_SIZE + 2 * math.log(count) / math.log(2), MAX_SIZE) / drawnScale
				n = n + 1
				SetPin(n, spot, count, last, spot.x / spot.count / 100 * w, spot.y / spot.count / 100 * h, size)
			end
		end
	end
	for i = n + 1, #pins do
		pins[i]:Hide()
	end
end

local function OnUpdate()
	if not ns.db then
		return
	end
	-- While zooming the scale changes every frame; redraw once it settles.
	local zoomed = WorldMapFrame:GetCanvasScale() ~= drawnScale and GetTime() - drawnAt > 0.2
	if WorldMapFrame:GetMapID() ~= drawnMap or zoomed or ns.version ~= drawnVersion then
		Redraw()
	end
end

local function Create()
	if overlay or not WorldMapFrame or not WorldMapFrame.GetCanvas then
		return
	end
	local canvas = WorldMapFrame:GetCanvas()
	overlay = CreateFrame("Frame", nil, canvas)
	overlay:SetAllPoints(canvas)
	-- Above the map art (and TravelLog's trail), below icons like flight
	-- masters and quest markers.
	local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
	local level = manager and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	overlay:SetFrameLevel(level and level + 2 or canvas:GetFrameLevel() + 2)
	overlay:SetScript("OnUpdate", OnUpdate)
	ns.mapOverlay = overlay
end

-- Applies a changed "/kills map" setting.
function ns.RefreshMap()
	drawnMap = nil
end

ns.On("PLAYER_LOGIN", Create)
ns.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
