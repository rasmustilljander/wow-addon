-- Gear: what you wear at the first login is remembered, not logged; each
-- item you put on after that is logged once (with slot, item level, quality
-- and what it replaced), not shirts or tabards, not swaps back, not after a
-- reload; its totals, /tl log and History group; a character that logs in
-- with nothing on. Enchants on worn gear (after a cast, not swapped copies or
-- temporary ones) and the first time each bag is equipped.
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
check(line and line:find("new gear 5, bags 0, enchants 0$"), "stats line: " .. tostring(line))
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

-- Enchants and bags: what's on at the first login is remembered, not logged.
local function Enchanted(id, enchant, name)
	return ("|cffffffff|Hitem:%d:%d:::::::5:::::|h[%s]|h|r"):format(id, enchant, name)
end
local ENCHANT_SPELL = 20034
M.enchantNames = { [1897] = "+5 Weapon Damage", [1900] = "Crusader", [41] = "+5 Health" }
local SWORD_DMG, SWORD_CRUSADER = Enchanted(103, 1897, "Sword"), Enchanted(103, 1900, "Sword")
local LINEN, POUCH, BIG_BAG = Link(300, "Linen Bag"), Link(301, "Small Pouch"), Link(302, "Traveler's Backpack", "1eff00")
M.items[301], M.items[302] = { quality = 1 }, { quality = 2 }
M.Logout()
M.player = { name = "Enchanter", realm = "Forever" }
M.equipped = { [5] = VEST, [16] = SWORD_DMG, [31] = LINEN }
M.bagSlots[1] = 6
ns = M.Login()
check(TravelLogCharDB.bags and TravelLogCharDB.bags[300] == 0, "worn bag remembered")
check(count("enchant") == 0 and count("bag") == 0 and count("equip") == 0, "nothing logged at first login")

-- Enchanting the sword: only UNIT_INVENTORY_CHANGED says so.
M.advance(10)
M.cast(ENCHANT_SPELL)
M.equipped[16] = SWORD_CRUSADER
M.fire("UNIT_INVENTORY_CHANGED", "player")
e = last("enchant")
check(count("enchant") == 1 and e.slot == 16 and e.item == SWORD_CRUSADER and e.enchant == 1900 and e.name == "Crusader"
	and e.old == 1897 and e.oldName == "+5 Weapon Damage", "new enchant logged")
check(ns.Describe(e) == "Enchanted " .. SWORD_CRUSADER .. " (main hand): Crusader, replacing +5 Weapon Damage",
	"described: " .. ns.Describe(e))
check(ns.LogGroup(e) == "Progress" and ns.LogTypeLabel(e) == "Enchant" and ns.LogMatches(e, "crusader", "Progress"),
	"group, label and search")
check(count("equip") == 0 and ns.stats.enchants == 1, "counted, not new gear")
M.fire("UNIT_INVENTORY_CHANGED", "player")
M.fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
check(count("enchant") == 1, "logged once")

-- A first enchant on the chest, reported as an equipment change.
M.advance(10)
M.cast(ENCHANT_SPELL)
local VEST_HEALTH = Enchanted(101, 41, "Vest")
M.equip(5, VEST_HEALTH)
e = last("enchant")
check(count("enchant") == 2 and e.slot == 5 and e.enchant == 41 and e.name == "+5 Health" and not e.old and not e.oldName,
	"first enchant logged")
check(ns.Describe(e) == "Enchanted " .. VEST_HEALTH .. " (chest): +5 Health", "described: " .. ns.Describe(e))

-- Swapping in another copy of the sword without a cast isn't an enchant.
M.advance(10)
M.equip(16, SWORD_DMG)
check(count("enchant") == 2 and count("equip") == 0, "swapped copy not logged")

-- A poison on the sword, then wearing off: temporary.
M.cast(ENCHANT_SPELL)
M.tempEnchants[0] = 7
M.equipped[16] = Enchanted(103, 7, "Sword")
M.fire("UNIT_INVENTORY_CHANGED", "player")
M.tempEnchants[0] = nil
M.equipped[16] = SWORD_DMG
M.fire("UNIT_INVENTORY_CHANGED", "player")
check(count("enchant") == 2, "temporary enchant not logged")

-- Another item in the slot right after a cast is new gear, not an enchant.
M.advance(10)
M.cast(ENCHANT_SPELL)
M.equip(16, Enchanted(202, 1900, "Big Axe"))
check(count("enchant") == 2 and count("equip") == 1 and last("equip").replaced == SWORD_DMG, "other item not an enchant")

-- Bags: a new one in an empty slot, a bigger one replacing the first, and
-- the first one back.
M.equipBag(2, POUCH, 8)
e = last("bag")
check(count("bag") == 1 and e.bag == 2 and e.item == POUCH and e.slots == 8 and e.quality == 1 and not e.replaced,
	"new bag logged")
check(ns.Describe(e) == "Equipped bag " .. POUCH .. " (8 slots)", "described: " .. ns.Describe(e))
check(ns.LogGroup(e) == "Progress" and ns.LogTypeLabel(e) == "Bag", "bag group and label")
M.equipBag(1, BIG_BAG, 14)
e = last("bag")
check(count("bag") == 2 and e.bag == 1 and e.slots == 14 and e.quality == 2 and e.replaced == LINEN, "bigger bag logged")
check(ns.Describe(e) == "Equipped bag " .. BIG_BAG .. " (14 slots), replacing " .. LINEN, "described: " .. ns.Describe(e))
M.equipBag(1, LINEN, 6)
M.equipBag(2, nil)
check(count("bag") == 2 and ns.stats.bags == 2, "known bag and taking off not logged")

-- After a reload, bags are still known.
ns = M.Reload()
check(TravelLogCharDB.bags[301] and TravelLogCharDB.bags[302] and TravelLogCharDB.bags[300] == 0, "bags saved")
M.equipBag(2, BIG_BAG, 14)
check(count("bag") == 2, "known bag not logged after reload")
M.out = {}
SlashCmdList.TRAVELLOG("stats")
line = nil
for _, text in ipairs(M.out) do line = line or text:match("Spells learned .*") end
check(line and line:find("new gear 1, bags 2, enchants 2$"), "stats line: " .. tostring(line))
M.out = {}
SlashCmdList.TRAVELLOG("log 5 enchanted")
check(#M.out == 3 and M.out[2]:find("Crusader, replacing", 1, true) and M.out[3]:find("+5 Health", 1, true),
	"/tl log: " .. table.concat(M.out, " / "))

-- A character with no bags remembers its first one.
M.Logout()
M.player = { name = "Bagless", realm = "Forever" }
M.equipped = {}
ns = M.Login()
check(TravelLogCharDB.bags == nil, "no bags to remember")
M.equipBag(1, POUCH, 8)
check(TravelLogCharDB.bags[301] == 0 and count("bag") == 0, "first bag remembered, not logged")
M.equipBag(2, LINEN, 6)
check(count("bag") == 1 and last("bag").item == LINEN, "then new bags are logged")
