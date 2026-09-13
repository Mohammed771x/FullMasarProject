// 🛡️ حارس اللاتيك على الجهاز — لا يصل الطالبَ رمزٌ إنجليزي أبداً.
//
// 🔴 **ما رآه المالك:** شرح درسٍ في التكامل فيه «int» و«quad» و«left»
//    ككلماتٍ إنجليزية وسط نصٍّ عربي. ومسحُ ٦٤ شرحاً حقيقياً أثبت أنه ليس
//    نادراً: `\int` وحدها ٢٣ مرة.
//
// ⚖️ والحارس **على الجهاز** لازمٌ رغم وجود نظيره في الخادم: البثّ يسبق
//    التنظيف — الأجزاء تصل خاماً والخادم لا ينقّي إلا في `done`.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

void main() {
  group('🛡️ تحويل اللاتيك لا حذفه', () {
    test('🔴 `\\int` تصير ∫ لا «int»', () {
      // الحذف الأعمى كان يُخرج «تكامل د(س) دس» بلا علامة تكامل — وهي
      // أسوأ من كلمةٍ إنجليزية لأنها تبدو صحيحة.
      expect(stripUnsupportedLatex(r'\int د(س) دس'), '∫ د(س) دس');
    });

    test('أوامر التنسيق تُحذف ويبقى ما حولها', () {
      expect(stripUnsupportedLatex(r'\left( س \right)').trim(), '( س )');
      expect(stripUnsupportedLatex(r'أ \quad ب').replaceAll('  ', ' '),
          'أ  ب'.replaceAll('  ', ' '));
    });

    test('`\\text{كلام}` يبقى مضمونها', () {
      expect(stripUnsupportedLatex(r'\text{المشتقة} = ٢س'), 'المشتقة = ٢س');
    });

    test('⚠️ الأطول أولاً — `\\in` لا تلتهم بداية `\\infty`', () {
      expect(stripUnsupportedLatex(r'\infty'), '∞');
      expect(stripUnsupportedLatex(r'س \in ص'), 'س ∈ ص');
    });

    test('🛡️ ما يرسمه التطبيق لا يُمسّ', () {
      const keep = r'\frac{١}{س} و \sqrt{٤} و \chem{H2O} و \ring{بنزين}';
      expect(stripUnsupportedLatex(keep), keep);
    });

    test('🎯 أمرٌ مجهول يُحذف ولا يبقى إنجليزياً', () {
      // القائمة لا تحيط بكل LaTeX، وموديلٌ قد يخترع أمراً لم نره.
      expect(stripUnsupportedLatex(r'س \widehat{ب} ص'), contains('س'));
      expect(stripUnsupportedLatex(r'س \foobarbaz ص'), isNot(contains('foobar')));
    });

    test('🚀 نصٌّ بلا لاتيك يمرّ كما هو حرفياً', () {
      const plain = 'المشتقة الأولى للدالة هي ٢س + ٣.';
      expect(stripUnsupportedLatex(plain), same(plain));
    });

    test('📡 وسط البثّ: أمرٌ ناقص لا يُترك إنجليزياً', () {
      // الجزء قد يصل مقطوعاً — والمهمّ ألّا يظهر اسمٌ لاتيني.
      for (final partial in [r'التكامل \i', r'التكامل \in', r'التكامل \int']) {
        expect(stripUnsupportedLatex(partial), isNot(contains('int')),
            reason: 'تسرّب في «$partial»');
      }
    });
  });
}
