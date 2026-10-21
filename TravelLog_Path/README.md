# TravelLog Path

Records the path you walk, ride, swim and fly in WoW: Forever, and every jump, and draws the trail on the world map, along with your alts' trails if you want them. Needs [TravelLog](../TravelLog/).

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
| `/tl trail <range>` | How far back your map trail goes (default `today`) |
| `/tl trail alts <range>` | The same for alts' trails (default `off`) |
| `/tl interval 1-5` | Seconds between path points (default 2) |

| Range | Shows |
| --- | --- |
| `session` | The latest session: your current one, an alt's last one |
| `today` | Since midnight |
| `week` | The last 7 days |
| `6h`, `3d` | The last 6 hours, 3 days, or any number of hours (`h`) or days (`d`) |
| `yesterday`, `2025-10-19` | That calendar day only. `yesterday` is saved as its date. |
| `all` | Everything, the archive included |
| `off` | Nothing |

`/tl stats` adds jumps, distance and, for the character you're on, this session's jumps and stored path points. The [TravelLog window](../TravelLog/README.md#window) shows jumps and distance. Its settings have buttons for your trail and the alts' trail (`session`, `today`, `24h`, `week`, `all`, `off`), each with `<` and `>` below to step one calendar day back or forward, a checkbox per alt with a recorded path to hide or show its trail, and buttons for the interval.

## World map

Zone and continent maps show your trail, broken at teleports (hearthstone, portals, graveyard), with markers for jumps and for TravelLog's loot, deaths, level-ups and other milestones. Hover a death marker to see its date and what you were fighting. Alts' trails are thinner lines in the alt's class color, drawn under yours, without markers.

The colors below are the defaults. To change one, click its swatch in the TravelLog window's **Colors** tab and pick a color and opacity; the map follows as you drag. **Default** puts one back, **All defaults** all of them. They're saved in TravelLog's settings as `trailColors` and `markerColors`, `{ r, g, b, a }` by kind.

| Trail | | Marker | |
| --- | --- | --- | --- |
| yellow | on foot | small white dot | jump |
| orange | mounted | purple dot | loot |
| light blue | flight path | red dot | death |
| blue | swimming | green dot | level-up |
| grey | ghost | pink dot | spell or skill learned, skill milestone |
| | | teal dot | flight path found |
| | | brown dot | reputation standing |
| | | large white dot | first ride on a mount |

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Path.lua`, every character's path, about 100 KB per hour of movement. It's account-wide so alts can see each other's trails. Sessions older than 10 days rotate into `TravelLog_Archive` with TravelLog's history ([details](../TravelLog/README.md#where-the-data-is)).

Before 0.2 each character's path was in `<Realm>/<Character>/SavedVariables/TravelLog_Path.lua`. It moves to the account-wide file at that character's first login with 0.2, so an alt's trail appears once you've logged in on it. Path data TravelLog kept before this addon existed moves too.

```lua
TravelLogPathAccountDB = {
  chars = {
    ["Name-Realm"] = {
      sessions = {   -- one per login or reload, oldest first
        { start = 1760000000, stop = 1760007200, jumpCount = 12, track = { "..." }, jumps = { "..." } },
      },
    },
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
- Every login loads all characters' paths. An alt's old sessions rotate into the archive only when that alt logs in, so an alt you no longer play keeps its last 10 days or more in the file. `/tl wipe confirm` on that alt removes them.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
