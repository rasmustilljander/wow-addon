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
| `wowmock.lua` | The fake client: frames and the Blizzard templates addons use, events, player position and state, bags, bank tabs and the cursor, equipment, mail, owned auctions, loot windows, merchants, flights, the world map and world positions, the minimap's range and facing, CVars, addon messages and chat filters, SavedVariables, load-on-demand addons. |
| `TravelLog/adventure.lua` | A short adventure with TravelLog, Path and Nodes: path, jumps, loot, vendors, money, quests, a flight, a death, the map trail, companion commands, a reload. |
| `TravelLog/loot.lua` | Loot sources (pickpockets too) and roll wins. |
| `TravelLog/progress.lua` | Spells from a trainer (with cost) and chat, new skills and milestones, a flight path, a reputation standing, mounts, their map markers, a reload. |
| `TravelLog/storage.lua` | Per-character files, migrations, rotation into the archive (Path's too), TravelLog alone, moving old path and nodes into the companions. |
| `TravelLog/window.lua` | The window and minimap button: sections, totals, settings, the searchable event log, companion tabs, moving, hiding the button and a reload. |
| `TravelLog/stress.lua` | Six hours of non-stop movement: speed, file size, map drawing. Prints its measurements. |
| `TravelLog_Path/alts.lua` | The path's move to the account-wide file, trail ranges (hours, days, calendar days), alts' trails, the window's day steppers and alt checkboxes, an alt's archive, wiping. |
| `TravelLog_Nodes/nodes.lua` | Remembered nodes, their minimap and world map pins and tooltips, alts sharing them, wiping, migration from 0.1 and from TravelLog. |
| `KillXP/tooltip.lua` | XP formula, rested and party bonuses, kills to level, tooltip lines, learning real XP. |
| `CVarBrowser/browser.lua` | Listing, searching, filtering, bookmarking and changing CVars, in code and through the window, and a reload. |
| `JunkToss/junk.lua` | Picking the cheapest grey or allowlisted stack, throwing it away from the minimap button, window and commands, the allowlist, a reload. |
| `TravelLog_Share/share.lua` | Two accounts sharing: the allow list, refused and recorded requests, nodes on request and as they're looted, a log on request, pacing and throttling, offline players, shared pins, the Sharing tab, a reload. |
| `ItemCount/count.lua` | Bags, bank and account bank, mail and mail to alts, auctions running out, equipped items, tooltip lines, commands, a reload. |
| `TravelLog_Group/group.lua` | Groups from the roster, other realms, kills together, unreadable names, raids, reloads and long logouts while grouped, tooltips, commands, the Players tab. |
| `TravelLog_Kills/kills.lua` | Kills from `PARTY_KILL` and the XP chat line, party and pet kills, secret GUIDs, tooltips, map pins, commands, the Kills tab, a reload. |
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
| `M.x`, `M.y`, `M.wa`, `M.wb`, `M.mapID`, `M.zone`, `M.subzone`, `M.mounted`, `M.taxi`, `M.money`, ... | Player state read by the fake API. `M.x = nil` means inside a dungeon. |
| `M.player = { name, realm, class }` | Who logs in; `class` is the class file name (default `MAGE`). Change it between logins to play an alt. |
| `M.units.target = { name, guid, hostile, level, ... }` | Other units (also `realm` for another realm, `class`, `classification`, `dead`, `tapped`, `trivial`, `player`, `pet`, and `title` for the tooltip line under an NPC's name). `M.units.npc` is who you're talking to. |
| `M.hover(unit)`, `M.hoverItem(itemID)` | Show a unit's or item's tooltip, running addons' post-calls; returns its lines without color codes. |
| `M.xp`, `M.xpMax`, `M.rested`, `M.auras`, `M.group`, `M.raid`, `M.instance` | Experience, rested pool, player auras by spell ID, other group members' units (`party1`, ... or `raid1`, ...), raid or party, instance type. |
| `M.skills`, `M.spellNames[id]`, `M.spellRanks[id]` | Skill lines (`{ skillID, name, rank, isHeader }`), spell names and rank text. |
| `M.trainerServices[i] = { name, rank, cost }` | The open trainer's list (`GetTrainerServiceInfo`, `GetTrainerServiceCost`). |
| `M.guidNames[guid] = name` | Units the client still knows by GUID (`UnitNameFromGUID`) after they're gone. |
| `M.cvars[name] = { value, default, help, category, ... }` | CVars the client knows (also `secure`, `readOnly`, `account`, `character`, `max`, and `unlisted` to leave one out of `ConsoleGetAllCommands`). |
| `M.script(frame, name, ...)`, `button:Click([mouseButton])` | Run a frame's script and its hooks (`OnEnterPressed`, `OnDragStop`, ...); click a button (default `"LeftButton"`) unless it's disabled. A scroll box gets a row in `.rows` for every element. |
| `M.bags["bag:slot"]`, `M.bagSlots[bag]`, `M.items[itemID]` | Bag contents (an item link, or `{ link, count, locked }`), bag sizes (default: a 16-slot backpack) and what the client knows of an item (`quality`, `price`, `icon`, `noValue`, `uncached`). |
| `M.equipped[slot]`, `M.accountBank` | Worn item links by inventory slot; whether the account bank can be seen. Bank tabs are bags 6 and up (account bank 15 and up) in `M.bags`. |
| `M.inbox`, `M.sendItems`, `M.sentMail` | Inbox mails `{ cod, items = { { link, count, currency } } }`, attachments of the mail being written, and what `SendMail` sent. |
| `M.ownedAuctions`, `M.ownedQueries` | What `C_AuctionHouse.GetOwnedAuctions` returns, and how often owned auctions were queried. |
| `M.cursorItem` | The `"bag:slot"` whose item is on the cursor (`C_Container.PickupContainerItem`, `DeleteCursorItem`). |
| `M.combat` | In combat (`InCombatLockdown`). |
| `M.sent`, `M.sendResult`, `M.addonMessage(sender, prefix, text)` | Addon messages sent (`{ prefix, text, chatType, target }`), a function returning another `Enum.SendAddonMessageResult` (throttled, offline), and a whisper arriving from another player. |
| `M.chat(event, text)` | Send a chat event; returns whether the chat frame would show it after addons' filters. |
| `M.cursor` | Cursor position in screen coordinates (`GetCursorPosition`); `Minimap` is 140 wide with its center at (1800, 900). |
| `M.minimapRadius`, `M.facing`, `M.world[mapID]` | Yards the minimap shows from its center, your facing in radians, and where maps lie in the world (`{ continent, left, top, width, height }` in yards). |
| `M.merchantItems`, `M.merchantFilter`, `M.canRepair` | The open vendor's items (`C_MerchantFrame.GetItemInfo` fields plus `link`), its filter (`LE_LOOT_FILTER_ALL` when nil) and whether it repairs. |
| `M.secrets[value] = true` | Make a value secret, as the Midnight-era client does in dungeons. |
| `M.installed`, `M.disabled` | Addon folders the client knows (default TravelLog, TravelLog_Path, TravelLog_Nodes) and which are off. |
| `M.viewMap`, `M.mapOverlay(level)`, `M.shown(pool)` | The shown world map, an addon's overlay on it (newest, or by frame level: Path 2010, Kills 2011, Nodes 2012), and its visible lines, textures and frames. |
| `M.out`, `M.errors` | Everything printed to chat, and Lua errors sent to `geterrorhandler` (they count as failures). |
| `M.saved`, `M.savedSize(addon, perCharacter)` | The saved files' text and size. |

When an addon needs an API or event the fake lacks, add it to `wowmock.lua`.

## What the fake can't tell you

A passing test only means the addon works **if** the real client behaves like `wowmock.lua`. Check new APIs against Blizzard's Forever UI code, as described in [`.claude/skills/addon-tests/SKILL.md`](../.claude/skills/addon-tests/SKILL.md).
