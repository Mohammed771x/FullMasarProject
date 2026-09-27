"""Waiting pose: remove the hourglass + its motion lines (owner: calmer), and empty the drawn
progress fill so the app can animate it (MasarCharacter.waiting.progress)."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
src = 'out/robot_waiting_before_calm.png'
im = Image.open(src).convert('RGBA'); a = np.array(im).astype(float)
H, W = a.shape[:2]
ys, xs = np.mgrid[0:H, 0:W]

# ── 1) hourglass + motion lines → transparent, never touching the download disc or the headphone
erase = Image.new('L', (W, H), 0); d = ImageDraw.Draw(erase)
for box in [(705, 190, 915, 452),   # hourglass
            (592, 298, 662, 362),   # spark left (beside the headphone)
            (650, 250, 700, 332),   # spark top
            (866, 322, 956, 445)]:  # sparks right
    d.rectangle(box, fill=255)
disc = (xs - 655) ** 2 + (ys - 472) ** 2 <= 112 ** 2
m = np.array(erase.filter(ImageFilter.GaussianBlur(1.5))).astype(float) / 255
m[disc] = 0
m[(xs < 600) & (ys < 312)] = 0          # headphone
a[..., 3] *= (1 - m)

# ── 1b) the hourglass base sat ON the disc's rim: rebuild the disc's upper-right quarter as the
#        mirror of its upper-left (the disc and its download glyph are symmetric about x = 655)
orig = np.array(im).astype(float)
rad = np.hypot(xs - 655, ys - 472)
# only the rim band the hourglass touched (x > 700) — the arrow in the middle is left untouched,
# and the weight ramps in from x 700→724 and from the midline up, so no seam or ghost shows
#  above the arrow (y < 405) the band may start earlier (x > 672) to catch the base's left edge
x0 = np.where(ys < 405, 672.0, 700.0)
q = (xs > x0) & (ys < 472) & (rad <= 108)
mx = np.clip(2 * 655 - xs, 0, W - 1)
wq = q * np.clip((472 - ys) / 30.0, 0, 1) * np.clip((xs - x0) / 20.0, 0, 1)
for c in range(4):
    a[..., c] = a[..., c] * (1 - wq) + orig[ys, mx, c] * wq
# the ring just outside the disc (upper-right) held only hourglass → clear it (above the card edge)
ring = (xs > 655) & (ys < 452) & (rad > 106) & (rad <= 126)
a[..., 3] = np.where(ring, 0, a[..., 3])

# ── 2) empty the progress groove: one smooth pill with the groove's own cross-profile
L = np.array([427.0, 609.0]); R = np.array([838.0, 593.0]); r = 21.0
u = (R - L) / np.linalg.norm(R - L); n = np.array([-u[1], u[0]])
t = (xs - L[0]) * u[0] + (ys - L[1]) * u[1]
v = (xs - L[0]) * n[0] + (ys - L[1]) * n[1]
length = np.linalg.norm(R - L)
# cross-profile averaged over an empty stretch of the groove (t 320..390)
band = (t > 320) & (t < 390) & (np.abs(v) < 26)
vb = v[band]; bins = np.round(vb * 2).astype(int)
prof = {}
for c in range(3):
    vals = orig[..., c][band]
    prof[c] = {b: vals[bins == b].mean() for b in np.unique(bins)}
def profile(c, vv):
    b = np.clip(np.round(vv * 2).astype(int), min(prof[c]), max(prof[c]))
    lut = np.array([prof[c].get(i, np.nan) for i in range(min(prof[c]), max(prof[c]) + 1)])
    ok = ~np.isnan(lut); idx = np.arange(len(lut)); lut = np.interp(idx, idx[ok], lut[ok])
    return lut[b - min(prof[c])]
# distance to the pill's centre segment ⇒ round caps at both ends, soft 1.5px edge
tc = np.clip(t, 0, length)
dist = np.hypot(t - tc, v)
w = np.clip((r + 0.5 - dist) / 1.5, 0, 1) * (t < 300)
for c in range(3):
    a[..., c] = a[..., c] * (1 - w) + profile(c, v) * w
Image.fromarray(a.round().clip(0, 255).astype(np.uint8)).save('out/robot_waiting.png', optimize=True)
print('ok')
