-- Distance by form: each shapeshift form and stealth counted next to the
-- per-mode totals, both moonkin IDs as one, prowl as cat and stealth, other
-- and secret forms not counted, the form and stealth in the stored flags,
-- /tl stats, the window's row, a reload and all characters added up.
M.installed = { "TravelLog", "TravelLog_Path" }
M.player = { name = "Rasmus", realm = "Forever", class = "DRUID" }
local ns = M.Login()
local path = M.ns("TravelLog_Path")

local function Walk(seconds)
	for _ = 1, seconds do
		M.wb = M.wb - 4
		M.tick(1)
	end
end
local function Near(a, b) return a and math.abs(a - b) < 0.01 end
local function LastFlags()
	local _, _, _, _, _, _, _, flags = path.Unpack(path.track.buffer[#path.track.buffer])
	return flags
end
local function Stats()
	M.out = {}
	SlashCmdList.TRAVELLOG("stats")
	return table.concat(M.out, "\n")
end
local function Stat(label)
	SlashCmdList.TRAVELLOG("")
	local w = ns.window
	for _ = 1, 70 do M.frame() end
	local all = M.descendants(w)
	local value
	for i, r in ipairs(all) do
		if r.kind == "FontString" and r:GetText() == label then value = all[i + 1]:GetText() end
	end
	SlashCmdList.TRAVELLOG("")
	return value
end

-- No form: nothing by form, the row says so.
M.tick(1)
Walk(5)
check(Near(ns.stats.distance.foot, 20) and ns.stats.formDistance == nil, "on foot, no form distance")
check(not Stats():find("by form"), "no by-form line in /tl stats")
check(Stat("Distance by form") == "none", "window row: none")

-- Cat form: a new point with the form in the flags, counted as foot and cat.
local points = #path.track.buffer
M.form = 1
M.tick(1)
check(#path.track.buffer == points + 1 and LastFlags() == 128, "shifting records a point, form 1 in flags: " .. LastFlags())
check(ns.FormOf(LastFlags()) == 1 and not ns.HasFlag(LastFlags(), ns.FLAGS.mounted)
	and not ns.HasFlag(LastFlags(), ns.FLAGS.stealth), "HasFlag ignores the form bits")
Walk(10)
check(Near(ns.stats.formDistance.cat, 40) and Near(ns.stats.distance.foot, 60), "cat 40 yd, foot too")

-- Prowl: cat and stealth both.
M.stealthed = true
Walk(5)
check(LastFlags() == 128 + 64 and ns.HasFlag(LastFlags(), ns.FLAGS.stealth), "stealth bit: " .. LastFlags())
check(Near(ns.stats.formDistance.cat, 60) and Near(ns.stats.formDistance.stealth, 20), "prowling counts as cat and stealth")
M.stealthed = false

-- Travel, bear, both moonkin forms, aquatic while swimming, Ghost Wolf.
for _, f in ipairs({ { 3, "travel" }, { 5, "bear" }, { 31, "moonkin" }, { 35, "moonkin" }, { 16, "ghostwolf" } }) do
	M.form = f[1]
	Walk(5)
end
check(Near(ns.stats.formDistance.travel, 20) and Near(ns.stats.formDistance.bear, 20)
	and Near(ns.stats.formDistance.moonkin, 40) and Near(ns.stats.formDistance.ghostwolf, 20), "each form counted, moonkin IDs as one")
M.form, M.swimming = 4, true
Walk(5)
check(Near(ns.stats.formDistance.aquatic, 20) and Near(ns.stats.distance.swim, 20)
	and ns.HasFlag(LastFlags(), ns.FLAGS.swimming) and ns.FormOf(LastFlags()) == 4, "aquatic and swimming")
M.swimming = false

-- Forms not on the list (tree, rogue stealth) are in the flags but not counted,
-- and a secret form ID reads as none.
local before = 0
for _, d in pairs(ns.stats.formDistance) do before = before + d end
M.form = 2
Walk(5)
check(ns.FormOf(LastFlags()) == 2, "tree form in the flags")
M.form = 30
M.secrets[30] = true
Walk(5)
check(LastFlags() == 0, "a secret form reads as none")
M.secrets[30] = nil
local after = 0
for _, d in pairs(ns.stats.formDistance) do after = after + d end
check(Near(before, after), "unlisted and secret forms not counted")
M.form = nil

-- /tl stats and the window.
local out = Stats()
check(out:find("Distance by form %(yd%): cat 60, bear 20, travel 20, aquatic 20, moonkin 40, ghost wolf 20, stealth 20"), "/tl stats line: " .. out)
check(Stat("Distance by form") == "cat 0.0, bear 0.0, travel 0.0, aquatic 0.0, moonkin 0.0, ghost wolf 0.0, stealth 0.0 miles",
	"window row: " .. tostring(Stat("Distance by form")))
ns.stats.formDistance.cat = 1760 * 2.5
check(Stat("Distance by form"):find("^cat 2%.5, bear 0%.0"), "window row in miles: " .. Stat("Distance by form"))

-- Kept over a reload, added up with an alt's.
ns = M.Reload()
check(Near(ns.stats.formDistance.cat, 4400) and Near(ns.stats.formDistance.stealth, 20), "kept over a reload")
M.Logout()
M.player = { name = "Altie", realm = "Forever", class = "SHAMAN" }
ns = M.Login()
M.tick(1)
M.form = 16
Walk(5)
check(Near(ns.stats.formDistance.ghostwolf, 20), "the alt's own Ghost Wolf distance")
M.out = {}
SlashCmdList.TRAVELLOG("stats all")
out = table.concat(M.out, "\n")
check(out:find("ghost wolf 40") and out:find("cat 4,400"), "/tl stats all adds them up: " .. out)
check(#M.errors == 0, "no errors")
