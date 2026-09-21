# -*- coding: utf-8 -*-
"""🩺 هل عاد ديب سيك؟ — فحصٌ في ثوانٍ لا انتظارَ فيه.

    .venv/bin/python tools/check_deepseek.py

يجرّب النماذج الثلاثة بمهلةٍ قصيرة ويطبع أيُّها يردّ. ومتى عاد
`deepseek-chat` عملت الرياضياتُ من نفسها بلا تعديلِ سطر — الاسمُ من
`DEEPSEEK_MODEL` في البيئة وافتراضُه الأصل ([core/curriculum]).
"""
import asyncio
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

MODELS = ("deepseek-chat", "deepseek-flash", "deepseek-v4-pro")
TIMEOUT = 25


async def probe(client, name):
    t = time.time()
    try:
        r = await asyncio.wait_for(client.chat.completions.create(
            model=name, messages=[{"role": "user", "content": "قل: تم"}],
            max_tokens=8, temperature=0), timeout=TIMEOUT)
        return name, time.time() - t, "✅ يردّ", (r.choices[0].message.content or "")[:20]
    except asyncio.TimeoutError:
        return name, time.time() - t, "⏳ يتعلّق بلا ردّ", ""
    except Exception as e:
        return name, time.time() - t, f"✗ {type(e).__name__}", str(e)[:60]


async def main():
    import api
    client = api.AI_CLIENTS.get("deepseek")
    if client is None:
        print("✗ لا عميلَ لديب سيك — تحقّق من DEEPSEEK_API_KEY")
        return
    print(f"{'النموذج':<20}{'الزمن':>8}  الحالة")
    rows = await asyncio.gather(*(probe(client, m) for m in MODELS))
    for name, secs, state, extra in rows:
        print(f"{name:<20}{secs:>7.1f}ث  {state}  {extra}")

    live = [n for n, _, s, _ in rows if s.startswith("✅")]
    current = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
    print(f"\nالمستعمَل الآن: {current}")
    if current in live:
        print("✅ الرياضياتُ تعمل.")
    elif live:
        print(f"⚠️ الرياضياتُ معطّلة. للتحويل فوراً ضع في .env:\n"
              f"   DEEPSEEK_MODEL={live[0]}")
    else:
        print("✗ لا نموذجَ يردّ — العطلُ عند المزوّد.")

if __name__ == "__main__":
    asyncio.run(main())
