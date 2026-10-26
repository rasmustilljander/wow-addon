-- The world map's canvas as the TravelLog addons draw on it, with OpenMap's
-- seamless map (OpenMapAPI) when it's there. An identical copy is in
-- TravelLog_Path, _Nodes, _Kills and _NPCs, so each works on its own.
--
-- OpenMap stitches every zone into one map but keeps Blizzard's map
-- underneath: the zone (or continent) at the view's centre. A canvas overlay
-- still lines up with that map, so other zones in view are placed on it here.
local _, ns = ...

local V = {}
ns.MapView = V

local WORLD = 947  -- Azeroth, which OpenMap stitches the zones onto
local MARGIN = 0.25 -- of the view's size: zones this close to it count as in view
local FILL = 0.5    -- of the view's width or height a zone must fill for its pins

-- Bumped when OpenMap's view moves or it switches between its map and
-- Blizzard's, so overlays know to check V.Near again.
V.moved = 0

local function API()
	local OM = OpenMapAPI
	return type(OM) == "table" and OM.major == 1 and OM or nil
end

local function Stitched()
	local OM = API()
	return OM and OM.IsStitched() and OM
end

-- Puts an overlay offset levels above the map's highlight layer. OpenMap
-- inserts its art below that layer when it starts, which moves it up, so
-- this is read every time rather than once at login.
function V.Raise(overlay, offset)
	local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
	local level = manager and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	level = (level or WorldMapFrame:GetCanvas():GetFrameLevel()) + offset
	if overlay:GetFrameLevel() ~= level then
		overlay:SetFrameLevel(level)
	end
end

local zones -- every zone and city under Azeroth, in a fixed order
local rects = {} -- rects[host][map] = { x, w, y, h } on host's canvas (0-1), or false

local function Rect(OM, map, host)
	local byHost = rects[host]
	if not byHost then
		byHost = {}
		rects[host] = byHost
	end
	local r = byHost[map]
	if r == nil then
		local u0, v0 = OM.WorldFromMap(map, 0, 0)
		local u1, v1 = OM.WorldFromMap(map, 1, 1)
		local x0, y0, x1, y1
		if u0 and u1 then
			x0, y0 = OM.MapFromWorld(host, u0, v0)
			x1, y1 = OM.MapFromWorld(host, u1, v1)
		end
		r = x0 and x1 and x1 > x0 and y1 > y0 and { x0, x1 - x0, y0, y1 - y0 } or false
		byHost[map] = r
	end
	return r
end

-- The other zones in view on OpenMap's seamless map, placed on host's
-- canvas: { [mapID] = { x, w, y, h } } (0-1, like map coordinates), and a
-- key that changes when the set does. With all, every zone in view;
-- otherwise only those filling enough of it to be worth their pins, about
-- when OpenMap would make one the map underneath. Zones placed(map) says the
-- caller places itself are left out. Empty without OpenMap or on Blizzard's
-- own map.
function V.Near(host, all, placed)
	local near = {}
	local OM = host and Stitched()
	local view = OM and WorldMapFrame.GetViewRect and WorldMapFrame:GetViewRect()
	if not view then
		return near, ""
	end
	if not zones then
		zones = {}
		for _, info in ipairs(C_Map.GetMapChildrenInfo(WORLD, Enum.UIMapType.Zone, true) or {}) do
			zones[#zones + 1] = info.mapID
		end
	end
	local vw, vh = view.right - view.left, view.bottom - view.top
	local left, right = view.left - vw * MARGIN, view.right + vw * MARGIN
	local top, bottom = view.top - vh * MARGIN, view.bottom + vh * MARGIN
	local keys = {}
	for _, map in ipairs(zones) do
		local r = map ~= host and not (placed and placed(map)) and Rect(OM, map, host)
		if r and r[1] < right and r[1] + r[2] > left and r[3] < bottom and r[3] + r[4] > top
			and (all or r[2] >= vw * FILL or r[4] >= vh * FILL) then
			near[map] = r
			keys[#keys + 1] = map
		end
	end
	return near, table.concat(keys, ",")
end

local function Moved()
	V.moved = V.moved + 1
end

-- Follows OpenMap's view, and adds a switch for an overlay to OpenMap's
-- menu under "TravelLog". Call at login, once OpenMap has loaded.
function V.Setup(id, label, icon, get, set)
	local OM = API()
	if not OM then
		return
	end
	if OM.RegisterCallback then
		OM.RegisterCallback(V, "OpenMap_ViewChanged", Moved)
		OM.RegisterCallback(V, "OpenMap_StitchedChanged", Moved)
	end
	if OM.RegisterMenuToggle then
		OM.RegisterMenuToggle("TravelLog", { id = id, label = label, icon = icon, get = get, set = set, section = "TravelLog" })
	end
end
