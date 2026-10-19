-- CVarBrowser window: a search box and filters on top, the CVar list on the
-- left, and the selected CVar's value and info box on the right.
local _, ns = ...

local ROW_HEIGHT = 20
local FILTERS = { { "all", "All" }, { "bookmarks", "Bookmarks" }, { "changed", "Changed" }, { "known", "Known" } }
local GOLD, WHITE, GRAY, RED = "|cffffd200", "|cffffffff", "|cff9d9d9d", "|cffff6060"

local window
local filter = "all"
local selected   -- the entry shown on the right

local function SetStar(texture, on)
	texture:SetAtlas(on and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
	texture:SetAlpha(on and 1 or 0.4)
end

-- The info box text: our description, the values, and the client's help.
function ns.InfoText(entry)
	local parts = {}
	local known = ns.Known(entry.name)
	if known then
		parts[#parts + 1] = known.text
		if known.values then
			parts[#parts + 1] = GOLD .. "Values:|r " .. known.values
		end
	end
	if entry.help then
		parts[#parts + 1] = GOLD .. "From the game:|r " .. entry.help
	end
	if #parts == 0 then
		return GRAY .. "No description known.|r"
	end
	return table.concat(parts, "\n\n")
end

local function ShowDetail()
	local d = window.detail
	local info = selected and ns.Info(selected.name)
	d:SetShown(info ~= nil)
	window.empty:SetShown(info == nil)
	if not info then
		return
	end
	d.name:SetText(selected.name)
	SetStar(d.star.icon, ns.IsBookmarked(selected.name))

	local meta = { selected.category }
	if selected.unlisted then
		meta[#meta + 1] = "not in the client's list"
	end
	if info.account then
		meta[#meta + 1] = "saved on the server for your account"
	elseif info.character then
		meta[#meta + 1] = "saved on the server for this character"
	end
	d.meta:SetText(table.concat(meta, ", "))

	if not d.edit:HasFocus() then
		d.edit:SetText(info.value)
	end
	d.defaultText:SetText("Default: " .. WHITE .. (info.default ~= "" and info.default or "(empty)") .. "|r")
	local blocked = not info.editable and "Addons can't change this CVar."
		or InCombatLockdown() and "CVars can't be changed in combat." or nil
	d.note:SetText(blocked and RED .. blocked .. "|r" or "")
	d.edit:SetEnabled(not blocked)
	d.set:SetEnabled(not blocked)
	d.reset:SetEnabled(not blocked and info.changed)
	d.toggle:SetShown(info.value == "0" or info.value == "1")
	d.toggle:SetEnabled(not blocked)
	d.info:SetText(ns.InfoText(selected))
end

local function InitRow(row, entry)
	if not row.name then
		local highlight = row:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		row.selected = row:CreateTexture(nil, "BACKGROUND")
		row.selected:SetAllPoints()
		row.selected:SetColorTexture(1, 0.82, 0, 0.15)

		row.star = CreateFrame("Button", nil, row)
		row.star:SetSize(16, 16)
		row.star:SetPoint("LEFT", 2, 0)
		row.star.icon = row.star:CreateTexture(nil, "ARTWORK")
		row.star.icon:SetAllPoints()
		row.star:SetScript("OnClick", function()
			ns.ToggleBookmark(row.entry.name)
			ns.Refresh()
		end)

		row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.value:SetPoint("RIGHT", -4, 0)
		row.value:SetWidth(110)
		row.value:SetJustifyH("RIGHT")
		row.value:SetWordWrap(false)
		row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.name:SetPoint("LEFT", row.star, "RIGHT", 4, 0)
		row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)

		row:SetScript("OnClick", function()
			selected = row.entry
			ns.Refresh()
		end)
	end
	row.entry = entry
	local info = ns.Info(entry.name) or { value = "" }
	row.name:SetText(entry.name)
	-- Changed values in white, defaults in gray.
	row.value:SetText((info.changed and WHITE or GRAY) .. info.value .. "|r")
	SetStar(row.star.icon, ns.IsBookmarked(entry.name))
	row.selected:SetShown(selected ~= nil and selected.name == entry.name)
end

-- Redraws the list (keeping its scroll position) and the selected CVar.
function ns.Refresh()
	if not window or not window:IsShown() then
		return
	end
	local found = ns.Find(window.search:GetText(), filter)
	window.list:SetDataProvider(CreateDataProvider(found), ScrollBoxConstants.RetainScrollPosition)
	window.count:SetText(#found == 1 and "1 CVar" or #found .. " CVars")
	window.minimap:SetChecked(not CVarBrowserDB.minimap.hide)
	for _, button in ipairs(window.filters) do
		if button.key == filter then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
	end
	ShowDetail()
end

local function Button(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	return button
end

local function Apply()
	local d = window.detail
	d.edit:ClearFocus()
	ns.Set(selected.name, d.edit:GetText())
	ns.Refresh()
end

local function CreateDetail(parent)
	local d = CreateFrame("Frame", nil, parent)

	d.star = CreateFrame("Button", nil, d)
	d.star:SetSize(20, 20)
	d.star:SetPoint("TOPRIGHT")
	d.star.icon = d.star:CreateTexture(nil, "ARTWORK")
	d.star.icon:SetAllPoints()
	d.star:SetScript("OnClick", function()
		ns.ToggleBookmark(selected.name)
		ns.Refresh()
	end)

	d.name = d:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	d.name:SetPoint("TOPLEFT")
	d.name:SetPoint("RIGHT", d.star, "LEFT", -6, 0)
	d.name:SetJustifyH("LEFT")
	d.meta = d:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	d.meta:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
	d.meta:SetPoint("RIGHT")
	d.meta:SetJustifyH("LEFT")

	local label = d:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", d.meta, "BOTTOMLEFT", 0, -16)
	label:SetText("Value")
	d.edit = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
	d.edit:SetSize(150, 20)
	d.edit:SetPoint("LEFT", label, "RIGHT", 12, 0)
	d.edit:SetAutoFocus(false)
	d.edit:SetScript("OnEnterPressed", Apply)
	d.edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		ShowDetail()
	end)
	d.set = Button(d, "Set", 50)
	d.set:SetPoint("LEFT", d.edit, "RIGHT", 6, 0)
	d.set:SetScript("OnClick", Apply)
	d.reset = Button(d, "Default", 70)
	d.reset:SetPoint("LEFT", d.set, "RIGHT", 2, 0)
	d.reset:SetScript("OnClick", function()
		ns.Reset(selected.name)
		ns.Refresh()
	end)
	d.toggle = Button(d, "Toggle", 60)
	d.toggle:SetPoint("LEFT", d.reset, "RIGHT", 2, 0)
	d.toggle:SetScript("OnClick", function()
		local info = ns.Info(selected.name)
		ns.Set(selected.name, info.value == "1" and "0" or "1")
		ns.Refresh()
	end)

	d.defaultText = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	d.defaultText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -12)
	d.note = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	d.note:SetPoint("LEFT", d.defaultText, "RIGHT", 12, 0)

	local box = CreateFrame("Frame", nil, d)
	box:SetPoint("TOPLEFT", d.defaultText, "BOTTOMLEFT", 0, -12)
	box:SetPoint("BOTTOMRIGHT")
	local bg = box:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.35)
	d.info = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	d.info:SetPoint("TOPLEFT", 10, -10)
	d.info:SetPoint("BOTTOMRIGHT", -10, 10)
	d.info:SetJustifyH("LEFT")
	d.info:SetJustifyV("TOP")
	return d
end

local function CreateWindow()
	local f = CreateFrame("Frame", "CVarBrowserFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(760, 500)
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
		CVarBrowserDB.point = { point, relativePoint, x, y }
	end)
	local point = CVarBrowserDB.point
	if point then
		f:SetPoint(point[1], UIParent, point[2], point[3], point[4])
	else
		f:SetPoint("CENTER")
	end
	f.TitleText:SetText("CVar Browser")
	f:HookScript("OnShow", ns.Refresh)
	-- Escape closes it.
	table.insert(UISpecialFrames, f:GetName())

	f.search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
	f.search:SetSize(200, 20)
	f.search:SetPoint("TOPLEFT", 18, -32)
	f.search:HookScript("OnTextChanged", ns.Refresh)

	f.filters = {}
	local previous = f.search
	for _, def in ipairs(FILTERS) do
		local button = Button(f, def[2], 80)
		button.key = def[1]
		button:SetPoint("LEFT", previous, "RIGHT", previous == f.search and 10 or 2, 0)
		button:SetScript("OnClick", function()
			filter = def[1]
			ns.Refresh()
		end)
		f.filters[#f.filters + 1] = button
		previous = button
	end
	f.count = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.count:SetPoint("TOPRIGHT", -18, -36)

	f.list = CreateFrame("Frame", nil, f, "WowScrollBoxList")
	f.list:SetPoint("TOPLEFT", 12, -62)
	f.list:SetPoint("BOTTOMLEFT", 12, 10)
	f.list:SetWidth(330)
	local bar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", f.list, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(f.list, bar, view)

	f.detail = CreateDetail(f)
	f.detail:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 28, 0)
	f.detail:SetPoint("BOTTOMRIGHT", -16, 40)
	f.minimap = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.minimap:SetSize(24, 24)
	f.minimap:SetPoint("TOPLEFT", f.detail, "BOTTOMLEFT", -4, -4)
	f.minimap.Text:SetText("Minimap button")
	f.minimap:SetScript("OnClick", function(self)
		ns.ShowMinimapButton(self:GetChecked())
	end)
	f.empty = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	f.empty:SetPoint("CENTER", f.detail, "CENTER")
	f.empty:SetText("Pick a CVar from the list.")
	return f
end

-- /cvars: toggles the window, or opens it on a search.
function ns.Toggle(text)
	if not window then
		window = CreateWindow()
		window:Hide()
	end
	if text and text ~= "" then
		window.search:SetText(text)
		window:Show()
	else
		window:SetShown(not window:IsShown())
	end
	ns.window = window
end
