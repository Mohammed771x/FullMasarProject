r"""يجد \frac{..}{..}\sup{..} — الأس يُرسم خارج الكسر كله (يُقرأ (أ/ب)ⁿ)."""
import json,sys,glob
def grp(s,i):
    assert s[i]=='{'; d=0
    for j in range(i,len(s)):
        d+= s[j]=='{'; d-= s[j]=='}'
        if d==0: return j+1
for f in sys.argv[1:]:
    d=json.load(open(f))
    for n,k in enumerate(d):
        a=d[k]['answer']; i=0
        while (i:=a.find('\\frac{',i))!=-1:
            e1=grp(a,i+5); e2=grp(a,e1) if e1<len(a) and a[e1]=='{' else None
            if e2 and a.startswith('\\sup{',e2):
                e3=grp(a,e2+4); print(f.split('explanations/')[1],n,'|',a[max(0,i-25):e3])
            i+=5
