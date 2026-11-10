"""Verify the exact supported game build, then compile the adapter with Zig."""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import subprocess
import os
import json

from low_priority import enable

ROOT = Path(__file__).resolve().parents[1]


def verify(executable):
    profile = json.loads((ROOT / 'build-profile.json').read_text())
    header = (ROOT / 'native/game_build.h').read_text()
    with executable.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != profile['sha256']:
        raise ValueError('Unsupported executable: re-analyse offsets before changing the build profile')
    data = executable.read_bytes()
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    count = struct.unpack_from('<H', data, pe + 6)[0]
    opt_size = struct.unpack_from('<H', data, pe + 20)[0]
    sections = [struct.unpack_from('<IIII', data, pe + 24 + opt_size + 40 * i + 8)
                for i in range(count)]

    def constant(name):
        match = re.search(r'#define\s+' + re.escape(name) + r'\s+(0x[0-9a-fA-F]+)', header)
        if not match:
            raise ValueError(f'Missing constant: {name}')
        return int(match[1], 16)

    assert constant('EXPECTED_TIMESTAMP') == struct.unpack_from('<I', data, pe + 8)[0]
    assert constant('EXPECTED_IMAGE_SIZE') == struct.unpack_from('<I', data, pe + 24 + 56)[0]
    for key, name in [('region_owner', 'REGION_OWNER_OFFSET'), ('pawn_main', 'PAWN_MAIN_OFFSET'),
                      ('instance_layouts', 'INSTANCE_LAYOUTS_OFFSET')]:
        assert profile[key] == constant(name), name
    encoded = re.search(r'EXPECTED_SHA256_BYTES\s+\{([^}]+)\}', header)[1]
    assert bytes(int(x.strip(), 16) for x in encoded.split(',')).hex() == digest
    for name, rva, size in profile['entries']:
        section = next(s for s in sections if s[1] <= rva < s[1] + s[2])
        raw = section[3] + rva - section[1]
        expected = re.search(re.escape(name) + r'_bytes\[\]=\{([^}]+)\}', header)[1]
        expected = bytes(int(x.strip(), 16) for x in expected.split(','))
        assert len(expected) == size and data[raw:raw + size] == expected, name
        assert '{' + hex(rva) + ',' + name + '_bytes' in header, name
    for key, name in [('deer_dispatch_rva', 'DEER_DISPATCH_RVA'),
                      ('deer_dispatch_original', 'DEER_DISPATCH_ORIGINAL'),
                      ('deer_dispatch_animals', 'DEER_DISPATCH_ANIMALS')]:
        assert profile[key] == constant(name), name
    rva = profile['deer_dispatch_rva']
    section = next(s for s in sections if s[1] <= rva < s[1] + s[2])
    raw = section[3] + rva - section[1]
    assert struct.unpack_from('<I', data, raw)[0] == profile['deer_dispatch_original'], 'Deer dispatch'
    assert struct.unpack_from('<I', data, raw + 6 * 4)[0] == profile['deer_dispatch_animals'], 'Small game dispatch'
    hunting = (ROOT / 'native/deer_hunting_build.h').read_text()
    rva = int(re.search(r'HUNTING_RVA\s+(0x[0-9a-f]+)', hunting)[1], 16)
    size = int(re.search(r'HUNTING_SIZE\s+(\d+)', hunting)[1])
    expected = re.search(r'HUNTING_SHA256_BYTES\s+\{([^}]+)\}', hunting)[1]
    expected = bytes(int(x.strip(), 16) for x in expected.split(',') if x.strip())
    section = next(s for s in sections if s[1] <= rva < s[1] + s[2])
    raw = section[3] + rva - section[1]
    assert hashlib.sha256(data[raw:raw + size]).digest() == expected, 'Native hunting function'
    return digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', required=True, type=Path)
    parser.add_argument('--zig', default='zig')
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/StartingResources-0.1.2.dll')
    args = parser.parse_args()
    enable()
    print('Verified executable SHA-256:', verify(args.exe), flush=True)
    if args.verify_only:
        return
    args.output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.setdefault('ZIG_LOCAL_CACHE_DIR', str(ROOT / 'build/zig-cache'))
    env.setdefault('ZIG_GLOBAL_CACHE_DIR', str(ROOT / 'build/zig-global-cache'))
    subprocess.run([args.zig, 'cc', '-target', 'x86_64-windows-gnu', '-std=c11', '-O2',
                    '-Wall', '-Wextra', '-Werror', '-shared', str(ROOT / 'native/starting_resources.c'),
                    '-o', str(args.output), '-lbcrypt'], env=env, check=True)
    print('Built:', args.output)


if __name__ == '__main__':
    main()
