import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/quota_badge.dart';
import '../controllers/chat_controller.dart';
import '../../../teacher/data/teacher_tool.dart';

// ==========================================
// 🪟 الشريط العلوي الزجاجي + بوصلة المسار
// ==========================================
class ChatGlassAppBar extends StatelessWidget {
  final ChatController controller;
  final VoidCallback onMenu;
  final VoidCallback onHelp;

  const ChatGlassAppBar({
    super.key,
    required this.controller,
    required this.onMenu,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    bool isLoadingMsg = controller.isLoading ||
        (controller.messages.isNotEmpty && controller.messages.last["animating"] == true);

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 15, left: 20, right: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite.withValues(alpha: 0.98),
        border: Border(
          bottom: BorderSide(
            color: isLoadingMsg ? AppColors.primary.withValues(alpha: 0.2) : AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // زر القائمة
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onMenu,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 22),
            ),
          ),

          // العنوان + بوصلة المسار
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 👨‍🏫 العنوان يقول للمعلّم **في أي أداة هو** — فالشاشة
                    //    واحدة للأدوات الأربع ولا يميّزها غير هذا السطر.
                    Flexible(
                      child: Text(
                        controller.isTeacher
                            ? "${controller.teacherTool!.emoji} ${controller.teacherTool!.label}"
                            : "مسار الطالب",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // 🎟️ الحصة بجوار العنوان — يراها الطالب قبل أن يصطدم بها.
                    const SizedBox(width: 8),
                    const QuotaBadge(compact: true),
                    if (isLoadingMsg) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // بوصلة المسار الديناميكية
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          controller.getCurrentLocationText(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // زر المساعدة
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onHelp,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.tips_and_updates_rounded, color: AppColors.secondary, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
