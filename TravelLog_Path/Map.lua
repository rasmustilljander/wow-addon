-- Draws your recorded path on the world map, with markers for jumps, and for
-- loot, deaths, level-ups, notes and other milestones from TravelLog's log,
-- and your alts' paths in their class color. "/tl trail" picks how far back
-- each shows.
local _, ns = ...
local tl = TravelLog

local MAX_LINES = 5000
local MAX_DOTS = 3000
local LINE_WIDTH = 2.5   -- screen pixels
local ALT_LINE_WIDTH = 1.5
local ALT_ALPHA = 0.7
local MIN_SEGMENT = 4    -- screen pixels between drawn trail points
local CURVE_ERROR = 0.5  -- screen pixels a curve's straight pieces may stray from it
local MAX_PIECES = 8     -- straight pieces per curved segment
local MAX_STEP = 300     -- yards between consecutive points; more is a teleport
local REFRESH = 3        -- seconds between adding new points while the map is open
local RANGE_REFRESH = 60 -- seconds before a rolling trail cutoff is recomputed

-- Trail colors by how you were moving, and marker colors. Changes from the
-- Colors tab (tl.settings.trailColors, markerColors) take their place.
ns.TRAIL_COLORS = {
	foot = { 1, 0.82, 0, 0.9 },
	mount = { 1, 0.5, 0.1, 0.9 },
	flight = { 0.3, 0.85, 1, 0.8 },
	swim = { 0.3, 0.5, 1, 0.9 },
	ghost = { 0.85, 0.85, 0.85, 0.6 },
}
ns.MARKER_COLORS = {
	jump = { 1, 1, 1, 0.8 },
	loot = { 0.75, 0.4, 1, 0.9 },
	death = { 1, 0.15, 0.15, 1 },
	level = { 0.2, 1, 0.3, 1 },
	learned = { 1, 0.45, 0.75, 1 },
	taxipath = { 0, 0.75, 0.65, 1 },
	standing = { 0.65, 0.45, 0.25, 1 },
	mount = { 1, 1, 1, 1 },
	note = { 1, 1, 0.6, 1 },
}

-- Marker sizes (screen pixels).
local MARKER_SIZES = { jump = 3, loot = 5, death = 9, level = 9, learned = 7, taxipath = 7, standing = 7, mount = 9, note = 9 }

-- Log entry types drawn with another type's marker.
local MARKER_OF = { spell = "learned", skill = "learned", skillup = "learned" }

-- Markers that show their entry when hovered.
local HOVERED = { death = true, note = true }

local overlay
local lines, dots, pins = {}, {}, {}
local drawnMap, drawnScale, drawnVersion, drawnRange, drawnAt = nil, nil, nil, nil, 0

-- A stable key until a rolling range needs its cutoff recomputed. Calendar
-- days change at local midnight; hour/day durations and week age once a
-- minute so an open map does not keep old points indefinitely.
local function RangeKey(range)
	if range == "today" then
		return range .. date("%Y-%m-%d", time())
	elseif range == "week" or range:match("^%d+[hd]$") then
		return range .. math.floor(time() / RANGE_REFRESH)
	end
	return range
end

local function CurrentRangeKey()
	return RangeKey(tl.settings.trail) .. ":" .. RangeKey(tl.settings.altTrail)
end

local function ModeOf(flags)
	local F = tl.FLAGS
	if tl.HasFlag(flags, F.taxi) then return "flight" end
	if tl.HasFlag(flags, F.dead) then return "ghost" end
	if tl.HasFlag(flags, F.swimming) then return "swim" end
	if tl.HasFlag(flags, F.mounted) then return "mount" end
	return "foot"
end

local function TrailColor(flags)
	local mode = ModeOf(flags)
	return tl.settings.trailColors[mode] or ns.TRAIL_COLORS[mode]
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

-- Alts' lines go on sublevel -1, below yours.
local function SetLine(i, x1, y1, x2, y2, color, thickness, sublevel)
	local line = lines[i]
	if not line then
		line = overlay:CreateLine(nil, "OVERLAY")
		lines[i] = line
	end
	line:SetDrawLayer("OVERLAY", sublevel)
	line:SetColorTexture(color[1], color[2], color[3], color[4])
	line:SetThickness(thickness)
	line:SetStartPoint("TOPLEFT", overlay, x1, -y1)
	line:SetEndPoint("TOPLEFT", overlay, x2, -y2)
	line:Show()
end

local function SetDot(i, x, y, color, size)
	local dot = dots[i]
	if not dot then
		dot = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
		dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		dots[i] = dot
	end
	dot:SetVertexColor(color[1], color[2], color[3], color[4])
	dot:SetSize(size, size)
	dot:ClearAllPoints()
	dot:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
	dot:Show()
end

local function PinTooltip(pin)
	local e = pin.event
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:AddLine(tl.LogTypeLabel(e))
	GameTooltip:AddLine(date("%Y-%m-%d %H:%M", e.time), 1, 1, 1)
	GameTooltip:AddLine(tl.Describe(e), 1, 1, 1)
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

-- An invisible, click-through frame over a death or note dot makes just that
-- marker hoverable without changing how the trail and its textures are drawn.
local function SetPin(i, e, x, y, size)
	local pin = pins[i]
	if not pin then
		pin = CreateFrame("Frame", nil, overlay)
		pin:EnableMouse(true)
		pin:SetMouseClickEnabled(false)
		pin:SetScript("OnEnter", PinTooltip)
		pin:SetScript("OnLeave", HideTooltip)
		pins[i] = pin
	end
	pin.event = e
	pin:SetSize(size, size)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", overlay, "TOPLEFT", x, -y)
	pin:Show()
end

local function HideFrom(pool, first)
	for i = first, #pool do
		pool[i]:Hide()
	end
end

-- Drawing state for the map being shown. A full redraw happens when the map,
-- zoom or setting changes; otherwise only newly recorded points are added.
local view = { progress = {}, cells = {}, sources = {}, logNext = {} }

local function Dot(x, y, kind, event)
	if view.dots >= MAX_DOTS then
		return
	end
	local size = MARKER_SIZES[kind] / view.scale
	-- Markers that would land on top of one of the same kind add nothing.
	local cell = kind .. math.floor(x / size) .. ":" .. math.floor(y / size)
	if view.cells[cell] then
		return
	end
	view.cells[cell] = true
	view.dots = view.dots + 1
	SetDot(view.dots, x, y, tl.settings.markerColors[kind] or ns.MARKER_COLORS[kind], size)
	if HOVERED[kind] then
		view.pins = view.pins + 1
		SetPin(view.pins, event, x, y, size)
	end
end

-- Direction of a centripetal Catmull-Rom curve at (mx, my), coming from
-- (ax, ay) and going on to (cx, cy). Without one neighbour, the direction to
-- or from the other.
local function Tangent(ax, ay, mx, my, cx, cy)
	local da = ax and ((mx - ax) ^ 2 + (my - ay) ^ 2) ^ 0.25
	local dc = cx and ((cx - mx) ^ 2 + (cy - my) ^ 2) ^ 0.25
	if not da or da == 0 then
		return (cx - mx) / dc, (cy - my) / dc
	elseif not dc or dc == 0 then
		return (mx - ax) / da, (my - ay) / da
	end
	return (mx - ax) / da - (cx - ax) / (da + dc) + (cx - mx) / dc,
		(my - ay) / da - (cy - ay) / (da + dc) + (cy - my) / dc
end

-- Draws the trail from b to c as a curve through a before it and d after it
-- (either may be nil), in as few straight pieces as look smooth. view.smooth
-- (0-1) is how round it is; 0 draws a straight line. Lines are taken from
-- slots first, if given, then from the pool; keep adds the pool's to slots
-- so the segment can be redrawn in place once the point after it is known.
local function DrawCurve(slots, keep, ax, ay, bx, by, cx, cy, dx, dy, color, thickness, sublevel)
	local ex, ey = cx - bx, cy - by
	local s = view.smooth * (ex * ex + ey * ey) ^ 0.25
	local t1x, t1y = Tangent(ax, ay, bx, by, cx, cy)
	local t2x, t2y = Tangent(bx, by, cx, cy, dx, dy)
	-- How far the curve leaves the straight line at each end. Only the part
	-- across the line bends it.
	local u1x, u1y, u2x, u2y = t1x * s - ex, t1y * s - ey, t2x * s - ex, t2y * s - ey
	local bend = (math.abs(u1x * ey - u1y * ex) + math.abs(u2x * ey - u2y * ex)) / (ex * ex + ey * ey) ^ 0.5 * view.scale
	local n = math.max(1, math.min(MAX_PIECES, math.ceil(math.sqrt(bend / (2 * CURVE_ERROR)))))
	local x0, y0 = bx, by
	for k = 1, n do
		local i = slots and slots[k]
		if not i then
			if view.lines >= MAX_LINES then
				break
			end
			view.lines = view.lines + 1
			i = view.lines
			if keep then
				slots[k] = i
			end
		end
		-- Hermite form: the straight line plus the bend at each end.
		local t = k / n
		local h1, h2 = t * (1 - t) ^ 2, t * t * (t - 1)
		local x, y = bx + t * ex + h1 * u1x + h2 * u2x, by + t * ey + h1 * u1y + h2 * u2y
		SetLine(i, x0, y0, x, y, color, thickness, sublevel)
		x0, y0 = x, y
	end
	for k = n + 1, slots and #slots or 0 do
		lines[slots[k]]:Hide()
	end
end

-- Finishes the trail drawn so far in progress, so the next point starts a
-- new one.
local function EndTrail(c, thickness, sublevel)
	if c.color and not c.tail then
		DrawCurve(nil, false, c.ax, c.ay, c.bx, c.by, c.x, c.y, nil, nil, c.color, thickness, sublevel)
	end
	c.ax, c.ay, c.bx, c.by, c.x, c.y, c.color, c.tail = nil, nil, nil, nil, nil, nil, nil, nil
end

-- Draws a session's points not drawn yet. source is the history it's from
-- (see Sources).
local function DrawSession(s, data, progress, source)
	local since, before, map, w, h = source.since, source.before or math.huge, view.map, view.w, view.h
	local color, thickness, sublevel = source.color, source.width / view.scale, source.color and -1 or 0
	-- Each segment waits for the point after it, which shapes its curve.
	-- progress holds the last three points kept (a, b and x), the color of
	-- the waiting segment b-x, and its lines if already drawn as an end.
	local p, c = data.path, progress
	for i = progress.path, #p, PATH_STRIDE do
		local x, y
		local t = s.start + p[i]
		if t >= since and t < before then
			x, y = Project(p[i + 1], p[i + 2], p[i + 3], map)
		end
		if not x then
			EndTrail(c, thickness, sublevel)
		else
			x, y = x * w, y * h
			if c.x and p[i + 5] then
				if (x - c.x) ^ 2 + (y - c.y) ^ 2 >= view.minSegment and view.lines < MAX_LINES then
					if c.color then
						DrawCurve(c.tail, false, c.ax, c.ay, c.bx, c.by, c.x, c.y, x, y, c.color, thickness, sublevel)
					end
					c.ax, c.ay, c.bx, c.by, c.x, c.y = c.bx, c.by, c.x, c.y, x, y
					c.color, c.tail = color or TrailColor(p[i + 4]), nil
				end
			else
				EndTrail(c, thickness, sublevel)
				c.x, c.y = x, y
			end
		end
	end
	progress.path = #p + 1
	-- The newest segment is drawn as an end until a point follows it.
	if c.color and not c.tail then
		c.tail = {}
		DrawCurve(c.tail, true, c.ax, c.ay, c.bx, c.by, c.x, c.y, nil, nil, c.color, thickness, sublevel)
	end
	if not source.jumps then
		return
	end

	local j = data.jumps
	for i = progress.jumps, #j, JUMP_STRIDE do
		local t = s.start + j[i]
		if t >= since and t < before then
			local x, y = Project(j[i + 1], j[i + 2], j[i + 3], map)
			if x then
				Dot(x * w, y * h, "jump")
			end
		end
	end
	progress.jumps = #j + 1
end

-- Adds a character's stored history in a range to the list. alt is an entry
-- of ns.Alts(), or nil for this character.
local function AddSources(list, range, alt)
	local sessions = alt and alt.sessions or ns.db.sessions
	local since, before = ns.TrailSpan(range, sessions)
	if not since then
		return
	end
	local style = { since = since, before = before, width = LINE_WIDTH, jumps = true }
	if alt then
		local r, g, b = GetClassColor(alt.profile.class)
		style = { since = since, before = before, width = ALT_LINE_WIDTH, color = { r, g, b, ALT_ALPHA } }
	end
	local function Add(history)
		for key, value in pairs(style) do
			history[key] = value
		end
		list[#list + 1] = history
	end

	Add({ sessions = sessions, log = not alt and tl.char.log or nil })
end

-- Where the trails come from, each { sessions, log, since, before, width,
-- color, jumps }: path sessions, TravelLog's log for the markers (yours
-- only), the time range, and how to draw them. Yours come first so they
-- get the line budget; alts' lines are drawn below them anyway.
local function Sources()
	local list = {}
	AddSources(list, tl.settings.trail)
	if tl.settings.altTrail ~= "off" then
		for _, alt in ipairs(ns.Alts()) do
			if not tl.settings.hiddenAlts[alt.key] then
				AddSources(list, tl.settings.altTrail, alt)
			end
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Redrawing
--------------------------------------------------------------------------------

-- Draws whatever was recorded since the last call.
local function DrawNew()
	drawnVersion = tl.version
	drawnAt = GetTime()
	if not view.map then
		return
	end
	local now = time()
	for _, history in ipairs(view.sources) do
		for _, s in ipairs(history.sessions) do
			if (s.stop or now) >= history.since and (not history.before or s.start < history.before) then
				local data = SessionData(s)
				if ShowsOn(data.maps, view.map) then
					local progress = view.progress[s]
					if not progress then
						progress = { path = 1, jumps = 1 }
						view.progress[s] = progress
					end
					DrawSession(s, data, progress, history)
				end
			end
		end

		local log = history.log
		if log then
			for i = view.logNext[log] or 1, #log do
				local e = log[i]
				local kind = MARKER_OF[e.type] or e.type
				if MARKER_SIZES[kind] and e.map and e.x and (not history.before or e.time < history.before) then
					local x, y = Project(e.map, e.x / 100, e.y / 100, view.map)
					if x then
						Dot(x * view.w, y * view.h, kind, e)
					end
				end
			end
			view.logNext[log] = #log + 1
		end
	end
end

local function Redraw()
	drawnMap = WorldMapFrame:GetMapID()
	drawnScale = WorldMapFrame:GetCanvasScale() or 1
	drawnRange = CurrentRangeKey()

	view.map, view.scale = drawnMap, drawnScale
	view.w, view.h = overlay:GetSize()
	view.minSegment = (MIN_SEGMENT / view.scale) ^ 2
	view.smooth = tl.settings.smooth / 100
	view.lines, view.dots, view.pins = 0, 0, 0
	view.sources = Sources()
	view.logNext = {}
	wipe(view.progress)
	wipe(view.cells)

	-- Logs are in time order: start each at its first event inside the range.
	for _, history in ipairs(view.sources) do
		local log = history.log
		if log then
			local i = #log + 1
			while i > 1 and log[i - 1].time >= history.since do
				i = i - 1
			end
			view.logNext[log] = i
		end
	end

	DrawNew()
	HideFrom(lines, view.lines + 1)
	HideFrom(dots, view.dots + 1)
	HideFrom(pins, view.pins + 1)
end

local function OnUpdate()
	local map, scale = WorldMapFrame:GetMapID(), WorldMapFrame:GetCanvasScale()
	local sinceDraw = GetTime() - drawnAt
	if map ~= drawnMap or CurrentRangeKey() ~= drawnRange or (scale ~= drawnScale and sinceDraw > 0.2) then
		Redraw()
	elseif drawnVersion ~= tl.version and sinceDraw > REFRESH then
		DrawNew()
	end
end

local function Shown()
	return tl.settings.trail ~= "off" or tl.settings.altTrail ~= "off"
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
	overlay:SetShown(Shown())
end

-- Applies changed trail settings, or moved history.
function ns.RefreshTrail()
	if not overlay then
		return
	end
	overlay:SetShown(Shown())
	drawnMap = nil
end

tl.On("TL_ROTATED", ns.RefreshTrail)
tl.On("PLAYER_LOGIN", Create)
tl.On("ADDON_LOADED", function(name)
	if name == "Blizzard_WorldMap" then
		Create()
	end
end)
