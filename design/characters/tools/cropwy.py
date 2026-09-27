import numpy as np
from PIL import Image
from collections import deque
im=Image.open('fills/0cea1c2577dcc9e0f6c2472dba2a4547f38d6ea4').convert('RGBA')
a=np.array(im)
H,W=a.shape[:2]
occ=a[...,3]>8
# keep components that touch the band y in [900,1040]
seen=np.zeros_like(occ)
keep=np.zeros_like(occ)
q=deque()
for x in range(W):
    for y in (1000,1040):
        if occ[y,x] and not seen[y,x]:
            seen[y,x]=1; q.append((y,x))
while q:
    y,x=q.popleft(); keep[y,x]=1
    for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
        ny,nx=y+dy,x+dx
        if 0<=ny<H and 0<=nx<W and occ[ny,nx] and not seen[ny,nx]:
            seen[ny,nx]=1; q.append((ny,nx))
low=np.zeros_like(occ); low[1040:]=True
a[...,3]=np.where(low & ~keep,0,a[...,3])
out=Image.fromarray(a)
bb=out.getbbox(); print(bb)
out=out.crop(bb); out.save('robot_with_you_raw.png')
bg=Image.new('RGBA',out.size,(255,200,200,255)); bg.alpha_composite(out); bg.thumbnail((700,700)); bg.save('wy_check.png')
