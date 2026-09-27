"""«هلا» turban alone (no face shell, screen, headphones), from out/robot_head.png (960x945)."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from matplotlib.colors import rgb_to_hsv
im = Image.open('out/robot_head.png').convert('RGBA'); W, H = im.size; k = 1.2   # grid view was 800 wide
outline = [(95,250),(100,190),(150,120),(230,40),(330,5),(480,0),(600,20),(700,90),(770,200),(790,300),
           (800,400),(790,460),(760,505),(740,512),
           (735,462),(690,398),(640,342),(580,302),(500,268),(400,247),(300,237),(200,237),(120,250)]
m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).polygon([(x*k, y*k) for x, y in outline], fill=255)
m = np.array(m.filter(ImageFilter.GaussianBlur(1.5))).astype(float) / 255
a = np.array(im).astype(float); h = rgb_to_hsv(a[..., :3] / 255)
shell = (h[..., 1] < 0.07) & (h[..., 2] > 0.85)
phone = (h[..., 0] > 0.55) & (h[..., 0] < 0.7) & (h[..., 1] > 0.6) & (h[..., 2] > 0.5)
drop = Image.fromarray(((shell | phone) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1))
m *= 1 - np.array(drop).astype(float) / 255 * (np.arange(H)[:, None] > 230*k)   # only near the brim
a[..., 3] *= m
out = Image.fromarray(a.round().astype(np.uint8)); out.save('out/turban_only.png')
bg = Image.new('RGBA', out.size, (200, 230, 200, 255)); bg.alpha_composite(out); bg.thumbnail((600, 600)); bg.save('turban_only_pv.png')
print(out.getchannel('A').getbbox())
