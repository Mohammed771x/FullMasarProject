// 📊 شاشتا التحليل فوق نتائج حقيقية في Hive — لا بيانات ديمو.
//
// ما يهمّ فعلاً: أن تُقرأ النتائج **بالمالك**، وأن تظهر الأرقام المشتقّة،
// وأن تفتح نقطة الضعف درسَها (الحلقة الذهبية). وأن الشاشة لا تنهار وهي فارغة.
//
// ⚠️ **كل كتابة Hive داخل `testWidgets` تمرّ عبر `runAsync`**: الاختبار يعمل
//    بزمن **وهمي**، وكتابة القرص تحتاج زمناً حقيقياً — فالانتظار عليها داخل
//    الزمن الوهمي لا ينتهي أبداً، ولا تنقذك مهلة الاختبار لأنها وهمية أيضاً.
//    (علّة كلّفتنا وقتاً: التعليق كان يبدو انهياراً في الواجهة وهو في الزمن.)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/screens/analysis_screen.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/screens/subject_analysis_screen.dart';
import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_storage.dart';

const _owner = 'owner-1';
const _other = 'owner-2';

QuizResult _r({
  required String subject,
  required int score,
  required int total,
  String owner = _owner,
  List<WrongAnswer> wrong = const [],
  DateTime? at,
  String unit = 'الفيزياء الذرية',
}) =>
    QuizResult(
      id: '$subject-$score-$total-${at?.millisecondsSinceEpoch ?? 0}-$owner',
      subject: subject,
      grade: 3,
      track: 'علمي',
      unit: unit,
      lessons: const ['نظرية بوهر'],
      score: score,
      total: total,
      wrong: wrong,
      durationSec: 100,
      createdAt: at ?? DateTime(2026, 8, 20),
      ownerUid: owner,
    );

const _bohr = WrongAnswer(
    topic: 'مستويات الطاقة', lesson: 'نظرية بوهر', unit: 'الفيزياء الذرية');

Widget _app(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('analysis_test');
    await QuizStorage.initForTests(dir.path);
  });

  tearDown(() async => QuizStorage.clearAll());

  tearDownAll(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// حفظ النتائج **بزمن حقيقي** قبل بناء الشاشة.
  Future<void> seed(WidgetTester t, List<QuizResult> rs) =>
      t.runAsync(() async {
        for (final r in rs) {
          await QuizStorage.save(r);
        }
      });

  group('الشاشة العامة', () {
    testWidgets('بلا نتائج ⇒ حالة فارغة تدعو لأول اختبار (لا انهيار)',
        (t) async {
      await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
      await t.pump();
      expect(find.text('لا يوجد تحليل بعد'), findsOneWidget);
      expect(find.textContaining('ابدأ اختبارك الأول'), findsOneWidget);
    });

    testWidgets('الأرقام مشتقّة من النتائج لا ثابتة', (t) async {
      await seed(t, [
        _r(subject: 'فيزياء', score: 8, total: 10),
        _r(subject: 'كيمياء', score: 2, total: 10, at: DateTime(2026, 8, 21)),
      ]);

      await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
      await t.pump();

      expect(find.text('2'), findsWidgets); // عدد الاختبارات
      expect(find.text('50%'), findsOneWidget); // 10 من 20
      expect(find.text('فيزياء'), findsWidgets); // أفضل مادة + بطاقتها

      // بطاقات المواد أسفل القائمة — `ListView` لا يبني ما هو خارج الشاشة
      await t.scrollUntilVisible(find.text('كيمياء'), 220,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('كيمياء'), findsOneWidget);
    });

    testWidgets('👤 لا يخلط نتائج حسابين', (t) async {
      await seed(t, [
        _r(subject: 'فيزياء', score: 5, total: 5),
        _r(subject: 'رياضيات', score: 0, total: 10, owner: _other),
      ]);

      await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
      await t.pump();

      expect(find.text('رياضيات'), findsNothing,
          reason: 'تسرّبت نتيجة حساب آخر');
      expect(find.text('100%'), findsWidgets);
    });

    testWidgets('نقطة الضعف تُعرض بدرسها ومعها «اشرح لي»', (t) async {
      await seed(t, [
        _r(subject: 'فيزياء', score: 6, total: 10, wrong: const [_bohr, _bohr]),
      ]);

      await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
      await t.pump();

      expect(find.text('نظرية بوهر'), findsWidgets);
      // الشارة صارت **نسبة خطأ** لا عدد أخطاء (قرار المالك)
      expect(find.textContaining('٪'), findsWidgets, reason: 'شارة النسبة غائبة');
      // الصفّ يفتح التفصيل؛ و«اشرح لي» صارت داخل الورقة
      expect(find.text('التفاصيل'), findsWidgets);
    });

    testWidgets('اختبار المراجعة يفتح ورقة فيها الدروس الضعيفة', (t) async {
      await seed(t, [
        _r(subject: 'فيزياء', score: 6, total: 10, wrong: const [_bohr]),
      ]);

      await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
      await t.pump();
      await t.tap(find.text('اختبار مراجعة'));
      // ⚠️ لا `pumpAndSettle`: `ScreenTip` يحمل مؤقّتات حيّة فلا تسكن الشاشة أبداً
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.text('اختبار مراجعة 📅'), findsOneWidget);
      expect(find.textContaining('ابدأ اختبار المراجعة'), findsOneWidget);
    });
  });

  goldenLoopTests();
  detailSheetTests();

  group('شاشة المادة', () {
    testWidgets('بلا نتائج للمادة ⇒ دعوة للاختبار', (t) async {
      await t.pumpWidget(_app(
          const SubjectAnalysisScreen(subject: 'كيمياء', ownerUid: _owner)));
      await t.pump();
      expect(find.textContaining('ما اختبرت نفسك في كيمياء'), findsOneWidget);
    });

    testWidgets('تعرض المتوسط وأفضل نتيجة وآخر نتيجة', (t) async {
      await seed(t, [
        _r(subject: 'فيزياء', score: 10, total: 10, at: DateTime(2026, 8, 1)),
        _r(subject: 'فيزياء', score: 4, total: 10, at: DateTime(2026, 8, 2)),
      ]);

      await t.pumpWidget(_app(
          const SubjectAnalysisScreen(subject: 'فيزياء', ownerUid: _owner)));
      await t.pump();

      expect(find.text('70%'), findsOneWidget); // المتوسط: 14 من 20
      expect(find.text('100%'), findsOneWidget); // أفضل نتيجة
      expect(find.text('40%'), findsOneWidget); // آخر نتيجة
      expect(find.text('2'), findsOneWidget); // عدد الاختبارات
    });

    testWidgets('بلا أخطاء ⇒ رسالة تهنئة لا قائمة فارغة', (t) async {
      await seed(t, [_r(subject: 'فيزياء', score: 10, total: 10)]);
      await t.pumpWidget(_app(
          const SubjectAnalysisScreen(subject: 'فيزياء', ownerUid: _owner)));
      await t.pump();
      expect(find.textContaining('ما عندك أخطاء'), findsOneWidget);
    });
  });
}

// ══════════ الحلقة الذهبية: «اشرح لي» يفتح درسها ══════════
// نراقب الملاحة بـ`NavigatorObserver`: يكفي أن يُدفع مسار جديد ليثبت أن الزر
// موصول فعلاً بالشات — بلا حاجة لبناء شاشة الشات (تحتاج Firebase).
class _PushSpy extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) =>
      pushed.add(route);
}

void goldenLoopTests() {
  testWidgets('«اشرح لي» يدفع شاشة جديدة (الحلقة الذهبية موصولة)', (t) async {
    final spy = _PushSpy();
    await t.runAsync(() => QuizStorage.save(_r(
        subject: 'فيزياء',
        score: 6,
        total: 10,
        wrong: const [_bohr])));

    await t.pumpWidget(MaterialApp(
      navigatorObservers: [spy],
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: SubjectAnalysisScreen(subject: 'فيزياء', ownerUid: _owner),
      ),
    ));
    await t.pump();

    final before = spy.pushed.length;
    // المسار الحقيقي: الصفّ ⇒ ورقة التفصيل ⇒ «اشرح لي هذا الدرس»
    await t.tap(find.text('نظرية بوهر').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('اشرح لي هذا الدرس'));
    await t.pump();

    // بناء شاشة الشات قد يرمي (تحتاج Firebase) — والمهم أن الدفع حصل.
    t.takeException();
    expect(spy.pushed.length, greaterThan(before),
        reason: 'الزر لم يفتح شيئاً — الحلقة الذهبية مقطوعة');
  });
}

// ══════════ ورقة التفصيل: أين ضعفي داخل الدرس ══════════
void detailSheetTests() {
  testWidgets('الضغط على نقطة الضعف يكشف مفاهيمها لا يفتح الشات مباشرةً',
      (t) async {
    const topics = [
      WrongAnswer(topic: 'نائب الفاعل', lesson: 'المنفعل الماضي', unit: 'النحو'),
      WrongAnswer(topic: 'نائب الفاعل', lesson: 'المنفعل الماضي', unit: 'النحو'),
      WrongAnswer(topic: 'علامة البناء', lesson: 'المنفعل الماضي', unit: 'النحو'),
    ];
    await t.runAsync(() => QuizStorage.save(_r(
        subject: 'عربي', score: 7, total: 10, wrong: topics, unit: 'النحو')));

    await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
    await t.pump();

    // الصفّ واحد لا ثلاثة
    expect(find.text('المنفعل الماضي'), findsOneWidget);
    expect(find.textContaining('٪'), findsWidgets);

    await t.tap(find.text('المنفعل الماضي'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('أين ضعفك بالضبط:'), findsOneWidget);
    // النسبة والعيّنة معاً — الرقم المجرّد يُقرأ خطأً
    expect(find.textContaining('نسبة الخطأ'), findsOneWidget);
    expect(find.text('نائب الفاعل'), findsOneWidget);
    expect(find.text('2 خطأ'), findsOneWidget);
    expect(find.text('علامة البناء'), findsOneWidget);
    expect(find.text('1 خطأ'), findsOneWidget);
    expect(find.text('اشرح لي هذا الدرس'), findsOneWidget);
  });

  testWidgets('الملخّص يعرض أضعف مادة إلى جوار أفضلها', (t) async {
    await t.runAsync(() async {
      await QuizStorage.save(_r(subject: 'فيزياء', score: 9, total: 10));
      await QuizStorage.save(_r(
          subject: 'كيمياء', score: 2, total: 10, at: DateTime(2026, 8, 21)));
    });

    await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
    await t.pump();

    expect(find.text('💪 أفضل مادة'), findsOneWidget);
    expect(find.text('🎯 أضعف مادة'), findsOneWidget);
  });

  testWidgets('مادة واحدة ⇒ لا تُعرض «أضعف مادة» (هي نفسها الأفضل)', (t) async {
    await t.runAsync(() => QuizStorage.save(_r(subject: 'فيزياء', score: 9, total: 10)));
    await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
    await t.pump();

    expect(find.text('💪 أفضل مادة'), findsOneWidget);
    expect(find.text('🎯 أضعف مادة'), findsNothing);
  });
}
