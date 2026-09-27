import json,sys
f=sys.argv[1]; a=int(sys.argv[2]); b=int(sys.argv[3])
d=json.load(open(f))
for i,(k,v) in enumerate(d.items()):
    if a<=i<b:
        print(f"\n=========== [{i}] {k}\n")
        print(v['answer'])
