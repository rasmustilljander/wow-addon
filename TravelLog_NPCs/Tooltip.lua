-- Item tooltips: the vendors you've seen selling the item, and the price.
local _, ns = ...

local SHOW = 3 -- vendors listed; the rest are counted

local function AddLines(tooltip, data)
	if not ns.db or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
		return
	end
	local itemID = ns.Clean(data and data.id)
	local set = itemID and ns.sellers[itemID]
	if not set then
		return
	end
	-- Vendors in your zone first, then by name.
	local zone, list = ns.Clean(GetRealZoneText()), {}
	for id in pairs(set) do
		local npc = ns.db.npcs[id]
		if npc and npc.items and npc.items[itemID] then
			list[#list + 1] = { npc = npc, item = npc.items[itemID], here = npc.zone == zone }
		end
	end
	table.sort(list, function(a, b)
		if a.here ~= b.here then
			return a.here
		end
		return a.npc.name < b.npc.name
	end)
	for i = 1, math.min(SHOW, #list) do
		local npc, item = list[i].npc, list[i].item
		local price = ns.PriceText(item) .. (item.limited and ", limited" or "")
		tooltip:AddDoubleLine(("Sold by %s (%s)"):format(npc.name, npc.subzone or npc.zone or "?"), price,
			1, 0.72, 0.3, 1, 1, 1)
	end
	if #list > SHOW then
		tooltip:AddLine(("and %d more vendors"):format(#list - SHOW), 1, 0.72, 0.3)
	end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		-- A broken tooltip line must not break the tooltip.
		local ok, err = pcall(AddLines, tooltip, data)
		if not ok then
			geterrorhandler()(err)
		end
	end)
end
