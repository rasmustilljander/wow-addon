-- TravelLog Group core: notices who is in your party or raid and records each
-- time you grouped with a player: when, for how long, where it started and
-- how many kills you made together.
--
-- A group with someone starts when they show up in the roster and ends when
-- they (or you) leave. Logging out ends it too, unless you log back in within
-- a few minutes still grouped with them.
local _, ns = ...

local RESUME = 300 -- seconds offline after which it's a new group with someone
local SETTLE = 10  -- seconds after login before players missing from the roster count as gone
local SEEN_KILLS = 200 -- killed GUIDs remembered, in case PARTY_KILL repeats

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- The Midnight-era client hands addons unreadable "secret" values in some
-- situations (unit names and GUIDs inside instances, chat in dungeons...).
local issecretvalue = issecretvalue
function ns.Clean(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

function ns.Count(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cff73b3e5TravelLog Group|r " .. text)
end

-- "3d 4h", "2h 13m", "5m": a number of seconds.
function ns.Duration(s)
	s = math.max(s, 0)
	local d, h, m = math.floor(s / 86400), math.floor(s / 3600) % 24, math.floor(s / 60) % 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	elseif m > 0 then
		return ("%dm"):format(m)
	end
	return "under a minute"
end

-- How long before now an epoch time was.
function ns.Ago(t)
	return ns.Duration(time() - t)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

-- Calls fn for a game event. Returns false if the client doesn't know it.
function ns.On(event, fn)
	if not handlers[event] then
		if not pcall(frame.RegisterEvent, frame, event) then
			return false
		end
		handlers[event] = {}
	end
	local list = handlers[event]
	list[#list + 1] = fn
	return true
end

frame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		local ok, err = pcall(fn, ...)
		if not ok then
			geterrorhandler()(err)
		end
	end
end)

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogGroupDB = {
--   total = 42,
--   places = { "Elwynn Forest|Goldshire", "Westfall", ... },
--   players = {
--     ["Anna-Forever"] = { key = "Anna-Forever", name = "Anna", realm = "Forever", guid = "Player-1-0A1B2C3D",
--       class = "WARRIOR", level = 14, count = 3, time = 15120, kills = 85,
--       first = 1760000000, last = 1760100000,
--       groups = { "1760000000,3600,2,40,12", ... } },  -- oldest first
--   },
--   open = { ["Anna-Forever"] = { start = 1760100000, seen = 1760103000, kills = 5 } },
-- }
-- Each group: start time, seconds together, place it started (index into
-- places), kills together, their level then, and "r" if it was a raid.
-- `open` holds the groups still going; they're written into `groups` when
-- they end.

local placeIndex = {} -- "Zone|Subzone" -> index into db.places
ns.byGUID = {}        -- player GUID -> player
ns.version = 0        -- goes up whenever something is recorded

local function Init()
	TravelLogGroupDB = TravelLogGroupDB or {}
	local db = TravelLogGroupDB
	db.version = 1
	db.total = db.total or 0
	db.places = db.places or {}
	db.players = db.players or {}
	db.open = db.open or {}
	ns.db = db
	for i, place in ipairs(db.places) do
		placeIndex[place] = i
	end
	for _, player in pairs(db.players) do
		if player.guid then
			ns.byGUID[player.guid] = player
		end
	end
end

local function PlaceIndex()
	local zone, subzone = ns.Clean(GetRealZoneText()), ns.Clean(GetSubZoneText())
	if not zone or zone == "" then
		return nil
	end
	local place = zone
	if subzone and subzone ~= "" and subzone ~= zone then
		place = zone .. "|" .. subzone
	end
	local i = placeIndex[place]
	if not i then
		i = #ns.db.places + 1
		ns.db.places[i] = place
		placeIndex[place] = i
	end
	return i
end

-- Zone and subzone (nil when there was none) of a place index.
function ns.Place(i)
	local place = i and ns.db.places[i]
	if not place then
		return nil
	end
	local zone, subzone = strsplit("|", place)
	return zone, subzone
end

local function Pack(g)
	local rec = ("%d,%d,%s,%s,%s,%s"):format(g.start, g.seconds, g.place or "", g.kills > 0 and g.kills or "",
		g.level or "", g.raid and "r" or "")
	return (rec:gsub(",+$", ""))
end

-- Reverses a packed group into a table.
function ns.UnpackGroup(rec)
	local start, seconds, place, kills, level, raid = strsplit(",", rec)
	local zone, subzone = ns.Place(tonumber(place))
	return {
		start = tonumber(start), seconds = tonumber(seconds), place = tonumber(place), zone = zone, subzone = subzone,
		kills = tonumber(kills) or 0, level = tonumber(level), raid = raid == "r",
	}
end

-- A player's groups as tables, oldest first; one still going is last, with
-- `now` set and the time so far.
function ns.Groups(player)
	local list = {}
	for i, rec in ipairs(player.groups) do
		list[i] = ns.UnpackGroup(rec)
	end
	local open = ns.db.open[player.key]
	if open and list[#list] then
		local g = list[#list]
		g.now, g.seconds, g.kills = true, time() - open.start, open.kills
	end
	return list
end

-- Total time grouped with a player, the current group included.
function ns.TimeWith(player)
	local open = ns.db.open[player.key]
	return player.time + (open and time() - open.start or 0)
end

-- Kills together, the current group included.
function ns.KillsWith(player)
	local open = ns.db.open[player.key]
	return player.kills + (open and open.kills or 0)
end

-- "Anna" for your own realm, "Anna-Stormrage" for others.
function ns.Display(player)
	if player.realm == GetNormalizedRealmName() then
		return player.name
	end
	return player.key
end

--------------------------------------------------------------------------------
-- The roster
--------------------------------------------------------------------------------

-- The other players in your group, by "Name-Realm", with what the client
-- tells about them. `complete` is false if someone couldn't be read (still
-- loading, or hidden inside an instance), so nobody should count as gone.
local function Roster()
	local members, complete = {}, true
	local n = GetNumGroupMembers()
	if n == 0 then
		return members, true
	end
	local raid = IsInRaid()
	local prefix = raid and "raid" or "party"
	for i = 1, raid and n or n - 1 do
		local unit = prefix .. i
		if UnitExists(unit) and not UnitIsUnit(unit, "player") then
			local name, realm = UnitName(unit)
			name, realm = ns.Clean(name), ns.Clean(realm)
			if not name or name == "" or name == UNKNOWNOBJECT then
				complete = false
			else
				realm = (realm and realm ~= "") and realm:gsub("[%s%-]", "") or GetNormalizedRealmName()
				local level = ns.Clean(UnitLevel(unit))
				members[name .. "-" .. realm] = {
					name = name, realm = realm, raid = raid,
					guid = ns.Clean(UnitGUID(unit)),
					class = ns.Clean((select(2, UnitClass(unit)))),
					level = level and level > 0 and level or nil,
				}
			end
		end
	end
	return members, complete
end

local function Player(key, m)
	local player = ns.db.players[key]
	if not player then
		player = { key = key, name = m.name, realm = m.realm, count = 0, time = 0, kills = 0, groups = {} }
		ns.db.players[key] = player
	end
	player.class = m.class or player.class
	player.level = m.level or player.level
	if m.guid then
		player.guid = m.guid
		ns.byGUID[m.guid] = player
	end
	return player
end

local function Start(key, m, now)
	local player = Player(key, m)
	player.count = player.count + 1
	player.first = player.first or now
	player.last = now
	player.groups[#player.groups + 1] = Pack({ start = now, seconds = 0, place = PlaceIndex(), kills = 0,
		level = m.level, raid = m.raid })
	ns.db.open[key] = { start = now, seen = now, kills = 0 }
	ns.db.total = ns.db.total + 1
end

-- Ends the group with a player at time `at`.
local function Stop(key, at)
	local open, player = ns.db.open[key], ns.db.players[key]
	ns.db.open[key] = nil
	if not (open and player and player.groups[1]) then
		return
	end
	local g = ns.UnpackGroup(player.groups[#player.groups])
	g.seconds, g.kills = math.max(at - open.start, 0), open.kills
	player.groups[#player.groups] = Pack(g)
	player.time = player.time + g.seconds
	player.kills = player.kills + g.kills
	player.last = math.max(player.last or 0, at)
end

local live = {}       -- "Name-Realm" -> true for open groups seen in the roster since login
local settled = false -- the roster is known: it changed, or SETTLE seconds passed since login

function ns.Scan()
	if not ns.db then
		return
	end
	local now = time()
	local members, complete = Roster()
	for key, m in pairs(members) do
		local open = ns.db.open[key]
		if open and not live[key] and now - open.seen > RESUME then
			Stop(key, open.seen) -- grouped again after a long time offline: a new group
			open = nil
		end
		if open then
			Player(key, m)
			open.seen = now
		else
			Start(key, m, now)
		end
		live[key] = true
	end
	if complete and settled then
		for key, open in pairs(ns.db.open) do
			if not members[key] then
				-- Gone while you were offline: it ended when you logged out.
				Stop(key, live[key] and now or open.seen)
				live[key] = nil
			end
		end
	end
	ns.version = ns.version + 1
end

ns.On("PLAYER_LOGIN", function()
	Init()
	ns.Scan()
	C_Timer.After(SETTLE, function()
		settled = true
		ns.Scan()
	end)
end)
ns.On("GROUP_ROSTER_UPDATE", function()
	settled = true
	ns.Scan()
end)

ns.On("PLAYER_LOGOUT", function()
	if not ns.db then
		return
	end
	local now = time()
	for _, open in pairs(ns.db.open) do
		open.seen = now
	end
end)

--------------------------------------------------------------------------------
-- Kills together
--------------------------------------------------------------------------------

local seen, seenCount = {}, 0

-- A killing blow by you, your pet or a party member while grouped.
ns.On("PARTY_KILL", function(_, targetGUID)
	if not ns.db or not next(ns.db.open) then
		return
	end
	local guid = ns.Clean(targetGUID)
	if guid then
		if seen[guid] then
			return
		end
		if seenCount >= SEEN_KILLS then
			seen, seenCount = {}, 0
		end
		seen[guid], seenCount = true, seenCount + 1
		if strsplit("-", guid) == "Pet" then
			return
		end
	end
	for _, open in pairs(ns.db.open) do
		open.kills = open.kills + 1
	end
	ns.version = ns.version + 1
end)
