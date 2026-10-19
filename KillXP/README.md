# KillXP

Adds two lines to the tooltip of any mob you can kill in WoW: Forever:

```
Kobold Vermin
Level 8
Kill XP          ~134 (+67 rested)
Kills to level   ~6
```

- **Kill XP** is the experience one kill gives you. Rested XP doubles a kill's XP while your rested pool lasts. When you have rested XP, the line shows the doubled amount and how much of it is the rested bonus. In a group it shows your share with the party bonus, then the group size and what you'd get solo, e.g. `~34 (3 in group, ~95 solo)`.
- **Kills to level** is how many of these mobs you need to kill to level up. It counts the rested XP you have left, which can run out partway through, and your group.

Gray mobs show `none (too low)`, mobs another player tagged show `none (tapped by others)`, and `??` mobs show `unknown`. Players, pets, friendly NPCs and corpses get no lines, and neither does anyone at max level or with XP turned off.

## Estimates and learned values

A `~` marks an estimate. Forever gives Classic's kill XP for mobs of your own level but less for mobs below your level, and Blizzard hasn't published by how much. So KillXP starts from the Classic formula:

- **Base:** `level × 5 + 45` for a mob of your level, 5% more per level above you (counting at most 4 levels), and less below you until the mob turns gray.
- **Elites:** 2× (2.5× in dungeons).
- **Party bonus:** 1.166× for 3 players, 1.3× for 4, 1.4× for 5. The total is split by level, and if the mob is gray to the highest-level member, nobody gets XP.

Every **solo** kill replaces the estimate with the XP you actually got, minus any rested bonus. That value is remembered for that mob level at your level (and elite, in a dungeon or not), and from then on it's shown without the `~`. Group kills aren't learned, because they depend on who is in the group. Group numbers always stay estimates, and they assume everyone is alive and close by.

Learned values are shared by all your characters. Buffs that add kill XP (food, a sleeping bag) are counted in what's learned.

## Commands

| | |
| --- | --- |
| `/killxp` | How many mob levels have a learned value. |
| `/killxp reset` | Forget the learned values, for example after a patch changes kill XP. |
