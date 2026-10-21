-- Pins for looted chests and gathering nodes on zone maps, with a tooltip
-- saying when you last looted each one.
local _, ns = ...
local tl = TravelLog

local NODE_SIZE = 8   -- screen pixels
local SHARED_SIZE = 6 -- other players' nodes, which are also dimmer
local NODE_COLORS = {
	herb = { 0.35, 0.95, 0.35 },
	ore = { 0.95, 0.6, 0.3 },
	chest = { 1, 0.85, 0.2 },
	object = { 0.8, 0.8, 0.8 },
}
local NODE_LABELS = { herb = "Herb", ore = "Ore", chest = "Chest", object = "Object" }

local overlay
local pins = {}
local drawnMap, drawnScale, drawnVersion

local function NodeTooltip(pin)
	local node = pin.node
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:AddLine(node.name or NODE_LABELS[node.kind])
	if pin.from then
		GameTooltip:AddLine("Shared by " .. pin.from, 0.6, 0.8, 1)
	end
	GameTooltip:AddLine(("Last looted %s (%s ago)"):format(date("%Y-%m-%d %H:%M", node.last), tl.Ago(node.last)), 1, 1, 1)
	if node.count > 1 then
		GameTooltip:AddLine(("Looted %d times."):format(node.count) .. (node.times and " Before that:" or ""), 0.8, 0.8, 0.8)
		for i = 2, #(node.times or {}) do
			GameTooltip:AddLine("  " .. date("%Y-%m-%d %H:%M", node.times[i]), 0.8, 0.8, 0.8)
		end
	end
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function SetPin(i, node, x, y, size, from)
	local pin = pins[i]
	if not pin then
		pin = CreateFrame("Frame", nil, overlay)
		pin:EnableMouse(true)
		pin:SetMouseClickEnabled(false) -- clicks still reach the map
		pin:SetScript("OnEnter", NodeTooltip)
		pin:SetScript("OnLeave", HideTooltip)
		pin.icon = pin:CreateTexture(nil, "OVERLAY")
		pin.icon:SetAllPoints()
		pins[i] = pin
	end
	pin.node, pin.from = node, from
	local color = NODE_COLORS[node.kind] or NODE_COLORS.object
	pin.icon:SetColorTexture(color[1], color[2], color[3], from and 0.6 or 1)
	pin:SetSize(size, size)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
	pin:Show()
end

-- Nodes are only drawn on their own zone's map; continent maps would be a
-- carpet of them.
local function Draw()
	drawnMap = WorldMapFrame:GetMapID()
	drawnScale = WorldMapFrame:GetCanvasScale() or 1
	drawnVersion = ns.version
	local n = 0
	local w, h = overlay:GetSize()
	local function Add(node, from)
		n = n + 1
		SetPin(n, node, node.x / 100 * w, node.y / 100 * h, (from and SHARED_SIZE or NODE_SIZE) / drawnScale, from)
	end
	if drawnMap then
		for _, get in ipairs(ns.sources) do
			get(drawnMap, Add)
		end
		for _, node in ipairs(ns.db.maps[drawnMap] or {}) do
			Add(node)
		end
	end
	for i = n + 1, #pins do
		pins[i]:Hide()
	end
end

local function OnUpdate()
	if WorldMapFrame:GetMapID() ~= drawnMap or (WorldMapFrame:GetCanvasScale() or 1) ~= drawnScale
		or ns.version ~= drawnVersion then
		Draw()
	end
end

local function Create()
	if overlay or not WorldMapFrame or not WorldMapFrame.GetCanvas then
		return
	end
	local canvas = WorldMapFrame:GetCanvas()
	overlay = CreateFrame("Frame", nil, canvas)
	overlay:SetAllPoints(canvas)
	-- Above TravelLog_Path's trail and TravelLog_Kills' pins, below icons like
	-- flight masters and quest markers.
	local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
	local level = manager and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	overlay:SetFrameLevel(level and level + 3 or canvas:GetFrameLevel() + 3)
	overlay:SetScript("OnUpdate", OnUpdate)
	overlay:SetShown(tl.settings.nodes)
end

-- Applies a changed "/tl nodes" setting.
function ns.RefreshMap()
	if not overlay then
		return
	end
	overlay:SetShown(tl.settings.nodes)
	drawnMap = nil
end

tl.On("PLAYER_LOGIN", Create)
tl.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
