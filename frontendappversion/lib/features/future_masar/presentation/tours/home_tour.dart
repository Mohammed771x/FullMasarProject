import '../../../../core/shell/masar_bottom_nav.dart';
import '../../../../core/tour/masar_tour.dart';
import '../../../../core/widgets/masar_character.dart';

// ==========================================
// 🏠 جولةُ الشاشة الرئيسية — المرحلة ١
// ==========================================
// الترتيبُ ترتيبُ العين: من أعلى الشاشة إلى أسفلها، ثم الشريطُ السفليّ من
// اليمين إلى اليسار. وكلُّ سطرٍ يقول **ماذا يفعل الطالبُ هنا**، لا اسمَ
// العنصر وحده. والوضعيةُ تتبع المعنى: «تمام» للأرقام، يقرأ للتعليم،
// قبّعةُ التخرّج للمنح — و«هلا» يرفع إصبعه لكل ما سواها.
class HomeTour {
  HomeTour._();

  static const String id = 'home';

  // 📍 المراسي — تُلفّ بها عناصرُ [HomeTab].
  static const String avatar = 'home.avatar';
  static const String bell = 'home.bell';
  static const String settings = 'home.settings';
  static const String stats = 'home.stats';
  static const String education = 'home.education';
  static const String banners = 'home.banners';
  static const String analysis = 'home.analysis';
  static const String focus = 'home.focus';
  static const String resume = 'home.resume';

  static List<TourStep> steps(String fullName) {
    final first = fullName.trim().split(RegExp(r'\s+')).first;
    // الاسمُ الافتراضيّ («طالب مسار») واسمُ حساب الزائر ليسا اسماً — لا يُنادى بهما.
    const notNames = {'طالب مسار', 'زائر', 'ضيف'};
    final hello = (first.isEmpty || notNames.contains(fullName.trim()))
        ? "مرحباً! أنا مسار، رفيقك التعليمي"
        : "مرحباً $first! أنا مسار، رفيقك التعليمي";
    return [
      TourStep(
        title: hello,
        body: "دعني أعرّفك على التطبيق في جولةٍ سريعة — اضغط «التالي» "
            "لأريك كل مكان.",
      ),
      const TourStep(
        anchor: avatar,
        shape: TourShape.circle,
        padding: 6,
        title: "هذه صفحتك الشخصية",
        body: "اضغط على صورتك لتفتح «معلومات الطالب»: تحليلُ مستواك في كل "
            "مادة، ونقاطُ قوّتك وضعفك، ومنها تغيّر صورتك.",
      ),
      const TourStep(
        anchor: bell,
        shape: TourShape.circle,
        padding: 8,
        title: "الإشعارات",
        body: "هنا تصلك المنحُ الجديدة ومواعيدُها وأخبارُ مسار — والرقمُ "
            "الأحمر يخبرك بما لم تقرأه بعد.",
      ),
      const TourStep(
        anchor: settings,
        shape: TourShape.circle,
        padding: 8,
        title: "الإعدادات",
        body: "غيّر صفّك ومسارك، والوضعَ الداكن، وحجمَ خطّ الإجابات — ومن "
            "هنا تعيد هذا الشرح متى احتجته.",
      ),
      const TourStep(
        anchor: stats,
        pose: MasarCharacter.ask,
        title: "إحصاءاتك",
        body: "عددُ محادثاتك، والموادُّ التي درستها، والإجاباتُ التي حفظتها "
            "— واضغط «محفوظ» لتفتح محفوظاتك.",
      ),
      const TourStep(
        anchor: education,
        pose: MasarCharacter.study,
        optional: true,
        title: "قسم التعليم",
        body: "قلبُ مسار: اختر المادة والدرس، واطلب شرحاً أو تلخيصاً، أو "
            "اسأل أي سؤالٍ من كتابك — ويمكنك تصوير السؤال بالكاميرا.",
      ),
      const TourStep(
        anchor: banners,
        optional: true,
        title: "أهمّ ما في مسار",
        body: "بطاقاتٌ تتقلّب وحدها بأحدث الأخبار — اضغط على أيٍّ منها "
            "لتنتقل إلى قسمها مباشرة.",
      ),
      const TourStep(
        anchor: analysis,
        pose: MasarCharacter.ask,
        optional: true,
        title: "تحليل مستواي",
        body: "اعرف مستواك في كل مادة من نتائج اختباراتك، وما الذي يحتاج "
            "منك مراجعة قبل الامتحان.",
      ),
      const TourStep(
        anchor: focus,
        optional: true,
        title: "الدروس التي تحتاج تركيز",
        body: "بعد كل اختبار تظهر هنا الدروسُ التي أخطأت فيها أكثر — اضغط "
            "على أحدها ليشرحه لك مسار أو لتعيد اختباره.",
      ),
      const TourStep(
        anchor: resume,
        optional: true,
        title: "أكمل من حيث توقفت",
        body: "آخرُ محادثةٍ لك محفوظةٌ هنا — اضغطها لتعود إلى الدرس نفسه "
            "والمحادثة نفسها.",
      ),
      TourStep(
        anchor: MasarBottomNav.anchorOf(MasarTab.quiz),
        padding: 0,
        pose: MasarCharacter.ask,
        title: "اختبر نفسك",
        body: "اختبارٌ قصير من الدروس التي تختارها، يصحَّح فوراً ويقيّم "
            "مستواك.",
      ),
      TourStep(
        anchor: MasarBottomNav.anchorOf(MasarTab.tutor),
        shape: TourShape.circle,
        padding: 10,
        title: "زرّ مسار",
        body: "من أي مكان، اضغط هنا لتفتح قسم التعليم وتبدأ محادثتك معي "
            "مباشرة.",
      ),
      TourStep(
        anchor: MasarBottomNav.anchorOf(MasarTab.scholarships),
        padding: 0,
        pose: MasarCharacter.guide,
        title: "المنح",
        body: "منحٌ داخل الدولة وخارجها بشروطها ومواعيدها — واسألني عن أي "
            "منحة وأنا أشرحها لك.",
      ),
      TourStep(
        anchor: MasarBottomNav.anchorOf(MasarTab.services),
        padding: 0,
        title: "الخدمات",
        body: "خدماتٌ إضافية للطالب — قريباً بإذن الله.",
      ),
      const TourStep(
        pose: MasarCharacter.ask,
        title: "أحسنت، أصبحت تعرف كل شيء!",
        body: "وإن احتجت هذا الشرح مرةً أخرى تجده في الإعدادات. "
            "لنبدأ؟",
      ),
    ];
  }
}
