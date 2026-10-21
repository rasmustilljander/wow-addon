-- Where TravelLog keeps its data: per-character files, the account-wide
-- file, rotation of old history (TravelLog_Path's too) into the archive
-- addon, and TravelLog with and without its companion addons.
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

-- The size estimate used for rotation is in the right ballpark of the file
ns = M.Login()
AddOldHistory(0.5, 1, 5)
local estimate = ns.Size(TravelLogPathAccountDB)
M.Logout()
local ratio = M.savedSize("TravelLog_Path") / estimate
check(ratio > 0.7 and ratio < 1.5, ("size estimate within range of the real file: %.2f"):format(ratio))

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
-- Rotation into the archive addon
--------------------------------------------------------------------------------

M.saved, M.savedChar = {}, {}
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Archive" }

ns = M.Login()
AddOldHistory(4, 20, 30) -- 4 MB of history from 50 to 20 days ago
TravelLogCharDB.log[#TravelLogCharDB.log + 1] = { type = "level", time = M.now - DAY, level = 6 }
M.Logout()
local before = M.savedSize("TravelLog_Path")
check(before > 3 * 1048576, ("path file is big before rotating: %.1f MB"):format(before / 1048576))

M.out = {}
ns = M.Login()
check(C_AddOns.IsAddOnLoaded("TravelLog_Archive"), "archive loaded for rotation")
check(said("moved 30 sessions, 30 log entries and 30 paths older than 10 days to TravelLog_Archive"), "rotation reported")
local recent = true
for _, s in ipairs(TravelLogCharDB.sessions) do recent = recent and s.start >= M.now - 10 * DAY end
for _, e in ipairs(TravelLogCharDB.log) do recent = recent and e.time >= M.now - 10 * DAY end
for _, s in ipairs(PathDB().sessions) do recent = recent and s.start >= M.now - 10 * DAY end
check(recent and #TravelLogCharDB.sessions == 2 and #PathDB().sessions == 2, "only recent history (last and current session) stays in the character files")
local archived = TravelLogArchiveDB.chars["Rasmus-Forever"]
check(#archived.sessions == 30 and #archived.log == 30 and #archived.path == 30, "old sessions, log and paths are in the archive")
M.Logout()
check(M.savedSize("TravelLog", true) < 100 * 1024 and M.savedSize("TravelLog_Path") < 100 * 1024,
	("character and path files are small after rotating: %d and %d bytes"):format(M.savedSize("TravelLog", true), M.savedSize("TravelLog_Path")))
check(M.savedSize("TravelLog_Archive") > 3 * 1048576, "archive file holds the old history")

ns = M.Login()
check(not C_AddOns.IsAddOnLoaded("TravelLog_Archive"), "archive not loaded at a normal login")
M.out = {}
SlashCmdList.TRAVELLOG("archive")
check(said("Archived so far: about [34]%.%d MB") and not C_AddOns.IsAddOnLoaded("TravelLog_Archive"), "/tl archive reports the size without loading it")
M.Logout()
check(M.savedSize("TravelLog_Archive") > 3 * 1048576, "an unloaded archive's file is left alone")

-- The map's "all" range reads the archive
ns = M.Login()
SlashCmdList.TRAVELLOG("trail all")
M.viewMap = 1429
M.frame()
check(C_AddOns.IsAddOnLoaded("TravelLog_Archive"), "trail all loads the archive")
local overlay = M.mapOverlay(2010)
local purple = 0
for _, t in ipairs(M.shown(overlay.textures)) do if t.color[1] == 0.75 then purple = purple + 1 end end
check(purple >= 1, "archived loot markers drawn")
SlashCmdList.TRAVELLOG("trail today")
M.Logout()

-- A second rotation adds to the same archive
ns = M.Login()
AddOldHistory(4, 20, 10)
M.Logout()
ns = M.Login()
check(#TravelLogArchiveDB.chars["Rasmus-Forever"].sessions == 40, "second rotation appended to the archive")
M.Logout()

-- Without the archive addon installed, history stays put and you're told
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes" }
ns = M.Login()
AddOldHistory(4, 20, 5)
M.Logout()
M.out = {}
ns = M.Login()
check(said("can't open TravelLog_Archive %(MISSING%)"), "missing archive addon reported")
check(#TravelLogCharDB.sessions > 5, "history kept in the main file")
M.out = {}
SlashCmdList.TRAVELLOG("archive")
check(said("TravelLog_Archive isn't installed"), "/tl archive says it isn't installed")
M.Logout()
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes", "TravelLog_Archive" }

-- Once the archive addon is back, the next login catches up
M.out = {}
ns = M.Login()
check(said("moved 5 sessions") and #TravelLogArchiveDB.chars["Rasmus-Forever"].sessions == 45, "rotation catches up once the archive is installed")
M.Logout()

-- "/tl archive now" moves old history right away, even if the file is small
ns = M.Login()
check(not C_AddOns.IsAddOnLoaded("TravelLog_Archive"), "small main file: no rotation at login")
TravelLogCharDB.log[#TravelLogCharDB.log + 1] = { type = "level", time = M.now - 12 * DAY, level = 7 }
M.out = {}
SlashCmdList.TRAVELLOG("archive now")
check(said("moved %d+ sessions, 1 log entries and %d+ paths"), "forced rotation")
M.Logout()

-- An alt's archived history is kept apart and survives the main being wiped
M.player = { name = "Altie", realm = "Forever" }
ns = M.Login()
AddOldHistory(0.1, 20, 2)
SlashCmdList.TRAVELLOG("archive now")
M.Logout()
M.player = { name = "Rasmus", realm = "Forever" }

-- Wiping a character removes it everywhere, the archive included
ns = M.Login()
SlashCmdList.TRAVELLOG("wipe confirm")
check(M.reloadRequested, "wipe reloads the UI")
ns = M.Reload()
check(#TravelLogCharDB.sessions == 1 and #TravelLogCharDB.log <= 1 and #PathDB().sessions == 1, "character history wiped")
check(ns.stats.jumps == nil, "character stats wiped")
ns.ArchivedHistory()
check(TravelLogArchiveDB.chars["Rasmus-Forever"] == nil, "archive no longer holds the character")
check(#TravelLogArchiveDB.chars["Altie-Forever"].sessions == 2, "the alt's archive is untouched")
check(TravelLogDB.archive.size < 1048576, "archive size estimate shrinks after the wipe")
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

--------------------------------------------------------------------------------
-- Paths archived before TravelLog_Path existed are still drawn
--------------------------------------------------------------------------------

M.saved, M.savedChar = {
	TravelLog = [[TravelLogDB = { ["archive"] = { ["size"] = 2000 } }]],
	TravelLog_Archive = [[
TravelLogArchiveDB = { ["chars"] = { ["Rasmus-Forever"] = {
	["sessions"] = { { ["start"] = 1750000000, ["stop"] = 1750003600,
		["track"] = { "1,1436,40.00,40.00,0,-10000.0,-1000.0,0;9,1436,42.00,41.00,0,-10010.0,-1010.0,0" }, ["jumps"] = {} } },
	["log"] = {},
} } }
]] }, {}
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Archive" }
ns = M.Login()
SlashCmdList.TRAVELLOG("trail all")
M.viewMap = 1436
M.frame()
overlay = M.mapOverlay(2010)
check(#M.shown(overlay.lines) == 1, "an archived old-style path is drawn")
M.Logout()
