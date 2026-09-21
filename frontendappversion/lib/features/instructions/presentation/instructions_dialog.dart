import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/prefs_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/masar_dialog.dart';
import '../../../core/widgets/masar_markdown.dart';
import '../../../core/widgets/phosphor.dart';
import '../data/app_instructions.dart';

// ==========================================
// 📚 نظام التعليمات (مربوط بالملف الخارجي والذاكرة الدائمة)
// ==========================================
class InstructionsDialog {
  /// تُعرض عند طلب التعليمات يدوياً لمادة لم تُكتب تعليماتها بعد.
  static void _showMissing(BuildContext context, String subject) {
    showDialog(
      context: context,
      builder: (ctx) => ThemeScope(
        builder: (ctx) => MasarDialog(
          icon: PD.lightbulbFilament,
          title: "تعليمات $subject",
          primaryLabel: "حسناً",
          fullWidthAction: true,
          child: Text(
            "تعليمات هذه المادة قيد الإعداد 🚧\n\n"
            "يمكنك الآن اختيار الوضع والوحدة من «إعدادات الجلسة» في أعلى "
            "الشاشة، ثم كتابة سؤالك مباشرة.",
            style: TextStyle(
                fontSize: 13,
                height: 1.9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  /// هل لهذه المادة تعليمات مكتوبة؟
  static bool hasInstructions(String subject) => AppInstructions.data.containsKey(subject);

  static Future<void> showIfNeeded(
    BuildContext context,
    String subject, {
    required int grade,
    required String track,
    bool forceShow = false,
  }) async {
    final instructionData = AppInstructions.data[subject];

    // ⚠️ سابقاً: أي مادة غير موجودة كانت تعرض **تعليمات الأحياء** بالخطأ.
    //    الآن: لا نعرض شيئاً تلقائياً، وعند الطلب اليدوي نوضّح أنها قيد الإعداد.
    if (instructionData == null) {
      if (forceShow && context.mounted) _showMissing(context, subject);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String storageKey = PrefsKeys.instructionShown(grade, track, subject);
    final bool hasBeenShown = prefs.getBool(storageKey) ?? false;

    // إذا ظهرت مسبقاً ولم يطلبها الطالب يدوياً، لا تظهرها مرة أخرى
    if (hasBeenShown && !forceShow) return;

    if (!context.mounted) return;
    await _present(
      context,
      text: instructionData["text"]!,
      videoUrl: instructionData["video_url"]!,
      onUnderstood: () => prefs.setBool(storageKey, true),
    );
  }

  /// 👨‍🏫 تعليمات **أداة المعلم** — واحدة لكل المواد (طلب المالك).
  ///
  /// ⚠️ فرقان مقصودان عن تعليمات الطالب:
  ///   ① لا تُربط بمادة ولا بصف: طريقة الاستعمال واحدة مهما كانت المادة،
  ///      فربطُها بهما كان سيعيد عرضها بلا جديد عند كل تبديل.
  ///   ② **لا رسالة «قيد الإعداد» هنا**: الأدوات أربعٌ معروفة ولكلٍّ نصُّها،
  ///      فغيابُ النصّ عطلٌ برمجي لا حالةُ محتوى ناقص.
  static Future<void> showTeacher(BuildContext context, String tool,
      {bool forceShow = false}) async {
    final data = AppInstructions.teacher[tool];
    if (data == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = PrefsKeys.teacherInstructionShown(tool);
    if ((prefs.getBool(key) ?? false) && !forceShow) return;

    if (!context.mounted) return;
    await _present(
      context,
      text: data["text"]!,
      videoUrl: data["video_url"]!,
      teacher: true,
      onUnderstood: () => prefs.setBool(key, true),
    );
  }

  /// نافذة التعليمات نفسها — واحدة للطالب وللمعلّم.
  /// (كانت مكتوبة داخل `showIfNeeded`؛ استُخرجت كي لا تُنسخ مرتين فتفترقا.)
  static Future<void> _present(
    BuildContext context, {
    required String text,
    required String videoUrl,
    required Future<void> Function() onUnderstood,
    bool teacher = false,
  }) async {
    final String instructionText = text;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ThemeScope(
        builder: (context) => MasarDialog(
          icon: PD.lightbulbFilament,
          title: "دليل استخدام تطبيق مسار",
          primaryLabel: "فهمت، ابدأ الآن",
          fullWidthAction: true,
          closable: true,
          divider: true,
          onPrimary: onUnderstood,
          child: _GuideBody(
              text: instructionText, videoUrl: videoUrl, teacher: teacher),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 🧭 جسمُ «دليل استخدام تطبيق مسار» — بطاقاتُ الأوضاع
// ══════════════════════════════════════════════════
// 🎨 **تصميم Figma** (`design/03-home/20`): أربعُ بطاقاتٍ ملوّنة بارتفاع 88
//    وفجوةٍ 12، في كلٍّ منها مربّعُ تشغيلٍ 36 r10 على يمينها، وعنوانٌ
//    مرقّمٌ بحبرها، ووصفٌ سطرين. ثم زرٌّ بعرض اللوح.
//
// 📚 **والأوضاعُ من التطبيق لا من الملف**: المصمّم رسم أربعةً، والتطبيق
//    فيه **خمسة** — و«وزاري» ليس زينةً بل بابُ أسئلة الامتحانات. فبُنيت
//    خامسةً بلغته نفسِها (سلّمُ الرمادي من التوكنات) ولم تُحذف.
//
// 📝 **والأوصافُ مكتوبةٌ من سلوك التطبيق** لا منقولةً عن الملف: نصوصُ
//    المصمّم عيّناتٌ توضيحية (قاعدة المالك).
//
// ▶️ **ومربّعُ التشغيل يفتح فيديو القسم** حين يوجد — وهو واحدٌ لكل مادة
//    يشرحها كلَّها. وحين لا فيديو، يصير المربّعُ أيقونةَ الوضع نفسِه
//    ولا يُنقر: زرٌّ لا يفعل شيئاً أسوأُ من لا زرّ.
//
// 🆕 **وتفاصيلُ المادة تحتها** قابلةً للطيّ: نصُّ التعليمات الكامل الذي
//    كان يملأ النافذة (نطاقاتُ الصفحات وأسماءُ الوحدات والأمثلة). لا
//    مكان له في تصميم المصمّم، وحذفُه يُضيع معلوماتٍ يحتاجها الطالب.
class _GuideBody extends StatefulWidget {
  const _GuideBody({
    required this.text,
    required this.videoUrl,
    this.teacher = false,
  });

  final String text;
  final String videoUrl;

  /// 👨‍🏫 **دليلُ المعلّم أدواتُه لا أوضاعُ الطالب.**
  ///
  /// 🔴 كانت النافذةُ تعرض للمعلّم «وضع الشرح · التلخيص · السؤال · الوزاري
  ///    · الاختبارات» — أوضاعُ قسمٍ لا يدخله أصلاً. وتصديرُ دليله
  ///    (`design/09-teacher/08`) يعرض **أوضاعَه هو** ثلاثةً بألوانها.
  final bool teacher;

  @override
  State<_GuideBody> createState() => _GuideBodyState();
}

class _GuideBodyState extends State<_GuideBody> {
  bool _details = false;

  /// 🎨 **اللونُ باسم الوضع لا بترتيبه**: المصمّم لوّن أربعةً —
  ///    الشرحُ أزرق · التلخيصُ عنبريّ · السؤالُ أخضر · **الاختباراتُ
  ///    بنفسجية**. والتطبيقُ فيه خامسٌ («وزاري») بينهما في الترتيب، فلو
  ///    وُزّعت الألوانُ بالفهرس لسرق الوزاريُّ بنفسجيَّ الاختبارات.
  ///    فالوزاريُّ يأخذ الدرجةَ الحياديّة الخامسة من سلّم المصمّم.
  /// 👨‍🏫 أدواتُ المعلم — بترتيب التصدير وألوانِه: خطةٌ زرقاء، تبسيطٌ
  ///    أصفر، واجبٌ أخضر. و«اسأل المساعد» 🆕 تأخذ الدرجةَ الحيادية
  ///    الخامسة (كما فعل «الوزاري» عند الطالب) فلا تسرق لوناً مرسوماً.
  static const List<List<dynamic>> _teacherModes = [
    ["📖", "وضع خطة درس", "خطةُ تحضيرٍ من نصّ درسك: الأهداف، خطوات الشرح بأزمنتها، النشاط والتقويم.", 0],
    ["💡", "وضع تبسيط مفهوم", "تشبيهان بحدودهما وتمثيلٌ بلا وسائل وسؤالٌ كاشف — لمفهومٍ يتعثّر فيه طلابك.", 1],
    ["📝", "وضع واجب واختبار", "واجبٌ متدرّج الصعوبة من الدرس وحده، ومعه سلّمُ تصحيحٍ بالدرجات.", 2],
    ["🤖", "وضع اسأل المساعد", "محادثةٌ مفتوحةٌ لأي سؤالٍ تربويّ — إدارةُ الحصة، التقويم السريع، الطلاب الضعاف.", 4],
  ];

  static const List<List<dynamic>> _modes = [
    ["📖", "وضع الشرح", "يشرح لك الدرس خطوةً خطوة بالأمثلة، وتسأله عمّا لم يتّضح.", 0],
    ["⚡", "وضع التلخيص", "يجمع لك الدرس في نقاطٍ مركّزة، ومستواه بيدك من واحدٍ إلى خمسة.", 1],
    ["❓", "وضع السؤال", "اكتب سؤالك أو أرفق صورةَ مسألةٍ من كتابك — ويحلّها بالخطوات.", 2],
    ["📝", "وضع الوزاري", "أسئلةُ الامتحانات الوزارية بسنواتها وأقسامها كما وردت.", 4],
    ["🧪", "وضع الاختبارات", "اختبارٌ مؤقّتٌ يُبنى من درسك، ويُصحَّح لك فور انتهائه.", 3],
  ];

  @override
  Widget build(BuildContext context) {
    final modes = widget.teacher ? _teacherModes : _modes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < modes.length; i++) ...[
          _GuideCard(
            index: i,
            colorSlot: modes[i][3] as int,
            emoji: modes[i][0] as String,
            name: modes[i][1] as String,
            desc: modes[i][2] as String,
            videoUrl: widget.videoUrl,
          ),
          const SizedBox(height: 12),
        ],
        // 🆕 تفاصيلُ المادة — مطويّةٌ كي لا تُغرق الدليل.
        MasarDialogRow(
          height: 46,
          highlighted: _details,
          onTap: () => setState(() => _details = !_details),
          child: Row(
            children: [
              PDuo(PD.notebook, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    widget.teacher
                        ? "تفاصيل هذه الأداة"
                        : "تفاصيل هذا القسم ونطاق صفحاته",
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
              ),
              AnimatedRotation(
                turns: _details ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(PI.caretDown.regular,
                    size: 15, color: AppColors.dropdownCaret),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_details
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MasarMarkdown(data: widget.text),
                ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// 🃏 بطاقةُ وضعٍ واحدة
// ══════════════════════════════════════════════════
class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.index,
    required this.colorSlot,
    required this.emoji,
    required this.name,
    required this.desc,
    required this.videoUrl,
  });

  final int index;

  /// خانةُ اللون في سلّم [AppColors.guideFills] — لا الفهرسُ نفسُه.
  final int colorSlot;

  final String emoji;
  final String name;
  final String desc;
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    final int c = colorSlot;
    final bool hasVideo = videoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.guideFills[c],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.guideBorders[c]),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${index + 1}. $emoji $name",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.guideInks[c])),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.7,
                        fontWeight: FontWeight.w700,
                        color: AppColors.chipInk)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ▶️ مربّعُ التشغيل — في **يسار** البطاقة كما في التصميم.
          //    ⚠️ فآخرُ أبناء `Row` في RTL هو أقصى اليسار.
          Material(
            color: AppColors.guideTiles[c],
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: hasVideo
                  ? () async {
                      final uri = Uri.parse(videoUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    }
                  : null,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  hasVideo ? PI.play.regular : PI.info.regular,
                  size: 17,
                  color: AppColors.guideAccents[c],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
