-- JunkToss minimap button: right-click throws away the cheapest item,
-- left-click opens the window, drag moves it around the minimap.
local _, ns = ...

local button
local hovering

-- Puts the button on the minimap's edge at its saved angle.
local function Place()
	local angle = math.rad(JunkTossDB.minimap.angle)
	local radius = Minimap:GetWidth() / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging: the angle from the minimap's center to the cursor.
local function Follow()
	local mx, my = Minimap:GetCenter()
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	JunkTossDB.minimap.angle = math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
	Place()
end

-- The tooltip names what a right-click throws away next.
function ns.UpdateTooltip()
	if not hovering then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText("JunkToss")
	local item = ns.Candidates()[1]
	GameTooltip:AddLine(item and "Next: " .. ns.Describe(item) or "Nothing to throw away.", 1, 1, 1)
	GameTooltip:AddLine("Right-click to throw it away, left-click for the allowlist, drag to move.", nil, nil, nil, true)
	GameTooltip:Show()
end

local function Create()
	button = CreateFrame("Button", "JunkTossMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetSize(17, 17)
	icon:SetPoint("TOPLEFT", 7, -6)
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			ns.Throw()
		else
			ns.Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", Follow)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnEnter", function()
		hovering = true
		ns.UpdateTooltip()
	end)
	button:SetScript("OnLeave", function()
		hovering = false
		GameTooltip:Hide()
	end)
	Place()
end

-- Shows or hides the button; called on load with the saved setting.
function ns.ShowMinimapButton(show)
	JunkTossDB.minimap.hide = not show or nil
	if show and not button then
		Create()
	end
	if button then
		button:SetShown(show)
	end
	ns.minimapButton = button
end
