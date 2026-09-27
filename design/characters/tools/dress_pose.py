"""Put the «هلا» turban (out/turban_only.png) on a full-body pose, placed by the face screens
(rotation + scale), enlarged EXTRA× about its brim so it covers the designer's turban.
usage: dress_pose.py <src.png> <dst.png> EXTRA DX DY"""
import sys, numpy as np
from PIL import Image
import visor as V
src, dst = sys.argv[1], sys.argv[2]
EXTRA, DX, DY, ROT = (float(v) for v in sys.argv[3:7])   # ROT: degrees; the screen is too round for PCA tilt
O = Image.open(src).convert('RGBA'); W, H = O.size

def meas(a, crit, step=2):
    d = crit(a)[::step, ::step]; p = V._largest(d)
    fill = np.zeros_like(d)
    for y in np.unique(p[:, 0]):
        xs = p[p[:, 0] == y, 1]; fill[y, xs.min():xs.max() + 1] = True
    ys, xs = np.nonzero(fill); ys *= step; xs *= step
    c = np.cov(np.stack([xs, ys])); w, v = np.linalg.eigh(c); mj = v[:, np.argmax(w)]
    return np.array([xs.mean(), ys.mean()]), (np.degrees(np.arctan2(mj[1], mj[0])) + 90) % 180 - 90, np.sqrt(w.max())

top = lambda q: np.arange(q.shape[0])[:, None] < q.shape[0] * 0.5
dark = lambda q: (q[..., :3].max(2) < 60) & (q[..., 3] > 200)
dc, dang, dmaj = meas(np.array(O).astype(float), lambda q: dark(q) & top(q))
head = Image.open('out/robot_head.png').convert('RGBA')
hc, hang, hmaj = meas(np.array(head).astype(float),
    lambda q: (q[..., :3].max(2) < 50) & ((q[..., :3].max(2) - q[..., :3].min(2)) < 26) & (q[..., 3] > 200)
              & (np.arange(q.shape[0])[:, None] > 380))
t = Image.open('out/turban_only.png').convert('RGBA')
s = dmaj / hmaj; rot = np.radians(ROT)
c, sn = np.cos(-rot), np.sin(-rot); R = np.array([[c, -sn], [sn, c]])
fwd = lambda p: dc + R @ ((np.asarray(p, float) - hc) * s)
bc = fwd([450.0, 300.0])
Rm = R * s * EXTRA
off = bc + (fwd(hc) - bc) * EXTRA + np.array([DX, DY]) - Rm @ hc
Ri = np.linalg.inv(Rm); oi = -Ri @ off
layer = t.transform((W, H), Image.AFFINE, (Ri[0,0], Ri[0,1], oi[0], Ri[1,0], Ri[1,1], oi[1]), resample=Image.BICUBIC)
out = O.copy(); out.alpha_composite(layer); out.save(dst)
print('scale', round(s, 3), 'rot', round(hang - dang, 1), 'dc', dc.round(), 'dmaj', round(dmaj))
