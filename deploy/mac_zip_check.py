"""Проверка архива для Mac (build/mac/CivCity-mac.zip) — её делает deploy/build_game.sh mac, можно и вручную:

    python -I deploy/mac_zip_check.py build/mac/CivCity-mac.zip [НОМЕР_СБОРКИ]

Что должно быть, иначе на Mac игра не откроется или скажет «приложение повреждено»:
  - CivCity.app/Contents/MacOS/CivCity с признаком «исполняемый» (права unix в атрибутах файла внутри zip);
  - CivCity.app/Contents/Info.plist (с bundle id ru.civcity.game);
  - подпись ad-hoc: CivCity.app/Contents/_CodeSignature/CodeResources;
  - вся игра одним файлом CivCity.app/Contents/Resources/CivCity.pck (код + модели + интерфейс + музыка) и никаких
    других наборов рядом;
  - внутри набора — номер сборки (mac_build.txt), если его передали вторым аргументом.
Код выхода 0 — всё на месте.
"""
import os
import stat
import struct
import sys
import zipfile

APP = 'CivCity.app/Contents/'


def pck_files(z, info):
    """Имена файлов внутри CivCity.pck (формат Godot 4, без шифрования) — читаем каталог прямо из zip."""
    with z.open(info) as f:
        head = f.read(64)
        if head[:4] != b'GDPC':
            return None
        version, major, minor, patch, flags = struct.unpack('<5I', head[4:24])
        dir_offset = struct.unpack('<Q', head[32:40])[0] if version >= 3 else 64 + 24 + 8
    with z.open(info) as f:
        # zip сжат — до каталога дочитываем по порядку (каталог Godot кладёт в конец файла)
        left = dir_offset
        while left > 0:
            chunk = f.read(min(left, 8 << 20))
            if not chunk:
                return None
            left -= len(chunk)
        count = struct.unpack('<I', f.read(4))[0]
        out = {}
        for _ in range(count):
            sl = struct.unpack('<I', f.read(4))[0]
            name = f.read(sl).rstrip(b'\0').decode('utf-8')
            ofs, size = struct.unpack('<QQ', f.read(16))
            f.read(16)
            f.read(4)
            out[name] = size
        return out


def main():
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    path = sys.argv[1]
    want_build = sys.argv[2] if len(sys.argv) > 2 else ''
    z = zipfile.ZipFile(path)
    names = {i.filename: i for i in z.infolist()}
    bad = []
    print('   архив: %s, %.1f МБ, файлов внутри: %d' % (os.path.basename(path), os.path.getsize(path) / 1048576, len(names)))
    exe = names.get(APP + 'MacOS/CivCity')
    if exe is None:
        bad.append('нет %sMacOS/CivCity' % APP)
    else:
        mode = exe.external_attr >> 16
        print('   %sMacOS/CivCity: права %s (%o), создан на системе %d (3 — unix), %.1f МБ'
              % (APP, stat.filemode(mode), mode & 0o7777, exe.create_system, exe.file_size / 1048576))
        if not mode & 0o111:
            bad.append('у движка нет признака «исполняемый» — на Mac не запустится')
    plist = names.get(APP + 'Info.plist')
    if plist is None:
        bad.append('нет %sInfo.plist' % APP)
    else:
        text = z.read(plist).decode('utf-8', 'replace')
        ok_id = 'ru.civcity.game' in text
        print('   %sInfo.plist: есть, bundle id ru.civcity.game — %s' % (APP, 'да' if ok_id else 'НЕТ'))
        if not ok_id:
            bad.append('в Info.plist нет bundle id ru.civcity.game')
    sig = [n for n in names if n.startswith(APP + '_CodeSignature/')]
    print('   %s_CodeSignature: %s' % (APP, ', '.join(sorted(os.path.basename(n) for n in sig)) or 'НЕТ'))
    if not sig:
        bad.append('нет подписи (Contents/_CodeSignature)')
    pck = names.get(APP + 'Resources/CivCity.pck')
    if pck is None:
        bad.append('нет %sResources/CivCity.pck' % APP)
    else:
        print('   %sResources/CivCity.pck: %.1f МБ' % (APP, pck.file_size / 1048576))
        files = pck_files(z, pck)
        if files is None:
            bad.append('CivCity.pck не читается как набор Godot')
        else:
            groups = {}
            for n in files:
                key = '/'.join(n.split('/')[:2]) if n.startswith('assets/') else n.split('/')[0]
                groups[key] = groups.get(key, 0) + 1
            # данные картинок, моделей и музыки лежат в .godot/imported, а в папках assets — их описания (.import)
            for need in ['assets/synty', 'assets/people', 'assets/animals', 'assets/artisau', 'assets/music', 'assets/ui',
                         'assets/fonts', 'assets/sfx', 'scripts', 'shaders', '.godot']:
                if groups.get(need, 0) <= 0:
                    bad.append('в CivCity.pck нет %s' % need)
            # не картинки и не модели, а файлы, которые игра читает сама (scripts/synty.gd: слоты материалов Synty)
            for need in ['assets/synty/MaterialList_PolygonAncientEmpire.txt', 'project.binary']:
                if need not in files:
                    bad.append('в CivCity.pck нет %s' % need)
            print('   внутри набора: %d файлов, %.1f МБ; по папкам (файлов): %s' % (len(files), sum(files.values()) / 1048576, ', '.join(
                '%s %d' % (k, v) for k, v in sorted(groups.items(), key=lambda kv: -kv[1])[:9])))
            tests = [n for n in files if n.startswith('test_') or n.startswith('scripts/test_')]
            if tests:
                bad.append('в набор попали проверки: ' + ', '.join(tests[:5]))
            if want_build:
                if 'mac_build.txt' not in files:
                    bad.append('в наборе нет mac_build.txt (номер сборки)')
                else:
                    print('   номер сборки внутри: есть (mac_build.txt)')
    extra = [n for n in names if n.endswith('.pck') and n != APP + 'Resources/CivCity.pck']
    if extra:
        bad.append('лишние наборы рядом: ' + ', '.join(extra))
    for b in bad:
        print('   ОШИБКА: ' + b)
    if not bad:
        print('   архив в порядке')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
