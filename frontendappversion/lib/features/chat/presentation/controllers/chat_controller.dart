import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/config/curriculum.dart';
import '../../../../core/services/image_service.dart';
import '../../../../core/services/stt_service.dart';
import '../../../../core/services/voice_text_merge.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/sync/sync_service.dart';
import '../../data/models/ask_response.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/subject_capabilities.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/tutor_content_repository.dart';
import '../../../teacher/data/teacher_tool.dart';

// ==========================================
// 🧠 متحكّم شاشة المحادثة
// ==========================================
// يحمل كامل حالة الشاشة ومنطقها (نفس منطق _MainChatScreenState الأصلي حرفياً)،
// بينما تبقى آثار الواجهة (Snackbars / Dialogs / الأنيميشن) في طبقة الويدجت
// عبر دوال رد النداء (callbacks) أدناه — فصلٌ نظيف دون أي تغيير في السلوك.
class ChatController extends ChangeNotifier {
  ChatController({
    ChatRepository? chatRepository,
    TutorContentRepository? contentRepository,
  })  : _chat = chatRepository ?? ChatRepository(),
        _content = contentRepository ?? TutorContentRepository();

  final ChatRepository _chat;
  final TutorContentRepository _content;

  // ===== آثار الواجهة (تُوصَل من الشاشة) =====
  void Function(String message)? onShowDataError; // بديل _showDataErrorSnackBar
  VoidCallback? onShowStopConfirmation; // "تم إيقاف الإجابة"
  VoidCallback? onShowBusyWarning; // "يرجى انتظار الرد الحالي"
  VoidCallback? onFadeReplay; // إعادة تشغيل أنيميشن التلاشي
  void Function(String subject)? onRequestInstructions; // عرض التعليمات
  /// 🎟️ انتهت الحصة — الواجهة تعرض دعوة للتسجيل (للزائر) أو موعد التجديد.
  void Function(bool isGuest)? onQuotaExceeded;

  // ===== Controllers مملوكة للمتحكّم =====
  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final TextEditingController questionCountController = TextEditingController(text: "10");
  final TextEditingController arabicQuestionCountController = TextEditingController(text: "5");
  final TextEditingController englishQuestionCountController = TextEditingController(text: "5");

  // ✅ مراقب لإيقاف أنيميشن الكتابة فوراً
  final ValueNotifier<bool> stopTypingNotifier = ValueNotifier(false);

  // ===== الحالة (نفس متغيرات الكود الأصلي) =====
  final String userId = const Uuid().v4();
  final Map<String, List<Map<String, dynamic>>> _allChatsHistory = {};

  String _deviceId = "";
  bool _disposed = false;

  String? currentConversationId;
  List<ChatConversation> conversations = [];
  String selectedMathBranch = "";
  String mathMode = "";

  // 🟢 متغيرات العربي الوزاري
  String selectedArabicExamYear = "";
  String selectedArabicExamSection = "";
  String selectedArabicExamType = "";
  final List<String> arabicExamSections = AppConstants.arabicExamSections;
  final List<String> arabicExamTypes = AppConstants.arabicExamTypes;

  // 🟢 متغيرات الإنجليزي الوزاري
  String selectedEnglishExamYear = "";
  String selectedEnglishQuestionType = "";
  List<String> englishQuestionTypes = [];

  List<String> mathLessons = [];
  List<String> mathExamYears = [];
  List<String> mathExamLessons = [];
  String selectedMathExamYear = "";
  String selectedMathExamLesson = "";
  String selectedLesson = "";
  List<String> availableUnits = [];
  String selectedUnit = "الكل";
  final List<String> mathBranches = AppConstants.mathBranches;
  String selectedExamYear = "";
  // ===== الصف والمسار (يأتيان من حساب الطالب ويُغيَّران من القائمة الجانبية) =====
  int grade = 3;
  Track track = Track.scientific;

  String selectedSubject = "احياء";
  String selectedMode = "شرح";

  // ═════════════════ 👨‍🏫 وضع المعلم ═════════════════
  // ⭐ **لماذا داخل هذا المتحكّم لا في متحكّم ثانٍ؟** طلب المالك أن يكون قسم
  //    المعلم «مطابقاً تماماً لقسم التعليم» في المحادثة: الصور والصوت والنسخ
  //    والإيقاف وسجلّ المحادثات والسياق. ونسخةٌ ثانية من ١٢٠٠ سطر تعني
  //    ميزةً تُصلَح هنا وتبقى مكسورة هناك. فالمطابقة هنا **بنيوية** لا منقولة:
  //    ما يعمل للطالب يعمل للمعلّم بالبناء نفسه.
  //
  // 🔒 وكل سطرٍ يخصّ المعلم محروسٌ بـ`isTeacher`، فمسار الطالب لا يتغيّر.
  TeacherTool? teacherTool;

  /// حقل «المفهوم» في أداة التبسيط (نظيره `inputController` في الشات).
  final TextEditingController conceptController = TextEditingController();
  String teacherDifficulty = "متوسط";
  int teacherCount = 10;

  bool get isTeacher => teacherTool != null;

  /// ⭐ **الدروس وحدها**: قرار المالك «محتوى الوحدات لا يأخذه أبداً».
  ///    فوضع الصفحات لا يُعرض ولا يُرسل في هذا القسم إطلاقاً.
  bool get teacherLessonReady => selectedV3Lesson.isNotEmpty;

  /// 📖 هل يكفي الضغط على «إرسال» بلا كتابة؟
  ///
  /// 🔴 **علّة مرصودة (2026-09-04):** لوحة الإعدادات تَعِد الطالب صراحةً
  ///    «✅ اضغط إرسال مباشرة لشرح الدرس كاملاً»، و`processRequest` تدعمها
  ///    فعلاً — لكن زرّ الإرسال كان مشروطاً بنصٍّ مكتوب وحده، فالوعد لا
  ///    يتحقّق والزرّ يبقى رمادياً. المنطق موجود، والبوّابة وحدها كانت مغلقة.
  bool get canSendWithoutText =>
      !isTeacher && effectiveContentMode == "lessons" && selectedV3Lesson.isNotEmpty;

  /// هل الأداة جاهزة للتوليد؟ (الدرس + ما تطلبه الأداة من حقول)
  bool get canGenerateTeacher {
    final t = teacherTool;
    if (t == null || !t.hasGenerate || isLoading) return false;
    if (t.requiresLesson && !teacherLessonReady) return false;
    if (t == TeacherTool.simplify && conceptController.text.trim().isEmpty) return false;
    return true;
  }

  // ===== 🆕 مصدر المحتوى (وضع الدروس / وضع الوحدات) =====
  // "lessons" = الطالب يختار وحدة ثم درساً والدرس يُرسل كاملاً (بلا embeddings)
  // "pages"   = نمط الأحياء: صفحة/برومت داخل وحدة (بالـ embeddings)
  // الرياضيات مستثناة: تبقى على تدفقها الأصلي دائماً.
  String contentMode = "pages";
  SubjectCapabilities? caps;
  bool capsLoading = false;
  String selectedV3Unit = "";     // وحدة وضع الدروس
  String selectedV3Lesson = "";   // درس وضع الدروس

  /// هل تظهر واجهة الوضعين؟ (لكل المواد عدا الرياضيات، وليس في الوزاري)
  /// 👨‍🏫 وقسم المعلم **خارجها كلياً**: لا اختيار بين دروس وصفحات — الدروس فقط.
  bool get usesContentModes =>
      !isTeacher && selectedSubject != "رياضيات" && selectedMode != "وزاري";

  /// القيمة المُرسلة للخادم — null يعني «المسار القديم كما هو».
  String? get effectiveContentMode => usesContentModes ? contentMode : null;

  String inputType = "برومت";
  int summaryLevel = 3;
  String selectedUnitName = "الكل";
  bool isLoading = false;
  bool sessionActive = false;
  /// جاري جلب سنوات الوزاري — تميّز «لم تصل بعد» عن «لا يوجد بنك لهذا الصف».
  bool yearsLoading = false;
  bool mathWazariQuestionsLoaded = false;
  List<Map<String, dynamic>> messages = [];
  List<String> availableYears = [];

  /// مواد الصف/المسار الحالي — تتغيّر مع تغيّر أي منهما.
  List<String> get subjects => Curriculum.subjectsFor(grade, track);

  /// هل محتوى المادة الحالية متاح على الخادم؟
  bool get isCurrentSubjectAvailable => Curriculum.isAvailable(grade, track, selectedSubject);

  String get gradeLabel => Curriculum.gradeLabel(grade);
  String get trackLabel => track.label;

  bool _isResponseCancelled = false;
  bool isMathExplanationStarted = false;

  // UI State
  bool showSettingsPanel = true;

  // ===== التهيئة =====
  /// [openSubject] و[openLesson] وأخواتها: فتحٌ موجَّه من خارج الشات —
  /// مثل «اشرح لي 📚» في نتيجة الاختبار، فيصل الطالب إلى **درسه الضعيف**
  /// مباشرةً بلا بحث يدوي ([31§7]).
  Future<void> init({
    String? openSubject,
    String? openUnit,
    String? openLesson,
    String? openMode,
    TeacherTool? teacher,
  }) async {
    teacherTool = teacher;
    if (teacher != null) contentMode = "lessons";
    _deviceId = await SecureStorage.getOrCreateDeviceId();

    // الصف والمسار من حساب الطالب (يُختاران عند إنشاء الحساب ويُعدَّلان من الإعدادات).
    grade = UserSession.I.grade;
    track = Curriculum.normalizeTrack(grade, TrackLabel.fromKey(UserSession.I.track));
    selectedSubject = Curriculum.defaultSubject(grade, track);
    if (openSubject != null && Curriculum.subjectsFor(grade, track).contains(openSubject)) {
      selectedSubject = openSubject;
    }
    _resetModeForSubject();
    if (openMode != null && openMode.isNotEmpty) selectedMode = openMode;

    loadConversations();
    // 🔄 محادثات وصلت من السحابة (جهاز جديد أو زر الاستعادة) ⇒ حدّث القائمة.
    SyncService.I.revision.addListener(_onRemoteConversations);
    createNewConversation();
    await loadCapabilities();
    if (!isTeacher) await loadAvailableUnits();   // 👨‍🏫 الدروس وحدها

    // بعد وصول القدرات: نُثبّت الوحدة والدرس المطلوبين.
    //
    // ⚠️ الرياضيات **خارج شرط القدرات عمداً**: `loadCapabilities()` تخرج
    //    مبكراً للرياضيات وتضع `caps = null` (دروسها من `/math/lessons` لا
    //    من القدرات). فكلُّ ما يُعشَّش تحت `caps?.lessonsAvailable` لا يُنفَّذ
    //    لها إطلاقاً — وهنا كان مقتل الفتح الموجَّه.
    if (openLesson != null && openLesson.isNotEmpty) {
      if (selectedSubject == "رياضيات") {
        await applyMathDeepLink(openUnit ?? "", openLesson);
      } else if (caps?.lessonsAvailable == true && caps!.lessonsUnits.isNotEmpty) {
        contentMode = "lessons";
        final unit = resolveLessonUnit(caps!, openUnit, openLesson);
        selectedV3Unit = unit;
        if (caps!.lessonsIn(unit).contains(openLesson)) {
          selectedV3Lesson = openLesson;
        }
      }
      _safeNotify();
    }
  }

  /// يُثبّت فرع الرياضيات ودرسه للفتح الموجَّه من التحليل/نتيجة الاختبار.
  ///
  /// للرياضيات آلة حالة منفصلة تماماً: `selectedMathBranch` + `selectedLesson`
  /// + `mathMode` — ولا تقرأ `selectedV3Lesson` إطلاقاً. فبدون هذه الدالة يصل
  /// الطالب «وضع الشرح» ويقف بلا درس مختار.
  ///
  /// [unit] هو المرشّح الأول (وهو فرعٌ صحيح عادةً لأن الاختبار بُني من
  /// القدرات)، وإن لم يُطابق مُسحت بقية الفروع — فاسمُ الدرس لا يتكرّر بينها.
  /// وحدةُ درسٍ للفتح الموجَّه — **الوحدة التي تحويه فعلاً**.
  ///
  /// ⚠️ لا يُوثَق بالوحدة القادمة مع النتيجة: **اختبار المراجعة يجمع دروساً من
  ///    وحدات مختلفة** (قرار المالك)، والنتيجة تُختم بوحدة **أول درس مختار**
  ///    وحدها — فأخطاء الدروس الأخرى تحمل وحدةً ليست وحدتها. وكان الكود يقبل
  ///    تلك الوحدة لمجرّد أنها وحدةٌ صالحة، ثم يفشل شرطُ احتوائها للدرس، فيصل
  ///    الطالب وضع الدروس **بلا درس مختار** — العطل نفسه الذي أصاب الرياضيات،
  ///    بسببٍ آخر.
  ///
  /// فالقاعدة: تُقبل [openUnit] **فقط إن كانت تحوي الدرس**، وإلا يُبحث عنه.
  @visibleForTesting
  static String resolveLessonUnit(
      SubjectCapabilities caps, String? openUnit, String lesson) {
    if (openUnit != null && caps.lessonsIn(openUnit).contains(lesson)) {
      return openUnit;
    }
    for (final u in caps.lessonsUnits) {
      if (u.lessons.contains(lesson)) return u.unit;
    }
    // درسٌ لا وجود له في القدرات ⇒ لا نخترع وحدة: نُبقي القادمة إن صحّت.
    if (openUnit != null && caps.lessonsUnits.any((u) => u.unit == openUnit)) {
      return openUnit;
    }
    return caps.lessonsUnits.isEmpty ? "" : caps.lessonsUnits.first.unit;
  }

  @visibleForTesting
  Future<void> applyMathDeepLink(String unit, String lesson) async {
    mathMode = "شرح";
    final candidates = [
      if (mathBranches.contains(unit)) unit,
      ...mathBranches.where((b) => b != unit),
    ];
    for (final branch in candidates) {
      await loadMathLessons(branch);
      if (mathLessons.contains(lesson)) {
        selectedMathBranch = branch;
        selectedLesson = lesson;
        return;
      }
    }
    // لم يُطابق أي فرع ⇒ لا نترك فرعاً مختاراً بلا درس: تُعرض القائمة صريحةً.
    selectedMathBranch = "";
    selectedLesson = "";
    mathLessons = [];
  }

  // ========== تبديل الصف / المسار / المادة ==========

  /// يغيّر الصف: يصحّح المسار، يعيد بناء قائمة المواد، ويبدّل سجلّ المحادثات كاملاً.
  Future<void> setGrade(int g) async {
    if (g == grade) return;
    grade = g;
    track = Curriculum.normalizeTrack(grade, track);
    await UserSession.I.updateProfile(grade_: g, track_: track.key);
    await _onScopeChanged();
  }

  /// يغيّر المسار (علمي/أدبي) — متاح للصفين الثاني والثالث فقط.
  Future<void> setTrack(Track t) async {
    if (!Curriculum.hasTracks(grade) || t == track) return;
    track = t;
    await UserSession.I.updateProfile(track_: t.key);
    await _onScopeChanged();
  }

  /// يغيّر المادة داخل نفس الصف/المسار.
  Future<void> setSubject(String subject) async {
    if (subject == selectedSubject) return;
    selectedSubject = subject;
    await _onScopeChanged(keepSubject: true);
  }

  /// كل ما يجب أن يحدث عند تغيّر النطاق (صف/مسار/مادة).
  Future<void> _onScopeChanged({bool keepSubject = false}) async {
    if (!keepSubject || !subjects.contains(selectedSubject)) {
      selectedSubject = Curriculum.defaultSubject(grade, track);
    }
    selectedUnit = "الكل";
    selectedUnitName = "الكل";
    availableUnits = [];
    availableYears = [];
    selectedExamYear = "";
    sessionActive = false;
    _resetModeForSubject();

    caps = null;
    selectedV3Unit = "";
    selectedV3Lesson = "";
    // 👨‍🏫 الدروس وحدها في قسم المعلم — تبديل المادة لا يعيده لوضع الصفحات.
    contentMode = isTeacher ? "lessons" : "pages";

    loadConversations();     // ← سجلّ محادثات النطاق الجديد
    createNewConversation();
    _safeNotify();

    await loadCapabilities();
    // 👨‍🏫 وحدات وضع الصفحات لا يقرؤها المعلم إطلاقاً — فلا نطلبها له.
    if (!isTeacher && isCurrentSubjectAvailable) {
      await loadAvailableUnits();
    }
  }

  void _resetModeForSubject() {
    inputType = "برومت";
    selectedLesson = "";
    // 👨‍🏫 «الوضع» في قسم المعلم هو الأداة نفسها — وعليه يُبنى مفتاح نطاق
    //    المحادثات، فسجلّ «خطة الدرس» لا يختلط بسجلّ «الواجب» ولا بسجلّ الطالب.
    if (isTeacher) {
      selectedMode = "معلم:${teacherTool!.id}";
      return;
    }
    if (selectedSubject == "رياضيات") {
      selectedMathBranch = "";
      mathMode = "شرح";
      selectedMode = "شرح";
      mathLessons = [];
    } else {
      selectedMode = "شرح";
    }
  }

  // ===== 📷 الصور المرفقة (حتى صورتين) =====
  // تُحفظ على جهاز الطالب فقط. تُرسل base64 مرة واحدة مع الطلب،
  // والخادم يستخرج نصها بجيميناي ثم يتجاهلها (لا تخزين ولا تسجيل).
  static const int maxImages = 2;
  final List<PickedImage> attachedImages = [];

  bool get canAttachMore => attachedImages.length < maxImages;

  Future<void> attachImage({required bool fromCamera}) async {
    if (isLoading) {
      onShowBusyWarning?.call();
      return;
    }
    if (!canAttachMore) {
      onVoiceNotice?.call("📷 الحد الأقصى $maxImages صور");
      return;
    }
    try {
      final picked = await ImageService.I.pick(fromCamera: fromCamera);
      if (picked == null) return; // ألغى الطالب
      attachedImages.add(picked);
      _safeNotify();
    } on ImageException catch (e) {
      onVoiceNotice?.call(e.message);
    } catch (_) {
      onVoiceNotice?.call("📷 تعذّر فتح الصورة.");
    }
  }

  /// استبدال صورة بعد تعديلها (قص/رسم).
  void replaceImage(int index, PickedImage edited) {
    if (index < 0 || index >= attachedImages.length) return;
    final old = attachedImages[index];
    attachedImages[index] = edited;
    _safeNotify();
    if (old.path != edited.path) ImageService.I.delete(old.path);
  }

  /// إزالة مرفق قبل الإرسال (زر ✕ على المعاينة).
  Future<void> removeAttachedImage(int index) async {
    if (index < 0 || index >= attachedImages.length) return;
    final img = attachedImages.removeAt(index);
    _safeNotify();
    await ImageService.I.delete(img.path);
  }

  // ===== 🎤 التسجيل الصوتي (بنمط ChatGPT) =====
  // شريط موجات مع ثلاثة إجراءات: 🗑️ حذف · ⏹️ إيقاف لنص · ➤ إرسال مباشر.
  // ★ لا يتوقف تلقائياً — الطالب وحده من ينهيه (SttService يعيد تشغيل
  //   جلسة المحرك كلما أنهاها بنفسه، ويراكم النص).
  bool get sttAvailable => SttService.I.isAvailable;
  bool isRecording = false;
  bool isCleaningVoice = false;
  void Function(String message)? onVoiceNotice;

  /// بدء التسجيل (زر المايك).
  Future<void> startVoiceRecording() async {
    if (isRecording) return;
    if (isLoading) {
      onShowBusyWarning?.call();
      return;
    }
    final started = await SttService.I.start();
    if (!started) {
      onVoiceNotice?.call("🎤 التعرف على الكلام غير متاح على هذا الجهاز");
      _safeNotify();
      return;
    }
    isRecording = true;
    _safeNotify();
  }

  /// 🗑️ حذف التسجيل — لا شيء يصل لحقل الكتابة.
  Future<void> deleteVoiceRecording() async {
    if (!isRecording) return;
    await SttService.I.discard();
    isRecording = false;
    _safeNotify();
  }

  /// ⏹️ إيقاف → تنظيف → النص يظهر في الحقل ليراجعه الطالب.
  ///
  /// ⭐ **يُضاف لما في الحقل لا يستبدله:** الطالب يسجّل جملة، يقرأها، ثم
  ///    يضغط المايك ليكمل — فاستبدالُ ما كتبه يمحو كلامه الأول بلا إنذار.
  Future<void> stopVoiceToText() async {
    final text = await _endRecordingAndClean();
    if (text == null) return;
    final merged = appendVoiceText(inputController.text, text);
    inputController.text = merged;
    inputController.selection = TextSelection.collapsed(offset: merged.length);
    _safeNotify();
  }

  /// ➤ إيقاف → تنظيف → إرسال مباشر بلا مراجعة.
  Future<void> stopVoiceAndSend() async {
    final text = await _endRecordingAndClean();
    if (text == null || text.isEmpty) return;
    // ★ يرسل ما في الحقل **مع** ما سُجّل — لا يتجاهل ما كتبه الطالب قبله.
    inputController.text = appendVoiceText(inputController.text, text);
    _safeNotify();
    await processRequest();
  }

  /// ينهي التسجيل ويمرّ بالنص على /voice/clean.
  /// يرجع null إن لم يُلتقط شيء.
  Future<String?> _endRecordingAndClean() async {
    if (!isRecording) return null;
    final raw = await SttService.I.finish();
    isRecording = false;

    if (raw.isEmpty) {
      onVoiceNotice?.call("🎤 لم أسمع شيئاً — حاول مجدداً");
      _safeNotify();
      return null;
    }

    // النص الخام جاهز فوراً؛ التنظيف يحسّنه بعد لحظة
    isCleaningVoice = true;
    _safeNotify();

    final cleaned = await _chat.cleanVoiceText(
      userId: userId,
      code: AppConfig.accessCode,
      subject: selectedSubject,
      deviceId: _deviceId,
      rawText: raw,
    );

    isCleaningVoice = false;
    return cleaned.isEmpty ? raw : cleaned;
  }

  /// 🆕 جلب قدرات المادة (الأوضاع + الشجرة) — استدعاء واحد.
  Future<void> loadCapabilities() async {
    // ⚠️ الرياضيات مستثناة في قسم الطالب (لها تدفّقها الخاص عبر `/math/lessons`)
    //    — أما قسم المعلم فيقرؤها من القدرات كبقية المواد، لأن الخادم يبني لها
    //    شجرة دروس فعلاً (`capabilities.describe`) والمعلّم يحتاج فرعاً ودرساً
    //    كأي مادة. بدون هذا الاستثناء من الاستثناء تصل قائمةُ دروسٍ فارغة.
    if (selectedSubject == "رياضيات" && !isTeacher) {
      caps = null;
      return;
    }
    capsLoading = true;
    _safeNotify();
    try {
      caps = await _content.getCapabilities(selectedSubject, grade, track.key);
      if (isTeacher) {
        // 👨‍🏫 لا مساومة: الدروس أو رسالة «قيد الإضافة». ولا سقوط على الصفحات.
        contentMode = "lessons";
        _resetV3Selection();
        capsLoading = false;
        _safeNotify();
        return;
      }
      // الافتراضي: الدروس إن وُجدت، وإلا الوحدات — وإن غاب الاثنان نبقي
      // الاختيار الحالي والخادم يرد برسالة «قيد الإضافة» الودّية.
      if (caps!.lessonsAvailable && !caps!.pagesAvailable) {
        contentMode = "lessons";
      } else if (caps!.pagesAvailable && !caps!.lessonsAvailable) {
        contentMode = "pages";
      }
      _resetV3Selection();
      _applyPagesUnits();
    } catch (_) {
      caps = null; // فشل الشبكة → الواجهة تُبقي الوضع الحالي بلا انهيار
    }
    capsLoading = false;
    _safeNotify();
  }

  /// 📄 وحدات **وضع الوحدات** — من القدرات وحدها (`pages.units`).
  ///
  /// المصدر واحد عمداً: `/subjects/units` القديم يرجع أول كتابٍ يجده
  /// (`unit_mode` ثم `lessons_mode`)، فمادةٌ بلا وضع وحدات كانت تعرض
  /// **وحدات دروسها** في وضع الوحدات — قائمةٌ لا يخدمها الخادم في هذا الوضع.
  void _applyPagesUnits() {
    availableUnits =
        (caps?.pagesAvailable ?? false) ? ["الكل", ...caps!.pagesUnits] : <String>[];
    if (!availableUnits.contains(selectedUnit)) {
      selectedUnit = "الكل";
      selectedUnitName = "الكل";
    }
  }

  void _resetV3Selection() {
    final units = caps?.lessonsUnits ?? const [];
    selectedV3Unit = units.isNotEmpty ? units.first.unit : "";
    selectedV3Lesson = "";
  }

  /// تبديل مصدر المحتوى من اللوحة.
  void setContentMode(String mode) {
    if (mode == contentMode) return;
    contentMode = mode;
    if (mode == "lessons") _resetV3Selection();
    _safeNotify();
  }

  void setV3Unit(String unit) {
    selectedV3Unit = unit;
    selectedV3Lesson = "";
    _safeNotify();
  }

  void setV3Lesson(String lesson) {
    selectedV3Lesson = lesson;
    _safeNotify();
  }

  List<String> get v3LessonsUnits => (caps?.lessonsUnits ?? const []).map((u) => u.unit).toList();
  List<String> get v3LessonsInSelectedUnit => caps?.lessonsIn(selectedV3Unit) ?? const [];

  /// مفتاح نطاق المحادثات الحالي.
  ///
  /// ⚠️ **قسم المعلم خارج فرع الرياضيات ووضعها**: لولا هذا الحرس لصار مفتاح
  ///    «معلم + رياضيات» هو `…|تفاضل|شرح` — أي **مفتاح الطالب نفسه**، فتظهر
  ///    خطط المعلّم في سجلّ محادثات الطالب والعكس.
  String get currentScopeKey => ChatConversation.buildScopeKey(
        grade: grade,
        track: track.key,
        subject: selectedSubject,
        branch: (!isTeacher && selectedSubject == "رياضيات") ? selectedMathBranch : "",
        mode: (!isTeacher && selectedSubject == "رياضيات") ? mathMode : selectedMode,
      );

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ========== مفتاح المحادثة الحالي ==========
  String getCurrentChatKey() => currentScopeKey;

  // ========== إيقاف الطلب الجاري ==========
  void stopCurrentRequest() {
    bool isAnimating = messages.isNotEmpty && messages.last["animating"] == true;
    if (!isLoading && !isAnimating) return;

    // 1. أوقف الـ HTTP request إذا كان لا يزال يحمل
    _chat.cancel();

    // 2. إطلاق رصاصة الإيقاف للأنيميشن (يوقف عند نفس الحرف)
    stopTypingNotifier.value = true;

    isLoading = false;
    _isResponseCancelled = true;
    _safeNotify();

    // 3. عرض رسالة تأكيد للمستخدم
    onShowStopConfirmation?.call();
  }

  // ========== تحميل صيغ أسئلة الإنجليزي (الوزاري) ==========
  Future<void> loadExamSections(String subject, String year) async {
    try {
      final list = await _content.getExamSections(subject, year, grade, track.key);
      if (_disposed) return;
      if (subject == "انجليزي") {
        englishQuestionTypes = list;
        selectedEnglishQuestionType = "";
      }
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب صيغ الأسئلة من السيرفر.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال أثناء جلب صيغ الأسئلة.");
    }
  }

  // ========== تبديل السياق (تغيير المادة أو الوضع) ==========
  void switchContext(VoidCallback updateSettings) {
    // 1. حفظ المحادثة الحالية قبل الانتقال
    String currentKey = getCurrentChatKey();
    if (messages.isNotEmpty) {
      _allChatsHistory[currentKey] = List.from(messages);
      // ★ حفظ دائم في Hive قبل مغادرة النطاق، وإلا ضاعت المحادثة عند التبديل.
      saveCurrentConversation();
    }

    // 2. تنفيذ التغيير (تغيير المادة أو الوضع)
    updateSettings();

    // ✅ 3. تصفير حالة زر شرح الرياضيات
    isMathExplanationStarted = false;

    // 4. استرجاع المحادثة الجديدة (إن وجدت)
    String newKey = getCurrentChatKey();
    messages = List.from(_allChatsHistory[newKey] ?? []);

    // ★ 4.ب سجلّ محادثات النطاق الجديد + معرّف محادثة جديد إن كانت فارغة.
    //   هذا ما يجعل تبديل الوضع (شرح ← تلخيص) يبدّل قائمة المحادثات كاملةً.
    loadConversations();
    if (messages.isEmpty) {
      currentConversationId = const Uuid().v4();
      sessionActive = false;
    }

    // 5. تأثيرات بصرية
    onFadeReplay?.call();

    // 6. تحميل البيانات المطلوبة للمادة الجديدة
    if (selectedSubject != "رياضيات") {
      if (selectedMode == "وزاري") {
        loadAvailableYears();
      } else {
        loadAvailableUnits();
      }
    }
    // 🔎 «سؤال» و«وزاري» لا تُعرض لهما شريحة صفحة/برومت — فلا نترك «صفحة»
    //    مخبوءةً من وضعٍ سابق، وإلا فُسِّر سؤال الطالب كأرقام صفحات.
    if (selectedMode == "سؤال" || selectedMode == "وزاري") inputType = "برومت";

    if (selectedSubject == "عربي") {
      selectedArabicExamYear = "";
      selectedArabicExamSection = "";
    }

    if (selectedSubject == "انجليزي") {
      selectedEnglishExamYear = "";
      selectedEnglishQuestionType = "";
    }

    _safeNotify();
    onRequestInstructions?.call(selectedSubject);
  }

  // ========== المحادثات (تخزين محلي) ==========
  /// 👤 مالك المحادثات = الحساب الحالي. جوّال بحسابين لا يخلط سجلّيهما.
  String get ownerUid => UserSession.I.uid;

  void _onRemoteConversations() {
    if (_disposed) return;
    loadConversations();
  }

  void loadConversations() {
    // ★ مفلترة بالنطاق (صف + مسار + مادة + فرع + وضع) **وبالمالك**.
    conversations = ChatStorage.getConversationsByScope(currentScopeKey, ownerUid);
    _safeNotify();
  }

  void createNewConversation() {
    currentConversationId = const Uuid().v4();
    messages = [];
    sessionActive = false;
    showSettingsPanel = true;
    _safeNotify();
  }

  /// يحمّل محادثة محفوظة (إغلاق الـ Drawer يتم في طبقة الويدجت).
  void loadConversation(ChatConversation conversation) {
    currentConversationId = conversation.id;
    messages = conversation.messages
        .map((m) => {
              'role': m.role,
              'text': m.text,
              'refs': m.refs,
              'animating': false,
              if (m.allImages.isNotEmpty) 'images': m.allImages,
              // ★ يعود مع المحادثة المستعادة: الصورة قد تكون فُقدت، والنصّ
              //   وحده يُبقي المتابعة مفهومة.
              if (m.imageText.isNotEmpty) 'imageText': m.imageText,
            })
        .toList();
    selectedMode = conversation.mode;
    showSettingsPanel = false;
    _safeNotify();
    ChatStorage.updateLastUsed(conversation.id);
    scrollToBottom();
  }

  Future<void> saveCurrentConversation() async {
    if (currentConversationId == null || messages.isEmpty) return;
    String title = messages.first['text'] ?? 'محادثة جديدة';
    if (title.length > 50) title = '${title.substring(0, 47)}...';
    final chatMessages = messages
        .map((m) => ChatMessage(
              role: m['role'],
              text: m['text'],
              refs: List<String>.from(m['refs'] ?? []),
              imagePaths: List<String>.from(m['images'] ?? const []),
              imageText: (m['imageText'] ?? "").toString(),
            ))
        .toList();
    final conversation = ChatConversation(
      id: currentConversationId!,
      title: title,
      subject: selectedSubject,
      // ⚠️ نفس حرس `currentScopeKey` حرفياً: اختلافهما يجعل المحادثة تُحفظ
      //    بمفتاح ولا تُقرأ به — فتختفي من السجلّ فور حفظها.
      mode: (!isTeacher && selectedSubject == "رياضيات") ? mathMode : selectedMode,
      messages: chatMessages,
      grade: grade,
      track: track.key,
      branch: (!isTeacher && selectedSubject == "رياضيات") ? selectedMathBranch : "",
    );
    await ChatStorage.saveConversation(conversation, ownerUid: ownerUid);
    // ☁️ نسخة سحابية بلا انتظار: الطالب لا يشعر بها، وفشلها يُسجَّل للإعادة.
    SyncService.I.pushConversation(conversation);
    loadConversations();
  }

  Future<void> deleteConversation(String id) async {
    await ChatStorage.deleteConversation(id);
    SyncService.I.deleteConversation(id);
    if (currentConversationId == id) createNewConversation();
    loadConversations();
  }

  Future<void> renameConversation(ChatConversation conversation, String newTitle) async {
    final updated = ChatConversation(
      id: conversation.id,
      title: newTitle,
      subject: conversation.subject,
      mode: conversation.mode,
      messages: conversation.messages,
      grade: conversation.grade,
      track: conversation.track,
      branch: conversation.branch,
      createdAt: conversation.createdAt,
      lastUpdated: conversation.lastUpdated,
    );
    await ChatStorage.saveConversation(updated);
    loadConversations();
  }

  // ========== تحميل السنوات/الوحدات/الدروس ==========
  Future<void> loadAvailableYears() async {
    yearsLoading = true;
    _safeNotify();
    try {
      final list = await _content.getExamYears(selectedSubject, grade, track.key);
      if (_disposed) return;
      availableYears = list..sort((a, b) => b.compareTo(a));
    } on ServerException {
      onShowDataError?.call("تعذر جلب سنوات الاختبار. السيرفر مشغول.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال أثناء جلب السنوات.");
    } finally {
      yearsLoading = false;
      _safeNotify();
    }
  }

  Future<void> loadMathLessons(String branch) async {
    try {
      final list = await _content.getMathLessons(branch, grade, track.key);
      if (_disposed) return;
      mathLessons = list;
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب دروس الرياضيات.");
    } catch (e) {
      onShowDataError?.call("تأكد من الإنترنت لجلب دروس الرياضيات.");
    }
  }

  Future<void> loadMathExamYears(String branch) async {
    try {
      final list = await _content.getMathExamYears(branch, grade, track.key);
      if (_disposed) return;
      mathExamYears = list;
      selectedMathExamYear = "";
      mathExamLessons = [];
      selectedMathExamLesson = "";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب سنوات الرياضيات.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال.");
    }
  }

  Future<void> loadMathExamLessons(String branch, String year) async {
    try {
      final list = await _content.getMathExamLessons(branch, year, grade, track.key);
      if (_disposed) return;
      mathExamLessons = list;
      selectedMathExamLesson = "";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب الدروس الوزارية.");
    } catch (e) {
      onShowDataError?.call("تأكد من اتصالك بالإنترنت.");
    }
  }

  Future<void> loadAvailableUnits() async {
    // ✅ وصلت القدرات ⇒ هي المصدر. و`/subjects/units` احتياطٌ لسقوط الشبكة
    //    وحده، حتى لا تفرغ الشاشة إن تعذّر الطلب الأول.
    if (caps != null) {
      _applyPagesUnits();
      _safeNotify();
      return;
    }
    try {
      final units = await _content.getUnits(selectedSubject, grade, track.key);
      if (_disposed) return;
      availableUnits = ["الكل"];
      for (var unit in units) {
        if (unit.isNotEmpty && unit != "الكل") availableUnits.add(unit);
      }
      selectedUnit = "الكل";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب وحدات $selectedSubject. السيرفر مشغول.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال. تأكد من الإنترنت.");
      debugPrint("Error loading units: $e");
    }
  }

  // ========== سياق المحادثة المُرسَل للموديل ==========
  // 📉 ثلاثة أرقام مختلفة — لا تخلط بينها:
  //   • هذا الرقم = ما **يراه الموديل** ⇒ يحدّد فاتورة التوكنات.
  //   • حجم الطلب على الشبكة = نفسه بعد هذا الإصلاح (كان 10 والباك يهمل 4).
  //   • ما يُخزَّن (Hive/Firestore) = **المحادثة كاملة** — لا علاقة له بهذا الرقم.
  /// عدد الرسائل السابقة المُرسلة مع كل طلب — الباك يستخدم آخر 6 في كل مادة.
  static const int historyLastN = 6;

  /// سقف حروف الرسالة الواحدة داخل السياق (ADR-005).
  /// المكسب الأكبر في القصّ لا في العدد: رد شرح كامل قد يبلغ 4,000 حرف.
  static const int historyMaxCharsPerMessage = 1500;

  @visibleForTesting
  List<Map<String, String>> buildChatHistory() {
    final recent = messages.length <= historyLastN
        ? messages
        : messages.sublist(messages.length - historyLastN);
    return recent.map((m) {
      final own = (m["text"] ?? "").toString();
      final imageText = (m["imageText"] ?? "").toString();
      // ★ نصّ الصورة جزءٌ من سؤال الطالب في السياق — وإلا فقد المعنى بعده.
      final text = imageText.isEmpty
          ? own
          : (own.isEmpty ? imageText : "$own\n$imageText");
      return {
        "role": (m["role"] ?? "user").toString(),
        // نحتفظ ببداية الرسالة: فيها الموضوع، والذيل غالباً تفاصيل وأمثلة.
        "content": text.length <= historyMaxCharsPerMessage
            ? text
            : "${text.substring(0, historyMaxCharsPerMessage)}…",
      };
    }).toList();
  }

  // ========== نظام البوصلة (تحديد مسار الطالب الحالي) ==========
  String _truncateText(String text, int maxWords) {
    if (text.isEmpty) return "";
    List<String> words = text.split(' ');
    if (words.length <= maxWords) return text;
    return "${words.take(maxWords).join(' ')}...";
  }

  String getCurrentLocationText() {
    // يبدأ المسار بالصف (والمسار الدراسي إن وُجد) ثم المادة فالوحدة فالدرس.
    final String gradePart = Curriculum.hasTracks(grade)
        ? "${Curriculum.gradeShort(grade)} ${track.label}"
        : Curriculum.gradeShort(grade);
    List<String> path = [gradePart, selectedSubject];

    // 👨‍🏫 المعلم دائماً في وضع الدروس — بوصلته من اختيار الوحدة والدرس.
    if (isTeacher) {
      if (selectedV3Unit.isNotEmpty) path.add(_truncateText(selectedV3Unit, 3));
      if (selectedV3Lesson.isNotEmpty) path.add(_truncateText(selectedV3Lesson, 4));
      return path.join(' • ');
    }

    if (selectedSubject == "رياضيات") {
      if (selectedMathBranch.isNotEmpty) path.add(selectedMathBranch);
      if (selectedLesson.isNotEmpty) path.add(_truncateText(selectedLesson, 4));
    } else if (effectiveContentMode == "lessons") {
      // 📖 وضع الدروس: وحدته ودرسه هما ما يُرسل فعلاً — وكانت البوصلة تعرض
      //    وحدةَ وضع الوحدات بدلهما، فتقول غير ما يذهب للخادم.
      if (selectedV3Unit.isNotEmpty) path.add(_truncateText(selectedV3Unit, 3));
      if (selectedV3Lesson.isNotEmpty) path.add(_truncateText(selectedV3Lesson, 4));
    } else {
      if (selectedUnit != "الكل" && selectedUnit.isNotEmpty) {
        path.add(_truncateText(selectedUnit, 3));
      }
    }

    return path.join(' • ');
  }

  // ========== 👨‍🏫 توليد أداة المعلم ==========
  /// يُستدعى من زرّ الأداة في لوحة الإعدادات. المتابعة بعده رسالةٌ عادية
  /// عبر `processRequest` — فالمحادثة **واحدة متصلة** لا جلستان.
  Future<void> generateTeacher() async {
    if (!canGenerateTeacher) return;
    await processRequest(teacherGenerate: true);
  }

  /// «٥ أسئلة» و«١٥ سؤالاً» — تمييز العدد في العربية (نظيره في الخادم).
  static String questionsLabel(int n) {
    if (n == 1) return "سؤال واحد";
    if (n == 2) return "سؤالان";
    if (n >= 3 && n <= 10) return "$n أسئلة";
    return "$n سؤالاً";
  }

  /// نصّ فقاعة المعلّم عند ضغط زرّ التوليد — يُعرض ويُحفظ ويدخل في السياق.
  String teacherActionText() {
    final concept = conceptController.text.trim();
    return switch (teacherTool!) {
      TeacherTool.lessonPlan => "أنشئ خطة درس لـ«$selectedV3Lesson»",
      TeacherTool.simplify => "بسّط مفهوم «$concept» من درس «$selectedV3Lesson»",
      TeacherTool.homework =>
        "أنشئ واجباً من درس «$selectedV3Lesson» — المستوى $teacherDifficulty — ${questionsLabel(teacherCount)}",
      TeacherTool.ask => "",
    };
  }

  // ========== معالجة الطلب (إرسال السؤال للسيرفر) ==========
  Future<void> processRequest({String? customText, bool teacherGenerate = false}) async {
    // ✅ حماية 1: تحقق من الشروط الأساسية
    final text = customText ?? inputController.text.trim();

    bool isMathExplain = selectedSubject == "رياضيات" && mathMode == "شرح" && selectedLesson.isNotEmpty;
    // 🆕 وضع الدروس: اختيار الدرس يكفي لبدء الشرح بلا كتابة
    bool isV3LessonReady = effectiveContentMode == "lessons" && selectedV3Lesson.isNotEmpty;

    final bool hasImage = attachedImages.isNotEmpty;
    // ★ نلتقط نسخة ونُفرغ المرفق **فوراً** — لا ينتظر رد الخادم.
    //   (العلّة السابقة: كان التفريغ بعد await فتبقى المعاينة ظاهرة طوال الطلب)
    final List<PickedImage> sendingImages = List.of(attachedImages);
    if (hasImage) {
      attachedImages.clear();
    }
    // 👨‍🏫 ضغطُ زرّ الأداة طلبٌ كامل بلا نصّ مكتوب — كما «ابدأ الشرح» للطالب.
    if (text.isEmpty && customText == null && !isMathExplain && !isV3LessonReady
        && !hasImage && !teacherGenerate) {
      return;
    }

    // ✅ حماية 2: لا تسمح بطلبين معاً
    if (isLoading) {
      onShowBusyWarning?.call();
      return;
    }

    if (currentConversationId == null) createNewConversation();
    stopTypingNotifier.value = false;

    // ✅ حماية 3: أضف رسالة الطالب للواجهة
    showSettingsPanel = false;
    _isResponseCancelled = false;

    if (teacherGenerate) {
      messages.add({"role": "user", "text": teacherActionText()});
    } else if (customText == null) {
      if (selectedSubject == "رياضيات" && mathMode == "شرح" && text.isEmpty) {
        messages.add({"role": "user", "text": "شرح درس: $selectedLesson"});
      } else if (hasImage && text.isEmpty) {
        messages.add({
          "role": "user",
          "text": sendingImages.length > 1 ? "📷 صورتان" : "📷 صورة",
          "images": sendingImages.map((e) => e.path).toList(),
        });
      } else if (effectiveContentMode == "lessons" && text.isEmpty) {
        messages.add({"role": "user", "text": "${selectedMode == "تلخيص" ? "تلخيص" : "شرح"} درس: $selectedV3Lesson"});
      } else {
        messages.add({
          "role": "user",
          "text": text,
          if (hasImage) "images": sendingImages.map((e) => e.path).toList(),
        });
      }
    } else if (selectedSubject == "رياضيات" && mathMode == "وزاري") {
      final parts = text.split('|');
      if (parts.length >= 2) {
        messages.add({"role": "user", "text": "جلب أسئلة وزاري: ${parts[1]} (${parts[0]})"});
      } else {
        messages.add({"role": "user", "text": text});
      }
    } else {
      messages.add({"role": "user", "text": text});
    }

    inputController.clear();
    isLoading = true;
    _safeNotify();

    scrollToBottom();

    // ==================================================
    // 🚀 محاولة واحدة فقط (بدون Loop) بحد أقصى دقيقة
    // ==================================================
    try {
      final chatHistory = buildChatHistory();

      String finalContentToSend = text;
      String finalLessonName = "";
      final String? cMode = effectiveContentMode;

      // 📌 اسم الدرس لا معنى له في وضع الوحدات — الخادم يتجاهله هناك،
      //    فيبقى لوضع الدروس والرياضيات وحدهما.
      if (cMode == "lessons") {
        finalLessonName = selectedV3Lesson;
      } else if (selectedSubject == "رياضيات") {
        finalLessonName = selectedLesson;
      }

      if (selectedSubject != "رياضيات" && selectedMode == "وزاري" && customText == null) {
        finalContentToSend = "$selectedExamYear,$text";
      }

      // تأكيد توفّر معرّف الجهاز (يُحمّل بأمان مرة واحدة)
      if (_deviceId.isEmpty) {
        _deviceId = await SecureStorage.getOrCreateDeviceId();
      }

      final AskResponse response = isTeacher
          ? await _chat.teacherAsk(
              userId: userId,
              code: AppConfig.accessCode,
              deviceId: _deviceId,
              tool: teacherTool!.id,
              generate: teacherGenerate,
              subject: selectedSubject,
              grade: grade,
              track: track.key,
              unitName: selectedV3Unit,
              lessonName: selectedV3Lesson,
              content: teacherGenerate ? "" : finalContentToSend,
              concept: conceptController.text.trim(),
              difficulty: teacherDifficulty,
              count: teacherCount,
              chatHistory: chatHistory,
              imagesBase64: sendingImages.map((e) => e.base64Data).toList(),
              idToken: await UserSession.I.idToken(),
            )
          : await _chat.ask(
        userId: userId,
        code: AppConfig.accessCode, // 🔑 ثابت SUPER_USER (لمطابقة الباك)
        deviceId: _deviceId,
        subject: selectedSubject,
        mode: selectedMode,
        inputType: inputType,
        summaryLevel: summaryLevel,
        lessonName: finalLessonName,
        content: finalContentToSend,
        unitName: (selectedSubject == "رياضيات")
            ? selectedMathBranch
            : (cMode == "lessons" ? selectedV3Unit : selectedUnit),
        chatHistory: chatHistory,
        grade: grade,
        track: track.key,
        contentMode: cMode,
        imagesBase64: sendingImages.map((e) => e.base64Data).toList(),
        idToken: await UserSession.I.idToken(),
      );

      // إذا ضغط المستخدم على إيقاف أثناء التحميل
      if (_isResponseCancelled || _disposed) return;

      // ★ نصّ الصورة يُثبَّت على **رسالة الطالب** — فهو جزء من سؤاله لا من الرد.
      //   بدونه تُنسى الصورة في السؤال التالي لأن التاريخ نصٌّ لا صور.
      if (response.imageText.isNotEmpty && hasImage) {
        for (var i = messages.length - 1; i >= 0; i--) {
          if (messages[i]["role"] == "user") {
            messages[i]["imageText"] = response.imageText;
            break;
          }
        }
      }

      // ✅ حالة النجاح
      isLoading = false;
      messages.add({
        "role": "ai",
        "text": response.answer,
        "refs": response.references,
        "animating": true,
        "fullText": response.answer,
      });
      sessionActive = response.sessionActive;
      _safeNotify();
      await saveCurrentConversation();
      scrollToBottom();
      if (response.quotaExceeded) onQuotaExceeded?.call(response.isGuest);
    } on TimeoutException catch (_) {
      // ⏱️ انتهت المهلة
      if (!_disposed && !_isResponseCancelled) {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": ErrorMessages.askTimeout,
          "refs": [],
          "animating": false,
          "isError": true,
        });
        _safeNotify();
        scrollToBottom();
      }
    } on SocketException catch (_) {
      // 📡 انقطع الإنترنت
      if (!_disposed && !_isResponseCancelled) {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": ErrorMessages.askNoConnection,
          "refs": [],
          "animating": false,
          "isError": true,
        });
        _safeNotify();
        scrollToBottom();
      }
    } catch (e) {
      // ❌ أخطاء أخرى
      if (!_disposed && !_isResponseCancelled) {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": ErrorMessages.askUnexpected,
          "refs": [],
          "animating": false,
          "isError": true,
        });
        _safeNotify();
        scrollToBottom();
      }
    } finally {
      // 🔪 تحرير موارد الاتصال
      _chat.cancel();
      if (!_disposed) {
        isLoading = false;
        _safeNotify();
      }
    }
  }

  // ========== التمرير للأسفل ==========
  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ========== تحديثات حالة بسيطة من الواجهة ==========
  void refresh() => _safeNotify();

  void setShowSettingsPanel(bool value) {
    showSettingsPanel = value;
    _safeNotify();
  }

  void toggleSettingsPanel() {
    showSettingsPanel = !showSettingsPanel;
    _safeNotify();
  }

  void update(VoidCallback fn) {
    fn();
    _safeNotify();
  }

  @override
  void dispose() {
    SyncService.I.flushNow();   // لا تترك آخر رسالة معلّقة
    SyncService.I.revision.removeListener(_onRemoteConversations);
    _disposed = true;
    try {
      // 1. احفظ آخر محادثة
      if (currentConversationId != null && messages.isNotEmpty) {
        saveCurrentConversation();
      }
      // 2. ألغِ أي طلب شغال وأغلق الاتصال
      _chat.cancel();
      // 3. أغلق الـ ValueNotifiers والـ Controllers
      stopTypingNotifier.dispose();
      inputController.dispose();
      conceptController.dispose();
      scrollController.dispose();
      questionCountController.dispose();
      arabicQuestionCountController.dispose();
      englishQuestionCountController.dispose();
    } catch (e) {
      debugPrint('Error in ChatController dispose: $e');
    }
    super.dispose();
  }
}
