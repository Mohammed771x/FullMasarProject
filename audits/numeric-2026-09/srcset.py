"""srcset.py FILE PATCH.json — يستبدل عناصر كاملة في ملف مصدر مُهيكل (دروس الرياضيات).
PATCH: [{"path": ["أمثلة_محلولة", 3], "value": {...}, "why": "..."}]. يحافظ على المسافة البادئة
الأصلية (1/2/4) ويسجّل القديم والجديد في source_fixes.jsonl. ⚠️ بعده verify.sh."""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
f, pf = sys.argv[1:3]
p = f if os.path.isabs(f) else os.path.join(HERE, '../../Backend/data/subjects', f)
raw = open(p, encoding='utf-8').read(); d = json.loads(raw)
ind = next(i for i in (2, 1, 4) if json.dumps(d, ensure_ascii=False, indent=i).strip() == raw.strip())
log = open(os.path.join(HERE, 'source_fixes.jsonl'), 'a')
for it in json.load(open(pf, encoding='utf-8')):
    o = d
    for k in it['path'][:-1]: o = o[k]
    old = o[it['path'][-1]]; o[it['path'][-1]] = it['value']
    log.write(json.dumps({'file': f, 'path': it['path'], 'old': old, 'new': it['value'], 'why': it['why']}, ensure_ascii=False) + '\n')
out = json.dumps(d, ensure_ascii=False, indent=ind) + ('\n' if raw.endswith('\n') else '')
open(p, 'w', encoding='utf-8').write(out); print('OK', f)
