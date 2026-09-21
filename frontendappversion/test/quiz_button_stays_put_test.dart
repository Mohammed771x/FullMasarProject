// 📌 زرُّ «تأكيد» لا يتحرّك من مكانه.
//
// 🔴 **شكوى المالك (٢٠٢٦-٠٩-٢٢):** «أختار إجابة وأضغط تأكيد — ينزل الزرُّ
//    لتحت، فأحرّك أصبعي وراه.» فصندوقُ النتيجة كان يُولد بين الخيارات
//    والزرّ لحظةَ التأكيد، ويدفعه ٩١ بكسلة.
//
// ⚠️ **ولا يُثبّتُه مقاسٌ مكتوب**: نصُّ «إجابة صحيحة» سطرٌ واحد أبداً، ونصُّ
//    الموضوع قد يلتفّ سطرين — فالحجزُ يُقاس بنصِّ السؤال المعروض نفسِه.
//    ولذلك يجري الاختبارُ على **الحالتين**، وبموضوعٍ طويلٍ عمداً في إحداهما.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_controller.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_play_screen.dart';
import 'package:ye_student_tutor/features/quiz/presentation/widgets/quiz_ui.dart';

QuizController _controllerWith(String topic) {
  final c = QuizController()
    ..subject = "احياء"
    ..grade = 3
    ..track = "علمي"
    ..unit = "الوحدة الأولى"
    ..questions = [
      QuizQuestion(
        q: "ما الطور الذي تصطفّ فيه الكروموسومات في وسط الخلية؟",
        options: const ["الطور التمهيدي", "الطور الاستوائي", "الطور الانفصالي", "الطور النهائي"],
        correctIndex: 1,
        topic: topic,
        lesson: "الانقسام المتساوي",
      ),
    ];
  return c;
}

Future<Offset> _buttonTopLeft(WidgetTester tester, String label) async {
  expect(find.text(label), findsOneWidget, reason: 'زرُّ «$label» غير معروض');
  // 🎯 موضعُ **الزرّ** لا موضعُ نصّه: عرضُ النصّ يتغيّر بين «تأكيد»
  //    و«عرض النتيجة»، فمركزُه يزحف أفقياً بلا أن يتحرّك الزرّ.
  return tester.getTopLeft(find.byType(QuizPrimaryButton));
}

Future<void> _pumpScreen(WidgetTester tester, QuizController c) async {
  // 📱 بمقاس جهازٍ حقيقي: على سطح الاختبار الافتراضي (800×600) تقع
  //    البطاقةُ والخياراتُ خارج المنظور فلا يصل النقرُ إلى الزرّ.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: QuizPlayScreen(controller: c),
    ),
  ));
  // ⏱️ **تُنهى حركةُ الدخول** ([FadeInSlide]): إطارٌ واحدٌ يترك البطاقة
  //    مزاحةً عن موضعها، فيُقاس موضعٌ عابرٌ ويقع النقرُ في الفراغ.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('📌 موضعُ الزرّ واحدٌ قبل التأكيد وبعده — إجابة صحيحة',
      (tester) async {
    final c = _controllerWith("أطوار الانقسام المتساوي");
    await _pumpScreen(tester, c);

    await tester.tap(find.text("الطور الاستوائي"));
    await tester.pump();
    final before = await _buttonTopLeft(tester, "تأكيد");

    await tester.tap(find.text("تأكيد"));
    await tester.pump();
    expect(c.confirmed, isTrue);
    // 🟩 صندوقُ النتيجة ظهر فعلاً — وإلا كان الاختبارُ يثبّت لا شيء.
    expect(find.text("إجابة صحيحة! 🎯"), findsOneWidget);

    final after = await _buttonTopLeft(tester, "عرض النتيجة 🏁");
    expect(after.dy, closeTo(before.dy, 0.5),
        reason: 'الزرُّ تحرّك ${(after.dy - before.dy).abs()} بكسلة عند التأكيد');
  });

  testWidgets('📌 وموضعُه واحدٌ كذلك مع إجابةٍ خاطئةٍ وموضوعٍ طويل',
      (tester) async {
    // 📏 موضوعٌ يلتفّ سطرين حتماً — هو ما كان يكسر أيَّ حجزٍ بمقاسٍ ثابت.
    final c = _controllerWith(
        "مراحل الانقسام المتساوي في الخلايا الحيوانية والنباتية وأوجه الفرق بينها");
    await _pumpScreen(tester, c);

    await tester.tap(find.text("الطور النهائي"));
    await tester.pump();
    final before = await _buttonTopLeft(tester, "تأكيد");

    await tester.tap(find.text("تأكيد"));
    await tester.pump();
    expect(c.confirmed, isTrue);
    // 📏 **اثنتان بالضبط**: القالبُ الخفيُّ الذي يحجز المكان، والصندوقُ
    //    المعروضُ فوقه. وهذا نفسُه دليلُ أن الحجزَ بمقاس هذا النصّ لا بمقاسٍ
    //    مكتوب — فلا يُزاح الزرُّ مهما طال اسمُ الموضوع.
    expect(find.textContaining("راجعه بعد الاختبار"), findsNWidgets(2));

    final after = await _buttonTopLeft(tester, "عرض النتيجة 🏁");
    expect(after.dy, closeTo(before.dy, 0.5),
        reason: 'الزرُّ تحرّك ${(after.dy - before.dy).abs()} بكسلة عند التأكيد');
  });

  testWidgets('ولا يتحرّك بمجرّد تبديل الاختيار قبل التأكيد', (tester) async {
    final c = _controllerWith("أطوار الانقسام");
    await _pumpScreen(tester, c);

    await tester.tap(find.text("الطور الاستوائي"));   // الصحيح
    await tester.pump();
    final onRight = await _buttonTopLeft(tester, "تأكيد");

    await tester.tap(find.text("الطور التمهيدي"));    // الخاطئ
    await tester.pump();
    final onWrong = await _buttonTopLeft(tester, "تأكيد");

    // ⚠️ حارسُ الحلّ الساذج: لو حُجز المكانُ بنصِّ الحالة **المختارة**
    //    لتبدّل الحجزُ مع كل لمسةِ خيار — فيقفز الزرُّ والطالبُ يتردّد بعد.
    expect(onWrong.dy, closeTo(onRight.dy, 0.5));
  });
}
