-- TravelLog_Share between two accounts: Rasmus and Bob add each other as
-- friends. Only one client runs at a time, so each side's whispers are kept
-- and delivered to the other when it plays.
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Share" }
local PREFIX = "TravelLogShare"
local ns = M.Login()
local share = M.ns("TravelLog_Share")

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
-- A batch of totals as sent: its SB line and the unpacked table.
local function Totals(texts)
	local head, pieces, n
	for _, t in ipairs(texts) do
		head = head or t:match("^SB (.*)$")
		if t:find("^S ") then
			pieces = pieces or {}
			pieces[#pieces + 1] = t:sub(3)
		end
		n = n or tonumber(t:match("^SE (%d+)$"))
	end
	return head, pieces and n == #pieces and share.Unpack(table.concat(pieces)), pieces
end
-- The Friends tab, opened with /tl share and redrawn.
local function Tab()
	SlashCmdList.TRAVELLOG("share")
	local w = M.ns("TravelLog").window
	for i, tab in ipairs(w.Tabs) do
		if tab:GetText() == "Friends" then return w.pages[i] end
	end
end
-- Types a name into the tab and presses Enter; returns the friend's side.
local function Add(name)
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
-- The value next to a label in the TravelLog window's totals.
local function Stat(w, label)
	local all = M.descendants(w)
	for i, r in ipairs(all) do
		if r.kind == "FontString" and r:GetText() == label then return all[i + 1]:GetText() end
	end
end
-- The font strings at x on a page, in order.
local function Texts(page, x)
	local list = {}
	for _, fs in ipairs(page.fontStrings or {}) do
		if fs.point and fs.point[2] == x and fs:GetText() ~= "" then list[#list + 1] = fs:GetText() end
	end
	return table.concat(list, ", ")
end
local function Button(w, text)
	for _, r in ipairs(M.descendants(w)) do
		if r.kind == "Button" and r:GetText() == text then return r end
	end
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
-- Packing totals
--------------------------------------------------------------------------------

local Pack, Unpack = share.Pack, share.Unpack
local value = { loot = { items = 12, money = 4.5 }, [3] = "three", ["a:b;{c}"] = "s5:x}", on = true, off = false, neg = -0.25,
	zones = { ["Tür"] = 1 }, fn = print }
local back = Unpack(Pack(value))
check(back and back.loot.items == 12 and back.loot.money == 4.5 and back[3] == "three" and back["a:b;{c}"] == "s5:x}"
	and back.on == true and back.off == false and back.neg == -0.25 and back.zones["Tür"] == 1 and back.fn == nil, "packs and unpacks")
check(Pack({ b = 1, a = 2, [2] = 0 }) == "{n2;n0;s1:an2;s1:bn1;}", "keys in order: " .. Pack({ b = 1, a = 2, [2] = 0 }))
local bad = { "", "x", "{", "{s5:abc}", "{n1;}", "{n1;n2;", "{s1:an1;}x", "{s9999:a}", "{n;n1;}",
	("{s1:a"):rep(9) .. "n1;" .. ("}"):rep(9) }
for _, text in ipairs(bad) do
	check(Unpack(text) == nil, "malformed: " .. text)
end
check(Unpack(("{s1:a"):rep(7) .. "n1;" .. ("}"):rep(7)) ~= nil, "nested a few deep")

--------------------------------------------------------------------------------
-- Rasmus: only friends get anything
--------------------------------------------------------------------------------

Herb("Peacebloom", 1618, { 0.30, 0.40, -9100, -300 })
M.advance(60)
M.cast(3365, "Battered Chest")
M.loot = { { name = "Linen Cloth", link = "[Linen Cloth]", qty = 1, guid = "GameObject-0-1-0-1-2843-0000FEED" } }
M.lootAll()
check(#TravelLogNodesAccountDB.maps[1429] == 2, "two nodes to share")

M.out = {}
M.addonMessage("Bob-Forever", PREFIX, "NODES 0")
check(Printed("Bob%-Forever wants to share TravelLog data but isn't your friend"), "told in chat")
local sent = Take("Bob-Forever")
check(#sent == 1 and sent[1] == "NO", "Bob is told no")
M.out = {}
M.addonMessage("Bob-Forever", PREFIX, "STATS")
check(#Take("Bob-Forever") == 0 and not Printed("wants to share"), "no second NO within a minute")
M.addonMessage("Bob-Forever", PREFIX, "HELLO")
M.addonMessage("Bob-Forever", PREFIX, "N 1429,9,h,50.0,50.0,1760000000,1,1618,Peacebloom")
check(#Take("Bob-Forever") == 0 and next(TravelLogShareDB.peers) == nil, "hello and nodes from someone not a friend do nothing")
M.addonMessage("Bob-Forever", "OtherAddon", "NODES 0")
M.fire("CHAT_MSG_ADDON", PREFIX, "NODES 0", "PARTY", "Bob-Forever", "", 0, 0, "", 0)
M.advance(61)
check(#Take("Bob-Forever") == 0, "other prefixes and channels are ignored")

local db = TravelLogShareDB
local page = Tab()
check(page:IsShown() and Rows(page.friends) == "" and not page.detail:IsShown() and page.hint:GetText():find("^Add a friend by name"),
	"no friends yet: " .. page.hint:GetText())
Add("rasmus")
check(not page.detail:IsShown() and page.name:GetText() == "rasmus" and next(db.friends) == nil, "you can't add yourself")
page.name:SetText("")

--------------------------------------------------------------------------------
-- Rasmus adds Bob: nodes on request and as you loot them, totals
--------------------------------------------------------------------------------

local d = Add("bob")
check(db.friends["bob-forever"] == "Bob-Forever", "Bob added, realm added")
check(Rows(page.friends) == "Bob-Forever " and d:IsShown() and d.title:GetText() == "Bob-Forever", "listed and picked: " .. Rows(page.friends))
check(d.status:GetText():find("^Not heard from yet") and d.status:GetText():find("Nodes: 0 of theirs") and d.status:GetText():find("Totals: none yet")
	and not d.totals:IsEnabled(), "status: " .. d.status:GetText())
sent = Take("Bob-Forever")
check(sent[1] == "HELLO" and sent[2] == "NODES 0" and sent[3] == "STATS" and #sent == 3, "adding says hello and asks: " .. table.concat(sent, " / "))

M.addonMessage("Bob-Forever", PREFIX, "NODES 0")
sent = Take("Bob-Forever")
check(Find(sent, "^N 1429,1,h,30%.0,40%.0,%d+,1,1618,Peacebloom;1429,2,c,30%.0,40%.0,%d+,1,2843,Battered Chest$"), "both nodes in one message: " .. tostring(sent[1]))
check(sent[#sent] == "NEND 2", "and how many")
local nodeMsgs = sent
check(M.now - db.peers["bob-forever"].seen <= 10, "heard from Bob")
check(Tab().detail.status:GetText():find("^Last heard from under a minute ago"), "status: " .. d.status:GetText())

M.addonMessage("Bob-Forever", PREFIX, "NODES " .. M.now)
check(Take("Bob-Forever")[1] == "NEND 0", "nothing newer than since")

M.advance(120)
Herb("Silverleaf", 1617, { 0.302, 0.401, -9104, -303 })
local looted = M.now
sent = Take("Bob-Forever")
check(#sent == 1 and sent[1]:find("^N 1429,1,h,30%.0,40%.0," .. looted .. ",2,1617,Silverleaf$"), "re-looted node pushed live: " .. tostring(sent[1]))
nodeMsgs[#nodeMsgs + 1] = sent[1]

-- Totals: everything first, with level, class and race
ns.stats.zoneTime["Ahn'Qiraj: Tür und Tor"] = 7
for i = 1, 100 do ns.stats.zoneTime["Zone number " .. i] = i end
M.addonMessage("Bob-Forever", PREFIX, "STATS")
local statsMsgs = Take("Bob-Forever")
local head, totals, pieces = Totals(statsMsgs)
check(head == "f,5,MAGE,Human" and statsMsgs[1] == "SB f,5,MAGE,Human" and statsMsgs[#statsMsgs]:find("^SE "), "a full batch: " .. tostring(statsMsgs[1]))
check(totals and totals.loot.items == ns.stats.loot.items and totals.zoneTime["Zone number 30"] == 30
	and totals.zoneTime["Ahn'Qiraj: Tür und Tor"] == 7, "all totals, unpacked")
check(#pieces > 2, "over several messages: " .. #pieces)
local cut = true
for _, m in ipairs(statsMsgs) do
	cut = cut and #m <= 255
end
for _, p in ipairs(pieces) do
	local b = p:byte(1)
	cut = cut and not (b >= 128 and b < 192)
end
check(cut, "each fits a message, none starts inside a character")

-- After that, only what changed, five minutes after the last batch
M.tick(280)
check(#Take("Bob-Forever", true) == 0, "nothing before five minutes")
M.tick(30)
local updateMsgs = Take("Bob-Forever", true)
head, totals = Totals(updateMsgs)
check(head == "u,5,MAGE,Human" and totals and totals.zoneTime["Elwynn Forest"] > 300
	and totals.zoneTime["Zone number 30"] == nil and totals.loot == nil, "an update with what changed")
Herb("Earthroot", 2449, { 0.60, 0.60, -9400, -600 })
Take("Bob-Forever")
M.tick(300)
updateMsgs = Take("Bob-Forever", true)
head, totals = Totals(updateMsgs)
check(totals and totals.loot.items == ns.stats.loot.items, "loot changed, sent")
local updatedItems = totals.loot.items

--------------------------------------------------------------------------------
-- Pacing: a few messages a second, retried when throttled
--------------------------------------------------------------------------------

M.addonMessage("Bob-Forever", PREFIX, "STATS")
local n = #statsMsgs
check(#Take("Bob-Forever", true) == 3, "three messages right away")
M.tick(1)
check(#Take("Bob-Forever", true) == 3, "three more a second later")
local throttled = 0
M.sendResult = function() throttled = throttled + 1; return Enum.SendAddonMessageResult.AddonMessageThrottle end
M.tick(1)
M.sendResult = nil
check(throttled == 1 and #Take("Bob-Forever", true) == 0, "throttled: stops for this second")
M.tick(20)
check(#Take("Bob-Forever", true) == n - 6, "and sends the rest after")

-- Bob goes offline: the server's "No player named" reply is hidden and he
-- stops getting nodes and updates
M.addonMessage("Bob-Forever", PREFIX, "STATS")
check(#Take("Bob-Forever", true) == 3, "sending")
check(M.chat("CHAT_MSG_SYSTEM", "No player named 'Bob-Forever' is currently playing.") == false, "not-found reply hidden")
check(#Take("Bob-Forever") == 0, "rest of the queue dropped")
Herb("Peacebloom", 1618, { 0.30, 0.40, -9100, -300 })
M.tick(300)
check(#Take("Bob-Forever") == 0, "no more live nodes or updates")
check(M.chat("CHAT_MSG_SYSTEM", "No player named 'Zed' is currently playing."), "others' not-found messages still show")
M.sendResult = function() return Enum.SendAddonMessageResult.TargetOffline end
M.addonMessage("Bob-Forever", PREFIX, "STATS")
M.tick(1)
M.sendResult = nil
check(#Take("Bob-Forever") == 0, "TargetOffline drops the queue too")

-- Saved; says hello to Bob and asks at the next login
ns = M.Reload()
check(TravelLogShareDB.friends["bob-forever"] == "Bob-Forever", "friends saved")
M.tick(9)
check(#Take("Bob-Forever", true) == 0, "waits a moment after login")
M.tick(1)
sent = Take("Bob-Forever", true)
check(sent[1] == "HELLO" and sent[2] == "NODES 0" and sent[3] == "STATS", "hello and asks at login: " .. table.concat(sent, " / "))

-- Removed: no more nodes
M.addonMessage("Bob-Forever", PREFIX, "NODES 0")
Take("Bob-Forever")
d = Add("bob-forever")
check(#Take("Bob-Forever") == 0, "adding a friend again asks nothing")
d.remove:Click()
check(TravelLogShareDB.friends["bob-forever"] == nil and not Tab().detail:IsShown() and Rows(Tab().friends) == "", "removed")
Herb("Peacebloom", 1618, { 0.30, 0.40, -9100, -300 })
check(#Take("Bob-Forever") == 0, "no more live nodes")
Add("Bob")
Take("Bob-Forever")

--------------------------------------------------------------------------------
-- Bob: Rasmus's nodes and totals
--------------------------------------------------------------------------------

ns = Play("bob", "Bob")
M.player.class = "WARRIOR"
Deliver("Rasmus-Forever", nodeMsgs)
Deliver("Rasmus-Forever", statsMsgs)
check(next(TravelLogShareDB.peers) == nil and next(ns.friends) == nil, "nothing taken from someone not a friend")

d = Add("rasmus")
check(Find(Take("Rasmus-Forever"), "^NODES 0$"), "adding asks for nodes")
M.out = {}
Deliver("Rasmus-Forever", nodeMsgs)
local peer = TravelLogShareDB.peers["rasmus-forever"]
local herb = peer and peer.nodes[1429][1]
check(herb and herb.kind == "herb" and herb.name == "Silverleaf" and herb.count == 2 and herb.x == 30, "shared node stored, updated by the push")
check(peer.nodes[1429][2].kind == "chest" and peer.nodesSince == herb.last, "chest too; since is the newest")
check(Printed("got 2 new or updated nodes from Rasmus%-Forever"), "told how many arrived")
check(next(TravelLogNodesAccountDB.maps) == nil, "not mixed into Bob's own nodes")
Tab()
check(d.status:GetText():find("Nodes: 2 of theirs on your map"), "count in the tab: " .. d.status:GetText())

M.viewMap = 1429
M.frame()
local pins = M.shown(M.mapOverlay(2012).children)
check(#pins == 2 and pins[1].from == "Rasmus-Forever" and pins[1].icon.color[4] == 0.6 and pins[1].w == 6, "shared pins, smaller and dimmer")
pins[1].scripts.OnEnter(pins[1])
check(GameTooltip.lines[1] == "Silverleaf" and GameTooltip.lines[2] == "Shared by Rasmus-Forever" and GameTooltip.lines[4] == "Looted 2 times", "shared pin tooltip: " .. table.concat(GameTooltip.lines, " / "))
local miniPins = M.shown(M.ns("TravelLog_Nodes").minimapHolder.children)
check(#miniPins == 2 and miniPins[1].from == "Rasmus-Forever" and miniPins[1].w == 6, "shared nodes on the minimap too")
Herb("Earthroot", 2449, { 0.60, 0.60, -9400, -600 })
M.frame()
check(#M.shown(M.mapOverlay(2012).children) == 3, "own and shared pins together")

-- Totals, like an alt's
M.out = {}
Deliver("Rasmus-Forever", statsMsgs)
local friend = ns.friends["Rasmus-Forever"]
check(friend and friend == peer.char and friend.name == "Rasmus" and friend.realm == "Forever" and friend.level == 5 and friend.class == "MAGE"
	and friend.stats.zoneTime["Zone number 30"] == 30, "totals stored")
check(Printed("got Rasmus%-Forever's totals: /tl stats rasmus shows them"), "told the first time")
local rasmusItems = friend.stats.loot.items
M.out = {}
SlashCmdList.TRAVELLOG("stats rasmus")
check(Printed("Rasmus%-Forever, level 5, a friend's from under a minute ago") and Printed("Loot: " .. rasmusItems .. " items"), "/tl stats rasmus")
M.out = {}
SlashCmdList.TRAVELLOG("stats all")
check(Printed("All 1 characters") and Printed("Loot: " .. ns.stats.loot.items .. " items"), "not in all of yours")
M.out = {}
SlashCmdList.TRAVELLOG("stats nobody")
check(Printed("Known: Bob%-Forever, Rasmus%-Forever"), "listed as known")

Tab()
check(Rows(Tab().friends) == "Rasmus-Forever level 5" and d.totals:IsEnabled(), "level in the list: " .. Rows(Tab().friends))
d.totals:Click()
local w = M.ns("TravelLog").window
local totalsPage = w.pages[1]
local function Picker() return Texts(totalsPage, 152) end
local function Step(text) Button(totalsPage, text):Click() end
check(totalsPage:IsShown() and Picker() == "Rasmus-Forever, level 5, a friend's from under a minute ago", "Show totals opens theirs: " .. Picker())
check(Stat(w, "Looted"):find("^" .. rasmusItems .. " items from") and Stat(w, "Entries"):find("only for the character you're on"),
	"their loot; your-character-only rows say so: " .. Stat(w, "Looted"))
Step(">")
check(Picker() == "All 1 characters" and Stat(w, "Looted"):find("^" .. ns.stats.loot.items .. " items from"), "then all of yours, without theirs")
Step(">")
Step(">")
check(Picker():find("^Rasmus%-Forever, level 5, a friend's"), "after yours: " .. Picker())

-- Updates merge into what's there; a broken batch changes nothing
Deliver("Rasmus-Forever", updateMsgs)
check(friend.stats.loot.items == updatedItems and friend.stats.loot.items > rasmusItems and friend.stats.zoneTime["Zone number 30"] == 30, "update merged")
M.out = {}
Deliver("Rasmus-Forever", { "SB u,6,MAGE,Human", "S {s4:lootn1;}", "SE 2" })
check(friend.stats.loot.items == updatedItems and friend.level == 5, "wrong piece count ignored")
Deliver("Rasmus-Forever", { "SB u,6,MAGE,Human", "S {s4:loot", "SE 1" })
check(friend.stats.loot.items == updatedItems, "unreadable batch ignored")
Deliver("Rasmus-Forever", { "S {s4:lootn1;}", "SE 1" })
check(friend.stats.loot.items == updatedItems, "pieces without a start ignored")
local big = { "SB f,6,MAGE,Human" }
for i = 2, 300 do big[i] = "S " .. ("x"):rep(250) end
big[#big + 1] = "SE 299"
Deliver("Rasmus-Forever", big)
check(friend.stats.loot.items == updatedItems and not Printed("totals"), "too big ignored")

-- Rasmus hasn't added Bob (anymore)
M.out = {}
M.addonMessage("Rasmus-Forever", PREFIX, "NO")
check(Printed("Rasmus%-Forever hasn't added you as a friend yet"), "told when refused")
M.addonMessage("Rasmus-Forever", PREFIX, "NO")
check(not table.concat(M.out, "\n"):find("yet.*yet"), "once")
Tab()
check(Rows(Tab().friends) == "Rasmus-Forever |cffff9933waiting|r" and d.status:GetText():find("^They haven't added you yet"), "waiting: " .. d.status:GetText())
M.addonMessage("Rasmus-Forever", PREFIX, "NEND 0")
check(Rows(Tab().friends) == "Rasmus-Forever level 5", "not waiting once they answer")

-- An interrupted batch stores its nodes but does not advance the durable
-- watermark, so the next login asks for them again.
local committed = peer.nodesSince
M.addonMessage("Rasmus-Forever", PREFIX, "HELLO")
sent = Take("Rasmus-Forever")
check(sent[1] == "NODES " .. math.max(committed - 1, 0) and sent[2] == "STATS", "hello asks again, overlapping the newest second")
M.addonMessage("Rasmus-Forever", PREFIX,
	"N 1429,2,c,30.0,40.0," .. (committed + 30) .. ",2,2843,Battered Chest")
check(peer.nodes[1429][2].last == committed + 30 and peer.nodesSince == committed, "partial batch does not advance the watermark")

-- Saved; their totals are there right after login
ns = M.Reload()
peer = TravelLogShareDB.peers["rasmus-forever"]
check(peer.nodes[1429][2].name == "Battered Chest" and peer.nodesSince == committed and peer.char.stats.loot.items == updatedItems,
	"shared nodes, committed watermark and totals saved")
check(ns.friends["Rasmus-Forever"] == peer.char, "back in TravelLog's friends")
M.out = {}
SlashCmdList.TRAVELLOG("stats rasmus")
check(Printed("Rasmus%-Forever, level 5, a friend's"), "/tl stats after a reload")
sent = Take("Rasmus-Forever")
check(sent[2] == "NODES " .. math.max(committed - 1, 0) and sent[3] == "STATS", "asks from the committed watermark at login")

d = Add("rasmus")
d.remove:Click()
M.frame()
check(TravelLogShareDB.peers["rasmus-forever"] == nil and ns.friends["Rasmus-Forever"] == nil and #M.shown(M.mapOverlay(2012).children) == 1,
	"removing drops their pins and totals")
M.out = {}
SlashCmdList.TRAVELLOG("stats rasmus")
check(Printed("no character"), "and /tl stats forgets them")
