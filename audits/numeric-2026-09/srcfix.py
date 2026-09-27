"""srcfix.py FILE 'old' 'new' 'why' — إصلاحٌ في نصّ الكتاب (lessons_mode / unit_mode).
يستبدل في النصّ الخام للملف (كما هو مكتوب في JSON) ويشترط موضعاً واحداً بالضبط،
ثم يتحقّق أن الملف ما زال JSON سليماً. يُسجَّل في source_fixes.jsonl.
⚠️ بعده شغّل rehash.py: تعديلُ المصدر يغيّر بصمة الدرس فيُسقط شرحَه المخزون."""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
f, old, new, why = sys.argv[1:5]
p = f if os.path.isabs(f) else os.path.join(HERE, '../../Backend', f)
raw = open(p, encoding='utf-8').read(); n = raw.count(old)
assert n == 1, f"occurrences={n}"
out = raw.replace(old, new); json.loads(out)
open(p, 'w', encoding='utf-8').write(out)
open(os.path.join(HERE, 'source_fixes.jsonl'), 'a').write(json.dumps({'file': f, 'old': old, 'new': new, 'why': why}, ensure_ascii=False) + '\n')
print('OK', f)
