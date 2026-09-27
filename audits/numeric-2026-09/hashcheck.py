"""hashcheck.py [--save FILE | --compare FILE] — أيّ الشروح المخزونة تطابق بصمتُها المصدرَ الحالي.
يمرّ بالمسار الحقيقي نفسه (lesson_cache.stored_for) فلا يخمّن طريقة البصم."""
import sys, os, json, glob
HERE = os.path.dirname(os.path.abspath(__file__))
B = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../Backend'))
sys.path.insert(0, B); os.chdir(B)
from core import lesson_cache as LC
ok, bad = [], []
for f in sorted(glob.glob('data/explanations/*/*/*.json')):
    g, t, s = f.split('/')[2], f.split('/')[3], f.split('/')[4][:-5]
    for k, v in json.load(open(f)).items():
        served = LC.stored_for(g, t, s, v['unit'], v['lesson'])
        (ok if served is not None else bad).append(f"{g}/{t}/{s} :: {k}")
print('valid', len(ok), 'not-served', len(bad))
if '--save' in sys.argv:
    json.dump({'valid': ok, 'bad': bad}, open(os.path.join(HERE, sys.argv[sys.argv.index('--save')+1]), 'w'), ensure_ascii=False, indent=1)
if '--compare' in sys.argv:
    base = json.load(open(os.path.join(HERE, sys.argv[sys.argv.index('--compare')+1])))
    lost = sorted(set(base['valid']) - set(ok))
    print('LOST since baseline:', len(lost)); [print('  ', x) for x in lost]
