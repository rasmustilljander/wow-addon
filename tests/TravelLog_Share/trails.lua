-- Friends' trails between two accounts: Rasmus streams his path to Bob, who
-- sees it on his world map in Rasmus's class color, under his own. Only one
-- client runs at a time, so Rasmus's whispers are kept and delivered to Bob.
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Share" }
local PREFIX = "TravelLogShare"
local ns = M.Login()
local share = M.ns("TravelLog_Share")

-- Whispers sent to someone since the last call, after giving the paced
-- queue time to send them.
local function Take(target, seconds)
	M.tick(seconds or 10)
	local list, keep = {}, {}
	for _, m in ipairs(M.sent) do
		if m.target == target and m.prefix == PREFIX then list[#list + 1] = m.text else keep[#keep + 1] = m end
	end
	M.sent = keep
	return list
end
local function Deliver(from, texts)
	for _, text in ipairs(texts) do M.addonMessage(from, PREFIX, text) end
end
local function Walk(seconds)
	for _ = 1, seconds do
		M.x, M.wb = M.x + 0.002, M.wb - 4
		M.tick(1)
	end
end
-- Path records in P messages, and the messages' heads.
local function Points(texts)
	local recs, heads = {}, {}
	for _, t in ipairs(texts) do
		local head, list = t:match("^(P %S+) (.+)$")
		if head then
			heads[#heads + 1] = head
			for rec in list:gmatch("[^;]+") do recs[#recs + 1] = rec end
		end
	end
	return recs, heads
end
-- Visible trail lines on the shown map: yours on sublevel 0 or 1, others' on -1.
local function Lines()
	M.frame()
	local mine, others = {}, {}
	for _, l in ipairs(M.shown(M.mapOverlay(2010).lines)) do
		if l.sublevel == -1 then others[#others + 1] = l else mine[#mine + 1] = l end
	end
	return mine, others
end
local function Tab()
	SlashCmdList.TRAVELLOG("share")
	local w = M.ns("TravelLog").window
	for i, tab in ipairs(w.Tabs) do
		if tab:GetText() == "Friends" then return w.pages[i] end
	end
end
local function Add(name)
	local page = Tab()
	page.name:SetText(name)
	M.script(page.name, "OnEnterPressed")
	return Tab().detail
end

local accounts, current = {}, "rasmus"
local function Play(account, name, class)
	M.Logout()
	accounts[current] = { saved = M.saved, savedChar = M.savedChar }
	local a = accounts[account] or { saved = {}, savedChar = {} }
	M.saved, M.savedChar, current = a.saved, a.savedChar, account
	M.player = { name = name, realm = "Forever", class = class }
	M.sent = {}
	return M.Login()
end

--------------------------------------------------------------------------------
-- Rasmus: points to a friend who asks, from when they came online
--------------------------------------------------------------------------------

local path = M.ns("TravelLog_Path")
Walk(20)
M.addonMessage("Bob-Forever", PREFIX, "PATH 0")
local sent = Take("Bob-Forever")
check(#sent == 1 and sent[1] == "NO" and not share.pathListeners["bob-forever"], "a stranger asking is told no")

Add("bob")
Take("Bob-Forever")
local start = path.session.start
local bobOnline = M.now
Walk(20)
M.addonMessage("Bob-Forever", PREFIX, "PATH " .. bobOnline)
sent = Take("Bob-Forever", 0)
local recs, heads = Points(sent)
check(#recs > 0 and heads[1] == "P " .. start .. ",MAGE", "catch-up sent with the session's start and class: " .. tostring(heads[1]))
local all = select(2, ns.RecentPath(0, 1000))
local fresh = 0
for _, rec in ipairs(all) do
	if start + tonumber(rec:match("^%d+")) >= bobOnline then fresh = fresh + 1 end
end
check(#recs == fresh and fresh < #all and recs[#recs] == all[#all], "only points since Bob came online: " .. #recs .. " of " .. #all)
local fits = true
for _, t in ipairs(sent) do fits = fits and #t <= 255 end
check(#sent > 1 and fits, "packed a few per message: " .. #sent)
local streamed = sent

-- New points every 10 seconds
Walk(9)
check(#Take("Bob-Forever", 0) == 0, "nothing before the batch is due")
Walk(11)
sent = Take("Bob-Forever")
recs = Points(sent)
check(#recs >= 9 and recs[#recs] == path.track.buffer[#path.track.buffer], "new points batched: " .. #recs)
for _, t in ipairs(sent) do streamed[#streamed + 1] = t end
M.tick(30)
check(#Take("Bob-Forever", 0) == 0, "standing still sends nothing")

-- The catch-up is capped
local before = #select(2, ns.RecentPath(0, 1000))
M.addonMessage("Bob-Forever", PREFIX, "PATH 0")
recs = Points(Take("Bob-Forever", 60))
check(before > 0 and #recs == math.min(before, 150), "asked from the start: everything up to the cap: " .. #recs)

-- Offline: no more points
local tried = 0
M.sendResult = function() tried = tried + 1; return Enum.SendAddonMessageResult.TargetOffline end
Walk(11)
M.sendResult = nil
Walk(20)
check(tried == 1 and #Take("Bob-Forever") == 0, "no more points once Bob is offline: " .. tried)

--------------------------------------------------------------------------------
-- Bob: Rasmus's trail on the map
--------------------------------------------------------------------------------

ns = Play("bob", "Bob", "WARRIOR")
share = M.ns("TravelLog_Share")
Deliver("Rasmus-Forever", streamed)
check(next(share.trails) == nil, "nothing taken from someone not a friend")
local d = Add("rasmus")
sent = Take("Rasmus-Forever")
check(sent[4] == "PATH " .. M.ns("TravelLog_Path").session.start, "adding asks for the path since Bob logged in: " .. tostring(sent[4]))
check(d.status:GetText():find("Trail: none this session"), "no trail yet: " .. d.status:GetText())

M.viewMap = 1429
local mine, others = Lines()
check(#mine == 0 and #others == 0, "nothing drawn yet")
Deliver("Rasmus-Forever", streamed)
local trail = share.trails["rasmus-forever"]
check(trail and trail.class == "MAGE" and #trail.sessions == 1 and trail.sessions[1].start == start, "Rasmus's session stored")
local points = trail.points
check(points == #Points(streamed), "every point kept: " .. points)
M.tick(5)
mine, others = Lines()
local l = others[1]
check(#mine == 0 and #others > 0 and l.color[1] == 0.25 and l.color[2] == 0.78, "drawn in mage blue: " .. #others)
check(l.thickness < 2.5, "thinner than your own: " .. l.thickness)

-- Bob walks too; his trail goes on top
Walk(10)
mine, others = Lines()
check(#mine > 0 and #others > 0 and mine[1].thickness > others[1].thickness, "both trails, Bob's above")

-- More points join the drawn trail; repeats and junk are ignored
local drawn = #others
Deliver("Rasmus-Forever", streamed)
check(trail.points == points, "points sent again aren't added twice")
local last = tonumber(Points(streamed)[points]:match("^%d+"))
Deliver("Rasmus-Forever", {
	("P %d,MAGE %d,1429,52.00,65.00,0,-9000.0,-300.0,0"):format(start, last + 2),
	("P %d,MAGE %d,1429,53.00,65.00,0,-9000.0,-320.0,0"):format(start, last + 4),
	("P %d,MAGE %d,1429,54.00,65.00,0,-9000.0,-340.0,0,extra"):format(start, last + 6),
	("P %d,MAGE %d,1429,x,65.00,0,-9000.0,-360.0,0"):format(start, last + 8),
	"P nonsense",
})
check(trail.points == points + 2, "two good points taken, bad ones not: " .. trail.points)
M.tick(5)
_, others = Lines()
check(#others == drawn + 2, "new points drawn while the map is open: " .. #others)

-- A reload on Rasmus's side is a new session
Deliver("Rasmus-Forever", { ("P %d,MAGE 0,1429,60.00,65.00,0,-9000.0,-500.0,0;2,1429,61.00,65.00,0,-9000.0,-520.0,0"):format(start + 3600) })
check(#trail.sessions == 2 and trail.sessions[2].start == start + 3600, "a second session")
_, others = Lines()
check(#others == drawn + 3, "drawn apart from the first: " .. #others)

Tab()
check(d.status:GetText():find("Trail: " .. trail.points .. " points this session"), "the tab counts them: " .. d.status:GetText())

-- /tl trail friends and the window's row
M.out = {}
SlashCmdList.TRAVELLOG("trail friends off")
check(ns.settings.friendTrail == "off" and table.concat(M.out):find("friends' map trail: off"), "friends' trail off")
mine, others = Lines()
check(#others == 0 and #mine > 0, "your own stays")
SlashCmdList.TRAVELLOG("trail off")
check(not M.mapOverlay(2010).shown, "nothing to show, overlay hidden")
SlashCmdList.TRAVELLOG("trail today")
SlashCmdList.TRAVELLOG("trail friends 1h")
_, others = Lines()
check(ns.settings.friendTrail == "1h" and #others > 0, "a range like an alt's")
SlashCmdList.TRAVELLOG("")
local w = ns.window
local row, button
for _, r in ipairs(M.descendants(w)) do
	if r.kind == "FontString" and r:GetText() == "Friends' trail" then row = r end
	-- Its buttons come after your trail's.
	if r.kind == "Button" and r:GetText() == "all" then button = r end
end
check(row, "a Friends' trail row in the settings")
button:Click()
check(ns.settings.friendTrail == "all", "its buttons set it: " .. ns.settings.friendTrail)

-- Kept for this session only; removing the friend drops it
ns = M.Reload()
share = M.ns("TravelLog_Share")
check(next(share.trails) == nil and not M.saved.TravelLog_Share:find("1429,"), "not saved")
check(ns.settings.friendTrail == "all", "the setting is")
Deliver("Rasmus-Forever", streamed)
_, others = Lines()
check(#others > 0, "drawn again as points arrive")
d = Add("rasmus")
d.remove:Click()
_, others = Lines()
check(next(share.trails) == nil and #others == 0, "removing Rasmus drops his trail")
M.Logout()

--------------------------------------------------------------------------------
-- Without TravelLog_Path nothing is asked for or kept
--------------------------------------------------------------------------------

M.installed = { "TravelLog", "TravelLog_Share" }
ns = M.Login()
M.sent = {}
share = M.ns("TravelLog_Share")
Add("rasmus")
sent = Take("Rasmus-Forever")
local asked = false
for _, t in ipairs(sent) do asked = asked or t:find("^PATH") ~= nil end
check(not asked and sent[1] == "HELLO", "no PATH request: " .. table.concat(sent, " / "))
Deliver("Rasmus-Forever", streamed)
check(next(share.trails) == nil, "points ignored")
M.addonMessage("Rasmus-Forever", PREFIX, "PATH 0")
check(#Take("Rasmus-Forever") == 0, "and none sent")
M.Logout()
