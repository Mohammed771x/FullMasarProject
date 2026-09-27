# setanswer.py FILE IDX NEW.md 'why' — يستبدل نصّ الشرح كله (لإعادة كتابةٍ كاملة)، ويحفظ القديم في rewrites/ ويُسجَّل
import json,sys,os,hashlib
f,i,src,why=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4]
raw=open(f,encoding='utf-8').read(); d=json.loads(raw); k=list(d)[i]; old=d[k]['answer']
new=open(src,encoding='utf-8').read().strip()+'\n'
here=os.path.dirname(os.path.abspath(__file__)); os.makedirs(os.path.join(here,'rewrites'),exist_ok=True)
tag=hashlib.sha1((f+k).encode()).hexdigest()[:10]
open(os.path.join(here,'rewrites',tag+'.old.md'),'w',encoding='utf-8').write(old)
open(os.path.join(here,'rewrites',tag+'.new.md'),'w',encoding='utf-8').write(new)
d[k]['answer']=new
if 'chars' in d[k]: d[k]['chars']=len(new)
ind = 2 if raw.startswith('{\n  "') else 1
open(f,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=ind)+('\n' if raw.endswith('\n') else ''))
with open(os.path.join(here,'fixes.jsonl'),'a') as L: L.write(json.dumps({'file':f,'i':i,'lesson':k,'old':f'<rewrite {tag}.old.md {len(old)}ch>','new':f'<rewrite {tag}.new.md {len(new)}ch>','why':why},ensure_ascii=False)+'\n')
print('OK rewrite',k,len(old),'->',len(new))
