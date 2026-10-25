# TravelLog Path

Records the path you walk, ride, swim and fly in WoW: Forever, and every jump, and draws the trail on the world map, along with your alts' and [friends'](../TravelLog_Share/) if you want them. Needs [TravelLog](../TravelLog/).

## What it records

| | |
| --- | --- |
| **Path** | Your position every 2 seconds while moving (`/tl interval`), and whenever the map or how you move changes: on foot, mounted, flight path, swimming or as a ghost. Nothing while standing still. |
| **Jumps** | Every jump with time and place, and totals per zone. |
| **Distance** | How far you've travelled each of those ways, and in each [form](#distance-by-form). |

## Commands

| Command | |
| --- | --- |
| `/tl jumps` | Jumps per zone |
| `/tl trail <range>` | How far back your map trail goes (default `today`) |
| `/tl trail alts <range>` | The same for alts' trails (default `off`) |
| `/tl trail friends <range>` | The same for friends' trails (default `today`) |
| `/tl smooth 0-100` | How round the trail's turns are; 0 draws straight lines (default 50) |
| `/tl fade ...` | How the trail fades (see [Fading](#fading)) |
| `/tl interval 1-5` | Seconds between path points (default 2) |

| Range | Shows |
| --- | --- |
| `session` | The latest session: your current one, an alt's last one |
| `today` | Since midnight |
| `week` | The last 7 days |
| `6h`, `3d` | The last n hours (`h`) or days (`d`) |
| `yesterday`, `2026-10-19` | That calendar day only (`yesterday` is saved as its date) |
| `all` | Everything stored |
| `off` | Nothing |

`/tl stats` adds jumps (and the zone with most), distance in yards by way of travel and by form and, for the character you're on, this session's jumps and the stored path points. The [TravelLog window](../TravelLog/README.md#window)'s Totals show jumps, and distance and distance by form in miles. Its Settings have buttons for your trail, the alts' trail (once an alt has a path) and, with TravelLog_Share, the friends' trail (`session`, `today`, `24h`, `week`, `all`, `off`), each with `<` and `>` to step one calendar day; a checkbox per alt to hide its trail; the fade (`off`, `1h`, `3h`, `6h`, `12h`), curves (`0` to `100`) and interval.

## Distance by form

Distance in a shapeshift form or in stealth is counted in TravelLog's `stats.formDistance` (yards), next to `stats.distance` by way of travel (`foot`, `mount`, `flight`, `swim`, `ghost`).

| Key | Form ID (`GetShapeshiftFormID()`) |
| --- | --- |
| `cat` | 1 |
| `bear` | 5 |
| `travel` | 3 |
| `aquatic` | 4 |
| `moonkin` | 31 or 35 |
| `ghostwolf` | 16 |
| `stealth` | `IsStealthed()`, in any form |

Stealth overlaps the rest: prowling counts as `cat` and `stealth`. Other forms (Tree of Life, Shadowform) are saved in the path's flags but not counted. Shifting records a path point, so shifting often adds points.

## World map

Zone and continent maps show your trail, broken at teleports (hearthstone, portals, graveyard), with markers for jumps and for TravelLog's loot, deaths, level-ups, notes and other milestones. Hover a death or note marker for its date and entry. Alts' and friends' trails are thinner lines in their class color, under yours, without markers.

The trail curves through the recorded points instead of turning sharply at each; `/tl smooth` (setting `smooth`) sets how much.

### Fading

Older parts of the trail get fainter and thinner, so your recent path and its direction stand out. Age is played time on that character, counted back from the end of the shown range (now, or the end of a calendar day), so each alt's trail fades back from where it last logged out.

By default, opacity eases from full at 15 played minutes to 50% at 2 hours, and width from full at 1 hour to 60% at 3 hours. Jump dots fade too; other markers don't. Lines are never thinner than 1 pixel. With the map open, the fade updates once a minute.

| Command | |
| --- | --- |
| `/tl fade` | Show the current fade |
| `/tl fade on`, `off` | Turn it on or off |
| `/tl fade 1h`, `3h`, `6h`, `12h` | Scale the default to that length (`3h` is the default) |
| `/tl fade opacity 15-120 50` | Opacity from 15 to 120 played minutes down to 50% (10–100%) |
| `/tl fade width 60-180 60` | The same for width (30–100%) |
| `/tl fade default` | Back to the default |

Times go up to a week (10080 minutes). Only changed values are saved, in TravelLog's settings as `trailFade` (`on`, `alphaFrom`, `alphaTo`, `alpha`, `widthFrom`, `widthTo`, `width`; minutes and percent).

### Colors

To change a color, click its swatch in the TravelLog window's **Colors** tab and pick a color and opacity; the map follows as you drag. **Default** resets one, **All defaults** all. They're saved in TravelLog's settings as `trailColors` and `markerColors`, `{ r, g, b, a }` by kind. Defaults:

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
| | | pale yellow dot | note |

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Path.lua`: every character's path, about 100 KB per hour of movement. It's account-wide so alts can see each other's trails. Nothing is pruned; `/tl wipe confirm` removes that character's path.

```lua
TravelLogPathAccountDB = {
  chars = {
    ["Name-Realm"] = {
      sessions = {   -- one per login or reload, oldest first; start matches TravelLog's session
        { start = 1760000000, stop = 1760007200, jumpCount = 12, track = { "..." }, jumps = { "..." } },
      },
    },
  },
}
```

Each string in `track` and `jumps` packs up to 200 records separated by `;`:

```
seconds into session, uiMapID, x, y, instanceID, world 1, world 2, flags
```

- `x`, `y`: map coordinates 0–100. `instanceID`, `world 1`, `world 2`: continent and `UnitPosition("player")` in yards.
- `flags`: sum of 1 mounted, 2 flight path, 4 swimming, 8 dead or ghost, 16 in combat, 32 indoors, 64 stealthed, plus 128 × the form ID.
- Jump records end with `,zone,subzone`.
- Values the game doesn't reveal (coordinates in dungeons) are empty.

## Limits

- No path in dungeons and raids, since addons get no position there. Jumps are still recorded, without coordinates.
- Every login loads all characters' stored paths.
- The form IDs are Blizzard's constants from other clients; Forever's UI code lists none, so they're unconfirmed in game.
- Overlapping markers of one kind are drawn once, so of several notes or deaths in one spot only the first can be hovered.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
