---
name: addon-tests
description: Run and extend the outside-the-game tests for this repo's WoW: Forever addons (python tests/run.py against the fake client in tests/wowmock.lua), and check new WoW API calls against Blizzard's Forever UI source. Use after changing any addon code, before committing, or when adding a feature that needs a new API or event.
---

# Testing the addons

The addons run in the game, but `tests/` runs them in real Lua 5.1 against a fake client. Read `tests/README.md` for what's there and how `M` works.

## Run the tests

```
pip install lupa        # once; bundles Lua 5.1
python tests/run.py     # all tests; or pass test files
```

Every check must pass and there must be no `LUA ERROR` lines before you commit. A failure is either a real bug or a test that expected the wrong thing. Work out which before changing either one, and don't weaken a check just to get it green.

## When you change an addon

- Add or update a test for the behavior. Put it in the file for that area (`tests/<Addon>/*.lua`), or start a new file for a new area.
- If the addon uses an API, event or frame method the fake doesn't have, add it to `tests/wowmock.lua`, shaped like the real one (same arguments and returns). Add new events to `M.KNOWN_EVENTS`.
- Anything saved goes through `M.Reload()` in a test at least once, so a real save and load happens (functions can't be saved; shared tables come back as copies).
- Run `tests/TravelLog/stress.lua` after touching recording or map drawing, and compare its printed numbers with before.

## Check new APIs against the real client

The fake can't tell you whether an API exists in Forever or what it returns. Forever (WoW 1.60.x, TOC 16001) runs on the Midnight-era mainline client, with game type `camelot`, so retail-style APIs apply. Blizzard's own UI code for it is mirrored on the `forever` branch of github.com/Gethe/wow-ui-source. Fetch only the parts you need into a scratch directory, outside the repo:

```
git clone --depth 1 --branch forever --filter=blob:none --sparse https://github.com/Gethe/wow-ui-source forever-ui
cd forever-ui
git sparse-checkout set Interface/AddOns/Blizzard_APIDocumentationGenerated Interface/AddOns/Blizzard_UIPanels_Game Interface/AddOns/Blizzard_MapCanvas Interface/AddOns/Blizzard_WorldMap Interface/AddOns/Blizzard_FrameXML
```

Then:

- **Documented API**: `grep -n 'Name = "LoadAddOn"' -A 20 Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` shows its arguments, returns, event payloads and secret-value flags (`SecretArguments`, `ConditionalSecret`, `SecretInChatMessagingLockdown`, ...).
- **Undocumented globals** (loot, merchant and taxi functions): grep Blizzard's own UI for calls, e.g. `grep -rn 'GetLootSlotInfo(' Interface/AddOns/Blizzard_UIPanels_Game`. If Blizzard's code calls it, it exists. Check which files the `.toc` loads for game type camelot (`[Family]` = Mainline).
- **Key bindings**: `Interface/AddOns/Blizzard_FrameXML/Bindings_Camelot.xml`.

The Midnight-era rules addons must live with:

- Values can be "secret" (unreadable to addons): chat text in dungeons, unit names and GUIDs in some situations, spell cast info. Pass anything that might be secret through `ns.Clean` first.
- The combat log events can't be registered.
- Unknown events error on `RegisterEvent`; `ns.On` swallows that and returns false.

Only hook functions with `hooksecurefunc`, and keep anything that touches Blizzard frames (like the world map) non-interactive or click-through, to avoid taint.
