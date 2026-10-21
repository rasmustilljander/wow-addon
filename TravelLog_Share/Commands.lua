-- /tl share, and a line in the TravelLog window.
local _, ns = ...
local tl = TravelLog

local function Names(map)
	local list = {}
	for _, name in pairs(map) do
		list[#list + 1] = name
	end
	table.sort(list)
	return #list > 0 and table.concat(list, ", ") or "nobody"
end

local function CountNodes(peer)
	local n = 0
	for _, list in pairs(peer and peer.nodes or {}) do
		for _ in pairs(list) do
			n = n + 1
		end
	end
	return n
end

local function Describe(r)
	local what = r.what == "log" and ("log (%d)"):format(r.count or 0) or r.what
	return ("%s asked %s for %s: %s"):format(r.from, r.to, what, r.allowed and "sent" or "not allowed")
end

function ns.ShowLog(key)
	local peer = ns.db.peers[key]
	local log = peer and peer.log
	if not log then
		tl.Print("no log from them yet: /tl share log <name> asks for it.")
		return
	end
	tl.Print("%s's last %d log entries (received %s ago):", peer.name, #log.entries, tl.Ago(log.received))
	for _, e in ipairs(log.entries) do
		print(("  %s  %s  |cff999999%s|r"):format(date("%m-%d %H:%M", e.time), e.text, e.where))
	end
end

local function ShowStatus()
	local db = ns.db
	tl.Print("sharing with: %s", Names(db.allowed))
	local follow = {}
	for key, name in pairs(db.follow) do
		follow[#follow + 1] = ("%s (%d nodes)"):format(name, CountNodes(db.peers[key]))
	end
	table.sort(follow)
	print("  Following: " .. (#follow > 0 and table.concat(follow, ", ") or "nobody"))
	local last = db.requests[#db.requests]
	if last then
		print(("  Last request, %s ago: %s"):format(tl.Ago(last.time), Describe(last)))
	end
	print("  /tl share help for the commands")
end

local function ShowRequests(n)
	local list = ns.db.requests
	n = math.min(n, #list)
	tl.Print("last %d requests:", n)
	for i = #list - n + 1, #list do
		print(("  %s  %s"):format(date("%m-%d %H:%M", list[i].time), Describe(list[i])))
	end
end

local function Help()
	tl.Print("share commands:")
	print("  /tl share - who you share with and follow, and the last request")
	print("  /tl share allow <name> - let <name> get your nodes and ask for your log")
	print("  /tl share revoke <name> - stop sharing with <name>")
	print("  /tl share follow <name> - get <name>'s nodes automatically")
	print("  /tl share unfollow <name> - stop, and drop their nodes")
	print(("  /tl share log <name> [n] - ask <name> for their last n log entries (default %d, max %d)"):format(ns.LOG_DEFAULT, ns.LOG_MAX))
	print("  /tl share show <name> - the log <name> last sent you")
	print("  /tl share requests [n] - the last n requests you got (default 10)")
end

local SUBCOMMANDS = {
	allow = function(name, key)
		ns.db.allowed[key] = name
		tl.Print("%s can now get your nodes and ask for your log.", name)
		ns.Send(name, "HELLO")
	end,
	revoke = function(name, key)
		ns.db.allowed[key], ns.listeners[key] = nil, nil
		tl.Print("%s no longer gets anything from you.", name)
	end,
	follow = function(name, key)
		ns.db.follow[key] = name
		tl.Print("asking %s for their nodes now and whenever you're both online.", name)
		ns.RequestNodes(key)
	end,
	unfollow = function(name, key)
		ns.db.follow[key] = nil
		if ns.db.peers[key] then
			ns.db.peers[key].nodes, ns.db.peers[key].nodesSince = {}, nil
		end
		if tl.NodesChanged then
			tl.NodesChanged()
		end
		tl.Print("stopped following %s and dropped their nodes.", name)
	end,
	log = function(name, key, n)
		n = math.min(tonumber(n) or ns.LOG_DEFAULT, ns.LOG_MAX)
		tl.Print("asking %s for their last %d log entries.", name, n)
		ns.RequestLog(name, key, n)
	end,
	show = function(_, key)
		ns.ShowLog(key)
	end,
}

tl.Command("share", "share - share nodes and your log with other players (/tl share help)", function(arg)
	local sub, who, n = arg:match("^(%S*)%s*(%S*)%s*(%d*)$")
	if sub == "" then
		ShowStatus()
	elseif sub == "requests" then
		ShowRequests(tonumber(who) or 10)
	elseif SUBCOMMANDS[sub] and ns.Name(who) then
		local name, key = ns.Name(who)
		SUBCOMMANDS[sub](name, key, n)
	else
		Help()
	end
end)

tl.AddStat("Sharing", function()
	local allowed, follow = 0, 0
	for _ in pairs(ns.db.allowed) do allowed = allowed + 1 end
	for _ in pairs(ns.db.follow) do follow = follow + 1 end
	local last = ns.db.requests[#ns.db.requests]
	return ("with %d, following %d%s"):format(allowed, follow,
		last and (", last request %s ago"):format(tl.Ago(last.time)) or "")
end)
