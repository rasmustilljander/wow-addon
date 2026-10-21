# TravelLog Path

Records the path you walk, ride, swim and fly in WoW: Forever, and every jump, and draws the trail on the world map. Needs [TravelLog](../TravelLog/).

## What it records

| | |
| --- | --- |
| **Path** | Your position every 2 seconds while moving (see `/tl interval`), with map and world coordinates and how you moved: on foot, mounted, flying, swimming or as a ghost. Nothing while standing still. |
| **Jumps** | Every jump with time, zone, subzone and coordinates, and totals per zone. |
| **Distance** | How far you've travelled by each of the ways above. |

## Commands

| Command | |
| --- | --- |
| `/tl jumps` | Jumps per zone |
| `/tl trail session\|today\|week\|all\|off` | How far back the map trail goes (default `today`). `all` reads the archive too. |
| `/tl interval 1-5` | Seconds between path points (default 2) |

`/tl stats` adds jumps, distance and stored path points. The [TravelLog window](../TravelLog/README.md#window) shows jumps and distance and has buttons for the trail and interval.

## World map

Zone and continent maps show your trail, broken at teleports (hearthstone, portals, graveyard), with markers for jumps and for TravelLog's loot, deaths and level-ups.

| Trail | | Marker | |
| --- | --- | --- | --- |
| yellow | on foot | small white dot | jump |
| orange | mounted | purple dot | loot |
| light blue | flight path | red dot | death |
| blue | swimming | green dot | level-up |
| grey | ghost | | |

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Path.lua`, about 100 KB per hour of movement. Sessions older than 10 days rotate into `TravelLog_Archive` with TravelLog's history ([details](../TravelLog/README.md#where-the-data-is)). Path data TravelLog kept before this addon existed moves here at the first login.

```lua
TravelLogPathDB = {
  sessions = {   -- one per login or reload, oldest first
    { start = 1760000000, stop = 1760007200, jumpCount = 12, track = { "..." }, jumps = { "..." } },
  },
}
```

`start` matches the TravelLog session's. Each string in `track` and `jumps` packs up to 200 records separated by `;`, each record being

```
seconds into session, uiMapID, x, y, instanceID, world 1, world 2, flags
```

- `x`, `y`: map coordinates 0–100, as shown in game.
- `instanceID`, `world 1`, `world 2`: continent and `UnitPosition("player")` in yards, continuous across zones.
- `flags`: sum of 1 mounted, 2 flight, 4 swimming, 8 dead or ghost, 16 in combat, 32 indoors.
- Jump records end with `,zone,subzone`.
- Values the game doesn't reveal (coordinates in dungeons) are empty.

## Limits

- No path in dungeons and raids, since addons get no position there. Jumps are still recorded, without coordinates.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
