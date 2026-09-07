import 'package:flutter/material.dart';

// ==========================================
// 🎏 بانر قسم
// ==========================================
// ⭐ لا نصّ ولا لون ولا وجهة في كود التطبيق — كلها تصل من اللوحة، فالإعلان
//    يتغيّر بلا نشر نسخة جديدة على المتجر (وهذا شهرٌ كامل انتظاراً).
class AppBanner {
  const AppBanner({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.icon = 'star',
    this.colors = const ['#3B82F6', '#1D4ED8'],
    this.action = 'none',
    this.actionValue = '',
    this.order = 0,
    this.auto = false,
    this.segment = 'all',
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final List<String> colors;

  /// وجهة النقر — تُفسَّر في `BannerCarousel`.
  final String action;
  final String actionValue;
  final int order;

  /// وُلِّد من حالة المنح (لا كتبه الأدمن) — يُعرَض بشارة في اللوحة فقط.
  final bool auto;

  /// 🎯 الفئة المستهدفة (`all` · `g1` · `g3_sci` …) — نفس مفاتيح الخادم.
  ///
  /// ⭐ **يصل مع كل بانرٍ حتى حين يصفّي الخادم**: الرد يُكيَّش على الجهاز،
  ///    فطالبٌ صحّح صفّه قد يقرأ كاشاً صُفِّي لصفٍّ تركه. وجودُ الفئة هنا
  ///    يجعل التصفية المحلية ممكنةً بلا انتظار الشبكة.
  final String segment;

  factory AppBanner.fromJson(Map<String, dynamic> j) => AppBanner(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        icon: (j['icon'] ?? 'star').toString(),
        colors: (j['colors'] as List?)?.map((c) => c.toString()).toList() ??
            const ['#3B82F6', '#1D4ED8'],
        action: (j['action'] ?? 'none').toString(),
        actionValue: (j['action_value'] ?? '').toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        auto: j['auto'] == true,
        segment: (j['segment'] ?? 'all').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'colors': colors,
        'action': action,
        'action_value': actionValue,
        'order': order,
        'auto': auto,
        'segment': segment,
      };

  List<Color> get gradient {
    final parsed = colors.map(_parse).whereType<Color>().toList();
    if (parsed.isEmpty) return const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
    return parsed.length == 1 ? [parsed.first, parsed.first] : parsed.take(2).toList();
  }

  /// 🎯 هل هذا البانر لهذا الطالب؟
  ///
  /// ⚠️ **نسخةٌ مصغّرة من `audience.matches_profile` في الخادم عمداً**، وهي
  ///    التصفية الثانية لا الأولى: الخادم يصفّي أصلاً حين يصله الصف. وجودها
  ///    هنا يحمي حالةً واحدة — كاشٌ حُفظ لصفٍّ ثم غيّر الطالب صفّه.
  ///    وأي فئةٍ لا يعرفها التطبيق تُعتبر **للجميع**: نسخةٌ قديمة لا تُخفي
  ///    بانراً لأنها لم تفهم كلمةً جديدة.
  bool targets(int grade, String track) {
    switch (segment) {
      case 'all':
      case '':
        return true;
      case 'students':
        return true; // التطبيق كله للطلاب
      case 'g1':
        return grade == 1;
      case 'g2':
        return grade == 2;
      case 'g3':
        return grade == 3;
      case 'g2_sci':
        return grade == 2 && track == 'علمي';
      case 'g2_lit':
        return grade == 2 && track == 'أدبي';
      case 'g3_sci':
        return grade == 3 && track == 'علمي';
      case 'g3_lit':
        return grade == 3 && track == 'أدبي';
      default:
        return true;
    }
  }

  static Color? _parse(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    final value = int.tryParse(clean, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  /// ⚠️ الأسماء **محصورة** ومطابقة لقائمة الخادم: اسمٌ حرّ يعني أيقونة
  ///    مفقودة على شاشة الطالب لا يكتشفها أحد من اللوحة.
  IconData get iconData => switch (icon) {
        'flight' => Icons.flight_takeoff_rounded,
        'school' => Icons.school_rounded,
        'explore' => Icons.explore_rounded,
        'handshake' => Icons.handshake_rounded,
        'book' => Icons.menu_book_rounded,
        'quiz' => Icons.quiz_rounded,
        'chart' => Icons.insights_rounded,
        'teacher' => Icons.record_voice_over_rounded,
        'fire' => Icons.local_fire_department_rounded,
        'gift' => Icons.card_giftcard_rounded,
        'clock' => Icons.schedule_rounded,
        'bell' => Icons.notifications_active_rounded,
        'rocket' => Icons.rocket_launch_rounded,
        'target' => Icons.track_changes_rounded,
        'trophy' => Icons.emoji_events_rounded,
        _ => Icons.star_rounded,
      };
}

/// أقسام التطبيق التي تعرض بانراً — نفس مفاتيح الخادم حرفاً بحرف.
class BannerSection {
  static const home = 'home';
  static const education = 'education';
  static const quiz = 'quiz';
  static const scholarships = 'scholarships';
  static const services = 'services';
  static const analysis = 'analysis';
  static const teacher = 'teacher';
}
