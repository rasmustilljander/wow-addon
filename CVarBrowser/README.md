# CVarBrowser

A window for browsing, searching, bookmarking and changing CVars (the game's console settings) in WoW: Forever.

## Commands

| | |
| --- | --- |
| `/cvars` or `/cvar` | Open or close the window |
| `/cvars <text>` | Open the window searching for `<text>` |

## The window

- **Search**: every word must appear in the CVar's name or description. CVars with the whole search in their name come first. Typing a CVar's full name also finds CVars the client knows but doesn't list.
- **Filters**: All, Bookmarks, Changed (value differs from the default) and Known (has a description from CVarBrowser).
- **List**: click the star to bookmark a CVar, or the row to select it. Changed values are white, defaults gray.
- **Selected CVar**: type a value and press Enter or **Set**. **Default** resets it, **Toggle** flips a `0`/`1` value. Each change is printed to chat, with a warning if the client didn't accept the value.
- **Info box**: what the CVar does and its values, for about 75 well-known CVars, plus the client's own help text when it has any.

The buttons are off in combat and for CVars the client doesn't let addons change (secure, read-only or locked).

## Saved data

`CVarBrowserDB` (account-wide):

| Field | |
| --- | --- |
| `bookmarks` | Lowercase name → name of each bookmarked CVar |
| `point` | Window position: `{ point, relativePoint, x, y }` |

CVar values themselves are saved by the game, not by CVarBrowser.
