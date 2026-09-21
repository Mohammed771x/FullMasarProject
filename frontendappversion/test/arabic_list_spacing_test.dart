// ══════════════════════════════════════════════════
// ↩️ «الكلام محشو، كله ورا بعض» — سطرُ الكاتب سطرٌ على الشاشة
// ══════════════════════════════════════════════════
//
// 🔴 **علّةُ المالك (2026-09-16).** وكانت في الرسّام لا في الشروح:
//    الماركداون القياسيّ **يَلحم** الأسطرَ المتتالية في فقرةٍ واحدة ما لم
//    يفصلها سطرٌ فارغ. وقوائمُنا مرقّمةٌ **بأرقامٍ عربية** بقرار المالك
//    ([arabic-numerals-in-answers])، و«١-» ليست بنداً في عُرف الماركداون
//    (يعرف `1.` اللاتينية وحدها) — فالبنودُ تُعرض سطراً واحداً متّصلاً.
//
// 📊 **مسحُ المخزون:** ١٨٢ درساً من ٨١٣ فيها ١١١٩ بنداً ملتحماً، أكثرُها
//    فيزياءُ وكيمياء — وهو عينُ ما رآه المالك حين قال «دروس الفيزياء شرح
//    خام، بدون السطور» بينما «درس الأحياء طلع رهيب» (قوائمُه بشُرَط).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

/// كلُّ ما رُسم من نصٍّ في الشجرة، مجموعاً.
String _rendered(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final element in find.byType(RichText).evaluate()) {
    final rich = element.widget as RichText;
    buffer.writeln(rich.text.toPlainText());
  }
  return buffer.toString();
}

Future<void> _pump(WidgetTester tester, String data, {bool math = true}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: MasarMarkdown(data: data, math: math, subject: "فيزياء"),
          ),
        ),
      ),
    ));

void main() {
  testWidgets('🔴 بنودُ القائمة العربية لا تلتحم في سطرٍ واحد',
      (tester) async {
    // نصٌّ من درسٍ حقيقيّ: «سرعة انتشار الموجات الصوتية» (الثاني العلمي).
    await _pump(tester, "تتأثر سرعة الصوت بخاصيتين أساسيتين للمادة:\n"
        "١- مرونة الوسط: الأجسام الصلبة ذات مرونة كبيرة.\n"
        "٢- كثافة الوسط: زيادة الكثافة تقلل سرعة الصوت.");

    final text = _rendered(tester);
    expect(text, contains("١- مرونة الوسط"));
    expect(text, contains("٢- كثافة الوسط"));
    expect(text, contains("\n١- "),
        reason: '☢️ البندُ الأول التحم بما قبله — وهو عينُ «كله ورا بعض»');
    expect(text, contains("\n٢- "),
        reason: '☢️ البندُ الثاني التحم بالأول');
  });

  testWidgets('وكذلك في المسار الذي لا رياضياتَ فيه', (tester) async {
    await _pump(tester, "أسبابٌ ثلاثة:\n١- الأول.\n٢- الثاني.\n٣- الثالث.",
        math: false);

    final text = _rendered(tester);
    expect(text, contains("\n٢- "));
    expect(text, contains("\n٣- "));
  });

  testWidgets('والنثرُ المتتابع يبقى أسطراً كما كتبه صاحبُه', (tester) async {
    await _pump(tester, "الجملة الأولى.\nالجملة الثانية.");
    expect(_rendered(tester), contains("الجملة الأولى.\nالجملة الثانية."));
  });

  testWidgets('⚠️ والفقرةُ الحقيقية تبقى فقرةً: السطرُ الفارغ لم يتغيّر',
      (tester) async {
    await _pump(tester, "فقرةٌ أولى.\n\nفقرةٌ ثانية.");
    final text = _rendered(tester);
    expect(text, contains("فقرةٌ أولى."));
    expect(text, contains("فقرةٌ ثانية."));
  });

  // ══════════════════════════════════════════════════
  // 🧱 والعنوانُ يُرى عنواناً
  // ══════════════════════════════════════════════════
  //
  // 🔴 **العلّةُ الثانية خلف «الكلام محشو»**: عنوانُ `###` كان يُرسم بنمط
  //    الفقرة حرفاً بحرف (قياسٌ من شجرة العرض: ١٦/w500 للاثنين)، لأن
  //    الشاشات تمرّر `MarkdownStyleSheet(p: …)` وفيها حقلٌ واحدٌ وبقيةُ
  //    الحقول `null`. فشرحٌ مقسّمٌ إلى ستّة أقسامٍ يصل كتلةً بلا فاصلٍ يُرى.

  /// نمطُ أولِ مقطعٍ نصّه `text` — كما يراه الطالب فعلاً.
  TextStyle? styleOf(WidgetTester tester, String text) {
    for (final element in find.byType(RichText).evaluate()) {
      final span = (element.widget as RichText).text as TextSpan;
      TextStyle? hit;
      span.visitChildren((s) {
        if (hit == null && s is TextSpan && (s.text ?? "").contains(text)) {
          hit = s.style;
        }
        return hit == null;
      });
      if (hit != null) return hit;
    }
    return null;
  }

  testWidgets('🔴 العنوانُ أكبرُ وأثقلُ من الفقرة — لا نسخةٌ منها',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: MasarMarkdown(
            data: "### خصائص المواد\nتتأثر سرعة الصوت بخاصيتين.",
            subject: "فيزياء",
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, height: 1.6),
            ),
          ),
        ),
      ),
    ));

    final head = styleOf(tester, "خصائص المواد");
    final body = styleOf(tester, "تتأثر سرعة الصوت");
    expect(head, isNotNull);
    expect(body, isNotNull);
    expect(head!.fontSize!, greaterThan(body!.fontSize!),
        reason: '☢️ العنوانُ بحجم الفقرة — فلا فاصلَ يراه الطالب');
    expect(head.fontWeight!.value, greaterThan(body.fontWeight!.value));
  });

  testWidgets('وحجمُه يتبع حجمَ الخطّ الذي اختاره الطالب', (tester) async {
    // ⚖️ لو أُخذ من الثيم لثبت العنوانُ بينما يكبر النصُّ حوله، فينقلب
    //    العنوانُ أصغرَ من فقرته عند من كبّر الخطّ ([AppSettings]).
    Future<double> headSize(double p) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: MasarMarkdown(
              data: "### عنوان\nنصّ.",
              subject: "فيزياء",
              styleSheet: MarkdownStyleSheet(p: TextStyle(fontSize: p)),
            ),
          ),
        ),
      ));
      return styleOf(tester, "عنوان")!.fontSize!;
    }

    expect(await headSize(22), greaterThan(await headSize(14)));
  });

  test('☢️ حارسٌ بنيويّ: كلا مسارَي العرض يحترمان السطر', () {
    final src = File(
            "lib/core/widgets/masar_markdown.dart")
        .readAsStringSync();
    // 🔴 مسارانِ يرسمان الماركداون: السريعُ (بلا كسورٍ ولا معادلات) ومسارُ
    //    الكتل. ونسيانُ أحدِهما يعني أن العلّة تعود في نصف الدروس فقط —
    //    وهي أصعبُ من عودتها كلِّها.
    expect("softLineBreak: true".allMatches(src).length, 2,
        reason: 'مسارُ عرضٍ بلا احترامٍ للسطر');
  });
  // 🔢 **الأرقامُ الفارسية تُوحَّد عند العرض** (رُصد 2026-09-17): مسحُ
  //    الصفوف الثلاثة وجد ٨٤٨٣ محرفاً فارسياً في ٣١٥ درساً — فيُعرض
  //    الجدولُ الواحد فيه «٦٠» و«۱۰۰» بخطّين مختلفَي الشكل (٤ و۴ · ٦ و۶).
  //    والعلاجُ في العرض يشمل المخزون كلَّه (٨١٣ شرحاً) بلا نداءٍ واحد
  //    وبلا إبطال بصمةِ درسٍ فيبطل شرحُه.
  test('الأرقامُ الفارسيةُ تصير عربيةً عند العرض', () {
    expect(arabizeDigits('م ع = (۱۰۰ - ۷۰) ÷ ٦٠ = ۴۵٪'),
        'م ع = (١٠٠ - ٧٠) ÷ ٦٠ = ٤٥٪');
  });

  test('ولا تُمسُّ العربيةُ ولا اللاتينية', () {
    expect(arabizeDigits('٧ و7 معاً'), '٧ و7 معاً');
    expect(arabizeDigits('بلا أرقام'), 'بلا أرقام');
  });
}
