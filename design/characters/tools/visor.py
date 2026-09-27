import numpy as np
from collections import deque
def _largest(m):
    H, W = m.shape; seen = np.zeros_like(m, bool); best = None
    for y, x in zip(*np.nonzero(m)):
        if seen[y, x]: continue
        q = deque([(y, x)]); seen[y, x] = 1; pts = []
        while q:
            cy, cx = q.popleft(); pts.append((cy, cx))
            for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                ny, nx = cy+dy, cx+dx
                if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = 1; q.append((ny, nx))
        if best is None or len(pts) > len(best): best = pts
    return np.array(best)
def visor(a, step=3):
    """face screen = largest neutral-black blob; holes (LED eyes) filled row-wise."""
    mx = a[..., :3].max(2); mn = a[..., :3].min(2)
    d = ((mx < 50) & ((mx - mn) < 26) & (a[..., 3] > 200))[::step, ::step]
    p = _largest(d)
    fill = np.zeros_like(d)
    for y in np.unique(p[:, 0]):
        xs = p[p[:, 0] == y, 1]; fill[y, xs.min():xs.max()+1] = True
    ys, xs = np.nonzero(fill); ys = ys * step; xs = xs * step
    c = np.cov(np.stack([xs, ys])); w, v = np.linalg.eigh(c); mj = v[:, np.argmax(w)]
    ang = (np.degrees(np.arctan2(mj[1], mj[0])) + 90) % 180 - 90
    return dict(bbox=(xs.min(), ys.min(), xs.max(), ys.max()), c=(round(xs.mean()), round(ys.mean())),
                ang=round(ang, 2), major=round(np.sqrt(w.max()), 1), minor=round(np.sqrt(w.min()), 1))
