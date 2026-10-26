# TravelLog NPCs

Remembers the NPCs you talk to in WoW: Forever, where they stand and what they sell. It pins them on the minimap and world map, names vendors on item tooltips, and lets you search NPCs by name, title, place or item. All your characters share the same NPCs. A companion to [TravelLog](../TravelLog/) that also works on its own.

## What it records

An NPC is saved or updated each time you open one of these windows with it:

| Window | Kind |
| --- | --- |
| Vendor | vendor, or repair vendor if it can repair |
| Trainer | trainer |
| Flight map | flight master |
| Bank | banker |
| Making an inn your home | innkeeper |
| Auction house | auctioneer |
| Stable | stable master |

`/npcs add` saves your target as an other. Kinds add up: an innkeeper you've also bought from is both.

For each NPC: name, title (`General Supplies`), kinds, zone, subzone, map coordinates (your position, not the NPC's) and your last visit. Dungeons have no coordinates, so no pins.

For vendors, every item on sale with its price, stack size, whether it's limited supply, and any currencies or items it costs (honor, marks, tokens). With the vendor's filter on **All**, each visit replaces the list; with a class filter, items are only added.

## Item tooltips

Items you've seen for sale list up to 3 vendors, those in your zone first, then by name:

```
Refreshing Spring Water
Sold by Brog Hamfist (Goldshire)       25c for 5
Sold by Innkeeper Farley (Goldshire)   20c for 5
and 2 more vendors
```

A price can read `1g 20s, limited` or `2g + 30 Warsong Gulch Mark of Honor`. `other currency` (or `2g + more`) means the client didn't say which.

## Minimap and world map

Saved NPCs within the minimap's range show as dots, following its rotation. The world map shows them on the map they were saved on, so Stormwind's NPCs are on the Stormwind map, not Elwynn Forest's. [OpenMap](../README.md#openmap)'s map also shows those of zones and cities around it that fill enough of the view. Hover a dot for the NPC's name, title, kinds, how many items it sells and your last visit.

An NPC with several kinds is drawn as the first of these:

| Kind | Color |
| --- | --- |
| Trainer | green |
| Flight master | light blue |
| Innkeeper | pink |
| Banker | purple |
| Auctioneer | orange |
| Stable master | brown |
| Repair vendor | white |
| Vendor | gold |
| Other | grey |

Turn dots off for all NPCs (minimap or world map), one kind, or one NPC. A kind is the color it's drawn as, so hiding vendors keeps innkeepers that also sell.

## Window

With TravelLog, [its window](../TravelLog/README.md#window) gets an **NPCs** tab: every NPC by name with its subzone (or zone), and a search box that matches name, title, zone, subzone or any item it sells. Click an NPC for its title, kinds, place, last visit, a **Pins on the maps** checkbox and its items with prices (hover one for its tooltip). Click it again for a checkbox per kind. Totals show how many NPCs and items you know, and Settings has **NPCs on the minimap** and **NPCs on the world map**.

## Commands

| Command | |
| --- | --- |
| `/npcs` | How many NPCs and items, which pins are on, and the commands |
| `/npcs <text>` | NPCs whose name, title, zone, subzone or items contain the text (up to 15), with where they are and the matching item's price |
| `/npcs add` | Save your target |
| `/npcs forget <name>\|target` | Delete a saved NPC |
| `/npcs hide <name>\|target`, `/npcs show ...` | One NPC's pins. Partial names work if only one NPC matches. |
| `/npcs minimap on\|off`, `/npcs map on\|off` | All pins on the minimap or world map (default on) |
| `/npcs kind <kind> on\|off` | One kind's pins: `trainer`, `flight`, `innkeeper`, `banker`, `auctioneer`, `stable`, `repair`, `vendor`, `other` |
| `/npcs kinds` | Which kinds are on |
| `/npcs window` | Open the [NPCs tab](#window) (needs TravelLog) |

`/tln` works too.

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_NPCs.lua`, by NPC ID:

```lua
TravelLogNPCsDB = {
  version = 1,
  settings = { minimap = true, worldMap = true, hideKinds = { trainer = true } },
  npcs = {
    [1265] = { name = "Brog Hamfist", title = "General Supplies", kinds = { vendor = true, repair = true },
      map = 1429, x = 42.0, y = 65.0, zone = "Elwynn Forest", subzone = "Goldshire", seen = 1760000000,
      hidden = true,                                         -- /npcs hide
      items = {
        [159] = { name = "Refreshing Spring Water", price = 25, stack = 5 },
        [2528] = { name = "Fine Longsword", price = 12000, limited = true },
        [19549] = { name = "Sentinel's Blade", special = true,                -- costs more than money
          cost = { { name = "Honor Points", count = 450 }, { name = "Warsong Gulch Mark of Honor", count = 30 } } },
      } },
  },
}
```

`x`, `y` are map coordinates 0–100. `price` (copper) and `cost` (other currencies and items) are for `stack` items when that's set. `special` without `cost` is a cost the client didn't reveal.

## Limits

- One position per NPC: the last place you talked to it. NPCs that share an ID (some guards) are one NPC.
- Gossip-only NPCs (quest givers, guards) aren't saved unless you `/npcs add` them.
- Untested in the live game; written against the Forever 1.60.1 API documentation and tested against a fake client ([tests](../tests/README.md)).
