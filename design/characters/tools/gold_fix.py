"""Second pass: the gold/copper motif family (turban medallions, wizar lozenges, tassels) mapped FULLY
(L, a, b mean+std) to «هلا» — the first pass kept the source lightness and left them brighter/more orange.
Props are excluded by boxes (fractions of the image)."""
import sys, json, numpy as np, match2 as M
from PIL import Image
ref = np.array(Image.open('out/robot_hello.png').convert('RGBA')).astype(float) / 255
Lr = M.to_lab(ref[..., :3]); fr = M.fams(ref[..., :3], ref[..., 3], np.zeros(ref.shape[:2], bool))
t = Lr[fr['motif']]; mt, st = t.mean(0), t.std(0)
for src, dst, excl in json.load(open(sys.argv[1])):
    a = np.array(Image.open(src).convert('RGBA')).astype(float) / 255; La = M.to_lab(a[..., :3])
    ex = M.boxmask(a.shape[:2], excl); m = M.fams(a[..., :3], a[..., 3], ex)['motif']
    s = La[m]; La[m] = (s - s.mean(0)) / (s.std(0) + 1e-6) * st + mt
    out = np.concatenate([M.to_rgb(La), a[..., 3:]], -1)
    Image.fromarray((out * 255).round().astype(np.uint8)).save(dst, optimize=True)
    b = M.to_lab(out[..., :3])[m]; print(dst, 'motif L%.0f a%.1f b%.1f' % tuple(b.mean(0)), 'ref L%.0f a%.1f b%.1f' % tuple(mt))
