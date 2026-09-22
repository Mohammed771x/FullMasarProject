// 🧠 وضعُ التفكير في شريط الكتابة — أيقونةٌ تُضغط، وورقةٌ تشرح، واختيارٌ يثبت.
//
// 🔴 **قرارُ المالك (2026-09-22):** جُرّبت شريحةً مكتوبةً باسمها فقال
//    «ما عجبنا مكانه… طول طول» — كانت تقتطع ٨٠ نقطةً من عرض الكتابة.
//    فصارت أيقونةً بحجم الكاميرا، والشرحُ يظهر عند الضغط لا دائماً.
//
// 📏 **ولماذا اختبارُ واجهةٍ لا اختبارُ حالة؟** زرٌّ يُرسم ولا تصله الضغطةُ
//    يبدو سليماً في كل اختبارٍ منطقيّ — وهذا ما يحرسه هذا الملف.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/settings/app_settings.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_input_area.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.I.resetAll();
    await AppSettings.I.load();
  });

  Future<ChatController> pumpBar(WidgetTester tester,
      {bool thinkingAvailable = true}) async {
    final c = ChatController();
    addTearDown(c.dispose);
    // 🧠 القدرةُ تأتي من الخادم ([GET /content/capabilities]) — والزرُّ
    //    يختفي حيث لا تصل، فلا بدّ من نصبها في الاختبار.
    c.thinkingAvailable = thinkingAvailable;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AnimatedBuilder(
            animation: c,
            builder: (_, __) =>
                ChatInputArea(controller: c, onEmptyWarning: () {}),
          ),
        ),
      ),
    ));
    await tester.pump();
    return c;
  }

  /// 🧭 أيقونةُ الدماغ — تُلتقط بنوعها لا بنصّها، فالشريطُ بلا كلمات.
  Finder brainIcon() => find.byWidgetPredicate((w) =>
      w is Icon && (w.icon?.fontFamily ?? '').startsWith('Phosphor'));

  testWidgets('الشريطُ بلا كلمةِ «تفكير» — لا تُقتطع مساحةُ الكتابة',
      (tester) async {
    await pumpBar(tester);
    expect(find.text('تفكير'), findsNothing);
  });

  testWidgets('الضغطةُ تفتح ورقةً تشرح الوضعين بفرقِهما', (tester) async {
    await pumpBar(tester);
    await tester.tap(brainIcon().at(1));   // الكاميرا أولاً ثم الدماغ
    await tester.pumpAndSettle();

    expect(find.text('عادي'), findsOneWidget);
    expect(find.text('تفكير'), findsOneWidget);
    // والوصفُ هو ما طلبه المالك: «يحلّ مسائل معقّدة وقد يتأخّر»
    expect(find.textContaining('المسائل المعقّدة'), findsOneWidget);
    expect(find.textContaining('سريعة'), findsOneWidget);
  });

  testWidgets('اختيارُ «تفكير» يُشعله، واختيارُ «عادي» يُطفئه', (tester) async {
    final c = await pumpBar(tester);
    expect(c.thinking, isFalse, reason: 'الافتراضُ إطفاء');

    await tester.tap(brainIcon().at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تفكير'));
    await tester.pumpAndSettle();
    expect(c.thinking, isTrue);

    await tester.tap(brainIcon().at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عادي'));
    await tester.pumpAndSettle();
    expect(c.thinking, isFalse);
  });

  testWidgets('واختيارُ الوضعِ القائم لا يقلبه', (tester) async {
    final c = await pumpBar(tester);
    await tester.tap(brainIcon().at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عادي'));     // وهو المختارُ أصلاً
    await tester.pumpAndSettle();
    expect(c.thinking, isFalse, reason: 'لا يُقلب وضعٌ باختيارِ نفسِه');
  });

  testWidgets('وفي موادّ جيميناي لا زرَّ أصلاً — لا يَعِد بما لا يقع',
      (tester) async {
    await pumpBar(tester, thinkingAvailable: false);
    // الكاميرا تبقى، والدماغُ وحدَه يغيب
    final icons = find.byWidgetPredicate((w) =>
        w is Icon && (w.icon?.fontFamily ?? '').startsWith('Phosphor'));
    final before = icons.evaluate().length;
    await pumpBar(tester, thinkingAvailable: true);
    expect(icons.evaluate().length, before + 1);
  });

  testWidgets('🧮 والرياضياتُ يظهر زرُّها رغم أن شجرةَ دروسها ليست في القدرات',
      (tester) async {
    // 🔴 **العطبُ (2026-09-22):** كان `thinkingAvailable` مشتقّاً من
    //    `caps`، والرياضياتُ تضعها `null` عمداً في قسم الطالب — فاختفى
    //    الزرُّ عن **أكثر المواد حاجةً إليه**. ورآه المالك على الشاشة.
    final c = ChatController();
    addTearDown(c.dispose);
    c.thinkingAvailable = true;
    expect(c.caps, isNull, reason: 'حالُ الرياضيات في قسم الطالب');

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AnimatedBuilder(
            animation: c,
            builder: (_, __) =>
                ChatInputArea(controller: c, onEmptyWarning: () {}),
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byWidgetPredicate((w) =>
        w is Icon &&
        (w.icon?.fontFamily ?? '').startsWith('Phosphor')).at(1));
    await tester.pumpAndSettle();
    expect(find.text('تفكير'), findsOneWidget,
        reason: 'الزرُّ حاضرٌ وشجرةُ الدروس غائبة — لا علاقةَ بينهما');
  });
}
