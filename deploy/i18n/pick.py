# Первая партия перевода: всё из account_ui.gd, gfx.gd, social/friends/union, короткие подписи hud.gd (без %),
# названия построек, рангов и исследований из defs.gd. Пишет pick.txt — по строке на фразу.
import re, os, sys, json
ROOT = sys.argv[1]
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
cyr = re.compile('[А-Яа-яЁё]')
out = []
seen = set()


def add(t):
    if t not in seen and cyr.search(t):
        seen.add(t)
        out.append(t)


def strings(path, short=None, nopct=False):
    for line in open(os.path.join(ROOT, path), encoding='utf-8'):
        if line.lstrip().startswith('#'):
            continue
        for m in lit.finditer(line):
            t = m.group(1)
            if nopct and '%' in t:
                continue
            if short and len(t) > short:
                continue
            add(t)


for f in ['account_ui.gd', 'gfx.gd', 'city_name.gd']:
    strings('godot/scripts/' + f)
strings('godot/scripts/hud.gd', short=40, nopct=True)
d = open(os.path.join(ROOT, 'godot/scripts/defs.gd'), encoding='utf-8').read()
for t in re.findall(r'"name": "([^"]+)"', d):
    add(t)
for t in re.findall(r'"(?:short|title|text)": "([^"%]{1,60})"', d):
    add(t)
open(os.path.join(os.path.dirname(__file__), 'pick.txt'), 'w', encoding='utf-8').write('\n'.join(out))
print(len(out), sum(len(t) for t in out))
