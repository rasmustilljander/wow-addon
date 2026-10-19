"""Runs the addon tests in a real Lua 5.1, outside the game.

    pip install lupa
    python tests/run.py                         # every test
    python tests/run.py tests/TravelLog/loot.lua   # just some

Each test file gets a fresh Lua state with tests/wowmock.lua loaded.
"""
import sys
from pathlib import Path

try:
    from lupa import lua51
except ImportError:
    sys.exit("This needs lupa, which bundles Lua 5.1: pip install lupa")

TESTS = Path(__file__).resolve().parent
REPO = TESTS.parent


def run(path):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().REPO = str(REPO).replace("\\", "/")
    lua.execute((TESTS / "wowmock.lua").read_text(encoding="utf-8"))
    test = lua.eval("function(src, name) return assert(loadstring(src, '@' .. name))() end")
    print(f"{path.relative_to(REPO)}")
    try:
        test(path.read_text(encoding="utf-8"), str(path.relative_to(REPO)))
    except Exception as err:  # a Lua error escaped the test
        print(f"  ERROR: {err}")
        return 0, 1
    m = lua.globals().M
    failed = m.failed + len(m.errors)
    print(f"  {m.passed} passed, {failed} failed")
    return m.passed, failed


def main():
    paths = [Path(p).resolve() for p in sys.argv[1:]] or sorted(TESTS.glob("*/*.lua"))
    passed = failed = 0
    for path in paths:
        p, f = run(path)
        passed, failed = passed + p, failed + f
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
