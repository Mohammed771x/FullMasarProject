// ══════════════════════════════════════════════════
// 🧾 طلباتُ المالك — ٢٠٢٦-٠٩-٢٤
// ══════════════════════════════════════════════════
//
// ① لكل محادثةٍ درسُها: تغييرُه (أو إضافةُ صفحةٍ من خارجها) يسأل
//    «نفتح محادثةً جديدة؟» — للقسمين.
// ② كل محادثةٍ تعود بدرسها وصفحاتها — والمعلّمُ كان لا يعود بشيء.
// ③ «تبسيط مفهوم»: المفهومُ أولُ رسالةٍ لا حقلٌ في الإعدادات.
// ④ البحثُ لا يعبر بين المعلّم والطالب.
// ⑤ البانراتُ الرسمية لا تغيب — فلا فراغَ تحت الرئيسية.
//
// ⚠️ اختباراتُ المتحكّم `test` لا `testWidgets`: الحفظُ يكتب في Hive،
//    وكتابةُ القرص تحت الزمن الوهمي لا تنتهي ([masar-testing-traps]).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/banners/data/banner_model.dart';
import 'package:ye_student_tutor/features/banners/data/banner_repository.dart';
import 'package:ye_student_tutor/features/banners/presentation/banner_carousel.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';

/// عميلٌ يلتقط جسمَ كل طلبٍ ويردّ بثّاً قصيراً — بلا شبكة.
class _Capture extends http.BaseClient {
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>);
    final done = jsonEncode(
        {"t": "done", "answer": "الجواب", "references": <String>[]});
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: $done\n\n')),
      200,
      request: request,
    );
  }
}

SubjectCapabilities _caps() => SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {
        "available": true,
        "units": [
          {
            "unit": "الجهاز العصبي",
            "lessons": ["الخلية العصبية", "السيال العصبي"]
          },
          {
            "unit": "الغدد",
            "lessons": ["الغدة الدرقية"]
          },
        ],
      },
      "pages": {
        "available": true,
        "units": ["الجهاز العصبي", "الغدد"],
        "unit_pages": {
          "الجهاز العصبي": [9, 10, 11, 12],
          "الغدد": [30, 31],
        },
        "max_selectable": 3,
      },
    });

/// طالبٌ في وضع الدروس ودرسُه مختار.
ChatController _student({_Capture? client}) => ChatController(
      askStream: client == null ? null : AskStream(client),
    )
      ..selectedSubject = "احياء"
      ..selectedMode = "شرح"
      ..contentMode = "lessons"
      ..caps = _caps()
      ..selectedV3Unit = "الجهاز العصبي"
      ..selectedV3Lesson = "الخلية العصبية"
      ..currentConversationId = "conv-1";

/// طالبٌ في وضع الصفحات.
ChatController _pagesStudent({_Capture? client}) => ChatController(
      askStream: client == null ? null : AskStream(client),
    )
      ..selectedSubject = "احياء"
      ..selectedMode = "شرح"
      ..contentMode = "pages"
      ..caps = _caps()
      ..selectedUnit = "الجهاز العصبي"
      ..inputType = "صفحة"
      ..currentConversationId = "conv-p";

ChatController _teacher(TeacherTool tool, {_Capture? client}) =>
    ChatController(askStream: client == null ? null : AskStream(client))
      ..teacherTool = tool
      ..selectedMode = "معلم:${tool.id}"
      ..selectedSubject = "احياء"
      ..contentMode = "lessons"
      ..caps = _caps()
      ..selectedV3Unit = "الجهاز العصبي"
      ..selectedV3Lesson = "الخلية العصبية"
      ..currentConversationId = "conv-t";

void _started(ChatController c) => c.messages = <Map<String, dynamic>>[
      {"role": "user", "text": "اشرح"},
      {"role": "ai", "text": "شرحٌ"},
    ];

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_0924');
    await ChatStorage.initForTests(dir.path);
  });
  setUp(() async => ChatStorage.clearAll());
  tearDownAll(() async => dir.delete(recursive: true));

  // ══════════════════════════════════════════════════
  // ① لكل محادثةٍ درسُها
  // ══════════════════════════════════════════════════
  group('🔒 تغييرُ الدرس في محادثةٍ بدأت', () {
    test('محادثةٌ لم تبدأ ⇒ يتغيّر في مكانه بلا سؤال', () async {
      final c = _student();
      addTearDown(c.dispose);
      var asked = 0;
      c.onConfirmNewConversation = (_) async {
        asked++;
        return true;
      };
      await c.setV3Lesson("السيال العصبي");
      expect(asked, 0);
      expect(c.selectedV3Lesson, "السيال العصبي");
      expect(c.currentConversationId, "conv-1");
    });

    test('«ابقَ هنا» ⇒ لا يُمسّ شيء: الدرسُ والرسائلُ والمعرّف', () async {
      final c = _student();
      addTearDown(c.dispose);
      _started(c);
      ContextChange? seen;
      c.onConfirmNewConversation = (change) async {
        seen = change;
        return false;
      };
      await c.setV3Lesson("السيال العصبي");
      expect(seen, ContextChange.lesson);
      expect(c.selectedV3Lesson, "الخلية العصبية");
      expect(c.messages, hasLength(2));
      expect(c.currentConversationId, "conv-1");
    });

    test('«محادثة جديدة» ⇒ معرّفٌ جديد، فارغة، وبالدرس الجديد', () async {
      final c = _student();
      addTearDown(c.dispose);
      _started(c);
      c.onConfirmNewConversation = (_) async => true;
      await c.setV3Lesson("السيال العصبي");
      expect(c.selectedV3Lesson, "السيال العصبي");
      expect(c.messages, isEmpty);
      expect(c.currentConversationId, isNot("conv-1"));
      // 💾 والقديمةُ حُفظت بدرسها قبل المغادرة.
      final old = ChatStorage.getOwnedConversation("conv-1", c.ownerUid);
      expect(old?.lesson, "الخلية العصبية");
    });

    test('تبديلُ الوحدة يُسقط الدرس — فهو تغييرُ درسٍ يُسأل عنه', () async {
      final c = _student();
      addTearDown(c.dispose);
      _started(c);
      ContextChange? seen;
      c.onConfirmNewConversation = (change) async {
        seen = change;
        return false;
      };
      await c.setV3Unit("الغدد");
      expect(seen, ContextChange.lesson);
      expect(c.selectedV3Unit, "الجهاز العصبي");
    });

    test('تبديلُ مصدر المحتوى في محادثةٍ بدأت يُسأل عنه', () async {
      final c = _student();
      addTearDown(c.dispose);
      _started(c);
      ContextChange? seen;
      c.onConfirmNewConversation = (change) async {
        seen = change;
        return false;
      };
      await c.setContentMode("pages");
      expect(seen, ContextChange.contentMode);
      expect(c.contentMode, "lessons");
    });

    test('بلا شاشةٍ تُسأل ⇒ القاعدةُ قائمة: محادثةٌ جديدة لا تغييرٌ في مكانه',
        () async {
      final c = _student();
      addTearDown(c.dispose);
      _started(c);
      await c.setV3Lesson("السيال العصبي");
      expect(c.messages, isEmpty);
      expect(c.currentConversationId, isNot("conv-1"));
    });

    test('👨‍🏫 والمعلّمُ كذلك', () async {
      final c = _teacher(TeacherTool.lessonPlan);
      addTearDown(c.dispose);
      _started(c);
      var asked = 0;
      c.onConfirmNewConversation = (_) async {
        asked++;
        return false;
      };
      await c.setV3Lesson("السيال العصبي");
      expect(asked, 1);
      expect(c.selectedV3Lesson, "الخلية العصبية");
    });

    test('«اسأل المساعد» بدأت بلا درس ⇒ أولُ درسٍ يُختار في مكانه', () async {
      final c = _teacher(TeacherTool.ask)..selectedV3Lesson = "";
      addTearDown(c.dispose);
      _started(c);
      var asked = 0;
      c.onConfirmNewConversation = (_) async {
        asked++;
        return true;
      };
      await c.setV3Lesson("السيال العصبي");
      expect(asked, 0);
      expect(c.selectedV3Lesson, "السيال العصبي");
      expect(c.messages, hasLength(2));
    });
  });

  group('📄 صفحاتُ المحادثة: تُحدَّث ولا يُضاف إليها', () {
    test('أولُ إرسالٍ بصفحاتٍ يثبّتها صفحاتٍ للمحادثة', () async {
      final client = _Capture();
      final c = _pagesStudent(client: client);
      addTearDown(c.dispose);
      c.addPage(9);
      c.addPage(10);
      await c.processRequest();
      expect(client.bodies.single["selected_pages"], [9, 10]);
      expect(c.conversationPages, [9, 10]);
    });

    test('إزالةُ صفحةٍ وإعادتُها حرّة — وصفحةٌ جديدة تُسأل عنها', () async {
      final client = _Capture();
      final c = _pagesStudent(client: client);
      addTearDown(c.dispose);
      c.addPage(9);
      c.addPage(10);
      await c.processRequest();

      var asked = <ContextChange>[];
      c.onConfirmNewConversation = (change) async {
        asked.add(change);
        return false;
      };
      c.removePage(10);
      expect(c.addPage(10), isNull);
      expect(c.selectedPages, [9, 10]);
      expect(asked, isEmpty, reason: 'الصفحةُ من صفحات المحادثة');

      expect(c.addPage(11), isNull, reason: 'لا رسالةَ رفض — السؤالُ حوار');
      await Future<void>.delayed(Duration.zero);
      expect(asked, [ContextChange.pages]);
      expect(c.selectedPages, [9, 10], reason: '«ابقَ هنا» لا يُضيفها');
    });

    test('«محادثة جديدة» ⇒ الصفحاتُ المختارة مع الجديدة', () async {
      final client = _Capture();
      final c = _pagesStudent(client: client);
      addTearDown(c.dispose);
      c.addPage(9);
      await c.processRequest();
      final firstId = c.currentConversationId;

      c.onConfirmNewConversation = (_) async => true;
      c.addPage(11);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.currentConversationId, isNot(firstId));
      expect(c.messages, isEmpty);
      expect(c.selectedPages, [9, 11]);
      expect(c.conversationPages, isEmpty, reason: 'تثبت مع أول إرسال');
    });

    test('تبديلُ وحدة الصفحات في محادثةٍ بدأت يُسأل عنه', () async {
      final c = _pagesStudent();
      addTearDown(c.dispose);
      _started(c);
      ContextChange? seen;
      c.onConfirmNewConversation = (change) async {
        seen = change;
        return false;
      };
      await c.setPageUnit("الغدد");
      expect(seen, ContextChange.unit);
      expect(c.selectedUnit, "الجهاز العصبي");
    });
  });

  // ══════════════════════════════════════════════════
  // ② كلُّ محادثةٍ تعود بدرسها وصفحاتها
  // ══════════════════════════════════════════════════
  group('🧭 الاستعادة', () {
    test('👨‍🏫 محادثةُ المعلّم تُحفظ بوحدة الدروس وتعود بدرسها', () async {
      final client = _Capture();
      final c = _teacher(TeacherTool.lessonPlan, client: client)
        ..selectedV3Unit = "الغدد"
        ..selectedV3Lesson = "الغدة الدرقية";
      addTearDown(c.dispose);
      await c.generateTeacher();
      final saved =
          ChatStorage.getOwnedConversation(c.currentConversationId!, c.ownerUid)!;
      expect(saved.unit, "الغدد", reason: 'كان يُحفظ selectedUnit الفارغ');
      expect(saved.lesson, "الغدة الدرقية");

      // المعلّمُ تنقّل إلى درسٍ آخر في محادثةٍ جديدة، ثم عاد إليها.
      await c.createNewConversation();
      c
        ..selectedV3Unit = "الجهاز العصبي"
        ..selectedV3Lesson = "الخلية العصبية";
      await c.loadConversation(saved);
      expect(c.selectedV3Unit, "الغدد");
      expect(c.selectedV3Lesson, "الغدة الدرقية");
    });

    test('محادثةٌ بلا درسٍ محفوظ لا ترث درسَ الشاشة', () async {
      final c = _student();
      addTearDown(c.dispose);
      await c.loadConversation(ChatConversation(
        id: "old",
        title: "قديمة",
        subject: "احياء",
        mode: "شرح",
        contentMode: "lessons",
        messages: [
          ChatMessage(role: "user", text: "س", timestamp: DateTime(2026)),
        ],
      ));
      expect(c.selectedV3Lesson, isEmpty,
          reason: 'وإلا أُرسلت رسالتُه التالية باسم درسٍ غريب');
    });

    test('📄 محادثةُ الصفحات تعود بصفحاتها', () async {
      final c = _pagesStudent()..selectedPages.clear();
      addTearDown(c.dispose);
      c.inputType = "برومت";
      await c.loadConversation(ChatConversation(
        id: "pg",
        title: "صفحات",
        subject: "احياء",
        mode: "شرح",
        contentMode: "pages",
        unit: "الجهاز العصبي",
        pages: const [9, 11, 99],
        messages: [
          ChatMessage(role: "user", text: "اشرح", timestamp: DateTime(2026)),
        ],
      ));
      expect(c.inputType, "صفحة");
      expect(c.selectedPages, [9, 11], reason: '99 ليست في الوحدة فتسقط');
      expect(c.conversationPages, [9, 11, 99]);
    });

    test('🗄️ الصفحاتُ تسافر في JSON — ومستندٌ قديمٌ يُقرأ بلا صفحات', () {
      final conv = ChatConversation(
          id: "x", title: "t", subject: "احياء", mode: "شرح", pages: const [3, 4]);
      final back = ChatConversation.fromJson(conv.toJson());
      expect(back.pages, [3, 4]);
      final legacy = conv.toJson()..remove('pages');
      expect(ChatConversation.fromJson(legacy).pages, isEmpty);
      expect(ChatConversation.pagesFrom(["1", -2, 5]), [5]);
      // 📏 الحدُّ ٣ — كالخادم وقاعدة Firestore.
      expect(ChatConversation.pagesFrom([1, 2, 3, 4, 5]), [1, 2, 3]);
    });
  });

  // ══════════════════════════════════════════════════
  // ③ المفهومُ أولُ رسالة
  // ══════════════════════════════════════════════════
  group('💡 «تبسيط مفهوم»: المفهومُ في الرسالة', () {
    test('لا زرَّ توليد للتبسيط — وللخطة والواجب وحدهما', () {
      expect(TeacherTool.simplify.hasGenerateButton, isFalse);
      expect(TeacherTool.simplify.conceptFromMessage, isTrue);
      expect(TeacherTool.lessonPlan.hasGenerateButton, isTrue);
      expect(TeacherTool.homework.hasGenerateButton, isTrue);
      expect(TeacherTool.ask.hasGenerateButton, isFalse);
      // والخادمُ ما زال يولّد للتبسيط — البابُ وحده تغيّر.
      expect(TeacherTool.simplify.hasGenerate, isTrue);
    });

    test('أولُ رسالةٍ تمضي توليداً منسّقاً، والثانيةُ محادثةٌ عادية', () async {
      final client = _Capture();
      final c = _teacher(TeacherTool.simplify, client: client);
      addTearDown(c.dispose);
      expect(c.awaitingTeacherConcept, isTrue);
      expect(c.sendBlocker, isNull);

      c.inputController.text = "  قاعدة لوشاتيليه ";
      await c.processRequest();
      final first = client.bodies.single;
      expect(first["generate"], isTrue);
      expect(first["concept"], "قاعدة لوشاتيليه");
      expect(first["content"], "");
      expect(c.messages.first["text"],
          "بسّط مفهوم «قاعدة لوشاتيليه» من درس «الخلية العصبية»");
      expect(c.awaitingTeacherConcept, isFalse);

      c.inputController.text = "أعطني تشبيهاً آخر";
      await c.processRequest();
      final second = client.bodies.last;
      expect(second["generate"], isFalse);
      expect(second["content"], "أعطني تشبيهاً آخر");
    });

    test('المفهومُ بلا درسٍ يُردّ عند البوّابة — لا طلبَ يُرسل', () async {
      final client = _Capture();
      final c = _teacher(TeacherTool.simplify, client: client)
        ..selectedV3Lesson = "";
      addTearDown(c.dispose);
      String? blocked;
      c.onSendBlocked = (r) => blocked = r;
      c.inputController.text = "الاشتقاق الضمني";
      await c.processRequest();
      expect(blocked, isNotNull);
      expect(client.bodies, isEmpty);
    });

    test('المفهومُ يُقصّ عند سقف الخادم', () async {
      final client = _Capture();
      final c = _teacher(TeacherTool.simplify, client: client);
      addTearDown(c.dispose);
      c.inputController.text = "م" * 500;
      await c.processRequest();
      expect((client.bodies.single["concept"] as String).length,
          ChatController.maxConceptChars);
    });

    test('محادثةٌ جديدة تنسى مفهومَ سابقتها', () async {
      final c = _teacher(TeacherTool.simplify);
      addTearDown(c.dispose);
      c.conceptController.text = "قديم";
      await c.createNewConversation();
      expect(c.conceptController.text, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════
  // ④ البحثُ لا يعبر بين الدورين
  // ══════════════════════════════════════════════════
  group('🔎 فتحُ نتيجة بحث', () {
    test('محادثةُ معلّمٍ لا تُفتح في شاشة الطالب', () async {
      final c = _student();
      addTearDown(c.dispose);
      await c.openFromSearch(ChatConversation(
          id: "t1", title: "خطة", subject: "احياء", mode: "معلم:plan"));
      expect(c.selectedMode, "شرح");
      expect(c.currentConversationId, "conv-1");
    });

    test('ونتيجةٌ من أداةٍ أخرى تنقل المعلّمَ إلى أداتها', () async {
      final c = _teacher(TeacherTool.lessonPlan);
      addTearDown(c.dispose);
      await c.openFromSearch(ChatConversation(
          id: "t2",
          title: "واجب",
          subject: "احياء",
          mode: "معلم:homework"));
      expect(c.teacherTool, TeacherTool.homework);
      expect(c.selectedMode, "معلم:homework");
      expect(c.currentConversationId, "t2");
    });
  });

  // ══════════════════════════════════════════════════
  // ⑤ البانراتُ الرسمية
  // ══════════════════════════════════════════════════
  group('🎏 البانراتُ الرسمية', () {
    testWidgets('بلا بانرات لوحة (زائرٌ بلا شبكة) ⇒ الرسميةُ تملأ المكان',
        (tester) async {
      BannerRepository.I.seed(const {});
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: BannerCarousel(
              section: BannerSection.home,
              onAction: (_, _) {},
              pinned: const [
                AppBanner(id: 'pinned:quiz', title: 'اختبر نفسك', action: 'quiz'),
                AppBanner(id: 'pinned:sch', title: 'المنح', action: 'scholarships'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('اختبر نفسك'), findsOneWidget);
      expect(tester.getSize(find.byType(PageView)).height, 106);
    });

    testWidgets('قسمٌ له بانرٌ في اللوحة لا يُكرَّر ببانرٍ رسميّ', (tester) async {
      BannerRepository.I.seed(const {
        BannerSection.home: [
          AppBanner(id: 'r1', title: 'منحة تركيا', action: 'scholarships'),
        ],
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BannerCarousel(
            section: BannerSection.home,
            onAction: (_, _) {},
            pinned: const [
              AppBanner(id: 'pinned:sch', title: 'المنح', action: 'scholarships'),
              AppBanner(id: 'pinned:quiz', title: 'اختبر نفسك', action: 'quiz'),
            ],
          ),
        ),
      ));
      await tester.pump();
      // نقطتان = بانران: بانرُ اللوحة للمنح، والرسميُّ للاختبار وحده.
      final dots = find.byType(AnimatedContainer);
      expect(dots, findsNWidgets(2));
    });

    testWidgets('بلا بانراتٍ أصلاً ⇒ لا مساحة', (tester) async {
      BannerRepository.I.seed(const {});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BannerCarousel(
              section: BannerSection.home, onAction: (_, _) {}),
        ),
      ));
      expect(find.byType(PageView), findsNothing);
    });
  });
}
