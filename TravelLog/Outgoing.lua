-- Items that leave your bags: handed over in a trade, sent by mail, put up
-- for auction or destroyed. Money that goes with them is the money ledger's.
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
-- Auctions
--------------------------------------------------------------------------------

local posting -- the auction being posted: { item, count, bid, buyout }

-- A post that needs confirming comes again as ConfirmPost*. Either way it's
-- recorded once the auction exists.
local function Post(location, _, quantity, bid, buyout)
	local item = C_Item.DoesItemExist(location) and ns.Clean(C_Item.GetItemLink(location))
	posting = item and { item = item, count = Count(quantity), bid = ns.Clean(bid), buyout = ns.Clean(buyout) } or nil
end

-- Commodities have one price per item.
local function PostCommodity(location, duration, quantity, unitPrice)
	unitPrice, quantity = ns.Clean(unitPrice), ns.Clean(quantity)
	Post(location, duration, quantity, nil, unitPrice and quantity and unitPrice * quantity)
end

if C_AuctionHouse then
	for name, fn in pairs({ PostItem = Post, ConfirmPostItem = Post,
		PostCommodity = PostCommodity, ConfirmPostCommodity = PostCommodity }) do
		if C_AuctionHouse[name] then
			hooksecurefunc(C_AuctionHouse, name, fn)
		end
	end
end

-- Posting several stacks of an item creates an auction for each; the first
-- records them all.
ns.On("AUCTION_HOUSE_AUCTION_CREATED", function()
	if posting then
		ns.Log("post", posting)
		ns.Add(posting.count, "given", "auction")
	end
	posting = nil
end)
ns.On("TL_CLOSE", function(context)
	if context == "auction" then
		posting = nil
	end
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
	if held and ns.char then
		ns.Log("destroy", held)
		ns.Add(held.count, "given", "destroy")
	end
	held = nil
end)
