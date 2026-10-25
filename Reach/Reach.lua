-- Reach: while you auto-attack or shoot, warns on screen when none of your
-- weapons can hit the target but it's close: out of melee range, or a
-- hunter's dead zone between melee and shooting range. Targets further away
-- get no warning, so chasing or pulling from afar stays quiet.
local _, ns = ...

-- Forever runs on the Midnight-era client, which hands addons unreadable
-- "secret" values in some situations. We can't use those, so treat them as
-- missing.
local issecretvalue = issecretvalue
function ns.Clean(value)
	if value ~= nil and issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

function ns.Print(text, ...)
	if select("#", ...) > 0 then
		text = text:format(...)
	end
	print("|cffffd200Reach|r " .. text)
end

local AUTO_ATTACK = 6603
local TRADE_DISTANCE = 2   -- CheckInteractDistance index: about 8 yards
local INTERVAL = 0.2       -- seconds between checks while attacking

ns.melee, ns.shooting = false, false

-- Whether the target is in range for one swing type: true, false, or nil
-- when the client can't tell (no weapon for it, no attackable target).
local function InRange(swingType)
	return ns.Clean(C_SwingTimer.IsTargetWithinSwingRange(swingType))
end

-- The warning to show now, or nil.
function ns.Warning()
	if not (ns.melee or ns.shooting) or not C_SwingTimer then
		return nil
	end
	local types = Enum.PlayerSwingType
	local main, off, ranged = InRange(types.MainHand), InRange(types.OffHand), InRange(types.Ranged)
	-- Nil isn't out of range: warn only when something checked and nothing hits.
	if main or off or ranged or (main == nil and off == nil and ranged == nil) then
		return nil
	end
	if not ns.Clean(CheckInteractDistance("target", TRADE_DISTANCE)) then
		return nil
	end
	if ranged == false then
		return "Dead zone: too close to shoot"
	end
	return "Out of melee range"
end

local warning = CreateFrame("Frame", "ReachWarning", UIParent)
warning:SetSize(400, 40)
warning:SetFrameStrata("HIGH")
warning:SetClampedToScreen(true)
warning:EnableMouse(false)   -- click-through until /reach move
warning:SetMovable(true)
warning:RegisterForDrag("LeftButton")
warning:SetScript("OnDragStart", function(self)
	self:StartMoving()
end)
warning:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	self:SetUserPlaced(false)   -- we keep the position ourselves
	local point, _, relativePoint, x, y = self:GetPoint()
	ReachDB.point = { point, relativePoint, x, y }
end)
warning.text = warning:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warning.text:SetAllPoints()
warning.text:SetTextColor(1, 0.2, 0.2)
warning:Hide()
ns.warning = warning

function ns.Update()
	if ns.moving then
		return
	end
	local text = ReachDB.enabled and ns.Warning()
	if text then
		warning.text:SetText(text)
	end
	warning:SetShown(text and true or false)
end

local function Place()
	local point = ReachDB.point
	warning:ClearAllPoints()
	if point then
		warning:SetPoint(point[1], UIParent, point[2], point[3], point[4])
	else
		warning:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" then
		if arg == "Reach" then
			ReachDB = ReachDB or {}
			if ReachDB.enabled == nil then
				ReachDB.enabled = true
			end
			Place()
		end
		return
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- A reload doesn't stop auto-attack.
		ns.melee = ns.Clean(C_Spell.IsCurrentSpell(AUTO_ATTACK)) or false
	elseif event == "PLAYER_ENTER_COMBAT" then
		ns.melee = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		ns.melee = false
	elseif event == "START_AUTOREPEAT_SPELL" then
		ns.shooting = true
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		ns.shooting = false
	end
	ns.Update()
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
	"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_TARGET_CHANGED" }) do
	frame:RegisterEvent(event)
end

-- Distance has no event, so check a few times a second while attacking.
C_Timer.NewTicker(INTERVAL, function()
	if ns.melee or ns.shooting or warning:IsShown() then
		ns.Update()
	end
end)

SLASH_REACH1 = "/reach"
SlashCmdList.REACH = function(msg)
	local cmd = msg:match("^%s*(%S*)"):lower()
	if cmd == "" then
		ReachDB.enabled = not ReachDB.enabled
		ns.Print(ReachDB.enabled and "Warnings on." or "Warnings off.")
		ns.Update()
	elseif cmd == "move" then
		ns.moving = not ns.moving
		warning:EnableMouse(ns.moving)
		if ns.moving then
			warning.text:SetText("Reach: drag me, then /reach move")
			warning:Show()
		else
			ns.Update()
		end
	elseif cmd == "reset" then
		ReachDB.point = nil
		Place()
		ns.Print("Warning moved back to the middle.")
	else
		ns.Print("/reach: turn warnings on or off. /reach move: move the warning. /reach reset: put it back.")
	end
end
