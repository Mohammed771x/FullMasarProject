import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/image_service.dart';
import '../controllers/chat_controller.dart';
import '../../../../core/media/image_editor_screen.dart';
import '../../../../core/widgets/voice_recording_bar.dart';

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
    // ✅ الدرس المختار وحده يكفي — كما تَعِد لوحة الإعدادات حرفياً.
    final bool canSend = (controller.inputController.text.trim().isNotEmpty ||
            controller.canSendWithoutText) &&
        !controller.isLoading;
    final bool isGenerating = controller.isLoading || (controller.messages.isNotEmpty && controller.messages.last["animating"] == true);
    final bool showTextInput = !(controller.selectedSubject == "رياضيات" && controller.mathMode == "شرح" && !controller.isMathExplanationStarted);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📷 معاينة الصور المرفقة (حتى صورتين)
            if (controller.attachedImages.isNotEmpty && !controller.isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(controller.attachedImages.length, (i) {
                      final img = controller.attachedImages[i];
                      return Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // ضغطة على المعاينة تفتح المحرّر (قص + رسم)
                            InkWell(
                              onTap: () => _editImage(context, i, img),
                              borderRadius: BorderRadius.circular(14),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(img.path),
                                  width: 72, height: 72, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 72, height: 72, color: AppColors.softSurface,
                                    child: Icon(Icons.broken_image_rounded,
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                            // شارة «عدّل»
                            Positioned(
                              bottom: 0, right: 0, left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(14)),
                                ),
                                child: const Text("عدّل",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 9.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            Positioned(
                              top: -6, left: -6,
                              child: InkWell(
                                onTap: () => controller.removeAttachedImage(i),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent, shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.surfaceWhite, width: 2),
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            Row(
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

            if (controller.isRecording) ...[
              const SizedBox(width: 10),
              // 🎙️ شريط التسجيل (يحل محل خانة الكتابة)
              Expanded(
                child: VoiceRecordingBar(
                  onDelete: () => controller.deleteVoiceRecording(),
                  onStopToText: () => controller.stopVoiceToText(),
                  onSend: () => controller.stopVoiceAndSend(),
                ),
              ),
            ] else if (showTextInput) ...[
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
                      // 📷 زر الصورة (يختفي عند بلوغ الحد الأقصى)
                      if (!isGenerating && controller.canAttachMore)
                        InkWell(
                          onTap: () => _pickImage(context),
                          borderRadius: BorderRadius.circular(30),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, top: 10, bottom: 10, right: 8),
                            child: Icon(Icons.camera_alt_rounded,
                                color: controller.attachedImages.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 23),
                          ),
                        ),

                      // 🎤 زر المايك — يبدأ شريط التسجيل
                      if (!isGenerating)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            onTap: () => controller.startVoiceRecording(),
                            borderRadius: BorderRadius.circular(30),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: controller.isCleaningVoice
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                                    )
                                  : Icon(Icons.mic_rounded,
                                      color: AppColors.textSecondary, size: 24),
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: controller.inputController,
                          enabled: !isGenerating || controller.messages.isEmpty,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: (_) => controller.refresh(),
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: controller.isRecording
                                ? "🎙️ أنا أسمعك... تكلّم"
                                : (controller.isCleaningVoice
                                    ? "✨ جارٍ ترتيب النص..."
                                    : "اكتب سؤالك..."),
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
          ],
        ),
      ),
    );
  }

  /// يفتح محرّر الصورة (قص + رسم) ويستبدل المرفق بالنتيجة.
  Future<void> _editImage(BuildContext context, int index, PickedImage img) async {
    final edited = await Navigator.push<PickedImage>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditorScreen(image: img)),
    );
    if (edited != null) controller.replaceImage(index, edited);
  }

  /// اختيار مصدر الصورة: كاميرا أو معرض.
  void _pickImage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text("التقاط صورة",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                controller.attachImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppColors.secondary),
              title: const Text("اختيار من المعرض",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                controller.attachImage(fromCamera: false);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
