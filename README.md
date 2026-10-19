# wow-addon

My personal addons for **World of Warcraft: Forever**. Each addon lives in its own folder.

| Addon | What it does |
| --- | --- |
| [TravelLog](TravelLog/) | Records your travels: your path, every jump, loot, vendor trades, deaths, quests and more. It draws your trail on the world map and shows when you last looted each chest, herb and ore. |
| `TravelLog_Archive` | Storage for TravelLog's older history, so the file loaded at every login stays small. Install it with TravelLog. |
| [KillXP](KillXP/) | Shows on a mob's tooltip how much XP a kill gives you, counting rested XP and party bonus, and how many kills you need to level up. |
| [TravelLog_Kills](TravelLog_Kills/) | Records every mob you kill: how many times, when and where. Pins kill spots on the world map and shows your kill count on mob tooltips. Works with or without TravelLog. |

## Installing

Copy (or link) the addon folders into the `Interface/AddOns` folder of your Forever client. Inside your World of Warcraft directory the Forever client has its own folder next to `_retail_` and `_classic_era_` (check the name your launcher created; during the beta it was `_forever_beta_`):

```
World of Warcraft/<forever folder>/Interface/AddOns/TravelLog/TravelLog.toc
World of Warcraft/<forever folder>/Interface/AddOns/TravelLog_Archive/TravelLog_Archive.toc
World of Warcraft/<forever folder>/Interface/AddOns/KillXP/KillXP.toc
World of Warcraft/<forever folder>/Interface/AddOns/TravelLog_Kills/TravelLog_Kills.toc
```

Linking means a `git pull` updates the addons in place. On Windows, this links every addon folder at once (run it in a command prompt, with your own paths):

```
for /d %d in ("C:\path\to\wow-addon\TravelLog*" "C:\path\to\wow-addon\KillXP") do mklink /J "C:\Program Files (x86)\World of Warcraft\<forever folder>\Interface\AddOns\%~nxd" "%d"
```

Then `/reload` in game, or restart, and make sure the addons are enabled under AddOns on the character select screen.

## Game version

The `.toc` files target Forever patch 1.60.1 (`## Interface: 16001`). If a later patch marks the addons as out of date, check the current number in game with `/dump select(4, GetBuildInfo())` and update the `## Interface` lines.

## Tests

The addons can be run outside the game against a fake of the game's API:

```
pip install lupa
python tests/run.py
```

See [tests/README.md](tests/README.md) for what's covered and how to write tests.
