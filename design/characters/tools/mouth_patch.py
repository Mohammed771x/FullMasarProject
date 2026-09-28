"""🗣️ رقعةُ الفم الناطق — تمسح قوسَ الابتسامة من شاشة الوجه.

تُنتج `assets/characters/robot_<name>_mouth.png`: مستطيلٌ من الصورة نفسِها مُلئ
بـ«رقعة كونز» (استيفاءٌ ثنائيّ من حوافّه الأربع) فيطابق لونَ الشاشة حوله بلا
درز. فوقه يرسم التطبيقُ فماً يُفتح ويُغلق (`_MouthPainter` في
`lib/core/widgets/masar_character.dart`).

المستطيلُ والقوسُ يُقاسان يدوياً لكل وضعية ويُكتبان في `MouthSpec` في الـenum:
  hello: patch (324,294)-(410,352) · قوس (343,311)→(357,346)→(393,329) · سماكة 12
⚠️ اختر المستطيلَ بحيث لا تمسّ حوافُّه العينين (الملءُ يأخذ لونَ الحافّة).
الاستعمال:  python3 mouth_patch.py robot_hello 324 294 410 352
"""
import sys

import numpy as np
from PIL import Image

name, L, T, R, B = sys.argv[1], *map(int, sys.argv[2:6])
src = f"frontendappversion/assets/characters/{name}.png"
a = np.asarray(Image.open(src).convert("RGBA")).astype(float)
p = a[T:B, L:R]
h, w = p.shape[:2]
out = np.zeros_like(p)
for y in range(h):
    for x in range(w):
        u, v = x / (w - 1), y / (h - 1)
        row = p[y, 0] * (1 - u) + p[y, -1] * u
        col = p[0, x] * (1 - v) + p[-1, x] * v
        corner = (p[0, 0] * (1 - u) * (1 - v) + p[0, -1] * u * (1 - v)
                  + p[-1, 0] * (1 - u) * v + p[-1, -1] * u * v)
        out[y, x] = row + col - corner
out = np.clip(out, 0, 255)
out[..., 3] = 255
Image.fromarray(out.astype("uint8")).save(
    f"frontendappversion/assets/characters/{name}_mouth.png")
print("✅", name, "mouth patch", w, "×", h)
