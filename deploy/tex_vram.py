"""Сжатие картинок Synty в видеопамяти (1.9 плана 24.10) — ОДИН переключатель на всю игру.

    python -I deploy/tex_vram.py status [ПАПКА_GODOT]        — как сейчас импортированы картинки
    python -I deploy/tex_vram.py basis  [ПАПКА_GODOT]        — Basis Universal (UASTC) + мипмапы  ← включено 26.10
    python -I deploy/tex_vram.py bc7    [ПАПКА_GODOT]        — VRAM Compressed (BC7 на ПК) + мипмапы
    python -I deploy/tex_vram.py s3tc   [ПАПКА_GODOT]        — VRAM Compressed (DXT1/DXT5) + мипмапы (меньше, грубее)
    python -I deploy/tex_vram.py off    [ПАПКА_GODOT]        — как было: без сжатия, без мипмапов (выпуск 1.0)

ПАПКА_GODOT — по умолчанию godot/ рядом с этим файлом. Меняются только строки [params] в файлах .import картинок
assets/synty/Textures (наборы Synty лежат только у владельца, в git их нет), всё остальное в файлах — как было.
После переключения: импорт (tools/godot.sh --headless --path godot --import) и обычная сборка (build_game.sh сама
пересоберёт CivCity_models.pck — его исходные файлы поменялись). Код игры готов ко всем видам картинок
(scripts/gfx.gd: копии для «Очень низкой» берутся из готовых мипмапов сжатой картинки — у Basis это KTX2 без
уровня 0, — без чтения с видеокарты).

Замер 26.10 (город владельца, RTX 3060, .work/gd/b/perf_offer): видеопамять на «Высокой» 3,0 → 1,9–2,2 ГБ, видеокарте
на ~10% легче, картинка почти та же (средняя разница точки ~2 из 255). Basis и BC7 в видеопамяти одинаковы (Basis
на ПК раскладывается в BC7 при загрузке), скачать набор моделей — 92 → 116 / 119 МБ, но на диске Basis — 128 МБ,
а BC7 — 1,4 ГБ. Поэтому предложение — basis. Замер при включении (.work/enable_gfx, тот же город, по кругу):
видеопамять «Высокой» 3,0 → 1,9–2,1 ГБ, «Очень низкой» 1,45 → 1,03 ГБ; время видеокарты — в пределах шума (±1 мс).

Почему так, а не флажком в коде: в собранной игре Godot сам картинки не сжимает (сжатие есть только в редакторе),
поэтому сжатые картинки должны лечь в набор моделей при сборке. Владелец выбрал basis (26.10); файлы .import в git
не хранятся — на компьютере сборки перед build_game.sh: «status» должен показать basis (deploy/RELEASE.md).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot')
DIRS = ['assets/synty/Textures']

# compress/mode: 0 — без потерь (как было), 2 — VRAM Compressed, 4 — Basis Universal
MODES = {
    'off':   {'compress/mode': '0', 'compress/high_quality': 'false', 'mipmaps/generate': 'false', 'compress/normal_map': '0'},
    'bc7':   {'compress/mode': '2', 'compress/high_quality': 'true', 'mipmaps/generate': 'true'},
    's3tc':  {'compress/mode': '2', 'compress/high_quality': 'false', 'mipmaps/generate': 'true'},
    'basis': {'compress/mode': '4', 'compress/high_quality': 'false', 'mipmaps/generate': 'true', 'compress/uastc_level': '2',
              'compress/rdo_quality_loss': '1.0'},
}
# карты рельефа (normal) при сжатии — двухканальный RGTC (BC5): Godot сам восстанавливает третью координату
NORMAL_RE = re.compile(r'normal', re.I)


def files(root):
    for d in DIRS:
        for base, subs, names in os.walk(os.path.join(root, d)):
            subs.sort()
            for n in sorted(names):
                if n.lower().endswith(('.png.import', '.tga.import', '.jpg.import')):
                    yield os.path.join(base, n)


def read(p):
    with open(p, 'rb') as f:
        raw = f.read()
    nl = b'\r\n' if b'\r\n' in raw else b'\n'
    return raw.decode('utf-8'), nl.decode()


def params(text):
    out = {}
    sect = ''
    for line in text.splitlines():
        if line.startswith('['):
            sect = line.strip()
        elif sect == '[params]' and '=' in line:
            k, v = line.split('=', 1)
            out[k] = v
    return out


def apply(p, mode):
    text, nl = read(p)
    want = dict(MODES[mode])
    if mode != 'off':
        want['compress/normal_map'] = '1' if NORMAL_RE.search(os.path.basename(p)) else '0'
    lines = text.split(nl)
    sect = ''
    seen = set()
    for i, line in enumerate(lines):
        if line.startswith('['):
            sect = line.strip()
        elif sect == '[params]' and '=' in line:
            k = line.split('=', 1)[0]
            if k in want:
                lines[i] = k + '=' + want[k]
                seen.add(k)
    missing = [k for k in want if k not in seen]
    if missing:
        raise SystemExit(f'{p}: нет строк {missing} — файл импорта не того вида, ничего не меняю')
    new = nl.join(lines)
    if new != text:
        with open(p, 'wb') as f:
            f.write(new.encode('utf-8'))
        return True
    return False


def kind(pr):
    m = pr.get('compress/mode', '?')
    mip = pr.get('mipmaps/generate', '?') == 'true'
    if m == '0' and not mip:
        return 'off'
    if m == '2':
        return ('bc7' if pr.get('compress/high_quality') == 'true' else 's3tc') + ('' if mip else ' (без мипмапов)')
    if m == '4':
        return 'basis' + ('' if mip else ' (без мипмапов)')
    return f'mode={m} mip={mip}'


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ('status', *MODES):
        print(__doc__)
        sys.exit(2)
    mode = sys.argv[1]
    root = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else ROOT)
    fl = list(files(root))
    if not fl:
        raise SystemExit(f'в {root} нет картинок {DIRS}')
    if mode == 'status':
        from collections import Counter
        c = Counter(kind(params(read(p)[0])) for p in fl)
        print(f'{root}: {len(fl)} картинок — ' + ', '.join(f'{k}: {n}' for k, n in c.most_common()))
        return
    n = sum(apply(p, mode) for p in fl)
    print(f'{root}: {len(fl)} картинок, изменено {n} — теперь «{mode}». Дальше: импорт и сборка (см. начало файла).')


if __name__ == '__main__':
    main()
