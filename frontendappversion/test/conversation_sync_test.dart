// سياسات حجم التخزين السحابي ([27§6.2]) — الحساب بالبايت لا بعدد الرسائل.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/sync/conversation_sync.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';

ChatMessage _msg(String text, {String role = "assistant", List<String> images = const []}) =>
    ChatMessage(role: role, text: text, imagePaths: images);

ChatConversation _conv(List<ChatMessage> messages, {DateTime? updated, String id = "c1"}) =>
    ChatConversation(
      id: id,
      title: "محادثة",
      subject: "احياء",
      mode: "شرح",
      messages: messages,
      grade: 2,
      track: "علمي",
      lastUpdated: updated,
    );

void main() {
  group('سقف 200 كيلوبايت للمستند', () {
    test('محادثة صغيرة تمر كما هي', () {
      final msgs = List.generate(10, (i) => _msg("رسالة $i"));
      expect(ConversationSync.trimToByteBudget(msgs).length, 10);
    });

    test('تُقصّ الأقدم ويبقى الأحدث', () {
      // 3,000 حرف عربي ≈ 6 كيلوبايت (بايتان للحرف) ⇒ 60 رسالة تتجاوز السقف
      final msgs = List.generate(60, (i) => _msg("$i${"ب" * 3000}"));
      final kept = ConversationSync.trimToByteBudget(msgs);

      expect(kept.length, lessThan(msgs.length));
      expect(kept.last.text, msgs.last.text); // الأحدث باقٍ دائماً
      final bytes = kept.fold<int>(0, (n, m) => n + utf8.encode(m.text).length + 64);
      expect(bytes, lessThanOrEqualTo(ConversationSync.maxDocBytes));
    });

    test('الحرف العربي بايتان — الميزانية تُحسب بالبايت', () {
      final arabic = List.generate(40, (_) => _msg("ب" * 3000));
      final latin = List.generate(40, (_) => _msg("b" * 3000));
      // نفس عدد الحروف، لكن العربي ضعف الحجم ⇒ يُقصّ أكثر
      expect(ConversationSync.trimToByteBudget(arabic).length,
          lessThan(ConversationSync.trimToByteBudget(latin).length));
    });

    test('لا تُفرَّغ المحادثة مهما كبرت رسائلها', () {
      final huge = List.generate(5, (_) => _msg("ب" * 500000));
      expect(ConversationSync.trimToByteBudget(huge).length,
          ConversationSync.minKeptMessages);
    });
  });

  group('سقف 30 محادثة', () {
    test('يُختار الأحدث فقط', () {
      final now = DateTime(2026, 8, 27);
      final all = List.generate(
        50,
        (i) => _conv([_msg("م")], id: "c$i", updated: now.subtract(Duration(days: i))),
      );
      final picked = ConversationSync.selectForSync(all);

      expect(picked.length, ConversationSync.maxSyncedConversations);
      expect(picked.first.id, "c0");  // الأحدث
      expect(picked.map((c) => c.id), isNot(contains("c30"))); // الأقدم يبقى محلياً
    });

    test('أقل من الحد يمر كاملاً', () {
      final all = List.generate(7, (i) => _conv([_msg("م")], id: "c$i"));
      expect(ConversationSync.selectForSync(all).length, 7);
    });
  });

  group('مستند Firestore', () {
    test('يحمل scope_key وإلا اختلطت الصفوف عند الاستعادة', () {
      final doc = ConversationSync().toDoc(_conv([_msg("م")]));
      expect(doc["scope_key"], "g2|علمي|احياء||شرح");
      expect(doc["grade"], 2);
      expect(doc["track"], "علمي");
    });

    test('🖼️ الصور لا تُرفع — العدد فقط', () {
      final doc = ConversationSync()
          .toDoc(_conv([_msg("سؤال", role: "user", images: ["/a.jpg", "/b.jpg"])]));
      final m = (doc["messages"] as List).first as Map<String, dynamic>;

      expect(m["images_count"], 2);
      expect(m.containsKey("imagePaths"), isFalse);
      expect(jsonEncode(doc["messages"]), isNot(contains("/a.jpg")));
    });

    test('expires_at بعد 6 أشهر من آخر نشاط (سياسة TTL)', () {
      final updated = DateTime(2026, 1, 1);
      final doc = ConversationSync().toDoc(_conv([_msg("م")], updated: updated));
      final expires = (doc["expires_at"] as dynamic).toDate() as DateTime;

      expect(expires.difference(updated).inDays, ConversationSync.cloudRetention.inDays);
    });

    test('يُعلَّم المستند المقصوص بـ truncated', () {
      final small = ConversationSync().toDoc(_conv([_msg("م")]));
      expect(small["truncated"], isFalse);

      final big = ConversationSync().toDoc(_conv(List.generate(60, (_) => _msg("ب" * 3000))));
      expect(big["truncated"], isTrue);
    });
  });

  group('سقف عدد الرسائل (يطابق قاعدة الأمان)', () {
    test('رسائل كثيرة صغيرة تُقصّ إلى 400 — وإلا رفضتها القاعدة', () {
      final many = List.generate(1200, (i) => _msg("م$i"));
      final kept = ConversationSync.trimToByteBudget(many);

      expect(kept.length, ConversationSync.maxCloudMessages);
      expect(kept.last.text, "م1199"); // الأحدث باقٍ
    });

    test('المستند المبني لا يتجاوز السقف أبداً', () {
      final doc = ConversationSync().toDoc(_conv(List.generate(900, (i) => _msg("م$i"))));
      expect((doc["messages"] as List).length, lessThanOrEqualTo(400));
      expect(doc["truncated"], isTrue);
    });
  });

  group('ذهاب وعودة', () {
    test('المحادثة تعود بحقولها من مستند السحابة', () {
      final original = _conv([_msg("سؤال", role: "user"), _msg("جواب")]);
      final restored = ConversationSync.fromDoc(original.id, ConversationSync().toDoc(original));

      expect(restored.id, original.id);
      expect(restored.subject, original.subject);
      expect(restored.grade, original.grade);
      expect(restored.track, original.track);
      expect(restored.scopeKey, original.scopeKey);
      expect(restored.messages.length, 2);
      expect(restored.messages.last.text, "جواب");
    });

    test('مستند ناقص لا يُسقط الاستعادة', () {
      final restored = ConversationSync.fromDoc("x", {});
      expect(restored.id, "x");
      expect(restored.grade, 3);
      expect(restored.messages, isEmpty);
    });
  });
  cloudContextTests();
}

// ══════════════════════════════════════════════════
// 🧭 سياقُ الدرس يسافر إلى السحابة ويعود
// ══════════════════════════════════════════════════
//
// 🔴 **ثغرةٌ وُجدت في فحص Phase 2:** حقولُ (الوحدة · الدرس · وضع المحتوى)
//    أُضيفت إلى [ChatConversation] وإلى Hive، وسقط `toDoc`/`fromDoc` من
//    الحساب. فالقرصُ يحفظ السياق والسحابةُ لا — وطالبٌ أعاد تثبيت التطبيق
//    أو فتحه على جهازٍ ثانٍ تُستعاد محادثاتُه **من السحابة**، فتعود
//    بمادتها بلا درسها. أي أن العطل يعود من بابٍ آخر.
void cloudContextTests() {
  test('☢️ الوحدةُ والدرسُ ووضعُ المحتوى يعبرون المستند ذهاباً وإياباً', () {
    final conv = ChatConversation(
      id: "c-ctx",
      title: "شرح",
      subject: "احياء",
      mode: "شرح",
      grade: 3,
      track: "علمي",
      contentMode: "lessons",
      unit: "الجهاز العصبي",
      lesson: "الخلية العصبية",
      messages: [_msg("اشرح", role: "user")],
    );

    final doc = ConversationSync().toDoc(conv);
    expect(doc["unit"], "الجهاز العصبي");
    expect(doc["lesson"], "الخلية العصبية");
    expect(doc["content_mode"], "lessons");

    final back = ConversationSync.fromDoc("c-ctx", doc);
    expect(back.unit, "الجهاز العصبي",
        reason: '🔴 المحادثة تعود من السحابة بلا وحدتها');
    expect(back.lesson, "الخلية العصبية",
        reason: '🔴 المحادثة تعود من السحابة بلا درسها');
    expect(back.contentMode, "lessons");
  });

  test('🗄️ ومستندٌ قديم بلا هذه الحقول يُقرأ فارغاً لا منهاراً', () {
    final legacy = ConversationSync.fromDoc("c-old", {
      "title": "قديمة",
      "subject": "احياء",
      "mode": "شرح",
      "grade": 3,
      "track": "علمي",
      "messages": const [],
    });
    expect(legacy.unit, "");
    expect(legacy.lesson, "");
    expect(legacy.contentMode, "");
  });
}
