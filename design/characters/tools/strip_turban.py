"""Erase the designer's own turban + the cloth hanging beside the neck (beige / gold / navy families)
above the collar, protecting the head (screen, shell, headphones) by an ellipse around the screen.
usage: strip_turban.py src dst COLLAR_Y "x0,y0,x1,y1;..." (boxes to keep: props, hands)"""
import sys, numpy as np
from PIL import Image, ImageFilter
from matplotlib.colors import rgb_to_hsv
import visor as V
src, dst, CY = sys.argv[1], sys.argv[2], int(sys.argv[3]); PS = 1.0
KEEP = [tuple(int(v) for v in b.split(',')) for b in sys.argv[4].split(';')] if len(sys.argv) > 4 and sys.argv[4] else []
im = Image.open(src).convert('RGBA'); a = np.array(im).astype(float); H, W = a.shape[:2]
top = np.arange(H)[:, None] < H * 0.5
d = (a[..., :3].max(2) < 60) & (a[..., 3] > 200) & top
p = V._largest(d[::2, ::2]) * 2
y0, x0 = p.min(0); y1, x1 = p.max(0); cx, cy = (x0 + x1) / 2, (y0 + y1) / 2; rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
yy, xx = np.mgrid[0:H, 0:W]
head = ((xx - cx) / (rx * 1.55 * PS)) ** 2 + ((yy - cy) / (ry * 1.35 * PS)) ** 2 < 1
h = rgb_to_hsv(a[..., :3] / 255); Hh, S, Vv = h[..., 0], h[..., 1], h[..., 2]
warm = ((Hh < 0.17) | (Hh > 0.95)) & (Vv > 0.15) & (S > 0.09)        # thobe white is S < 0.09
cloth = warm | ((Hh > 0.55) & (Hh < 0.75) & (S > 0.35) & (Vv < 0.42) & (Vv > 0.06))
zone = (((xx - cx) / (rx * 2.3)) ** 2 + ((yy - cy) / (ry * 2.3)) ** 2 < 1) & (yy < CY) & ~head
for bx0, by0, bx1, by1 in KEEP: zone[by0:by1, bx0:bx1] = False
kill = cloth & zone & (a[..., 3] > 0)
# only whole blobs of cloth: grow a little so anti-aliased fringes go too
k = np.array(Image.fromarray((kill * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
k &= zone
a[..., 3] *= ~k
Image.fromarray(a.astype(np.uint8)).save(dst)
print('screen', (x0, y0, x1, y1), 'killed', int(k.sum()))
