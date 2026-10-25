# TravelLog Group

Records every player you group with in WoW: Forever: how often, when, for how long and where. A companion to [TravelLog](../TravelLog/) that also works on its own.

## What it records

A group with a player starts when they show up in your party or raid and ends when they or you leave. For each one:

| | |
| --- | --- |
| **When** | Start date and time, and how long you were grouped. |
| **Where** | The zone and subzone where it started. |
| **Kills** | Kills made together: killing blows by you, your pet or a party member while grouped. |
| **Them** | Their level then, and whether it was a raid. Their class and latest level are kept per player. |

Logging out ends your groups, unless you log back in within 5 minutes still grouped: then it's the same group.

Tooltips of players you've grouped with show `Grouped 3 times (4h 12m), last 2d 4h ago`, or `in your group now`.

## Window

With TravelLog, [its window](../TravelLog/README.md#window) gets a **Players** tab: everyone you've grouped with, most often first, in class colors, with a search box that matches any part of `Name-Realm`. Click a player for the number of groups, total time, first and latest group and kills together, then every group, newest first: date, length (green while it's still going), where, kills, their level and whether it was a raid. Totals show how many players you've grouped with and with whom most.

## Commands

| Command | |
| --- | --- |
| `/grouped [n]` | Total groups and the n players you grouped with most (default 10) |
| `/grouped <name>` | One player: count, total time, first and last group, kills together and the last 10 groups. Partial names and realms work; several matches are listed. |
| `/grouped target` | The same for your target |
| `/grouped recent [n]` | Your last n groups with anyone (default 15) |
| `/grouped window` | Open the [Players tab](#window) (needs TravelLog) |
| `/grouped wipe confirm` | Delete every group for this character, then reload |

`/tlg` works too. Players from your own realm are shown by name, others as `Name-Realm`.

```
/grouped anna
TravelLog Group Anna (Warrior): grouped 3 times, 4h 12m in total.
  First 2026-10-12 14:03, last 2026-10-19 09:12 (last 2h 5m ago)
  85 kills together
  Last 3:
    10-19 08:10  1h 2m  Westfall / Moonbrook, 45 kills, level 18
    ...
```

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Group.lua`:

```lua
TravelLogGroupDB = {
  version = 1,
  total = 42,
  places = { "Elwynn Forest|Goldshire", "Westfall|Moonbrook", ... },
  players = {
    ["Anna-Forever"] = { key = "Anna-Forever", name = "Anna", realm = "Forever", guid = "Player-1-0A1B2C3D",
      class = "WARRIOR", level = 18, count = 3, time = 15120, kills = 85,
      first = 1760000000, last = 1760600000,
      groups = { "1760000000,3720,2,45,18", ... } },   -- oldest first
  },
  open = { ["Anna-Forever"] = { start = 1760600000, seen = 1760603000, kills = 5 } },   -- groups still going
}
```

Each group is one string, `start, seconds, place, kills, level, r` (`r` for a raid), with trailing empty fields dropped. `place` indexes `places` (`zone|subzone`). `time` and `kills` are totals of the ended groups; a group still going is in `open` and is the last entry in `groups`.

## Limits

- Inside instances the client can hide players' names. While anyone in the roster is unavailable or can't be read, nobody's group ends.
- Kills together are the killing blows [TravelLog_Kills](../TravelLog_Kills/README.md#how-kills-are-detected) sees too (`PARTY_KILL`), so kills by players outside your party don't count.
- Untested in the live game; written against the Forever 1.60.1 API documentation and tested against a fake client ([tests](../tests/README.md)).
