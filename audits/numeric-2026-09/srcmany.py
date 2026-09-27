"""srcmany.py FILE PATCH.json — عدّة إصلاحات مصدر في ملف واحد. PATCH قائمة {old,new,why,n?}
n = عدد المواضع المتوقَّع (افتراضياً 1). يتحقق من كل شيء قبل الكتابة، ويسجّل في source_fixes.jsonl.
⚠️ بعده rehash.py ثم hashcheck.py."""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
f, pf = sys.argv[1:3]
p = f if os.path.isabs(f) else os.path.join(HERE, '../../Backend/data/subjects', f)
raw = open(p, encoding='utf-8').read(); out = raw
if os.environ.get('DRY'):
    for it in json.load(open(pf, encoding='utf-8')): print(raw.count(it['old']), it.get('n', 1), it['old'][:70])
    sys.exit()
for it in json.load(open(pf, encoding='utf-8')):
    n = out.count(it['old']); assert n == it.get('n', 1), (it['old'], n)
    out = out.replace(it['old'], it['new'])
json.loads(out)
open(p, 'w', encoding='utf-8').write(out)
with open(os.path.join(HERE, 'source_fixes.jsonl'), 'a') as L:
    for it in json.load(open(pf, encoding='utf-8')):
        L.write(json.dumps({'file': f, **it}, ensure_ascii=False) + '\n')
print('OK', f)
