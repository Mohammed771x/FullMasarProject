import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/settings/app_settings.dart';
import '../../saved/data/saved_storage.dart';
import '../../../core/media/image_editor_screen.dart';
import '../../../core/media/image_viewer_screen.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/voice_text_merge.dart';
import '../../../core/widgets/chat_welcome_hero.dart';
import '../../../core/widgets/reveal_in_scroll.dart';
import '../../../core/widgets/tap_to_dismiss_keyboard.dart';
import '../../../core/widgets/masar_markdown.dart';
import '../../../core/widgets/streaming_text.dart';
import '../../../core/widgets/voice_recording_bar.dart';
import '../../../core/widgets/typing_indicator.dart';
import '../../../core/widgets/masar_brand.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/phosphor.dart';
import 'widgets/scholarship_ui.dart';
import '../data/models/scholarship.dart';
import '../data/models/scholarship_chat.dart';
import '../../../core/session/user_session.dart';
import 'controllers/scholarship_chat_controller.dart';
import 'widgets/scholarship_chat_drawer.dart';
import '../../../../core/widgets/input_bar_metrics.dart';

// ==========================================
// 💬 شات مساعد المنحة — بسجلّ محادثات جانبي
// ==========================================
// ⭐ **ما كان ناقصاً في الديمو:** شات بلا ذاكرة. تفتح المساعد فتبدأ من
//    الصفر في كل مرة، ولا سبيل للرجوع لما قيل لك عن خطاب الدافع الأسبوع
//    الماضي. الآن: **قائمة جانبية** فيها كل محادثاتك مع هذه المنحة —
//    مربوطة بحسابك، محفوظة على الجهاز، ومرفوعة للسحابة فتعود معك على
//    جهاز جديد ([32§5]).
//
// الفصل مقصود: محادثات المنحة التركية لا تظهر في المنحة الماليزية.
class ScholarshipChatScreen extends StatefulWidget {
  final Scholarship scholarship;
  const ScholarshipChatScreen({super.key, required this.scholarship});

  @override
  State<ScholarshipChatScreen> createState() => _ScholarshipChatScreenState();
}

class _ScholarshipChatScreenState extends State<ScholarshipChatScreen> {
  late final ScholarshipChatController _c;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _scaffold = GlobalKey<ScaffoldState>();

  /// طابع الرسالة التي نُسخت للتوّ — لتبديل الأيقونة ثانيتين.
  DateTime? _copiedAt;

  @override
  void initState() {
    super.initState();
    _c = ScholarshipChatController(scholarship: widget.scholarship)..start();
    _c.addListener(_onChange);
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.flush();          // ارفع المؤجَّل قبل الخروج
    _c.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
    // 📍 فُتحت من نتيجة بحث ⇒ إلى تلك الرسالة لا إلى الآخر.
    final reveal = _c.takePendingReveal();
    if (reveal != null) {
      _reveal(reveal.$1, position: reveal.$2);
      return;
    }
    // 📌 ما دام يقرأ ما جاء إليه من البحث لا يُسحب إلى الآخر بإشعارٍ عابر.
    if (_revealed != null) return;
    _scrollToEnd();
  }

  // ══════════════ 📍 الذهابُ إلى رسالة (من البحث) ══════════════
  // نظيرُ [ChatController.revealMessage]: القائمةُ كسولة، فقفزةٌ تقديريّةٌ
  // تبني الرسالة ثم `ensureVisible` الدقيق، ووميضٌ لحظيٌّ يدلّ عليها.
  int? _revealed;
  final GlobalKey _revealKey = GlobalKey(debugLabel: 'sch-reveal');

  Future<void> _reveal(int index, {double position = 0}) async {
    setState(() => _revealed = index);
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted || _revealed != index) return;
      final ctx = _revealKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await revealInScroll(_scroll, ctx, position: position);
        break;
      }
      final n = _c.messages.length;
      if (_scroll.hasClients && n > 1) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent * index / (n - 1));
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (mounted && _revealed == index) setState(() => _revealed = null);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty && !_c.hasAttachments) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    await _c.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scholarship;
    return Scaffold(
      key: _scaffold,
      backgroundColor: AppColors.bgLight,
      // ★ القائمة الجانبية: من اليمين في RTL — نفس مكان درج قسم التعليم.
      drawer: ScholarshipChatDrawer(controller: _c),
      body: Stack(
        children: [
          // 🌈 **خلفيّةُ المحادثة ليست بيضاء** — نفسُ تدرّج قسم التعليم
          //    حرفاً بحرف (أمرُ المالك 2026-09-21: «نفس بالضبط حق قسم
          //    التعليم»). وهو تدرّجٌ رأسيٌّ يعمّ الشاشة: أبيضُ في الأعلى
          //    يزرقّ حتى ذروةٍ عند ثلثيها ثم يرمدّ في القاع.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.chatBackdrop),
              ),
            ),
          ),
          Column(
        children: [
          _appBar(context, s),
          // ⌨️ نقرةٌ على المحادثة تُنزل الكيبورد — تجربةُ المحادثة واحدةٌ
          //    في كل الأقسام ([TapToDismissKeyboard]).
          Expanded(
            child: TapToDismissKeyboard(
              child: _c.isEmpty ? _intro(s) : _list(),
            ),
          ),
          if (_c.notice != null) _noticeBar(_c.notice!),
          // 🔴 **كانت تختفي بعد أول سؤال** — فيرى الطالبُ بابَ «الوثائق»
          //    مرّةً واحدةً ثم لا يجد المواعيدَ ولا المزايا أبداً
          //    (علّةُ المالك: «مش باين عندي»). وهي أجوبةٌ فوريّةٌ بلا
          //    كلفة، فبقاؤها مكسبٌ لا مزاحمة.
          if (!_c.hasAttachments && !_c.isRecording) _quickPrompts(s),
          if (_c.hasAttachments && !_c.isRecording) _attachmentStrip(),
          // 🎙️ **نفس شريط قسم التعليم حرفياً**: موجات · مؤقّت · حذف ·
          //    إيقاف→نص · إرسال مباشر. تجربة واحدة في القسمين لا اثنتان.
          if (_c.isRecording)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: VoiceRecordingBar(
                  onDelete: () => _c.cancelVoiceRecording(),
                  onStopToText: _voiceToText,
                  onSend: _voiceAndSend,
                ),
              ),
            )
          else
            _inputBar(),
        ],
          ),
        ],
      ),
    );
  }

  // ══════════════ الرأس ══════════════

  /// 📐 مقيسٌ من `05-الرفيق الذاكي`: رأسٌ **أبيضُ** لا متدرّج، أزرارُه
  ///    40×40 · r14 بحدٍّ `#E8EDF3` وحبرٍ `#003359`. وترتيبُه من اليمين:
  ///    الرجوع · رمزُ الدولة · العنوانُ ووصفُه · محادثةٌ جديدة · السجلّ.
  Widget _appBar(BuildContext context, Scholarship s) {
    final count = _c.history.length;
    return Container(
      // 🌈 شفّافٌ كي يمرّ تدرّجُ الخلفية تحته — كما في رأس قسم التعليم.
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
          SchMetrics.margin, MediaQuery.of(context).padding.top + 10,
          SchMetrics.margin, 12),
      child: Row(
        children: [
          // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك سهمُ الرجوع في التصدير.
          SchSquareButton(
            icon: PI.arrowRight,
            onTap: () => Navigator.maybePop(context),
            tooltip: "رجوع",
          ),
          const SizedBox(width: 10),
          Text(s.badge, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("مساعد ${s.name}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.headingInk)),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: s.statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(_c.isSending ? "يكتب الآن..." : s.statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SchSquareButton(
            icon: PI.plus,
            tooltip: "محادثة جديدة",
            onTap: () {
              _c.newChat();
              _input.clear();
            },
          ),
          const SizedBox(width: 8),
          // 📂 السجلّ — بشارة العدد كي يعرف الطالب أن له محادثات سابقة.
          SchSquareButton(
            icon: PI.chat,
            tooltip: "محادثاتي",
            badge: count > 0 ? "$count" : null,
            onTap: () => _scaffold.currentState?.openDrawer(),
          ),
        ],
      ),
    );
  }

  // ══════════════ الرسائل ══════════════

  /// شاشة البدء: ترحيب ثابت **بلا نداء موديل** — لا نصرف من حصة الطالب
  /// على جملة يمكن كتابتها في الكود.
  ///
  /// 📐 من `05-الرفيق الذاكي`: الروبوتُ فوق هالةٍ زرقاء، ثم الترحيبُ
  ///    18/w900، ثم الوصفُ 12/w600 — والكلُّ في وسط الشاشة لا أعلاها.
  Widget _intro(Scholarship s) {
    // 🤖 [ChatWelcomeHero] نفسُه في الأقسام الثلاثة — مقيسٌ من هذا التصميم.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SchMetrics.margin),
      child: Center(
        child: SingleChildScrollView(
          child: ChatWelcomeHero(
            title: "أهلاً! أنا مساعد ${s.name}",
            body:
                "اسألني عن الشروط، المواعيد، الوثائق المطلوبة، أو طريقة التقديم.\n"
                "أجيب من بيانات هذه المنحة — وما لا أعرفه أقول لك إني لا أعرفه.",
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final msgs = _c.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          SchMetrics.margin, 10, SchMetrics.margin, 10),
      itemCount: msgs.length + (_c.isSending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= msgs.length) {
          // ⏳ في **يسار** الشاشة كما في قسم التعليم: هناك يظهر ردُّ
          //    المساعد، فمؤشّرُ كتابته يسبقه في مكانه لا في الجهة المقابلة.
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 10, bottom: 20, top: 10),
              child: TypingIndicator(),
            ),
          );
        }
        // 🌊 الفقاعة الأخيرة وحدها هي التي تُبثّ — وما قبلها مكتملٌ ثابت.
        final bubble = _bubble(msgs[i],
            streaming: _c.isStreaming && i == msgs.length - 1 && !msgs[i].isUser);
        final revealed = _revealed == i;
        return KeyedSubtree(
          key: revealed ? _revealKey : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              color: revealed
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: bubble,
          ),
        );
      },
    );
  }

  /// زر نسخ ظاهر — نفس ما في قسم التعليم، لأن الطالب ينسخ شروط المنحة
  /// ومواعيدها كثيراً، والضغط المطوّل وحده ميزةٌ مخفيّة لا يكتشفها.
  /// ينسخ نصّ الرسالة (بلا نصّ الصورة — الطالب يريد الكلام لا وصف الصورة).
  Future<void> _copy(SchMessage m) async {
    await Clipboard.setData(ClipboardData(text: m.text));
    if (!mounted) return;
    setState(() => _copiedAt = m.timestamp);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedAt == m.timestamp) {
        setState(() => _copiedAt = null);
      }
    });
  }

  /// ⭐ حفظ رد المساعد في المحفوظات — **شريحةُ قسم التعليم نفسُها**
  /// (أمرُ المالك 2026-09-21: «مكان النسخ واللصق… نفس حق التعليم بالضبط»).
  Widget _saveButton(SchMessage m) {
    final uid = UserSession.I.uid;
    final saved = SavedStorage.isSaved(uid, m.text);
    return InkWell(
      onTap: m.text.trim().isEmpty
          ? null
          : () async {
              final nowSaved = await SavedStorage.toggle(
                ownerUid: uid,
                section: "scholarship",
                subject: widget.scholarship.name,
                text: m.text,
                scope: UserSession.I.scope,
              );
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(
                      nowSaved ? "⭐ حُفظت في المحفوظات" : "أُزيلت من المحفوظات",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.textPrimary,
                ));
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
            Icon(saved ? PI.star.fill : PI.star.regular,
                size: 15,
                color: saved ? AppColors.savedInk : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(saved ? "محفوظة" : "حفظ",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        saved ? AppColors.savedInk : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _copyButton(SchMessage m, {bool dense = false}) {
    final copied = _copiedAt == m.timestamp;
    final inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(copied ? PI.check.bold : PI.copy.regular,
            size: dense ? 13 : 14,
            color: copied ? AppColors.copiedInk : AppColors.textSecondary),
        SizedBox(width: dense ? 4 : 6),
        Text(copied ? "تم النسخ" : "نسخ",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:
                    copied ? AppColors.copiedInk : AppColors.textSecondary)),
      ],
    );
    return InkWell(
      onTap: () => _copy(m),
      borderRadius: BorderRadius.circular(8),
      child: dense
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: inner)
          : AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: copied
                    ? AppColors.copiedInk.withValues(alpha: 0.1)
                    : AppColors.softSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: inner,
            ),
    );
  }

  /// 💬 **الفقاعةُ نسخةٌ من قسم التعليم حرفاً بحرف** (أمرُ المالك
  ///    2026-09-21: «طريقة عرض الكلام، صورة الشخص، مكان النسخ واللصق،
  ///    وصورة الذكاء الصناعي وين تكون — نفس حق التعليم بالضبط»).
  ///
  ///    ⇒ الطالبُ **يميناً** بفقاعةٍ متدرّجة وصورتُه بجانبها، والمساعدُ
  ///      يساراً بفقاعةٍ **بيضاء بحبرٍ أسود** يعلوها اسمُ «مسار AI»
  ///      وصورةُ الروبوت — والصورتان في **جهةٍ واحدة: اليمين**، لأن
  ///      اليمينَ أوّلُ السطر في العربية فمن هناك تخرج الرسالة.
  ///
  /// ⚠️ وهذا **يخالف تصدير المنح** الذي وضع فقاعةَ الطالب يساراً بتعبئةٍ
  ///    زرقاء — والمالك حسم: تجربةُ المحادثة واحدةٌ في القسمين.
  Widget _bubble(SchMessage m, {bool streaming = false}) {
    final isUser = m.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ⚠️ `Row` في RTL يضع **أوّلَ ابنٍ في اليمين** — فالصورتان
          //    تُكتبان قبل الفقاعة لا بعدها.
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(left: 10, bottom: 8),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: AppColors.primaryTintSurface,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.bubbleShadow),
              child: const MasarRobot(size: 28),
            ),
          if (isUser)
            const Padding(
              padding: EdgeInsets.only(left: 10, bottom: 8),
              child: UserAvatar(radius: 15),
            ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // ⚠️ التطبيق RTL: `start` = يمين الشاشة و`end` = يسارها.
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // 📷 الصور **فوق** الفقاعة لا داخلها — كما في قسم التعليم.
                if (m.hasImages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _bubbleImages(m.imagePaths),
                  ),
                if (m.text.isNotEmpty || !isUser)
                  GestureDetector(
                    onLongPress: () => _copy(m),
                    child: Container(
                      margin: EdgeInsets.only(bottom: isUser ? 4 : 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isUser)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text("مسار AI",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          if (isUser)
                            Text(m.text,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppSettings.I.answerFontSize,
                                    height: 1.6,
                                    fontWeight: FontWeight.w500))
                          // 🚫 بلا رسّام رياضيات: المنح لا رياضيات فيها،
                          //    ورفعُ «رقم/رقم» إلى كسر يحوّل تاريخاً
                          //    (20/02/2026) إلى كسرٍ مرسوم على الشاشة.
                          // 🌊 أثناء البثّ: حافةٌ متلاشية ومؤشّرُ كتابة.
                          else
                            StreamingText(
                              streaming: streaming,
                              child: MasarMarkdown(
                                data: m.text,
                                // ⚠️ التحديد يُعطَّل أثناء البثّ: النصّ
                                //    يتغيّر تحت الإصبع فينفكّ ويرتجّ العرض.
                                selectable: !streaming,
                                math: false,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: AppSettings.I.answerFontSize,
                                    fontWeight: FontWeight.w500,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                          if (!isUser && streaming)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: TypingCaret(color: AppColors.primary),
                            ),
                          // 📋 أزرارُ المساعد **داخل فقاعته** — كالتعليم.
                          if (!isUser && !streaming) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _copyButton(m),
                                const SizedBox(width: 8),
                                _saveButton(m),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                // 📋 وزرُّ الطالب **تحت فقاعته** — كالتعليم أيضاً.
                if (isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 6),
                    child: _copyButton(m, dense: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// صور الرسالة — **فوق** الفقاعة كما في قسم التعليم.
  /// ⚠️ الصورة على الجهاز وحده: جهازٌ جديد أو إعادة تثبيت ⇒ الملف غير موجود،
  ///    فنعرض بديلاً صريحاً بدل أيقونة عطل ([27§3]).
  Widget _bubbleImages(List<String> paths) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: paths.map((path) {
          final file = File(path);
          final index = paths.indexOf(path);
          return GestureDetector(
            // 🔍 الضغط يفتح العارض: تكبير · تقليب بين الصورتين · ملء الشاشة.
            onTap: file.existsSync()
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ImageViewerScreen(
                              paths: paths, initialIndex: index)),
                    )
                : null,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: file.existsSync()
                ? Image.file(file, width: 132, height: 132, fit: BoxFit.cover)
                : Container(
                    width: 132,
                    height: 132,
                    color: AppColors.softSurface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text("الصورة لم تعد متاحة",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
          ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════ الأسفل ══════════════

  /// شريط المرفقات قبل الإرسال — بمعاينة وزر حذف لكل صورة.
  Widget _attachmentStrip() {
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        itemCount: _c.attachedImages.length,
        itemBuilder: (_, i) {
          final img = _c.attachedImages[i];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  // ✂️ الضغط يفتح المحرّر: قص + رسم لتحديد موضع السؤال.
                  onTap: () => _editImage(i, img),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(img.path),
                        width: 66, height: 66, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: -6,
                  left: -6,
                  child: InkWell(
                    onTap: () => _c.removeAttachedImage(i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surfaceWhite, width: 1.5)),
                      child: Icon(PI.x.regular,
                          size: 13, color: AppColors.surfaceWhite),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 🎤 بدء التسجيل.
  Future<void> _startVoice() async {
    final error = await _c.startVoiceRecording();
    if (error != null && mounted) _snack(error);
  }

  /// ⏹️ إنهاء → تنظيف → النص في الحقل **ليراجعه الطالب** قبل الإرسال.
  Future<void> _voiceToText() async {
    final text = await _c.stopVoiceToText();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      _snack("🎤 لم أسمع شيئاً — حاول مجدداً");
      return;
    }
    // ⭐ يُضاف لما في الحقل لا يستبدله — الطالب قد يكمل تسجيلاً بعد تسجيل.
    final merged = appendVoiceText(_input.text, text);
    _input.text = merged;
    _input.selection = TextSelection.collapsed(offset: merged.length);
  }

  /// ➤ إنهاء → تنظيف → **إرسال مباشر** بلا مراجعة.
  Future<void> _voiceAndSend() async {
    final text = await _c.stopVoiceToText();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      _snack("🎤 لم أسمع شيئاً — حاول مجدداً");
      return;
    }
    // ★ يرسل ما في الحقل **مع** ما سُجّل — لا يتجاهل ما كتبه الطالب قبله.
    final merged = appendVoiceText(_input.text, text);
    _input.clear();
    await _c.send(merged);
  }

  /// ✂️ يفتح محرّر الصورة (قص + رسم) ويستبدل المرفق بالنتيجة.
  Future<void> _editImage(int index, PickedImage img) async {
    final edited = await Navigator.push<PickedImage>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditorScreen(image: img)),
    );
    if (edited != null && mounted) _c.replaceImage(index, edited);
  }

  /// اختيار مصدر الصورة — كاميرا أو معرض.
  Future<void> _pickImage() async {
    if (!_c.canAttachMore) {
      _snack("📷 الحد الأقصى ${ScholarshipChatController.maxImages} صور");
      return;
    }
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(PI.camera.regular, color: AppColors.primary),
              title: Text("التقاط صورة",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: Icon(PI.images.regular, color: AppColors.secondary),
              title: Text("من المعرض",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (fromCamera == null) return;
    final error = await _c.attachImage(fromCamera: fromCamera);
    if (error != null && mounted) _snack(error);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: AppColors.secondary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _noticeBar(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(SchMetrics.margin, 0, SchMetrics.margin, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.schRedFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.schRedInk)),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.schRedInk)),
    );
  }

  /// 🧭 أبوابُ المنحة — زرٌّ لكل ما تجيبه بطاقتُها فوراً.
  ///
  /// 🔴 **كانت أربعةً مكتوبةً هنا** لا صلةَ لها ببيانات المنحة: فيها «كيف
  ///    أكتب خطاب الدافع؟» (سؤالُ موديلٍ لا بطاقة) وليس فيها المزايا ولا
  ///    التخصصات ولا المراحل. فصارت [Scholarship.doors] — يحسبها الخادم،
  ///    ولا يظهر بابٌ لمنحةٍ لا تملك بياناتِه.
  ///
  /// 📐 وشكلُها من `05-الرفيق الذاكي`: شرائحُ 27 · r14 · تعبئة `#F8FAFC`
  ///    وحدٌّ `#E7ECF2` — والأولى منها (أقربُ سؤالٍ لليمين) بحدّ الهوية.
  Widget _quickPrompts(Scholarship s) {
    final doors = s.doors;
    if (doors.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 27,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SchMetrics.margin),
        itemCount: doors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = doors[i];
          final first = i == 0;
          return Material(
            color: AppColors.quizChipFill,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              // 🏷️ الزرُّ يحمل **اسمَ الباب** لا نصَّ السؤال: أقصرُ فيتّسع
              //    الشريطُ لتسعةِ أبوابٍ بدل أربعة، والمُرسَل هو السؤالُ
              //    الكامل الذي يفهمه الخادم.
              onTap: () => _send(d.question),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: first
                          ? AppColors.primary
                          : AppColors.quizChipBorder),
                ),
                child: Text(d.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: first ? AppColors.primary : AppColors.chipInk)),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ⌨️ **شريطُ الكتابة نسخةٌ من قسم التعليم** (أمرُ المالك 2026-09-21:
  ///    «الأزرار اللي تحت… نفس حق التعليم بالضبط») — وهو نفسُه ما رسمه
  ///    المصمّم في `05-الرفيق الذاكي`: شريطٌ أبيضُ 56 · r24 · حدٌّ
  ///    `#CAD5E2`، الكاميرا يميناً ثم الحقل ثم المايك ثم دائرةُ إرسالٍ 42.
  ///
  /// 🎨 والمعطَّلُ **40% من لون الإرسال** لا رماديّ — كما في التعليم:
  ///    قِيس `#A1BEFE` فكان `#155DFC` بشفافية 0.4 فوق الأبيض بالضبط.
  Widget _inputBar() {
    final bool canSend =
        (_input.text.trim().isNotEmpty || _c.hasAttachments) && !_c.isBusy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.inputBarBorder),
            boxShadow: AppColors.bubbleShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 📷 الكاميرا — تختفي عند بلوغ الحدّ الأقصى للمرفقات،
              //    كما في التعليم حرفياً.
              if (!_c.isBusy && _c.canAttachMore)
                _roundIcon(
                  icon: PI.camera,
                  size: 36,
                  color: _c.hasAttachments
                      ? AppColors.primary
                      : AppColors.inputBarIcon,
                  onTap: _pickImage,
                )
              else
                const SizedBox(width: 36),
              Expanded(
                child: TextField(
                  controller: _input,
                  // ⌨️ يبقى مفتوحاً أثناء البثّ: الطالب يُحضّر سؤاله
                  //    التالي وهو يقرأ. المنعُ على **الإرسال** وحده.
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (canSend) _send();
                  },
                  // 🔠 مقاسُ الشريطين واحد ([kInputFontSize]) — ١٦ كتعليمٍ.
                  style: TextStyle(
                      fontSize: kInputFontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inputBarText),
                  decoration: InputDecoration(
                    isDense: true,
                    // ⚠️ **الأربعةُ جميعاً بعد `filled`.** سمةُ التطبيق
                    //    العامّة تملأ الحقل وتعطيه إطاراً مستديراً، فيظهر
                    //    **مربّعٌ داخل مربّع** داخل الشريط الأبيض.
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: _c.isCleaningVoice
                        ? "✨ جارٍ ترتيب النص..."
                        : _c.hasAttachments
                            ? "اكتب سؤالك عن الصورة (اختياري)..."
                            : "اسأل عن المنحة...",
                    hintStyle: TextStyle(
                        fontSize: kInputFontSize,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inputBarIcon),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: kInputVPad),
                  ),
                ),
              ),
              // 🎤 المايك — نفس تدفّق التعليم: تسجيل ← تنظيف ← مراجعة.
              if (!_c.isBusy)
                _c.isCleaningVoice
                    ? SizedBox(
                        width: 36,
                        height: kInputSideBox,   // 📐 كالكاميرا تماماً
                        child: Center(
                          child: SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary)),
                          ),
                        ),
                      )
                    : _roundIcon(
                        icon: PI.microphone,
                        size: 36,
                        color: AppColors.inputBarIcon,
                        onTap: _startVoice,
                      ),
              const SizedBox(width: 2),
              // 🚀 الإرسال — دائرةٌ 42، وتصير حمراء للإيقاف.
              //    ⚠️ الإيقاف يقطع الاتصال فعلاً (لا يتجاهل الرد فقط)، وإلا
              //       بقي الطلب معلّقاً على الخادم واستهلك نداء موديل كاملاً.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  // 🛑 أثناء البثّ أيضاً — لا في لحظة الانتظار وحدها.
                  onTap: () {
                    if (_c.isBusy) {
                      _c.stop();
                    } else if (canSend) {
                      _send();
                    } else {
                      _snack("✍️ اكتب سؤالك أولاً أو أرفق صورة");
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _c.isBusy
                          ? AppColors.error500
                          : AppColors.sendButton
                              .withValues(alpha: canSend ? 1 : 0.4),
                      shape: BoxShape.circle,
                    ),
                    // ↔️ **يشير يساراً.** خطُّ Phosphor لا يُعكس مع الاتجاه،
                    //    والطائرةُ في التصميم تطير نحو يسار الشاشة.
                    child: Transform.scale(
                      scaleX: _c.isBusy ? 1 : -1,
                      child: Icon(
                          _c.isBusy
                              ? PI.stopCircle.fill
                              : PI.paperPlaneRight.fill,
                          color: Colors.white,
                          size: 21),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📐 **ارتفاعُ الصندوق [kInputSideBox] لا [size].** الصفُّ محاذىً من
  ///    الأسفل كي تبقى الأيقونات عند السطر الأخير حين يكبر الحقل — وصندوقٌ
  ///    36 مركزُه على بُعد 18 من القاع بينما دائرةُ الإرسال 42 مركزُها 21
  ///    ومركزُ السطر ≈20.5، فتظهر الكاميرا والمايك **أخفضَ من الكلام
  ///    بثلاث بكسلات** (علّةُ المالك 2026-09-21). فنُساوي الصندوقَ بالدائرة:
  ///    المراكزُ الثلاثة على خطٍّ واحد، والأيقونةُ نفسُها 20 كما هي.
  Widget _roundIcon({
    required PIcon icon,
    required VoidCallback? onTap,
    required Color color,
    double size = 36,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: kInputSideBox,
            child: Icon(icon.regular, size: 20, color: color),
          ),
        ),
      );
}

/// يُستعمل من الدرج لعرض «زائر» بلا استيراد إضافي هناك.
bool get isGuestSession => UserSession.I.isGuest;
