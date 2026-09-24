// 🔑 شاشتا الدخول وإنشاء الحساب — **مقاسات الملف لا التقدير**.
//
// 🔴 **ملاحظةُ المالك (٢٠٢٦-٠٩-٢٢):** «شوف التصميم عندك، خله نفسه بالضبط…
//    شوف فوق الروبوت كيف كبير، شوف تحت كيف الخانات… كلها مكدّسة في النص».
//
// 📐 وما يحرسه هذا الملف هو **الأرقام التي أُخذت من تصدير Figma بدقّة ٢×**:
//    ارتفاعُ الحقل الذي كان يتبدّل بحسب وجود أيقونةٍ فيه، وعرضُ الروبوت،
//    والأنصاف أقطار، وموضعُ زرّ إظهار كلمة المرور، وألّا يسقط زرٌّ.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/core/widgets/masar_brand.dart';
import 'package:ye_student_tutor/core/widgets/phosphor.dart';
import 'package:ye_student_tutor/features/auth/presentation/widgets/auth_kit.dart';

/// لوح المصمّم نفسه — 390×844 (iPhone 14).
void _figmaBoard(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  addTearDown(tester.view.reset);
}

/// ⚠️ **الاتجاه داخل `MaterialApp` لا حولها**: هي تبني `Directionality`
///    خاصّتَها من اللغة (إنجليزية افتراضاً) فتُلغي أيَّ اتجاهٍ فوقها —
///    فتُقاس الشاشةُ مقلوبةً وتسقط اختباراتُ اليمين واليسار بلا ذنب.
Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );

void main() {
  // ══════════════════════════════════════════════════
  // 📏 الحقل — 42 مهما كان بداخله
  // ══════════════════════════════════════════════════
  group('📏 صندوق الحقل', () {
    testWidgets('☢️ ارتفاعه واحدٌ بالضبط، بأيقونةٍ وبغيرها', (tester) async {
      _figmaBoard(tester);
      final a = TextEditingController(), b = TextEditingController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await tester.pumpWidget(_host(Scaffold(
        body: Column(children: [
          AuthField(label: "البريد الإلكتروني", controller: a),
          AuthField(label: "كلمة المرور", controller: b, obscure: true),
        ]),
      )));

      // 🔴 **العطل الذي يمنعه:** `InputDecorator` يقيس بمحتواه، فخرج الحقلُ
      //    العاري 43 وحقلُ كلمة المرور **48** — صندوقان بارتفاعين في شاشةٍ
      //    واحدة، والملف يعطيهما مقاساً واحداً.
      expect(find.byType(TextField), findsNWidgets(2));
      // 🔑 **بالمفتاح لا بالنوع:** صار تحت الحقل شريطُ قوّةٍ ورسالةُ خطأٍ
      //    لكلٍّ منهما `Container`اتُه، فعدُّ الأنواع يلتقطها معه.
      final boxes = find.byKey(AuthField.boxKey);
      expect(boxes, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        expect(tester.getSize(boxes.at(i)).height, AuthMetrics.fieldHeight);
      }
    });

    testWidgets('وزرّ الإظهار أيقونةُ Phosphor في **نهاية** السطر',
        (tester) async {
      _figmaBoard(tester);
      final c = TextEditingController();
      addTearDown(c.dispose);
      // ⚠️ `ltr: true` كحقل كلمة المرور في الشاشتين — وهو ما كان يقلبها.
      await tester.pumpWidget(_host(Scaffold(
        body: AuthField(
            label: "كلمة المرور", controller: c, obscure: true, ltr: true),
      )));

      final icon = tester.widget<Icon>(find.byType(Icon));
      // ⑤ Phosphor حصراً — لا `Icons.visibility_outlined`.
      expect(icon.icon, PI.eye.regular);

      // ⚠️ RTL: النهاية يسار. وفي الملف العينُ على يسار الصندوق والنجماتُ
      //    على يمينه — وكانت عندنا معكوسة.
      final field = tester.getRect(find.byType(TextField));
      final eye = tester.getRect(find.byType(Icon));
      expect(eye.center.dx, lessThan(field.center.dx),
          reason: 'العين يجب أن تكون في يسار الحقل كما في التصميم');
    });

    testWidgets('يقبل النقر على العين فيتبدّل الإخفاء', (tester) async {
      _figmaBoard(tester);
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(Scaffold(
        body: AuthField(label: "كلمة المرور", controller: c, obscure: true),
      )));
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue);
      await tester.tap(find.byType(Icon));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText,
          isFalse);
      expect(tester.widget<Icon>(find.byType(Icon)).icon, PI.eyeSlash.regular);
    });
  });

  // ══════════════════════════════════════════════════
  // 🎛️ الأزرار والأنصاف أقطار
  // ══════════════════════════════════════════════════
  group('🎛️ مقاسات الملف', () {
    // 🔵 **الأرقام تبدّلت ٢٠٢٦-٠٩-٢٣ بقرار المالك** («كبّر الحقول شوي»)،
    //    فما يحرسه هذا الاختبار صار **القرار** لا رقمَ الملف. والقاعدةُ
    //    التي لا تُنقض: **لا هدفَ لمسٍ تحت 44** — حدُّ أبل، وهو سببُ
    //    التكبير أصلاً. فلو أعادها أحدٌ إلى 42 ظنّاً أنه «يطابق Figma»
    //    سقط الاختبار وقرأ السبب.
    test('☢️ الأرقام قرارُ المالك — ولا هدفَ لمسٍ تحت 44', () {
      expect(AuthMetrics.gutter, 24);
      expect(AuthMetrics.topGap, 30);
      expect(AuthMetrics.fieldHeight, 48);
      expect(AuthMetrics.fieldRadius, 12);
      expect(AuthMetrics.buttonHeight, 50);
      expect(AuthMetrics.buttonRadius, 14);
      expect(AuthMetrics.secondaryHeight, 46);
      expect(AuthMetrics.backSize, 40);

      // ☢️ القاعدةُ الحاكمة — كلُّ ما يُلمس ≥ 44.
      for (final (name, h) in [
        ('الحقل', AuthMetrics.fieldHeight),
        ('الزرّ الأساسي', AuthMetrics.buttonHeight),
        ('الزرّ الثانوي', AuthMetrics.secondaryHeight),
      ]) {
        expect(h, greaterThanOrEqualTo(44),
            reason: '$name هدفُ لمسٍ — لا ينزل تحت 44 مهما قال الملف');
      }

      // والفجوةُ بين حقلين تفصلهما فعلاً (كانت 7 فبدَوا كتلةً واحدة).
      expect(AuthMetrics.fieldGap, greaterThanOrEqualTo(12));
      expect(AuthMetrics.fieldGap, lessThanOrEqualTo(16),
          reason: 'ولا تتباعد حتى يصير الحقلان شاشتين');
    });

    testWidgets('الزرّ الأساسي والثانوي بارتفاعَيهما المعلنَين', (tester) async {
      _figmaBoard(tester);
      await tester.pumpWidget(_host(Scaffold(
        body: Column(children: [
          AuthPrimaryButton(label: "تسجيل الدخول", onTap: () {}),
          AuthOutlineButton(label: "المتابعة بحساب جوجل", onTap: () {}),
        ]),
      )));
      expect(tester.getSize(find.byType(ElevatedButton)).height,
          AuthMetrics.buttonHeight);
      expect(
          tester
              .getSize(find.descendant(
                  of: find.byType(AuthOutlineButton),
                  matching: find.byType(Container)))
              .height,
          AuthMetrics.secondaryHeight);
    });
  });

  // ══════════════════════════════════════════════════
  // 🫱 الفجوة المرنة — لا فراغَ ميّتاً أسفل الشاشة
  // ══════════════════════════════════════════════════
  testWidgets('🫱 ما زاد من طول الجهاز يُوزَّع على الفجوات لا يتراكم أسفل',
      (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 900 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(Scaffold(
      body: SizedBox(
        height: 600,
        child: AuthBody(children: [
          const AuthSlack(20),
          Container(height: 100, color: AppColors.primary),
          const AuthSlack(20),
          Container(height: 100, color: AppColors.primary),
        ]),
      ),
    )));

    final boxes = find.byType(Container);
    final first = tester.getRect(boxes.at(0));
    final second = tester.getRect(boxes.at(1));
    // 600 = 20+100+20+100 + فائضٌ 360 يُقسم على فجوتين ⇒ 180 لكلٍّ منهما.
    expect(first.top, closeTo(200, 0.5));
    expect(second.top - first.bottom, closeTo(200, 0.5));
  });

  testWidgets('وحين يضيق الطول تعود الفجوة إلى مقاسها في الملف ثم يمرّر',
      (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(402 * 3, 900 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(Scaffold(
      body: SizedBox(
        height: 150, // أقصرُ من المحتوى
        child: AuthBody(children: [
          const AuthSlack(20),
          Container(height: 100, color: AppColors.primary),
          const AuthSlack(20),
          Container(height: 100, color: AppColors.primary),
        ]),
      ),
    )));
    final first = tester.getRect(find.byType(Container).at(0));
    expect(first.top, closeTo(20, 0.5), reason: 'الفجوة لا تنزل تحت مقاس الملف');
  });

  // ══════════════════════════════════════════════════
  // 🔗 الرابط المضغوط داخل صفّ
  // ══════════════════════════════════════════════════
  testWidgets('🔗 رابطٌ مضغوط في `Row` لا يتمدّد إلى ما لا نهاية',
      (tester) async {
    _figmaBoard(tester);
    // 🔴 وقع فعلاً: `OverflowBox` تأخذ `constraints.biggest`، وعرضُ الصفّ
    //    غير محدود ⇒ «OVERFLOWED BY Infinity PIXELS» أسفل إنشاء الحساب.
    await tester.pumpWidget(_host(Scaffold(
      body: SizedBox(
        width: 354, // عرضُ المحتوى في الشاشة
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⚠️ نصٌّ قصير: خطُّ الاختبار (Ahem) يجعل كلَّ حرفٍ مربّعاً
            //    بمقاس الخطّ، فالنصُّ الطويل يفيض بلا ذنبٍ للودجت.
            const Text("لديك؟", style: TextStyle(fontSize: 12)),
            AuthLink(label: "دخول", fontSize: 12, dense: true, onTap: () {}),
          ],
        ),
      ),
    )));
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(AuthLink));
    // ٤ حروفٍ × 12 = 48 بلا حشوةٍ أفقية — لا عرضُ الصفّ (354) ولا ما لا نهاية.
    expect(size.width, closeTo(48, 2), reason: 'يلزم عرضَ نصّه لا عرضَ الصفّ');
    // ☢️ **ويبلغ حدَّ اللمس**: كان ≈30 بمقايضةٍ معلنة، فأخطأته ثلاثُ
    //    نقراتٍ في المحاكي على «نسيت كلمة المرور؟» — والرابطُ يُقصد حين
    //    لا يستطيع الطالب الدخول أصلاً. صار ≈43 من فراغٍ كان مهدوراً.
    expect(size.height, greaterThanOrEqualTo(42));
    expect(size.height, lessThan(48), reason: 'ولا يبتلع سطرَ ما تحته');
  });

  testWidgets('وفي `Align` يلزم جهتَه ولا يتوسّط', (tester) async {
    _figmaBoard(tester);
    // 🔴 وقع فعلاً: «نسيت كلمة المرور؟» ظهرت **وسط** الشاشة بدل يمينها.
    await tester.pumpWidget(_host(Scaffold(
      body: SizedBox(
        width: 354,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthLink(
              label: "نسيت؟", fontSize: 12, dense: true, onTap: () {}),
        ),
      ),
    )));
    final r = tester.getRect(find.byType(AuthLink));
    expect(r.right, closeTo(354, 1), reason: 'RTL: البداية هي اليمين');
    expect(r.width, lessThan(140), reason: 'لا يتمدّد على عرض الشاشة');
  });

  // ══════════════════════════════════════════════════
  // 🤖 الروبوت — عرضُه من الملف
  // ══════════════════════════════════════════════════
  testWidgets('🤖 الروبوت 132 في شاشة الدخول (كان 120)', (tester) async {
    _figmaBoard(tester);
    await tester.pumpWidget(_host(const Scaffold(
      body: Center(child: MasarRobot(size: 132, pose: MasarRobotPose.fly)),
    )));
    expect(tester.getSize(find.byType(Image)).width, 132);
  });

  // 🔴 الفخّ الذي دفع نصفَ الشاشة خارجها: `Image` بعرضٍ فقط تُبلّغ
  //    ارتفاعاً جوهرياً محسوباً على **أقصى عرضٍ متاح**.
  testWidgets('☢️ وارتفاعُه الجوهريّ ارتفاعُه هو لا ارتفاعُ الشاشة',
      (tester) async {
    _figmaBoard(tester);
    await tester.pumpWidget(_host(const Scaffold(
      body: SizedBox(width: 354, child: AuthRobot(132)),
    )));
    final h = tester.getSize(find.byType(AuthRobot)).height;
    expect(h, closeTo(132 * 400 / 512, 0.01));
    // وهو ما تقرأه [AuthBody] حين توزّع الفائض.
    final box = tester.renderObject<RenderBox>(find.byType(AuthRobot));
    expect(box.getMaxIntrinsicHeight(354), closeTo(h, 0.01));
  });
}
