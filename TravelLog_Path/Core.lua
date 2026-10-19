-- TravelLog Path core: this character's path and jumps, one set per session
-- (login or reload), packed into compact strings. Needs TravelLog, whose
-- helpers, events and settings it uses.
local _, ns = ...
local tl = TravelLog

tl.Defaults({
	interval = 2,     -- seconds between recorded path points while moving (1-5)
	trail = "today",  -- what the world map trail shows: session/today/week/all/off
})

-- Path points and jumps are packed this many records per string, which keeps
-- the SavedVariables file small and quick to load.
local CHUNK_SIZE = 200

--------------------------------------------------------------------------------
-- Packed records
--------------------------------------------------------------------------------

local function Fixed(value, fmt)
	return value and fmt:format(value) or ""
end

-- Packs a snapshot from TravelLog.Here() into one compact record:
--   seconds into session, uiMapID, x, y (0-100 like in-game coordinates),
--   instanceID, world axis 1, world axis 2 (yards), flags [, extra...]
-- Missing values are left empty.
function ns.Pack(h, ...)
	local rec = ("%d,%s,%s,%s,%s,%s,%s,%d"):format(
		h.t - ns.session.start, h.map or "",
		Fixed(h.x and h.x * 100, "%.2f"), Fixed(h.y and h.y * 100, "%.2f"),
		h.inst or "", Fixed(h.wx, "%.1f"), Fixed(h.wy, "%.1f"), h.flags)
	for i = 1, select("#", ...) do
		local extra = tostring(select(i, ...) or ""):gsub("[,;]", " ")
		rec = rec .. "," .. extra
	end
	return rec
end

-- Reverses ns.Pack for one record. Numbers come back as numbers, x/y as 0-1.
function ns.Unpack(rec)
	local dt, map, x, y, inst, wx, wy, flags, extra = strsplit(",", rec, 9)
	x, y = tonumber(x), tonumber(y)
	return tonumber(dt), tonumber(map), x and x / 100, y and y / 100,
		tonumber(inst), tonumber(wx), tonumber(wy), tonumber(flags) or 0, extra
end

--------------------------------------------------------------------------------
-- Streams: append-only packed records (path points, jumps)
--------------------------------------------------------------------------------

local Stream = {}
Stream.__index = Stream

function ns.NewStream(store)
	return setmetatable({ store = store, buffer = {} }, Stream)
end

function Stream:Add(rec)
	tl.version = tl.version + 1
	local buffer = self.buffer
	buffer[#buffer + 1] = rec
	if #buffer >= CHUNK_SIZE then
		self:Flush()
	end
end

function Stream:Flush()
	if #self.buffer > 0 then
		self.store[#self.store + 1] = table.concat(self.buffer, ";")
		self.buffer = {}
	end
end

function ns.CountRecords(store, buffer)
	local n = buffer and #buffer or 0
	for _, chunk in ipairs(store) do
		n = n + select(2, chunk:gsub(";", "")) + 1
	end
	return n
end

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogPathDB = {
--   sessions = {   -- oldest first, one per login or reload
--     { start = 1760000000, stop = 1760007200, jumpCount = 12,
--       track = { "...", ... }, jumps = { "...", ... } },
--   },
-- }
-- start is the same as the TravelLog session's.

local function Init()
	TravelLogPathDB = TravelLogPathDB or {}
	local db = TravelLogPathDB
	db.sessions = db.sessions or {}

	-- TravelLog kept the path in its own sessions before this addon existed.
	local moved = false
	for _, s in ipairs(tl.char.sessions) do
		if s.track then
			db.sessions[#db.sessions + 1] = { start = s.start, stop = s.stop, jumpCount = s.jumpCount,
				track = s.track, jumps = s.jumps or {} }
			s.track, s.jumps, s.jumpCount = nil, nil, nil
			moved = true
		end
	end
	if moved then
		table.sort(db.sessions, function(a, b) return a.start < b.start end)
	end

	local session = { start = tl.session.start, track = {}, jumps = {} }
	db.sessions[#db.sessions + 1] = session
	ns.db, ns.session = db, session
	ns.track = ns.NewStream(session.track)
	ns.jumps = ns.NewStream(session.jumps)
end

tl.On("PLAYER_LOGIN", Init)

tl.On("PLAYER_LOGOUT", function()
	ns.session.stop = time()
	ns.track:Flush()
	ns.jumps:Flush()
end)

tl.On("TL_WIPE", function()
	TravelLogPathDB = nil
end)

-- Old sessions move into TravelLog_Archive along with TravelLog's own.
tl.Rotates("path", "paths",
	function() return ns.db.sessions end,
	function(list) ns.db.sessions = list end,
	function(s) return s ~= ns.session and (s.stop or s.start) end)
