-- Gear: what you wear at the first login is remembered, not logged; each
-- item you put on after that is logged once (with slot, item level, quality
-- and what it replaced), not shirts or tabards, not swaps back, not after a
-- reload; its totals, /tl log and History group; a character that logs in
-- with nothing on.
local function Link(id, name, color)
	return ("|cff%s|Hitem:%d::::::::5:::::|h[%s]|h|r"):format(color or "ffffff", id, name)
end
local CAP, VEST, SHIRT, SWORD = Link(100, "Cap"), Link(101, "Vest"), Link(102, "Shirt"), Link(103, "Sword")
local MAIL, TABARD, AXE, BOOTS = Link(200, "Chain Vest", "1eff00"), Link(201, "Tabard"), Link(202, "Big Axe"), Link(203, "Boots")
M.items[200] = { quality = 2, level = 14 }
M.items[202] = { quality = 3, level = 18 }
M.items[203] = { uncached = true }
M.equipped = { [1] = CAP, [4] = SHIRT, [5] = VEST, [16] = SWORD }
local ns = M.Login()

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end

-- What you wear at the first login is remembered, not logged; the shirt isn't.
local gear = TravelLogCharDB.gear
check(gear and gear[100] == 0 and gear[101] == 0 and gear[103] == 0 and not gear[102], "worn gear remembered")
check(count("equip") == 0 and not ns.stats.gear, "worn gear not logged")

-- A new chest piece: slot, link, item level, quality and the old one.
M.equip(5, MAIL)
local e = last("equip")
check(count("equip") == 1 and e.slot == 5 and e.item == MAIL and e.ilvl == 14 and e.quality == 2 and e.replaced == VEST,
	"new chest logged")
check(e.zone == "Elwynn Forest" and e.x, "stamped with where")
check(ns.Describe(e) == "Equipped " .. MAIL .. " (chest, item level 14), replacing " .. VEST, "described: " .. ns.Describe(e))
check(ns.LogGroup(e) == "Progress" and ns.LogTypeLabel(e) == "Gear", "group and label")
check(ns.LogMatches(e, "gear", "Progress") and ns.LogMatches(e, "chain vest") and not ns.LogMatches(e, "gear", "Loot"),
	"found by filter and search")
check(TravelLogCharDB.gear[200] and ns.stats.gear == 1, "remembered and counted")

-- Back to the old vest, and to the new one again: both known.
M.equip(5, VEST)
M.equip(5, MAIL)
check(count("equip") == 1, "swaps back not logged")

-- Shirts and tabards are left out.
M.equip(4, nil)
M.equip(4, Link(204, "Fancy Shirt"))
M.equip(19, TABARD)
check(count("equip") == 1 and not TravelLogCharDB.gear[201] and not TravelLogCharDB.gear[204], "shirt and tabard skipped")

-- Taking the sword off, then a two-hander into the empty hand.
M.equip(16, nil)
check(count("equip") == 1, "taking off not logged")
M.equip(16, AXE)
e = last("equip")
check(count("equip") == 2 and e.item == AXE and e.ilvl == 18 and e.quality == 3 and not e.replaced, "two-hander logged")
check(ns.Describe(e) == "Equipped " .. AXE .. " (main hand, item level 18)", "described: " .. ns.Describe(e))

-- An item the client hasn't loaded yet: logged without level or quality.
M.equip(8, BOOTS)
e = last("equip")
check(count("equip") == 3 and e.item == BOOTS and not e.ilvl and not e.quality and e.slot == 8, "uncached item logged")
check(ns.Describe(e) == "Equipped " .. BOOTS .. " (feet)", "described: " .. ns.Describe(e))

-- An unreadable link isn't remembered, so it's logged once it can be read.
local CLOAK = Link(205, "Cloak")
M.secrets[CLOAK] = true
M.equip(15, CLOAK)
check(count("equip") == 3 and not TravelLogCharDB.gear[205], "secret link skipped")
M.secrets[CLOAK] = nil
M.equip(15, CLOAK)
check(count("equip") == 4 and TravelLogCharDB.gear[205], "logged once readable")

-- After a reload the gear is still known, and replacing still names the old item.
ns = M.Reload()
check(TravelLogCharDB.gear[200] and TravelLogCharDB.gear[100] == 0, "gear saved")
M.equip(16, SWORD)
M.equip(5, VEST)
check(count("equip") == 4, "known gear not logged after reload")
M.equip(1, Link(206, "Helm"))
check(count("equip") == 5 and last("equip").replaced == CAP, "replaced after reload")

M.out = {}
SlashCmdList.TRAVELLOG("stats")
local line
for _, text in ipairs(M.out) do line = line or text:match("Spells learned .*") end
check(line and line:find("new gear 5$"), "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 2 gear")
check(#M.out == 3 and M.out[2]:find("Equipped " .. CLOAK .. " (back)", 1, true) and M.out[3]:find("[Helm]", 1, true),
	"/tl log: " .. table.concat(M.out, " / "))

-- A character that logs in with nothing on remembers its first item.
M.Logout()
M.player = { name = "Naked", realm = "Forever" }
M.equipped = {}
ns = M.Login()
check(TravelLogCharDB.gear == nil, "nothing to remember")
M.equip(5, VEST)
check(TravelLogCharDB.gear[101] == 0 and count("equip") == 0, "first item remembered, not logged")
M.equip(1, CAP)
check(count("equip") == 1 and last("equip").item == CAP, "then new items are logged")
