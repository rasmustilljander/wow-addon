-- TravelLog Kills core: notices kills and records each one per mob, with
-- when and where it happened.
--
-- Addons can't read the combat log on this client, so kills come from two
-- other places:
--   PARTY_KILL                  you, your pet or a party member landed the
--                               killing blow; names the mob by GUID
--   "X dies, you gain N         the kill gave you experience; names the mob
--    experience." (chat)        and the XP, but not which one it was
-- A kill usually produces both. Each one waits a moment for its other half
-- and is then saved once.
local _, ns = ...

local PAIR_WINDOW = 2 -- seconds a kill waits for its other half
local NAME_CACHE = 500 -- GUIDs remembered from targets, mouseover and nameplates

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

function ns.Round(value, places)
	local m = 10 ^ (places or 0)
	return math.floor(value * m + 0.5) / m
end

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffe57373TravelLog Kills|r " .. text)
end

-- "3d 4h", "2h 13m", "5m": how long before `now` (default: the current
-- time) an epoch time was.
function ns.Ago(t, now)
	local s = math.max((now or time()) - t, 0)
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

-- Splits a GUID like "Creature-0-1-2-3-299-4" into its type and NPC ID.
function ns.ParseGUID(guid)
	guid = ns.Clean(guid)
	if not guid then
		return
	end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return kind, tonumber(id)
end

-- Turns a localized format like "%s dies, you gain %d experience" into a Lua
-- pattern. Left open-ended so rested and group bonus variants match too.
local function ToPattern(format)
	local pattern = format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
	pattern = pattern:gsub("%%%%%d%%%$s", "(.+)"):gsub("%%%%%d%%%$d", "(%%d+)")
	pattern = pattern:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
	return "^" .. pattern
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

-- TravelLogKillsDB = {
--   total = 1234,
--   settings = { map = true, mapFilter = "Kobold Worker" },
--   places = { "Elwynn Forest|Goldshire", "Westfall", ... },
--   mobs = {
--     ["Defias Thug"] = { name = "Defias Thug", ids = { 38 }, count = 54,
--       first = 1760000000, last = 1760100000,
--       kills = { "1760000000,1436,52.10,51.04,2,45", ... } },  -- oldest first
--   },
-- }
-- Each kill: time, uiMapID, x, y (0-100), place (index into places), XP,
-- and who landed the killing blow when it wasn't you or your pet.

local placeIndex = {} -- "Zone|Subzone" -> index into db.places
ns.byID = {}          -- NPC ID -> mob

local function Init()
	TravelLogKillsDB = TravelLogKillsDB or {}
	local db = TravelLogKillsDB
	db.version = 1
	db.total = db.total or 0
	db.places = db.places or {}
	db.mobs = db.mobs or {}
	db.settings = db.settings or {}
	if db.settings.map == nil then
		db.settings.map = true -- kill spots on the world map
	end
	ns.db = db
	for i, place in ipairs(db.places) do
		placeIndex[place] = i
	end
	for _, mob in pairs(db.mobs) do
		for _, id in ipairs(mob.ids or {}) do
			ns.byID[id] = mob
		end
	end
end

local function PlaceIndex(zone, subzone)
	if not zone then
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

-- Reverses the packed kill record into a table.
function ns.UnpackKill(rec)
	local t, map, x, y, place, xp, by = strsplit(",", rec)
	x, y = tonumber(x), tonumber(y)
	local zone, subzone = ns.Place(tonumber(place))
	return {
		time = tonumber(t), map = tonumber(map), x = x, y = y, zone = zone, subzone = subzone,
		xp = tonumber(xp), by = by ~= "" and by or nil,
	}
end

-- The mob saved under this exact name, or the one with this NPC ID.
function ns.Mob(name, id)
	return (name and ns.db.mobs[name]) or (id and ns.byID[id])
end

--------------------------------------------------------------------------------
-- Where am I?
--------------------------------------------------------------------------------

local function Where()
	local w = { time = time() }
	w.zone = ns.Clean(GetRealZoneText())
	w.subzone = ns.Clean(GetSubZoneText())
	local map = ns.Clean(C_Map.GetBestMapForUnit("player"))
	w.map = map
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	if pos then
		local x, y = ns.Clean(pos.x), ns.Clean(pos.y)
		if x and y and not (x == 0 and y == 0) then
			w.x, w.y = x * 100, y * 100
		end
	end
	return w
end

local function Fixed(value)
	return value and ("%.2f"):format(value) or ""
end

--------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------

-- UnitNameFromGUID only knows units the client has around, so names seen on
-- targets, mouseover and nameplates are remembered for a while too.
local names, nameCount = {}, 0

local function Remember(unit)
	local guid, name = ns.Clean(UnitGUID(unit)), ns.Clean(UnitName(unit))
	if guid and name and not names[guid] then
		if nameCount >= NAME_CACHE then
			names, nameCount = {}, 0
		end
		names[guid], nameCount = name, nameCount + 1
	end
end

ns.On("PLAYER_TARGET_CHANGED", function() Remember("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() Remember("mouseover") end)
ns.On("NAME_PLATE_UNIT_ADDED", function(unit) Remember(unit) end)

local function NameOf(guid)
	if not guid then
		return nil
	end
	local name = UnitNameFromGUID and ns.Clean(UnitNameFromGUID(guid))
	if name and name ~= "" then
		return name
	end
	return names[guid]
end

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------

local pending = {} -- kills waiting for their other half, oldest first

local function Save(k)
	local id = k.id
	local name = k.name or (id and ns.byID[id] and ns.byID[id].name)
	if not name and not id then
		return -- nothing to tell this kill apart by
	end
	local key = name or ("NPC #" .. id)
	local mobs = ns.db.mobs
	local mob = mobs[key]
	if not mob then
		mob = { name = key, count = 0, kills = {} }
		mobs[key] = mob
	end
	if id then
		mob.ids = mob.ids or {}
		local known = false
		for _, have in ipairs(mob.ids) do
			known = known or have == id
		end
		if not known then
			mob.ids[#mob.ids + 1] = id
		end
		ns.byID[id] = mob
	end
	if k.kind == "Player" then
		mob.player = true
	end

	local w = k.where
	local rec = ("%d,%s,%s,%s,%s,%s,%s"):format(w.time, w.map or "", Fixed(w.x), Fixed(w.y),
		PlaceIndex(w.zone, w.subzone) or "", k.xp or "", (k.by or ""):gsub(",", " "))
	mob.kills[#mob.kills + 1] = (rec:gsub(",+$", ""))
	mob.count = mob.count + 1
	mob.first = mob.first or w.time
	mob.last = w.time
	ns.db.total = ns.db.total + 1
	ns.MapAdd(key, w)
end

-- Saves the kills that have both halves, or have waited long enough (all of
-- them when `all` is set).
local function Flush(all)
	local now, keep = GetTime(), {}
	for _, k in ipairs(pending) do
		if all or (k.fromKill and k.fromXP) or now - k.at >= PAIR_WINDOW then
			Save(k)
		else
			keep[#keep + 1] = k
		end
	end
	pending = keep
end

local function Add(k)
	k.at, k.where = GetTime(), Where()
	pending[#pending + 1] = k
	C_Timer.After(PAIR_WINDOW, function() Flush() end)
end

-- The oldest waiting kill that still lacks `half` and could be this mob: the
-- same name, or a name not known yet.
local function Match(half, name)
	local fallback
	for _, k in ipairs(pending) do
		if not k[half] then
			if name and k.name == name then
				return k
			elseif not fallback and (not name or not k.name) then
				fallback = k
			end
		end
	end
	return fallback
end

local seen, seenCount = {}, 0 -- GUIDs already counted, in case of repeats

ns.On("PARTY_KILL", function(attackerGUID, targetGUID)
	local guid, attacker = ns.Clean(targetGUID), ns.Clean(attackerGUID)
	if guid then
		if seen[guid] then
			return
		end
		if seenCount >= NAME_CACHE then
			seen, seenCount = {}, 0
		end
		seen[guid], seenCount = true, seenCount + 1
	end
	local kind, id = ns.ParseGUID(guid)
	if kind == "Pet" then
		return
	end
	local by
	if attacker and attacker ~= ns.Clean(UnitGUID("player")) and attacker ~= ns.Clean(UnitGUID("pet")) then
		by = NameOf(attacker)
	end
	local name = NameOf(guid)
	local k = Match("fromKill", name)
	if k then
		k.name = k.name or name
	else
		k = { name = name }
		Add(k)
	end
	k.fromKill, k.kind, k.id, k.by = true, kind, id, by
	Flush()
end)

local xpPattern = type(COMBATLOG_XPGAIN_FIRSTPERSON) == "string"
	and ToPattern(COMBATLOG_XPGAIN_FIRSTPERSON:gsub("%.$", ""))

ns.On("CHAT_MSG_COMBAT_XP_GAIN", function(text)
	text = ns.Clean(text)
	local name, xp
	if xpPattern and text then
		name, xp = text:match(xpPattern)
	end
	if not name then
		return
	end
	local k = Match("fromXP", name)
	if k then
		k.name = name
	else
		k = { name = name }
		Add(k)
	end
	k.fromXP, k.xp = true, tonumber(xp)
	Flush()
end)

ns.On("PLAYER_LOGIN", Init)
ns.On("PLAYER_LOGOUT", function() Flush(true) end)
