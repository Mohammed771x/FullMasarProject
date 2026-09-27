"""robot_ring = the designer's #69 (scholarships / teacher chat hero: a flying head in light rings),
untouched, wearing the «هلا» turban. Antenna removed (the turban sits where it was)."""
import sys, numpy as np
from PIL import Image
import visor as V
EXTRA = float(sys.argv[1]) if len(sys.argv) > 1 else 1.1
DX = float(sys.argv[2]) if len(sys.argv) > 2 else 0
DY = float(sys.argv[3]) if len(sys.argv) > 3 else 0
f = lambda n: [l.split()[1] for l in open('fills_index.txt') if int(l.split()[0]) == n][0]
O = Image.open('fills/' + f(69)).convert('RGBA'); W, H = O.size

def meas(a, crit, step=3):
    d = crit(a)[::step, ::step]; p = V._largest(d)
    fill = np.zeros_like(d)
    for y in np.unique(p[:, 0]):
        xs = p[p[:, 0] == y, 1]; fill[y, xs.min():xs.max() + 1] = True
    ys, xs = np.nonzero(fill); ys *= step; xs *= step
    c = np.cov(np.stack([xs, ys])); w, v = np.linalg.eigh(c); mj = v[:, np.argmax(w)]
    return np.array([xs.mean(), ys.mean()]), (np.degrees(np.arctan2(mj[1], mj[0])) + 90) % 180 - 90, np.sqrt(w.max())

a = np.array(O).astype(float)
dc, dang, dmaj = meas(a, lambda q: (q[..., 0] < 35) & (q[..., 1] < 55) & (q[..., 2] < 125) & (q[..., 3] > 200))
head = Image.open('out/robot_head.png').convert('RGBA')
hc, hang, hmaj = meas(np.array(head).astype(float),
    lambda q: (q[..., :3].max(2) < 50) & ((q[..., :3].max(2) - q[..., :3].min(2)) < 26) & (q[..., 3] > 200)
              & (np.arange(q.shape[0])[:, None] > 380))
t = Image.open('out/turban_only.png').convert('RGBA')
s = dmaj / hmaj; rot = np.radians(hang - dang)
brim_h = np.array([450.0, 300.0])
c, sn = np.cos(-rot), np.sin(-rot); R = np.array([[c, -sn], [sn, c]])
fwd = lambda p: dc + R @ ((np.asarray(p, float) - hc) * s)
bc = fwd(brim_h)
Rm = R * s * EXTRA
off = bc + (fwd(hc) - bc) * EXTRA + np.array([DX, DY]) - Rm @ hc
Ri = np.linalg.inv(Rm); oi = -Ri @ off
layer = t.transform((W, H), Image.AFFINE, (Ri[0,0], Ri[0,1], oi[0], Ri[1,0], Ri[1,1], oi[1]), resample=Image.BICUBIC)

# erase the antenna: blue/white pixels above the shell top, not covered by the turban
base = np.array(O)
ant = np.zeros((H, W), bool)
ant[:450, 1240:1540] = True   # antenna ball + stem (measured on #69)
cover = np.array(layer.getchannel('A')) > 20
base[ant & ~cover, 3] = 0
out = Image.fromarray(base); out.alpha_composite(layer)
bb = out.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
out = out.crop(bb); sc = 960 / max(out.size)
out = out.resize((round(out.width*sc), round(out.height*sc)), Image.LANCZOS)
out.save('out/robot_ring.png', optimize=True)
orig = O.crop(O.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()); orig.thumbnail(out.size)
cmp_ = Image.new('RGBA', (out.width*2 + 20, out.height), (215, 235, 250, 255))
cmp_.alpha_composite(orig, (0, out.height - orig.height)); cmp_.alpha_composite(out, (out.width + 20, 0)); cmp_.thumbnail((1200, 600)); cmp_.save('ring_cmp.png')
print('ok', out.size, 'scale', round(s, 3), 'rot', round(hang - dang, 1), 'dc', dc.round(), 'dmaj', round(dmaj))
