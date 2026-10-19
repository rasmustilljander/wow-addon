-- CVarBrowser: descriptions of well-known CVars, shown in the info box. The
-- client's own help text (often empty) is shown next to these. A CVar listed
-- here that Forever doesn't have is never shown.
local _, ns = ...

local ONOFF = "0 = off, 1 = on"

-- name = { what it does, its values (optional) }
local KNOWN = {
	-- Camera
	cameraDistanceMaxZoomFactor = { "How far the camera can zoom out, as a multiple of the normal maximum. The client caps it.", "1 = normal, higher zooms out further" },
	cameraSmoothStyle = { "Whether and how the camera swings back behind you while you move.", "0 = never adjusts the camera" },
	cameraYawMoveSpeed = { "How fast the camera turns sideways when you mouse-look." },
	cameraPitchMoveSpeed = { "How fast the camera tilts up and down when you mouse-look." },
	mouseInvertPitch = { "Inverts up and down when you mouse-look.", ONOFF },
	enableMouseSpeed = { "Use mouseSpeed instead of the system mouse speed.", ONOFF },
	mouseSpeed = { "Mouse sensitivity, used when enableMouseSpeed is on." },
	autoInteract = { "Click-to-move: right-clicking the ground walks you there.", ONOFF },

	-- Nameplates
	nameplateMaxDistance = { "How far away nameplates are shown, in yards." },
	nameplateShowEnemies = { "Show enemy nameplates.", ONOFF },
	nameplateShowFriends = { "Show friendly nameplates.", ONOFF },
	nameplateShowAll = { "Always show nameplates, not only for units in combat with you.", ONOFF },
	nameplateMotion = { "How nameplates arrange themselves when they would overlap.", "0 = overlapping, 1 = stacking" },
	nameplateOverlapV = { "Vertical space between stacked nameplates." },
	nameplateOccludedAlphaMult = { "Opacity of nameplates for units behind walls or other objects.", "0 = hidden, 1 = fully visible" },
	nameplateMinScale = { "Size of nameplates far away." },
	nameplateMaxScale = { "Size of nameplates close by." },
	nameplateSelectedScale = { "Size of your target's nameplate." },

	-- Combat
	SpellQueueWindow = { "How long before your current cast or global cooldown ends you can queue the next ability, in milliseconds.", "0 to 400" },
	ActionButtonUseKeyDown = { "Use abilities when the key is pressed instead of when it's released.", ONOFF },
	autoSelfCast = { "Helpful spells go on you when you have no friendly target.", ONOFF },
	autoDismountFlying = { "Dismount automatically when you use an ability while flying.", ONOFF },
	deselectOnClick = { "Clicking the ground clears your target. Off is sticky targeting.", ONOFF },
	doNotFlashLowHealthWarning = { "Stops the red screen flash at low health.", "0 = flash, 1 = no flash" },
	enableFloatingCombatText = { "Floating combat text about you: damage taken, heals, procs.", ONOFF },
	floatingCombatTextCombatDamage = { "Show the damage you deal as numbers over your targets.", ONOFF },
	floatingCombatTextCombatHealing = { "Show the healing you do as numbers over your targets.", ONOFF },
	WorldTextScale = { "Size of floating combat text and other text in the world." },

	-- Interface
	autoLootDefault = { "Loot everything without clicking. Holding the auto loot key does the opposite.", ONOFF },
	lootUnderMouse = { "Open the loot window at the mouse.", ONOFF },
	autoQuestWatch = { "Track quests in the objective tracker when you accept them.", ONOFF },
	autoClearAFK = { "Clear your AFK status when you move or act.", ONOFF },
	showTutorials = { "Show tutorial popups.", ONOFF },
	UberTooltips = { "Detailed spell and ability tooltips.", ONOFF },
	showTargetOfTarget = { "Show the target-of-target frame.", ONOFF },
	statusTextDisplay = { "Text on health and mana bars.", "NONE, NUMERIC, PERCENT or BOTH" },
	xpBarText = { "Always show the text on the experience bar.", ONOFF },
	alwaysShowActionBars = { "Show empty action bar slots.", ONOFF },
	lockActionBars = { "Lock action bars so abilities can't be dragged off.", ONOFF },
	countdownForCooldowns = { "Show the seconds left on cooldowns.", ONOFF },
	breakUpLargeNumbers = { "Thousands separators in large numbers.", ONOFF },
	rotateMinimap = { "Rotate the minimap with you instead of keeping north up.", ONOFF },
	colorblindMode = { "Colorblind mode: adds text to things shown by color only.", ONOFF },
	useUiScale = { "Use uiScale instead of the automatic UI size.", ONOFF },
	uiScale = { "Size of the whole UI, used when useUiScale is on." },
	mapFade = { "Fade the world map while you move.", ONOFF },
	scriptErrors = { "Show Lua errors from addons in a popup.", ONOFF },
	taintLog = { "Write taint (addons blocking Blizzard's UI) to Logs/taint.log.", "0 = off, 1 = basic, 2 = verbose" },

	-- Chat and social
	chatBubbles = { "Chat bubbles over players who /say or /yell.", ONOFF },
	chatBubblesParty = { "Chat bubbles for party chat.", ONOFF },
	whisperMode = { "Where new whispers show up.", "inline, popout or popout_and_inline" },
	showTimestamps = { "Timestamps in chat.", "none, or a format such as %H:%M " },
	profanityFilter = { "Hide swear words in chat.", ONOFF },
	blockTrades = { "Refuse all trade requests.", ONOFF },
	blockChannelInvites = { "Refuse all chat channel invites.", ONOFF },

	-- Sound
	Sound_EnableAllSound = { "Master switch for all sound.", ONOFF },
	Sound_EnableSFX = { "Sound effects.", ONOFF },
	Sound_EnableMusic = { "Music.", ONOFF },
	Sound_EnableAmbience = { "Ambient sounds like wind and birds.", ONOFF },
	Sound_EnableErrorSpeech = { "Your character says error messages aloud, like \"Not enough mana\".", ONOFF },
	Sound_EnableSoundWhenGameIsInBG = { "Keep playing sound when the game is in the background.", ONOFF },
	Sound_MasterVolume = { "Master volume.", "0 to 1" },
	Sound_SFXVolume = { "Sound effects volume.", "0 to 1" },
	Sound_MusicVolume = { "Music volume.", "0 to 1" },
	Sound_AmbienceVolume = { "Ambient sound volume.", "0 to 1" },
	Sound_DialogVolume = { "Dialog volume.", "0 to 1" },

	-- Graphics
	maxFPS = { "Frame rate limit while the game is in front.", "0 = no limit" },
	maxFPSBk = { "Frame rate limit while the game is in the background.", "0 = no limit" },
	renderScale = { "Resolution the 3D world is drawn at, relative to the screen.", "1 = full resolution" },
	Gamma = { "Screen brightness." },
	ffxGlow = { "Full-screen glow effect.", ONOFF },
	ffxDeath = { "Gray screen while you're dead.", ONOFF },
	weatherDensity = { "How much rain, snow and other weather is drawn.", "0 = none to 3 = most" },
	violenceLevel = { "How much blood is shown.", "0 = none to 5 = most" },
	screenshotFormat = { "File format of screenshots.", "jpeg, png or tga" },
	screenshotQuality = { "Quality of JPEG screenshots.", "1 to 10" },
}

-- By lowercase name, as CVar names are case-insensitive.
ns.known = {}
for name, info in pairs(KNOWN) do
	ns.known[name:lower()] = { text = info[1], values = info[2] }
end
