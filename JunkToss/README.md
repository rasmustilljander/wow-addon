# JunkToss

Throws away the least valuable grey in your bags, one stack per right-click on its minimap button. Items you put on the allowlist count as greys, whatever their quality.

## Throwing away

- **Right-click** the minimap button: throws away the cheapest stack. Its tooltip names that stack first.
- **Left-click**: opens or closes the window. Drag to move the button around the minimap.

"Cheapest" is the stack's sell price times its count, so a lone 7c grey goes before five 2c ones. Ties go in bag order. Items without a sell price go first. The thrown stack is printed to chat:

```
JunkToss Threw away [Rat Tail]x5 (10c).
```

Poor items go without confirmation; an allowlisted item of higher quality waits for the game's. Nothing is thrown while your cursor holds something, and items the client hasn't loaded a price for yet are skipped.

## Commands

| | |
| --- | --- |
| `/junk` or `/junktoss` | Open or close the window |
| `/junk throw` | Throw away the cheapest stack |
| `/junk add <item>` | Add an item to the allowlist (shift-click it into chat) |
| `/junk remove <item>` | Take an item off the allowlist |

## The window

- **Left**: every grey and allowlisted stack in your bags, cheapest first, with its value. The next one to go is highlighted. **Throw away cheapest** does the same as a right-click.
- **Right**: the allowlist. Drop an item on the box at the top to add it; the X removes one.
- **Minimap button** checkbox hides or shows the button.

## Saved data

`JunkTossDB` (account-wide):

| Field | |
| --- | --- |
| `allow` | Item ID → item link of each allowlisted item |
| `point` | Window position: `{ point, relativePoint, x, y }` |
| `minimap` | Minimap button: `angle` in degrees (starts at 200, left), `hide` when it's off |
