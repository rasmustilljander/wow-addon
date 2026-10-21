-- Plays through a short adventure and checks what TravelLog and
-- TravelLog_Path recorded: path, jumps, loot, vendors, money, quests, a
-- flight, a death and the map.
local ns = M.Login()
local path = M.ns("TravelLog_Path")
local KEY = "Rasmus-Forever"

local function last(kind)
	local log = TravelLogCharDB.log
	for i = #log, 1, -1 do
		if not kind or log[i].type == kind then return log[i] end
	end
end
local function count(kind)
	local n = 0
	for _, e in ipairs(TravelLogCharDB.log) do if e.type == kind then n = n + 1 end end
	return n
end

-- Login
check(TravelLogDB.chars[KEY].class == "MAGE", "character profile created")
check(#TravelLogCharDB.sessions == 1, "session started")
check(last("area") and last("area").subzone == "Goldshire" and last("area").first, "first area logged")

-- Walk east for 10 seconds, then stand still
M.tick(1)
for _ = 1, 10 do
	M.x = M.x + 0.001; M.wb = M.wb - 4
	M.tick(1)
end
check(#path.track.buffer >= 5 and #path.track.buffer <= 7, "a path point every 2 s while moving: " .. #path.track.buffer)
local before = #path.track.buffer
M.tick(20)
check(#path.track.buffer == before, "no points while standing still")
check(math.abs(ns.stats.distance.foot - 40) < 0.01, "distance on foot = 40 yd: " .. tostring(ns.stats.distance.foot))

-- Mounting up records a point right away
M.mounted = true
M.tick(1)
check(#path.track.buffer == before + 1, "flag change records a point")
local _, map, x, _, inst, _, _, flags = path.Unpack(path.track.buffer[#path.track.buffer])
check(map == 1429 and math.abs(x - 0.43) < 1e-6 and inst == 0 and flags == 1, "packed point round-trips: " .. path.track.buffer[#path.track.buffer])

-- Jumps
JumpOrAscendStart()
check(ns.stats.jumps == 1, "jump counted")
JumpOrAscendStart()
check(ns.stats.jumps == 1, "second press in the same frame not counted")
M.falling = true; M.frame()
JumpOrAscendStart()
check(ns.stats.jumps == 1, "press while falling not counted")
M.falling = false; M.frame()
JumpOrAscendStart()
check(ns.stats.jumps == 2, "next jump counted")
M.swimming = true; M.frame()
JumpOrAscendStart()
check(ns.stats.jumps == 2, "swimming up not counted")
M.swimming = false; M.frame()
check(ns.stats.jumpsByZone["Elwynn Forest"] == 2, "jumps by zone")
check(path.jumps.buffer[1]:match(",Elwynn Forest,Goldshire$"), "jump record has zone and subzone: " .. path.jumps.buffer[1])
M.mounted = false

-- Loot a corpse with autoloot: an item, coins, and one item left behind
local KOBOLD = "Creature-0-1-0-1-6-0000ABCD"
M.units.target = { name = "Kobold Vermin", guid = KOBOLD, hostile = true }
M.loot = {
	{ name = "Linen Cloth", link = "|cffffffff|Hitem:2589::::|h[Linen Cloth]|h|r", qty = 2, guid = KOBOLD },
	{ name = "12 Copper", qty = 0, type = 2, guid = KOBOLD },
	{ name = "Ruined Pelt", link = "|cff9d9d9d|Hitem:4865::::|h[Ruined Pelt]|h|r", qty = 1, guid = KOBOLD },
}
M.fire("LOOT_READY", true)
M.fire("LOOT_OPENED", true, false)
M.fire("LOOT_SLOT_CLEARED", 1)
M.fire("LOOT_SLOT_CLEARED", 2)
M.fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2589::::|h[Linen Cloth]|h|rx2.")
M.fire("LOOT_CLOSED")
M.money = M.money + 12
M.fire("PLAYER_MONEY") -- coins arrive after the window closed
local loot = last("loot")
check(loot.source == "Kobold Vermin" and loot.sourceType == "Creature" and loot.sourceID == 6, "loot source recorded")
check(#loot.items == 1 and loot.items[1].count == 2, "only taken items recorded")
check(loot.money == 12, "coins attached to the loot event: " .. tostring(loot.money))
check(count("receive") == 0, "loot chat not double-counted")
check(count("money") == 0, "looted coins not logged as separate money rows")
check(ns.stats.money.loot.gained == 12, "money ledger: loot")
M.units.target = nil

-- Herb gathering: the cast names the node
M.cast(2366, "Peacebloom")
M.loot = { { name = "Peacebloom", link = "|cffffffff|Hitem:2447::::|h[Peacebloom]|h|r", qty = 3, guid = "GameObject-0-1-0-1-1618-0000BEEF" } }
M.lootAll()
loot = last("loot")
check(loot.source == "Peacebloom" and loot.via == "Herb Gathering" and loot.sourceID == 1618, "herb named by the cast")

-- Opening a clam from the bags
M.bags["0:1"] = "|cffffffff|Hitem:5523::::|h[Small Barnacled Clam]|h|r"
C_Container.UseContainerItem(0, 1)
M.loot = { { name = "Clam Meat", link = "|cffffffff|Hitem:5503::::|h[Clam Meat]|h|r", qty = 1, guid = "Item-1-0-000F" } }
M.fire("LOOT_OPENED", false, true)
M.fire("LOOT_SLOT_CLEARED", 1)
M.fire("LOOT_CLOSED")
check(last("loot").sourceType == "Item" and last("loot").source:find("Small Barnacled Clam"), "container source recorded")

-- An empty corpse closed without taking anything isn't logged
local nLoot = count("loot")
M.loot = {}
M.fire("LOOT_READY", false); M.fire("LOOT_OPENED", false, false); M.fire("LOOT_CLOSED")
check(count("loot") == nLoot, "nothing taken, nothing logged")

-- Items without a loot window
M.advance(10)
M.fire("CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:2683::::|h[Crab Cake]|h|rx4.")
check(last("receive").how == "created" and last("receive").count == 4, "crafted item")
M.fire("CHAT_MSG_LOOT", "Bob receives loot: |cffffffff|Hitem:1::::|h[Thing]|h|r.")
check(last("receive").how == "created", "other players' loot ignored")
M.secrets["You receive item: [Secret]."] = true
M.fire("CHAT_MSG_LOOT", "You receive item: [Secret].")
check(count("receive") == 1, "secret chat text ignored")

-- Quest: accept, then turn in with money and an item reward
M.quests[54] = "Report to Goldshire"
M.fire("QUEST_ACCEPTED", 54)
check(last("quest").title == "Report to Goldshire", "quest accepted with title")
M.quests[54] = nil -- no longer cached by the client
M.advance(60)
GetQuestReward(1)
M.money = M.money + 75
M.fire("PLAYER_MONEY")
M.fire("CHAT_MSG_LOOT", "You receive item: |cff1eff00|Hitem:2547::::|h[Boots]|h|r.")
M.fire("QUEST_TURNED_IN", 54, 250, 75)
check(last("questdone").title == "Report to Goldshire", "turn-in remembers the title")
check(last("money").reason == "quest" and last("money").amount == 75, "quest money reason")
check(last("receive").how == "quest", "quest reward item")
M.fire("QUEST_REMOVED", 54, false)
check(count("questabandon") == 0, "a turned-in quest leaving the log isn't abandoned")

-- Abandon: a cancelled dialog doesn't count, a confirmed one does
M.quests[60], M.quests[61] = "The Fargodeep Mine", "Kobold Candles"
M.fire("QUEST_ACCEPTED", 60)
M.fire("QUEST_ACCEPTED", 61)
C_QuestLog.SetSelectedQuest(60)
C_QuestLog.SetAbandonQuest() -- dialog shown, then cancelled
M.fire("QUEST_TURNED_IN", 60, 300, 0)
M.fire("QUEST_REMOVED", 60, false)
check(count("questabandon") == 0, "a cancelled abandon isn't recorded")
C_QuestLog.SetSelectedQuest(61)
C_QuestLog.SetAbandonQuest()
C_QuestLog.AbandonQuest()
M.quests[61] = nil
M.fire("QUEST_REMOVED", 61, false)
check(count("questabandon") == 1 and last("questabandon").title == "Kobold Candles", "abandoned quest logged with title")
check(TravelLogCharDB.quests[61].abandoned and not TravelLogCharDB.quests[61].done, "abandoned quest marked")
check(ns.Describe(last("questabandon")) == "Abandoned quest: Kobold Candles", "abandon described")
check(ns.LogMatches(last("questabandon"), "abandon", "Life"), "abandon found under Life")
check(ns.stats.quests.abandoned == 1, "abandon counted")
M.fire("QUEST_REMOVED", 61, false)
check(count("questabandon") == 1, "abandon recorded once")

-- Kill and discovery messages
M.fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Vermin dies, you gain 45 experience. (+22 exp Rested bonus)")
check(last("kill") and last("kill").name == "Kobold Vermin" and last("kill").xp == 45, "kill from the XP message")
M.fire("UI_INFO_MESSAGE", 0, "Discovered Jerod's Landing: 30 experience gained")
M.fire("CHAT_MSG_SYSTEM", "Discovered Jerod's Landing: 30 experience gained")
check(count("discover") == 1 and last("discover").place == "Jerod's Landing" and last("discover").xp == 30, "discovery logged once")

-- Vendor: buy, sell three things, buy one back, repair
M.units.npc = { name = "Brother Danil", guid = "Creature-0-1-0-1-152-0000" }
M.merchantItems[1] = { name = "Refreshing Spring Water", price = 25, stackCount = 5, link = "|cffffffff|Hitem:159::::|h[Refreshing Spring Water]|h|r" }
M.repairCost = 140
M.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Merchant)
M.fire("MERCHANT_SHOW")
check(ns.open.merchant, "merchant window tracked")
BuyMerchantItem(1)    -- one stack of 5
BuyMerchantItem(1, 2) -- 2 bottles via split
check(last("buy").count == 2 and last("buy").price == 10, "split buy priced per item: " .. tostring(last("buy").price))
check(count("buy") == 2 and ns.stats.vendor.spent == 35, "buy totals")
M.buyback = { { name = "Ruined Pelt", link = "[Ruined Pelt]", price = 5, count = 1 } }
M.fire("MERCHANT_UPDATE")
M.buyback[2] = { name = "Ruined Pelt", link = "[Ruined Pelt]", price = 5, count = 1 }
M.buyback[3] = { name = "Linen Cloth", link = "[Linen Cloth]", price = 26, count = 2 }
M.fire("BAG_UPDATE_DELAYED")
check(count("sell") == 3 and ns.stats.vendor.earned == 36, "sales found via the buyback list: " .. count("sell"))
check(last("sell").vendor == "Brother Danil", "vendor name on sale")
BuybackItem(3)
table.remove(M.buyback, 3)
M.fire("MERCHANT_UPDATE")
check(last("buyback") and last("buyback").price == 26 and count("sell") == 3, "buyback logged, not a sale")
RepairAllItems()
check(last("repair") and last("repair").price == 140, "repair cost logged")
M.money = M.money - 140
M.fire("PLAYER_MONEY")
check(last("money").reason == "vendor", "vendor money reason")
M.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Merchant)
M.fire("MERCHANT_CLOSED")
check(not ns.open.merchant, "merchant closed")

-- Flight
M.taxiNodes = { { name = "Stormwind, Elwynn", type = "CURRENT", cost = 0 }, { name = "Sentinel Hill, Westfall", type = "REACHABLE", cost = 50 } }
M.fire("TAXIMAP_OPENED", 1)
TakeTaxiNode(2)
M.fire("TAXIMAP_CLOSED")
M.money = M.money - 50
M.fire("PLAYER_MONEY")
check(last("flight").to == "Sentinel Hill, Westfall" and last("flight").from == "Stormwind, Elwynn" and last("flight").price == 50, "flight logged")
check(last("money").reason == "flight", "flight money reason")
M.taxi = true
for _ = 1, 30 do M.y = M.y + 0.004; M.wa = M.wa - 30; M.tick(1) end
M.taxi = false
M.mapID, M.zone, M.subzone = 1436, "Westfall", "Sentinel Hill"
M.fire("ZONE_CHANGED_NEW_AREA")
M.tick(1)
check(last("landed") and last("landed").seconds == 31 and last("landed").to == "Sentinel Hill, Westfall", "landing logged with duration")
check(ns.stats.distance.flight > 800, "flight distance counted")

-- Death, release, corpse run, level-up
M.units.target = { name = "Defias Thug", guid = "Creature-0-1-0-1-38-1", hostile = true }
M.dead = true
local deathTime = M.now
M.fire("PLAYER_DEAD")
M.dead, M.ghost = false, true
M.fire("PLAYER_ALIVE")
M.ghost = false
M.fire("PLAYER_UNGHOST")
check(count("death") == 1 and last("death").target == "Defias Thug", "death logged")
check(count("release") == 1 and count("revive") == 1, "release and revive")
M.fire("PLAYER_LEVEL_UP", 6)
check(last("level").level == 6 and TravelLogDB.chars[KEY].level == 6, "level up")

-- Hearthstone back to Goldshire
M.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 8690)
check(last("hearth") and last("hearth").to == "Goldshire", "hearth logged")
M.mapID, M.zone, M.subzone, M.x, M.y, M.wa, M.wb = 1429, "Elwynn Forest", "Goldshire", 0.42, 0.65, -9000, -100
M.fire("ZONE_CHANGED_NEW_AREA")
M.tick(1)

-- Dungeon: no coordinates, but jumps still count
M.x, M.wa = nil, nil
M.zone, M.subzone = "The Deadmines", ""
local nPoints = #path.track.buffer
M.tick(5)
check(#path.track.buffer == nPoints, "no path points without coordinates")
M.frame(); JumpOrAscendStart()
local dungeonJump = path.jumps.buffer[#path.jumps.buffer]
check(ns.stats.jumps == 3 and dungeonJump:match("^%d+,1429,,,,,,%d+,The Deadmines,$"), "dungeon jump recorded: " .. dungeonJump)
M.x, M.y, M.wa, M.wb = 0.42, 0.65, -9000, -100

-- World map, zone view
M.viewMap = 1429
M.frame()
local overlay = M.mapOverlay(2010)
check(overlay and overlay.level == 2010, "overlay above the map art")
check(#M.shown(overlay.lines) >= 4, "trail lines drawn: " .. #M.shown(overlay.lines))
check(#M.shown(overlay.textures) == 2, "overlapping markers merged: one jump and one loot dot in Goldshire: " .. #M.shown(overlay.textures))
local allInside = true
for _, l in ipairs(M.shown(overlay.lines)) do
	if l.start[1] < 0 or l.start[1] > 1000 or l.start[2] > 0 or l.start[2] < -667 then allInside = false end
end
check(allInside, "trail inside the canvas")

M.viewMap = 1436
M.frame()
local colors = {}
for _, t in ipairs(M.shown(overlay.textures)) do colors[#colors + 1] = table.concat(t.color, ",") end
table.sort(colors)
check(#colors == 2 and colors[1]:match("^0.2,1") and colors[2]:match("^1,0.15"), "death and level markers in Westfall: " .. table.concat(colors, " | "))
local deathPin = M.shown(overlay.children)[1]
check(deathPin and deathPin.mouse and deathPin.mouseClicks == false, "death marker is hoverable and click-through")
M.script(deathPin, "OnEnter")
local deathTip = table.concat(GameTooltip.lines, "\n")
check(deathTip:find("Death", 1, true) and deathTip:find(date("%Y-%m-%d %H:%M", deathTime), 1, true)
	and deathTip:find("Died fighting Defias Thug at level 5", 1, true), "death marker tooltip: " .. deathTip)
M.script(deathPin, "OnLeave")
check(not GameTooltip.shown, "death marker tooltip hides")

M.viewMap = 1415
M.frame()
check(#M.shown(overlay.lines) >= 1, "trail on the continent map")
M.viewMap = 9999
M.frame()
check(#M.shown(overlay.lines) == 0, "nothing drawn on an unrelated map")

-- Slash commands
M.out = {}
SlashCmdList.TRAVELLOG("stats")
local stats = table.concat(M.out, "\n")
check(stats:find("Jumps: 3 ") and stats:find("Distance: ") and stats:find("Path: %d+ points in 1 sessions")
	and stats:find("Nodes remembered: 1 herbs"), "companion addons add their lines to /tl stats: " .. stats)
M.out = {}
SlashCmdList.TRAVELLOG("help")
local help = table.concat(M.out, "\n")
check(help:find("/tl trail [alts] session", 1, true) and help:find("/tl interval 1%-5") and help:find("/tl nodes on|off", 1, true)
	and help:find("/tl jumps"), "help lists the companion addons' commands: " .. help)
SlashCmdList.TRAVELLOG("jumps")
SlashCmdList.TRAVELLOG("log 40")
M.out = {}
SlashCmdList.TRAVELLOG("log 5 deaths")
local deathLog = table.concat(M.out, "\n")
check(deathLog:find('Last 1 events matching "deaths"', 1, true)
	and deathLog:find("Died fighting Defias Thug at level 5", 1, true)
	and not deathLog:find("Looted", 1, true), "filtered /tl log: " .. deathLog)
SlashCmdList.TRAVELLOG("interval 4")
check(ns.settings.interval == 4, "interval set")
SlashCmdList.TRAVELLOG("interval 9")
check(ns.settings.interval == 4, "bad interval rejected")
M.viewMap = 1429
SlashCmdList.TRAVELLOG("trail off")
M.frame()
check(not overlay.shown, "trail off hides the trail")
SlashCmdList.TRAVELLOG("trail week")
check(overlay.shown and ns.settings.trail == "week", "trail week")

check(ns.On("SOME_EVENT_THAT_DOES_NOT_EXIST", function() end) == false, "unknown events are skipped")

-- Reload: everything goes through a real save and load
local buffered, jumps = #path.track.buffer, ns.stats.jumps
ns = M.Reload()
path = M.ns("TravelLog_Path")
local first = path.db.sessions[1]
check(first.stop and #first.track == 1, "path flushed into the session on logout")
check(first.start == TravelLogCharDB.sessions[1].start and not TravelLogCharDB.sessions[1].track, "path kept in its own file, matched to TravelLog's session")
check(path.CountRecords(first.track) == buffered, "all points saved")
check(path.CountRecords(first.jumps) == 3, "all jumps saved")
check(#TravelLogCharDB.sessions == 2 and #path.db.sessions == 2 and ns.stats.jumps == jumps, "second session keeps history")

M.viewMap = 1429
M.frame()
overlay = M.mapOverlay(2010)
check(#M.shown(overlay.lines) >= 4, "previous session drawn from the saved chunks: " .. #M.shown(overlay.lines))

-- Walking with the map open adds segments; the result matches a full redraw
local beforeLines = #M.shown(overlay.lines)
for i = 1, 30 do
	M.x = M.x + 0.002; M.wb = M.wb - 8
	M.tick(1)
	M.frame()
	if i % 9 == 0 then JumpOrAscendStart(); M.frame() end
end
M.advance(4); M.frame() -- past the live refresh throttle
local liveLines, liveDots = #M.shown(overlay.lines), #M.shown(overlay.textures)
check(liveLines > beforeLines, ("live trail grows while the map is open: %d -> %d"):format(beforeLines, liveLines))
path.RefreshTrail(); M.frame()
check(#M.shown(overlay.lines) == liveLines and #M.shown(overlay.textures) == liveDots,
	("incremental draw matches a full redraw: %d/%d vs %d/%d"):format(liveLines, liveDots, #M.shown(overlay.lines), #M.shown(overlay.textures)))
