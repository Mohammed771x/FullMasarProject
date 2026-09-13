import 'dart:io';
import '../../../../core/widgets/masar_markdown.dart';
import '../../../../core/widgets/streaming_text.dart';

import 'package:flutter/material.dart';

import '../../../../core/media/image_viewer_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/typewriter_text.dart';
import '../../../../core/widgets/typing_indicator.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../saved/data/saved_storage.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// 💬 قائمة فقاعات المحادثة
// ==========================================
class ChatListView extends StatelessWidget {
  final ChatController controller;

  /// ارتفاع ما يظهر أسفل الشاشة فوق خانة الكتابة (أزرار الوزاري / زر شرح
  /// الرياضيات). بدونه تختفي آخر رسالة خلف تلك الأزرار.
  final double bottomExtra;

  const ChatListView({super.key, required this.controller, this.bottomExtra = 0});

  @override
  Widget build(BuildContext context) {
    final messages = controller.messages;

    // ══════════════════════════════════════════════════
    // 📌 تمرير الطالب **بنفسه** هو الإشارة الوحيدة
    // ══════════════════════════════════════════════════
    // 🔴 **الفرق الذي تقوم عليه الميزة كلها:** نموّ النصّ أثناء البثّ يزيد
    //    `maxScrollExtent` فتكبر المسافة إلى القاع **بلا أن يلمس الطالب
    //    شيئاً**. ولو عاملنا ذلك «صعوداً» لفُكّ الالتصاق من تلقاء نفسه في
    //    أول جزء — أي أن الميزة تتعطّل بالضبط حين تلزم.
    //
    // ✅ ولذلك نستمع لـ`ScrollUpdateNotification` **ذات `dragDetails`**
    //    وحدها: هي التي تعني إصبعاً على الشاشة. أما `ScrollMetricsNotification`
    //    (تغيّر المقاسات) فنتجاهلها تماماً.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification && n.dragDetails != null) {
          // 👆 **لحظة اللمس**: الطالب أخذ الشاشة. نفكّ الالتصاق فوراً بلا
          //    انتظار عتبة، وإلا ابتلع القفزُ التالي سحبتَه قبل أن تبلغها.
          controller.onUserDragStart();
        } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
          controller.onUserScroll(n.metrics);
        } else if (n is ScrollEndNotification) {
          // ✋ رُفع الإصبع واستقرّت اللفّة — والموضع النهائي هو ما يعنينا.
          controller.onUserDragEnd(n.metrics);
        }
        return false;
      },
      child: _buildList(context, messages),
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> messages) {
    return ListView.builder(
      controller: controller.scrollController,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 160 + bottomExtra, // خانة الكتابة + ما يعلوها من أزرار
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
                    // ⚠️ التطبيق RTL: `start` = يمين الشاشة و`end` = يسارها.
                    //    رسالة الطالب تُحاذى لليمين، ورد المساعد لليسار —
                    //    وبهذا تلتصق الفقاعة بحافة الصور المرفقة نفسها
                    //    بدل أن تنزاح للجهة المقابلة عند إرسال صورتين.
                    crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      // 📷 الصور المرفقة — قابلة للضغط لعرضها ملء الشاشة
                      if (((msg["images"] as List?) ?? const []).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _AttachedImages(
                            key: const ValueKey("attachedImages"),
                            paths: List<String>.from(msg["images"]),
                          ),
                        ),
                      Container(
                        key: const ValueKey("bubble"),
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
                            // 🌊 **البثّ جارٍ**: النصّ ينمو، وحافته السفلى
                            //    تتلاشى فينبثق الجديد بهدوء بدل أن يقفز،
                            //    ومؤشّرٌ يقول «ما زال يكتب» ([StreamingText]).
                            if (msg["streaming"] == true)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StreamingText(
                                    streaming: true,
                                    child: MasarMarkdown(
                                      data: (msg["text"] ?? "").toString(),
                                      selectable: false,
                                      // 🧪 رسّامُ الكيمياء في الكيمياء وحدها
                                      subject: controller.selectedSubject,
                                      styleSheet: MarkdownStyleSheet(
                                        p: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: AppSettings.I.answerFontSize,
                                            fontWeight: FontWeight.w500,
                                            height: 1.6),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: TypingCaret(color: AppColors.primary),
                                  ),
                                ],
                              )
                            else if (msg["animating"] == true && !controller.isLoading)
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
                              MasarMarkdown(
                                data: msg["text"],
                                selectable: true,
                                subject: controller.selectedSubject,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: AppSettings.I.answerFontSize, fontWeight: FontWeight.w500, height: 1.6),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _copyButton(msg, dense: false),
                                  const SizedBox(width: 8),
                                  _saveButton(context, msg),
                                ],
                              ),
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

  /// ⭐ حفظ الإجابة.
  ///
  /// ⚠️ **لا نحفظ أثناء الطباعة**: `text` وقتها جزءٌ ناقص من الرد، فتُخزَّن
  ///    نصفُ إجابة ببصمةٍ لا تطابق النصّ الكامل بعد انتهائه — فيظهر الزر
  ///    فارغاً وقد حُفظ شيء. لذلك نقرأ `fullText` ونعطّل الزر حتى تكتمل.
  Widget _saveButton(BuildContext context, Map<String, dynamic> msg) {
    final String text = (msg["fullText"] ?? msg["text"] ?? "").toString();
    final bool busy = msg["animating"] == true;
    final String uid = UserSession.I.uid;
    final bool saved = !busy && SavedStorage.isSaved(uid, text);

    return InkWell(
      onTap: busy || text.trim().isEmpty
          ? null
          : () async {
              final nowSaved = await SavedStorage.toggle(
                ownerUid: uid,
                section: controller.isTeacher ? "teacher" : "education",
                subject: controller.selectedSubject,
                text: text,
                scope: UserSession.I.scope,
              );
              controller.refresh();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(
                    nowSaved ? "⭐ حُفظت في المحفوظات" : "أُزيلت من المحفوظات",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.textPrimary,
                ));
            },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: saved
              ? Colors.amber.withValues(alpha: 0.14)
              : AppColors.softSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 15,
              color: busy
                  ? AppColors.textSecondary.withValues(alpha: 0.4)
                  : (saved ? Colors.amber.shade700 : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              saved ? "محفوظة" : "حفظ",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: saved ? Colors.amber.shade800 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
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


/// صور الرسالة — ضغطة تفتح العارض ملء الشاشة.
class _AttachedImages extends StatelessWidget {
  final List<String> paths;
  const _AttachedImages({super.key, required this.paths});

  @override
  Widget build(BuildContext context) {
    // صورتان معاً ⇒ مربّعان متساويان تماماً، فلا تتفاوت الحواف السفلية
    // ولا يبدو النص تحتهما مائلاً. صورة واحدة ⇒ تحتفظ بنسبتها الطبيعية.
    final bool multi = paths.length > 1;
    final double w = multi ? 120.0 : 190.0;
    final double? h = multi ? 120.0 : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(paths.length, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i < paths.length - 1 ? 6 : 0),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(paths: paths, initialIndex: i),
              ),
            ),
            borderRadius: BorderRadius.circular(18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(paths[i]),
                width: w,
                height: h,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: w,
                  height: h ?? 110,
                  color: AppColors.softSurface,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_rounded,
                          color: AppColors.textSecondary, size: 24),
                      const SizedBox(height: 4),
                      Text("الصورة لم تعد متاحة",
                          style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
