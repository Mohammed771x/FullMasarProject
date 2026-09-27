#!/bin/sh
# verify.sh — بعد كل إصلاح مصدر: rehash ثم hashcheck (يجب LOST 0)
H=$(cd "$(dirname "$0")" && pwd); P="$H/../../Backend/.venv/bin/python"
"$P" "$H/rehash.py" | tail -1 && "$P" "$H/hashcheck.py" --compare baseline_valid.json | tail -2
