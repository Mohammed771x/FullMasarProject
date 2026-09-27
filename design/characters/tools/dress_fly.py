"""robot_fly = the designer's #112 untouched (face, shell, swirl, rings, crystals, framing) wearing the
«هلا» turban. Owner 2026-09-27: «نفس الروبوت بالضبط، اللهم أضف له العمامة».
Base: #112 with its own turban colour-matched to «هلا» (so any sliver the new turban leaves uncovered
already wears our colours); on top: the «هلا» turban, rotated/scaled by the face screens, enlarged
EXTRA× about its brim so it covers the designer's fuller turban."""
import sys, numpy as np
from PIL import Image, ImageDraw
import visor as V, match2 as M
EXTRA = float(sys.argv[1]) if len(sys.argv) > 1 else 1.15
DX = float(sys.argv[2]) if len(sys.argv) > 2 else 0
DY = float(sys.argv[3]) if len(sys.argv) > 3 else 0
f = lambda n: [l.split()[1] for l in open('fills_index.txt') if int(l.split()[0]) == n][0]
O = Image.open('fills/' + f(112)).convert('RGBA'); W, H = O.size; k = W / 900.0

def meas(a, crit, step=3):
    d = crit(a)[::step, ::step]; p = V._largest(d)
    fill = np.zeros_like(d)
    for y in np.unique(p[:, 0]):
        xs = p[p[:, 0] == y, 1]; fill[y, xs.min():xs.max() + 1] = True
    ys, xs = np.nonzero(fill); ys *= step; xs *= step
    c = np.cov(np.stack([xs, ys])); w, v = np.linalg.eigh(c); mj = v[:, np.argmax(w)]
    return np.array([xs.mean(), ys.mean()]), (np.degrees(np.arctan2(mj[1], mj[0])) + 90) % 180 - 90, np.sqrt(w.max())

a = np.array(O).astype(float)
reg = np.zeros((H, W), bool); reg[int(220*k):int(580*k), int(170*k):int(640*k)] = True
dc, dang, dmaj = meas(a, lambda q: (q[..., 0] < 35) & (q[..., 1] < 55) & (q[..., 2] < 125) & (q[..., 3] > 200) & reg)

# 1) base: designer image, turban (incl. its tail + tassels) colour-matched to «هلا»
tur = Image.new('L', (W, H), 0)
ImageDraw.Draw(tur).polygon([(x*k, y*k) for x, y in [(200,180),(250,105),(330,62),(480,38),(625,48),(725,105),
    (785,185),(800,300),(830,410),(870,455),(900,500),(900,690),(760,690),(730,610),(700,560),(690,420),
    (640,330),(560,265),(400,228),(290,238),(205,262)]], fill=255)
base = M.transfer(O, M.load('fills/' + f(18)), [], [[0.25,0.35,0.52,0.62]], only=np.array(tur) > 0)

# 2) the «هلا» turban, placed by the face screens
head = Image.open('out/robot_head.png').convert('RGBA')
hc, hang, hmaj = meas(np.array(head).astype(float),
    lambda q: (q[..., :3].max(2) < 50) & ((q[..., :3].max(2) - q[..., :3].min(2)) < 26) & (q[..., 3] > 200)
              & (np.arange(q.shape[0])[:, None] > 380))
t = Image.open('out/turban_only.png').convert('RGBA')
s = dmaj / hmaj
rot = np.radians(hang - dang)      # PIL rotates counter-clockwise by +deg
# affine: head px -> designer px :  p' = dc + R(-rot)·s·(p - hc), then EXTRA about the turban brim centre
brim_h = np.array([450.0, 300.0])                      # brim centre in head px (front of the turban)
def fwd(p):
    v = (np.asarray(p, float) - hc) * s
    c, sn = np.cos(-rot), np.sin(-rot)
    return dc + np.array([c*v[0] - sn*v[1], sn*v[0] + c*v[1]])
bc = fwd(brim_h)
def full(p):
    return bc + (fwd(p) - bc) * EXTRA + np.array([DX*k, DY*k])
# inverse map for Image.transform (output px -> input px)
A = np.zeros((2, 2)); c, sn = np.cos(-rot), np.sin(-rot)
Rm = np.array([[c, -sn], [sn, c]]) * s * EXTRA
off = full(hc) - Rm @ hc
Ri = np.linalg.inv(Rm); oi = -Ri @ off
layer = t.transform((W, H), Image.AFFINE, (Ri[0,0], Ri[0,1], oi[0], Ri[1,0], Ri[1,1], oi[1]), resample=Image.BICUBIC)
out = base.copy(); out.alpha_composite(layer)
b1 = O.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
b2 = out.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
bb = (min(b1[0], b2[0]), min(b1[1], b2[1]), max(b1[2], b2[2]), max(b1[3], b2[3]))   # the designer's frame, grown only if the turban needs it
out = out.crop(bb); sc = 960 / max(out.size)
out = out.resize((round(out.width*sc), round(out.height*sc)), Image.LANCZOS)
out.save('out/robot_fly.png', optimize=True)
orig = O.crop(bb).resize(out.size, Image.LANCZOS)
cmp_ = Image.new('RGBA', (out.width*2 + 20, out.height), (215, 235, 250, 255))
cmp_.alpha_composite(orig); cmp_.alpha_composite(out, (out.width + 20, 0)); cmp_.thumbnail((1100, 600)); cmp_.save('dress_cmp.png')
print('ok', out.size, 'scale', round(s, 3), 'rot', round(hang - dang, 1))
