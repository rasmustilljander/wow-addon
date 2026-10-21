-- What TravelLog Share whispers. Every message is an addon whisper with the
-- prefix "TravelLogShare":
--
--   HELLO                 I'm online (sent at login to the players you allow)
--   NODES <since>         send me your nodes looted after <since> (epoch)
--   LOG <n>               send me your last n log entries
--   NO <nodes|log>        you aren't allowed
--   N <node>;<node>...    nodes: map,index,kind,x,y,last,count,objectID,name
--   NEND <n>              that was all n nodes
--   LBEGIN <n>, L <time>,<where>;<text>, LEND   a log, oldest first
--
-- Only players on your allow list get your data. Nodes go to them whenever
-- they ask, which their addon does on its own; the log only when they ask
-- for it with /tl share log.
local _, ns = ...
local tl = TravelLog

ns.LOG_DEFAULT, ns.LOG_MAX = 20, 100
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

-- Item links to plain [names], then cut to fit, if a line is too long.
local function Fit(text, room)
	if #text <= room then
		return text
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
	if #text <= room then
		return text
	end
	-- Don't cut a UTF-8 character in half.
	return (text:sub(1, room - 3):gsub("[\192-\255][\128-\191]*$", "")) .. "..."
end

--------------------------------------------------------------------------------
-- Sharing yours
--------------------------------------------------------------------------------

local function NodeRecord(map, index, node)
	return ("%d,%d,%s,%.1f,%.1f,%d,%d,%s,%s"):format(map, index, KIND_CODES[node.kind] or "x", node.x, node.y,
		node.last, node.count, node.id or "", Strip(node.name, NAME_LENGTH))
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
	for map, list in pairs(TravelLogNodesDB and TravelLogNodesDB.maps or {}) do
		for i, node in ipairs(list) do
			if node.last and node.last > since then
				records[#records + 1] = NodeRecord(map, i, node)
			end
		end
	end
	SendPacked(target, "N", records)
	ns.Send(target, "NEND " .. #records)
end

local function SendLog(target, n)
	local log = tl.char.log
	local first = math.max(#log - n + 1, 1)
	ns.Send(target, "LBEGIN " .. (#log - first + 1))
	for i = first, #log do
		local text, where = tl.Describe(log[i])
		local head = ("L %d,%s;"):format(log[i].time, where:gsub(";", " "):sub(1, 80))
		ns.Send(target, head .. Fit(text, ns.MAX_LENGTH - #head))
	end
	ns.Send(target, "LEND")
end

local refused = {} -- key -> GetTime() of the last NO sent there

-- Says no, but not often, so nobody can make you spam whispers.
local function Refuse(sender, key, what)
	if refused[key] and GetTime() - refused[key] < REFUSE_EVERY then
		return false
	end
	refused[key] = GetTime()
	ns.Send(sender, "NO " .. what)
	return true
end

local handlers = {}

handlers.NODES = function(sender, key, arg)
	local allowed = ns.db.allowed[key] ~= nil
	ns.Record(sender, "nodes", allowed)
	if not allowed then
		if Refuse(sender, key, "nodes") then
			tl.Print("%s asked for your nodes but isn't allowed (/tl share allow %s).", sender, sender)
		end
		return
	end
	ns.listeners[key] = sender
	SendNodes(sender, tonumber(arg) or 0)
end

handlers.LOG = function(sender, key, arg)
	local n = math.min(math.max(math.floor(tonumber(arg) or ns.LOG_DEFAULT), 1), ns.LOG_MAX)
	local allowed = ns.db.allowed[key] ~= nil
	ns.Record(sender, "log", allowed, n)
	if not allowed then
		if Refuse(sender, key, "log") then
			tl.Print("%s asked for your log but isn't allowed (/tl share allow %s).", sender, sender)
		end
		return
	end
	tl.Print("%s asked for your log: sending the last %d entries.", sender, n)
	SendLog(sender, n)
end

-- Nodes you loot go straight to whoever asked for them this session.
tl.On("TL_NODE", function(map, index, node)
	local rec = NodeRecord(map, index, node)
	for key, name in pairs(ns.listeners) do
		if ns.db.allowed[key] then
			ns.Send(name, "N " .. rec)
		end
	end
end)

--------------------------------------------------------------------------------
-- Getting theirs
--------------------------------------------------------------------------------

local pending = {}  -- key -> log entries arriving after a /tl share log
local toldNo = {}   -- followed players who said no, told once a session

function ns.RequestNodes(key)
	local peer = ns.db.peers[key]
	ns.Send(ns.db.follow[key], "NODES " .. (peer and peer.nodesSince or 0))
end

function ns.RequestLog(name, key, n)
	pending[key] = { entries = {} }
	ns.Send(name, "LOG " .. n)
end

handlers.HELLO = function(_, key)
	if ns.db.follow[key] then
		ns.RequestNodes(key)
	end
end

handlers.NO = function(sender, key, what)
	if what == "log" and pending[key] then
		pending[key] = nil
		tl.Print("%s hasn't allowed you to see their log.", sender)
	elseif what == "nodes" and ns.db.follow[key] and not toldNo[key] then
		toldNo[key] = true
		tl.Print("%s doesn't share their nodes with you.", sender)
	end
end

handlers.N = function(sender, key, arg)
	if not ns.db.follow[key] then
		return
	end
	local peer = ns.Peer(key, sender)
	for rec in arg:gmatch("[^;]+") do
		local map, index, kind, x, y, last, count, id, name = strsplit(",", rec, 9)
		map, index, kind, x, y = tonumber(map), tonumber(index), KINDS[kind], tonumber(x), tonumber(y)
		last, count = tonumber(last), tonumber(count)
		if map and index and kind and x and y and last and count then
			peer.nodes[map] = peer.nodes[map] or {}
			peer.nodes[map][index] = { kind = kind, name = name ~= "" and name or nil, id = tonumber(id),
				x = x, y = y, last = last, count = count }
			peer.nodesSince = math.max(peer.nodesSince or 0, last)
		end
	end
	if tl.NodesChanged then
		tl.NodesChanged()
	end
end

handlers.NEND = function(sender, key, arg)
	local n = tonumber(arg)
	if ns.db.follow[key] and n and n > 0 then
		tl.Print("got %d new or updated nodes from %s.", n, sender)
	end
end

handlers.LBEGIN = function(_, key)
	if pending[key] then
		pending[key].entries = {}
	end
end

handlers.L = function(_, key, arg)
	local p = pending[key]
	local t, where, text = arg:match("^(%d+),([^;]*);(.*)$")
	if p and t and #p.entries < ns.LOG_MAX then
		p.entries[#p.entries + 1] = { time = tonumber(t), where = where, text = text }
	end
end

handlers.LEND = function(sender, key)
	local p = pending[key]
	if not p then
		return
	end
	pending[key] = nil
	ns.Peer(key, sender).log = { received = time(), entries = p.entries }
	ns.ShowLog(key)
end

tl.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	prefix, text, channel, sender = tl.Clean(prefix), tl.Clean(text), tl.Clean(channel), tl.Clean(sender)
	if prefix ~= ns.PREFIX or channel ~= "WHISPER" or not text or not sender then
		return
	end
	local name, key = ns.Name(sender)
	if not key or key == ns.me then
		return
	end
	-- Keep the name as the game spells it.
	ns.db.allowed[key] = ns.db.allowed[key] and name
	ns.db.follow[key] = ns.db.follow[key] and name
	local command, arg = text:match("^(%S+) ?(.*)$")
	if handlers[command] then
		handlers[command](name, key, arg)
	end
end)

--------------------------------------------------------------------------------
-- Login, and other players' nodes on the map
--------------------------------------------------------------------------------

tl.On("PLAYER_LOGIN", function()
	C_Timer.After(LOGIN_DELAY, function()
		for _, name in pairs(ns.db.allowed) do
			ns.Send(name, "HELLO")
		end
		for key in pairs(ns.db.follow) do
			ns.RequestNodes(key)
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
