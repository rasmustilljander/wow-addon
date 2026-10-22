# TravelLog

Records your travels in WoW: Forever so you can retrace them: loot, vendor trades, money, flights, deaths, quests and more.

Optional companions, each its own folder:

- [TravelLog_Path](../TravelLog_Path/): your path and jumps, drawn on the world map. Needs TravelLog.
- [TravelLog_Nodes](../TravelLog_Nodes/): looted chests, herbs and ore, pinned on the minimap and world map. Needs TravelLog.
- `TravelLog_Archive`: storage for older history (see [Where the data is](#where-the-data-is)). Install it with TravelLog.
- [TravelLog_Kills](../TravelLog_Kills/): every kill per mob. Works on its own too.
- [TravelLog_NPCs](../TravelLog_NPCs/): NPCs you've talked to and what they sell, on the maps and item tooltips. Works on its own too.
- [TravelLog_Group](../TravelLog_Group/): every player you group with, and when. Works on its own too.
- [TravelLog_Share](../TravelLog_Share/): your nodes, and on request your log, for players you allow. Needs TravelLog.

## What it records

Every entry is stamped with character, time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Loot** | Corpses, pickpockets, chests, herbs, ore, fishing and containers: items taken, coins and source (name, NPC/object ID, and the spell for herbs, ore, chests, skinning and Pick Pocket). |
| **Other items** | Quest rewards, crafts, roll wins (with your roll), trades and mail, and other items that arrive without a loot window. |
| **Items out** | Items you hand over in a trade, mail, put up for auction (with bid and buyout) or destroy. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every gold change with a reason: loot, vendor, flight, quest, training, mail, COD, trade, auction (buys, and sales paid by mail with the item), auction deposit, bank slot, account bank, guild bank, barber, talent reset, stable slot or other. A bank slot also gets its own entry. |
| **Trades and mail** | Money and items from a trade, both ways, are saved with the other player (`partner`, as `Name-Realm` for another realm); from mail, with the mail's sender (`sender`); mail you send and its postage, with the recipient (`recipient`). |
| **Travel** | Zone and subzone changes (first visits marked), flights (from, to, cost, duration), hearthstones and other teleports (from, to and the spell or item), summons (from, to and who), boat and zeppelin rides (from, to, duration), dungeons and raids (name, type, difficulty, and time inside when you leave), hearthstone binds. |
| **Life** | Deaths (and what you fought), spirit releases, revivals, level-ups (with how long the level took), quests accepted, completed and abandoned, kills that gave XP, discoveries. |
| **Sessions** | Each login or reload: start, end, level, money and the experience gained. |
| **Progress** | Spells, abilities and recipes learned (with rank, trainer and cost), new skills, every 25 points of a skill, flight paths found, reputation standings reached, the first ride on each mount. |

## Window

Pick TravelLog from the addons dropdown on the minimap, or type `/tl`, for a window with these tabs:

- **Totals**: numbers under Travel, Loot (money in and out by reason, largest first), Life (time played too) and Log. **Character**'s `<` and `>` step from the character you're on through your other characters to all of them added up (a place several visited counts once). Rows only the character you're on has (time played, log entries, and the Kills and Group rows) show for that character.
- **Settings**: the companions' map options and Path's interval.
- **History**: what's still in the character file, newest first, in views:
  - **Events**: every event. Filter by Travel, Loot, Trade, Life or Progress, or search event types, descriptions, names, places, dates and saved fields. Search `death` to list deaths with their level, fight target and location, or `level` for each level-up and how long it took.
  - **Sessions**: each session's length, levels, money and experience gained (per hour once it's 10 minutes long), and its quests, XP kills and deaths.
  - **Kills**, with [TravelLog_Kills](../TravelLog_Kills/README.md#window): every mob you've killed and where.
- **NPCs**, with [TravelLog_NPCs](../TravelLog_NPCs/README.md#window): search NPCs by name, place or what they sell.
- **Players**, with [TravelLog_Group](../TravelLog_Group/README.md#window): everyone you've grouped with and each time.
- **Colors**, with [TravelLog_Path](../TravelLog_Path/README.md#world-map): the trail's and markers' colors on the world map.
- **Sharing**, with [TravelLog_Share](../TravelLog_Share/README.md#the-sharing-tab): who you share with and follow, and their logs.

Companions add their rows to the matching section.

## Commands

| Command | |
| --- | --- |
| `/tl` | Open or close the window |
| `/tl stats [all\|name]` | Totals (and time played) for this character, all of them added up, or another by `Name` or `Name-Realm` |
| `/tl log [n] [search]` | The last matching events (default 15); for example, `/tl log 20 death` |
| `/tl sessions [n]` | The last n sessions (default 10), as in the Sessions view |
| `/tl archive [now]` | Archive size; `now` archives old history right away |
| `/tl wipe confirm` | Delete everything for this character, including its archive and its Path, Nodes and Share data. Kills and Group have their own `wipe confirm`. |

`/travellog` works too. TravelLog_Path adds `/tl jumps`, `/tl trail` and `/tl interval`, TravelLog_Nodes adds `/tl nodes`, and both add lines to `/tl stats`. TravelLog_Share adds `/tl share`, which opens its tab.

## Where the data is

WoW writes SavedVariables only on logout or `/reload`, so a crash loses everything since the last one. `/reload` now and then on long sessions.

| File under `WTF/Account/<ACCOUNT>/` | Contents |
| --- | --- |
| `SavedVariables/TravelLog.lua` | Settings (the companions' too, and the window's `point`), each character's profile and totals |
| `<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's log, sessions, quests, skills, mounts and the instance you're in |
| `SavedVariables/TravelLog_Path.lua` | Every character's path, for TravelLog_Path |
| `SavedVariables/TravelLog_Nodes.lua` | Every character's nodes, for TravelLog_Nodes |
| `SavedVariables/TravelLog_Archive.lua` | Older history of all characters |

**Rotation.** The path grows about 100 KB per hour of movement. When a character's log, sessions and path pass about 3 MB, the next login moves everything older than 10 days into the archive (nodes and totals stay). The archive is a separate load-on-demand addon because each addon gets only one account-wide file. It's read only for the `all` trail range, `/tl archive now` and rotation, so its size doesn't slow down logins. Without it installed, history stays in the character files and TravelLog says so when it tries to rotate.

Before 0.3, the path and nodes lived in TravelLog's character file. The first login with TravelLog_Path or TravelLog_Nodes installed moves them into that addon's file.

The character file:

```lua
TravelLogCharDB = {
  log = {   -- oldest first
    { type = "loot", time = 1760000000, zone = "Elwynn Forest", subzone = "Goldshire",
      map = 1429, x = 42.1, y = 65.3, source = "Peacebloom", sourceType = "GameObject",
      sourceID = 1618, via = "Herb Gathering", lastHere = 1759998200,
      items = { { item = "|cffffffff|Hitem:2447:...|h[Peacebloom]|h|r", count = 2 } } },
    ...
  },
  sessions = {   -- one per login or reload
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, money = 10000, moneyEnd = 12500, xp = 5600 },
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ..., abandoned = ... } },  -- last time of each
  skills = { [129] = 75 },           -- skill ID -> rank, to tell new skills and milestones
  mounts = { [458] = 1760000000 },   -- mount spell ID -> first ride
  instance = { name = "The Deadmines", kind = "dungeon", id = 36, inside = 600, since = ... },  -- while you're in one
}
```

Log entry types: `area`, `loot`, `receive`, `buy`, `sell`, `buyback`, `repair`, `give` (trade), `send` (mail), `post` (auction), `destroy`, `money`, `bankslot`, `flight`, `landed`, `hearth`, `teleport`, `summon`, `board`, `disembark`, `instance`, `instanceleave`, `bind`, `death`, `release`, `revive`, `level`, `quest`, `questdone`, `questabandon`, `kill`, `discover`, `spell`, `skill`, `skillup`, `taxipath`, `standing`, `mount`. Fields the game doesn't reveal (coordinates in dungeons) are left empty. A `level` entry also has `played`, the seconds played in all, and `took`, the seconds played at the level before.

A `money` entry has `amount` (negative when spent), `reason` (`loot`, `vendor`, `flight`, `quest`, `training`, `mail`, `cod`, `trade`, `auction`, `deposit`, `bankslot`, `bank`, `guildbank`, `barber`, `respec`, `stable` or `other`) and `balance`, plus `partner`, `sender` or `recipient` for trades and mail and `item` for an auction sale. A `bankslot` entry has `bank` (`character` or `account`), `slot` (its number in that bank) and `price`.

Travel entries' own fields:

| Type | Fields |
| --- | --- |
| `hearth`, `teleport` | `from`, `to` (place names); `spell` and `via` (its name) when your cast did it |
| `summon` | `from`, `to`, `by` (the summoner) |
| `board` | none: it's stamped where the ride started |
| `disembark` | `from`, `to`, `seconds` on board |
| `instance` | `name`, `kind` (`dungeon`, `raid`, `battleground`, `arena` or `scenario`), `difficulty`, `size`, `id` |
| `instanceleave` | `name`, `kind`, `seconds` inside |

The archive is `TravelLogArchiveDB = { chars = { ["Name-Realm"] = { sessions = {...}, log = {...}, path = {...} } } }`. `path` holds TravelLog_Path's sessions; sessions archived before TravelLog_Path existed carry `track` and `jumps` themselves, and TravelLog_Path reads both.

## Limits

- Only items whose loot slot empties are recorded, so items left behind aren't. With free-for-all loot, another player's pick from a window you have open can count as yours.
- A loot window combining several corpses is credited to the first one.
- Objects are named from the cast that opened them. One that opens without a cast (some quest crates) gets its object ID but no name.
- Addons get no coordinates in dungeons and raids. The Midnight-era client also hides some chat there, so crafted items, quest rewards, kills, discoveries and reputation standings may be missing. Loot windows and roll wins still work.
- Time played comes from `/played`, which TravelLog asks for at each login and keeps out of chat. A `/played` you type before that answer arrives (usually within a second of login) doesn't show, and a level-up before the answer arrives gets no times.
- Teleports are found by a jump in your position: more than 100 yards beyond what you could have walked or ridden since the last look a second before. A cast in the 5 seconds before is named as the cause, and one that lands you where your hearthstone is set counts as a hearth. A jump without a cast of yours (another mage's portal, an NPC that sends you somewhere) is a teleport with no spell, since the client doesn't say whose portal it was.
- The Hearthstone always counts, even next to the inn. Other teleports shorter than 100 yards, teleports inside dungeons (no positions there), and teleports out of a dungeon that don't land at your hearthstone are missed: leaving a dungeon is logged either way.
- The client doesn't report boats and zeppelins. A ride is when you're carried at least 4 yards a second faster than your own speed for 5 seconds, so it can't tell a boat from a zeppelin, and it ends after 10 seconds on your own feet.
- Summons are logged once you accept and arrive. The summoner's name is missing if the client hides it.
- Time in a dungeon or raid counts only while you're logged in, and a reload inside is the same visit.
- Mounts count from when TravelLog was installed, so "First mount" is only your real first if you hadn't ridden before.
- Kills count only when they give XP, since this client has no combat log for addons. [TravelLog_Kills](../TravelLog_Kills/) records every kill.
- Items used up (potions, food, reagents) aren't recorded: no event says an item was consumed.
- Mailed items are saved by item ID, so their link has no random enchantment ("of the Bear").
- Destroyed items are recorded only when picked up from your bags or gear first, so a gamepad delete isn't.
- Money reasons are guesses from the window that's open and what you clicked in the few seconds before. A bank slot that costs nothing logs no entry.
- Sales are read from the 12-slot buyback list, so selling more than 12 items in one click (Sell All Junk) may not list each one. The money total is always right.
- Untested in the live game; written against the Forever 1.60.1 UI source and tested against a fake client ([tests](../tests/README.md)). If something breaks, turn on Lua errors with `/console scriptErrors 1`.
