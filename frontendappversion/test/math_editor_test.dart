import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/math_keyboard/math_editor.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

// 🧮 محرّر الرياضيات — كلُّ اختبارٍ يمشي ضغطاتِ طالبٍ حقيقية ويقارن **النصَّ
//    المُرسل** حرفاً بحرف، لأنه ما سيقرؤه الموديل.

MathEditor _ed() => MathEditor(TextEditingController());

void main() {
  test('مسألةُ المالك: نها جا٣س² على جا²س — التربيعُ في موضعه', () {
    final e = _ed();
    e.insertTemplate('نها\\sub{س←‸} ');
    e.insert('٠');
    e.forward(); // خروجٌ من الدليل
    e.forward(); // تجاوزُ المسافة
    e.insertTemplate(r'\frac{‸}{}');
    e.insert('جا ');
    e.insert('٣س');
    e.insertTemplate(r'\sup{٢}‸');
    e.forward(); // إلى المقام
    e.insert('جا ');
    e.insertTemplate(r'\sup{٢}‸'); // يلتصق بالدالة لا بالمسافة
    e.insert('س');
    expect(e.text, r'نها\sub{س←٠} \frac{جا ٣س\sup{٢}}{جا\sup{٢} س}');
  });

  test('الأُسُّ الفارغ بعد دالة يدخل خانتَه قبل المسافة', () {
    final e = _ed();
    e.insert('جتا ');
    e.insertTemplate(r'\sup{‸}');
    e.insert('٣');
    e.forward();
    e.insert('(٢س)');
    expect(e.text, r'جتا\sup{٣} (٢س)');
  });

  test('المؤشرُ لا يقف داخل اسم أمرٍ ولا بين خانتين', () {
    final e = _ed();
    e.insertTemplate(r'\frac{‸}{}');
    final s = e.stops();
    // \frac{}{} : المواضع الصالحة 0 (قبل) · 6 (البسط) · 8 (المقام) · 9 (بعد)
    expect(s, [0, 6, 8, 9]);
  });

  test('⌫ على قالبٍ فارغ يمحوه كلَّه، وعلى الممتلئ يدخله', () {
    final e = _ed();
    e.insertTemplate(r'\frac{‸}{}');
    e.backspace();
    expect(e.text, '');

    e.insertTemplate(r'\sqrt{‸}');
    e.insert('٥');
    e.forward(); // بعد الجذر
    e.backspace(); // يدخل الجذر
    expect(e.text, r'\sqrt{٥}');
    expect(e.caret, e.text.length - 1);
    e.backspace(); // يمحو ٥
    e.backspace(); // الجذرُ فارغ ⇒ يُمحى
    expect(e.text, '');
  });

  test('⌫ يمحو اسمَ الدالة كتلةً', () {
    final e = _ed();
    e.insert('٢ + جتا ');
    e.backspace();
    expect(e.text, '٢ + ');
  });

  test('القيمةُ المطلقة لا تلتبس بعلامة المؤشر', () {
    final e = _ed();
    e.insertTemplate('|‸|');
    e.insert('ع');
    expect(e.text, '|ع|');
  });

  test('العرضُ يضع المؤشر والخانات الفارغة ولا يمسّ النصّ', () {
    final e = _ed();
    e.insertTemplate(r'\frac{‸}{}');
    expect(e.display(), '\\frac{$kCaretMark$kSlotMark}{$kSlotMark}');
    expect(e.text, r'\frac{}{}');
  });

  test('الجذرُ النونيّ: الدليلُ خانةٌ أولى', () {
    final e = _ed();
    e.insertTemplate(r'\sqrt[‸]{}');
    e.insert('٣');
    e.forward();
    e.insert('س - ١');
    expect(e.text, r'\sqrt[٣]{س - ١}');
  });
}
