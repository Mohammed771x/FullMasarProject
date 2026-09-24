// 🚦 **حالاتُ شاشتَي الدخول والتسجيل** — جولة ٢٠٢٦-٠٩-٢٣.
//
// 🔴 **ملاحظةُ المالك:** «ما يعجبني إنه يطلع كلام [في وسط الشاشة]. البريد
//    الإلكتروني خطأ ⇒ الحقلُ يحمرّ ويظهر تحته الكلام… ولما يكتب، تقعة
//    برتقالية، بعدها تقعة خضراء… وشعارُ جوجل سيئة جداً، وخلّه في اليسار».
//
// وما يحرسه هذا الملف ثلاثةٌ لا يُرى عطلُها إلا في اليد:
//   ① الرسالةُ **تحت حقلها**، ولا تظهر حيث لا نصّ (حمرةُ «البيانات خاطئة»).
//   ② **سياسةُ كلمة المرور** — وهي أمانٌ لا شكل: ٨ أحرف، ولا شائعَ، ولا
//      مشتقَّ من البريد.
//   ③ **الشعارُ يسارَ النصّ** ومساره مقروءٌ فعلاً لا مقدَّر.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/auth/auth_repository.dart';
import 'package:ye_student_tutor/core/auth/auth_validators.dart';
import 'package:ye_student_tutor/core/auth/password_strength.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/features/auth/presentation/widgets/auth_kit.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

/// لونُ حدّ الصندوق المرسوم — الطريقُ الوحيد للتأكد أنه احمرّ فعلاً.
Color _borderOf(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(find.byKey(AuthField.boxKey));
  final dec = box.decoration! as BoxDecoration;
  return dec.border!.top.color;
}

void main() {
  // ══════════════════════════════════════════════════
  // ① الرسالة تحت حقلها
  // ══════════════════════════════════════════════════
  group('🚦 حالاتُ الحقل', () {
    testWidgets('☢️ خطأٌ برسالة ⇒ إطارٌ أحمر ونصٌّ تحته', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(AuthField(
        label: "البريد الإلكتروني",
        controller: c,
        errorText: "تحقّق من صيغة البريد الإلكتروني",
      )));

      expect(find.text("تحقّق من صيغة البريد الإلكتروني"), findsOneWidget);
      expect(_borderOf(tester), AppColors.fieldErrorBorder);
    });

    // 🔴 **الفخّ الذي أسقط النسخة الأولى:** `_hasError` كانت تشمل
    //    [AuthField.invalid]، والرسالةُ تُبنى بـ`errorText!` — فحقلٌ
    //    محمَّرٌ بلا نصّ كان **يرمي** عند أول بناء.
    testWidgets('☢️ حمرةٌ بلا رسالة ⇒ إطارٌ أحمر ولا نصَّ ولا رمي',
        (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(AuthField(
        label: "كلمة المرور",
        controller: c,
        obscure: true,
        invalid: true,
      )));

      expect(tester.takeException(), isNull);
      expect(_borderOf(tester), AppColors.fieldErrorBorder);
      // لا شيء تحت الحقل سوى عنوانه — ولا رسالةَ تنسب الخطأ إليه.
      expect(find.byIcon(PIcons.warningFill), findsNothing);
    });

    testWidgets('والخطأُ يُخفي سطرَ الإرشاد فلا يزدحم سطران', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(AuthField(
        label: "كلمة المرور",
        controller: c,
        helper: "٨ أحرف على الأقل",
        errorText: "كلمة المرور ٨ أحرف على الأقل",
      )));
      expect(find.text("٨ أحرف على الأقل"), findsNothing);
      expect(find.text("كلمة المرور ٨ أحرف على الأقل"), findsOneWidget);
    });

    testWidgets('✅ الصحّةُ إطارٌ أخضر — بلا تعبئةٍ صارخة', (tester) async {
      final c = TextEditingController(text: 'a@b.com');
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(
          AuthField(label: "البريد", controller: c, ok: true)));
      expect(_borderOf(tester), AppColors.fieldOkBorder);
      final box = tester.widget<AnimatedContainer>(find.byKey(AuthField.boxKey));
      expect((box.decoration! as BoxDecoration).color, AppColors.fieldFill);
    });
  });

  // ══════════════════════════════════════════════════
  // ② شريطُ القوّة — ثلاثُ تقعات
  // ══════════════════════════════════════════════════
  group('🔋 شريط قوّة كلمة المرور', () {
    testWidgets('تقعةٌ واحدةٌ للضعيفة وثلاثٌ للقوية', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);

      Future<int> filledFor(String pass) async {
        final s = PasswordStrength.of(pass);
        await tester.pumpWidget(_host(
            AuthField(label: "كلمة المرور", controller: c, strength: s)));
        await tester.pumpAndSettle();
        return s.filled;
      }

      expect(await filledFor('abc'), 1); // قصيرة
      expect(await filledFor('ahmedsalim'), 2); // مقبولة بسيطة
      expect(await filledFor('Ahmed!Salim2026'), 3); // قوية
    });

    testWidgets('ولا شريطَ على حقلٍ فارغ', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(AuthField(
        label: "كلمة المرور",
        controller: c,
        strength: PasswordStrength.of(''),
      )));
      expect(find.text('قصيرة'), findsNothing);
      expect(find.text('قوية'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════
  // ③ السياسة — أمانٌ لا شكل
  // ══════════════════════════════════════════════════
  group('🔒 سياسة كلمة المرور', () {
    test('☢️ الحدُّ الأدنى ٨ — و٧ تُرفض', () {
      expect(PasswordStrength.minLength, 8);
      expect(PasswordStrength.of('kitab12').accepted, isFalse);
      expect(PasswordStrength.of('kitab123').accepted, isTrue);
      // ⚠️ و`abcd1234` **ليست** مثالاً للقبول: هي في قائمة الشائع.
      expect(PasswordStrength.of('abcd1234').accepted, isFalse);
    });

    test('☢️ الشائعُ يُرفض مهما طال', () {
      for (final p in ['12345678', 'password', 'qwerty123', 'iloveyou']) {
        expect(PasswordStrength.of(p).accepted, isFalse, reason: p);
      }
    });

    test('☢️ المكرَّرُ والمتتالي يُرفضان', () {
      expect(PasswordStrength.of('aaaaaaaa').accepted, isFalse);
      expect(PasswordStrength.of('abcdefgh').accepted, isFalse);
      expect(PasswordStrength.of('87654321').accepted, isFalse);
    });

    test('☢️ المشتقُّ من البريد أو الاسم يُرفض', () {
      expect(
          PasswordStrength.of('ahmed12345', email: 'ahmed@masar.ye').accepted,
          isFalse);
      expect(PasswordStrength.of('salim9988', name: 'سالم Salim').accepted,
          isFalse);
      // وبريدٌ لا علاقة له لا يمنع.
      expect(PasswordStrength.of('kitab9988', email: 'ahmed@masar.ye').accepted,
          isTrue);
    });

    test('الدرجةُ تصعد بالتنوّع لا بالطول وحده', () {
      expect(PasswordStrength.of('kitabuna').level, PasswordLevel.fair);
      expect(PasswordStrength.of('Kitab#2026').level, PasswordLevel.strong);
    });
  });

  // ══════════════════════════════════════════════════
  // ④ فاحصُ الحقول — قاعدةٌ واحدة لكل شاشة
  // ══════════════════════════════════════════════════
  group('✅ AuthValidators', () {
    test('☢️ `a@b.` كانت تمرّ من الشاشة وترفضها الجلسة بعد ٣ خطوات', () {
      expect(AuthValidators.email('a@b.'), isNotNull);
      expect(AuthValidators.email('ahmed@masar.ye'), isNull);
      expect(AuthValidators.email(''), 'اكتب بريدك الإلكتروني');
      expect(AuthValidators.email('a b@c.com'), isNotNull);
    });

    test('الاسمُ ≤ 60 — وهو سقفُ `validProfile` في قواعد Firestore', () {
      expect(AuthValidators.name('أ'), isNotNull);
      expect(AuthValidators.name('أحمد سالم'), isNull);
      expect(AuthValidators.name('م' * 61), isNotNull);
    });

    test('التأكيدُ يطابق', () {
      expect(AuthValidators.confirm('abcd1234', 'abcd1234'), isNull);
      expect(AuthValidators.confirm('abcd1234', 'abcd12345'), isNotNull);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑤ 🛡️ لا إحصاءَ حسابات — رسالةٌ واحدة لثلاثة أكواد
  // ══════════════════════════════════════════════════
  group('🛡️ رسائل الدخول لا تفشي وجودَ الحساب', () {
    test('☢️ الأكواد الثلاثة ترجع الرسالة نفسها حرفاً', () {
      // 🔴 **ما يمنعه هذا الاختبار:** أن يفصّلها أحدٌ يوماً بنيّة «رسائل
      //    أوضح» — فيصير التطبيق أداةَ جمعِ قائمةِ مستخدمين: من ردّت عليه
      //    «كلمة المرور خاطئة» فبريدُه مسجَّلٌ عندنا.
      final messages = {
        for (final c in ['user-not-found', 'wrong-password', 'invalid-credential'])
          AuthRepository.messageForCode(c),
      };
      expect(messages.length, 1, reason: 'رسالةٌ واحدة لا ثلاث');
      expect(messages.single, AuthRepository.genericCredentialError);
    });

    test('ولا تذكر أيَّ الحقلين', () {
      final m = AuthRepository.genericCredentialError;
      expect(m.contains('غير مسجّل'), isFalse);
      expect(m.contains('لا يوجد'), isFalse);
      // «أو» هي ما يجعلها غامضة — وغموضُها هو الحماية.
      expect(m.contains('أو'), isTrue);
    });

    test('وما يخصّ حقلاً بعينه يبقى مفصّلاً', () {
      expect(AuthRepository.messageForCode('invalid-email'),
          isNot(AuthRepository.genericCredentialError));
      expect(AuthRepository.messageForCode('network-request-failed'),
          isNot(AuthRepository.genericCredentialError));
    });
  });

  // ══════════════════════════════════════════════════
  // ⑥ شعار جوجل — مسارٌ مقروءٌ ويسارَ النصّ
  // ══════════════════════════════════════════════════
  group('🇬 شعار جوجل', () {
    test('☢️ المسارُ يُقرأ ويملأ لوحَ 48 — لا شكلاً منكمشاً', () {
      // 🔴 قارئٌ صامتٌ يعيد `Path` فارغة يرسم **لا شيء**، والزرُّ يبدو
      //    سليماً في الشجرة. فالحدودُ هي البرهان.
      final p = SvgPathParser.parse(
          'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
          '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z');
      final b = p.getBounds();
      expect(b.width, greaterThan(30));
      expect(b.height, greaterThan(15));
      expect(b.right, lessThanOrEqualTo(48.5));
    });

    test('وأمرٌ غير مدعوم يُرمى ولا يُتجاهل صامتاً', () {
      expect(() => SvgPathParser.parse('M0 0A10 10 0 0 1 20 20'),
          throwsA(isA<FormatException>()));
    });

    testWidgets('☢️ الأيقونةُ يسارَ النصّ في واجهةٍ عربية', (tester) async {
      // 🔴 كانت [leading] أوّلَ ابنٍ في `Row`، وأوّلُ ابنٍ في RTL **يمين**.
      await tester.pumpWidget(_host(AuthOutlineButton(
        label: "المتابعة بحساب جوجل",
        leading: const GoogleGlyph(),
        onTap: () {},
      )));
      final glyph = tester.getRect(find.byType(GoogleGlyph));
      final text = tester.getRect(find.text("المتابعة بحساب جوجل"));
      expect(glyph.center.dx, lessThan(text.center.dx),
          reason: 'شعارُ جوجل يسارَ النصّ في كل اللغات — إرشاداتُ جوجل');
    });
  });

  // ══════════════════════════════════════════════════
  // ⑦ شريطُ الخطأ غير المنسوب
  // ══════════════════════════════════════════════════
  testWidgets('📣 AuthAlert يعرض رسالتَه ويُغلق', (tester) async {
    var closed = false;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => closed
          ? const SizedBox()
          : AuthAlert(
              message: "البريد أو كلمة المرور غير صحيحة.",
              onClose: () => setState(() => closed = true),
            ),
    )));
    expect(find.text("البريد أو كلمة المرور غير صحيحة."), findsOneWidget);
    await tester.tap(find.byType(Icon).last);
    await tester.pump();
    expect(find.text("البريد أو كلمة المرور غير صحيحة."), findsNothing);
  });
}

/// أيقوناتٌ يُبحث عنها بالاسم في الاختبار وحده.
class PIcons {
  static const warningFill = IconData(0xe4e2, fontFamily: 'PhosphorFill');
}
