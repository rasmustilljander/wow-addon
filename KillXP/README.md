# KillXP

Adds two lines to the tooltip of mobs you can kill in WoW: Forever:

```
Kobold Vermin
Level 8
Kill XP          ~170 (+85 rested)
Kills to level   ~6
```

- **Kill XP**: what one kill gives you, with active Well Fed and sleeping-bag XP buffs (`+5% XP buffs`). With rested XP it shows the doubled amount and the rested part. In a group it shows your share with the party bonus, the group size and your buffed solo XP: `~34 (3 in group, ~95 solo)`.
- **Kills to level**: kills of this mob to level up, counting your group and the rested XP you have left, even if it runs out partway.

Gray mobs show `none (too low)`, mobs gray to your group's highest level `none (too low for your group)`, mobs tagged by others `none (tapped by others)`, and `??` mobs `unknown (level ??)`. Players, pets, friendly NPCs and corpses get no lines, and neither do characters at max level or with XP turned off.

## Estimates and learned values

`~` marks an estimate from Forever's current formula:

- **Base:** `level × 5 + 45` at your level, 5% more per level above (at most 4). Lower mobs use their own level for the base, then lose more until gray.
- **Elites and dungeons:** outdoor elites give 2×; dungeon creatures give about 1.2× instead.
- **Party bonus:** 1.166× for 3 players, 1.3× for 4, 1.4× for 5, none in raids, split by level. Nobody gets XP if the mob is gray to the highest-level member.
- **XP buffs:** Well Fed adds 5%; the sleeping-bag Well-Rested buff 1% per stack, up to 3%.
- **Rested:** kills give double XP until the XP bar reaches the rested marker, so the pool is worth half its size in bonus XP.

Each **solo** kill of a mob you looked at in the last minute replaces the estimate with the XP you actually got, minus rested and buffs, remembered by your level, mob level, elite and dungeon, and shown without `~` from then on (with your current buffs added). Learned values are shared by all your characters. Group kills aren't learned, so group numbers stay estimates that assume everyone is alive and nearby.

## Commands

| | |
| --- | --- |
| `/killxp` | How many mob levels have a learned value |
| `/killxp reset` | Forget learned values, e.g. after a patch changes kill XP |

## Saved data

`WTF/Account/<ACCOUNT>/SavedVariables/KillXP.lua`: `KillXPDB = { version = 1, seen = { ["8:8"] = 85, ["20:21e"] = 304 } }`. `seen` keys are your level, `:`, the mob's level, then `e` for elite and `d` for dungeon; values are unbuffed solo XP. `version` is the data version. With a newer version (from a newer KillXP) it says so in chat and on `/killxp`, only estimates and leaves the file as it is.

## Limits

- The rested bonus is taken out of what's learned only when the kill's chat line says it (`(+40 exp Rested bonus)`). Forever is said to leave it out, so a kill isn't learned while you have rested XP, in the 2 s after the pool goes down, or when the pool can't be read.
