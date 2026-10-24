-- World buffs: Rallying Cry, Songflower, the Dire Maul tribute, Sayge's
-- fortunes and the like, logged when you gain one.
local _, ns = ...

-- Spell ID -> name, used when the aura doesn't give one. Add new buffs here.
local WORLD_BUFFS = {
	[22888] = "Rallying Cry of the Dragonslayer",
	[16609] = "Warchief's Blessing",
	[24425] = "Spirit of Zandalar",
	[15366] = "Songflower Serenade",
	[22817] = "Fengus' Ferocity",
	[22818] = "Mol'dar's Moxie",
	[22820] = "Slip'kik's Savvy",
	[23768] = "Sayge's Dark Fortune of Damage",
	[23769] = "Sayge's Dark Fortune of Resistance",
	[23767] = "Sayge's Dark Fortune of Armor",
	[23766] = "Sayge's Dark Fortune of Intelligence",
	[23738] = "Sayge's Dark Fortune of Spirit",
	[23737] = "Sayge's Dark Fortune of Stamina",
	[23736] = "Sayge's Dark Fortune of Agility",
	[23735] = "Sayge's Dark Fortune of Strength",
	[430947] = "Boon of Blackfathom",
}
ns.WORLD_BUFFS = WORLD_BUFFS

-- auraInstanceID -> true for the world buffs on you now, so one you already
-- had at login, or that the client lists again, isn't logged as new.
local known = {}

-- Looks up which world buffs are on you, without logging them: at login and
-- whenever the client sends a full aura update (reloads, loading screens).
local function Remember()
	known = {}
	if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
		return
	end
	for spellID in pairs(WORLD_BUFFS) do
		local aura = ns.Clean(C_UnitAuras.GetPlayerAuraBySpellID(spellID))
		local id = aura and ns.Clean(aura.auraInstanceID)
		if id then
			known[id] = true
		end
	end
end

ns.On("PLAYER_LOGIN", Remember)

-- Who gave it, when the aura names a unit the client knows (not you).
local function Giver(unit)
	unit = ns.Clean(unit)
	if not unit or UnitIsUnit(unit, "player") then
		return
	end
	return ns.Clean((UnitName(unit)))
end

local function Gained(aura)
	local spellID, id = ns.Clean(aura.spellId), ns.Clean(aura.auraInstanceID)
	if not spellID or not WORLD_BUFFS[spellID] or (id and known[id]) then
		return
	end
	if id then
		known[id] = true
	end
	local duration = ns.Clean(aura.duration)
	ns.Log("worldbuff", {
		id = spellID,
		name = ns.Clean(aura.name) or WORLD_BUFFS[spellID],
		duration = duration and duration > 0 and ns.Round(duration) or nil,
		by = Giver(aura.sourceUnit),
	})
	ns.Add(1, "worldBuffs")
end

-- The client says what changed: only addedAuras can hold a new world buff,
-- so the rest of your auras aren't looked at. A buff refreshed in place
-- comes as updatedAuraInstanceIDs and isn't a new gain.
ns.On("UNIT_AURA", function(unit, info)
	if unit ~= "player" then
		return
	end
	if not info or info.isFullUpdate then
		return Remember()
	end
	for _, id in ipairs(info.removedAuraInstanceIDs or {}) do
		id = ns.Clean(id)
		if id then
			known[id] = nil
		end
	end
	for _, aura in ipairs(info.addedAuras or {}) do
		aura = ns.Clean(aura)
		if aura then
			Gained(aura)
		end
	end
end)
