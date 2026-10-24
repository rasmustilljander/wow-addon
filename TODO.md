# TODO

## Data versions

TravelLog's account and character files have a data version (`ns.DATA_VERSION` in `TravelLog/Core.lua`, now 1), and so does KillXP's file (`KillXP/XP.lua`, now 1). Each refuses versions it doesn't know. Still to do:

- **Conversions.** When a layout change means older TravelLogs would misread a file, bump `DATA_VERSION` and add a `CONVERT` step from the old version (in TravelLog an `account` and/or `char` function), or list it in `COMPATIBLE` if it reads as it is. Test each step with a saved file of the old version.
- **Companion files.** They aren't checked: Kills, NPCs and Group save `version = 1` without reading it; Path, Nodes and Share save none.

## Planned

- **TravelLog export.** The log and totals can't be copied out of the game; only the raw SavedVariables file has them. Add a command or button that opens a copyable text box (CSV or similar) with the log or the totals. A text box because addons can't write files of their own.

## Won't do

- **Personal bank item log.** TravelLog logs items moved to and from the guild bank, but not the personal bank; decided against.
