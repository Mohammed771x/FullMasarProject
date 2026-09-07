import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/prefs_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../data/app_instructions.dart';

// ==========================================
// 📚 نظام التعليمات (مربوط بالملف الخارجي والذاكرة الدائمة)
// ==========================================
class InstructionsDialog {
  /// تُعرض عند طلب التعليمات يدوياً لمادة لم تُكتب تعليماتها بعد.
  static void _showMissing(BuildContext context, String subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text("تعليمات $subject",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
          ],
        ),
        content: Text(
          "تعليمات هذه المادة قيد الإعداد 🚧\n\nيمكنك الآن اختيار الوضع والوحدة من زر إعدادات الجلسة ثم كتابة سؤالك مباشرة.",
          style: TextStyle(color: AppColors.textSecondary, height: 1.8, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("حسناً", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
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
  }) async {
    final String instructionText = text;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite.withValues(alpha: 0.98),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 15),
            Text("كيف تستخدم مسار؟", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videoUrl.isNotEmpty) ...[
                InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse(videoUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "اضغط هنا لمشاهدة الفيديو التعليمي لاستخدام هذا القسم",
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: AppColors.softSurface, height: 1),
                const SizedBox(height: 16),
              ],
              Text(
                instructionText,
                style: TextStyle(fontSize: 15, height: 1.8, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(20)),
            child: TextButton(
              onPressed: () async {
                // ✅ حفظ في الذاكرة الدائمة أن التعليمات قُرئت ولن تظهر مجدداً
                await onUnderstood();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("فهمت، ابدأ الآن 🚀", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
