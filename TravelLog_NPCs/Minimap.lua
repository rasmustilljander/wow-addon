-- Pins on the minimap for the NPCs around you. NPC positions are turned into
-- coordinates on the map you're on, then into yards from you, so NPCs saved
-- on a city map still show while you're outside it.
local _, ns = ...

local SIZE = 10 -- pixels

local holder
local pins = {}
local candidates = {} -- { npc, x, y } on the player's map, 0-1
local builtMap, builtVersion
local width, height   -- yards the player's map covers
local last = {}       -- what was last drawn, to skip frames where nothing moved

-- Where an NPC is on another map (on continent `here`), in that map's 0-1
-- coordinates.
local function OnMap(npc, map, here)
	if npc.map == map then
		return npc.x / 100, npc.y / 100
	end
	local inst, world = C_Map.GetWorldPosFromMapPos(npc.map, CreateVector2D(npc.x / 100, npc.y / 100))
	if not (inst and world) or inst ~= here then
		return
	end
	local _, pos = C_Map.GetMapPosFromWorldPos(inst, world, map)
	if pos then
		return pos.x, pos.y
	end
end

-- The shown NPCs on the player's continent, placed on the player's map.
local function Build(map)
	builtMap, builtVersion, candidates = map, ns.version, {}
	width, height = C_Map.GetMapWorldSize(map)
	local here = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0.5, 0.5))
	for _, npc in pairs(ns.db.npcs) do
		if npc.x and ns.Shown(npc) then
			local x, y = OnMap(npc, map, here)
			if x then
				candidates[#candidates + 1] = { npc = npc, x = x, y = y }
			end
		end
	end
end

-- Both maps' pins: name, title, kinds, stock and last visit.
local function PinTooltip(pin)
	local npc = pin.npc
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:AddLine(npc.name)
	if npc.title then
		GameTooltip:AddLine(npc.title, 1, 1, 1)
	end
	local kind = ns.Kind(npc)
	GameTooltip:AddLine(ns.KindsText(npc), kind.color[1], kind.color[2], kind.color[3])
	if npc.items and next(npc.items) then
		local n = 0
		for _ in pairs(npc.items) do
			n = n + 1
		end
		GameTooltip:AddLine(("Sells %d item%s"):format(n, n == 1 and "" or "s"), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(("Visited %s ago"):format(ns.Ago(npc.seen)), 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

function ns.NewPin(parent)
	local pin = CreateFrame("Frame", nil, parent)
	pin:EnableMouse(true)
	pin:SetMouseClickEnabled(false) -- clicks still reach the map
	pin:SetScript("OnEnter", PinTooltip)
	pin:SetScript("OnLeave", HideTooltip)
	pin.icon = pin:CreateTexture(nil, "OVERLAY")
	pin.icon:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
	pin.icon:SetAllPoints()
	return pin
end

-- Colors a pin for its NPC.
function ns.SetPinNPC(pin, npc)
	pin.npc = npc
	local c = ns.Kind(npc).color
	pin.icon:SetVertexColor(c[1], c[2], c[3], 1)
end

local function HideFrom(n)
	for i = n, #pins do
		pins[i]:Hide()
	end
end

local function Update()
	if not ns.db then
		return
	end
	local map = ns.db.settings.minimap and ns.Clean(C_Map.GetBestMapForUnit("player"))
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	local px, py = pos and ns.Clean(pos.x), pos and ns.Clean(pos.y)
	if not (px and py) then
		last.x = nil -- draw again once there's a position
		return HideFrom(1)
	end
	if map ~= builtMap or ns.version ~= builtVersion then
		Build(map)
		last.x = nil
	end
	local radius = C_Minimap.GetViewRadius()
	local rotate = C_CVar.GetCVar("rotateMinimap") == "1"
	local facing = rotate and ns.Clean(GetPlayerFacing()) or 0
	local size = Minimap:GetWidth()
	if px == last.x and py == last.y and facing == last.facing and radius == last.radius and size == last.size then
		return
	end
	last = { x = px, y = py, facing = facing, radius = radius, size = size }
	if not (width and width > 0 and radius and radius > 0) then
		return HideFrom(1)
	end

	local scale = size / 2 / radius -- pixels per yard
	local cos, sin = math.cos(facing), math.sin(facing)
	local n = 0
	for _, c in ipairs(candidates) do
		local east, north = (c.x - px) * width, (py - c.y) * height
		if east * east + north * north <= radius * radius then
			-- A rotating minimap turns with you: what you face is up.
			east, north = east * cos + north * sin, north * cos - east * sin
			n = n + 1
			local pin = pins[n]
			if not pin then
				pin = ns.NewPin(holder)
				pin:SetSize(SIZE, SIZE)
				pins[n] = pin
			end
			ns.SetPinNPC(pin, c.npc)
			pin:ClearAllPoints()
			pin:SetPoint("CENTER", Minimap, "CENTER", east * scale, north * scale)
			pin:Show()
		end
	end
	HideFrom(n + 1)
end

ns.On("PLAYER_LOGIN", function()
	if not (Minimap and C_Minimap and C_Minimap.GetViewRadius and C_Map.GetMapWorldSize) then
		return
	end
	holder = CreateFrame("Frame", nil, Minimap)
	holder:SetAllPoints(Minimap)
	holder:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	holder:SetScript("OnUpdate", Update)
	ns.minimapHolder = holder
end)
