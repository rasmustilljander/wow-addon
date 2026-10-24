-- Time per zone: counted every second you're logged in (AFK too), subzones
-- in their zone, a zone change, a loading screen, a secret zone name, a
-- reload and a night logged out; /tl stats, the Totals row's top three, an
-- alt and all added up.
local ns = M.Login() -- in Elwynn Forest, Goldshire

local function seconds(zone) return (ns.stats.zoneTime or {})[zone] end
local function Stat(label)
	local all = M.descendants(ns.window)
	for i, r in ipairs(all) do
		if r.kind == "FontString" and r:GetText() == label then return all[i + 1]:GetText() end
	end
end
local function StatsLine(arg)
	M.out = {}
	SlashCmdList.TRAVELLOG("stats " .. (arg or ""))
	for _, text in ipairs(M.out) do
		local line = text:match("Time by zone: (.*)")
		if line then return line end
	end
end

M.tick(100)
check(seconds("Elwynn Forest") == 100, "counted every second: " .. tostring(seconds("Elwynn Forest")))

-- A new subzone stays in its zone.
M.subzone = "Northshire Valley"
M.fire("ZONE_CHANGED")
M.tick(20)
check(seconds("Elwynn Forest") == 120 and seconds("Northshire Valley") == nil, "subzones count for the zone")

-- AFK time counts too.
M.afk = true
M.fire("PLAYER_FLAGS_CHANGED", "player")
M.tick(30)
M.afk = false
M.fire("PLAYER_FLAGS_CHANGED", "player")
check(seconds("Elwynn Forest") == 150, "AFK counted")

-- Into Westfall: what came before stays with Elwynn.
M.zone, M.subzone = "Westfall", "Sentinel Hill"
M.fire("ZONE_CHANGED_NEW_AREA")
M.tick(50)
check(seconds("Elwynn Forest") == 150 and seconds("Westfall") == 50, "a new zone")

-- A loading screen (no ticks) counts for the zone you left.
M.advance(10)
M.zone, M.subzone = "Stormwind City", "Trade District"
M.fire("PLAYER_ENTERING_WORLD", false, false)
check(seconds("Westfall") == 60 and seconds("Stormwind City") == nil, "the loading screen goes to Westfall")
M.tick(30)

-- An unreadable zone name keeps counting for the last one.
M.secrets["Ironforge"] = true
M.zone, M.subzone = "Ironforge", ""
M.fire("ZONE_CHANGED_NEW_AREA")
M.tick(20)
check(seconds("Stormwind City") == 50 and seconds("Ironforge") == nil, "secret zone name")
M.secrets["Ironforge"] = nil
M.zone, M.subzone = "Stormwind City", "Trade District"
M.fire("ZONE_CHANGED_NEW_AREA")

-- A reload counts each second once: up to the logout, then from the login.
M.advance(5)
ns = M.Reload()
check(seconds("Stormwind City") == 55, "saved at the reload: " .. tostring(seconds("Stormwind City")))
check(TravelLogDB.chars["Rasmus-Forever"].stats.zoneTime["Westfall"] == 60, "in the account file")
M.tick(10)
check(seconds("Stormwind City") == 65, "no double count after the reload: " .. tostring(seconds("Stormwind City")))

-- A night logged out isn't counted.
M.Logout()
M.advance(8 * 3600)
ns = M.Login()
M.tick(15)
check(seconds("Stormwind City") == 80, "time logged out left out: " .. tostring(seconds("Stormwind City")))

-- A fourth zone, for "1 more".
M.zone, M.subzone = "Duskwood", "Darkshire"
M.fire("ZONE_CHANGED_NEW_AREA")
M.tick(5)

-- /tl stats lists every zone, longest first; the Totals row the top three.
check(StatsLine() == "Elwynn Forest 2m, Stormwind City 1m, Westfall 1m, Duskwood under a minute", "/tl stats: " .. tostring(StatsLine()))
SlashCmdList.TRAVELLOG("")
check(Stat("Time by zone") == "Elwynn Forest 2m, Stormwind City 1m, Westfall 1m, 1 more", "Totals row: " .. tostring(Stat("Time by zone")))

-- An alt's own time, the main's, and all added up.
M.Logout()
M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
M.zone, M.subzone = "Elwynn Forest", "Goldshire"
ns = M.Login()
SlashCmdList.TRAVELLOG("")
check(Stat("Time by zone") == "none", "the alt starts with none: " .. tostring(Stat("Time by zone")))
M.tick(3600)
ns.RefreshWindow()
check(Stat("Time by zone") == "Elwynn Forest 1h 0m", "the alt's: " .. tostring(Stat("Time by zone")))
local function Step()
	for _, r in ipairs(M.descendants(ns.window.pages[1])) do
		if r.kind == "Button" and r:GetText() == ">" then r:Click() return end
	end
end
Step()
check(Stat("Time by zone") == "Elwynn Forest 2m, Stormwind City 1m, Westfall 1m, 1 more", "the main's: " .. tostring(Stat("Time by zone")))
Step()
check(Stat("Time by zone") == "Elwynn Forest 1h 2m, Stormwind City 1m, Westfall 1m, 1 more", "all added up: " .. tostring(Stat("Time by zone")))
check(StatsLine("all") == "Elwynn Forest 1h 2m, Stormwind City 1m, Westfall 1m, Duskwood under a minute", "/tl stats all: " .. tostring(StatsLine("all")))
check(StatsLine("rasmus") == "Elwynn Forest 2m, Stormwind City 1m, Westfall 1m, Duskwood under a minute", "/tl stats rasmus")
check(#M.errors == 0, "no errors")
