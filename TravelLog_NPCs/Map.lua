-- Pins on the world map for the NPCs saved on the shown map. Like kills,
-- only on the map an NPC was saved on, so a city's NPCs show on the city map
-- and not on its zone or continent. With OpenMap, other zones zoomed in on
-- around the shown one show theirs too.
local _, ns = ...

local SIZE = 9 -- screen pixels

local MapView = ns.MapView
local WHOLE = { 0, 1, 0, 1 } -- the shown map on itself

local overlay
local pins = {}
local drawnMap, drawnScale, drawnVersion, drawnAt, drawnNear, drawnMoved = nil, nil, nil, 0, nil, nil

local function Redraw()
	drawnMap, drawnScale, drawnVersion = WorldMapFrame:GetMapID(), WorldMapFrame:GetCanvasScale() or 1, ns.version
	drawnAt = GetTime()
	local near
	near, drawnNear = MapView.Near(drawnMap)
	drawnMoved = MapView.moved
	local n = 0
	if ns.db.settings.worldMap and drawnMap then
		local w, h = overlay:GetSize()
		local size = SIZE / drawnScale
		for _, npc in pairs(ns.db.npcs) do
			local r = npc.map == drawnMap and WHOLE or near[npc.map]
			if r and npc.x and ns.Shown(npc) then
				n = n + 1
				local pin = pins[n]
				if not pin then
					pin = ns.NewPin(overlay)
					pins[n] = pin
				end
				ns.SetPinNPC(pin, npc)
				pin:SetSize(size, size)
				pin:ClearAllPoints()
				pin:SetPoint("CENTER", overlay, "TOPLEFT", (r[1] + npc.x / 100 * r[2]) * w, -(r[3] + npc.y / 100 * r[4]) * h)
				pin:Show()
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
	MapView.Raise(overlay, 4)
	-- While zooming the scale changes every frame; redraw once it settles.
	local zoomed = WorldMapFrame:GetCanvasScale() ~= drawnScale and GetTime() - drawnAt > 0.2
	if WorldMapFrame:GetMapID() ~= drawnMap or zoomed or ns.version ~= drawnVersion
		or MapView.moved ~= drawnMoved and select(2, MapView.Near(drawnMap)) ~= drawnNear then
		Redraw()
	end
	drawnMoved = MapView.moved
end

local function Create()
	if overlay or not WorldMapFrame or not WorldMapFrame.GetCanvas then
		return
	end
	local canvas = WorldMapFrame:GetCanvas()
	overlay = CreateFrame("Frame", nil, canvas)
	overlay:SetAllPoints(canvas)
	-- Above TravelLog's trail, kills and nodes, below Blizzard's icons.
	MapView.Raise(overlay, 4)
	overlay:SetScript("OnUpdate", OnUpdate)
	ns.mapOverlay = overlay
end

ns.On("PLAYER_LOGIN", function()
	Create()
	MapView.Setup("npcs", "NPCs", "Interface\\Icons\\INV_Misc_Coin_01", function()
		return ns.db.settings.worldMap
	end, function(on)
		ns.db.settings.worldMap = on
		ns.Changed()
	end)
end)
ns.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
