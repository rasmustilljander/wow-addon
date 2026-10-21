-- The History tab, with a button per view along the top. Events, TravelLog's
-- own view, lists every event in this character's current log, newest first.
-- Category buttons narrow the kinds of event; the search also sees fields not
-- shown in a row, such as source IDs and a death's level. Companion addons
-- add views with ns.AddHistoryView.
local _, ns = ...

local HEIGHT = 320      -- the Events view
local VIEWS_HEIGHT = 26 -- the row of view buttons
local VIEW_WIDTH = 69
local ROW_HEIGHT = 34
local LIST_WIDTH = 410
local GROUPS = { "All", "Travel", "Loot", "Trade", "Life", "Progress" }
local GROUP_WIDTH = 69

local views = {} -- { name, height, build, refresh }, Events first
local history    -- the tab's page, once the window exists
local selectedView = 1
local page       -- the Events view
local selectedGroup
local drawn

-- Lights the chosen one of a row of buttons, with white text.
local function Light(buttons, chosen)
	for _, button in ipairs(buttons) do
		if button == chosen then
			button:LockHighlight()
			button:SetNormalFontObject(GameFontHighlight)
		else
			button:UnlockHighlight()
			button:SetNormalFontObject(GameFontNormal)
		end
	end
end

local function SetGroupButtons()
	for _, button in ipairs(page.groupButtons) do
		if button.group == (selectedGroup or "All") then
			Light(page.groupButtons, button)
		end
	end
end

local function RefreshEvents()
	if not ns.char then
		return
	end
	local search = page.search:GetText()
	local state = ("%d\n%s\n%s"):format(ns.version, search, selectedGroup or "All")
	if state == drawn then
		return
	end
	drawn = state

	local found = {}
	for i = #ns.char.log, 1, -1 do
		local e = ns.char.log[i]
		if ns.LogMatches(e, search, selectedGroup) then
			found[#found + 1] = e
		end
	end
	page.events:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
	if search == "" and not selectedGroup then
		page.found:SetText(("%s entries"):format(ns.Count(#found)))
	else
		page.found:SetText(("%s of %s entries"):format(ns.Count(#found), ns.Count(#ns.char.log)))
	end
	page.hint:SetShown(#found == 0)
	page.hint:SetText(#ns.char.log == 0 and "No events yet." or "No events match these filters.")
	SetGroupButtons()
end

local function InitRow(row, e)
	if not row.what then
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row.when = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.when:SetPoint("TOPRIGHT", -4, -2)
		row.when:SetJustifyH("RIGHT")
		row.what = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.what:SetPoint("TOPLEFT", 4, -2)
		row.what:SetPoint("RIGHT", row.when, "LEFT", -8, 0)
		row.what:SetJustifyH("LEFT")
		row.what:SetWordWrap(false)
		row.kind = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.kind:SetPoint("BOTTOMRIGHT", -4, 2)
		row.kind:SetJustifyH("RIGHT")
		row.where = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.where:SetPoint("BOTTOMLEFT", 4, 2)
		row.where:SetPoint("RIGHT", row.kind, "LEFT", -8, 0)
		row.where:SetJustifyH("LEFT")
		row.where:SetWordWrap(false)
	end
	local what, where = ns.Describe(e)
	row.event = e
	row.what:SetText(what)
	row.when:SetText(date("%Y-%m-%d %H:%M", e.time))
	row.where:SetText(where)
	row.kind:SetText(ns.LogTypeLabel(e))
end

local function List(parent)
	local list = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Frame", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
	return list
end

local function BuildEvents(f)
	page = f
	f.search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	f.search:SetSize(214, 20)
	f.search:SetPoint("TOPLEFT", 22, 0)
	f.search:HookScript("OnTextChanged", RefreshEvents)
	f.found = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.found:SetPoint("TOPRIGHT", -18, -4)
	f.found:SetJustifyH("RIGHT")

	f.groupButtons = {}
	for i, group in ipairs(GROUPS) do
		local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		button:SetSize(GROUP_WIDTH, 20)
		button:SetPoint("TOPLEFT", 14 + (i - 1) * GROUP_WIDTH, -27)
		button:SetText(group)
		button.group = group
		button:SetScript("OnClick", function(self)
			selectedGroup = self.group ~= "All" and self.group or nil
			drawn = nil
			RefreshEvents()
		end)
		f.groupButtons[i] = button
	end

	f.events = List(f)
	f.events:SetPoint("TOPLEFT", 14, -54)
	f.events:SetPoint("BOTTOMLEFT", 14, 8)
	f.events:SetWidth(LIST_WIDTH)
	f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	f.hint:SetPoint("TOPLEFT", 18, -62)
	f.hint:SetWidth(LIST_WIDTH - 8)
	f.hint:SetJustifyH("LEFT")
end

--------------------------------------------------------------------------------
-- The views
--------------------------------------------------------------------------------

-- Adds a view to the History tab, after Events. build(page) fills its page
-- when the window is first opened; the page is the window's width and at
-- least height tall. refresh(), if given, runs whenever the view is shown and
-- every second while it is.
function ns.AddHistoryView(name, height, build, refresh)
	views[#views + 1] = { name = name, height = height, build = build, refresh = refresh }
end

local function Refresh()
	local view = views[selectedView]
	if view.refresh then
		view.refresh()
	end
end

local function SelectView(i)
	selectedView = i
	for j, view in ipairs(views) do
		view.page:SetShown(i == j)
	end
	if history.viewButtons then
		Light(history.viewButtons, history.viewButtons[i])
	end
	Refresh()
end

-- The buttons show only when a companion adds a view.
local function Build(f)
	history = f
	local top = #views > 1 and -VIEWS_HEIGHT or 0
	local height = 0
	f.views = {}
	for i, view in ipairs(views) do
		view.page = CreateFrame("Frame", nil, f)
		view.page:SetPoint("TOPLEFT", 0, top)
		view.page:SetPoint("BOTTOMRIGHT")
		height = math.max(height, view.height or 0, view.build(view.page) or 0)
		f.views[i] = view.page
	end
	if #views > 1 then
		f.viewButtons = {}
		for i, view in ipairs(views) do
			local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
			button:SetSize(VIEW_WIDTH, 20)
			button:SetPoint("TOPLEFT", 14 + (i - 1) * VIEW_WIDTH, 0)
			button:SetText(view.name)
			button:SetScript("OnClick", function()
				SelectView(i)
			end)
			f.viewButtons[i] = button
		end
	end
	SelectView(selectedView)
	return height - top
end

-- Opens the window on the History view with this name.
function ns.ShowHistory(name)
	ns.ShowTab("History")
	for i, view in ipairs(views) do
		if view.name == name then
			SelectView(i)
		end
	end
end

ns.AddHistoryView("Events", HEIGHT, BuildEvents, RefreshEvents)
ns.AddTab("History", 0, Build, Refresh)
