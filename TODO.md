# TODO

## Data versions

TravelLog's account and character files have a data version (`ns.DATA_VERSION` in `TravelLog/Core.lua`, now 1) and refuse versions they don't know. Still to do:

- **Conversions.** When a layout change means older TravelLogs would misread a file, bump `DATA_VERSION` and add a `CONVERT` step from the old version (an `account` and/or `char` function), or list it in `COMPATIBLE` if it reads as it is. Test each step with a saved file of the old version.
- **Companion files.** They aren't checked: Kills, NPCs and Group save `version = 1` without reading it; Path, Nodes and Share save none.
