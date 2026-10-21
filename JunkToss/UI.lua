-- JunkToss window: what's in the bags to throw away, cheapest first, on the
-- left, and the allowlist on the right.
local _, ns = ...

local ROW_HEIGHT = 20
local GRAY = "|cff9d9d9d"

local window

local function ShowItemTooltip(row)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(row.link)
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

-- The parts both lists' rows share: highlight, icon and name.
local function CreateRowParts(row)
	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("LEFT", 2, 0)
	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row:SetScript("OnEnter", ShowItemTooltip)
	row:SetScript("OnLeave", HideTooltip)
end

local function InitBagRow(row, item)
	if not row.name then
		CreateRowParts(row)
		row.next = row:CreateTexture(nil, "BACKGROUND")
		row.next:SetAllPoints()
		row.next:SetColorTexture(1, 0.82, 0, 0.15)
		row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.value:SetPoint("RIGHT", -4, 0)
		row.value:SetWidth(90)
		row.value:SetJustifyH("RIGHT")
		row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
	end
	row.item, row.link = item, item.link
	row.icon:SetTexture(item.icon)
	row.name:SetText(item.link .. (item.count > 1 and " x" .. item.count or "")
		.. (item.allowed and GRAY .. " (allowlist)|r" or ""))
	row.value:SetText(ns.Money(item.value))
	-- The next one the minimap button throws away.
	row.next:SetShown(item == window.candidates[1])
end

local function InitAllowRow(row, entry)
	if not row.name then
		CreateRowParts(row)
		row.remove = CreateFrame("Button", nil, row)
		row.remove:SetSize(16, 16)
		row.remove:SetPoint("RIGHT", -4, 0)
		row.remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
		row.remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
		row.remove:SetScript("OnClick", function()
			ns.Disallow(row.entry.id)
		end)
		row.name:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
	end
	row.entry, row.link = entry, entry.link
	row.icon:SetTexture(select(5, C_Item.GetItemInfoInstant(entry.id)))
	row.name:SetText(entry.link)
end

-- Redraws both lists, keeping their scroll positions.
function ns.Refresh()
	if not window or not window:IsShown() then
		return
	end
	local candidates = ns.Candidates()
	local total = 0
	for _, item in ipairs(candidates) do
		total = total + item.value
	end
	window.candidates = candidates
	window.bags:SetDataProvider(CreateDataProvider(candidates), ScrollBoxConstants.RetainScrollPosition)
	window.bagsEmpty:SetShown(#candidates == 0)
	window.count:SetText(#candidates == 0 and "" or
		(#candidates == 1 and "1 stack" or #candidates .. " stacks") .. ", " .. ns.Money(total))
	window.throw:SetEnabled(#candidates > 0)

	local allowlist = ns.Allowlist()
	window.allow:SetDataProvider(CreateDataProvider(allowlist), ScrollBoxConstants.RetainScrollPosition)
	window.allowEmpty:SetShown(#allowlist == 0)
	window.minimap:SetChecked(not JunkTossDB.minimap.hide)
end

-- Adds the item on the cursor to the allowlist and puts it back in the bags.
local function AddFromCursor()
	local kind, id, link = GetCursorInfo()
	if kind == "item" then
		ClearCursor()
		ns.Allow(id, link)
	end
end

local function List(parent, init)
	local list = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", init)
	ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)
	return list
end

local function Label(parent, text, template)
	local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
	label:SetText(text)
	return label
end

local function CreateWindow()
	local f = CreateFrame("Frame", "JunkTossFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(700, 440)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)   -- we keep the position ourselves
		local point, _, relativePoint, x, y = self:GetPoint()
		JunkTossDB.point = { point, relativePoint, x, y }
	end)
	local point = JunkTossDB.point
	if point then
		f:SetPoint(point[1], UIParent, point[2], point[3], point[4])
	else
		f:SetPoint("CENTER")
	end
	f.TitleText:SetText("JunkToss")
	f:HookScript("OnShow", ns.Refresh)
	-- Escape closes it.
	table.insert(UISpecialFrames, f:GetName())

	-- Left: the bags.
	local bagsLabel = Label(f, "In your bags, cheapest first")
	bagsLabel:SetPoint("TOPLEFT", 18, -34)
	f.bags = List(f, InitBagRow)
	f.bags:SetPoint("TOPLEFT", 12, -56)
	f.bags:SetPoint("BOTTOMLEFT", 12, 44)
	f.bags:SetWidth(340)
	f.bagsEmpty = Label(f, "No greys or allowlisted items in your bags.", "GameFontDisable")
	f.bagsEmpty:SetPoint("CENTER", f.bags, "CENTER")

	f.throw = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.throw:SetSize(140, 22)
	f.throw:SetText("Throw away cheapest")
	f.throw:SetPoint("BOTTOMLEFT", 14, 14)
	f.throw:SetScript("OnClick", function()
		ns.Throw()
	end)
	f.count = Label(f, "", "GameFontHighlightSmall")
	f.count:SetPoint("LEFT", f.throw, "RIGHT", 10, 0)

	-- Right: the allowlist.
	local allowLabel = Label(f, "Allowlist")
	allowLabel:SetPoint("TOPLEFT", f.bags, "TOPRIGHT", 30, 22)
	local note = Label(f, "Thrown away like greys, whatever their quality.", "GameFontDisableSmall")
	note:SetPoint("LEFT", allowLabel, "RIGHT", 8, 0)

	local drop = CreateFrame("Button", nil, f)
	drop:SetPoint("TOPLEFT", f.bags, "TOPRIGHT", 28, 0)
	drop:SetPoint("RIGHT", -16, 0)
	drop:SetHeight(36)
	local bg = drop:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.35)
	local highlight = drop:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 0.82, 0, 0.12)
	local dropText = Label(drop, "Drop an item here to add it", "GameFontHighlight")
	dropText:SetPoint("CENTER")
	drop:SetScript("OnReceiveDrag", AddFromCursor)
	drop:SetScript("OnClick", AddFromCursor)
	f.drop = drop

	f.allow = List(f, InitAllowRow)
	f.allow:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -8)
	f.allow:SetPoint("BOTTOMRIGHT", -32, 44)
	f.allowEmpty = Label(f, "Nothing allowlisted.", "GameFontDisable")
	f.allowEmpty:SetPoint("CENTER", f.allow, "CENTER")

	f.minimap = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.minimap:SetSize(24, 24)
	f.minimap:SetPoint("BOTTOMLEFT", f.allow, "BOTTOMLEFT", -4, -34)
	f.minimap.Text:SetText("Minimap button")
	f.minimap:SetScript("OnClick", function(self)
		ns.ShowMinimapButton(self:GetChecked())
	end)
	return f
end

-- /junk: toggles the window.
function ns.Toggle()
	if not window then
		window = CreateWindow()
		window:Hide()
	end
	window:SetShown(not window:IsShown())
	ns.window = window
end
