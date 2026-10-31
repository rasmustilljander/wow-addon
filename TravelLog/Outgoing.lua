-- Items that leave your bags: handed over in a trade, sent by mail or
-- destroyed, and items moved to and from the guild bank. Auctions are in
-- Auctions.lua; money that goes with them is the money ledger's.
local _, ns = ...

-- Counts can come back as nil or 0 for single items.
local function Count(n)
	return math.max(ns.Clean(n) or 1, 1)
end

local function Gave(items, how)
	for _, it in ipairs(items) do
		ns.Add(it.count, "given", how)
	end
end

--------------------------------------------------------------------------------
-- Trades
--------------------------------------------------------------------------------

local offered -- what you've put in the trade window: { { item, count }, ... }

-- The slot after MAX_TRADABLE_ITEMS is "will not be traded", for enchanting.
local function ReadTrade()
	offered = {}
	for i = 1, MAX_TRADABLE_ITEMS or 6 do
		local name, _, count = GetTradePlayerItemInfo(i)
		local item = ns.Clean(GetTradePlayerItemLink(i)) or ns.Clean(name)
		if item then
			offered[#offered + 1] = { item = item, count = Count(count) }
		end
	end
end

ns.On("TL_OPEN", function(context)
	if context == "trade" then
		offered = nil
	end
end)
ns.On("TRADE_PLAYER_ITEM_CHANGED", ReadTrade)
ns.On("TRADE_ACCEPT_UPDATE", ReadTrade)

-- There is no "trade done" event, only this message, which can come after
-- the window has closed.
ns.On("UI_INFO_MESSAGE", function(_, text)
	if not offered or type(ERR_TRADE_COMPLETE) ~= "string" or ns.Clean(text) ~= ERR_TRADE_COMPLETE then
		return
	end
	if #offered > 0 then
		ns.Log("give", ns.WithCounterpart({ items = offered }, "trade"))
		Gave(offered, "trade")
	end
	offered = nil
end)

--------------------------------------------------------------------------------
-- Mail
--------------------------------------------------------------------------------

local ATTACHMENTS_SEND = 12 -- ATTACHMENTS_MAX_SEND, once Blizzard_MailFrame has loaded
local mailing -- the mail being sent: { recipient, items }

-- The attachments only give an item ID, so the link is the plain item's.
hooksecurefunc("SendMail", function(recipient)
	local items = {}
	for i = 1, ATTACHMENTS_MAX_SEND or ATTACHMENTS_SEND do
		local name, id, _, count = GetSendMailItem(i)
		id = ns.Clean(id)
		local item = id and select(2, C_Item.GetItemInfo(id)) or ns.Clean(name)
		if item then
			items[#items + 1] = { item = item, count = Count(count) }
		end
	end
	mailing = #items > 0 and { recipient = ns.Clean(recipient), items = items } or nil
end)

ns.On("MAIL_SEND_SUCCESS", function()
	if mailing then
		ns.Log("send", { items = mailing.items, recipient = mailing.recipient })
		Gave(mailing.items, "mail")
	end
	mailing = nil
end)
ns.On("MAIL_FAILED", function()
	mailing = nil
end)

--------------------------------------------------------------------------------
-- Destroyed items
--------------------------------------------------------------------------------

-- What's on the cursor, as last picked up: { item, count }. Deleting clears
-- the cursor before a hook can look, so it's read when picked up.
local held

local function Hold(count)
	local kind, _, link = GetCursorInfo()
	held = kind == "item" and ns.Clean(link) and { item = ns.Clean(link), count = Count(count) } or nil
end

hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	Hold(info and info.stackCount)
end)
hooksecurefunc(C_Container, "SplitContainerItem", function(_, _, amount)
	Hold(amount)
end)
hooksecurefunc("PickupInventoryItem", function()
	Hold(1)
end)
hooksecurefunc("ClearCursor", function()
	held = nil
end)

hooksecurefunc("DeleteCursorItem", function()
	-- Protected items leave the cursor in place while Blizzard asks for
	-- confirmation. The accepted second call clears it; a cancellation goes
	-- through ClearCursor above.
	if held and not GetCursorInfo() and ns.char then
		ns.Mark("destroy")
		ns.Log("destroy", held)
		ns.Add(held.count, "given", "destroy")
	end
	if not GetCursorInfo() then
		held = nil
	end
end)

--------------------------------------------------------------------------------
-- Guild bank
--------------------------------------------------------------------------------

-- Items moved between your bags and the guild bank, one entry per visit. The
-- server does the moving, so it's read from your bags: what they gained or
-- lost soon after a guild bank click. Other bag changes (equipping) don't
-- count.
local GUILD_BANK_CLICK = 10 -- seconds a click's move may take, holding the item on the cursor included
local bagCounts -- item link -> count in your bags, while the guild bank is open
local moved     -- this visit's { deposited = { link -> count }, withdrawn = { link -> count } }

local function CountBags()
	local counts = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local link = info and ns.Clean(info.hyperlink)
			if link then
				counts[link] = (counts[link] or 0) + Count(info.stackCount)
			end
		end
	end
	return counts
end

local function Clicked()
	if ns.open.guildbank then
		ns.Mark("guildbankitem")
	end
end
for _, name in ipairs({ "PickupGuildBankItem", "AutoStoreGuildBankItem", "SplitGuildBankItem" }) do
	if _G[name] then
		hooksecurefunc(name, Clicked)
	end
end
-- Right-clicking a bag item with the guild bank open deposits it.
hooksecurefunc(C_Container, "UseContainerItem", Clicked)

-- Adds what grew from "from" to "to" into "into".
local function AddGrowth(into, from, to)
	for link, n in pairs(to) do
		local was = from[link] or 0
		if n > was then
			into[link] = (into[link] or 0) + n - was
		end
	end
end

local function LeaveGuildBank()
	if not moved then
		return
	end
	local deposited, withdrawn = ns.ItemList(moved.deposited), ns.ItemList(moved.withdrawn)
	bagCounts, moved = nil, nil
	if deposited or withdrawn then
		ns.Log("guildbank", { deposited = deposited, withdrawn = withdrawn, guild = ns.char.guild and ns.char.guild.name })
		for _, it in ipairs(deposited or {}) do ns.Add(it.count, "guildBank", "deposited") end
		for _, it in ipairs(withdrawn or {}) do ns.Add(it.count, "guildBank", "withdrawn") end
	end
end

ns.On("TL_OPEN", function(context)
	if context == "guildbank" then
		bagCounts, moved = CountBags(), { deposited = {}, withdrawn = {} }
	end
end)
ns.On("BAG_UPDATE_DELAYED", function()
	if not bagCounts then
		return
	end
	local counts = CountBags()
	if ns.Recent("guildbankitem", GUILD_BANK_CLICK) then
		AddGrowth(moved.withdrawn, bagCounts, counts)
		AddGrowth(moved.deposited, counts, bagCounts)
	end
	bagCounts = counts
end)
ns.On("TL_CLOSE", function(context)
	if context == "guildbank" then
		LeaveGuildBank()
	end
end)
ns.On("PLAYER_LOGOUT", LeaveGuildBank)
