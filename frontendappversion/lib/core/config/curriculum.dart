// ==========================================
// 🎓 المنهج: الصفوف والمسارات والمواد
// ==========================================
// ⚠️ هذا الملف هو **المصدر الوحيد** لقوائم المواد.
//    لتعديل مواد أي صف/مسار عدّل هنا فقط — لا تعدّل شاشة.
//
// حالة المحتوى في الباك اند اليوم: **الصف الثالث الثانوي العلمي فقط**.
//    بقية الصفوف بنيتها جاهزة ومحتواها لم يُضف بعد،
//    ولذلك تُعرض موادها بشارة "قيد الإضافة 🚧".

/// المسار الدراسي. الصف الأول الثانوي موحّد بلا مسار.
enum Track { none, scientific, literary }

extension TrackLabel on Track {
  String get label => switch (this) {
        Track.none => "عام",
        Track.scientific => "علمي",
        Track.literary => "أدبي",
      };

  /// المفتاح المستخدم في التخزين وفي طلبات الـ API.
  String get key => switch (this) {
        Track.none => "عام",
        Track.scientific => "علمي",
        Track.literary => "أدبي",
      };

  static Track fromKey(String? k) => switch (k) {
        "علمي" => Track.scientific,
        "أدبي" => Track.literary,
        _ => Track.none,
      };
}

class Curriculum {
  Curriculum._();

  static const int minGrade = 1;
  static const int maxGrade = 3;

  static String gradeLabel(int g) => switch (g) {
        1 => "الأول الثانوي",
        2 => "الثاني الثانوي",
        _ => "الثالث الثانوي",
      };

  static String gradeShort(int g) => switch (g) {
        1 => "الأول",
        2 => "الثاني",
        _ => "الثالث",
      };

  /// هل هذا الصف ينقسم إلى علمي/أدبي؟ (الأول الثانوي موحّد)
  static bool hasTracks(int grade) => grade >= 2;

  /// المسارات المتاحة لصف معيّن.
  static List<Track> tracksFor(int grade) =>
      hasTracks(grade) ? const [Track.scientific, Track.literary] : const [Track.none];

  /// يصحّح المسار ليطابق الصف (الأول الثانوي ← بلا مسار).
  static Track normalizeTrack(int grade, Track t) {
    if (!hasTracks(grade)) return Track.none;
    return t == Track.none ? Track.scientific : t;
  }

  // ===== المواد (قوائم المالك الرسمية — 2026-08-27) =====
  static const List<String> _g1Common = [
    "عربي", "انجليزي", "رياضيات", "فيزياء", "كيمياء", "احياء", "تاريخ", "جغرافيا", "مجتمع",
  ];

  static const List<String> _g2Scientific = [
    "عربي", "انجليزي", "فيزياء", "كيمياء", "احياء", "رياضيات",
  ];

  static const List<String> _g2Literary = [
    "عربي", "انجليزي", "رياضيات", "تاريخ", "جغرافيا", "علم الاقتصاد", "علم الاجتماع",
  ];

  static const List<String> _g3Scientific = [
    "احياء", "فيزياء", "كيمياء", "عربي", "انجليزي", "رياضيات",
  ];

  static const List<String> _g3Literary = [
    "عربي", "انجليزي", "رياضيات", "تاريخ", "جغرافيا", "مبادئ علم الخرائط", "فلسفة", "منطق",
  ];

  /// مواد صف ومسار معيّنين.
  static List<String> subjectsFor(int grade, Track track) {
    final t = normalizeTrack(grade, track);
    if (grade == 1) return _g1Common;
    if (grade == 2) return t == Track.literary ? _g2Literary : _g2Scientific;
    return t == Track.literary ? _g3Literary : _g3Scientific;
  }

  // ===== التوفّر =====
  // قرار المالك: كل المواد مفتوحة. توفّر المحتوى الفعلي يأتي من
  // GET /content/capabilities — وإن غاب الملف يرد الخادم رسالة ودّية.
  static bool isAvailable(int grade, Track track, String subject) =>
      subjectsFor(grade, track).contains(subject);

  /// أول مادة في القائمة (كلها مفتوحة الآن).
  static String defaultSubject(int grade, Track track) => subjectsFor(grade, track).first;

  /// وضع الاختبارات — الشريحة الخامسة بجوار الوزاري ([31§3]).
  static const String quizMode = "اختبارات";

  /// الأوضاع المتاحة لمادة (الرياضيات بلا وضع "تلخيص").
  ///
  /// قرار المالك حرفياً ([31§9]):
  ///   • **الصف الثالث (علمي وأدبي): الوزاري كما هو — لا يُحذف ولا يُغيَّر**،
  ///     وتُضاف **بجواره** شريحة «اختبارات». خمس شرائح.
  ///   • **الأول والثاني (علمي وأدبي): الوزاري يُحذف** (امتحان وطني للثالث)،
  ///     و«اختبارات» تحلّ مكانه.
  ///   • **الاختبارات** تُبنى من الدروس، لكل المواد بلا استثناء.
  static List<String> modesFor(
    String subject, {
    int grade = 3,
    bool examsAvailable = true,
  }) {
    // ★ الثالث يحتفظ بالوزاري دائماً بصرف النظر عن أي كشف من الخادم.
    //   وغيره يراه فقط إن ظهر له بنك أسئلة يوماً.
    final showExams = grade == 3 || examsAvailable;

    final modes = <String>["شرح"];
    if (subject != "رياضيات") modes.add("تلخيص");
    modes.add("سؤال");
    if (showExams) modes.add("وزاري");
    // 🧠 **الاختبارات تظهر دائماً ولكل الصفوف** — الطالب يرى الباب مفتوحاً،
    //    وشاشة الإعداد وحدها تقول «دروس هذه المادة لم تُضف بعد 🚧» إن لزم.
    //    (إخفاء الشريحة كان يجعل القسم يبدو غير موجود أصلاً.)
    modes.add(quizMode);
    return modes;
  }
}
