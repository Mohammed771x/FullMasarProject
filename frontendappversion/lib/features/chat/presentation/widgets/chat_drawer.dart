import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/prefs_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/chat_controller.dart';
import 'chat_dialogs.dart';

// ==========================================
// 📂 القائمة الجانبية (Drawer)
// ==========================================
class ChatDrawer extends StatelessWidget {
  final ChatController controller;

  const ChatDrawer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(left: BorderSide(color: AppColors.softSurface)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("منصة مسار", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                          Text("Premium Education", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ زر محادثة جديدة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () {
                    controller.createNewConversation();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text("محادثة جديدة", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ الخيارات (حُذف "تحديث الكود" مع إزالة نظام التفعيل)
              _drawerItem(Icons.library_books_rounded, "الموارد", () {
                Navigator.pop(context);
                ChatDialogs.showResources(context);
              }, 12),
              _drawerItem(Icons.support_agent_rounded, "المطور", () {
                Navigator.pop(context);
                ChatDialogs.showDeveloperInfo(context);
              }, 12),

              // 🌙 زر الوضع الداكن
              ValueListenableBuilder<bool>(
                valueListenable: isDarkModeNotifier,
                builder: (context, isDark, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        isDarkModeNotifier.value = !isDark;
                        controller.refresh();
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setBool(PrefsKeys.isDarkMode, isDarkModeNotifier.value);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary.withValues(alpha: 0.1) : AppColors.softSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: isDark ? AppColors.primary : Colors.orange.shade600, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDark ? "الوضع الداكن مفعّل" : "تفعيل الوضع الداكن",
                                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.primary : AppColors.textPrimary, fontSize: 13),
                              ),
                            ),
                            Switch(
                              value: isDark,
                              onChanged: (val) async {
                                isDarkModeNotifier.value = val;
                                controller.refresh();
                                final prefs = await SharedPreferences.getInstance();
                                prefs.setBool(PrefsKeys.isDarkMode, val);
                              },
                              activeThumbColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Divider(height: 1, color: AppColors.softSurface)),

              // ✅ عنوان المواد
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text("المواد الدراسية", style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                ),
              ),

              // ✅ قائمة المواد
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: controller.subjects.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        controller.switchContext(() {
                          controller.selectedUnit = "الكل";
                          controller.availableUnits = [];
                          controller.selectedSubject = s;
                          controller.sessionActive = false;
                          controller.selectedExamYear = "";
                          controller.availableYears = [];
                          controller.loadConversations();
                          controller.createNewConversation();
                          if (s == "رياضيات") {
                            controller.selectedMathBranch = "";
                            controller.mathMode = "شرح";
                            controller.selectedMode = "شرح";
                            controller.selectedLesson = "";
                            controller.mathLessons = [];
                            controller.inputType = "برومت";
                          } else {
                            controller.selectedMode = "شرح";
                            controller.inputType = "برومت";
                          }
                        });
                        controller.loadAvailableUnits();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: controller.selectedSubject == s ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.book_rounded, size: 18, color: controller.selectedSubject == s ? AppColors.primary : AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Text(s, style: TextStyle(fontSize: 13, color: controller.selectedSubject == s ? AppColors.primary : AppColors.textPrimary, fontWeight: controller.selectedSubject == s ? FontWeight.bold : FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),

              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Divider(height: 1, color: AppColors.softSurface)),

              // ✅ عنوان المحادثات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text("المحادثات السابقة", style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                ),
              ),

              // ✅ قائمة المحادثات بحجم ثابت
              SizedBox(height: 300, child: _buildConversationsList(context)),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, [double padding = 24]) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.textPrimary, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(BuildContext context) {
    if (controller.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text("لا توجد محادثات بعد.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 0),
      itemCount: controller.conversations.length,
      itemBuilder: (context, index) {
        final conv = controller.conversations[index];
        final isActive = conv.id == controller.currentConversationId;
        return InkWell(
          onTap: () {
            controller.loadConversation(conv);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: isActive ? AppColors.softSurface : Colors.transparent,
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 18, color: isActive ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    conv.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? AppColors.primary : AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.secondary),
                  onPressed: () => ChatDialogs.showRename(context, controller, conv),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  onPressed: () => ChatDialogs.showDeleteConfirmation(context, controller, conv.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
