# Reach

While you auto-attack or shoot, Reach shows a red warning above the middle of the screen when none of your weapons can hit your target:

| Warning | When |
| --- | --- |
| `Out of melee range` | Your target is just out of reach of your melee weapon, and you have no ranged weapon that can hit it. |
| `Dead zone: too close to shoot` | Your target is too close for your ranged weapon and too far for melee, like a hunter's dead zone between melee and shooting range. |

It only warns when the target is within trade distance (about 8 yards), so chasing a mob or starting an attack from across the field stays quiet. It has no sound. It checks five times a second and hides as soon as you stop attacking, change target or the target dies.

## Commands

| | |
| --- | --- |
| `/reach` | Turn warnings on or off |
| `/reach move` | Show the warning so you can drag it; `/reach move` again to finish |
| `/reach reset` | Put the warning back above the middle |

## Saved data

`ReachDB` (account-wide):

| Field | |
| --- | --- |
| `enabled` | Whether warnings are on (default `true`) |
| `point` | Warning position: `{ point, relativePoint, x, y }`; none means the default |

## Limits

- Ranges come from the game's own swing-range check (`C_SwingTimer.IsTargetWithinSwingRange`), the one that dims Blizzard's swing timer. When the game can't tell (no weapon for it, a target you can't attack), Reach stays quiet.
- After a `/reload` while shooting, it warns again from your next shot.
