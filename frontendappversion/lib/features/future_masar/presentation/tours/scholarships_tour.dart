import '../../../../core/tour/masar_tour.dart';
import '../../../../core/widgets/masar_character.dart';

// ==========================================
// 🎓 جولاتُ المنح — القائمة · المنحة · مساعدُها (المرحلة ٥)
// ==========================================
// ⚡ **سريعةٌ عمداً** (أمرُ المالك ٢٠٢٦-٠٩-٢٧: «ما في داعي تعبر على الشروط
//    والمدري إيش… قول هنا هنا هنا، تو على السريع، وبعدين داخل المحادثة كم
//    حاجة»). فكلُّ شاشةٍ جولتُها القصيرة: إشارةٌ إلى المكان وسطرٌ واحد،
//    بلا ترحيبٍ طويل ولا شرحٍ لمحتوى المنحة نفسِها.
class ScholarshipsTour {
  ScholarshipsTour._();

  // ── ١. قائمةُ المنح ──
  static const String listId = 'scholarships';
  static const String search = 'sch.search';
  static const String filters = 'sch.filters';
  static const String card = 'sch.card';
  static const String follow = 'sch.follow';

  static List<TourStep> listSteps() => const [
    TourStep(
      anchor: search,
      padding: 6,
      title: "ابحث عن منحة",
      body: "باسمها أو دولتها أو تخصّصها.",
    ),
    TourStep(
      anchor: filters,
      padding: 6,
      pose: MasarCharacter.guide,
      title: "الفلاتر",
      body:
          "متابَعاتك، والتمويل، والمفتوحة الآن، والتي تُغلق قريباً — اسحبها جانباً.",
    ),
    TourStep(
      anchor: card,
      optional: true,
      padding: 6,
      pose: MasarCharacter.study,
      title: "المنحة",
      body: "حالتها وتمويلها وموعدها والمعدّل — واضغطها لتفاصيلها.",
    ),
    TourStep(
      anchor: follow,
      optional: true,
      shape: TourShape.circle,
      padding: 8,
      pose: MasarCharacter.ask,
      title: "تابعها",
      body: "وأنبّهك قبل أن يُغلق التقديم.",
    ),
  ];

  // ── ٢. صفحةُ المنحة ──
  static const String detailId = 'scholarship_detail';
  static const String summary = 'sch.summary';
  static const String tabs = 'sch.tabs';
  static const String ask = 'sch.ask';
  static const String site = 'sch.site';

  static List<TourStep> detailSteps() => const [
    TourStep(
      anchor: summary,
      padding: 6,
      title: "حالةُ المنحة",
      body: "مفتوحةٌ أم لا، وتمويلُها، وكم يوماً باقٍ.",
    ),
    TourStep(
      anchor: tabs,
      padding: 6,
      pose: MasarCharacter.study,
      title: "كلُّ تفاصيلها هنا",
      body: "النبذة والشروط والوثائق والمواعيد وطريقة التقديم.",
    ),
    TourStep(
      anchor: ask,
      padding: 6,
      pose: MasarCharacter.guide,
      title: "اسأل مساعد المنحة",
      body: "عن أي تفصيلٍ فيها — يجيبك منها هي.",
    ),
    TourStep(
      anchor: site,
      optional: true,
      padding: 6,
      title: "الموقع الرسمي",
      body: "لتقدّم من المصدر نفسه.",
    ),
  ];

  // ── ٣. مساعدُ المنحة ──
  static const String chatId = 'scholarship_chat';
  static const String prompts = 'sch.prompts';
  static const String input = 'sch.input';
  static const String newChat = 'sch.new';
  static const String history = 'sch.history';

  static List<TourStep> chatSteps() => const [
    TourStep(
      anchor: prompts,
      optional: true,
      padding: 4,
      pose: MasarCharacter.ask,
      title: "أسئلةٌ جاهزة",
      body: "جوابُها فوريٌّ من بطاقة المنحة — بلا خصمٍ من رصيدك.",
    ),
    TourStep(
      anchor: input,
      padding: 6,
      title: "اسأل ما شئت",
      body: "اكتب، أو صوّر ورقة، أو تكلّم — وأجيبك عن هذه المنحة.",
    ),
    TourStep(
      anchor: newChat,
      shape: TourShape.circle,
      padding: 8,
      pose: MasarCharacter.guide,
      title: "محادثةٌ جديدة",
      body: "ابدأ سؤالاً جديداً — والسابقةُ تبقى محفوظة.",
    ),
    TourStep(
      anchor: history,
      shape: TourShape.circle,
      padding: 8,
      title: "محادثاتك",
      body: "كلُّ ما سألته عن المنح محفوظٌ هنا.",
    ),
  ];
}
