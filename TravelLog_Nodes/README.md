# TravelLog Nodes

Remembers every chest, herb and ore spot you loot in WoW: Forever and pins it on the world map with when you last looted it. Needs [TravelLog](../TravelLog/), whose loot recording tells it what you looted, where and with which spell.

## What it records

Per spot: what it was, when you last looted it, how many times, and the five latest times. Spots are matched by kind and place (within about 10 yards), not by object, because one spot can grow different herbs. The loot entry in `/tl log` notes the previous visit, e.g. `Looted [Peacebloom]x2 from Peacebloom (looted here 30m before)`.

## Commands

| Command | |
| --- | --- |
| `/tl nodes on\|off` | Pins on the world map (default on) |

`/tl stats` adds how many herbs, ore, chests and other objects are remembered.

## World map

Zone maps (not continent maps) show square pins: green herbs, orange ore, gold chests, grey other objects. Hover one for when you last looted it, how long ago, how many times, and the times before.

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Nodes.lua`. Nodes never rotate into the archive. Nodes TravelLog kept before this addon existed move here at the first login.

```lua
TravelLogNodesDB = {
  maps = {   -- per uiMapID
    [1429] = { { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3,
                 inst = 0, a = -9000.0, b = -100.0, last = 1760000000,
                 count = 8, times = { 1760000000, 1759998200, ... } } },
  },
}
```

- `kind`: `herb`, `ore`, `chest` or `object` (opened without a cast).
- `x`, `y`: map coordinates 0–100. `inst`, `a`, `b`: continent and world position in yards, used to match spots.
- `times`: the last five loot times, newest first.

## Limits

- An object that opens without a cast (some quest crates) has no name, only its object ID.
- Dungeons have no coordinates, so chests there aren't remembered. TravelLog still logs the loot.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
