-- Alts' trails and trail ranges: the path moving to the account-wide file,
-- alts drawn in their class color, ranges by hours, days and calendar day,
-- the window's alt rows, the archive and wiping.
local HOUR, DAY = 3600, 86400
M.installed = { "TravelLog", "TravelLog_Path", "TravelLog_Archive" }
M.now = os.time({ year = 2025, month = 10, day = 9, hour = 12 })
local TODAY = os.date("%Y-%m-%d", M.now)
local YESTERDAY = os.date("%Y-%m-%d", M.now - DAY)

local function said(pattern)
	for _, line in ipairs(M.out) do
		if line:find(pattern) then return true end
	end
	return false
end

-- Visible trail lines on the shown map, split by whose they are: yours on
-- sublevel 0, alts' on -1.
local function Lines()
	M.frame()
	local mine, alts = {}, {}
	for _, l in ipairs(M.shown(M.mapOverlay(2010).lines)) do
		if l.sublevel == -1 then alts[#alts + 1] = l else mine[#mine + 1] = l end
	end
	return mine, alts
end

local function Walk(seconds)
	for _ = 1, seconds do
		M.x, M.wb = M.x + 0.01, M.wb - 20
		M.tick(1)
	end
end

--------------------------------------------------------------------------------
-- A path from version 0.1, in the character's own file, moves to the
-- account-wide one
--------------------------------------------------------------------------------

M.savedChar["Rasmus-Forever"] = { TravelLog_Path = ([[
TravelLogPathDB = { ["sessions"] = { { ["start"] = %d, ["stop"] = %d,
	["track"] = { "0,1429,30.00,30.00,0,-9100.0,-200.0,0;60,1429,40.00,30.00,0,-9100.0,-300.0,0" }, ["jumps"] = {} } } }
]]):format(M.now - DAY, M.now - DAY + HOUR) }
local ns = M.Login()
local path = M.ns("TravelLog_Path")
check(TravelLogPathDB == nil and #path.db.sessions == 2 and path.db.sessions[1].start == M.now - DAY,
	"old per-character path moved into the account-wide file")
check(TravelLogPathAccountDB.chars["Rasmus-Forever"] == path.db, "kept under the character's name")
Walk(10)
M.Logout()
check(M.savedSize("TravelLog_Path", true) == 0 and M.saved.TravelLog_Path:find('"Rasmus%-Forever"'), "saved account-wide only")

--------------------------------------------------------------------------------
-- Ranges for your own trail
--------------------------------------------------------------------------------

ns = M.Login()
path = M.ns("TravelLog_Path")
M.viewMap = 1429
local mine, alts = Lines()
check(#mine == 4 and #alts == 0, "today: this morning's walk, no alts: " .. #mine)
local today = #mine

SlashCmdList.TRAVELLOG("trail yesterday")
check(ns.settings.trail == YESTERDAY, "yesterday saved as a date: " .. ns.settings.trail)
mine = Lines()
check(#mine == 1 and mine[1].color[1] == 1, "yesterday: only yesterday's line")

SlashCmdList.TRAVELLOG("trail 2d")
check(#Lines() == today + 1, "last 2 days: both")
M.out = {}
SlashCmdList.TRAVELLOG("trail session")
check(said("map trail: latest session") and #Lines() == 0, "this session: nothing walked yet")

M.advance(2 * HOUR)
Walk(10)
SlashCmdList.TRAVELLOG("trail 1h")
mine = Lines()
check(#mine == today, "last hour: only the newest walk: " .. #mine)
M.advance(HOUR + 61)
mine = Lines()
check(#mine == 0, "last hour ages off while the map stays open: " .. #mine)
M.out = {}
SlashCmdList.TRAVELLOG("trail 1h")
check(said("map trail: last hour"), "described in chat")

-- Bad ranges show the help and change nothing.
for _, bad in ipairs({ "0h", "2025-02-30", "fortnight", "alts" }) do
	M.out = {}
	SlashCmdList.TRAVELLOG("trail " .. bad)
	check(ns.settings.trail == "1h" and said("/tl trail %[alts%]"), "rejected: " .. bad)
end
M.out = {}
SlashCmdList.TRAVELLOG("help")
check(said("now: last hour, alts: off"), "help shows both ranges")
SlashCmdList.TRAVELLOG("trail today")
M.Logout()

--------------------------------------------------------------------------------
-- An alt sees your trail in your class color, below its own
--------------------------------------------------------------------------------

M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
M.x, M.wb = 0.30, -100
ns = M.Login()
path = M.ns("TravelLog_Path")
local list = path.Alts()
check(#list == 1 and list[1].key == "Rasmus-Forever" and list[1].profile.class == "MAGE", "Rasmus is an alt of Altie")
Walk(10)
mine, alts = Lines()
check(#mine == 4 and #alts == 0, "alts' trails are off by default")

SlashCmdList.TRAVELLOG("trail alts today")
check(ns.settings.altTrail == "today" and ns.settings.trail == "today", "alts' range set apart from yours")
mine, alts = Lines()
check(#alts == today * 2, "Rasmus's walks today drawn: " .. #alts)
local a = alts[1]
check(a.color[1] == 0.25 and a.color[2] == 0.78 and a.color[4] == 0.7 and a.thickness < mine[1].thickness,
	"in mage blue, thinner and fainter than yours")
check(#M.shown(M.mapOverlay(2010).textures) == 0, "no markers or jumps for alts")

SlashCmdList.TRAVELLOG("trail alts session")
_, alts = Lines()
check(#alts == today, "an alt's session is its latest one")
SlashCmdList.TRAVELLOG("trail off")
mine, alts = Lines()
check(M.mapOverlay(2010).shown and #mine == 0 and #alts == today, "your trail off, alts' still shown")

--------------------------------------------------------------------------------
-- The window: day steppers, alts' rows and a checkbox per alt
--------------------------------------------------------------------------------

local function Button(w, text, n)
	for _, child in ipairs(M.descendants(w)) do
		if child.kind == "Button" and child:GetText() == text then
			n = (n or 1) - 1
			if n == 0 then return child end
		end
	end
end
local function Text(w, pattern, n)
	for _, fs in ipairs(M.descendants(w)) do
		if fs.kind == "FontString" and fs:GetText():find(pattern) then
			n = (n or 1) - 1
			if n == 0 then return fs end
		end
	end
end

SlashCmdList.TRAVELLOG("trail today")
SlashCmdList.TRAVELLOG("")
local w = ns.window
check(Text(w, "^Your trail$") and Text(w, "^Alts' trail$"), "alts' rows")
local alt
for _, child in ipairs(M.descendants(w)) do
	if child.kind == "CheckButton" and child.Text:GetText():find("Rasmus-Forever", 1, true) then alt = child end
end
check(alt and alt.Text:GetText() == "|cff3fc7ebRasmus-Forever|r, level 5" and alt:GetChecked(),
	"a checkbox per alt, in its class color: " .. alt.Text:GetText())
check(alt.point[2] == Button(w.pages[2], "<", 2).point[2] - 4, "lined up under the alts' trail")
check(Text(w, "^today$") and Text(w, "^latest session$"), "steppers show the ranges")

-- Your day: back from today to yesterday and the day before, forward to today.
Button(w.pages[2], "<", 1):Click()
check(ns.settings.trail == YESTERDAY and Text(w, "^" .. os.date("%a %d %b", M.now - DAY) .. "$"), "< steps to yesterday")
Button(w.pages[2], "<", 1):Click()
check(ns.settings.trail == os.date("%Y-%m-%d", M.now - 2 * DAY), "and the day before")
Button(w.pages[2], ">", 1):Click()
Button(w.pages[2], ">", 1):Click()
check(ns.settings.trail == "today", "> back to today")
Button(w.pages[2], ">", 1):Click()
check(ns.settings.trail == "today", "not past today")
Button(w.pages[2], "<", 2):Click()
check(ns.settings.altTrail == YESTERDAY and ns.settings.trail == "today", "alts' stepper changes only theirs")
_, alts = Lines()
check(#alts == 1, "Rasmus's day yesterday")
Button(w, "24h", 2):Click()
check(ns.settings.altTrail == "24h" and Text(w, "^last 24 hours$"), "alts' preset buttons")

alt:Click()
_, alts = Lines()
check(ns.settings.hiddenAlts["Rasmus-Forever"] and #alts == 0, "unchecking an alt hides its trail")
alt:Click()
_, alts = Lines()
check(not ns.settings.hiddenAlts["Rasmus-Forever"] and #alts > 0, "checking shows it again")

--------------------------------------------------------------------------------
-- "all" reads an alt's archived path; wiping removes only your own
--------------------------------------------------------------------------------

M.saved.TravelLog_Archive = ([[
TravelLogArchiveDB = { ["chars"] = { ["Rasmus-Forever"] = { ["path"] = { { ["start"] = %d, ["stop"] = %d,
	["track"] = { "0,1429,50.00,50.00,0,-9200.0,-500.0,0;60,1429,60.00,50.00,0,-9200.0,-600.0,0" } } } } } }
]]):format(M.now - 30 * DAY, M.now - 30 * DAY + HOUR)
TravelLogDB.archive = { size = 500 }
SlashCmdList.TRAVELLOG("trail alts week")
local week = #select(2, Lines())
SlashCmdList.TRAVELLOG("trail alts all")
_, alts = Lines()
check(C_AddOns.IsAddOnLoaded("TravelLog_Archive") and #alts == week + 1, "alts' archived path drawn with all")

SlashCmdList.TRAVELLOG("wipe confirm")
M.Logout()
check(not M.saved.TravelLog_Path:find('"Altie%-Forever"') and M.saved.TravelLog_Path:find('"Rasmus%-Forever"'),
	"wipe removes only this character's path")
M.player = { name = "Rasmus", realm = "Forever" }
ns = M.Login()
check(#M.ns("TravelLog_Path").Alts() == 0, "the wiped alt is gone from Rasmus's alts")
M.Logout()
