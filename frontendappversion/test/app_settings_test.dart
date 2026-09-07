// 🧪 الإعدادات: تُحفظ فعلاً وتُقيَّد بحدودها.
//    كانت في `DemoState` بالذاكرة فتضيع مع كل إغلاق — والاختبار هنا يحرس
//    أنها لم تعد كذلك.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/settings/app_settings.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.I.resetAll();
    await AppSettings.I.load();
  });

  test('الافتراضات قبل أي ضبط', () {
    expect(AppSettings.I.answerFontSize, AppSettings.defaultFont);
    expect(AppSettings.I.notifScholarships, isTrue);
    expect(AppSettings.I.notifGeneral, isTrue);
  });

  test('حجم الخط يُحفظ ويعود بعد إعادة التحميل', () async {
    await AppSettings.I.setAnswerFontSize(21);
    await AppSettings.I.load();
    expect(AppSettings.I.answerFontSize, 21);
  });

  test('🛡️ الحجم يُقيَّد بحدوده لا يُرفض', () async {
    await AppSettings.I.setAnswerFontSize(99);
    expect(AppSettings.I.answerFontSize, AppSettings.maxFont);
    await AppSettings.I.setAnswerFontSize(1);
    expect(AppSettings.I.answerFontSize, AppSettings.minFont);
  });

  test('قيمة محفوظة خارج الحدود تُقيَّد عند القراءة', () async {
    // نسخة أقدم سمحت بقيمة أكبر — يجب ألّا تُخرج نصّاً عملاقاً.
    SharedPreferences.setMockInitialValues({'settings_answer_font': 80.0});
    await AppSettings.I.load();
    expect(AppSettings.I.answerFontSize, AppSettings.maxFont);
  });

  test('مفاتيح الإشعارات تُحفظ', () async {
    await AppSettings.I.setNotifScholarships(false);
    await AppSettings.I.setNotifGeneral(false);
    await AppSettings.I.load();
    expect(AppSettings.I.notifScholarships, isFalse);
    expect(AppSettings.I.notifGeneral, isFalse);
  });

  test('التغيير يُخطر المستمعين — الشاشات تلتقطه بلا ربط يدوي', () async {
    var fired = 0;
    void listener() => fired++;
    AppSettings.I.addListener(listener);
    await AppSettings.I.setAnswerFontSize(18);
    await AppSettings.I.setNotifGeneral(false);
    AppSettings.I.removeListener(listener);
    expect(fired, 2);
  });

  test('resetAll يعيد كل شيء لافتراضه', () async {
    await AppSettings.I.setAnswerFontSize(22);
    await AppSettings.I.setNotifGeneral(false);
    await AppSettings.I.resetAll();
    await AppSettings.I.load();
    expect(AppSettings.I.answerFontSize, AppSettings.defaultFont);
    expect(AppSettings.I.notifGeneral, isTrue);
  });
}
