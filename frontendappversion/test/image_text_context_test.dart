// 📄 نصّ الصورة يبقى في سياق المحادثة — في القسمين معاً.
//
// 🔴 **العلّة التي يحرسها هذا الملف:** تاريخ المحادثة يُرسل **نصّاً لا صوراً**.
//    فلو خُزّنت رسالة الطالب المصوّرة بنصّ «📷 صورة» فقط، ضاع محتوى الصورة
//    من السؤال التالي وصار المساعد يجيب على «وهل هذا يكفي؟» بلا مرجع.
//    ولو استعاد الطالب محادثته على جهاز جديد (والصورة لا تُرفع أصلاً) لصارت
//    المحادثة كلها بلا معنى.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/scholarships/data/models/scholarship_chat.dart';

void main() {
  const ocr = "[محتوى صورة أرسلها الطالب: الحد الأدنى للمعدل 70%]";

  group('🎓 رسالة مساعد المنحة', () {
    test('نصّ الصورة يدخل في السياق ولا يُعرض في الفقاعة', () {
      final m = SchMessage(
        role: "user",
        text: "هل معدلي يكفي؟",
        imagePaths: const ["/tmp/a.jpg"],
        imageText: ocr,
      );
      expect(m.text, "هل معدلي يكفي؟");        // المعروض نظيف
      expect(m.contextText, contains(ocr));     // والمُرسل يحمل الصورة
      expect(m.contextText, contains("هل معدلي يكفي؟"));
    });

    test('صورة بلا نص ⇒ السياق هو نصّ الصورة وحده', () {
      final m = SchMessage(role: "user", text: "📷 صورة", imageText: ocr);
      expect(m.contextText, contains(ocr));
    });

    test('بلا صورة ⇒ السياق هو النص كما هو', () {
      final m = SchMessage(role: "user", text: "متى الموعد؟");
      expect(m.contextText, "متى الموعد؟");
    });

    test('☁️ يُرفع مع المحادثة ويعود منها', () {
      final m = SchMessage(role: "user", text: "س", imageText: ocr);
      final back = SchMessage.fromMap(m.toMap());
      expect(back.imageText, ocr);
      // ⚠️ الصورة نفسها لا تُرفع أبداً — النصّ وحده ([27§3]).
      expect(m.toMap().containsKey("images"), isFalse);
    });

    test('الرسائل القديمة (بلا الحقل) تُقرأ بلا انهيار', () {
      final back = SchMessage.fromMap({"role": "user", "text": "قديمة"});
      expect(back.imageText, isEmpty);
      expect(back.contextText, "قديمة");
    });
  });

  group('📚 رسالة قسم التعليم', () {
    test('نصّ الصورة يدخل في السياق ولا يُعرض', () {
      final m = ChatMessage(
        role: "user",
        text: "اشرح لي هذه",
        imagePaths: const ["/tmp/b.jpg"],
        imageText: ocr,
      );
      expect(m.text, "اشرح لي هذه");
      expect(m.contextText, contains(ocr));
    });

    test('يُحفظ ويُقرأ من JSON', () {
      final m = ChatMessage(role: "user", text: "س", imageText: ocr);
      expect(ChatMessage.fromJson(m.toJson()).imageText, ocr);
    });

    test('الرسائل القديمة تبقى سليمة', () {
      final m = ChatMessage(role: "user", text: "قديمة");
      expect(m.imageText, isEmpty);
      expect(m.contextText, "قديمة");
    });
  });
}
