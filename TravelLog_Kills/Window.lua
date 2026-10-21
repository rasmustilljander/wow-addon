-- The TravelLog window, when TravelLog is installed: kill rows in its totals,
-- a Kills checkbox in its settings, and a Kills view in its History tab
-- listing every mob you've killed. Clicking a mob there shows the zones you
-- killed it in.
local _, ns = ...

local tl = TravelLog
if not (tl and tl.AddTab) then
	return
end

local Count = ns.Count

local HEIGHT = 300     -- the Kills view, at least
local ROW_HEIGHT = 18
local LIST_WIDTH = 210 -- the mob list
local DETAIL_X = 252   -- the selected mob, right of the list and its scroll bar
local DETAIL_WIDTH = 176

--------------------------------------------------------------------------------
-- Totals and settings
--------------------------------------------------------------------------------

tl.AddStat("Life", "All kills", function()
	local mobs = 0
	for _ in pairs(ns.db.mobs) do
		mobs = mobs + 1
	end
	return ("%s of %s mobs"):format(Count(ns.db.total), Count(mobs))
end)
tl.AddStat("Life", "Most killed", function()
	local best
	for _, mob in pairs(ns.db.mobs) do
		if not best or mob.count > best.count then
			best = mob
		end
	end
	return best and ("%s (%s)"):format(best.name, Count(best.count)) or "nothing yet"
end)
tl.AddSetting("World map", function()
	return "Kills" .. (ns.db.settings.mapFilter and ns.db.settings.map
		and (": only %s"):format(ns.db.settings.mapFilter) or "")
end, function()
	return ns.db.settings.map
end, function(on)
	ns.db.settings.map, ns.db.settings.mapFilter = on, nil
	ns.RefreshMap()
end)

--------------------------------------------------------------------------------
-- The Kills view
--------------------------------------------------------------------------------

local page     -- the view's page, once the window exists
local selected -- name of the mob whose zones are shown
local drawn    -- what the view last showed; it's redrawn only when that changes

-- A mob's kills per zone, most first.
local function Zones(mob)
	local counts = {}
	for _, rec in ipairs(mob.kills) do
		local zone = ns.UnpackKill(rec).zone or "Unknown"
		counts[zone] = (counts[zone] or 0) + 1
	end
	local list = {}
	for zone, n in pairs(counts) do
		list[#list + 1] = { name = zone, count = n }
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.name < b.name
	end)
	return list
end

local function Refresh()
	if not ns.db then
		return
	end
	local search = page.search:GetText()
	-- The minute keeps "last 2h ago" current.
	local state = ("%d\n%d\n%s\n%s"):format(ns.version, time() / 60, search, selected or "")
	if state == drawn then
		return
	end
	drawn = state

	local all, found, text = ns.SortedMobs(), {}, search:lower()
	for _, mob in ipairs(all) do
		if mob.name:lower():find(text, 1, true) then
			found[#found + 1] = mob
		end
	end
	page.mobs:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
	if search == "" then
		page.found:SetText(("%s mobs, %s kills"):format(Count(#all), Count(ns.db.total)))
	else
		page.found:SetText(("%s of %s mobs"):format(Count(#found), Count(#all)))
	end

	local mob = selected and ns.db.mobs[selected]
	page.title:SetText(mob and mob.name or "")
	page.summary:SetText(mob and ("%s kill%s, last %s ago"):format(Count(mob.count),
		mob.count == 1 and "" or "s", ns.Ago(mob.last)) or "")
	page.first:SetText(mob and ("First %s"):format(date("%Y-%m-%d %H:%M", mob.first)) or "")
	page.zones:SetDataProvider(CreateDataProvider(mob and Zones(mob) or {}))
	page.hint:SetText(mob and "" or #all == 0 and "No kills yet." or "Click a mob to see where you killed it.")
end

-- A name on the left and a count on the right.
local function SetUpRow(row)
	row.count = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.count:SetPoint("RIGHT", -4, 0)
	row.count:SetJustifyH("RIGHT")
	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
end

local function InitMobRow(row, mob)
	if not row.name then
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(1, 0.82, 0, 0.15)
		SetUpRow(row)
		row:SetScript("OnClick", function()
			selected = row.mob.name
			Refresh()
		end)
	end
	row.mob = mob
	row.name:SetText(mob.name)
	row.count:SetText(Count(mob.count))
	row.selected:SetShown(mob.name == selected)
end

local function InitZoneRow(row, zone)
	if not row.name then
		SetUpRow(row)
	end
	row.name:SetText(zone.name)
	row.count:SetText(Count(zone.count))
end

local function List(parent, init, kind)
	local list = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
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

	f.mobs = List(f, InitMobRow, "Button")
	f.mobs:SetPoint("TOPLEFT", 14, -28)
	f.mobs:SetPoint("BOTTOMLEFT", 14, 8)
	f.mobs:SetWidth(LIST_WIDTH)

	f.title = Text(f, "GameFontNormalLarge", DETAIL_X, -28, DETAIL_WIDTH)
	f.summary = Text(f, "GameFontHighlight", DETAIL_X, -50, DETAIL_WIDTH)
	f.first = Text(f, "GameFontHighlightSmall", DETAIL_X, -66, DETAIL_WIDTH)
	f.zones = List(f, InitZoneRow, "Frame")
	f.zones:SetPoint("TOPLEFT", DETAIL_X - 4, -86)
	f.zones:SetPoint("BOTTOMLEFT", DETAIL_X - 4, 8)
	f.zones:SetWidth(DETAIL_WIDTH)
	f.hint = Text(f, "GameFontDisable", DETAIL_X, -28, DETAIL_WIDTH)
	f.hint:SetWordWrap(true)
end

tl.AddHistoryView("Kills", HEIGHT, Build, Refresh)

-- /kills window
function ns.ShowWindow()
	tl.ShowHistory("Kills")
end
