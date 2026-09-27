"""قراءة/كتابة ملف بنك مع الحفاظ على تنسيقه (indent 1 أو 2)."""
import json, os
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../Backend/data/quizzes')
def path(rel): return rel if os.path.isabs(rel) else os.path.join(BASE, rel)
def load(rel):
    r = open(path(rel), encoding='utf-8').read(); d = json.loads(r)
    ind = next(i for i in (2, 1, None) if json.dumps(d, ensure_ascii=False, indent=i).rstrip('\n') == r.rstrip('\n'))
    return d, ind, r.endswith('\n')
def save(rel, d, ind, nl):
    open(path(rel), 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=ind) + ('\n' if nl else ''))
