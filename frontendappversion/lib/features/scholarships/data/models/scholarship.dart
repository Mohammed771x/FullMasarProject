import 'package:flutter/material.dart';

// ==========================================
// 🎓 نموذج المنحة — مرآةٌ لمستند `scholarships/{id}`
// ==========================================
// ⭐ **لا منحة واحدة مكتوبة في الكود.** كل ما يظهر للطالب يأتي من اللوحة
//    عبر `GET /scholarships`، فموسمُ منحٍ جديد لا يحتاج نشر تطبيق
//    ([docs/32-scholarships.md]).
//
// ⚠️ **الحالة تُحسب لا تُقرأ:** الخادم يرسلها محسوبةً، لكننا نعيد حسابها
//    محلياً من التاريخين. السبب: القائمة مكيَّشة على الجهاز، وطالبٌ يفتح
//    التطبيق بعد أسبوعين بلا إنترنت يجب أن يرى «مغلق» لا «مفتوح» قديماً.

enum SchStatus { open, soon, closed }

/// 🚪 بابٌ واحد: نصُّ الزرّ، والسؤالُ الذي يُرسَل عند ضغطه.
class ScholarshipDoor {
  const ScholarshipDoor(this.label, this.question);

  final String label;
  final String question;

  static List<ScholarshipDoor> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ScholarshipDoor>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final label = (item["label"] ?? "").toString().trim();
      final question = (item["question"] ?? "").toString().trim();
      if (label.isNotEmpty && question.isNotEmpty) {
        out.add(ScholarshipDoor(label, question));
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {"label": label, "question": question};
}


class Scholarship {
  final String id;
  final String name;
  final String country;
  final String flag;
  final String shortDesc;
  final String about;
  final String fundingType; // full | partial
  final List<String> requirements;
  final List<String> howToApply;
  final List<String> benefits;
  final List<String> documents;
  final List<String> fields;
  final List<String> degreeLevels;

  /// 📊 **المعدّل المطلوب** — نسبةٌ مئويّة، و`0` = «غير محدّد».
  ///
  /// 🔴 **أمرُ المالك (2026-09-21):** «أضف كم المعدّل المطلوب للمنحة
  ///    عشان يكون موجود في الشاشة الرئيسية، يجيب لوحة التحكم». فصار حقلاً
  ///    صريحاً في المنحة بدل استخراجِه من نصّ الشروط — والاستخراجُ يبقى
  ///    احتياطاً لمنحةٍ لم يُملأ حقلُها بعد ([minGpaOf]).
  ///
  /// ⚠️ و`0` **ليست صفراً**: منحةٌ بمعدّلٍ صفرٍ لا معنى لها، والصفرُ
  ///    هنا يعني «لم يُحدَّد» فتُعرض «غير محدّد» لا «0%».
  final int minGpa;

  /// 🧭 **أبوابُ المنحة** — أزرارٌ كلُّ واحدٍ منها يفتح جواباً مخزوناً في
  /// الخادم بلا نداءِ موديلٍ ولا خصمٍ من الحصة.
  ///
  /// 🔴 **علّةُ المالك (2026-09-20):** «تسع نيّات تُجاب من البطاقة — **وين
  ///    هالنيّات؟ مش موجودة**… خلّها من ضمن الاقتراحات، لو ضغطها يطلع له
  ///    الوثائق». وكانت الأزرارُ أربعةً مكتوبةً في الشاشة لا صلةَ لها
  ///    بما تملكه المنحة.
  ///
  /// ⚠️ ويحسبها **الخادم** لأنه صاحبُ قرار «أيُّ سؤالٍ يُجاب من البطاقة».
  ///    وتبقى فارغةً في نسخةٍ قديمةٍ من الكاش، فيتولّاها [doors].
  final List<ScholarshipDoor> suggestions;
  final String website;
  final String coverUrl;
  final String logoUrl;
  final DateTime? openDate;
  final DateTime? closeDate;
  final List<Color> gradient;
  final int order;

  /// 🖼️ هل لهذه المنحة غلاف مرفوع؟
  ///
  /// ⭐ الغلاف نفسه في Firebase Storage و**رابطه** في `coverUrl` — والقائمة
  ///   تحمل رابطاً (~100 بايت) لا صورة (~50 ك.ب). عشر منح × صورة = نصف
  ///   ميغابايت في كل تحديث على إنترنت متقطّع ([32§5.5]).
  ///   و`cached_network_image` يتكفّل بالتنزيل والكاش بلا كود منّا.
  final bool hasCover;

  const Scholarship({
    required this.id,
    required this.name,
    required this.country,
    this.flag = "",
    this.shortDesc = "",
    this.about = "",
    this.fundingType = "full",
    this.requirements = const [],
    this.howToApply = const [],
    this.benefits = const [],
    this.documents = const [],
    this.fields = const [],
    this.degreeLevels = const [],
    this.minGpa = 0,
    this.suggestions = const [],
    this.website = "",
    this.coverUrl = "",
    this.logoUrl = "",
    this.openDate,
    this.closeDate,
    this.gradient = const [],
    this.order = 0,
    this.hasCover = false,
  });

  bool get isFullyFunded => fundingType == "full";

  /// 🟢🟡🔴 — تُحسب من التاريخين، بتوقيت جهاز الطالب.
  SchStatus get status {
    final today = DateUtils.dateOnly(DateTime.now());
    if (openDate != null && today.isBefore(DateUtils.dateOnly(openDate!))) {
      return SchStatus.soon;
    }
    if (closeDate != null && today.isAfter(DateUtils.dateOnly(closeDate!))) {
      return SchStatus.closed;
    }
    return SchStatus.open;
  }

  /// نصّ الشارة **بالإيموجي** — لكرت القائمة حيث لا أيقونة بجانبه.
  String get statusLabel => switch (status) {
        SchStatus.open => "🟢 التقديم مفتوح",
        SchStatus.soon => "🟡 يفتح قريباً",
        SchStatus.closed => "🔴 مغلق حالياً",
      };

  /// النصّ **بلا إيموجي** — حيث تسبقه أيقونة، وإلا ظهرت دائرتان متجاورتان.
  String get statusText => switch (status) {
        SchStatus.open => "التقديم مفتوح",
        SchStatus.soon => "يفتح قريباً",
        SchStatus.closed => "مغلق حالياً",
      };

  IconData get statusIcon => switch (status) {
        SchStatus.open => Icons.check_circle_rounded,
        SchStatus.soon => Icons.schedule_rounded,
        SchStatus.closed => Icons.cancel_rounded,
      };

  Color get statusColor => switch (status) {
        SchStatus.open => const Color(0xFF16A34A),
        SchStatus.soon => const Color(0xFFF59E0B),
        SchStatus.closed => const Color(0xFFEF4444),
      };

  /// الأيام المتبقية للإغلاق — `null` حين لا تاريخ إغلاق أو انقضى.
  /// ⭐ هذا ما يخلق الإلحاح النافع: «باقٍ ١٢ يوماً» يُحرّك الطالب.
  int? get daysLeft {
    if (closeDate == null || status != SchStatus.open) return null;
    final diff = DateUtils.dateOnly(closeDate!)
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
    return diff >= 0 ? diff : null;
  }

  /// تدرّج الكرت: من اللوحة إن ضُبط، وإلا لونٌ ثابت مشتق من المعرّف —
  /// **لا عشوائية**: نفس المنحة بنفس اللون في كل مرة وعلى كل جهاز.
  List<Color> get colors {
    if (gradient.length >= 2) return gradient;
    return _fallbackPalettes[id.hashCode.abs() % _fallbackPalettes.length];
  }

  static const List<List<Color>> _fallbackPalettes = [
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    [Color(0xFF16A34A), Color(0xFF065F46)],
    [Color(0xFFEF4444), Color(0xFFB91C1C)],
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    [Color(0xFFF59E0B), Color(0xFFB45309)],
    [Color(0xFF0EA5E9), Color(0xFF0369A1)],
  ];

  /// أول حرفين من اسم الدولة — بديل العلم حين لا يضبطه الأدمن.
  String get badge => flag.isNotEmpty
      ? flag
      : (country.isNotEmpty ? country.characters.take(2).toString() : "🎓");

  bool matches(String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    return name.contains(q) || country.contains(q) || shortDesc.contains(q);
  }

  // ══════════════ التحويل ══════════════

  static DateTime? _date(dynamic v) {
    final s = (v ?? "").toString();
    return s.isEmpty ? null : DateTime.tryParse(s);
  }

  /// ⚠️ الرقمُ قد يصل نصّاً من كاشٍ قديم أو من لوحةٍ أرسلت «70».
  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? "").toString().trim()) ?? 0;
  }

  static List<String> _list(dynamic v) =>
      ((v as List?) ?? const []).map((e) => e.toString()).toList();

  static List<Color> _colors(dynamic v) {
    final out = <Color>[];
    for (final raw in ((v as List?) ?? const [])) {
      final hex = raw.toString().replaceFirst("#", "");
      final value = int.tryParse(hex, radix: 16);
      if (hex.length == 6 && value != null) out.add(Color(0xFF000000 | value));
    }
    return out.length >= 2 ? out.take(2).toList() : const [];
  }

  /// 🧭 أبوابُ هذه المنحة كما تُعرض للطالب.
  ///
  /// ⚖️ **الخادمُ هو المرجع** — فهو وحده يعرف أيَّ سؤالٍ يجيبه من البطاقة.
  ///    وهذه القائمةُ **احتياطٌ لنسخةِ كاشٍ قديمةٍ** لا `suggestions` فيها:
  ///    بلا احتياطٍ كانت الأزرارُ ستختفي كلَّها عند من لم يُحدِّث بعد،
  ///    وهو أسوأُ من القديم لا أحسن.
  ///
  /// 🔒 ونصوصُها **مطابقةٌ حرفاً** لـ`_SUGGESTIONS` في
  ///    [core/scholarship_facts.py]، ويحرس التطابقَ اختبارٌ يقرأ الملفَّين.
  List<ScholarshipDoor> get doors {
    if (suggestions.isNotEmpty) return suggestions;
    final out = <ScholarshipDoor>[];
    void add(bool has, String label, String question) {
      if (has) out.add(ScholarshipDoor(label, question));
    }

    add(requirements.isNotEmpty, "الشروط", "ما شروط التقديم؟");
    add(documents.isNotEmpty, "الوثائق المطلوبة", "ما الوثائق المطلوبة؟");
    if (closeDate != null) {
      out.add(const ScholarshipDoor("المواعيد", "متى آخر موعد للتقديم؟"));
    } else if (openDate != null) {
      out.add(const ScholarshipDoor("المواعيد", "متى يفتح التقديم؟"));
    }
    add(benefits.isNotEmpty, "المزايا", "ما مزايا المنحة؟");
    add(howToApply.isNotEmpty, "خطوات التقديم", "ما خطوات التقديم؟");
    add(fields.isNotEmpty, "التخصصات", "ما التخصصات المتاحة؟");
    add(degreeLevels.isNotEmpty, "المراحل", "ما المراحل الدراسية؟");
    add(fundingType.isNotEmpty, "التمويل", "هل المنحة ممولة بالكامل؟");
    add(about.trim().isNotEmpty || shortDesc.trim().isNotEmpty,
        "نبذة عن المنحة", "نبذة عن المنحة");
    return out;
  }

  factory Scholarship.fromJson(Map<String, dynamic> j) => Scholarship(
        id: (j["id"] ?? "").toString(),
        name: (j["name"] ?? "").toString(),
        country: (j["country"] ?? "").toString(),
        flag: (j["flag"] ?? "").toString(),
        shortDesc: (j["short_desc"] ?? "").toString(),
        about: (j["about"] ?? "").toString(),
        fundingType: (j["funding_type"] ?? "full").toString(),
        requirements: _list(j["requirements"]),
        howToApply: _list(j["how_to_apply"]),
        benefits: _list(j["benefits"]),
        documents: _list(j["documents"]),
        fields: _list(j["fields"]),
        degreeLevels: _list(j["degree_levels"]),
        minGpa: _int(j["min_gpa"]),
        suggestions: ScholarshipDoor.listFrom(j["suggestions"]),
        website: (j["website"] ?? "").toString(),
        coverUrl: (j["cover_url"] ?? "").toString(),
        logoUrl: (j["logo_url"] ?? "").toString(),
        openDate: _date(j["open_date"]),
        closeDate: _date(j["close_date"]),
        gradient: _colors(j["gradient"]),
        order: (j["order"] is int) ? j["order"] as int : 0,
        hasCover: j["has_cover"] == true,
      );

  /// للكاش المحلي — نفس صيغة الخادم كي لا يوجد محوّلان يفترقان.
  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "country": country,
        "flag": flag,
        "short_desc": shortDesc,
        "about": about,
        "funding_type": fundingType,
        "requirements": requirements,
        "how_to_apply": howToApply,
        "benefits": benefits,
        "documents": documents,
        "fields": fields,
        "degree_levels": degreeLevels,
        "min_gpa": minGpa,
        "suggestions": suggestions.map((d) => d.toJson()).toList(),
        "website": website,
        "cover_url": coverUrl,
        "logo_url": logoUrl,
        "open_date": openDate == null
            ? ""
            : openDate!.toIso8601String().substring(0, 10),
        "close_date": closeDate == null
            ? ""
            : closeDate!.toIso8601String().substring(0, 10),
        "gradient": gradient
            .map((c) => "#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}")
            .toList(),
        "order": order,
        "has_cover": hasCover,
      };
}

/// فلاتر شريط الشرائح أعلى القائمة.
enum SchFilter { all, favorites, full, partial, openNow, closingSoon }

extension SchFilterX on SchFilter {
  String get label => switch (this) {
        SchFilter.all => "الكل",
        SchFilter.favorites => "⭐ متابَعة",
        SchFilter.full => "ممولة بالكامل",
        SchFilter.partial => "جزئية",
        SchFilter.openNow => "مفتوحة الآن",
        SchFilter.closingSoon => "تُغلق قريباً",
      };

  /// «تُغلق قريباً» = مفتوحة وباقٍ لها ٣٠ يوماً أو أقل — الفلتر الذي
  /// ينقذ طالباً من تفويت موعد، لا مجرد تصنيف.
  ///
  /// ⚠️ **«متابَعة» يحتاج [favoriteIds]** لأن المفضّلة حالةُ الطالب لا صفةٌ
  ///    في المنحة. وتمريرُها اختياريٌّ كي لا ينكسر كلُّ مُنادٍ قديم — وحين
  ///    تغيب يُرجع الفلتر لا شيء، وهو الصواب: «لا مفضّلة معروفة» ≠ «الكل».
  bool test(Scholarship s, {Set<String> favoriteIds = const {}}) => switch (this) {
        SchFilter.all => true,
        SchFilter.favorites => favoriteIds.contains(s.id),
        SchFilter.full => s.isFullyFunded,
        SchFilter.partial => !s.isFullyFunded,
        SchFilter.openNow => s.status == SchStatus.open,
        SchFilter.closingSoon => (s.daysLeft ?? 9999) <= 30,
      };
}
