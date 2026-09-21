import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 🔁 ما سُئل عنه الطالبُ قريباً — كي لا يُعاد عليه
// ==========================================
//
// 🔴 **العطل من زاوية الطالب:** يختبر نفسَه في درسٍ، يرى نتيجته، فيعيد
//    الاختبار ليتحسّن — **فتأتيه الأسئلةُ العشرةُ نفسُها**. صار الاختبارُ
//    امتحانَ ذاكرةٍ لأسئلةٍ لا لفهمِ درس.
//
// ⚖️ **ولماذا على الجهاز لا على الخادم؟** (سؤالُ المالك عن التوسّع):
//    لو حفظها الخادمُ لاحتاج **حالةً لكل طالب**: قراءةٌ وكتابةٌ في كل اختبار،
//    والتصاقٌ بخادمٍ بعينه أو تنسيقٌ بين النسخ. وهي **ذاكرةُ راحةٍ لا أمان**
//    — أسوأُ ما يقع إن ضاعت أن يتكرّر سؤال. فبقاؤها في الجهاز يُبقي الخادمَ
//    **بلا حالة**، فيتوسّع أفقياً بنسخٍ متطابقةٍ لا تعرف بعضها.
//
// 📏 **وسقفُها ستّون معرّفاً** — أربعُ محاولاتٍ بخمسةَ عشرَ سؤالاً. وأبعدُ
//    من ذلك يفرّغ البنكَ من خياراته فيصير المنعُ ضرراً لا نفعاً
//    ([Backend/core/quiz_bank.SEEN_PENALTY] تُخفّض ولا تمنع لهذا السبب).
//
// 👤 ومربوطةٌ بالحساب وبالدرس معاً: جوّالٌ بحسابين لا يرث أحدُهما ذاكرةَ
//    الآخر، ودرسُ الأحياء لا يكتم أسئلةَ درسِ الفيزياء.
class QuizSeenStore {
  QuizSeenStore._();

  static const String _prefix = "quiz_seen_";
  static const int maxIds = 60;

  static String _key(String uid, String scope) => "$_prefix${uid}_$scope";

  /// مفتاحُ النطاق: المادة + الدروس المختارة مرتَّبةً (لا يتأثّر بترتيب الاختيار).
  static String scopeOf(String subject, List<String> lessons) {
    final names = [...lessons]..sort();
    return "$subject|${names.join('~')}";
  }

  static Future<List<String>> read(String uid, String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key(uid, scope)) ?? const [];
    } catch (_) {
      return const [];       // 🛟 عطلُ تخزينٍ لا يمنع اختباراً
    }
  }

  /// يضيف معرّفات اختبارٍ انتهى — **الأحدثُ أولاً** ثم يُقصّ عند السقف.
  static Future<void> remember(String uid, String scope, List<String> ids) async {
    final fresh = ids.where((e) => e.isNotEmpty).toList();
    if (fresh.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(uid, scope);
      final old = prefs.getStringList(key) ?? const [];
      final merged = <String>[...fresh];
      for (final id in old) {
        if (merged.length >= maxIds) break;
        if (!merged.contains(id)) merged.add(id);
      }
      await prefs.setStringList(key, merged.take(maxIds).toList());
    } catch (_) {
      // ذاكرةُ راحةٍ: فشلُ حفظها يعني تكرارَ سؤالٍ لا أكثر.
    }
  }

  static Future<void> clear(String uid, String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid, scope));
    } catch (_) {}
  }
}
