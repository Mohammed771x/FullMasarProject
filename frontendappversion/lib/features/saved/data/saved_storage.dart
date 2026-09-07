import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/session/grade_scope.dart';
import 'saved_answer.dart';

// ==========================================
// 💾 تخزين الإجابات المحفوظة (Hive)
// ==========================================
// 👤 كل استعلام محكوم بالمالك — جهاز واحد قد يتناوب عليه إخوة.
//
// 🎓 **وبالصف كذلك ([GradeScope]).** الحساب يرافق الطالب ثلاث سنوات، ومحفوظُ
//    سنةٍ لا مكان له في قائمة سنةٍ أخرى.
//
// ⚠️ **والسقف يبقى للحساب لا للصف**: `maxPerUser` يحرس ذاكرة الجهاز، وذاكرةُ
//    الجهاز واحدةٌ لا ثلاث. لو صار السقف لكل صفٍّ لصار الفعليّ ٦٠٠.
class SavedStorage {
  static const String _boxName = 'saved_answers';

  /// سقفٌ لكل حساب. المحفوظ نصٌّ خالص (~2 ك.ب) فالسقف كريم، لكنه موجود:
  /// صندوق بلا سقف ينمو أبداً على جهازٍ رخيص الذاكرة.
  static const int maxPerUser = 200;

  static Box<SavedAnswer>? _box;

  static Future<void> init() async {
    _registerAdapters();
    _box = await Hive.openBox<SavedAnswer>(_boxName);
  }

  @visibleForTesting
  static Future<void> initForTests(String path) async {
    Hive.init(path);
    _registerAdapters();
    _box = await Hive.openBox<SavedAnswer>(_boxName);
    await _box!.clear();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(SavedAnswerAdapter());
  }

  /// بصمة النصّ (FNV-1a 64) — ثابتة بين التشغيلات، بخلاف `hashCode` الذي
  /// لا تضمن دارت ثباته عبر الإصدارات فلا يصلح مفتاحاً مخزَّناً.
  static String fingerprint(String ownerUid, String text) {
    var hash = 0xcbf29ce484222325;
    for (final unit in '$ownerUid|${text.trim()}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static Iterable<SavedAnswer> _inScope(String ownerUid, GradeScope? scope) {
    final owned =
        (_box?.values ?? const <SavedAnswer>[]).where((a) => a.ownerUid == ownerUid);
    if (scope == null) return owned;
    return owned.where((a) => scope.includes(a.grade, a.track));
  }

  static bool isSaved(String ownerUid, String text) =>
      _box?.containsKey(fingerprint(ownerUid, text)) ?? false;

  /// يحفظ أو يزيل. يعيد الحالة **بعد** التبديل (true ⇒ صارت محفوظة).
  ///
  /// [scope] يُختم على المحفوظ ساعةَ الحفظ، فيبقى في سجلّ ذلك الصف وحده.
  static Future<bool> toggle({
    required String ownerUid,
    required String section,
    required String subject,
    required String text,
    GradeScope? scope,
  }) async {
    final box = _box;
    if (box == null) return false;

    final key = fingerprint(ownerUid, text);
    if (box.containsKey(key)) {
      await box.delete(key);
      return false;
    }
    await box.put(
      key,
      SavedAnswer(
        id: key,
        ownerUid: ownerUid,
        section: section,
        subject: subject,
        text: text,
        grade: scope?.grade ?? 0,
        track: scope?.track ?? "",
      ),
    );
    await _trim(ownerUid);
    return true;
  }

  /// المحفوظات من الأحدث إلى الأقدم. [scope] يقصرها على صفٍّ ومسار.
  static List<SavedAnswer> all(String ownerUid, {GradeScope? scope}) {
    final items = _inScope(ownerUid, scope).toList();
    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  static int count(String ownerUid, {GradeScope? scope}) =>
      _inScope(ownerUid, scope).length;

  static Future<void> remove(String id) async => _box?.delete(id);

  static Future<int> clear(String ownerUid, {GradeScope? scope}) async {
    final keys = all(ownerUid, scope: scope).map((a) => a.id).toList();
    await _box?.deleteAll(keys);
    return keys.length;
  }

  /// 🎓 ينسب المحفوظات التي لا صفَّ لها (نسخةٌ سابقة) إلى نطاق الطالب.
  ///
  /// يُنادى مرةً عند الدخول كما تُنادى `adoptOrphans` للمالك — وبعدها لا يبقى
  /// محفوظٌ بلا صف، فينتهي الاستثناء في [GradeScope.includes] طبيعياً.
  /// يعيد كم سجلّاً تبنّى.
  static Future<int> adoptScopeless(String ownerUid, GradeScope scope) async {
    if (ownerUid.isEmpty) return 0;
    final orphans = (_box?.values ?? const <SavedAnswer>[])
        .where((a) => a.ownerUid == ownerUid && a.grade == 0)
        .toList();
    for (final a in orphans) {
      a.grade = scope.grade;
      a.track = scope.track;
      await _box?.put(a.id, a);
    }
    return orphans.length;
  }

  /// ⚠️ **بلا نطاق عمداً** — السقف للحساب لا للصف (انظر رأس الملف).
  static Future<void> _trim(String ownerUid) async {
    final items = all(ownerUid);
    if (items.length <= maxPerUser) return;
    await _box?.deleteAll(items.skip(maxPerUser).map((a) => a.id));
  }
}
