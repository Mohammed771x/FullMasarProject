import '../../../../core/tour/masar_tour.dart';
import '../../../../core/widgets/masar_character.dart';
import '../../../chat/data/models/subject_capabilities.dart';

// ==========================================
// 🧠 جولةُ «اختبر نفسك» — المرحلة ٤
// ==========================================
// 🧭 **بترتيب الشاشة نفسِها**: الاختبارُ المعلّق (إن وُجد) ← المادة ← الوحدة
//    والدروس ← عدد الأسئلة ← زرّ البدء ← ثم ما يحدث بعد الاختبار.
//
// 🎭 **لا تُشرح شاشةٌ فارغة** (أمرُ المالك ٢٠٢٦-٠٩-٢٧): مادةٌ دروسُها «لم
//    تُضف بعد» — وأكثرُها في الصفّين الأول والثاني — لا تُظهر بطاقاتِ الدروس
//    والعدد والزرّ أصلاً. فتُعرض أثناء الجولة وحدةٌ ودروسٌ «(مثال)» في الذاكرة
//    ([demoCaps])، ثم تعود الشاشةُ إلى حقيقتها. لا يُرسل منها شيء.
class QuizTour {
  QuizTour._();

  static const String id = 'quiz';

  // 📍 المراسي.
  static const String resume = 'quiz.resume';
  static const String subjects = 'quiz.subjects';
  static const String lessons = 'quiz.lessons';
  static const String count = 'quiz.count';
  static const String start = 'quiz.start';

  /// الدروسُ التوضيحية — أوّلُها مختارٌ ليُرى شكلُ الاختيار.
  static const String demoUnit = "الوحدة الأولى (مثال)";
  static const List<String> demoLessons = [
    "الدرس الأول (مثال)",
    "الدرس الثاني (مثال)",
    "الدرس الثالث (مثال)",
  ];

  static SubjectCapabilities demoCaps(String subject) => SubjectCapabilities(
    subject: subject,
    lessonsAvailable: true,
    pagesAvailable: false,
    lessonsUnits: const [LessonsUnit(unit: demoUnit, lessons: demoLessons)],
    pagesUnits: const [],
    quizAvailable: true,
  );

  static List<TourStep> steps({required bool demo}) {
    String t(String title) => demo ? "$title (مثال)" : title;
    return [
      TourStep(
        title: "هنا تختبر نفسك",
        body: demo
            ? "اختر دروسك وأجهّز لك أسئلةً منها — ودروسُ هذه المادة تُضاف "
                  "قريباً، فسأريك بمثال."
            : "اختر دروسك وأجهّز لك أسئلةً منها — سهلةً ثم أصعب — ثم "
                  "أصحّحها لك فوراً.",
      ),
      const TourStep(
        anchor: resume,
        optional: true,
        padding: 6,
        pose: MasarCharacter.ask,
        title: "اختبارٌ لم يكتمل",
        body:
            "أكمله من حيث توقفت بلا خصمٍ من رصيدك — أو «تجاهله» لتبدأ "
            "من جديد.",
      ),
      const TourStep(
        anchor: subjects,
        padding: 6,
        pose: MasarCharacter.study,
        title: "١. اختر المادة",
        body: "موادُّ صفّك كلُّها هنا — اضغط المادة التي تريد أن تختبر فيها.",
      ),
      TourStep(
        anchor: lessons,
        padding: 6,
        title: t("٢. الوحدة والدروس"),
        body:
            "اختر الوحدة، ثم حتى ٣ دروس — ولو من وحداتٍ مختلفة، "
            "وما اخترته يظهر فوقها.",
      ),
      TourStep(
        anchor: count,
        padding: 6,
        pose: MasarCharacter.ask,
        title: t("عدد الأسئلة"),
        // 🔢 بلا أرقام: أرقامٌ عربيةٌ متجاورةٌ في جملةٍ عربية يقلبها الاتجاه.
        body:
            "القليلُ لمراجعةٍ سريعة، والأكثرُ لاختبارٍ أعمق — اختر ما يناسب وقتك.",
      ),
      TourStep(
        anchor: start,
        padding: 6,
        title: t("ابدأ الاختبار"),
        body:
            "يضيء حين تختار درساً — وإن خرجتَ في منتصفه حفظتُه لك لتكمله "
            "لاحقاً.",
      ),
      TourStep(
        pose: MasarCharacter.ask,
        title: "وبعد الاختبار؟",
        body: demo
            ? "كانت هذه أمثلة — وحين تُضاف الدروس ترى نتيجتك وأخطاءك "
                  "مشروحة، وتُضاف إلى «تحليل مستواي»."
            : "ترى نتيجتك وأخطاءك مشروحة، ويُضاف كلُّ اختبارٍ إلى «تحليل "
                  "مستواي» لتعرف ما تراجعه.",
      ),
    ];
  }
}
