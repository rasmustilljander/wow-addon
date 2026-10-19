-- KillXP tooltip lines: XP per kill and kills to the next level.
local _, ns = ...

-- Levels of everyone in your group, yours first.
local function GroupLevels()
	local raid = IsInRaid()
	local levels = { UnitLevel("player") }
	local prefix, count = raid and "raid" or "party", GetNumGroupMembers()
	for i = 1, raid and count or count - 1 do
		local unit = prefix .. i
		if not UnitIsUnit(unit, "player") then
			local level = ns.Clean(UnitLevel(unit))
			if level and level > 0 then
				levels[#levels + 1] = level
			end
		end
	end
	return levels, raid
end

-- What killing `unit` would give you, or nil for units that don't give kill
-- XP (players, pets, friendly NPCs, the dead) or when you can't gain XP.
-- Also remembers the mob so its kill message can be matched later.
function ns.Look(unit)
	if not unit or not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit)
		or not UnitCanAttack("player", unit) or UnitIsDead(unit) then
		return nil
	end
	local level = UnitLevel("player")
	if level >= GetMaxPlayerLevel() or IsXPUserDisabled() then
		return nil
	end
	local mobLevel = ns.Clean(UnitLevel(unit))
	local elite = ns.IsElite(unit)
	if not mobLevel then
		return nil
	end
	local info = { mobLevel = mobLevel, elite = elite }
	if mobLevel <= 0 then
		info.unknown = true   -- "??": too high to see its level
		return info
	end
	ns.Remember(UnitName(unit), mobLevel, elite)
	if UnitIsTapDenied(unit) then
		info.tapped = true
		return info
	end

	local dungeon = ns.InDungeon()
	info.solo, info.estimate = ns.SoloXP(level, mobLevel, elite, dungeon)
	if info.solo == 0 or ns.Clean(UnitIsTrivial(unit)) then
		info.solo, info.gray = 0, true
		return info
	end
	info.xp = info.solo
	if GetNumGroupMembers() > 0 then
		local levels, raid = GroupLevels()
		info.groupSize = #levels
		info.xp = ns.GroupShare(info.solo, level, mobLevel, levels, raid)
		info.estimate = true   -- assumes everyone is alive and close by
	end

	local rested = GetXPExhaustion() or 0
	info.rested = math.min(info.xp, rested)
	info.kills = ns.KillsToLevel(UnitXPMax("player") - UnitXP("player"), info.xp, rested)
	return info
end

local function Number(n)
	local s = tostring(n)
	repeat
		local done
		s, done = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until done == 0
	return s
end

local GRAY, WHITE, BLUE = "|cff9d9d9d", "|cffffffff", "|cff4fa3ff"

-- The right-hand text of the "Kill XP" line.
function ns.XPText(info)
	if info.unknown then
		return GRAY .. "unknown (level ??)|r"
	elseif info.tapped then
		return GRAY .. "none (tapped by others)|r"
	elseif info.gray then
		return GRAY .. "none (too low)|r"
	elseif info.xp == 0 then
		return GRAY .. "none (too low for your group)|r"
	end
	local about = info.estimate and "~" or ""
	local text = WHITE .. about .. Number(info.xp + info.rested) .. "|r"
	local parts = {}
	if info.rested > 0 then
		parts[#parts + 1] = BLUE .. "+" .. Number(info.rested) .. " rested|r"
	end
	if info.groupSize then
		parts[#parts + 1] = ("%d in group, %s%s solo"):format(info.groupSize, about, Number(info.solo))
	end
	if #parts > 0 then
		text = text .. " (" .. table.concat(parts, ", ") .. ")"
	end
	return text
end

local function AddLines(tooltip)
	if tooltip ~= GameTooltip then
		return
	end
	local _, unit = tooltip:GetUnit()
	unit = ns.Clean(unit) or "mouseover"
	local info = ns.Look(unit)
	if not info then
		return
	end
	tooltip:AddDoubleLine("Kill XP", ns.XPText(info), 1, 0.82, 0)
	if info.kills then
		local about = info.estimate and "~" or ""
		tooltip:AddDoubleLine("Kills to level", WHITE .. about .. Number(info.kills) .. "|r", 1, 0.82, 0)
	end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
	-- A broken tooltip line must not break the tooltip.
	local ok, err = pcall(AddLines, tooltip)
	if not ok then
		geterrorhandler()(err)
	end
end)
