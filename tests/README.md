# Tests

The tests run the addons in real Lua 5.1 (the game's version) against a fake WoW: Forever client, [`wowmock.lua`](wowmock.lua). Each one plays through something (walking, looting, a vendor visit, a reload) and checks what the addons recorded.

## Running

Needs Python 3 and [lupa](https://pypi.org/project/lupa/), which bundles Lua 5.1:

```
pip install lupa
python tests/run.py                            # everything
python tests/run.py tests/TravelLog/loot.lua   # one file
```

Each file runs in a fresh Lua state. The output gives passed/failed counts and failing checks per file; the exit code is non-zero on any failure.

## Files

| File | |
| --- | --- |
| `run.py` | Finds and runs `tests/<Addon>/*.lua`. |
| `wowmock.lua` | The fake client: frames and the Blizzard templates addons use, events, player position and state, bags, bank tabs (buying them, account bank gold) and the cursor, equipment (bags and enchants too) and its durability, death, its recap and resurrection, AFK, breath and fatigue bars, trades, mail, posting and owned auctions, loot windows (several corpses in one), merchants, flights, talents, the quest log (failed and timed quests, collapsed headers) and its abandon dialog, talent resets, stable slots, the guild bank window, its tabs and moving items in and out, the barber window, summons, instances, boss encounters and lockouts (Raid Info), resting, duels, honorable kills, your PvP rank and battleground results, guilds, achievements, channels and pets (levels, abandoning, the stable), the world map and world positions, the minimap's range and facing, the addon compartment, the Options window's AddOns pages, auto-attack and shooting, player auras and `UNIT_AURA`, screenshots, swing range and interact distance to the target, CVars, addon messages and chat filters, SavedVariables, load-on-demand addons. |
| `TravelLog/adventure.lua` | A short adventure with TravelLog, Path and Nodes: path, jumps, loot, successful and failed vendor actions, money, quests (one abandoned), a flight, a death, the map trail, companion commands, a reload. |
| `TravelLog/deathrecap.lua` | The killer and cause from the death recap: a mob, a player, a pet, lava, a recap that's late, old, from before a reload or unreadable, no recap API; totals and a reload. |
| `TravelLog/deaths.lua` | Deaths by drowning, fatigue, a fall or a mob; coming back by corpse run, spirit healer, another player or a soulstone; time dead, durability lost, a reload while a ghost, `/tl log` and `/tl stats`. |
| `TravelLog/loot.lua` | Loot sources (pickpockets too), roll wins, rolls lost or passed on, and the partner or sender of trades and mail. |
| `TravelLog/outgoing.lua` | Items given in a trade, mailed (and postage), put up for auction (with a confirmation) and destroyed (whole, split, worn); guild bank deposits and withdrawals (right-click, drag, split, equipping that isn't one, a visit ended by logging out); their totals and History groups, a reload. |
| `TravelLog/played.lua` | Time played: asked quietly at login, counted forward, how long a level took, `/tl stats` and `/tl log`, a reload, no answer. |
| `TravelLog/quests.lua` | Failed quests: an escort, a timer running out, a collapsed header, logged once across log updates, a reload and an abandon, retaken, `/tl stats`, `/tl log`, `/tl sessions`, the Totals. |
| `TravelLog/gear.lua` | Gear: what's worn at the first login remembered, new gear logged once (not shirts, tabards or swaps back), uncached and unreadable items, enchants (replacing one, a first one, a swapped copy, a poison, another item), bags (new, replacing, swapped back, none at first), totals, `/tl log`, a reload, a character with nothing on. |
| `TravelLog/travel.lua` | Teleports by your casts and others' portals, hearthstone-like spells, summons (a secret summoner too), a boat ride across a loading screen, dungeons and raids with time inside across a reload and a relog, and what isn't travel (casts, walking, doors, knockbacks, deaths); stats, `/tl log` and Totals rows. |
| `TravelLog/resting.lua` | Resting: entering and leaving an inn, its door, a reload and a night logged out inside, logging in rested (known late too), rested XP; stats, `/tl log`, the Resting row. |
| `TravelLog/zonetime.lua` | Time by zone: counted while logged in (AFK too), subzones, a zone change, a loading screen, a secret zone name, a reload and a night logged out; `/tl stats`, the Totals row, an alt and all added up. |
| `TravelLog/bosses.lua` | Boss fights: wipes and kills (a reload during the fight, an unseen pull, a secret name, an unknown difficulty), kills and wipes on leaving, a raid boss, a fight outside an instance; stats, `/tl log`, the Bosses row, a reload. |
| `TravelLog/lockouts.lua` | Lockouts at the first login (remembered, not logged), a new one after a kill and after the "now saved" line, extended, expired, forgotten and secret ones, a reload; resets that worked and failed; stats, `/tl log`, the Instances row. |
| `TravelLog/screenshots.lua` | Screenshots: the file name from when it was taken, where, a failed one; stats, `/tl log`, the Screenshots row, a reload. Automatic ones on level-ups, boss kills (first kills only or all) and Legacy Challenges: the wait, the 1 s gap, a failed one, `/tl screenshots`, the Settings tab, a reload. |
| `TravelLog/notes.lua` | Notes: `/tl note` without text, the text as typed, the time and place, History's Travel filter and search, `/tl log`, `/tl stats`, the Notes row, the map marker and its tooltip, a reload. |
| `TravelLog/pvp.lua` | Duels challenged and accepted (won, lost, fled, no winner, declined), others' duels, honorable kills from chat and from the kill count when chat is hidden, honor awards, your rank going up and down (online, offline, a new season, data arriving late), battlegrounds won, lost, drawn (a secret score) and left; stats, `/tl log`, the PvP and Battlegrounds rows, a reload. |
| `TravelLog/guild.lua` | Guilds: the first one remembered, promotions and demotions (the line before or after), others' lines, a renamed rank, kicked out, accepted and declined invitations, late-loading guild info, leaving, founding, offline changes, a secret name; stats, `/tl log`, the Guild row, a reload. |
| `TravelLog/itemtooltip.lua` | Item tooltips: rare and better items first looted, fished, won in a roll, mailed or bought, how often (sales and common items not), kept up to date as the log grows, an uncached item, a reload and an alt. |
| `TravelLog/locales.lua` | Reordered numbered placeholders in localized loot, XP, discovery, reputation standing and gain, guild, honor, duel and instance reset messages. |
| `TravelLog/worldbuffs.lua` | World buffs: gained (with giver and duration), already on you at login or a reload, refreshed in place, replaced, other buffs and units, a secret spell ID, a full update; stats, `/tl log`, the Totals row, a reload. |
| `TravelLog/achievements.lua` | Legacy Challenges: points, category and reward, earned before on another character, a guild one, one the client has no info for, a secret name; stats, `/tl log`, the Totals row, a reload. |
| `TravelLog/progress.lua` | Spells from a trainer (with cost) and chat, new skills and milestones, a flight path, a reputation standing, mounts, their map markers and Totals row, a reload. |
| `TravelLog/pets.lua` | Taming: a beast tamed (the first marked), channels cut short or interrupted, pets called or dismissed or turning up late, other channels, a secret name. Pet level-ups (several at once, another pet, a secret level, a warlock's demon), abandoning (confirmed or not), stabling, taking out and swapping. History, `/tl log`, `/tl stats`, the Totals row, a reload. |
| `TravelLog/talents.lua` | Talent points: existing ones remembered, each applied point (staged ones wait), several ranks at once, a respec and a full reset, the second spec, a secret name, History, `/tl log`, `/tl stats`, the Totals row, a reload. |
| `TravelLog/storage.lua` | Per-character files, data versions of both files (a newer one left unread and untouched), old history kept in place, TravelLog alone (History with only Events and Sessions), moving old path and nodes into the companions. |
| `TravelLog/money.lua` | Money reasons: bank slots (with their entry), the account and guild banks, the barber, talent resets, stable slots, auction deposits and sales, COD; `/tl log`, `/tl stats`, a reload. |
| `TravelLog/sessions.lua` | Where each session starts and ends (a zone unknown at login too), experience gained per session (across a level-up), money, time AFK and per-hour rates with and without it (the setting), what happened in each, `/tl sessions`, the Sessions view, a reload while AFK. |
| `TravelLog/experience.lua` | XP by source: counted once from a character's saved sessions (its old kill counter dropped), then as it happens; other, `/tl stats`, `/tl sessions`, the Totals row, the Sessions view's tooltip, a reload, an alt and all added up. |
| `TravelLog/restedxp.lua` | Rested bonus XP from the rested pool going down (before or after the XP bar, a partly rested last kill), not from it going up, an unreadable pool, max level or a reload; taken out of kills or other; `/tl stats`, `/tl sessions`, the Totals row, the Sessions tooltip, a session saved without it. |
| `TravelLog/window.lua` | The window and its addon compartment entry: sections, totals, settings, the History tab's searchable event log and Kills view, companion tabs, moving, a reload, and an alt's view of other characters' and everyone's totals (`/tl stats all`/`name` too). |
| `TravelLog/stress.lua` | Six hours of non-stop movement: speed, file size, map drawing. Prints its measurements. |
| `TravelLog_Path/colors.lua` | The Colors tab: recoloring trail lines and markers with the color picker, cancelling, defaults, a reload. |
| `TravelLog_Path/curves.lua` | Trail curves: straight lines at 0, a rounded corner through the recorded points, straight walks left alone, more pieces zoomed in, live drawing matching a full redraw, `/tl smooth`, the window's buttons, a reload. |
| `TravelLog_Path/alts.lua` | The path's move to the account-wide file, trail ranges (hours, days, calendar days), alts' trails, the window's day steppers and alt checkboxes, old stored paths, wiping. |
| `TravelLog_Nodes/nodes.lua` | Remembered nodes, their minimap and world map pins and tooltips, alts sharing them, wiping, migration from 0.1 and from TravelLog. |
| `KillXP/tooltip.lua` | XP formula, rested and party bonuses, kills to level, tooltip lines, learning real XP (not from rested kills whose line leaves the bonus out), a newer data version left unread and untouched. |
| `CVarBrowser/browser.lua` | Listing, searching, filtering, bookmarking and changing CVars, in code and through the window, its addon compartment entry, and a reload. |
| `JunkToss/junk.lua` | Picking the cheapest grey or allowlisted stack, throwing it away from the minimap button, window and commands, the allowlist, a reload. |
| `TravelLog_Share/share.lua` | Two accounts sharing: the allow list, refused and recorded requests, nodes on request and as they're looted, a log on request, pacing and throttling, offline players, shared pins, the Sharing tab, a reload. |
| `ItemCount/count.lua` | Bags, bank and account bank, mail and mail to alts, auctions running out, equipped items, tooltip lines, commands, a reload. |
| `ItemCount/guildbank.lua` | The Options page, the guild bank counted tab by tab (hidden and removed tabs), shown only in its own guild and outside the total, turned off, a reload. |
| `TravelLog_Group/group.lua` | Groups from the roster, other realms, kills together, unreadable names, raids, reloads and long logouts while grouped, tooltips, commands, the Players tab. |
| `TravelLog_Kills/kills.lua` | Kills from `PARTY_KILL` and the XP chat line, party and pet kills, secret GUIDs, tooltips, map pins, commands, the Kills view, a reload. |
| `TravelLog_Kills/drops.lua` | Drops per mob from corpse loot windows (several corpses in one, reopened, coins only, no source info), what isn't a drop (pickpockets, chests, fishing, skinning), tooltips' top 5, `/kills <name>`, a reload. |
| `Reach/reach.lua` | The warning out of melee range and in a hunter's dead zone, quiet far away, without a weapon check and with secret ones; turning it off, moving it, a reload while auto-attacking. |
| `TravelLog_NPCs/npcs.lua` | NPCs from each kind of window, vendors' stock and filters, item tooltips, minimap pins (range, rotation, other maps), world map pins, hiding, commands, the NPCs tab, a reload and an alt. |

## Writing a test

A test drives the fake client through the global `M` and calls `check(condition, message)`:

```lua
local ns = M.Login()                -- load the installed addons and log in
M.x, M.wb = M.x + 0.01, M.wb - 40   -- walk a bit east...
M.tick(5)                           -- ...for 5 seconds
JumpOrAscendStart()                 -- press jump
check(ns.stats.jumps == 1, "jump counted")
ns = M.Reload()                     -- save SavedVariables to text, log out, log back in
check(TravelLogCharDB.sessions[1].stop, "session closed on logout")
```

| Part of `M` | |
| --- | --- |
| `M.Login()`, `M.Logout()`, `M.Reload()` | Logging out writes each loaded addon's SavedVariables to text (an unloaded addon keeps its old text, as in the game) and drops all addon state, hooks and frames. |
| `M.fire(event, ...)` | Send a game event. Registering an event the fake doesn't know errors, like the real client. |
| `M.tick(n)`, `M.advance(s)`, `M.frame()` | Run `C_Timer` tickers and timers for n seconds, move the clock, run one `OnUpdate` frame. |
| `M.cast(spellID, target)`, `M.lootAll(take)` | Cast a spell (SENT, then SUCCEEDED); loot the window in `M.loot`. |
| `M.channel(spellID, seconds)`, `M.channelStop(interrupted)` | Start channeling (CHANNEL_START, and `UnitChannelInfo`); stop (INTERRUPTED first when `interrupted`, then CHANNEL_STOP). |
| `M.x`, `M.y`, `M.wa`, `M.wb`, `M.mapID`, `M.zone`, `M.subzone`, `M.mounted`, `M.taxi`, `M.money`, ... | Player state read by the fake API. `M.x = nil` means inside a dungeon. |
| `M.player = { name, realm, class }` | Who logs in; `class` is the class file name (default `MAGE`). Change it between logins to play an alt. |
| `M.stable[slot]`, `M.abandoned` | Pets in the stable (`{ name, level, familyName, petNumber }`; slot 1 is the pet you can call) and how often `C_PetInfo.PetAbandon` was called. `C_StableInfo.SetPetSlot` swaps two slots and fires `PET_STABLE_UPDATE`. |
| `M.units.target = { name, guid, hostile, level, ... }` | Other units (also `realm` for another realm, `class`, `classification`, `dead`, `tapped`, `trivial`, `player`, `pet`, `family` for a beast's creature family, and `title` for the tooltip line under an NPC's name). `M.units.npc` is who you're talking to. |
| `M.hover(unit)`, `M.hoverItem(itemID)` | Show a unit's or item's tooltip, running addons' post-calls; returns its lines without color codes. |
| `M.played`, `M.playedLevel`, `M.playedAsks`, `M.chatLines` | Seconds played in all and at this level (both grow with the clock), how often `RequestTimePlayed` was called (it answers with `TIME_PLAYED_MSG` a second later), and what `ChatFrame1` printed of the answers. |
| `M.xp`, `M.xpMax`, `M.rested`, `M.resting`, `M.auras`, `M.group`, `M.raid`, `M.instance` | Experience, rested pool (`GetXPExhaustion`; fire `UPDATE_EXHAUSTION` after changing it), whether you're resting (`IsResting`; fire `PLAYER_UPDATE_RESTING` after changing it), player auras by spell ID (`M.gainAura(spellID, fields)`, `M.refreshAura`, `M.loseAura` send `UNIT_AURA` updates; login sends a full one), other group members' units (`party1`, ... or `raid1`, ...), raid or party, instance type. |
| `M.questLog`, `M.failedQuests[id]`, `M.questTimers[id]` | The quest log as shown (quest IDs and header names; leave out a collapsed header's quests), failed quests, and timed ones (`{ total, started }`, `started` from `GetTime()`). |
| `M.instanceInfo`, `M.speed`, `M.summon` | The instance you're in (`{ name, difficultyName, maxPlayers, instanceID }`, for `GetInstanceInfo`), your own speed (`GetUnitSpeed`: 7 unless set, 0 standing on a boat), a summon on offer (`{ by, area }`, then fire `CONFIRM_SUMMON`). Tests fire `ENCOUNTER_START` and `ENCOUNTER_END` themselves; `GetDifficultyInfo` knows difficulties 1, 2 and 9. |
| `M.skills`, `M.spellNames[id]`, `M.spellRanks[id]` | Skill lines (`{ skillID, name, rank, isHeader }`), spell names and rank text. |
| `M.talentConfig`, `M.loadouts[configID][nodeID] = { spellID, tree, rank, max }`, `M.talentTrees[groupID]`, `M.talentsStaged` | The active talent loadout (nil: none yet), each loadout's talents with points applied, the trees' names, and whether points are placed but not applied. |
| `M.trainerServices[i] = { name, rank, cost }` | The open trainer's list (`GetTrainerServiceInfo`, `GetTrainerServiceCost`). |
| `M.guidNames[guid] = name` | Units the client still knows by GUID (`UnitNameFromGUID`) after they're gone. |
| `M.cvars[name] = { value, default, help, category, ... }` | CVars the client knows (also `secure`, `readOnly`, `account`, `character`, `max`, and `unlisted` to leave one out of `ConsoleGetAllCommands`). |
| `M.script(frame, name, ...)`, `button:Click([mouseButton])` | Run a frame's script and its hooks (`OnEnterPressed`, `OnDragStop`, ...); click a button (default `"LeftButton"`) unless it's disabled. A scroll box gets a row in `.rows` for every element. |
| `M.bags["bag:slot"]`, `M.bagSlots[bag]`, `M.items[itemID]` | Bag contents (an item link, or `{ link, count, locked }`), bag sizes (default: a 16-slot backpack) and what the client knows of an item (`quality`, `price`, `icon`, `noValue`, `level`, `uncached`). |
| `M.equipped[slot]`, `M.equip(slot, link)`, `M.equipBag(bag, link, slots)`, `M.accountBank`, `M.bankTabs[bankType]` | Worn item links by inventory slot; put an item on (nil takes it off) with `PLAYER_EQUIPMENT_CHANGED`; put a bag in bag slot 1 to 5 (inventory slot 30 + bag) with `BAG_CONTAINER_UPDATE`; whether the account bank can be seen; how many tabs (bank slots) each bank has bought. Bank tabs are bags 6 and up (account bank 15 and up) in `M.bags`. |
| `M.inbox`, `M.sendItems`, `M.sentMail` | Inbox mails `{ sender, money, cod, invoice = { type, item, player }, items = { { link, count, currency } } }`, attachments of the mail being written, and what `SendMail` sent. |
| `M.tradeItems[i]` | `{ link, count }` in your trade slot i (7 is "will not be traded"). |
| `M.ownedAuctions`, `M.ownedQueries` | What `C_AuctionHouse.GetOwnedAuctions` returns, and how often owned auctions were queried. |
| `M.posts`, `M.postWarning` | What `C_AuctionHouse.PostItem`, `PostCommodity` and their `Confirm*` posted (`ItemLocation:CreateFromBagAndSlot` for the item); whether a post needs confirming. |
| `M.enchantNames[id]`, `M.tempEnchants[weaponSlot]` | Enchants: the ID is the link's field after the item ID; its name is the worn item's tooltip line (`C_TooltipInfo.GetInventoryItem`). A weapon's temporary enchant ID by `Enum.WeaponSlot` (`C_Item.GetWeaponEnchantInfo`). Fire `UNIT_INVENTORY_CHANGED` after changing a worn link in place. |
| `M.cursorItem`, `M.cursorSplit`, `M.deleteWarning` | The `"bag:slot"` (or `"equip:slot"`) whose item is on the cursor, how many after `C_Container.SplitContainerItem`, and whether the first `DeleteCursorItem` waits for confirmation. |
| `M.combat`, `M.afk` | In combat (`InCombatLockdown`); AFK (`UnitIsAFK`; fire `PLAYER_FLAGS_CHANGED` after changing it). |
| `M.dead`, `M.ghost`, `M.falling`, `M.durability[slot]`, `M.mirrorTimers` | Dead, a ghost or falling; worn items' `{ current, max }` durability; milliseconds left on the `BREATH` and `EXHAUSTION` bars. Tests fire the death, resurrection and bar events themselves. |
| `M.resurrecter`, `M.resSickness`, `M.selfRes` | Who offers a resurrection, whether it brings resurrection sickness, and the death dialog's self-resurrect options (`{ name, optionType, id, canUse, ... }`). |
| `M.recap` | The latest death recap's hits, newest first (`{ event, sourceName, sourceGUID, spellName, spellId, amount, overkill, environmentalType, timestamp, ... }`), as `C_DeathRecap.GetRecapEvents` returns them. |
| `M.guild` | Your guild: `{ name, rank, rankIndex }`, `{ loading = true }` while the client doesn't know which yet, or nil for none (`IsInGuild`, `GetGuildInfo`). Fire `PLAYER_GUILD_UPDATE` after changing it. `M.rosterRequests` counts `C_GuildInfo.GuildRoster` calls. |
| `M.achievements[id]`, `M.achievementCategories[id]` | Achievements (`{ name, points, category, reward, guild }`, for `GetAchievementInfo` and `GetAchievementCategory`) and their categories (`{ name, parent }`, for `GetCategoryInfo`). Fire `ACHIEVEMENT_EARNED` with the ID. |
| `M.honorKills` | Today's honorable kills (`GetPVPSessionStats`); fire `PLAYER_PVP_KILLS_CHANGED` after changing it. |
| `M.pvpRank`, `M.pvpSeason` | Your PvP rank (renown with faction 2800; nil: not loaded yet) and the season (`GetCurrentArenaSeason`); fire `UPDATE_FACTION`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` or `PLAYER_PVP_RANK_CHANGED` after changing them. |
| `M.pvpFaction`, `M.pvpScore` | Your battleground team (`GetBattlefieldArenaFaction`: 0 Horde, 1 Alliance, the default) and your scoreboard line (`{ killingBlows, honorableKills, deaths, honorGained }`); fire `PVP_MATCH_COMPLETE` with the winner and seconds. |
| `M.sent`, `M.sendResult`, `M.addonMessage(sender, prefix, text)` | Addon messages sent (`{ prefix, text, chatType, target }`), a function returning another `Enum.SendAddonMessageResult` (throttled, offline), and a whisper arriving from another player. |
| `M.chat(event, text)` | Send a chat event; returns whether the chat frame would show it after addons' filters. |
| `M.guildBankItems["tab:slot"]`, `M.guildBankTabs`, `M.guildBankTab`, `M.guildBankHidden[tab]` | Guild bank items (a link, or `{ link, count }`), how many tabs it has, the one shown and those you may not view. Fire `GUILDBANKBAGSLOTS_CHANGED` when a tab's items arrive. |
| `M.settings[name]` | An addon's page under Options → AddOns; `controls[i].setting` has `:GetValue()` and `:SetValue(value)`. |
| `M.compartment[addon]` | The addon's entry in the minimap's addons dropdown (`text`, `icon`, `:Click([mouseButton])`), for addons whose `.toc` names an `AddonCompartmentFunc`. |
| `M.cursor` | Cursor position in screen coordinates (`GetCursorPosition`); `Minimap` is 140 wide with its center at (1800, 900). |
| `M.minimapRadius`, `M.facing`, `M.world[mapID]` | Yards the minimap shows from its center, your facing in radians, and where maps lie in the world (`{ continent, left, top, width, height }` in yards). |
| `M.merchantItems`, `M.merchantFilter`, `M.canRepair` | The open vendor's items (`C_MerchantFrame.GetItemInfo` fields plus `link`), its filter (`LE_LOOT_FILTER_ALL` when nil) and whether it repairs. |
| `M.units.target.distance`, `M.swingReach[swingType]`, `M.currentSpells[id]` | Yards to the target (for `CheckInteractDistance`: 8 trade, 7 duel, 28 inspect and follow), each `Enum.PlayerSwingType`'s weapon reach `{ min, max }` (main hand 0–5 by default; nil means none), and spells on for `C_Spell.IsCurrentSpell` (auto attack is 6603). Fire `PLAYER_ENTER_COMBAT` or `START_AUTOREPEAT_SPELL` to start attacking. |
| `M.secrets[value] = true` | Make a value secret, as the Midnight-era client does in dungeons. |
| `M.installed`, `M.disabled` | Addon folders the client knows (default TravelLog, TravelLog_Path, TravelLog_Nodes) and which are off. |
| `M.viewMap`, `M.mapOverlay(level)`, `M.shown(pool)` | The shown world map, an addon's overlay on it (newest, or by frame level: Path 2010, Kills 2011, Nodes 2012), and its visible lines, textures and frames. |
| `M.pickColor(r, g, b, a)`, `M.closeColorPicker(okay)` | Drag the open `ColorPickerFrame` to a color; close it with Okay or Cancel. |
| `M.screenshots`, `M.screenshotFails` | How often `Screenshot` was called (it fires `SCREENSHOT_STARTED`, then `SCREENSHOT_SUCCEEDED` a second later), and whether it fails instead (`SCREENSHOT_FAILED`). |
| `M.out`, `M.errors` | Everything printed to chat, and Lua errors sent to `geterrorhandler` (they count as failures). |
| `M.saved`, `M.savedSize(addon, perCharacter)` | The saved files' text and size. |

When an addon needs an API or event the fake lacks, add it to `wowmock.lua`.

## What the fake can't tell you

A passing test only means the addon works **if** the real client behaves like `wowmock.lua`. Check new APIs against Blizzard's Forever UI code, as described in [`.claude/skills/addon-tests/SKILL.md`](../.claude/skills/addon-tests/SKILL.md).
