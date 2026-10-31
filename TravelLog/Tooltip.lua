-- Item tooltips: when, where and how you first got a rare or better item, and
-- how often, from this character's log.
local _, ns = ...

local MIN_QUALITY = Enum and Enum.ItemQuality and Enum.ItemQuality.Rare or 3

-- How a receive entry's item came, as in "First won ...".
local HOW = {
	loot = "looted", roll = "won", created = "made", quest = "got from a quest",
	mail = "got by mail", trade = "got in a trade", received = "received",
}

-- Item ID -> { first = the earliest entry, times = entries }. Built from the
-- log on the first hover, then caught up with the entries saved since.
local index, indexed = {}, 0

local function Got(item, e)
	local id = type(item) == "string" and tonumber(item:match("item:(%d+)"))
	if not id then
		return
	end
	local got = index[id]
	if not got then
		index[id] = { first = e, times = 1 }
		return
	end
	got.times = got.times + 1
	-- A loot window's entry is stamped when it opens and saved when it closes.
	if (e.time or 0) < (got.first.time or 0) then
		got.first = e
	end
end

ns.On("TL_LOG_CHANGED", function()
	index, indexed = {}, 0
end)

-- The first entry and the number of times you got an item, by item ID.
function ns.ItemHistory(itemID)
	local log = ns.char.log
	for i = indexed + 1, #log do
		local e = log[i]
		if e.type == "loot" then
			for _, it in ipairs(e.items or {}) do
				Got(it.item, e)
			end
		elseif e.type == "receive" or e.type == "buy" then
			Got(e.item, e)
		end
	end
	indexed = #log
	local got = index[itemID]
	if got then
		return got.first, got.times
	end
end

-- "First looted 2026-10-02 from Defias Thug, Westfall".
local function FirstText(e)
	local how, from = HOW[e.how] or "received", e.partner or e.sender
	if e.type == "loot" then
		how, from = e.sourceType == "Fishing" and "fished" or "looted", e.source
	elseif e.type == "buy" then
		how, from = "bought", e.vendor
	end
	local text = ("First %s %s"):format(how, date("%Y-%m-%d", e.time))
	if from then
		text = ("%s from %s"):format(text, from)
	end
	if e.zone then
		text = ("%s%s%s"):format(text, from and ", " or " in ", e.zone)
	end
	return e.roll and ("%s (rolled %d)"):format(text, e.roll) or text
end

local function AddLines(tooltip, data)
	if not ns.char or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
		return
	end
	local itemID = ns.Clean(data and data.id)
	local quality = itemID and ns.Clean(C_Item.GetItemQualityByID(itemID))
	if not quality or quality < MIN_QUALITY then
		return
	end
	local first, times = ns.ItemHistory(itemID)
	if not first then
		return
	end
	tooltip:AddLine(FirstText(first), 0.31, 0.76, 0.97)
	if times > 1 then
		tooltip:AddLine(("Got %d times"):format(times), 0.31, 0.76, 0.97)
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
