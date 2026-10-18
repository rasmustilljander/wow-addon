# wow-addon

My personal addons for **World of Warcraft: Forever**. Each addon lives in its own folder.

| Addon | What it does |
| --- | --- |
| [TravelLog](TravelLog/) | Records your travels: your path, every jump, loot, vendor trades, deaths, quests and more, and draws your trail on the world map. |

## Installing

Copy (or link) an addon's folder into the `Interface/AddOns` folder of your Forever client. Inside your World of Warcraft directory the Forever client has its own folder next to `_retail_` and `_classic_era_` (check the name your launcher created; during the beta it was `_forever_beta_`):

```
World of Warcraft/<forever folder>/Interface/AddOns/TravelLog/TravelLog.toc
```

Linking means a `git pull` updates the addon in place. On Windows, from a command prompt:

```
mklink /J "C:\Program Files (x86)\World of Warcraft\<forever folder>\Interface\AddOns\TravelLog" "C:\path\to\wow-addon\TravelLog"
```

Then `/reload` in game, or restart, and make sure the addon is enabled under AddOns on the character select screen.

## Game version

The `.toc` files target Forever patch 1.60.1 (`## Interface: 16001`). If a later patch marks an addon as out of date, check the current number in game with `/dump select(4, GetBuildInfo())` and update the `## Interface` line.
