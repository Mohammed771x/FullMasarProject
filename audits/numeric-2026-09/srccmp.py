"""srccmp.py SUBJECT_GLOB — لكل مادة لها الوضعان: الأرقام (≥3 خانات أو عشرية) الموجودة في lessons_mode
ولا أثر لها في unit_mode (والعكس بـ --rev). unit_mode صفحات الكتاب، فرقمٌ في الدروس غائبٌ عن الكتاب
مرشّحٌ لخطأ نسخ. يطبع السياق. مرشِّح لا حَكَم."""
import sys, os, re, glob, json
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../Backend/data/subjects')
D = str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹٫', '01234567890123456789.')
def nums(t):
    out = {}
    for m in re.finditer(r'(?<![\d.,])\d+(?:[.,]\d+)*(?![\d])', t):
        s = m.group(0); k = s.replace(',', '.') if re.fullmatch(r'\d+,\d{1,2}', s) else s.replace(',', '')
        k = k.rstrip('0').rstrip('.') if '.' in k else k
        if len(k.replace('.', '')) >= 3 or '.' in k: out.setdefault(k, m.start())
    return out
rev = '--rev' in sys.argv
for L in sorted(glob.glob(os.path.join(base, sys.argv[1], '**/lessons_mode/*.json'), recursive=True)):
    U = glob.glob(os.path.join(os.path.dirname(os.path.dirname(L)), 'unit_mode', '*.json'))
    if not U: continue
    lo = open(L).read().replace('\\n', '\n'); uo = open(U[0]).read().replace('\\n', '\n'); lt = lo.translate(D); ut = uo.translate(D)
    a, b = (nums(ut), nums(lt)) if rev else (nums(lt), nums(ut))
    src = uo if rev else lo
    miss = [(k, p) for k, p in a.items() if k not in b]
    print('#####', os.path.relpath(L, base), 'missing', len(miss))
    for k, p in sorted(miss, key=lambda x: x[1]):
        print(f'  {k:>12} | ' + src[max(0, p - 70):p + 40].replace('\n', ' ⏎ '))
