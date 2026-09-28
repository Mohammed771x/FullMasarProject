import '../../../../core/config/curriculum.dart';
import '../../../../core/tour/masar_tour.dart';
import '../../../../core/widgets/masar_character.dart';
import '../../../quiz/data/models/quiz_models.dart';

// ==========================================
// 📊 جولةُ «معلومات الطالب» وتحليل مستواي — المرحلة ٢
// ==========================================
// الشاشةُ حالتان: **بلا اختبارات** (بطاقة «لا يوجد تحليل بعد») و**بنتائج**
// (الملخّص والتقدّم ونقاط الضعف والمراجعة والمواد). كلُّ خطوةٍ لقسمٍ لا
// يُبنى إلا ببيانات **اختيارية** — فيرى كلُّ طالبٍ شرحَ ما أمامه فقط.
// والصفوفُ الطويلة (الدروس · المواد) تُفتح على **أوّل صفٍّ** منها: فتحةٌ
// بطول الشاشة لا تترك للروبوت مكاناً ولا تقول «هذا» لشيء.
class AnalysisTour {
  AnalysisTour._();

  static const String id = 'analysis';

  // 📍 المراسي.
  static const String avatar = 'analysis.avatar';
  static const String studied = 'analysis.studied';
  static const String details = 'analysis.details';
  static const String empty = 'analysis.empty';
  static const String summary = 'analysis.summary';
  static const String progress = 'analysis.progress';
  static const String focus = 'analysis.focus';
  static const String review = 'analysis.review';
  static const String subjects = 'analysis.subjects';

  /// 🎭 **نتائجُ توضيحية للجولة وحدها** (أمرُ المالك ٢٠٢٦-٠٩-٢٧): الطالبُ الجديد
  ///    بلا اختبارات، والجولةُ تظهر مرّةً واحدة — فلو شرحت شاشةً فارغة لما عرف
  ///    أبداً أين يجد ملخّصه ونقاطَ ضعفه حين تظهر. فتُعرض هذه **في الذاكرة فقط**
  ///    أثناء الشرح (لا تُحفظ، والفتحةُ لا تُنقر)، ثم تعود الشاشةُ إلى حقيقتها.
  ///    الموادُّ موادُّ صفِّه هو؛ والدروسُ أسماءٌ عامّة لأن فهرسَها في الخادم.
  static List<QuizResult> demoResults({
    required int grade,
    required String track,
    required String owner,
  }) {
    final subjects = Curriculum.subjectsFor(grade, TrackLabel.fromKey(track));
    String sub(int i) => subjects[i % subjects.length];
    final now = DateTime.now();
    QuizResult r(
      int i,
      String subject,
      int score,
      int daysAgo,
      Map<String, int> wrong,
    ) => QuizResult(
      id: 'tour-demo-$i',
      subject: subject,
      grade: grade,
      track: track,
      unit: 'الوحدة الأولى',
      lessons: wrong.keys.toList(),
      score: score,
      total: 10,
      wrong: [
        for (final e in wrong.entries)
          for (var k = 0; k < e.value; k++)
            WrongAnswer(topic: '', lesson: e.key, unit: 'الوحدة الأولى'),
      ],
      durationSec: 300,
      createdAt: now.subtract(Duration(days: daysAgo)),
      ownerUid: owner,
    );
    return [
      r(0, sub(0), 8, 0, {'الدرس الثاني': 2}),
      r(1, sub(1), 5, 1, {'الدرس الأول': 3, 'الدرس الثالث': 2}),
      r(2, sub(2), 7, 2, {'الدرس الرابع': 3}),
      r(3, sub(0), 6, 3, {'الدرس الثاني': 4}),
    ];
  }

  static List<TourStep> steps({required bool guest, bool demo = false}) {
    // 🏷️ ما يُعرض من البيانات التوضيحية يُقال عنه «مثال» صراحةً.
    String t(String title) => demo ? "$title (مثال)" : title;
    return [
      TourStep(
        title: "هنا معلوماتك وتحليل مستواك",
        body: demo
            ? "كل اختبارٍ تحلّه يُضاف هنا — ولأنك لم تختبر بعد، سأريك بمثالٍ "
                  "كيف ستبدو نتائجك."
            : "كل اختبارٍ تحلّه يُضاف هنا، فتعرف أين أنت في كل مادة وماذا "
                  "تراجع — دعني أريك.",
      ),
      TourStep(
        anchor: avatar,
        shape: TourShape.circle,
        padding: 6,
        title: "صورتك",
        body: guest
            ? "أنشئ حساباً دائماً من الإعدادات لتضع صورتك وتُحفظ نتائجك."
            : "اضغط على صورتك لتختار صورةً من المعرض، أو لتحذفها.",
      ),
      const TourStep(
        anchor: studied,
        padding: 6,
        title: "الموادّ التي درستها",
        body:
            "الشريطُ يمتلئ كلما فتحت مادةً جديدة في قسم التعليم — هدفُك أن "
            "تكمله.",
      ),
      const TourStep(
        anchor: details,
        padding: 6,
        title: "عرض التفاصيل",
        body: "يفتح إعداداتك: اسمك وصفّك ومسارك ونوعُ حسابك.",
      ),
      const TourStep(
        anchor: empty,
        optional: true,
        pose: MasarCharacter.ask,
        title: "لا يوجد تحليل بعد",
        body:
            "التحليلُ يُبنى من اختباراتك — اضغط «ابدأ اختبارك الأول» "
            "وسيظهر مستواك هنا بعده مباشرة.",
      ),
      TourStep(
        anchor: summary,
        optional: true,
        pose: MasarCharacter.ask,
        title: t("ملخّص أدائك"),
        body:
            "عددُ اختباراتك، ومعدّلُك العام، ونتيجةُ آخر اختبار — وتحتها "
            "أفضلُ مادةٍ لك وأضعفُها، وأيامُك المتتالية.",
      ),
      TourStep(
        anchor: progress,
        optional: true,
        title: t("تقدّمك"),
        body: "خطٌّ يرسم نتائج آخر اختباراتك — إن كان يصعد فأنت تتحسّن.",
      ),
      TourStep(
        anchor: focus,
        optional: true,
        pose: MasarCharacter.study,
        title: t("الدروس التي تحتاج تركيز"),
        body:
            "مرتّبةٌ من الأكثر خطأً — اضغط على أيّ درسٍ ليشرحه لك مسار، أو "
            "لتعيد اختباره.",
      ),
      TourStep(
        anchor: review,
        optional: true,
        pose: MasarCharacter.ask,
        title: t("اختبار مراجعة"),
        body:
            "أسئلةٌ من دروسك الضعيفة وحدها — أسرعُ طريقٍ لسدّ الثغرات قبل "
            "الامتحان.",
      ),
      TourStep(
        anchor: subjects,
        optional: true,
        title: t("تحليل المواد"),
        body:
            "كلُّ مادةٍ بنسبتها وتقييمها — اضغط على مادةٍ لترى تحليلها "
            "بالتفصيل وحدةً وحدة.",
      ),
      TourStep(
        pose: MasarCharacter.ask,
        title: "هكذا تعرف مستواك!",
        body: demo
            ? "كانت هذه أرقاماً للتوضيح — ابدأ اختبارك الأول، وستظهر أرقامُك "
                  "الحقيقية هنا مكانها."
            : "اختبر نفسك باستمرار، وأنا أحدّث لك هذا التحليل بعد كل اختبار.",
      ),
    ];
  }
}
