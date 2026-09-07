// 💾 نتائج الاختبارات: معزولة بالحساب مثل المحادثات تماماً.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_storage.dart';

QuizResult _r(String id, {String subject = "فيزياء", int score = 7}) => QuizResult(
      id: id,
      subject: subject,
      grade: 3,
      track: "علمي",
      unit: "الفيزياء الذرية",
      lessons: const ["نظرية بوهر"],
      score: score,
      total: 10,
      wrong: [const WrongAnswer(topic: "مستويات الطاقة", lesson: "نظرية بوهر", unit: "الفيزياء الذرية")],
      durationSec: 200,
    );

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_quiz_test');
    await QuizStorage.initForTests(dir.path);
  });

  setUp(() async => QuizStorage.clearAll());
  tearDownAll(() async => dir.delete(recursive: true));

  test('كل حساب يرى نتائجه وحده', () async {
    await QuizStorage.save(_r("a1"), ownerUid: "ahmed");
    await QuizStorage.save(_r("a2"), ownerUid: "ahmed");
    await QuizStorage.save(_r("s1"), ownerUid: "sara");

    expect(QuizStorage.countForOwner("ahmed"), 2);
    expect(QuizStorage.all("sara").single.id, "s1");
    expect(QuizStorage.all("uid-جديد"), isEmpty);
  });

  test('الفلترة بالمادة', () async {
    await QuizStorage.save(_r("a1", subject: "فيزياء"), ownerUid: "ahmed");
    await QuizStorage.save(_r("a2", subject: "كيمياء"), ownerUid: "ahmed");

    expect(QuizStorage.forSubject("ahmed", "كيمياء").single.id, "a2");
  });

  test('المسح لا يمسّ حساباً آخر', () async {
    await QuizStorage.save(_r("a1"), ownerUid: "ahmed");
    await QuizStorage.save(_r("s1"), ownerUid: "sara");

    expect(await QuizStorage.clearForOwner("ahmed"), 1);
    expect(QuizStorage.all("sara").length, 1);
  });

  test('طابور المزامنة: غير المرفوعة فقط', () async {
    await QuizStorage.save(_r("a1"), ownerUid: "ahmed");
    await QuizStorage.save(_r("a2"), ownerUid: "ahmed");
    expect(QuizStorage.pendingSync("ahmed").length, 2);

    await QuizStorage.markSynced("a1");
    expect(QuizStorage.pendingSync("ahmed").single.id, "a2");
  });

  test('النتائج بلا مالك يتبنّاها أول حساب', () async {
    await QuizStorage.save(_r("old1"));            // بلا ownerUid
    expect(QuizStorage.all("ahmed"), isEmpty);

    expect(await QuizStorage.adoptOrphans("ahmed"), 1);
    expect(QuizStorage.all("ahmed").single.id, "old1");
  });

  test('الترتيب: الأحدث أولاً', () async {
    final older = _r("old");
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final newer = _r("new");
    await QuizStorage.save(older, ownerUid: "ahmed");
    await QuizStorage.save(newer, ownerUid: "ahmed");

    expect(QuizStorage.all("ahmed").first.id, "new");
  });

  test('ذهاب وعودة عبر مستند Firestore', () {
    final r = _r("x1");
    final back = QuizResult.fromDoc("x1", r.toDoc());

    expect(back.subject, r.subject);
    expect(back.score, r.score);
    expect(back.wrong.single.lesson, "نظرية بوهر");   // ★ الدرس ينجو ⇒ الحلقة الذهبية تعمل
    expect(back.synced, isTrue);
  });
}
