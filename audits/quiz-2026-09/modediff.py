"""modediff.py SUBJECT_DIR — يقارن كتاب الدروس (lessons_mode) بكتاب الوحدة (unit_mode) جملةً جملة،
ويطبع الجمل شبه المتطابقة التي تختلف في كلمة أو رقم (أخطاء نسخ في أحد الكتابين).
مثال: modediff.py "جغرافيا/grade1"  أو  modediff.py "جغرافيا/grade2/أدبي"
"""
import json, re, sys, os, glob, difflib, collections
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../Backend/data/subjects')
DIG = str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')
DIAC = re.compile('[ً-ْـ]')

def strings(x, out):
    if isinstance(x, dict):
        for v in x.values(): strings(v, out)
    elif isinstance(x, list):
        for v in x: strings(v, out)
    elif isinstance(x, str): out.append(x)
    return out

def norm(s):
    s = DIAC.sub('', s.translate(DIG)).replace('\\n', ' ')
    s = re.sub('[أإآ]', 'ا', s)
    s = re.sub(r'\s*([,،٫.:;؛()\[\]|/\-–])\s*', r'\1', s)
    return re.sub(r'\s+', ' ', s).strip()

def sentences(path):
    out = []
    for s in strings(json.load(open(path, encoding='utf-8')), []):
        for p in re.split(r'(?<=[.؟!])\s+|\n', s):
            p = p.strip()
            if len(p) >= 30: out.append(p)
    return out

def noise(x, y):
    """فروق شكلية: عنوان «X:» ملصق، رقم خلية جدول «1957|»، حرف ياء/ألف مقصورة/تاء."""
    for a, b in ((x, y), (y, x)):
        if b and a != b and (a.endswith(b) or a.startswith(b)):
            extra = a.replace(b, '', 1)
            if re.search(r'[:|\[\]]', extra) or re.fullmatch(r'[\W\d]*', extra): return True
        if not b and re.fullmatch(r'[\W\d]*|.*[:|].*', a): return True
    f = lambda t: re.sub('[ىي]', 'ي', re.sub('[ةه]', 'ه', re.sub(r'[^\w]', '', t)))
    return f(x) == f(y)

def grams(s, n=5):
    w = s.split()
    return {' '.join(w[i:i + n]) for i in range(max(1, len(w) - n + 1))}

def main(sub):
    L = glob.glob(os.path.join(BASE, sub, 'lessons_mode', '*.json'))
    U = glob.glob(os.path.join(BASE, sub, 'unit_mode', '*.json'))
    if not L or not U: sys.exit('missing mode files')
    ls, us = sentences(L[0]), sentences(U[0])
    un = [norm(u) for u in us]
    uset = set(un)
    idx = collections.defaultdict(set)
    for i, u in enumerate(un):
        for g in grams(u): idx[g].add(i)
    seen = set()
    for l in ls:
        nl = norm(l)
        if nl in uset or nl in seen: continue
        seen.add(nl)
        cand = collections.Counter()
        for g in grams(nl):
            for i in idx.get(g, ()): cand[i] += 1
        best, br = None, 0
        for i, _ in cand.most_common(5):
            r = difflib.SequenceMatcher(None, nl, un[i], autojunk=False).ratio()
            if r > br: best, br = i, r
        if best is None or br < 0.85: continue
        a, b = nl.split(), un[best].split()
        sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
        diffs = [(' '.join(a[i1:i2]), ' '.join(b[j1:j2])) for t, i1, i2, j1, j2 in sm.get_opcodes() if t != 'equal']
        diffs = [(x, y) for x, y in diffs if re.sub(r'[^\w]', '', x) != re.sub(r'[^\w]', '', y) and not noise(x, y)]
        if not diffs: continue
        num = any(re.search(r'\d', x + y) for x, y in diffs)
        print(('#' if num else '-'), f'{br:.2f}', ' ; '.join(f'«{x}» ⇐ unit «{y}»' for x, y in diffs[:4]), '||', nl[:140])

if __name__ == '__main__':
    main(sys.argv[1])
