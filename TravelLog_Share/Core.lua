-- TravelLog Share core: who may ask for your data, whose nodes you follow,
-- what other players sent you, a record of every request you got, and a
-- paced queue for the addon whispers. Needs TravelLog.
local _, ns = ...
local tl = TravelLog

ns.PREFIX = "TravelLogShare"
ns.MAX_LENGTH = 255      -- bytes per addon message
local PER_SECOND = 3     -- messages sent per second; the server throttles bursts
local MAX_REQUESTS = 200 -- request records kept, oldest dropped first
local NOT_FOUND_WINDOW = 10 -- seconds a "No player named" reply is matched to our whisper

C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogShareDB = {
--   allowed = { ["bob-forever"] = "Bob-Forever" },   -- may ask for your nodes and log
--   follow = { ["ann-forever"] = "Ann-Forever" },    -- whose nodes you get automatically
--   requests = {   -- oldest first
--     { time = 1760000000, from = "Bob-Forever", to = "Rasmus-Forever", what = "log", count = 20, allowed = true },
--   },
--   peers = {   -- what others sent you
--     ["ann-forever"] = { name = "Ann-Forever", nodesSince = 1760000000,
--       nodes = { [1429] = { [3] = { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3,
--                                   last = 1760000000, count = 8 } } },
--       log = { received = 1760000000, entries = { { time = ..., where = "Goldshire (42.1, 65.3)", text = "..." } } } },
--   },
-- }
-- Keys are lowercase "name-realm"; the values keep the name as shown. A
-- peer's nodes are keyed by map and by their place in that player's list.

tl.On("PLAYER_LOGIN", function()
	TravelLogShareDB = TravelLogShareDB or {}
	local db = TravelLogShareDB
	db.allowed = db.allowed or {}
	db.follow = db.follow or {}
	db.requests = db.requests or {}
	db.peers = db.peers or {}
	ns.db = db
	ns.me = select(2, ns.Name(UnitName("player")))
end)

-- Wiping a character drops the requests it got.
tl.On("TL_WIPE", function()
	local keep = {}
	for _, r in ipairs(ns.db.requests) do
		if r.to ~= tl.charKey then
			keep[#keep + 1] = r
		end
	end
	ns.db.requests = keep
	ns.Changed()
end)

-- "bob", "Bob-Forever" -> "Bob-Forever", "bob-forever": a character name as
-- shown, and as a key. Without a realm, it's yours.
function ns.Name(text)
	local name, realm = (text or ""):match("^%s*([^%s%-]+)%-?(%S*)%s*$")
	if not name then
		return
	end
	if realm == "" then
		realm = GetNormalizedRealmName()
	end
	local full = name:sub(1, 1):upper() .. name:sub(2):lower() .. "-" .. realm
	return full, full:lower()
end

-- What another player sent you, by key.
function ns.Peer(key, name)
	local peer = ns.db.peers[key]
	if not peer then
		peer = { name = name, nodes = {} }
		ns.db.peers[key] = peer
	end
	peer.name = name or peer.name
	return peer
end

-- Goes up whenever anything the Sharing tab shows changes.
ns.version = 0
function ns.Changed()
	ns.version = ns.version + 1
end

-- Notes a request someone sent you.
function ns.Record(from, what, allowed, count)
	local list = ns.db.requests
	list[#list + 1] = { time = time(), from = from, to = tl.charKey, what = what, count = count, allowed = allowed }
	if #list > MAX_REQUESTS then
		table.remove(list, 1)
	end
	ns.Changed()
end

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

-- Players who asked for your nodes this session, by key, and get new ones
-- as you loot them.
ns.listeners = {}

local queue, budget = {}, PER_SECOND
local whispered = {} -- key -> GetTime() of our last whisper to them
local R = Enum.SendAddonMessageResult or {}

-- Everything still queued for someone who turned out to be offline is
-- dropped, and they stop getting new nodes.
function ns.Offline(key)
	local keep = {}
	for _, m in ipairs(queue) do
		if m.key ~= key then
			keep[#keep + 1] = m
		end
	end
	queue = keep
	ns.listeners[key] = nil
end

local function Drain()
	while budget > 0 and queue[1] do
		local m = queue[1]
		local result = C_ChatInfo.SendAddonMessage(ns.PREFIX, m.text, "WHISPER", m.target)
		if result == R.AddonMessageThrottle or result == R.ChannelThrottle or result == R.AddOnMessageLockdown then
			budget = 0 -- try again next second
			return
		end
		table.remove(queue, 1)
		budget = budget - 1
		whispered[m.key] = GetTime()
		if result == R.TargetOffline then
			ns.Offline(m.key)
		end
	end
end

-- Whispers a message to another player's TravelLog Share, a few a second.
function ns.Send(target, text)
	queue[#queue + 1] = { target = target, key = select(2, ns.Name(target)), text = text }
	Drain()
end

C_Timer.NewTicker(1, function()
	budget = PER_SECOND
	Drain()
end)

-- Whispering someone offline gets "No player named 'Bob' is currently
-- playing." Those replies to our own whispers are hidden from chat.
local NOT_FOUND = ERR_CHAT_PLAYER_NOT_FOUND_S
	and "^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.+)") .. "$"

local function NotFound(text)
	text = tl.Clean(text)
	local name = NOT_FOUND and type(text) == "string" and text:match(NOT_FOUND)
	local key = name and select(2, ns.Name(name))
	if key and whispered[key] and GetTime() - whispered[key] <= NOT_FOUND_WINDOW then
		return key
	end
end

tl.On("CHAT_MSG_SYSTEM", function(text)
	local key = NotFound(text)
	if key then
		ns.Offline(key)
	end
end)

if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
	ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
		return NotFound(text) ~= nil
	end)
end
