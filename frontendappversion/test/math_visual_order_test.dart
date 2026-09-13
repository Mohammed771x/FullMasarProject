// ============================================================
// 👁️ ترتيبُ ما يراه الطالب — لا وجودُه فقط
// ============================================================
// 🔴 **ما رآه المالك (2026-09-10):** «\frac{ع-١}{ع+١}» خرجت «-١ع» فوق
//    «+١ع» — أي أن الإشارة والرقم قفزا إلى الجهة الخطأ.
//
// ⚖️ **ولماذا لم تكشفه اختباراتي؟** لأنها كانت تسأل «هل النصّ موجود؟»
//    و«ع» و«-١» موجودان فعلاً — ولكن **في الترتيب الخطأ**. فاختبارُ
//    الوجود يمرّ على عيبٍ بصريّ تام.
//
// ⭐ فهذه الاختبارات تقيس **الإحداثيّ الأفقيّ** لكل ذرّة: في العربية
//    يقع أوّلُ التعبير **يميناً** وآخرُه يساراً. وهو ما يجعل المعادلة
//    «نفس الكتاب» — طلب المالك.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/math_text.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// مركزُ ودجت النصّ الذي محتواه `s` على المحور الأفقي.
double _x(WidgetTester t, String s) =>
    t.getCenter(find.text(s)).dx;

/// يتحقّق أن الذرّات تقع **من اليمين إلى اليسار** بترتيب القراءة العربية.
void _expectRtlOrder(WidgetTester t, List<String> readingOrder) {
  for (var i = 0; i + 1 < readingOrder.length; i++) {
    final a = _x(t, readingOrder[i]);
    final b = _x(t, readingOrder[i + 1]);
    expect(a, greaterThan(b),
        reason: '«${readingOrder[i]}» يجب أن تقع يمينَ «${readingOrder[i + 1]}»');
  }
}

void main() {
  group('➖ الطرح الثنائي لا يُقرأ سالباً', () {
    testWidgets('⭐ «ع-١»: المعامل يبقى مع «ع» يمينَ الرقم', (t) async {
      // 🔴 قبل الإصلاح كانت المقاطع «ع» و«-١»، فتقفز الإشارة مع رقمها
      //    يساراً فيقرأ الطالب «-١ع». والآن «ع-» ثم «١» — أي ع − ١ يميناً.
      await t.pumpWidget(_wrap(const MathText('ع-١')));
      expect(find.text('ع-'), findsOneWidget,
          reason: 'الإشارة يجب أن تبقى مع المقدار الذي قبلها');
      expect(find.text('-١'), findsNothing,
          reason: 'لأنها ليست سالباً بل طرحاً');
      _expectRtlOrder(t, ['ع-', '١']);
    });

    testWidgets('⭐ والسالبُ الأحاديّ يقع عن **يمين** عدده', (t) async {
      // 🔴 قرار المالك (2026-09-11): «في اللغة العربية السالب يكون على
      //    يمين الرقم». وكان قبلها ملتصقاً يساره كالإنجليزية.
      //
      // ⚖️ والفحص بالبكسل لا بوجود النصّ: «-» و«٢» موجودتان في
      //    الحالتين، والخللُ في موضعهما ([math_visual_order] كلُّه).
      // ⚠️ الإشارةُ تُدمج مع ما قبلها في مقطعٍ عربيّ واحد («د(-»)، فلا
      //    يصحّ البحث عن «-» وحدها؛ الفحصُ على **موضع المقطع** الحامل لها.
      await t.pumpWidget(_wrap(const MathText('د(-٢) = ٥')));
      final sign = t.getCenter(find.textContaining('-')).dx;
      expect(sign, greaterThan(t.getCenter(find.text('٢')).dx),
          reason: 'الإشارة عن يمين العدد');
    });

    testWidgets('⚖️ إلا إذا كان العددُ السالب وحده — فتبقى يساره', (t) async {
      // «بس لما يكون individually خلّيه على يسار الرقم».
      await t.pumpWidget(_wrap(const MathText('-٢')));
      expect(find.text('-٢'), findsOneWidget);
    });

    testWidgets('⭐⭐ وداخلَ صندوقٍ لا يكون العددُ «وحده» — الأُسّ',
        (t) async {
      // 🔴 **طلبُ المالك (2026-09-12):** «الأس يطلع السالب في اليسار،
      //    خله في اليمين بدله».
      //
      // ⚖️ والعلّةُ في **معنى «وحده»**: كان الفحصُ على نصّ الصندوق، و
      //    «-١٩» يملأ صندوقَ الأُسّ فعلاً — لكنه **جزءٌ من مقدار** لا
      //    مقدارٌ قائمٌ بنفسه، فالاستثناءُ لم يكن له أصلاً.
      await t.pumpWidget(_wrap(const MathText(r'١٠\sup{-١٩}')));
      _expectRtlOrder(t, ['-', '١٩']);
    });

    testWidgets('⭐⭐ وفي البسط والمقام كذلك', (t) async {
      // 🔴 «وبرضه لو كان في المقام يطلع السالب في اليسار — خله في اليمين».
      await t.pumpWidget(_wrap(const MathText(r'\frac{-١٣.٦}{٤}')));
      _expectRtlOrder(t, ['-', '١٣.٦']);
      await t.pumpWidget(_wrap(const MathText(r'\frac{١}{-٤}')));
      _expectRtlOrder(t, ['-', '٤']);
    });

    testWidgets('⭐ وتحت الجذر', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\sqrt{-٣}')));
      _expectRtlOrder(t, ['√', '-', '٣']);
    });

    testWidgets('«ب - ٢أ» طرحٌ بين مقدارين بمسافات', (t) async {
      await t.pumpWidget(_wrap(const MathText('ب - ٢أ')));
      _expectRtlOrder(t, ['ب', '-', '٢']);
    });
  });

  group('🔢 ترتيب المعادلة كاملاً', () {
    testWidgets('«ع² + ٤ = ٠» يُقرأ من اليمين', (t) async {
      await t.pumpWidget(_wrap(const MathText('ع² + ٤ = ٠')));
      _expectRtlOrder(t, ['ع²', '+', '٤', '=', '٠']);
    });

    testWidgets('والكسر يقع في موضعه بين طرفَي المعادلة', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'أ = \frac{ب}{جـ} + د')));
      _expectRtlOrder(t, ['أ', '=']);
      // «د» آخرُ التعبير فتقع أقصى اليسار
      expect(_x(t, 'د'), lessThan(_x(t, '=')));
    });
  });

  group('√ الجذر في موضعه', () {
    testWidgets('العلامة يمينَ مقدارها كما في الكتاب العربي', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\sqrt{٣}')));
      expect(_x(t, '√'), greaterThan(_x(t, '٣')));
    });
  });
}
