-- Where TravelLog keeps its data: per-character files, the account-wide
-- file, data versions, old history kept in place, and TravelLog with and
-- without its companion addons.
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
-- current character, ending `ago` days back, with their path in
-- TravelLog_Path.
local function AddOldHistory(mb, ago, days)
	local record = "120,1429,42.10,65.30,0,-9000.0,-100.0,0"
	local chunk = (record .. ";"):rep(199) .. record -- ~8.5 KB
	local chunks = math.floor(mb * 1048576 / #chunk)
	local perSession = math.ceil(chunks / days)
	local start = M.now - (ago + days) * DAY
	local sessions, paths, log = {}, {}, {}
	for d = 1, days do
		local s = { start = start + d * DAY, stop = start + d * DAY + 3600 }
		local p = { start = s.start, stop = s.stop, track = {}, jumps = {} }
		for _ = 1, perSession do p.track[#p.track + 1] = chunk end
		sessions[#sessions + 1] = s
		paths[#paths + 1] = p
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
-- The account file's data version: a new file gets the current one, a newer
-- one isn't read
--------------------------------------------------------------------------------

M.saved, M.savedChar = {}, {}
ns = M.Login()
check(TravelLogDB.version == 1, "a new account file gets data version 1")
M.Logout()
check(M.saved.TravelLog:find('%["version"%] = 1'), "and saves it")

local NEWER_ACCOUNT = [[
TravelLogDB = {
	["version"] = 2,
	["players"] = { "a layout this TravelLog doesn't know" },
}
]]
M.saved, M.savedChar = { TravelLog = NEWER_ACCOUNT }, {}
M.out, M.errors = {}, {}
ns = M.Login()
check(said("account file is data version 2") and ns.db == nil and ns.char == nil, "a newer account file isn't read, and chat says so")
M.tick(1)
for _ = 1, 5 do M.x = M.x + 0.001; M.wb = M.wb - 4; M.tick(1) end
JumpOrAscendStart()
M.out = {}
SlashCmdList.TRAVELLOG("")
check(said("account file is data version 2") and ns.window == nil, "/tl says why")
check(#M.errors == 0 and TravelLogDB.chars == nil and TravelLogDB.settings == nil, "nothing recorded, no errors")
check(TravelLogCharDB == nil and PathDB() == nil, "the character file and companions aren't started")
M.Logout()
check(M.saved.TravelLog:find('%["version"%] = 2') and M.saved.TravelLog:find("doesn't know"), "the account file is saved back as it was")

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
M.Logout()
check(M.savedSize("TravelLog_Path") > 3 * 1048576, "large old path stays in TravelLog_Path")

M.out = {}
ns = M.Login()
check(#TravelLogCharDB.sessions == stored.sessions + 1 and #PathDB().sessions == stored.paths + 1,
	"old sessions and paths kept after login")
check(#TravelLogCharDB.log >= stored.log and TravelLogCharDB.log[1].source == "Old Kobold"
	and PathDB().sessions[1].track[1], "old events and path points kept")

-- "all" reads old history directly from the stored path and event log.
SlashCmdList.TRAVELLOG("trail all")
M.viewMap = 1429
M.frame()
local overlay = M.mapOverlay(2010)
local purple = 0
for _, t in ipairs(M.shown(overlay.textures)) do if t.color[1] == 0.75 then purple = purple + 1 end end
check(purple >= 1, "old loot markers drawn from the stored log")

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

M.saved, M.savedChar = {}, {}
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
check(ns.window.Tabs[3]:GetText() == "History" and #history.views == 3 and history.views[1]:IsShown()
	and history.viewButtons[2]:GetText() == "Sessions" and history.viewButtons[3]:GetText() == "Levels", "History has only Events, Sessions and Levels")
SlashCmdList.TRAVELLOG("")
check(TravelLogCharDB.log[#TravelLogCharDB.log].source == "Peacebloom" and not TravelLogCharDB.log[#TravelLogCharDB.log].lastHere, "loot recorded without nodes")
M.Logout()

M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Nodes" }
ns = M.Login()
check(#PathDB().sessions == 1 and PathDB().sessions[1].start == TravelLogCharDB.sessions[2].start
	and next(TravelLogNodesAccountDB.maps) == nil, "companions installed later start from this login")
M.Logout()

--------------------------------------------------------------------------------
-- The character file's data version: a new file gets the current one, a
-- newer one isn't read
--------------------------------------------------------------------------------

M.saved, M.savedChar = {}, {}
ns = M.Login()
check(TravelLogCharDB.version == ns.DATA_VERSION and ns.DATA_VERSION == 1, "a new file gets data version 1")
M.Logout()
check(M.savedChar["Rasmus-Forever"].TravelLog:find('%["version"%] = 1'), "and saves it")

local NEWER_CHAR = [[
TravelLogCharDB = {
	["version"] = 99,
	["entries"] = { "a layout this TravelLog doesn't know" },
}
]]
M.saved, M.savedChar = {}, { ["Rasmus-Forever"] = { TravelLog = NEWER_CHAR } }
M.out, M.errors = {}, {}
ns = M.Login()
check(said("data version 99") and ns.char == nil, "a newer data version isn't read, and chat says so")
M.tick(1)
for _ = 1, 5 do M.x = M.x + 0.001; M.wb = M.wb - 4; M.tick(1) end
JumpOrAscendStart()
M.cast(2366, "Peacebloom")
M.loot = { { name = "Peacebloom", link = "[Peacebloom]", qty = 1, guid = "GameObject-0-1-0-1-1618-00F00D" } }
M.lootAll()
M.out = {}
SlashCmdList.TRAVELLOG("")
check(said("data version 99") and ns.window == nil, "/tl says why instead of opening the window")
M.out = {}
M.compartment.TravelLog:Click()
check(said("data version 99") and ns.window == nil, "so does the addons dropdown")
SlashCmdList.TRAVELLOG("wipe confirm")
check(not M.reloadRequested, "wipe does nothing")
check(#M.errors == 0, "no errors with an unreadable file")
check(TravelLogCharDB.version == 99 and #TravelLogCharDB.entries == 1 and TravelLogCharDB.log == nil
	and TravelLogCharDB.sessions == nil, "nothing recorded into it")
check(PathDB() == nil and TravelLogNodesAccountDB == nil, "the companions don't start either")
M.Logout()
check(M.savedChar["Rasmus-Forever"].TravelLog:find('%["version"%] = 99')
	and M.savedChar["Rasmus-Forever"].TravelLog:find("doesn't know"), "the file is saved back as it was")
