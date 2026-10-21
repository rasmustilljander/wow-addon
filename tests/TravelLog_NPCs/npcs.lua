-- TravelLog NPCs: NPCs saved from vendor, trainer and other windows, vendors'
-- stock, item tooltips, minimap and world map pins, hiding, commands, the
-- NPCs tab and a reload.
M.installed = { "TravelLog", "TravelLog_NPCs" }
M.Login()
local ns = M.ns("TravelLog_NPCs")
check(TravelLogNPCsDB and next(TravelLogNPCsDB.npcs) == nil, "starts empty")
check(TravelLogNPCsDB.settings.minimap and TravelLogNPCsDB.settings.worldMap, "pins on by default")

local function Link(id, name) return ("|cffffffff|Hitem:%d::::|h[%s]|h|r"):format(id, name) end
local function Talk(unit, type)
	M.units.npc = unit
	M.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", type)
end
local function Close(type)
	M.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", type)
	M.units.npc = nil
end

-- A vendor who repairs, at Goldshire (42, 65).
local BROG = { name = "Brog Hamfist", guid = "Creature-0-1-2-3-1265-1", title = "General Supplies", level = 30 }
M.canRepair = true
M.merchantItems = {
	{ name = "Refreshing Spring Water", price = 25, stackCount = 5, numAvailable = -1, link = Link(159, "Refreshing Spring Water") },
	{ name = "Tough Hunk of Bread", price = 25, stackCount = 1, numAvailable = -1, link = Link(4540, "Tough Hunk of Bread") },
	{ name = "Fine Longsword", price = 12000, stackCount = 1, numAvailable = 2, link = Link(2528, "Fine Longsword") },
	{ name = nil, price = 0, stackCount = 1, numAvailable = -1, hasExtendedCost = true, link = Link(20558, "Warsong Gulch Mark of Honor") },
	{ name = "Sentinel's Blade", price = 0, stackCount = 1, numAvailable = -1, hasExtendedCost = true, link = Link(19549, "Sentinel's Blade"),
		cost = { { 450, currency = "Honor Points" }, { 30, link = Link(20558, "Warsong Gulch Mark of Honor") } } },
	{ name = "Insignia", price = 5000, stackCount = 1, numAvailable = -1, hasExtendedCost = true, link = Link(18854, "Insignia"),
		cost = { { 2, link = Link(20558, "Warsong Gulch Mark of Honor") } } },
}
M.items[20558] = { link = Link(20558, "Warsong Gulch Mark of Honor") } -- known to the client by now
Talk(BROG, Enum.PlayerInteractionType.Merchant)
M.fire("MERCHANT_SHOW")
local brog = TravelLogNPCsDB.npcs[1265]
check(brog and brog.name == "Brog Hamfist" and brog.title == "General Supplies", "vendor saved with title")
check(brog and brog.kinds.vendor and brog.kinds.repair, "vendor and repairs")
check(brog and brog.map == 1429 and brog.x == 42 and brog.y == 65, "where you stood")
check(brog and brog.zone == "Elwynn Forest" and brog.subzone == "Goldshire" and brog.seen == M.now, "zone, subzone, when")
local water = brog.items[159]
check(water and water.name == "Refreshing Spring Water" and water.price == 25 and water.stack == 5 and not water.limited, "item with stack")
check(brog.items[2528].limited and not brog.items[4540].stack, "limited supply")
check(brog.items[20558].special and not brog.items[20558].price and brog.items[20558].name == "Warsong Gulch Mark of Honor",
	"other currency; name from the item cache")
local BLADE = M.merchantItems[5]
local blade = brog.items[19549].cost
check(blade and #blade == 2 and blade[1].name == "Honor Points" and blade[1].count == 450
	and blade[2].name == "Warsong Gulch Mark of Honor" and blade[2].count == 30, "currencies and items it costs")
check(ns.PriceText(brog.items[19549]) == "450 Honor Points + 30 Warsong Gulch Mark of Honor", ns.PriceText(brog.items[19549]))
check(ns.PriceText(brog.items[18854]) == "50s + 2 Warsong Gulch Mark of Honor", ns.PriceText(brog.items[18854]))
check(ns.Kind(brog).key == "repair", "counts as a repair vendor")

-- Item tooltips.
local function Tip(id) return table.concat(M.hoverItem(id), "\n") end
check(Tip(159):find("Sold by Brog Hamfist %(Goldshire%)  25c for 5"), "tooltip: " .. Tip(159))
check(Tip(2528):find("1g 20s, limited"), "tooltip: limited, gold")
check(Tip(20558):find("other currency"), "tooltip: unreadable cost is other currency")
check(Tip(19549):find("450 Honor Points %+ 30 Warsong"), "tooltip: currencies by name")
check(not Tip(2589):find("Sold by"), "no line for items nobody sells")

-- With the class filter on, the list is partial: nothing is dropped.
M.merchantFilter = LE_LOOT_FILTER_CLASS
M.merchantItems = { M.merchantItems[1], M.merchantItems[2] }
M.fire("MERCHANT_FILTER_ITEM_UPDATE")
check(brog.items[2528] and brog.items[20558], "class filter keeps the rest")
-- On "All", the list is the whole stock: sold-out lines go.
M.merchantFilter = nil
M.fire("MERCHANT_UPDATE")
check(brog.items[159] and not brog.items[2528], "full list replaces the stock")
check(not Tip(2528):find("Sold by"), "dropped item leaves the tooltip")
Close(Enum.PlayerInteractionType.Merchant)
M.fire("MERCHANT_CLOSED")
M.fire("MERCHANT_UPDATE")
check(brog.items[159], "updates after closing don't touch it")

-- An innkeeper who also sells: kinds add up, the inn wins.
local FARLEY = { name = "Innkeeper Farley", guid = "Creature-0-1-2-3-295-1", title = "Innkeeper", level = 30 }
M.merchantItems = { { name = "Refreshing Spring Water", price = 20, stackCount = 5, numAvailable = -1, link = Link(159, "Refreshing Spring Water") } }
M.canRepair = false
Talk(FARLEY, Enum.PlayerInteractionType.Merchant)
Close(Enum.PlayerInteractionType.Merchant)
Talk(FARLEY, Enum.PlayerInteractionType.Binder)
Close(Enum.PlayerInteractionType.Binder)
local farley = TravelLogNPCsDB.npcs[295]
check(farley and farley.kinds.innkeeper and farley.kinds.vendor and not farley.kinds.repair, "innkeeper and vendor")
check(ns.Kind(farley).key == "innkeeper" and ns.KindsText(farley) == "innkeeper, vendor", "innkeeper first")
local tip = Tip(159)
check(tip:find("Sold by Brog Hamfist.-Sold by Innkeeper Farley"), "two vendors by name")

-- A trainer 2% of Elwynn east (69 yards), no title line.
M.x = 0.44
Talk({ name = "Llane Beshere", guid = "Creature-0-1-2-3-911-1", level = 40 }, Enum.PlayerInteractionType.Trainer)
Close(Enum.PlayerInteractionType.Trainer)
local llane = TravelLogNPCsDB.npcs[911]
check(llane and llane.kinds.trainer and not llane.title and not llane.items, "trainer, no title")
-- A flight master far away (277 yards east).
M.x = 0.50
Talk({ name = "Ariena Stormfeather", guid = "Creature-0-1-2-3-352-1" }, Enum.PlayerInteractionType.TaxiNode)
Close(Enum.PlayerInteractionType.TaxiNode)
check(TravelLogNPCsDB.npcs[352].kinds.flight, "flight master")
-- In Stormwind, its own map, and on another continent.
M.mapID, M.x, M.y, M.zone, M.subzone = 84, 0.5, 0.5, "Stormwind City", "Trade District"
Talk({ name = "Olivia Burgess", guid = "Creature-0-1-2-3-1307-1", title = "Banker" }, Enum.PlayerInteractionType.Banker)
Close(Enum.PlayerInteractionType.Banker)
check(TravelLogNPCsDB.npcs[1307].map == 84, "saved on the city map")
M.mapID, M.zone, M.subzone = 1438, "Teldrassil", "Dolanaar"
Talk({ name = "Shalomon", guid = "Creature-0-1-2-3-3610-1" }, Enum.PlayerInteractionType.StableMaster)
Close(Enum.PlayerInteractionType.StableMaster)
check(TravelLogNPCsDB.npcs[3610].kinds.stable, "stable master")
-- Players and windows without an NPC aren't saved.
Talk({ name = "Friend", guid = "Player-1-0001" }, Enum.PlayerInteractionType.Trainer)
Talk(nil, Enum.PlayerInteractionType.Trainer)
local count = 0
for _ in pairs(TravelLogNPCsDB.npcs) do count = count + 1 end
check(count == 6, "only NPCs saved: " .. count)
-- Secret GUIDs (some instances) are skipped.
local SECRET = "Creature-0-1-2-3-4000-1"
M.secrets[SECRET] = true
Talk({ name = "Hidden", guid = SECRET }, Enum.PlayerInteractionType.Trainer)
check(not TravelLogNPCsDB.npcs[4000], "secret GUID skipped")

-- Search: names, titles, places and items, by name.
local function Names(list)
	local out = {}
	for i, m in ipairs(list) do out[i] = m.npc.name .. (m.item and ("[" .. m.item .. "]") or "") end
	return table.concat(out, ", ")
end
check(Names(ns.Search("WATER")) == "Brog Hamfist[Refreshing Spring Water], Innkeeper Farley[Refreshing Spring Water]", "search items: " .. Names(ns.Search("WATER")))
check(Names(ns.Search("goldshire")) == "Brog Hamfist, Innkeeper Farley, Llane Beshere, Ariena Stormfeather" or #ns.Search("goldshire") == 4, "search places")
check(Names(ns.Search("supplies")) == "Brog Hamfist", "search titles")
check(#ns.Search("") == 6, "empty search lists all")

-- Minimap pins: back at Goldshire.
M.mapID, M.x, M.y, M.zone, M.subzone = 1429, 0.42, 0.65, "Elwynn Forest", "Goldshire"
local function MiniPins()
	M.frame()
	local out = {}
	for _, pin in ipairs(M.shown(ns.minimapHolder.children)) do out[pin.npc.name] = pin end
	return out
end
local pins = MiniPins()
check(pins["Brog Hamfist"] and pins["Innkeeper Farley"] and pins["Llane Beshere"], "nearby NPCs pinned")
check(not pins["Ariena Stormfeather"], "beyond the minimap's radius: no pin")
check(not pins["Shalomon"] and not pins["Olivia Burgess"], "other continent and far city: no pin")
local p = pins["Llane Beshere"]
-- 69.4 yards east; the minimap is 140 pixels across for 200 yards of radius.
check(p and math.abs(p.point[4] - 69.4 * 70 / 200) < 0.1 and math.abs(p.point[5]) < 0.01, "trainer east of you")
check(pins["Brog Hamfist"].point[4] == 0 and pins["Brog Hamfist"].icon.color[1] == 0.9, "vendor under you, repair color")
check(p.mouse and p.mouseClicks == false, "pins take hover but let clicks through")
M.script(p, "OnEnter")
check(GameTooltip.lines[1] == "Llane Beshere" and GameTooltip.lines[2] == "trainer", "minimap pin tooltip")
-- A rotating minimap facing west: east is down.
M.cvars.rotateMinimap = { value = "1", default = "0" }
M.facing = math.pi / 2
p = MiniPins()["Llane Beshere"]
check(math.abs(p.point[4]) < 0.01 and math.abs(p.point[5] + 69.4 * 70 / 200) < 0.1, "rotated: east is down")
M.cvars.rotateMinimap, M.facing = nil, 0
-- Zooming out brings the flight master in.
M.minimapRadius = 300
check(MiniPins()["Ariena Stormfeather"], "zoomed out: far NPC shown")
M.minimapRadius = 200
-- A city NPC shows from the zone map, at the right spot.
M.x, M.y = 970 / 3470, 545 / 2315
pins = MiniPins()
check(pins["Olivia Burgess"] and math.abs(pins["Olivia Burgess"].point[4]) < 0.01, "city NPC on the zone's minimap")
M.x, M.y = 0.42, 0.65
-- Hiding: a kind, one NPC, all of them; nothing in instances.
TravelLogNPCsDB.settings.hideKinds.trainer = true
ns.Changed()
check(not MiniPins()["Llane Beshere"], "hidden kind")
TravelLogNPCsDB.settings.hideKinds.trainer = nil
ns.Changed()
check(MiniPins()["Llane Beshere"], "kind shown again")
M.x = nil
check(next(MiniPins()) == nil, "no pins without a position")
M.x = 0.42

-- World map pins: on the map each NPC was saved on.
local function MapPins()
	M.frame()
	local out = {}
	for _, pin in ipairs(M.shown(ns.mapOverlay.children)) do out[pin.npc.name] = pin end
	return out
end
check(ns.mapOverlay.level == 2013, "world map overlay above the other companions")
pins = MapPins()
check(pins["Brog Hamfist"] and pins["Llane Beshere"] and pins["Ariena Stormfeather"] and not pins["Olivia Burgess"], "zone map pins")
check(math.abs(pins["Brog Hamfist"].point[4] - 420) < 0.01 and math.abs(pins["Brog Hamfist"].point[5] + 0.65 * 667) < 0.01, "pin position")
M.script(pins["Brog Hamfist"], "OnEnter")
check(GameTooltip.lines[2] == "General Supplies" and GameTooltip.lines[3] == "repair vendor", "map pin tooltip")
M.viewMap = 84
check(MapPins()["Olivia Burgess"], "city map pins")
M.viewMap = 1429

-- Commands.
local function Run(msg)
	M.out = {}
	SlashCmdList.TRAVELLOGNPCS(msg)
	return table.concat(M.out, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end
check(Run(""):find("6 NPCs saved, selling 2 items"), "/npcs: " .. Run(""))
local text = Run("bread")
check(text:find("1 NPC matches") and text:find("Brog Hamfist %(repair vendor%), Goldshire, Elwynn Forest %(42.0, 65.0%) %- sells Tough Hunk of Bread for 25c"), "/npcs <item>: " .. text)
check(Run("nothing"):find("no NPC matches"), "/npcs no match")
check(Run("hide brog"):find("Brog Hamfist: pins hidden") and brog.hidden, "/npcs hide")
check(not MiniPins()["Brog Hamfist"] and not MapPins()["Brog Hamfist"], "hidden NPC: no pins")
check(Run("bread"):find("%[hidden%]"), "hidden shows in results")
check(Run("show Brog Hamfist"):find("pins shown") and not brog.hidden and MiniPins()["Brog Hamfist"], "/npcs show")
check(Run("hide e"):find("several NPCs match"), "ambiguous name")
check(Run("kind inn off"):find("innkeeper off") and TravelLogNPCsDB.settings.hideKinds.innkeeper, "/npcs kind off")
check(not MiniPins()["Innkeeper Farley"], "innkeepers hidden")
check(Run("kind innkeepers on"):find("innkeeper on") and not TravelLogNPCsDB.settings.hideKinds.innkeeper, "/npcs kind on")
check(Run("kind wizard off"):find("usage"), "unknown kind")
check(Run("minimap off"):find("minimap off, world map on") and next(MiniPins()) == nil, "/npcs minimap off")
check(Run("map off"):find("world map off") and next(MapPins()) == nil, "/npcs map off")
Run("minimap on")
Run("map on")
check(MiniPins()["Brog Hamfist"] and MapPins()["Brog Hamfist"], "pins back on")
M.units.target = { name = "Marshal Dughan", guid = "Creature-0-1-2-3-240-1", title = "Marshal", level = 25 }
check(Run("add"):find("saved Marshal Dughan %(other%)"), "/npcs add")
check(ns.Kind(TravelLogNPCsDB.npcs[240]).key == "other", "added NPC is an other")
check(Run("forget target"):find("forgot Marshal Dughan") and not TravelLogNPCsDB.npcs[240], "/npcs forget target")
M.units.target = nil
check(Run("add"):find("target an NPC"), "/npcs add without target")

-- The NPCs tab in TravelLog's window.
check(Run("window") == "", "/npcs window")
local w = M.ns("TravelLog").window
local page = w.pages[4]
check(w.Tabs[4]:GetText() == "NPCs" and page:IsShown(), "NPCs tab open")
local function Rows(list)
	local out = {}
	for _, row in ipairs(M.shown(list.rows)) do out[#out + 1] = row.name:GetText() .. " " .. row.right:GetText() end
	return table.concat(out, ", ")
end
check(page.found:GetText() == "6 NPCs" and select(2, Rows(page.npcs):gsub(", ", "")) == 5, "every NPC listed")
check(page.hint:GetText():find("Click an NPC") and page.kindChecks[1]:IsShown() and not page.show:IsShown(), "kinds shown with nothing picked")
page.search:SetText("water")
check(Rows(page.npcs) == "Brog Hamfist Goldshire, Innkeeper Farley Goldshire", "search: " .. Rows(page.npcs))
page.npcs.rows[1]:Click()
check(page.title:GetText() == "Brog Hamfist" and page.kinds:GetText() == "General Supplies, repair vendor", "picked NPC")
check(page.where:GetText() == "Goldshire, Elwynn Forest (42.0, 65.0)" and page.sells:GetText() == "Sells 2 items", "where and stock")
check(Rows(page.items) == "Refreshing Spring Water 25c for 5, Tough Hunk of Bread 25c", "items: " .. Rows(page.items))
check(not page.kindChecks[1]:IsShown() and page.show:IsShown() and page.show:GetChecked(), "details replace kinds")
M.script(page.items.rows[2], "OnEnter")
check(GameTooltip.item == 4540, "item row tooltip")
page.show:Click()
check(brog.hidden and not MiniPins()["Brog Hamfist"], "pin checkbox hides the NPC")
for _ = 1, 70 do M.frame() end
check(page.npcs.rows[1].name.textColor[1] == 0.5, "hidden NPC grayed")
page.show:Click()
check(not brog.hidden, "pin checkbox shows it again")
page.npcs.rows[1]:Click()
check(page.title:GetText() == "" and page.kindChecks[1]:IsShown(), "clicking it again goes back to the kinds")
page.kindChecks[1]:Click()
check(TravelLogNPCsDB.settings.hideKinds.trainer and not MiniPins()["Llane Beshere"], "kind checkbox")
page.kindChecks[1]:Click()
check(not TravelLogNPCsDB.settings.hideKinds.trainer, "kind checkbox back on")
page.search.clearButton:Click()
-- Settings and totals.
local minimapCheck
for _, f in ipairs(M.descendants(w)) do
	if f.kind == "CheckButton" and f.Text and f.Text:GetText() == "NPCs on the minimap" then minimapCheck = f end
end
w.Tabs[2]:Click()
check(minimapCheck and minimapCheck:GetChecked(), "minimap setting")
minimapCheck:Click()
check(not TravelLogNPCsDB.settings.minimap, "minimap setting off")
minimapCheck:Click()
local totals = {}
for _, f in ipairs(M.descendants(w.pages[1])) do totals[#totals + 1] = f.text end
check(table.concat(totals, "\n"):find("6, selling 2 items"), "totals row")

-- Saved account-wide; the tooltip index comes back after a reload.
M.merchantItems = { { name = "Refreshing Spring Water", price = 25, stackCount = 5, numAvailable = -1, link = Link(159, "Refreshing Spring Water") }, BLADE }
Talk(BROG, Enum.PlayerInteractionType.Merchant)
Close(Enum.PlayerInteractionType.Merchant)
TravelLogNPCsDB.settings.hideKinds.stable = true
ns = M.Reload()
ns = M.ns("TravelLog_NPCs")
check(TravelLogNPCsDB.npcs[1265].items[159].price == 25, "saved")
check(Tip(19549):find("450 Honor Points %+ 30 Warsong"), "currencies saved")
check(TravelLogNPCsDB.settings.hideKinds.stable, "settings saved")
check(Tip(159):find("Sold by Brog Hamfist"), "tooltip after reload")
check(MiniPins()["Brog Hamfist"], "pins after reload")
-- Another character sees the same NPCs.
M.player = { name = "Altie", realm = "Forever", class = "WARRIOR" }
ns = M.Reload()
ns = M.ns("TravelLog_NPCs")
check(TravelLogNPCsDB.npcs[1265] and Tip(159):find("Sold by Brog Hamfist"), "shared with alts")

-- Works without TravelLog too.
M.Logout()
M.installed = { "TravelLog_NPCs" }
TravelLog = nil -- the fake keeps addon globals across logins
for _, name in ipairs(M.installed) do C_AddOns.LoadAddOn(name) end
M.fire("PLAYER_LOGIN")
ns = M.ns("TravelLog_NPCs")
check(Tip(159):find("Sold by Brog Hamfist"), "works on its own")
check(Run("window"):find("needs TravelLog"), "no window without TravelLog")
