# numlines.py FILE [A B] — يطبع من كل درس الأسطر التي فيها رقم (عدا ترقيم القوائم «١)» و«1.») مع عنوان الدرس
import json,sys,re
f=sys.argv[1]; d=json.load(open(f)); ks=list(d)
a=int(sys.argv[2]) if len(sys.argv)>2 else 0; b=int(sys.argv[3]) if len(sys.argv)>3 else len(ks)
num=re.compile(r'[0-9٠-٩۰-۹]')
lead=re.compile(r'^\s*(?:[-*•]\s*)?(?:\(?[0-9٠-٩۰-۹]{1,2}[\).\-:]|\[[0-9٠-٩]{1,2}\]|#+)\s*')
for i in range(a,b):
    out=[]
    for ln in d[ks[i]]['answer'].split('\n'):
        s=lead.sub('',ln)
        if num.search(s): out.append(ln.strip()[:300])
    if out: print(f'==== [{i}] {ks[i]}'); print('\n'.join(out))
