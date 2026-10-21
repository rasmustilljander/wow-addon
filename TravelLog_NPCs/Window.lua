-- The TravelLog window, when TravelLog is installed: an NPC row in its
-- totals, pin checkboxes in its settings, and an NPCs tab to search NPCs by
-- name, title, place or what they sell. Clicking one shows where it is and
-- its items; with none picked, the tab shows which kinds have pins.
local _, ns = ...

local tl = TravelLog
if not (tl and tl.AddTab) then
	return
end

local Count = ns.Count

local HEIGHT = 340     -- the NPCs tab, at least
local ROW_HEIGHT = 18
local LIST_WIDTH = 190 -- the NPC list
local DETAIL_X = 232   -- the selected NPC, right of the list and its scroll bar
local DETAIL_WIDTH = 196
local ZONE_WIDTH = 72  -- a list row's place

--------------------------------------------------------------------------------
-- Totals and settings
--------------------------------------------------------------------------------

tl.AddStat("Travel", "NPCs", function()
	local npcs = 0
	for _ in pairs(ns.db.npcs) do
		npcs = npcs + 1
	end
	return ("%s, selling %s items"):format(Count(npcs), Count(ns.ItemCount()))
end)
tl.AddSetting("World map", "NPCs on the minimap", function()
	return ns.db.settings.minimap
end, function(on)
	ns.db.settings.minimap = on
	ns.Changed()
end)
tl.AddSetting("World map", "NPCs on the world map", function()
	return ns.db.settings.worldMap
end, function(on)
	ns.db.settings.worldMap = on
	ns.Changed()
end)

--------------------------------------------------------------------------------
-- The NPCs tab
--------------------------------------------------------------------------------

local page     -- the tab's page, once the window exists
local selected -- ID of the NPC whose details are shown
local drawn    -- what the tab last showed; it's redrawn only when that changes

-- An NPC's items, by name.
local function Items(npc)
	local list = {}
	for id, item in pairs(npc.items or {}) do
		list[#list + 1] = { id = id, item = item, name = item.name or C_Item.GetItemInfo(id) or ("Item #" .. id) }
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.id < b.id
	end)
	return list
end

local function Refresh()
	if not ns.db then
		return
	end
	local search = page.search:GetText()
	-- The minute keeps "visited 2h ago" current.
	local state = ("%d\n%d\n%s\n%s"):format(ns.version, time() / 60, search, tostring(selected))
	if state == drawn then
		return
	end
	drawn = state

	local found, total = ns.Search(search), 0
	for _ in pairs(ns.db.npcs) do
		total = total + 1
	end
	page.npcs:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
	page.found:SetText(search == "" and ("%s NPCs"):format(Count(total))
		or ("%s of %s NPCs"):format(Count(#found), Count(total)))

	local npc = selected and ns.db.npcs[selected]
	if not npc then
		selected = nil
	end
	page.title:SetText(npc and npc.name or "")
	page.kinds:SetText(npc and ((npc.title and npc.title .. ", " or "") .. ns.KindsText(npc)) or "")
	page.where:SetText(npc and ns.Where(npc) or "")
	page.seen:SetText(npc and ("Visited %s ago"):format(ns.Ago(npc.seen)) or "")
	page.show:SetShown(npc ~= nil)
	page.show:SetChecked(npc and not npc.hidden)
	local items = npc and Items(npc) or {}
	page.sells:SetText(#items > 0 and ("Sells %d item%s"):format(#items, #items == 1 and "" or "s") or "")
	page.items:SetDataProvider(CreateDataProvider(items))
	page.items:SetShown(npc ~= nil)

	page.hint:SetText(npc and "" or total == 0 and "No NPCs yet. Talk to a vendor, trainer or flight master."
		or "Click an NPC for details. Pins on the maps:")
	for _, check in ipairs(page.kindChecks) do
		check:SetShown(not npc)
		check:SetChecked(not ns.db.settings.hideKinds[check.key])
	end
end

-- A text on the left and a short one on the right.
local function SetUpRow(row, rightWidth)
	row.right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.right:SetPoint("RIGHT", -4, 0)
	row.right:SetJustifyH("RIGHT")
	row.right:SetWordWrap(false)
	if rightWidth then
		row.right:SetWidth(rightWidth)
	end
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("LEFT", 4, 0)
	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)
end

local function InitNPCRow(row, match)
	if not row.name then
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(1, 0.82, 0, 0.15)
		SetUpRow(row, ZONE_WIDTH)
		row.icon:SetSize(8, 8)
		row.icon:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		-- Clicking the shown NPC again goes back to the kinds.
		row:SetScript("OnClick", function()
			selected = selected ~= row.id and row.id or nil
			Refresh()
		end)
	end
	local npc = match.npc
	row.id = match.id
	local c = ns.Kind(npc).color
	row.icon:SetVertexColor(c[1], c[2], c[3], 1)
	row.name:SetText(npc.name)
	-- Hidden NPCs are grayed out.
	row.name:SetTextColor(npc.hidden and 0.5 or 1, npc.hidden and 0.5 or 1, npc.hidden and 0.5 or 1)
	row.right:SetText(npc.subzone or npc.zone or "")
	row.selected:SetShown(match.id == selected)
end

local function InitItemRow(row, entry)
	if not row.name then
		SetUpRow(row)
		row.icon:SetSize(14, 14)
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
	row.itemID = entry.id
	row.icon:SetTexture(select(5, C_Item.GetItemInfoInstant(entry.id)))
	row.name:SetText(entry.name)
	row.right:SetText(ns.PriceText(entry.item))
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

local function Check(f, y, onClick)
	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", DETAIL_X - 4, y + 4)
	check.Text:SetFontObject(GameFontNormal)
	check:SetScript("OnClick", function(self)
		onClick(self, self:GetChecked())
		Refresh()
	end)
	return check
end

local function Build(f)
	page = f
	f.search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	f.search:SetSize(LIST_WIDTH - 6, 20)
	f.search:SetPoint("TOPLEFT", 22, 0)
	f.search:HookScript("OnTextChanged", Refresh)
	f.found = Text(f, "GameFontHighlightSmall", DETAIL_X, -4, DETAIL_WIDTH)

	f.npcs = List(f, InitNPCRow, "Button")
	f.npcs:SetPoint("TOPLEFT", 14, -28)
	f.npcs:SetPoint("BOTTOMLEFT", 14, 8)
	f.npcs:SetWidth(LIST_WIDTH)

	f.title = Text(f, "GameFontNormalLarge", DETAIL_X, -28, DETAIL_WIDTH)
	f.kinds = Text(f, "GameFontHighlight", DETAIL_X, -50, DETAIL_WIDTH)
	f.where = Text(f, "GameFontHighlightSmall", DETAIL_X, -66, DETAIL_WIDTH)
	f.seen = Text(f, "GameFontHighlightSmall", DETAIL_X, -80, DETAIL_WIDTH)
	f.show = Check(f, -96, function(_, on)
		ns.db.npcs[selected].hidden = not on or nil
		ns.Changed()
	end)
	f.show.Text:SetText("Pins on the maps")
	f.sells = Text(f, "GameFontNormal", DETAIL_X, -124, DETAIL_WIDTH)
	f.items = List(f, InitItemRow, "Button")
	f.items:SetPoint("TOPLEFT", DETAIL_X - 4, -142)
	f.items:SetPoint("BOTTOMLEFT", DETAIL_X - 4, 8)
	f.items:SetWidth(DETAIL_WIDTH)

	f.hint = Text(f, "GameFontDisable", DETAIL_X, -28, DETAIL_WIDTH)
	f.hint:SetWordWrap(true)
	f.kindChecks = {}
	for i, kind in ipairs(ns.KINDS) do
		local check = Check(f, -60 - (i - 1) * 22, function(_, on)
			ns.db.settings.hideKinds[kind.key] = not on or nil
			ns.Changed()
		end)
		check.key = kind.key
		check.Text:SetText(kind.label)
		check.Text:SetTextColor(kind.color[1], kind.color[2], kind.color[3])
		f.kindChecks[i] = check
	end
end

tl.AddTab("NPCs", HEIGHT, Build, Refresh)

-- /npcs window
function ns.ShowWindow()
	tl.ShowTab("NPCs")
end
