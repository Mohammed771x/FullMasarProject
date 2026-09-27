"""qstruct.py — فحص بنيوي لكل أسئلة البنك: correct_index في المدى، ٤ خيارات، خيارات مكرّرة
(نصاً بعد التطبيع أو قيمةً عددية واحدة: 0.5 = ١/٢ = 50%)، سؤال مكرّر داخل الدرس."""
import json, glob, re, os
from fractions import Fraction
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../Backend/data/quizzes')
D = str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹٫', '01234567890123456789.')
AR = re.compile(r'[\u064B-\u065F\u0670ـ]')
def norm(s):
    s = str(s).translate(D)
    return re.sub(r'[\s«»"،؛]+', ' ', s).strip()
def value(s):
    t = str(s).translate(D).replace('−','-').replace(' ', '')
    m = re.fullmatch(r'(-?\d+(?:\.\d+)?)(%?)', t)
    if m: return Fraction(m.group(1)) / (100 if m.group(2) else 1) if m.group(2) else Fraction(m.group(1))
    m = re.fullmatch(r'(-?\d+)/(\d+)', t) or re.fullmatch(r'(-?)\\frac\{(\d+)\}\{(\d+)\}', t)
    if m and len(m.groups()) == 3: return (-1 if m.group(1) else 1) * Fraction(int(m.group(2)), int(m.group(3))) if int(m.group(3)) else None
    if m and int(m.group(2)): return Fraction(int(m.group(1)), int(m.group(2)))
    return None
out = []
for f in sorted(glob.glob(BASE + '/*/*/*.json')):
    rel = os.path.relpath(f, BASE)
    for k, v in json.load(open(f)).items():
        seenq = {}
        for i, x in enumerate(v['questions']):
            o = x.get('options') or []; ci = x.get('correct_index')
            tag = f"{rel} | {k} | #{i} {x.get('id')}"
            if len(o) != 4: out.append(f"NOPTS{len(o)} {tag}")
            if not isinstance(ci, int) or not 0 <= ci < len(o): out.append(f"BADIDX {tag}"); continue
            n = [norm(a) for a in o]
            if len(set(n)) < len(n): out.append(f"DUPTXT {tag} :: {o}")
            vals = [value(a) for a in o]
            vv = [a for a in vals if a is not None]
            if len(set(vv)) < len(vv): out.append(f"DUPVAL {tag} :: {o}")
            qn = norm(x.get('q'))
            if qn in seenq: out.append(f"DUPQ {tag} (=#{seenq[qn]}) :: {x.get('q')[:80]}")
            seenq[qn] = i
print('\n'.join(out)); print(len(out), 'flags')
