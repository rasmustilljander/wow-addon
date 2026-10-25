# TravelLog Path

Records the path you walk, ride, swim and fly in WoW: Forever, and every jump, and draws the trail on the world map, along with your alts' and [friends'](../TravelLog_Share/) trails if you want them. Needs [TravelLog](../TravelLog/).

## What it records

| | |
| --- | --- |
| **Path** | Your position every 2 seconds while moving (see `/tl interval`), with map and world coordinates and how you moved: on foot, mounted, flying, swimming or as a ghost. Nothing while standing still. |
| **Jumps** | Every jump with time, zone, subzone and coordinates, and totals per zone. |
| **Distance** | How far you've travelled by each of the ways above, and in each form (see [Distance by form](#distance-by-form)). |

## Commands

| Command | |
| --- | --- |
| `/tl jumps` | Jumps per zone |
| `/tl trail <range>` | How far back your map trail goes (default `today`) |
| `/tl trail alts <range>` | The same for alts' trails (default `off`) |
| `/tl trail friends <range>` | The same for friends' trails (default `today`) |
| `/tl fade` | How the trail fades (see [Fading](#fading)) |
| `/tl smooth 0-100` | How round the trail's turns are; 0 draws straight lines (default 50) |
| `/tl interval 1-5` | Seconds between path points (default 2) |

| Range | Shows |
| --- | --- |
| `session` | The latest session: your current one, an alt's last one |
| `today` | Since midnight |
| `week` | The last 7 days |
| `6h`, `3d` | The last 6 hours, 3 days, or any number of hours (`h`) or days (`d`) |
| `yesterday`, `2025-10-19` | That calendar day only. `yesterday` is saved as its date. |
| `all` | Everything stored |
| `off` | Nothing |

`/tl stats` adds jumps, distance (in yards and by form, if any) and, for the character you're on, this session's jumps and stored path points. The [TravelLog window](../TravelLog/README.md#window) shows jumps, distance and distance by form (in miles). Its settings have buttons for your trail, the alts' trail and, with TravelLog_Share, the friends' trail (`session`, `today`, `24h`, `week`, `all`, `off`), each with `<` and `>` below to step one calendar day back or forward, a checkbox per alt with a recorded path to hide or show its trail, and buttons for the fade (`off`, `1h`, `3h`, `6h`, `12h`), the curves (`0`, `25`, `50`, `75`, `100`) and the interval.

## Distance by form

Distance in a shapeshift form or in stealth is also counted in `stats.formDistance` (yards, in TravelLog's file), next to `stats.distance` by way of travel.

| Key | Form ID (`GetShapeshiftFormID()`) |
| --- | --- |
| `cat` | 1 |
| `bear` | 5 |
| `travel` | 3 |
| `aquatic` | 4 |
| `moonkin` | 31 or 35 |
| `ghostwolf` | 16 |
| `stealth` | `IsStealthed()`, any form |

- Stealth overlaps the rest: prowling counts as `cat` and `stealth`.
- Other forms (Tree of Life, Shadowform) are stored in the path's flags but not counted.
- Shifting changes the flags, which records a path point, so shifting often adds points.

## World map

Zone and continent maps show your trail, broken at teleports (hearthstone, portals, graveyard), with markers for jumps and for TravelLog's loot, deaths, level-ups, notes and other milestones. Hover a death or note marker for its date and entry: who or what killed you, or your note. Alts' and friends' trails are thinner lines in their class color, drawn under yours, without markers.

Trails curve through the recorded points (a centripetal Catmull-Rom spline) instead of turning sharply at each one. `/tl smooth` (saved as `smooth` in TravelLog's settings) sets how round: 100 is the full spline, lower values flatten it toward straight lines. Each turn is drawn as up to 8 short lines, as few as look smooth at the current zoom; straight stretches stay single lines.

### Fading

Older parts of the trail get fainter and thinner, so your recent path and its direction stand out. Age is counted in played time on that character, back from the end of the shown range: now, or the end of a calendar day. Time logged out doesn't count, so each alt's trail fades back from where it last logged out.

| Played time ago | Opacity | Width |
| --- | --- | --- |
| under 15 min | full | full |
| 15 min to 2 h | eases down to 50% | full until 1 h |
| 1 h to 3 h | 50% from 2 h | eases down to 60% |
| over 3 h | 50% | 60% |

Jump dots fade too; other markers don't. Lines never get thinner than 1 pixel. Your lines that haven't started fading are drawn on top where the trail crosses itself. With the map open, the fade updates once a minute.

| Command | |
| --- | --- |
| `/tl fade` | Show the current fade |
| `/tl fade on`, `off` | Turn it on or off |
| `/tl fade 1h`, `3h`, `6h`, `12h` | Stretch or squeeze the default times to that length (`3h` is the default) |
| `/tl fade opacity 15-120 50` | Fade opacity from 15 to 120 played minutes down to 50% (10–100%) |
| `/tl fade width 60-180 60` | The same for width (30–100%) |
| `/tl fade default` | Back to the default |

Times go up to a week (10080 minutes). Only changed values are saved, in TravelLog's settings as `trailFade` (`on`, `alphaFrom`, `alphaTo`, `alpha`, `widthFrom`, `widthTo`, `width`; minutes and percent).

### Colors

The colors below are the defaults. To change one, click its swatch in the TravelLog window's **Colors** tab and pick a color and opacity (the full opacity, before fading); the map follows as you drag. **Default** puts one back, **All defaults** all of them. They're saved in TravelLog's settings as `trailColors` and `markerColors`, `{ r, g, b, a }` by kind.

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
| | | pale yellow dot | note (`/tl note`) |

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Path.lua`, every character's path, about 100 KB per hour of movement. It's account-wide so alts can see each other's trails. Paths are not pruned automatically; `/tl wipe confirm` removes that character's path.

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
- `flags`: sum of 1 mounted, 2 flight, 4 swimming, 8 dead or ghost, 16 in combat, 32 indoors, 64 stealthed, and 128 × the form ID (0 for none).
- Jump records end with `,zone,subzone`.
- Values the game doesn't reveal (coordinates in dungeons) are empty.

## Limits

- No path in dungeons and raids, since addons get no position there. Jumps are still recorded, without coordinates.
- Every login loads all characters' stored paths.
- The form IDs are Blizzard's constants from other clients; Forever's UI code lists none, so they're unconfirmed in game.
- Markers of one kind that would overlap are drawn once, so of several notes or deaths in one spot only the first can be hovered.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
