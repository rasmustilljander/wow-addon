-- Pins for looted chests and gathering nodes on zone maps, with a tooltip
-- saying when each was last looted and by which character.
local _, ns = ...
local tl = TravelLog

local NODE_SIZE = 8 -- screen pixels
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

-- A character's name in their class color, with the realm if it isn't yours.
local function Who(key)
	local profile = tl.db.chars[key]
	local _, _, _, color = GetClassColor(profile and profile.class)
	local name, realm = key:match("^(.-)%-(.+)$")
	return ("|c%s%s|r"):format(color, realm == GetRealmName() and name or key)
end

local function Stamp(t)
	return date("%Y-%m-%d %H:%M", t)
end

local function NodeTooltip(pin)
	local node = pin.node
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:AddLine(node.name or NODE_LABELS[node.kind])
	if node.last then
		GameTooltip:AddLine(("Last looted %s (%s ago) by %s"):format(Stamp(node.last), tl.Ago(node.last),
			Who(node.by[1])), 1, 1, 1)
	end
	local total = ns.Total(node)
	if total > 1 then
		local looters = {}
		for key, count in pairs(node.counts) do
			looters[#looters + 1] = { key = key, count = count }
		end
		local text = ("Looted %d times"):format(total)
		if #looters > 1 then
			table.sort(looters, function(a, b) return a.count > b.count or (a.count == b.count and a.key < b.key) end)
			for i, l in ipairs(looters) do
				looters[i] = Who(l.key) .. " " .. l.count
			end
			text = text .. " (" .. table.concat(looters, ", ") .. ")"
		end
		GameTooltip:AddLine(text .. (#node.times > 1 and ". Before that:" or ""), 0.8, 0.8, 0.8)
		for i = 2, #node.times do
			GameTooltip:AddLine(("  %s  %s"):format(Stamp(node.times[i]), Who(node.by[i])), 0.8, 0.8, 0.8)
		end
	end
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function SetPin(i, node, x, y, size)
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
	pin.node = node
	local color = NODE_COLORS[node.kind] or NODE_COLORS.object
	pin.icon:SetColorTexture(color[1], color[2], color[3], 1)
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
	local list = drawnMap and ns.db.maps[drawnMap]
	if list then
		local w, h = overlay:GetSize()
		local size = NODE_SIZE / drawnScale
		for _, node in ipairs(list) do
			n = n + 1
			SetPin(n, node, node.x / 100 * w, node.y / 100 * h, size)
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
