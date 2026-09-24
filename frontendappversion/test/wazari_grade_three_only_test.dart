// 📝 «الوزاري» لا يُرسم إلا لطالب الثالث — **في كل سطحٍ يظهر فيه**.
//
// 🔴 ملاحظةُ المالك (٢٠٢٦-٠٩-٢٢): «أعتقد في بعض أماكن محذوف، في بعض الأماكن
//    موجود». والقاعدةُ في [Curriculum] وحدها لا تكفي: ما يهمّ الطالبَ هو ما
//    **يُرسم على شاشته**، وقد كانت الرياضياتُ ترسم قائمةً مكتوبةً باليد،
//    ودليلُ الاستخدام يعرض بطاقةً لوضعٍ محذوف. فهنا تُمتحن الأسطح نفسُها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/config/curriculum.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/session_settings_panel.dart';
import 'package:ye_student_tutor/features/instructions/presentation/instructions_dialog.dart';

SubjectCapabilities _caps(String subject) => SubjectCapabilities(
      subject: subject,
      lessonsAvailable: true,
      pagesAvailable: false,
      lessonsUnits: const [LessonsUnit(unit: "الوحدة الأولى", lessons: ["درس"])],
      pagesUnits: const [],
      // ☢️ **الخادمُ يقول «عندي بنكُ أسئلة»** — وهو بالضبط ما كان يُعيد
      //    الشريحةَ للأول والثاني. فالقيمةُ هنا `true` عمداً في كل حالة.
      examsAvailable: true,
    );

Future<void> _pumpPanel(WidgetTester tester, ChatController c) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(child: SessionSettingsPanel(controller: c)),
      ),
    ),
  ));
  await tester.pump();
}

ChatController _panelController({required String subject, required int grade}) {
  final c = ChatController()
    ..grade = grade
    ..track = grade == 1 ? Track.none : Track.scientific
    ..selectedSubject = subject
    ..selectedMode = "شرح"
    ..caps = _caps(subject)
    // 🃏 مطويّةٌ عند الدخول منذ ٢٠٢٦-٠٩-٢٤ — وهنا تُفحص شرائحُها فتُفتح.
    ..showSettingsPanel = true;
  if (subject == "رياضيات") {
    c.selectedMathBranch = "تفاضل";
    c.mathMode = "شرح";
  }
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('🎛️ شرائحُ لوحة الإعدادات', () {
    testWidgets('الثالث يرى «وزاري» و«اختبارات» معاً', (tester) async {
      await _pumpPanel(tester, _panelController(subject: "احياء", grade: 3));
      expect(find.text("وزاري"), findsOneWidget);
      expect(find.text("اختبارات"), findsOneWidget);
    });

    testWidgets('☢️ والأول والثاني لا يريانه ولو قال الخادمُ إن عنده بنكاً',
        (tester) async {
      for (final g in [1, 2]) {
        await _pumpPanel(tester, _panelController(subject: "احياء", grade: g));
        expect(find.text("وزاري"), findsNothing, reason: "صف $g");
        expect(find.text("اختبارات"), findsOneWidget, reason: "صف $g");
      }
    });

    // 🧮 الرياضياتُ لوحتُها الخاصة — وهي التي سمّاها المالك بالاسم.
    testWidgets('🧮 رياضياتُ الثالث: وزاري واختبارات', (tester) async {
      await _pumpPanel(tester, _panelController(subject: "رياضيات", grade: 3));
      expect(find.text("وزاري"), findsOneWidget);
      expect(find.text("اختبارات"), findsOneWidget);
      expect(find.text("تلخيص"), findsNothing, reason: 'الرياضيات بلا تلخيص');
    });

    testWidgets('🧮 ورياضياتُ الأول والثاني: الاختبارات مكان الوزاري',
        (tester) async {
      for (final g in [1, 2]) {
        await _pumpPanel(tester, _panelController(subject: "رياضيات", grade: g));
        expect(find.text("وزاري"), findsNothing, reason: "صف $g");
        // 🎯 «يروح لقسم الاختبارات» — فالبابُ موجودٌ لا محذوفٌ معه.
        expect(find.text("اختبارات"), findsOneWidget, reason: "صف $g");
        expect(find.text("شرح"), findsOneWidget, reason: "صف $g");
        expect(find.text("سؤال"), findsOneWidget, reason: "صف $g");
      }
    });
  });

  // ══════════════════════════════════════════════════
  // 💡 ودليلُ الاستخدام سطحٌ ثالث
  // ══════════════════════════════════════════════════
  // بطاقةٌ تَعِد طالبَ الأول الثانوي بوضعٍ لا يجده في شاشته أسوأُ من نقصٍ
  // في الدليل: وعدٌ مكسور، ويظنّ أن قسماً من التطبيق معطوبٌ عنده.
  group('💡 بطاقاتُ دليل الاستخدام', () {
    testWidgets('الثالث يرى بطاقة «وضع الوزاري»', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => InstructionsDialog.showIfNeeded(context, "احياء",
                grade: 3, track: "علمي", forceShow: true),
            child: const Text("افتح"),
          ),
        ),
      ));
      await tester.tap(find.text("افتح"));
      await tester.pumpAndSettle();

      expect(find.textContaining("وضع الوزاري"), findsOneWidget);
      expect(find.textContaining("وضع الاختبارات"), findsOneWidget);
    });

    testWidgets('☢️ والأول لا يراها', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => InstructionsDialog.showIfNeeded(context, "احياء",
                grade: 1, track: "عام", forceShow: true),
            child: const Text("افتح"),
          ),
        ),
      ));
      await tester.tap(find.text("افتح"));
      await tester.pumpAndSettle();

      expect(find.textContaining("وضع الوزاري"), findsNothing);
      // ✅ وبقيةُ البطاقات كما هي — الحذفُ بطاقةٌ واحدةٌ لا القائمةُ كلها.
      expect(find.textContaining("وضع الشرح"), findsOneWidget);
      expect(find.textContaining("وضع الاختبارات"), findsOneWidget);
    });
  });
}
