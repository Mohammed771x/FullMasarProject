// 👤 عزل المحادثات بالحساب: جوّال واحد بحسابين (وزائر) لا يخلط سجلّاتهم.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';

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
}
