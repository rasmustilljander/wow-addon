-- Time per zone by state: combat, dead and ghost, AFK, flying and grouped,
-- each its own counter (overlapping ones too), next to the zone's total; an
-- unreadable AFK state, a loading screen, a reload; /tl stats (states under a
-- minute left out), the Totals row without them, and all added up.
local ns = M.Login() -- in Elwynn Forest, Goldshire

local function state(name, zone) return ((ns.stats.zoneStateTime or {})[name] or {})[zone] end
local function StatsLine(arg)
	M.out = {}
	SlashCmdList.TRAVELLOG("stats " .. (arg or ""))
	for _, text in ipairs(M.out) do
		local line = text:match("Time by zone: (.*)")
		if line then return line end
	end
end

-- Nothing going on: only the total.
M.tick(10)
check(ns.stats.zoneTime["Elwynn Forest"] == 10 and ns.stats.zoneStateTime == nil, "no states yet")

-- A fight.
M.combat = true
M.tick(90)
M.combat = false
check(state("combat", "Elwynn Forest") == 90, "combat: " .. tostring(state("combat", "Elwynn Forest")))

-- Dead, then a ghost: both count as dead.
M.dead = true
M.tick(40)
M.dead, M.ghost = false, true
M.tick(30)
M.ghost = false
check(state("dead", "Elwynn Forest") == 70, "dead and ghost: " .. tostring(state("dead", "Elwynn Forest")))

-- AFK while grouped: both count.
M.group, M.units.party1 = { "party1" }, { name = "Anna", realm = "Forever", level = 5 }
M.tick(60)
M.afk = true
M.fire("PLAYER_FLAGS_CHANGED", "player")
M.tick(120)
check(state("afk", "Elwynn Forest") == 120 and state("group", "Elwynn Forest") == 180, "AFK while grouped")

-- AFK that can't be read (chat lockdown) isn't counted; the rest still is.
local realAFK, secret = UnitIsAFK, {}
M.secrets[secret] = true
UnitIsAFK = function() return secret end
M.tick(20)
UnitIsAFK = realAFK
check(state("afk", "Elwynn Forest") == 120 and state("group", "Elwynn Forest") == 200, "a secret AFK left out")
M.afk = false
M.fire("PLAYER_FLAGS_CHANGED", "player")
M.group, M.units.party1 = {}, nil
check(ns.stats.zoneTime["Elwynn Forest"] == 370, "the total is all of it: " .. tostring(ns.stats.zoneTime["Elwynn Forest"]))

-- A flight into Westfall: each zone gets its part.
M.taxi = true
M.tick(45)
M.zone, M.subzone = "Westfall", "Sentinel Hill"
M.fire("ZONE_CHANGED_NEW_AREA")
M.tick(75)
M.taxi = false
M.tick(5)
check(state("flight", "Elwynn Forest") == 45 and state("flight", "Westfall") == 75, "flying by zone")
check(ns.stats.zoneTime["Westfall"] == 80, "Westfall's total")

-- A loading screen counts the state you come out in, for the zone you left.
M.combat = true
M.advance(10)
M.zone, M.subzone = "Stormwind City", "Trade District"
M.fire("PLAYER_ENTERING_WORLD", false, false)
M.combat = false
check(state("combat", "Westfall") == 10 and state("combat", "Stormwind City") == nil, "the loading screen")

-- A reload counts each second once.
M.combat = true
M.tick(30)
ns = M.Reload()
check(state("combat", "Stormwind City") == 30, "saved at the reload: " .. tostring(state("combat", "Stormwind City")))
M.tick(40)
M.combat = false
check(state("combat", "Stormwind City") == 70, "no double count: " .. tostring(state("combat", "Stormwind City")))

-- /tl stats: states after each zone, in a fixed order, under a minute left
-- out; the Totals row has none.
check(StatsLine() == "Elwynn Forest 6m (combat 1m, dead 1m, AFK 2m, grouped 3m), Westfall 1m (flying 1m), Stormwind City 1m (combat 1m)",
	"/tl stats: " .. tostring(StatsLine()))
SlashCmdList.TRAVELLOG("")
local text
local all = M.descendants(ns.window)
for i, r in ipairs(all) do
	if r.kind == "FontString" and r:GetText() == "Time by zone" then text = all[i + 1]:GetText() end
end
check(text == "Elwynn Forest 6m, Westfall 1m, Stormwind City 1m", "Totals row: " .. tostring(text))

-- An alt's are added in for all.
M.Logout()
M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
M.zone, M.subzone = "Westfall", "Moonbrook"
ns = M.Login()
M.taxi = true
M.tick(60)
M.taxi = false
check(StatsLine("all"):find("Westfall 2m %(flying 2m%)") ~= nil, "/tl stats all: " .. tostring(StatsLine("all")))
check(StatsLine() == "Westfall 1m (flying 1m)", "the alt's own: " .. tostring(StatsLine()))
check(#M.errors == 0, "no errors")
