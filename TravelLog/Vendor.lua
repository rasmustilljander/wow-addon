-- Vendor trades: purchases, sales, buybacks and repairs.
local _, ns = ...

local WAIT = 5

local vendor              -- name of the merchant we're talking to
local buyback = {}        -- buyback list as last seen
local repairCost = 0
local pendingBuys = {}
local pendingBuybacks = {}
local pendingRepairs = {}

local function ReadBuyback()
	local list = {}
	for i = 1, GetNumBuybackItems() do
		local name, _, price, count = GetBuybackItemInfo(i)
		list[i] = { item = GetBuybackItemLink(i) or name, count = count, price = price }
	end
	return list
end

local function Key(entry)
	return ("%s#%s#%s"):format(tostring(entry.item), tostring(entry.count), tostring(entry.price))
end

local function CountEntries(list, key)
	local count = 0
	for _, entry in ipairs(list) do
		if Key(entry) == key then
			count = count + 1
		end
	end
	return count
end

local function CountInBags(itemID)
	local count = 0
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID == itemID then
				count = count + (info.stackCount or 1)
			end
		end
	end
	return count
end

local function Fresh(action)
	return GetTime() - action.at <= WAIT
end

local function LogBuy(action)
	ns.Log("buy", action.data)
	ns.Add(1, "vendor", "bought")
	ns.Add(action.data.price or 0, "vendor", "spent")
end

-- Pick the set of clicks that exactly explains the new item count. This keeps
-- a failed split purchase from being mistaken for a later successful stack.
local function ConfirmedBuys(actions, current)
	local states = { { chosen = {}, total = 0 } }
	for _, action in ipairs(actions) do
		local nextStates, byFloor = {}, {}
		local function Keep(state)
			local key = state.floor == nil and "none" or tostring(state.floor)
			local old = byFloor[key]
			if not old or state.total > old.total then
				byFloor[key] = state
			end
		end
		for _, state in ipairs(states) do
			Keep(state)
			local base = math.max(state.floor or action.before, action.before)
			if base + action.count <= current then
				local chosen = {}
				for i, previous in ipairs(state.chosen) do chosen[i] = previous end
				chosen[#chosen + 1] = action
				Keep({ floor = base + action.count, chosen = chosen, total = state.total + action.count })
			end
		end
		for _, state in pairs(byFloor) do nextStates[#nextStates + 1] = state end
		states = nextStates
	end
	local best
	for _, state in ipairs(states) do
		if state.floor == current and (not best or state.total > best.total) then
			best = state
		end
	end
	for _, action in ipairs(best and best.chosen or {}) do
		action.confirmed = true
	end
end

local function CheckPurchases()
	local byItem = {}
	for _, action in ipairs(pendingBuys) do
		if Fresh(action) then
			byItem[action.itemID] = byItem[action.itemID] or {}
			byItem[action.itemID][#byItem[action.itemID] + 1] = action
		end
	end
	local counts = {}
	for itemID, actions in pairs(byItem) do
		counts[itemID] = CountInBags(itemID)
		ConfirmedBuys(actions, counts[itemID])
	end
	local keep = {}
	for _, action in ipairs(pendingBuys) do
		if action.confirmed then
			LogBuy(action)
		elseif Fresh(action) then
			action.before = counts[action.itemID]
			keep[#keep + 1] = action
		end
	end
	pendingBuys = keep
end

local function CheckBuybacks(now)
	local counts, floors = {}, {}
	local keep = {}
	for _, action in ipairs(pendingBuybacks) do
		if Fresh(action) then
			local key = action.key
			counts[key] = counts[key] or CountEntries(now, key)
			local base = math.min(action.before, floors[key] or action.before)
			if counts[key] < base then
				ns.Log("buyback", action.data)
				ns.Add(action.data.price or 0, "vendor", "spent")
				floors[key] = base - 1
			else
				action.before = counts[key]
				keep[#keep + 1] = action
			end
		end
	end
	pendingBuybacks = keep
end

-- There is no "item sold" event, but everything you sell lands in the buyback
-- list, so new entries there are sales.
local function CheckSales(now)
	local seen = {}
	for _, entry in ipairs(buyback) do
		local key = Key(entry)
		seen[key] = (seen[key] or 0) + 1
	end
	for _, entry in ipairs(now) do
		local key = Key(entry)
		if (seen[key] or 0) > 0 then
			seen[key] = seen[key] - 1
		elseif entry.item then
			ns.Log("sell", { item = entry.item, count = entry.count, price = entry.price, vendor = vendor })
			ns.Add(1, "vendor", "sold")
			ns.Add(entry.price or 0, "vendor", "earned")
		end
	end
	buyback = now
end

local function ReadRepairCost()
	local cost, canRepair = GetRepairAllCost()
	return canRepair and cost or 0
end

local function CheckRepairs()
	local remaining = ReadRepairCost()
	local confirmed
	for i = #pendingRepairs, 1, -1 do
		local action = pendingRepairs[i]
		if Fresh(action) and remaining < action.before then
			confirmed = action
			break
		end
	end
	if confirmed then
		local cost = confirmed.before - remaining
		ns.Log("repair", { price = cost, vendor = confirmed.vendor, guildBank = confirmed.guildBank })
		ns.Add(1, "vendor", "repairs")
		ns.Add(cost, "vendor", "repairCost")
		pendingRepairs = {}
	else
		local keep = {}
		for _, action in ipairs(pendingRepairs) do
			if Fresh(action) then
				action.before = remaining
				keep[#keep + 1] = action
			end
		end
		pendingRepairs = keep
	end
	repairCost = remaining
end

ns.On("TL_OPEN", function(context)
	if context ~= "merchant" then
		return
	end
	vendor = ns.Clean(UnitName("npc"))
	buyback = ReadBuyback()
	repairCost = ReadRepairCost()
	pendingBuys, pendingBuybacks, pendingRepairs = {}, {}, {}
end)

ns.On("TL_CLOSE", function(context)
	if context == "merchant" then
		pendingBuys, pendingBuybacks, pendingRepairs = {}, {}, {}
	end
end)

for _, event in ipairs({ "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY" }) do
	ns.On(event, function()
		if ns.open.merchant then
			CheckPurchases()
			local now = ReadBuyback()
			CheckBuybacks(now)
			CheckSales(now)
			CheckRepairs()
		end
	end)
end

local function MerchantItem(index)
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local info = C_MerchantFrame.GetItemInfo(index)
		if info then
			return info.name, info.price, info.stackCount, info.hasExtendedCost
		end
	elseif GetMerchantItemInfo then
		local name, _, price, stackCount, _, _, _, hasExtendedCost = GetMerchantItemInfo(index)
		return name, price, stackCount, hasExtendedCost
	end
end

hooksecurefunc("BuyMerchantItem", function(index, quantity)
	if not ns.char or not ns.open.merchant then
		return
	end
	local name, price, stackCount, hasExtendedCost = MerchantItem(index)
	stackCount = (stackCount and stackCount > 0) and stackCount or 1
	local count = quantity or stackCount
	-- The listed price is for one stack of stackCount items.
	local cost = price and math.floor(price * count / stackCount + 0.5) or 0
	local item = GetMerchantItemLink(index) or name
	local itemID = GetMerchantItemID and GetMerchantItemID(index)
	if item and itemID and count > 0 then
		pendingBuys[#pendingBuys + 1] = {
			itemID = itemID,
			count = count,
			before = CountInBags(itemID),
			at = GetTime(),
			data = {
				item = item,
				count = count,
				price = cost,
				otherCurrency = hasExtendedCost or nil,
				vendor = vendor,
			},
		}
	end
end)

hooksecurefunc("BuybackItem", function(index)
	if not ns.char or not ns.open.merchant then
		return
	end
	local entry = buyback[index]
	local name, _, price, count = GetBuybackItemInfo(index)
	if name then
		entry = { item = GetBuybackItemLink(index) or name, count = count, price = price }
	end
	if entry then
		local key = Key(entry)
		pendingBuybacks[#pendingBuybacks + 1] = {
			key = key,
			before = CountEntries(ReadBuyback(), key),
			at = GetTime(),
			data = { item = entry.item, count = entry.count, price = entry.price, vendor = vendor },
		}
	end
end)

hooksecurefunc("RepairAllItems", function(useGuildBank)
	if not ns.char or not ns.open.merchant or repairCost <= 0 then
		return
	end
	pendingRepairs[#pendingRepairs + 1] = {
		before = repairCost,
		at = GetTime(),
		vendor = vendor,
		guildBank = useGuildBank or nil,
	}
end)
