"""Список файлов внутри .pck Godot 4 (формат v2/v3/v4, без шифрования).

    python deploy/pck_list.py build/game/CivCity.pck            # все файлы с размерами
    python deploy/pck_list.py build/game/CivCity.pck --groups   # сводка по папкам (2 уровня)
    python deploy/pck_list.py build/game/CivCity.pck --grep synty
"""
import struct
import sys
from collections import defaultdict


def read_pck(path):
    with open(path, 'rb') as f:
        data_start = 0
        if f.read(4) != b'GDPC':
            raise SystemExit('%s: не .pck (нет GDPC в начале)' % path)
        version, major, minor, patch, flags = struct.unpack('<5I', f.read(20))
        file_base = struct.unpack('<Q', f.read(8))[0]
        if version >= 3:
            dir_offset = struct.unpack('<Q', f.read(8))[0]
            f.seek(dir_offset + data_start)
        else:
            f.read(64)
        if flags & 1:
            raise SystemExit('%s: каталог зашифрован' % path)
        count = struct.unpack('<I', f.read(4))[0]
        out = []
        for _ in range(count):
            sl = struct.unpack('<I', f.read(4))[0]
            name = f.read(sl).rstrip(b'\0').decode('utf-8')
            ofs, size = struct.unpack('<QQ', f.read(16))
            f.read(16)  # md5
            fl = struct.unpack('<I', f.read(4))[0]
            out.append((name, size, fl))
        return (major, minor, patch, version), out


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    if len(sys.argv) < 2:
        print(__doc__)
        return
    ver, files = read_pck(sys.argv[1])
    args = sys.argv[2:]
    total = sum(s for _, s, _ in files)
    if '--groups' in args:
        g = defaultdict(lambda: [0, 0])
        for n, s, _ in files:
            p = n.replace('res://', '').split('/')
            if p[0] == '.godot' and len(p) > 2 and p[1] == 'imported':
                key = '.godot/imported'
            else:
                key = '/'.join(p[:2]) if len(p) > 2 else p[0]
            g[key][0] += 1
            g[key][1] += s
        for k, (c, s) in sorted(g.items(), key=lambda kv: -kv[1][1]):
            print('%10.2f MB  %5d  %s' % (s / 1048576, c, k))
    else:
        pat = args[args.index('--grep') + 1] if '--grep' in args else None
        for n, s, fl in sorted(files):
            if pat is None or pat in n:
                print('%12d  %s%s' % (s, n, '  [removed]' if fl & 2 else ''))
    print('Godot %d.%d.%d, формат pck v%d: %d файлов, %.2f MB' % (ver[0], ver[1], ver[2], ver[3], len(files), total / 1048576))


if __name__ == '__main__':
    main()
