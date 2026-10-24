-- Reach: the warning while auto-attacking or shooting, out of melee range and
-- a hunter's dead zone, quiet far away, toggling, moving, a reload.
M.installed = { "Reach" }
local ns = M.Login()
local w = ns.warning
check(ReachDB.enabled == true and not w:IsShown(), "on by default, hidden")
check(w.point[1] == "CENTER" and w.point[5] == 150 and w.mouse == false, "above the middle, click-through")

local function Shown()
	M.tick(1)
	return w:IsShown() and w.text:GetText() or nil
end

-- A warrior: melee only.
M.units.target = { name = "Kobold Vermin", guid = "Creature-0-1-2-3-6-1", hostile = true, level = 8, distance = 3 }
M.fire("PLAYER_TARGET_CHANGED")
check(Shown() == nil, "not attacking: nothing")
M.fire("PLAYER_ENTER_COMBAT")
check(Shown() == nil, "in melee range: nothing")
M.units.target.distance = 7
check(Shown() == "Out of melee range", "stepped back: warned")
M.units.target.distance = 30
check(Shown() == nil, "far away: nothing")
M.units.target.distance = 6
check(Shown() == "Out of melee range", "close again: warned")
M.units.target.dead = true
check(Shown() == nil, "dead target: nothing")
M.units.target.dead = nil
M.units.target = nil
M.fire("PLAYER_TARGET_CHANGED")
check(not w:IsShown(), "no target: hidden at once")
M.units.target = { name = "Kobold Vermin", hostile = true, distance = 7 }
M.fire("PLAYER_TARGET_CHANGED")
check(w:IsShown(), "new target: shown at once")
M.fire("PLAYER_LEAVE_COMBAT")
check(not w:IsShown(), "stopped attacking: hidden at once")

-- A hunter: melee up to 5 yards, shooting from 8.
M.swingReach[Enum.PlayerSwingType.Ranged] = { 8, 35 }
M.fire("START_AUTOREPEAT_SPELL")
check(Shown() == "Dead zone: too close to shoot", "dead zone while shooting")
M.units.target.distance = 4
check(Shown() == nil, "meleeing range: the melee weapon can hit")
M.units.target.distance = 20
check(Shown() == nil, "shooting range")
M.units.target.distance = 40
check(Shown() == nil, "too far to shoot: nothing")
M.fire("STOP_AUTOREPEAT_SPELL")
M.fire("PLAYER_ENTER_COMBAT")
M.units.target.distance = 7
check(Shown() == "Dead zone: too close to shoot", "dead zone while meleeing")
M.units.target.distance = 10
check(Shown() == nil, "meleeing but the gun reaches: nothing")
M.fire("PLAYER_LEAVE_COMBAT")

-- No weapon checks (nothing equipped, or the client can't tell): nil isn't
-- out of range.
M.swingReach = {}
M.fire("PLAYER_ENTER_COMBAT")
M.units.target.distance = 7
check(Shown() == nil, "no range check: nothing")
M.swingReach = { [0] = { 0, 5 } }

-- Unreadable range checks count as unknown.
local isRange = C_SwingTimer.IsTargetWithinSwingRange
C_SwingTimer.IsTargetWithinSwingRange = function(...)
	local v = isRange(...)
	if v ~= nil then M.secrets[v] = true end
	return v
end
check(Shown() == nil, "secret range: nothing")
C_SwingTimer.IsTargetWithinSwingRange = isRange
M.secrets = {}
check(Shown() == "Out of melee range", "readable again")

-- /reach turns it off and on.
SlashCmdList.REACH("")
check(ReachDB.enabled == false and not w:IsShown() and M.out[#M.out]:find("off"), "turned off")
check(Shown() == nil, "off: nothing")
SlashCmdList.REACH("")
check(Shown() == "Out of melee range", "on again")

-- /reach move: a sample to drag, then click-through again.
SlashCmdList.REACH("move")
check(w:IsShown() and w.mouse == true and w.text:GetText():find("drag"), "move: sample shown")
w:SetPoint("TOP", UIParent, "TOP", 0, -200)
M.script(w, "OnDragStop")
check(ReachDB.point[1] == "TOP" and ReachDB.point[4] == -200, "position saved")
check(Shown():find("drag"), "the sample stays while moving")
SlashCmdList.REACH("move")
check(w.mouse == false and w.text:GetText() == "Out of melee range", "done moving")
M.fire("PLAYER_LEAVE_COMBAT")

-- A reload keeps the setting and position, and knows auto-attack is still on.
SlashCmdList.REACH("")
M.currentSpells[6603] = true
ns = M.Reload()
w = ns.warning
check(ReachDB.enabled == false and w.point[1] == "TOP" and w.point[5] == -200, "setting and position kept")
check(ns.melee == true, "auto-attack still on after a reload")
SlashCmdList.REACH("")
check(Shown() == "Out of melee range", "warns after the reload")
SlashCmdList.REACH("reset")
check(ReachDB.point == nil and w.point[1] == "CENTER" and w.point[5] == 150, "position reset")
