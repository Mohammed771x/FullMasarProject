// 🎤 دمج التسجيل مع ما في الحقل — لا استبدال.
//
// 🔴 **السلوك الذي يحرسه:** كان التسجيل الثاني يمحو ما في الحقل. والطالب
//    يسجّل جملة، يقرأها، ثم يضغط المايك ليكمل — فيفقد كلامه الأول بلا إنذار.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/services/voice_text_merge.dart';

void main() {
  test('⭐ يُضاف لا يستبدل', () {
    expect(appendVoiceText("كم راتب المنحة", "وهل يشمل السكن"),
        "كم راتب المنحة وهل يشمل السكن");
  });

  test('الحقل فارغ ⇒ النص الجديد وحده', () {
    expect(appendVoiceText("", "كم الراتب"), "كم الراتب");
    expect(appendVoiceText("   ", "كم الراتب"), "كم الراتب");
  });

  test('لا مسافات مضاعفة', () {
    expect(appendVoiceText("كم الراتب   ", "  وهل يشمل السكن  "),
        "كم الراتب وهل يشمل السكن");
  });

  test('علامة الترقيم تبقى ولا تُفصل عن كلمتها', () {
    expect(appendVoiceText("ما الشروط؟", "وما الوثائق؟"),
        "ما الشروط؟ وما الوثائق؟");
  });

  test('تسجيل فارغ لا يغيّر شيئاً', () {
    expect(appendVoiceText("كلامي", ""), "كلامي");
    expect(appendVoiceText("كلامي", "   "), "كلامي");
  });

  test('يتراكم عبر تسجيلات متتالية', () {
    var t = "";
    for (final part in ["أول", "ثاني", "ثالث"]) {
      t = appendVoiceText(t, part);
    }
    expect(t, "أول ثاني ثالث");
  });
}
