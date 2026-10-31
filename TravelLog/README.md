# TravelLog

Records your travels in WoW: Forever so you can retrace them: loot, vendor trades, money, flights, deaths, quests and more.

Optional companions:

| Addon | Adds | Needs TravelLog |
| --- | --- | --- |
| [TravelLog_Path](../TravelLog_Path/) | Your path and jumps, drawn on the world map | yes |
| [TravelLog_Nodes](../TravelLog_Nodes/) | Looted chests, herbs and ore on the minimap and world map | yes |
| [TravelLog_Share](../TravelLog_Share/) | A friend's nodes, trail and totals | yes |
| [TravelLog_Kills](../TravelLog_Kills/) | Every kill per mob | no |
| [TravelLog_NPCs](../TravelLog_NPCs/) | NPCs you've talked to and what they sell | no |
| [TravelLog_Group](../TravelLog_Group/) | Every player you group with | no |

## What it records

Every entry is stamped with time, zone, subzone, map ID and map coordinates.

| | |
| --- | --- |
| **Loot** | Corpses, pickpockets, chests, herbs, ore, fishing and containers: items, coins and source (name, NPC or object ID, and the spell for herbs, ore, chests, skinning and Pick Pocket). |
| **Other items** | Quest rewards, crafts, roll wins (with your roll), trades, mail, and other items that arrive without a loot window. |
| **Rolls** | Group loot rolls you lost or passed on: your choice and roll, and who won with what. |
| **Items used** | Potions, food, bandages, reagents and ammo you use up, with the spell when the client shows it; the materials each craft took; what each boss fight used. |
| **Items out** | Items you trade, mail, put up for auction (with bid and buyout) or destroy. |
| **Guild bank** | Items you put in and take out, one entry per visit. |
| **Vendors** | Purchases with price, sales, buybacks and repairs, with the vendor's name. |
| **Money** | Every gold change with a reason (see `money` [below](#entry-fields)). Trades and mail name the other player. |
| **Travel** | Zone and subzone changes (first visits marked); time per zone, and how much of it in combat, dead, AFK, flying and grouped (totals only); flights; hearthstones and other teleports; summons; boat and zeppelin rides; dungeons and raids (time inside, bosses killed and wiped on); instance resets and new lockouts; resting in inns and cities; hearthstone binds; screenshots ([some automatic](#automatic-screenshots)); notes you add with `/tl note`. |
| **Life** | Deaths (killer, spell and damage, or drowning, fatigue, a fall, fire, lava or slime); spirit releases; revivals (how, time dead, durability lost); level-ups (time the level took, health, power, base stats, item level and what the level gave); quests accepted, completed, abandoned and failed; kills that gave XP; boss kills and wipes; discoveries; world buffs (Rallying Cry, Warchief's Blessing, Spirit of Zandalar, Songflower, the Dire Maul tribute, Sayge's fortunes, Boon of Blackfathom); guilds joined, left or kicked from, and rank changes. |
| **PvP** | Duels, battlegrounds (result, length and your scoreboard line), honorable kills, honor awards and your PvP rank going up or down. |
| **Progress** | Spells and recipes learned (rank, trainer, cost); new skills and every 25 skill points; talent points spent and reset; flight paths found; reputation standings, and reputation gained and lost per faction (totals only); the first ride on each mount; beasts tamed, your hunter pet's level-ups, deaths, revives, abandoning and stabling; the first time you wear each piece of gear (not shirts or tabards) and each bag; new permanent enchants on worn gear; Legacy Challenges (Forever's achievements). |
| **Sessions** | Each login or reload: start and end (time and place), level, money, experience gained (and its rested bonus) and time AFK. |

## Window

Pick TravelLog from the minimap's addons dropdown, or type `/tl`.

- **Totals**: Travel, Loot (money in and out by reason), Life and Log. Reputation and time by zone show the top three here and all in `/tl stats`, which also splits each zone's time by state: `Elwynn Forest 6m (combat 1m, AFK 2m, grouped 3m)`. **Character**'s `<` and `>` step through your characters, [friends'](../TravelLog_Share/) characters and all of yours added up (a place several visited counts once; friends aren't added). Time played, log entries and the Kills and Group rows show only for the character you're on.
- **Settings**: the companions' map options; Path's trail, fade, curves and interval; whether gold and XP per hour leave out AFK time and whether each level-up says in chat what it gave (both on by default); [automatic screenshots](#automatic-screenshots).
- **History**, newest first:
  - **Events**: filter by Travel (notes too), Loot, Trade, Life (PvP and guilds too) or Progress, or search types, descriptions, names, places, dates and saved fields. Try `death`, `revival`, `level` or `note`. Right-click an entry to delete it, or to edit a note (Enter saves, Escape cancels).
  - **Sessions**: length, time AFK, levels, start and end place, money and XP gained (per hour after 10 minutes; AFK time left out by default), quests done and failed, XP kills and deaths. Hover one for XP by source.
  - **Levels**: time played at each level, when you reached it, quests done and failed, XP kills, deaths, money gained or spent, and the zone with most events. Hover one for XP by source, discoveries, what the level gave and its top three zones.
- **Next level** (top of Levels, and in Totals): XP to go and how long at your XP per hour, e.g. `1,400 xp to go (50%), about 1h 0m at 1,400 xp/h`. The rate is from your latest sessions, whole ones back to 2 hours of play, AFK left out by default; it shows after 10 minutes.
  - **Kills**, with [TravelLog_Kills](../TravelLog_Kills/README.md#window).
- **NPCs**, **Players**, **Colors** and **Friends** tabs come with [TravelLog_NPCs](../TravelLog_NPCs/README.md#window), [TravelLog_Group](../TravelLog_Group/README.md#window), [TravelLog_Path](../TravelLog_Path/README.md#colors) and [TravelLog_Share](../TravelLog_Share/README.md#the-friends-tab).

## Item tooltips

A rare or better item's tooltip says when, where and how this character first got it, and how often when more than once:

```
First looted 2026-10-02 from Defias Thug, Westfall
Got 3 times
```

It counts items looted, received (roll wins, quest rewards, crafts, mail, trades) and bought.

## Automatic screenshots

Taken a moment after the event, so its glow or banner shows, and logged like your own.

| When | Name | Default | After |
| --- | --- | --- | --- |
| A level-up (not to level 1) | `level` | on | 1 s |
| A boss kill | `boss` | on | 0.5 s |
| Only a boss's first kill in this character's log (with `boss` on) | `first` | on | |
| A Legacy Challenge earned | `achievement` | off | 1 s |

None is taken within 1 s of another, so a level-up and a challenge together give one.

## Commands

| Command | |
| --- | --- |
| `/tl` | Open or close the window |
| `/tl stats [all\|name]` | Totals for this character, all of yours added up, or another or a friend's (`Name` or `Name-Realm`) |
| `/tl log [n] [search]` | The last n matching events (default 15), e.g. `/tl log 20 death`, each with its `#` |
| `/tl note <text>` | Add a note to the log |
| `/tl edit <#> <text>` | Change a note's text |
| `/tl delete <#>` | Delete one entry; asks for `/tl delete <#> confirm` first |
| `/tl sessions [n]` | The last n sessions (default 10), with XP by source |
| `/tl screenshots [level\|boss\|first\|achievement on\|off]` | Show or change automatic screenshots |
| `/tl wipe confirm` | Delete everything TravelLog, Path and Nodes have for this character, then reload. Kills and Group have their own `wipe confirm`. |

`/travellog` works too. Companions add `/tl jumps`, `/tl trail`, `/tl fade`, `/tl smooth`, `/tl interval` ([Path](../TravelLog_Path/README.md#commands)), `/tl nodes` ([Nodes](../TravelLog_Nodes/README.md#commands)) and `/tl share` ([Share](../TravelLog_Share/README.md#the-friends-tab)), and lines to `/tl stats`.

## Where the data is

WoW saves only on logout or `/reload`, so a crash loses everything since. `/reload` now and then on long sessions.

| File under `WTF/Account/<ACCOUNT>/` | Contents |
| --- | --- |
| `SavedVariables/TravelLog.lua` | `TravelLogDB`: `settings` (the companions' too, and the window's `point`) and `chars["Name-Realm"]`, each character's profile and totals (`stats`) |
| `<Realm>/<Character>/SavedVariables/TravelLog.lua` | `TravelLogCharDB`: that character's log, sessions and what TravelLog compares against (below) |

Companions' files are described in their READMEs. Nothing is pruned: the log and sessions stay until you delete entries or `/tl wipe confirm`. Deleting an entry leaves totals as they were, except the notes count; Nodes keeps its spots.

Time by zone is in `stats.zoneTime[zone]` (seconds), and by state in `stats.zoneStateTime.<state>[zone]`, states being `combat`, `dead`, `afk`, `flight` and `group`.

Both files save `version`, TravelLog's data version (now 1). A file from a newer TravelLog is left untouched and nothing is recorded, Path, Nodes and Share included: for that character, or with the account file, for all. Chat, `/tl` and the addons dropdown say why.

```lua
TravelLogCharDB = {
  version = 1,
  log = {   -- oldest first
    { type = "loot", time = 1760000000, zone = "Elwynn Forest", subzone = "Goldshire",
      map = 1429, x = 42.1, y = 65.3, source = "Peacebloom", sourceType = "GameObject",
      sourceID = 1618, via = "Herb Gathering", lastHere = 1759998200,
      items = { { item = "|cffffffff|Hitem:2447:...|h[Peacebloom]|h|r", count = 2 } } },
  },
  sessions = {   -- one per login or reload
    { start = 1760000000, stop = 1760007200, level = 12, levelEnd = 13, money = 10000, moneyEnd = 12500,
      xp = 5600, rested = 1400, afk = 1200,   -- rested: bonus XP; afk: seconds
      zone = "Elwynn Forest", subzone = "Goldshire", map = 1429, x = 42.1, y = 65.3,   -- where you logged in
      zoneEnd = "Stormwind City", subzoneEnd = "Old Town", mapEnd = 1453, xEnd = 75.2, yEnd = 61.8 },  -- and out
  },
  quests = { [54] = { title = "Report to Goldshire", accepted = ..., done = ..., abandoned = ..., failed = ... } },  -- last time of each
  skills = { [129] = 75 },               -- skill ID -> rank
  talents = { [7001] = { [101] = 3 } },  -- loadout ID -> talent node ID -> rank
  mounts = { [458] = 1760000000 },       -- mount spell ID -> first ride
  instance = { name = "The Deadmines", kind = "dungeon", id = 36, inside = 600, since = ..., kills = 2, wipes = 1 },  -- while in one
  fight = { id = 2972, since = 1760000000 },  -- the boss fight in progress
  lockouts = { ["Molten Core:9:1001"] = 1760600000 },  -- "name:difficulty ID:lockout ID" -> when it resets
  rest = { inside = 600, since = ... },  -- while resting
  gear = { [25] = 0, [2361] = 1760000000 },   -- item ID -> first worn (0: worn when recording began)
  bags = { [4496] = 0, [4245] = 1760000000 }, -- bag item ID -> first equipped (0: likewise)
  pvpRank = { rank = 3, season = 1 },    -- last rank seen
  guild = { name = "Wanderers", rank = "Officer", rankIndex = 2, since = 1760000000 },  -- {} for none
}
```

### Entry fields

Every entry has `type`, `time` and the place stamp (`zone`, `subzone`, `map`, `x`, `y`); what the game doesn't reveal (coordinates in dungeons) is left out. Item lists are `{ item = link, count }`; money and prices are in copper.

| Type | Fields |
| --- | --- |
| `area` | `first`: `true` on your first visit to the subzone (or zone) |
| `loot` | `source` (name), `sourceType` (`Creature`, `GameObject`, `Item`, `Fishing`, ...), `sourceID`, `via` (the spell, e.g. Herb Gathering, Pick Pocket), `items`, `money`; with TravelLog_Nodes, `lastHere` (when the spot was last looted) and `lastBy` (the alt who did) |
| `receive` | `item`, `count`, `how` (`loot`, `created`, `quest`, `mail`, `trade`, `roll` or `received`); `roll` for a won roll, `sender` from mail, `partner` from a trade, `materials` (an item list) for a craft |
| `use` | `item`, `count`, and `spell` and `spellID` of your cast that used it, when seen. The same item used the same way within 30 s of the last adds to the entry, if nothing was logged in between. |
| `roll` | `item`, `choice` (`need`, `offspec`, `transmog`, `greed` or `pass`), `roll` (none for a pass), `winner` and `winnerRoll` (none when everyone passed) |
| `buy`, `sell`, `buyback` | `item`, `count`, `price`, `vendor`; `otherCurrency` (`true`) for a `buy` priced in items or currency |
| `repair` | `price`, `vendor`, `guildBank` (`true` when the guild paid) |
| `give` | A trade: `items`, `partner` |
| `send` | Mail: `items`, `recipient` |
| `post` | An auction: `item`, `count`, `bid`, `buyout` (a commodity has only `buyout`, for the whole stack) |
| `destroy` | `item`, `count` |
| `guildbank` | `deposited` and `withdrawn` (item lists), `guild` |
| `money` | `amount` (negative when spent), `balance`, `reason`: `loot`, `vendor`, `flight`, `quest`, `training`, `mail`, `cod`, `trade`, `auction` (buys, and sales paid by mail), `deposit` (auction deposit), `bankslot`, `bank` (account bank), `guildbank`, `barber`, `respec` (talent reset), `stable` (stable slot) or `other`. `partner`, `sender` or `recipient` for trades and mail, `item` for an auction sale. |
| `bankslot` | `bank` (`character` or `account`), `slot`, `price` |
| `flight` | `from`, `to` (flight points), `price`; `seconds` flown, added on landing |
| `landed` | `from`, `to`, `seconds`; none after a reload in the air |
| `hearth`, `teleport` | `from`, `to` (place names); `spell` and `via` (its name) when your cast did it |
| `summon` | `from`, `to`, `by` (the summoner) |
| `board`, `rest`, `release` | none |
| `disembark` | `from`, `to`, `seconds` on board |
| `instance` | `name`, `kind` (`dungeon`, `raid`, `battleground`, `arena` or `scenario`), `difficulty`, `size`, `id` |
| `instanceleave` | `name`, `kind`, `seconds` inside; `kills` and `wipes` when any |
| `instancereset` | `name`; `failed` when it didn't work: `inside` (players still inside), `offline` (party members offline) or `zoning` (players entering) |
| `lockout` | `name`, `kind` (`dungeon` or `raid`), `difficulty`, `size`, `lockout` (its ID), `resets` (a `time` value) |
| `boss` | `name` and `id` of the encounter, `result` (`kill` or `wipe`), `difficulty`, `size` (group size), `seconds` (from the pull, when seen), `instance`, `used` (items used during the fight, when any) |
| `bind` | `place`: where your hearthstone is now set |
| `restleave` | `seconds` resting, `rested` (your rested XP pool as you leave, if any) |
| `note` | `text` |
| `screenshot` | `file`: the game's name for it without extension (`WoWScrnShot_102226_143005`, local date and time); for an automatic one, `auto` (`level`, `boss` or `achievement`) and `what` (the level, boss or challenge) |
| `quest`, `questabandon` | `id`, `title` |
| `questdone` | `id`, `title`, `xp`, `money` |
| `questfail` | `id`, `title`, `reason` (`time` when its timer ran out) |
| `kill` | `name`, `xp` |
| `discover` | `place`, `xp` |
| `standing` | `faction`, `standing` reached |
| `level` | `level` reached, `played` (seconds in all), `took` (seconds at the level before), `hp` and `power` (max), `powerType` (`MANA`, `RAGE`, `ENERGY`, ...), `stats` (base Strength, Agility, Stamina, Intellect, Spirit), `ilvl` (average of worn gear), `gain` (`{ hp, power, stats }` the level gave) |
| `death` | `target` (the hostile unit you had targeted), `level`, `cause` (`drowning`, `fatigue`, `falling`, `fire`, `lava` or `slime`, when known). From the death recap's killing blow: `killer`, `killerType` (`Creature`, `Player` or `Pet`), `killerID` (a creature's NPC ID), `spell` and `spellID` (none for melee), `amount` (damage, overkill included), `overkill` (when above 0). |
| `revive` | `how` (`corpse`, `spirithealer`, `player` or `selfres`, when known), `by` (who resurrected you), `spell` (the self-resurrection: Soulstone, Reincarnation, ...), `sickness` (`true` with resurrection sickness), `took` and `ghost` (seconds since the death and since the release), `durability` (average percentage points lost on worn items) |
| `equip` | `slot` (1 head to 18 ranged), `item`, `ilvl`, `quality` (0 poor, 1 common, 2 uncommon, ...), `replaced` (the link it replaced). `ilvl` and `quality` are missing if the item wasn't loaded yet. |
| `enchant` | `slot`, `item` (with the new enchant), `enchant` (ID), `name` (its tooltip line, e.g. `Crusader`); `old` and `oldName` for the one it replaced. Names are missing if the tooltip wasn't loaded. |
| `bag` | `bag` (bag slot, 1 next to the backpack), `item`, `slots`, `quality`, `replaced` |
| `spell` | `id`, `name`, `rank`; `trainer` and `cost` when bought from a trainer |
| `skill`, `skillup` | `id`, `name`, `rank` (skill points) |
| `taxipath` | `npc`: the flight master |
| `mount` | `id` (its spell), `name`, `first` (`true`: your first mount) |
| `talent` | `name`, `id` (its spell), `tree`, `rank`, `max`, `level`; `points` when several ranks were applied at once |
| `talentreset` | `points` taken back, `spent` (points still spent), `level` |
| `tame` | `name`, `id` (creature ID), `level`, `family`; `pet` (the pet's name when it differs); `first` (`true`: your first pet) |
| `petlevel` | `name`, `family`, `level` reached |
| `petdeath`, `petrevive`, `petabandon`, `petstable`, `petunstable` | `name`, `level`, `family` |
| `achievement` | A Legacy Challenge: `id`, `name`, `points`, `category`, `reward` (e.g. a title), `already` (`true`: another character earned it first), `guild` (`true` for a guild one) |
| `duel` | `opponent`, `result` (`won`, `lost` or `interrupted`: no winner), `fled` (the loser ran), `challenger` (`you` or `opponent`) |
| `battleground` | `name`, `result` (`won`, `lost`, `draw` or `left`: before the end), `seconds`; from your scoreboard line, `killingBlows`, `honorableKills`, `deaths`, `honor` |
| `honorkill` | `name`, `rank`, `honor`; all empty for a kill known only from the count |
| `honor` | `honor` awarded |
| `pvprank` | `rank` (0 unranked), `old`, `title` (Sergeant, Knight, ...), `season`, `newSeason` (`true` when the season changed) |
| `guildjoin` | `guild`, `rank`, `by` (who invited you), `founder` (`true` when you signed its charter) |
| `guildleave` | `guild`, `rank` you had, `how` (`left`, `kicked` or `disbanded`, when known), `by`, `seconds` in the guild (when TravelLog saw you join) |
| `guildrank` | `guild`, `rank`, `from`, `change` (`promoted` or `demoted`), `by` |
| `worldbuff` | `id` (its spell), `name`, `duration` (seconds; none for a buff without one), `by` (who gave it, when known) |

## Limits

Untested in the live game; written against the Forever 1.60.1 UI source and tested against a fake client ([tests](../tests/README.md)). If something breaks, turn on Lua errors with `/console scriptErrors 1`.

**Dungeons and raids.** Addons get no coordinates there, and the client hides some chat, so crafted items, quest rewards, kills, discoveries and reputation can be missing. Loot windows and rolls still work.

**Loot and items**

- Only items whose loot slot empties are recorded. With free-for-all loot, another player's pick from a window you have open can count as yours.
- A loot window combining several corpses is credited to the first one.
- Objects are named from the cast that opened them; one opened without a cast (some quest crates) has only its object ID.
- Lost and passed rolls come from the group loot history, and only if TravelLog saw them undecided, so one decided during a reload is missed.
- Used items are what your bags lose with no vendor, trade, mail, auction or bank window open, not within 2 s of a destroy or 5 s of a quest turn-in or abandon, and not gear or bags (ammo counts). A cast of yours in the 1.5 s before counts them even with a window open, and names the spell; where the client hides casts, there's no spell.
- So an item leaving some other way (expiring, taken by an NPC) counts as used, and more than 3 different items gone at once without a cast don't count.
- A craft's materials go on its `receive` entry when its "You create" line comes within 1 s of them; where that line is hidden (dungeons), they're `use` entries.
- A boss fight's `used` counts from its pull, across a reload, so a fight whose pull wasn't seen has none.
- Mailed items are saved by item ID, so their link has no random enchantment ("of the Bear").
- Destroyed items count only when picked up from your bags or gear first, so a gamepad delete doesn't.
- Guild bank moves are what your bags gain or lose within 10 s of a guild bank click: equipping or destroying an item in those seconds counts as a move, and an item held on the cursor longer is missed. Moves between tabs aren't logged.
- Item tooltips read only this character's log and match by item ID, so another random enchantment counts as the same item. Buybacks and guild bank withdrawals don't count.

**Money and vendors**

- Money reasons are guesses from the open window and what you clicked in the few seconds before. A free bank slot logs no entry.
- Sales are read from the 12-slot buyback list, so selling more than 12 items in one click (Sell All Junk) may not list each one. The money total is always right.
- Buys, buybacks and repairs are logged once the bag count, buyback list or repair cost confirms them within 5 s, so failed clicks and slower confirmations aren't.

**Travel**

- A teleport is a jump of more than 100 yards beyond what you could have moved since the last look, a second before. A cast in the 5 s before is named as its cause, and one landing where your hearthstone is set is a hearth. Without a cast of yours (another mage's portal, an NPC), it's a teleport with no spell.
- The Hearthstone always counts, even next to the inn. Other teleports under 100 yards, teleports inside dungeons, and teleports out of a dungeon that don't land at your hearthstone are missed; leaving the dungeon is still logged.
- The client doesn't report boats and zeppelins. A ride is being carried at least 4 yards a second faster than your own speed for 5 s, and ends after 10 s on your own feet, so boats and zeppelins look the same.
- Summons are logged once you accept and arrive, without the summoner's name if the client hides it.
- Time in a dungeon or raid counts only while you're logged in; a reload inside is the same visit.
- Resets come from the "has been reset" system line and its "Cannot reset" variants, so only if your chat gets them.
- Lockouts come from the Raid Info list, read after each loading screen, 3 s after a boss kill and after "You are now saved to this instance". A new one is logged when the list first shows it, stamped where you are then. Lockouts at your first login are remembered, not logged; expired ones still listed aren't logged; world bosses aren't included.
- Boss fights come from the encounter events, which Forever's own UI never uses, so it's unconfirmed that every boss sends them. After a reload mid-fight, its length may count from the reload.
- Resting is the game's rested state, so an inn and a city look the same. A change counts once it holds 5 s, so walking through an inn's door isn't a stay. Logging in rested starts a stay without a `rest` entry; a reload or a night logged out inside is the same stay, and its time counts only while logged in.
- Time by zone counts every second you're logged in, AFK included (like `/played`), by zone, not subzone, from when TravelLog was installed. A loading screen counts for the zone you left, in the state you come out in. States overlap (AFK while grouped), so they don't add up to the zone's total; dead includes ghost; flying is a flight path, counted in each zone you fly over; AFK isn't counted while the client hides it. `/tl stats` leaves out states under a minute.
- A screenshot's `file` is worked out from your computer's clock, so it can be a second off.

**Life**

- Time played comes from `/played`, asked quietly at each login. A `/played` you type before that answer arrives (usually within a second) doesn't show, and a level-up before it gets no `took`.
- A level-up's stats are read a second later, and each second after (up to 5 s) while unreadable or unchanged; in combat, when it ends. The chat line waits for them and for `/played` (up to 10 s after login). `gain` comes from the level-up event; when the client hides it, it's the change since the level before (gear included), or missing if that level has no stats saved.
- The killer and an environmental `cause` come from the death recap, read a frame after dying and again a second later. A recap already used, or there at login, isn't used again. A hidden or unreadable killer isn't named. Totals count kills by players and their pets as "by players".
- Without a recap, `cause` comes from the breath and fatigue bars (run out in the last minute) and from falls over 1.5 s ending within a second of dying, so a mob kill right after a long fall counts as the fall.
- How you came back is known from what you chose in the game's dialogs in the 30 s before. Battleground spirit healers aren't. A resurrection names the player, not the spell.
- Durability lost needs a reading from before the death, so a revival after a reload while dead has none.
- A failed quest is noticed at the next quest log update and logged once per time you take it: not again after a reload, and abandoning it then is a `questabandon`. One failed offline is logged when first seen. Only a timer running out is told apart, and a failed quest the server removes at once isn't seen.
- Kills count only when they give XP, since this client has no combat log for addons. [TravelLog_Kills](../TravelLog_Kills/) records every kill.
- The Levels view counts what's in the log, so the level you installed at counts only from then; its time played is whole. The next-level estimate assumes your recent rate holds and doesn't count rested XP ahead.
- XP by source splits the XP bar's gain into quests, kills, discoveries, rested and other (the rest, including kills and discoveries hidden in dungeons). Totals count from the oldest session that recorded XP.
- Rested is counted from the rested pool going down (two pool points per bonus XP), not while logged out, at max level or when the pool can't be read. It assumes a kill's chat line includes the bonus, as Classic's did, so rested is taken out of kills, or out of other beyond the kills chat showed.
- AFK time is when the game marks you AFK (`/afk`, or idle long enough), so idle minutes before that count as active. A change the client hides (dungeons) is missed.
- Reputation totals come from "Reputation with Stormwind increased by 25." lines; one without an amount isn't counted.
- World buffs are the spell IDs in `WORLD_BUFFS` (`TravelLog/WorldBuffs.lua`), from Classic; Boon of Blackfathom (430947) may not exist in Forever. Only a new aura counts: not buffs you have at login or after a reload or loading screen, nor one refreshed in place. Buffs gained while the game hides aura data (combat, boss fights) or during a loading screen are missed. `by` needs the caster to be a unit the client knows, so a far-away giver (a city's Rallying Cry) usually has none.
- Legacy Challenges come from `ACHIEVEMENT_EARNED`, which Blizzard's Legacy Challenges window listens for. Whether Forever fires it is unchecked in the live game; `/tl log achievement` shows what was recorded.
- Guild changes come from your guild info and are logged 3 s after they're seen. Your guild at the first login is remembered, not logged; a change while offline is logged at the next login without `by` or `how`. Who did it comes from the system line, so others' arrivals and departures aren't logged, and declined invites are ignored. Totals count a disbanded guild or an unknown departure as left. A renamed guild counts as leaving and joining, and reordered ranks as promotions or demotions.

**Progress**

- Mounts and pets count from install, so "first" is your real first only if you hadn't ridden or tamed before.
- Talent points count when applied, not when placed. Points spent before install, or on the other spec before you first switch to it, are remembered, not logged. Re-spent points count again in the total. A reset is logged without its cost.
- No event says a tame worked: it's a Tame Beast channel that runs its full length, then a pet appearing within 5 s. The beast is your target when the channel began.
- Pet level-ups are seen only while the pet is out. A level gained while the client hides the pet's level or GUID (dungeons) is logged when they show again, if the pet is still out.
- A pet death is the game's `UNIT_DIED` for the hunter pet last out, or that pet showing as dead; each is logged once. A revive is a Revive Pet cast that goes through; it names the pet that died, or the one out, if known.
- An abandon is the game's abandon call for the pet that's out, followed by the pet going within 5 s, so a pet dismissed or killed then after a failed abandon counts too. Abandoning a pet that isn't out isn't logged.
- Stabling is seen only while the stable window is open. Moving a pet between stable slots isn't logged.
- Gear and bags count from the first login: what you wear then is remembered, not logged. Both are kept by item ID, so a second copy, or another random enchantment, isn't logged again. Only your own bag slots count; Forever's bank has tabs, not bag slots.
- An enchant is a change of the permanent enchant on a worn item within 5 s of a spell you cast (enchanting, an armor kit). Swapping in a copy with another enchant counts only if you cast something in the 5 s before. Enchants on items in your bags, and temporary ones (poisons, sharpening stones, oils), aren't logged.

**PvP**

- Duel results come from the "Ann has defeated Bob in a duel" line. The client doesn't say when your challenge is accepted, so a duel you challenged that ends without a winner is logged only if one of you crossed the duel area's edge.
- A battleground's result and scoreboard line are read when the match ends; leaving earlier, or being away then, counts as `left`. Numbers the client hides are left empty.
- Honorable kills and honor come from their chat lines. Where chat is hidden (battlegrounds), kills come from the day's kill count, without name, rank or honor, and honor awards are missed.
- Your PvP rank is your renown with the PvP rank faction, as on the character frame's PvP tab. The rank at the first login is remembered, not logged; a change while offline (a new season) is logged at the next login.

**Other**

- An entry's `#` is its place in the log, oldest first, so deleting one renumbers those after it. A confirm for an entry that has since moved asks again.
