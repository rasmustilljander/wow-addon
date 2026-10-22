-- TravelLog_Share between two accounts: Rasmus shares, Bob asks. Only one
-- client runs at a time, so each side's whispers are kept and delivered to
-- the other when it plays.
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Share" }
local PREFIX = "TravelLogShare"
local ns = M.Login()

-- Whispers sent to someone since the last call, after giving the paced
-- queue time to send them (unless now is set).
local function Take(target, now)
	if not now then M.tick(10) end
	local list, keep = {}, {}
	for _, m in ipairs(M.sent) do
		if m.target == target and m.prefix == PREFIX and m.chatType == "WHISPER" then
			list[#list + 1] = m.text
		else
			keep[#keep + 1] = m
		end
	end
	M.sent = keep
	return list
end
local function Deliver(from, texts)
	for _, text in ipairs(texts) do M.addonMessage(from, PREFIX, text) end
end
local function Find(texts, pattern)
	for _, t in ipairs(texts) do if t:find(pattern) then return t end end
end
local function Printed(pattern)
	return table.concat(M.out, "\n"):find(pattern) ~= nil
end
-- The Sharing tab, opened with /tl share and redrawn.
local function Tab()
	SlashCmdList.TRAVELLOG("share")
	local w = M.ns("TravelLog").window
	for i, tab in ipairs(w.Tabs) do
		if tab:GetText() == "Sharing" then return w.pages[i] end
	end
end
-- Types a name into the tab and presses Enter; returns the player's side.
local function Pick(name)
	local page = Tab()
	page.name:SetText(name)
	M.script(page.name, "OnEnterPressed")
	return Tab().detail
end
local function Rows(list)
	local out = {}
	for _, row in ipairs(M.shown(list.rows)) do out[#out + 1] = row.name:GetText() .. " " .. row.tag:GetText() end
	return table.concat(out, ", ")
end

-- Two accounts, each with its own SavedVariables.
local accounts, current = {}, "rasmus"
local function Play(account, name)
	M.Logout()
	accounts[current] = { saved = M.saved, savedChar = M.savedChar }
	local a = accounts[account] or { saved = {}, savedChar = {} }
	M.saved, M.savedChar, current = a.saved, a.savedChar, account
	M.player = { name = name, realm = "Forever" }
	M.sent = {}
	return M.Login()
end

local function Herb(name, id, spot)
	M.x, M.y, M.wa, M.wb = spot[1], spot[2], spot[3], spot[4]
	M.cast(2366, name)
	M.loot = { { name = name, link = "|cffffffff|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r", qty = 1, guid = "GameObject-0-1-0-1-" .. id .. "-00F00D" } }
	M.lootAll()
end

--------------------------------------------------------------------------------
-- Rasmus: requests from someone not allowed are recorded and refused
--------------------------------------------------------------------------------

Herb("Peacebloom", 1618, { 0.30, 0.40, -9100, -300 })
M.advance(60)
M.cast(3365, "Battered Chest")
M.loot = { { name = "Linen Cloth", link = "[Linen Cloth]", qty = 1, guid = "GameObject-0-1-0-1-2843-0000FEED" } }
M.lootAll()
check(#TravelLogNodesAccountDB.maps[1429] == 2, "two nodes to share")

M.out = {}
M.addonMessage("Bob-Forever", PREFIX, "LOG 5")
local db = TravelLogShareDB
local r = db.requests[1]
check(r and r.from == "Bob-Forever" and r.to == "Rasmus-Forever" and r.what == "log" and r.count == 5 and r.allowed == false, "denied log request recorded")
check(Printed("Bob%-Forever asked for your log but isn't allowed"), "and told in chat")
local sent = Take("Bob-Forever")
check(#sent == 1 and sent[1] == "NO log", "Bob is told no")
M.addonMessage("Bob-Forever", PREFIX, "NODES 0")
check(#db.requests == 2 and db.requests[2].what == "nodes" and #Take("Bob-Forever") == 0, "second request recorded, no second NO within a minute")
M.addonMessage("Bob-Forever", "OtherAddon", "LOG 5")
M.fire("CHAT_MSG_ADDON", PREFIX, "LOG 5", "PARTY", "Bob-Forever", "", 0, 0, "", 0)
check(#db.requests == 2, "other prefixes and channels are ignored")

-- The tab lists who asked; nobody is picked yet
local page = Tab()
check(page:IsShown() and Rows(page.players) == "Bob-Forever |cffff9933asked|r", "requester listed: " .. Rows(page.players))
check(not page.detail:IsShown() and page.hint:GetText():find("Last request, under a minute ago: Bob%-Forever asked Rasmus%-Forever for nodes: not allowed"),
	"hint: " .. page.hint:GetText())
Pick("rasmus")
check(not page.detail:IsShown() and page.name:GetText() == "rasmus", "you can't add yourself")
page.name:SetText("")
page.players.rows[1]:Click()
local d = page.detail
check(d:IsShown() and d.title:GetText() == "Bob-Forever" and not d.share:GetChecked() and not d.follow:GetChecked(), "picked Bob")
check(d.asked:GetText() == "Asked 2 times. Last under a minute ago, for nodes from Rasmus-Forever: not allowed", "asked: " .. d.asked:GetText())

--------------------------------------------------------------------------------
-- Allowed: nodes on request and as you loot them, the log on request
--------------------------------------------------------------------------------

d = Pick("bob")
d.share:Click()
check(db.allowed["bob-forever"] == "Bob-Forever" and Tab().detail.share:GetChecked(), "bob allowed, realm added")
check(Rows(page.players) == "Bob-Forever share", "tagged: " .. Rows(page.players))
check(Find(Take("Bob-Forever"), "^HELLO$"), "allowing says hello")

M.addonMessage("Bob-Forever", PREFIX, "NODES 0")
sent = Take("Bob-Forever")
check(Find(sent, "^N 1429,1,h,30%.0,40%.0,%d+,1,1618,Peacebloom;1429,2,c,30%.0,40%.0,%d+,1,2843,Battered Chest$"), "both nodes in one message: " .. tostring(sent[1]))
check(sent[#sent] == "NEND 2" and db.requests[3].allowed, "nodes sent and the request recorded")
local nodeMsgs = sent

M.addonMessage("Bob-Forever", PREFIX, "NODES " .. M.now)
check(Take("Bob-Forever")[1] == "NEND 0", "nothing newer than since")

M.advance(120)
Herb("Silverleaf", 1617, { 0.302, 0.401, -9104, -303 })
local looted = M.now
sent = Take("Bob-Forever")
check(#sent == 1 and sent[1]:find("^N 1429,1,h,30%.0,40%.0," .. looted .. ",2,1617,Silverleaf$"), "re-looted node pushed live: " .. tostring(sent[1]))
nodeMsgs[#nodeMsgs + 1] = sent[1]

-- A loot line too long for one message loses its links, then gets cut
local many = {}
for i = 1, 12 do
	many[i] = { name = "Item " .. i, link = "|cffffffff|Hitem:" .. (5000 + i) .. "::::|h[Glittering Item Number " .. i .. "]|h|r", qty = 1, guid = "Creature-0-1-0-1-299-0000AAAA" }
end
M.units.target = { name = "Young Wolf", guid = "Creature-0-1-0-1-299-0000AAAA", hostile = true }
M.loot = many
M.lootAll()
M.units.target = nil

M.out = {}
M.addonMessage("Bob-Forever", PREFIX, "LOG 3")
check(Printed("Bob%-Forever asked for your log: sending the last 3 entries"), "log request shown")
local logMsgs = Take("Bob-Forever")
check(logMsgs[1] == "LBEGIN 3" and logMsgs[#logMsgs] == "LEND" and #logMsgs == 5, "three entries between LBEGIN and LEND: " .. #logMsgs)
check(logMsgs[3]:find("^L " .. looted .. ",Goldshire %(30%.2, 40%.1%);Looted |cffffffff|Hitem:1617"), "entry keeps its time, place and link: " .. logMsgs[3])
local long = logMsgs[4]
check(#long <= 255 and long:find("Looted %[Glittering Item Number 1%]") and not long:find("|H") and long:find("%.%.%.$"), "long entry plain and cut: " .. long)
check(db.requests[#db.requests].what == "log" and db.requests[#db.requests].count == 3, "log request recorded")

M.addonMessage("Bob-Forever", PREFIX, "LOG 5000")
check(db.requests[#db.requests].count == 100, "at most 100 entries")
M.tick(60)
check(#Take("Bob-Forever") == math.min(#TravelLogCharDB.log, 100) + 2, "a long log is sent over time")

--------------------------------------------------------------------------------
-- Pacing: a few messages a second, retried when throttled
--------------------------------------------------------------------------------

M.tick(1)
M.addonMessage("Bob-Forever", PREFIX, "LOG 10")
check(#Take("Bob-Forever", true) == 3, "three messages right away")
M.tick(1)
check(#Take("Bob-Forever", true) == 3, "three more a second later")
local throttled = 0
M.sendResult = function() throttled = throttled + 1; return Enum.SendAddonMessageResult.AddonMessageThrottle end
M.tick(1)
M.sendResult = nil
check(throttled == 1 and #Take("Bob-Forever", true) == 0, "throttled: stops for this second")
M.tick(2)
check(#Take("Bob-Forever", true) == math.min(#TravelLogCharDB.log, 10) + 2 - 6, "and sends the rest after")

-- Bob goes offline: the server's "No player named" reply is hidden and he
-- stops getting nodes
M.tick(1)
M.addonMessage("Bob-Forever", PREFIX, "LOG 10")
check(#Take("Bob-Forever", true) == 3, "sending")
check(M.chat("CHAT_MSG_SYSTEM", "No player named 'Bob-Forever' is currently playing.") == false, "not-found reply hidden")
check(#Take("Bob-Forever") == 0, "rest of the queue dropped")
Herb("Peacebloom", 1618, { 0.30, 0.40, -9100, -300 })
check(#Take("Bob-Forever") == 0, "no more live nodes")
check(M.chat("CHAT_MSG_SYSTEM", "No player named 'Zed' is currently playing."), "others' not-found messages still show")
M.sendResult = function() return Enum.SendAddonMessageResult.TargetOffline end
M.addonMessage("Bob-Forever", PREFIX, "LOG 10")
M.tick(1)
M.sendResult = nil
check(#Take("Bob-Forever") == 0, "TargetOffline drops the queue too")

-- Requests in the tab and the totals
Tab()
check(d.asked:GetText():find("^Asked %d+ times%. Last under a minute ago, for log %(10%) from Rasmus%-Forever: sent$"), "asked: " .. d.asked:GetText())
M.ns("TravelLog").window.Tabs[1]:Click()
local found
for _, fs in ipairs(M.descendants(TravelLogFrame)) do
	if fs.text and fs.text:find("^with 1, following 0, last request") then found = true end
end
check(found, "sharing line in the window")

-- Saved; says hello to Bob at the next login
local requests = #db.requests
ns = M.Reload()
check(TravelLogShareDB.allowed["bob-forever"] == "Bob-Forever" and #TravelLogShareDB.requests == requests, "allowed list and requests saved")
M.tick(9)
check(#Take("Bob-Forever", true) == 0, "waits a moment after login")
M.tick(1)
check(Find(Take("Bob-Forever", true), "^HELLO$"), "hello at login")

-- Revoked: no more nodes
M.addonMessage("Bob-Forever", PREFIX, "NODES 0")
Take("Bob-Forever")
d = Pick("bob-forever")
check(d.share:GetChecked(), "still allowed after a reload")
d.share:Click()
Herb("Peacebloom", 1618, { 0.30, 0.40, -9100, -300 })
check(TravelLogShareDB.allowed["bob-forever"] == nil and #Take("Bob-Forever") == 0, "revoked")
Pick("Bob").share:Click()

--------------------------------------------------------------------------------
-- Bob: follows Rasmus's nodes and asks for his log
--------------------------------------------------------------------------------

ns = Play("bob", "Bob")
M.addonMessage("Rasmus-Forever", PREFIX, "N 1429,9,h,50.0,50.0,1760000000,1,1618,Peacebloom")
check(next(TravelLogShareDB.peers) == nil, "nodes from someone not followed are ignored")

d = Pick("rasmus")
check(d.follow.Text:GetText() == "Get their nodes", "not following yet")
d.follow:Click()
check(TravelLogShareDB.follow["rasmus-forever"] == "Rasmus-Forever" and Take("Rasmus-Forever")[1] == "NODES 0", "following asks for nodes")
M.out = {}
Deliver("Rasmus-Forever", nodeMsgs)
local peer = TravelLogShareDB.peers["rasmus-forever"]
local herb = peer and peer.nodes[1429][1]
check(herb and herb.kind == "herb" and herb.name == "Silverleaf" and herb.count == 2 and herb.x == 30, "shared node stored, updated by the push")
check(peer.nodes[1429][2].kind == "chest" and peer.nodesSince == herb.last, "chest too; since is the newest")
check(Printed("got 2 new or updated nodes from Rasmus%-Forever"), "told how many arrived")
check(#TravelLogNodesAccountDB.maps == 0 and next(TravelLogNodesAccountDB.maps) == nil, "not mixed into Bob's own nodes")
Tab()
check(d.follow:GetChecked() and d.follow.Text:GetText() == "Get their nodes (2)", "count in the tab: " .. d.follow.Text:GetText())
check(d.status:GetText() == "You haven't asked for their log." and #M.shown(d.log.rows) == 0, "no log yet")

M.viewMap = 1429
M.frame()
local pins = M.shown(M.mapOverlay(2012).children)
check(#pins == 2 and pins[1].from == "Rasmus-Forever" and pins[1].icon.color[4] == 0.6 and pins[1].w == 6, "shared pins, smaller and dimmer")
pins[1].scripts.OnEnter(pins[1])
check(GameTooltip.lines[1] == "Silverleaf" and GameTooltip.lines[2] == "Shared by Rasmus-Forever" and GameTooltip.lines[4] == "Looted 2 times", "shared pin tooltip: " .. table.concat(GameTooltip.lines, " / "))
local miniPins = M.shown(M.ns("TravelLog_Nodes").minimapHolder.children)
check(#miniPins == 2 and miniPins[1].from == "Rasmus-Forever" and miniPins[1].w == 6, "shared nodes on the minimap too")

-- Bob's own herb shows beside them
Herb("Earthroot", 2449, { 0.60, 0.60, -9400, -600 })
M.frame()
check(#M.shown(M.mapOverlay(2012).children) == 3, "own and shared pins together")

-- The log, only when asked
Deliver("Rasmus-Forever", logMsgs)
check(peer.log == nil, "a log nobody asked for is ignored")
d.ask[1]:Click()
check(Take("Rasmus-Forever")[1] == "LOG 20", "asks for the log")
check(d.status:GetText() == "Asked for 20 entries, waiting...", "waiting: " .. d.status:GetText())
M.out = {}
Deliver("Rasmus-Forever", logMsgs)
check(#peer.log.entries == 3 and peer.log.entries[2].text:find("^Looted |cffffffff|Hitem:1617") and peer.log.entries[2].time == looted, "log stored")
check(Printed("got 3 log entries from Rasmus%-Forever"), "told in chat")
Tab()
local entries = M.shown(d.log.rows)
check(d.status:GetText() == "Their last 3 entries, received under a minute ago:" and #entries == 3, "shown in the tab: " .. d.status:GetText())
check(entries[1].what:GetText():find("Glittering") and entries[2].what:GetText():find("^Looted |cffffffff|Hitem:1617")
	and entries[2].where:GetText() == date("%m-%d %H:%M", looted) .. "  Goldshire (30.2, 40.1)", "newest first: " .. entries[2].where:GetText())
d.ask[3]:Click()
check(Take("Rasmus-Forever")[1] == "LOG 100", "asks for more")
M.out = {}
M.addonMessage("Rasmus-Forever", PREFIX, "NO log")
check(Printed("Rasmus%-Forever hasn't allowed you to see their log"), "told when refused")
Tab()
check(d.status:GetText() == "They haven't allowed you to see their log." and #M.shown(d.log.rows) == 3, "refused, the old log stays")

-- An interrupted batch stores its nodes but does not advance the durable
-- watermark, so the next login asks for them again.
local committed = peer.nodesSince
M.addonMessage("Rasmus-Forever", PREFIX, "HELLO")
check(Take("Rasmus-Forever")[1] == "NODES " .. math.max(committed - 1, 0), "request overlaps the newest second")
M.addonMessage("Rasmus-Forever", PREFIX,
	"N 1429,2,c,30.0,40.0," .. (committed + 30) .. ",2,2843,Battered Chest")
check(peer.nodes[1429][2].last == committed + 30 and peer.nodesSince == committed, "partial batch does not advance the watermark")

-- Saved; asks from the committed watermark at login and when Rasmus says hello.
ns = M.Reload()
peer = TravelLogShareDB.peers["rasmus-forever"]
check(peer.nodes[1429][2].name == "Battered Chest" and peer.nodes[1429][2].last == committed + 30
	and peer.nodesSince == committed and #peer.log.entries == 3, "shared nodes, committed watermark and log saved")
check(Take("Rasmus-Forever")[1] == "NODES " .. math.max(peer.nodesSince - 1, 0), "asks from the committed watermark at login")
M.addonMessage("Rasmus-Forever", PREFIX, "HELLO")
check(Take("Rasmus-Forever")[1] == "NODES " .. math.max(peer.nodesSince - 1, 0), "and on hello")
M.addonMessage("Ann-Forever", PREFIX, "HELLO")
check(#Take("Ann-Forever") == 0, "hello from someone not followed does nothing")

d = Pick("rasmus")
check(#M.shown(d.log.rows) == 3, "log shown after a reload")
d.follow:Click()
M.frame()
check(TravelLogShareDB.follow["rasmus-forever"] == nil and #M.shown(M.mapOverlay(2012).children) == 1, "unfollow drops their pins")
