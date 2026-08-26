import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// ⌨️ خانة الكتابة وأزرار الإرسال/الإيقاف
// ==========================================
class ChatInputArea extends StatelessWidget {
  final ChatController controller;
  final VoidCallback onEmptyWarning;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.onEmptyWarning,
  });

  @override
  Widget build(BuildContext context) {
    final bool canSend = controller.inputController.text.trim().isNotEmpty && !controller.isLoading;
    final bool isGenerating = controller.isLoading || (controller.messages.isNotEmpty && controller.messages.last["animating"] == true);
    final bool showTextInput = !(controller.selectedSubject == "رياضيات" && controller.mathMode == "شرح" && !controller.isMathExplanationStarted);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 1️⃣ زر الإعدادات
            InkWell(
              onTap: () => controller.toggleSettingsPanel(),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: controller.showSettingsPanel ? AppColors.primary : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.softShadow,
                  border: Border.all(color: controller.showSettingsPanel ? Colors.transparent : AppColors.textSecondary.withValues(alpha: 0.1), width: 1),
                ),
                child: Icon(Icons.tune_rounded, color: controller.showSettingsPanel ? Colors.white : AppColors.textSecondary, size: 24),
              ),
            ),

            if (showTextInput) ...[
              const SizedBox(width: 10),

              // 2️⃣ خانة الكتابة
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: AppColors.softShadow,
                    border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.1), width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.inputController,
                          enabled: !isGenerating || controller.messages.isEmpty,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: (_) => controller.refresh(),
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: "اكتب سؤالك...",
                            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) {
                            if (canSend) controller.processRequest();
                          },
                        ),
                      ),

                      // زر الإرسال
                      Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: InkWell(
                          onTap: () {
                            if (isGenerating) {
                              controller.stopCurrentRequest();
                            } else if (canSend) {
                              controller.processRequest();
                            } else {
                              onEmptyWarning();
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: isGenerating ? null : (canSend ? AppColors.mainGradient : null),
                              color: isGenerating ? Colors.redAccent : (canSend ? null : AppColors.softSurface),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                              color: isGenerating ? Colors.white : (canSend ? Colors.white : AppColors.textSecondary),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
