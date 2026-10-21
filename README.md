# wow-addon

My addons for **World of Warcraft: Forever**, one per folder.

| Addon | What it does |
| --- | --- |
| [TravelLog](TravelLog/) | Records loot, vendor trades, money, flights, deaths, quests and more, with a window from the minimap. |
| [TravelLog_Path](TravelLog_Path/) | Records your path and jumps and draws the trail, and your alts', on the world map. Needs TravelLog. |
| [TravelLog_Nodes](TravelLog_Nodes/) | Pins chests, herbs and ore any of your characters looted on the minimap and world map, with when and by whom. Needs TravelLog. |
| [TravelLog_Share](TravelLog_Share/) | Shares your nodes, and on request your log, with players you allow, and records who asked. Needs TravelLog. |
| `TravelLog_Archive` | Load-on-demand storage for older TravelLog and TravelLog_Path history. Install it with TravelLog. |
| [TravelLog_Kills](TravelLog_Kills/) | Records every kill per mob (count, when, where), with map pins and tooltip counts. TravelLog optional. |
| [TravelLog_NPCs](TravelLog_NPCs/) | Remembers vendors, trainers and other NPCs with what they sell: searchable, pinned on the minimap and world map, and named on item tooltips. TravelLog optional. |
| [TravelLog_Group](TravelLog_Group/) | Records every player you group with (how often, when, how long, where), searchable in a window tab. TravelLog optional. |
| [KillXP](KillXP/) | Shows a mob's kill XP (rested and party bonus included) and kills to level on its tooltip. |
| [CVarBrowser](CVarBrowser/) | A window to search, bookmark and change CVars, with descriptions of well-known ones. |
| [JunkToss](JunkToss/) | Right-click its minimap button to throw away the cheapest grey, or anything on its allowlist. |
| [ItemCount](ItemCount/) | Shows on item tooltips how many each character has in bags, bank, mail and on the AH. |

## Installing

Copy or link the addon folders into `World of Warcraft/<forever folder>/Interface/AddOns/`. The Forever folder sits next to `_retail_` (during the beta it was `_forever_beta_`). Linking lets `git pull` update the addons; on Windows, in a command prompt:

```
for /d %d in ("C:\path\to\wow-addon\TravelLog*" "C:\path\to\wow-addon\KillXP" "C:\path\to\wow-addon\CVarBrowser" "C:\path\to\wow-addon\JunkToss" "C:\path\to\wow-addon\ItemCount") do mklink /J "C:\Program Files (x86)\World of Warcraft\<forever folder>\Interface\AddOns\%~nxd" "%d"
```

Or copy them with `./deploy.sh` (needs bash and rsync). Copy `.env.example` to `.env` and set `WOW_ADDONS_DIR` to the AddOns folder, or to `user@host:path` for another machine. `./deploy.sh` replaces every addon folder there with the repo's copy, `./deploy.sh TravelLog KillXP` only those, and `-n` first shows what would change. Other addons and SavedVariables aren't touched; linked folders are skipped.

Then `/reload` and make sure the addons are enabled on the character select screen.

## Game version

The `.toc` files target Forever 1.60.1 (`## Interface: 16001`). If a patch marks them out of date, get the new number with `/dump select(4, GetBuildInfo())` and update the `## Interface` lines.

## Tests

`pip install lupa`, then `python tests/run.py` runs the addons against a fake client. See [tests/README.md](tests/README.md).
