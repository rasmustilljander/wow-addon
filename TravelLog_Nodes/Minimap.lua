-- Pins for looted chests and gathering nodes close to the player. The
-- minimap's yard radius and rotation determine which pins show and where.
local _, ns = ...
local tl = TravelLog

local holder
local pins = {}
local candidates = {} -- { node, from } on the player's map
local builtMap, builtVersion
local width, height -- yards the player's map covers
local last = {}     -- what was last drawn, to skip frames where nothing moved

local function HideFrom(first)
	for i = first, #pins do
		pins[i]:Hide()
	end
end

local function Build(map)
	builtMap, builtVersion, candidates = map, ns.version, {}
	width, height = C_Map.GetMapWorldSize(map)
	local function Add(node, from)
		candidates[#candidates + 1] = { node = node, from = from }
	end
	for _, get in ipairs(ns.sources) do
		get(map, Add)
	end
	for _, node in ipairs(ns.db.maps[map] or {}) do
		Add(node)
	end
end

local function Update()
	if not ns.db then
		return
	end
	local map = tl.settings.nodeMinimap and tl.Clean(C_Map.GetBestMapForUnit("player"))
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	local px, py = pos and tl.Clean(pos.x), pos and tl.Clean(pos.y)
	if not (px and py) then
		last.x = nil -- draw again once there is a position
		return HideFrom(1)
	end
	if map ~= builtMap or ns.version ~= builtVersion then
		Build(map)
		last.x = nil
	end
	local radius = C_Minimap.GetViewRadius()
	local rotate = C_CVar.GetCVar("rotateMinimap") == "1"
	local facing = rotate and tl.Clean(GetPlayerFacing()) or 0
	local size = Minimap:GetWidth()
	if px == last.x and py == last.y and facing == last.facing and radius == last.radius and size == last.size then
		return
	end
	last = { x = px, y = py, facing = facing, radius = radius, size = size }
	if not (width and width > 0 and height and height > 0 and radius and radius > 0) then
		return HideFrom(1)
	end

	local scale = size / 2 / radius -- pixels per yard
	local cos, sin = math.cos(facing), math.sin(facing)
	local n = 0
	for _, candidate in ipairs(candidates) do
		local node = candidate.node
		local east = (node.x / 100 - px) * width
		local north = (py - node.y / 100) * height
		if east * east + north * north <= radius * radius then
			-- A rotating minimap turns with you: what you face is up.
			east, north = east * cos + north * sin, north * cos - east * sin
			n = n + 1
			local pin = pins[n]
			if not pin then
				pin = ns.NewNodePin(holder)
				pins[n] = pin
			end
			ns.SetNodePin(pin, node, candidate.from)
			pin:ClearAllPoints()
			pin:SetPoint("CENTER", Minimap, "CENTER", east * scale, north * scale)
			pin:Show()
		end
	end
	HideFrom(n + 1)
end

function ns.RefreshMinimap()
	last.x = nil
	if not tl.settings.nodeMinimap then
		HideFrom(1)
	end
end

tl.On("PLAYER_LOGIN", function()
	if not (Minimap and C_Minimap and C_Minimap.GetViewRadius and C_Map.GetMapWorldSize) then
		return
	end
	holder = CreateFrame("Frame", nil, Minimap)
	holder:SetAllPoints(Minimap)
	holder:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	holder:SetScript("OnUpdate", Update)
	ns.minimapHolder = holder
end)
