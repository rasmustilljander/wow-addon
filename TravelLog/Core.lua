-- TravelLog core: saved data, sessions, event plumbing and shared helpers.
local _, ns = ...

-- Bumped whenever something is recorded, so the map knows when to redraw.
ns.version = 0
ns.nodesVersion = 0

local DEFAULTS = {
	interval = 2,     -- seconds between recorded path points while moving (1-5)
	trail = "today",  -- what the world map overlay shows: session/today/week/all/off
	nodes = true,     -- show looted chests, herbs and ore on the world map
}

-- Path points and jumps are packed this many records per string, which keeps
-- the SavedVariables file small and quick to load.
local CHUNK_SIZE = 200

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Forever runs on the Midnight-era client, which hands addons unreadable
-- "secret" values in some situations (chat inside dungeons, unit names in
-- combat, ...). We can't use those, so treat them as missing.
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
	print("|cff4fc3f7TravelLog|r " .. text)
end

function ns.MoneyText(copper)
	copper = copper or 0
	local sign = copper < 0 and "-" or ""
	copper = math.abs(copper)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if g > 0 then
		return ("%s%dg %ds %dc"):format(sign, g, s, c)
	elseif s > 0 then
		return ("%s%ds %dc"):format(sign, s, c)
	end
	return ("%s%dc"):format(sign, c)
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

-- Splits a GUID like "Creature-0-1-2-3-299-4" into its type and entry ID.
function ns.ParseGUID(guid)
	guid = ns.Clean(guid)
	if not guid then
		return
	end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return kind, tonumber(id)
end

-- Adds n to a (possibly nested) counter in this character's stats, e.g.
-- ns.Add(1, "jumps") or ns.Add(12.5, "distance", "mount").
function ns.Add(n, ...)
	local t = ns.stats
	local depth = select("#", ...)
	for i = 1, depth - 1 do
		local key = select(i, ...)
		t[key] = t[key] or {}
		t = t[key]
	end
	local key = select(depth, ...)
	t[key] = (t[key] or 0) + n
end

-- Remembers when something happened, for "did X just happen?" checks.
local marks = {}
function ns.Mark(what)
	marks[what] = GetTime()
end

function ns.Recent(what, seconds)
	local t = marks[what]
	return t ~= nil and GetTime() - t <= seconds
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

-- Calls fn for a game event, or for one of our own "TL_*" messages sent with
-- ns.Fire. Returns false if the client doesn't know the event.
function ns.On(event, fn)
	local list = handlers[event]
	if not list then
		if not event:find("^TL_") and not pcall(frame.RegisterEvent, frame, event) then
			return false
		end
		list = {}
		handlers[event] = list
	end
	list[#list + 1] = fn
	return true
end

-- Runs every handler for an event. One failing recorder must not stop the
-- others, so errors are reported without interrupting the loop.
function ns.Fire(event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

--------------------------------------------------------------------------------
-- Where am I?
--------------------------------------------------------------------------------

-- uiMapID and 0-1 map coordinates. The coordinates are nil inside instances,
-- where the client doesn't reveal positions.
function ns.MapPosition()
	local mapID = ns.Clean(C_Map.GetBestMapForUnit("player"))
	if not mapID then
		return
	end
	local pos = C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then
		return mapID
	end
	local x, y = ns.Clean(pos.x), ns.Clean(pos.y)
	if not x or not y or (x == 0 and y == 0) then
		return mapID
	end
	return mapID, x, y
end

-- Instance (continent) ID and the two UnitPosition() axes, in yards.
function ns.WorldPosition()
	local a, b, _, instanceID = UnitPosition("player")
	a, b, instanceID = ns.Clean(a), ns.Clean(b), ns.Clean(instanceID)
	if not a or not b or not instanceID then
		return
	end
	return instanceID, a, b
end

-- Movement state bits stored with every path point and jump.
ns.FLAGS = { mounted = 1, taxi = 2, swimming = 4, dead = 8, combat = 16, indoors = 32 }

function ns.HasFlag(flags, bit)
	return flags % (bit * 2) >= bit
end

-- A snapshot of the player's position and state.
function ns.Here()
	local h = { t = time(), now = GetTime() }
	h.map, h.x, h.y = ns.MapPosition()
	h.inst, h.wx, h.wy = ns.WorldPosition()
	h.mounted = IsMounted() and true or false
	h.taxi = UnitOnTaxi("player") and true or false
	h.swimming = IsSwimming() and true or false
	h.dead = UnitIsDeadOrGhost("player") and true or false
	h.combat = ns.Clean(UnitAffectingCombat("player")) and true or false
	h.indoors = IsIndoors() and true or false
	local flags = 0
	for name, bit in pairs(ns.FLAGS) do
		if h[name] then
			flags = flags + bit
		end
	end
	h.flags = flags
	return h
end

local function Fixed(value, fmt)
	return value and fmt:format(value) or ""
end

-- Packs a snapshot into one compact record:
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
	ns.version = ns.version + 1
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

-- Calls fn(record) for every record in stored chunks, then an optional buffer.
function ns.EachRecord(store, buffer, fn)
	for _, chunk in ipairs(store) do
		for rec in chunk:gmatch("[^;]+") do
			fn(rec)
		end
	end
	if buffer then
		for _, rec in ipairs(buffer) do
			fn(rec)
		end
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
-- The event log
--------------------------------------------------------------------------------

-- A new log entry stamped with the current time and place, not yet saved.
function ns.NewEvent(kind, data)
	local e = data or {}
	e.type = kind
	e.time = time()
	e.zone = ns.Clean(GetRealZoneText())
	local subzone = ns.Clean(GetSubZoneText())
	if subzone and subzone ~= "" and subzone ~= e.zone then
		e.subzone = subzone
	end
	local map, x, y = ns.MapPosition()
	e.map = map
	if x then
		e.x, e.y = ns.Round(x * 100, 2), ns.Round(y * 100, 2)
	end
	return e
end

function ns.Save(e)
	ns.version = ns.version + 1
	local log = ns.char.log
	log[#log + 1] = e
	return e
end

function ns.Log(kind, data)
	return ns.Save(ns.NewEvent(kind, data))
end

--------------------------------------------------------------------------------
-- Which NPC window is open? Used to explain loot and money changes.
--------------------------------------------------------------------------------

ns.open = {}

local function SetOpen(context, isOpen)
	isOpen = isOpen or nil
	if ns.open[context] == isOpen then
		return
	end
	ns.open[context] = isOpen
	ns.Fire(isOpen and "TL_OPEN" or "TL_CLOSE", context)
end

local INTERACTIONS = {
	Merchant = "merchant", TaxiNode = "taxi", Trainer = "trainer", MailInfo = "mail",
	TradePartner = "trade", Auctioneer = "auction", Banker = "bank",
}
local contextByType = {}
if Enum and Enum.PlayerInteractionType then
	for name, context in pairs(INTERACTIONS) do
		local id = Enum.PlayerInteractionType[name]
		if id then
			contextByType[id] = context
		end
	end
end

ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
	if contextByType[kind] then SetOpen(contextByType[kind], true) end
end)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
	if contextByType[kind] then SetOpen(contextByType[kind], false) end
end)

-- The older per-window events, in case a window doesn't go through the
-- interaction manager.
local WINDOW_EVENTS = {
	MERCHANT_SHOW = { "merchant", true }, MERCHANT_CLOSED = { "merchant", false },
	TAXIMAP_OPENED = { "taxi", true }, TAXIMAP_CLOSED = { "taxi", false },
	TRAINER_SHOW = { "trainer", true }, TRAINER_CLOSED = { "trainer", false },
	MAIL_SHOW = { "mail", true }, MAIL_CLOSED = { "mail", false },
	TRADE_SHOW = { "trade", true }, TRADE_CLOSED = { "trade", false },
	AUCTION_HOUSE_SHOW = { "auction", true }, AUCTION_HOUSE_CLOSED = { "auction", false },
	BANKFRAME_OPENED = { "bank", true }, BANKFRAME_CLOSED = { "bank", false },
}
for event, change in pairs(WINDOW_EVENTS) do
	ns.On(event, function()
		SetOpen(change[1], change[2])
	end)
end

--------------------------------------------------------------------------------
-- Startup and sessions
--------------------------------------------------------------------------------

local function EndSession()
	local s = ns.session
	s.stop = time()
	s.levelEnd = UnitLevel("player")
	s.moneyEnd = GetMoney()
	ns.track:Flush()
	ns.jumps:Flush()
end

local function Init()
	TravelLogDB = TravelLogDB or {}
	local db = TravelLogDB
	db.settings = db.settings or {}
	for key, value in pairs(DEFAULTS) do
		if db.settings[key] == nil then
			db.settings[key] = value
		end
	end
	db.chars = db.chars or {}

	-- Who each character is and their totals live in the account-wide file.
	local name, realm = UnitName("player"), GetRealmName()
	local key = name .. "-" .. realm
	local profile = db.chars[key] or {}
	db.chars[key] = profile
	profile.name, profile.realm = name, realm
	profile.class = select(2, UnitClass("player"))
	profile.race = select(2, UnitRace("player"))
	profile.faction = UnitFactionGroup("player")
	profile.level = UnitLevel("player")
	profile.stats = profile.stats or {}

	-- Everything the character recorded lives in its own per-character file,
	-- so playing one character never loads another's history. Version 1 kept
	-- it in the account-wide file.
	TravelLogCharDB = TravelLogCharDB or {}
	local char = TravelLogCharDB
	for _, field in ipairs({ "log", "sessions", "quests" }) do
		if profile[field] then
			char[field] = char[field] or profile[field]
			profile[field] = nil
		end
	end
	db.version = 2
	char.log = char.log or {}
	char.sessions = char.sessions or {}
	char.quests = char.quests or {}
	char.nodes = char.nodes or {}

	local session = {
		start = time(),
		level = profile.level,
		money = GetMoney(),
		track = {},
		jumps = {},
	}
	char.sessions[#char.sessions + 1] = session

	ns.db, ns.settings, ns.charKey = db, db.settings, key
	ns.profile, ns.stats, ns.char = profile, profile.stats, char
	ns.session = session
	ns.track = ns.NewStream(session.track)
	ns.jumps = ns.NewStream(session.jumps)

	-- Registered now, after every module's own PLAYER_LOGOUT handler, so the
	-- streams are flushed last.
	ns.On("PLAYER_LOGOUT", EndSession)
end

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" and not ns.char then
		Init()
	end
	if ns.char then
		ns.Fire(event, ...)
	end
end)
frame:RegisterEvent("PLAYER_LOGIN")
