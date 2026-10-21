-- TravelLog NPCs core: remembers the NPCs you talk to (vendors, trainers,
-- flight masters, ...), where they stand and what they sell. Saved
-- account-wide, since an NPC is the same for every character.
local _, ns = ...

-- Bumped on every change, so the maps and the window know to redraw.
ns.version = 0

-- An NPC with several kinds counts as the first one here (an innkeeper who
-- sells food is an innkeeper). color is its pin on the maps.
ns.KINDS = {
	{ key = "trainer", name = "trainer", label = "Trainers", color = { 0.3, 0.9, 0.3 } },
	{ key = "flight", name = "flight master", label = "Flight masters", color = { 0.4, 0.75, 1 } },
	{ key = "innkeeper", name = "innkeeper", label = "Innkeepers", color = { 1, 0.5, 0.8 } },
	{ key = "banker", name = "banker", label = "Bankers", color = { 0.7, 0.5, 1 } },
	{ key = "auctioneer", name = "auctioneer", label = "Auctioneers", color = { 1, 0.55, 0.15 } },
	{ key = "stable", name = "stable master", label = "Stable masters", color = { 0.75, 0.55, 0.35 } },
	{ key = "repair", name = "repair vendor", label = "Repair vendors", color = { 0.9, 0.9, 0.9 } },
	{ key = "vendor", name = "vendor", label = "Vendors", color = { 1, 0.82, 0 } },
	{ key = "other", name = "other", label = "Others", color = { 0.6, 0.6, 0.6 } },
}
ns.kindInfo = {}
for _, kind in ipairs(ns.KINDS) do
	ns.kindInfo[kind.key] = kind
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- The Midnight-era client hands addons unreadable "secret" values in some
-- situations (unit names and GUIDs inside instances...).
local issecretvalue = issecretvalue
function ns.Clean(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffffb74dTravelLog NPCs|r " .. text)
end

function ns.Count(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end

function ns.MoneyText(copper)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. "g" end
	if s > 0 then parts[#parts + 1] = s .. "s" end
	if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
	return table.concat(parts, " ")
end

-- "3d 4h", "2h 13m", "5m": how long ago an epoch time was.
function ns.Ago(t)
	local s = math.max(time() - t, 0)
	local d, h, m = math.floor(s / 86400), math.floor(s / 3600) % 24, math.floor(s / 60) % 60
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	elseif m > 0 then
		return ("%dm"):format(m)
	end
	return "under a minute"
end

-- Splits a GUID like "Creature-0-1-2-3-299-4" into its type and NPC ID.
function ns.ParseGUID(guid)
	guid = ns.Clean(guid)
	if not guid then
		return
	end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return kind, tonumber(id)
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local handlers = {}

-- Calls fn for a game event. Returns false if the client doesn't know it.
function ns.On(event, fn)
	if not handlers[event] then
		if not pcall(frame.RegisterEvent, frame, event) then
			return false
		end
		handlers[event] = {}
	end
	local list = handlers[event]
	list[#list + 1] = fn
	return true
end

frame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		local ok, err = pcall(fn, ...)
		if not ok then
			geterrorhandler()(err)
		end
	end
end)

--------------------------------------------------------------------------------
-- Saved data
--------------------------------------------------------------------------------

-- TravelLogNPCsDB = {
--   settings = { minimap = true, worldMap = true, hideKinds = { trainer = true } },
--   npcs = {
--     [1265] = { name = "Brog Hamfist", title = "General Supplies", kinds = { vendor = true },
--       map = 1429, x = 43.2, y = 65.8, zone = "Elwynn Forest", subzone = "Goldshire",
--       seen = 1760000000, hidden = true,
--       items = { [159] = { name = "Refreshing Spring Water", price = 25, stack = 5,
--         limited = true, special = true, cost = { { name = "Honor Points", count = 450 } } } } },
--   },
-- }
-- x, y are map coordinates 0-100 of where you stood.

ns.sellers = {} -- itemID -> { [npcID] = true }

-- Adds (or with remove, takes out) an NPC's items in ns.sellers.
local function Index(id, npc, remove)
	for itemID in pairs(npc.items or {}) do
		local set = ns.sellers[itemID]
		if remove then
			if set then
				set[id] = nil
			end
		else
			if not set then
				set = {}
				ns.sellers[itemID] = set
			end
			set[id] = true
		end
	end
end

local function Init()
	TravelLogNPCsDB = TravelLogNPCsDB or {}
	local db = TravelLogNPCsDB
	db.version = 1
	db.npcs = db.npcs or {}
	db.settings = db.settings or {}
	local s = db.settings
	if s.minimap == nil then s.minimap = true end
	if s.worldMap == nil then s.worldMap = true end
	s.hideKinds = s.hideKinds or {}
	ns.db = db
	for id, npc in pairs(db.npcs) do
		Index(id, npc)
	end
	ns.version = ns.version + 1
end

function ns.Changed()
	ns.version = ns.version + 1
end

-- The kind an NPC counts as, the first of ns.KINDS it is.
function ns.Kind(npc)
	for _, kind in ipairs(ns.KINDS) do
		if npc.kinds[kind.key] then
			return kind
		end
	end
	return ns.kindInfo.other
end

-- Whether an NPC's pins are drawn: not hidden, and its kind isn't either.
function ns.Shown(npc)
	return not npc.hidden and not ns.db.settings.hideKinds[ns.Kind(npc).key]
end

-- "Goldshire, Elwynn Forest (43.2, 65.8)"
function ns.Where(npc)
	local where = npc.zone or "?"
	if npc.subzone then
		where = npc.subzone .. ", " .. where
	end
	if npc.x then
		where = ("%s (%.1f, %.1f)"):format(where, npc.x, npc.y)
	end
	return where
end

-- An NPC's kinds as text, ns.KINDS order: "innkeeper, repair vendor"
function ns.KindsText(npc)
	local list = {}
	for _, kind in ipairs(ns.KINDS) do
		if npc.kinds[kind.key] and not (kind.key == "vendor" and npc.kinds.repair) then
			list[#list + 1] = kind.name
		end
	end
	return #list > 0 and table.concat(list, ", ") or ns.kindInfo.other.name
end

-- The text for what one item costs: "25c", "1s for 5", "1g + 20 Honor Points",
-- "other currency" (one whose currencies weren't readable).
function ns.PriceText(item)
	local parts = {}
	if item.price then
		parts[1] = ns.MoneyText(item.price)
	end
	for _, cost in ipairs(item.cost or {}) do
		parts[#parts + 1] = ("%d %s"):format(cost.count, cost.name)
	end
	local text
	if item.special and not item.cost then
		text = item.price and parts[1] .. " + more" or "other currency"
	else
		text = #parts > 0 and table.concat(parts, " + ") or "free"
	end
	if item.stack then
		text = ("%s for %d"):format(text, item.stack)
	end
	return text
end

-- How many different items the saved vendors sell.
function ns.ItemCount()
	local n = 0
	for _, set in pairs(ns.sellers) do
		if next(set) then
			n = n + 1
		end
	end
	return n
end

function ns.Forget(id)
	local npc = ns.db.npcs[id]
	if npc then
		Index(id, npc, true)
		ns.db.npcs[id] = nil
		ns.Changed()
	end
end

-- Every NPC whose name, title, place or one of the items it sells contains
-- text, by name. Each match is { id, npc, item }, item being the name of the
-- first matching item when only an item matched.
function ns.Search(text)
	text = (text or ""):lower()
	local function Has(s)
		return s and s:lower():find(text, 1, true)
	end
	local found = {}
	for id, npc in pairs(ns.db.npcs) do
		local match = text == "" or Has(npc.name) or Has(npc.title) or Has(npc.zone) or Has(npc.subzone)
		local item
		if not match then
			for _, it in pairs(npc.items or {}) do
				if Has(it.name) and (not item or it.name < item) then
					item = it.name
				end
			end
		end
		if match or item then
			found[#found + 1] = { id = id, npc = npc, item = item }
		end
	end
	table.sort(found, function(a, b)
		if a.npc.name ~= b.npc.name then
			return a.npc.name < b.npc.name
		end
		return a.id < b.id
	end)
	return found
end

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------

-- The line under an NPC's name on its tooltip, like "General Supplies".
-- Level lines have digits, titles don't.
local function Title(unit, name)
	local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
	local line = data and data.lines and data.lines[2]
	local text = line and ns.Clean(line.leftText)
	if type(text) == "string" and text ~= "" and text ~= name and not text:find("%d") then
		return text
	end
end

-- Saves (or updates) the NPC behind unit as having this kind, at your
-- position. Returns its ID and record, or nil if unit isn't an NPC.
function ns.Record(unit, kind)
	if not ns.db then
		return
	end
	local guidKind, id = ns.ParseGUID(UnitGUID(unit))
	if guidKind ~= "Creature" or not id then
		return
	end
	local npc = ns.db.npcs[id]
	if not npc then
		npc = { kinds = {} }
		ns.db.npcs[id] = npc
	end
	local name = ns.Clean(UnitName(unit))
	npc.name = name or npc.name or ("NPC #" .. id)
	npc.title = Title(unit, name) or npc.title
	if kind then
		npc.kinds[kind] = true
	end

	local zone, subzone = ns.Clean(GetRealZoneText()), ns.Clean(GetSubZoneText())
	npc.zone = zone or npc.zone
	npc.subzone = subzone ~= "" and subzone ~= zone and subzone or nil
	local map = ns.Clean(C_Map.GetBestMapForUnit("player"))
	local pos = map and C_Map.GetPlayerMapPosition(map, "player")
	local x, y = pos and ns.Clean(pos.x), pos and ns.Clean(pos.y)
	if x and y and not (x == 0 and y == 0) then
		npc.map, npc.x, npc.y = map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
	elseif map and map ~= npc.map then
		npc.map, npc.x, npc.y = map, nil, nil -- in an instance: no coordinates
	end
	npc.seen = time()
	ns.Changed()
	return id, npc
end

--------------------------------------------------------------------------------
-- Vendors' stock
--------------------------------------------------------------------------------

local merchant -- ID of the vendor whose window is open

-- The currencies and items (not money) merchant item i costs, as
-- { { name = "Honor Points", count = 450 } }, or nil if none are readable.
local function MerchantCost(i)
	if not GetMerchantItemCostItem then
		return nil
	end
	local cost = {}
	for c = 1, MAX_ITEM_COST or 3 do
		local texture, count, link, currency = GetMerchantItemCostItem(i, c)
		count, link, currency = ns.Clean(count), ns.Clean(link), ns.Clean(currency)
		local name = currency or (link and link:match("|h%[(.-)%]|h"))
		if texture and name and count then
			cost[#cost + 1] = { name = name, count = count }
		end
	end
	return #cost > 0 and cost or nil
end

-- Reads the open vendor's items. With the vendor's filter on "All" this is
-- the whole list; with a class filter it only adds to what's known.
local function ScanMerchant()
	local npc = merchant and ns.db.npcs[merchant]
	if not npc then
		return
	end
	local n = GetMerchantNumItems()
	if n == 0 then
		return -- not loaded yet
	end
	local all = not (GetMerchantFilter and LE_LOOT_FILTER_ALL) or GetMerchantFilter() == LE_LOOT_FILTER_ALL
	local old = npc.items or {}
	local items = all and {} or old
	for i = 1, n do
		local itemID = GetMerchantItemID(i)
		local info = C_MerchantFrame.GetItemInfo(i)
		if itemID and info then
			local name = ns.Clean(info.name) or (old[itemID] and old[itemID].name)
			if not name and C_Item.GetItemInfo then
				name = C_Item.GetItemInfo(itemID)
			end
			items[itemID] = {
				name = name,
				price = info.price and info.price > 0 and info.price or nil,
				stack = info.stackCount and info.stackCount > 1 and info.stackCount or nil,
				limited = info.numAvailable and info.numAvailable >= 0 or nil,
				special = info.hasExtendedCost or nil,
				cost = info.hasExtendedCost and MerchantCost(i) or nil,
			}
		end
	end
	Index(merchant, npc, true)
	npc.items = items
	Index(merchant, npc)
	ns.Changed()
end

local function OpenMerchant()
	merchant = ns.Record("npc", "vendor")
	if merchant and CanMerchantRepair and CanMerchantRepair() then
		ns.db.npcs[merchant].kinds.repair = true
	end
	ScanMerchant()
end

-- Interaction windows and the kind they make an NPC.
local INTERACTIONS = {
	TaxiNode = "flight", Trainer = "trainer", Banker = "banker", CharacterBanker = "banker",
	AccountBanker = "banker", Binder = "innkeeper", Auctioneer = "auctioneer", StableMaster = "stable",
}
local kindByType = {}
if Enum and Enum.PlayerInteractionType then
	for name, kind in pairs(INTERACTIONS) do
		local id = Enum.PlayerInteractionType[name]
		if id then
			kindByType[id] = kind
		end
	end
end

ns.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(type)
	if Enum.PlayerInteractionType and type == Enum.PlayerInteractionType.Merchant then
		merchant = nil
	end
end)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(type)
	if Enum.PlayerInteractionType and type == Enum.PlayerInteractionType.Merchant then
		OpenMerchant()
	elseif kindByType[type] then
		ns.Record("npc", kindByType[type])
	end
end)
ns.On("MERCHANT_SHOW", function()
	if not merchant then
		OpenMerchant()
	end
end)
ns.On("MERCHANT_UPDATE", ScanMerchant)
ns.On("MERCHANT_FILTER_ITEM_UPDATE", ScanMerchant)
ns.On("MERCHANT_CLOSED", function()
	merchant = nil
end)

ns.On("PLAYER_LOGIN", Init)
