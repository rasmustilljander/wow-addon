# TravelLog Nodes

Remembers every chest, herb and ore spot your characters loot in WoW: Forever and pins it on the minimap and world map with when it was last looted and by whom. All characters on the account share the same nodes, like Gatherer. Needs [TravelLog](../TravelLog/), whose loot recording tells it what you looted, where and with which spell.

## What it records

Per spot: what it was, when it was last looted, the five latest loot times with who looted each, and how many times each character looted it. Spots are matched by kind and place (within about 10 yards), not by object, because one spot can grow different herbs. The loot entry in `/tl log` notes the previous visit, and the alt if it was another character, e.g. `Looted [Peacebloom]x2 from Peacebloom (looted here 30m before by Altie-Forever)`.

## Commands

| Command | |
| --- | --- |
| `/tl nodes on\|off` | Pins on the world map (default on) |

`/tl stats` and the [TravelLog window](../TravelLog/README.md#window) show how many herbs, ore, chests and other objects all characters have found. The window has separate **Looted nodes on the minimap** and **Looted nodes on the world map** checkboxes; both default on.

## Map pins

The minimap shows nearby nodes recorded on its current map and follows the minimap's range and rotation. Zone maps (not continent maps) show every node in the zone. Both use square pins: green herbs, orange ore, gold chests, grey other objects. Hover one for when it was last looted, how long ago and by whom, how many times (split by character when more than one looted it), and the times before:

```
Peacebloom
Last looted 2025-10-09 15:35 (5m ago) by Altie
Looted 9 times (Rasmus 8, Altie 1). Before that:
  2025-10-09 12:10  Rasmus
```

Names are in the character's class color, with the realm when it isn't yours. Nodes other players share through [TravelLog_Share](../TravelLog_Share/) are smaller and dimmer.

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Nodes.lua`, one file for every character on every realm. Nodes never rotate into the archive. Nodes from 0.1's per-character file, and from TravelLog's file before this addon existed, move into it at each character's first login; the same spot from two characters becomes one node.

Pin settings are in `SavedVariables/TravelLog.lua`: `TravelLogDB.settings.nodeMinimap` controls the minimap and `TravelLogDB.settings.nodes` controls the world map.

```lua
TravelLogNodesAccountDB = {
  maps = {   -- per uiMapID
    [1429] = { { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3,
                 inst = 0, a = -9000.0, b = -100.0, last = 1760000000,
                 times = { 1760000000, 1759998200, ... },
                 by = { "Altie-Forever", "Rasmus-Forever", ... },
                 counts = { ["Rasmus-Forever"] = 8, ["Altie-Forever"] = 1 } } },
  },
}
```

- `kind`: `herb`, `ore`, `chest` or `object` (opened without a cast).
- `x`, `y`: map coordinates 0–100. `inst`, `a`, `b`: continent and world position in yards, used to match spots.
- `times`: the last five loot times, newest first. `by[i]` is who looted at `times[i]`.

`/tl wipe confirm` takes the character out of every node and deletes the nodes only it looted.

## Limits

- Realms share nodes, but each realm has its own spawns, so a time from another realm says nothing about this one.
- An object that opens without a cast (some quest crates) has no name, only its object ID.
- Dungeons have no coordinates, so chests there aren't remembered. TravelLog still logs the loot.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
