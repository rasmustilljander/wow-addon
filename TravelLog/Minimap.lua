-- TravelLog minimap button: click to open the window, drag to move it
-- around the minimap.
local _, ns = ...

ns.Defaults({
	minimap = true,      -- show the minimap button
	minimapAngle = 195,  -- its place on the minimap's edge, in degrees
})

local button

-- Puts the button on the minimap's edge at its saved angle.
local function Place()
	local angle = math.rad(ns.settings.minimapAngle)
	local radius = Minimap:GetWidth() / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging: the angle from the minimap's center to the cursor.
local function Follow()
	local mx, my = Minimap:GetCenter()
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.settings.minimapAngle = math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
	Place()
end

local function Create()
	button = CreateFrame("Button", "TravelLogMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function()
		ns.Toggle()
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", Follow)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("TravelLog")
		GameTooltip:AddLine("Click to open or close, drag to move.", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	Place()
end

-- Shows or hides the button; called at login with the saved setting.
function ns.ShowMinimapButton(show)
	ns.settings.minimap = show and true or false
	if show and not button then
		Create()
	end
	if button then
		button:SetShown(show)
	end
	ns.minimapButton = button
end

ns.On("PLAYER_LOGIN", function()
	ns.ShowMinimapButton(ns.settings.minimap)
end)
