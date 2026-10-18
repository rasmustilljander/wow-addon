-- Draws your recorded path on the world map, with markers for jumps, loot,
-- deaths and level-ups. "/tl trail" picks how far back it shows.
local _, ns = ...

local MAX_LINES = 5000
local MAX_DOTS = 3000
local LINE_WIDTH = 2.5   -- screen pixels
local MIN_SEGMENT = 4    -- screen pixels between drawn trail points
local MAX_STEP = 300     -- yards between consecutive points; more is a teleport
local REFRESH = 3        -- seconds between adding new points while the map is open

-- Trail colors by how you were moving.
local COLORS = {
	foot = { 1, 0.82, 0, 0.9 },
	mount = { 1, 0.5, 0.1, 0.9 },
	flight = { 0.3, 0.85, 1, 0.8 },
	swim = { 0.3, 0.5, 1, 0.9 },
	ghost = { 0.85, 0.85, 0.85, 0.6 },
}

-- Marker colors and sizes (screen pixels).
local MARKERS = {
	jump = { 1, 1, 1, 0.8, 3 },
	loot = { 0.75, 0.4, 1, 0.9, 5 },
	death = { 1, 0.15, 0.15, 1, 9 },
	level = { 0.2, 1, 0.3, 1, 9 },
}

local overlay
local lines, dots = {}, {}
local drawnMap, drawnScale, drawnVersion, drawnAt = nil, nil, nil, 0

local function ModeOf(flags)
	local F = ns.FLAGS
	if ns.HasFlag(flags, F.taxi) then return "flight" end
	if ns.HasFlag(flags, F.dead) then return "ghost" end
	if ns.HasFlag(flags, F.swimming) then return "swim" end
	if ns.HasFlag(flags, F.mounted) then return "mount" end
	return "foot"
end

local function TrailStart(range)
	if range == "session" then
		return ns.session.start
	elseif range == "today" then
		local d = date("*t")
		d.hour, d.min, d.sec = 0, 0, 0
		return time(d)
	elseif range == "week" then
		return time() - 7 * 86400
	elseif range == "all" then
		return 0
	end
end

--------------------------------------------------------------------------------
-- Map projection
--------------------------------------------------------------------------------

-- Where each zone sits on the map being viewed, e.g. Elwynn Forest inside
-- Eastern Kingdoms. false means "not part of that map".
local rects = {}

local function Project(map, x, y, view)
	if map == view then
		return x, y
	end
	local byView = rects[view]
	if not byView then
		byView = {}
		rects[view] = byView
	end
	local r = byView[map]
	if r == nil then
		local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(map, view)
		r = minX and maxX > minX and maxY > minY and { minX, maxX - minX, minY, maxY - minY } or false
		byView[map] = r
	end
	if r then
		return r[1] + x * r[2], r[3] + y * r[4]
	end
end

--------------------------------------------------------------------------------
-- Parsed session data
--------------------------------------------------------------------------------

-- Path points are flattened into one array, PATH_STRIDE values per point:
-- seconds into session, map, x, y, flags, connected-to-previous-point.
local PATH_STRIDE = 6
local JUMP_STRIDE = 4 -- seconds, map, x, y

local function AddPathRecord(data, rec)
	local dt, map, x, y, inst, a, b, flags = ns.Unpack(rec)
	if not (dt and map and x and y) then
		return
	end
	local connected = false
	if data.prevMap then
		if inst and inst == data.prevInst and a and data.prevA then
			connected = (a - data.prevA) ^ 2 + (b - data.prevB) ^ 2 <= MAX_STEP ^ 2
		elseif map == data.prevMap then
			connected = math.abs(x - data.prevX) + math.abs(y - data.prevY) < 0.03
		end
	end
	local p, n = data.path, #data.path
	p[n + 1], p[n + 2], p[n + 3], p[n + 4], p[n + 5], p[n + 6] = dt, map, x, y, flags, connected
	data.maps[map] = true
	data.prevMap, data.prevX, data.prevY, data.prevInst, data.prevA, data.prevB = map, x, y, inst, a, b
end

local function AddJumpRecord(data, rec)
	local dt, map, x, y = ns.Unpack(rec)
	if dt and map and x and y then
		local j, n = data.jumps, #data.jumps
		j[n + 1], j[n + 2], j[n + 3], j[n + 4] = dt, map, x, y
		data.maps[map] = true
	end
end

-- Feeds add() the records of a stream it hasn't seen yet. read.chunks counts
-- stored chunks already read, read.buffered the buffer records read after
-- them; when the buffer is flushed those become the start of the next chunk.
local function CatchUp(data, read, store, buffer, add)
	local skip = read.buffered
	for c = read.chunks + 1, #store do
		for rec in store[c]:gmatch("[^;]+") do
			if skip > 0 then
				skip = skip - 1
			else
				add(data, rec)
			end
		end
	end
	if #store > read.chunks then
		read.chunks, read.buffered = #store, 0
	end
	if buffer then
		for i = read.buffered + 1, #buffer do
			add(data, buffer[i])
		end
		read.buffered = #buffer
	end
end

-- Parsed points per session, extended as new records arrive, so an open map
-- never re-reads a whole session.
local parsed = {}

local function SessionData(s)
	local data = parsed[s]
	if not data then
		data = {
			path = {}, jumps = {}, maps = {},
			pathRead = { chunks = 0, buffered = 0 }, jumpsRead = { chunks = 0, buffered = 0 },
		}
		parsed[s] = data
	end
	local current = s == ns.session
	CatchUp(data, data.pathRead, s.track, current and ns.track.buffer, AddPathRecord)
	CatchUp(data, data.jumpsRead, s.jumps or {}, current and ns.jumps.buffer, AddJumpRecord)
	return data
end

local function ShowsOn(maps, view)
	for map in pairs(maps) do
		if Project(map, 0.5, 0.5, view) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

local function SetLine(i, x1, y1, x2, y2, color, thickness)
	local line = lines[i]
	if not line then
		line = overlay:CreateLine(nil, "OVERLAY")
		lines[i] = line
	end
	line:SetColorTexture(color[1], color[2], color[3], color[4])
	line:SetThickness(thickness)
	line:SetStartPoint("TOPLEFT", overlay, x1, -y1)
	line:SetEndPoint("TOPLEFT", overlay, x2, -y2)
	line:Show()
end

local function SetDot(i, x, y, marker, size)
	local dot = dots[i]
	if not dot then
		dot = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
		dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		dots[i] = dot
	end
	dot:SetVertexColor(marker[1], marker[2], marker[3], marker[4])
	dot:SetSize(size, size)
	dot:ClearAllPoints()
	dot:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
	dot:Show()
end

local function HideFrom(pool, first)
	for i = first, #pool do
		pool[i]:Hide()
	end
end

-- Drawing state for the map being shown. A full redraw happens when the map,
-- zoom or setting changes; otherwise only newly recorded points are added.
local view = { progress = {}, cells = {} }

local function Dot(x, y, kind)
	if view.dots >= MAX_DOTS then
		return
	end
	local marker = MARKERS[kind]
	local size = marker[5] / view.scale
	-- Markers that would land on top of one of the same kind add nothing.
	local cell = kind .. math.floor(x / size) .. ":" .. math.floor(y / size)
	if view.cells[cell] then
		return
	end
	view.cells[cell] = true
	view.dots = view.dots + 1
	SetDot(view.dots, x, y, marker, size)
end

local function DrawSession(s, data, progress)
	local since, map, w, h = view.since, view.map, view.w, view.h
	local p, lastX, lastY = data.path, progress.x, progress.y
	for i = progress.path, #p, PATH_STRIDE do
		local x, y
		if s.start + p[i] >= since then
			x, y = Project(p[i + 1], p[i + 2], p[i + 3], map)
		end
		if not x then
			lastX = nil
		else
			x, y = x * w, y * h
			if lastX and p[i + 5] then
				if (x - lastX) ^ 2 + (y - lastY) ^ 2 >= view.minSegment and view.lines < MAX_LINES then
					view.lines = view.lines + 1
					SetLine(view.lines, lastX, lastY, x, y, COLORS[ModeOf(p[i + 4])], view.thickness)
					lastX, lastY = x, y
				end
			else
				lastX, lastY = x, y
			end
		end
	end
	progress.path, progress.x, progress.y = #p + 1, lastX, lastY

	local j = data.jumps
	for i = progress.jumps, #j, JUMP_STRIDE do
		if s.start + j[i] >= since then
			local x, y = Project(j[i + 1], j[i + 2], j[i + 3], map)
			if x then
				Dot(x * w, y * h, "jump")
			end
		end
	end
	progress.jumps = #j + 1
end

-- Draws whatever was recorded since the last call.
local function DrawNew()
	drawnVersion = ns.version
	drawnAt = GetTime()
	if not view.since or not view.map then
		return
	end
	local now = time()
	for _, s in ipairs(ns.char.sessions) do
		if (s.stop or now) >= view.since then
			local data = SessionData(s)
			if ShowsOn(data.maps, view.map) then
				local progress = view.progress[s]
				if not progress then
					progress = { path = 1, jumps = 1 }
					view.progress[s] = progress
				end
				DrawSession(s, data, progress)
			end
		end
	end

	local log = ns.char.log
	for i = view.logNext, #log do
		local e = log[i]
		if MARKERS[e.type] and e.map and e.x then
			local x, y = Project(e.map, e.x / 100, e.y / 100, view.map)
			if x then
				Dot(x * view.w, y * view.h, e.type)
			end
		end
	end
	view.logNext = #log + 1
end

local function Redraw()
	drawnMap = WorldMapFrame:GetMapID()
	drawnScale = WorldMapFrame:GetCanvasScale() or 1

	view.map, view.scale = drawnMap, drawnScale
	view.since = TrailStart(ns.settings.trail)
	view.w, view.h = overlay:GetSize()
	view.thickness = LINE_WIDTH / view.scale
	view.minSegment = (MIN_SEGMENT / view.scale) ^ 2
	view.lines, view.dots = 0, 0
	wipe(view.progress)
	wipe(view.cells)

	-- The log is in time order: find the first event inside the range.
	local log = ns.char.log
	view.logNext = #log + 1
	while view.since and view.logNext > 1 and log[view.logNext - 1].time >= view.since do
		view.logNext = view.logNext - 1
	end

	DrawNew()
	HideFrom(lines, view.lines + 1)
	HideFrom(dots, view.dots + 1)
end

local function OnUpdate()
	local map, scale = WorldMapFrame:GetMapID(), WorldMapFrame:GetCanvasScale()
	local sinceDraw = GetTime() - drawnAt
	if map ~= drawnMap or (scale ~= drawnScale and sinceDraw > 0.2) then
		Redraw()
	elseif drawnVersion ~= ns.version and sinceDraw > REFRESH then
		DrawNew()
	end
end

local function Create()
	if overlay or not WorldMapFrame or not WorldMapFrame.GetCanvas then
		return
	end
	local canvas = WorldMapFrame:GetCanvas()
	overlay = CreateFrame("Frame", nil, canvas)
	overlay:SetAllPoints(canvas)
	-- Above the map art and explored-area overlays, below icons like flight
	-- masters and quest markers.
	local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
	local level = manager and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
	overlay:SetFrameLevel(level and level + 1 or canvas:GetFrameLevel() + 1)
	overlay:SetScript("OnUpdate", OnUpdate)
	overlay:SetShown(ns.settings.trail ~= "off")
end

-- Applies a changed "/tl trail" setting.
function ns.RefreshTrail()
	if not overlay then
		return
	end
	overlay:SetShown(ns.settings.trail ~= "off")
	drawnMap = nil
end

ns.On("PLAYER_LOGIN", Create)
ns.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
