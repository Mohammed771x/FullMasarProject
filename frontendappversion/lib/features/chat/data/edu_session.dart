import 'package:flutter/foundation.dart';

import 'models/chat_model.dart';

// ==========================================
// 🪑 جلسةُ قسم التعليم — «المكانُ الذي تركتُه فيه»
// ==========================================
//
// 🔴 **طلبُ المالك (٢٠٢٦-٠٩-٢٢):** «لما نزلت من قسم التعليم ورجعت له،
//    المفروض يرجّعني للمحادثة اللي كنت آخر مرة فيها — مو أرجع أصير على
//    العربي من أول. خلّ فيه جلسة… إلا إذا نزلت من التطبيق ورجعت منه مرة
//    ثانية، هذا كلام ثاني.»
//
// 🧭 **والسببُ البنيويّ للعطل:** قسمُ التعليم شاشةٌ **تُدفع وتُنزع**
//    (`Navigator.push`) لا تبويبٌ يبقى حيّاً، و[ChatController] يُبنى معها
//    ويموت معها. فكلُّ فتحةٍ كانت بداية: `defaultSubject` (أوّلُ مادةٍ في
//    قائمة الصف) ومحادثةٌ فارغة — ولو كان الطالب قبل ثوانٍ في «فيزياء ·
//    وضع الدروس · الدرس الثالث» ومعه عشرون رسالة.
//
// ⚖️ **ولماذا في الذاكرة لا على القرص؟** حرفيّةُ الشرط أعلاه: الاستعادةُ
//    داخل تشغيلةِ التطبيق الواحدة، وإغلاقُ التطبيق يبدأ صفحةً بيضاء.
//    ولو كُتبت على القرص لصار إقلاعُ التطبيق يفتح آخرَ محادثةٍ دائماً —
//    وهو ما لم يطلبه، وفيه إزعاجٌ لمن أغلق التطبيق **ليخرج** من محادثة.
//
// 🔁 **وزرُّ «أكمل من حيث توقفت» يكتب هنا** (`rememberConversation`): تلك
//    هي وظيفتُه بالضبط — يقول للقسم «افتح هذه»، فيفتحها القسمُ بآليّته
//    نفسِها. وبها صار الزرُّ يعمل بعد أن كان يفتح القسمَ فارغاً.
//
// 🎓 **والنطاقُ حارسٌ لا زينة:** ما حُفظ لـ«ثاني علمي» لا يُستعاد لـ«ثالث
//    علمي». طالبٌ بدّل صفَّه يبدأ من موادِّ صفِّه الجديد — وإلا فُتحت له
//    مادةٌ لا يدرسها ومحادثةٌ من منهجٍ تركه.
@immutable
class EduPlace {
  const EduPlace({
    required this.uid,
    required this.grade,
    required this.track,
    required this.subject,
    required this.mode,
    this.mathBranch = "",
    this.mathMode = "",
    this.mathLesson = "",
    this.contentMode = "pages",
    this.unit = "",
    this.lesson = "",
    this.conversationId,
  });

  final String uid;
  final int grade;
  final String track;
  final String subject;

  /// وضعُ الطالب (`شرح`/`تلخيص`/`سؤال`/`وزاري`) — لا وضعُ معلّم.
  final String mode;

  final String mathBranch;
  final String mathMode;
  final String mathLesson;

  /// `lessons` أو `pages`.
  final String contentMode;
  final String unit;
  final String lesson;

  /// معرّفُ المحادثة المفتوحة — `null` لمحادثةٍ لم تُكتب فيها رسالة.
  final String? conversationId;

  bool matches(String uid_, int grade_, String track_) =>
      uid == uid_ && grade == grade_ && track == track_;
}

/// حاملُ آخر مكانٍ في قسم التعليم — **حيٌّ ما دام التطبيق حيّاً**.
class EduSession {
  EduSession._();
  static final EduSession I = EduSession._();

  EduPlace? place;

  /// 🧹 يُنسى المكان — تُستعمل في الاختبارات وعند تبديل الحساب.
  void clear() => place = null;

  /// 🔁 «أكمل من حيث توقفت»: محادثةٌ من المخزن تصير **وجهةَ** الفتحة التالية.
  ///
  /// ⚠️ **ولا تحمل وحدةً ولا درساً** — [ChatConversation] لا تحفظهما أصلاً
  ///    (نفسُ ما شرحته `openFromSearch`). فتُفتح اللوحةُ ليختار الطالبُ
  ///    درسَه، ولا يُرسَل طلبٌ بدرسٍ فارغ.
  void rememberConversation(ChatConversation c, String uid) {
    place = EduPlace(
      uid: uid,
      grade: c.grade,
      track: c.track,
      subject: c.subject,
      mode: c.subject == "رياضيات" ? "شرح" : c.mode,
      mathBranch: c.subject == "رياضيات" ? c.branch : "",
      mathMode: c.subject == "رياضيات" ? c.mode : "",
      conversationId: c.id,
    );
  }
}
