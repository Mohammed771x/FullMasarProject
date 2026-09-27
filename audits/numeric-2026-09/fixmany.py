# fixmany.py FILE IDX PATCH.json — عدّة استبدالات لدرسٍ واحد من ملف JSON: [{"old":..,"new":..,"why":..,"all":false}]
# كل old يجب أن يظهر مرة واحدة بالضبط (أو all=true)، وإلا يتوقف قبل الكتابة. يُسجَّل كلٌّ في fixes.jsonl.
import json,sys,os
f,i,pp=sys.argv[1],int(sys.argv[2]),sys.argv[3]
raw=open(f,encoding='utf-8').read(); d=json.loads(raw); k=list(d)[i]; t=d[k]['answer']
patches=json.load(open(pp,encoding='utf-8'))
for p in patches:
    n=t.count(p['old'])
    assert n==1 or (n>1 and p.get('all')), f"occurrences={n} :: {p['old'][:60]}"
    t=t.replace(p['old'],p['new'])
d[k]['answer']=t
if 'chars' in d[k]: d[k]['chars']=len(t)
ind = 2 if raw.startswith('{\n  "') else 1
open(f,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=ind)+('\n' if raw.endswith('\n') else ''))
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'fixes.jsonl'),'a') as L:
    for p in patches: L.write(json.dumps({'file':f,'i':i,'lesson':k,'old':p['old'],'new':p['new'],'why':p['why']},ensure_ascii=False)+'\n')
print('OK',k,len(patches))
