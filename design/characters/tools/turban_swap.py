"""robot_fly = designer #112 EXACTLY; only the turban becomes «هلا»'s.
The «هلا» turban (cut from head.png) is fitted by a 3-point affine onto the brim of the designer's
turban; the designer's own turban is recoloured underneath (Lab, identity palette) so any sliver or
the hanging tail it keeps reads as the same cloth, and its bulk that sticks out is removed."""
import numpy as np
from PIL import Image, ImageDraw
import match2 as M
f = lambda n: [l.split()[1] for l in open('fills_index.txt') if int(l.split()[0]) == n][0]
src = Image.open('fills/' + f(112)).convert('RGBA'); W, H = src.size; kd = W / 900.0
ys, xs = np.mgrid[0:H, 0:W]
# designer turban body (900-grid display coords) and tail
body = [(200,180),(250,105),(330,62),(480,38),(625,48),(725,105),(785,185),(800,300),(820,420),(760,470),
        (730,440),(700,380),(660,320),(620,280),(570,250),(500,230),(400,225),(300,235),(240,250),(200,292),(185,250)]
tail = [(760,470),(820,420),(870,455),(900,500),(900,690),(760,690),(730,610),(700,560),(730,500)]
def pmask(poly, w, h, k):
    m = Image.new('L', (w, h), 0); ImageDraw.Draw(m).polygon([(x*k, y*k) for x, y in poly], fill=255); return np.array(m) > 0
Tb = pmask(body, W, H, kd); Tt = pmask(tail, W, H, kd)
ref = M.load('fills/' + f(18))
base = np.array(M.transfer(src, ref, [], [[0.25,0.35,0.52,0.62]], only=(Tb | Tt))).astype(float)

# «هلا» turban only (head.png, 800-grid display ×1.2), no tail, no face
hd = Image.open('out/robot_head.png').convert('RGBA'); hw, hh = hd.size; kh = hw / 800.0
tpoly = [(95,0),(800,0),(800,420),(785,500),(745,505),(700,470),(640,420),(560,360),(470,300),(380,262),
         (280,248),(180,250),(100,262),(95,240)]
Th = pmask(tpoly, hw, hh, kh)
ha = np.array(hd).astype(float); ha[..., 3] *= Th
turban = Image.fromarray(ha.round().astype(np.uint8))
# 3-point correspondence on the brim: left end · above visor centre · right end at the headphone
P = np.array([(100,262),(380,262),(745,505)], float) * kh
Q = np.array([(188,300),(400,232),(705,395)], float) * kd
A = np.hstack([Q, np.ones((3,1))]); coef = np.linalg.solve(A, P)   # dest -> src (PIL wants inverse map)
data = (coef[0,0], coef[1,0], coef[2,0], coef[0,1], coef[1,1], coef[2,1])
warped = np.array(turban.transform((W, H + int(120 * kd)), Image.AFFINE,
    (data[0], data[1], data[2] + data[1] * -int(120 * kd), data[3], data[4], data[5] + data[4] * -int(120 * kd)),
    resample=Image.BICUBIC)).astype(float)
warped_full = warped; warped = warped[int(120 * kd):]
N = warped[..., 3] / 255
# remove the designer turban bulk the new one doesn't cover (keep the tail)
from PIL import ImageFilter
Nd = np.array(Image.fromarray((N > 0.3).astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(9))) > 0
base[..., 3] = np.where(Tb & ~Nd, 0, base[..., 3])
out = base.copy()
for c in range(3): out[..., c] = warped[..., c] * N + base[..., c] * (1 - N)
out[..., 3] = np.maximum(base[..., 3], warped[..., 3])
top = warped_full[:int(120 * kd)]
# the canvas must have room above the designer's frame for the (taller) new turban
pad = int(120 * kd)
out = np.concatenate([top, out], 0)
img = Image.fromarray(out.round().clip(0, 255).astype(np.uint8))
img = img.crop(img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox())   # nothing of the turban cut off
sc = 960 / max(img.size); img = img.resize((round(img.width*sc), round(img.height*sc)), Image.LANCZOS)
img.save('out/robot_fly.png', optimize=True); print(img.size)
