"""robot_teach without the props behind/next to it (board, stacked books, plant, bulb, sparkles) —
owner 2026-09-27: «تخليه بس هو ماسك الدفتر والقلم». Keep = everything left of the board + the pointing
arm/glove/pen + the wizar tassels & swirl (polygons traced on 2× zooms of the 960×918 colour-matched frame)."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
im = Image.open('out/robot_teach.png').convert('RGBA'); W, H = im.size
arm = lambda p: [(520 + x/2, 220 + y/2) for x, y in p]
low = lambda p: [(500 + x/2, 560 + y/2) for x, y in p]
keep = Image.new('L', (W, H), 0); d = ImageDraw.Draw(keep)
d.rectangle((0, 0, 537, H), fill=255); d.rectangle((537, 445, 547, H), fill=255)   # board's left bar reaches x≈540 above the torso
d.rectangle((537, 0, 616, 350), fill=255)   # head + right headphone (the board starts at y≈365, the sparkles at x≈620)
d.polygon(arm([(583,44),(602,64),(562,150),(550,250),(554,330),(547,392),(512,432),(432,467),(412,502),(397,547),
               (362,582),(302,642),(262,684),(160,700),(56,700),(56,500),(100,470),(150,420),(215,362),(258,333),
               (298,318),(308,280),(358,208),(428,158),(478,138),(520,98),(560,58)]), fill=255)
d.polygon(low([(0,40),(70,45),(110,90),(170,130),(215,158),(260,212),(300,248),(325,283),(318,305),(280,330),
               (270,375),(297,415),(292,455),(250,485),(180,515),(100,555),(30,595),(0,600)]), fill=255)
km = np.array(keep).copy()
er = np.array(keep.filter(ImageFilter.MinFilter(5)))          # arm edge: shave the 2px of board white it caught
km[350:, 548:] = er[350:, 548:]
k = np.array(Image.fromarray(km).filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255
a = np.array(im)
cl = a[335:395, 776:805].astype(int)                           # the board's yellow clip beside the glove
cl[..., 3] *= ~((cl[..., 0] > 150) & (cl[..., 1] > 100) & (cl[..., 2] < 120)); a[335:395, 776:805] = cl.astype(np.uint8); a[..., 3] = (a[..., 3] * k).astype(np.uint8)
for x0, y0, x1, y1 in [(537, 440, 578, 482), (535, 540, 562, 625), (660, 350, 700, 380)]:   # board-frame blue slivers
    r = a[y0:y1, x0:x1].astype(int)
    blue = (r[..., 2] > 150) & (r[..., 0] < 110) & (r[..., 2] - r[..., 0] > 90)
    r[..., 3] *= ~blue; a[y0:y1, x0:x1] = r.astype(np.uint8)
out = Image.fromarray(a); out = out.crop(out.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox())
print('bbox', out.size)
out.save('out/robot_teach_solo_raw.png')
pv = Image.new('RGBA', out.size, (215, 235, 250, 255)); pv.alpha_composite(out); pv.thumbnail((700, 700)); pv.save('teach_solo_pv.png')
