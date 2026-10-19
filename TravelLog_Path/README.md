# TravelLog Path

Records the path you walk, ride, swim and fly in WoW: Forever, and every jump, and draws it as a trail on the world map. Part of [TravelLog](../TravelLog/), which it needs.

## What it records

| | |
| --- | --- |
| **Path** | Your position every 2 seconds while you move (1–5 s, see `/tl interval`), with map coordinates, world coordinates and how you were moving: on foot, mounted, on a flight, swimming or as a ghost. Nothing is recorded while you stand still. |
| **Jumps** | Every jump, with time, zone, subzone and coordinates. Totals per zone. |
| **Distance** | How far you've travelled on foot, mounted, on flights, swimming and as a ghost. |

## Commands

| Command | |
| --- | --- |
| `/tl jumps` | Jumps per zone |
| `/tl trail session\|today\|week\|all\|off` | How far back the world map trail goes (default `today`). `all` also reads the archive. |
| `/tl interval 1-5` | Seconds between path points while moving (default 2) |

`/tl stats` shows jumps, distance and how many path points are stored.

## World map

Open the world map to see where you've been, on zone maps and continent maps. The trail breaks at teleports (hearthstone, portals, releasing to a graveyard). TravelLog's loot, deaths and level-ups are marked on it too.

| Trail color | | Marker | |
| --- | --- | --- | --- |
| yellow | on foot | small white dot | jump |
| orange | mounted | purple dot | loot |
| light blue | flight path | red dot | death |
| blue | swimming | green dot | level-up |
| grey | ghost | | |

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Path.lua`, one file per character, written when you log out or `/reload`. It grows by roughly 100 KB per hour of non-stop movement. Sessions older than 10 days move into `TravelLog_Archive` along with TravelLog's own history; see [TravelLog](../TravelLog/README.md#where-the-data-is).

```lua
TravelLogPathDB = {
  sessions = {   -- one per login or reload, oldest first
    { start = 1760000000, stop = 1760007200, jumpCount = 12, track = { "..." }, jumps = { "..." } },
  },
}
```

`start` is the same as the matching TravelLog session's. `track` (path) and `jumps` are packed to keep the file small: each string holds up to 200 records separated by `;`, and each record is

```
seconds into session, uiMapID, x, y, instanceID, world 1, world 2, flags
```

- `x`, `y`: map coordinates 0–100, like the ones you see in game.
- `instanceID`, `world 1`, `world 2`: continent and the two values `UnitPosition("player")` returns, in yards. Handy for drawing one continuous path across zones.
- `flags`: 1 mounted, 2 on a flight, 4 swimming, 8 dead or ghost, 16 in combat, 32 indoors (added together).
- Jump records add `,zone,subzone` at the end.

Fields the game doesn't reveal (coordinates inside dungeons) are left empty.

Before this addon existed, TravelLog kept the path inside its own sessions. The first login with TravelLog_Path installed moves it here.

## Limits

- The game doesn't give addons your position inside dungeons and raids, so there's no path in there. Jumps are still recorded, without coordinates.
- Not yet tested in the live game. It's tested against a fake client (see [tests](../tests/README.md)).
