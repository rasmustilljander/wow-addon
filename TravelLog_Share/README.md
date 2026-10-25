# TravelLog Share

You and a friend see each other's looted chests, herbs and ore on the map, each other's trail on the world map while you're both online, and each other's TravelLog totals in the [TravelLog window](../TravelLog/README.md#window) and `/tl stats`, like an alt's. Needs [TravelLog](../TravelLog/); nodes need [TravelLog_Nodes](../TravelLog_Nodes/) and trails [TravelLog_Path](../TravelLog_Path/). Both players need TravelLog Share.

## The Friends tab

Open it with `/tl share` or from the TravelLog window. Type a name and press Enter or **Add**; a name without a realm is on your realm. Nothing is shared until you've both added each other. A friend is one character, so add each one your friend plays. Your friend list is account-wide, so all your characters answer.

The list shows a friend's level once their totals arrive, or `waiting` while they haven't added you. Pick one to see when you last heard from them, how many of their nodes you have, when their totals arrived and how many of their trail points you have this session. **Show totals** opens their totals in the Totals tab; **Remove** drops their nodes and totals.

## What's shared

| | |
| --- | --- |
| **Nodes** | Every chest, herb and ore your characters looted, with the total loot count but not who looted it. Sent when your friend asks: at their login, at yours and when they add you. After that only new or updated nodes, and nodes you loot right away. |
| **Trail** | Your path points, every 10 seconds while you move. When your friend asks, they first get your points since their login or reload (from your current session, at most 150). |
| **Totals** | The totals of the character you're on (TravelLog's, and Path's jumps and distance), with its level, class and race. Sent in full when your friend asks, then every 5 minutes only what changed. Not your log, sessions or time played. |

A friend's character shows after yours under **Character** in the Totals tab and with `/tl stats <name>`, but never counts in **All characters** or `/tl stats all`.

The whispers are addon messages, hidden from chat. Chat tells you when someone who isn't your friend asks (at most once a minute per player), when a friend hasn't added you yet, when new nodes arrive and the first time a friend's totals arrive.

## On the map

Friends' nodes are drawn like yours, smaller and dimmer, on zone maps and the minimap while TravelLog_Nodes shows yours. The tooltip says who shared it, when they last looted it and how many times.

Friends' trails are drawn like an alt's: thinner lines in their class color, under yours, without markers. `/tl trail friends <range>` or the **Friends' trail** setting sets how far back they go (default `today`; see [TravelLog_Path](../TravelLog_Path/README.md#commands)).

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Share.lua`:

```lua
TravelLogShareDB = {
  friends = { ["bob-forever"] = "Bob-Forever" },
  peers = {   -- what friends sent you
    ["bob-forever"] = { name = "Bob-Forever", seen = 1760000000, nodesSince = 1760000000,
      nodes = { [1429] = { [3] = { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3, last = 1760000000, count = 8 } } },
      char = { name = "Bob", realm = "Forever", class = "WARRIOR", race = "Human", level = 12, received = 1760000000,
               stats = { ... } } },   -- as in TravelLogDB.chars
  },
}
```

- `seen`: when they last whispered you. `nodesSince`: the newest node you got from them.
- A peer's nodes are keyed by map and by their place in that player's own list.
- Friends' trails aren't saved.

## Limits

- Both players must be online. Whispers to someone offline are dropped, and the game's "No player named ... is currently playing" reply is hidden.
- Messages go out three a second. A well-travelled character's full totals are about 150 messages, so they take about a minute after each login; updates are a few messages. While the game blocks addon messages, they wait.
- Totals over 256 KB packed aren't taken.
- Friends' trails last until you log out or reload; after that you see only points sent from then on. At most 20,000 points per friend (about 11 hours of movement at the default interval).
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
