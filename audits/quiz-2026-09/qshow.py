"""qshow.py FILE [KEY_SUBSTR] [--all] — يطبع أسئلة الدروس (الافتراضي: ما فيه أرقام فقط).
FILE نسبي من data/quizzes مثل 3/علمي/فيزياء. يطبع: رقم الدرس، #i id [مستوى] السؤال، الخيارات (✓ للصحيح)، why."""
import sys, re, qio
f = sys.argv[1] + ('' if sys.argv[1].endswith('.json') else '.json')
sub = next((a for a in sys.argv[2:] if not a.startswith('--')), '')
allq = '--all' in sys.argv
non = '--non' in sys.argv
d, _, _ = qio.load(f)
N = re.compile(r'[0-9٠-٩۰-۹]')
META = re.compile(r'استُ?بدل|استبدال|المؤشر|السؤال الأصلي|تم تعديل|تم تصحيح|صُحّح|في الأصل|الصياغة الأصلية|أُعيدت صياغ|الخيار الصحيح كان|كان الجواب|بدلاً من السؤال|غير واردة في الدرس|السؤال السابق|الخيار \(?[0-3٠-٣]\)?|الخيارات السابقة|إزالة الخيار')
for li, (k, v) in enumerate(d.items()):
    if sub and sub not in k and sub != str(li): continue
    qs = [(i, x) for i, x in enumerate(v['questions']) if (non and not N.search(x['q'] + ' '.join(map(str, x['options']))) and not META.search(x.get('why',''))) or (not non) and (allq or N.search(x['q'] + ' '.join(map(str, x['options']))) or META.search(x.get('why','')))]
    if not qs: continue
    print(f'\n===== L{li} {k}  ({len(qs)}/{len(v["questions"])})')
    for i, x in qs:
        print(f"#{i} {x['id']} [{x.get('level','')}]{' ⚑' if META.search(x.get('why','')) else ''} {x['q']}")
        print('   ' + ' | '.join(('✓' if j == x['correct_index'] else '') + str(o) for j, o in enumerate(x['options'])))
        w = str(x.get('why', ''))
        if '--short' in sys.argv and not N.search(x['q'] + ' '.join(map(str, x['options']))): w = w[:90]
        print('   ↳ ' + w)
