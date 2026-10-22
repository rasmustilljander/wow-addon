-- The TravelLog window: any character's totals, or all of them added up, on
-- one tab and the settings on another, each under section headings. Opened
-- from the addon compartment (the minimap's addons dropdown) or /tl.
-- Companion addons add their own rows with ns.AddStat, ns.AddSetting and
-- ns.AddStepper, and whole tabs with ns.AddTab, while loading or at login.
local _, ns = ...

local WIDTH = 600
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
local extraTabs = {} -- companions' tabs, after Totals and Settings
local window

-- Whose totals show: an index into ns.Characters(), one past its end for all
-- of them added up. 1 is the character you're on.
local showing = 1
local ONLY_YOU = "|cff999999only for the character you're on|r"

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

-- Adds a line to the totals under section. value(st, key) returns its text
-- for the totals shown: st is that character's stats (every character's
-- added up when key is nil) and key its "Name-Realm". A row whose data only
-- the character you're on has passes mine, and says so for the others.
function ns.AddStat(section, label, value, mine)
	Add(stats, section, { label = label, value = value, mine = mine })
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

-- Adds a tab after Settings. build(page) fills its page when the window is
-- first opened; the page is the window's width and at least height tall.
-- refresh(), if given, runs whenever the tab is shown and every second while
-- it is.
function ns.AddTab(name, height, build, refresh)
	extraTabs[#extraTabs + 1] = { name = name, height = height, build = build, refresh = refresh }
end

local function Text(label)
	return type(label) == "function" and label() or label
end

--------------------------------------------------------------------------------
-- TravelLog's own rows
--------------------------------------------------------------------------------

local Count = ns.Count

ns.AddStat("Travel", "Places visited", function(st) return Count(ns.PlacesVisited(st)) end)
ns.AddStat("Travel", "Flights", function(st) return Count(st.flights) end)
ns.AddStat("Travel", "Flight paths", function(st) return Count(st.flightPaths) end)
ns.AddStat("Travel", "Teleports", function(st)
	return ("%s hearths, %s teleports, %s summons"):format(Count(st.hearths), Count(st.teleports), Count(st.summons))
end)
ns.AddStat("Travel", "Boat rides", function(st) return Count(st.boats) end)
ns.AddStat("Travel", "Instances", function(st)
	local i = st.instances or {}
	return ("%s dungeons, %s raids, %s inside"):format(Count(i.dungeon), Count(i.raid), ns.Duration(st.instanceTime or 0))
end)
ns.AddStat("Travel", "Screenshots", function(st) return Count(st.screenshots) end)
ns.AddStat("Loot", "Looted", function(st)
	local loot = st.loot or {}
	return ("%s items from %s sources, %s in coins"):format(Count(loot.items), Count(loot.opened), ns.MoneyText(loot.money))
end)
ns.AddStat("Loot", "Vendors", function(st)
	local v = st.vendor or {}
	return ("spent %s, earned %s"):format(ns.MoneyText((v.spent or 0) + (v.repairCost or 0)), ns.MoneyText(v.earned))
end)
ns.AddStat("Loot", "Rolls", ns.RollsText)
ns.AddStat("Loot", "Items out", ns.GivenText)
ns.AddStat("Loot", "Money in", function(st) return ns.MoneyByReason(st, "gained") end)
ns.AddStat("Loot", "Money out", function(st) return ns.MoneyByReason(st, "spent") end)
ns.AddStat("Life", "Played", function()
	local total, level = ns.Played()
	return total and ("%s, %s at this level"):format(ns.Duration(total), ns.Duration(level)) or "not known yet"
end, true)
ns.AddStat("Life", "Quests", function(st)
	local quests = st.quests or {}
	return ("%s done, %s failed"):format(Count(quests.completed), Count(quests.failed))
end)
ns.AddStat("Life", "Learned", function(st)
	return ("%s spells, %s skills, %s skill points, %s talent points"):format(
		Count(st.spells), Count(st.skills), Count(st.skillups), Count(st.talents))
end)
ns.AddStat("Life", "New gear", function(st) return Count(st.gear) end)
ns.AddStat("Life", "XP kills", function(st) return Count(st.kills) end)
ns.AddStat("Life", "Deaths", ns.DeathsText)
ns.AddStat("Life", "Came back", ns.RevivalsText)
ns.AddStat("Life", "PvP", function(st)
	local d = st.duels or {}
	return ("%s duels won, %s lost, %s honorable kills, %s honor"):format(
		Count(d.won), Count(d.lost), Count(st.honorKills), Count(st.honor))
end)
ns.AddStat("Life", "Battlegrounds", function(st)
	local b = st.battlegrounds or {}
	return ("%s won, %s lost, %s left"):format(Count(b.won), Count(b.lost), Count(b.left))
end)
ns.AddStat("Life", "Guild", ns.GuildText)
ns.AddStat("Log", "Entries", function()
	return ("%s in %s sessions"):format(Count(#ns.char.log), Count(#ns.char.sessions))
end, true)

-- The Totals tab's < and > buttons, stepping through the characters and all
-- of them together.
local picker = {
	label = "Character",
	get = function()
		local list = ns.Characters()
		local key = list[showing]
		if not key then
			return ("All %d characters"):format(#list)
		end
		return ("%s, level %d"):format(key, ns.db.chars[key].level or 0)
	end,
	step = function(step)
		local n = #ns.Characters() + 1
		showing = (showing - 1 + step) % n + 1
	end,
}

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Refresh()
	if not window or not window:IsShown() then
		return
	end
	window.who:SetText(("%s, level %d %s %s"):format(ns.charKey, UnitLevel("player"), UnitRace("player"), UnitClass("player")))
	local list = ns.Characters()
	showing = math.min(showing, #list + 1)
	local key = list[showing]
	local st = ns.StatsFor(key)
	picker.text:SetText(picker.get())
	EachRow(stats, function(stat)
		stat.text:SetText(stat.mine and key ~= ns.charKey and ONLY_YOU or stat.value(st, key))
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
	for _, tab in ipairs(extraTabs) do
		if tab.refresh and tab.page:IsShown() then
			tab.refresh()
		end
	end
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

-- Fills a tab's page with its sections, from y (default 0) down, and returns
-- how tall it is.
local function Fill(page, tab, AddRow, y)
	y = y or 0
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

	-- A page per tab, the window as tall as the tallest one.
	f.pages = {}
	local all = {
		{ name = "Totals", build = function(page)
			AddStepper(page, picker, 0)
			return Fill(page, stats, AddStatRow, -SETTING_HEIGHT - 4)
		end },
		{ name = "Settings", build = function(page) return Fill(page, settings, AddSettingRow) end },
	}
	for _, tab in ipairs(extraTabs) do
		all[#all + 1] = tab
	end
	local tabs, height = {}, 0
	for i, tab in ipairs(all) do
		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", 0, TOP)
		height = math.max(height, tab.height or 0, tab.build(page) or 0)
		tab.page = page
		f.pages[i] = page

		-- Named so PanelTemplates finds it as TravelLogFrameTab<i>.
		tabs[i] = CreateFrame("Button", "TravelLogFrameTab" .. i, f, "PanelTabButtonTemplate")
		tabs[i]:SetID(i)
		tabs[i]:SetText(tab.name)
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

local function Window()
	if not window then
		window = CreateWindow()
		window:Hide()
		ns.window = window
	end
	return window
end

-- Opens or closes the window.
function ns.Toggle()
	Window():SetShown(not window:IsShown())
end

-- The addon compartment's entry, named in the .toc.
function TravelLog_OnAddonCompartmentClick()
	ns.Toggle()
end

-- Opens the window on the tab with this name.
function ns.ShowTab(name)
	local f = Window()
	f:Show()
	for i, tab in ipairs(f.Tabs) do
		if tab:GetText() == name then
			SelectTab(f, i)
		end
	end
end

