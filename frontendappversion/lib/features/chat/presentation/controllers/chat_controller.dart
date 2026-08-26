import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/ask_response.dart';
import '../../data/models/chat_model.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/tutor_content_repository.dart';

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
  List<String> physicsLessons = [];
  List<String> chemistryLessons = [];
  String selectedChemistryLesson = "";
  List<String> arabicLessons = [];
  String selectedArabicLesson = "";
  List<String> englishLessons = [];
  String selectedEnglishLesson = "";
  String selectedPhysicsLesson = "";

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
  String selectedSubject = "احياء";
  String selectedMode = "شرح";
  String inputType = "برومت";
  String selectedUnitName = "الكل";
  int summaryLevel = 3;
  bool isLoading = false;
  bool sessionActive = false;
  bool mathWazariQuestionsLoaded = false;
  List<Map<String, dynamic>> messages = [];
  List<String> availableYears = [];
  final List<String> subjects = AppConstants.subjects;

  bool _isResponseCancelled = false;
  bool isMathExplanationStarted = false;

  // UI State
  bool showSettingsPanel = true;

  // ===== التهيئة =====
  Future<void> init() async {
    _deviceId = await SecureStorage.getOrCreateDeviceId();
    loadConversations();
    createNewConversation();
    await loadAvailableUnits();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ========== مفتاح المحادثة الحالي ==========
  String getCurrentChatKey() {
    if (selectedSubject == "رياضيات") {
      return "رياضيات_${selectedMathBranch}_$mathMode";
    } else {
      return "${selectedSubject}_$selectedMode";
    }
  }

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
      final list = await _content.getExamSections(subject, year);
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

  // ========== تحميل دروس الإنجليزي ==========
  Future<void> loadEnglishLessons(String unitName) async {
    try {
      final list = await _content.getLessons("انجليزي", unitName);
      if (_disposed) return;
      englishLessons = list;
      selectedEnglishLesson = "";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("حدث خطأ في السيرفر أثناء جلب دروس الإنجليزي.");
    } catch (e) {
      onShowDataError?.call("تأكد من اتصالك بالإنترنت لجلب الدروس.");
    }
  }

  // ========== تحميل دروس العربي ==========
  Future<void> loadArabicLessons(String unitName) async {
    try {
      final list = await _content.getLessons("عربي", unitName);
      if (_disposed) return;
      arabicLessons = list;
      selectedArabicLesson = "";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("حدث خطأ في السيرفر أثناء جلب دروس العربي.");
    } catch (e) {
      onShowDataError?.call("تأكد من اتصالك بالإنترنت لجلب الدروس.");
    }
  }

  // ========== تحميل دروس الفيزياء ==========
  Future<void> loadPhysicsLessons(String unitName) async {
    try {
      final list = await _content.getLessons("فيزياء", unitName);
      if (_disposed) return;
      physicsLessons = list;
      selectedPhysicsLesson = "";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب دروس الفيزياء.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال بالإنترنت.");
    }
  }

  // ========== تحميل دروس الكيمياء ==========
  Future<void> loadChemistryLessons(String unitName) async {
    try {
      final list = await _content.getLessons("كيمياء", unitName);
      if (_disposed) return;
      chemistryLessons = list;
      selectedChemistryLesson = "";
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب دروس الكيمياء.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال بالإنترنت.");
    }
  }

  // ========== تبديل السياق (تغيير المادة أو الوضع) ==========
  void switchContext(VoidCallback updateSettings) {
    // 1. حفظ المحادثة الحالية قبل الانتقال
    String currentKey = getCurrentChatKey();
    if (messages.isNotEmpty) _allChatsHistory[currentKey] = List.from(messages);

    // 2. تنفيذ التغيير (تغيير المادة أو الوضع)
    updateSettings();

    // ✅ 3. تصفير حالة زر شرح الرياضيات
    isMathExplanationStarted = false;

    // 4. استرجاع المحادثة الجديدة (إن وجدت)
    String newKey = getCurrentChatKey();
    messages = List.from(_allChatsHistory[newKey] ?? []);

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
    if (selectedSubject == "كيمياء") {
      chemistryLessons = [];
      selectedChemistryLesson = "";
    }

    // ✅ تصفير دروس الفيزياء لما تنقل
    if (selectedSubject == "فيزياء") {
      physicsLessons = [];
      selectedPhysicsLesson = "";
    }

    if (selectedSubject == "عربي") {
      arabicLessons = [];
      selectedArabicLesson = "";

      selectedArabicExamYear = "";
      selectedArabicExamSection = "";
    }

    if (selectedSubject == "انجليزي") {
      englishLessons = [];
      selectedEnglishLesson = "";
      selectedEnglishExamYear = "";
      selectedEnglishQuestionType = "";
    }

    _safeNotify();
    onRequestInstructions?.call(selectedSubject);
  }

  // ========== المحادثات (تخزين محلي) ==========
  void loadConversations() {
    conversations = ChatStorage.getConversationsBySubject(selectedSubject)
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
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
        .map((m) => {'role': m.role, 'text': m.text, 'refs': m.refs, 'animating': false})
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
        .map((m) => ChatMessage(role: m['role'], text: m['text'], refs: List<String>.from(m['refs'] ?? [])))
        .toList();
    final conversation = ChatConversation(
      id: currentConversationId!,
      title: title,
      subject: selectedSubject,
      mode: selectedMode,
      messages: chatMessages,
    );
    await ChatStorage.saveConversation(conversation);
    loadConversations();
  }

  Future<void> deleteConversation(String id) async {
    await ChatStorage.deleteConversation(id);
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
    );
    await ChatStorage.saveConversation(updated);
    loadConversations();
  }

  // ========== تحميل السنوات/الوحدات/الدروس ==========
  Future<void> loadAvailableYears() async {
    try {
      final list = await _content.getExamYears(selectedSubject);
      if (_disposed) return;
      availableYears = list..sort((a, b) => b.compareTo(a));
      _safeNotify();
    } on ServerException {
      onShowDataError?.call("تعذر جلب سنوات الاختبار. السيرفر مشغول.");
    } catch (e) {
      onShowDataError?.call("مشكلة في الاتصال أثناء جلب السنوات.");
    }
  }

  Future<void> loadMathLessons(String branch) async {
    try {
      final list = await _content.getMathLessons(branch);
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
      final list = await _content.getMathExamYears(branch);
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
      final list = await _content.getMathExamLessons(branch, year);
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
    try {
      final units = await _content.getUnits(selectedSubject);
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

  // ========== نظام البوصلة (تحديد مسار الطالب الحالي) ==========
  String _truncateText(String text, int maxWords) {
    if (text.isEmpty) return "";
    List<String> words = text.split(' ');
    if (words.length <= maxWords) return text;
    return "${words.take(maxWords).join(' ')}...";
  }

  String getCurrentLocationText() {
    List<String> path = [selectedSubject];

    if (selectedSubject == "رياضيات") {
      if (selectedMathBranch.isNotEmpty) path.add(selectedMathBranch);
      if (selectedLesson.isNotEmpty) path.add(_truncateText(selectedLesson, 4));
    } else {
      if (selectedUnit != "الكل" && selectedUnit.isNotEmpty) {
        path.add(_truncateText(selectedUnit, 3));
      }

      String currentLesson = "";
      if (selectedSubject == "فيزياء") {
        currentLesson = selectedPhysicsLesson;
      } else if (selectedSubject == "كيمياء") {
        currentLesson = selectedChemistryLesson;
      } else if (selectedSubject == "عربي") {
        currentLesson = selectedArabicLesson;
      } else if (selectedSubject == "انجليزي") {
        currentLesson = selectedEnglishLesson;
      }

      if (currentLesson.isNotEmpty) {
        path.add(_truncateText(currentLesson, 4));
      }
    }

    return path.join(' • ');
  }

  // ========== معالجة الطلب (إرسال السؤال للسيرفر) ==========
  Future<void> processRequest({String? customText}) async {
    // ✅ حماية 1: تحقق من الشروط الأساسية
    final text = customText ?? inputController.text.trim();

    bool isMathExplain = selectedSubject == "رياضيات" && mathMode == "شرح" && selectedLesson.isNotEmpty;

    if (text.isEmpty && customText == null && !isMathExplain) return;

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

    if (customText == null) {
      if (selectedSubject == "رياضيات" && mathMode == "شرح" && text.isEmpty) {
        messages.add({"role": "user", "text": "شرح درس: $selectedLesson"});
      } else {
        messages.add({"role": "user", "text": text});
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
      final chatHistory = messages.reversed
          .take(10)
          .map((m) => {"role": m["role"], "content": m["text"]})
          .toList()
          .reversed
          .toList();

      String finalContentToSend = text;
      String finalLessonName = "";

      if (selectedSubject == "فيزياء") {
        finalLessonName = selectedPhysicsLesson;
      } else if (selectedSubject == "كيمياء") {
        finalLessonName = selectedChemistryLesson;
      } else if (selectedSubject == "عربي") {
        finalLessonName = selectedArabicLesson;
      } else if (selectedSubject == "انجليزي") {
        finalLessonName = selectedEnglishLesson;
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

      final AskResponse response = await _chat.ask(
        userId: userId,
        code: AppConfig.accessCode, // 🔑 ثابت SUPER_USER (لمطابقة الباك)
        deviceId: _deviceId,
        subject: selectedSubject,
        mode: selectedMode,
        inputType: inputType,
        summaryLevel: summaryLevel,
        lessonName: finalLessonName,
        content: finalContentToSend,
        unitName: (selectedSubject == "رياضيات") ? selectedMathBranch : selectedUnit,
        chatHistory: chatHistory,
      );

      // إذا ضغط المستخدم على إيقاف أثناء التحميل
      if (_isResponseCancelled || _disposed) return;

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
