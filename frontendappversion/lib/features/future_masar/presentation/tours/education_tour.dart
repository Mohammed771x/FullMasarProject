import '../../../../core/tour/masar_tour.dart';
import '../../../../core/widgets/masar_character.dart';
import '../../../chat/data/models/chat_model.dart';

// ==========================================
// 🎓 جولةُ قسم التعليم — الشاشة ثم القائمة الجانبية (المرحلة ٣)
// ==========================================
// 🧭 **الترتيبُ ترتيبُ الاستعمال**: من أين تختار (القائمة · الدليل) ← كيف
//    تجهّز درسك (إعدادات الجلسة: الوضع · المصدر · الدرس · الصفحات) ← كيف
//    تسأل (الكتابة · الكاميرا · التفكير · الصوت · الإرسال) ← أين يظهر الردّ
//    ← ثم تُفتح القائمةُ الجانبية ويُشرح ما فيها.
//
// 🎭 **لا تُشرح شاشةٌ فارغة** (أمرُ المالك ٢٠٢٦-٠٩-٢٧): طالبٌ لم يسأل بعد
//    يرى ردّاً توضيحياً ومحادثاتٍ توضيحية — عناوينُها «(مثال)» — تُعرض في
//    الذاكرة أثناء الجولة وحدها ثم تعود الشاشةُ إلى حقيقتها. لا يُحفظ منها
//    شيء ([demoMessages] · [demoConversations]).
//
// 🎬 وما يلزم فتحُه قبل شرحه (البطاقةُ المطويّة · القائمة · الردّ التوضيحي)
//    يُفتح بـ[TourStep.before] — والشاشةُ تعطي الأفعالَ، وهذا الملفُّ الكلام.
class EducationTour {
  EducationTour._();

  static const String id = 'education';

  // 📍 الشاشة.
  static const String menu = 'edu.menu';
  static const String help = 'edu.help';
  static const String quota = 'edu.quota';
  static const String panel = 'edu.panel';
  static const String modes = 'edu.modes';
  static const String math = 'edu.math';
  static const String source = 'edu.source';
  static const String lesson = 'edu.lesson';
  static const String pages = 'edu.pages';
  static const String suggest = 'edu.suggest';
  static const String bar = 'edu.bar';
  static const String camera = 'edu.camera';
  static const String thinking = 'edu.thinking';
  static const String mic = 'edu.mic';
  static const String send = 'edu.send';
  static const String reply = 'edu.reply';
  static const String actions = 'edu.actions';
  static const String followUps = 'edu.followUps';

  // 📍 القائمة الجانبية.
  static const String newChat = 'edu.drawer.new';
  static const String resources = 'edu.drawer.resources';
  static const String search = 'edu.drawer.search';
  static const String subjects = 'edu.drawer.subjects';
  static const String chats = 'edu.drawer.chats';
  static const String home = 'edu.drawer.home';

  /// 🎭 **سؤالٌ وردٌّ توضيحيان** — بشكل رسائل المتحكّم نفسِه، فتُرسم بما
  ///    يُرسم به الحقيقيّ (الفقاعة · النسخ · الحفظ · اقتراحات المتابعة).
  ///    `tourDemo` وسمٌ لا يقرؤه إلا من أراد أن يعرف أنها ليست حقيقية.
  static List<Map<String, dynamic>> demoMessages(String subject) => [
    {"role": "user", "text": "اشرح لي الدرس", "tourDemo": true},
    {
      "role": "ai",
      "text":
          "**(مثال) هكذا يظهر ردّي** ✨\n\n"
          "شرحٌ مرتّبٌ من كتابك، خطوةً خطوة.",
      "animating": false,
      "tourDemo": true,
    },
  ];

  /// 🎭 **محادثاتٌ توضيحية** للقائمة الجانبية حين لا محادثات بعد.
  static List<ChatConversation> demoConversations({
    required String subject,
    required String mode,
    required int grade,
    required String track,
    bool teacher = false,
  }) {
    final now = DateTime.now();
    ChatConversation c(int i, String title) => ChatConversation(
      id: 'tour-demo-chat-$i',
      title: title,
      subject: subject,
      mode: mode,
      grade: grade,
      track: track,
      createdAt: now.subtract(Duration(days: i)),
      lastUpdated: now.subtract(Duration(days: i)),
    );
    return teacher
        ? [c(0, "(مثال) خطة الدرس الأول"), c(1, "(مثال) واجب الوحدة الأولى")]
        : [
            c(0, "(مثال) شرح الدرس الأول"),
            c(1, "(مثال) أسئلة على الوحدة الأولى"),
          ];
  }

  static List<TourStep> steps({
    required bool guest,
    bool wazari = false,
    bool demoLesson = false,
    required bool demoReply,
    required bool demoChats,
    required Future<void> Function() openPanel,
    required Future<void> Function() showReply,
    required Future<void> Function() openDrawer,
    required Future<void> Function() closeDrawer,
  }) {
    String t(bool demo, String title) => demo ? "$title (مثال)" : title;
    return [
      const TourStep(
        title: "أهلاً بك في قسم التعليم",
        body:
            "هنا مدرّسك الخاص: يشرح ويلخّص ويجيب من كتابك نفسه — دعني "
            "أعرّفك بالمكان.",
      ),
      const TourStep(
        anchor: menu,
        shape: TourShape.circle,
        padding: 10,
        pose: MasarCharacter.guide,
        title: "القائمة",
        body:
            "منها تختار المادة، وتبدأ محادثةً جديدة، وترجع إلى محادثاتك — "
            "سأفتحها لك في آخر الجولة.",
      ),
      const TourStep(
        anchor: help,
        shape: TourShape.circle,
        padding: 10,
        pose: MasarCharacter.ask,
        title: "دليل الاستخدام",
        body:
            "شرحُ كل وضعٍ ونطاقُ صفحات المادة — ومنه تعيد هذه الجولة بزرّ "
            "«شرح الواجهة الرئيسية».",
      ),
      TourStep(
        anchor: quota,
        optional: true,
        padding: 6,
        title: "رصيدُك اليوم",
        body: guest
            ? "كم سؤالاً تجريبياً بقي لك — سجّل مجاناً ليصير لك رصيدٌ "
                  "يتجدّد كل يوم."
            : "كم سؤالاً بقي لك اليوم — ويتجدّد كل يوم بعد منتصف الليل.",
      ),
      TourStep(
        anchor: panel,
        padding: 6,
        pose: MasarCharacter.study,
        before: openPanel,
        title: "إعدادات الجلسة",
        body:
            "هنا تجهّز درسك قبل أن تسأل — واضغط رأسها لتطويها أو تفتحها "
            "متى شئت.",
      ),
      TourStep(
        anchor: modes,
        optional: true,
        padding: 6,
        title: "اختر الوضع",
        body: wazari
            ? "«شرح» خطوةً خطوة · «تلخيص» نقاطٌ مركّزة · «سؤال» لسؤالٍ "
                  "محدّد · «اختبارات» تختبر نفسك · «وزاري» أسئلةُ الوزارة."
            : "«شرح» خطوةً خطوة · «تلخيص» نقاطٌ مركّزة · «سؤال» لسؤالٍ "
                  "محدّد · «اختبارات» تختبر فيها نفسك.",
      ),
      const TourStep(
        anchor: math,
        optional: true,
        padding: 6,
        title: "فرعُ الرياضيات",
        body: "اختر الفرع أولاً، ثم الدرس — وأحلّ معك مسائله خطوةً خطوة.",
      ),
      const TourStep(
        anchor: source,
        optional: true,
        padding: 6,
        title: "مصدر المحتوى",
        body:
            "«وضع الدروس» تختار فيه درساً باسمه، و«وضع الوحدات» تختار "
            "وحدةً وصفحاتٍ من كتابك.",
      ),
      TourStep(
        anchor: lesson,
        optional: true,
        padding: 6,
        pose: MasarCharacter.study,
        title: t(demoLesson, "الوحدة والدرس"),
        body: demoLesson
            ? "محتوى هذه المادة يُضاف قريباً — وحين يصل تختار منه وحدتك "
                  "ودرسك هكذا، وأشرحه لك من كتابك."
            : "من هنا تختار ما تدرسه الآن — وأشرح لك من كتابك ما اخترته "
                  "بالضبط.",
      ),
      const TourStep(
        anchor: pages,
        optional: true,
        padding: 6,
        title: "صفحاتُ كتابك",
        body:
            "اختر الصفحات التي تريدها — وتظهر فوق خانة الكتابة لتعرف عمّا "
            "تسأل.",
      ),
      const TourStep(
        anchor: suggest,
        optional: true,
        padding: 4,
        pose: MasarCharacter.ask,
        title: "اقتراحاتٌ جاهزة",
        body: "لا تدري ماذا تطلب؟ اضغط اقتراحاً وأبدأ فوراً.",
      ),
      const TourStep(
        anchor: bar,
        padding: 6,
        pose: MasarCharacter.ask,
        title: "اكتب سؤالك",
        body: "اكتب هنا ما تريد: سؤالاً، أو مسألة، أو «اشرح لي الدرس».",
      ),
      const TourStep(
        anchor: camera,
        shape: TourShape.circle,
        padding: 8,
        title: "صوّر مسألتك",
        body:
            "التقط صورةَ المسألة من كتابك أو اخترها من المعرض — وتقصّها "
            "وتكتب عليها قبل الإرسال.",
      ),
      const TourStep(
        anchor: thinking,
        optional: true,
        shape: TourShape.circle,
        padding: 8,
        pose: MasarCharacter.study,
        title: "وضعُ التفكير",
        body: "للمسائل الصعبة: أتمهّل لأحلّها بدقّةٍ أكبر — والعاديُّ أسرع.",
      ),
      const TourStep(
        anchor: mic,
        shape: TourShape.circle,
        padding: 8,
        title: "تكلّم بدل الكتابة",
        body: "سجّل سؤالك بصوتك — وأحوّله لك نصّاً مرتّباً.",
      ),
      const TourStep(
        anchor: send,
        shape: TourShape.circle,
        padding: 8,
        title: "أرسل",
        body: "ويصير أحمرَ أثناء إجابتي — لتوقفها متى شئت.",
      ),
      TourStep(
        anchor: reply,
        // محادثةٌ حقيقية آخرُها سؤالٌ بلا ردّ ⇒ لا فقاعةَ تُشرح.
        optional: !demoReply,
        padding: 6,
        pose: MasarCharacter.study,
        before: showReply,
        title: t(demoReply, "هنا يظهر ردّي"),
        body:
            "شرحٌ مرتّبٌ من كتابك بالمعادلات والجداول — وتحته «نسخ» و«حفظ» "
            "لتجده في المحفوظات.",
      ),
      TourStep(
        anchor: followUps,
        optional: true,
        padding: 4,
        pose: MasarCharacter.ask,
        title: t(demoReply, "أكمل من هنا"),
        body: "اقتراحاتٌ للخطوة التالية تحت ردّي — اضغط واحداً لنكمل.",
      ),
      TourStep(
        anchor: newChat,
        padding: 6,
        pose: MasarCharacter.guide,
        before: openDrawer,
        title: "محادثةٌ جديدة",
        body:
            "هذه القائمة الجانبية — ومن هنا تبدأ من جديد بدرسٍ آخر، "
            "ومحادثاتُك السابقة تبقى محفوظة.",
      ),
      const TourStep(
        anchor: resources,
        padding: 6,
        title: "الموارد",
        body: "كتبُ صفّك وروابطُ موادّه في مكانٍ واحد.",
      ),
      const TourStep(
        anchor: search,
        padding: 6,
        pose: MasarCharacter.ask,
        title: "ابحث في محادثاتك",
        body:
            "اكتب كلمةً وأجدها لك في كل محادثاتك — وأفتحها على الرسالة "
            "نفسها.",
      ),
      const TourStep(
        anchor: subjects,
        padding: 6,
        pose: MasarCharacter.study,
        title: "اختر المادة",
        body: "كلُّ موادّ صفّك هنا — والمختارةُ عليها علامة ✓.",
      ),
      TourStep(
        anchor: chats,
        optional: true,
        padding: 6,
        title: t(demoChats, "محادثاتك"),
        body:
            "كلُّ محادثةٍ بدرسها — افتحها لتكمل، أو غيّر اسمها ✏️ أو "
            "احذفها 🗑️.",
      ),
      const TourStep(
        anchor: home,
        optional: true,
        shape: TourShape.circle,
        padding: 10,
        title: "العودة للرئيسية",
        body: "ومن هنا ترجع إلى الشاشة الرئيسية.",
      ),
      TourStep(
        pose: MasarCharacter.ask,
        before: closeDrawer,
        title: "جاهز؟ اسألني عن أي درس!",
        body: "وإن نسيت شيئاً، افتح الدليل 💡 واضغط «شرح الواجهة الرئيسية».",
      ),
    ];
  }
}
