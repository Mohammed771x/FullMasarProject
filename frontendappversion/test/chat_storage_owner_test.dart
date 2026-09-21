// 👤 عزل المحادثات بالحساب: جوّال واحد بحسابين (وزائر) لا يخلط سجلّاتهم.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

const _ahmed = "uid-ahmed";
const _sara = "uid-sara";
const _guest = "uid-guest-anon";

ChatConversation _conv(
  String id, {
  String subject = "احياء",
  String mode = "شرح",
  int grade = 3,
  String track = "علمي",
  String owner = "",
  DateTime? updated,
}) =>
    ChatConversation(
      id: id,
      title: "محادثة $id",
      subject: subject,
      mode: mode,
      grade: grade,
      track: track,
      ownerUid: owner,
      lastUpdated: updated,
      messages: [ChatMessage(role: "user", text: "سؤال")],
    );

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_hive_test');
    await ChatStorage.initForTests(dir.path);
  });

  setUp(() async => ChatStorage.clearAll());
  tearDownAll(() async => dir.delete(recursive: true));

  group('العزل بين الحسابات على الجهاز نفسه', () {
    test('كل حساب يرى محادثاته وحده', () async {
      await ChatStorage.saveConversation(_conv("a1"), ownerUid: _ahmed);
      await ChatStorage.saveConversation(_conv("a2"), ownerUid: _ahmed);
      await ChatStorage.saveConversation(_conv("s1"), ownerUid: _sara);

      expect(ChatStorage.getAllConversations(_ahmed).map((c) => c.id).toSet(), {"a1", "a2"});
      expect(ChatStorage.countForOwner(_ahmed), 2);
      expect(ChatStorage.countForOwner(_sara), 1);
      expect(ChatStorage.getAllConversations(_sara).single.id, "s1");
    });

    test('الزائر سجلّ مستقل تماماً', () async {
      await ChatStorage.saveConversation(_conv("g1"), ownerUid: _guest);
      await ChatStorage.saveConversation(_conv("a1"), ownerUid: _ahmed);

      expect(ChatStorage.getAllConversations(_guest).single.id, "g1");
      expect(ChatStorage.getAllConversations(_ahmed).single.id, "a1");
    });

    test('حساب لا يفتح محادثة حساب آخر ولو عرف معرّفها', () async {
      await ChatStorage.saveConversation(_conv("s1"), ownerUid: _sara);

      expect(ChatStorage.getOwnedConversation("s1", _sara), isNotNull);
      expect(ChatStorage.getOwnedConversation("s1", _ahmed), isNull);
    });

    test('النطاق والمالك يعملان معاً', () async {
      await ChatStorage.saveConversation(_conv("a1", subject: "احياء"), ownerUid: _ahmed);
      await ChatStorage.saveConversation(_conv("a2", subject: "فيزياء"), ownerUid: _ahmed);
      await ChatStorage.saveConversation(_conv("s1", subject: "احياء"), ownerUid: _sara);

      final scope = ChatConversation.buildScopeKey(
          grade: 3, track: "علمي", subject: "احياء", branch: "", mode: "شرح");

      expect(ChatStorage.getConversationsByScope(scope, _ahmed).map((c) => c.id), ["a1"]);
      expect(ChatStorage.getConversationsByScope(scope, _sara).map((c) => c.id), ["s1"]);
      expect(ChatStorage.countInScope(scope, _ahmed), 1);
    });

    test('حساب بلا محادثات يرى قائمة فارغة لا محادثات غيره', () {
      expect(ChatStorage.getAllConversations("uid-new"), isEmpty);
    });
  });

  group('المسح محكوم بالمالك', () {
    test('«مسح محادثاتي» لا يمسّ الحساب الآخر', () async {
      await ChatStorage.saveConversation(_conv("a1"), ownerUid: _ahmed);
      await ChatStorage.saveConversation(_conv("a2"), ownerUid: _ahmed);
      await ChatStorage.saveConversation(_conv("s1"), ownerUid: _sara);

      final removed = await ChatStorage.clearForOwner(_ahmed);

      expect(removed, 2);
      expect(ChatStorage.getAllConversations(_ahmed), isEmpty);
      expect(ChatStorage.getAllConversations(_sara).length, 1);
    });
  });

  group('ترحيل المحادثات القديمة', () {
    test('محادثة بلا مالك لا تظهر لأي حساب قبل التبنّي', () async {
      await ChatStorage.saveConversation(_conv("old1"));   // بلا ownerUid

      expect(ChatStorage.getAllConversations(_ahmed), isEmpty);
      expect(ChatStorage.orphanConversations().length, 1);
    });

    test('التبنّي ينسبها لأول حساب — ولا يلمس محادثات غيره', () async {
      await ChatStorage.saveConversation(_conv("old1"));
      await ChatStorage.saveConversation(_conv("old2"));
      await ChatStorage.saveConversation(_conv("s1"), ownerUid: _sara);

      final adopted = await ChatStorage.adoptOrphans(_ahmed);

      expect(adopted, 2);
      expect(ChatStorage.getAllConversations(_ahmed).length, 2);
      expect(ChatStorage.getAllConversations(_sara).length, 1);
      expect(ChatStorage.orphanConversations(), isEmpty);
    });

    test('التبنّي بمعرّف فارغ لا يفعل شيئاً', () async {
      await ChatStorage.saveConversation(_conv("old1"));
      expect(await ChatStorage.adoptOrphans(""), 0);
      expect(ChatStorage.orphanConversations().length, 1);
    });
  });

  group('بقاء البيانات', () {
    test('المالك يُحفظ ويُقرأ من القرص كما هو', () async {
      await ChatStorage.saveConversation(_conv("a1"), ownerUid: _ahmed);
      expect(ChatStorage.getConversation("a1")!.ownerUid, _ahmed);
    });

    test('حفظ بلا ownerUid لا يمسح المالك القائم', () async {
      await ChatStorage.saveConversation(_conv("a1"), ownerUid: _ahmed);
      final again = ChatStorage.getConversation("a1")!;
      again.title = "عنوان جديد";
      await ChatStorage.saveConversation(again); // بلا تمرير المالك

      expect(ChatStorage.getConversation("a1")!.ownerUid, _ahmed);
      expect(ChatStorage.getAllConversations(_ahmed).single.title, "عنوان جديد");
    });
  });

  // ══════════════════════════════════════════════════
  // ✏️ إعادة التسمية لا تُيتّم المحادثة
  // ══════════════════════════════════════════════════
  // 🔴 **عطلٌ حقيقيّ وقع** (٢٠٢٦-٠٩-٢٠): `renameConversation` كانت تبني
  //    نسخةً جديدة بنسخ الحقول يدوياً، و`ownerUid` ليس فيها — فيأخذ `""`.
  //    وكلُّ استعلامات التخزين محكومةٌ بالمالك، فتختفي المحادثةُ من
  //    القائمة عن كل حساب. وصفَها المالك بأنها «تنحذف».
  //
  // 🛡️ والحارسُ يسأل عن **الأثر** لا عن طريقة التنفيذ: بعد التسمية،
  //    هل ما زالت المحادثةُ في قائمة صاحبها بالاسم الجديد ورسائلها؟
  group('إعادة تسمية المحادثة', () {
    test('⭐ لا تختفي من قائمة صاحبها ولا تفقد رسائلها', () async {
      // 👤 صاحبُ المحادثة **غيرُ** صاحب المتحكّم (وهو `""` في الاختبار)
      //    — وهذا بالضبط ما يكشف العطل: النسخُ اليدويّ كان يستبدل المالك
      //    بالفراغ، والمُصلَحُ يُبقيه كما هو.
      final c = ChatController();
      addTearDown(c.dispose);

      final conv = _conv("r1", owner: _ahmed);
      await ChatStorage.saveConversation(conv);

      expect(ChatStorage.getConversationsByScope(conv.scopeKey, _ahmed).length, 1,
          reason: "قبل التسمية: موجودة");

      await c.renameConversation(conv, "اسمٌ جديد");

      final after = ChatStorage.getConversationsByScope(conv.scopeKey, _ahmed);
      expect(after.length, 1, reason: "بعد التسمية: ما زالت في قائمة صاحبها");
      expect(after.first.title, "اسمٌ جديد");
      expect(after.first.ownerUid, _ahmed, reason: "المالك لم يُمحَ");
      expect(after.first.messages.length, 1, reason: "الرسائل لم تضِع");
    });

    // 🔴 **والاسمُ كان يُمحى عند السؤال التالي.** `saveCurrentConversation`
    //    تشتقّ العنوانَ من `messages.first` في **كل** حفظ — والرسالةُ الأولى
    //    لا تتغيّر، فالمشتقُّ ثابتٌ ويكتب فوق ما سمّاه الطالب: «مراجعة
    //    الفيزياء» تعود «اشرح لي قانون نيوتن» بعد رسالةٍ واحدة.
    //    وُجدت 2026-09-21 وأنا أضيف الزرَّ نفسَه في مساعد المنحة.
    test('⭐ ولا يُمحى الاسمُ عند حفظ الرسالة التالية', () async {
      final c = ChatController();
      addTearDown(c.dispose);

      // 👤 صاحبُها هو صاحبُ المتحكّم هنا (`""`) لأن الحفظَ يقرأ العنوانَ
      //    المخزون **محكوماً بالمالك**.
      final conv = _conv("r3");
      await ChatStorage.saveConversation(conv);
      await c.renameConversation(conv, "مراجعة الفيزياء");

      c.currentConversationId = conv.id;
      c.messages = [
        {"role": "user", "text": "اشرح لي قانون نيوتن"},
        {"role": "ai", "text": "…"},
      ];
      await c.saveCurrentConversation();

      expect(ChatStorage.getConversation(conv.id)?.title, "مراجعة الفيزياء");
    });

    test('والمحادثةُ الجديدة ما زالت تأخذ عنوانَها من أوّل سؤال', () async {
      final c = ChatController();
      addTearDown(c.dispose);

      c.currentConversationId = "r4";
      c.messages = [
        {"role": "user", "text": "ما هو قانون أوم؟"},
        {"role": "ai", "text": "…"},
      ];
      await c.saveCurrentConversation();

      expect(ChatStorage.getConversation("r4")?.title, "ما هو قانون أوم؟");
    });

    test('لا تظهر عند حسابٍ آخر بعد التسمية', () async {
      final c = ChatController();
      addTearDown(c.dispose);

      final conv = _conv("r2", owner: _ahmed);
      await ChatStorage.saveConversation(conv);
      await c.renameConversation(conv, "اسمٌ آخر");

      expect(ChatStorage.getConversationsByScope(conv.scopeKey, _sara), isEmpty);
    });
  });
}