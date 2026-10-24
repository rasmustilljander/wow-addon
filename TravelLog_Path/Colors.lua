-- The Colors tab of the TravelLog window: a swatch for each trail line and
-- map marker opens the color picker, opacity included. The world map shows
-- a change right away; Default goes back to the color in Map.lua.
local _, ns = ...
local tl = TravelLog

local HEIGHT = 254
local ROW_HEIGHT = 24
local LABEL_WIDTH = 112
local COLUMN_WIDTH = 210

local COLUMNS = {
	{ title = "Trail", saved = "trailColors", defaults = ns.TRAIL_COLORS, x = 18, rows = {
		{ "foot", "On foot" }, { "mount", "Mounted" }, { "flight", "Flight path" }, { "swim", "Swimming" },
		{ "ghost", "Ghost" },
	} },
	{ title = "Markers", saved = "markerColors", defaults = ns.MARKER_COLORS, x = 240, rows = {
		{ "jump", "Jump" }, { "loot", "Loot" }, { "death", "Death" }, { "level", "Level-up" },
		{ "learned", "Learned" }, { "taxipath", "New flight path" }, { "standing", "Reputation" },
		{ "mount", "First ride" }, { "note", "Note" },
	} },
}

local swatches = {} -- one per row: { saved, key, default, color, reset }

local function Current(s)
	return tl.settings[s.saved][s.key] or s.default
end

local function Refresh()
	for _, s in ipairs(swatches) do
		local c = Current(s)
		s.color:SetColorTexture(c[1], c[2], c[3], c[4])
		s.reset:SetEnabled(tl.settings[s.saved][s.key] ~= nil)
	end
end

-- Saves a color, or nil for the default, and redraws.
local function Set(s, color)
	tl.settings[s.saved][s.key] = color
	ns.RefreshTrail()
	Refresh()
end

local function Pick(s)
	local before = tl.settings[s.saved][s.key]
	local c = Current(s)
	local function Picked()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		local color = { tl.Round(r, 3), tl.Round(g, 3), tl.Round(b, 3), tl.Round(ColorPickerFrame:GetColorAlpha(), 3) }
		local d = s.default
		local same = color[1] == d[1] and color[2] == d[2] and color[3] == d[3] and color[4] == d[4]
		Set(s, not same and color or nil)
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = c[1], g = c[2], b = c[3], opacity = c[4], hasOpacity = true,
		swatchFunc = Picked, opacityFunc = Picked,
		cancelFunc = function() Set(s, before) end,
	})
end

local function Button(page, text, width, x, y, onClick)
	local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	button:SetSize(width, 20)
	button:SetPoint("TOPLEFT", x, y + 3)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

-- A label, a color swatch with a grey border over black (so opacity shows),
-- and a Default button.
local function AddRow(page, s, x, y, label)
	local text = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("TOPLEFT", x, y)
	text:SetWidth(LABEL_WIDTH)
	text:SetJustifyH("LEFT")
	text:SetText(label)

	local swatch = CreateFrame("Button", nil, page)
	swatch:SetSize(36, 18)
	swatch:SetPoint("TOPLEFT", x + LABEL_WIDTH, y + 2)
	local border = swatch:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	border:SetColorTexture(0.6, 0.6, 0.6, 1)
	local back = swatch:CreateTexture(nil, "BORDER")
	back:SetPoint("TOPLEFT", 1, -1)
	back:SetPoint("BOTTOMRIGHT", -1, 1)
	back:SetColorTexture(0, 0, 0, 1)
	s.color = swatch:CreateTexture(nil, "ARTWORK")
	s.color:SetPoint("TOPLEFT", 2, -2)
	s.color:SetPoint("BOTTOMRIGHT", -2, 2)
	swatch:SetScript("OnClick", function() Pick(s) end)
	s.swatch = swatch

	s.reset = Button(page, "Default", 56, x + LABEL_WIDTH + 42, y, function() Set(s, nil) end)
end

local function Build(page)
	for _, column in ipairs(COLUMNS) do
		local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		heading:SetPoint("TOPLEFT", column.x - 4, 0)
		heading:SetText(column.title)
		local rule = page:CreateTexture(nil, "ARTWORK")
		rule:SetColorTexture(1, 0.82, 0, 0.25)
		rule:SetSize(COLUMN_WIDTH, 1)
		rule:SetPoint("TOPLEFT", column.x - 4, -18)
		for i, row in ipairs(column.rows) do
			local s = { saved = column.saved, key = row[1], default = column.defaults[row[1]] }
			swatches[#swatches + 1] = s
			AddRow(page, s, column.x, -24 - (i - 1) * ROW_HEIGHT, row[2])
		end
	end

	local hint = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", COLUMNS[1].x, -24 - 5.5 * ROW_HEIGHT)
	hint:SetWidth(COLUMN_WIDTH - 4)
	hint:SetJustifyH("LEFT")
	hint:SetText("Click a color to change it. Alts' trails use their class color.")
	Button(page, "All defaults", 100, COLUMNS[1].x, -24 - 7 * ROW_HEIGHT, function()
		wipe(tl.settings.trailColors)
		wipe(tl.settings.markerColors)
		ns.RefreshTrail()
		Refresh()
	end)
end

tl.AddTab("Colors", HEIGHT, Build, Refresh)
