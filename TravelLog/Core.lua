-- TravelLog core: saved data, sessions, event plumbing and shared helpers.
local _, ns = ...

-- The companion addons (TravelLog_Path, TravelLog_Nodes) load after this one
-- and use its helpers, events and saved data through this global.
TravelLog = ns

-- Bumped whenever something is recorded, so the map knows when to redraw.
ns.version = 0

-- Settings in the account-wide file. Companion addons add their own with
-- ns.Defaults while loading.
local DEFAULTS = {}

function ns.Defaults(t)
	for key, value in pairs(t) do
		DEFAULTS[key] = value
	end
end

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

-- "3d 4h", "2h 13m", "5m": a number of seconds as text.
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

-- How long before `now` (default: the current time) an epoch time was.
function ns.Ago(t, now)
	return ns.Duration((now or time()) - t)
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

-- Whether a name from a chat line ("Name" or "Name-Realm") is yours.
function ns.IsMe(name)
	return name:match("^[^%-]+") == UnitName("player")
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

-- Movement state bits, stored with every path point and jump. The shapeshift
-- form ID goes in the bits above them, as form * FORM_BIT; ns.HasFlag ignores it.
ns.FLAGS = { mounted = 1, taxi = 2, swimming = 4, dead = 8, combat = 16, indoors = 32, stealth = 64 }
ns.FORM_BIT = 128

function ns.HasFlag(flags, bit)
	return flags % (bit * 2) >= bit
end

function ns.FormOf(flags)
	return math.floor(flags / ns.FORM_BIT)
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
	h.stealth = ns.Clean(IsStealthed()) and true or false
	local form = ns.Clean(GetShapeshiftFormID())
	h.form = type(form) == "number" and form > 0 and math.floor(form) or 0
	local flags = h.form * ns.FORM_BIT
	for name, bit in pairs(ns.FLAGS) do
		if h[name] then
			flags = flags + bit
		end
	end
	h.flags = flags
	return h
end

--------------------------------------------------------------------------------
-- The event log
--------------------------------------------------------------------------------

-- Stamps t with where you are: zone, subzone (when it differs), map and the
-- map coordinates x and y in percent. A suffix goes on each field name, as in
-- zoneEnd.
function ns.StampPlace(t, suffix)
	suffix = suffix or ""
	local zone = ns.Clean(GetRealZoneText())
	zone = zone ~= "" and zone or nil
	local subzone = ns.Clean(GetSubZoneText())
	local map, x, y = ns.MapPosition()
	t["zone" .. suffix] = zone
	t["subzone" .. suffix] = subzone ~= "" and subzone ~= zone and subzone or nil
	t["map" .. suffix] = map
	t["x" .. suffix] = x and ns.Round(x * 100, 2)
	t["y" .. suffix] = y and ns.Round(y * 100, 2)
	return t
end

-- A new log entry stamped with the current time and place, not yet saved.
function ns.NewEvent(kind, data)
	local e = data or {}
	e.type = kind
	e.time = time()
	return ns.StampPlace(e)
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
	TradePartner = "trade", Auctioneer = "auction", Banker = "bank", GuildBanker = "guildbank",
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
	GUILDBANKFRAME_OPENED = { "guildbank", true }, GUILDBANKFRAME_CLOSED = { "guildbank", false },
	BARBER_SHOP_OPEN = { "barber", true }, BARBER_SHOP_CLOSE = { "barber", false },
}
for event, change in pairs(WINDOW_EVENTS) do
	ns.On(event, function()
		SetOpen(change[1], change[2])
	end)
end

-- Who's on the other side: the trade partner, the sender of the mail you
-- last took money or an item from, and who you last sent mail to.
local partner, sender, recipient

ns.On("TL_OPEN", function(context)
	if context == "trade" then
		local name, realm = UnitName("npc")
		name, realm = ns.Clean(name), ns.Clean(realm)
		partner = name and realm and realm ~= "" and name .. "-" .. realm or name
	end
end)

local function TookMail(index)
	sender = ns.Clean((select(3, GetInboxHeaderInfo(index))))
end
hooksecurefunc("TakeInboxMoney", TookMail)
hooksecurefunc("TakeInboxItem", TookMail)
hooksecurefunc("AutoLootMailItem", TookMail)

hooksecurefunc("SendMail", function(to)
	recipient = ns.Clean(to)
	ns.Mark("mailsent")
end)

-- Adds the partner, sender or recipient to an event's data for money or
-- items that came or went by trade or mail. Money paid right after sending
-- mail is its postage, or money sent with it; COD is paid to the sender.
function ns.WithCounterpart(data, how)
	if how == "trade" then
		data.partner = partner
	elseif how == "mail" and (data.amount or 0) < 0 and ns.Recent("mailsent", 10) then
		data.recipient = recipient
	elseif how == "mail" or how == "cod" then
		data.sender = sender
	end
	return data
end

--------------------------------------------------------------------------------
-- Data versions
--------------------------------------------------------------------------------

-- The layout of TravelLog's files, saved in each as `version`: a new file
-- gets this one. Bump it when older TravelLogs would misread what the new one
-- writes (new fields they ignore don't need it), then list the old version
-- in COMPATIBLE or add a CONVERT step for it.
ns.DATA_VERSION = 1

-- Versions this TravelLog reads and writes as they are.
local COMPATIBLE = { [1] = true }

-- CONVERT[n].account(db) and CONVERT[n].char(char) rewrite a version n file
-- as version n + 1; a step leaves out a file it doesn't change. None yet.
local CONVERT = {}

-- Brings the account ("account") or a character ("char") file to
-- DATA_VERSION. Returns false, leaving the file as it is, when this
-- TravelLog can't read its version (a newer one's).
local function Upgrade(t, file)
	local version = t.version or ns.DATA_VERSION -- a new file
	local step = version
	while not COMPATIBLE[step] do
		if type(step) ~= "number" or not CONVERT[step] then
			return false
		end
		step = step + 1
	end
	while not COMPATIBLE[version] do
		if CONVERT[version][file] then
			CONVERT[version][file](t)
		end
		version = version + 1
	end
	t.version = ns.DATA_VERSION
	return true
end

-- Says that a file can't be read, and keeps saying it on /tl and the addons
-- dropdown. Nothing is recorded, so the file is saved back untouched.
local function Unreadable(what, t)
	ns.unreadable = ("%s is data version %s, which this TravelLog (data version %d) can't read. Update TravelLog: until then nothing is recorded and the file is kept as it is.")
		:format(what, tostring(t.version), ns.DATA_VERSION)
	ns.Print(ns.unreadable)
end

--------------------------------------------------------------------------------
-- Startup and sessions
--------------------------------------------------------------------------------

local function EndSession()
	local s = ns.session
	s.stop = time()
	s.levelEnd = UnitLevel("player")
	s.moneyEnd = GetMoney()
	ns.StampPlace(s, "End")
end

local function Init()
	TravelLogDB = TravelLogDB or {}
	local db = TravelLogDB
	if not Upgrade(db, "account") then
		return Unreadable("TravelLog's account file", db)
	end
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
	-- so playing one character never loads another's history.
	TravelLogCharDB = TravelLogCharDB or {}
	local char = TravelLogCharDB
	if not Upgrade(char, "char") then
		return Unreadable("This character's log", char)
	end
	char.log = char.log or {}
	char.sessions = char.sessions or {}
	char.quests = char.quests or {}

	local session = {
		start = time(),
		level = profile.level,
		money = GetMoney(),
	}
	ns.StampPlace(session)
	char.sessions[#char.sessions + 1] = session

	ns.db, ns.settings, ns.charKey = db, db.settings, key
	ns.profile, ns.stats, ns.char = profile, profile.stats, char
	ns.session = session

	-- Registered now, after every module's (and companion addon's) own logout
	-- handler, so the session closes after they've saved their data.
	ns.On("PLAYER_LOGOUT", EndSession)
	-- The zone can still be unknown at login; it is by the first loading screen.
	ns.On("PLAYER_ENTERING_WORLD", function()
		if not session.zone then
			ns.StampPlace(session)
		end
	end)
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
