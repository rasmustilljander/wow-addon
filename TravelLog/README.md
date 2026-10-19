# TravelLog

Records your travels in WoW: Forever so you can retrace them later: what you looted and bought, where your money went, flights, deaths, quests and more.

It comes in parts, each its own addon folder. Install the ones you want:

| Addon | |
| --- | --- |
| `TravelLog` | This one. Everything below. The others need it. |
| [TravelLog_Path](../TravelLog_Path/) | Your path and every jump, drawn as a trail on the world map. |
| [TravelLog_Nodes](../TravelLog_Nodes/) | Every chest, herb and ore spot you've looted, pinned on the world map with when you last looted it. |
| `TravelLog_Archive` | Storage for older history (see [Where the data is](#where-the-data-is)). Install it along with the others. |

[TravelLog_Kills](../TravelLog_Kills/) is a relative that works on its own.

## What it records

Every log entry is stamped with the character, time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Loot** | Every corpse, chest, herb, ore vein, fishing catch or container you loot: what you took, the coins, and the source. The source is a name and NPC/object ID, plus the spell that opened it for herbs, ore, chests and skinning. |
| **Other items** | Quest rewards, crafted items, won rolls (with your roll) and other pickups that arrive without a loot window. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every change to your gold with a reason: loot, vendor, flight, quest, training, mail, trade, auction or other. |
| **Travel** | Zone and subzone changes (first visits are marked), flights (from, to, cost, how long), hearthstone uses and where you set your hearthstone. |
| **Life** | Deaths (and what you were fighting), releasing your spirit and coming back to life, level-ups, quests accepted and completed, kills that gave XP, and newly discovered places. |

## Commands

| Command | |
| --- | --- |
| `/tl` or `/tl stats` | Totals for this character |
| `/tl log [n]` | The last n recorded events (default 15) |
| `/tl archive [now]` | Where older history is kept. `now` archives it right away. |
| `/tl wipe confirm` | Delete everything recorded for this character, archives and the other TravelLog addons' files included |

`/travellog` works too. TravelLog_Path adds `/tl jumps`, `/tl trail` and `/tl interval`, and TravelLog_Nodes adds `/tl nodes`. Both add their totals to `/tl stats`.

## Where the data is

WoW gives each addon one file per account plus one per character, and only writes them when you log out or `/reload`. If the game crashes, everything since the last reload is lost, so `/reload` now and then on long sessions.

| File | What's in it |
| --- | --- |
| `WTF/Account/<ACCOUNT>/SavedVariables/TravelLog.lua` | Settings (the other TravelLog addons' too), and each character's profile and totals. Small. |
| `WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's history: log, sessions and quests. Loaded only when you play that character. |
| `WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Path.lua` | That character's path and jumps (see [TravelLog_Path](../TravelLog_Path/)). |
| `WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Nodes.lua` | That character's chests and gathering nodes (see [TravelLog_Nodes](../TravelLog_Nodes/)). |
| `WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Archive.lua` | Older history, all characters. Loaded only when needed. |

The path is what grows: roughly 100 KB per hour of non-stop movement. To keep the character files small, history is **rotated**: when this character's log, sessions and path together pass about 3 MB, the next login moves everything older than 10 days into the archive (chests, nodes and totals stay). The archive is its own addon, because WoW gives each addon one account-wide file, and it loads on demand: it isn't read at login, only for `/tl trail all`, `/tl archive now` and the next rotation. `/tl archive` shows how big it has grown without loading it.

The archive file keeps growing, but since it's left alone at a normal login, its size doesn't slow anything down until you look at all of your history. If the archive folder isn't installed, nothing is lost: history just stays in the character files, and TravelLog tells you at login.

Before version 0.3 the path and the nodes were in TravelLog's own character file. The first login with TravelLog_Path or TravelLog_Nodes installed moves them into that addon's file. Until then they stay where they were.

What a character file holds:

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

The archive holds `TravelLogArchiveDB = { chars = { ["Name-Realm"] = { sessions = { ... }, log = { ... }, path = { ... } } } }`. `path` holds TravelLog_Path's sessions. Sessions archived before TravelLog_Path existed have their path inside them instead (`track` and `jumps`), and TravelLog_Path reads both.

Log entry types: `area`, `loot`, `receive`, `buy`, `sell`, `buyback`, `repair`, `money`, `flight`, `landed`, `hearth`, `bind`, `death`, `release`, `revive`, `level`, `quest`, `questdone`, `kill`, `discover`.

Fields the game doesn't reveal (coordinates inside dungeons) are left empty.

## Limits

Loot windows:

- An item counts as yours when the game reports its slot as emptied. Items you leave behind (full bags, or you just close the window) aren't recorded.
- If someone else loots the same corpse while you have it open (free-for-all loot), their pick can be counted as yours.
- Items you win by rolling arrive later, outside the loot window, and are recorded as received items, with your roll.
- A loot window that combines several corpses is credited to the first one.
- Chests and herbs are named by the spell that opened them. An object that opens without a cast (some quest crates) is recorded with its object ID but no name.

Everything else:

- The game doesn't give addons your position inside dungeons and raids, so loot and other events there have no coordinates.
- Forever runs on the Midnight-era client, which hides some data from addons inside instances. Things read from chat (crafted items, quest rewards, kills, discoveries) may be missing there. Loot windows and roll wins still work.
- Kills are only counted when they give XP, since addons can't read the combat log on this client. [TravelLog_Kills](../TravelLog_Kills/) records every kill per mob, XP or not.
- Sales are read from the buyback list. If one click sells more than 12 items (Sell All Junk), only the last 12 may show up individually. The money ledger total is always right.
- Not yet tested in the live game. It's written against the Forever 1.60.1 UI source and tested against a fake client (see [tests](../tests/README.md)). If something misbehaves, the Lua error (enable them with `/console scriptErrors 1`) is the most useful thing to look at.
