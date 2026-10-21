-- The TravelLog window, when TravelLog is installed: group rows in its
-- totals and a Players tab listing everyone you've grouped with. Clicking a
-- player there shows each time you grouped: when, how long and where.
local _, ns = ...

local tl = TravelLog
if not (tl and tl.AddTab) then
	return
end

local Count, Duration = ns.Count, ns.Duration

local HEIGHT = 300     -- the Players tab, at least
local ROW_HEIGHT = 18  -- a player
local GROUP_HEIGHT = 30 -- a group: date and length, then where
local LIST_WIDTH = 210 -- the player list
local DETAIL_X = 252   -- the selected player, right of the list and its scroll bar
local DETAIL_WIDTH = 176

--------------------------------------------------------------------------------
-- Totals
--------------------------------------------------------------------------------

tl.AddStat("Life", "Grouped with", function()
	local players = 0
	for _ in pairs(ns.db.players) do
		players = players + 1
	end
	return ("%s players, %s times"):format(Count(players), Count(ns.db.total))
end)
tl.AddStat("Life", "Most grouped", function()
	local best = ns.SortedPlayers()[1]
	return best and ("%s (%s)"):format(ns.Display(best), Count(best.count)) or "nobody yet"
end)

--------------------------------------------------------------------------------
-- The Players tab
--------------------------------------------------------------------------------

local page     -- the tab's page, once the window exists
local selected -- key of the player whose groups are shown
local drawn    -- what the tab last showed; it's redrawn only when that changes

local function Refresh()
	if not ns.db then
		return
	end
	local search = page.search:GetText()
	-- The minute keeps "last 2h ago" and running groups current.
	local state = ("%d\n%d\n%s\n%s"):format(ns.version, time() / 60, search, selected or "")
	if state == drawn then
		return
	end
	drawn = state

	local all, found, text = ns.SortedPlayers(), {}, search:lower()
	for _, player in ipairs(all) do
		if player.key:lower():find(text, 1, true) then
			found[#found + 1] = player
		end
	end
	page.players:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
	if search == "" then
		page.found:SetText(("%s players, %s groups"):format(Count(#all), Count(ns.db.total)))
	else
		page.found:SetText(("%s of %s players"):format(Count(#found), Count(#all)))
	end

	local player = selected and ns.db.players[selected]
	local groups = player and ns.Groups(player) or {}
	local newest = {}
	for i = #groups, 1, -1 do
		newest[#newest + 1] = groups[i]
	end
	page.title:SetText(player and ns.Display(player) or "")
	page.summary:SetText(player and ("%s time%s, %s together"):format(Count(player.count),
		player.count == 1 and "" or "s", Duration(ns.TimeWith(player))) or "")
	page.first:SetText(player and ("First %s"):format(date("%Y-%m-%d %H:%M", player.first)) or "")
	local kills = player and ns.KillsWith(player) or 0
	page.last:SetText(player and ("%s%s"):format(ns.db.open[player.key] and "In your group now"
		or ("Last %s ago"):format(ns.Ago(player.last)), kills > 0 and (", %s kills"):format(Count(kills)) or "") or "")
	page.groups:SetDataProvider(CreateDataProvider(newest))
	page.hint:SetText(player and "" or #all == 0 and "Nobody yet. Join a group!"
		or "Click a player to see when you grouped.")
end

local function Line(row, font, anchor, y)
	local text = row:CreateFontString(nil, "ARTWORK", font)
	text:SetPoint(anchor, 4, y)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

local function InitPlayerRow(row, player)
	if not row.name then
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(1, 0.82, 0, 0.15)
		row.count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.count:SetPoint("RIGHT", -4, 0)
		row.count:SetJustifyH("RIGHT")
		row.name = Line(row, "GameFontHighlight", "LEFT", 0)
		row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
		row:SetScript("OnClick", function()
			selected = row.player.key
			Refresh()
		end)
	end
	row.player = player
	row.name:SetText(ns.Display(player))
	local r, g, b = 1, 1, 1
	if player.class then
		r, g, b = GetClassColor(player.class)
	end
	row.name:SetTextColor(r, g, b)
	row.count:SetText(Count(player.count))
	row.selected:SetShown(player.key == selected)
end

-- When and how long on top, where (and kills, level, raid) below.
local function InitGroupRow(row, g)
	if not row.when then
		row.length = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.length:SetPoint("TOPRIGHT", -4, -2)
		row.length:SetJustifyH("RIGHT")
		row.when = Line(row, "GameFontHighlight", "TOPLEFT", -2)
		row.when:SetPoint("RIGHT", row.length, "LEFT", -6, 0)
		row.where = Line(row, "GameFontDisableSmall", "TOPLEFT", -17)
		row.where:SetPoint("RIGHT", -4, 0)
	end
	row.when:SetText(date("%Y-%m-%d %H:%M", g.start))
	row.length:SetText(g.now and ("|cff40ff40%s|r"):format(Duration(g.seconds)) or Duration(g.seconds))
	row.where:SetText(ns.GroupText(g))
end

local function List(parent, init, kind, extent)
	local list = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(extent)
	view:SetElementInitializer(kind, init)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
	return list
end

local function Text(f, font, x, y, width)
	local text = f:CreateFontString(nil, "ARTWORK", font)
	text:SetPoint("TOPLEFT", x, y)
	text:SetWidth(width)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

local function Build(f)
	page = f
	f.search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	f.search:SetSize(LIST_WIDTH - 6, 20)
	f.search:SetPoint("TOPLEFT", 22, 0)
	f.search:HookScript("OnTextChanged", Refresh)
	f.found = Text(f, "GameFontHighlightSmall", DETAIL_X, -4, DETAIL_WIDTH)

	f.players = List(f, InitPlayerRow, "Button", ROW_HEIGHT)
	f.players:SetPoint("TOPLEFT", 14, -28)
	f.players:SetPoint("BOTTOMLEFT", 14, 8)
	f.players:SetWidth(LIST_WIDTH)

	f.title = Text(f, "GameFontNormalLarge", DETAIL_X, -28, DETAIL_WIDTH)
	f.summary = Text(f, "GameFontHighlight", DETAIL_X, -50, DETAIL_WIDTH)
	f.first = Text(f, "GameFontHighlightSmall", DETAIL_X, -66, DETAIL_WIDTH)
	f.last = Text(f, "GameFontHighlightSmall", DETAIL_X, -80, DETAIL_WIDTH)
	f.groups = List(f, InitGroupRow, "Frame", GROUP_HEIGHT)
	f.groups:SetPoint("TOPLEFT", DETAIL_X - 4, -98)
	f.groups:SetPoint("BOTTOMLEFT", DETAIL_X - 4, 8)
	f.groups:SetWidth(DETAIL_WIDTH)
	f.hint = Text(f, "GameFontDisable", DETAIL_X, -28, DETAIL_WIDTH)
	f.hint:SetWordWrap(true)
end

tl.AddTab("Players", HEIGHT, Build, Refresh)

-- /grouped window
function ns.ShowWindow()
	tl.ShowTab("Players")
end
