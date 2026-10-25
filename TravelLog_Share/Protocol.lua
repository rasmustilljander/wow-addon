-- What TravelLog Share whispers. Every message is an addon whisper with the
-- prefix "TravelLogShare", which chat doesn't show:
--
--   HELLO                 I'm online (sent at login and when you add a friend)
--   NODES <since>         send me your nodes looted after <since> (epoch)
--   STATS                 send me your totals (Stats.lua)
--   NO                    you aren't my friend
--   N <node>;<node>...    nodes: map,index,kind,x,y,last,count,objectID,name
--   NEND <n>              that was all n nodes
--   SB, S, SE             totals (Stats.lua)
--
-- Only friends get your data, and you take only theirs. Data moves once
-- both players have added each other.
local _, ns = ...
local tl = TravelLog

local LOGIN_DELAY = 10 -- seconds after login before saying hello
local REFUSE_EVERY = 60 -- seconds between "NO" replies to the same player
local NAME_LENGTH = 60

local KIND_CODES = { herb = "h", ore = "o", chest = "c", object = "x" }
local KINDS = {}
for kind, code in pairs(KIND_CODES) do
	KINDS[code] = kind
end

local function Strip(text, length)
	return (tostring(text or ""):gsub("[,;]", " "):sub(1, length))
end

--------------------------------------------------------------------------------
-- Sharing yours
--------------------------------------------------------------------------------

-- How many times all your characters together looted the node.
local function Total(node)
	local n = 0
	for _, count in pairs(node.counts) do
		n = n + count
	end
	return n
end

local function NodeRecord(map, index, node)
	return ("%d,%d,%s,%.1f,%.1f,%d,%d,%s,%s"):format(map, index, KIND_CODES[node.kind] or "x", node.x, node.y,
		node.last, Total(node), node.id or "", Strip(node.name, NAME_LENGTH))
end

-- Sends "<head> rec;rec;..." in as few messages as fit.
local function SendPacked(target, head, records)
	local text
	for _, rec in ipairs(records) do
		if text and #text + 1 + #rec > ns.MAX_LENGTH then
			ns.Send(target, text)
			text = nil
		end
		text = text and text .. ";" .. rec or head .. " " .. rec
	end
	if text then
		ns.Send(target, text)
	end
end

local function SendNodes(target, since)
	local records = {}
	for map, list in pairs(TravelLogNodesAccountDB and TravelLogNodesAccountDB.maps or {}) do
		for i, node in ipairs(list) do
			if node.last and node.last > since then
				records[#records + 1] = NodeRecord(map, i, node)
			end
		end
	end
	SendPacked(target, "N", records)
	ns.Send(target, "NEND " .. #records)
end

local refused = {} -- key -> GetTime() of the last NO sent there

-- Whether a request comes from a friend. Others are told no, but not often,
-- so nobody can make you spam whispers.
function ns.FromFriend(sender, key)
	if ns.db.friends[key] then
		return true
	end
	if not refused[key] or GetTime() - refused[key] >= REFUSE_EVERY then
		refused[key] = GetTime()
		ns.Send(sender, "NO")
		tl.Print("%s wants to share TravelLog data but isn't your friend (/tl share to add them).", sender)
	end
	return false
end

ns.handlers = {}
local handlers = ns.handlers

handlers.NODES = function(sender, key, arg)
	if ns.FromFriend(sender, key) then
		ns.listeners[key] = sender
		SendNodes(sender, tonumber(arg) or 0)
	end
end

-- Nodes you loot go straight to friends who asked for them this session.
tl.On("TL_NODE", function(map, index, node)
	local rec = NodeRecord(map, index, node)
	for key, name in pairs(ns.listeners) do
		if ns.db.friends[key] then
			ns.Send(name, "N " .. rec)
		end
	end
end)

--------------------------------------------------------------------------------
-- Getting theirs
--------------------------------------------------------------------------------

-- This session only, by key:
ns.waiting = {} -- friends who said they haven't added you
local nodeBatches = {} -- key -> highest timestamp in the requested batch

local function RequestNodes(key)
	local peer = ns.db.peers[key]
	local since = peer and peer.nodesSince or 0
	-- Timestamps have one-second resolution, so include the watermark second;
	-- records overwrite by map/index and are safe to receive again.
	nodeBatches[key] = since
	ns.Send(ns.db.friends[key], "NODES " .. math.max(since - 1, 0))
end

-- Asks a friend for everything they share.
local function Request(key)
	RequestNodes(key)
	ns.RequestStats(key)
end

-- Adds a friend, says hello and asks for their data.
function ns.AddFriend(name, key)
	ns.db.friends[key] = name
	ns.Changed()
	ns.Send(name, "HELLO")
	Request(key)
end

-- Removes a friend and drops what they sent you.
function ns.RemoveFriend(key)
	local peer = ns.db.peers[key]
	if peer then
		tl.friends[peer.name] = nil
	end
	ns.db.friends[key], ns.db.peers[key] = nil, nil
	ns.listeners[key], ns.statsSent[key], ns.waiting[key] = nil, nil, nil
	nodeBatches[key] = nil
	ns.Changed()
	if tl.NodesChanged then
		tl.NodesChanged()
	end
end

handlers.HELLO = function(_, key)
	if ns.db.friends[key] then
		Request(key)
	end
end

handlers.NO = function(sender, key)
	if ns.db.friends[key] and not ns.waiting[key] then
		ns.waiting[key] = true
		nodeBatches[key] = nil
		ns.Changed()
		tl.Print("%s hasn't added you as a friend yet.", sender)
	end
end

handlers.N = function(sender, key, arg)
	local peer = ns.Peer(key, sender)
	for rec in arg:gmatch("[^;]+") do
		local map, index, kind, x, y, last, count, id, name = strsplit(",", rec, 9)
		map, index, kind, x, y = tonumber(map), tonumber(index), KINDS[kind], tonumber(x), tonumber(y)
		last, count = tonumber(last), tonumber(count)
		if map and index and kind and x and y and last and count then
			peer.nodes[map] = peer.nodes[map] or {}
			peer.nodes[map][index] = { kind = kind, name = name ~= "" and name or nil, id = tonumber(id),
				x = x, y = y, last = last, count = count }
			if nodeBatches[key] then
				nodeBatches[key] = math.max(nodeBatches[key], last)
			else
				peer.nodesSince = math.max(peer.nodesSince or 0, last)
			end
		end
	end
	ns.Changed()
	if tl.NodesChanged then
		tl.NodesChanged()
	end
end

handlers.NEND = function(sender, key, arg)
	local n = tonumber(arg)
	if n then
		local newest = nodeBatches[key]
		if newest then
			ns.Peer(key, sender).nodesSince = newest
			nodeBatches[key] = nil
			ns.Changed()
		end
		if n > 0 then
			tl.Print("got %d new or updated nodes from %s.", n, sender)
		end
	end
end

-- Requests are answered for friends only; what a friend sends is taken
-- only from friends.
local REQUESTS = { NODES = true, STATS = true }

tl.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	prefix, text, channel, sender = tl.Clean(prefix), tl.Clean(text), tl.Clean(channel), tl.Clean(sender)
	if prefix ~= ns.PREFIX or channel ~= "WHISPER" or not text or not sender then
		return
	end
	local name, key = ns.Name(sender)
	if not key or key == ns.me then
		return
	end
	local command, arg = text:match("^(%S+) ?(.*)$")
	local handler = handlers[command]
	if not handler or not (REQUESTS[command] or ns.db.friends[key]) then
		return
	end
	if ns.db.friends[key] then
		-- Keep the name as the game spells it.
		ns.db.friends[key] = name
		ns.Peer(key, name).seen = time()
		if command ~= "NO" then
			ns.waiting[key] = nil
		end
		ns.Changed()
	end
	handler(name, key, arg)
end)

--------------------------------------------------------------------------------
-- Login, and friends' nodes on the map
--------------------------------------------------------------------------------

tl.On("PLAYER_LOGIN", function()
	C_Timer.After(LOGIN_DELAY, function()
		for key, name in pairs(ns.db.friends) do
			ns.Send(name, "HELLO")
			Request(key)
		end
	end)
	-- TravelLog_Nodes draws them, when it's installed.
	if tl.AddNodeSource then
		tl.AddNodeSource(function(map, add)
			for _, peer in pairs(ns.db.peers) do
				for _, node in pairs(peer.nodes[map] or {}) do
					add(node, peer.name)
				end
			end
		end)
	end
end)
