# Tests

The addons can't be run outside the game, so these tests run them against a fake of the WoW: Forever addon API ([`wowmock.lua`](wowmock.lua)) in a real Lua 5.1, the same Lua version the game uses. A test plays through something (walking, looting, a vendor visit, a reload) and checks what the addon recorded.

## Running

You need Python 3 and [lupa](https://pypi.org/project/lupa/), which bundles Lua 5.1:

```
pip install lupa
python tests/run.py                            # everything
python tests/run.py tests/TravelLog/loot.lua   # one file
```

Each test file runs in a fresh Lua state. The output lists every file with its passed/failed count and any failing checks, and the exit code is non-zero if anything failed:

```
tests/TravelLog/adventure.lua
  72 passed, 0 failed
tests/TravelLog/loot.lua
  32 passed, 0 failed
...
150 passed, 0 failed
```

## What's here

| File | |
| --- | --- |
| `run.py` | Finds and runs the tests (`tests/<Addon>/*.lua`). |
| `wowmock.lua` | The fake client: frames and events, the player's position and state, loot windows, merchants, flights, the world map, SavedVariables and load-on-demand addons. |
| `TravelLog/adventure.lua` | A short adventure with TravelLog, TravelLog_Path and TravelLog_Nodes: path, jumps, loot, vendors, money, quests, a flight, a death, the map trail, the companions' commands and a reload. |
| `TravelLog/loot.lua` | Loot sources and roll wins. |
| `TravelLog/storage.lua` | Per-character files, migration from earlier versions, rotation (TravelLog_Path's too) into the archive addon, TravelLog on its own and moving its old path and nodes out when the companions are installed. |
| `TravelLog/stress.lua` | Six hours of non-stop movement: speed, file size, map drawing. Prints its measurements. |
| `TravelLog_Nodes/nodes.lua` | Remembered chests and gathering nodes, their map pins and tooltips, moving old nodes out of TravelLog's file, wiping. |
| `KillXP/tooltip.lua` | The XP formula, rested and party bonuses, kills to level, the tooltip lines, and learning real XP from kills. |
| `TravelLog_Kills/kills.lua` | Kills from `PARTY_KILL` and the XP chat line, party and pet kills, secret GUIDs, tooltips, map pins, commands, a reload. |

## Writing a test

A test is a Lua file that drives the fake client through the global `M` and calls `check(condition, message)`:

```lua
local ns = M.Login()                -- load the installed addons and log in
M.x, M.wb = M.x + 0.01, M.wb - 40   -- walk a bit east...
M.tick(5)                           -- ...for 5 seconds
JumpOrAscendStart()                 -- press jump
check(ns.stats.jumps == 1, "jump counted")
ns = M.Reload()                     -- save SavedVariables to text, log out, log back in
check(TravelLogCharDB.sessions[1].stop, "session closed on logout")
```

Useful parts of `M`:

| | |
| --- | --- |
| `M.Login()`, `M.Logout()`, `M.Reload()` | Log in and out. Logging out writes each loaded addon's SavedVariables to text (an addon that wasn't loaded keeps its old text, like in the game) and throws away all addon state, hooks and frames. |
| `M.fire(event, ...)` | Send a game event. Registering an event the fake doesn't know errors, like the real client. |
| `M.tick(n)`, `M.advance(s)`, `M.frame()` | Run `C_Timer` tickers and timers for n seconds, move the clock, run one `OnUpdate` frame. |
| `M.cast(spellID, target)`, `M.lootAll(take)` | Cast a spell (SENT, then SUCCEEDED) and loot a window from `M.loot`. |
| `M.x`, `M.y`, `M.wa`, `M.wb`, `M.mapID`, `M.zone`, `M.subzone`, `M.mounted`, `M.taxi`, `M.money`, ... | The player's state, read by the fake API. Set `M.x = nil` for "inside a dungeon". |
| `M.units.target = { name, guid, hostile, level, ... }` | Other units (`classification`, `dead`, `tapped`, `trivial`, `player`, `pet`). |
| `M.hover(unit)` | Show a unit's tooltip, running addons' tooltip post-calls; returns its lines without color codes. |
| `M.xp`, `M.xpMax`, `M.rested`, `M.group`, `M.instance` | Experience, rested pool, the other group members' units and the instance type. |
| `M.guidNames[guid] = name` | Units the client still knows by GUID (`UnitNameFromGUID`) after they're gone. |
| `M.secrets[value] = true` | Make a value "secret", like the Midnight-era client does in dungeons. |
| `M.installed`, `M.disabled` | Which addon folders the client knows about (TravelLog, TravelLog_Path and TravelLog_Nodes unless a test changes it), and which are switched off. |
| `M.viewMap`, `M.mapOverlay(level)`, `M.shown(pool)` | What the world map shows, an addon's frame on it (the newest, or the one at a frame level: TravelLog_Path 2010, TravelLog_Kills 2011, TravelLog_Nodes 2012), and the visible lines/textures/frames. |
| `M.out`, `M.errors` | Everything printed to chat, and Lua errors reported through `geterrorhandler`. Errors count as failures. |
| `M.saved`, `M.savedSize(addon, perCharacter)` | The saved files' text and size. |

When an addon starts using an API or event the fake doesn't have, add it to `wowmock.lua`.

## What the fake can't tell you

It only knows what's written in `wowmock.lua`. A passing test means the addon does what it should **if** the real client behaves like the fake. Check new APIs against Blizzard's own Forever UI code; see [`.claude/skills/addon-tests/SKILL.md`](../.claude/skills/addon-tests/SKILL.md) for how.
