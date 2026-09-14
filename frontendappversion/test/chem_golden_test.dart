// 🖼️ يُخرج صورة PNG للرسم كي يُحكم عليه بالعين لا بالاختبارات وحدها.
//     `flutter test test/chem_golden_test.dart --update-goldens`
//     ثم افتح `test/goldens/chem_sheet.png`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

const _cases = <String, String>{
  'بروبيل أمين (نصّ الكتاب حرفياً)': r'\chem{CH3 CH2 CH2 NH2}',
  'ثنائي ميثيل أمين': r'\chem{CH3-NH-CH3}',
  '٢-ميثيل بروبان': r'\chem{CH3-CH(CH3)-CH3}',
  '٢-أمينو بنتان': r'\chem{CH3-CH2-CH2-CH(NH2)-CH3}',
  '٢،٢-ثنائي ميثيل بروبان': r'\chem{CH3-C(CH3)(CH3)-CH3}',
  'أسيتونيتريل (رابطة ثلاثية)': r'\chem{CH3-C#N}',
  'أسيتالدهيد (رابطة ثنائية)': r'\chem{CH3-CH=O}',
  'سيكلوبروبان · سيكلوبيوتان · سيكلوبنتان': r'\ring{3} \ring{4} \ring{5}',
  'سيكلوهيكسان · بنزين': r'\ring{6} \ring{6|ar}',
  'بيريدين · بيبيريدين': r'\ring{6|ar|N} \ring{6|NH}',
  'أنيلين · أمينو سيكلوبروبان': r'\ring{6|ar|+NH2} \ring{3|+NH2}',
  // ⭐ عطلُ المالك (2026-09-13): الثلاثة كانت رسمةً واحدة.
  'هكسان حلقي · هكسين حلقي · بنزين':
      r'\ring{6} \ring{6|=1} \ring{6|ar}',
  'بنزين بصيغة كيكولي': r'\ring{6|=1,3,5}',
  'بروبين · بيوتين · بنتين حلقي': r'\ring{3|=1} \ring{4|=1} \ring{5|=1}',
  'نفثالين · أنثراسين': r'\ring{6|ar|fuse2} \ring{6|ar|fuse3}',
  'تولوين · فينول · بنزالدهيد':
      r'\ring{6|ar|+CH3} \ring{6|ar|+OH} \ring{6|ar|+CHO}',
  'أورثو · ميتا · بارا — ثنائي برومو بنزين':
      r'\ring{6|ar|+Br@1|+Br@2} \ring{6|ar|+Br@1|+Br@3} \ring{6|ar|+Br@1|+Br@4}',
  'ثلاثي نيتروتولوين (TNT)':
      r'\ring{6|ar|+CH3@1|+NO2@2|+NO2@4|+NO2@6}',
  'جلوكوز (صيغة حلقية) · فركتوز': r'\ring{6|O} \ring{5|O}',
  'N-بروبيل بيوتاناميد': r'\chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}',
  'N-ميثيل N-بنتيل بيوتاناميد':
      r'\chem{CH3-CH2-CH2-C(=O)-N(CH3)-CH2-CH2-CH2-CH2-CH3}',
  'N,N-ثنائي إيثيل إيثاناميد': r'\chem{CH3-C(=O)-N(CH2-CH3)-CH2-CH3}',
  'هيبتاناميد': r'\chem{CH3-CH2-CH2-CH2-CH2-CH2-C(=O)-NH2}',
  'داخل جملة عربية':
      r'المركب \chem{CH3-CH(NH2)-CH3} يسمى ٢-أمينو بروبان، وحلقته \ring{6|ar}.',
};

void main() {
  testWidgets('لوحة الصيغ البنائية', (tester) async {
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            key: const Key('sheet'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in _cases.entries) ...[
                  Text(e.key,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  MathText(e.value,
                      style: const TextStyle(
                          fontSize: 19, color: Colors.black, height: 1.6)),
                  const Divider(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      // 🔑 بالمفتاح لا بالنوع: صار داخل اللوحة ١٣ ممرّراً بعد أن
      //    غُلّفت كل سلسلةٍ بتمريرٍ أفقيّ يمنع الفيضان.
      find.byKey(const Key('sheet')),
      // 📌 حُدِّثت الصورة المرجعية 2026-09-09 بفارق **بكسل واحد (0.00٪)**
      //    — إزاحةُ تقريبٍ لا غير، سبّبها تغليفُ كل سلسلة بتمريرٍ أفقيّ
      //    يمنع فيضان الشاشة. والرسم نفسه لم يتغيّر (تغيّرُ الرسم يُظهر
      //    آلاف البكسلات لا واحداً).
      matchesGoldenFile('goldens/chem_sheet.png'),
    );
  });
}
