// 🧠 زرُّ «تفكير» — يُحفظ، ويصل الخادمَ، ويُطيل المهلةَ حين يُشعل.
//
// 🔴 **ما أوجبه (2026-09-22):** المالكُ رأى شرحاً يقف في منتصف الجملة،
//    فقال «أنا ما بغيته reasoning… هو الطالب يقدر يختار؟». وقِيس الفرق:
//    مُطفأً ٩٦٪ في مسائل الفيزياء والكيمياء، ومُشغّلاً ١٠٠٪.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/settings/app_settings.dart';
import 'package:ye_student_tutor/core/config/app_config.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.I.resetAll();
    await AppSettings.I.load();
  });

  test('الافتراضُ إطفاء — أكثرُ ما يُسأل شرحٌ لا حساب', () {
    expect(AppSettings.I.thinking, isFalse);
  });

  test('الاختيارُ ينجو من إغلاق التطبيق', () async {
    await AppSettings.I.setThinking(true);
    await AppSettings.I.load();
    expect(AppSettings.I.thinking, isTrue);
  });

  test('حذفُ الحساب يعيده لافتراضه', () async {
    await AppSettings.I.setThinking(true);
    await AppSettings.I.resetAll();
    expect(AppSettings.I.thinking, isFalse);
  });

  test('مهلةُ التفكير تفوق مهلةَ الخادم (٢٤٠ث)', () {
    // ⚠️ القاعدةُ في [AppConfig]: مهلةُ العميل أطولُ من مهلة الخادم عمداً،
    //    فقطعُها مبكراً يعني حصةً خُصمت وجواباً ضاع.
    expect(AppConfig.askTimeoutThinking.inSeconds, greaterThan(240));
    expect(AppConfig.askTimeoutThinking, greaterThan(AppConfig.askTimeout));
  });
}
