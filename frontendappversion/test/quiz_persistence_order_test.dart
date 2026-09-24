// ══════════════════════════════════════════════════
// 💾 نتيجةٌ واحدة، ولقطةٌ لا تسبق نفسَها ولا تعود بعد النهاية
// ══════════════════════════════════════════════════
//
// 🎯 ثلاثةُ أعطالٍ صامتة في مسار الحفظ، يجمعها أنها **لا تُرى في شاشة**:
//    السجلُّ وحده يعرف أن شيئاً ساء.
//
//    ① نقرتان على «عرض النتيجة 🏁» ⇒ نتيجتان في «تقدّمي» ومتوسّطٌ محسوبٌ
//      على محاولةٍ لم تقع.
//    ② كتابتان متوازيتان للقطة ⇒ الطالب يستأنف من سؤالٍ **سبق أن أجابه**.
//    ③ محوُ اللقطة يسبق كتابةً معلّقة ⇒ «استأنف» يفتح اختباراً انتهى.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/quota/quota_repository.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_repository.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_resume_store.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_storage.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_controller.dart';

// 🧪 **مُعرّفان لا واحد.** `UserSession.I.uid` يقرأ من Firebase مباشرةً
//    فيعود `""` في الاختبارات، ولا حاقنَ له. فما يمرّ بالجلسة يُقاس
//    بالفارغ (وهو ما يفعله المتحكّم فعلاً هنا)، وما يُنادى مباشرةً —
//    وفيه يعيش منطقُ الترتيب والختم — يُقاس بمعرّفٍ حقيقيّ.
const _uid = "طالب-الاختبار";
const _sessionUid = ""; // ما تراه `UserSession.I.uid` تحت الاختبار

QuizQuestion _q(int i) => QuizQuestion(
      q: "سؤال $i",
      options: const ["أ", "ب", "ج", "د"],
      correctIndex: 0,
      topic: "موضوع",
      lesson: "نظرية بوهر",
      id: "q$i",
    );

QuizSnapshot _snap(int index) => QuizSnapshot(
      ownerUid: _uid,
      subject: "فيزياء",
      grade: 3,
      track: "علمي",
      unit: "الفيزياء الذرية",
      lessons: const ["نظرية بوهر"],
      questions: [for (var i = 0; i < 5; i++) _q(i)],
      answers: [for (var i = 0; i < index; i++) 0],
      index: index,
      score: index,
      savedAt: DateTime.now(),
      startedAt: DateTime.now(),
    );

/// مستودعٌ يردّ أسئلةً جاهزة بلا شبكة.
class _FakeQuizRepo extends QuizRepository {
  _FakeQuizRepo({this.refunded = false});
  final bool refunded;
  int calls = 0;

  @override
  Future<QuizGeneration> generate({
    required String subject,
    required int grade,
    required String track,
    required String unit,
    required List<String> lessons,
    required int count,
    String? idToken,
    String userId = "",
    String requestId = "",
    List<String> seenIds = const [],
  }) async {
    calls++;
    return QuizGeneration(
      questions: [for (var i = 0; i < 3; i++) _q(i)],
      lessons: lessons,
      unit: unit,
      quotaRefunded: refunded,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_quiz_persist');
    await QuizStorage.initForTests(dir.path);
  });
  tearDownAll(() async => dir.delete(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    QuizResumeStore.resetForTests();
    await QuizStorage.clearAll();
    UserSession.I.isGuest = true;
    QuotaRepository.I.clear();
  });

  // ══════════════ ① نقرتان ⇒ نتيجةٌ واحدة ══════════════

  test('☢️ نقرتان على «عرض النتيجة» ⇒ نتيجةٌ واحدة في السجلّ', () async {
    final c = QuizController(repository: _FakeQuizRepo());
    await c.generate();
    c
      ..select(0)
      ..confirm();

    // نقرتان متلاحقتان — بلا انتظارٍ بينهما، كما تقع في اليد فعلاً.
    final first = c.saveResult();
    final second = c.saveResult();
    final a = await first;
    final b = await second;

    expect(QuizStorage.all(_sessionUid), hasLength(1),
        reason: '🔴 نتيجتان لمحاولةٍ واحدة');
    expect(a.id, b.id, reason: 'المستدعي الثاني أخذ نتيجةً أخرى');
    c.dispose();
  });

  test('والنقرةُ الثالثة بعد اكتمال الحفظ لا تُضيف شيئاً', () async {
    final c = QuizController(repository: _FakeQuizRepo());
    await c.generate();
    final one = await c.saveResult();
    final two = await c.saveResult();

    expect(QuizStorage.all(_sessionUid), hasLength(1));
    expect(one.id, two.id);
    c.dispose();
  });

  // ══════════════ ② الترتيب ══════════════

  test('☢️ لقطةٌ قديمة لا تُكتب فوق الأحدث', () async {
    // كتابتان بلا `await` بينهما — كما تفعل `_persistProgress` حرفياً.
    final older = QuizResumeStore.save(_snap(2));
    final newer = QuizResumeStore.save(_snap(4));
    await Future.wait([older, newer]);

    final read = await QuizResumeStore.read(_uid);
    expect(read?.index, 4, reason: '🔴 لقطةُ السؤال ٢ غلبت لقطةَ السؤال ٤');
  });

  // ══════════════ ③ لا عودة بعد النهاية ══════════════

  test('☢️ لقطةٌ معلّقة لا تُحيي اختباراً انتهى', () async {
    // كتابةٌ انطلقت قبل الإنهاء، ومحوٌ خلفها — الترتيبُ محفوظٌ والختمُ قاطع.
    final pending = QuizResumeStore.save(_snap(3));
    final cleared = QuizResumeStore.clear(_uid, seal: true);
    await Future.wait([pending, cleared]);
    // ومحاولةٌ متأخّرة جداً بعد الختم:
    await QuizResumeStore.save(_snap(4));

    expect(await QuizResumeStore.read(_uid), isNull,
        reason: '🔴 «استأنف» سيفتح اختباراً حُسبت نتيجتُه');
  });

  // ══════════════ ④ الحصة ══════════════

  test('🎟️ اختبارٌ نجح يُنقص العدّاد المعروض', () async {
    QuotaRepository.I.status = const QuotaStatus(
        limit: 50, used: 10, remaining: 40, isGuest: false, resetsDaily: true);

    final c = QuizController(repository: _FakeQuizRepo());
    await c.generate();

    expect(QuotaRepository.I.status.remaining, 39,
        reason: '🔴 الاختبار يخصم على الخادم والرقمُ المعروض لا يتحرّك');
    expect(QuotaRepository.I.status.used, 11);
    c.dispose();
  });

  test('💳 واختبارٌ من البنك رُدّت حصّتُه لا يُنقصه', () async {
    QuotaRepository.I.status = const QuotaStatus(
        limit: 50, used: 10, remaining: 40, isGuest: false, resetsDaily: true);

    final c = QuizController(repository: _FakeQuizRepo(refunded: true));
    await c.generate();

    expect(QuotaRepository.I.status.remaining, 40,
        reason: '🔴 خُصمت حصةٌ ردّها الخادم ([core/billing.settle_quota])');
    c.dispose();
  });
}
