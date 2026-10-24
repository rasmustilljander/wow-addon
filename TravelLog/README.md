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
| **Travel** | Zone and subzone changes (first visits marked), time logged in per zone (totals only), flights (from, to, cost, duration), hearthstones and other teleports (from, to and the spell or item), summons (from, to and who), boat and zeppelin rides (from, to, duration), dungeons and raids (name, type, difficulty, and when you leave, time inside and bosses killed and wiped on), instance resets (and failed ones, with why), new lockouts (instance, difficulty, lockout ID and when it resets), resting in inns and cities (where it started, and how long when it ends), hearthstone binds, screenshots (with the file's name, to match pictures to the log; TravelLog can [take some itself](#automatic-screenshots)), and notes you add with `/tl note`. |
| **Life** | Deaths (who or what killed you, with the spell and damage, or drowning, fatigue, a fall, fire, lava or slime), spirit releases, revivals (corpse run, spirit healer, another player or a soulstone and the like, with how long you were dead and the durability lost), level-ups (with how long the level took), quests accepted, completed, abandoned and failed (and whether time ran out), kills that gave XP, boss kills and wipes (boss, difficulty, group size, fight length), discoveries, world buffs gained (Rallying Cry, Warchief's Blessing, Spirit of Zandalar, Songflower, the Dire Maul tribute, Sayge's fortunes and Boon of Blackfathom, with duration and who gave it), and guilds joined, left (or kicked out of, or disbanded) and rank changes (with who invited, promoted, demoted or kicked you). |
| **PvP** | Duels (opponent, won, lost or no winner, whether the loser fled, who challenged), battlegrounds (won, lost, drawn or left before the end, with length and your killing blows, honorable kills, deaths and honor), honorable kills (victim, rank, honor), honor awards, and your own PvP rank going up or down. |
| **Sessions** | Each login or reload: start and end (time and place), level, money, the experience gained (and its rested bonus) and time AFK. |
| **Progress** | Spells, abilities and recipes learned (with rank, trainer and cost), new skills (a dropped profession learned again counts), every 25 points of a skill, talent points spent (talent, tree, new rank and your level) and taken back, flight paths found, reputation standings reached, reputation gained and lost per faction (totals only), the first ride on each mount, beasts tamed (name, level and family), your hunter pet's level-ups, abandoning it, and pets put in or taken out of the stable (name, level and family), the first time you put on each piece of gear (slot, item level, quality and what it replaced; not shirts or tabards) and each bag (size, quality and what it replaced), new permanent enchants on worn gear (and the one they replaced), and Legacy Challenges (Forever's achievements) earned, with points, category and reward. |

## Window

Pick TravelLog from the addons dropdown on the minimap, or type `/tl`, for a window with these tabs:

- **Totals**: numbers under Travel, Loot (money in and out by reason, largest first), Life (quest and PvP outcomes, discoveries, mounts, pets, world buffs, time played, reputation and XP) and Log. Reputation and time by zone show the top three (most changed factions, longest zones) here and all in `/tl stats`; XP sources are largest first. **Character**'s `<` and `>` step from the character you're on through your other characters to all of them added up (a place several visited counts once). Rows only the character you're on has (time played, log entries, and the Kills and Group rows) show for that character.
- **Settings**: the companions' map options, Path's trail curves and interval, whether gold and XP per hour leave out AFK time (on by default), and [automatic screenshots](#automatic-screenshots).
- **History**: what's in the character file, newest first, in views:
  - **Events**: every event. Filter by Travel (notes too), Loot, Trade, Life (PvP and guilds too) or Progress, or search event types, descriptions, names, places, dates and saved fields. Search `death` to list deaths with their level, killer or cause and location, `revival` for how you came back, `level` for each level-up and how long it took, or `note` for your notes.
  - **Sessions**: each session's length and time AFK, levels, where it started and ended, money and experience gained (per hour after 10 minutes; by default AFK time is left out of both), and its quests done and failed, XP kills and deaths. Hover a session for its XP by source.
  - **Kills**, with [TravelLog_Kills](../TravelLog_Kills/README.md#window): every mob you've killed and where.
- **NPCs**, with [TravelLog_NPCs](../TravelLog_NPCs/README.md#window): search NPCs by name, place or what they sell.
- **Players**, with [TravelLog_Group](../TravelLog_Group/README.md#window): everyone you've grouped with and each time.
- **Colors**, with [TravelLog_Path](../TravelLog_Path/README.md#world-map): the trail's and markers' colors on the world map.
- **Sharing**, with [TravelLog_Share](../TravelLog_Share/README.md#the-sharing-tab): who you share with and follow, and their logs.

Companions add their rows to the matching section.

## Item tooltips

A rare, epic or better item's tooltip says when, where and how you first got it, and how often when it's more than once:

```
First looted 2026-10-02 from Defias Thug, Westfall
Got 3 times
```

It counts items looted, received (roll wins, quest rewards, crafts, mail, trades) and bought.

## Automatic screenshots

TravelLog can take a screenshot for you, a moment after the event so its glow or banner shows. It's logged like one you take yourself.

| When | Name | Default | After |
| --- | --- | --- | --- |
| A level-up (not to level 1) | `level` | on | 1 s |
| A boss kill | `boss` | on | 0.5 s |
| Only a boss's first kill in this character's log, when `boss` is on | `first` | on | |
| A Legacy Challenge earned | `achievement` | off | 1 s |

None is taken within 1 s of another screenshot, so a level-up and a challenge together give one. Change them on the Settings tab or with `/tl screenshots`.

## Commands

| Command | |
| --- | --- |
| `/tl` | Open or close the window |
| `/tl stats [all\|name]` | Totals (and time played) for this character, all of them added up, or another by `Name` or `Name-Realm` |
| `/tl log [n] [search]` | The last matching events (default 15); for example, `/tl log 20 death` |
| `/tl note <text>` | Add a note to the log, stamped with the time and place |
| `/tl sessions [n]` | The last n sessions (default 10), as in the Sessions view, with XP by source |
| `/tl screenshots [level\|boss\|first\|achievement on\|off]` | Show or change [automatic screenshots](#automatic-screenshots); for example, `/tl screenshots achievement on` |
| `/tl wipe confirm` | Delete everything for this character, including its Path, Nodes and Share data. Kills and Group have their own `wipe confirm`. |

`/travellog` works too. TravelLog_Path adds `/tl jumps`, `/tl trail`, `/tl smooth` and `/tl interval`, TravelLog_Nodes adds `/tl nodes`, and both add lines to `/tl stats`. TravelLog_Share adds `/tl share`, which opens its tab.

## Where the data is

WoW writes SavedVariables only on logout or `/reload`, so a crash loses everything since the last one. `/reload` now and then on long sessions.

| File under `WTF/Account/<ACCOUNT>/` | Contents |
| --- | --- |
| `SavedVariables/TravelLog.lua` | Settings (the companions' too, and the window's `point`), each character's profile and totals (`stats`; seconds logged in per zone name in `stats.zoneTime`) |
| `<Realm>/<Character>/SavedVariables/TravelLog.lua` | That character's log, sessions, quests, skills, talents, mounts, gear, bags, PvP rank, guild, lockouts, and the instance or rested area you're in |
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
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, money = 10000, moneyEnd = 12500, xp = 5600, rested = 1400, afk = 1200,  -- rested bonus XP; seconds AFK
      zone = "Elwynn Forest", subzone = "Goldshire", map = 1429, x = 42.1, y = 65.3,   -- where you logged in
      zoneEnd = "Stormwind City", subzoneEnd = "Old Town", mapEnd = 1453, xEnd = 75.2, yEnd = 61.8 },  -- and out
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ..., abandoned = ..., failed = ... } },  -- last time of each
  skills = { [129] = 75 },           -- skill ID -> rank of skills you have, to tell new skills and milestones
  talents = { [7001] = { [101] = 3 } },  -- loadout ID -> talent node ID -> rank, to tell points spent
  mounts = { [458] = 1760000000 },   -- mount spell ID -> first ride
  instance = { name = "The Deadmines", kind = "dungeon", id = 36, inside = 600, since = ..., kills = 2, wipes = 1 },  -- while you're in one
  fight = { id = 2972, since = 1760000000 },  -- the boss fight in progress
  lockouts = { ["Molten Core:9:1001"] = 1760600000 },  -- "name:difficulty ID:lockout ID" -> when it resets, to tell new ones
  rest = { inside = 600, since = ... },  -- while you're resting
  gear = { [25] = 0, [2361] = 1760000000 },  -- item ID -> first put on (0: worn when gear recording began)
  bags = { [4496] = 0, [4245] = 1760000000 },  -- bag item ID -> first equipped (0: equipped when bag recording began)
  pvpRank = { rank = 3, season = 1 },  -- last rank seen, to tell changes
  guild = { name = "Wanderers", rank = "Officer", rankIndex = 2, since = 1760000000 },  -- {} for none; since: when you joined
}
```

Each entry has `type`, `time` and the place stamp (`zone`, `subzone`, `map`, `x`, `y`); fields the game doesn't reveal (coordinates in dungeons) are left empty. Item lists are `item` (link) and `count` pairs; prices and money are in copper. The other fields, by type:

| Type | Fields |
| --- | --- |
| `area` | `first`: `true` on your first visit to the subzone (or zone) |
| `loot` | `source` (name), `sourceType` (`Creature`, `GameObject`, `Item`, `Fishing`, ...), `sourceID`, `via` (the spell, such as Herb Gathering or Pick Pocket), `items`, `money`; with TravelLog_Nodes, `lastHere` (when the spot was last looted) and `lastBy` (the alt who did) |
| `receive` | `item`, `count`, `how` (`loot`, `created`, `quest`, `mail`, `trade`, `roll` or `received`: other); `roll` for a won roll, `sender` from mail, `partner` from a trade |
| `buy`, `sell`, `buyback` | `item`, `count`, `price`, `vendor`; a `buy` priced in items or currency has `otherCurrency` (`true`) |
| `repair` | `price`, `vendor`, `guildBank` (`true` when the guild paid) |
| `give` | A trade: `items`, `partner` |
| `send` | Mail: `items`, `recipient` |
| `post` | An auction: `item`, `count`, `bid`, `buyout` (a commodity has only `buyout`, for the whole stack) |
| `destroy` | `item`, `count` |
| `guildbank` | `deposited` and `withdrawn` (item lists), `guild` |
| `money` | `amount` (negative when spent), `reason` (`loot`, `vendor`, `flight`, `quest`, `training`, `mail`, `cod`, `trade`, `auction`, `deposit`, `bankslot`, `bank`, `guildbank`, `barber`, `respec`, `stable` or `other`), `balance`; `partner`, `sender` or `recipient` for trades and mail, `item` for an auction sale |
| `bankslot` | `bank` (`character` or `account`), `slot` (its number in that bank), `price` |
| `flight` | `from`, `to` (flight points), `price`; `seconds` flown, added on landing |
| `landed` | `from`, `to`, `seconds` of the flight; none after a reload in the air |
| `hearth`, `teleport` | `from`, `to` (place names); `spell` and `via` (its name) when your cast did it |
| `summon` | `from`, `to`, `by` (the summoner) |
| `board`, `rest`, `release` | none: the stamp says where it happened |
| `disembark` | `from`, `to`, `seconds` on board |
| `instance` | `name`, `kind` (`dungeon`, `raid`, `battleground`, `arena` or `scenario`), `difficulty`, `size`, `id` |
| `instanceleave` | `name`, `kind`, `seconds` inside; `kills` and `wipes` when there were any |
| `instancereset` | `name`; `failed` when it didn't work: `inside` (players still inside), `offline` (party members offline) or `zoning` (players entering an instance) |
| `lockout` | `name`, `kind` (`dungeon` or `raid`), `difficulty`, `size`, `lockout` (its ID), `resets` (when, as a `time` value) |
| `boss` | `name` and `id` of the encounter, `result` (`kill` or `wipe`), `difficulty`, `size` (group size), `seconds` the fight lasted (from the pull, when seen), `instance` |
| `bind` | `place`: where your hearthstone is now set |
| `restleave` | `seconds` resting, `rested` (your rested XP pool as you leave, if any) |
| `note` | `text`: what you typed |
| `screenshot` | `file`: the name the game gives the picture, without its extension (`WoWScrnShot_102226_143005`: local date and time it was taken); for an automatic one, `auto` (`level`, `boss` or `achievement`) and `what` (the level, boss or challenge's name) |
| `quest`, `questabandon` | `id`, `title` |
| `questdone` | `id`, `title`, `xp` and `money` it gave |
| `questfail` | `id`, `title`, `reason` (`time` when its timer ran out) |
| `kill` | `name`, `xp` |
| `discover` | `place`, `xp` |
| `standing` | `faction`, `standing` reached |
| `level` | `level` reached, `played` (seconds played in all), `took` (seconds played at the level before) |
| `death` | `target`: the hostile unit you had targeted. `level`. `cause`: `drowning`, `fatigue`, `falling`, `fire`, `lava` or `slime`, when known. From the death recap's killing blow: `killer` (name), `killerType` (`Creature`, `Player` or `Pet`), `killerID` (a creature's NPC ID), `spell` and `spellID` (none for melee), `amount` (damage, overkill included), `overkill` (when above 0). |
| `revive` | `how`: `corpse`, `spirithealer`, `player` or `selfres`, when known. `by`: who resurrected you. `spell`: the self-resurrection used (Soulstone, Reincarnation, ...). `sickness`: `true` with resurrection sickness. `took` and `ghost`: seconds since the death and since the release. `durability`: average percentage points lost on worn items since before the death. |
| `roll` | `item`, `choice` (`need`, `offspec`, `transmog`, `greed` or `pass`), `roll` (yours; none for a pass), `winner` and `winnerRoll` (none when everyone passed). A win is a `receive` entry with `how = "roll"`. |
| `equip` | `slot` (inventory slot, 1 head to 18 ranged), `item` (link), `ilvl`, `quality` (0 poor, 1 common, 2 uncommon, ...), `replaced` (the link it replaced). `ilvl` and `quality` are missing if the item wasn't loaded yet. |
| `enchant` | `slot`, `item` (link, with the new enchant), `enchant` (enchant ID), `name` (its tooltip line, such as `Crusader`); `old` and `oldName` for the enchant it replaced. Names are missing if the tooltip wasn't loaded. |
| `bag` | `bag` (bag slot, 1 next to the backpack), `item` (link), `slots`, `quality`, `replaced` (the link it replaced) |
| `spell` | `id`, `name`, `rank`; `trainer` and `cost` when bought from a trainer |
| `skill`, `skillup` | `id`, `name`, `rank` (skill points) |
| `taxipath` | `npc`: the flight master |
| `mount` | `id` (its spell), `name`, `first` (`true`: your first mount) |
| `talent` | `name`, `id` (its spell), `tree`, `rank`, `max`, `level`; `points` when several ranks were applied at once. |
| `talentreset` | `points` taken back, `spent` (points still spent), `level`. |
| `tame` | `name`, `id` (creature ID), `level` and `family` of the beast; `pet`: the pet's name when it's neither; `first`: your first pet. |
| `petlevel` | `name` and `family` of your pet, `level` reached |
| `petabandon`, `petstable`, `petunstable` | `name`, `level` and `family` of the pet abandoned, stabled or taken out of the stable |
| `achievement` | A Legacy Challenge: `id`, `name`, `points`, `category`, `reward` (the reward text, such as a title), `already` (`true`: another character on the account earned it first), `guild` (`true` for a guild one). |
| `duel` | `opponent`, `result` (`won`, `lost` or `interrupted`: no winner), `fled` (the loser ran), `challenger` (`you` or `opponent`) |
| `battleground` | `name`, `result` (`won`, `lost`, `draw` or `left`: before the end), `seconds` the match lasted; from your scoreboard line, `killingBlows`, `honorableKills`, `deaths` and `honor` gained |
| `honorkill` | `name`, `rank`, `honor`; all empty for a kill known only from the count |
| `honor` | `honor` awarded |
| `pvprank` | `rank` (0 unranked), `old` (the rank before), `title` (Sergeant, Knight, ...), `season`, `newSeason` (`true` when the season changed) |
| `guildjoin` | `guild`, `rank`, `by` (who invited you), `founder` (`true` when you signed its charter) |
| `guildleave` | `guild`, `rank` you had, `how` (`left`, `kicked` or `disbanded`, when known), `by` (who kicked you or disbanded it), `seconds` in the guild (when TravelLog saw you join) |
| `guildrank` | `guild`, `rank`, `from` (the rank before), `change` (`promoted` or `demoted`), `by` |
| `worldbuff` | `id` (its spell), `name`, `duration` (seconds; none for a buff without one), `by` (who gave it, when the client names them) |

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
- Resets come from the "The Deadmines has been reset." system line (and its "Cannot reset" variants), so a reset is logged only if your chat gets that line.
- Lockouts come from the game's list (the one in the Raid Info window), which TravelLog asks for after each loading screen, 3 s after a boss kill and after the "You are now saved to this instance" line. A lockout is logged when the list first shows it, stamped where you are then. Lockouts at the first login with lockout recording are remembered, not logged; an expired one the game still lists isn't logged. World bosses aren't included.
- Time by zone counts from when TravelLog started recording it, so earlier time is missing. It counts every second you're logged in, AFK included (like `/played`), by zone, not subzone; a loading screen counts for the zone you left.
- Resting comes from the game's rested state, so it can't tell an inn from a city. A change is logged where it happened once it has held for 5 s, so stepping through an inn's door isn't a stay. Logging in rested starts a stay without a `rest` entry (the session says where you were), a reload or a night logged out inside is the same stay, and its time counts only while you're logged in.
- Talent points count when applied, not when placed in the talent frame. Points spent before TravelLog was installed, or on the other spec before you first switch to it with TravelLog, are remembered without being logged. Re-spent points count again in the total. A reset is logged without its cost.
- A failed quest is noticed when the quest log next updates, and logged once each time you take it: not again after a reload, and abandoning it afterwards is a `questabandon`. One that failed while you were offline or before TravelLog was installed is logged when it's first seen. The client doesn't say why a quest failed, so only a timer running out is told apart, and a failed quest the server drops from the log at once isn't seen.
- Reputation totals come from the "Reputation with Stormwind increased by 25." chat lines, counted from when TravelLog was installed. A line without an amount isn't counted.
- Mounts and pets count from when TravelLog was installed, so "First mount" and "First pet" are only your real firsts if you hadn't ridden or tamed before.
- No event says a tame worked. It's a Tame Beast channel that runs its full length, then a pet appearing within 5 seconds; the beast is your target when the channel began.
- Pet level-ups are seen only while the pet is out, by comparing its level with the last one seen for the same pet. A level gained while the client hides the pet's level or GUID (in dungeons) is logged when they show again, if the pet is still out.
- An abandon is the game's abandon call for the pet that's out, followed by the pet going away within 5 s, so a pet dismissed or killed in those seconds after a failed abandon counts too. Abandoning a pet that isn't out isn't logged.
- Stabling is seen only while the stable window is open, by comparing its slots after each update. A pet moved between stable slots isn't logged.
- Gear and bags count from the first login that records them: what you wear then is remembered, not logged, and gear in your bags is logged the first time you put it on. Both are kept by item ID, so a second copy of an item, or the same item with another random enchantment, isn't logged again. Only your own bag slots count: Forever's bank has tabs, not bag slots.
- An enchant is a change of the permanent enchant on an item you keep on, within 5 s of a spell you cast (enchanting it, an armor kit). Swapping in another copy of the item with another enchant counts only if you cast something in the 5 s before. Enchants on items in your bags, and temporary ones (poisons, sharpening stones, oils), aren't logged.
- Duel results come from the "Ann has defeated Bob in a duel" line. The client doesn't say when the other player accepts your challenge, so a duel you challenged that ends without a winner is logged only if one of you crossed the duel area's edge.
- A battleground's result and scoreboard line are read when the match ends. Leaving earlier, or being away when it ends, counts as `left`. Scoreboard numbers the client hides are left empty.
- Honorable kills and honor come from their chat lines. Where chat is hidden (battlegrounds), kills come from the day's honorable kill count instead, without name, rank or honor, and honor awards are missed.
- Your PvP rank is your renown with the PvP rank faction, as on the character frame's PvP tab. The rank at the first login is remembered, not logged; a change while you were offline (a new season) is logged at the next login.
- Guild changes come from your guild info and are logged 3 s after they're seen. The guild you're in at the first login with guild recording is remembered, not logged, and a change while you were offline is logged at the next login without `by` or `how`. Who did it comes from the system line, so others' arrivals and departures aren't logged, and declined invites are discarded. Totals count a disbanded guild or an unknown departure as left. A renamed guild counts as leaving one and joining another, and reordered ranks as promotions or demotions.
- Boss fights come from the game's encounter events, which Forever's own UI never uses (its boss banner is retail-only), so it's unconfirmed that every boss sends them. A boss with no encounter isn't logged. After a reload during a fight, its length may count only from the reload.
- Legacy Challenges come from the `ACHIEVEMENT_EARNED` event, which Blizzard's own Legacy Challenges window listens for. Whether Forever fires it (its window only opens once you have renown with the legacy reward faction) is unchecked in the live game; `/tl log achievement` shows what was recorded.
- AFK time is the time the game marks you AFK (`/afk`, or idle long enough), so the idle minutes before that count as active. A change while the client hides it (in dungeons) is missed.
- XP by source splits the XP bar's gain into quests, kills, discoveries, rested and other. Other is the rest, including kills and discoveries the client hides in dungeons. The totals count from the oldest session in the character file that recorded experience gained, so earlier XP isn't in them.
- Rested is the rested bonus, counted from the rested pool going down (two pool points per bonus XP), but not while logged out, at max level or when the pool can't be read. It assumes a kill's chat line includes the bonus in its XP, as Classic's did, so rested is taken out of kills, or out of other beyond the kills chat showed. Sessions from before TravelLog counted it have none.
- Kills count only when they give XP, since this client has no combat log for addons. [TravelLog_Kills](../TravelLog_Kills/) records every kill.
- The killer and an environmental `cause` come from the game's death recap (its Death Recap window), read a frame after dying and again a second later. A recap already used for an earlier death, or there at login, isn't used again. A killer the recap hides or makes unreadable isn't named; Totals count kills by players and their pets as "by players".
- Without a recap, `cause` comes from the breath and fatigue bars (run out in the last minute) and from falls over 1.5 s that end within a second of dying, and a mob kill right after a long fall counts as the fall.
- How you came back is known when you chose it in the game's dialogs (resurrection, spirit healer, soulstone and the like, corpse) in the 30 s before. Battleground spirit healers aren't. A resurrection names the player but not the spell.
- Durability lost needs a reading from before the death, so a revival after a reload while dead has none.
- Lost and passed rolls come from the group loot history. A roll is logged only if TravelLog saw it undecided, so one decided while you were reloading is missed.
- Item tooltips read only the log of the character you're on, so they don't show what your alts got. They match by item ID, so an item with another random enchantment counts as the same one. Buybacks and guild bank withdrawals don't count.
- Items used up (potions, food, reagents) aren't recorded: no event says an item was consumed.
- Mailed items are saved by item ID, so their link has no random enchantment ("of the Bear").
- Destroyed items are recorded only when picked up from your bags or gear first, so a gamepad delete isn't.
- Guild bank items are read from what your bags gain or lose within 10 s of a guild bank click, so equipping or destroying an item in those seconds counts as a move, and an item held on the cursor longer is missed. Moves between tabs aren't logged.
- Money reasons are guesses from the window that's open and what you clicked in the few seconds before. A bank slot that costs nothing logs no entry.
- Sales are read from the 12-slot buyback list, so selling more than 12 items in one click (Sell All Junk) may not list each one. The money total is always right.
- Vendor buys, buybacks and repairs are logged only after the bag count, buyback list or repair cost confirms them within 5 seconds. Failed clicks aren't logged; a confirmation delayed longer than that is missed.
- A note can't be edited or deleted on its own. TravelLog_Share sends them with the rest of your log to the players you allow when they ask for it.
- World buffs are the spell IDs in `WORLD_BUFFS` (`TravelLog/WorldBuffs.lua`), from Classic; Boon of Blackfathom (430947) may not exist in Forever. Only a new aura counts: buffs you have at login, after a reload or through a loading screen aren't logged, nor is a buff the game refreshes in place while you have it. A buff gained while the game hides aura data (combat, boss fights) or during a loading screen is missed. `by` is filled only when the aura names its caster as a unit the client knows, so a giver far away (a city's Rallying Cry) usually has none.
- Untested in the live game; written against the Forever 1.60.1 UI source and tested against a fake client ([tests](../tests/README.md)). If something breaks, turn on Lua errors with `/console scriptErrors 1`.
