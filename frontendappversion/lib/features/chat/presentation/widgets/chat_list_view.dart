import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/typewriter_text.dart';
import '../../../../core/widgets/typing_indicator.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// 💬 قائمة فقاعات المحادثة
// ==========================================
class ChatListView extends StatelessWidget {
  final ChatController controller;

  const ChatListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final messages = controller.messages;
    return ListView.builder(
      controller: controller.scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 160, // مساحة كافية لخانة الكتابة والزر
        top: MediaQuery.of(context).padding.top + 85, // مساحة للبار العلوي
      ),
      itemCount: messages.length + (controller.isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 10, bottom: 20, top: 10),
              child: TypingIndicator(),
            ),
          );
        }

        final msg = messages[i];
        final isUser = msg["role"] == "user";

        return FadeInSlide(
          delay: 0.0,
          beginOffset: Offset(isUser ? -0.05 : 0.05, 0),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isUser)
                  Container(
                    margin: const EdgeInsets.only(left: 10, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.surfaceWhite, shape: BoxShape.circle, boxShadow: AppColors.bubbleShadow),
                    child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
                  ),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(bottom: isUser ? 4 : 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: isUser ? AppColors.bubbleGradient : null,
                          color: isUser ? null : AppColors.surfaceWhite,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(24),
                            topRight: const Radius.circular(24),
                            bottomLeft: Radius.circular(isUser ? 24 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 24),
                          ),
                          boxShadow: AppColors.bubbleShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text("مسار AI", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            if (msg["animating"] == true && !controller.isLoading)
                              TypewriterText(
                                text: msg["fullText"] ?? msg["text"],
                                stopNotifier: controller.stopTypingNotifier,
                                onTyping: () {
                                  if (controller.scrollController.hasClients) {
                                    controller.scrollController.jumpTo(controller.scrollController.position.maxScrollExtent);
                                  }
                                },
                                onStopped: (stoppedText) {
                                  msg["text"] = "$stoppedText\n\n⏹️ *تم الإيقاف*";
                                  msg["animating"] = false;
                                  controller.refresh();
                                  controller.saveCurrentConversation();
                                },
                                onFinished: () {
                                  msg["animating"] = false;
                                  controller.refresh();
                                  controller.saveCurrentConversation();
                                },
                              )
                            else
                              MarkdownBody(
                                data: msg["text"],
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500, height: 1.6),
                                ),
                              ),
                            if (msg["refs"] != null && (msg["refs"] as List).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (msg["refs"] as List)
                                      .map<Widget>((ref) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.link_rounded, size: 12, color: AppColors.secondary),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Tooltip(
                                                    message: "$ref",
                                                    child: Text(
                                                      "$ref",
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),

                            // 👇 زر النسخ للذكاء الاصطناعي 👇
                            if (!isUser) ...[
                              const SizedBox(height: 12),
                              _copyButton(msg, dense: false),
                            ],
                          ],
                        ),
                      ),

                      // 👇 زر النسخ للطالب 👇
                      if (isUser)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, right: 6),
                          child: _copyButton(msg, dense: true),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _copyButton(Map<String, dynamic> msg, {required bool dense}) {
    final bool copied = msg["isCopied"] == true;
    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(copied ? Icons.check_rounded : Icons.content_copy_rounded, size: dense ? 13 : 14, color: copied ? Colors.green : AppColors.textSecondary),
        SizedBox(width: dense ? 4 : 6),
        Text(
          copied ? "تم النسخ" : "نسخ",
          style: TextStyle(
            fontSize: 11,
            color: copied ? Colors.green : (dense ? AppColors.textSecondary.withValues(alpha: 0.8) : AppColors.textSecondary),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: () async {
        final textToCopy = msg["fullText"] ?? msg["text"];
        await Clipboard.setData(ClipboardData(text: textToCopy));
        msg["isCopied"] = true;
        controller.refresh();
        Future.delayed(const Duration(seconds: 2), () {
          msg["isCopied"] = false;
          controller.refresh();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: dense
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: inner,
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: copied ? Colors.green.withValues(alpha: 0.1) : AppColors.softSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: inner,
            ),
    );
  }
}
