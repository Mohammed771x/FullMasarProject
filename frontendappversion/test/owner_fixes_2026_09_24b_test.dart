// ══════════════════════════════════════════════════
// 🧾 طلباتُ المالك — ٢٠٢٦-٠٩-٢٤ (الدفعة الثانية)
// ══════════════════════════════════════════════════
//
// ① البحثُ كما في ChatGPT: كلُّ موضعٍ ذُكرت فيه الكلمة، بأسطرٍ من مكانها
//    والكلمةُ مظلَّلة — في التعليم والمعلّم والمنح.
// ② اسمُ المحادثة من أول سؤال (والمخزونُ «شرح درس …»).
// ③ شرائحُ المعلّم ٢×٢ متساوية.
// ④ الترحيبُ روبوتٌ في الوسط وكلامٌ بحسب الوضع — والبطاقةُ مطويّة.
// ⑤ «اختبر نفسك» لا سهمَ رجوعٍ فيها وهي تبويب.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ye_student_tutor/core/services/conversation_titler.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/core/widgets/masar_brand.dart';
import 'package:ye_student_tutor/features/chat/data/conversation_search.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_list_view.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';
import 'package:ye_student_tutor/features/teacher/presentation/widgets/teacher_tool_bar.dart';

class _Conv {
  _Conv(this.title, this.messages);
  final String title;
  final List<SearchableMessage> messages;
}

List<SearchHit<_Conv>> _hits(List<_Conv> convs, String q) => searchHits<_Conv>(
      convs,
      q,
      titleOf: (c) => c.title,
      messagesOf: (c) => c.messages,
    );

class _Capture extends http.BaseClient {
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>);
    final done = jsonEncode(
        {"t": "done", "answer": "قانونُ أوم يربط الجهد بالتيار", "references": <String>[]});
    return http.StreamedResponse(
        Stream.value(utf8.encode('data: $done\n\n')), 200,
        request: request);
  }
}

void main() {
  // ══════════════════════════════════════════════════
  // ① البحث
  // ══════════════════════════════════════════════════
  group('📍 نتائجُ البحث', () {
    test('كلُّ رسالةٍ ذُكرت فيها الكلمة — في كل المحادثات، بترتيبها', () {
      final hits = _hits([
        _Conv("الأولى", const [
          SearchableMessage("ما التناضح؟", isUser: true),
          SearchableMessage("التناضح انتقال الماء عبر غشاء.", isUser: false),
        ]),
        _Conv("الثانية", const [
          SearchableMessage("اشرح الانتشار", isUser: true),
          SearchableMessage("يختلف الانتشار عن التناضح في…", isUser: false),
        ]),
      ], "التناضح");
      expect(hits.map((h) => (h.conversation.title, h.messageIndex)), [
        ("الأولى", 0),
        ("الأولى", 1),
        ("الثانية", 1),
      ]);
      expect(hits[0].isUser, isTrue);
      expect(hits[1].isUser, isFalse);
    });

    test('🎯 الكلمةُ المظلَّلة هي الكلمةُ في النصّ الأصليّ — رغم التشكيل', () {
      final hits = _hits([
        _Conv("ت", const [
          SearchableMessage("قالَ المعلّمُ: الأَكسدةُ فقدانُ إلكترونات", isUser: false),
        ]),
      ], "الاكسده");
      expect(hits.single.match, "الأَكسدةُ",
          reason: 'كان المؤشّرُ يُقاس على النصّ المطبَّع فينزاح بالتشكيل');
      expect(hits.single.before.endsWith("المعلّمُ: "), isTrue);
      expect(hits.single.after.startsWith(" فقدانُ"), isTrue);
    });

    test('📏 «كم سطر» حول الكلمة — مقصوصٌ على حدّ كلمة، بعلامة قصّ', () {
      final long = "${List.filled(40, "كلمة").join(" ")} الهدف "
          "${List.filled(60, "بعد").join(" ")}";
      final h = _hits([_Conv("ت", [SearchableMessage(long, isUser: false)])],
              "الهدف")
          .single;
      expect(h.before.startsWith("…"), isTrue);
      expect(h.after.endsWith("…"), isTrue);
      expect(h.before.length,
          lessThanOrEqualTo(ConversationSearchHits.contextBefore + 2));
      expect(h.after.length,
          lessThanOrEqualTo(ConversationSearchHits.contextAfter + 2));
      expect(h.before.contains("كل "), isFalse, reason: 'لا نصفَ كلمة');
    });

    test('🔢 «٤٥» تجد «45» والعكس — والمظلَّلُ رقمُ النصّ نفسُه', () {
      expect(ConversationSearch.normalize("٤٥ دقيقة"),
          ConversationSearch.normalize("45 دقيقة"));
      expect(ConversationSearch.normalize("۴۵"), "45");
      final h = _hits([
        _Conv("ت", const [SearchableMessage("الحصة 45 دقيقة", isUser: false)]),
      ], "٤٥").single;
      expect(h.match, "45");
    });

    test('🧹 لا ماركداون خاماً في المقتطف', () {
      final h = _hits([
        _Conv("ت", const [
          SearchableMessage("## العنوان\n**2. العرض** والنشاط `كود` الحصة **مهمة**",
              isUser: false),
        ]),
      ], "الحصة").single;
      expect("${h.before}${h.match}${h.after}", isNot(contains("*")));
      expect("${h.before}${h.after}", isNot(contains("#")));
      expect("${h.before}${h.after}", isNot(contains("`")));
    });

    test('محادثةٌ واحدة لا تبتلع القائمة', () {
      final many = _Conv("كثيرة", [
        for (var i = 0; i < 30; i++)
          const SearchableMessage("الخلية", isUser: false),
      ]);
      expect(_hits([many], "الخلية").length,
          ConversationSearchHits.maxHitsPerConversation);
    });

    test('🏷️ في الاسم وحده ⇒ نتيجةٌ بلا رسالة', () {
      final h = _hits([
        _Conv("مراجعة الفيزياء", const [
          SearchableMessage("سؤال", isUser: true),
        ]),
      ], "الفيزياء").single;
      expect(h.messageIndex, -1);
      expect(h.match, "الفيزياء");
    });

    test('استعلامٌ فارغ ⇒ لا نتائج', () {
      expect(_hits([_Conv("أ", const [])], "  "), isEmpty);
    });
  });

  // ══════════════════════════════════════════════════
  // ② اسمُ المحادثة
  // ══════════════════════════════════════════════════
  group('🏷️ اسمُ المحادثة', () {
    test('لحظةُ التسمية: أولُ سؤالٍ وأولُ جوابٍ — لا قبل ولا بعد', () {
      expect(ConversationTitler.shouldName([{"role": "user"}]), isFalse);
      expect(
          ConversationTitler.shouldName([
            {"role": "user"},
            {"role": "ai"}
          ]),
          isTrue);
      expect(
          ConversationTitler.shouldName([
            {"role": "user"},
            {"role": "ai"},
            {"role": "user"},
            {"role": "ai"}
          ]),
          isFalse);
    });

    test('لا يُكتب فوق اسمٍ اختاره صاحبُ المحادثة', () {
      expect(ConversationTitler.applies("اشرح لي…", "اشرح لي…"), isTrue);
      expect(ConversationTitler.applies("محادثة جديدة", "x"), isTrue);
      expect(ConversationTitler.applies("مراجعتي", "اشرح لي…"), isFalse);
    });

    test('المخزونُ «شرح درس …»', () {
      expect(ConversationTitler.storedLessonTitle("الخلية العصبية"),
          "شرح درس الخلية العصبية");
    });

    group('في المتحكّم', () {
      late Directory dir;
      setUpAll(() async {
        dir = await Directory.systemTemp.createTemp('masar_title');
        await ChatStorage.initForTests(dir.path);
      });
      setUp(() async => ChatStorage.clearAll());
      tearDown(() => ConversationTitler.debugOverride = null);
      tearDownAll(() async => dir.delete(recursive: true));

      ChatController student(_Capture client) =>
          ChatController(askStream: AskStream(client))
            ..selectedSubject = "فيزياء"
            ..selectedMode = "سؤال"
            ..contentMode = "lessons"
            ..selectedV3Unit = "الكهرباء"
            ..selectedV3Lesson = "قانون أوم"
            ..currentConversationId = "c1";

      test('بعد أول جواب ⇒ اسمٌ من الموديل، مرّةً واحدة', () async {
        final asked = <String>[];
        ConversationTitler.debugOverride = (q, a, s, section) async {
          asked.add("$q|$section");
          return "قانون أوم والمقاومة";
        };
        final c = student(_Capture());
        addTearDown(c.dispose);
        c.inputController.text = "ما علاقة الجهد بالتيار؟";
        await c.processRequest();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ChatStorage.getOwnedConversation("c1", c.ownerUid)!.title,
            "قانون أوم والمقاومة");
        expect(asked, ["ما علاقة الجهد بالتيار؟|education"]);

        c.inputController.text = "وما وحدة المقاومة؟";
        await c.processRequest();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(asked, hasLength(1), reason: 'أول سؤالٍ فقط');
      });

      test('فشلُ التسمية يُبقي الاسمَ المؤقّت', () async {
        ConversationTitler.debugOverride = (_, _, _, _) async => null;
        final c = student(_Capture());
        addTearDown(c.dispose);
        c.inputController.text = "ما علاقة الجهد بالتيار؟";
        await c.processRequest();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ChatStorage.getOwnedConversation("c1", c.ownerUid)!.title,
            "ما علاقة الجهد بالتيار؟");
      });

      test('📖 الشرحُ المخزون ⇒ «شرح درس …» بلا نداء', () async {
        var called = false;
        ConversationTitler.debugOverride = (_, _, _, _) async {
          called = true;
          return "لا";
        };
        final c = student(_Capture())
          ..messages = <Map<String, dynamic>>[
            {"role": "user", "text": "شرح درس: قانون أوم"},
            {"role": "ai", "text": "الشرح…", "cached": true},
          ];
        addTearDown(c.dispose);
        await c.saveCurrentConversation();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(called, isFalse);
        expect(ChatStorage.getOwnedConversation("c1", c.ownerUid)!.title,
            "شرح درس قانون أوم");
      });

      test('اسمٌ اختاره الطالب أثناء الانتظار لا يُمحى', () async {
        ChatController? ctl;
        ConversationTitler.debugOverride = (_, _, _, _) async {
          final conv = ChatStorage.getOwnedConversation("c1", ctl!.ownerUid)!;
          await ctl.renameConversation(conv, "مراجعتي");
          return "اسم الموديل";
        };
        final c = student(_Capture());
        ctl = c;
        addTearDown(c.dispose);
        c.inputController.text = "سؤال";
        await c.processRequest();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ChatStorage.getOwnedConversation("c1", c.ownerUid)!.title,
            "مراجعتي");
      });
    });
  });

  // ══════════════════════════════════════════════════
  // ③ شرائحُ المعلّم ٢×٢
  // ══════════════════════════════════════════════════
  testWidgets('🔲 أدواتُ المعلّم أربعُ خلايا متساويةِ العرض', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 316,
              child: TeacherToolChips(
                  selected: TeacherTool.ask, onTap: (_) {}),
            ),
          ),
        ),
      ),
    ));
    final widths = [
      for (final t in TeacherToolX.bar)
        tester.getSize(find.ancestor(
                of: find.text(t.chipLabel),
                matching: find.byType(AnimatedContainer))
            .first).width,
    ];
    expect(widths.toSet(), hasLength(1), reason: 'عرضٌ واحد: $widths');
    // صفّان: الأولى والثانية في صفٍّ واحد.
    final y = [
      for (final t in TeacherToolX.bar) tester.getCenter(find.text(t.chipLabel)).dy
    ];
    expect(y[0], y[1]);
    expect(y[2], y[3]);
    expect(y[2], greaterThan(y[0]));

    // 📐 «الأيقونات فوق بعض» — أيقونتا كل عمودٍ على خطٍّ رأسيٍّ واحد مهما
    //    اختلف طولُ النصّ بعدها.
    double iconX(TeacherTool t) => tester
        .getCenter(find
            .ancestor(
                of: find.text(t.chipLabel),
                matching: find.byType(AnimatedContainer))
            .first)
        .dx;
    double boxX(TeacherTool t) {
      final chip = find
          .ancestor(
              of: find.text(t.chipLabel),
              matching: find.byType(AnimatedContainer))
          .first;
      final box = find.descendant(
          of: chip,
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.constraints?.maxWidth == TeacherToolBar.iconBox));
      return tester.getCenter(box).dx;
    }
    expect(iconX(TeacherTool.lessonPlan), iconX(TeacherTool.simplify));
    expect(boxX(TeacherTool.lessonPlan), boxX(TeacherTool.simplify));
    expect(boxX(TeacherTool.homework), boxX(TeacherTool.ask));
  });

  // ══════════════════════════════════════════════════
  // ④ الترحيب
  // ══════════════════════════════════════════════════
  group('🤖 الترحيب', () {
    Future<void> pumpWelcome(WidgetTester tester, ChatController c) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ChatListView(controller: c)),
        ),
      ));
      await tester.pump();
    }

    testWidgets('البطاقةُ مطويّةٌ عند الدخول', (tester) async {
      final c = ChatController();
      addTearDown(c.dispose);
      expect(c.showSettingsPanel, isFalse);
    });

    for (final (mode, word) in [
      ("شرح", "وأشرحه لك"),
      ("تلخيص", "وألخّصه لك"),
      ("سؤال", "اكتب سؤالك"),
      ("وزاري", "أسئلة الوزارة"),
    ]) {
      testWidgets('نصُّ «$mode» يقول ماذا يفعل الآن — والروبوتُ ثابت', (tester) async {
        final c = ChatController()
          ..selectedSubject = "احياء"
          ..selectedMode = mode;
        addTearDown(c.dispose);
        await pumpWelcome(tester, c);
        expect(find.textContaining(word), findsOneWidget);
        expect(find.textContaining("إعدادات الجلسة"), findsOneWidget);
        expect(find.text("احياء · $mode"), findsOneWidget);
        // 🧍 «لا تحرّك الروبوت» — صورةٌ ساكنة، لا نسخةَ متحرّكة.
        expect(find.byType(MasarRobotAnimated), findsNothing);
        expect(find.byType(MasarRobot), findsOneWidget);
      });
    }

    testWidgets('والمعلّمُ بحسب أداته', (tester) async {
      final c = ChatController()
        ..teacherTool = TeacherTool.simplify
        ..selectedMode = "معلم:simplify"
        ..selectedSubject = "احياء";
      addTearDown(c.dispose);
      await pumpWelcome(tester, c);
      expect(find.text("مساعد المعلم الذكي"), findsOneWidget);
      expect(find.textContaining("المفهوم الذي يتعثّر فيه طلابك"), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑤ لا سهمَ رجوعٍ في تبويب «اختبر نفسك»
  // ══════════════════════════════════════════════════
  test('↩️ السهمُ يسأل مسارَ الشاشة لا الملّاحَ كلَّه', () {
    final src = File('lib/features/quiz/presentation/quiz_setup_screen.dart')
        .readAsStringSync();
    expect(src, contains('ModalRoute.of(context)?.isFirst == false'));
    expect(src, isNot(contains('Navigator.of(context).canPop()')),
        reason: 'كان يُظهر سهماً يُسقط القشرة فتسودّ الشاشة');
  });
}
