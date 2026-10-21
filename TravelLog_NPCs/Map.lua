-- Pins on the world map for the NPCs saved on the shown map. Like kills,
-- only on the map an NPC was saved on, so a city's NPCs show on the city map
-- and not on its zone or continent.
local _, ns = ...

local SIZE = 9 -- screen pixels

local overlay
local pins = {}
local drawnMap, drawnScale, drawnVersion, drawnAt = nil, nil, nil, 0

local function Redraw()
	drawnMap, drawnScale, drawnVersion = WorldMapFrame:GetMapID(), WorldMapFrame:GetCanvasScale() or 1, ns.version
	drawnAt = GetTime()
	local n = 0
	if ns.db.settings.worldMap and drawnMap then
		local w, h = overlay:GetSize()
		local size = SIZE / drawnScale
		for _, npc in pairs(ns.db.npcs) do
			if npc.map == drawnMap and npc.x and ns.Shown(npc) then
				n = n + 1
				local pin = pins[n]
				if not pin then
					pin = ns.NewPin(overlay)
					pins[n] = pin
				end
				ns.SetPinNPC(pin, npc)
				pin:SetSize(size, size)
				pin:ClearAllPoints()
				pin:SetPoint("CENTER", overlay, "TOPLEFT", npc.x / 100 * w, -npc.y / 100 * h)
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
	-- Above TravelLog's trail, kills and nodes, below Blizzard's icons.
	local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
	local level = manager and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	overlay:SetFrameLevel(level and level + 4 or canvas:GetFrameLevel() + 4)
	overlay:SetScript("OnUpdate", OnUpdate)
	ns.mapOverlay = overlay
end

ns.On("PLAYER_LOGIN", Create)
ns.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
