-- ItemCount: the Options page, the guild bank counted tab by tab, shown only
-- to the guild's own characters and left out of the total, turned off, a
-- reload.
M.installed = { "ItemCount" }

local function Link(id, name)
	return "|cffffffff|Hitem:" .. id .. "::::|h[" .. name .. "]|h|r"
end
local LINEN, WOOL = Link(2589, "Linen Cloth"), Link(2592, "Wool Cloth")
M.items = { [2589] = { link = LINEN }, [2592] = { link = WOOL } }

local function Lines(id)
	local lines = M.hoverItem(id)
	table.remove(lines, 1) -- the item's name
	return table.concat(lines, " | ")
end

--------------------------------------------------------------------------------
-- The Options page
--------------------------------------------------------------------------------

M.player = { name = "Rasmus", realm = "Forever", class = "MAGE" }
M.guild = { name = "Explorers", rank = "Member", rankIndex = 2 }
M.bags = { ["0:1"] = { link = LINEN, count = 10 } }
local ns = M.Login()

local page = M.settings.ItemCount
check(page and #page.controls == 1, "a page under AddOns")
local guildBank = page and page.controls[1].setting
check(guildBank:GetName() == "Guild bank" and guildBank:GetValue() == true, "guild bank on by default")
check(ns.db.settings.guildBank == true, "saved")

--------------------------------------------------------------------------------
-- Counting tab by tab
--------------------------------------------------------------------------------

M.guildBankTabs, M.guildBankTab = 3, 1
M.guildBankItems = {
	["1:1"] = { link = LINEN, count = 20 }, ["1:98"] = { link = LINEN, count = 5 }, ["1:4"] = WOOL,
	["2:1"] = { link = LINEN, count = 100 },
}
M.fire("GUILDBANKBAGSLOTS_CHANGED")
check(Lines(2589) == "Rasmus  10 (bags 10)", "not counted while closed: " .. Lines(2589))

M.fire("GUILDBANKFRAME_OPENED")
M.fire("GUILDBANKBAGSLOTS_CHANGED")
check(Lines(2589) == "Rasmus  10 (bags 10) | Guild bank  25", "first tab, no total: " .. Lines(2589))
check(Lines(2592) == "Guild bank  1", "only in the guild bank: " .. Lines(2592))

M.guildBankTab = 2
M.fire("GUILDBANKBAGSLOTS_CHANGED")
check(Lines(2589):find("Guild bank  125"), "second tab added: " .. Lines(2589))

-- A tab you may not view keeps nothing new; one past the last isn't a tab.
M.guildBankTab, M.guildBankHidden[3], M.guildBankItems["3:1"] = 3, true, { link = LINEN, count = 1 }
M.fire("GUILDBANKBAGSLOTS_CHANGED")
M.guildBankTab = 4
M.fire("GUILDBANKBAGSLOTS_CHANGED")
check(Lines(2589):find("Guild bank  125"), "hidden and missing tabs ignored: " .. Lines(2589))

-- Taking items out, seen on the next look at the tab.
M.guildBankTab, M.guildBankItems["1:1"] = 1, nil
M.fire("GUILDBANKBAGSLOTS_CHANGED")
M.fire("GUILDBANKFRAME_CLOSED")
check(Lines(2589):find("Guild bank  105"), "recounted: " .. Lines(2589))

M.out = {}
SlashCmdList.ITEMCOUNT("")
check(table.concat(M.out, "\n"):find("Guild bank %(Explorers%-Forever%): 0m ago"), "last counted: " .. table.concat(M.out, "\n"))

-- A tab the guild no longer has is dropped.
M.guildBankTabs = 1
M.fire("GUILDBANKFRAME_OPENED")
M.fire("GUILDBANKBAGSLOTS_CHANGED")
M.fire("GUILDBANKFRAME_CLOSED")
check(Lines(2589):find("Guild bank  5$"), "removed tab dropped: " .. Lines(2589))
M.guildBankTabs = 2
M.fire("GUILDBANKFRAME_OPENED")
M.guildBankTab = 2
M.fire("GUILDBANKBAGSLOTS_CHANGED")
M.fire("GUILDBANKFRAME_CLOSED")
M.Logout()

--------------------------------------------------------------------------------
-- Only for the guild's characters, never in the total
--------------------------------------------------------------------------------

M.player, M.guild = { name = "Altie", realm = "Forever", class = "WARRIOR" }, nil
M.bags = { ["0:1"] = { link = LINEN, count = 3 } }
ns = M.Login()
check(Lines(2589) == "Total  13 | Altie  3 (bags 3) | Rasmus  10 (bags 10)", "not shown to an alt outside the guild: " .. Lines(2589))
check(Lines(2592) == "", "nothing for the alt")
M.out = {}
SlashCmdList.ITEMCOUNT("")
check(not table.concat(M.out, "\n"):find("Guild bank"), "no guild bank in /itemcount")

M.guild = { name = "Other Guild", rank = "Member", rankIndex = 2 }
check(Lines(2589) == "Total  13 | Altie  3 (bags 3) | Rasmus  10 (bags 10)", "nor to one in another guild")

M.guild = { name = "Explorers", rank = "Alt", rankIndex = 3 }
check(Lines(2589) == "Total  13 | Altie  3 (bags 3) | Rasmus  10 (bags 10) | Guild bank  105", "shown to a guild member, not in the total: " .. Lines(2589))
M.secrets["Explorers"] = true
check(not Lines(2589):find("Guild bank"), "unreadable guild name")
M.secrets["Explorers"] = nil

--------------------------------------------------------------------------------
-- Turned off, a reload
--------------------------------------------------------------------------------

M.settings.ItemCount.controls[1].setting:SetValue(false)
check(not Lines(2589):find("Guild bank"), "hidden when off")
M.guildBankItems["1:2"] = { link = LINEN, count = 50 }
M.fire("GUILDBANKFRAME_OPENED")
M.guildBankTab = 1
M.fire("GUILDBANKBAGSLOTS_CHANGED")
M.fire("GUILDBANKFRAME_CLOSED")

ns = M.Reload()
check(M.settings.ItemCount.controls[1].setting:GetValue() == false, "off kept over a reload")
check(not Lines(2589):find("Guild bank"), "still hidden")
M.settings.ItemCount.controls[1].setting:SetValue(true)
check(Lines(2589):find("Guild bank  105$"), "not counted while off: " .. Lines(2589))
