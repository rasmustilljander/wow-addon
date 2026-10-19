# TravelLog

Records your travels in WoW: Forever so you can retrace them later. It draws your trail on the world map, along with every chest, herb and ore you've looted and when you last looted it.

Install the `TravelLog_Archive` folder along with it (see [Where the data is](#where-the-data-is)).

## What it records

Every log entry is stamped with the character, time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Path** | Your position every 2 seconds while you move (1–5 s, see `/tl interval`), with map coordinates, world coordinates and how you were moving: on foot, mounted, on a flight, swimming or as a ghost. Nothing is recorded while you stand still. |
| **Jumps** | Every jump, with time, zone, subzone and coordinates. Totals per zone. |
| **Loot** | Every corpse, chest, herb, ore vein, fishing catch or container you loot: what you took, the coins, and the source. The source is a name and NPC/object ID, plus the spell that opened it for herbs, ore, chests and skinning. |
| **Chests and nodes** | Every chest, herb and ore spot you've looted, remembered by place: when you last looted it, how many times, and the five most recent times. |
| **Other items** | Quest rewards, crafted items, won rolls (with your roll) and other pickups that arrive without a loot window. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every change to your gold with a reason: loot, vendor, flight, quest, training, mail, trade, auction or other. |
| **Travel** | Zone and subzone changes (first visits are marked), flights (from, to, cost, how long), hearthstone uses, where you set your hearthstone, and distance travelled per movement type. |
| **Life** | Deaths (and what you were fighting), releasing your spirit and coming back to life, level-ups, quests accepted and completed, kills that gave XP, and newly discovered places. |

## Commands

| Command | |
| --- | --- |
| `/tl` or `/tl stats` | Totals for this character |
| `/tl jumps` | Jumps per zone |
| `/tl log [n]` | The last n recorded events (default 15) |
| `/tl trail session\|today\|week\|all\|off` | How far back the world map trail goes (default `today`). `all` also reads the archives. |
| `/tl nodes on\|off` | Show looted chests, herbs and ore on the world map (default on) |
| `/tl interval 1-5` | Seconds between path points while moving (default 2) |
| `/tl archive [now]` | Where older history is kept. `now` archives it right away. |
| `/tl wipe confirm` | Delete everything recorded for this character, archives included |

`/travellog` works too.

## World map

Open the world map to see where you've been, on zone maps and continent maps. The trail breaks at teleports (hearthstone, portals, releasing to a graveyard).

| Trail color | | Marker | |
| --- | --- | --- | --- |
| yellow | on foot | small white dot | jump |
| orange | mounted | purple dot | loot |
| light blue | flight path | red dot | death |
| blue | swimming | green dot | level-up |
| grey | ghost | | |

On zone maps, square pins mark the chests and gathering nodes you've looted: green for herbs, orange for ore, gold for chests and grey for other objects. Hover a pin to see when you last looted it, how long ago that was, how many times you've looted it and the times before. `/tl log` shows the same thing for each loot, e.g. `Looted [Peacebloom]x2 from Peacebloom (looted here 30m before)`.

## Where the data is

WoW gives each addon one file per account plus one per character, and only writes them when you log out or `/reload`. If the game crashes, everything since the last reload is lost, so `/reload` now and then on long sessions.

| File | What's in it |
| --- | --- |
| `WTF/Account/<ACCOUNT>/SavedVariables/TravelLog.lua` | Settings, and each character's profile and totals. Small. |
| `WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's history: log, path, jumps, quests, chests and nodes. Loaded only when you play that character. |
| `WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Archive.lua` | Older history, all characters. Loaded only when needed. |

Recording grows a character's file by roughly 100 KB per hour of non-stop movement. To keep it small, history is **rotated**: when the file passes about 3 MB, the next login moves everything older than 10 days into the archive (chests, nodes and totals stay). The archive is its own addon, because WoW gives each addon one account-wide file, and it loads on demand: it isn't read at login, only for `/tl trail all`, `/tl archive now` and the next rotation. `/tl archive` shows how big it has grown without loading it.

The archive file keeps growing, but since it's left alone at a normal login, its size doesn't slow anything down until you look at all of your history. If the archive folder isn't installed, nothing is lost: history just stays in the character file, and TravelLog tells you at login.

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
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, track = { "..." }, jumps = { "..." } },
  },
  nodes = {   -- per uiMapID
    [1429] = { { kind = "herb", name = "Peacebloom", x = 42.1, y = 65.3, last = 1760000000,
                 count = 8, times = { 1760000000, 1759998200, ... } } },
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ... } },
}
```

The archive holds `TravelLogArchiveDB = { chars = { ["Name-Realm"] = { sessions = { ... }, log = { ... } } } }`.

Log entry types: `area`, `loot`, `receive`, `buy`, `sell`, `buyback`, `repair`, `money`, `flight`, `landed`, `hearth`, `bind`, `death`, `release`, `revive`, `level`, `quest`, `questdone`, `kill`, `discover`.

`track` (path) and `jumps` are packed to keep the file small: each string holds up to 200 records separated by `;`, and each record is

```
seconds into session, uiMapID, x, y, instanceID, world 1, world 2, flags
```

- `x`, `y`: map coordinates 0–100, like the ones you see in game.
- `instanceID`, `world 1`, `world 2`: continent and the two values `UnitPosition("player")` returns, in yards. Handy for drawing one continuous path across zones.
- `flags`: 1 mounted, 2 on a flight, 4 swimming, 8 dead or ghost, 16 in combat, 32 indoors (added together).
- Jump records add `,zone,subzone` at the end.

Fields the game doesn't reveal (coordinates inside dungeons) are left empty.

## Limits

Loot windows:

- An item counts as yours when the game reports its slot as emptied. Items you leave behind (full bags, or you just close the window) aren't recorded.
- If someone else loots the same corpse while you have it open (free-for-all loot), their pick can be counted as yours.
- Items you win by rolling arrive later, outside the loot window, and are recorded as received items, with your roll.
- A loot window that combines several corpses is credited to the first one.
- Chests and herbs are named by the spell that opened them. An object that opens without a cast (some quest crates) is recorded with its object ID but no name.
- Inside dungeons there are no coordinates, so chests looted there aren't remembered on the map. The loot itself is still recorded.

Everything else:

- The game doesn't give addons your position inside dungeons and raids, so there's no path in there. Jumps and loot are still recorded, without coordinates.
- Forever runs on the Midnight-era client, which hides some data from addons inside instances. Things read from chat (crafted items, quest rewards, kills, discoveries) may be missing there. Loot windows and roll wins still work.
- Kills are only counted when they give XP, since addons can't read the combat log on this client.
- Sales are read from the buyback list. If one click sells more than 12 items (Sell All Junk), only the last 12 may show up individually. The money ledger total is always right.
- Not yet tested in the live game. It's written against the Forever 1.60.1 UI source and tested against a fake client (see [tests](../tests/README.md)). If something misbehaves, the Lua error (enable them with `/console scriptErrors 1`) is the most useful thing to look at.
