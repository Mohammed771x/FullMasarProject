# numcheck.py EXPL.json SUBJECT_DIR [MINLEN=2] — أرقام في الشرح لا توجد في نصّ الكتاب (الوضعين) ⇒ مشتبه بها
import json,sys,re,glob,os
tr=str.maketrans('٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789')
def nums(s):
    s=s.translate(tr).replace('٫','.').replace('،',',')
    out=set()
    for m in re.finditer(r'\d[\d,.]*\d|\d',s):
        t=m.group().strip('.,')
        v=t.replace(',','')           # 22,198,000 ⇒ 22198000
        out.add(v)
        if re.fullmatch(r'\d+,\d{1,2}',t): out.add(t.replace(',','.'))   # فاصلة عشرية عربية ٢,٥
        if re.fullmatch(r'\d+/\d+',t): out.add(t.replace('/','.'))
    return out
f,src=sys.argv[1],sys.argv[2]; minlen=int(sys.argv[3]) if len(sys.argv)>3 else 2
base=os.path.join(os.path.dirname(os.path.abspath(__file__)),'../../Backend/data/subjects')
S=set()
for p in glob.glob(os.path.join(base,src,'**/*.json'),recursive=True):
    raw=open(p,encoding='utf-8').read()
    S|=nums(raw); S|=nums(raw.replace('/','.'))
d=json.load(open(f))
for i,k in enumerate(d):
    a=d[k]['answer']; bad=[]
    for ln in a.split('\n'):
        for n in sorted(nums(ln)):
            core=n.replace('.','')
            if len(core)<minlen or n in S: continue
            bad.append((n,ln.strip()[:160]))
    if bad:
        print(f'==== [{i}] {k}')
        seen=set()
        for n,ln in bad:
            if (n,ln) in seen: continue
            seen.add((n,ln)); print(f'  {n} :: {ln}')
