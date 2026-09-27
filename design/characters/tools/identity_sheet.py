"""Build the Masar character identity sheet: full reference pose, cut head, garment close-ups, measured swatches."""
import json
from PIL import Image, ImageDraw, ImageFont

FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
F = lambda s, b=False: ImageFont.truetype(BOLD if b else FONT, s)

hello = Image.open('out/robot_hello.png').convert('RGBA')
head = Image.open('out/robot_head.png').convert('RGBA')
p = json.load(open('palette.json'))

W, H = 2400, 1560
sh = Image.new('RGBA', (W, H), (250, 251, 253, 255))
d = ImageDraw.Draw(sh)
d.text((60, 34), "MASAR CHARACTER  -  reference identity", fill=(20, 30, 50), font=F(46, True))
d.text((60, 92), "Source: Figma 'Welcome' (hello) pose - untouched. Every character wears exactly this outfit; only the pose changes.",
       fill=(90, 100, 120), font=F(24))

t = hello.copy(); t.thumbnail((720, 1000)); sh.alpha_composite(t, (60, 150))
d.text((60, 1170), "reference pose  (assets/characters/robot_hello.png)", fill=(80, 90, 110), font=F(22))
t = head.copy(); t.thumbnail((440, 460)); sh.alpha_composite(t, (840, 150))
d.text((840, 630), "head - cut from the same image", fill=(80, 90, 110), font=F(22))
d.text((840, 660), "(assets/characters/robot_head.png)", fill=(120, 130, 150), font=F(18))

crops = [("turban band - navy + gold medallions", (300, 60, 560, 240)),
         ("turban cloth - beige, soft folds", (430, 0, 650, 140)),
         ("sarong - navy / beige / gold diamond stripes", (250, 720, 560, 880)),
         ("thobe - white, gold buttons, gold pen", (330, 430, 560, 640)),
         ("headphone - royal blue + LED dashes", (140, 150, 230, 300)),
         ("face - black screen, cyan LED arcs + brows", (240, 200, 520, 380))]
for i, (n, b) in enumerate(crops):
    c = hello.crop(b); c.thumbnail((330, 220))
    bg = Image.new('RGBA', c.size, (255, 255, 255, 255)); bg.alpha_composite(c)
    cx = 1330 + (i % 3) * 360; cy = 150 + (i // 3) * 300
    sh.alpha_composite(bg, (cx, cy))
    d.text((cx, cy + c.height + 8), n, fill=(80, 90, 110), font=F(17))

rows = []
for k, v in p.items():
    base = k.split(' (')[0]
    if isinstance(v, dict):
        rows += [(f"{base} - {kk}", vv) for kk, vv in v.items()]
    else:
        rows.append((base, v))
d.text((840, 760), "Measured palette (k-means on the reference image)", fill=(20, 30, 50), font=F(26, True))
for i, (name, sw) in enumerate(rows):
    cx = 840 + (i // 9) * 780; cy = 810 + (i % 9) * 80
    d.text((cx, cy + 10), name.replace('_', ' '), fill=(40, 50, 70), font=F(20))
    for j, (hexv, _share) in enumerate(sw[:3]):
        rgb = tuple(int(hexv[q:q + 2], 16) for q in (1, 3, 5))
        x = cx + 400 + j * 118
        d.rounded_rectangle((x, cy, x + 100, cy + 44), 10, fill=rgb, outline=(210, 215, 225))
        d.text((x + 4, cy + 50), hexv, fill=(90, 100, 120), font=F(16))
sh.convert('RGB').save('identity_sheet.png', optimize=True)
print('ok')
