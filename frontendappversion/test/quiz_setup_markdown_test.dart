// ══════════════════════════════════════════════════
// ✳️ لا نجمتَي توكيدٍ خامّتين على شاشة الطالب
// ══════════════════════════════════════════════════
//
// 🔴 **ما رُصد في المحاكي (2026-09-13):** بطاقةُ تمهيد «اختبر نفسك» تعرض
//    «أسئلة **من الدرس نفسه**» — بالنجمتين. النصُّ من عندنا لا من الموديل،
//    وكان في `Text` عادي لا في محلّل markdown.
//
// ⚖️ والقاعدة: النصُّ الثابت يُكتب توكيدُه توكيداً (`FontWeight`)، ونصُّ
//    الموديل يمرّ بـ`MasarMarkdown`. أما `**` داخل `Text` فعطلٌ في الحالين.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('🔍 لا `**` في نصوصٍ تُعرض بـText عادي', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // المحلّلُ نفسه ومصانعُ نصوص المحادثة مستثناة: ما يمرّ بها يُرسم.
      if (file.path.contains('core/widgets/') ||
          file.path.contains('core/error/') ||
          file.path.contains('data/repositories/') ||
          // 📚 دليلُ الاستخدام يُرسم بـ`MasarMarkdown` كاملاً
          //    (`_GuideBody` في `instructions_dialog`)، فالتوكيدُ فيه
          //    يُرسم توكيداً. والقاعدةُ «لا `**` في `Text` عاديّ» قائمةٌ
          //    على ما يُرسم لا على ما يُكتب.
          file.path.contains('features/instructions/data/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;   // تعليق لا نصّ
        if (!RegExp(r'"[^"]*\*\*').hasMatch(line)) continue;
        if (line.contains('replaceAll')) continue;        // يُنظّف لا يعرض
        offenders.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'ترميزُ توكيدٍ خامّ قد يصل الشاشة:\n${offenders.join("\n")}');
  });

  testWidgets('🖌️ والتوكيد في بطاقة «اختبر نفسك» ثخانةٌ لا نجمتان',
      (tester) async {
    // نتأكّد أن `Text.rich` يعطي النصّ متّصلاً بلا نجوم — وهو ما يقرؤه الطالب.
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: "اختر دروسك وسأجهّز لك أسئلة "),
          TextSpan(text: "من الدرس نفسه",
              style: TextStyle(fontWeight: FontWeight.w900)),
          TextSpan(text: " — سهلة ثم أصعب."),
        ])),
      ),
    ));
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('من الدرس نفسه'), findsOneWidget);
  });
}
