"""Cut the head (turban included) out of the reference «مرحباً» character, so every head
wears the *same* turban — pattern, colours and all. Coordinates are in robot_hello.png (743x960)."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
im = Image.open('out/robot_hello.png').convert('RGBA')
W, H = im.size
keep = [(140,0),(743,0),(743,395),(615,395),(600,418),(578,432),(578,494),(470,494),
        (468,446),(440,437),(400,426),(350,413),(300,399),(262,380),(232,358),(200,322),(140,300)]
m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).polygon(keep, fill=255)
m = np.array(m.filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255
# the hanging turban tail fades out below the headphone instead of ending on a hard line
ys = np.arange(H)[:, None] * np.ones(W)[None, :]
xs = np.ones(H)[:, None] * np.arange(W)[None, :]
tail = (xs > 466) & (xs < 580)
fade = np.clip((492 - ys) / 44, 0, 1)
m = np.where(tail & (ys > 448), m * fade, m)
a = np.array(im).astype(float)
a[..., 3] *= m
out = Image.fromarray(a.round().astype(np.uint8))
bb = out.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox(); out = out.crop(bb)
s = 960 / max(out.size); out = out.resize((round(out.width*s), round(out.height*s)), Image.LANCZOS)
out.save('out/robot_head.png', optimize=True); print('bbox in hello', bb, 'size', out.size, 'scale', round(s,4))
