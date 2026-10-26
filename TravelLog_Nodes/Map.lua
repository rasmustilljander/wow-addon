-- Pins for looted chests and gathering nodes on zone maps, with a tooltip
-- saying when each was last looted and by which character.
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

local MapView = ns.MapView
local WHOLE = { 0, 1, 0, 1 } -- the shown map on itself

local overlay
local pins = {}
local drawnMap, drawnScale, drawnVersion, drawnNear, drawnMoved

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
	-- Another player's, from TravelLog_Share: only when and how often.
	if pin.from then
		GameTooltip:AddLine("Shared by " .. pin.from, 0.6, 0.8, 1)
		GameTooltip:AddLine(("Last looted %s (%s ago)"):format(Stamp(node.last), tl.Ago(node.last)), 1, 1, 1)
		if node.count > 1 then
			GameTooltip:AddLine(("Looted %d times"):format(node.count), 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
		return
	end
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

-- Both the world map and minimap use the same pins and tooltip.
function ns.NewNodePin(parent)
	local pin = CreateFrame("Frame", nil, parent)
	pin:EnableMouse(true)
	pin:SetMouseClickEnabled(false) -- clicks still reach the map
	pin:SetScript("OnEnter", NodeTooltip)
	pin:SetScript("OnLeave", HideTooltip)
	pin.icon = pin:CreateTexture(nil, "OVERLAY")
	pin.icon:SetAllPoints()
	return pin
end

function ns.SetNodePin(pin, node, from)
	pin.node, pin.from = node, from
	local color = NODE_COLORS[node.kind] or NODE_COLORS.object
	pin.icon:SetColorTexture(color[1], color[2], color[3], from and 0.6 or 1)
	pin:SetSize(from and SHARED_SIZE or NODE_SIZE, from and SHARED_SIZE or NODE_SIZE)
	return pin
end

local function SetPin(i, node, x, y, size, from)
	local pin = pins[i]
	if not pin then
		pin = ns.NewNodePin(overlay)
		pins[i] = pin
	end
	ns.SetNodePin(pin, node, from)
	pin:SetSize(size, size)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
	pin:Show()
end

-- Nodes are only drawn on their own zone's map, and with OpenMap on other
-- zones zoomed in on around it; continent maps would be a carpet of them.
local function Draw()
	drawnMap = WorldMapFrame:GetMapID()
	drawnScale = WorldMapFrame:GetCanvasScale() or 1
	drawnVersion = ns.version
	local near
	near, drawnNear = MapView.Near(drawnMap)
	drawnMoved = MapView.moved
	local n = 0
	local w, h = overlay:GetSize()
	local r -- where the map being drawn sits on the shown one
	local function Add(node, from)
		n = n + 1
		SetPin(n, node, (r[1] + node.x / 100 * r[2]) * w, (r[3] + node.y / 100 * r[4]) * h,
			(from and SHARED_SIZE or NODE_SIZE) / drawnScale, from)
	end
	local function AddMap(map, rect)
		r = rect
		for _, get in ipairs(ns.sources) do
			get(map, Add)
		end
		for _, node in ipairs(ns.db.maps[map] or {}) do
			Add(node)
		end
	end
	if drawnMap then
		AddMap(drawnMap, WHOLE)
		for map, rect in pairs(near) do
			AddMap(map, rect)
		end
	end
	for i = n + 1, #pins do
		pins[i]:Hide()
	end
end

local function OnUpdate()
	MapView.Raise(overlay, 3)
	if WorldMapFrame:GetMapID() ~= drawnMap or (WorldMapFrame:GetCanvasScale() or 1) ~= drawnScale
		or ns.version ~= drawnVersion
		or MapView.moved ~= drawnMoved and select(2, MapView.Near(drawnMap)) ~= drawnNear then
		Draw()
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
	-- Above TravelLog_Path's trail and TravelLog_Kills' pins, below icons like
	-- flight masters and quest markers.
	MapView.Raise(overlay, 3)
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

tl.On("PLAYER_LOGIN", function()
	Create()
	MapView.Setup("nodes", "Looted nodes", "Interface\\Icons\\INV_Misc_Herb_07", function()
		return tl.settings.nodes
	end, function(on)
		tl.settings.nodes = on
		ns.RefreshMap()
	end)
end)
tl.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
