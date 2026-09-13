// ♿ تكبير الخط — الشاشات لا تنهار عند 1.5× و2.0×
//
// 🔴 **لماذا هذا اختبارٌ لا رفاهية:**
//    • مراجعة المتاجر تفحصه (Google Play Accessibility · Apple).
//    • وطلابٌ كثيرون يرفعون خطّ النظام لضعف نظرٍ أو لشاشةٍ صغيرة.
//    • و`RenderFlex overflowed` في فلاتر **ليس تحذيراً تجميلياً**: يرسم
//      الشريط الأصفر والأسود فوق الواجهة ويجعلها تبدو معطوبة تماماً.
//
// ⚠️ ويُفحص بـ`TextScaler` لا `textScaleFactor` المهجورة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/quota/quota_repository.dart';
import 'package:ye_student_tutor/core/version/version_gate.dart';
import 'package:ye_student_tutor/core/widgets/quota_badge.dart';
import 'package:ye_student_tutor/features/onboarding/presentation/force_update_screen.dart';

/// يبني شاشةً بمقياس خطٍّ محدّد وحجم جهازٍ صغير — أسوأ اجتماعٍ ممكن.
Widget _scaled(Widget child, double scale) => MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(scale),
        size: const Size(360, 640),   // جهازٌ صغير شائع في اليمن
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(home: child),
      ),
    );

/// يفشل إن رسم أيُّ عنصرٍ خارج حدوده (شريط الفيض الأصفر/الأسود).
void _expectNoOverflow(WidgetTester tester) {
  final errors = tester.takeException();
  expect(errors, isNull, reason: "تجاوزت الواجهة حدودها عند تكبير الخط");
}

void main() {
  group('♿ شاشة التحديث الإلزامي', () {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('تصمد عند ${scale}x', (tester) async {
        await tester.pumpWidget(_scaled(
          const ForceUpdateScreen(
            verdict: VersionVerdict(
              updateRequired: true,
              message: "صدر تحديثٌ مهم لمسار — حدّث التطبيق لتتابع بلا مشاكل "
                  "وبلا انقطاع في محادثاتك أو اختباراتك.",
              storeUrl: "https://example.test",
            ),
          ),
          scale,
        ));
        await tester.pumpAndSettle();

        _expectNoOverflow(tester);
        expect(find.text("تحديثٌ مطلوب"), findsOneWidget);
        expect(find.text("حدّث الآن"), findsOneWidget);
      });
    }

    testWidgets('🚧 لا يمكن تخطّيها بزرّ الرجوع', (tester) async {
      await tester.pumpWidget(
          _scaled(const ForceUpdateScreen(verdict: VersionVerdict.none), 1.0));
      await tester.pumpAndSettle();

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('رسالةٌ فارغة من اللوحة ⇒ نصٌّ افتراضي لا شاشة عمياء',
        (tester) async {
      await tester.pumpWidget(
          _scaled(const ForceUpdateScreen(verdict: VersionVerdict.none), 1.0));
      await tester.pumpAndSettle();
      expect(find.textContaining("حدّث التطبيق"), findsOneWidget);
    });
  });

  group('♿ شارة الحصة', () {
    setUp(() => QuotaRepository.I.clear());

    testWidgets('👻 تختفي تماماً قبل وصول أول قراءة', (tester) async {
      // صفرٌ مؤقّتٌ أسوأ من لا شيء: يظنّ الطالب حصته انتهت وهي لم تُقرأ بعد.
      await tester.pumpWidget(_scaled(
          const Scaffold(body: Center(child: QuotaBadge())), 1.0));
      await tester.pumpAndSettle();
      expect(find.byType(Text), findsNothing);
    });

    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('تصمد داخل شريطٍ ضيّق عند ${scale}x', (tester) async {
        QuotaRepository.I.status = const QuotaStatus(
            limit: 50, used: 33, remaining: 17,
            isGuest: false, resetsDaily: true);

        await tester.pumpWidget(_scaled(
          const Scaffold(
            // شريطٌ ضيّق عمداً: هنا يقع الفيض إن كان سيقع.
            body: SizedBox(height: 40, child: Row(children: [QuotaBadge(compact: true)])),
          ),
          scale,
        ));
        await tester.pumpAndSettle();
        _expectNoOverflow(tester);
        expect(find.text("17"), findsOneWidget);
      });
    }

    testWidgets('♿ تحمل وصفاً مقروءاً لقارئ الشاشة لا رقماً عائماً',
        (tester) async {
      // ⚠️ شجرة الدلالات لا تُبنى في الاختبارات إلا بطلبٍ صريح — وتُغلق
      //    **داخل** الاختبار لا في `addTearDown`: التحقق من إغلاقها يسبق
      //    التنظيف، فيسقط الاختبار على «SemanticsHandle نشط» لا على منطقه.
      final semantics = tester.ensureSemantics();
      QuotaRepository.I.status = const QuotaStatus(
          limit: 50, used: 33, remaining: 17, isGuest: false, resetsDaily: true);

      await tester.pumpWidget(_scaled(
          const Scaffold(body: Center(child: QuotaBadge())), 1.0));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel("متبقٍّ 17 من 50 أسئلة"), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('النفاد يقول «انتهت أسئلتك» لا رقماً', (tester) async {
      final semantics = tester.ensureSemantics();
      QuotaRepository.I.status = const QuotaStatus(
          limit: 50, used: 50, remaining: 0, isGuest: false, resetsDaily: true);

      await tester.pumpWidget(_scaled(
          const Scaffold(body: Center(child: QuotaBadge())), 1.0));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel("انتهت أسئلتك"), findsOneWidget);
      semantics.dispose();
    });
  });
}
