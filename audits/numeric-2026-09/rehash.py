"""rehash.py — بعد إصلاح المصدر: كلُّ شرحٍ كان يُسلَّم في baseline_valid.json وسقط الآن
لأن بصمة درسه تغيّرت، تُحدَّث بصمتُه إلى المصدر الجديد (الشرح نفسه مُدقَّق يدوياً).
لا يلمس شرحاً لم يكن سليماً في خط الأساس. شغّله ببيئة Backend/.venv."""
import sys, os, json, glob
HERE = os.path.dirname(os.path.abspath(__file__))
B = os.path.abspath(os.path.join(HERE, '../../Backend')); sys.path.insert(0, B); os.chdir(B)
from core import lesson_cache as LC
from core.content_store import get_lessons_book, find_lesson
from core.serializer import serialize_lesson
base = set(json.load(open(os.path.join(HERE, 'baseline_valid.json')))['valid'])
fixed = 0
for f in sorted(glob.glob('data/explanations/*/*/*.json')):
    g, t, s = f.split('/')[2], f.split('/')[3], f.split('/')[4][:-5]
    raw = open(f).read(); d = json.loads(raw); changed = False
    for k, v in d.items():
        tag = f"{g}/{t}/{s} :: {k}"
        if tag not in base or LC.stored_for(g, t, s, v['unit'], v['lesson']) is not None:
            continue
        if s == 'رياضيات':
            from subjects.math import load_math_lesson
            text = LC.math_source(load_math_lesson(v['unit'], v['lesson']))
        else:
            book = get_lessons_book(g, t, s)
            u, L = find_lesson(book, v['unit'], v['lesson'])
            if L is None: u, L = find_lesson(book, '', v['lesson'])
            text = serialize_lesson(L, (u or {}).get('اسم_الوحدة', '').strip(), subject=s)
        v['hash'] = LC.fingerprint(text); changed = True; fixed += 1; print('rehash', tag)
    if changed:
        open(f, 'w').write(json.dumps(d, ensure_ascii=False, indent=2 if raw.startswith('{\n  "') else 1))
print('rehashed', fixed)
