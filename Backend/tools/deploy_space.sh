#!/usr/bin/env bash
# ==================================================
# 🚀 tools/deploy_space.sh — نشرُ الخادم إلى Hugging Face Space بشجرةٍ نظيفة
# ==================================================
# ☢️ (فحص الأمان 2026-10-01) الـSpace **عام** ورُفع يدوياً من مجلّدٍ محلي
#    (فيه `__pycache__`)، فبقي عليه `codes.json` ونظامُ الأكواد القديم.
#    ومجلّدُ Backend المحلي فيه `.env` بكل المفاتيح — رفعُه يدوياً مرّةً
#    واحدة يجعلها علنية في تبويب Files.
#
# ✅ هذا السكربت يرفع **ما في git وحده** (`git archive HEAD`) — فلا `.env`
#    ولا `.dev_store.json` ولا سجلات ولا تعديلاتٍ غير مُثبَّتة — ثم يتحقق
#    من خلوّه من الأسرار، ثم يرفعه **ماحياً** كلَّ ملفٍّ قديم على الـSpace
#    ليس في النسخة الجديدة (`codes.json` · `auth.py` · `*.pyc`).
#
#   cd Backend && tools/deploy_space.sh            # عرضُ ما سيُرفع فقط
#   cd Backend && tools/deploy_space.sh --push     # رفعٌ فعلي (يلزم: hf auth login)
#
# ⚠️ الأسرار تُضبط مرّةً في الـSpace: Settings ← Variables and secrets
#    (القائمة في رأس الـDockerfile).
set -euo pipefail

SPACE="${MASAR_SPACE:-Mohammed771/my-tutor-backend}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
HF="${HF_BIN:-$HERE/.venv/bin/hf}"

if [[ -n "$(git -C "$ROOT" status --porcelain -- Backend)" ]]; then
  echo "⚠️  في Backend تعديلاتٌ غير مُثبَّتة — لن تُرفع (يُرفع آخر commit وحده)."
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
git -C "$ROOT" archive HEAD Backend | tar -x -C "$STAGE"
SRC="$STAGE/Backend"

# 🧱 الحارس: ما لا يجوز أن يصل الـSpace أبداً.
bad="$(cd "$SRC" && find . \( -name '.env' -o -name '.env.*' -o -name '.dev_store.json' \
        -o -name 'codes.json' -o -name '*.pem' -o -name '*adminsdk*.json' \
        -o -name '*service-account*.json' \) -print)"
if [[ -n "$bad" ]]; then
  echo "⛔ ملفّاتٌ سرّية في الشجرة — أُلغي النشر:"; echo "$bad"; exit 1
fi
if grep -RIlE 'sk-proj-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|gsk_[A-Za-z0-9]{20,}|"private_key": *"-----BEGIN' "$SRC" >/dev/null 2>&1; then
  echo "⛔ نصٌّ يشبه مفتاحاً سرّياً في الشجرة — أُلغي النشر:"
  grep -RIlE 'sk-proj-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|gsk_[A-Za-z0-9]{20,}|"private_key": *"-----BEGIN' "$SRC"
  exit 1
fi

echo "📦 $(cd "$SRC" && find . -type f | wc -l | tr -d ' ') ملفاً من $(git -C "$ROOT" rev-parse --short HEAD) → $SPACE"

if [[ "${1:-}" != "--push" ]]; then
  echo "👀 عرضٌ فقط. للرفع: tools/deploy_space.sh --push"
  exit 0
fi

"$HF" upload "$SPACE" "$SRC" . --repo-type=space \
  --exclude 'tests/*' 'tools/*' '*.pyc' '__pycache__/*' \
  --delete '*' \
  --commit-message "deploy $(git -C "$ROOT" rev-parse --short HEAD)"

echo "✅ رُفع. تحقّق بعد اكتمال البناء:"
echo "   curl -s https://${SPACE/\//-}.hf.space/openapi.json | grep -c verify-access   # يجب: 0"
