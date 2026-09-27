"""Remove small detached alpha islands (leftover fringe of the stripped turban). usage: despeck.py in out [MIN]"""
import sys, numpy as np
from collections import deque
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA'); a = np.array(im); MIN = int(sys.argv[3]) if len(sys.argv) > 3 else 600
m = a[..., 3] > 20; H, W = m.shape; lab = np.zeros((H, W), np.int32); n = 0; sizes = {}
for y, x in zip(*np.nonzero(m)):
    if lab[y, x]: continue
    n += 1; q = deque([(y, x)]); lab[y, x] = n; c = 0
    while q:
        cy, cx = q.popleft(); c += 1
        for ny, nx in ((cy+1, cx), (cy-1, cx), (cy, cx+1), (cy, cx-1)):
            if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not lab[ny, nx]: lab[ny, nx] = n; q.append((ny, nx))
    sizes[n] = c
small = [k for k, v in sizes.items() if v < MIN]
kill = np.isin(lab, small) | ((a[..., 3] <= 20) & (a[..., 3] > 0))
a[kill, 3] = 0
out = Image.fromarray(a); bb = out.getchannel("A").getbbox(); out = out.crop(bb); out.save(sys.argv[2]); print("offset", bb[:2])
print(sys.argv[2], 'islands removed', len(small), 'size', out.size)
