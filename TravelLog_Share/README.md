# TravelLog Share

Shares what TravelLog records with other players you choose. Players on your allow list get your looted chests, herbs and ore automatically, and can ask for your log; everyone else is refused. Every request you get is recorded. Needs [TravelLog](../TravelLog/); install [TravelLog_Nodes](../TravelLog_Nodes/) to share nodes and see other players' on the map. Both players need TravelLog Share.

## How it works

| | You share | You receive |
| --- | --- | --- |
| **Set up** | `/tl share allow Bob` | `/tl share follow Rasmus` |
| **Nodes** | Sent whenever an allowed player asks, which their addon does on its own: at their login, at yours, and when they follow you. Nodes you loot afterwards go to them right away. | Shown on your world map beside your own (see [below](#on-the-map)). Only nodes looted since the last batch are sent again. |
| **Log** | Sent only when they ask with `/tl share log`. Chat tells you who asked. | `/tl share log Rasmus 20` asks for the last 20 entries and prints them when they arrive. |

Names without a realm are on your realm. The allow list is account-wide, so all your characters answer. Each sends the nodes all your characters looted, with the total loot count, and its own log.

## Commands

| Command | |
| --- | --- |
| `/tl share` | Who you share with and follow, and the last request |
| `/tl share allow <name>` | Let `<name>` get your nodes and ask for your log |
| `/tl share revoke <name>` | Stop sharing with `<name>` |
| `/tl share follow <name>` | Get `<name>`'s nodes automatically |
| `/tl share unfollow <name>` | Stop, and drop their nodes |
| `/tl share log <name> [n]` | Ask `<name>` for their last n log entries (default 20, max 100) |
| `/tl share show <name>` | The log `<name>` last sent you |
| `/tl share requests [n]` | The last n requests you got (default 10) |

The [TravelLog window](../TravelLog/README.md#window) shows how many players you share with and follow, and when the last request came.

## On the map

Other players' nodes are drawn like yours, a little smaller and dimmer, on zone maps while `/tl nodes` is on. The tooltip says who shared it, when they last looted it and how many times.

## Where the data is

`WTF/Account/<ACCOUNT>/SavedVariables/TravelLog_Share.lua`:

```lua
TravelLogShareDB = {
  allowed = { ["bob-forever"] = "Bob-Forever" },
  follow = { ["rasmus-forever"] = "Rasmus-Forever" },
  requests = {   -- oldest first, the last 200
    { time = 1760000000, from = "Bob-Forever", to = "Rasmus-Forever", what = "log", count = 20, allowed = true },
  },
  peers = {   -- what others sent you
    ["rasmus-forever"] = { name = "Rasmus-Forever", nodesSince = 1760000000,
      nodes = { [1429] = { [3] = { kind = "herb", name = "Peacebloom", id = 1618, x = 42.1, y = 65.3, last = 1760000000, count = 8 } } },
      log = { received = 1760000000, entries = { { time = 1760000000, where = "Goldshire (42.1, 65.3)", text = "Looted ..." } } } },
  },
}
```

- `what`: `nodes` or `log`; `count` is how many log entries were asked for, `allowed` whether they were sent.
- A peer's nodes are keyed by map and by their place in that player's own list. Log entries arrive as text, as `/tl log` shows them.
- `/tl wipe confirm` drops the requests that character got; the rest stays.

## Limits

- Both players must be online. Whispers to someone offline are dropped, and the game's "No player named ... is currently playing" reply to them is hidden.
- Messages go out three a second, so a 100-entry log takes about half a minute. While the game blocks addon messages, they wait.
- A log line longer than one message (255 bytes) loses its item links, then is cut short.
- Untested in the live game; tested against a fake client ([tests](../tests/README.md)).
