-- TravelLog Share core: your friends, what they sent you and a paced queue
-- for the addon whispers. Needs TravelLog.
local _, ns = ...
local tl = TravelLog

ns.PREFIX = "TravelLogShare"
ns.MAX_LENGTH = 255      -- bytes per addon message
local PER_SECOND = 3     -- messages sent per second; the server throttles bursts
local NOT_FOUND_WINDOW = 10 -- seconds a "No player named" reply is matched to our whisper

C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogShareDB = {
--   friends = { ["bob-forever"] = "Bob-Forever" },   -- you share with each other
--   peers = {   -- what friends sent you
--     ["bob-forever"] = { name = "Bob-Forever", seen = 1760000000, nodesSince = 1760000000,
--       nodes = { [1429] = { [3] = { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3,
--                                   last = 1760000000, count = 8 } } },
--       char = { name = "Bob", realm = "Forever", class = "WARRIOR", race = "Human", level = 12,
--                received = 1760000000, stats = { ... } } },
--   },
-- }
-- Keys are lowercase "name-realm"; the values keep the name as shown. A
-- peer's nodes are keyed by map and by their place in that player's list;
-- char is their TravelLog profile, with stats as in TravelLogDB.chars.

tl.On("PLAYER_LOGIN", function()
	TravelLogShareDB = TravelLogShareDB or {}
	local db = TravelLogShareDB
	db.friends = db.friends or {}
	db.peers = db.peers or {}
	ns.db = db
	ns.me = select(2, ns.Name(UnitName("player")))
	-- Friends' characters show in TravelLog's totals beside yours.
	for _, peer in pairs(db.peers) do
		if peer.char then
			tl.friends[peer.name] = peer.char
		end
	end
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

-- What a friend sent you, by key.
function ns.Peer(key, name)
	local peer = ns.db.peers[key]
	if not peer then
		peer = { name = name, nodes = {} }
		ns.db.peers[key] = peer
	end
	if name and name ~= peer.name and peer.char then
		tl.friends[peer.name], tl.friends[name] = nil, peer.char
	end
	peer.name = name or peer.name
	return peer
end

-- Goes up whenever anything the Friends tab shows changes.
ns.version = 0
function ns.Changed()
	ns.version = ns.version + 1
end

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

-- Friends who asked for your nodes this session, by key, and get new ones
-- as you loot them.
ns.listeners = {}
-- Friends who asked for your totals this session, by key: what they were
-- last sent, so only changes go out after that.
ns.statsSent = {}

local queue, budget = {}, PER_SECOND
local whispered = {} -- key -> GetTime() of our last whisper to them
local R = Enum.SendAddonMessageResult or {}

-- Everything still queued for someone who turned out to be offline is
-- dropped, and they stop getting new nodes and totals.
function ns.Offline(key)
	local keep = {}
	for _, m in ipairs(queue) do
		if m.key ~= key then
			keep[#keep + 1] = m
		end
	end
	queue = keep
	ns.listeners[key], ns.statsSent[key] = nil, nil
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
