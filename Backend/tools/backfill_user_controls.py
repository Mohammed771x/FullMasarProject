#!/usr/bin/env python3
# ==================================================
# 🔒 tools/backfill_user_controls.py — نقلٌ لمرّةٍ واحدة إلى user_controls
# ==================================================
# الحظرُ والحدُّ الخاص صارا يُكتبان في `user_controls/{uid}` ([core/user_controls]).
# أمّا ما وُضع **قبل** ذلك ففي `users/{uid}` وحده — ويسقط إن حذف صاحبُه مستندَه.
# هذا السكربت ينسخ تلك القرارات القديمة مرّةً واحدة.
#
#   cd Backend && .venv/bin/python tools/backfill_user_controls.py          # عرضٌ بلا كتابة
#   cd Backend && .venv/bin/python tools/backfill_user_controls.py --apply  # كتابةٌ فعلية
#
# ⚖️ لا يلمس حساباً له قرارٌ في `user_controls` أصلاً — الأحدث يبقى الحَكَم.

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(override=True)

from core import quota, user_controls  # noqa: E402


def main() -> int:
    apply = "--apply" in sys.argv
    db = quota._firestore()
    if db is None:
        print("⛔ لا Firestore — اضبط GOOGLE_APPLICATION_CREDENTIALS أو FIREBASE_SERVICE_ACCOUNT_JSON.")
        return 1

    existing = user_controls.read_all(db)
    todo = []
    for doc in db.collection("users").stream():
        if doc.id in existing:
            continue
        d = doc.to_dict() or {}
        fields = {}
        if d.get("banned") is True:
            fields["banned"] = True
        if isinstance(d.get("quota_override"), int) and not isinstance(d.get("quota_override"), bool):
            fields["quota_override"] = d["quota_override"]
        if fields:
            todo.append((doc.id, fields))

    for uid, fields in todo:
        print(f"{'✍️ ' if apply else '👀'} {uid}: {fields}")
        if apply:
            user_controls.write(db, uid, **fields)

    print(f"\n{len(todo)} حساباً {'نُقل' if apply else 'سيُنقل (أعد التشغيل بـ --apply)'}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
