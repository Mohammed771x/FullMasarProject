# عرضٌ فقط: يطبع الدروس التي فيها حساب رقمي من الفهرس a حتى ميزانية الحروف
import json,sys,re
f=sys.argv[1]; a=int(sys.argv[2]); budget=int(sys.argv[3]) if len(sys.argv)>3 else 26000
d=list(json.load(open(f)).items()); used=0; skipped=[]
num=re.compile(r'^(?![ \t]*(?:#+ ?)?[٠-٩0-9]+[-.)] )[^\n]*[٠-٩0-9]',re.M)
i=a
while i<len(d):
    k,v=d[i]; t=v['answer']
    if not num.search(t): skipped.append(i); i+=1; continue
    if used and used+len(t)>budget: break
    print(f"\n=========== [{i}] {k}\n"); print(t); used+=len(t); i+=1
print(f"\n### skipped(no calc): {skipped}  NEXT={i} / {len(d)}")
