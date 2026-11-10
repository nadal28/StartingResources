"""Run Lua 5.4 regression tests without starting Manor Lords."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from low_priority import enable

enable()
from lupa.lua54 import LuaRuntime

compiled = 0
for path in sorted((ROOT / 'Scripts').glob('*.lua')):
    LuaRuntime().execute('assert(load(...))', path.read_text(encoding='utf-8'))
    compiled += 1

checks = 0
catalog = LuaRuntime(unpack_returned_tuples=True)
catalog.execute("package.path = ... .. '/Scripts/?.lua;' .. package.path", ROOT.as_posix())
ids = catalog.execute("local ids = {}; for _, r in ipairs(require('resource_setup_model').resources) do ids[#ids + 1] = r.id end; return ids")
c_source = (ROOT / 'native/starting_resources.c').read_text()
allowed = re.search(r'unsigned allowed=([^;]+);', c_source)[1]
assert set(ids.values()) == {int(x) for x in re.findall(r'1u<<([0-9]+)', allowed)}, 'Lua and native resource IDs differ'
checks += 1
for path in sorted(Path(__file__).parent.glob('test_*.lua')):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_ROOT = ROOT.as_posix()
    lua.execute("package.path = TEST_ROOT .. '/Scripts/?.lua;' .. package.path")
    count = lua.execute(path.read_text(encoding='utf-8'))
    checks += count
    print(f'{path.name}: {count} checks')
print(f'PASS: {checks} checks; {compiled} Lua scripts compiled')
