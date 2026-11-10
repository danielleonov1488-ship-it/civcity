# Третья партия: описания построек (desc в defs.gd), ещё не переведённые
import re, json, sys, os
ROOT = sys.argv[1]
s = open(os.path.join(ROOT, 'godot/scripts/defs.gd'), encoding='utf-8').read()
done = json.load(open(os.path.join(ROOT, 'godot/i18n/en.json'), encoding='utf-8'))
descs = []
for t in re.findall(r'"desc": "((?:[^"\\]|\\.)*)"', s):
    if t not in done and t not in descs and '%' not in t:
        descs.append(t)
D = os.path.dirname(__file__)
open(os.path.join(D, 'pick3.txt'), 'w', encoding='utf-8').write('\n'.join(descs))
for b in range(0, len(descs), 130):
    open(os.path.join(D, 'b3_%d.txt' % (b // 130 + 1)), 'w', encoding='utf-8').write('\n'.join('%d\t%s' % (i + 1, descs[i]) for i in range(b, min(b + 130, len(descs)))))
print(len(descs), sum(len(t) for t in descs))
