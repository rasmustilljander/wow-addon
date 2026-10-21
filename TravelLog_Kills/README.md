# TravelLog Kills

Records every mob you kill in WoW: Forever: how often, when and where. A companion to [TravelLog](../TravelLog/) that also works on its own.

## What it records

A kill counts when you, your pet or a party member lands the killing blow, XP or not (grey mobs too). For each one:

| | |
| --- | --- |
| **Mob** | Name and NPC ID. Kills are grouped by name, so same-named NPCs (most "Defias Thug"s) add up. |
| **When** | Date and time. |
| **Where** | Zone, subzone, map ID and coordinates: your position, not the mob's. |
| **XP** | The experience gained, if any. |
| **Who** | The party member who landed the blow, if not you. Your pet's kills are yours. |

Tooltips of mobs you've killed show `Killed 54 times, last 2h ago`.

## World map

Zone maps (not continent maps) show red pins where you've killed things. Kills within about 2% of the map's width share a pin that grows with the count. Hover a pin for its kill count, the latest kill and the mobs killed there, most first. Dungeon kills have no coordinates, so they aren't pinned.

## Window

With TravelLog installed, [its window](../TravelLog/README.md#window) gets a **Kills** tab: every mob you've killed, most first, with a search box that matches any part of the name. Click a mob for its kill count, first and last kill, and the zones you killed it in with a count each.

The window's Totals tab also shows your total and most-killed mob, and Settings has a **Kills** checkbox for the pins (checking it shows all kills again).

## Commands

| Command | |
| --- | --- |
| `/kills [n]` | Total kills and your n most-killed mobs (default 10) |
| `/kills <name>` | One mob: count, first and last kill, top places, total XP and the last 10 kills. Partial names work; several matches are listed. |
| `/kills target` | The same for your target |
| `/kills recent [n]` | Your last n kills (default 15) |
| `/kills window` | Open the [Kills tab](#window) (needs TravelLog) |
| `/kills map on\|off` | Pins on the world map (default on) |
| `/kills map <name>` | Pin only that mob's kills (`/kills map target` for your target; `on` shows all again) |
| `/kills wipe confirm` | Delete every kill for this character |

`/tlk` works too.

```
/kills kobold worker
TravelLog Kills Kobold Worker: killed 54 times.
  First 2026-10-12 14:03, last 2026-10-19 09:12 (2h 5m ago)
  Where: Elwynn Forest / Fargodeep Mine (41), Elwynn Forest / Jasperlode Mine (13)
  2,310 xp in total, 3 finished by party members
  Last 10:
    10-19 09:12  Elwynn Forest / Fargodeep Mine (39.8, 81.2) +42 xp
    ...
```

## How kills are detected

Addons can't read the combat log on this client, so kills come from:

- `PARTY_KILL`, fired for a killing blow by you, your pet or a party member. It identifies the exact mob.
- The chat line `X dies, you gain N experience.`, which gives the name and XP.

Most kills produce both. Each waits up to 2 seconds for the other and is saved once.

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Kills.lua`:

```lua
TravelLogKillsDB = {
  total = 1234,
  settings = { map = true, mapFilter = "Kobold Worker" },   -- /kills map
  places = { "Elwynn Forest|Goldshire", "Elwynn Forest|Fargodeep Mine", "Westfall", ... },
  mobs = {
    ["Kobold Worker"] = { name = "Kobold Worker", ids = { 257 }, count = 54,
      first = 1760000000, last = 1760600000,
      kills = { "1760000000,1429,39.80,81.20,2,42", ... } },   -- oldest first
  },
}
```

Each kill is one string, `time, uiMapID, x, y, place, xp, killed by`, with trailing empty fields dropped. `x`, `y` are map coordinates 0–100 and `place` indexes `places` (`zone|subzone`). About 50 bytes per kill, so 10,000 kills take about half a megabyte.

## Limits

- Kills by anyone outside your party (another player, a guard) aren't counted.
- In dungeons and raids the client can hide mob identities and coordinates. A kill there is recorded without coordinates if its XP line names it, and not at all if nothing names it.
- When several unnamed mobs die at once, their XP lines are matched to them in order.
- Untested in the live game; written against the Forever 1.60.1 API documentation and tested against a fake client ([tests](../tests/README.md)).
