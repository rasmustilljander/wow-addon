# TODO

## Data versions

TravelLog's character file has a data version (`ns.DATA_VERSION` in `TravelLog/Core.lua`, now 1) and refuses versions it doesn't know. Still to do:

- **Conversions.** When a layout change means older TravelLogs would misread the file, bump `DATA_VERSION` and add a `CONVERT` step from the old version, or list it in `COMPATIBLE` if it reads as it is. Test each step with a saved file of the old version.
- **Other files.** TravelLog's account file and the companions' files aren't checked. The account file's `version = 2` only marks the move of history to character files; Kills, NPCs and Group save `version = 1` without reading it; Path, Nodes and Share save none.
