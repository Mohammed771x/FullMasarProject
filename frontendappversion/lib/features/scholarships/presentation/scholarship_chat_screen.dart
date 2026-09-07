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
import '../../../core/widgets/masar_markdown.dart';
import '../../../core/widgets/voice_recording_bar.dart';
import '../../../core/widgets/typing_indicator.dart';
import '../data/models/scholarship.dart';
import '../data/models/scholarship_chat.dart';
import '../../../core/session/user_session.dart';
import 'controllers/scholarship_chat_controller.dart';
import 'widgets/scholarship_chat_drawer.dart';

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
    _scrollToEnd();
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
      body: Column(
        children: [
          _appBar(context, s),
          Expanded(child: _c.isEmpty ? _intro(s) : _list()),
          if (_c.notice != null) _noticeBar(_c.notice!),
          if (_c.isEmpty && !_c.hasAttachments) _quickPrompts(s),
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
    );
  }

  // ══════════════ الرأس ══════════════

  Widget _appBar(BuildContext context, Scholarship s) {
    final count = _c.history.length;
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10, bottom: 12, left: 14, right: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: s.colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
        boxShadow: [
          BoxShadow(
              color: s.colors.last.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
          const SizedBox(width: 10),
          Text(s.badge, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("مساعد ${s.name}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text(_c.isSending ? "يكتب الآن..." : s.statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88))),
              ],
            ),
          ),
          _iconBtn(Icons.add_comment_rounded, () {
            _c.newChat();
            _input.clear();
          }, tooltip: "محادثة جديدة"),
          const SizedBox(width: 8),
          // 📂 السجلّ — بشارة العدد كي يعرف الطالب أن له محادثات سابقة.
          Stack(
            clipBehavior: Clip.none,
            children: [
              _iconBtn(Icons.forum_rounded,
                  () => _scaffold.currentState?.openDrawer(),
                  tooltip: "محادثاتي"),
              if (count > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(9)),
                    child: Text("$count",
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: s.colors.last)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final btn = InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: Colors.white, size: 20)),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }

  // ══════════════ الرسائل ══════════════

  /// شاشة البدء: ترحيب ثابت **بلا نداء موديل** — لا نصرف من حصة الطالب
  /// على جملة يمكن كتابتها في الكود.
  Widget _intro(Scholarship s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
      children: [
        Center(child: Text(s.badge, style: const TextStyle(fontSize: 54))),
        const SizedBox(height: 16),
        Text("أهلاً! أنا مساعد ${s.name} 😊",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Text(
          "اسألني عن الشروط، المواعيد، الوثائق المطلوبة، أو طريقة التقديم.\n"
          "أجيب من بيانات هذه المنحة — وما لا أعرفه أقول لك إني لا أعرفه.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12.5,
              height: 1.9,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _list() {
    final msgs = _c.messages;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      itemCount: msgs.length + (_c.isSending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= msgs.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 10),
            child: Align(alignment: Alignment.centerRight, child: TypingIndicator()),
          );
        }
        return _bubble(msgs[i]);
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

  /// ⭐ حفظ رد المساعد في المحفوظات — نفس زر قسم التعليم.
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(saved ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 13,
                color: saved ? Colors.amber.shade700 : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(saved ? "محفوظة" : "حفظ",
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: saved
                        ? Colors.amber.shade800
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _copyButton(SchMessage m) {
    final copied = _copiedAt == m.timestamp;
    return InkWell(
      onTap: () => _copy(m),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(copied ? Icons.check_rounded : Icons.content_copy_rounded,
                size: 13,
                color: copied ? Colors.green : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(copied ? "تم النسخ" : "نسخ",
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: copied ? Colors.green : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _bubble(SchMessage m) {
    final isUser = m.isUser;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        // ⚠️ التطبيق RTL: `start` = يمين الشاشة و`end` = يسارها — نفس منطق
        //    قسم التعليم، فتلتصق الفقاعة بحافة صورها لا تنزاح عنها.
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 📷 الصور **فوق** الفقاعة لا داخلها — كما في قسم التعليم تماماً.
          if (m.hasImages)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _bubbleImages(m.imagePaths),
            ),

          if (m.text.isNotEmpty)
            GestureDetector(
              onLongPress: () => _copy(m),
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isUser ? AppColors.bubbleGradient : null,
                  color: isUser ? null : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 6 : 20),
                    bottomRight: Radius.circular(isUser ? 20 : 6),
                  ),
                  boxShadow: AppColors.bubbleShadow,
                ),
                child: isUser
                    ? Text(m.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.7,
                            fontWeight: FontWeight.w600))
                    // 🚫 بلا رسّام رياضيات: المنح لا رياضيات فيها، ورفعُ
                    //    «رقم/رقم» إلى كسر يحوّل تاريخاً (20/02/2026) إلى
                    //    كسرٍ مرسوم على شاشة الطالب.
                    : MasarMarkdown(
                        data: m.text,
                        selectable: true,
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
            ),

          // 📋 النسخ **على يمين الفقاعة دائماً** — للطالب وللمساعد سواء.
          //    كان يتبع جهة الفقاعة فيقفز يميناً ويساراً بين الرسائل.
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[_saveButton(m), const SizedBox(width: 4)],
                  _copyButton(m),
                ],
              ),
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
                      child: Icon(Icons.close_rounded,
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
              leading: Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: Text("التقاط صورة",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppColors.secondary),
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
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25))),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary)),
    );
  }

  /// أسئلة جاهزة — تُعرض قبل أول سؤال فقط، ثم تختفي فلا تزاحم المحادثة.
  Widget _quickPrompts(Scholarship s) {
    final prompts = [
      "ما شروط التقديم؟",
      "ما الوثائق المطلوبة؟",
      if (s.closeDate != null) "متى آخر موعد للتقديم؟" else "متى يفتح التقديم؟",
      "كيف أكتب خطاب الدافع؟",
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: prompts
            .map((p) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    label: Text(p,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    backgroundColor: AppColors.surfaceWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    onPressed: () => _send(p),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          boxShadow: AppColors.bubbleShadow,
        ),
        child: Row(
          children: [
            // 🎤 المايك — نفس تدفّق التعليم: تسجيل ← تنظيف ← مراجعة ([23])
            InkWell(
                onTap: _c.isSending ? null : _startVoice,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _c.isRecording
                        ? Colors.redAccent.withValues(alpha: 0.14)
                        : AppColors.softSurface,
                    shape: BoxShape.circle,
                  ),
                  child: _c.isCleaningVoice
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : Icon(
                          _c.isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: 21,
                          color: _c.isRecording
                              ? Colors.redAccent
                              : AppColors.primary),
                ),
              ),
            const SizedBox(width: 8),
            // 📷 إرفاق صورة — لقطة من موقع المنحة أو وثيقة يسأل عنها
            InkWell(
              onTap: _c.isSending ? null : _pickImage,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: AppColors.softSurface, shape: BoxShape.circle),
                child: Icon(Icons.add_photo_alternate_rounded,
                    size: 21,
                    color: _c.canAttachMore
                        ? AppColors.primary
                        : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(22)),
                child: TextField(
                  controller: _input,
                  enabled: !_c.isSending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: _c.hasAttachments
                        ? "اكتب سؤالك عن الصورة (اختياري)..."
                        : "اسأل عن المنحة...",
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ➤ / ⏹️ — الزر نفسه يصير إيقافاً أثناء الانتظار.
            //    ⚠️ الإيقاف يقطع الاتصال فعلاً (لا يتجاهل الرد فقط)، وإلا
            //       بقي الطلب معلّقاً على الخادم واستهلك نداء موديل كاملاً.
            InkWell(
              onTap: _c.isSending ? _c.stop : _send,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: _c.isSending ? null : AppColors.mainGradient,
                  color: _c.isSending ? Colors.redAccent : null,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.softShadow,
                ),
                child: Icon(
                    _c.isSending ? Icons.stop_rounded : Icons.send_rounded,
                    color: Colors.white,
                    size: _c.isSending ? 22 : 21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// يُستعمل من الدرج لعرض «زائر» بلا استيراد إضافي هناك.
bool get isGuestSession => UserSession.I.isGuest;
