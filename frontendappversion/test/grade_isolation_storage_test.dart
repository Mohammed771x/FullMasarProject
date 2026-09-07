// 🎓 عزل الصفوف في المخازن الثلاثة — حسابٌ واحد يرافق الطالب ثلاث سنوات،
//    وكل سنةٍ سجلُّها المستقل: يبدّل صفّه فتتبدّل أرقامه، ويعود فيجدها كما تركها.
//
// **وهذا ما يجعل الفكرة بلا كلفةٍ على الفاتورة:** لا مستند جديد ولا قراءة
// جديدة — الحقول موجودة أصلاً، وما يُضاف هنا هو **الفلترة** وحدها.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/session/grade_scope.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_storage.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_analytics.dart';
import 'package:ye_student_tutor/features/saved/data/saved_storage.dart';

const _uid = 'uid-ahmed';
const _other = 'uid-sara';

const g1 = GradeScope(1, 'عام');
const g2sci = GradeScope(2, 'علمي');
const g2lit = GradeScope(2, 'أدبي');
const g3sci = GradeScope(3, 'علمي');

ChatConversation _conv(String id, GradeScope s, {String subject = 'احياء'}) =>
    ChatConversation(
      id: id,
      title: 'محادثة $id',
      subject: subject,
      mode: 'شرح',
      grade: s.grade,
      track: s.track,
      ownerUid: _uid,
      messages: [ChatMessage(role: 'user', text: 'سؤال')],
    );

QuizResult _res(
  String id,
  GradeScope s, {
  String subject = 'فيزياء',
  int score = 7,
}) =>
    QuizResult(
      id: id,
      subject: subject,
      grade: s.grade,
      track: s.track,
      unit: 'وحدة',
      lessons: const ['درس'],
      score: score,
      total: 10,
      wrong: const [WrongAnswer(topic: 'مفهوم', lesson: 'درس', unit: 'وحدة')],
      durationSec: 120,
    );

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_grade_scope');
    await ChatStorage.initForTests(dir.path);
    await QuizStorage.initForTests(dir.path);
    await SavedStorage.initForTests(dir.path);
  });

  setUp(() async {
    await ChatStorage.clearAll();
    await QuizStorage.clearAll();
    await SavedStorage.clear(_uid);
    await SavedStorage.clear(_other);
  });

  tearDownAll(() async => dir.delete(recursive: true));

  // ══════════════ 💬 المحادثات ══════════════
  group('المحادثات', () {
    test('كل صفٍّ يرى محادثاته وحده', () async {
      await ChatStorage.saveConversation(_conv('c1', g1), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('c2', g3sci), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('c3', g3sci), ownerUid: _uid);

      expect(ChatStorage.getAllConversations(_uid, scope: g1).map((c) => c.id), ['c1']);
      expect(ChatStorage.countForOwner(_uid, scope: g3sci), 2);
      expect(ChatStorage.countForOwner(_uid, scope: g2sci), 0);
    });

    // 🔑 «ثاني علمي» و«ثاني أدبي» صفٌّ واحدٌ ومنهجان — والفصل بينهما مطلوب.
    test('المسار يفصل داخل الصف الواحد', () async {
      await ChatStorage.saveConversation(_conv('sci', g2sci), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('lit', g2lit), ownerUid: _uid);

      expect(ChatStorage.getAllConversations(_uid, scope: g2sci).single.id, 'sci');
      expect(ChatStorage.getAllConversations(_uid, scope: g2lit).single.id, 'lit');
    });

    // ⭐ **جوهر المطلب:** لا شيء يُمسح — الرجوع للصف القديم يعيد سجلّه كاملاً.
    test('العودة إلى الصف السابق تُرجع سجلّه كما كان', () async {
      await ChatStorage.saveConversation(_conv('أول-1', g1), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('أول-2', g1), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('ثالث-1', g3sci), ownerUid: _uid);

      // الطالب في الثالث: لا يرى شيئاً من الأول…
      expect(ChatStorage.countForOwner(_uid, scope: g3sci), 1);
      // …ثم يعود للأول فيجد محادثتيه سليمتين.
      expect(ChatStorage.countForOwner(_uid, scope: g1), 2);
      // والمجموع للحساب كله لم يُمسّ.
      expect(ChatStorage.countForOwner(_uid), 3);
    });

    test('المزامنة بلا نطاق ترى كل الصفوف — وإلا ضاع سجلُّ صفٍّ سحابياً', () async {
      await ChatStorage.saveConversation(_conv('a', g1), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('b', g3sci), ownerUid: _uid);
      expect(ChatStorage.getAllConversations(_uid), hasLength(2));
    });

    test('المالك يبقى الحارس الأول: نطاقٌ مطابق لحسابٍ آخر لا يُسرّب شيئاً', () async {
      await ChatStorage.saveConversation(_conv('c1', g3sci), ownerUid: _uid);
      expect(ChatStorage.getAllConversations(_other, scope: g3sci), isEmpty);
    });

    test('مسح صفٍّ واحد لا يمسّ الصفوف الأخرى', () async {
      await ChatStorage.saveConversation(_conv('c1', g1), ownerUid: _uid);
      await ChatStorage.saveConversation(_conv('c2', g3sci), ownerUid: _uid);

      expect(await ChatStorage.clearForScope(_uid, g1), 1);
      expect(ChatStorage.countForOwner(_uid, scope: g1), 0);
      expect(ChatStorage.countForOwner(_uid, scope: g3sci), 1);
    });
  });

  // ══════════════ 🧠 النتائج والتحليل ══════════════
  group('نتائج «اختبر نفسك»', () {
    test('نتائج كل صف على حدة', () async {
      await QuizStorage.save(_res('r1', g1), ownerUid: _uid);
      await QuizStorage.save(_res('r2', g3sci), ownerUid: _uid);

      expect(QuizStorage.all(_uid, scope: g1).single.id, 'r1');
      expect(QuizStorage.all(_uid, scope: g3sci).single.id, 'r2');
      expect(QuizStorage.all(_uid), hasLength(2));
    });

    test('الفلترة بالمادة تحترم النطاق', () async {
      await QuizStorage.save(_res('r1', g1, subject: 'رياضيات'), ownerUid: _uid);
      await QuizStorage.save(_res('r2', g3sci, subject: 'رياضيات'), ownerUid: _uid);

      expect(QuizStorage.forSubject(_uid, 'رياضيات', scope: g1).single.id, 'r1');
    });

    // 🔴 **العلّة التي كان يراها الطالب:** «أضعف مادة» تُحسب من كل السنوات،
    //    فيُقال له إن ضعفه في مادةٍ لا يدرسها هذه السنة أصلاً.
    test('أضعف مادة تُحسب من نتائج الصف الحالي وحده', () async {
      // في الأول: ضعفٌ شديد في العربي.
      await QuizStorage.save(_res('a1', g1, subject: 'عربي', score: 1), ownerUid: _uid);
      await QuizStorage.save(_res('a2', g1, subject: 'عربي', score: 2), ownerUid: _uid);
      // في الثالث: ضعفٌ في الكيمياء، والعربي غير مدروس.
      await QuizStorage.save(_res('b1', g3sci, subject: 'كيمياء', score: 3), ownerUid: _uid);
      await QuizStorage.save(_res('b2', g3sci, subject: 'كيمياء', score: 4), ownerUid: _uid);

      final weakThird =
          QuizAnalytics.weakestSubject(QuizStorage.all(_uid, scope: g3sci));
      expect(weakThird?.subject, 'كيمياء');

      final weakFirst = QuizAnalytics.weakestSubject(QuizStorage.all(_uid, scope: g1));
      expect(weakFirst?.subject, 'عربي');

      // وبلا نطاق يختلط الاثنان — وهذا هو ما كان يحدث قبل الإصلاح.
      expect(QuizAnalytics.bySubject(QuizStorage.all(_uid)), hasLength(2));
      expect(QuizAnalytics.bySubject(QuizStorage.all(_uid, scope: g1)), hasLength(1));
    });

    test('الرفع المعلَّق بلا نطاق — نتيجةُ صفٍّ تُرك لا تضيع', () async {
      await QuizStorage.save(_res('r1', g1), ownerUid: _uid);
      await QuizStorage.save(_res('r2', g3sci), ownerUid: _uid);
      expect(QuizStorage.pendingSync(_uid), hasLength(2));
    });
  });

  // ══════════════ ⭐ المحفوظات ══════════════
  group('المحفوظات', () {
    Future<void> save(String text, GradeScope? s) => SavedStorage.toggle(
          ownerUid: _uid,
          section: 'education',
          subject: 'احياء',
          text: text,
          scope: s,
        );

    test('المحفوظ يحمل صفَّ ساعة الحفظ', () async {
      await save('نصّ الأول', g1);
      await save('نصّ الثالث', g3sci);

      expect(SavedStorage.count(_uid, scope: g1), 1);
      expect(SavedStorage.all(_uid, scope: g3sci).single.text, 'نصّ الثالث');
      expect(SavedStorage.count(_uid), 2);
    });

    // 🕰️ محفوظاتُ النسخة السابقة بلا صف: تظهر في كل الصفوف كي لا يفتح
    //    الطالب التطبيق بعد التحديث فيجدها اختفت.
    test('محفوظٌ بلا صف يظهر في كل الصفوف قبل التبنّي', () async {
      await save('قديم', null);
      expect(SavedStorage.count(_uid, scope: g1), 1);
      expect(SavedStorage.count(_uid, scope: g3sci), 1);
    });

    test('التبنّي ينسبه لصفٍّ واحد فينتهي ظهوره في الباقي', () async {
      await save('قديم', null);
      expect(await SavedStorage.adoptScopeless(_uid, g3sci), 1);

      expect(SavedStorage.count(_uid, scope: g3sci), 1);
      expect(SavedStorage.count(_uid, scope: g1), 0);
    });

    test('التبنّي لا يلمس محفوظات حسابٍ آخر', () async {
      await SavedStorage.toggle(
          ownerUid: _other, section: 'education', subject: 'احياء', text: 'لسارة');
      expect(await SavedStorage.adoptScopeless(_uid, g3sci), 0);
      expect(SavedStorage.all(_other, scope: g1).single.text, 'لسارة');
    });

    test('التبنّي لا يعيد وسم ما له صفٌّ بالفعل', () async {
      await save('نصّ الأول', g1);
      expect(await SavedStorage.adoptScopeless(_uid, g3sci), 0);
      expect(SavedStorage.count(_uid, scope: g1), 1);
      expect(SavedStorage.count(_uid, scope: g3sci), 0);
    });

    test('«مسح المحفوظات» في صفٍّ لا يمسّ صفاً آخر', () async {
      await save('نصّ الأول', g1);
      await save('نصّ الثالث', g3sci);

      expect(await SavedStorage.clear(_uid, scope: g1), 1);
      expect(SavedStorage.count(_uid, scope: g3sci), 1);
    });

    // ⚠️ السقف يحرس ذاكرة الجهاز، وذاكرةُ الجهاز واحدةٌ لا ثلاث.
    test('السقف يبقى للحساب لا لكل صف', () async {
      for (var i = 0; i < SavedStorage.maxPerUser + 5; i++) {
        await save('نص رقم $i', i.isEven ? g1 : g3sci);
      }
      expect(SavedStorage.count(_uid), SavedStorage.maxPerUser);
    });
  });
}
