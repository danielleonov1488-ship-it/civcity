# Вторая партия: короткие подписи (до 40 знаков, без %) из всех остальных файлов игры, кроме уже переведённого
import re, os, sys, json, glob
ROOT = sys.argv[1]
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
cyr = re.compile('[А-Яа-яЁё]')
done = set(json.load(open(os.path.join(ROOT, 'godot/i18n/en.json'), encoding='utf-8')).keys())
SKIP = {'city_name.gd', 'names.gd', 'story_defs.gd', 'stories.gd', 'story_orders.gd'}   # фильтр слов; истории — отдельной партией
out = []
seen = set()
for f in sorted(glob.glob(os.path.join(ROOT, 'godot/scripts/*.gd'))):
    b = os.path.basename(f)
    if b.startswith('test_') or b.startswith('qa_') or b in SKIP:
        continue
    for line in open(f, encoding='utf-8'):
        if line.lstrip().startswith('#'):
            continue
        for m in lit.finditer(line):
            t = m.group(1)
            k = t.replace('\\n', '\n')
            if '%' in t or len(t) > 40 or not cyr.search(t) or k in done or t in seen:
                continue
            seen.add(t)
            out.append(t)
open(os.path.join(os.path.dirname(__file__), 'pick2.txt'), 'w', encoding='utf-8').write('\n'.join(out))
L = out
for b in range(0, len(L), 260):
    open(os.path.join(os.path.dirname(__file__), 'b2_%d.txt' % (b // 260 + 1)), 'w', encoding='utf-8').write('\n'.join('%d\t%s' % (i + 1, L[i]) for i in range(b, min(b + 260, len(L)))))
print(len(out), sum(len(t) for t in out))
