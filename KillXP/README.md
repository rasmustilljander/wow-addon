# KillXP

Adds two lines to the tooltip of mobs you can kill in WoW: Forever:

```
Kobold Vermin
Level 8
Kill XP          ~134 (+67 rested)
Kills to level   ~6
```

- **Kill XP**: what one kill gives you. It includes active Well Fed and sleeping-bag XP buffs. With rested XP it shows the doubled amount and the rested part. In a group it shows your share with the party bonus, the group size and your buffed solo XP, e.g. `~34 (3 in group, ~95 solo)`.
- **Kills to level**: kills of this mob needed to level up, counting your group and the rested XP you have left, even if it runs out partway.

Gray mobs show `none (too low)`, mobs tagged by others `none (tapped by others)`, and `??` mobs `unknown`. Players, pets, friendly NPCs and corpses get no lines, and neither do characters at max level or with XP turned off.

## Estimates and learned values

`~` marks an estimate. KillXP starts from Forever's current formula:

- **Base:** `level × 5 + 45` at your level, 5% more per level above (at most 4); lower mobs use their own level for the base, then lose more until gray.
- **Elites and dungeons:** outdoor elites give 2×; dungeon creatures currently give about 1.2× instead.
- **Party bonus:** 1.166× for 3 players, 1.3× for 4, 1.4× for 5, split by level. Nobody gets XP if the mob is gray to the highest-level member.
- **XP buffs:** Well Fed adds 5%; the sleeping-bag Well-Rested buff adds 1% per stack, up to 3%. These are separate from the rested-XP pool that doubles kill XP.

Each **solo** kill replaces the estimate with the XP you actually got minus rested and active percentage bonuses, remembered per your level, mob level, elite and dungeon, and shown without `~` after that. The current buffs are added when the tooltip is shown. Learned values are shared by all your characters. Group kills aren't learned, so group numbers stay estimates that assume everyone is alive and nearby.

`WTF/Account/<ACCOUNT>/SavedVariables/KillXP.lua` stores `KillXPDB = { version = 2, seen = { ... } }`. Version 1 learned values are cleared once because their active XP buffs were not recorded.

## Commands

| | |
| --- | --- |
| `/killxp` | How many mob levels have a learned value |
| `/killxp reset` | Forget learned values, e.g. after a patch changes kill XP |
