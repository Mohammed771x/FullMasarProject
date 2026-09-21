// 🛡️ اختبارات التحصين في التطبيق: الهوية · الأخطاء · الحصة · التحديث ·
//    حذف الحساب · المفضّلة · استئناف الاختبار.
//
// كل مجموعة هنا تحرس **عطلاً محدّداً** لا سلوكاً عاماً.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/auth/user_repository.dart';
import 'package:ye_student_tutor/core/error/error_messages.dart';
import 'package:ye_student_tutor/core/quota/quota_repository.dart';
import 'package:ye_student_tutor/core/version/version_gate.dart';
import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_resume_store.dart';
import 'package:ye_student_tutor/features/scholarships/data/models/scholarship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ══════════════════════════════════════════════════
  // 📡 تصنيف أعطال الشبكة
  // ══════════════════════════════════════════════════
  group('📡 رسالة العطل تقول للطالب ما يستطيع إصلاحه', () {
    test('🔴 ClientException = انقطاع اتصال، لا «خطأ غير متوقع»', () {
      // العلّة الأصلية: الشاشة كانت تمسك `SocketException` وحدها، وحزمة
      // `http` على أندرويد ترمي `ClientException` في معظم أعطال الشبكة
      // الحقيقية — فيُلام التطبيق على انقطاع نتِّ الطالب.
      final e = http.ClientException("Connection closed");
      expect(ErrorMessages.isConnectivity(e), isTrue);
      expect(ErrorMessages.forSendFailure(e), ErrorMessages.askNoConnection);
    });

    test('SocketException كذلك', () {
      const e = SocketException("no route");
      expect(ErrorMessages.forSendFailure(e), ErrorMessages.askNoConnection);
    });

    test('المهلة رسالتها الخاصة — «السيرفر مشغول» لا «لا يوجد إنترنت»', () {
      final e = TimeoutException("t");
      expect(ErrorMessages.forSendFailure(e), ErrorMessages.askTimeout);
      expect(ErrorMessages.isConnectivity(e), isFalse);
    });

    test('الخطأ البرمجي يبقى «غير متوقع» ولا يُقترح إعادة المحاولة', () {
      final e = StateError("bug");
      expect(ErrorMessages.forSendFailure(e), ErrorMessages.askUnexpected);
      expect(ErrorMessages.isRetryable(e), isFalse);
    });

    test('المهلة والشبكة وحدهما تستحقان زرّ «أعد المحاولة»', () {
      expect(ErrorMessages.isRetryable(TimeoutException("t")), isTrue);
      expect(ErrorMessages.isRetryable(http.ClientException("x")), isTrue);
      expect(ErrorMessages.isRetryable(FormatException("x")), isFalse);
    });
  });

  // ══════════════════════════════════════════════════
  // 🎟️ حالة الحصة
  // ══════════════════════════════════════════════════
  group('🎟️ عدّاد الحصة', () {
    test('قبل أول قراءة: غير معروفة ⇒ لا تُعرض', () {
      expect(QuotaStatus.unknown.isKnown, isFalse);
    });

    test('العتبة **نسبية** لا رقمٌ ثابت', () {
      // حدُّ الزائر ٥ وحدُّ الطالب ٥٠: «باقٍ ٥» تحذيرٌ للثاني وحالةٌ
      // طبيعية تماماً للأول. عتبةٌ رقمية كانت ستُنذر الزائر من أول سؤال.
      const guest = QuotaStatus(
          limit: 5, used: 0, remaining: 5, isGuest: true, resetsDaily: false);
      const student = QuotaStatus(
          limit: 50, used: 45, remaining: 5, isGuest: false, resetsDaily: true);
      expect(guest.isLow, isFalse);
      expect(student.isLow, isTrue);
    });

    test('النفاد حالةٌ مستقلة عن الانخفاض', () {
      const q = QuotaStatus(
          limit: 50, used: 50, remaining: 0, isGuest: false, resetsDaily: true);
      expect(q.isExhausted, isTrue);
      expect(q.isLow, isFalse);      // النافد ليس «منخفضاً» — له لونه ورسالته
    });

    test('الخصم المحلي يُنقص المتبقي ولا ينزل تحت الصفر', () {
      const q = QuotaStatus(
          limit: 3, used: 2, remaining: 1, isGuest: false, resetsDaily: true);
      final after = q.consumeOne();
      expect(after.remaining, 0);
      expect(after.used, 3);
      expect(after.consumeOne().remaining, 0);   // لا سالب
    });

    test('يقرأ ردّ الخادم ويميّز الزائر', () {
      final q = QuotaStatus.fromJson({
        "limit": 5, "used": 2, "remaining": 3,
        "is_guest": true, "resets_daily": false,
      });
      expect(q.remaining, 3);
      expect(q.isGuest, isTrue);
      expect(q.resetsDaily, isFalse);
    });

    test('🛟 ردٌّ مشوّه لا يُسقط الواجهة — يبقى «غير معروف»', () {
      final q = QuotaStatus.fromJson({"limit": "كلام", "remaining": null});
      expect(q.isKnown, isFalse);
    });
  });

  // ══════════════════════════════════════════════════
  // 📦 بوابة التحديث
  // ══════════════════════════════════════════════════
  group('📦 بوابة التحديث تفشل مفتوحة دائماً', () {
    test('ردٌّ غير 200 ⇒ لا تحديث مطلوب', () async {
      final client = MockClient((_) async => http.Response("nope", 503));
      final v = await VersionGate.check(client: client);
      expect(v.updateRequired, isFalse);
    });

    test('🛟 عطل شبكة ⇒ لا تحديث مطلوب (لا يُحجب الطالب بسبب انقطاع)', () async {
      final client = MockClient((_) async => throw const SocketException("down"));
      final v = await VersionGate.check(client: client);
      expect(v.updateRequired, isFalse);
    });

    test('🛟 JSON مشوّه ⇒ لا تحديث مطلوب', () async {
      final client = MockClient((_) async => http.Response("<html>", 200));
      final v = await VersionGate.check(client: client);
      expect(v.updateRequired, isFalse);
    });

    test('الخادم يقرّر الإلزام — لا يُحسب في التطبيق', () async {
      // ⚠️ الحساب في الخادم لا هنا عمداً: النسخة القديمة هي بالضبط التي
      //    قد تحسبه خطأً، وهي التي نريد إلزامها.
      final client = MockClient((_) async => http.Response(
            '{"update_required":true,"message":"حدّث","store_url":"https://x.test"}',
            200,
            headers: {"content-type": "application/json; charset=utf-8"},
          ));
      final v = await VersionGate.check(client: client);
      expect(v.updateRequired, isTrue);
      expect(v.storeUrl, "https://x.test");
    });
  });

  // ══════════════════════════════════════════════════
  // 🗑️ حذف الحساب
  // ══════════════════════════════════════════════════
  group('🗑️ حذف الحساب لا يترك بيانات خلفه', () {
    test('🔴 `scholarship_chats` ضمن المجموعات المحذوفة', () {
      // العطل: كانت القائمة مكتوبةً في مكانها وتذكر ثلاث مجموعات، ثم
      // أُضيفت `scholarship_chats` في `firestore.rules` ولم يعلم بها أحد.
      // فيحذف الطالب حسابه وتبقى محادثاته مع مساعد المنح في السحابة.
      expect(UserRepository.userSubcollections, contains("scholarship_chats"));
    });

    test('كل فروع المستخدم مذكورة — والقائمة مصدرٌ واحد', () {
      expect(
        UserRepository.userSubcollections,
        containsAll(<String>[
          "conversations",
          "scholarship_chats",
          "results",
          "saved_answers",
        ]),
      );
    });
  });

  // ══════════════════════════════════════════════════
  // ⭐ المنح المتابَعة
  // ══════════════════════════════════════════════════
  group('⭐ فلتر المفضّلة', () {
    Scholarship sch(String id) =>
        Scholarship(id: id, name: "منحة $id", country: "تركيا");

    test('«متابَعة» يعتمد على المعرّفات الممرَّرة لا على صفةٍ في المنحة', () {
      expect(SchFilter.favorites.test(sch("a"), favoriteIds: {"a"}), isTrue);
      expect(SchFilter.favorites.test(sch("b"), favoriteIds: {"a"}), isFalse);
    });

    test('⚠️ بلا معرّفات ⇒ لا شيء (لا «الكل»)', () {
      // «لا مفضّلة معروفة» ≠ «كل المنح» — والخلط بينهما يعرض عشرين منحة
      // تحت عنوان «متابَعة» فيظنّ الطالب أنه تابعها كلها.
      expect(SchFilter.favorites.test(sch("a")), isFalse);
    });

    test('بقية الفلاتر لم تتأثر بإضافة المعامل', () {
      expect(SchFilter.all.test(sch("a")), isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // ⏸️ استئناف الاختبار
  // ══════════════════════════════════════════════════
  group('⏸️ استئناف اختبار لم يكتمل', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    QuizSnapshot snap({int index = 3, DateTime? saved}) => QuizSnapshot(
          ownerUid: "u1",
          subject: "فيزياء",
          grade: 3,
          track: "علمي",
          unit: "الفيزياء الذرية",
          lessons: const ["نظرية بوهر"],
          questions: List.generate(
            5,
            (i) => QuizQuestion(
              q: "سؤال $i",
              options: const ["أ", "ب", "ج", "د"],
              correctIndex: 1,
              topic: "بوهر",
              lesson: "نظرية بوهر",
              why: "لأن نصف القطر يتناسب مع مربّع العدد",
              level: "متوسط",
              id: "qid$i",
            ),
          ),
          answers: List.generate(index, (_) => 1),
          index: index,
          score: index,
          savedAt: saved ?? DateTime.now(),
          startedAt: DateTime.now().subtract(const Duration(minutes: 4)),
        );

    test('يحفظ ثم يستعيد من حيث توقّف الطالب', () async {
      await QuizResumeStore.save(snap());
      final back = await QuizResumeStore.read("u1");
      expect(back, isNotNull);
      expect(back!.index, 3);
      expect(back.questions.length, 5);
      expect(back.remaining, 2);
      // 💡 **واللقطةُ تحمل «لماذا» و`id`** — بدونهما تصل المراجعةُ بلا
      //    تعليل ويتكرّر السؤالُ في المحاولة التالية (رُئي 2026-09-18).
      expect(back.questions.first.why, isNotEmpty);
      expect(back.questions.first.id, "qid0");
      expect(back.questions.first.level, "متوسط");
      expect(back.answers.length, 3);
    });

    test('👤 محكومٌ بالحساب — حسابٌ آخر لا يستأنف اختبار غيره', () async {
      await QuizResumeStore.save(snap());
      expect(await QuizResumeStore.read("someone-else"), isNull);
    });

    test('⏳ لقطةٌ أقدم من يومٍ تُهمَل وتُمحى', () async {
      await QuizResumeStore.save(
          snap(saved: DateTime.now().subtract(const Duration(days: 3))));
      // ⚠️ `save` يختم `saved_at` بالوقت الحالي، فنكتب اللقطة القديمة يدوياً.
      SharedPreferences.setMockInitialValues({
        "quiz_in_progress_u1":
            '{"questions":[],"index":0,"saved_at":"2020-01-01T00:00:00.000"}'
      });
      expect(await QuizResumeStore.read("u1"), isNull);
    });

    test('🛟 لقطة بلا أسئلة تُمحى ولا تُعرض (زرٌّ يفتح شاشةً منهارة)', () async {
      SharedPreferences.setMockInitialValues({
        "quiz_in_progress_u1":
            '{"questions":[],"index":0,"saved_at":"${DateTime.now().toIso8601String()}"}'
      });
      expect(await QuizResumeStore.read("u1"), isNull);
    });

    test('🛟 مؤشّرٌ خارج المدى يُمحى كذلك', () async {
      final s = snap(index: 3);
      await QuizResumeStore.save(s);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString("quiz_in_progress_u1")!;
      await prefs.setString(
          "quiz_in_progress_u1", raw.replaceFirst('"index":3', '"index":99'));
      expect(await QuizResumeStore.read("u1"), isNull);
    });

    test('🛟 بياناتٌ مشوّهة لا تُسقط الشاشة', () async {
      SharedPreferences.setMockInitialValues({"quiz_in_progress_u1": "{{{"});
      expect(await QuizResumeStore.read("u1"), isNull);
    });

    test('المسح بعد اكتمال الاختبار', () async {
      await QuizResumeStore.save(snap());
      await QuizResumeStore.clear("u1");
      expect(await QuizResumeStore.read("u1"), isNull);
    });
  });
}

/// عميل HTTP وهمي بسيط — أخفّ من إضافة `http/testing` كاعتماد.
class MockClient extends http.BaseClient {
  MockClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await handler(request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      request: request,
    );
  }
}
