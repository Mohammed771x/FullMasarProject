import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/masar_character.dart';
import 'tour_overlay.dart';

// ==========================================
// 🧭 جولة الشرح — روبوت «هلا» يعرّف الطالبَ بكل مكانٍ في الشاشة
// ==========================================
// 🎨 **تصميم Figma** «تتبع الخطوات» (واجهات الطالب): الشاشةُ كلُّها مغبّشةٌ
//    ومعتّمة، ويبقى المكانُ المشروح مفتوحاً بدائرةٍ بيضاء، وفوق الروبوت
//    فقاعةٌ بعنوانٍ عريضٍ وسطرِ شرح، وتحته «التالي» و«إغلاق».
//    وبأمر المالك (٢٠٢٦-٠٩-٢٧): الروبوتُ **كبيرٌ بجسده** لا رأسٌ صغير،
//    ويتحرّك ويتكلّم — والأجزاءُ الكبيرة تُفتح بمستطيلٍ لا بدائرة.
//
// كلُّ قسمٍ يعطي [MasarTour.maybeStart] قائمةَ خطواته فقط، والمحرّكُ واحد.
// وتظهر **مرّةً واحدة** لكل جولة (محفوظةٌ على الجهاز)، وتُعاد من الإعدادات.

/// شكلُ الفتحة حول المكان المشروح.
enum TourShape {
  /// دائرةٌ بيضاء — للأزرار والأيقونات.
  circle,

  /// مستطيلٌ بزوايا ناعمة — للبطاقات والأجزاء الكبيرة.
  rect,
}

class TourStep {
  const TourStep({
    this.anchor,
    required this.title,
    required this.body,
    this.shape = TourShape.rect,
    this.padding = 8,
    this.pose = MasarCharacter.hello,
    this.optional = false,
    this.before,
  });

  /// مرساةُ المكان ([TourAnchor]) — و`null` خطوةٌ في وسط الشاشة بلا فتحة
  /// (الترحيب والختام).
  final String? anchor;
  final String title;
  final String body;
  final TourShape shape;

  /// كم تتّسع الفتحةُ حول العنصر.
  final double padding;

  /// وضعيةُ الروبوت في هذه الخطوة — تتبدّل بقفزة.
  final MasarCharacter pose;

  /// عنصرٌ قد لا يُبنى (قسمٌ أطفأه الأدمن، بطاقةٌ بلا بيانات) ⇒ تُتخطّى
  /// خطوتُه بصمت بدل أن تشير الفتحةُ إلى فراغ.
  final bool optional;

  /// 🎬 ما يُفعل **قبل** شرح الخطوة — فتحُ القائمة الجانبية، بسطُ بطاقةٍ
  /// مطويّة. يُنتظر حتى ينتهي (ومعه حركتُه) ثم يُقاس المكان. وما بعدها من
  /// الخطوات الاختيارية لا يُعرف أحاضرٌ هو إلا بعده، فيُفرز عندها لا في البدء.
  final Future<void> Function()? before;
}

class MasarTour {
  MasarTour._();

  static String _key(String id) => 'tour_done_$id';

  /// كلُّ الجولات — تُصفَّر معاً من «أعد جولة الشرح». وكلُّ قسمٍ تُبنى جولتُه
  /// يُضاف اسمُه هنا.
  static const List<String> allIds = [
    'home',
    'analysis',
    'education',
    'quiz',
    'scholarships',
    'scholarship_detail',
    'scholarship_chat',
    'teacher',
  ];

  /// هل رآها الطالب؟
  static Future<bool> seen(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key(id)) ?? false;
  }

  /// يصفّر الجولات — «أعد عرض الشرح» في الإعدادات.
  static Future<void> reset(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    for (final id in ids) {
      await p.remove(_key(id));
    }
  }

  static bool _running = false;

  /// يعرضها إن لم تُرَ (أو دائماً مع [force]). تُعلَّم «مرئيةً» عند
  /// **بدئها** لا انتهائها: طالبٌ أغلق التطبيقَ في منتصفها لا يُحاصَر بها
  /// عند كل فتح — وإعادتُها متاحةٌ من الإعدادات.
  static Future<void> maybeStart(
    BuildContext context, {
    required String id,
    required List<TourStep> steps,
    bool force = false,
  }) async {
    if (_running || steps.isEmpty) return;
    if (!force && await seen(id)) return;
    if (!context.mounted) return;
    _running = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key(id), true);
      if (!context.mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierDismissible: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => TourOverlay(steps: steps),
        ),
      );
    } finally {
      _running = false;
    }
  }
}
