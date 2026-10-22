-- Where TravelLog keeps its data: per-character files, the account-wide
-- file, old history kept in place, and TravelLog with and without its
-- companion addons.
local DAY = 86400

-- This character's TravelLog_Path data, or nil when it isn't loaded.
local function PathDB()
	return M.loaded.TravelLog_Path and M.ns("TravelLog_Path").db
end

local function said(pattern)
	for _, line in ipairs(M.out) do
		if line:find(pattern) then return true end
	end
	return false
end

-- Adds `days` worth of fake old sessions (about `mb` MB in total) to the
-- current character, ending `ago` days back. The path goes to TravelLog_Path
-- when it's loaded, and into TravelLog's sessions (like before it existed)
-- when it isn't.
local function AddOldHistory(mb, ago, days)
	local record = "120,1429,42.10,65.30,0,-9000.0,-100.0,0"
	local chunk = (record .. ";"):rep(199) .. record -- ~8.5 KB
	local chunks = math.floor(mb * 1048576 / #chunk)
	local perSession = math.ceil(chunks / days)
	local start = M.now - (ago + days) * DAY
	local sessions, paths, log = {}, {}, {}
	for d = 1, days do
		local s = { start = start + d * DAY, stop = start + d * DAY + 3600 }
		local p = PathDB() and { start = s.start, stop = s.stop } or s
		p.track, p.jumps = {}, {}
		for _ = 1, perSession do p.track[#p.track + 1] = chunk end
		sessions[#sessions + 1] = s
		paths[#paths + 1] = p ~= s and p or nil
		log[#log + 1] = { type = "loot", time = s.start + 60, map = 1429, x = 42.1, y = 65.3, source = "Old Kobold" }
	end
	local char = TravelLogCharDB
	for i = #sessions, 1, -1 do table.insert(char.sessions, 1, sessions[i]) end
	for i = #paths, 1, -1 do table.insert(PathDB().sessions, 1, paths[i]) end
	for i = #log, 1, -1 do table.insert(char.log, 1, log[i]) end
end

--------------------------------------------------------------------------------
-- Each character gets its own file; the account file only has profiles
--------------------------------------------------------------------------------

local ns = M.Login()
M.tick(1)
for _ = 1, 10 do M.x = M.x + 0.001; M.wb = M.wb - 4; M.tick(1) end
JumpOrAscendStart()
M.Logout()
check(M.savedSize("TravelLog", true) > 0, "history saved in the per-character file")
check(M.savedSize("TravelLog_Path") > 0 and M.savedSize("TravelLog_Path", true) == 0, "the path in the account-wide file")
check(not M.saved.TravelLog:find('%["sessions"%]'), "account-wide file has no sessions")
check(M.saved.TravelLog:find('%["Rasmus%-Forever"%]'), "account-wide file has the character's profile")

M.player = { name = "Altie", realm = "Forever" }
ns = M.Login()
check(#TravelLogCharDB.sessions == 1 and #TravelLogCharDB.log <= 2 and #PathDB().sessions == 1, "an alt starts with its own empty history")
check(TravelLogDB.chars["Rasmus-Forever"] and TravelLogDB.chars["Altie-Forever"], "both profiles in the account file")
M.Logout()
M.player = { name = "Rasmus", realm = "Forever" }
ns = M.Login()
check(#TravelLogCharDB.sessions == 2 and #PathDB().sessions == 2 and ns.stats.jumps == 1, "back on the main, its history is back")
M.Logout()

--------------------------------------------------------------------------------
-- Version 1 files (everything in the account-wide file) are migrated
--------------------------------------------------------------------------------

M.saved, M.savedChar = {}, {}
M.saved.TravelLog = [[
TravelLogDB = {
	["version"] = 1,
	["settings"] = { ["interval"] = 3, ["trail"] = "week" },
	["chars"] = {
		["Rasmus-Forever"] = {
			["level"] = 9,
			["stats"] = { ["jumps"] = 42 },
			["log"] = { { ["type"] = "level", ["time"] = 1750000000, ["level"] = 9 } },
			["sessions"] = { { ["start"] = 1750000000, ["stop"] = 1750003600, ["track"] = { "1,1429,40.00,60.00,0,-9000.0,-100.0,0" }, ["jumps"] = {} } },
			["quests"] = { [54] = { ["title"] = "Report to Goldshire" } },
		},
	},
}
]]
ns = M.Login()
check(TravelLogCharDB.log[1].level == 9 and #TravelLogCharDB.sessions == 2, "v1 log and sessions moved to the character file")
check(#PathDB().sessions == 2 and PathDB().sessions[1].track[1]:find("^1,1429,40.00")
	and PathDB().sessions[1].start == 1750000000 and not TravelLogCharDB.sessions[1].track, "and the v1 path on to TravelLog_Path")
check(TravelLogCharDB.quests[54].title == "Report to Goldshire", "v1 quests moved")
check(TravelLogDB.chars["Rasmus-Forever"].log == nil and TravelLogDB.version == 2, "account file cleaned up")
check(ns.stats.jumps == 42 and ns.settings.interval == 3, "stats and settings kept")
M.Logout()

--------------------------------------------------------------------------------
-- Old history stays in the main files
--------------------------------------------------------------------------------

M.saved, M.savedChar = {}, {}
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes" }

ns = M.Login()
AddOldHistory(4, 20, 30) -- 4 MB of history from 50 to 20 days ago
local stored = {
	sessions = #TravelLogCharDB.sessions,
	log = #TravelLogCharDB.log,
	paths = #PathDB().sessions,
}
TravelLogDB.archive = { size = 4 * 1048576 } -- metadata left by the removed archive feature
M.Logout()
check(M.savedSize("TravelLog_Path") > 3 * 1048576, "large old path stays in TravelLog_Path")

M.out = {}
ns = M.Login()
check(TravelLogDB.archive == nil, "old archive metadata removed")
check(#TravelLogCharDB.sessions == stored.sessions + 1 and #PathDB().sessions == stored.paths + 1,
	"old sessions and paths kept after login")
check(#TravelLogCharDB.log >= stored.log and TravelLogCharDB.log[1].source == "Old Kobold"
	and PathDB().sessions[1].track[1], "old events and path points kept")
check(not said("moved .* history"), "old history is not rotated")

-- "all" reads old history directly from the stored path and event log.
SlashCmdList.TRAVELLOG("trail all")
M.viewMap = 1429
M.frame()
local overlay = M.mapOverlay(2010)
local purple = 0
for _, t in ipairs(M.shown(overlay.textures)) do if t.color[1] == 0.75 then purple = purple + 1 end end
check(purple >= 1, "old loot markers drawn from the stored log")

M.out = {}
SlashCmdList.TRAVELLOG("archive")
check(said("commands:") and not said("/tl archive"), "/tl archive removed")

-- Wiping a character removes its retained TravelLog and Path history.
SlashCmdList.TRAVELLOG("wipe confirm")
check(M.reloadRequested, "wipe reloads the UI")
ns = M.Reload()
check(#TravelLogCharDB.sessions == 1 and #TravelLogCharDB.log <= 1 and #PathDB().sessions == 1, "character history wiped")
check(ns.stats.jumps == nil, "character stats wiped")
M.Logout()

--------------------------------------------------------------------------------
-- TravelLog without its companion addons, and installing them later
--------------------------------------------------------------------------------

-- A character file from before TravelLog_Path and TravelLog_Nodes existed
local OLD_CHAR = [[
TravelLogCharDB = {
	["log"] = {},
	["sessions"] = { { ["start"] = 1759990000, ["stop"] = 1759993600, ["jumpCount"] = 2,
		["track"] = { "1,1436,40.00,40.00,0,-10000.0,-1000.0,0;9,1436,42.00,41.00,0,-10010.0,-1010.0,0" },
		["jumps"] = { "5,1436,41.00,40.50,0,-10005.0,-1005.0,0,Westfall,Sentinel Hill" } } },
	["nodes"] = { [1436] = { { ["kind"] = "ore", ["x"] = 41, ["y"] = 40, ["count"] = 1, ["last"] = 1759991000, ["times"] = { 1759991000 } } } },
}
]]
M.saved, M.savedChar = {}, { ["Rasmus-Forever"] = { TravelLog = OLD_CHAR } }
M.installed = { "TravelLog" }
M.out, M.errors = {}, {}
ns = M.Login()
M.tick(1)
for _ = 1, 5 do M.x = M.x + 0.001; M.wb = M.wb - 4; M.tick(1) end
JumpOrAscendStart()
M.cast(2366, "Peacebloom")
M.loot = { { name = "Peacebloom", link = "[Peacebloom]", qty = 1, guid = "GameObject-0-1-0-1-1618-00F00D" } }
M.lootAll()
SlashCmdList.TRAVELLOG("stats")
SlashCmdList.TRAVELLOG("trail week")
check(said("/tl log %[n%]") and not said("/tl trail"), "without TravelLog_Path, /tl trail isn't a command")
SlashCmdList.TRAVELLOG("log")
check(#M.errors == 0 and TravelLogPathAccountDB == nil and TravelLogNodesAccountDB == nil, "TravelLog works on its own")
SlashCmdList.TRAVELLOG("")
local history = ns.window.pages[3]
check(ns.window.Tabs[3]:GetText() == "History" and #history.views == 2 and history.views[1]:IsShown()
	and #history.viewButtons == 2 and history.viewButtons[2]:GetText() == "Sessions", "History has only Events and Sessions")
SlashCmdList.TRAVELLOG("")
check(TravelLogCharDB.log[#TravelLogCharDB.log].source == "Peacebloom" and not TravelLogCharDB.log[#TravelLogCharDB.log].lastHere, "loot recorded without nodes")
check(TravelLogCharDB.sessions[1].track and TravelLogCharDB.nodes[1436], "the old path and nodes are left alone")
M.Logout()

M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes" }
ns = M.Login()
local moved = PathDB().sessions[1]
check(not TravelLogCharDB.sessions[1].track and not TravelLogCharDB.nodes, "installing the companions moves the old data out of TravelLog's file")
check(moved.start == 1759990000 and moved.stop == 1759993600 and moved.jumpCount == 2 and #moved.track == 1 and #moved.jumps == 1, "old path moved whole")
check(#PathDB().sessions == 2 and PathDB().sessions[2].start == TravelLogCharDB.sessions[3].start, "path sessions in order, the new one last (none for the login without it)")
check(TravelLogNodesAccountDB.maps[1436][1].kind == "ore", "old nodes moved")
SlashCmdList.TRAVELLOG("trail week")
M.viewMap = 1436
M.frame()
local overlay = M.mapOverlay(2010)
check(#M.shown(overlay.lines) == 1 and #M.shown(overlay.textures) == 1, "the moved path and its jump are drawn")
M.Logout()
