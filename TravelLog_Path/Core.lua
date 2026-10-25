-- TravelLog Path core: each character's path and jumps, one set per session
-- (login or reload), packed into compact strings. Needs TravelLog, whose
-- helpers, events and settings it uses.
local _, ns = ...
local tl = TravelLog

tl.Defaults({
	interval = 2,       -- seconds between recorded path points while moving (1-5)
	trail = "today",    -- how far back the world map trail goes (see Range.lua)
	altTrail = "off",   -- the same for alts' trails
	friendTrail = "today", -- and for friends' trails (TravelLog_Share)
	smooth = 50,        -- how round the map trail's turns are, 0 (straight lines) to 100
	hiddenAlts = {},    -- alts whose trail isn't shown, by "Name-Realm"
	trailColors = {},   -- trail colors changed in the Colors tab, by how you moved: { r, g, b, a }
	markerColors = {},  -- the same for map markers, by kind
	trailFade = {},     -- how the map trail fades, the fields /tl fade changed (see ns.TRAIL_FADE)
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

-- TravelLogPathAccountDB = {
--   chars = {
--     ["Name-Realm"] = {
--       sessions = {   -- oldest first, one per login or reload
--         { start = 1760000000, stop = 1760007200, jumpCount = 12,
--           track = { "...", ... }, jumps = { "...", ... } },
--       },
--     },
--   },
-- }
-- start is the same as the TravelLog session's. Every character's path is
-- in the account-wide file so the map can show alts' trails.

local function Init()
	TravelLogPathAccountDB = TravelLogPathAccountDB or {}
	local account = TravelLogPathAccountDB
	account.chars = account.chars or {}
	local db = account.chars[tl.charKey] or {}
	account.chars[tl.charKey] = db
	db.sessions = db.sessions or {}

	-- Version 0.1 kept the path in the character's own file, where alts
	-- couldn't read it.
	local moved = false
	if TravelLogPathDB then
		for _, s in ipairs(TravelLogPathDB.sessions or {}) do
			db.sessions[#db.sessions + 1] = s
			moved = true
		end
		TravelLogPathDB = nil
	end

	-- TravelLog kept the path in its own sessions before this addon existed.
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
	ns.account, ns.db, ns.session = account, db, session
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
	ns.account.chars[tl.charKey] = nil
end)

-- This session's start and its newest path records, at most max of them,
-- from since (epoch) on. TravelLog_Share sends them to friends.
function tl.RecentPath(since, max)
	local list, from = {}, since - ns.session.start
	local function Take(rec)
		if tonumber(rec:match("^%d+")) >= from then
			list[#list + 1] = rec
		end
	end
	for _, chunk in ipairs(ns.session.track) do
		for rec in chunk:gmatch("[^;]+") do
			Take(rec)
		end
	end
	for _, rec in ipairs(ns.track.buffer) do
		Take(rec)
	end
	local newest = {}
	for i = math.max(#list - max + 1, 1), #list do
		newest[#newest + 1] = list[i]
	end
	return ns.session.start, newest
end

-- The other characters with a recorded path, sorted by "Name-Realm". Each
-- is { key, sessions, profile }, profile being TravelLog's (class, level).
function ns.Alts()
	local list = {}
	for key, char in pairs(ns.account.chars) do
		if key ~= tl.charKey and char.sessions and #char.sessions > 0 then
			list[#list + 1] = { key = key, sessions = char.sessions, profile = tl.db.chars[key] or {} }
		end
	end
	table.sort(list, function(a, b) return a.key < b.key end)
	return list
end
