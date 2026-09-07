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
// حالة اليوم: **الثالث الثانوي علمي فقط** لديه روابط.

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
  static const Map<String, Map<String, List<ResourceLink>>> _byScope = {
    // ✅ الصف الثالث الثانوي — علمي
    "g3|علمي": {
      "رياضيات": [
        ResourceLink("ملخص التفاضل", "https://drive.google.com/drive/folders/1hIojvkK09LT7IcqaK5aGoEV_vrrVZjLs"),
        ResourceLink("ملخص الجبر", "https://drive.google.com/drive/folders/1m8QVLyM6tbG5buQNDdGwNCRbV_28bsxA"),
        ResourceLink("ملخص التكامل", "https://drive.google.com/drive/u/1/folders/1ao83kRRVKk40VOAsgnLcjDeOodIyHNri"),
        ResourceLink("ملخص الهندسة", "https://drive.google.com/drive/u/1/folders/1TWxdgszrwzxCQW2uRSXkv7VZrIKIGvGV"),
        ResourceLink("ملخص الاحتمالات", "https://drive.google.com/drive/u/1/folders/1Sx-ZJqwjORzFwQR5EDVrVd32mkjkI_lh"),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "احياء": [
        ResourceLink("ملخصات الأحياء", "https://drive.google.com/drive/u/1/folders/1LLzIsWFKiZOkrr6DUaagm9RVmBdKKDQn"),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "كيمياء": [
        ResourceLink("ملخصات الكيمياء", "https://drive.google.com/drive/u/1/folders/1_9YpbhSvG4-qcVihLU10o8muFFPh0Gqt"),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "فيزياء": [
        ResourceLink("ملخص الفيزياء", "https://drive.google.com/drive/folders/1ATQPwJNXYf-yidgXjhkW7E7AaqYev2vc"),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "عربي": [
        ResourceLink("ملخص النحو", "https://drive.google.com/drive/u/1/folders/13Ec4BtxzxvJTOrR9_BriUGfr1HszU3M1"),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
      "انجليزي": [
        ResourceLink("ملخصات الانجليزي", "https://drive.google.com/drive/u/1/folders/1hEE0h4iBkgNRDsoy9OOVfL1eNFzYeiHU"),
        ResourceLink("الأسئلة الوزارية", _wazariG3Sci),
      ],
    },

    // 🚧 بانتظار الروابط — أضِف المواد هنا وتظهر فوراً في التطبيق
    "g1|عام": {},
    "g2|علمي": {},
    "g2|أدبي": {},
    "g3|أدبي": {},
  };

  /// روابط مادة في صف ومسار معيّنين (فارغة = «قريباً»).
  static List<ResourceLink> forSubject(int grade, Track track, String subject) =>
      _byScope[scopeKey(grade, track)]?[subject] ?? const [];

  /// هل لهذا الصف/المسار أي روابط أصلاً؟
  static bool hasAny(int grade, Track track) =>
      Curriculum.subjectsFor(grade, track).any((s) => forSubject(grade, track, s).isNotEmpty);

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
