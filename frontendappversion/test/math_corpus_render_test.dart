// ============================================================
// 📐 ٩٨٤ سطراً رياضياً حقيقياً — من ملفّات المنهج، بعرض الجهاز
// ============================================================
// 🔴 **طلب المالك (2026-09-10):** «سوِّ اختبارات لكل شيء حرفياً… أبغى كل
//    شيء طبيعي نفس الكتب». وقبلها: «ما تشوف السيميوليتور كيف تطلع الأشياء؟»
//
// ⚖️ **ودرسٌ تعلّمتُه بالخطأ:** اختباراتي كانت تسأل «هل النصّ موجود؟» —
//    و«ع» و«-١» موجودان في «\frac{ع-١}{ع+١}» فعلاً، **لكن في الترتيب
//    الخطأ** («-١ع» على الشاشة). فاختبارُ الوجود يمرّ على عيبٍ بصريّ تامّ.
//    فهنا نفحص **البنية والترتيب** لا الوجود.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/math_text.dart';

const Size _phone = Size(402, 874);

/// مقدارٌ ثم إشارة ثم رقم = **طرحٌ ثنائي** لا عددٌ سالب.
final _binary = RegExp(r'[ء-ي0-9٠-٩)\]²³][-−+][0-9٠-٩]');

List<Map<String, dynamic>> _corpus() {
  final f = File('test/fixtures/math_lines.json');
  if (!f.existsSync()) return const [];
  return List<Map<String, dynamic>>.from(jsonDecode(f.readAsStringSync()));
}

void main() {
  final corpus = _corpus();

  test('🛡️ الحمولة مثبّتة', () {
    expect(corpus.length, greaterThan(900));
  });

  testWidgets('⭐ لا سطرَ يفيض ولا يعرض ترميزاً خاماً', (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final bad = <String>[];
    for (final row in corpus) {
      final line = '${row['line']}';
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MathText(line),
              ),
            ),
          ),
        ),
      ));
      final err = t.takeException();
      if (err != null && '$err'.contains('overflowed')) {
        bad.add('فيضان: ${row['branch']} · $line');
      }
      for (final m in [r'\frac', r'\sqrt', r'\chem']) {
        if (find.textContaining(m).evaluate().isNotEmpty) {
          bad.add('ترميز خام «$m»: $line');
        }
      }
    }
    expect(bad, isEmpty, reason: '${bad.length}:\n  ${bad.take(5).join('\n  ')}');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('⭐⭐ الطرح الثنائي لا يُقرأ عدداً سالباً — ١١٣ سطراً', (t) async {
    // 🔴 **هذا هو العطل الذي رآه المالك بعينه.** «\frac{ع-١}{ع+١}» خرجت
    //    «-١ع» فوق «+١ع»، لأن مُقسِّم المقاطع ابتلع الإشارة مع الرقم فصارا
    //    ذرّةً واحدة تُرتَّب RTL فتقفز يسارَ «ع».
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final offenders = <String>[];
    for (final row in corpus) {
      final line = '${row['line']}';
      if (!_binary.hasMatch(line)) continue;
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(child: MathText(line)),
          ),
        ),
      ));
      t.takeException();

      // ⚠️ الفحص على **بنية المقاطع**: أيُّ مقطعٍ نصّه «إشارة + أرقام» فقط
      //    يعني أن الإشارة فُصلت عن مقدارها السابق — وهو عين العطل.
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        final d = w.data ?? '';
        if (RegExp(r'^[-−+][0-9٠-٩]+$').hasMatch(d) &&
            _binary.hasMatch(line)) {
          // ⚠️ ومسموحٌ لو كان في السطر **سالبٌ أحاديّ فعليّ**. وحدُّه ما
          //    يسبقه: بدايةُ سطر · مسافة · عاملٌ · **أو قوسُ فترة**.
          //    كشفَه المسح نفسه: «[-١، ٥]» فترةٌ حدُّها الأدنى سالبُ واحد —
          //    فحصرُ المسموح في المسافة والعامل وحدهما يجعل الاختبار
          //    يشتكي من رسمٍ صحيح.
          if (!RegExp(r'(^|[\s(\[،,=×*/])[-−+][0-9٠-٩]').hasMatch(line)) {
            offenders.add('${row['branch']}: «$d» في «$line»');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '${offenders.length} سطراً:\n  ${offenders.take(6).join('\n  ')}');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
