# KillXP

Adds two lines to the tooltip of mobs you can kill in WoW: Forever:

```
Kobold Vermin
Level 8
Kill XP          ~134 (+67 rested)
Kills to level   ~6
```

- **Kill XP**: what one kill gives you. With rested XP it shows the doubled amount and the rested part. In a group it shows your share with the party bonus, the group size and your solo XP, e.g. `~34 (3 in group, ~95 solo)`.
- **Kills to level**: kills of this mob needed to level up, counting your group and the rested XP you have left, even if it runs out partway.

Gray mobs show `none (too low)`, mobs tagged by others `none (tapped by others)`, and `??` mobs `unknown`. Players, pets, friendly NPCs and corpses get no lines, and neither do characters at max level or with XP turned off.

## Estimates and learned values

`~` marks an estimate. Forever matches Classic's kill XP for mobs of your level but gives an unpublished, smaller amount below it, so KillXP starts from Classic's formula:

- **Base:** `level × 5 + 45` at your level, 5% more per level above (at most 4), less below until the mob turns gray.
- **Elites:** 2×, or 2.5× in dungeons.
- **Party bonus:** 1.166× for 3 players, 1.3× for 4, 1.4× for 5, split by level. Nobody gets XP if the mob is gray to the highest-level member.

Each **solo** kill replaces the estimate with the XP you actually got minus rested bonus, remembered per your level, mob level, elite and dungeon, and shown without `~` after that. Buffs that add kill XP are included in what's learned. Learned values are shared by all your characters. Group kills aren't learned, so group numbers stay estimates that assume everyone is alive and nearby.

## Commands

| | |
| --- | --- |
| `/killxp` | How many mob levels have a learned value |
| `/killxp reset` | Forget learned values, e.g. after a patch changes kill XP |
