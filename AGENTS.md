# Agent instructions

WoW: Forever addons, one per folder. Testing and API checks: `.claude/skills/addon-tests/SKILL.md`.

## Documentation

Docs are the root `README.md`, one `README.md` per addon, and `tests/README.md`. Planned work goes in `TODO.md`. Keep them short and correct.

- **Update docs in the same change as the code.** New or changed commands, saved fields, defaults, limits and map colors go in the addon's README.
- **Check every claim against the code.** Numbers (intervals, sizes, radii, defaults), command syntax, file paths and SavedVariables layouts must match the source. If you can't verify something, leave it out.
- **Write for the player first.** Lead with what the addon does, then commands, then where the data is and its format, then limits. Skip implementation details unless a player or test author needs them.
- **Say it once.** Facts shared between addons (dungeon limits) live in one README and are linked from the others.
- **Prefer tables and short bullets** for commands, fields and options. One sentence per idea; no filler, history or marketing.
- **Use examples only where they replace explanation**, like a tooltip, a chat output or a saved-data sample, and keep them minimal.
- **Don't document the obvious** or repeat what a table or code block already shows.
- When you edit a README, tighten what's around your change too. Shorter is better if nothing correct is lost.
