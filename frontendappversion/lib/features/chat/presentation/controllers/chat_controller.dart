import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/config/curriculum.dart';
import '../../../../core/services/image_service.dart';
import '../../../../core/services/stt_service.dart';
import '../../../../core/services/voice_text_merge.dart';
import '../../../../core/quota/quota_repository.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/sync/sync_service.dart';
import '../../data/models/ask_response.dart';
import '../../data/models/chat_suggestion.dart';
import '../../data/models/chat_model.dart';
import '../../data/edu_session.dart';
import '../../data/models/subject_capabilities.dart';
import '../../data/repositories/ask_stream.dart';
import '../../data/repositories/chat_repository.dart';
import 'stick_to_bottom.dart';
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
    // 🧪 يُحقن في الاختبارات وحدها — الإنتاج لا يمرّر شيئاً.
    AskStream? askStream,
  })  : _chat = chatRepository ?? ChatRepository(),
        _content = contentRepository ?? TutorContentRepository(),
        _stream = askStream ?? AskStream();

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

  /// 🔴 **كان `const Uuid().v4()` — معرّفاً جديداً في كل فتحةِ شاشة.**
  ///
  /// و`MainChatScreen` ينشئ المتحكّم في `initState`، أي أن كل خروجٍ ورجوع
  /// كان يولّد هويةً جديدة تماماً. وثلاث نتائج تتبع ذلك:
  ///   1. **جلسة الرياضيات تنقطع**: الخادم يُمفتِح جلسات «وزاري» و«شرح»
  ///      بـ`user_id` (`sessions_math`). فطالبٌ في منتصف تسلسلٍ متعدد
  ///      الخطوات يخرج للرئيسية ويعود ⇒ يبدأ من الصفر بلا سبب ظاهر.
  ///   2. مفتاح تحديد المعدل كان يتغيّر معه ⇒ الحماية تُلتفّ عليها بمجرد
  ///      إعادة فتح الشاشة.
  ///   3. جداول الجلسات على الخادم تنتفخ بمفاتيح ميتة لا يعود إليها أحد.
  ///
  /// ✅ والآن هوية الحساب: ثابتةٌ عبر الشاشات والجلسات وحتى إعادة التثبيت.
  ///    (والخادم يكتبها فوق ما نرسله على أي حال — راجع `_authenticate`.)
  String get userId => UserSession.I.uid;

  final Map<String, List<Map<String, dynamic>>> _allChatsHistory = {};

  // ══════════════════════════════════════════════════
  // 🌊 البثّ + 📌 الالتصاق بالأسفل
  // ══════════════════════════════════════════════════

  /// عميل البثّ — يُغلق عند المغادرة كما يُغلق عميل الطلب العادي.
  final AskStream _stream;

  /// 📌 قرار «هل نتبع الأسفل؟» — منطقٌ خالص يُختبر وحده
  /// ([stick_to_bottom.dart]).
  final StickToBottom stick = StickToBottom();

  /// هل يُكتب ردٌّ الآن؟ (تراه الفقاعة لتُظهر التلاشي والمؤشّر)
  bool isStreaming = false;

  /// 👆 لمس الطالب الشاشة — يفكّ الالتصاق فوراً ويمنع أي قفزٍ حتى يرفع.
  void onUserDragStart() {
    final was = stick.isStuck;
    stick.beginUserDrag();
    if (was) _safeNotify();     // يظهر زرّ «انزل للأسفل»
  }

  /// ✋ رفع الطالب إصبعه واستقرّت اللفّة — يُعاد الحكم من موضعه النهائي.
  void onUserDragEnd(ScrollMetrics metrics) {
    final was = stick.isStuck;
    stick.endUserDrag(metrics);
    if (was != stick.isStuck) _safeNotify();
  }

  /// يُنادى من الويدجت حين **يمرّر الطالب بنفسه** لا حين ينمو النص.
  void onUserScroll(ScrollMetrics metrics) {
    final was = stick.isStuck;
    stick.onUserScroll(metrics);
    // نُعلم الواجهة فقط عند تغيّر الحالة — زرّ «انزل للأسفل» يظهر ويختفي.
    if (was != stick.isStuck) _safeNotify();
  }

  /// زرّ «انزل للأسفل» — يعيد الالتصاق وينزل بحركةٍ ناعمة.
  void jumpToBottomAndStick() {
    stick.stick();
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    _safeNotify();
  }

  /// ⏸️ ضغط الطالب «إيقاف» بينما الردّ في الطريق.
  ///
  /// الطلب يُكمل، والجواب حين يصل يُضاف **بلا أنيميشن** ويُحفظ: الحصة
  /// دُفعت فلا يُرمى ما اشترته. راجع [stopCurrentRequest].
  bool _quietlyAwaitingAnswer = false;

  /// 🧾 معرّف **المحاولة الجارية** — لا معرّف الرسالة ولا الجلسة.
  ///
  /// يُولَّد مرةً واحدة عند بدء الإرسال ويبقى ثابتاً عبر إعادات المحاولة
  /// التلقائية، فيعرف الخادم أنها **نفس** المحاولة فلا يخصم مرتين
  /// ([Backend/core/idempotency.py]). ورسالةٌ جديدة تعني معرّفاً جديداً.
  String _requestId = "";

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
  // 📚 فارغةٌ حتى تصل قائمةُ الوحدات — «الكل» لم تعد خياراً
  //    ([_applyPagesUnits]).
  String selectedUnit = "";
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
  /// يُنبّه أن وضع الصفحات يحتاج اختياراً — تملؤه الشاشة.
  void Function()? onShowPagesRequired;

  /// ❓ **وضعُ السؤال يحتاج سؤالاً مكتوباً** (قرار المالك 2026-09-14):
  ///    «في خانة السؤال ضروري الطالب يكتب سؤال… السؤالُ ليس الذي يشرح
  ///    الدرس. فلا تخلّيه يقدر يضغط زرّ الإرسال بلا ما يكتب شي، في كل
  ///    المواد.»
  ///
  /// 🔴 وما كان: الضغطُ بحقلٍ فارغ في وضع السؤال يُولّد طلباً من عندنا
  ///    («اطرح ملخصاً سريعاً…» · «أجب من الصفحات الآتية») فيخرج **شرحُ
  ///    درسٍ كامل من وضع السؤال** — ويُخصم من حصّة الطالب.
  ///
  /// ⚖️ والصورةُ سؤالٌ بذاتها: نصُّها يُدمج في السؤال على الخادم، فمرفَقٌ
  ///    بلا كتابة يمرّ — ولهذا الشرطُ على `canSendWithoutText` لا على
  ///    مسار الصور ([chat_input_area] يفتح الزرّ للمرفقات على حدة).
  bool get questionNeedsTypedText => !isTeacher && selectedMode == "سؤال";

  // ══════════════════════════════════════════════════
  // 💡 اقتراحاتُ الوضع — بدايةٌ للطالب، ومتابعةٌ بعد الجواب
  // ══════════════════════════════════════════════════
  //
  // ⚖️ **قرار المالك (2026-09-16):** «اقتراحات مناسبة لكل وضع. وركّز في زرّ
  //    اشرح لي — خلّه باين أفضل، لما يضغط عليه يشرح له على طول من المخزون.»
  //
  // 🎯 و«اشرح لي الدرس» ليست شريحةً كغيرها: هي **الطلبُ الوحيد المخزون**
  //    ([core/lesson_cache] على الخادم)، فتصل في جزءٍ من الثانية وبلا خصمٍ
  //    من الحصة. ولذلك تُعرض زرّاً بارزاً (`primary`) لا شريحةً في الصفّ.
  //    ونصُّها **حرفياً** ما يقبله `lesson_cache.is_full_lesson_request`،
  //    فأيُّ صياغةٍ أخرى تُفوّت المخزون وتذهب للموديل.
  //
  // 🔄 **وتتبدّل بعد أول جواب**: شرائحُ البداية تصير شرائحَ متابعة. فشريحةٌ
  //    تقول «بسّط لي» قبل أن يُشرح شيءٌ تُنتج رداً بلا معنى وتُستهلك من
  //    الحصة — نفسُ القاعدة المطبّقة في [TeacherSuggestionChips].

  /// نصُّ «اشرح لي الدرس» كما يقبله المخزون على الخادم. **لا يُغيَّر بلا
  /// تغيير `is_full_lesson_request` معه** — وإلا سقط الكاشُ بصمت.
  static const String explainLessonText = "اشرح لي هذا الدرس";

  static const List<ChatSuggestion> _followUps = [
    ChatSuggestion("بسّط لي", "بسّط لي ما شرحته بلغةٍ أسهل"),
    ChatSuggestion("مثال من الحياة",
        "أعطني مثالاً من الحياة اليومية يوضّح الفكرة"),
    ChatSuggestion("وضّح أكثر", "وضّح أكثر ما شرحته"),
    ChatSuggestion("لخّص", "لخّص لي ما سبق في نقاط"),
  ];

  /// عددُ ردودِ المساعد في هذه المحادثة — مقياسُ «أين نحن من الحصة».
  int get _answerCount =>
      messages.where((m) => m["role"] == "ai").length;

  /// ⏳ **بعد جولتين تُطفأ الاقتراحات** (قرار المالك 2026-09-16: «الثالثة
  /// خلاص ما عاد شي داعي تطلع الاقتراحات — خلاص هو يتصرّف اليوزر»).
  ///
  /// ⚖️ والحدُّ ليس تجميلاً: الاقتراحُ يخدم **البداية** — أن يعرف الطالبُ
  ///    ما يستطيع طلبه. فإذا سأل مرّتين فقد عرف، وبقاؤها بعدها يضيّق
  ///    الشاشةَ ويغري بضغطةٍ بلا حاجة تُخصم من حصّته.
  static const int _maxSuggestionRounds = 2;

  /// الاقتراحاتُ المناسبة للحالة الراهنة — فارغةٌ حين لا معنى لها.
  List<ChatSuggestion> get suggestions {
    if (isTeacher) return const [];            // للمعلّم شرائحُه الخاصة
    if (selectedMode == "وزاري" || selectedMode == "اختبارات") return const [];
    final answers = _answerCount;
    if (answers >= _maxSuggestionRounds) return const [];
    if (answers > 0) return _followUps;

    // 📖 الزرُّ البارز لا يظهر إلا ودرسٌ مختار — وإلا لا شيءَ ليُشرح.
    final lessonReady = effectiveContentMode == "lessons"
        ? selectedV3Lesson.isNotEmpty
        : (selectedSubject == "رياضيات" && selectedLesson.isNotEmpty);

    switch (selectedMode) {
      case "تلخيص":
        return [
          if (lessonReady)
            const ChatSuggestion("لخّص لي", "لخّص لي هذا الدرس", primary: true),
          const ChatSuggestion("في نقاط", "لخّص الدرس في نقاطٍ مرقّمة"),
          const ChatSuggestion("أهم التعريفات",
              "اجمع لي أهم التعريفات في هذا الدرس"),
        ];
      case "سؤال":
        // ⚠️ **قوالبُ تُملأ ولا تُرسل**: وضعُ السؤال يشترط أن يكتب الطالبُ
        //    سؤاله ([questionNeedsTypedText]). فتُفتح له البداية ويُكملها
        //    بموضوعه — ولو أُرسلت ناقصةً لضاعت من حصّته بلا فائدة.
        return const [
          ChatSuggestion("عرّف لي…", "عرّف لي ", send: false),
          ChatSuggestion("ما الفرق بين…", "ما الفرق بين ", send: false),
          ChatSuggestion("لماذا…", "لماذا ", send: false),
          ChatSuggestion("اذكر أمثلة على…", "اذكر أمثلة على ", send: false),
        ];
      default:                                  // شرح
        return [
          if (lessonReady)
            const ChatSuggestion("اشرح لي", explainLessonText, primary: true),
          const ChatSuggestion("مثال من الحياة",
              "اشرح لي الدرس وأعطني مثالاً من الحياة اليومية"),
          const ChatSuggestion("بطريقةٍ مبسّطة",
              "اشرح لي الدرس بطريقةٍ مبسّطةٍ جداً"),
          const ChatSuggestion("أهم النقاط",
              "اشرح لي أهم النقاط في هذا الدرس"),
        ];
    }
  }

  /// تنفيذُ اقتراح: إرسالٌ فوريّ، أو ملءُ حقل الكتابة لِيُكمله الطالب.
  void applySuggestion(ChatSuggestion s) {
    if (s.send) {
      processRequest(customText: s.text);
      return;
    }
    inputController.text = s.text;
    inputController.selection =
        TextSelection.collapsed(offset: s.text.length);
    notifyListeners();
  }

  bool get canSendWithoutText =>
      !isTeacher &&
      !questionNeedsTypedText &&
      ((effectiveContentMode == "lessons" && selectedV3Lesson.isNotEmpty) ||
          // 📄 صفحاتٌ مختارة = طلبٌ كامل بذاته. طلبُ المالك: «الزر يكون
          //    دايركت — لو ضغطت عليه يقول له اشرح الصفحات الآتية».
          (canPickPages && selectedPages.isNotEmpty));

  /// ما يُرسل حين تُختار صفحات ولا يكتب الطالب شيئاً.
  String get _defaultPagesPrompt {
    final verb = {"تلخيص": "لخّص", "سؤال": "أجب من"}[selectedMode] ?? "اشرح";
    return "$verb الصفحات الآتية.";
  }

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

  String _inputType = "برومت";

  String get inputType => _inputType;

  /// 🛡️ **مُسنِدٌ لا حقلٌ عارٍ** — والسببُ عطلٌ وقع فعلاً:
  ///
  /// «صفحة» تُنسى مُسنَدةً حين يخرج الطالب من وضع الوحدات، فتبقى حالةً
  /// **مخفيّة** (اللوحة لا تعرض محدّدها هناك) تحكم سلوكاً ظاهراً. وتصفيرُها
  /// في كل موضعٍ يخرج منه يعني ستة مواضع تُنسى إحداها يوماً.
  ///
  /// ⭐ فالخروج من «صفحة» يُسقط ما اختير معه — هنا، مرّةً واحدة، لكل
  ///    المواضع الحالية وما يُضاف بعدها.
  set inputType(String value) {
    if (_inputType == value) return;
    _inputType = value;
    if (value != "صفحة") selectedPages.clear();
  }

  // ══════════════════════════════════════════════════
  // 📄 الصفحات المختارة — ترتفع مع البرومبت لا معه مرّةً واحدة
  // ══════════════════════════════════════════════════
  // 🔴 كان الطالب يكتب «13، 14، 15» داخل سؤاله، فيخلط الرقمَ المقصود
  //    بالرقم العابر، **ويفقد صفحاته في السؤال التالي** لأن الرقم كان في
  //    نصّ الرسالة السابقة لا في حالة الجلسة.
  //
  // ⭐ فصارت حالةً مستقلة: تبقى ظاهرةً فوق حقل الكتابة وتُرسل مع كل رسالة
  //    حتى يرفعها الطالب بنفسه (قرار المالك 2026-09-09).
  final List<int> selectedPages = [];

  int get maxPages => caps?.maxSelectablePages ?? 3;

  /// 🚦 **البوّابة الوحيدة لوضع الصفحات** — عليها يتوقّف كلُّ شيء: ظهور
  /// المُنتقي، وشرائحُ الصفحات فوق حقل الكتابة، وإرسالُ `selected_pages`،
  /// والمنعُ من الإرسال بلا اختيار.
  ///
  /// 🔴 **العطل الذي كشفه المالك (2026-09-09):** كانت تسأل عن «صفحة/برومت»
  ///    وحدها ولا تسأل عن **مصدر المحتوى**. فمن اختار صفحاتٍ في وضع
  ///    الوحدات ثم رجع إلى وضع الدروس بقي `inputType == "صفحة"` مخفياً
  ///    (اللوحة تُخفي محدّده في وضع الدروس ولا تُصفّره)، فظهر المُنتقي في
  ///    وضع الدروس **وأُرسلت الصفحات مع الدرس معاً** — طلبٌ مختلط لا يعرف
  ///    الخادمُ أيَّهما يخدم.
  ///
  /// ⚖️ وجمعُ الشروط في *مشتقٍّ واحد* لا نسخِها في كل موضع: أيُّ موضعٍ
  ///    يُنسى هو عودةٌ لنفس العطل.
  bool get canPickPages =>
      !isTeacher &&
      effectiveContentMode == "pages" &&   // 👈 وضع الوحدات حصراً
      inputType == "صفحة" &&
      (caps?.pagesAvailable ?? false);

  /// صفحات النطاق الحالي — الوحدة المختارة، أو المنهج كلّه عند «الكل».
  List<int> get availablePages =>
      caps?.pagesIn(selectedUnit) ?? const <int>[];

  /// يضيف صفحةً ويعيد سبب الرفض إن رُفضت — **رسالةٌ لا صمت**.
  String? addPage(int page) {
    if (selectedPages.contains(page)) return "الصفحة $page مضافة أصلاً.";
    if (selectedPages.length >= maxPages) {
      return "الصفحات زائدة — الحد $maxPages صفحات في المرة الواحدة.";
    }
    selectedPages.add(page);
    selectedPages.sort();
    notifyListeners();
    return null;
  }

  void removePage(int page) {
    selectedPages.remove(page);
    notifyListeners();
  }

  void clearPages() {
    if (selectedPages.isEmpty) return;
    selectedPages.clear();
    notifyListeners();
  }
  int summaryLevel = 3;
  String selectedUnitName = "";
  bool isLoading = false;

  /// 🚦 **مشغولٌ الآن؟ — التحميلُ والبثُّ معاً.**
  ///
  /// 🔴 **العطل الذي كشفه المالك (2026-09-13):** أوّلُ جزءٍ يصل من البثّ
  ///    يُطفئ `isLoading` عمداً (لتختفي دائرة الانتظار وتظهر الفقاعة).
  ///    فمن سأل `isLoading` وحده ظنّ الشاشة فارغةً **والطلبُ ما زال في
  ///    الطريق**: زرّ الإرسال يعود سهماً، وزرّ الكاميرا يظهر، فيُرفق
  ///    الطالب صورةً ويضغط إرسال — فيُطلق طلباً ثانياً فوق الأول:
  ///    **الصورة تُفرَّغ ولا تصل، والفقاعة تختلط بجوابين**. وهو بالضبط
  ///    ما وصفه: «المحادثة فيها كلام… أضغط إرسال ما يضبط وتختفي الصورة».
  ///
  /// ⚖️ فصار سؤالُ «هل أنا مشغول؟» **مشتقّاً واحداً** لا حقلاً عارياً:
  ///    كلُّ موضعٍ ينسى `isStreaming` هو عودةٌ لنفس العطل.
  bool get isBusy => isLoading || isStreaming;

  /// للاختبارات وحدها: يُشيخ الحالةَ المشغولة كأن الطلب تجمّد.
  @visibleForTesting
  void debugAgeBusyState() =>
      _busySince = DateTime.now().subtract(_busyCeiling * 2);

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

    // الصف والمسار من حساب الطالب (يُختاران عند إنشاء الحساب ويُعدَّلان من الإعدادات).
    // 🎟️ رقمٌ حقيقيّ عند فتح الشاشة (لا يؤخّرها — بلا انتظار).
    unawaited(QuotaRepository.I.refresh());

    grade = UserSession.I.grade;
    track = Curriculum.normalizeTrack(grade, TrackLabel.fromKey(UserSession.I.track));
    selectedSubject = Curriculum.defaultSubject(grade, track);
    if (openSubject != null && Curriculum.subjectsFor(grade, track).contains(openSubject)) {
      selectedSubject = openSubject;
    }
    _resetModeForSubject();
    if (openMode != null && openMode.isNotEmpty) selectedMode = openMode;

    // 🪑 **آخرُ مكانٍ تركه الطالب** — قبل بناء المحادثة لا بعدها: المادةُ
    //    والوضعُ هما مفتاحُ النطاق الذي تُقرأ به المحادثات وتُحفظ به.
    //    ولا تُستعاد لفتحةٍ موجَّهة (نتيجةُ اختبارٍ أو تحليل): تلك تقول
    //    أين تذهب صراحةً، فالجلسةُ لا تنقضها ([EduSession]).
    final resumed = (openSubject == null && openLesson == null && openMode == null)
        ? _restorePlace()
        : null;

    loadConversations();
    // 🔄 محادثات وصلت من السحابة (جهاز جديد أو زر الاستعادة) ⇒ حدّث القائمة.
    SyncService.I.revision.addListener(_onRemoteConversations);
    createNewConversation();
    // 💬 ورسائلُ المحادثة نفسِها بعد أن صار سجلُّ النطاق بين يدينا.
    if (resumed != null) {
      for (final conv in conversations) {
        if (conv.id != resumed) continue;
        loadConversation(conv);
        break;
      }
    }
    // 🎓 ويتبع الطالبَ أينما بدّل صفَّه — من الدرج أو من الإعدادات.
    UserSession.I.addListener(_onSessionScopeChanged);
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

    // 🪑 وحدةُ الجلسة ودرسُها — **بعد وصول القدرات** كما للفتح الموجَّه
    //    تماماً: قبلها لا قائمةَ دروسٍ يُتحقَّق منها، فيُثبَّت درسٌ قد لا
    //    يكون في المادة أصلاً.
    _restoreLessonOfPlace();
  }

  /// 🪑 يُنزل الشاشةَ على آخر مكانٍ في قسم التعليم، ويعيد معرّف محادثته.
  ///
  /// يعود `null` إن لم يكن ثمّة مكانٌ محفوظ، أو كان لحسابٍ آخر أو لصفٍّ
  /// آخر، أو كانت مادتُه ليست من مواد الصف الحالي.
  String? _restorePlace() {
    final p = EduSession.I.place;
    if (p == null || isTeacher) return null;
    // 👨‍🏫 حارسٌ أخير: مكانٌ يحمل وضعَ معلّمٍ لا يُفتح في قسم التعليم.
    //    (المصدرُ مُنقّى عند الكتابة، وهذا كي لا يعتمد الصحُّ على مصدرٍ بعينه.)
    if (isTeacherMode(p.mode)) return null;
    if (!p.matches(UserSession.I.uid, grade, track.key)) return null;
    if (!Curriculum.subjectsFor(grade, track).contains(p.subject)) return null;

    selectedSubject = p.subject;
    _resetModeForSubject();
    if (selectedSubject == "رياضيات") {
      selectedMathBranch = p.mathBranch;
      if (p.mathMode.isNotEmpty) {
        mathMode = p.mathMode;
        selectedMode = p.mathMode;
      }
      selectedLesson = p.mathLesson;
      if (selectedMathBranch.isNotEmpty) unawaited(loadMathLessons(selectedMathBranch));
    } else {
      // ⚠️ وضعٌ لم يعد لهذا الصف (وزاريُّ من تشغيلةٍ قبل تبديل الصف) يُهمَل
      //    ويبقى «شرح» — الشريحةُ غيرُ مرسومةٍ أصلاً فلا يُفتح عليها.
      if (Curriculum.modesFor(selectedSubject, grade: grade).contains(p.mode)) {
        selectedMode = p.mode;
      }
      contentMode = p.contentMode;
    }
    return p.conversationId;
  }

  /// 🪑 الشقُّ المؤجَّل من [_restorePlace] — يحتاج `caps`.
  void _restoreLessonOfPlace() {
    final p = EduSession.I.place;
    if (p == null || isTeacher || p.lesson.isEmpty) return;
    if (p.subject != selectedSubject) return;
    if (caps?.lessonsAvailable != true) return;
    if (!caps!.lessonsIn(p.unit).contains(p.lesson)) return;
    selectedV3Unit = p.unit;
    selectedV3Lesson = p.lesson;
    _safeNotify();
  }

  /// 🪑 يحفظ المكان الحالي قبل أن تموت الشاشة — يقرؤه الفتحُ التالي.
  @visibleForTesting
  void rememberPlace() => _rememberPlace();

  void _rememberPlace() {
    if (isTeacher) return;
    EduSession.I.place = EduPlace(
      uid: UserSession.I.uid,
      grade: grade,
      track: track.key,
      subject: selectedSubject,
      mode: selectedMode,
      mathBranch: selectedMathBranch,
      mathMode: mathMode,
      mathLesson: selectedLesson,
      contentMode: contentMode,
      unit: selectedV3Unit,
      lesson: selectedV3Lesson,
      // 💬 محادثةٌ بلا رسالةٍ واحدة لا تُحفظ في المخزن أصلاً، فلا تُطلب.
      conversationId: messages.isEmpty ? null : currentConversationId,
    );
  }

  /// 🎓 **الصفُّ تبدّل من خارج هذه الشاشة** (شاشةُ الإعدادات مثلاً).
  ///
  /// 🔴 كان [ChatController] يقرأ الصفَّ **مرّةً في `init`** ثم يعيش —
  ///    فمن بدّل صفَّه ثم عاد إلى محادثةٍ ما زالت في المكدّس بقي أمامه
  ///    موادُّ صفٍّ تركه، **وأوّلُ رسالةٍ يرسلها تذهب بصفٍّ خاطئ**
  ///    وتُحفظ في نطاقٍ خاطئ. (نفسُ العلّة التي عولجت في `MasarShell`
  ///    للتبويبات، وهذه الشاشةُ خارجَه لأنها تُدفع فوقه.)
  void _onSessionScopeChanged() {
    if (_disposed || isTeacher) return;
    final g = UserSession.I.grade;
    final t = Curriculum.normalizeTrack(g, TrackLabel.fromKey(UserSession.I.track));
    if (g == grade && t == track) return;
    grade = g;
    track = t;
    unawaited(_onScopeChanged());
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
  /// ⚠️ **عبر [UserSession.setGrade] لا `updateProfile`** (٢٠٢٦-٠٩-٢٢):
  ///    تلك تكتب الحقلين وتُخطر الواجهة فحسب، وهذه تفعل ما يلزم فعلاً —
  ///    تُسقط كاشَ حارس الأقسام في الخادم، وتُعيد جلب بانرات الصف الجديد،
  ///    وتُصحّح المسار للأول الثانوي. فمن بدّل صفَّه من **الدرج** كان يبقى
  ///    يرى أقسام صفٍّ تركه وبانراته حتى الإقلاع التالي، بينما من بدّله من
  ///    **الإعدادات** لا يرى ذلك — بابان لفعلٍ واحد وسلوكان مختلفان.
  Future<void> setGrade(int g) async {
    if (g == grade) return;
    grade = g;
    track = Curriculum.normalizeTrack(grade, track);
    await UserSession.I.setGrade(g);
    await _onScopeChanged();
  }

  /// يغيّر المسار (علمي/أدبي) — متاح للصفين الثاني والثالث فقط.
  Future<void> setTrack(Track t) async {
    if (!Curriculum.hasTracks(grade) || t == track) return;
    track = t;
    await UserSession.I.setTrack(t.key);   // ← نفسُ سبب [setGrade] حرفياً
    await _onScopeChanged();
  }

  /// يغيّر المادة داخل نفس الصف/المسار.
  Future<void> setSubject(String subject) async {
    if (subject == selectedSubject) return;
    selectedSubject = subject;
    await _onScopeChanged(keepSubject: true);
  }

  /// 👨‍🏫 **يبدّل أداة المعلم من شريط الأدوات** — بلا مغادرة الشاشة.
  ///
  /// 🎨 صار لازماً بتصميم `design/09-teacher`: كانت الأداةُ تُختار مرّةً
  ///    من شاشة بوابةٍ ثم تُفتح الشاشةُ عليها، فلا تتبدّل إلا برجوعٍ
  ///    وفتحٍ جديد. وفي التصميم شريطٌ فوق المحادثة يبدّلها بلمسة.
  ///
  /// ⚠️ **والأداةُ جزءٌ من مفتاح النطاق** (`selectedMode = "معلم:<id>"`)،
  ///    فتبديلُها تبديلُ سجلٍّ كامل: تُحمَّل محادثاتُ الأداة الجديدة
  ///    وتُفتح محادثةٌ فارغة — تماماً كما كان يحدث عند فتح الشاشة عليها.
  ///
  /// 🔒 **ولا تُمسّ المادةُ ولا الوحدةُ ولا الدرس**: معلّمٌ اختار درسه ثم
  ///    أراد منه واجباً بدل الخطة لا يُعقل أن يُعيد اختياره. ولهذا لا
  ///    تمرّ هذه الدالة بـ[_onScopeChanged] — تلك تمسح القدرات والدرس
  ///    لأن المادة تغيّرت، وهنا لم تتغيّر.
  Future<void> setTeacherTool(TeacherTool tool) async {
    if (!isTeacher || tool == teacherTool) return;
    teacherTool = tool;
    selectedMode = "معلم:${tool.id}";
    loadConversations();
    createNewConversation();
    _safeNotify();
  }

  /// كل ما يجب أن يحدث عند تغيّر النطاق (صف/مسار/مادة).
  Future<void> _onScopeChanged({bool keepSubject = false}) async {
    if (!keepSubject || !subjects.contains(selectedSubject)) {
      selectedSubject = Curriculum.defaultSubject(grade, track);
    }
    // تُملأ بأول وحدةٍ فور وصول قائمة المادة الجديدة.
    selectedUnit = "";
    selectedUnitName = "";
    // 📄 صفحاتُ وحدةٍ لا معنى لها في مادةٍ أخرى — وإبقاؤها كان سيُرسل
    //    أرقاماً تخصّ كتاباً آخر فيردّ الخادم «لم أجد هذه الصفحات».
    selectedPages.clear();
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

  /// 📷 هل في خانة الإرفاق صورةٌ تنتظر الإرسال؟
  ///
  /// ⭐ **والصورةُ وحدها طلبٌ كامل** — «اقرأ لي هذه» ضمنيةٌ فيها. وعليها
  ///    تُفتح بوّابة الإرسال كما في مساعد المنح تماماً ([ChatInputArea]).
  bool get hasAttachments => attachedImages.isNotEmpty;

  /// 🧹 يُفرغ المرفقات المعلّقة ويحذف ملفاتها.
  ///
  /// 🔴 **علّة مرصودة:** المرفق كان يبقى عبر تبديل المحادثات والمواد —
  ///    فمن صوّر صفحة أحياء ثم فتح محادثة رياضيات وأرسل، ذهبت صورةُ
  ///    الأحياء مع سؤال الرياضيات. والمرفق سياقُ **هذه** المحادثة لا غيرها.
  void clearAttachments() {
    if (attachedImages.isEmpty) return;
    final gone = List<PickedImage>.of(attachedImages);
    attachedImages.clear();
    for (final img in gone) {
      unawaited(ImageService.I.delete(img.path));
    }
  }

  Future<void> attachImage({required bool fromCamera}) async {
    // 🚦 البثُّ طلبٌ جارٍ وإن أطفأ `isLoading` — راجع [isBusy].
    if (isBusy) {
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
    // 🚦 «إرسال مباشر» ينتهي بـ`processRequest` — فحارسُه حارسُها ([isBusy]).
    if (isBusy) {
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
      subject: selectedSubject,
      rawText: raw,
      idToken: await UserSession.I.idToken(),
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
  /// 📚 **«الكل» لم تعد خياراً** (قرار المالك 2026-09-14): «الكل ماشي
  /// الكل — ضروري يكون في وحدة عشان يقلّل البحث، يكون معصور، بحثٌ أفضل».
  ///
  /// والقياسُ يؤيّده: كتابُ الأحياء ١٦٢ صفحة ووحدةُ التنظيم الهرموني ١٩.
  /// البحثُ في ١٩ يميّز بين جيرانٍ متقاربين، وفي ١٦٢ يُزاحم الموضوعَ
  /// صفحاتٌ من وحداتٍ لا علاقة لها به. والخادمُ يردّ الطلبَ بلا وحدة.
  void _applyPagesUnits() {
    availableUnits =
        (caps?.pagesAvailable ?? false) ? [...caps!.pagesUnits] : <String>[];
    if (!availableUnits.contains(selectedUnit)) {
      // أولُ وحدةٍ افتراضاً — لا «الكل»، ولا فراغٌ يُربك الطالب.
      selectedUnit = availableUnits.isNotEmpty ? availableUnits.first : "";
      selectedUnitName = selectedUnit;
    }
    // ⚠️ وما اختير من صفحاتٍ خارج النطاق الجديد يسقط — لا يبقى معلّقاً
    //    في شريطٍ يراه الطالب ولا يجده الخادم.
    final ok = caps?.pagesIn(selectedUnit) ?? const <int>[];
    selectedPages.removeWhere((p) => !ok.contains(p));
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
    if (mode == "lessons") {
      _resetV3Selection();
      // 📄 ولا تبقى صفحاتٌ معلّقة من وضعٍ آخر: الشرائح تختفي من فوق حقل
      //    الكتابة، فبقاؤها في الحالة يعني إرسالَ أرقامٍ لا يراها الطالب.
      selectedPages.clear();
      // ↩️ و«صفحة» لا معنى لها خارج وضع الوحدات — واللوحة تُخفي محدّدها
      //    هنا، فتركُها يجعل حالةً مخفيّةً تحكم سلوكاً ظاهراً.
      inputType = "برومت";
    }
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

  // ══════════════════════════════════════════════════
  // ⚡ الشرحُ المخزون يُسحب **قبل أن يُطلب**
  // ══════════════════════════════════════════════════
  //
  // 🔴 **علّةُ المالك (2026-09-16):** «لما أضغط شرح المفروض على طول يطلع
  //    لي الشرح، ما ينتظر ثانيتين ولا ثلاثة — كما قسم الوزارة.»
  //
  // ⚖️ وقياسُ الخادم قال إن الشرحَ يُقرأ من القرص في **مللي ثانيةٍ واحدة**.
  //    فالانتظارُ لم يكن في الجواب بل في الطريق إليه: رحلةُ شبكةٍ من جهاز
  //    الطالب، ثم حرّاسُ `/ask`، ثم **خصمُ الحصة من Firestore ثم ردُّها**
  //    — معاملتان عبر الشبكة لطلبٍ لم يكلّف شيئاً أصلاً.
  //
  // 🎯 **فليُسحب لحظةَ اختيار الدرس**: يفتح الطالبُ اللوحة ويختار درساً،
  //    فيصل الشرحُ في الخلفية بينما هو يغلق اللوحة. ثم تكون الضغطةُ عرضاً
  //    من الذاكرة — **بلا رحلةِ شبكةٍ أصلاً**، وهو ما قاس عليه المالك.
  //
  // 🔒 و[TutorContentRepository.getStoredExplanation] لا تنادي موديلاً ولا
  //    تخصم حصة، فلا ضررَ في سحبها عند كل اختيار — ولا ترمي عند الفشل،
  //    فالسحبُ راحةٌ لا وظيفة: إن غاب مضى الطالبُ في `/ask` كما كان.
  //
  // 📍 **والنداءُ من `_safeNotify` لا من كل مكانٍ يُختار فيه درس**: مواضعُ
  //    الاختيار ستةٌ (اللوحة · الرابط العميق · نتيجةُ الاختبار · التحليل …)
  //    وواحدٌ منها يُنسى يعني ميزةً تعمل أحياناً — وهي أسوأُ من ميزةٍ لا
  //    تعمل. والحارسُ مقارنةُ نصٍّ واحدة، فلا كلفةَ لتكرارها.

  String _prefetchKey = "";        // آخرُ مفتاحٍ طُلب (كي لا يتكرّر النداء)
  String _prefetchedFor = "";      // مفتاحُ ما وصل فعلاً
  String _prefetchedAnswer = "";   // الشرحُ المخزون في اليد

  /// مفتاحُ الدرس الذي يصحّ له شرحٌ مخزون — أو فراغ.
  ///
  /// ⚠️ وضعُ الوحدات (`pages`) خارجَه: مدخلُه صفحاتٌ يختارها الطالب، فلا
  ///    شرحَ مخزونَ له أصلاً ([core/lesson_cache]).
  String get _explainScopeKey {
    if (isTeacher || selectedMode != "شرح") return "";
    if (selectedSubject == "رياضيات") {
      if (mathMode != "شرح" || selectedLesson.isEmpty) return "";
      return "$grade|${track.key}|رياضيات|$selectedMathBranch|$selectedLesson";
    }
    if (effectiveContentMode != "lessons" || selectedV3Lesson.isEmpty) return "";
    return "$grade|${track.key}|$selectedSubject|$selectedV3Unit|$selectedV3Lesson";
  }

  void _maybePrefetchExplanation() {
    final key = _explainScopeKey;
    if (key.isEmpty || key == _prefetchKey) return;
    _prefetchKey = key;
    unawaited(_pullStoredExplanation(key));
  }

  Future<void> _pullStoredExplanation(String key) async {
    final parts = key.split('|');
    if (parts.length != 5) return;
    final answer = await _content.getStoredExplanation(
        parts[2], parts[3], parts[4], int.tryParse(parts[0]) ?? grade, parts[1]);
    if (_disposed || answer.isEmpty) return;
    // ⏱️ وقد يكون الطالبُ بدّل درسَه أثناء الرحلة — فالنتيجةُ تُنسب لمفتاحها.
    _prefetchedFor = key;
    _prefetchedAnswer = answer;
  }

  /// الشرحُ المخزون الجاهز لهذه اللحظة — أو `null`.
  ///
  /// ⚠️ **وشرطُ «لا جوابَ قبله» هنا كما على الخادم** ([lesson_cache.serves]):
  ///    من شُرح له نصفُ الدرس ثم قال «اشرح الدرس» يريد متابعةً لا نسخةً
  ///    جاهزة — تلك حالةُ الموديل لا حالةُ المخزون.
  String? get _readyExplanation {
    if (_prefetchedAnswer.isEmpty) return null;
    if (_prefetchedFor.isEmpty || _prefetchedFor != _explainScopeKey) return null;
    if (_answerCount > 0) return null;
    return _prefetchedAnswer;
  }

  /// نصُّ المرجع كما يبنيه الخادم: «الوحدة › الدرس».
  String get _explainRef {
    final parts = _explainScopeKey.split('|');
    if (parts.length != 5) return "";
    return "${parts[3]} › ${parts[4]}".replaceAll(RegExp(r'^\s*›\s*'), '').trim();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
    _maybePrefetchExplanation();
  }

  // ========== مفتاح المحادثة الحالي ==========
  String getCurrentChatKey() => currentScopeKey;

  // ========== إيقاف الطلب الجاري ==========
  //
  // 🔴 **ما كان يحدث:** الضغط على «إيقاف» أثناء التحميل كان يقطع الاتصال
  //    ويرمي الردّ. لكن الخادم **لا يتوقف**: الحصة خُصمت بالفعل ونداءُ
  //    الموديل يمضي إلى نهايته ويُدفع ثمنه كاملاً — ثم يُلقى في القمامة.
  //    طالبٌ يضغط إيقاف عشر مرات = عشر مكالماتٍ مدفوعة بلا فائدة لأحد،
  //    وعشرُ حصصٍ خُصمت من يومه بلا أن يقرأ حرفاً.
  //
  // ✅ **والتفريق بين ثلاث حالاتٍ مختلفةٍ حقاً:**
  //    • أثناء **الأنيميشن** (الردّ وصل): إيقافٌ فوريّ للكتابة — النصّ
  //      كاملٌ أمامه أصلاً، وهذا هو الاستعمال الغالب للزر.
  //    • أثناء **التحميل** (الردّ لم يصل): لا نقطع الاتصال. نُخفي مؤشّر
  //      الانتظار ونترك الطلب يُكمل، فإذا وصل الجواب ظهر بلا أنيميشن
  //      وحُفظ. الحصةُ التي دُفعت تُشترى بها إجابة، لا فراغ.
  //    • أثناء **البثّ** (الردّ يصل الآن): نُثبّت ما وصل ونقطع — وهذه
  //      الحالة لم تكن محسوبة هنا أصلاً (راجع الشرح في المتن).
  void stopCurrentRequest() {
    final bool isAnimating = messages.isNotEmpty && messages.last["animating"] == true;
    if (!isLoading && !isStreaming && !isAnimating) return;

    // 1️⃣ الأنيميشن يتوقف فوراً في الحالتين (رصاصة الإيقاف).
    stopTypingNotifier.value = true;

    // 🌊 **البثُّ جارٍ** — حالةٌ ثالثة لم تكن محسوبة هنا إطلاقاً:
    //    `isLoading` مُطفأ منذ أول جزء، فكان الشرط أعلاه يخرج فوراً
    //    **ولا يوقف شيئاً**. أي أن الردّ المبثوث لم يكن يُوقَف أبداً.
    //
    // ✅ ونُثبّت ما وصل ولا نمحوه: الحصةُ دُفعت، والنصُّ الذي قرأه
    //    الطالب حتى الآن ملكُه. ثم نُغلق الاتصال فلا شيء بعده يُنتظر.
    if (isStreaming) {
      _isResponseCancelled = true;      // فلا يُكتب الجواب فوق ما ثبّتناه
      _quietlyAwaitingAnswer = false;
      _stream.cancel();
      _finalizePartialStream(suffix: "\n\n⏹️ *تم الإيقاف*");
      isLoading = false;
      _safeNotify();
      unawaited(saveCurrentConversation());
      onShowStopConfirmation?.call();
      return;
    }

    if (isLoading) {
      // 2️⃣ التحميل: نُسكت الواجهة ولا نقتل الطلب — راجع الشرح أعلاه.
      //    `_isResponseCancelled` يبقى `false` كي يُقبل الجواب حين يصل.
      _quietlyAwaitingAnswer = true;
      isLoading = false;
      _safeNotify();
      onShowStopConfirmation?.call();
      return;
    }

    // 3️⃣ الأنيميشن وحده: النصّ مكتملٌ في `fullText` فلا شيء يُنتظر.
    isLoading = false;
    _safeNotify();
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

    // 4. استرجاع المحادثة الجديدة (إن وجدت)
    String newKey = getCurrentChatKey();
    // ☢️ `List<Map<String, dynamic>>` صريحةً — نفسُ فخّ التغاير أعلاه
    //    ([loadConversation]): `List.from` بلا وسمٍ تستنتج نوعَ العناصر.
    messages = List<Map<String, dynamic>>.from(_allChatsHistory[newKey] ?? []);

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
    _endInFlightRequest();  // 🧹 نفسُ سبب [loadConversation] حرفياً
    // 📷 المرفق سياقُ المحادثة التي التُقط فيها — لا يعبر إلى غيرها.
    clearAttachments();
    currentConversationId = const Uuid().v4();
    messages = <Map<String, dynamic>>[];
    sessionActive = false;
    showSettingsPanel = true;
    _safeNotify();
  }

  /// 🔎 يفتح نتيجة بحثٍ قد تكون **من نطاقٍ آخر** (مادة/صف/وضع مختلف).
  ///
  /// 🔴 **ولماذا لا تكفي [loadConversation] وحدها:** هي تستعيد الرسائل
  ///    و`selectedMode` فقط، وتترك المادة والصف والمسار والفرع على ما كانت
  ///    عليه الشاشة. فطالبٌ يفتح — من نتيجة بحث — محادثة كيمياء وهو في
  ///    الفيزياء كان يرى رسائل الكيمياء بينما الشاشة تقول «فيزياء»؛ وأول
  ///    رسالةٍ يكتبها بعدها تُرسَل **بمادةٍ خاطئة** وتُحفظ في **نطاقٍ
  ///    خاطئ** — أي أن المحادثتين تختلطان بلا رجعة.
  ///
  /// ⚠️ ولذلك يُضبط النطاق **قبل** الاستعادة: `currentScopeKey` مشتقٌّ من
  ///    هذه الحقول، وهو ما يُحفظ به الرد التالي.
  Future<void> openFromSearch(ChatConversation conversation) async {
    // 1️⃣ احفظ ما هو مفتوح الآن قبل مغادرة نطاقه (وإلا ضاعت رسائل غير محفوظة).
    if (messages.isNotEmpty) await saveCurrentConversation();

    // 2️⃣ انقل الشاشة إلى نطاق المحادثة المطلوبة.
    grade = conversation.grade;
    track = Curriculum.normalizeTrack(grade, TrackLabel.fromKey(conversation.track));
    if (Curriculum.subjectsFor(grade, track).contains(conversation.subject)) {
      selectedSubject = conversation.subject;
    }
    if (conversation.subject == "رياضيات") {
      selectedMathBranch = conversation.branch;
      mathMode = conversation.mode;
    } else {
      selectedMode = conversation.mode;
    }

    // 3️⃣ أعد بناء قائمة المحادثات للنطاق الجديد ثم استعد المطلوبة.
    loadConversations();
    loadConversation(conversation);

    // 4️⃣ قوائم الوحدات/الدروس تتبع المادة — بلا هذا تبقى قوائم المادة السابقة.
    //    ⚠️ و**تُنتظَر** لا تُطلق: القرار في الخطوة ٥ يعتمد على نتيجتها.
    await loadCapabilities();
    if (_disposed) return;

    // 5️⃣ 🔴 **الدرس لا يُستعاد — لأن المحادثة لا تحفظه أصلاً.**
    //
    //    `ChatConversation` تحفظ (الصف · المسار · المادة · الفرع · الوضع)
    //    ولا تحفظ الوحدة ولا الدرس. فمحادثةٌ في «وضع الدروس» تعود بمادتها
    //    صحيحةً و`selectedV3Lesson` **فارغاً** (يمسحه `_resetV3Selection`).
    //
    //    ورأيتُ أثر ذلك في المحاكي: الطالب يفتح نتيجة بحثٍ من مادة أخرى،
    //    فتظهر البوصلة «انجليزي • القواعد» بلا درس — ولو أرسل رسالةً لذهبت
    //    باسم درسٍ فارغ، فيردّ الخادم «قيد الإضافة» على مادةٍ محتواها موجود.
    //    وهو أسوأ أنواع الأعطال: كل شيء يبدو سليماً والجواب وحده خاطئ.
    //
    // ✅ فنفتح لوحة الإعدادات ليختار درسه — تماماً كما تُفتح لمحادثةٍ جديدة
    //    في تلك المادة. سطرٌ واحد يحوّل حالةً مكسورة إلى خطوةٍ مفهومة.
    if (!isTeacher && effectiveContentMode == "lessons" && selectedV3Lesson.isEmpty) {
      showSettingsPanel = true;
      _safeNotify();
    }
  }

  // ══════════════════════════════════════════════════
  // 🧹 تبديلُ المحادثة يُنهي أيَّ طلبٍ جارٍ
  // ══════════════════════════════════════════════════
  //
  // 🔴 **شكوى المالك (2026-09-14) — «باغ خطير»:** «لو كتبت وأرسلت، نزلت
  //    من المحادثة ورجعت دخلت، وكتبت مرة ثانية — ما يرسل.»
  //
  //    و[ChatController] **كائنٌ واحدٌ يعيش بعد الشاشة**: فتحُ محادثةٍ كان
  //    يستبدل `messages` ولا يمسّ حالةَ الطلب. فمن غادر أثناء بثٍّ أو
  //    انتظار يعود و`isStreaming`/`isLoading` ما زالت `true` — و[isBusy]
  //    تُطفئ زرّ الإرسال **إلى الأبد**. ولا مخرجَ إلا إغلاق التطبيق.
  //
  // ☢️ وأسوأُ منه صمتاً: `_streamIndex` يبقى مشيراً إلى رسالةٍ في القائمة
  //    **القديمة**، فأيُّ جزءٍ متأخّر من البثّ يُكتب في محادثةٍ أخرى —
  //    أو يرمي `RangeError` إن كانت الجديدة أقصر.
  //
  // ⚖️ **ونقطع الاتصال ولا نتركه يُكمل**: الطالب غادر تلك المحادثة،
  //    وجوابُها لم يعد له مكانٌ يُكتب فيه.
  // ⏱️ **حارسٌ زمنيّ على الحالة المشغولة** — شبكةُ أمانٍ لكل الطرق الأخرى.
  //
  // 🔴 مهلةُ `ask_stream` مهلةُ **فتحِ** الاتصال (١٢٠ث) لا مهلةَ التدفّق
  //    بعده. فلو تجمّد البثّ في منتصفه — خلفيةُ الجوال، سقوطُ واي-فاي،
  //    وسيطٌ يقطع الصمت — بقي `await for` معلّقاً **إلى الأبد**، و`isBusy`
  //    معه، وزرُّ الإرسال ميتاً بلا مخرجٍ إلا إغلاق التطبيق.
  //
  // ⚖️ ولا مؤقّتَ دوريّ: الفحصُ يقع **لحظة يضغط الطالب إرسال** — هناك
  //    وحده يهمّ. وكلُّ جزءٍ يصل يُجدّد العمر، فلا يقطع طلباً حيّاً.
  static const Duration _busyCeiling = Duration(seconds: 150);
  DateTime? _busySince;

  bool get _busyLooksStale =>
      isBusy &&
      _busySince != null &&
      DateTime.now().difference(_busySince!) > _busyCeiling;

  void _markBusy() => _busySince = DateTime.now();

  void _endInFlightRequest() {
    if (!isBusy && _streamIndex == null && !_quietlyAwaitingAnswer) return;
    _isResponseCancelled = true;
    _quietlyAwaitingAnswer = false;
    _stream.cancel();
    _pending.clear();
    _streamIndex = null;
    isStreaming = false;
    isLoading = false;
    _busySince = null;
    stopTypingNotifier.value = true;
  }

  /// للاختبارات وحدها: يضع الحالةَ المشغولة التي كانت تُقفل الزرّ.
  @visibleForTesting
  void debugSetBusy({bool loading = false, bool streaming = false, int? streamIndex}) {
    isLoading = loading;
    isStreaming = streaming;
    _streamIndex = streamIndex;
  }

  /// للاختبارات وحدها: مؤشّرُ الرسالة التي يُكتب فيها البثّ.
  @visibleForTesting
  int? get debugStreamIndex => _streamIndex;

  /// يحمّل محادثة محفوظة (إغلاق الـ Drawer يتم في طبقة الويدجت).
  void loadConversation(ChatConversation conversation) {
    _endInFlightRequest();  // 🧹 وإلا بقي زرّ الإرسال مقفولاً ([_endInFlightRequest])
    clearAttachments();     // 📷 صورةُ محادثةٍ لا تُرسل في أخرى
    currentConversationId = conversation.id;
    // ☢️ **`<String, dynamic>` صريحةً — وهذا ليس تجميلاً.**
    //
    // 🔴 **عطلُ المالك «الخطير» (2026-09-14):** «كتبت وأرسلت، نزلت من
    //    المحادثة ورجعت دخلت، وكتبت مرة ثانية — ما يرسل.»
    //
    //    القائمةُ المعلَنة `List<Map<String, dynamic>>`، لكنّ دارت تستنتج
    //    من هذه الحرفيّة `Map<String, Object>` (لا قيمةَ فيها فارغة)،
    //    فيصير **النوعُ الحقيقي** للقائمة `List<Map<String, Object>>`.
    //    والإسنادُ يمرّ (تغايرُ الأنواع)، ثم أولُ
    //    `messages.add(<String, dynamic>{...})` يرمي في زمن التشغيل:
    //
    //      type '_Map<String, dynamic>' is not a subtype of
    //      type 'Map<String, Object>' of 'value'
    //
    //    والاستثناءُ يقع **قبل** إضافة فقاعة الطالب، وفي `async` بلا
    //    ممسك — فلا شيء يظهر على الشاشة ولا رسالةُ خطأ. زرُّ الإرسال
    //    يبدو سليماً ويعمل، ولا يحدث شيء أبداً.
    //
    // ⚠️ ولا تحذّر أداةُ التحليل منه: النوعان متوافقان عند الترجمة.
    messages = conversation.messages
        .map<Map<String, dynamic>>((m) => <String, dynamic>{
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
    // محادثةٌ فُتحت للتوّ ⇒ ابدأ من آخرها حتماً، ثم الالتصاق من جديد.
    stick.stick();
    scrollToBottom(force: true);
  }

  Future<void> saveCurrentConversation() async {
    if (currentConversationId == null || messages.isEmpty) return;
    // ✏️ **العنوانُ يُشتقّ مرّةً، ولا يُكتب فوق اسمٍ اختاره الطالب.**
    //
    // 🔴 كان يُشتقّ من `messages.first` في **كل** حفظ — والرسالةُ الأولى
    //    لا تتغيّر، فالعنوانُ المشتقُّ ثابت. ومعناه أن [renameConversation]
    //    **تُمحى عند أوّل سؤالٍ تالٍ**: يسمّيها الطالبُ «مراجعة الفيزياء»
    //    فتعود «اشرح لي قانون نيوتن» بعد رسالةٍ واحدة. وُجدت وأنا أضيف
    //    الزرَّ نفسَه في مساعد المنحة (2026-09-21) — والعلّةُ هنا أقدم.
    // 🔒 المحكومةُ بالمالك لا المطلقة — انضباطُ المخزن نفسُه.
    final stored = (ChatStorage.getOwnedConversation(
                currentConversationId!, ownerUid)
            ?.title ??
        '')
        .trim();
    String title = stored;
    if (title.isEmpty || title == 'محادثة جديدة') {
      title = messages.first['text'] ?? 'محادثة جديدة';
      if (title.length > 50) title = '${title.substring(0, 47)}...';
    }
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
    // 🧹 صورُ المحادثة تُحذف معها.
    //
    // 🔴 **تسريبٌ صامت:** الصور تُحفظ في `chat_images` على الجوال وحده،
    //    ولا أحد يحذفها. فمحادثةٌ حُذفت تترك ميجاباياتٍ من صور صفحاتٍ لا
    //    يراها أحد ولا يصل إليها شيء — تتراكم حتى يمتلئ جوال الطالب.
    for (final path in ChatStorage.getConversation(id)?.messages
            .expand((m) => m.allImages) ??
        const <String>[]) {
      unawaited(ImageService.I.delete(path));
    }
    await ChatStorage.deleteConversation(id);
    SyncService.I.deleteConversation(id);
    if (currentConversationId == id) createNewConversation();
    loadConversations();
  }

  /// ✏️ إعادة تسمية المحادثة.
  ///
  /// 🔴 **عطلٌ رآه المالك: «لما نعدّل الاسم تنحذف».** ولم تكن تُحذف — بل
  ///    **تصير يتيمة**. كانت الدالة تبني `ChatConversation` جديدةً بنسخ
  ///    الحقول حقلاً حقلاً، و`ownerUid` **لم يكن في القائمة** فيأخذ قيمته
  ///    الافتراضية `""`. وكلُّ استعلامات `ChatStorage` محكومةٌ بالمالك
  ///    (`_ownedBy`)، فتختفي من القائمة الجانبية عن **كل** حساب — ويراها
  ///    الطالبُ محذوفةً وهي قابعةٌ في الصندوق بلا مالك.
  ///
  /// ✅ **والعلاج ألّا تُنسخ أصلاً**: `title` حقلٌ غيرُ نهائيّ، فيُبدَّل
  ///    في مكانه وتُحفظ المحادثةُ نفسُها. نسخُ الحقول يدوياً يعني أن كل
  ///    حقلٍ يُضاف مستقبلاً سيسقط هنا بصمت — وهذا ما وقع بالضبط.
  Future<void> renameConversation(
      ChatConversation conversation, String newTitle) async {
    conversation.title = newTitle;
    await ChatStorage.saveConversation(conversation, ownerUid: ownerUid);
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
      // 📚 بلا «الكل» — راجع [_applyPagesUnits].
      availableUnits = [
        for (final unit in units)
          if (unit.isNotEmpty && unit != "الكل") unit,
      ];
      selectedUnit = availableUnits.isNotEmpty ? availableUnits.first : "";
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

  /// 📜 **الرسالة السابقة تُرسل كاملة — لا أولَ ١٥٠٠ حرفٍ منها.**
  ///
  /// 🔴 **قرار المالك (2026-09-14):** «موضوع إنه نأخذ أول ١٥٠٠ حرف من
  ///    الرسائل السابقة أنا لا أؤيد — خلّه ناخذ كل الرسالة، حتى كانت
  ///    ٢٠ ألف حرف، ناخذ كل الست رسائل اللي قبل.»
  ///
  ///    والسببُ وجيه: ردُّ شرحٍ كامل يبلغ ٨ آلاف حرف، فالقصُّ عند ١٥٠٠
  ///    كان يُسلّم الموديلَ **مقدّمة الشرح وحدها**. يسأل الطالب «وضّح
  ///    الخطوة السابعة» والموديلُ لم يرَ إلا الأولى والثانية.
  ///
  /// ⚖️ والجدارُ الوحيد الباقي دفاعيٌّ على الخادم (`HISTORY_MAX_CHARS`)
  ///    فوق أطولِ ردٍّ ممكن بمرّتين — يمنع حمولةً خبيثة ولا يمسّ محتوى.

  @visibleForTesting
  List<Map<String, String>> buildChatHistory() {
    // 🚫 **دورُ الرفض يُحذف من السجلّ — هو وسؤالُه.**
    //
    // 🔴 رُئي حرفياً في المحاكي (2026-09-14): سؤالٌ عن قانون نيوتن رُفض
    //    («ليس في وحدتك»)، ثم سأل الطالب عن الغدة النخامية — فجاء الجواب
    //    صحيحاً **ثم اعتذر عن قانون نيوتن**. الموديل رأى في السجلّ سؤالاً
    //    بلا جواب فحاول إكماله. والرفضُ يبقى معروضاً للطالب على الشاشة.
    final kept = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m["offTopic"] == true) {
        // نحذف السؤال الذي أثاره أيضاً — وإلا بقي معلّقاً بلا جواب.
        if (kept.isNotEmpty && (kept.last["role"] ?? "") == "user") {
          kept.removeLast();
        }
        continue;
      }
      kept.add(m);
    }
    final recent = kept.length <= historyLastN
        ? kept
        : kept.sublist(kept.length - historyLastN);
    return recent.map((m) {
      final own = (m["text"] ?? "").toString();
      final imageText = (m["imageText"] ?? "").toString();
      // ★ نصّ الصورة جزءٌ من سؤال الطالب في السياق — وإلا فقد المعنى بعده.
      final text = imageText.isEmpty
          ? own
          : (own.isEmpty ? imageText : "$own\n$imageText");
      return {
        // ☢️ **"ai" ليست دوراً يفهمه الخادم** — وهذا كان أخطر عطبٍ في
        //    المحادثة كلِّها (2026-09-14). التطبيق يخزّن ردَّ المساعد
        //    بـ`"role": "ai"`، والخادمُ يُصفّي في كل معالجٍ
        //    `role in ("user", "assistant")` — فكانت **ردودُ المساعد كلُّها
        //    تُحذف** قبل أن تصل الموديل.
        //
        //    فيرى الموديلُ ستَّ رسائلَ من الطالب بلا جوابٍ واحد بينها،
        //    فيقرؤها قائمةَ أسئلةٍ معلّقة ويجيب عنها كلِّها من جديد
        //    («يحسب إن الرسائل الست ضروري تنشرح»)؛ و«أعطني مثالاً» يصله
        //    بلا موضوعٍ سابق فيعتذر بـ«غير متوفرة في الكتاب».
        //
        // ⚖️ والخادمُ يُطبّع الدور أيضاً (`models.normalize_history`) لأن
        //    النسخَ المثبّتة على أجهزة الطلاب ستبقى ترسل "ai" شهوراً —
        //    وهنا نُصلح ما يخرج من عندنا اليوم.
        "role": (m["role"] ?? "user").toString() == "ai"
            ? "assistant"
            : (m["role"] ?? "user").toString(),
        "content": text,
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
    var text = customText ?? inputController.text.trim();

    final bool hasImage = hasAttachments;

    // 📄 وضعُ الصفحات: لا إرسال بلا اختيار — **ورسالةٌ تقول لماذا**.
    //    (طلب المالك: «إذا ما اخترت صفحات يقول له ما اخترت شي صفحات»)
    //
    // 📷 **إلا مع صورة:** من صوّر الصفحة بكاميرته لم ينسَ اختيارها — هو
    //    استغنى عنه. ورفضُه هنا كان يعني «اختر الصفحات أولاً» في وجه
    //    طالبٍ صفحتُه بين يديه بالفعل.
    if (canPickPages && selectedPages.isEmpty && customText == null && !hasImage) {
      onShowPagesRequired?.call();
      return;
    }
    // وضغطُ الإرسال بلا كتابةٍ طلبٌ كامل: «اشرح الصفحات الآتية».
    // 📄 صفحاتٌ مختارة بلا كتابة = «اشرح الصفحات الآتية» — إلا في وضع
    //    السؤال، فالسؤالُ يكتبه الطالب ([questionNeedsTypedText]).
    if (text.isEmpty && customText == null && !hasImage &&
        !questionNeedsTypedText &&
        canPickPages && selectedPages.isNotEmpty) {
      text = _defaultPagesPrompt;
    }

    bool isMathExplain = selectedSubject == "رياضيات" && mathMode == "شرح" && selectedLesson.isNotEmpty;
    // 🆕 وضع الدروس: اختيار الدرس يكفي لبدء الشرح بلا كتابة
    bool isV3LessonReady = effectiveContentMode == "lessons" &&
        selectedV3Lesson.isNotEmpty && !questionNeedsTypedText;

    // 👨‍🏫 ضغطُ زرّ الأداة طلبٌ كامل بلا نصّ مكتوب — كما «ابدأ الشرح» للطالب.
    if (text.isEmpty && customText == null && !isMathExplain && !isV3LessonReady
        && !hasImage && !teacherGenerate) {
      return;
    }

    // ✅ حماية 2: لا تسمح بطلبين معاً — **والبثُّ طلبٌ جارٍ** ([isBusy]).
    //
    // ⏱️ **إلا أن تكون الحالةُ المشغولة ميتة**: طلبٌ تجمّد ولم يُغلق يترك
    //    الزرَّ معطّلاً بلا مخرج. فنُنهيه ونمضي بدل أن نردّ الطالب بتحذير
    //    لا يستطيع فعل شيءٍ حياله ([_busyLooksStale]).
    if (isBusy) {
      if (!_busyLooksStale) {
        onShowBusyWarning?.call();
        return;
      }
      _endInFlightRequest();
      stopTypingNotifier.value = false;
    }

    // ══════════════════════════════════════════════════
    // 📷 من هنا فقط تُفرَّغ خانة الإرفاق — **بعد أن يُقطع بالإرسال**
    // ══════════════════════════════════════════════════
    // 🔴 **العطل:** كان التفريغ يسبق حارسَي «مشغول» و«لا نصّ»، فكلُّ ضغطةٍ
    //    مرفوضة تبتلع الصورة: يضغط الطالب، لا يحدث شيء، **وتختفي صورته**
    //    فيعود إلى المعرض من أوّله. الآن: إن رُفض الطلب بقي المرفق مكانه.
    //
    // ★ وحين يمضي الطلب يُفرَّغ **فوراً** لا بعد `await` — وإلا بقيت
    //   المعاينة معلّقةً فوق حقل الكتابة طوال الانتظار (علّةٌ سابقة).
    final List<PickedImage> sendingImages = List<PickedImage>.of(attachedImages);
    attachedImages.clear();

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
    _markBusy();
    // 🧾 معرّف هذه المحاولة — يثبت عبر إعادات المحاولة فلا تُخصم الحصة مرتين.
    _requestId = const Uuid().v4();
    // 📌 **الإرسال لا يسحب الشاشة** (قرار المالك 2026-09-09 — صريح):
    //
    //    كان هنا `stick.stick()` بحجّة أن «من كتب سؤالاً يريد أن يرى جوابه».
    //    وهو خطأ: الطالب يقرأ فقرةً في أعلى المحادثة، يخطر له سؤال، يكتبه
    //    ويرسله — فتقفز به الشاشة إلى الأسفل **وتضيع منه الفقرة التي كان
    //    فيها**. أي أن الإرسال يعاقبه على السؤال.
    //
    // ✅ فالسؤال ينزل أسفل، والجواب يُبثّ أسفل، **وهو يبقى حيث هو يقرأ**.
    //    وزرّ «الرد يُكتب…» يخبره أن في الأسفل جديداً، فينزل متى شاء.
    //    ومن كان في الأسفل أصلاً يتبع البثّ كالمعتاد — بلا تغيير.
    _safeNotify();

    scrollToBottom();

    // ══════════════════════════════════════════════════
    // ⚡ الشرحُ المخزون في اليد ⇒ يُعرض بلا رحلةِ شبكة
    // ══════════════════════════════════════════════════
    //
    // 🎯 هنا تتحقّق «على طول» التي طلبها المالك: سُحب الشرحُ لحظةَ اختيار
    //    الدرس ([_pullStoredExplanation])، فالضغطةُ لا تنتظر شيئاً.
    //
    // ⚖️ **وبعد إضافة رسالة الطالب لا قبلها**: المحادثة تُحفظ كاملةً
    //    (سؤالٌ ثم جواب)، فيمضي سؤالُه التالي إلى الموديل وفي سجلّه الشرحُ
    //    — وهو ما يجعل «يسأل مع الشرح حقه» يعمل بلا جلسةٍ على الخادم
    //    ([subjects/math._last_assistant_text]).
    //
    // 💳 ولا حصةَ تُخصم: الخادمُ نفسُه يردّها للشرح المخزون
    //    ([_dispatch_and_settle])، فتخطّي الرحلة لا يغيّر حساباً.
    if (!teacherGenerate && !hasImage && !questionNeedsTypedText &&
        (text.isEmpty || text == explainLessonText)) {
      final ready = _readyExplanation;
      if (ready != null) {
        isLoading = false;
        _busySince = null;
        messages.add({
          "role": "ai",
          "text": ready,
          "refs": _explainRef.isEmpty ? <String>[] : <String>[_explainRef],
          "cached": true,
          // ⌨️ ويُكتب كغيره تماماً — الفرقُ أنه يبدأ **من اللحظة الأولى**.
          "animating": true,
          "fullText": ready,
        });
        sessionActive = false;
        _safeNotify();
        scrollToBottom();
        // 🗄️ والحفظُ لا يحجب العرض: الشرحُ أمام الطالب قبل أن يلمس القرصَ
        //    أحد، وعطلُ التخزين لا يجوز أن يبتلع جواباً وصل.
        try {
          await saveCurrentConversation();
        } catch (_) {}
        return;
      }
    }

    // ==================================================
    // 🚀 الإرسال — بمحاولةٍ ثانيةٍ واحدة عند عطل شبكةٍ عابر
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

      // ══════════════════════════════════════════════════
      // 🌊 **البثّ في المسارين** — الشاشة واحدة فلا تجربتان
      // ══════════════════════════════════════════════════
      // قسم المعلّم يستعمل نفس شاشة الشات ونفس المتحكّم، فبقاؤه على الردّ
      // الواحد كان يعني معلّماً يحدّق في مؤشّرٍ صامت بينما الطالب يقرأ
      // جوابه ينساب. الفرق بينهما الآن الوجهةُ والحمولة لا غير.
      final AskResponse response = isTeacher
          ? await _askStreaming(
              url: ApiEndpoints.teacherAskStream(),
              requestId: _requestId,
              body: {
                "tool": teacherTool!.id,
                "generate": teacherGenerate,
                "subject": selectedSubject,
                "unit_name": selectedV3Unit,
                "lesson_name": selectedV3Lesson,
                "content": teacherGenerate ? "" : finalContentToSend,
                "concept": conceptController.text.trim(),
                "difficulty": teacherDifficulty,
                "count": teacherCount,
                "chat_history": chatHistory,
              },
              imagesBase64: sendingImages.map((e) => e.base64Data).toList(),
            )
          : await _askStreaming(
              url: ApiEndpoints.askStream(),
              requestId: _requestId,
              body: {
                "subject": selectedSubject,
                "mode": selectedMode,
                "input_type": inputType,
                "summary_level": summaryLevel,
                "lesson_name": finalLessonName,
                "content": finalContentToSend,
                "unit_name": (selectedSubject == "رياضيات")
                    ? selectedMathBranch
                    : (cMode == "lessons" ? selectedV3Unit : selectedUnit),
                "chat_history": chatHistory,
                if (cMode != null) "content_mode": cMode,
                // 📄 مفصولةً عن نصّ الطالب — فلا يلتقط الخادم رقماً عابراً
                //    من سؤاله ولا تضيع صفحاته في الرسالة التالية.
                // ⚠️ بالبوّابة لا بـ«القائمة غير فارغة»: الأخيرة تُرسل
                //    صفحاتٍ بقيت من وضعٍ سابق مع درسٍ لا علاقة له بها.
                if (canPickPages && selectedPages.isNotEmpty)
                  "selected_pages": selectedPages,
              },
              imagesBase64: sendingImages.map((e) => e.base64Data).toList(),
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
      // ⏸️ إن كان الطالب قد ضغط «إيقاف» أثناء الانتظار، يظهر الجواب
      //    مكتملاً بلا أنيميشن: هو لم يطلب حذفه بل طلب ألّا ينتظر.
      final bool quiet = _quietlyAwaitingAnswer;
      _quietlyAwaitingAnswer = false;

      // ⚡ آخر دفعةٍ لم يحن موعد سكبها بعد — تُسكب قبل التثبيت وإلا
      //    ضاعت الأحرف الأخيرة بين آخر سكبٍ ووصول `done`.
      _drainPending();

      if (_streamIndex != null) {
        // 🌊 **الفقاعة موجودة أصلاً** — أنشأها البثّ ونمت أمام الطالب.
        //    نُثبّت فيها النصّ **النهائي** (بعد تنظيف الخادم) والمراجع.
        //    ⚠️ ولا `messages.add` هنا: كانت ستُظهر الجواب **مرتين**.
        final m = messages[_streamIndex!];
        m["text"] = response.answer;
        m["fullText"] = response.answer;
        m["refs"] = response.references;
        m["streaming"] = false;
        m["animating"] = false;      // البثّ بديلٌ عن الطابعة لا يجتمعان
        if (response.offTopic) m["offTopic"] = true;
        // ⚡ وسمُ «من المحفوظ» — سؤالُ المالك: «ما أدري هل يجي من المخزون
        //    ولا لا». فالجوابُ يُرى على الفقاعة، ولا يُقاس بالإحساس.
        if (response.cached) m["cached"] = true;
        _streamIndex = null;
        isStreaming = false;
      } else {
        messages.add({
          "role": "ai",
          "text": response.answer,
          "refs": response.references,
          if (response.cached) "cached": true,
          // ⌨️ **والمخزونُ يُكتب كغيره** (تصحيحُ المالك 2026-09-16):
          //    «خلّه يطلع يكتب مثل الدروس الباقية وكأنه بثّ، بس توّه على
          //    طول بسرعة يكتب — يا إما تطبّق الشيء كامل يا إما لا.»
          //
          // ⚖️ وهو محقّ: الطابعةُ ليست إبطاءً بل **شكلَ الجواب في هذا
          //    التطبيق**. فجوابٌ يهبط كتلةً واحدةً يبدو غريباً عمّا حوله،
          //    والقارئُ يفقد موضعَه في نصٍّ ظهر دفعةً. الذي كان يزعج
          //    المالكَ هو **الانتظارُ قبل أول حرف** لا الكتابةُ نفسُها —
          //    وذاك صار صفراً بالسحب المسبق ([_readyExplanation]).
          "animating": !quiet,
          "fullText": response.answer,
          if (response.offTopic) "offTopic": true,
        });
      }
      sessionActive = response.sessionActive;
      _safeNotify();
      await saveCurrentConversation();
      scrollToBottom();

      // 🎟️ العدّاد يتحرّك فور نجاح السؤال — تقديرٌ محليّ بلا رحلة شبكة.
      //    وعند تجاوز الحصة نسأل الخادم فوراً كي يظهر «٠» لا رقمٌ قديم.
      if (response.quotaExceeded) {
        unawaited(QuotaRepository.I.refresh(force: true));
        onQuotaExceeded?.call(response.isGuest);
      } else if (!response.quotaRefunded) {
        QuotaRepository.I.consumeOne();
      }
    } catch (e) {
      // ══════════════════════════════════════════════
      // ❌ التصنيف: عطلُ شبكةٍ أم انقطاعُ نت أم غير ذلك؟
      // ══════════════════════════════════════════════
      // 🔴 **علّة حقيقية كانت هنا:** الصيغة السابقة أمسكت `SocketException`
      //    وحدها لرسالة «لا يوجد اتصال». لكن حزمة `http` على أندرويد ترمي
      //    `ClientException` في **معظم** أعطال الشبكة الفعلية — فكان الطالب
      //    الذي انقطع نتُّه يرى «حدث خطأ غير متوقع»، فيظنّ التطبيق معطوباً
      //    ويعيد المحاولة بلا أن يتفقّد اتصاله. `describeNetworkFailure`
      //    توحّد التصنيف في مكانٍ واحد ([ErrorMessages]).
      _quietlyAwaitingAnswer = false;
      // 🌊 فقاعةٌ بدأت ولم تكتمل: نُغلق حالتها فلا يبقى المؤشّر يومض إلى
      //    الأبد على ردٍّ توقّف — والنصّ الواصل يبقى معروضاً.
      _finalizePartialStream();
      if (!_disposed && !_isResponseCancelled) {
        isLoading = false;
        // 📷 **الصورة تعود إلى خانة الإرفاق** عند فشل الإرسال.
        //
        //    شبكةُ الطالب تتقطّع كثيراً، وكان كلُّ انقطاعٍ يعني رحلةً
        //    جديدة إلى الكاميرا أو المعرض. الآن: إعادةُ المحاولة ضغطةٌ
        //    واحدة. ونرفعها من الفقاعة الفاشلة في الوقت نفسه كي لا يبقى
        //    للملف مالكان — فلو حذفها من خانة الإرفاق بقيت الفقاعة
        //    تعرض ملفاً محذوفاً.
        if (sendingImages.isNotEmpty && attachedImages.isEmpty) {
          attachedImages.addAll(sendingImages);
          for (var i = messages.length - 1; i >= 0; i--) {
            if (messages[i]["role"] == "user") {
              messages[i].remove("images");
              break;
            }
          }
        }
        messages.add({
          "role": "ai",
          "text": ErrorMessages.forSendFailure(e),
          "refs": [],
          "animating": false,
          "isError": true,
          // ★ يسمح للواجهة بعرض زرّ «أعد المحاولة» على هذه الفقاعة وحدها.
          "canRetry": ErrorMessages.isRetryable(e),
        });
        _safeNotify();
        scrollToBottom();
      }
    } finally {
      // 🔪 تحرير موارد الاتصال
      _chat.cancel();
      _quietlyAwaitingAnswer = false;
      isStreaming = false;
      if (!_disposed) {
        isLoading = false;
        _safeNotify();
      }
    }
  }


  // ══════════════════════════════════════════════════
  // 🌊 الإرسال بالبثّ — الفقاعة تنمو أمام الطالب
  // ══════════════════════════════════════════════════
  // 🔴 **ما كان يحدث:** مؤشّر تحميل صامت حتى ٦٠ ثانية ثم النص دفعةً واحدة.
  //    وشرحُ درسٍ كامل يستغرق ٢٠–٤٠ ثانية، فالانتظار الصامت هو التجربة
  //    الغالبة لا الاستثناء.
  //
  // 📌 **والتمرير لا يُجبَر:** ننزل مع البثّ فقط إن كان الطالب في الأسفل
  //    أصلاً ([StickToBottom]). من صعد ليقرأ تبقى شاشته ساكنة تماماً.

  /// موضع فقاعة البثّ في [messages] — `null` حين لا بثّ جارٍ.
  int? _streamIndex;

  Future<AskResponse> _askStreaming({
    required String url,
    required String requestId,
    required Map<String, dynamic> body,
    List<String> imagesBase64 = const [],
  }) async {
    final token = await UserSession.I.idToken();

    Map<String, dynamic>? finished;
    String? failure;

    await for (final ev in _stream.open(
      url: Uri.parse(url),
      headers: ApiClient.authHeaders(token),
      timeout: AppConfig.askTimeout,
      body: {
        // 🔐 الهوية والنطاق يُضافان هنا لا في المُنادي — حقولٌ يجب أن
        //    ترافق **كل** طلب، ونسيانها في مسارٍ عطلٌ صامت.
        //    (والخادم يكتب `user_id` فوق ما نرسله على أي حال.)
        "user_id": userId,
        "request_id": requestId,
        "grade": grade,
        "track": track.key,
        ...body,
        if (imagesBase64.isNotEmpty) "images_base64": imagesBase64,
      },
    )) {
      if (_disposed) break;

      switch (ev) {
        case AskDelta(text: final piece):
          _appendStreamDelta(piece);
        case AskDone(payload: final p):
          finished = p;
        case AskFailure(message: final m):
          failure = m;
      }
    }

    if (failure != null && finished == null) {
      // 🛟 انقطاعٌ **بعد** وصول جزءٍ من الشرح: نُبقي ما وصل ونُلحق سبب
      //    التوقّف. حذفُه كان سيمحو نصّاً دُفع ثمنه وقرأه الطالب فعلاً.
      final partial = _streamIndex == null
          ? ""
          : (messages[_streamIndex!]["text"] ?? "").toString();
      if (partial.trim().isNotEmpty) {
        _finalizePartialStream(suffix: "\n\n$failure");
        return AskResponse(
          answer: messages.last["text"].toString(),
          references: const [],
          sessionActive: false,
        );
      }
      _finalizePartialStream();
      throw StreamInterrupted(failure);
    }

    return AskResponse.fromJson(finished ?? const {});
  }

  // ══════════════════════════════════════════════════
  // ⚡ تجميع الأجزاء — سببُ نعومة العرض
  // ══════════════════════════════════════════════════
  // 🔴 **علّة الأداء التي كانت تُحدث «تعليقاً» أثناء البثّ:** كل جزءٍ يصل
  //    كان يستدعي `notifyListeners` فوراً. والجزء الواحد من الموديل قد
  //    يكون **حرفين**، فشرحٌ من ٤٠٠٠ حرف يعني ~٥٠٠ إعادة بناء — وفي كل
  //    واحدة يُعيد `MasarMarkdown` تحليل **النصّ كاملاً** (وهو ينمو).
  //    فالكلفة تربيعية: ٥٠٠ × متوسط ٢٠٠٠ حرف = مليون حرف تُحلَّل، ومعها
  //    `jumpTo` خمسمئة مرة. النتيجة تلعثمٌ يزداد كلما طال الجواب.
  //
  // ✅ **الحل: نُجمّع ونرسم كل ٥٠ملّي** (~٢٠ إطاراً/ثانية). العين لا تفرّق
  //    — القراءة أبطأ من ذلك بكثير — والعمل ينخفض عشرة أضعاف.
  //
  // ⚠️ ولا نُطيلها أكثر: فوق ~١٠٠ملّي يبدأ النصّ يظهر «دفعات» لا انسياباً،
  //    فنخسر الإحساس الذي بُنيت الميزة لأجله.
  static const Duration _flushEvery = Duration(milliseconds: 50);

  final StringBuffer _pending = StringBuffer();
  Timer? _flushTimer;

  /// يُلغي المؤقّت ويسكب ما تبقّى فوراً.
  void _drainPending() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_streamIndex == null || _pending.isEmpty) {
      _pending.clear();
      return;
    }
    messages[_streamIndex!]["text"] =
        "${messages[_streamIndex!]["text"] ?? ""}${_pending.toString()}";
    _pending.clear();
  }

  /// يُلحق جزءاً جديداً بفقاعة البثّ — ويُنشئها عند أول جزء.
  void _appendStreamDelta(String piece) {
    if (piece.isEmpty) return;

    if (_streamIndex == null) {
      // ⏳ أول جزءٍ يصل ⇒ ينتهي الانتظار وتبدأ القراءة. ومن هنا يشعر
      //    الطالب أن الرد «بدأ» — وهي اللحظة التي كانت غائبة تماماً.
      //    وهذه وحدها تُرسم فوراً بلا تجميع: تأخيرُ ظهور الفقاعة يُبقي
      //    مؤشّر الانتظار لحظةً زائدة بلا سبب.
      isLoading = false;
      isStreaming = true;
      messages.add({
        "role": "ai",
        "text": "",
        "refs": const <String>[],
        "streaming": true,
        "animating": false,
      });
      _streamIndex = messages.length - 1;
      _safeNotify();
    }

    _markBusy();                 // ⏱️ جزءٌ وصل ⇒ الطلبُ حيّ
    _pending.write(piece);
    _flushTimer ??= Timer(_flushEvery, _flushStream);
  }

  /// يسكب المتراكم في الفقاعة ويرسم مرةً واحدة.
  void _flushStream() {
    _flushTimer = null;
    if (_disposed || _streamIndex == null || _pending.isEmpty) return;

    messages[_streamIndex!]["text"] =
        "${messages[_streamIndex!]["text"] ?? ""}${_pending.toString()}";
    _pending.clear();
    _safeNotify();

    // 📌 هنا القرار كله: نتبع الأسفل **إن كان الطالب هناك**، وإلا لا نلمس
    //    موضعه. و`jumpTo` لا `animateTo`: أنيميشن مع كل دفعةٍ يُلغي سابقه
    //    فيهتزّ العرض بلا توقّف.
    //
    // ⏱️ وبعد إطارٍ واحد: `maxScrollExtent` لا يعرف النصّ الجديد قبل أن
    //    يُخطَّط، فالقفز الفوري يقف **دون** آخر سطرٍ وصل ويتخلّف تدريجياً.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) scrollController.followBottom(stick);
    });
  }

  /// يُغلق فقاعة بثٍّ لم تكتمل — يوقف المؤشّر ويُبقي ما وصل.
  void _finalizePartialStream({String suffix = ""}) {
    _drainPending();
    isStreaming = false;
    final i = _streamIndex;
    _streamIndex = null;
    if (i == null || i >= messages.length) return;

    final m = messages[i];
    m["streaming"] = false;
    if (suffix.isNotEmpty) m["text"] = "${m["text"] ?? ""}$suffix";
    m["fullText"] = m["text"];
    _safeNotify();
  }

  // ========== التمرير للأسفل ==========
  //
  // 📌 **يحترم الالتصاق**: هذه تُنادى بعد كل رسالة وبعد الاستعادة، وكانت
  //    تنزل **دائماً**. مع البثّ صار ذلك يسحب الشاشة من تحت طالبٍ يقرأ
  //    في الأعلى — وهو بالضبط ما لا نريده.
  void scrollToBottom({bool force = false}) {
    if (!force && !stick.isStuck) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_disposed || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
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
    // 🪑 **قبل كل شيء**: المكانُ يُلتقط من حالةٍ حيّة، وما بعده يُفكّكها.
    _rememberPlace();
    SyncService.I.flushNow();   // لا تترك آخر رسالة معلّقة
    SyncService.I.revision.removeListener(_onRemoteConversations);
    UserSession.I.removeListener(_onSessionScopeChanged);
    _disposed = true;
    try {
      // 1. احفظ آخر محادثة
      if (currentConversationId != null && messages.isNotEmpty) {
        saveCurrentConversation();
      }
      // 2. ألغِ أي طلب شغال وأغلق الاتصال (العادي **والبثّ** معاً)
      _flushTimer?.cancel();
      _chat.cancel();
      _stream.cancel();
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
