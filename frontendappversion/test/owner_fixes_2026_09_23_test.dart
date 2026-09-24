// ══════════════════════════════════════════════════
// 🧾 تعديلاتُ المالك (٢٠٢٦-٠٩-٢٣) — التوثيقُ وقسمُ التعليم
// ══════════════════════════════════════════════════
// كلُّ مجموعةٍ هنا تحرس بنداً من رسالةٍ واحدة، وكلٌّ منها كُتب ليسقط
// لو عادت العلّةُ التي جاء لإصلاحها:
//
//   ① «Cancel» في نافذة جوجل كان يُدخل الزائرَ باسم «طالب مسار».
//   ② خمسُ محاولاتٍ خاطئة ثم تهدئةٌ تتضاعف — ولا تُصفَّر بإغلاق التطبيق.
//   ③ شرائحُ الأوضاع تملأ عرضَ البطاقة على كل جوال.
//   ④ عددُ القطع مِعدادٌ لا حقلَ كتابة (فلا كيبوردَ يطوي البطاقة).
//   ⑤ نقرةٌ على المحادثة تُنزل الكيبورد — والسحبُ لا.
//   ⑥ لا إرسالَ قبل أن يكتمل الاختيار — في كل وضع.
//   ⑦ لكل وضعٍ محادثتُه: العودةُ إلى «سؤال» لا تكتب فوق «وزاري».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/auth/auth_repository.dart';
import 'package:ye_student_tutor/core/auth/login_throttle.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/core/utils/safe_cut.dart';
import 'package:ye_student_tutor/core/widgets/typewriter_text.dart';
import 'package:ye_student_tutor/core/widgets/count_stepper.dart';
import 'package:ye_student_tutor/core/widgets/filled_wrap.dart';
import 'package:ye_student_tutor/core/widgets/tap_to_dismiss_keyboard.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';

// ══════════════════════════════════════════════════
// 🧪 بدائلُ الشبكة
// ══════════════════════════════════════════════════

/// جوجل يُلغى — كما يضغط الطالب «Cancel» في نافذة الآيفون.
class _CancellingAuth extends AuthRepository {
  @override
  Future<GoogleAuthResult> signInWithGoogle() async =>
      const GoogleAuthResult.cancelled();
}

/// محتوى ثابتٌ بلا رحلة شبكة.
class _Content extends TutorContentRepository {
  @override
  Future<SubjectCapabilities> getCapabilities(
          String subject, int grade, String track) async =>
      SubjectCapabilities(
        subject: subject,
        lessonsAvailable: true,
        pagesAvailable: true,
        lessonsUnits: const [
          LessonsUnit(unit: "الوحدة", lessons: ["الدرس"]),
        ],
        pagesUnits: const ["الوحدة"],
      );

  @override
  Future<List<String>> getUnits(String subject, int grade, String track) async =>
      const ["الوحدة"];

  @override
  Future<List<String>> getExamYears(String subject, int grade, String track) async =>
      const ["2019", "2020"];

  @override
  Future<String> getStoredExplanation(String subject, String unit, String lesson,
          int grade, String track) async =>
      "";
}

/// شبكةٌ مقطوعة: كلُّ طلبٍ يرمي فوراً — لا ينتظر اختبارٌ خادماً حقيقياً.
class _NoNetwork extends http.BaseClient {
  int calls = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    throw const SocketException('offline (test)');
  }
}

ChatController _student({_NoNetwork? net}) => ChatController(
      contentRepository: _Content(),
      askStream: AskStream(net ?? _NoNetwork()),
    )
      ..selectedSubject = "احياء"
      ..selectedMode = "شرح";

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('owner_fixes_2026_09_23');
    await ChatStorage.initForTests(dir.path);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChatStorage.clearAll();
  });
  tearDownAll(() async => dir.delete(recursive: true));

  // ══════════════════════════════════════════════════
  // ① جوجل — الإلغاءُ ليس دخولاً
  // ══════════════════════════════════════════════════
  group('① Cancel في نافذة جوجل', () {
    test('النتيجةُ ثلاثُ حالاتٍ متمايزة', () {
      const ok = GoogleAuthResult.signedIn();
      const no = GoogleAuthResult.cancelled();
      const bad = GoogleAuthResult.failed("خطأ");
      expect([ok.signedIn, ok.cancelled, ok.error], [true, false, null]);
      expect([no.signedIn, no.cancelled, no.error], [false, true, null]);
      expect([bad.signedIn, bad.cancelled, bad.error], [false, false, "خطأ"]);
    });

    test('☢️ زائرٌ يُلغي ⇒ يبقى زائراً باسمه — لا «طالب مسار»', () async {
      final s = UserSession.I;
      UserSession.overrideRepositories(auth: _CancellingAuth());
      s.isGuest = true;
      s.name = 'زائر';

      final r = await s.signInWithGoogle(grade_: 2, track_: 'علمي', role_: 'student');

      expect(r.cancelled, isTrue);
      expect(r.signedIn, isFalse, reason: 'الإلغاءُ صار دخولاً — العلّةُ نفسُها');
      expect(s.isGuest, isTrue, reason: 'كان يصير `false` فيُعامَل الزائرُ مسجّلاً');
      expect(s.name, 'زائر', reason: 'الاسمُ الافتراضيُّ «طالب مسار» يعني أن مسار النجاح مضى');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('session_pending_grade'), isNull,
          reason: 'لا يُكتب صفٌّ معلّقٌ لحسابٍ لم يُنشأ');
    });
  });

  // ══════════════════════════════════════════════════
  // ② التهدئة بعد المحاولات الخاطئة
  // ══════════════════════════════════════════════════
  group('② LoginThrottle', () {
    test('أربعٌ مجانية، والخامسةُ تقفل ٣٠ثانية، ثم تتضاعف حتى ١٥ دقيقة', () async {
      var now = DateTime(2026, 9, 23, 12);
      final t = LoginThrottle.forTest('t1', () => now);

      for (var i = 0; i < 4; i++) {
        expect(await t.recordFailure(), Duration.zero);
      }
      expect(await t.remaining(), Duration.zero);
      expect(await t.recordFailure(), const Duration(seconds: 30));
      expect(await t.remaining(), const Duration(seconds: 30));

      now = now.add(const Duration(seconds: 31));
      expect(await t.remaining(), Duration.zero, reason: 'المهلةُ لا تبقى بعد انقضائها');
      expect(await t.recordFailure(), const Duration(seconds: 60));
      expect(await t.recordFailure(), const Duration(minutes: 2));
      for (var i = 0; i < 10; i++) {
        await t.recordFailure();
      }
      expect(await t.recordFailure(), LoginThrottle.maxLock);
    });

    test('النجاحُ يمحو العدّاد كلَّه', () async {
      final now = DateTime(2026, 9, 23);
      final t = LoginThrottle.forTest('t2', () => now);
      for (var i = 0; i < 5; i++) {
        await t.recordFailure();
      }
      await t.clear();
      expect(await t.remaining(), Duration.zero);
      expect(await t.recordFailure(), Duration.zero, reason: 'العدُّ يبدأ من جديد');
    });

    test('💾 القفلُ على القرص — «إغلاقُ التطبيق وفتحُه» لا يصفّره', () async {
      final now = DateTime(2026, 9, 23);
      for (var i = 0; i < 5; i++) {
        await LoginThrottle.forTest('t3', () => now).recordFailure();
      }
      // كائنٌ جديد = إقلاعٌ جديد.
      final fresh = LoginThrottle.forTest('t3', () => now);
      expect(await fresh.remaining(), const Duration(seconds: 30));
    });

    test('📨 رسالةٌ بأرقامٍ عربية', () {
      expect(LoginThrottle.waitMessage(const Duration(seconds: 45)),
          contains('٤٥ ثانية'));
      expect(LoginThrottle.waitMessage(const Duration(minutes: 1)), contains('دقيقة'));
      expect(LoginThrottle.waitMessage(const Duration(minutes: 15)),
          contains('١٥ دقائق'));
    });
  });

  // ══════════════════════════════════════════════════
  // ③ شرائحُ الأوضاع تملأ العرض
  // ══════════════════════════════════════════════════
  group('③ FilledWrap', () {
    // عروضُ الشرائح الطبيعية كما تقيسها فلاتر تقريباً (شرح · تلخيص · سؤال · اختبارات · وزاري).
    const five = [70.0, 80.0, 72.0, 90.0, 78.0];

    test('خمسُ شرائح لا تسعها سطراً ⇒ «٣ + ٢» متوازنة لا «٤ + ١»', () {
      expect(FilledWrap.partition(five, 358, 6), [3, 2]);
      expect(FilledWrap.partition(five, 300, 6), [3, 2]);
    });

    test('أربعُ شرائح تسعها ⇒ سطرٌ واحد', () {
      expect(FilledWrap.partition([70, 80, 72, 90], 358, 6), [4]);
    });

    test('شاشةٌ ضيّقة جداً ⇒ أسطرٌ أكثر ولا شريحةَ تُقصّ', () {
      final rows = FilledWrap.partition(five, 170, 6);
      expect(rows.fold<int>(0, (a, b) => a + b), 5);
      expect(rows.length, greaterThanOrEqualTo(3));
    });

    for (final width in [300.0, 358.0, 392.0]) {
      testWidgets('⭐ كلُّ سطرٍ يبلغ الحافّتين على عرض $width (iPhone 17 · Pro Max)',
          (tester) async {
        final keys = List.generate(5, (i) => GlobalKey());
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: width,
              child: FilledWrap(children: [
                for (var i = 0; i < 5; i++)
                  SizedBox(key: keys[i], width: five[i], height: 35),
              ]),
            ),
          ),
        ));
        final box = tester.getRect(find.byType(FilledWrap));
        Rect r(int i) => tester.getRect(find.byKey(keys[i]));
        // RTL: الأوّلُ يمينَ السطر، والأخيرُ في سطره عند اليسار.
        expect(r(0).right, moreOrLessEquals(box.right, epsilon: 0.5));
        expect(r(2).left, moreOrLessEquals(box.left, epsilon: 0.5),
            reason: 'السطرُ الأوّل يقف قبل الحافّة — شكوى المالك بعينها');
        expect(r(3).right, moreOrLessEquals(box.right, epsilon: 0.5));
        expect(r(4).left, moreOrLessEquals(box.left, epsilon: 0.5));
        expect(r(3).top, greaterThan(r(0).top), reason: 'سطران لا واحد');
        // والأعرضُ طبيعةً يبقى أعرض.
        expect(r(3).width, greaterThan(r(4).width));
      });
    }
  });

  // ══════════════════════════════════════════════════
  // ④ المِعداد — لا كيبورد
  // ══════════════════════════════════════════════════
  group('④ CountStepper', () {
    testWidgets('+ و− بين الحدّين، ولا حقلَ كتابةٍ أصلاً', (tester) async {
      final c = TextEditingController(text: "2");
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
                child: CountStepper(controller: c, fallback: 1, min: 1, max: 3)),
          ),
        ),
      ));
      expect(find.byType(TextField), findsNothing,
          reason: 'حقلُ كتابةٍ يرفع الكيبورد فتُطوى البطاقة — العلّةُ نفسُها');

      await tester.tap(find.bySemanticsLabel('زِد'));
      await tester.pump();
      expect(c.text, "3");
      await tester.tap(find.bySemanticsLabel('زِد'));
      await tester.pump();
      expect(c.text, "3", reason: 'تجاوز السقف');

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('أنقِص'));
        await tester.pump();
      }
      expect(c.text, "1", reason: 'نزل تحت الحدّ الأدنى');
    });

    testWidgets('قيمةٌ فاسدةٌ قديمة تُعرض داخل الحدّين', (tester) async {
      final c = TextEditingController(text: "99999");
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CountStepper(controller: c, fallback: 5)),
      ));
      expect(find.text("20"), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑤ نقرةٌ تُنزل الكيبورد — والسحبُ لا
  // ══════════════════════════════════════════════════
  group('⑤ TapToDismissKeyboard', () {
    Future<FocusNode> pump(WidgetTester tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            Expanded(
              child: TapToDismissKeyboard(
                child: ListView(children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 60, child: Text("سطر $i")),
                ]),
              ),
            ),
            TextField(focusNode: focus),
          ]),
        ),
      ));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      return focus;
    }

    testWidgets('⭐ نقرةٌ على نصّ المحادثة ⇒ الكيبورد ينزل', (tester) async {
      final focus = await pump(tester);
      await tester.tap(find.text("سطر 3"));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('🔽 سحبٌ للتمرير ⇒ الكيبورد باقٍ (طلبُ المالك صريحاً)', (tester) async {
      final focus = await pump(tester);
      await tester.drag(find.text("سطر 3"), const Offset(0, -200));
      await tester.pump();
      expect(focus.hasFocus, isTrue, reason: '«مش إنه لو حركت لفوق ولا تحت»');
    });

    testWidgets('✋ ضغطةٌ مطوّلة (تحديدُ نصّ) ⇒ الكيبورد باقٍ', (tester) async {
      final focus = await pump(tester);
      final g = await tester.startGesture(tester.getCenter(find.text("سطر 3")));
      await tester.pump(const Duration(milliseconds: 700));
      await g.up();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑥ لا إرسالَ قبل اكتمال الاختيار
  // ══════════════════════════════════════════════════
  group('⑥ sendBlocker', () {
    test('وضعُ الدروس: بلا درسٍ مغلق، وبدرسٍ مفتوح', () {
      final c = _student()
        ..contentMode = "lessons"
        ..caps = SubjectCapabilities(
          subject: "احياء",
          lessonsAvailable: true,
          pagesAvailable: false,
          lessonsUnits: const [LessonsUnit(unit: "الوحدة", lessons: ["الدرس"])],
          pagesUnits: const [],
        );
      addTearDown(c.dispose);
      expect(c.sendBlocker, "اختر الوحدة ثم الدرس");
      c.selectedV3Unit = "الوحدة";
      expect(c.sendBlocker, "اختر الدرس أولاً");
      c.selectedV3Lesson = "الدرس";
      expect(c.sendBlocker, isNull);
    });

    test('وضعُ الوحدات: «صفحة» بلا صفحات مغلق، والصورةُ تُغني عنها', () {
      final c = _student()
        ..contentMode = "pages"
        ..caps = SubjectCapabilities(
          subject: "احياء",
          lessonsAvailable: false,
          pagesAvailable: true,
          lessonsUnits: const [],
          pagesUnits: const ["الوحدة"],
        )
        ..availableUnits = ["الوحدة"];
      addTearDown(c.dispose);
      expect(c.sendBlocker, "اختر الوحدة أولاً");
      c.selectedUnit = "الوحدة";
      expect(c.sendBlocker, isNull, reason: '«برومت» يكفيه الوحدة');
      c.inputType = "صفحة";
      expect(c.sendBlocker, "اختر الصفحات أولاً");
      c.addPage(9);
      expect(c.sendBlocker, isNull);
    });

    test('مادةٌ بلا محتوى ⇒ يقال «قيد الإضافة» لا «اختر»', () {
      final c = _student()..contentMode = "pages";
      addTearDown(c.dispose);
      expect(c.sendBlocker, contains("قيد الإضافة"));
    });

    test('وزاري الفيزياء: السنةُ شرط', () {
      final c = _student()
        ..selectedSubject = "فيزياء"
        ..selectedMode = "وزاري"
        ..availableYears = ["2019"];
      addTearDown(c.dispose);
      expect(c.sendBlocker, "اختر السنة الوزارية أولاً");
      c.selectedExamYear = "2019";
      expect(c.sendBlocker, isNull);
    });

    test('وزاري العربي والإنجليزي: لا كتابةَ حرّة أصلاً — الخادمُ يرفضها', () {
      for (final subject in ["عربي", "انجليزي"]) {
        final c = _student()
          ..selectedSubject = subject
          ..selectedMode = "وزاري"
          ..availableYears = ["2019"];
        addTearDown(c.dispose);
        expect(c.sendBlocker, contains("جلب الأسئلة"), reason: subject);
      }
    });

    test('الرياضيات: الفرعُ ثم الدرس، والوزاريُّ بعد الجلب', () {
      final c = _student()..selectedSubject = "رياضيات";
      addTearDown(c.dispose);
      expect(c.sendBlocker, "اختر فرع الرياضيات أولاً");
      c.selectedMathBranch = "تفاضل";
      expect(c.sendBlocker, "اختر الدرس أولاً");
      c.selectedLesson = "النهايات";
      expect(c.sendBlocker, isNull);
      c.mathMode = "وزاري";
      expect(c.sendBlocker, contains("جلب الأسئلة"));
      c.mathWazariQuestionsLoaded = true;
      expect(c.sendBlocker, isNull);
    });

    test('👨‍🏫 المعلّم: أدواتُ التوليد تحتاج الدرس، و«اسأل» لا', () {
      final c = _student()..teacherTool = TeacherTool.lessonPlan;
      addTearDown(c.dispose);
      expect(c.sendBlocker, isNotNull);
      c.selectedV3Lesson = "الدرس";
      expect(c.sendBlocker, isNull);
      c
        ..selectedV3Lesson = ""
        ..teacherTool = TeacherTool.ask;
      expect(c.sendBlocker, isNull, reason: '«الدرس (اختياري)» في «اسأل المساعد»');
    });

    test('⭐ نصٌّ مكتوبٌ بلا درس ⇒ لا رسالةَ ولا طلبَ ولا خصم — والسببُ يُقال', () async {
      final net = _NoNetwork();
      final c = _student(net: net)..contentMode = "lessons";
      addTearDown(c.dispose);
      c.inputController.text = "اشرح لي";
      String? reason;
      c.onSendBlocked = (r) => reason = r;

      await c.processRequest();

      expect(reason, isNotNull);
      expect(c.messages, isEmpty, reason: '«مش أنا أرسل ويقول لي اختر»');
      expect(net.calls, 0, reason: 'رحلةُ شبكةٍ لطلبٍ محكومٍ بالرفض');
      expect(c.inputController.text, "اشرح لي", reason: 'لا يضيع ما كتبه');
    });

    test('💡 وشرائحُ الاقتراح تمرّ من البوّابة نفسِها', () async {
      final net = _NoNetwork();
      final c = _student(net: net)..contentMode = "lessons";
      addTearDown(c.dispose);
      String? reason;
      c.onSendBlocked = (r) => reason = r;
      final chip = c.suggestions.firstWhere((s) => s.send);
      c.applySuggestion(chip);
      await Future<void>.delayed(Duration.zero);
      expect(reason, isNotNull);
      expect(net.calls, 0);
    });

    test('🧭 وأزرارُ الوزاري لا تمنعها البوّابة — لها جاهزيّتُها', () async {
      final net = _NoNetwork();
      final c = _student(net: net)
        ..selectedSubject = "عربي"
        ..selectedMode = "وزاري"
        ..availableYears = ["2019"];
      addTearDown(c.dispose);
      var blocked = false;
      c.onSendBlocked = (_) => blocked = true;

      await c.processRequest(customText: "2019|النحو|قطعة|2");

      expect(blocked, isFalse);
      expect(net.calls, greaterThan(0), reason: 'زرُّ «جلب الأسئلة» لم يصل الخادم');
    });
  });

  // ══════════════════════════════════════════════════
  // ⑦ لكل وضعٍ محادثتُه
  // ══════════════════════════════════════════════════
  test('⑦ ☢️ سؤال ⇐ وزاري ⇐ سؤال: كلُّ وضعٍ يعود بمعرّفه لا بمعرّف غيره', () async {
    final c = _student()..selectedMode = "سؤال";
    addTearDown(c.dispose);
    c.currentConversationId = "conv-question";
    c.messages = <Map<String, dynamic>>[
      {"role": "user", "text": "عرّف الخلية"},
      {"role": "ai", "text": "…", "animating": false},
    ];

    await c.switchContext(() => c.selectedMode = "وزاري");
    final wazariId = c.currentConversationId;
    expect(wazariId, isNot("conv-question"), reason: 'الوزاريُّ فُتح داخل محادثة السؤال');
    expect(c.messages, isEmpty);
    c.messages.add({"role": "user", "text": "قطعة 2019"});

    await c.switchContext(() => c.selectedMode = "سؤال");
    expect(c.currentConversationId, "conv-question",
        reason: 'رسائلُ السؤال عادت بمعرّف الوزاري — فتُحفظ فوقه (العلّة)');
    expect(c.messages.first["text"], "عرّف الخلية");

    await c.switchContext(() => c.selectedMode = "وزاري");
    expect(c.currentConversationId, wazariId);
    expect(c.messages.single["text"], "قطعة 2019");
  });

  // ══════════════════════════════════════════════════
  // 🚪 الدخولُ بلا كيبورد
  // ══════════════════════════════════════════════════
  // 🔄 قرار المالك ٢٠٢٦-٠٩-٢٤ عكس نصفَ هذا: البطاقةُ **مطويّةٌ** عند الدخول
  //    (الروبوتُ وترحيبُه أولاً)، ومحادثةٌ جديدة لا تفتحها ولا تطويها.
  testWidgets('🚪 محادثةٌ جديدة تُسقط تركيزَ الحقل ولا تمسّ البطاقة', (tester) async {
    final c = _student();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TextField(focusNode: c.inputFocus)),
    ));
    c.inputFocus.requestFocus();
    await tester.pump();
    expect(c.chatInputFocused, isTrue);

    c.showSettingsPanel = false;
    await c.createNewConversation();
    await tester.pump();

    expect(c.chatInputFocused, isFalse, reason: '«أول ما ندخل ما يفتح كيبورد»');
    expect(c.showSettingsPanel, isFalse);
    expect(ChatController().showSettingsPanel, isFalse,
        reason: 'مطويّةٌ عند الدخول');
  });

  // ══════════════════════════════════════════════════
  // ✂️ نصفُ رمزٍ تعبيريّ — «string is not well-formed UTF-16» (رُئي في المحاكي)
  // ══════════════════════════════════════════════════
  group('✂️ القصُّ لا يشطر رمزاً', () {
    test('safeCut يتراجع خطوةً إن وقع داخل زوج', () {
      const s = 'ab📝cd'; // 📝 = وحدتان (2 و3)
      expect(safeCut(s, 3), 'ab', reason: 'نصفُ 📝 كان سيبقى');
      expect(safeCut(s, 4), 'ab📝');
      expect(safeCut(s, 99), s);
      expect(safeCut(s, 0), '');
    });

    test('firstGlyph يأخذ الرمزَ كاملاً', () {
      expect(firstGlyph('😀أحمد'), '😀');
      expect(firstGlyph('أحمد'), 'أ');
      expect(firstGlyph(''), '');
    });

    testWidgets('⌨️ الطابعةُ لا تُظهر نصفَ رمزٍ في أيّ خطوة', (tester) async {
      // ١١ حرفاً ثم رمز: الخطوةُ ١٢ تقع بين نصفيه بالضبط.
      const text = 'اختبار ابتد📝 نهاية النص هنا وأكثر من ذلك بكثير';
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = old);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TypewriterText(text: text)),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
    });
  });
}
