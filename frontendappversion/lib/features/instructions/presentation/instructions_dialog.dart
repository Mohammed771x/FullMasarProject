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
  static Future<void> showIfNeeded(BuildContext context, String subject, {bool forceShow = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String storageKey = PrefsKeys.instructionShown(subject);
    final bool hasBeenShown = prefs.getBool(storageKey) ?? false;

    // إذا ظهرت مسبقاً ولم يطلبها الطالب يدوياً، لا تظهرها مرة أخرى
    if (hasBeenShown && !forceShow) return;

    // جلب البيانات من الملف الخارجي
    final instructionData = AppInstructions.data[subject] ?? AppInstructions.data["احياء"]!;
    final String instructionText = instructionData["text"]!;
    final String videoUrl = instructionData["video_url"]!;

    if (!context.mounted) return;

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
                // ✅ حفظ في الذاكرة الدائمة أن الطالب قرأ التعليمات ولن تظهر مجدداً
                await prefs.setBool(storageKey, true);
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
