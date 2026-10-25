# TODO

## Data versions

TravelLog's account and character files have a data version (`ns.DATA_VERSION` in `TravelLog/Core.lua`, now 1), and so does KillXP's file (`KillXP/XP.lua`, now 1). Each refuses versions it doesn't know. Still to do:

- **Conversions.** When a layout change means older TravelLogs would misread a file, bump `DATA_VERSION` and add a `CONVERT` step from the old version (in TravelLog an `account` and/or `char` function), or list it in `COMPATIBLE` if it reads as it is. Test each step with a saved file of the old version.
- **Companion files.** They aren't checked: Kills, NPCs and Group save `version = 1` without reading it; Path, Nodes and Share save none.

## Planned

- **TravelLog export.** The log and totals can't be copied out of the game; only the raw SavedVariables file has them. Add a command or button that opens a copyable text box (CSV or similar) with the log or the totals. A text box because addons can't write files of their own.

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
