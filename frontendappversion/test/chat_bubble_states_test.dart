// 🫧 حالاتُ فقاعة الردّ — العطل · الجوابُ المقطوع · النقرُ على النصّ.
//
// 🔴 **ما رُئي في المحاكي (فحص ٢٠٢٦-١٠-٠٢):**
//    • كلُّ نقرةٍ أو ضغطةٍ مطوّلة على نصّ جوابٍ ترمي
//      `Null check operator used on a null value` (flutter_markdown).
//    • فقاعةُ العطل بزرّ «حفظ» وتحتها «بسّط لي» و«لخّص» — ولا زرّ إعادة.
//    • الجوابُ المقطوع يبدو كاملاً.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/monitoring/crash_reporter.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_list_view.dart';

Future<ChatController> _pumpChat(
    WidgetTester tester, List<Map<String, dynamic>> messages) async {
  final c = ChatController()..messages = messages;
  addTearDown(c.dispose);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Scaffold(body: ChatListView(controller: c)),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  return c;
}

void main() {
  group('👆 النقرُ على نصّ الجواب', () {
    testWidgets('نقرةٌ وضغطةٌ مطوّلة على نصٍّ قابلٍ للتحديد ⇒ بلا استثناء',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MasarMarkdown(
              data: "الفعلُ الناقص يرفع **المبتدأ** وينصب الخبر.",
              selectable: true,
            ),
          ),
        ),
      ));
      await tester.tap(find.byType(SelectableText).first);
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: "النقرُ على نصّ الجواب رمى استثناءً");

      await tester.longPress(find.byType(SelectableText).first);
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: "الضغطةُ المطوّلة على نصّ الجواب رمت استثناءً");
    });

    testWidgets('وداخل فقاعة المحادثة نفسِها', (tester) async {
      await _pumpChat(tester, [
        {"role": "user", "text": "سؤال"},
        {"role": "ai", "text": "جوابٌ كامل يُقرأ ويُحدَّد.", "refs": []},
      ]);
      await tester.tap(find.byType(SelectableText).last);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('🧯 فقاعةُ العطل', () {
    testWidgets('زرُّ «أعد المحاولة» ظاهر، و«حفظ» واقتراحاتُ المتابعة غائبة',
        (tester) async {
      await _pumpChat(tester, [
        {"role": "user", "text": "سؤال"},
        {
          "role": "ai",
          "text": "📡 تعذّر الاتصال",
          "refs": [],
          "isError": true,
          "canRetry": true,
          "retry": {"typed": "سؤال", "custom": null, "teacher": false},
        },
      ]);
      expect(find.byKey(const ValueKey("retryButton")), findsOneWidget);
      expect(find.text("حفظ"), findsNothing);
      // ♿ قارئُ الشاشة يقرأ الزرّ باسمه لا «زرّ» وحدها.
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == "أعد المحاولة"),
        findsOneWidget,
      );
    });

    testWidgets('عطلٌ لا تُجدي إعادتُه (الحصة/الحظر) ⇒ بلا زرّ', (tester) async {
      await _pumpChat(tester, [
        {"role": "user", "text": "سؤال"},
        {
          "role": "ai",
          "text": "🎟️ انتهت أسئلتك",
          "refs": [],
          "isError": true,
          "canRetry": false,
          "retry": {"typed": "سؤال", "custom": null, "teacher": false},
        },
      ]);
      expect(find.byKey(const ValueKey("retryButton")), findsNothing);
    });

    testWidgets('عطلٌ عاد من المخزن (بلا ما يُعاد) ⇒ بلا زرٍّ لا يعمل',
        (tester) async {
      await _pumpChat(tester, [
        {"role": "user", "text": "سؤال"},
        {"role": "ai", "text": "📡 تعذّر الاتصال", "refs": [], "isError": true},
      ]);
      expect(find.byKey(const ValueKey("retryButton")), findsNothing);
      expect(find.text("حفظ"), findsNothing);
    });
  });

  testWidgets('🏷️ الجوابُ المقطوع موسومٌ «غير مكتمل» — والكاملُ لا',
      (tester) async {
    await _pumpChat(tester, [
      {"role": "user", "text": "سؤال"},
      {"role": "ai", "text": "جزءٌ من جواب", "refs": [], "partial": true},
      {"role": "user", "text": "سؤال ثانٍ"},
      {"role": "ai", "text": "جوابٌ كامل", "refs": []},
    ]);
    expect(find.byKey(const ValueKey("partialTag")), findsOneWidget);
    expect(find.text("⚠️ جوابٌ غير مكتمل"), findsOneWidget);
  });

  group('🔒 مراقبةُ الأعطال لا ترفع محتوى الطالب', () {
    test('العربيُّ في نصّ الاستثناء يُستبدل', () {
      final s = CrashReporter.scrub(
          "Bad state: لا يوجد عنصر في سؤال الطالب عن الغدة النخامية");
      expect(s.contains("الغدة"), isFalse);
      expect(s, startsWith("Bad state: «…»"));
    });

    test('FormatException تُرفع بلا مصدرها (مقطعِ النصّ الذي فشل)', () {
      final e = FormatException("Unexpected character", '{"answer":"سر الطالب');
      expect(CrashReporter.describe(e), "FormatException: Unexpected character");
      expect(ScrubbedError(e).toString().contains("سر"), isFalse);
    });

    test('الطولُ ٣٠٠ حرفاً على الأكثر، ولا يُشطر رمزٌ تعبيريّ', () {
      final s = CrashReporter.scrub("x" * 299 + "😀" * 5);
      expect(s.length, lessThanOrEqualTo(302));
      expect(s.contains('\uD83D…'), isFalse);
    });

    test('مطفأةٌ في الاختبار/التصحيح — لا يُرفع شيء', () {
      expect(CrashReporter.enabled, isFalse);
    });
  });
}
