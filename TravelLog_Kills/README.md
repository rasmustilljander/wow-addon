# TravelLog Kills

Records every mob you kill in WoW: Forever: how many times you've killed it, when and where. It's a companion to [TravelLog](../TravelLog/) but works on its own too.

## What it records

For every kill:

| | |
| --- | --- |
| **Mob** | Its name and NPC ID. Kills are grouped by name, so different NPCs with the same name (most "Defias Thug"s) add up together. |
| **When** | Date and time. |
| **Where** | Zone, subzone, map ID and map coordinates. This is your position when it died, not the mob's. |
| **XP** | The experience it gave, if any. |
| **Who** | The party member's name when someone else in your group landed the killing blow. Your pet's kills count as yours. |

Kills count when you, your pet or someone in your party lands the killing blow, whether or not the mob gives XP (grey mobs count too).

Mobs you've killed show it on their tooltip: `Killed 54 times, last 2h ago`.

## Commands

| Command | |
| --- | --- |
| `/kills [n]` | Total kills and the n mobs you've killed most (default 10) |
| `/kills <name>` | One mob: how many times, first and last kill, where (top places), total XP and the last 10 kills with time and coordinates. Part of a name works; if several mobs match they're listed. |
| `/kills target` | The same for your current target |
| `/kills recent [n]` | Your last n kills of any mob (default 15) |
| `/kills wipe confirm` | Delete every recorded kill for this character |

`/tlk` works too.

Example:

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

The Forever client doesn't let addons read the combat log, so kills come from two other places:

- `PARTY_KILL`: the client's event for a killing blow by you, your pet or a party member. It identifies the exact mob.
- The chat line `X dies, you gain N experience.`: gives the name and the XP.

Most kills produce both. Each one waits up to 2 seconds for the other and is saved once.

## Where the data is

`WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/TravelLog_Kills.lua`, one file per character, written when you log out or `/reload`.

```lua
TravelLogKillsDB = {
  total = 1234,
  places = { "Elwynn Forest|Goldshire", "Elwynn Forest|Fargodeep Mine", "Westfall", ... },
  mobs = {
    ["Kobold Worker"] = { name = "Kobold Worker", ids = { 257 }, count = 54,
      first = 1760000000, last = 1760600000,
      kills = { "1760000000,1429,39.80,81.20,2,42", ... } },   -- oldest first
  },
}
```

Each kill is packed into one string to keep the file small:

```
time, uiMapID, x, y, place, xp, killed by
```

- `x`, `y`: map coordinates 0–100, like the ones you see in game.
- `place`: index into `places` (`zone|subzone`).
- Empty fields at the end are left out.

Each kill takes about 50 bytes, so 10,000 kills make a file of about half a megabyte.

## Limits

- Kills by someone outside your party (another player who tagged the mob, a guard) aren't yours and aren't counted.
- Inside dungeons and raids the client can hide mob identities and coordinates from addons. A kill there is still recorded if its XP line names it, without coordinates. A kill with neither (no name, no XP) can't be recorded.
- If several mobs die at once and the client can't name them, their XP lines are matched to them in order.
- Not yet tested in the live game. It's written against the Forever 1.60.1 API documentation and tested against a fake client (see [tests](../tests/README.md)).
