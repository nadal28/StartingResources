"""Create an installable archive from an explicit production file list."""
from pathlib import Path
import hashlib
import re
import zipfile

from low_priority import enable

ROOT = Path(__file__).resolve().parents[1]


def main():
    enable()
    main_source = (ROOT / 'Scripts/main.lua').read_text(encoding='utf-8')
    version = re.search(r'\[StartingResources ([0-9.]+)\]', main_source)[1]
    native_source = (ROOT / 'Scripts/resource_setup_native.lua').read_text(encoding='utf-8')
    dll = re.search(r'native/(StartingResources-[0-9.]+\.dll)', native_source)[1]
    files = [ROOT / 'README.md', ROOT / 'CHANGELOG.md', ROOT / 'docs/VALIDATION.md',
             ROOT / 'enabled.txt', ROOT / 'build-profile.json',
             *sorted((ROOT / 'Scripts').glob('*.lua')), ROOT / 'native' / dll,
             ROOT / 'native/starting_resources.c', *sorted((ROOT / 'native').glob('*.h'))]
    assert all(path.is_file() for path in files), 'A production file is missing'
    target = ROOT / 'dist' / f'starting-resources-{version}.zip'
    target.parent.mkdir(exist_ok=True)
    names = {str(Path('StartingResources') / p.relative_to(ROOT)).replace('\\', '/') for p in files}
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, Path('StartingResources') / path.relative_to(ROOT))
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == names
    print(f'{target.name}: {len(files)} files; SHA-256 {hashlib.sha256(target.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
