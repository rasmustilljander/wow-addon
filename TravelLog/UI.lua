-- The TravelLog window: this character's totals and the settings, opened
-- from the minimap button or /tl window. Companion addons add their own
-- rows with ns.AddStat, ns.AddSetting and ns.AddStepper while loading, or
-- at login.
local _, ns = ...

local WIDTH = 460
local LABEL_WIDTH = 110
local ROW_HEIGHT = 18
local REFRESH = 1 -- seconds between redraws while the window is open

local stats, settings = {}, {}
local window

-- Adds a line to the totals. value() returns its text.
function ns.AddStat(label, value)
	stats[#stats + 1] = { label = label, value = value }
end

-- Adds a setting: a checkbox, or a button per choice when choices is given.
-- get() returns the current value and set(value) changes it. label is a
-- string, or a function returning one.
function ns.AddSetting(label, get, set, choices)
	settings[#settings + 1] = { label = label, get = get, set = set, choices = choices }
end

-- Adds a row with < and > buttons around a value. get() returns the text
-- shown; the buttons call step(-1) and step(1).
function ns.AddStepper(label, get, step)
	settings[#settings + 1] = { label = label, get = get, step = step }
end

local function Text(label)
	return type(label) == "function" and label() or label
end

--------------------------------------------------------------------------------
-- TravelLog's own totals
--------------------------------------------------------------------------------

local Count = ns.Count

ns.AddStat("Loot", function()
	local loot = ns.stats.loot or {}
	return ("%s items from %s sources, %s in coins"):format(Count(loot.items), Count(loot.opened), ns.MoneyText(loot.money))
end)
ns.AddStat("Vendors", function()
	local v = ns.stats.vendor or {}
	return ("spent %s, earned %s"):format(ns.MoneyText((v.spent or 0) + (v.repairCost or 0)), ns.MoneyText(v.earned))
end)
ns.AddStat("Quests done", function() return Count((ns.stats.quests or {}).completed) end)
ns.AddStat("Flights", function() return Count(ns.stats.flights) end)
ns.AddStat("Deaths", function() return Count(ns.stats.deaths) end)
ns.AddStat("XP kills", function() return Count(ns.stats.kills) end)
ns.AddStat("Places visited", function() return Count(ns.PlacesVisited()) end)
ns.AddStat("Log", function()
	return ("%s entries in %s sessions"):format(Count(#ns.char.log), Count(#ns.char.sessions))
end)

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local function Refresh()
	if not window or not window:IsShown() then
		return
	end
	window.who:SetText(("%s, level %d %s %s"):format(ns.charKey, UnitLevel("player"), UnitRace("player"), UnitClass("player")))
	for _, stat in ipairs(stats) do
		stat.text:SetText(stat.value())
	end
	for _, setting in ipairs(settings) do
		local value = setting.get()
		if setting.step then
			setting.text:SetText(value)
		elseif setting.choices then
			for _, button in ipairs(setting.buttons) do
				if button.value == value then
					button:LockHighlight()
				else
					button:UnlockHighlight()
				end
			end
		else
			setting.check:SetChecked(value)
			setting.check.Text:SetText(Text(setting.label))
		end
	end
	window.minimap:SetChecked(ns.settings.minimap)
end
ns.RefreshWindow = Refresh

local function Label(f, text, y)
	local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("TOPLEFT", 18, y)
	label:SetWidth(LABEL_WIDTH)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

local function Heading(f, text, y)
	local heading = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 14, y)
	heading:SetText(text)
	return y - 24
end

local function Check(f, y)
	local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", 14, y + 4)
	return check
end

local function AddChoices(f, setting, y)
	Label(f, Text(setting.label), y)
	setting.buttons = {}
	local x = 18 + LABEL_WIDTH
	local width = math.floor((WIDTH - x - 16) / #setting.choices)
	for _, value in ipairs(setting.choices) do
		local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		button:SetSize(width, 20)
		button:SetPoint("TOPLEFT", x, y + 3)
		button:SetText(tostring(value))
		button.value = value
		button:SetScript("OnClick", function()
			setting.set(value)
			Refresh()
		end)
		setting.buttons[#setting.buttons + 1] = button
		x = x + width
	end
end

local function AddStepper(f, setting, y)
	Label(f, Text(setting.label), y)
	local x = 18 + LABEL_WIDTH
	local function Arrow(text, step, left)
		local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		button:SetSize(24, 20)
		button:SetPoint("TOPLEFT", left, y + 3)
		button:SetText(text)
		button:SetScript("OnClick", function()
			setting.step(step)
			Refresh()
		end)
	end
	Arrow("<", -1, x)
	setting.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	setting.text:SetPoint("TOPLEFT", x + 24, y)
	setting.text:SetWidth(120)
	setting.text:SetJustifyH("CENTER")
	Arrow(">", 1, x + 144)
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

	local y = Heading(f, "Totals", -60)
	for _, stat in ipairs(stats) do
		Label(f, stat.label, y)
		stat.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		stat.text:SetPoint("TOPLEFT", 18 + LABEL_WIDTH, y)
		stat.text:SetWidth(WIDTH - LABEL_WIDTH - 36)
		stat.text:SetJustifyH("LEFT")
		stat.text:SetWordWrap(false)
		y = y - ROW_HEIGHT
	end

	y = Heading(f, "Settings", y - 10)
	for _, setting in ipairs(settings) do
		if setting.step then
			AddStepper(f, setting, y)
		elseif setting.choices then
			AddChoices(f, setting, y)
		else
			setting.check = Check(f, y)
			setting.check:SetScript("OnClick", function(self)
				setting.set(self:GetChecked())
				Refresh()
			end)
		end
		y = y - 24
	end
	f.minimap = Check(f, y)
	f.minimap.Text:SetText("Minimap button")
	f.minimap:SetScript("OnClick", function(self)
		ns.ShowMinimapButton(self:GetChecked())
	end)

	f:SetSize(WIDTH, -y + 34)
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
