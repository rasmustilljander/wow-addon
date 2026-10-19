-- Jump counter: every jump is stored with time, place and coordinates.
local _, ns = ...

-- Pressing jump while already in the air (or swimming, or on a flight) doesn't
-- jump, so we only count presses that start from the ground. The falling state
-- is sampled every frame because it may already read "falling" by the time our
-- hook runs for a real jump.
local airborne = false
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	airborne = IsFalling() and true or false
end)

hooksecurefunc("JumpOrAscendStart", function()
	if not ns.char or airborne or IsSwimming() or UnitOnTaxi("player") or IsFlying() then
		return
	end
	airborne = true

	local zone = ns.Clean(GetRealZoneText()) or "?"
	local subzone = ns.Clean(GetSubZoneText()) or ""
	ns.jumps:Add(ns.Pack(ns.Here(), zone, subzone))

	ns.Add(1, "jumps")
	ns.Add(1, "jumpsByZone", zone)
	ns.session.jumpCount = (ns.session.jumpCount or 0) + 1
end)
