import 'package:flutter/foundation.dart';

// رسالة في محادثة مساعد المعلم (محفوظة بالذاكرة عبر التنقّل)
class TeacherMsg {
  final String role; // user | ai
  final String text;
  bool animate;
  TeacherMsg(this.role, this.text, {this.animate = false});
}

// ==========================================
// 🧠 حالة الديمو (محاكاة Firebase Auth + Firestore + Hive بالذاكرة)
// ==========================================
// كل شيء بالذاكرة — يُصفَّر عند إعادة تشغيل الديمو ليُعرض التدفق كاملاً كل مرة.
class DemoState extends ChangeNotifier {
  DemoState._();
  static final DemoState I = DemoState._();

  // ===== محادثات مساعد المعلم (كل ميزة لها سجلّها المستقل والمستمر) =====
  final Map<String, List<TeacherMsg>> teacherChats = {
    "plan": [],
    "simplify": [],
    "homework": [],
    "chat": [
      TeacherMsg("ai", "أهلاً أستاذ 👋 أنا مساعد المعلم من مسار.\nأساعدك في التخطيط للدروس، تبسيط المفاهيم، إعداد الواجبات، وأي سؤال تربوي. كيف أخدمك اليوم؟"),
      TeacherMsg("user", "كيف أجعل حصة الرياضيات أكثر تفاعلاً؟"),
      TeacherMsg("ai", "🤖 **(عرض تجريبي)** أفكار سريعة لزيادة التفاعل:\n\n- ابدأ بلغز رياضي قصير يشد الانتباه.\n- استخدم أمثلة من حياة الطالب (تسوّق، رياضة).\n- قسّم الطلاب لمجموعات صغيرة بمسابقة سريعة.\n- اختم بسؤال تحدٍّ للحصة القادمة.\n\nتريد خطة درس جاهزة على هذا الأساس؟"),
    ],
  };

  void addTeacherMsg(String key, TeacherMsg m) {
    teacherChats[key]!.add(m);
    notifyListeners();
  }

  // ===== الحساب (محاكاة Firebase Auth) =====
  bool loggedIn = false;
  bool isGuest = false;
  String name = "شاهد";
  String email = "shahed@masar.app";
  int grade = 3; // 1 | 2 | 3
  int guestQuestionsLeft = 5; // حد الزائر

  // ===== الإعدادات (محاكاة users/{uid}.settings) =====
  bool autoTts = false;
  double answerFontSize = 16;
  bool notifScholarships = true;
  bool notifGeneral = true;

  // ===== نشاط الطالب (محاكاة Hive) =====
  String? lastChatSubject;
  String? lastChatMode;
  DateTime? lastChatAt;
  final List<Map<String, String>> savedAnswers = []; // {subject, text}
  final List<Map<String, dynamic>> results = []; // {type, subject?, score, total, wrong:[..]}
  bool aptitudeDone = false;
  final Set<String> scholarshipReminders = {};

  // ===== الروبوت (محاكاة SharedPreferences robot_shown_*) =====
  final Set<String> robotIntroShown = {};

  String get gradeLabel => switch (grade) {
        1 => "الأول الثانوي",
        2 => "الثاني الثانوي",
        _ => "الثالث الثانوي",
      };

  String get greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return "صباح الخير";
    if (h >= 12 && h < 17) return "مساء النور";
    return "مساء الخير";
  }

  void signIn({required String name_, required String email_, required int grade_, bool guest = false}) {
    loggedIn = true;
    isGuest = guest;
    name = guest ? "زائر" : (name_.trim().isEmpty ? "طالب مسار" : name_.trim());
    email = email_;
    grade = grade_;
    guestQuestionsLeft = 5;
    notifyListeners();
  }

  void setGrade(int g) {
    grade = g;
    notifyListeners();
  }

  void recordChat(String subject, String mode) {
    lastChatSubject = subject;
    lastChatMode = mode;
    lastChatAt = DateTime.now();
    notifyListeners();
  }

  /// ينقص عداد الزائر. يرجع false إذا نفدت أسئلته.
  bool consumeGuestQuestion() {
    if (!isGuest) return true;
    if (guestQuestionsLeft <= 0) return false;
    guestQuestionsLeft--;
    notifyListeners();
    return guestQuestionsLeft >= 0;
  }

  void saveAnswer(String subject, String text) {
    savedAnswers.insert(0, {"subject": subject, "text": text});
    notifyListeners();
  }

  void addResult(Map<String, dynamic> r) {
    results.insert(0, r);
    if (r["type"] == "aptitude") aptitudeDone = true;
    notifyListeners();
  }

  void signOut() {
    loggedIn = false;
    isGuest = false;
    lastChatSubject = null;
    lastChatMode = null;
    lastChatAt = null;
    savedAnswers.clear();
    results.clear();
    aptitudeDone = false;
    scholarshipReminders.clear();
    robotIntroShown.clear();
    notifyListeners();
  }
}
