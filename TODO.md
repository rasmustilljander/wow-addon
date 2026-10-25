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

- **Map replay.** Play back your trail on the world map: a time slider with play, pause, step and speed draws the trail and markers up to that moment, with your level and gear then.
  - TravelLog_Path: drawing already limits each source to `since`/`before` (`Map.lua`), so the slider moves `before`. Playing forward can draw incrementally; stepping back needs a full redraw.
  - Level from the log's `level` entries; gear from `equip` entries, which TravelLog logs only the first time an item is worn, so re-equipped items are missed.
  - The controls are a frame of our own, not a child of the world map, so the map stays click-through and untainted.
  - Risk: redraw cost on long ranges; check with `tests/TravelLog/stress.lua`.

- **Trail fade.** Older parts of the map trail get fainter and thinner, so the recent path and its direction stand out.
  - Age is played time (logged in on that character), counted back from the end of the shown range: now, or the end of a calendar day. A night logged out doesn't fade the trail, and each alt's trail fades from where it left off.
  - Default shape: full for 15 min; opacity eases to 50% by 2 h; width eases to 60% from 1 h to 3 h; the floor after that. Smoothstep curves overlapping, so there's no visible knee where one fade stops and the other starts.
  - Width has a floor of 1 screen pixel; thinner lines flicker. Alts' trails (1.5 px, 0.7 alpha) fade by the same factors.
  - Fades your trail and jump dots; milestone markers (deaths, loot, notes) don't.
  - Settings: `trailFade = { on, alphaFrom, alphaTo, alpha, widthFrom, widthTo, width }` in minutes and percent. Opacity no lower than 10%, width 30%.
  - Commands: `/tl fade on|off|default`, `/tl fade opacity 15-120 50`, `/tl fade width 60-180 60`. Window buttons `off`, `1h`, `3h`, `6h`, `12h` scale the default shape (`3h` is the default).
  - TravelLog_Path `Map.lua`: each source gets a played clock (sessions oldest first, each session's length; the current one runs to now, an unclosed old one to its last record). Each line slot keeps its base color, base width and clock; curve pieces interpolate between their two points' clocks.
  - While the map is open, only the current session's clock moves: every 60 s restyle those lines with `SetColorTexture`/`SetThickness`, no new geometry, skipping lines already at the floor. Fresh lines go on sublevel 1, so where the trail crosses itself the recent path is on top.
  - The Colors tab's opacity is the full one; the fade multiplies it.
  - Map replay gets a fading tail for free: moving `before` moves the end of the range.
  - Check in game: 50% opacity on bright zones (Tanaris, Winterspring), the ghost color (0.6 alpha) at its floor, and restyle cost with `tests/TravelLog/stress.lua`.

- **Distance by form.** Distance per shapeshift form and in stealth, next to the per-mode totals.
  - TravelLog `ns.FLAGS`: stealth as bit 64, the form as a number in the bits above (form × 128). `ns.HasFlag` ignores higher bits, so older readers still work.
  - TravelLog_Path `Track.lua`: a new `stats.formDistance` by `cat`, `bear`, `travel`, `aquatic`, `moonkin`, `ghostwolf`, `stealth`; `stats.distance` stays as it is.
  - API: `GetShapeshiftFormID()` (undocumented; Blizzard's UI calls it), `IsStealthed()`.
  - Form IDs: Blizzard's Cata constants have cat 1, travel 3, aquatic 4, bear 5, Ghost Wolf 16, moonkin 31 and 35; the Camelot ones list none, so confirm in game.
  - A form change changes the flags, which records a path point, so shifting often adds points.

- **Time per zone by state.** Per zone, how long you were in combat, dead or a ghost, AFK, on flights and grouped.
  - TravelLog `Travel.lua`: `CountZoneTime` (every second) also adds to `stats.zoneStateTime[state][zone]`; `stats.zoneTime` stays the total.
  - States overlap (AFK while grouped), so each is its own counter, not a split of the total.
  - API: `UnitAffectingCombat`, `UnitIsDeadOrGhost`, `UnitIsAFK` (secret in chat lockdown), `UnitOnTaxi`, `IsInGroup` (undocumented; Blizzard's UI calls it).

- **Player notes and ratings.** An account-wide note and a behavior and skill rating per player, shown in the Players tab and the player's tooltip.
  - TravelLog_Group: Group's file is per character, so this needs a new account-wide `SavedVariables` keyed by `Name-Realm`, like `players`.
  - Set from the Players tab (an edit box) and with `/grouped note` and `/grouped rate`.
  - The tooltip line (`OnUnitTooltip`) shows only for players grouped with on this character; notes should show for any noted player.
  - Open: the rating scale; renamed or transferred characters lose their note unless matched by GUID.

## Maybe

- **Kills by tap.** Count kills of mobs you tapped when someone outside your party lands the blow; TravelLog_Kills counts only `PARTY_KILL`. `UNIT_DIED` gives just a GUID, and `UnitTokenFromGUID` and `UnitIsTapDenied` need a unit token (target, nameplate), so many kills are missed. Small gain.
- **Milestone announcements.** Post level-ups and other milestones to guild or party. `C_ChatInfo.SendChatMessage` has restrictions (`HasRestrictions`); check which channels work without a key press.
- **Stats by level range.** Only log entries and sessions (`level`, `levelEnd`) can be filtered: `stats` are running totals with no time, so distance and zone time would need per-session counters.

## Won't do

- **Personal bank item log.** TravelLog logs items moved to and from the guild bank, but not the personal bank; decided against.
