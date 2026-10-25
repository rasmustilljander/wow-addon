-- Totals between friends: your character's TravelLog totals go to friends
-- who ask, and theirs show in your TravelLog window and /tl stats like an
-- alt's. A batch is
--
--   SB <f|u>,<level>,<class>,<race>   f: all totals, u: only what changed
--   S <piece>                         the packed totals, cut into pieces
--   SE <n>                            that was all n pieces
--
-- After the first batch, what changed goes out every few minutes: each
-- total, or for a table of them (zoneTime, places) each entry, that isn't
-- what was sent before.
local _, ns = ...
local tl = TravelLog

local UPDATE_EVERY = 300   -- seconds from one batch to a friend to the next update
local CHECK_EVERY = 10     -- seconds between looks for updates that are due
local MAX_BYTES = 256 * 1024 -- packed totals taken from a friend, at most
local MAX_DEPTH = 8         -- tables in tables

--------------------------------------------------------------------------------
-- Packing: n12; is a number, s5:hello a string, t and f booleans, and
-- {key value key value} a table, keys in order so equal totals pack equal.
--------------------------------------------------------------------------------

local function Before(a, b)
	if type(a) ~= type(b) then
		return type(a) == "number"
	end
	return a < b
end

local Pack

local function PackKey(k)
	local kind = type(k)
	if kind == "string" then
		return "s" .. #k .. ":" .. k
	elseif kind == "number" and k == k and k ~= math.huge and k ~= -math.huge then
		return ("n%.14g;"):format(k)
	end
end

-- Packs a value, or returns nil for one that can't be (a function).
function Pack(v)
	local kind = type(v)
	if kind == "boolean" then
		return v and "t" or "f"
	elseif kind ~= "table" then
		return PackKey(v)
	end
	local keys = {}
	for k in pairs(v) do
		if PackKey(k) then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys, Before)
	local parts = { "{" }
	for _, k in ipairs(keys) do
		local packed = Pack(v[k])
		if packed then
			parts[#parts + 1] = PackKey(k) .. packed
		end
	end
	parts[#parts + 1] = "}"
	return table.concat(parts)
end
ns.Pack = Pack

-- Unpacks text from Pack; nil if it's anything else.
local function Read(text, pos, depth)
	local c = text:sub(pos, pos)
	if c == "t" or c == "f" then
		return c == "t", pos + 1
	elseif c == "n" then
		local num, after = text:match("^([^;]*);()", pos + 1)
		num = tonumber(num)
		if num then
			return num, after
		end
	elseif c == "s" then
		local length, start = text:match("^(%d+):()", pos + 1)
		length = tonumber(length)
		if length and start + length - 1 <= #text then
			return text:sub(start, start + length - 1), start + length
		end
	elseif c == "{" and depth < MAX_DEPTH then
		local t = {}
		pos = pos + 1
		while text:sub(pos, pos) ~= "}" do
			local k, v
			k, pos = Read(text, pos, depth + 1)
			if type(k) ~= "string" and type(k) ~= "number" then
				return
			end
			v, pos = Read(text, pos, depth + 1)
			if v == nil then
				return
			end
			t[k] = v
		end
		return t, pos + 1
	end
end

function ns.Unpack(text)
	local ok, v, pos = pcall(Read, text, 1, 0)
	if ok and pos == #text + 1 then
		return v
	end
end

--------------------------------------------------------------------------------
-- Sending yours
--------------------------------------------------------------------------------

-- Cuts text into pieces that fit a message, not inside a UTF-8 character.
local function Pieces(text, room)
	local list, pos = {}, 1
	while pos <= #text do
		local stop = math.min(pos + room - 1, #text)
		while stop > pos and text:byte(stop + 1) and text:byte(stop + 1) >= 128 and text:byte(stop + 1) < 192 do
			stop = stop - 1
		end
		list[#list + 1] = text:sub(pos, stop)
		pos = stop + 1
	end
	return list
end

local function Strip(text)
	return (tostring(text or ""):gsub(",", ""))
end

-- Your totals packed two levels deep: a packed value per total, or for a
-- table a packed value per entry.
local function Packed()
	local packed = {}
	for k, v in pairs(tl.stats) do
		if PackKey(k) and type(v) == "table" then
			local entries = {}
			for ek, ev in pairs(v) do
				entries[ek] = PackKey(ek) and Pack(ev)
			end
			packed[k] = entries
		elseif PackKey(k) then
			packed[k] = Pack(v)
		end
	end
	return packed
end

-- Packs the parts of now that differ from before, all of it without before.
local function Changes(now, before)
	local keys, parts = {}, {}
	for k in pairs(now) do
		keys[#keys + 1] = k
	end
	table.sort(keys, Before)
	for _, k in ipairs(keys) do
		local v, old = now[k], before and before[k]
		if type(v) == "table" then
			local entries = Changes(v, type(old) == "table" and old or nil)
			if entries ~= "{}" or not old then
				parts[#parts + 1] = PackKey(k) .. entries
			end
		elseif v ~= old then
			parts[#parts + 1] = PackKey(k) .. v
		end
	end
	return "{" .. table.concat(parts) .. "}"
end

-- Sends your totals, or with update only what changed since the last batch.
local function SendStats(target, key, update)
	local sent = ns.statsSent[key]
	local now = Packed()
	local text = Changes(now, update and sent and sent.parts)
	local profile = tl.profile
	local head = ("%d,%s,%s"):format(profile.level or 0, Strip(profile.class), Strip(profile.race))
	if update and text == "{}" and sent.head == head then
		return
	end
	ns.statsSent[key] = { head = head, parts = now, due = GetTime() + UPDATE_EVERY }
	local pieces = Pieces(text, ns.MAX_LENGTH - 2)
	ns.Send(target, ("SB %s,%s"):format(update and "u" or "f", head))
	for _, piece in ipairs(pieces) do
		ns.Send(target, "S " .. piece)
	end
	ns.Send(target, "SE " .. #pieces)
end

ns.handlers.STATS = function(sender, key)
	if ns.FromFriend(sender, key) then
		SendStats(sender, key)
	end
end

C_Timer.NewTicker(CHECK_EVERY, function()
	for key, sent in pairs(ns.statsSent) do
		if ns.db.friends[key] and sent.due <= GetTime() then
			sent.due = GetTime() + UPDATE_EVERY
			SendStats(ns.db.friends[key], key, true)
		end
	end
end)

--------------------------------------------------------------------------------
-- Getting theirs
--------------------------------------------------------------------------------

local incoming = {} -- key -> the batch arriving

function ns.RequestStats(key)
	incoming[key] = nil
	ns.Send(ns.db.friends[key], "STATS")
end

ns.handlers.SB = function(_, key, arg)
	local mode, level, class, race = strsplit(",", arg, 4)
	if mode == "f" or mode == "u" then
		incoming[key] = { update = mode == "u", level = tonumber(level), class = class, race = race,
			pieces = {}, bytes = 0 }
	end
end

ns.handlers.S = function(_, key, arg)
	local batch = incoming[key]
	if batch then
		batch.bytes = batch.bytes + #arg
		batch.pieces[#batch.pieces + 1] = arg
		if batch.bytes > MAX_BYTES then
			incoming[key] = nil
		end
	end
end

ns.handlers.SE = function(sender, key, arg)
	local batch = incoming[key]
	incoming[key] = nil
	local stats = batch and tonumber(arg) == #batch.pieces and ns.Unpack(table.concat(batch.pieces))
	if type(stats) ~= "table" then
		return
	end
	local peer = ns.Peer(key, sender)
	local first = not peer.char
	local char = peer.char or {}
	if batch.update then
		char.stats = char.stats or {}
		for k, v in pairs(stats) do
			local old = char.stats[k]
			if type(v) == "table" and type(old) == "table" then
				for ek, ev in pairs(v) do
					old[ek] = ev
				end
			else
				char.stats[k] = v
			end
		end
	else
		char.stats = stats
	end
	char.name, char.realm = sender:match("^(.-)%-(.+)$")
	char.level, char.class, char.race = batch.level, batch.class, batch.race
	char.received = time()
	peer.char = char
	tl.friends[peer.name] = char
	ns.Changed()
	if first then
		tl.Print("got %s's totals: /tl stats %s shows them.", sender, char.name:lower())
	end
end
