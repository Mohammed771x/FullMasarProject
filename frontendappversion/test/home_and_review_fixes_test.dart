// 🩹 ثلاثُ ملاحظاتٍ من المالك (٢٠٢٦-٠٩-٢٢) — كلٌّ منها عطلٌ يراه الطالب:
//
//   ① «الروبوت مطروحٌ داخل الدائرة الزرقاء، مش مضبوط».
//   ② «أوّلُ ما يدخل الطالب… تحت ماشي دروسٌ تحتاج تركيز… ماشي مكانٌ فاضي».
//   ③ «لما ننزل تحت نراجع إجاباتي، بغيت زرّ رجوع — ماشي لازم نطلع فوق».
//   ④ «العناصر الانتقالية… الأُس يكون فوق العنصر من اليمين».
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/shell/masar_bottom_nav.dart';
import 'package:ye_student_tutor/core/widgets/masar_brand.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_review_screen.dart';
import 'package:ye_student_tutor/features/quiz/presentation/widgets/quiz_ui.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

/// ترتيبُ المحارف **كما تراها العين** من اليمين إلى اليسار.
///
/// ⚖️ يقيس المواضع الأفقية الحقيقية بعد تطبيق خوارزمية الاتجاه، فلا يعتمد
///    على خطٍّ بعينه — ولذلك يصحّ في بيئة الاختبار كما يصحّ على الجهاز.
String _visualRtl(String s) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: const TextStyle(fontSize: 20)),
    textDirection: TextDirection.rtl,
  )..layout(maxWidth: 900);
  final items = <MapEntry<double, String>>[];
  for (var i = 0; i < s.length; i++) {
    final cu = s.codeUnitAt(i);
    if (cu == 0x2066 || cu == 0x2069) continue; // محارفُ عزلٍ لا تُرسم
    final b = tp.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1));
    if (b.isEmpty) continue;
    items.add(MapEntry(b.first.left, s[i]));
  }
  items.sort((a, b) => b.key.compareTo(a.key));
  return items.map((e) => e.value).join();
}

void main() {
  // ══════════════════════════════════════════════════
  // 🤖 ① الروبوت داخل دائرة «مسار»
  // ══════════════════════════════════════════════════
  testWidgets('🤖 الروبوت يجلس في الدائرة ولا يملؤها', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(Scaffold(
      bottomNavigationBar:
          MasarBottomNav(current: MasarTab.home, onTap: (_) {}),
    )));

    final robot = tester.getSize(find.byType(MasarRobot)).width;
    // 📐 الملف: روبوت 34 في دائرة 50 = **٦٨٪**. وكان 43 في 47 = ٩١٪،
    //    فيلتصق رأسُه بالحافّة من كل جهة.
    expect(robot / 47, closeTo(0.68, 0.03),
        reason: 'نسبةُ الروبوت إلى قطر الدائرة');
  });

  // ══════════════════════════════════════════════════
  // 🎯 ② الرئيسيةُ لا تترك مكانَ «الدروس التي تحتاج تركيز» فارغاً
  // ══════════════════════════════════════════════════
  // ⚖️ **حارسُ مصدرٍ لا اختبارُ ودجت:** بناءُ [HomeTab] يستدعي الجلسةَ
  //    والمخزونَ وحارسَ الأقسام والبانرات — وتهيئةُ ذلك كلِّه لاختبار
  //    «ماذا يظهر حين لا نتائج» تقيس التهيئةَ لا الشاشة. والذي يجب ألّا
  //    يعود هو **السطرُ نفسُه**: حذفُ القسم عند الفراغ.
  test('🎯 لا `SizedBox.shrink` مكانَ قسم التركيز — بل بطاقةٌ تدعو', () {
    final src = File(
            'lib/features/future_masar/presentation/screens/home_tab.dart')
        .readAsStringSync();

    expect(src, isNot(contains('if (weak.isEmpty) return const SizedBox')),
        reason: 'القسمُ كان يُحذف فيبقى بياضٌ تحت بطاقة التحليل');
    expect(src, contains('_weakSpotsEmpty'));
    expect(src, contains('هنا تظهر دروسك التي تحتاج تركيز'));
    // 🔗 والبطاقةُ بابٌ إلى أوّل خطوةٍ يحتاجها الطالب: اختبار.
    expect(src, contains('MasarTab.quiz'));
    // 🔇 و«عرض الكل» لا تُعرض على شاشةٍ فارغة.
    expect(src, contains('if (weak.isNotEmpty)'));
  });

  // ══════════════════════════════════════════════════
  // 📋 ③ زرُّ الرجوع في «راجع إجاباتك» لا يمرّ مع التمرير
  // ══════════════════════════════════════════════════
  testWidgets('📋 زرُّ الرجوع يبقى بعد التمرير إلى آخر الأسئلة',
      (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);

    final items = [
      for (var i = 0; i < 20; i++)
        QuizReviewItem(
          question: "السؤال رقم $i",
          options: const ["أ", "ب", "ج", "د"],
          correctIndex: 1,
          chosenIndex: i.isEven ? 1 : 2,
          lesson: "درس $i",
          topic: "موضوع",
        ),
    ];
    final result = QuizResult(
      id: "r1",
      subject: "كيمياء",
      grade: 3,
      track: "علمي",
      unit: "وحدة",
      lessons: const ["درس"],
      askedPerLesson: const {"درس": 20},
      score: 10,
      total: 20,
      wrong: const [],
      durationSec: 60,
      createdAt: DateTime(2026, 9, 1),
      reviewRaw: [for (final it in items) jsonEncode(it.toJson())],
    );

    await tester.pumpWidget(_host(QuizReviewScreen.saved(result)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(QuizHeader), findsOneWidget);

    // ⬇️ تمريرٌ طويل إلى آخر الأسئلة — وهو ما كان يُخفي الزرّ.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(QuizHeader), findsOneWidget,
        reason: 'الرأسُ ثابتٌ خارج القائمة فلا يمرّ معها');
  });

  // ══════════════════════════════════════════════════
  // ⚡ ④ شحنةُ الأيون فوق يمين رمزه
  // ══════════════════════════════════════════════════
  group('⚡ شحنةُ الأيون', () {
    test('☢️ كانت تقفز يسارَ الرمز — وهذا ما يثبته القياس', () {
      // بلا عزل: «⁺» تأخذ اتجاه الفقرة العربية فتسبق الرمز.
      expect(_visualRtl("تمتلك Zn²⁺ شحنة"), contains("²nZ⁺"));
    });

    test('وبعد العزل تُقرأ Zn²⁺ كما في الكتاب', () {
      // العرضُ من اليمين: العلامةُ أوّلاً ⇒ فهي أقصى يسار المجموعة… أي
      // أن المجموعة تُقرأ Z n ² ⁺ من اليسار. (والمقياسُ مواضعُ لا ظنّ.)
      expect(_visualRtl(isolateChargeSigns("تمتلك Zn²⁺ شحنة")),
          contains("⁺²nZ"));
    });

    test('ويشمل الأيونات والأسس السالبة كلَّها', () {
      const cases = {
        "أيون الكلوريد Cl⁻ هنا": "⁻lC",
        "المركب SO₄²⁻ ثابت": "⁻²₄OS",
        "الرقم 10⁻³ صغير": "³⁻01",
        "الإلكترون e⁻ سالب": "⁻e",
        "الحديد Fe³⁺ والنحاس Cu²⁺": "⁺³eF",
      };
      cases.forEach((src, want) {
        expect(_visualRtl(isolateChargeSigns(src)), contains(want),
            reason: src);
      });
    });

    test('☢️ ولا يمسّ ما لا شحنةَ فيه', () {
      for (final s in [
        "الأس 10⁶ بلا إشارة",
        "لا كيمياء هنا إطلاقاً",
        "المعادلة 2 + 3 = 5",
        "درجة الحرارة -25.9",
      ]) {
        expect(isolateChargeSigns(s), s, reason: s);
      }
    });
  });
}
