# src.py PATH 'regex' [CTX=60]  — بحث في نصّ المصدر الخام (grep يختنق بالعربية). PATH نسبي من Backend/data/subjects أو مطلق
import sys,re,os,glob
p=sys.argv[1]; rx=re.compile(sys.argv[2]); c=int(sys.argv[3]) if len(sys.argv)>3 else 60
base=os.path.join(os.path.dirname(os.path.abspath(__file__)),'../../Backend/data/subjects')
root=p if os.path.isabs(p) else os.path.join(base,p)
files=[root] if os.path.isfile(root) else glob.glob(root+'/**/*.json',recursive=True)
for f in files:
    s=open(f,encoding='utf-8').read()
    for m in rx.finditer(s): print(os.path.relpath(f,base),'|',s[max(0,m.start()-c):m.end()+c].replace('\n',' '))
