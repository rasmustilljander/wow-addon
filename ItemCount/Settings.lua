-- ItemCount's page in the game's Options window, under AddOns.
local _, ns = ...

-- Called at login, once ItemCountDB is loaded. Missing settings get their
-- defaults.
function ns.SetUpSettings(db)
	db.settings = db.settings or {}
	local category = Settings.RegisterVerticalLayoutCategory("ItemCount")
	local guildBank = Settings.RegisterAddOnSetting(category, "ItemCount_GuildBank", "guildBank", db.settings,
		Settings.VarType.Boolean, "Guild bank", true)
	Settings.CreateCheckbox(category, guildBank,
		"Count your guild's bank and show it on tooltips, only while you play a character in that guild. It isn't added to the total.")
	Settings.RegisterAddOnCategory(category)
end
