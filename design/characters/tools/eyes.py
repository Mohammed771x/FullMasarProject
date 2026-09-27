from PIL import Image, ImageDraw
import numpy as np
from collections import deque
def comps(m):
    H,W=m.shape; seen=np.zeros_like(m,bool); out=[]
    for y,x in zip(*np.nonzero(m)):
        if seen[y,x]: continue
        q=deque([(y,x)]); seen[y,x]=1; pts=[]
        while q:
            cy,cx=q.popleft(); pts.append((cy,cx))
            for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
                ny,nx=cy+dy,cx+dx
                if 0<=ny<H and 0<=nx<W and m[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=1; q.append((ny,nx))
        p=np.array(pts); out.append((len(p),p[:,1].min(),p[:,0].min(),p[:,1].max(),p[:,0].max()))
    return sorted(out,reverse=True)
res={}
for k in ['robot_hello','robot_ask','robot_guide','robot_with_you']:
    im=Image.open(f'out/{k}.png'); a=np.array(im).astype(int)
    small=im.resize((im.width//4,im.height//4)); s=np.array(small).astype(int)
    dark=(s[...,:3].max(2)<45)&(s[...,3]>200)
    c=comps(dark)[0]; vx0,vy0,vx1,vy1=[v*4 for v in c[1:]]
    # visor bbox; LEDs inside
    sub=a[vy0:vy1,vx0:vx1]
    led=(sub[...,2]>200)&(sub[...,1]>140)&(sub[...,0]<160)
    cs=[cc for cc in comps(led[::2,::2]) if cc[0]>30][:3]
    boxes=[(vx0+2*b[1],vy0+2*b[2],vx0+2*b[3],vy0+2*b[4]) for b in cs]
    boxes.sort(key=lambda b:b[1])  # top first: eyes then mouth
    print(k,im.size,'visor',(vx0,vy0,vx1,vy1),boxes)
    res[k]=(im.size,(vx0,vy0,vx1,vy1),boxes)
    d=ImageDraw.Draw(im)
    for b in boxes: d.rectangle(b,outline='red',width=3)
    d.rectangle((vx0,vy0,vx1,vy1),outline='lime',width=3)
    bg=Image.new('RGBA',im.size,'white'); bg.alpha_composite(im); bg.thumbnail((400,400)); bg.save(f'out/{k}_dbg.png')
pass
