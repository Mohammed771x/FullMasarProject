// 💬 محادثات المنح: معزولة بالحساب **وبالمنحة** معاً.
//
// العزل المزدوج هو جوهر هذا التخزين: جوّال بحسابين لا يخلط أسئلتهما،
// ومحادثات المنحة التركية لا تظهر في الماليزية.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/scholarships/data/models/scholarship_chat.dart';
import 'package:ye_student_tutor/features/scholarships/data/scholarship_chat_storage.dart';

SchConversation _c(
  String id, {
  String sch = "turkey",
  String name = "المنحة التركية",
  List<String> asks = const ["ما الشروط؟"],
}) {
  final c = SchConversation(
    id: id,
    title: "محادثة",
    scholarshipId: sch,
    scholarshipName: name,
  );
  for (final q in asks) {
    c.messages.add(SchMessage(role: "user", text: q));
    c.messages.add(SchMessage(role: "ai", text: "جواب عن «$q»"));
  }
  return c;
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_sch_chat_test');
    await SchChatStorage.initForTests(dir.path);
  });

  setUp(() async => SchChatStorage.clearAll());
  tearDownAll(() async => dir.delete(recursive: true));

  group('العزل بالحساب', () {
    test('كل حساب يرى محادثاته وحده', () async {
      await SchChatStorage.save(_c("a1"), ownerUid: "ahmed");
      await SchChatStorage.save(_c("s1"), ownerUid: "sara");

      expect(SchChatStorage.forScholarship("ahmed", "turkey").single.id, "a1");
      expect(SchChatStorage.forScholarship("sara", "turkey").single.id, "s1");
      expect(SchChatStorage.forScholarship("uid-جديد", "turkey"), isEmpty);
    });

    test('لا تُقرأ محادثة حسابٍ آخر بمعرّفها', () async {
      await SchChatStorage.save(_c("a1"), ownerUid: "ahmed");
      expect(SchChatStorage.get("a1", "sara"), isNull);
      expect(SchChatStorage.get("a1", "ahmed"), isNotNull);
    });
  });

  group('العزل بالمنحة', () {
    test('محادثات كل منحة على حدة', () async {
      await SchChatStorage.save(_c("t1", sch: "turkey"), ownerUid: "ahmed");
      await SchChatStorage.save(_c("m1", sch: "malaysia"), ownerUid: "ahmed");

      expect(SchChatStorage.countFor("ahmed", "turkey"), 1);
      expect(SchChatStorage.countFor("ahmed", "malaysia"), 1);
      expect(SchChatStorage.forScholarship("ahmed", "turkey").single.id, "t1");
      expect(SchChatStorage.all("ahmed").length, 2);
    });

    test('مسح منحة لا يمسّ الأخرى', () async {
      await SchChatStorage.save(_c("t1", sch: "turkey"), ownerUid: "ahmed");
      await SchChatStorage.save(_c("m1", sch: "malaysia"), ownerUid: "ahmed");

      await SchChatStorage.clearForScholarship("ahmed", "turkey");
      expect(SchChatStorage.countFor("ahmed", "turkey"), 0);
      expect(SchChatStorage.countFor("ahmed", "malaysia"), 1);
    });
  });

  test('المحادثات الفارغة لا تُعرض في السجلّ', () async {
    // فتح الشات ثم الخروج بلا سؤال يجب ألا يترك سطراً في القائمة.
    await SchChatStorage.save(_c("empty", asks: const []), ownerUid: "ahmed");
    expect(SchChatStorage.forScholarship("ahmed", "turkey"), isEmpty);
  });

  test('الترتيب: الأحدث أولاً', () async {
    await SchChatStorage.save(_c("old"), ownerUid: "ahmed");
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await SchChatStorage.save(_c("new"), ownerUid: "ahmed");
    expect(SchChatStorage.forScholarship("ahmed", "turkey").first.id, "new");
  });

  test('السقف يحذف الأقدم تلقائياً', () async {
    for (var i = 0; i < SchChatStorage.maxPerScholarship + 5; i++) {
      await SchChatStorage.save(_c("c$i"), ownerUid: "ahmed");
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(SchChatStorage.countFor("ahmed", "turkey"),
        SchChatStorage.maxPerScholarship);
  });

  group('العنوان والمعاينة', () {
    test('العنوان = أول سؤال للطالب لا رسالة الترحيب', () {
      final c = _c("x", asks: const ["ما الوثائق المطلوبة للتقديم؟"]);
      c.retitleFromFirstQuestion();
      expect(c.title, "ما الوثائق المطلوبة للتقديم؟");
    });

    test('السؤال الطويل يُقص بثلاث نقاط', () {
      final c = _c("x", asks: ["س" * 90]);
      c.retitleFromFirstQuestion();
      expect(c.title.length, lessThanOrEqualTo(40));
      expect(c.title.endsWith("…"), isTrue);
    });

    test('بلا أسئلة ⇒ العنوان لا يتغيّر', () {
      final c = _c("x", asks: const []);
      c.retitleFromFirstQuestion();
      expect(c.title, "محادثة");
    });

    test('المعاينة تعرض آخر رسالة', () {
      expect(_c("x").preview, contains("جواب عن"));
    });

    test('عدّاد الأسئلة يحسب رسائل الطالب وحدها', () {
      expect(_c("x", asks: const ["أ", "ب", "ج"]).questionCount, 3);
    });
  });

  group('المزامنة', () {
    test('المحفوظ حديثاً غير مُزامَن', () async {
      await SchChatStorage.save(_c("a1"), ownerUid: "ahmed");
      expect(SchChatStorage.pendingSync("ahmed").length, 1);
      await SchChatStorage.markSynced("a1");
      expect(SchChatStorage.pendingSync("ahmed"), isEmpty);
    });

    test('مستند السحابة يعود كما ذهب', () {
      final c = _c("a1");
      final round = SchConversation.fromDoc("a1", c.toDoc());
      expect(round.scholarshipId, "turkey");
      expect(round.messages.length, c.messages.length);
      expect(round.messages.first.text, c.messages.first.text);
      expect(round.synced, isTrue);
    });
  });

  test('المحادثات بلا مالك يتبنّاها أول حساب', () async {
    await SchChatStorage.save(_c("orphan"));   // بلا ownerUid
    expect(SchChatStorage.all("ahmed"), isEmpty);
    await SchChatStorage.adoptOrphans("ahmed");
    expect(SchChatStorage.all("ahmed").single.id, "orphan");
  });
}
