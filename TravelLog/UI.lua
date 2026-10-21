-- The TravelLog window: this character's totals on one tab and the settings
-- on another, each under section headings. Opened from the minimap button
-- or /tl window. Companion addons add their own rows with ns.AddStat,
-- ns.AddSetting and ns.AddStepper while loading, or at login.
local _, ns = ...

local WIDTH = 460
local LEFT = 18                        -- labels
local LABEL_WIDTH = 110
local VALUE_X = LEFT + LABEL_WIDTH     -- values, buttons and indented checkboxes
local CHOICE_WIDTH = 52                -- one choice button
local CHOICES_WIDTH = 6 * CHOICE_WIDTH -- the widest row of choices
local STAT_HEIGHT = 18
local SETTING_HEIGHT = 24
local TOP = -52                        -- where the tabs' contents start
local REFRESH = 1 -- seconds between redraws while the window is open

-- Each tab's rows by section. Sections show in this order, then any others
-- in the order they're first used. Empty ones are left out.
local stats = { order = { "Travel", "Loot", "Life", "Log" }, rows = {} }
local settings = { order = { "World map", "General" }, rows = {} }
local window

local function Add(tab, section, row)
	if not tab.rows[section] then
		tab.rows[section] = {}
		local known
		for _, name in ipairs(tab.order) do
			known = known or name == section
		end
		if not known then
			tab.order[#tab.order + 1] = section
		end
	end
	table.insert(tab.rows[section], row)
end

-- Calls fn(row) for every row of a tab, in order.
local function EachRow(tab, fn)
	for _, section in ipairs(tab.order) do
		for _, row in ipairs(tab.rows[section] or {}) do
			fn(row)
		end
	end
end

-- Adds a line to the totals under section. value() returns its text.
function ns.AddStat(section, label, value)
	Add(stats, section, { label = label, value = value })
end

-- Adds a setting under section: a checkbox, or a button per choice when
-- choices is given. get() returns the current value and set(value) changes
-- it. label is a string, or a function returning one. An indented checkbox
-- lines up with the buttons of the row above.
function ns.AddSetting(section, label, get, set, choices, indent)
	Add(settings, section, { label = label, get = get, set = set, choices = choices, indent = indent })
end

-- Adds < and > buttons around a value, as wide as a row of choices. get()
-- returns the text shown; the buttons call step(-1) and step(1). Without a
-- label it reads as part of the row above.
function ns.AddStepper(section, label, get, step)
	Add(settings, section, { label = label, get = get, step = step })
end

local function Text(label)
	return type(label) == "function" and label() or label
end

--------------------------------------------------------------------------------
-- TravelLog's own rows
--------------------------------------------------------------------------------

local Count = ns.Count

ns.AddStat("Travel", "Places visited", function() return Count(ns.PlacesVisited()) end)
ns.AddStat("Travel", "Flights", function() return Count(ns.stats.flights) end)
ns.AddStat("Travel", "Flight paths", function() return Count(ns.stats.flightPaths) end)
ns.AddStat("Loot", "Looted", function()
	local loot = ns.stats.loot or {}
	return ("%s items from %s sources, %s in coins"):format(Count(loot.items), Count(loot.opened), ns.MoneyText(loot.money))
end)
ns.AddStat("Loot", "Vendors", function()
	local v = ns.stats.vendor or {}
	return ("spent %s, earned %s"):format(ns.MoneyText((v.spent or 0) + (v.repairCost or 0)), ns.MoneyText(v.earned))
end)
ns.AddStat("Life", "Quests done", function() return Count((ns.stats.quests or {}).completed) end)
ns.AddStat("Life", "Learned", function()
	local st = ns.stats
	return ("%s spells, %s skills, %s skill points"):format(Count(st.spells), Count(st.skills), Count(st.skillups))
end)
ns.AddStat("Life", "XP kills", function() return Count(ns.stats.kills) end)
ns.AddStat("Life", "Deaths", function() return Count(ns.stats.deaths) end)
ns.AddStat("Log", "Entries", function()
	return ("%s in %s sessions"):format(Count(#ns.char.log), Count(#ns.char.sessions))
end)

ns.AddSetting("General", "Minimap button", function() return ns.settings.minimap end, function(on)
	ns.ShowMinimapButton(on)
end)

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Refresh()
	if not window or not window:IsShown() then
		return
	end
	window.who:SetText(("%s, level %d %s %s"):format(ns.charKey, UnitLevel("player"), UnitRace("player"), UnitClass("player")))
	EachRow(stats, function(stat)
		stat.text:SetText(stat.value())
	end)
	EachRow(settings, function(setting)
		local value = setting.get()
		if setting.step then
			setting.text:SetText(value)
		elseif setting.choices then
			-- The chosen button stays lit, with white text.
			for _, button in ipairs(setting.buttons) do
				if button.value == value then
					button:LockHighlight()
					button:SetNormalFontObject(GameFontHighlight)
				else
					button:UnlockHighlight()
					button:SetNormalFontObject(GameFontNormal)
				end
			end
		else
			setting.check:SetChecked(value)
			setting.check.Text:SetText(Text(setting.label))
		end
	end)
end
ns.RefreshWindow = Refresh

local function Label(f, text, y)
	local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", LEFT, y)
	label:SetWidth(LABEL_WIDTH)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

-- A section heading with a faint rule under it. Returns the y of the first row.
local function Heading(f, text, y)
	local heading = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", LEFT - 4, y)
	heading:SetText(text)
	local rule = f:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(1, 0.82, 0, 0.25)
	rule:SetSize(WIDTH - 2 * LEFT + 4, 1)
	rule:SetPoint("TOPLEFT", LEFT - 4, y - 18)
	return y - 24
end

local function Button(f, text, width, x, y, onClick)
	local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	button:SetSize(width, 20)
	button:SetPoint("TOPLEFT", x, y + 3)
	button:SetText(text)
	button:SetScript("OnClick", function()
		onClick()
		Refresh()
	end)
	return button
end

local function AddCheck(f, setting, y)
	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", (setting.indent and VALUE_X or LEFT) - 4, y + 4)
	check.Text:SetFontObject(GameFontNormal)
	check:SetScript("OnClick", function(self)
		setting.set(self:GetChecked())
		Refresh()
	end)
	setting.check = check
end

local function AddChoices(f, setting, y)
	Label(f, Text(setting.label), y)
	setting.buttons = {}
	for i, value in ipairs(setting.choices) do
		local button = Button(f, tostring(value), CHOICE_WIDTH, VALUE_X + (i - 1) * CHOICE_WIDTH, y, function()
			setting.set(value)
		end)
		button.value = value
		setting.buttons[i] = button
	end
end

local function AddStepper(f, setting, y)
	if setting.label then
		Label(f, Text(setting.label), y)
	end
	Button(f, "<", 24, VALUE_X, y, function() setting.step(-1) end)
	setting.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	setting.text:SetPoint("TOPLEFT", VALUE_X + 24, y)
	setting.text:SetWidth(CHOICES_WIDTH - 48)
	setting.text:SetJustifyH("CENTER")
	Button(f, ">", 24, VALUE_X + CHOICES_WIDTH - 24, y, function() setting.step(1) end)
end

-- Fills a tab's page with its sections and returns how tall it is.
local function Fill(page, tab, AddRow)
	local y = 0
	for _, section in ipairs(tab.order) do
		local rows = tab.rows[section]
		if rows then
			y = Heading(page, section, y)
			for _, row in ipairs(rows) do
				y = AddRow(page, row, y)
			end
			y = y - 8
		end
	end
	return -y
end

local function AddStatRow(page, stat, y)
	Label(page, stat.label, y)
	stat.text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	stat.text:SetPoint("TOPLEFT", VALUE_X, y)
	stat.text:SetWidth(WIDTH - VALUE_X - LEFT)
	stat.text:SetJustifyH("LEFT")
	stat.text:SetWordWrap(false)
	return y - STAT_HEIGHT
end

local function AddSettingRow(page, setting, y)
	if setting.step then
		AddStepper(page, setting, y)
	elseif setting.choices then
		AddChoices(page, setting, y)
	else
		AddCheck(page, setting, y)
	end
	return y - SETTING_HEIGHT
end

-- Shows tab i's page and hides the other.
local function SelectTab(f, i)
	PanelTemplates_SetTab(f, i)
	for j, page in ipairs(f.pages) do
		page:SetShown(i == j)
	end
	Refresh()
end

local function CreateWindow()
	local f = CreateFrame("Frame", "TravelLogFrame", UIParent, "BasicFrameTemplateWithInset")
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
		self:SetUserPlaced(false) -- we keep the position ourselves
		local point, _, relativePoint, x, y = self:GetPoint()
		ns.settings.point = { point, relativePoint, x, y }
	end)
	local point = ns.settings.point
	if point then
		f:SetPoint(point[1], UIParent, point[2], point[3], point[4])
	else
		f:SetPoint("CENTER")
	end
	f.TitleText:SetText("TravelLog")
	f:HookScript("OnShow", Refresh)
	-- Totals change as you play, so redraw now and then while open.
	local wait = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - elapsed
		if wait <= 0 then
			wait = REFRESH
			Refresh()
		end
	end)
	-- Escape closes it.
	table.insert(UISpecialFrames, f:GetName())

	f.who = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.who:SetPoint("TOPLEFT", 14, -34)

	-- A page per tab, the window as tall as the taller one.
	f.pages = {}
	local tabs, height = {}, 0
	for i, tab in ipairs({ { "Totals", stats, AddStatRow }, { "Settings", settings, AddSettingRow } }) do
		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", 0, TOP)
		height = math.max(height, Fill(page, tab[2], tab[3]))
		f.pages[i] = page

		-- Named so PanelTemplates finds it as TravelLogFrameTab<i>.
		tabs[i] = CreateFrame("Button", "TravelLogFrameTab" .. i, f, "PanelTabButtonTemplate")
		tabs[i]:SetID(i)
		tabs[i]:SetText(tab[1])
		tabs[i]:SetScript("OnClick", function(self)
			SelectTab(f, self:GetID())
		end)
	end
	tabs[1]:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 8, 2)
	PanelTemplates_SetNumTabs(f, #tabs)
	for _, page in ipairs(f.pages) do
		page:SetSize(WIDTH, height)
	end
	f:SetSize(WIDTH, height - TOP + 8)
	SelectTab(f, 1)
	return f
end

-- Opens or closes the window.
function ns.Toggle()
	if not window then
		window = CreateWindow()
		window:Hide()
		ns.window = window
	end
	window:SetShown(not window:IsShown())
end

ns.Command("window", "window - open or close the TravelLog window", function()
	ns.Toggle()
end)
