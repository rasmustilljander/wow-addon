-- Auctions you post, and how each ends: sold, expired or cancelled. A post
-- stays open in TravelLogCharDB.auctions until all its items have ended.
-- A cancel is seen at the auction house; a sale when you take its money from
-- the mail, an expiry when you take the item back.
local _, ns = ...

local WAIT = 5 -- seconds a mail take's money or item may take to arrive

-- Counts can come back as nil or 0 for single items.
local function Count(n)
	return math.max(ns.Clean(n) or 1, 1)
end

-- "[Copper Ore]" from a link, or the name itself.
local function NameOf(item)
	return type(item) == "string" and (item:match("%[(.-)%]") or item) or nil
end

-- Open posts, oldest first: { entry = the post's log index, left = items not
-- yet ended, ids = { auction IDs } }.
local function Open()
	ns.char.auctions = ns.char.auctions or {}
	return ns.char.auctions
end

local function PostOf(open)
	local e = ns.char.log[open.entry]
	return e and e.type == "post" and e or nil
end

--------------------------------------------------------------------------------
-- Posting
--------------------------------------------------------------------------------

local posting -- the auction being posted: { item, count, bid, buyout }
local posted  -- the open post that more auctions from the same click join

-- A post that needs confirming comes again as ConfirmPost*. Either way it's
-- recorded once the auction exists. The money it costs is its deposit.
local function Post(location, _, quantity, bid, buyout)
	ns.Mark("deposit")
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
-- records them all, and each adds its ID to the open post.
ns.On("AUCTION_HOUSE_AUCTION_CREATED", function(id)
	if posting then
		ns.Log("post", posting)
		ns.Add(posting.count, "given", "auction")
		posted = { entry = #ns.char.log, left = posting.count, ids = {} }
		table.insert(Open(), posted)
	end
	posting = nil
	id = ns.Clean(id)
	if posted and id then
		table.insert(posted.ids, id)
	end
end)
ns.On("TL_CLOSE", function(context)
	if context == "auction" then
		posting, posted = nil, nil
	end
end)

--------------------------------------------------------------------------------
-- Endings
--------------------------------------------------------------------------------

local function Has(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
end

-- Open posts an ending belongs to: the one with its auction ID, or else
-- those of the same item, oldest first.
local function Matching(id, name)
	local found, list = {}, Open()
	for i = #list, 1, -1 do
		if not PostOf(list[i]) then
			table.remove(list, i) -- its entry is gone
		end
	end
	for _, open in ipairs(list) do
		if id and Has(open.ids, id) then
			return { open }
		elseif NameOf(PostOf(open).item) == name then
			found[#found + 1] = open
		end
	end
	return found
end

-- Logs an auction's end ("sold", "expired" or "cancelled") from data
-- { item, count, price, buyer }, and adds it to the posts it came from.
local function End(result, data, id)
	local matched = Matching(id, NameOf(data.item))
	local first = matched[1]
	-- A cancel without the auction's quantity takes its share of the post.
	data.count = data.count or first and math.ceil(first.left / math.max(#first.ids, 1)) or 1
	local left = data.count
	for _, open in ipairs(matched) do
		local post, n = PostOf(open), math.min(left, open.left)
		if n > 0 then
			post[result] = (post[result] or 0) + n
			open.left, left = open.left - n, left - n
			data.posted = data.posted or post.time
			data.item = data.item and data.item:find("|H") and data.item or post.item
		end
		if id and Has(open.ids, id) then
			table.remove(open.ids, Has(open.ids, id))
		end
		if open.left <= 0 then
			table.remove(Open(), Has(Open(), open))
		end
	end
	data.result = result
	ns.Log("auction", data)
	ns.Add(data.count, "auctions", result)
end

-- Cancelling: the auction's item and quantity are read as you cancel it, and
-- the cancel counts once the auction house confirms it.
local cancelling = {} -- auction ID -> { item, count }

if C_AuctionHouse and C_AuctionHouse.CancelAuction then
	hooksecurefunc(C_AuctionHouse, "CancelAuction", function(id)
		id = ns.Clean(id)
		if not id then
			return
		end
		cancelling[id] = {}
		for _, a in ipairs(C_AuctionHouse.GetOwnedAuctions() or {}) do
			if ns.Clean(a.auctionID) == id then
				cancelling[id] = { item = ns.Clean(a.itemLink), count = ns.Clean(a.quantity) }
			end
		end
	end)
end

ns.On("AUCTION_CANCELED", function(id)
	id = ns.Clean(id)
	local c = id and cancelling[id]
	if c then
		cancelling[id] = nil
		End("cancelled", c, id)
	end
end)

-- A sale's money taken from the mail: { item (name), count, price, buyer }.
function ns.AuctionSold(sale)
	End("sold", { item = sale.item, count = Count(sale.count), price = sale.price, buyer = sale.buyer })
end

-- The auction house's mails, known by subject: items back from an expired or
-- cancelled auction, and items won.
local SUBJECTS = {
	AUCTION_EXPIRED_MAIL_SUBJECT = "expired", AUCTION_REMOVED_MAIL_SUBJECT = "cancelled",
	AUCTION_WON_MAIL_SUBJECT = "won",
}
local subjects = {}
for name, kind in pairs(SUBJECTS) do
	if type(_G[name]) == "string" then
		subjects[#subjects + 1] = { pattern = ns.ToPattern(_G[name]), kind = kind }
	end
end

local mail -- the kind of auction house mail last taken from, or nil for another

local function TookMail(index)
	local subject = ns.Clean((select(4, GetInboxHeaderInfo(index))))
	mail = nil
	for _, s in ipairs(subjects) do
		if type(subject) == "string" and subject:match(s.pattern) then
			mail = s.kind
		end
	end
	ns.Mark("auctionmail")
end
hooksecurefunc("TakeInboxItem", TookMail)
hooksecurefunc("AutoLootMailItem", TookMail)

-- How an item taken from the mail came: "returned" from an auction that
-- didn't sell, "auction" when won, or nil from other mail.
function ns.AuctionMailHow()
	if mail and ns.open.mail and ns.Recent("auctionmail", WAIT) then
		return mail == "won" and "auction" or "returned"
	end
end

-- An item back in your bags from the mail: an expired auction ends. A
-- cancelled one ended when you cancelled it.
function ns.AuctionReturned(item, count)
	if mail == "expired" then
		End("expired", { item = item, count = count })
	end
end
