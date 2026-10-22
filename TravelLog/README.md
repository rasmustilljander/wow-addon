# TravelLog

Records your travels in WoW: Forever so you can retrace them: loot, vendor trades, money, flights, deaths, quests and more.

Optional companions, each its own folder:

- [TravelLog_Path](../TravelLog_Path/): your path and jumps, drawn on the world map. Needs TravelLog.
- [TravelLog_Nodes](../TravelLog_Nodes/): looted chests, herbs and ore, pinned on the minimap and world map. Needs TravelLog.
- `TravelLog_Archive`: storage for older history (see [Where the data is](#where-the-data-is)). Install it with TravelLog.
- [TravelLog_Kills](../TravelLog_Kills/): every kill per mob. Works on its own too.
- [TravelLog_NPCs](../TravelLog_NPCs/): NPCs you've talked to and what they sell, on the maps and item tooltips. Works on its own too.
- [TravelLog_Group](../TravelLog_Group/): every player you group with, and when. Works on its own too.
- [TravelLog_Share](../TravelLog_Share/): your nodes, and on request your log, for players you allow. Needs TravelLog.

## What it records

Every entry is stamped with character, time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Loot** | Corpses, pickpockets, chests, herbs, ore, fishing and containers: items taken, coins and source (name, NPC/object ID, and the spell for herbs, ore, chests, skinning and Pick Pocket). |
| **Other items** | Quest rewards, crafts, roll wins (with your roll), trades and mail, and other items that arrive without a loot window. |
| **Rolls** | Group loot rolls you lost or passed on: your choice and roll, and who won with what. |
| **Items out** | Items you hand over in a trade, mail, put up for auction (with bid and buyout) or destroy. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every gold change with a reason: loot, vendor, flight, quest, training, mail, COD, trade, auction (buys, and sales paid by mail with the item), auction deposit, bank slot, account bank, guild bank, barber, talent reset, stable slot or other. A bank slot also gets its own entry. |
| **Trades and mail** | Money and items from a trade, both ways, are saved with the other player (`partner`, as `Name-Realm` for another realm); from mail, with the mail's sender (`sender`); mail you send and its postage, with the recipient (`recipient`). |
| **Travel** | Zone and subzone changes (first visits marked), flights (from, to, cost, duration), hearthstones and other teleports (from, to and the spell or item), summons (from, to and who), boat and zeppelin rides (from, to, duration), dungeons and raids (name, type, difficulty, and time inside when you leave), hearthstone binds, screenshots (with the file's name, to match pictures to the log). |
| **Life** | Deaths (what you fought, and drowning, fatigue or a long fall), spirit releases, revivals (corpse run, spirit healer, another player or a soulstone and the like, with how long you were dead and the durability lost), level-ups (with how long the level took), quests accepted, completed, abandoned and failed (and whether time ran out), kills that gave XP, discoveries. |
| **PvP** | Duels (opponent, won, lost or no winner, whether the loser fled, who challenged), honorable kills (victim, rank, honor) and honor awards. |
| **Sessions** | Each login or reload: start and end (time and place), level, money and the experience gained. |
| **Progress** | Spells, abilities and recipes learned (with rank, trainer and cost), new skills, every 25 points of a skill, talent points spent (talent, tree, new rank and your level) and taken back, flight paths found, reputation standings reached, the first ride on each mount, beasts tamed (name, level and family), and the first time you put on each piece of gear (slot, item level, quality and what it replaced; not shirts or tabards). |

## Window

Pick TravelLog from the addons dropdown on the minimap, or type `/tl`, for a window with these tabs:

- **Totals**: numbers under Travel, Loot (money in and out by reason, largest first), Life (time played too) and Log. **Character**'s `<` and `>` step from the character you're on through your other characters to all of them added up (a place several visited counts once). Rows only the character you're on has (time played, log entries, and the Kills and Group rows) show for that character.
- **Settings**: the companions' map options and Path's interval.
- **History**: what's still in the character file, newest first, in views:
  - **Events**: every event. Filter by Travel, Loot, Trade, Life (PvP too) or Progress, or search event types, descriptions, names, places, dates and saved fields. Search `death` to list deaths with their level, cause, fight target and location, `revival` for how you came back, or `level` for each level-up and how long it took.
  - **Sessions**: each session's length, levels, where it started and ended, money and experience gained (per hour once it's 10 minutes long), and its quests done and failed, XP kills and deaths.
  - **Kills**, with [TravelLog_Kills](../TravelLog_Kills/README.md#window): every mob you've killed and where.
- **NPCs**, with [TravelLog_NPCs](../TravelLog_NPCs/README.md#window): search NPCs by name, place or what they sell.
- **Players**, with [TravelLog_Group](../TravelLog_Group/README.md#window): everyone you've grouped with and each time.
- **Colors**, with [TravelLog_Path](../TravelLog_Path/README.md#world-map): the trail's and markers' colors on the world map.
- **Sharing**, with [TravelLog_Share](../TravelLog_Share/README.md#the-sharing-tab): who you share with and follow, and their logs.

Companions add their rows to the matching section.

## Commands

| Command | |
| --- | --- |
| `/tl` | Open or close the window |
| `/tl stats [all\|name]` | Totals (and time played) for this character, all of them added up, or another by `Name` or `Name-Realm` |
| `/tl log [n] [search]` | The last matching events (default 15); for example, `/tl log 20 death` |
| `/tl sessions [n]` | The last n sessions (default 10), as in the Sessions view |
| `/tl archive [now]` | Archive size; `now` archives old history right away |
| `/tl wipe confirm` | Delete everything for this character, including its archive and its Path, Nodes and Share data. Kills and Group have their own `wipe confirm`. |

`/travellog` works too. TravelLog_Path adds `/tl jumps`, `/tl trail` and `/tl interval`, TravelLog_Nodes adds `/tl nodes`, and both add lines to `/tl stats`. TravelLog_Share adds `/tl share`, which opens its tab.

## Where the data is

WoW writes SavedVariables only on logout or `/reload`, so a crash loses everything since the last one. `/reload` now and then on long sessions.

| File under `WTF/Account/<ACCOUNT>/` | Contents |
| --- | --- |
| `SavedVariables/TravelLog.lua` | Settings (the companions' too, and the window's `point`), each character's profile and totals |
| `<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's log, sessions, quests, skills, talents, mounts, gear and the instance you're in |
| `SavedVariables/TravelLog_Path.lua` | Every character's path, for TravelLog_Path |
| `SavedVariables/TravelLog_Nodes.lua` | Every character's nodes, for TravelLog_Nodes |
| `SavedVariables/TravelLog_Archive.lua` | Older history of all characters |

**Rotation.** The path grows about 100 KB per hour of movement. When a character's log, sessions and path pass about 3 MB, the next login moves everything older than 10 days into the archive (nodes and totals stay). The archive is a separate load-on-demand addon because each addon gets only one account-wide file. It's read only for the `all` trail range, `/tl archive now` and rotation, so its size doesn't slow down logins. Without it installed, history stays in the character files and TravelLog says so when it tries to rotate.

Before 0.3, the path and nodes lived in TravelLog's character file. The first login with TravelLog_Path or TravelLog_Nodes installed moves them into that addon's file.

The character file:

```lua
TravelLogCharDB = {
  log = {   -- oldest first
    { type = "loot", time = 1760000000, zone = "Elwynn Forest", subzone = "Goldshire",
      map = 1429, x = 42.1, y = 65.3, source = "Peacebloom", sourceType = "GameObject",
      sourceID = 1618, via = "Herb Gathering", lastHere = 1759998200,
      items = { { item = "|cffffffff|Hitem:2447:...|h[Peacebloom]|h|r", count = 2 } } },
    ...
  },
  sessions = {   -- one per login or reload
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, money = 10000, moneyEnd = 12500, xp = 5600,
      zone = "Elwynn Forest", subzone = "Goldshire", map = 1429, x = 42.1, y = 65.3,   -- where you logged in
      zoneEnd = "Stormwind City", subzoneEnd = "Old Town", mapEnd = 1453, xEnd = 75.2, yEnd = 61.8 },  -- and out
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ..., abandoned = ..., failed = ... } },  -- last time of each
  skills = { [129] = 75 },           -- skill ID -> rank, to tell new skills and milestones
  talents = { [7001] = { [101] = 3 } },  -- loadout ID -> talent node ID -> rank, to tell points spent
  mounts = { [458] = 1760000000 },   -- mount spell ID -> first ride
  instance = { name = "The Deadmines", kind = "dungeon", id = 36, inside = 600, since = ... },  -- while you're in one
  gear = { [25] = 0, [2361] = 1760000000 },  -- item ID -> first put on (0: worn when gear recording began)
}
```

Log entry types: `area`, `loot`, `receive`, `roll`, `buy`, `sell`, `buyback`, `repair`, `give` (trade), `send` (mail), `post` (auction), `destroy`, `money`, `bankslot`, `flight`, `landed`, `hearth`, `teleport`, `summon`, `board`, `disembark`, `instance`, `instanceleave`, `bind`, `screenshot`, `death`, `release`, `revive`, `level`, `quest`, `questdone`, `questabandon`, `questfail`, `kill`, `discover`, `duel`, `honorkill`, `honor`, `spell`, `skill`, `skillup`, `talent`, `talentreset`, `taxipath`, `standing`, `mount`, `tame`, `equip`. Fields the game doesn't reveal (coordinates in dungeons) are left empty. A `questfail` entry has `reason = "time"` when the quest's timer ran out.

A `money` entry has `amount` (negative when spent), `reason` (`loot`, `vendor`, `flight`, `quest`, `training`, `mail`, `cod`, `trade`, `auction`, `deposit`, `bankslot`, `bank`, `guildbank`, `barber`, `respec`, `stable` or `other`) and `balance`, plus `partner`, `sender` or `recipient` for trades and mail and `item` for an auction sale. A `bankslot` entry has `bank` (`character` or `account`), `slot` (its number in that bank) and `price`.

Some types have more:

| Type | Fields |
| --- | --- |
| `hearth`, `teleport` | `from`, `to` (place names); `spell` and `via` (its name) when your cast did it |
| `summon` | `from`, `to`, `by` (the summoner) |
| `board` | none: it's stamped where the ride started |
| `disembark` | `from`, `to`, `seconds` on board |
| `instance` | `name`, `kind` (`dungeon`, `raid`, `battleground`, `arena` or `scenario`), `difficulty`, `size`, `id` |
| `instanceleave` | `name`, `kind`, `seconds` inside |
| `screenshot` | `file`: the name the game gives the picture, without its extension (`WoWScrnShot_102226_143005`: local date and time it was taken) |
| `level` | `played`: seconds played in all. `took`: seconds played at the level before. |
| `death` | `target`: the hostile unit you had targeted. `level`. `cause`: `drowning`, `fatigue` or `falling`, when known. |
| `revive` | `how`: `corpse`, `spirithealer`, `player` or `selfres`, when known. `by`: who resurrected you. `spell`: the self-resurrection used (Soulstone, Reincarnation, ...). `sickness`: `true` with resurrection sickness. `took` and `ghost`: seconds since the death and since the release. `durability`: average percentage points lost on worn items since before the death. |
| `roll` | `item`, `choice` (`need`, `offspec`, `transmog`, `greed` or `pass`), `roll` (yours; none for a pass), `winner` and `winnerRoll` (none when everyone passed). A win is a `receive` entry with `how = "roll"`. |
| `equip` | `slot` (inventory slot, 1 head to 18 ranged), `item` (link), `ilvl`, `quality` (0 poor, 1 common, 2 uncommon, ...), `replaced` (the link it replaced). `ilvl` and `quality` are missing if the item wasn't loaded yet. |
| `talent` | `name`, `id` (its spell), `tree`, `rank`, `max`, `level`; `points` when several ranks were applied at once. |
| `talentreset` | `points` taken back, `spent` (points still spent), `level`. |
| `tame` | `name`, `id` (creature ID), `level` and `family` of the beast; `pet`: the pet's name when it's neither; `first`: your first pet. |
| `duel` | `opponent`, `result` (`won`, `lost` or `interrupted`: no winner), `fled` (the loser ran), `challenger` (`you` or `opponent`) |
| `honorkill` | `name`, `rank`, `honor`; all empty for a kill known only from the count |
| `honor` | `honor` awarded |

The archive is `TravelLogArchiveDB = { chars = { ["Name-Realm"] = { sessions = {...}, log = {...}, path = {...} } } }`. `path` holds TravelLog_Path's sessions; sessions archived before TravelLog_Path existed carry `track` and `jumps` themselves, and TravelLog_Path reads both.

## Limits

- Only items whose loot slot empties are recorded, so items left behind aren't. With free-for-all loot, another player's pick from a window you have open can count as yours.
- A loot window combining several corpses is credited to the first one.
- Objects are named from the cast that opened them. One that opens without a cast (some quest crates) gets its object ID but no name.
- Addons get no coordinates in dungeons and raids. The Midnight-era client also hides some chat there, so crafted items, quest rewards, kills, discoveries and reputation standings may be missing. Loot windows and rolls still work.
- Time played comes from `/played`, which TravelLog asks for at each login and keeps out of chat. A `/played` you type before that answer arrives (usually within a second of login) doesn't show, and a level-up before the answer arrives gets no times.
- Teleports are found by a jump in your position: more than 100 yards beyond what you could have walked or ridden since the last look a second before. A cast in the 5 seconds before is named as the cause, and one that lands you where your hearthstone is set counts as a hearth. A jump without a cast of yours (another mage's portal, an NPC that sends you somewhere) is a teleport with no spell, since the client doesn't say whose portal it was.
- The Hearthstone always counts, even next to the inn. Other teleports shorter than 100 yards, teleports inside dungeons (no positions there), and teleports out of a dungeon that don't land at your hearthstone are missed: leaving a dungeon is logged either way.
- The client doesn't report boats and zeppelins. A ride is when you're carried at least 4 yards a second faster than your own speed for 5 seconds, so it can't tell a boat from a zeppelin, and it ends after 10 seconds on your own feet.
- A screenshot's `file` is worked out from your computer's clock, not read from the game, so it can be a second off from the real name.
- Summons are logged once you accept and arrive. The summoner's name is missing if the client hides it.
- Time in a dungeon or raid counts only while you're logged in, and a reload inside is the same visit.
- Talent points count when applied, not when placed in the talent frame. Points spent before TravelLog was installed, or on the other spec before you first switch to it with TravelLog, are remembered without being logged. Re-spent points count again in the total. A reset is logged without its cost.
- A failed quest is noticed when the quest log next updates, and logged once each time you take it: not again after a reload, and abandoning it afterwards is a `questabandon`. One that failed while you were offline or before TravelLog was installed is logged when it's first seen. The client doesn't say why a quest failed, so only a timer running out is told apart, and a failed quest the server drops from the log at once isn't seen.
- Mounts and pets count from when TravelLog was installed, so "First mount" and "First pet" are only your real firsts if you hadn't ridden or tamed before.
- No event says a tame worked. It's a Tame Beast channel that runs its full length, then a pet appearing within 5 seconds; the beast is your target when the channel began.
- Gear counts from the first login that records it: what you wear then is remembered, not logged, and gear in your bags is logged the first time you put it on. Gear is kept by item ID, so a second copy of an item, or the same item with another random enchantment, isn't logged again.
- Duel results come from the "Ann has defeated Bob in a duel" line. The client doesn't say when the other player accepts your challenge, so a duel you challenged that ends without a winner is logged only if one of you crossed the duel area's edge.
- Honorable kills and honor come from their chat lines. Where chat is hidden (battlegrounds), kills come from the day's honorable kill count instead, without name, rank or honor, and honor awards are missed. Deaths don't say whether a player killed you: no event names the killer.
- Kills count only when they give XP, since this client has no combat log for addons. [TravelLog_Kills](../TravelLog_Kills/) records every kill.
- Without the combat log, a death's `cause` comes only from the breath and fatigue bars (run out in the last minute) and from falls over 1.5 s that end within a second of dying. Lava, fire and slime aren't told apart, and a mob kill right after a long fall counts as the fall.
- How you came back is known when you chose it in the game's dialogs (resurrection, spirit healer, soulstone and the like, corpse) in the 30 s before. Battleground spirit healers aren't. A resurrection names the player but not the spell.
- Durability lost needs a reading from before the death, so a revival after a reload while dead has none.
- Lost and passed rolls come from the group loot history. A roll is logged only if TravelLog saw it undecided, so one decided while you were reloading is missed.
- Items used up (potions, food, reagents) aren't recorded: no event says an item was consumed.
- Mailed items are saved by item ID, so their link has no random enchantment ("of the Bear").
- Destroyed items are recorded only when picked up from your bags or gear first, so a gamepad delete isn't.
- Money reasons are guesses from the window that's open and what you clicked in the few seconds before. A bank slot that costs nothing logs no entry.
- Sales are read from the 12-slot buyback list, so selling more than 12 items in one click (Sell All Junk) may not list each one. The money total is always right.
- Untested in the live game; written against the Forever 1.60.1 UI source and tested against a fake client ([tests](../tests/README.md)). If something breaks, turn on Lua errors with `/console scriptErrors 1`.
