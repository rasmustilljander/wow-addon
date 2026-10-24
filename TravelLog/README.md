# TravelLog

Records your travels in WoW: Forever so you can retrace them: loot, vendor trades, money, flights, deaths, quests and more.

Optional companions, each its own folder:

- [TravelLog_Path](../TravelLog_Path/): your path and jumps, drawn on the world map. Needs TravelLog.
- [TravelLog_Nodes](../TravelLog_Nodes/): looted chests, herbs and ore, pinned on the minimap and world map. Needs TravelLog.
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
| **Guild bank** | Items you put in and take out, one entry per visit, with the guild's name. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every gold change with a reason: loot, vendor, flight, quest, training, mail, COD, trade, auction (buys, and sales paid by mail with the item), auction deposit, bank slot, account bank, guild bank, barber, talent reset, stable slot or other. A bank slot also gets its own entry. |
| **Trades and mail** | Money and items from a trade, both ways, are saved with the other player (`partner`, as `Name-Realm` for another realm); from mail, with the mail's sender (`sender`); mail you send and its postage, with the recipient (`recipient`). |
| **Travel** | Zone and subzone changes (first visits marked), flights (from, to, cost, duration), hearthstones and other teleports (from, to and the spell or item), summons (from, to and who), boat and zeppelin rides (from, to, duration), dungeons and raids (name, type, difficulty, and when you leave, time inside and bosses killed and wiped on), resting in inns and cities (where it started, and how long when it ends), hearthstone binds, screenshots (with the file's name, to match pictures to the log). |
| **Life** | Deaths (what you fought, and drowning, fatigue or a long fall), spirit releases, revivals (corpse run, spirit healer, another player or a soulstone and the like, with how long you were dead and the durability lost), level-ups (with how long the level took), quests accepted, completed, abandoned and failed (and whether time ran out), kills that gave XP, boss kills and wipes (boss, difficulty, group size, fight length), discoveries, and guilds joined, left (or kicked out of, or disbanded) and rank changes (with who invited, promoted, demoted or kicked you). |
| **PvP** | Duels (opponent, won, lost or no winner, whether the loser fled, who challenged), battlegrounds (won, lost, drawn or left before the end, with length and your killing blows, honorable kills, deaths and honor), honorable kills (victim, rank, honor), honor awards, and your own PvP rank going up or down. |
| **Sessions** | Each login or reload: start and end (time and place), level, money, the experience gained and time AFK. |
| **Progress** | Spells, abilities and recipes learned (with rank, trainer and cost), new skills (a dropped profession learned again counts), every 25 points of a skill, talent points spent (talent, tree, new rank and your level) and taken back, flight paths found, reputation standings reached, reputation gained and lost per faction (totals only), the first ride on each mount, beasts tamed (name, level and family), the first time you put on each piece of gear (slot, item level, quality and what it replaced; not shirts or tabards), and Legacy Challenges (Forever's achievements) earned, with points, category and reward. |

## Window

Pick TravelLog from the addons dropdown on the minimap, or type `/tl`, for a window with these tabs:

- **Totals**: numbers under Travel, Loot (money in and out by reason, largest first), Life (quest and PvP outcomes, discoveries, mounts, pets, time played, reputation and XP) and Log. Reputation shows the three most changed factions here and all in `/tl stats`; XP sources are largest first. **Character**'s `<` and `>` step from the character you're on through your other characters to all of them added up (a place several visited counts once). Rows only the character you're on has (time played, log entries, and the Kills and Group rows) show for that character.
- **Settings**: the companions' map options, Path's interval, and whether gold and XP per hour leave out AFK time (on by default).
- **History**: what's in the character file, newest first, in views:
  - **Events**: every event. Filter by Travel, Loot, Trade, Life (PvP and guilds too) or Progress, or search event types, descriptions, names, places, dates and saved fields. Search `death` to list deaths with their level, cause, fight target and location, `revival` for how you came back, or `level` for each level-up and how long it took.
  - **Sessions**: each session's length and time AFK, levels, where it started and ended, money and experience gained (per hour after 10 minutes; by default AFK time is left out of both), and its quests done and failed, XP kills and deaths. Hover a session for its XP by source.
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
| `/tl sessions [n]` | The last n sessions (default 10), as in the Sessions view, with XP by source |
| `/tl wipe confirm` | Delete everything for this character, including its Path, Nodes and Share data. Kills and Group have their own `wipe confirm`. |

`/travellog` works too. TravelLog_Path adds `/tl jumps`, `/tl trail` and `/tl interval`, TravelLog_Nodes adds `/tl nodes`, and both add lines to `/tl stats`. TravelLog_Share adds `/tl share`, which opens its tab.

## Where the data is

WoW writes SavedVariables only on logout or `/reload`, so a crash loses everything since the last one. `/reload` now and then on long sessions.

| File under `WTF/Account/<ACCOUNT>/` | Contents |
| --- | --- |
| `SavedVariables/TravelLog.lua` | Settings (the companions' too, and the window's `point`), each character's profile and totals |
| `<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's log, sessions, quests, skills, talents, mounts, gear, PvP rank, guild, and the instance or rested area you're in |
| `SavedVariables/TravelLog_Path.lua` | Every character's path, for TravelLog_Path |
| `SavedVariables/TravelLog_Nodes.lua` | Every character's nodes, for TravelLog_Nodes |

TravelLog keeps its log and sessions until `/tl wipe confirm`. TravelLog_Path keeps its path separately; see its [data and limits](../TravelLog_Path/README.md#where-the-data-is).

Before 0.3, the path and nodes lived in TravelLog's character file. The first login with TravelLog_Path or TravelLog_Nodes installed moves them into that addon's file.

Both files save `version`, TravelLog's data version (now 1). TravelLog reads only versions it knows. A file from a newer TravelLog is left as it is and nothing is recorded (Path, Nodes and Share included): for that character, or with the account file, for all of them. Chat, `/tl` and the addons dropdown say why.

The character file:

```lua
TravelLogCharDB = {
  version = 1,   -- data version
  log = {   -- oldest first
    { type = "loot", time = 1760000000, zone = "Elwynn Forest", subzone = "Goldshire",
      map = 1429, x = 42.1, y = 65.3, source = "Peacebloom", sourceType = "GameObject",
      sourceID = 1618, via = "Herb Gathering", lastHere = 1759998200,
      items = { { item = "|cffffffff|Hitem:2447:...|h[Peacebloom]|h|r", count = 2 } } },
    ...
  },
  sessions = {   -- one per login or reload
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, money = 10000, moneyEnd = 12500, xp = 5600, afk = 1200,  -- seconds AFK
      zone = "Elwynn Forest", subzone = "Goldshire", map = 1429, x = 42.1, y = 65.3,   -- where you logged in
      zoneEnd = "Stormwind City", subzoneEnd = "Old Town", mapEnd = 1453, xEnd = 75.2, yEnd = 61.8 },  -- and out
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ..., abandoned = ..., failed = ... } },  -- last time of each
  skills = { [129] = 75 },           -- skill ID -> rank of skills you have, to tell new skills and milestones
  talents = { [7001] = { [101] = 3 } },  -- loadout ID -> talent node ID -> rank, to tell points spent
  mounts = { [458] = 1760000000 },   -- mount spell ID -> first ride
  instance = { name = "The Deadmines", kind = "dungeon", id = 36, inside = 600, since = ..., kills = 2, wipes = 1 },  -- while you're in one
  fight = { id = 2972, since = 1760000000 },  -- the boss fight in progress
  rest = { inside = 600, since = ... },  -- while you're resting
  gear = { [25] = 0, [2361] = 1760000000 },  -- item ID -> first put on (0: worn when gear recording began)
  pvpRank = { rank = 3, season = 1 },  -- last rank seen, to tell changes
  guild = { name = "Wanderers", rank = "Officer", rankIndex = 2, since = 1760000000 },  -- {} for none; since: when you joined
}
```

Log entry types: `area`, `loot`, `receive`, `roll`, `buy`, `sell`, `buyback`, `repair`, `give` (trade), `send` (mail), `post` (auction), `destroy`, `guildbank`, `money`, `bankslot`, `flight`, `landed`, `hearth`, `teleport`, `summon`, `board`, `disembark`, `instance`, `instanceleave`, `rest`, `restleave`, `bind`, `screenshot`, `death`, `release`, `revive`, `level`, `quest`, `questdone`, `questabandon`, `questfail`, `kill`, `boss`, `discover`, `duel`, `battleground`, `honorkill`, `honor`, `pvprank`, `guildjoin`, `guildleave`, `guildrank`, `spell`, `skill`, `skillup`, `talent`, `talentreset`, `taxipath`, `standing`, `mount`, `tame`, `equip`, `achievement`. Fields the game doesn't reveal (coordinates in dungeons) are left empty.

A `money` entry has `amount` (negative when spent), `reason` (`loot`, `vendor`, `flight`, `quest`, `training`, `mail`, `cod`, `trade`, `auction`, `deposit`, `bankslot`, `bank`, `guildbank`, `barber`, `respec`, `stable` or `other`) and `balance`, plus `partner`, `sender` or `recipient` for trades and mail and `item` for an auction sale. A `bankslot` entry has `bank` (`character` or `account`), `slot` (its number in that bank) and `price`.

Some types have more:

| Type | Fields |
| --- | --- |
| `guildbank` | `deposited` and `withdrawn`: lists of `item` (link) and `count`; `guild` |
| `hearth`, `teleport` | `from`, `to` (place names); `spell` and `via` (its name) when your cast did it |
| `summon` | `from`, `to`, `by` (the summoner) |
| `board` | none: it's stamped where the ride started |
| `disembark` | `from`, `to`, `seconds` on board |
| `instance` | `name`, `kind` (`dungeon`, `raid`, `battleground`, `arena` or `scenario`), `difficulty`, `size`, `id` |
| `instanceleave` | `name`, `kind`, `seconds` inside; `kills` and `wipes` when there were any |
| `boss` | `name` and `id` of the encounter, `result` (`kill` or `wipe`), `difficulty`, `size` (group size), `seconds` the fight lasted (from the pull, when seen), `instance` |
| `restleave` | `seconds` resting, `rested` (your rested XP pool as you leave, if any) |
| `screenshot` | `file`: the name the game gives the picture, without its extension (`WoWScrnShot_102226_143005`: local date and time it was taken) |
| `quest`, `questabandon` | `id`, `title` |
| `questdone` | `id`, `title`, `xp` and `money` (copper) it gave |
| `questfail` | `id`, `title`, `reason` (`time` when its timer ran out) |
| `kill` | `name`, `xp` |
| `discover` | `place`, `xp` |
| `standing` | `faction`, `standing` reached |
| `level` | `played`: seconds played in all. `took`: seconds played at the level before. |
| `death` | `target`: the hostile unit you had targeted. `level`. `cause`: `drowning`, `fatigue` or `falling`, when known. |
| `revive` | `how`: `corpse`, `spirithealer`, `player` or `selfres`, when known. `by`: who resurrected you. `spell`: the self-resurrection used (Soulstone, Reincarnation, ...). `sickness`: `true` with resurrection sickness. `took` and `ghost`: seconds since the death and since the release. `durability`: average percentage points lost on worn items since before the death. |
| `roll` | `item`, `choice` (`need`, `offspec`, `transmog`, `greed` or `pass`), `roll` (yours; none for a pass), `winner` and `winnerRoll` (none when everyone passed). A win is a `receive` entry with `how = "roll"`. |
| `equip` | `slot` (inventory slot, 1 head to 18 ranged), `item` (link), `ilvl`, `quality` (0 poor, 1 common, 2 uncommon, ...), `replaced` (the link it replaced). `ilvl` and `quality` are missing if the item wasn't loaded yet. |
| `talent` | `name`, `id` (its spell), `tree`, `rank`, `max`, `level`; `points` when several ranks were applied at once. |
| `talentreset` | `points` taken back, `spent` (points still spent), `level`. |
| `tame` | `name`, `id` (creature ID), `level` and `family` of the beast; `pet`: the pet's name when it's neither; `first`: your first pet. |
| `achievement` | A Legacy Challenge: `id`, `name`, `points`, `category`, `reward` (the reward text, such as a title), `already` (`true`: another character on the account earned it first), `guild` (`true` for a guild one). |
| `duel` | `opponent`, `result` (`won`, `lost` or `interrupted`: no winner), `fled` (the loser ran), `challenger` (`you` or `opponent`) |
| `battleground` | `name`, `result` (`won`, `lost`, `draw` or `left`: before the end), `seconds` the match lasted; from your scoreboard line, `killingBlows`, `honorableKills`, `deaths` and `honor` gained |
| `honorkill` | `name`, `rank`, `honor`; all empty for a kill known only from the count |
| `honor` | `honor` awarded |
| `pvprank` | `rank` (0 unranked), `old` (the rank before), `title` (Sergeant, Knight, ...), `season`, `newSeason` (`true` when the season changed) |
| `guildjoin` | `guild`, `rank`, `by` (who invited you), `founder` (`true` when you signed its charter) |
| `guildleave` | `guild`, `rank` you had, `how` (`left`, `kicked` or `disbanded`, when known), `by` (who kicked you or disbanded it), `seconds` in the guild (when TravelLog saw you join) |
| `guildrank` | `guild`, `rank`, `from` (the rank before), `change` (`promoted` or `demoted`), `by` |

## Limits

- Only items whose loot slot empties are recorded, so items left behind aren't. With free-for-all loot, another player's pick from a window you have open can count as yours.
- A loot window combining several corpses is credited to the first one.
- Objects are named from the cast that opened them. One that opens without a cast (some quest crates) gets its object ID but no name.
- Addons get no coordinates in dungeons and raids. The Midnight-era client also hides some chat there, so crafted items, quest rewards, kills, discoveries and reputation may be missing. Loot windows and rolls still work.
- Time played comes from `/played`, which TravelLog asks for at each login and keeps out of chat. A `/played` you type before that answer arrives (usually within a second of login) doesn't show, and a level-up before the answer arrives gets no times.
- Teleports are found by a jump in your position: more than 100 yards beyond what you could have walked or ridden since the last look a second before. A cast in the 5 seconds before is named as the cause, and one that lands you where your hearthstone is set counts as a hearth. A jump without a cast of yours (another mage's portal, an NPC that sends you somewhere) is a teleport with no spell, since the client doesn't say whose portal it was.
- The Hearthstone always counts, even next to the inn. Other teleports shorter than 100 yards, teleports inside dungeons (no positions there), and teleports out of a dungeon that don't land at your hearthstone are missed: leaving a dungeon is logged either way.
- The client doesn't report boats and zeppelins. A ride is when you're carried at least 4 yards a second faster than your own speed for 5 seconds, so it can't tell a boat from a zeppelin, and it ends after 10 seconds on your own feet.
- A screenshot's `file` is worked out from your computer's clock, not read from the game, so it can be a second off from the real name.
- Summons are logged once you accept and arrive. The summoner's name is missing if the client hides it.
- Time in a dungeon or raid counts only while you're logged in, and a reload inside is the same visit.
- Resting comes from the game's rested state, so it can't tell an inn from a city. A change is logged where it happened once it has held for 5 s, so stepping through an inn's door isn't a stay. Logging in rested starts a stay without a `rest` entry (the session says where you were), a reload or a night logged out inside is the same stay, and its time counts only while you're logged in.
- Talent points count when applied, not when placed in the talent frame. Points spent before TravelLog was installed, or on the other spec before you first switch to it with TravelLog, are remembered without being logged. Re-spent points count again in the total. A reset is logged without its cost.
- A failed quest is noticed when the quest log next updates, and logged once each time you take it: not again after a reload, and abandoning it afterwards is a `questabandon`. One that failed while you were offline or before TravelLog was installed is logged when it's first seen. The client doesn't say why a quest failed, so only a timer running out is told apart, and a failed quest the server drops from the log at once isn't seen.
- Reputation totals come from the "Reputation with Stormwind increased by 25." chat lines, counted from when TravelLog was installed. A line without an amount isn't counted.
- Mounts and pets count from when TravelLog was installed, so "First mount" and "First pet" are only your real firsts if you hadn't ridden or tamed before.
- No event says a tame worked. It's a Tame Beast channel that runs its full length, then a pet appearing within 5 seconds; the beast is your target when the channel began.
- Gear counts from the first login that records it: what you wear then is remembered, not logged, and gear in your bags is logged the first time you put it on. Gear is kept by item ID, so a second copy of an item, or the same item with another random enchantment, isn't logged again.
- Duel results come from the "Ann has defeated Bob in a duel" line. The client doesn't say when the other player accepts your challenge, so a duel you challenged that ends without a winner is logged only if one of you crossed the duel area's edge.
- A battleground's result and scoreboard line are read when the match ends. Leaving earlier, or being away when it ends, counts as `left`. Scoreboard numbers the client hides are left empty.
- Honorable kills and honor come from their chat lines. Where chat is hidden (battlegrounds), kills come from the day's honorable kill count instead, without name, rank or honor, and honor awards are missed. Deaths don't say whether a player killed you: no event names the killer.
- Your PvP rank is your renown with the PvP rank faction, as on the character frame's PvP tab. The rank at the first login is remembered, not logged; a change while you were offline (a new season) is logged at the next login.
- Guild changes come from your guild info and are logged 3 s after they're seen. The guild you're in at the first login with guild recording is remembered, not logged, and a change while you were offline is logged at the next login without `by` or `how`. Who did it comes from the system line, so others' arrivals and departures aren't logged, and declined invites are discarded. Totals count a disbanded guild or an unknown departure as left. A renamed guild counts as leaving one and joining another, and reordered ranks as promotions or demotions.
- Boss fights come from the game's encounter events, which Forever's own UI never uses (its boss banner is retail-only), so it's unconfirmed that every boss sends them. A boss with no encounter isn't logged. After a reload during a fight, its length may count only from the reload.
- Legacy Challenges come from the `ACHIEVEMENT_EARNED` event, which Blizzard's own Legacy Challenges window listens for. Whether Forever fires it (its window only opens once you have renown with the legacy reward faction) is unchecked in the live game; `/tl log achievement` shows what was recorded.
- AFK time is the time the game marks you AFK (`/afk`, or idle long enough), so the idle minutes before that count as active. A change while the client hides it (in dungeons) is missed.
- XP by source splits the XP bar's gain into quests, kills, discoveries and other. Other is the rest, including kills and discoveries the client hides in dungeons. The totals count from the oldest session in the character file that recorded experience gained, so earlier XP isn't in them.
- Kills count only when they give XP, since this client has no combat log for addons. [TravelLog_Kills](../TravelLog_Kills/) records every kill.
- Without the combat log, a death's `cause` comes only from the breath and fatigue bars (run out in the last minute) and from falls over 1.5 s that end within a second of dying. Lava, fire and slime aren't told apart, and a mob kill right after a long fall counts as the fall.
- How you came back is known when you chose it in the game's dialogs (resurrection, spirit healer, soulstone and the like, corpse) in the 30 s before. Battleground spirit healers aren't. A resurrection names the player but not the spell.
- Durability lost needs a reading from before the death, so a revival after a reload while dead has none.
- Lost and passed rolls come from the group loot history. A roll is logged only if TravelLog saw it undecided, so one decided while you were reloading is missed.
- Items used up (potions, food, reagents) aren't recorded: no event says an item was consumed.
- Mailed items are saved by item ID, so their link has no random enchantment ("of the Bear").
- Destroyed items are recorded only when picked up from your bags or gear first, so a gamepad delete isn't.
- Guild bank items are read from what your bags gain or lose within 10 s of a guild bank click, so equipping or destroying an item in those seconds counts as a move, and an item held on the cursor longer is missed. Moves between tabs aren't logged.
- Money reasons are guesses from the window that's open and what you clicked in the few seconds before. A bank slot that costs nothing logs no entry.
- Sales are read from the 12-slot buyback list, so selling more than 12 items in one click (Sell All Junk) may not list each one. The money total is always right.
- Vendor buys, buybacks and repairs are logged only after the bag count, buyback list or repair cost confirms them within 5 seconds. Failed clicks aren't logged; a confirmation delayed longer than that is missed.
- Untested in the live game; written against the Forever 1.60.1 UI source and tested against a fake client ([tests](../tests/README.md)). If something breaks, turn on Lua errors with `/console scriptErrors 1`.
