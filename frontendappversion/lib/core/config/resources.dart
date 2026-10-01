import 'curriculum.dart';

// ==========================================
// 📚 مركز الموارد: روابط الملخصات والوزاريات
// ==========================================
// ⚠️ هذا الملف هو **المصدر الوحيد** لروابط الموارد.
//    مركز الموارد في التطبيق يتبع الصف والمسار المختارَين:
//    مواده = `Curriculum.subjectsFor(grade, track)` بالضبط،
//    وروابط كل مادة تُقرأ من هنا.
//
// ➕ **لإضافة روابط صف جديد:** أضِف مواده داخل مفتاح نطاقه في `_byScope`
//    (مثلاً `"g2|علمي"`)، ولا تلمس أي شاشة. المواد بلا روابط تظهر
//    تلقائياً بشارة «قريباً».
//
// 📖 لكلّ مادةٍ في كلّ صفٍّ سطرُ «كتاب …» جاهز — ينتظر رابطه فقط.

/// رابط مورد واحد داخل مادة.
class ResourceLink {
  final String name;
  final String url;
  const ResourceLink(this.name, this.url);
}

class Resources {
  Resources._();

  /// وزاريات الثالث العلمي — مجلّد واحد مشترك بين المواد الست.
  static const String _wazariG3Sci =
      "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b";

  /// مفتاح النطاق: "g{الصف}|{المسار}" — نفس منطق نطاق المحادثات.
  static String scopeKey(int grade, Track track) =>
      "g$grade|${Curriculum.normalizeTrack(grade, track).key}";

  // ===== الروابط =====
  // 📖 **الكتب: الصق الرابط بين علامتَي التنصيص الفارغتين وحسب.**
  //    `ResourceLink("كتاب الأحياء", "")` ← `ResourceLink("كتاب الأحياء", "https://…")`
  //    السطرُ برابطٍ فارغ **لا يظهر للطالب** ([forSubject] يُسقطه) — فلا زرَّ
  //    ميّت، والمادةُ بلا أي رابطٍ ممتلئ تبقى «قريباً». ثم أعِد بناء التطبيق.
  static const Map<String, Map<String, List<ResourceLink>>> _byScope = {
    // ───── الصف الأول الثانوي — عام ─────
    "g1|عام": {
      "عربي": [ResourceLink("كتاب اللغة العربية", "")],
      "انجليزي": [ResourceLink("كتاب اللغة الإنجليزية", "")],
      "رياضيات": [ResourceLink("كتاب الرياضيات", "")],
      "فيزياء": [ResourceLink("كتاب الفيزياء", "")],
      "كيمياء": [ResourceLink("كتاب الكيمياء", "")],
      "احياء": [ResourceLink("كتاب الأحياء", "")],
      "تاريخ": [ResourceLink("كتاب التاريخ", "")],
      "جغرافيا": [ResourceLink("كتاب الجغرافيا", "")],
      "مجتمع": [ResourceLink("كتاب المجتمع", "")],
    },

    // ───── الصف الثاني الثانوي — علمي ─────
    "g2|علمي": {
      "عربي": [ResourceLink("كتاب اللغة العربية", "")],
      "انجليزي": [ResourceLink("كتاب اللغة الإنجليزية", "")],
      "فيزياء": [ResourceLink("كتاب الفيزياء", "")],
      "كيمياء": [ResourceLink("كتاب الكيمياء", "")],
      "احياء": [ResourceLink("كتاب الأحياء", "")],
      "رياضيات": [ResourceLink("كتاب الرياضيات", "")],
    },

    // ───── الصف الثاني الثانوي — أدبي ─────
    "g2|أدبي": {
      "عربي": [ResourceLink("كتاب اللغة العربية", "")],
      "انجليزي": [ResourceLink("كتاب اللغة الإنجليزية", "")],
      "رياضيات": [ResourceLink("كتاب الرياضيات", "")],
      "تاريخ": [ResourceLink("كتاب التاريخ", "")],
      "جغرافيا": [ResourceLink("كتاب الجغرافيا", "")],
      "علم الاقتصاد": [ResourceLink("كتاب علم الاقتصاد", "")],
      "علم الاجتماع": [ResourceLink("كتاب علم الاجتماع", "")],
    },

    // ───── الصف الثالث الثانوي — علمي ─────
    "g3|علمي": {
      "رياضيات": [
        ResourceLink("كتاب الرياضيات", ""),
        ResourceLink(
          "ملخص التفاضل",
          "https://drive.google.com/drive/folders/1hIojvkK09LT7IcqaK5aGoEV_vrrVZjLs",
        ),
        ResourceLink(
          "ملخص الجبر",
          "https://drive.google.com/drive/folders/1m8QVLyM6tbG5buQNDdGwNCRbV_28bsxA",
        ),
        ResourceLink(
          "ملخص التكامل",
          "https://drive.google.com/drive/u/1/folders/1ao83kRRVKk40VOAsgnLcjDeOodIyHNri",
        ),
        ResourceLink(
          "ملخص الهندسة",
          "https://drive.google.com/drive/u/1/folders/1TWxdgszrwzxCQW2uRSXkv7VZrIKIGvGV",
        ),
        ResourceLink(
          "ملخص الاحتمالات",
          "https://drive.google.com/drive/u/1/folders/1Sx-ZJqwjORzFwQR5EDVrVd32mkjkI_lh",
        ),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "احياء": [
        ResourceLink("كتاب الأحياء", ""),
        ResourceLink(
          "ملخصات الأحياء",
          "https://drive.google.com/drive/u/1/folders/1LLzIsWFKiZOkrr6DUaagm9RVmBdKKDQn",
        ),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "كيمياء": [
        ResourceLink("كتاب الكيمياء", ""),
        ResourceLink(
          "ملخصات الكيمياء",
          "https://drive.google.com/drive/u/1/folders/1_9YpbhSvG4-qcVihLU10o8muFFPh0Gqt",
        ),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "فيزياء": [
        ResourceLink("كتاب الفيزياء", ""),
        ResourceLink(
          "ملخص الفيزياء",
          "https://drive.google.com/drive/folders/1ATQPwJNXYf-yidgXjhkW7E7AaqYev2vc",
        ),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "عربي": [
        ResourceLink("كتاب اللغة العربية", ""),
        ResourceLink(
          "ملخص النحو",
          "https://drive.google.com/drive/u/1/folders/13Ec4BtxzxvJTOrR9_BriUGfr1HszU3M1",
        ),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "انجليزي": [
        ResourceLink("كتاب اللغة الإنجليزية", ""),
        ResourceLink(
          "ملخصات الانجليزي",
          "https://drive.google.com/drive/u/1/folders/1hEE0h4iBkgNRDsoy9OOVfL1eNFzYeiHU",
        ),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
    },

    // ───── الصف الثالث الثانوي — أدبي ─────
    "g3|أدبي": {
      "عربي": [ResourceLink("كتاب اللغة العربية", "")],
      "انجليزي": [ResourceLink("كتاب اللغة الإنجليزية", "")],
      "رياضيات": [ResourceLink("كتاب الرياضيات", "")],
      "تاريخ": [ResourceLink("كتاب التاريخ", "")],
      "جغرافيا": [ResourceLink("كتاب الجغرافيا", "")],
      "مبادئ علم الخرائط": [ResourceLink("كتاب مبادئ علم الخرائط", "")],
      "فلسفة": [ResourceLink("كتاب الفلسفة", "")],
      "منطق": [ResourceLink("كتاب المنطق", "")],
    },
  };

  /// روابط مادة في صف ومسار معيّنين (فارغة = «قريباً»).
  ///    والسطرُ برابطٍ فارغ (كتابٌ لم يُلصق رابطُه بعد) لا يُعرض.
  static List<ResourceLink> forSubject(
    int grade,
    Track track,
    String subject,
  ) => (_byScope[scopeKey(grade, track)]?[subject] ?? const [])
      .where((l) => l.url.trim().isNotEmpty)
      .toList();

  /// هل لهذا الصف/المسار أي روابط أصلاً؟
  static bool hasAny(int grade, Track track) => Curriculum.subjectsFor(
    grade,
    track,
  ).any((s) => forSubject(grade, track, s).isNotEmpty);

  // ===== العرض =====
  static const Map<String, String> _emoji = {
    "رياضيات": "📐",
    "احياء": "🧬",
    "كيمياء": "⚛️",
    "فيزياء": "🔬",
    "عربي": "📜",
    "انجليزي": "🔤",
    "تاريخ": "🏛️",
    "جغرافيا": "🗺️",
    "مجتمع": "🤝",
    "علم الاقتصاد": "💹",
    "علم الاجتماع": "👥",
    "مبادئ علم الخرائط": "🧭",
    "فلسفة": "🧠",
    "منطق": "⚖️",
  };

  /// اسم المادة كما يُعرض في مركز الموارد (إيموجي + اسم مقروء).
  static String displayName(String subject) {
    const readable = {"عربي": "اللغة العربية", "انجليزي": "اللغة الإنجليزية"};
    return "${_emoji[subject] ?? "📘"} ${readable[subject] ?? subject}";
  }
}
