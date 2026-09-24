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
import '../../../../core/widgets/chat_welcome_hero.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/models/chat_suggestion.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../saved/data/saved_storage.dart';
import '../controllers/chat_controller.dart';
import '../../../teacher/data/teacher_tool.dart';
import '../controllers/stick_to_bottom.dart';
import '../../../../core/widgets/phosphor.dart';

// ==========================================
// 💬 قائمة فقاعات المحادثة
// ==========================================
class ChatListView extends StatelessWidget {
  final ChatController controller;

  /// ارتفاع ما يظهر أسفل الشاشة فوق خانة الكتابة (أزرار الوزاري / زر شرح
  /// الرياضيات). بدونه تختفي آخر رسالة خلف تلك الأزرار.
  final double bottomExtra;

  /// 🃏 ارتفاعُ بطاقة إعدادات الجلسة الثابتة فوق القائمة.
  ///
  /// 📌 **البطاقةُ لا تُمرَّر مع المحادثة** (قرار المالك: «إعدادات الجلسة
  /// تكون قدامي يقدر نعدّلها في أي وقت»). جرّبتُ جعلَها أوّلَ عناصر
  /// القائمة فطارت مع أول رسالة — وهذا خطأ.
  ///
  /// ✅ وهي **طافيةٌ فوق القائمة** لا دافعةٌ لها: القائمةُ تمتدّ تحتها
  /// كاملةً، وهذه الحشوةُ بمقدار ارتفاعها الحاليّ (مطويّةً كانت أو
  /// مفتوحة) — فلا يختفي شيءٌ خلفها ولا ينشأ فاصلٌ بينهما.
  final double topExtra;

  /// شريحةُ اقتراحاتٍ تُلصَق بآخر ردٍّ للمساعد — تُبنى من الخارج.
  final Widget Function(List<ChatSuggestion>)? followUpsBuilder;

  const ChatListView({
    super.key,
    required this.controller,
    this.bottomExtra = 0,
    this.topExtra = 0,
    this.followUpsBuilder,
  });

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
    // 💬 **فقاعة الترحيب** — حالةُ المحادثة الفارغة في التصميم
    //    (الرفيق الذاكي · 390:2048 عند y=547): فقاعةٌ 281×66 r14 بتعبئة
    //    `#E6F4FF` عنوانُها 12/w900 `#21302A` ووصفُها 12/w700 `#6C7A71`،
    //    وإلى يمينها الروبوت 45×45.
    //
    // 🔴 **كانت الشاشة فارغةً تماماً** قبل أول رسالة — بياضٌ لا يقول للطالب
    //    ماذا يفعل. والتصميمُ يملؤه بترحيبٍ يشرح الدور.
    if (messages.isEmpty && !controller.isLoading) {
      return _ChatWelcome(controller: controller);
    }
    return ListView.builder(
      controller: controller.scrollController,
      // 📐 **24 لا 16** — هامشُ بطاقة الجلسة نفسُه. البطاقةُ تطفو فوق
      //    القائمة، فلو كانت الفقاعاتُ أعرضَ منها لبرز طرفُها من جانبها
      //    عند التمرير كأنه عطل. وبتساوي الهامشين تمرّ الفقاعةُ خلفها
      //    مستورةً تماماً.
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 24 + bottomExtra,
        top: 8 + topExtra,
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
        final bool isLast = i == messages.length - 1;
        final List<ChatSuggestion> followUps = followUpsBuilder == null
            ? const []
            : controller.suggestions.where((s) => !s.primary).toList();

        // ↗️ **اقتراحاتُ المتابعة من الرسالة نفسها** (قرار المالك):
        //    أسهمٌ تحت آخر ردٍّ — لا شريطُ شرائحَ فوق حقل الكتابة يزاحم
        //    الصفحات ويضيّق الشاشة. وتحت **آخر** ردٍّ وحده: تكرارُها تحت
        //    كل ردٍّ يحوّل المحادثة قائمةَ أزرار.
        //
        // ⚠️ وهي **خارج صفّ الفقاعة** لا داخله: الصفُّ يحاذي أبناءه من
        //    الأسفل، فلو دخلت فيه لانزلقت صورةُ الروبوت إلى أسفل آخر سهم
        //    بدل أن تلازم الفقاعة. رأيتُه في المحاكي.
        final bool showFollowUps =
            !isUser &&
            isLast &&
            msg["streaming"] != true &&
            msg["animating"] != true &&
            followUps.isNotEmpty;

        // 📍 رسالةٌ جاء إليها من البحث: مفتاحٌ يُمرَّر إليه، ووميضٌ لحظيّ.
        final bool revealed = controller.revealedIndex == i;
        return KeyedSubtree(
          key: revealed ? controller.revealKey : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              color: revealed
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: FadeInSlide(
              delay: 0.0,
              beginOffset: Offset(isUser ? -0.05 : 0.05, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 👥 **الصورتان في جهةٍ واحدة: اليمين** (قرار المالك).
                        //
                        //    اليمينُ في العربية أوّلُ السطر — فمن هناك «تخرج»
                        //    الرسالةُ نحو اليسار. فصورةُ صاحبِها أوّلُ ما يُقرأ:
                        //    الروبوتُ يمينَ ردِّه، والطالبُ يمينَ رسالته. ووضعُ
                        //    صورة الطالب في اليسار كان يجعل رسالتَه تبدو خارجةً
                        //    من الجهة المقابلة.
                        //
                        // ⚠️ و`Row` في RTL يضع **أوّلَ ابنٍ في اليمين** — فكلتاهما
                        //    تُكتب قبل الفقاعة لا بعدها.
                        //
                        // 🤖 والروبوتُ نفسُه لا ثلاثُ نجمات: شخصيّةُ «مسار» هي وجهُ
                        //    الردّ، وأيقونةُ «تألّق» عامّةٌ لا تقول من يتكلّم.
                        if (!isUser)
                          Container(
                            margin: const EdgeInsets.only(left: 10, bottom: 8),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTintSurface,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.bubbleShadow,
                            ),
                            child: const MasarRobot(size: 28),
                          ),
                        // 👤 صورةُ الطالب — `UserAvatar` نفسُه المستعمل في الرئيسية:
                        //    يعرف الزائرَ من صاحب الحساب ويتحدّث بعد رفع الصورة.
                        if (isUser)
                          const Padding(
                            padding: EdgeInsets.only(left: 10, bottom: 8),
                            child: UserAvatar(radius: 15),
                          ),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            // ⚠️ التطبيق RTL: `start` = يمين الشاشة و`end` = يسارها.
                            //    رسالة الطالب تُحاذى لليمين، ورد المساعد لليسار —
                            //    وبهذا تلتصق الفقاعة بحافة الصور المرفقة نفسها
                            //    بدل أن تنزاح للجهة المقابلة عند إرسال صورتين.
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              // 📷 الصور المرفقة — قابلة للضغط لعرضها ملء الشاشة
                              if (((msg["images"] as List?) ?? const [])
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _AttachedImages(
                                    key: const ValueKey("attachedImages"),
                                    paths: List<String>.from(msg["images"]),
                                  ),
                                ),
                              Container(
                                key: const ValueKey("bubble"),
                                margin: EdgeInsets.only(
                                  bottom: isUser ? 4 : 12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isUser
                                      ? AppColors.bubbleGradient
                                      : null,
                                  color: isUser ? null : AppColors.surfaceWhite,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(24),
                                    topRight: const Radius.circular(24),
                                    bottomLeft: Radius.circular(
                                      isUser ? 24 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      isUser ? 4 : 24,
                                    ),
                                  ),
                                  boxShadow: AppColors.bubbleShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isUser)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "مسار AI",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            // ⚡ **وسمُ «من المحفوظ»** — شرحٌ جاهزٌ من
                                            //    المخزون ([core/lesson_cache]) لا مولَّد:
                                            //    يصل في جزءٍ من الثانية وبلا خصمٍ من
                                            //    الحصة. سأل المالك «ما أدري هل يجي من
                                            //    المخزون ولا لا» — فصار يُرى لا يُحزَر.
                                            if (msg["cached"] == true) ...[
                                              const SizedBox(width: 7),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(9),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      PI.lightning.fill,
                                                      size: 12,
                                                      color: AppColors.primary,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      "من المحفوظ",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    // 🌊 **البثّ جارٍ**: النصّ ينمو، وحافته السفلى
                                    //    تتلاشى فينبثق الجديد بهدوء بدل أن يقفز،
                                    //    ومؤشّرٌ يقول «ما زال يكتب» ([StreamingText]).
                                    if (msg["streaming"] == true)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          StreamingText(
                                            streaming: true,
                                            child: MasarMarkdown(
                                              data: (msg["text"] ?? "")
                                                  .toString(),
                                              selectable: false,
                                              // 🧪 رسّامُ الكيمياء في الكيمياء وحدها
                                              subject:
                                                  controller.selectedSubject,
                                              styleSheet: MarkdownStyleSheet(
                                                p: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontSize: AppSettings
                                                      .I
                                                      .answerFontSize,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.6,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: TypingCaret(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (msg["animating"] == true &&
                                        !controller.isLoading)
                                      TypewriterText(
                                        text: msg["fullText"] ?? msg["text"],
                                        stopNotifier:
                                            controller.stopTypingNotifier,
                                        // 📌 **والطابعةُ تتبع قاعدةَ التمرير كالبثّ
                                        //    تماماً** (أمرُ المالك 2026-09-19):
                                        //    «لو جات رسالة من المخزون تو على طول
                                        //    ينزل بآخر شيء… أنا أبغاه نفس لو أرسلت
                                        //    رسالة للمودل ويجيبها».
                                        //
                                        // 🔴 وكان هنا `jumpTo(maxScrollExtent)`
                                        //    **بلا شرط** مع كل حرف — يتجاوز
                                        //    [StickToBottom] كلَّه. فالشرحُ المخزون
                                        //    (وهو وحده ما يُكتب بالطابعة) كان يسحب
                                        //    الشاشةَ من تحت القارئ ولا يُفلتها، ولو
                                        //    وضع إصبعَه عليها. والبثُّ من الموديل
                                        //    يحترمها منذ 2026-09-09
                                        //    ([chat_controller._flushStream]) —
                                        //    فاختلف المساران في شيءٍ يراه الطالب.
                                        //
                                        // ⏱️ وبعد إطارٍ واحد: `maxScrollExtent` لا
                                        //    يعرف الحرفَ الجديد قبل أن يُخطَّط.
                                        onTyping: () {
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                controller.scrollController
                                                    .followBottom(
                                                      controller.stick,
                                                    );
                                              });
                                        },
                                        onStopped: (stoppedText) {
                                          msg["text"] =
                                              "$stoppedText\n\n⏹️ *تم الإيقاف*";
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
                                          p: TextStyle(
                                            color: isUser
                                                ? Colors.white
                                                : AppColors.textPrimary,
                                            fontSize:
                                                AppSettings.I.answerFontSize,
                                            fontWeight: FontWeight.w500,
                                            height: 1.6,
                                          ),
                                        ),
                                      ),
                                    if (msg["refs"] != null &&
                                        (msg["refs"] as List).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: (msg["refs"] as List)
                                              .map<Widget>(
                                                (ref) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.softSurface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        PI.link.bold,
                                                        size: 12,
                                                        color:
                                                            AppColors.secondary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Tooltip(
                                                          message: "$ref",
                                                          child: Text(
                                                            "$ref",
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppColors
                                                                  .textSecondary,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
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
                                  padding: const EdgeInsets.only(
                                    bottom: 12,
                                    right: 6,
                                  ),
                                  child: _copyButton(msg, dense: true),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showFollowUps)
                    Padding(
                      padding: const EdgeInsets.only(right: 44),
                      child: followUpsBuilder!(followUps),
                    ),
                ],
              ),
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
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      nowSaved ? "⭐ حُفظت في المحفوظات" : "أُزيلت من المحفوظات",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.textPrimary,
                  ),
                );
            },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: saved ? AppColors.savedSurface : AppColors.softSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? PI.star.fill : PI.star.regular,
              size: 15,
              color: busy
                  ? AppColors.textSecondary.withValues(alpha: 0.4)
                  : (saved ? AppColors.savedInk : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              saved ? "محفوظة" : "حفظ",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: saved ? AppColors.savedInk : AppColors.textSecondary,
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
        Icon(
          copied ? PI.check.bold : PI.copy.regular,
          size: dense ? 13 : 14,
          color: copied ? AppColors.copiedInk : AppColors.textSecondary,
        ),
        SizedBox(width: dense ? 4 : 6),
        Text(
          copied ? "تم النسخ" : "نسخ",
          style: TextStyle(
            fontSize: 11,
            color: copied
                ? Colors.green
                : (dense
                      ? AppColors.textSecondary.withValues(alpha: 0.8)
                      : AppColors.textSecondary),
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
                color: copied
                    ? Colors.green.withValues(alpha: 0.1)
                    : AppColors.softSurface,
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
                builder: (_) =>
                    ImageViewerScreen(paths: paths, initialIndex: i),
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
                      Icon(
                        PI.imageBroken.regular,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "الصورة لم تعد متاحة",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// ══════════════════════════════════════════════════
// 🤖 ترحيبُ المحادثة الفارغة — روبوتٌ في الوسط وتحته كلام
// ══════════════════════════════════════════════════
// 🎯 **قرار المالك (٢٠٢٦-٠٩-٢٤):** «لما يدخل على أي محادثة يطلع له الروبوت
//    بشكلٍ جميل جداً في النص، وتحته كلام — نفس المنح ونفس المعلم. والكلامُ
//    يتغيّر على حسب الوضع». فالقسمان وشاشةُ المنح لغةٌ واحدة: هالةٌ زرقاء
//    ١٩٠ فيها الروبوتُ المتحرّك ١١٨ (مقاسُ ترحيب المنح نفسُه)، ثم عنوانٌ
//    ١٨/w900، ثم سطرٌ صغيرٌ بالمادة والوضع، ثم فقرةٌ وسطيّة.
//
// 🔄 **وما كان:** فقاعةٌ صغيرةٌ عند الطالب («أنا مسار، رفيقك التعليمي»)
//    ولوحةٌ وسطيّةٌ عند المعلّم (روبوت `fly` ١٠٤) — شكلان لحالةٍ واحدة،
//    ونصٌّ ثابتٌ لا يقول ماذا يفعل الطالب **الآن**.
//
// 🃏 **والبطاقةُ مطويّةٌ عند الدخول** ([ChatController.showSettingsPanel])،
//    فالفقرةُ تدلّ عليها بالاسم: «اضغط «إعدادات الجلسة» في الأعلى».
//
// 📐 **ويتوسّط ما بقي تحت البطاقة، ويعلو حين يضيق** (بطاقةٌ مفتوحةٌ طويلة).
class _ChatWelcome extends StatelessWidget {
  const _ChatWelcome({required this.controller});

  final ChatController controller;

  static const double gapUnderCard = 24;

  ChatController get c => controller;

  /// الوضعُ كما يراه الطالب — الرياضياتُ وضعُها في `mathMode`.
  String get _mode =>
      c.selectedSubject == "رياضيات" ? c.mathMode : c.selectedMode;

  String get _title => c.isTeacher
      ? "مساعد المعلم الذكي"
      : "مرحباً ${UserSession.I.name}! أنا مسار";

  String get _tag {
    final t = c.teacherTool;
    if (t != null) return "${c.selectedSubject} · ${t.label}";
    return "${c.selectedSubject} · $_mode";
  }

  /// 📝 **ماذا يفعل الآن — بحسب الوضع أو الأداة.**
  String get _body {
    const open = "اضغط «إعدادات الجلسة» في الأعلى";
    final t = c.teacherTool;
    if (t != null) {
      // 👋 باسم المعلّم كما كان ترحيبُه — العنوانُ للقسم والتحيّةُ له.
      final body = switch (t) {
        TeacherTool.lessonPlan =>
          "$open واختر المادة والوحدة والدرس، ثم «توليد خطة الدرس» — "
              "أهدافٌ وخطواتٌ بأزمنتها ونشاطٌ وتقويم، وناقشها معي بعدها.",
        TeacherTool.homework =>
          "$open واختر الدرس والمستوى وعدد الأسئلة، ثم «إنشاء الواجب» — "
              "متدرّجَ الصعوبة ومعه سلّمُ التصحيح.",
        TeacherTool.simplify =>
          "$open واختر الدرس، ثم اكتب لي المفهوم الذي يتعثّر فيه طلابك — "
              "وأبسّطه بتشبيهاتٍ وتمثيلٍ وسؤالٍ كاشف.",
        TeacherTool.ask =>
          "اسألني عن التدريس وإدارة الحصة والتقويم والطلاب الضعاف — "
              "ومع درسٍ من «إعدادات الجلسة» إن أردت أن نتكلّم عنه.",
      };
      return "مرحباً ${UserSession.I.name}! $body";
    }
    return switch (_mode) {
      "تلخيص" =>
        "$open واختر درسك ومستوى التلخيص — وألخّصه لك "
            "في نقاطٍ واضحةٍ تراجعها قبل الاختبار.",
      "سؤال" =>
        "$open واختر درسك، ثم اكتب سؤالك — "
            "أجيبك من كتابك مباشرةً، بأمثلةٍ إن احتجت.",
      "اختبارات" =>
        "$open واختر دروسك — وأجهّز لك اختباراً قصيراً "
            "يكشف ما أتقنتَه وما يحتاج مراجعة.",
      "وزاري" =>
        "$open واختر السنة والقسم — وأعرض لك أسئلة الوزارة "
            "وأحلّها معك خطوةً بخطوة.",
      _ =>
        "$open واختر درسك — وأشرحه لك من كتابك خطوةً بخطوة، "
            "ثم اسألني عمّا لم يتّضح.",
    };
  }

  // 📌 **ثابتٌ خلف البطاقة — لا يتقلّص ولا يتحرّك** (قرار المالك
  //    ٢٠٢٦-٠٩-٢٤: «لو طلّعت إعدادات الجلسة، خلاص هو يتمّ واقف ورا —
  //    الإعدادات تطلع فوقها، وإذا رجعتها ترجع. ما في داعي تصغّر وتكبّر
  //    الروبوت»). فموضعُه يُحسب من **رأس البطاقة المطويّ** لا من ارتفاعها
  //    الحاليّ ([topExtra])، والبطاقةُ المفتوحةُ تغطّيه كما تغطّي أيَّ رسالة.
  static const double collapsedCard = 62;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, collapsedCard + gapUnderCard, 24, 16),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ChatWelcomeHero(
            title: _title,
            tag: _tag,
            body: _body,
          ),
        ),
      ),
    );
  }
}
