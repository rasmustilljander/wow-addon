# wow-addon

My addons for **World of Warcraft: Forever**, one per folder.

| Addon | What it does |
| --- | --- |
| [TravelLog](TravelLog/) | Records loot, vendor trades, money, flights, deaths, quests and more. |
| [TravelLog_Path](TravelLog_Path/) | Records your path and jumps and draws the trail on the world map. Needs TravelLog. |
| [TravelLog_Nodes](TravelLog_Nodes/) | Pins looted chests, herbs and ore on the world map with when you last looted each. Needs TravelLog. |
| `TravelLog_Archive` | Load-on-demand storage for older TravelLog and TravelLog_Path history. Install it with TravelLog. |
| [TravelLog_Kills](TravelLog_Kills/) | Records every kill per mob (count, when, where), with map pins and tooltip counts. TravelLog optional. |
| [KillXP](KillXP/) | Shows a mob's kill XP (rested and party bonus included) and kills to level on its tooltip. |
| [CVarBrowser](CVarBrowser/) | A window to search, bookmark and change CVars, with descriptions of well-known ones. |

## Installing

Copy or link the addon folders into `World of Warcraft/<forever folder>/Interface/AddOns/`. The Forever folder sits next to `_retail_` (during the beta it was `_forever_beta_`). Linking lets `git pull` update the addons; on Windows, in a command prompt:

```
for /d %d in ("C:\path\to\wow-addon\TravelLog*" "C:\path\to\wow-addon\KillXP" "C:\path\to\wow-addon\CVarBrowser") do mklink /J "C:\Program Files (x86)\World of Warcraft\<forever folder>\Interface\AddOns\%~nxd" "%d"
```

Then `/reload` and make sure the addons are enabled on the character select screen.

## Game version

The `.toc` files target Forever 1.60.1 (`## Interface: 16001`). If a patch marks them out of date, get the new number with `/dump select(4, GetBuildInfo())` and update the `## Interface` lines.

## Tests

`pip install lupa`, then `python tests/run.py` runs the addons against a fake client. See [tests/README.md](tests/README.md).
