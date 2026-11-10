import re, glob, os, json, sys
ROOT = sys.argv[1]
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
cyr = re.compile('[А-Яа-яЁё]')
uniq = {}
per_file = {}
for f in glob.glob(os.path.join(ROOT, 'godot/scripts/*.gd')):
    b = os.path.basename(f)
    if b.startswith('test_') or b.startswith('qa_'):
        continue
    n = 0
    for line in open(f, encoding='utf-8'):
        st = line.lstrip()
        if st.startswith('#'):
            continue
        for m in lit.finditer(line):
            t = m.group(1)
            if cyr.search(t):
                uniq.setdefault(t, set()).add(b)
                n += 1
    if n:
        per_file[b] = n
chars = sum(len(t) for t in uniq)
print('unique', len(uniq), 'chars', chars, 'with %', sum(1 for t in uniq if '%' in t), 'files', len(per_file))
for b, n in sorted(per_file.items(), key=lambda x: -x[1])[:25]:
    print(f'{n:6d} {b}')
json.dump({t: sorted(v) for t, v in uniq.items()}, open(os.path.join(os.path.dirname(__file__), 'strings.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
