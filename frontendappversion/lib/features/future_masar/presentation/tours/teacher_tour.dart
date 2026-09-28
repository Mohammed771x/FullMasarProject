import '../../../../core/tour/masar_tour.dart';
import '../../../../core/widgets/masar_character.dart';
import 'education_tour.dart';

// ==========================================
// 👨‍🏫 جولةُ قسم المعلّم — الشاشة ثم القائمة الجانبية (المرحلة ٦)
// ==========================================
// 🧭 شاشةُ المعلّم هي شاشةُ المحادثة نفسُها ([MainChatScreen]) بأدواتٍ مكان
//    الأوضاع — فالمراسي المشتركة (القائمة · الدليل · البطاقة · الكتابة ·
//    الردّ · الدرج) من [EducationTour]، وما يخصّ المعلّم هنا: الأدوات ·
//    الدرس · زرّ التوليد · الحساب · المحفوظات · الإشعارات · مبدّل الصف.
//
// 📝 **أفصلُ من جولة المنح** (أمرُ المالك ٢٠٢٦-٠٩-٢٧: «المعلم فصّل شوية»):
//    المعلّمُ يستعمل الأدوات للتحضير يومياً، فكلُّ أداةٍ تُسمّى ويُقال
//    ما تُخرجه — والمنحُ نظرةٌ عابرة.
//
// 🎭 وكالطالب: مادةٌ بلا دروس ⇒ وحدةٌ ودرسٌ «(مثال)»، ولا ردَّ بعد ⇒ خطةٌ
//    توضيحية، ولا محادثاتِ ⇒ محادثاتٌ توضيحية — في الذاكرة وحدها.
class TeacherTour {
  TeacherTour._();

  static const String id = 'teacher';

  // 📍 ما يخصّ المعلّم.
  static const String tools = 'teach.tools';
  static const String lesson = 'teach.lesson';
  static const String generate = 'teach.generate';
  static const String account = 'teach.account';
  static const String saved = 'teach.saved';
  static const String notifications = 'teach.notifications';
  static const String grades = 'teach.grades';

  /// 🎭 طلبٌ وردٌّ توضيحيان بشكل ردود الأدوات.
  static List<Map<String, dynamic>> demoMessages(String subject) => [
    {"role": "user", "text": "خطة درس لحصة ٤٥ دقيقة", "tourDemo": true},
    {
      "role": "ai",
      "text":
          "**(مثال) خطة درس** 📖\n\n"
          "الأهداف · الخطوات · النشاط · التقويم.",
      "animating": false,
      "tourDemo": true,
    },
  ];

  static List<TourStep> steps({
    required bool guest,
    required bool demoLesson,
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
        title: "أهلاً بك يا أستاذ",
        body:
            "هنا مساعدك في التحضير: خططُ دروس، وتبسيطُ مفاهيم، وواجباتٌ "
            "بسلّم تصحيح — كلُّها من نصّ درسك في الكتاب.",
      ),
      const TourStep(
        anchor: EducationTour.menu,
        shape: TourShape.circle,
        padding: 10,
        pose: MasarCharacter.guide,
        title: "القائمة",
        body:
            "حسابك ومحفوظاتك وصفوفك وموادك ومحادثاتك — سأفتحها لك في آخر "
            "الجولة.",
      ),
      const TourStep(
        anchor: EducationTour.help,
        shape: TourShape.circle,
        padding: 10,
        pose: MasarCharacter.ask,
        title: "دليلُ الأداة",
        body:
            "شرحُ الأداة المفتوحة — ومنه تعيد هذه الجولة بزرّ «شرح الواجهة "
            "الرئيسية».",
      ),
      TourStep(
        anchor: EducationTour.quota,
        optional: true,
        padding: 6,
        title: "رصيدُك اليوم",
        body: guest
            ? "طلباتُك التجريبية الباقية — سجّل لتحصل على رصيدٍ يومي."
            : "كم طلباً بقي لك اليوم — ويتجدّد كل يوم.",
      ),
      TourStep(
        anchor: EducationTour.panel,
        padding: 6,
        pose: MasarCharacter.teach,
        before: openPanel,
        title: "إعدادات الجلسة",
        body: "هنا أدواتك وحقولها — اضغط رأسها لتطويها أو تفتحها متى شئت.",
      ),
      const TourStep(
        anchor: tools,
        padding: 6,
        pose: MasarCharacter.teach,
        title: "أدواتك الأربع",
        body:
            "«خطة درس» أهدافٌ وخطواتٌ بأزمنتها · «تبسيط مفهوم» تشبيهاتٌ "
            "وسؤالٌ كاشف · «واجب واختبار» بسلّم تصحيح · «اسأل المساعد» "
            "لأي سؤالٍ تربوي.",
      ),
      TourStep(
        anchor: lesson,
        optional: true,
        padding: 6,
        pose: MasarCharacter.study,
        title: t(demoLesson, "الوحدة والدرس"),
        body: demoLesson
            ? "دروسُ هذه المادة تُضاف قريباً — وحين تصل تختار منها هكذا، "
                  "وتُبنى الأداةُ من نصّ الدرس نفسه."
            : "كلُّ أداةٍ تُبنى من نصّ الدرس الذي تختاره هنا — لا من "
                  "معلوماتٍ عامّة.",
      ),
      const TourStep(
        anchor: generate,
        optional: true,
        padding: 6,
        pose: MasarCharacter.ask,
        title: "زرُّ التوليد",
        body: "يضيء حين تكتمل الحقول — والنتيجةُ تظهر في المحادثة لتناقشها.",
      ),
      const TourStep(
        anchor: EducationTour.bar,
        padding: 6,
        pose: MasarCharacter.ask,
        title: "ناقش واطلب",
        body:
            "اسأل سؤالاً تربوياً، أو اطلب تعديل ما ولّدته: «أقصر»، «أضف "
            "نشاطاً»، «سؤالاً أصعب».",
      ),
      const TourStep(
        anchor: EducationTour.camera,
        shape: TourShape.circle,
        padding: 8,
        title: "صوّر صفحة",
        body: "صفحةٌ من الكتاب أو ورقةُ طالب — وأبني عليها.",
      ),
      const TourStep(
        anchor: EducationTour.mic,
        shape: TourShape.circle,
        padding: 8,
        title: "تكلّم",
        body: "سجّل طلبك بصوتك — وأحوّله نصّاً مرتّباً.",
      ),
      TourStep(
        anchor: EducationTour.reply,
        optional: !demoReply,
        padding: 6,
        pose: MasarCharacter.teach,
        before: showReply,
        title: t(demoReply, "هنا تظهر النتيجة"),
        body:
            "انسخها لورقة التحضير، أو احفظها ⭐ لتجدها في «المحفوظات» من "
            "القائمة.",
      ),
      TourStep(
        anchor: EducationTour.followUps,
        optional: true,
        padding: 4,
        pose: MasarCharacter.ask,
        title: t(demoReply, "خطوتُك التالية"),
        body: "اقتراحاتٌ تحت النتيجة — اضغط واحداً لتكمل عليها.",
      ),
      TourStep(
        anchor: EducationTour.newChat,
        padding: 6,
        pose: MasarCharacter.guide,
        before: openDrawer,
        title: "محادثةٌ جديدة",
        body:
            "هذه قائمتك — ومن هنا تبدأ تحضيراً جديداً، والسابقُ يبقى "
            "محفوظاً.",
      ),
      const TourStep(
        anchor: EducationTour.search,
        padding: 6,
        pose: MasarCharacter.ask,
        title: "ابحث في محادثاتك",
        body: "كلمةٌ واحدة وأجدها لك في كل ما حضّرته.",
      ),
      const TourStep(
        anchor: account,
        padding: 6,
        title: "حسابك",
        body: "اسمك والصفّ الذي تدرّسه — واضغطه لتفتح الإعدادات.",
      ),
      const TourStep(
        anchor: saved,
        padding: 6,
        pose: MasarCharacter.study,
        title: "المحفوظات",
        body: "كلُّ خطةٍ أو واجبٍ حفظته — جاهزٌ للنسخ والطباعة.",
      ),
      const TourStep(
        anchor: notifications,
        padding: 6,
        title: "الإشعارات",
        body: "جديدُ مسار وتنبيهاتُه لك.",
      ),
      const TourStep(
        anchor: grades,
        padding: 6,
        pose: MasarCharacter.teach,
        title: "الصف الدراسي",
        body: "تدرّس أكثر من صف؟ بدّل هنا بلمسة — ولكل صفٍّ محادثاتُه.",
      ),
      const TourStep(
        anchor: EducationTour.subjects,
        padding: 6,
        pose: MasarCharacter.study,
        title: "المادة",
        body: "اختر المادة التي تحضّر لها — والمختارةُ عليها علامة ✓.",
      ),
      TourStep(
        anchor: EducationTour.chats,
        optional: true,
        padding: 6,
        title: t(demoChats, "محادثاتك"),
        body:
            "كلُّ تحضيرٍ بدرسه وأداته — افتحه لتكمل، أو غيّر اسمه ✏️ أو "
            "احذفه 🗑️.",
      ),
      TourStep(
        pose: MasarCharacter.teach,
        before: closeDrawer,
        title: "جاهز يا أستاذ!",
        body:
            "اختر أداةً ودرساً وابدأ — وإن نسيت شيئاً فالدليلُ 💡 فيه «شرح "
            "الواجهة الرئيسية».",
      ),
    ];
  }
}
