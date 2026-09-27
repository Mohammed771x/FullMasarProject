import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_character.dart';

// 🤖 الشخصيات الحيّة في شاشة الترحيب: تُبنى بكل أنواعها، تُلمس، وتُنزع
//    دون مؤقّتٍ معلّق — و«تقليل الحركة» يعيدها صورةً ساكنة.
Widget _host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Center(child: SizedBox(width: 340, height: 380, child: child)),
  ),
);

void main() {
  for (final c in MasarCharacter.values) {
    testWidgets('${c.name}: يحوم ويرمش ويقفز ثم يُنزع بلا مؤقّتٍ معلّق', (
      tester,
    ) async {
      await tester.pumpWidget(_host(MasarCharacterView(character: c)));
      await tester.pump(const Duration(milliseconds: 1200)); // الدخول
      expect(find.byType(Image), findsNWidgets(2)); // الصورة + رقعة الرمش

      // 📐 رقعةُ الرمش داخل حدود الصورة دائماً.
      expect(c.patch.left, greaterThanOrEqualTo(0));
      expect(c.patch.top, greaterThanOrEqualTo(0));
      expect(c.patch.right, lessThanOrEqualTo(c.pixels.width));
      expect(c.patch.bottom, lessThanOrEqualTo(c.pixels.height));

      await tester.tap(find.byType(MasarCharacterView));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(seconds: 6)); // رمشةٌ مجدولة على الأقل

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
    });
  }

  testWidgets('تقليل الحركة: صورةٌ ساكنة بلا لمسٍ ولا مؤقّتات', (tester) async {
    await tester.pumpWidget(
      _host(
        const MasarCharacterView(character: MasarCharacter.hello),
        still: true,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(MasarCharacterView),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  // 📐 أبعادُ كل ملفٍّ على القرص = ما يعلنه الـenum — وإلا انزاحت رقعةُ
  //    الرمش عن العينين بصمت حين تُستبدل صورة (وقع التبديل ٢٠٢٦-٠٩-٢٦).
  test('أبعادُ الصور ورقعِ الرمش تطابق الـenum', () async {
    Future<Size> sizeOf(String path) async {
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
      );
      final img = (await codec.getNextFrame()).image;
      return Size(img.width.toDouble(), img.height.toDouble());
    }

    for (final c in MasarCharacter.values) {
      expect(await sizeOf(c.asset), c.pixels, reason: c.asset);
      expect(await sizeOf(c.blinkAsset), c.patch.size, reason: c.blinkAsset);
    }
  });

  testWidgets('💬 الفقاعة تنبثق بعد الدخول لا قبله', (tester) async {
    await tester.pumpWidget(
      _host(
        const MasarCharacterView(character: MasarCharacter.hello, say: 'هلا!'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final early = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('هلا!'), matching: find.byType(Opacity))
          .first,
    );
    expect(early.opacity, 0);

    await tester.pump(const Duration(milliseconds: 1100)); // انتهى الدخول
    await tester.pump(const Duration(milliseconds: 700)); // انبثقت
    final late = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('هلا!'), matching: find.byType(Opacity))
          .first,
    );
    expect(late.opacity, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('💬 مع تقليل الحركة تظهر الفقاعة ساكنة', (tester) async {
    await tester.pumpWidget(
      _host(
        const MasarCharacterView(character: MasarCharacter.hello, say: 'هلا!'),
        still: true,
      ),
    );
    await tester.pump();
    expect(find.text('هلا!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('⏳ شريطُ الانتظار حيٌّ في `waiting` وحدها، ويمتلئ مع الزمن', (
    tester,
  ) async {
    bool hasBar(WidgetTester t) => t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((p) => p.painter.runtimeType.toString() == '_ProgressPainter');

    await tester.pumpWidget(
      _host(const MasarCharacterView(character: MasarCharacter.hello)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(hasBar(tester), isFalse);

    await tester.pumpWidget(
      _host(const MasarCharacterView(character: MasarCharacter.waiting)),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(hasBar(tester), isTrue);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });
}
