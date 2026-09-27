# fix.py FILE INDEX 'old' 'new' 'reason'  — استبدالٌ واحدٌ بالضبط، ويُسجَّل  (FIXALL=1 يسمح بعدّة مواضع)
import json,sys,io
f,i,old,new,why=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4],sys.argv[5]
raw=open(f,encoding='utf-8').read(); d=json.loads(raw)
k=list(d)[i]; t=d[k]['answer']; n=t.count(old)
assert n==1 or (n>1 and __import__("os").environ.get("FIXALL")=="1"), f"occurrences={n}"  # FIXALL=1 ⇒ كل المواضع
d[k]['answer']=t.replace(old,new)
if 'chars' in d[k]: d[k]['chars']=len(d[k]['answer'])
ind = 2 if raw.startswith('{\n  "') else 1
open(f,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=ind)+('\n' if raw.endswith('\n') else ''))
open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'fixes.jsonl'),'a').write(json.dumps({'file':f,'i':i,'lesson':k,'old':old,'new':new,'why':why},ensure_ascii=False)+'\n')
print('OK',k)
