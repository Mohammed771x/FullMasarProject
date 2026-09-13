// 🔬 الفيزياء بأرقامٍ عربية — طلبُ المالك 2026-09-12.
//
// 🔴 «مادة الفيزياء شيكت عليها، أمورها طيبة. فقط الأرقام حوّلها كامل
//    بالعربية، والسالب يكون من جهة يمين الرقم».
//
// ⚖️ **والتحويلُ في الخادم، والقلبُ في الرسم.** الخادم يُخرج «-٥» —
//    الإشارةُ قبل عددها كما تُكتب — والرقمُ العربي-الهندي صنفُه AN في
//    خوارزمية الاتجاه الثنائي، فتُحلّ الإشارةُ المجاورة له **محايدةً**
//    فتأخذ اتجاهَ السطر (RTL) فتقع يمينَه على الشاشة. فهذا الملفّ يقيس
//    **ما تراه العين** لا ما في النصّ.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

/// نصوص السطر مرتَّبةً كما تُقرأ من اليسار إلى اليمين على الشاشة.
Future<List<String>> _order(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SizedBox(width: 1200, child: child)),
    ),
  ));
  await tester.pump();
  final entries = <(double, String)>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final box = find.byWidget(w).evaluate().first.renderObject as RenderBox;
    entries.add((box.localToGlobal(Offset.zero).dx, w.data ?? ''));
  }
  entries.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in entries) e.$2];
}

void main() {
  group('➖ السالبُ يمينَ عددِه العربي', () {
    testWidgets('⭐ في معادلةٍ فيزيائية', (tester) async {
      final order = await _order(
          tester, const MathText(r'الشغل = -٥٠ جول'));
      expect(order.indexOf('-'), greaterThan(order.indexOf('٥٠')),
          reason: 'الإشارةُ يجب أن تقع يمينَ العدد: $order');
    });

    testWidgets('⭐ والرقمُ العربي يحفظ إشارتَه يمينَه حتى لو طُلب `latinSign`',
        (tester) async {
      // 🛡️ **حارسٌ ذاتيّ لا نطاقٌ فقط:** `_bidiRuns` تفصل الإشارةَ إذا
      //    كان عددُها عربياً **مهما كانت** `latinSign` — فلو ضُمّت
      //    الفيزياءُ يوماً إلى `latinSignSubjects` بالخطأ لم تنقلب
      //    إشارةُ رقمها. والنطاقُ يبقى الكيمياءَ وحدها على كل حال.
      expect(MasarMarkdown.latinSignSubjects, {'كيمياء'});
      final order = await _order(
          tester, const MathText(r'ح = -٢٠ نيوتن', latinSign: true));
      expect(order.indexOf('-'), greaterThan(order.indexOf('٢٠')),
          reason: 'الإشارةُ يجب أن تبقى يمينَ العدد العربي: $order');
    });
  });

  group('➖➖ وداخلَ الصناديق كذلك — طلبُ المالك الثاني 2026-09-12', () {
    testWidgets('⭐ الأُسُّ السالب في معادلةٍ فيزيائية حقيقية', (tester) async {
      // 📖 من ص ١٥٥ من كتاب الثالث: «طاع = ٦.٦٢٥ × ١٠^{-٣٤}».
      final order = await _order(
          tester, const MathText(r'ط = ٦.٦٢٥ × ١٠\sup{-٣٤} جول'));
      expect(order.indexOf('-'), greaterThan(order.indexOf('٣٤')),
          reason: 'إشارةُ الأُسّ يمينَ عدده: $order');
      // ⚖️ وترتيبُ المعادلة نفسُه لم يتغيّر: الأساسُ يمينَ أُسّه.
      expect(order.indexOf('١٠'), greaterThan(order.indexOf('-')));
    });

    testWidgets('⭐ والبسطُ السالب — من ص ١٣٨', (tester) async {
      final order = await _order(tester, const MathText(r'\frac{-١٣.٦}{٤}'));
      expect(order.indexOf('-'), greaterThan(order.indexOf('١٣.٦')),
          reason: 'إشارةُ البسط يمينَ عدده: $order');
    });
  });

  group('٠١٢ الأرقام العربية تُرسم كاملةً', () {
    testWidgets('الأُسُّ العربي يرتفع', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MathText(r'ع = ٣ × ١٠\sup{٨} م/ث')),
        ),
      ));
      await tester.pump();
      expect(find.text('٨'), findsOneWidget);
      expect(find.textContaining(r'\sup'), findsNothing);
    });

    testWidgets('الكسرُ العربي بسطاً ومقاماً', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MathText(r'ط = \frac{١}{٢} م ع')),
        ),
      ));
      await tester.pump();
      expect(find.text('١'), findsOneWidget);
      expect(find.text('٢'), findsOneWidget);
    });

    testWidgets('والجذرُ العربي', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MathText(r'ك = \sqrt{٢ط/ج}')),
        ),
      ));
      await tester.pump();
      expect(find.textContaining(r'\sqrt'), findsNothing);
    });
  });

  group('🛡️ ورمزُ الفيزياء اللاتينيّ يُقرأ من اليسار', () {
    testWidgets('«T1» و«T2» يبقيان لاتينيَّين وفي مكانهما', (tester) async {
      // ⚠️ الرمزُ يبقى لاتينياً بحكم الخادم («رقمٌ ملاصقٌ لحرفٍ لاتيني
      //    رمزٌ لا عدد»)، فيُرسم مقطعاً يُقرأ من اليسار: T ثم 1.
      //
      // 📐 والقفلُ على **ترتيب الشاشة** كاملاً: القارئُ العربي يقرأ من
      //    اليمين «T1» ثم «=» ثم «٣٠٠» ثم «كلفن» ثم «و» ثم «T2» …
      //
      // 🔄 **وعلامةُ المساواة خرجت من مقطع الرمز** (2026-09-12): كانت
      //    تُبلَع في مجموعة «T1» فتُقرأ «T1 =» من اليسار، والآن تتبع
      //    **اتجاه الفقرة** كما في UAX #9 (محايدٌ في آخر المقطع). وهو
      //    نفسُ ما يفعله الخطُّ في النصّ العادي — قِيس بـ`TextPainter`.
      final order = await _order(
          tester, const MathText(r'T1 = ٣٠٠ كلفن و T2 = ٤٥٠ كلفن'));
      expect(order.join(), 'كلفن٤٥٠=T2وكلفن٣٠٠=T1');
      // ورقمُ الرمز يقع **يساره** لأن المقطع لاتينيّ.
      expect(order.indexOf('T'), lessThan(order.indexOf('1')));
    });
  });
}
