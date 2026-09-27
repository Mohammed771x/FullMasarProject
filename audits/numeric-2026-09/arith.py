"""arith.py [PATH] — يلتقط في نصوص المصدر كل تعبير حسابي بسيط «أ op ب ... = ج» (أرقام فقط)
ويعيد حسابه؛ يطبع ما يختلف بأكثر من 1.5% (بعد التقريب). مرشِّح لا حَكَم — كل سطر يُراجع يدوياً."""
import sys, os, re, glob, json
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../Backend/data/subjects')
root = os.path.join(base, sys.argv[1]) if len(sys.argv) > 1 else base
D = str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹٫', '01234567890123456789.')
NUM = r'\d+(?:[.,]\d+)?'
EXPR = re.compile(rf'(?<![\w.,/^(\-])({NUM}(?:\s*[+\-×x*÷]\s*{NUM})+)\s*=\s*(-?{NUM})(?![\d/^.,]|\s*[+\-×x*÷^/(])')
def val(s):
    s = s.replace(',', '.') if re.fullmatch(r'\d+,\d{1,2}', s) or re.fullmatch(r'\d+,\d{4,}', s) else s.replace(',', '')
    return float(s)
files = [root] if os.path.isfile(root) else sorted(glob.glob(root + '/**/*.json', recursive=True))
n = 0
for f in files:
    if '/exams/' in f or '_ingest' in f: continue
    t = open(f, encoding='utf-8').read().translate(D).replace('\\n', '\n')
    for m in EXPR.finditer(t):
        lhs, rhs = m.group(1), m.group(2)
        e = lhs.replace('×', '*').replace('x', '*').replace('÷', '/')
        e = re.sub(NUM, lambda k: repr(val(k.group(0))), e)
        try: got = eval(e); want = val(rhs.lstrip('-')) * (-1 if rhs.startswith('-') else 1)
        except Exception: continue
        if abs(got - want) <= max(0.015 * abs(want), 0.051): continue
        ctx = t[max(0, m.start() - 50):m.end() + 20].replace('\n', ' ⏎ ')
        print(os.path.relpath(f, base).split('/')[0], os.path.basename(os.path.dirname(f)), '|', f'{lhs} = {rhs}', f'→ {got:.6g}', '|', ctx); n += 1
print('flagged', n, file=sys.stderr)
