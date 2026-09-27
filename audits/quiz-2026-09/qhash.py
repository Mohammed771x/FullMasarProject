"""qhash.py [--fix] — لكل بنك «اختبر نفسك»: هل بصمته تطابق نصّ الدرس الحالي كما يحسبه الخادم
(core/quiz.collect_banks)؟ بنكٌ لا يطابق = لاغٍ صامتاً (يُولَّد الاختبار حيّاً بلا تدقيق).
qhash.py [--fix] [G/T/S ...] — --fix يحدّث البصمة (بعد أن تُراجَع أسئلة الدرس مقابل النص المصحَّح). شغّله ببيئة Backend/.venv."""
import sys, os, json, glob
HERE = os.path.dirname(os.path.abspath(__file__))
B = os.path.abspath(os.path.join(HERE, '../../Backend')); sys.path.insert(0, B); os.chdir(B)
from core import quiz_bank as QB
from core.content_store import get_lessons_book, find_lesson, _clean
from core.serializer import serialize_lesson
fix = '--fix' in sys.argv
only = [a for a in sys.argv[1:] if not a.startswith('--')]  # مثل 3/علمي/فيزياء — يحصر الفحص/الإصلاح
ok = bad = 0
for f in sorted(glob.glob('data/quizzes/*/*/*.json')):
    g, t, s = f.split('/')[2], f.split('/')[3], f.split('/')[4][:-5]
    if only and f"{g}/{t}/{s}" not in only: continue
    sys.path.insert(0, HERE); import qio
    d, ind, nl = qio.load(os.path.abspath(f)); changed = False
    book = get_lessons_book(g, t, s)
    for k, v in d.items():
        u, doc = find_lesson(book, v['unit'], v['lesson'])
        if doc is None: u, doc = find_lesson(book, '', v['lesson'])
        if doc is None: print('NODOC', f, k); bad += 1; continue
        src = serialize_lesson(doc, _clean((u or {}).get('اسم_الوحدة')), subject=s)
        if v.get('hash') == QB.fingerprint(src): ok += 1; continue
        bad += 1; print('STALE', f"{g}/{t}/{s} :: {k}")
        if fix: v['hash'] = QB.fingerprint(src); changed = True
    if changed:
        qio.save(os.path.abspath(f), d, ind, nl)
print('ok', ok, 'stale', bad)
