# TravelLog Nodes

Remembers every chest, herb and ore spot you loot in WoW: Forever, and pins them on the world map with when you last looted each one. Part of [TravelLog](../TravelLog/), which it needs: TravelLog's loot recording tells it what you looted, where, and with which spell.

## What it records

Every chest, herb and ore spot you've looted, remembered by place: what it was, when you last looted it, how many times, and the five most recent times. A spot is matched by kind and place (within about 10 yards), not by object, because the same spot can grow different herbs.

The loot entry in `/tl log` says when you last looted that spot, e.g. `Looted [Peacebloom]x2 from Peacebloom (looted here 30m before)`.

## Commands

| Command | |
| --- | --- |
| `/tl nodes on\|off` | Show looted chests, herbs and ore on the world map (default on) |

`/tl stats` shows how many herbs, ore, chests and other objects are remembered.

## World map

On zone maps, square pins mark the chests and gathering nodes you've looted: green for herbs, orange for ore, gold for chests and grey for other objects. Hover a pin to see when you last looted it, how long ago that was, how many times you've looted it and the times before. Pins only appear on zone maps, not continent maps.

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Nodes.lua`, one file per character, written when you log out or `/reload`. Nodes don't move into the archive.

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
- `x`, `y`: map coordinates 0–100. `inst`, `a`, `b`: continent and world position in yards, used to match the spot.
- `times`: the last five loot times, newest first.

Before this addon existed, TravelLog kept the nodes in its own character file. The first login with TravelLog_Nodes installed moves them here.

## Limits

- Chests and herbs are named by the spell that opened them. An object that opens without a cast (some quest crates) is recorded with its object ID but no name.
- Inside dungeons there are no coordinates, so chests looted there aren't remembered. The loot itself is still in TravelLog's log.
- Not yet tested in the live game. It's tested against a fake client (see [tests](../tests/README.md)).
