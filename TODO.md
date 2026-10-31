# TODO

## Data versions

TravelLog's account and character files have a data version (`ns.DATA_VERSION` in `TravelLog/Core.lua`, now 1), and so does KillXP's file (`KillXP/XP.lua`, now 1). Each refuses versions it doesn't know. Still to do:

- **Conversions.** When a layout change means older TravelLogs would misread a file, bump `DATA_VERSION` and add a `CONVERT` step from the old version (in TravelLog an `account` and/or `char` function), or list it in `COMPATIBLE` if it reads as it is. Test each step with a saved file of the old version.
- **Companion files.** They aren't checked: Kills, NPCs and Group save `version = 1` without reading it; Path, Nodes and Share save none.

## Planned

- **OpenMap in the game.** The [OpenMap](README.md#openmap) support is tested only against a stand-in for its API. Check with the real addon:
  - the overlays stay above its art, also if it ever sets up after them;
  - other zones' trail and pins appear and go while panning, and cities show theirs: neighbours come from `C_Map.GetMapChildrenInfo(947, Enum.UIMapType.Zone, true)`, so a city of another map type would be missed;
  - the TravelLog switches in its menu, and their icons (`INV_Misc_Map_01`, `INV_Misc_Herb_07`, `Ability_DualWield`, `INV_Misc_Coin_01`).

- **TravelLog export.** The log and totals can't be copied out of the game; only the raw SavedVariables file has them. Add a command or button that opens a copyable text box (CSV or similar) with the log or the totals. A text box because addons can't write files of their own.

- **Log size.** TravelLog's character file only grows. On the fake client an entry is about 320 bytes saved and 2 KB in memory, about 60 KB per hour of leveling, measured before items used up (`use`) were logged, which add more. All of it loads at every login, and each keystroke in the History search checks every entry (0.7 s at 50,000 entries, about 250 hours). Totals (`stats`) aren't built from the log, so moving or deleting entries never changes them. Steps, each useful on its own:
  1. **Show the size.** Show the entry count, an estimated file size and the oldest entry's date on Totals' Log row and in `/tl stats`.
  2. **Stop reading the whole log.** Item tooltips, the first-kill screenshot check, and the Sessions and Levels views' counts all scan the full log. Save what they need in the character file instead: first time and count per item ID, killed boss IDs, and each session's and level's counts when it ends. Keep `level` and `equip` entries live for Path's replay.
  3. **Faster search.** Cache each entry's search text and search when typing pauses, not on every keystroke.
  4. **Archive.** Add a load-on-demand companion, TravelLog_Archive, with its own per-character file. When the live log passes 15,000 entries, move whole months to it, oldest first, until 10,000 or fewer remain. Store each entry as one string of `key=value` pairs, item links cut to `item:ID:...`, about 120 bytes. It needs no per-type format, and a string takes about a fifteenth of the memory. Its file loads only when you ask History or `/tl log` to search older entries. If the companion is missing or turned off, nothing moves.
  5. **Delete.** `/tl prune <days> confirm` deletes archived entries older than that. Use the planned export first to keep a copy.
  - Not planned: deflate compression. It shrinks the file another 3–4×, but it's slow in Lua, the saved file can't be read, and one bad byte breaks a whole chunk. Memory and search time are the real costs, and not loading old entries fixes both.
  - Check in game: that the client leaves a load-on-demand addon's saved file alone in sessions where it isn't loaded, and whether `C_AddOns.LoadAddOn` works in combat.
  - Path grows faster and is riskier: see Path size.

- **Path size.** TravelLog_Path's file grows by about 100 KB per hour of movement. It's account-wide, so every character's path loads at every login, on every character. The map now parses a long range over several frames and keeps at most 200,000 parsed points, and `/tl forget` removes another character's path. What's left, measured on the fake client with a 35 MB file (about 350 hours):
  - The `all` trail takes about 4.5 s, over about 250 frames, to draw in. Past the cap, each zoom or map change parses again.
  - `/tl stats` recounts every point each time (0.24 s).

  Totals (distance, jumps) are in TravelLog's `stats`, so none of the steps below change them. Steps:
  1. **Show the size.** Save each session's point count and byte size at logout. Show this character's and all characters' sizes in `/tl stats` and Settings. This also ends the recount.
  2. **Thin old sessions.** After 30 days, drop the points in near-straight stretches of a session's track (within about 2 yards, by world coordinates). Keep every point where the map or flags change, or where the path breaks. It's lossy and can't be undone, so it's a setting, and replays of old sessions get less exact. Measure the saving on a real file first.
  3. **Archive** old sessions to TravelLog_Archive (see Log size), only if thinning isn't enough. Unlike the log's archive, this file must be account-wide for alts' trails. It loads when a trail range reaches back past the live sessions.
  - Friends' trails, if they're ever saved (see Maybe), would need the same thinning.
  - The parse cap keeps the oldest sessions in range and parses the newest again. Keeping the newest would suit `all` better.

- **Damage and healing totals.** Your damage, healing and DPS per boss fight and per session, from Forever's built-in meter.
  - TravelLog: `boss` entries get `damage`, `healing` and `dps`; sessions and `stats` get totals, shown in the Sessions view and `/tl sessions`.
  - API: `C_DamageMeter.GetCombatSessionFromID`/`FromType` by `Enum.DamageMeterType` (`DamageDone`, `HealingDone`, `Absorbs`, `Interrupts`, `Dispels`, `DamageTaken`, `Deaths`, ...), taking the source with `isLocalPlayer`; `GetCombatSessionSourceFromID` for your per-spell breakdown. `GetAvailableCombatSessions` lists the meter's sessions; events `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `DAMAGE_METER_RESET`.
  - The getters are `SecretWhenInCombat`: read once out of combat (`PLAYER_REGEN_ENABLED`), before the meter resets or drops the session.
  - No biggest single hit: the meter has per-spell totals (`totalAmount`, `overkillAmount`), not single hits. Top spell by total is the closest.
  - Open: whether sessions are recorded with the meter turned off (`damageMeterEnabled` CVar, `C_DamageMeter.IsDamageMeterAvailable()`), and how meter sessions line up with boss pulls.

- **Camping.** Logs each camp at a campfire next to `rest`, and counts them.
  - TravelLog `Travel.lua`: a `camp` entry with place and length, and `stats.camps` and `campTime`.
  - API: `C_UnitAuras.GetPlayerAuraBySpellID` on `UNIT_AURA` for Camp Benefits (spell 1229741); Welcoming Campfire is spell 1229739.
  - Neither ID is in Blizzard's UI code; confirm both in game, and whether camping also makes you rest (`IsResting()`), which would log a `rest` as well.
  - The aura lookup can be secret when auras are restricted (`SecretWhenUnitAuraRestricted`); pass it through `ns.Clean`.

- **Player notes and ratings.** An account-wide note and a behavior and skill rating per player, shown in the Players tab and the player's tooltip.
  - TravelLog_Group: Group's file is per character, so this needs a new account-wide `SavedVariables` keyed by `Name-Realm`, like `players`.
  - Set from the Players tab (an edit box) and with `/grouped note` and `/grouped rate`.
  - The tooltip line (`OnUnitTooltip`) shows only for players grouped with on this character; notes should show for any noted player.
  - Open: the rating scale; renamed or transferred characters lose their note unless matched by GUID.

## Maybe

- **Friends' trails across reloads.** [TravelLog_Share](TravelLog_Share/) keeps friends' trails in memory, so a reload or relog on your side loses what you had, and catching up is capped at 150 points. Saving them in `TravelLogShareDB` would keep them, at about 100 KB per hour of a friend's movement; they'd need pruning.
- **Kills by tap.** Count kills of mobs you tapped when someone outside your party lands the blow; TravelLog_Kills counts only `PARTY_KILL`. `UNIT_DIED` gives just a GUID, and `UnitTokenFromGUID` and `UnitIsTapDenied` need a unit token (target, nameplate), so many kills are missed. Small gain.
- **Milestone announcements.** Post level-ups and other milestones to guild or party. `C_ChatInfo.SendChatMessage` has restrictions (`HasRestrictions`); check which channels work without a key press.
- **Stats by level range.** Only log entries and sessions (`level`, `levelEnd`) can be filtered: `stats` are running totals with no time, so distance and zone time would need per-session counters.

## Won't do

- **Personal bank item log.** TravelLog logs items moved to and from the guild bank, but not the personal bank; decided against.
