-- Where TravelLog keeps its data: per-character files, the account-wide
-- file, and rotation of old history into the archive addons.
local DAY = 86400
local ARCHIVES = { "TravelLog_Archive1", "TravelLog_Archive2", "TravelLog_Archive3", "TravelLog_Archive4" }

local function said(pattern)
	for _, line in ipairs(M.out) do
		if line:find(pattern) then return true end
	end
	return false
end

-- Adds `days` worth of fake old sessions (about `mb` MB in total) to the
-- current character, ending `ago` days back.
local function AddOldHistory(mb, ago, days)
	local record = "120,1429,42.10,65.30,0,-9000.0,-100.0,0"
	local chunk = (record .. ";"):rep(199) .. record -- ~8.5 KB
	local chunks = math.floor(mb * 1048576 / #chunk)
	local perSession = math.ceil(chunks / days)
	local start = M.now - (ago + days) * DAY
	local sessions, log = {}, {}
	for d = 1, days do
		local s = { start = start + d * DAY, stop = start + d * DAY + 3600, track = {}, jumps = {} }
		for _ = 1, perSession do s.track[#s.track + 1] = chunk end
		sessions[#sessions + 1] = s
		log[#log + 1] = { type = "loot", time = s.start + 60, map = 1429, x = 42.1, y = 65.3, source = "Old Kobold" }
	end
	local char = TravelLogCharDB
	for i = #sessions, 1, -1 do table.insert(char.sessions, 1, sessions[i]) end
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
check(not M.saved.TravelLog:find('%["sessions"%]'), "account-wide file has no sessions")
check(M.saved.TravelLog:find('%["Rasmus%-Forever"%]'), "account-wide file has the character's profile")

M.player = { name = "Altie", realm = "Forever" }
ns = M.Login()
check(#TravelLogCharDB.sessions == 1 and #TravelLogCharDB.log <= 2, "an alt starts with its own empty history")
check(TravelLogDB.chars["Rasmus-Forever"] and TravelLogDB.chars["Altie-Forever"], "both profiles in the account file")
M.Logout()
M.player = { name = "Rasmus", realm = "Forever" }
ns = M.Login()
check(#TravelLogCharDB.sessions == 2 and ns.stats.jumps == 1, "back on the main, its history is back")
M.Logout()

-- The size estimate used for rotation is in the right ballpark of the file
ns = M.Login()
AddOldHistory(0.5, 1, 5)
local estimate = ns.Size(TravelLogCharDB)
M.Logout()
local ratio = M.savedSize("TravelLog", true) / estimate
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
check(TravelLogCharDB.quests[54].title == "Report to Goldshire", "v1 quests moved")
check(TravelLogDB.chars["Rasmus-Forever"].log == nil and TravelLogDB.version == 2, "account file cleaned up")
check(ns.stats.jumps == 42 and ns.settings.interval == 3, "stats and settings kept")
M.Logout()

--------------------------------------------------------------------------------
-- Rotation into the archive addons
--------------------------------------------------------------------------------

M.saved, M.savedChar = {}, {}
for _, name in ipairs(ARCHIVES) do M.installed[#M.installed + 1] = name end

ns = M.Login()
AddOldHistory(4, 20, 30) -- 4 MB of history from 50 to 20 days ago
TravelLogCharDB.log[#TravelLogCharDB.log + 1] = { type = "level", time = M.now - DAY, level = 6 }
M.Logout()
local before = M.savedSize("TravelLog", true)
check(before > 3 * 1048576, ("main file is big before rotating: %.1f MB"):format(before / 1048576))

M.out = {}
ns = M.Login()
check(C_AddOns.IsAddOnLoaded("TravelLog_Archive1"), "archive slot 1 loaded for rotation")
check(said("moved 30 sessions and 30 log entries older than 10 days to TravelLog_Archive1"), "rotation reported")
local recent = true
for _, s in ipairs(TravelLogCharDB.sessions) do recent = recent and s.start >= M.now - 10 * DAY end
for _, e in ipairs(TravelLogCharDB.log) do recent = recent and e.time >= M.now - 10 * DAY end
check(recent and #TravelLogCharDB.sessions == 2, "only recent history (last and current session) stays in the main file")
check(#TravelLogArchive1.chars["Rasmus-Forever"].sessions == 30, "old sessions are in the archive")
M.Logout()
check(M.savedSize("TravelLog", true) < 100 * 1024, ("main file is small after rotating: %d bytes"):format(M.savedSize("TravelLog", true)))
check(M.savedSize("TravelLog_Archive1") > 3 * 1048576, "archive file holds the old history")

ns = M.Login()
check(not C_AddOns.IsAddOnLoaded("TravelLog_Archive1"), "archive not loaded at a normal login")
M.Logout()
check(M.savedSize("TravelLog_Archive1") > 3 * 1048576, "an unloaded archive's file is left alone")

-- The map's "all" range reads the archive
ns = M.Login()
SlashCmdList.TRAVELLOG("trail all")
M.viewMap = 1429
M.frame()
check(C_AddOns.IsAddOnLoaded("TravelLog_Archive1"), "trail all loads the archive")
local overlay = M.mapOverlay()
local purple = 0
for _, t in ipairs(M.shown(overlay.textures)) do if t.color[1] == 0.75 then purple = purple + 1 end end
check(purple >= 1, "archived loot markers drawn")
SlashCmdList.TRAVELLOG("trail today")
M.Logout()

-- A full slot sends new history to the next one
ns = M.Login()
TravelLogDB.archive.sizes[1] = 9 * 1048576
AddOldHistory(4, 20, 10)
M.Logout()
ns = M.Login()
check(C_AddOns.IsAddOnLoaded("TravelLog_Archive2") and TravelLogDB.archive.slot == 2, "rotation moved on to slot 2")
check(#TravelLogArchive2.chars["Rasmus-Forever"].sessions == 10, "new old history in slot 2")
M.out = {}
SlashCmdList.TRAVELLOG("archive")
check(said("TravelLog_Archive1: about 9.0 MB") and said("TravelLog_Archive2: about .+ %(in use%)"), "/tl archive lists both slots")
M.Logout()

-- Without the archive addons installed, history stays put and you're told
M.installed = { "TravelLog" }
ns = M.Login()
AddOldHistory(4, 20, 5)
M.Logout()
M.out = {}
ns = M.Login()
check(said("can't open TravelLog_Archive2 %(MISSING%)"), "missing archive addon reported")
check(#TravelLogCharDB.sessions > 5, "history kept in the main file")
M.Logout()
for _, name in ipairs(ARCHIVES) do M.installed[#M.installed + 1] = name end

-- Once the archive addons are back, the next login catches up
M.out = {}
ns = M.Login()
check(said("moved 5 sessions") and C_AddOns.IsAddOnLoaded("TravelLog_Archive2"), "rotation catches up once the archives are installed")
M.Logout()

-- "/tl archive now" moves old history right away, even if the file is small
ns = M.Login()
check(not C_AddOns.IsAddOnLoaded("TravelLog_Archive2"), "small main file: no rotation at login")
TravelLogCharDB.log[#TravelLogCharDB.log + 1] = { type = "level", time = M.now - 12 * DAY, level = 7 }
M.out = {}
SlashCmdList.TRAVELLOG("archive now")
check(said("moved %d+ sessions and %d+ log entries"), "forced rotation")
M.Logout()

-- Wiping a character removes it everywhere, the archives included
ns = M.Login()
SlashCmdList.TRAVELLOG("wipe confirm")
check(M.reloadRequested, "wipe reloads the UI")
ns = M.Reload()
check(#TravelLogCharDB.sessions == 1 and #TravelLogCharDB.log <= 1, "character history wiped")
check(ns.stats.jumps == nil, "character stats wiped")
check(TravelLogArchive1 == nil or TravelLogArchive1.chars["Rasmus-Forever"] == nil, "archive slot 1 wiped")
ns.ArchivedHistory()
check(TravelLogArchive1.chars["Rasmus-Forever"] == nil and TravelLogArchive2.chars["Rasmus-Forever"] == nil, "archives no longer hold the character")
M.Logout()
