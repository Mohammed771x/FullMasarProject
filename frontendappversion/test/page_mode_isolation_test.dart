// ==========================================
// 🚦 عزلُ وضع الصفحات — لا تختلط الصفحات بالدرس أبداً
// ==========================================
// 🔴 **ما كشفه المالك (2026-09-09):** «لو كنّا في وضع الوحدة واخترنا صفحة،
//    ثم رجعنا لوضع الدرس والصفحة ما غيّرناها — يظل نقدر نختار صفحة… أنا لو
//    أرسلت بترسل الصفحات وبيرسل الدرس».
//
// ⚖️ والسبب أن `canPickPages` كانت تسأل عن «صفحة/برومت» وحدها ولا تسأل عن
//    **مصدر المحتوى**. واللوحة تُخفي محدّد «صفحة/برومت» في وضع الدروس ولا
//    تُصفّره — فبقيت حالةٌ **مخفيّة** تحكم سلوكاً ظاهراً.
//
// 🎯 وهذه الاختبارات تمشي في **كل معبرٍ** بين الوضعين لا في واحد.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

SubjectCapabilities _caps() => SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {
        "available": true,
        "units": [
          {"unit": "الجهاز العصبي", "lessons": ["الخلية العصبية"]}
        ],
      },
      "pages": {
        "available": true,
        "units": ["الجهاز العصبي"],
        "unit_pages": {"الجهاز العصبي": [9, 10, 11]},
        "max_selectable": 3,
      },
    });

/// طالبٌ في وضع الوحدات وقد اختار صفحتين — نقطة البدء لكل معبر.
ChatController _inPagesModeWithPages() {
  final c = ChatController()
    ..selectedSubject = "احياء"
    ..selectedMode = "شرح"
    ..contentMode = "pages"
    ..selectedUnit = "الجهاز العصبي"
    ..caps = _caps();
  c.inputType = "صفحة";
  c.addPage(9);
  c.addPage(11);
  return c;
}

void main() {
  test('نقطة البدء سليمة: البوّابة مفتوحة والصفحات مختارة', () {
    final c = _inPagesModeWithPages();
    expect(c.canPickPages, isTrue);
    expect(c.selectedPages, [9, 11]);
  });

  group('🚪 كل معبرٍ يُغلق البوّابة ويُسقط الصفحات', () {
    test('⭐ الانتقال إلى وضع الدروس — العطل الذي شكا منه المالك', () {
      final c = _inPagesModeWithPages();
      c.setContentMode("lessons");

      expect(c.canPickPages, isFalse, reason: 'المُنتقي يجب أن يختفي');
      expect(c.selectedPages, isEmpty,
          reason: 'وإلا أُرسلت الصفحات مع الدرس معاً');
      expect(c.inputType, "برومت",
          reason: '«صفحة» حالةٌ مخفيّة خارج وضع الوحدات');
    });

    test('التبديل إلى «برومت» داخل وضع الوحدات', () {
      final c = _inPagesModeWithPages();
      c.inputType = "برومت";
      expect(c.canPickPages, isFalse);
      expect(c.selectedPages, isEmpty);
    });

    test('وضع «وزاري» يُخرج من أوضاع المحتوى كلّها', () {
      final c = _inPagesModeWithPages();
      c.selectedMode = "وزاري";
      // `usesContentModes` تصير false ⇒ `effectiveContentMode` null
      expect(c.canPickPages, isFalse);
    });

    test('مادةٌ بلا وضع وحدات (الرياضيات)', () {
      final c = _inPagesModeWithPages();
      c.selectedSubject = "رياضيات";
      expect(c.canPickPages, isFalse);
    });

    test('واجهة المعلّم لا وضعَ صفحاتٍ فيها', () {
      final c = _inPagesModeWithPages();
      c.teacherTool = TeacherTool.ask;   // ⇐ `isTeacher` مشتقّةٌ منها
      expect(c.canPickPages, isFalse);
    });

    test('مادةٌ لا وضع وحدات لها في بياناتها', () {
      final c = _inPagesModeWithPages();
      c.caps = SubjectCapabilities.fromJson({
        "subject": "س",
        "lessons": {"available": true, "units": []},
        "pages": {"available": false},
      });
      expect(c.canPickPages, isFalse);
    });
  });

  group('↩️ العودة لا تُحيي ما سقط', () {
    test('الرجوع إلى وضع الوحدات يبدأ بلا صفحات', () {
      final c = _inPagesModeWithPages();
      c.setContentMode("lessons");
      c.setContentMode("pages");

      expect(c.selectedPages, isEmpty);
      // ⚠️ و«برومت» تبقى حتى يختار الطالب «صفحة» بنفسه — لا نُعيده إلى
      //    وضعٍ لم يطلبه لمجرّد أنه كان فيه قبل قليل.
      expect(c.inputType, "برومت");
      expect(c.canPickPages, isFalse);

      c.inputType = "صفحة";
      expect(c.canPickPages, isTrue);
      expect(c.selectedPages, isEmpty);
    });
  });

  group('🧹 تغيّر النطاق', () {
    test('صفحاتٌ خارج الوحدة الجديدة تسقط', () {
      final c = _inPagesModeWithPages();
      c.caps = SubjectCapabilities.fromJson({
        "subject": "احياء",
        "lessons": {"available": false, "units": []},
        "pages": {
          "available": true,
          "units": ["وحدة أخرى"],
          "unit_pages": {"وحدة أخرى": [50, 51]},
        },
      });
      c.selectedUnit = "وحدة أخرى";
      c.selectedPages.removeWhere((p) => !c.availablePages.contains(p));
      expect(c.selectedPages, isEmpty);
    });
  });

  group('🚀 الإرسال بلا نصّ', () {
    test('يُسمح به في وضع الصفحات مع اختيار', () {
      expect(_inPagesModeWithPages().canSendWithoutText, isTrue);
    });

    test('ولا يُسمح به بعد الرجوع لوضع الدروس بلا درس', () {
      final c = _inPagesModeWithPages();
      c.setContentMode("lessons");
      c.selectedV3Lesson = "";
      expect(c.canSendWithoutText, isFalse);
    });
  });

  // ══════════════════════════════════════════════════
  // ❓ وضعُ السؤال يحتاج سؤالاً مكتوباً — في كل المواد
  // ══════════════════════════════════════════════════
  //
  // ⚖️ **قرار المالك (2026-09-14):** «في خانة السؤال ضروري الطالب يكتب
  //    سؤال… السؤالُ ليس الذي يشرح الدرس. فلا تخلّيه يقدر يضغط زرّ الإرسال
  //    بلا ما يكتب شي، في كل المواد.»
  //
  // 🔴 وما كان: الضغطُ بحقلٍ فارغ في وضع السؤال يُولّد طلباً من عندنا —
  //    «اطرح ملخصاً سريعاً…» أو «أجب من الصفحات الآتية» — فيخرج **شرحُ
  //    درسٍ كامل من وضع السؤال**، ويُخصم من حصّة الطالب.
  group('❓ وضعُ السؤال يحتاج سؤالاً', () {
    test('الإرسالُ الفارغ مغلقٌ مع درسٍ مختار', () {
      final c = ChatController()
        ..selectedSubject = "احياء"
        ..selectedMode = "سؤال"
        ..contentMode = "lessons"
        ..selectedV3Unit = "الجهاز العصبي"
        ..selectedV3Lesson = "الخلية العصبية"
        ..caps = _caps();
      addTearDown(c.dispose);
      expect(c.questionNeedsTypedText, isTrue);
      expect(c.canSendWithoutText, isFalse);
    });

    test('ومغلقٌ مع صفحاتٍ مختارة كذلك', () {
      final c = _inPagesModeWithPages();
      addTearDown(c.dispose);
      expect(c.canSendWithoutText, isTrue);   // وهو في وضع «شرح»
      c.selectedMode = "سؤال";
      expect(c.canSendWithoutText, isFalse);
    });

    test('ويعود مفتوحاً بمجرّد الرجوع لوضع الشرح', () {
      final c = _inPagesModeWithPages();
      addTearDown(c.dispose);
      c.selectedMode = "سؤال";
      expect(c.canSendWithoutText, isFalse);
      c.selectedMode = "شرح";
      expect(c.canSendWithoutText, isTrue);
    });

    test('والتلخيصُ لا يتأثّر — القيدُ على السؤال وحده', () {
      final c = _inPagesModeWithPages();
      addTearDown(c.dispose);
      c.selectedMode = "تلخيص";
      expect(c.questionNeedsTypedText, isFalse);
      expect(c.canSendWithoutText, isTrue);
    });

    test('وقسمُ المعلّم خارج هذا القيد', () {
      final c = ChatController()
        ..selectedSubject = "احياء"
        ..selectedMode = "سؤال"
        ..teacherTool = TeacherTool.ask;
      addTearDown(c.dispose);
      expect(c.questionNeedsTypedText, isFalse);
    });
  });
}
