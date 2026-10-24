# KillXP

Adds two lines to the tooltip of mobs you can kill in WoW: Forever:

```
Kobold Vermin
Level 8
Kill XP          ~134 (+67 rested)
Kills to level   ~6
```

- **Kill XP**: what one kill gives you. It includes active Well Fed and sleeping-bag XP buffs. With rested XP it shows the doubled amount and the rested part. In a group it shows your share with the party bonus, the group size and your buffed solo XP, e.g. `~34 (3 in group, ~95 solo)`.
- **Kills to level**: kills of this mob needed to level up, counting your group and the rested XP you have left, even if it runs out partway. Rested kills give double XP until the XP bar reaches the rested marker, so the pool is worth half its size in bonus XP.

Gray mobs show `none (too low)`, mobs tagged by others `none (tapped by others)`, and `??` mobs `unknown`. Players, pets, friendly NPCs and corpses get no lines, and neither do characters at max level or with XP turned off.

## Estimates and learned values

`~` marks an estimate. KillXP starts from Forever's current formula:

- **Base:** `level × 5 + 45` at your level, 5% more per level above (at most 4); lower mobs use their own level for the base, then lose more until gray.
- **Elites and dungeons:** outdoor elites give 2×; dungeon creatures currently give about 1.2× instead.
- **Party bonus:** 1.166× for 3 players, 1.3× for 4, 1.4× for 5, split by level. Nobody gets XP if the mob is gray to the highest-level member.
- **XP buffs:** Well Fed adds 5%; the sleeping-bag Well-Rested buff adds 1% per stack, up to 3%. These are separate from the rested-XP pool that doubles kill XP.

Each **solo** kill of a mob KillXP saw in the last minute replaces the estimate with the XP you actually got minus rested and active percentage bonuses, remembered per your level, mob level, elite and dungeon, and shown without `~` after that. The current buffs are added when the tooltip is shown. Learned values are shared by all your characters. Group kills aren't learned, so group numbers stay estimates that assume everyone is alive and nearby.

`WTF/Account/<ACCOUNT>/SavedVariables/KillXP.lua` stores `KillXPDB = { version = 1, seen = { ... } }`, `version` being its data version. KillXP reads only versions it knows: with a newer one (from a newer KillXP) it says so in chat and on `/killxp`, only estimates, and leaves the file as it is.

## Commands

| | |
| --- | --- |
| `/killxp` | How many mob levels have a learned value |
| `/killxp reset` | Forget learned values, e.g. after a patch changes kill XP |

## Limits

- The rested bonus is taken out of what's learned only when the kill's chat line says it (`(+40 exp Rested bonus)`). Forever is said to leave it out, so a kill without it isn't learned while you have rested XP, in the 2 s after the pool goes down, or when the pool can't be read.
