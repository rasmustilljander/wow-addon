-- Vendor trades: purchases, sales, buybacks and repairs.
local _, ns = ...

local vendor       -- name of the merchant we're talking to
local buyback = {} -- buyback list as last seen
local repairCost = 0

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

-- There is no "item sold" event, but everything you sell lands in the buyback
-- list, so new entries there are sales.
local function CheckSales()
	local now = ReadBuyback()
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

local function UpdateRepairCost()
	local cost, canRepair = GetRepairAllCost()
	repairCost = canRepair and cost or 0
end

ns.On("TL_OPEN", function(context)
	if context ~= "merchant" then
		return
	end
	vendor = ns.Clean(UnitName("npc"))
	buyback = ReadBuyback()
	UpdateRepairCost()
end)

for _, event in ipairs({ "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY" }) do
	ns.On(event, function()
		if ns.open.merchant then
			CheckSales()
			UpdateRepairCost()
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
	if not ns.char then
		return
	end
	local name, price, stackCount, hasExtendedCost = MerchantItem(index)
	stackCount = (stackCount and stackCount > 0) and stackCount or 1
	local count = quantity or stackCount
	-- The listed price is for one stack of stackCount items.
	local cost = price and math.floor(price * count / stackCount + 0.5) or 0
	ns.Log("buy", {
		item = GetMerchantItemLink(index) or name,
		count = count,
		price = cost,
		otherCurrency = hasExtendedCost or nil,
		vendor = vendor,
	})
	ns.Add(1, "vendor", "bought")
	ns.Add(cost, "vendor", "spent")
end)

hooksecurefunc("BuybackItem", function(index)
	if not ns.char then
		return
	end
	local entry = buyback[index]
	local name, _, price, count = GetBuybackItemInfo(index)
	if name then
		entry = { item = GetBuybackItemLink(index) or name, count = count, price = price }
	end
	if entry then
		ns.Log("buyback", { item = entry.item, count = entry.count, price = entry.price, vendor = vendor })
		ns.Add(entry.price or 0, "vendor", "spent")
	end
end)

hooksecurefunc("RepairAllItems", function(useGuildBank)
	if not ns.char or repairCost <= 0 then
		return
	end
	ns.Log("repair", { price = repairCost, vendor = vendor, guildBank = useGuildBank or nil })
	ns.Add(1, "vendor", "repairs")
	ns.Add(repairCost, "vendor", "repairCost")
	repairCost = 0
end)
