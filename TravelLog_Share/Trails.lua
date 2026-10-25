-- Friends' trails: the path points TravelLog_Path records go to friends who
-- ask, a few per message, and theirs are drawn on your world map like an
-- alt's trail. Both need TravelLog_Path.
--
--   PATH <since>               send me your path points from <since> (epoch)
--                              on, and new ones as you record them
--   P <start>,<class> <rec>;<rec>...
--                              path records of your session that started at
--                              <start>, packed as TravelLog_Path saves them
--
-- Only points of the sender's current session are sent, and only from when
-- the asker came online: catching up on more is too slow for the paced
-- whispers. What you get is kept for this session only.
local _, ns = ...
local tl = TravelLog

local SEND_EVERY = 10    -- seconds between batches of new points to friends
local MAX_CATCHUP = 150  -- points sent at most when a friend asks
local MAX_POINTS = 20000 -- points kept from one friend this session

-- A packed path record: seconds into the session, map, x, y, instance,
-- world position, flags. Anything else isn't taken.
local RECORD = "^%d+,%d+,%d+%.?%d*,%d+%.?%d*,%-?%d*,%-?[%d%.]*,%-?[%d%.]*,%d+$"

--------------------------------------------------------------------------------
-- Sharing yours
--------------------------------------------------------------------------------

local pending, pendingStart = {}, nil -- points recorded since the last batch

local function SendPoints(target, start, records)
	if #records > 0 then
		ns.SendPacked(target, ("P %d,%s"):format(start, select(2, UnitClass("player")) or ""), records)
	end
end

ns.handlers.PATH = function(sender, key, arg)
	if ns.FromFriend(sender, key) and tl.RecentPath then
		ns.pathListeners[key] = sender
		SendPoints(sender, tl.RecentPath(tonumber(arg) or 0, MAX_CATCHUP))
	end
end

tl.On("TL_PATH", function(rec, start)
	if next(ns.pathListeners) then
		pending[#pending + 1], pendingStart = rec, start
	end
end)

C_Timer.NewTicker(SEND_EVERY, function()
	if #pending == 0 then
		return
	end
	for key, name in pairs(ns.pathListeners) do
		if ns.db.friends[key] then
			SendPoints(name, pendingStart, pending)
		end
	end
	pending = {}
end)

--------------------------------------------------------------------------------
-- Getting theirs
--------------------------------------------------------------------------------

-- What friends sent this session, by key: { class, points, sessions }, the
-- sessions shaped like TravelLog_Path's ({ start, track }, oldest first),
-- each with the newest point's seconds into it (last).
ns.trails = {}

function ns.RequestPath(key)
	if tl.AddTrailSource then
		ns.Send(ns.db.friends[key], "PATH " .. tl.session.start)
	end
end

function ns.DropTrail(key)
	if ns.trails[key] then
		ns.trails[key] = nil
		tl.TrailsChanged()
	end
end

local function Session(trail, start)
	for _, s in ipairs(trail.sessions) do
		if s.start == start then
			return s
		end
	end
	local s = { start = start, track = {}, last = -1 }
	table.insert(trail.sessions, s)
	table.sort(trail.sessions, function(a, b) return a.start < b.start end)
	tl.TrailsChanged()
	return s
end

ns.handlers.P = function(_, key, arg)
	local start, class, list = arg:match("^(%d+),(%u*) (.+)$")
	start = tonumber(start)
	if not (start and tl.AddTrailSource) then
		return
	end
	local trail = ns.trails[key]
	if not trail then
		trail = { points = 0, sessions = {} }
		ns.trails[key] = trail
	end
	trail.class = class ~= "" and class or trail.class
	local s = Session(trail, start)
	-- A friend asked again may send points you have; take only newer ones.
	local records = {}
	for rec in list:gmatch("[^;]+") do
		local dt = rec:find(RECORD) and tonumber(rec:match("^%d+"))
		if dt and dt > s.last and trail.points < MAX_POINTS then
			records[#records + 1] = rec
			s.last, trail.points = dt, trail.points + 1
		end
	end
	if #records > 0 then
		s.track[#s.track + 1] = table.concat(records, ";")
		tl.version = tl.version + 1
	end
end

tl.On("PLAYER_LOGIN", function()
	if tl.AddTrailSource then
		tl.AddTrailSource(function(add)
			for key, trail in pairs(ns.trails) do
				if ns.db.friends[key] then
					add(trail.class, trail.sessions)
				end
			end
		end)
	end
end)
