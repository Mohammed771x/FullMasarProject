"""srcconfig.py FILE — يوحّد صيغة التوزيع الإلكتروني في نص المصدر: 2S2 / 2S^2 / 2S^{2} ⇒ 2s²
(F الكبيرة مستثناة لأنها الفلور: 2F2). ويزيل $…$ حول التوزيع، ويفصل المستويات الملتصقة،
ويحوّل N^7 / $F^{9}$ في عمود «رمزه وعدده الذري» إلى «N 7». يسجّل في source_fixes.jsonl."""
import sys, os, re, json
HERE = os.path.dirname(os.path.abspath(__file__))
f = sys.argv[1]
p = f if os.path.isabs(f) else os.path.join(HERE, '../../Backend/data/subjects', f)
SUP = str.maketrans('0123456789', '⁰¹²³⁴⁵⁶⁷⁸⁹')
raw = open(p, encoding='utf-8').read(); out = raw
sub = lambda m: m.group(1) + m.group(2).lower() + m.group(3).translate(SUP)
out, a = re.subn(r'(?<![A-Za-z0-9])([1-7])([SPspdf])\^\{(\d{1,2})\}', sub, out)
out, b = re.subn(r'(?<![A-Za-z0-9])([1-7])([SPspdf])\^?(\d{1,2})(?![A-Za-z0-9.(])', sub, out)
out, c = re.subn(r'(?<=[⁰¹²³⁴⁵⁶⁷⁸⁹\]])(?=[1-7][spdf][⁰¹²³⁴⁵⁶⁷⁸⁹])', ' ', out)
out, d = re.subn(r'\$((?:\[[A-Z][a-z]?\] ?)?[1-7][spdf][⁰¹²³⁴⁵⁶⁷⁸⁹]+(?: [1-7][spdf][⁰¹²³⁴⁵⁶⁷⁸⁹]+)*)\$', r'\1', out)
out, e = re.subn(r'\| \$?([A-Z][a-z]?)\^\{?(\d{1,3})\}?\$? \|', r'| \1 \2 |', out)
json.loads(out)
open(p, 'w', encoding='utf-8').write(out)
open(os.path.join(HERE, 'source_fixes.jsonl'), 'a').write(json.dumps({'file': f, 'old': '2S2 / 2S^{2} / N^7', 'new': '2s² / N 7', 'why': f'صيغة التوزيع الإلكتروني ({a}+{b} مستوى، {c} فصل، {d} $، {e} رمز)'}, ensure_ascii=False) + '\n')
print('OK', f, a, b, c, d, e)
