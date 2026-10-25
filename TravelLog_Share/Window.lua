-- The Friends tab in the TravelLog window, opened with /tl share: your
-- friends, with how much of theirs you have. Type a name to add one; pick
-- one to see their totals or remove them.
local _, ns = ...
local tl = TravelLog

local HEIGHT = 200       -- the tab, at least
local ROW_HEIGHT = 18    -- a friend
local LIST_WIDTH = 170   -- the friend list
local DETAIL_X = 214     -- the selected friend, right of the list and its scroll bar
local DETAIL_WIDTH = 340
local WAITING = "|cffff9933waiting|r"

local page     -- the tab's page, once the window exists
local selected -- key of the friend shown on the right
local drawn    -- what the tab last showed; it's redrawn only when that changes

local function CountNodes(peer)
	local n = 0
	for _, list in pairs(peer and peer.nodes or {}) do
		for _ in pairs(list) do
			n = n + 1
		end
	end
	return n
end

-- Your friends by name: { key, name, peer }.
local function Friends()
	local list = {}
	for key, name in pairs(ns.db.friends) do
		list[#list + 1] = { key = key, name = name, peer = ns.db.peers[key] }
	end
	table.sort(list, function(a, b) return a.key < b.key end)
	return list
end

local function Tag(f)
	if ns.waiting[f.key] then
		return WAITING
	end
	local char = f.peer and f.peer.char
	return char and ("level %d"):format(char.level or 0) or ""
end

local function Status(f)
	local peer = f.peer or {}
	local lines = {}
	if ns.waiting[f.key] then
		lines[1] = "They haven't added you yet. Nothing is shared until you've both added each other."
	elseif peer.seen then
		lines[1] = ("Last heard from %s ago."):format(tl.Ago(peer.seen))
	else
		lines[1] = "Not heard from yet. They need TravelLog Share, and both of you need to be online."
	end
	lines[2] = ("Nodes: %d of theirs on your map."):format(CountNodes(peer))
	local char = peer.char
	lines[3] = char and ("Totals: level %d, from %s ago."):format(char.level or 0, tl.Ago(char.received))
		or "Totals: none yet."
	return table.concat(lines, "\n")
end

local function Refresh()
	if not ns.db then
		return
	end
	-- The minute keeps "2m ago" current.
	local state = ("%d\n%d\n%s"):format(ns.version, time() / 60, selected or "")
	if state == drawn then
		return
	end
	drawn = state

	local list = Friends()
	page.friends:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
	local f
	for _, friend in ipairs(list) do
		f = friend.key == selected and friend or f
	end
	page.detail:SetShown(f ~= nil)
	page.hint:SetShown(f == nil)
	if not f then
		return
	end
	local d = page.detail
	d.title:SetText(f.name)
	d.status:SetText(Status(f))
	d.totals:SetEnabled(f.peer and f.peer.char ~= nil)
end

local function InitRow(row, f)
	if not row.name then
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(1, 0.82, 0, 0.15)
		row.tag = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.tag:SetPoint("RIGHT", -4, 0)
		row.tag:SetJustifyH("RIGHT")
		row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.name:SetPoint("LEFT", 4, 0)
		row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row:SetScript("OnClick", function()
			selected = row.friend.key
			Refresh()
		end)
	end
	row.friend = f
	row.name:SetText(f.name)
	row.tag:SetText(Tag(f))
	row.selected:SetShown(f.key == selected)
end

local function Text(f, font, x, y, width)
	local text = f:CreateFontString(nil, "ARTWORK", font)
	text:SetPoint("TOPLEFT", x, y)
	text:SetWidth(width)
	text:SetJustifyH("LEFT")
	return text
end

local function Button(f, text, width, x, y, onClick)
	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetSize(width, 20)
	button:SetPoint("TOPLEFT", x, y)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function AddTyped()
	local name, key = ns.Name(page.name:GetText())
	if key and key ~= ns.me then
		page.name:SetText("")
		page.name:ClearFocus()
		if not ns.db.friends[key] then
			ns.AddFriend(name, key)
		end
		selected = key
		Refresh()
	end
end

local function Build(f)
	page = f
	f.name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.name:SetSize(LIST_WIDTH - 54, 20)
	f.name:SetPoint("TOPLEFT", 20, 0)
	f.name:SetAutoFocus(false)
	f.name:SetScript("OnEnterPressed", AddTyped)
	f.name:SetScript("OnEscapePressed", f.name.ClearFocus)
	f.add = Button(f, "Add", 48, LIST_WIDTH - 32, 0, AddTyped)

	f.friends = CreateFrame("Frame", nil, f, "WowScrollBoxList")
	f.friends:SetPoint("TOPLEFT", 14, -28)
	f.friends:SetPoint("BOTTOMLEFT", 14, 8)
	f.friends:SetWidth(LIST_WIDTH)
	local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", f.friends, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", f.friends, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(f.friends, bar, view)

	f.hint = Text(f, "GameFontDisable", DETAIL_X, -4, DETAIL_WIDTH)
	f.hint:SetText("Add a friend by name. Once you've both added each other, you see each other's"
		.. " looted nodes on the map and totals in the Totals tab and /tl stats.")

	local d = CreateFrame("Frame", nil, f)
	d:SetPoint("TOPLEFT", DETAIL_X, 0)
	d:SetPoint("BOTTOMLEFT", DETAIL_X, 0)
	d:SetWidth(DETAIL_WIDTH)
	f.detail = d
	d.title = Text(d, "GameFontNormalLarge", 0, -2, DETAIL_WIDTH)
	d.title:SetWordWrap(false)
	d.status = Text(d, "GameFontHighlightSmall", 0, -26, DETAIL_WIDTH)
	d.totals = Button(d, "Show totals", 100, 0, -84, function()
		tl.ShowTotals(ns.db.peers[selected].name)
	end)
	d.remove = Button(d, "Remove", 80, 106, -84, function()
		ns.RemoveFriend(selected)
		selected = nil
		Refresh()
	end)
end

tl.AddTab("Friends", HEIGHT, Build, Refresh)

tl.Command("share", "share - your friends, whose nodes and totals you see, in the Friends tab", function()
	tl.ShowTab("Friends")
end)
