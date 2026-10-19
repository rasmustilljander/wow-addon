# TravelLog

Records your travels in WoW: Forever so you can retrace them: loot, vendor trades, money, flights, deaths, quests and more.

Optional companions, each its own folder:

- [TravelLog_Path](../TravelLog_Path/): your path and jumps, drawn on the world map. Needs TravelLog.
- [TravelLog_Nodes](../TravelLog_Nodes/): looted chests, herbs and ore, pinned on the world map. Needs TravelLog.
- `TravelLog_Archive`: storage for older history (see [Where the data is](#where-the-data-is)). Install it with TravelLog.
- [TravelLog_Kills](../TravelLog_Kills/): every kill per mob. Works on its own too.

## What it records

Every entry is stamped with character, time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Loot** | Corpses, chests, herbs, ore, fishing and containers: items taken, coins and source (name, NPC/object ID, and the opening spell for herbs, ore, chests and skinning). |
| **Other items** | Quest rewards, crafts, roll wins (with your roll) and other items that arrive without a loot window. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every gold change with a reason: loot, vendor, flight, quest, training, mail, trade, auction or other. |
| **Travel** | Zone and subzone changes (first visits marked), flights (from, to, cost, duration), hearthstone uses and binds. |
| **Life** | Deaths (and what you fought), spirit releases, revivals, level-ups, quests accepted and completed, kills that gave XP, discoveries. |

## Commands

| Command | |
| --- | --- |
| `/tl` or `/tl stats` | Totals for this character |
| `/tl log [n]` | The last n events (default 15) |
| `/tl archive [now]` | Archive size; `now` archives old history right away |
| `/tl wipe confirm` | Delete everything for this character, including its archive and the companions' files |

`/travellog` works too. TravelLog_Path adds `/tl jumps`, `/tl trail` and `/tl interval`, TravelLog_Nodes adds `/tl nodes`, and both add lines to `/tl stats`.

## Where the data is

WoW writes SavedVariables only on logout or `/reload`, so a crash loses everything since the last one. `/reload` now and then on long sessions.

| File under `WTF/Account/<ACCOUNT>/` | Contents |
| --- | --- |
| `SavedVariables/TravelLog.lua` | Settings (the companions' too), each character's profile and totals |
| `<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's log, sessions and quests |
| `<Realm>/<Character>/SavedVariables/TravelLog_Path.lua`, `TravelLog_Nodes.lua` | The companions' data for that character |
| `SavedVariables/TravelLog_Archive.lua` | Older history of all characters |

**Rotation.** The path grows about 100 KB per hour of movement. When a character's log, sessions and path pass about 3 MB, the next login moves everything older than 10 days into the archive (nodes and totals stay). The archive is a separate load-on-demand addon because each addon gets only one account-wide file. It's read only for `/tl trail all`, `/tl archive now` and rotation, so its size doesn't slow down logins. Without it installed, history stays in the character files and TravelLog says so when it tries to rotate.

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
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, money = 10000, moneyEnd = 12500 },
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ... } },
}
```

Log entry types: `area`, `loot`, `receive`, `buy`, `sell`, `buyback`, `repair`, `money`, `flight`, `landed`, `hearth`, `bind`, `death`, `release`, `revive`, `level`, `quest`, `questdone`, `kill`, `discover`. Fields the game doesn't reveal (coordinates in dungeons) are left empty.

The archive is `TravelLogArchiveDB = { chars = { ["Name-Realm"] = { sessions = {...}, log = {...}, path = {...} } } }`. `path` holds TravelLog_Path's sessions; sessions archived before TravelLog_Path existed carry `track` and `jumps` themselves, and TravelLog_Path reads both.

## Limits

- Only items whose loot slot empties are recorded, so items left behind aren't. With free-for-all loot, another player's pick from a window you have open can count as yours.
- A loot window combining several corpses is credited to the first one.
- Objects are named from the cast that opened them. One that opens without a cast (some quest crates) gets its object ID but no name.
- Addons get no coordinates in dungeons and raids. The Midnight-era client also hides some chat there, so crafted items, quest rewards, kills and discoveries may be missing. Loot windows and roll wins still work.
- Kills count only when they give XP, since this client has no combat log for addons. [TravelLog_Kills](../TravelLog_Kills/) records every kill.
- Sales are read from the 12-slot buyback list, so selling more than 12 items in one click (Sell All Junk) may not list each one. The money total is always right.
- Untested in the live game; written against the Forever 1.60.1 UI source and tested against a fake client ([tests](../tests/README.md)). If something breaks, turn on Lua errors with `/console scriptErrors 1`.
