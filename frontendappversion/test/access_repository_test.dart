// 🧪 قواعد ظهور الأقسام: **الفشل المفتوح** قبل كل شيء.
//
// 🔴 الخطأ الذي لا يُغتفر هنا ليس إظهار قسمٍ كان يجب إخفاؤه — الخادم يحرس
//    الفتح بـ403 على المسار نفسه. الخطأ الذي لا يُغتفر هو **إخفاء قسمٍ
//    مسموح**: طالبٌ يفتح التطبيق على شبكةٍ متقطّعة فيجد التعليم اختفى،
//    فيظن التطبيق معطوباً ويحذفه. لذلك كل طريقٍ مشكوكٍ فيه ⇒ مفتوح.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/access/access_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccessRepository.I.reset();
  });

  tearDown(() => AccessRepository.overrideClient(null));

  http.Client jsonClient(Object body, {int status = 200}) =>
      MockClient((_) async => http.Response(
            jsonEncode(body),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

  Map<String, dynamic> section(String mode, {String message = ''}) =>
      {'mode': mode, 'visible': mode != 'off', 'usable': mode == 'on', 'message': message};

  group('الحالة الافتراضية — مفتوحٌ ما لم يُقل غير ذلك', () {
    test('قسم لم يُذكر إطلاقاً ⇒ مفتوح', () {
      expect(AccessRepository.I.of('anything').usable, isTrue);
      expect(AccessRepository.I.visible(AppSection.teacher), isTrue);
    });

    test('🛟 انقطاع الشبكة لا يُخفي شيئاً', () async {
      AccessRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await AccessRepository.I.refresh();
      for (final s in AppSection.all) {
        expect(AccessRepository.I.usable(s), isTrue, reason: s);
      }
    });

    test('🛟 خطأ ٥٠٠ من الخادم لا يُخفي شيئاً', () async {
      AccessRepository.overrideClient(jsonClient({'error': 'x'}, status: 500));
      await AccessRepository.I.refresh();
      expect(AccessRepository.I.usable(AppSection.education), isTrue);
    });

    test('🛟 ردٌّ بلا `sections` لا يمسح ما كان', () async {
      AccessRepository.I.seed({
        AppSection.quiz: const SectionState(mode: SectionMode.off, message: 'مقفل'),
      });
      AccessRepository.overrideClient(jsonClient({'ok': true}));
      await AccessRepository.I.refresh();
      // لم يُمسح ولم يُستبدل — الردّ المشوّه لا يُغيّر الحالة أصلاً.
      expect(AccessRepository.I.usable(AppSection.quiz), isFalse);
    });
  });

  group('قراءة الأوضاع', () {
    test('off ⇒ مخفيٌّ ولا يُفتح', () async {
      AccessRepository.overrideClient(jsonClient({
        'sections': {AppSection.scholarships: section('off', message: 'للثالث فقط')}
      }));
      await AccessRepository.I.refresh();
      final s = AccessRepository.I.of(AppSection.scholarships);
      expect(s.visible, isFalse);
      expect(s.usable, isFalse);
      expect(s.message, 'للثالث فقط');
    });

    test('⭐ soon ⇒ يُرى ولا يُفتح — وهذا كل الفرق عن off', () async {
      AccessRepository.overrideClient(jsonClient({
        'sections': {AppSection.services: section('soon', message: 'قريباً')}
      }));
      await AccessRepository.I.refresh();
      final s = AccessRepository.I.of(AppSection.services);
      expect(s.visible, isTrue);
      expect(s.usable, isFalse);
    });

    test('🛟 وضعٌ لا يعرفه التطبيق ⇒ مفتوح', () async {
      // خادمٌ أحدث من التطبيق: نسخةٌ قديمة لا يجوز أن تُخفي قسماً
      // لأنها لم تفهم كلمةً جديدة.
      AccessRepository.overrideClient(jsonClient({
        'sections': {AppSection.quiz: {'mode': 'maintenance', 'message': ''}}
      }));
      await AccessRepository.I.refresh();
      expect(AccessRepository.I.usable(AppSection.quiz), isTrue);
    });
  });

  group('الكاش', () {
    test('يُحفظ ويُقرأ في الإقلاع التالي', () async {
      AccessRepository.overrideClient(jsonClient({
        'sections': {AppSection.teacher: section('off')}
      }));
      await AccessRepository.I.refresh();

      // إقلاعٌ جديد بلا شبكة — يقرأ ما حُفظ.
      AccessRepository.I.reset();
      AccessRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await AccessRepository.I.load();
      expect(AccessRepository.I.visible(AppSection.teacher), isFalse);
    });

    test('⚠️ كاشُ صفٍّ آخر يُهمل — طالبٌ غيّر صفّه لا يُحكم بقواعد صفٍّ تركه',
        () async {
      SharedPreferences.setMockInitialValues({
        'access_cache_v1': jsonEncode({AppSection.quiz: section('off')}),
        'access_scope_v1': '1|عام', // كاشٌ لصفٍّ غير صفّ الجلسة (٣ علمي)
      });
      AccessRepository.I.reset();
      AccessRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await AccessRepository.I.load();
      expect(AccessRepository.I.usable(AppSection.quiz), isTrue);
    });

    test('🛟 كاشٌ تالف لا يُخفي شيئاً', () async {
      SharedPreferences.setMockInitialValues({
        'access_cache_v1': '}{ليس JSON',
        'access_scope_v1': '3|علمي',
      });
      AccessRepository.I.reset();
      AccessRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await AccessRepository.I.load();
      expect(AccessRepository.I.usable(AppSection.education), isTrue);
    });
  });

  test('🔔 يُخطر المستمعين كي تُعاد الشاشة بعد وصول الرد', () async {
    var notified = 0;
    void listener() => notified++;
    AccessRepository.I.addListener(listener);
    AccessRepository.overrideClient(jsonClient({
      'sections': {AppSection.quiz: section('off')}
    }));
    await AccessRepository.I.refresh();
    AccessRepository.I.removeListener(listener);
    expect(notified, greaterThan(0));
  });
}

/// استثناء شبكة مبسّط — `MockClient` يقبل أي رمي.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'لا اتصال';
}
