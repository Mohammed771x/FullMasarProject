"""Per-family colour transfer (Lab mean/std) from the reference «مرحباً» character (#18).
Families: beige cloth · patterned motifs (gold/orange) · navy fabric. Props excluded by boxes."""
import numpy as np, sys, json
from PIL import Image
from matplotlib.colors import rgb_to_hsv

M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
WP = np.array([0.95047, 1.0, 1.08883])
def lin(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def delin(c): return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.clip(c, 0, None) ** (1 / 2.4) - 0.055)
def f(t): return np.where(t > (6/29)**3, np.cbrt(t), t / (3*(6/29)**2) + 4/29)
def finv(t): return np.where(t > 6/29, t**3, 3*(6/29)**2*(t - 4/29))
def to_lab(rgb):
    xyz = lin(rgb) @ M.T / WP; fx, fy, fz = f(xyz[..., 0]), f(xyz[..., 1]), f(xyz[..., 2])
    return np.stack([116*fy - 16, 500*(fx - fy), 200*(fy - fz)], -1)
def to_rgb(lab):
    fy = (lab[..., 0] + 16) / 116; fx = fy + lab[..., 1] / 500; fz = fy - lab[..., 2] / 200
    xyz = np.stack([finv(fx), finv(fy), finv(fz)], -1) * WP
    return np.clip(delin(xyz @ np.linalg.inv(M).T), 0, 1)

def load(p):
    im = Image.open(p).convert('RGBA'); bb = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return im.crop(bb)
def boxmask(shape, boxes):
    m = np.zeros(shape, bool); Hh, Ww = shape
    for x0, y0, x1, y1 in boxes: m[int(y0*Hh):int(y1*Hh), int(x0*Ww):int(x1*Ww)] = True
    return m
def fams(rgb, a, excl):
    h = rgb_to_hsv(rgb); H, S, V = h[..., 0], h[..., 1], h[..., 2]
    vis = (a > 0.6) & ~excl
    warm = vis & ((H < 0.17) | (H > 0.95)) & (V > 0.18)
    beige = warm & (S < 0.30) & (V > 0.55)
    motif = warm & ~beige & (S >= 0.22)
    navy = vis & (H > 0.55) & (H < 0.75) & (S > 0.25) & (V < 0.62)
    return {'beige': beige, 'motif': motif, 'navy': navy}

def transfer(src, ref, sx, rx, only=None, strength=None):
    a = np.array(src).astype(float) / 255; r = np.array(ref).astype(float) / 255
    La, Lr = to_lab(a[..., :3]), to_lab(r[..., :3])
    fa = fams(a[..., :3], a[..., 3], boxmask(a.shape[:2], sx)); fr = fams(r[..., :3], r[..., 3], boxmask(r.shape[:2], rx))
    out = La.copy()
    for k in fa:
        ma = fa[k] if only is None else fa[k] & only
        if ma.sum() < 50: continue
        s, t = La[ma], Lr[fr[k]]
        ms, ss, mt, st = s.mean(0), s.std(0) + 1e-6, t.mean(0), t.std(0)
        new = (s - ms) / ss * st + mt
        # keep the source's own lightness structure (shading) — transfer mostly chroma
        new[:, 0] = s[:, 0] + (mt[0] - ms[0]) * 0.8
        out[ma] = new
    rgb = to_rgb(out)
    return Image.fromarray((np.concatenate([rgb, a[..., 3:]], -1) * 255).round().astype(np.uint8))

if __name__ == '__main__':
    cfg = json.load(open(sys.argv[1])); ref = load(cfg['ref'])
    for job in cfg['jobs']:
        im = load(job['src'])
        only = boxmask((im.height, im.width), job['only']) if 'only' in job else None
        out = transfer(im, ref, job.get('excl', []), cfg.get('ref_excl', []), only)
        s = 960 / max(out.size); out = out.resize((round(out.width*s), round(out.height*s)), Image.LANCZOS)
        out.save(job['dst'], optimize=True); print(job['dst'], out.size)
