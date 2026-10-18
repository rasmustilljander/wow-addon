# TravelLog

Records your travels in WoW: Forever so you can retrace them later, and draws your trail on the world map.

## What it records

Every log entry is stamped with the character, time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Path** | Your position every 2 seconds while you move (1–5 s, see `/tl interval`), with map coordinates, world coordinates and how you were moving: on foot, mounted, on a flight, swimming or as a ghost. Nothing is recorded while you stand still. |
| **Jumps** | Every jump, with time, zone, subzone and coordinates. Totals per zone. |
| **Loot** | Every corpse, chest, herb, ore vein, fishing catch or container you loot: what you took, the coins, and the source (name, NPC/object ID, and the gathering spell for herbs/ore/chests). Items you left behind aren't counted. |
| **Other items** | Quest rewards, crafted items, won rolls and other pickups that arrive without a loot window. |
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
| `/tl trail session\|today\|week\|all\|off` | How far back the world map trail goes (default `today`) |
| `/tl interval 1-5` | Seconds between path points while moving (default 2) |
| `/tl wipe confirm` | Delete everything recorded for this character |

`/travellog` works too.

## World map trail

Open the world map to see where you've been, on zone maps and continent maps. The trail breaks at teleports (hearthstone, portals, releasing to a graveyard).

| Trail color | | Marker | |
| --- | --- | --- | --- |
| yellow | on foot | small white dot | jump |
| orange | mounted | purple dot | loot |
| light blue | flight path | red dot | death |
| blue | swimming | green dot | level-up |
| grey | ghost | | |

## Where the data is

Everything is saved account-wide (all characters in one file) in

```
WTF/Account/<ACCOUNT>/SavedVariables/TravelLog.lua
```

WoW writes that file when you log out or `/reload`. If the game crashes, everything since the last reload is lost, so `/reload` now and then on long sessions. It grows by roughly 100 KB per hour of non-stop movement.

```lua
TravelLogDB = {
  settings = { interval = 2, trail = "today" },
  chars = {
    ["Name-Realm"] = {
      stats = { jumps = 1234, jumpsByZone = { ... }, distance = { foot = ..., mount = ... }, ... },
      log = {   -- oldest first
        { type = "loot", time = 1760000000, zone = "Elwynn Forest", subzone = "Goldshire",
          map = 1429, x = 42.1, y = 65.3, source = "Kobold Vermin", sourceType = "Creature",
          sourceID = 6, items = { { item = "|cffffffff|Hitem:2589:...|h[Linen Cloth]|h|r", count = 2 } },
          money = 12 },
        ...
      },
      sessions = {   -- one per login or reload
        { start = 1760000000, stop = 1760007200, level = 12, track = { "..." }, jumps = { "..." } },
      },
      quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ... } },
    },
  },
}
```

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

- The game doesn't give addons your position inside dungeons and raids, so there's no path in there. Jumps and loot are still recorded, without coordinates.
- Forever runs on the Midnight-era client, which hides some data from addons inside instances. Things read from chat (items received without a loot window, kills, discoveries) may be missing there; loot windows still work.
- Kills are only counted when they give XP, since addons can't read the combat log on this client.
- Sales are read from the buyback list. If one click sells more than 12 items (Sell All Junk), only the last 12 may show up individually. The money ledger total is always right.
- Not yet tested in the live game. It's written against the Forever 1.60.1 UI source, so if something misbehaves, the Lua error (enable them with `/console scriptErrors 1`) is the most useful thing to look at.
