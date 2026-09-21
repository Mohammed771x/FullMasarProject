import 'package:flutter/material.dart';

import '../../../chat/presentation/widgets/mode_suggestions.dart';
import '../../../chat/presentation/controllers/chat_controller.dart';
import '../../data/teacher_tool.dart';

// ==========================================
// 💬 شرائح متابعة أداة المعلم
// ==========================================
// «أضف مثالاً من الحياة» · «اجعل النشاط مناسباً للمجموعات» — أُبقيت بطلب
// المالك، لكنها هنا **ليست زخرفة كما في الديمو**: كل شريحة تُرسل رسالةَ
// متابعة حقيقية عبر نفس مسار الكتابة، فيصلها الخادم ببرومبت المحادثة
// وبسياق ما وُلِّد قبلها — أي أنها تعدّل الخطة فعلاً لا تُنتج نصاً ثابتاً.
//
// ⚠️ **لا تظهر قبل أول رد** في أدوات التوليد الثلاث: شريحةٌ تقول «أضف مثالاً»
//    ولا شيء لتضيف إليه تُنتج رداً بلا معنى، وتُستهلك من حصة المعلّم بلا مقابل.
//
// ⭐ **إلا «اسأل المساعد»** — وهذا فرقٌ مقصود: لا زرّ توليد لها، فلو انتظرنا
//    أول رد لواجه المعلّمُ **شاشةً بيضاء بلا مدخل**. فشرائحها **بدايات** لا
//    متابعات («كيف أدير وقت الحصة؟»)، وتظهر فوراً.
// 🎨 **وشكلُها شكلُ شرائح الطالب حرفاً** ([SuggestionChip]): التصديرُ
//    يعرض الشريطين متطابقين، فمصدرٌ واحدٌ لهما لا نسختان تفترقان.
class TeacherSuggestionChips extends StatelessWidget {
  final ChatController controller;

  const TeacherSuggestionChips({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final tool = controller.teacherTool;
    if (tool == null) return const SizedBox.shrink();

    final busy = controller.isLoading ||
        (controller.messages.isNotEmpty && controller.messages.last["animating"] == true);
    if (busy) return const SizedBox.shrink();

    final hasAnswer = controller.messages.any((m) => m["role"] == "ai");
    if (!hasAnswer && tool.hasGenerate) return const SizedBox.shrink();

    final items = tool.suggestions;
    return SizedBox(
      height: SuggestionChip.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        // ⭐ `customText` لا `inputController`: تُرسل فوراً كما في أزرار
        //    «أكمل/إيقاف» لدى الطالب، بلا خطوة كتابةٍ زائدة.
        itemBuilder: (_, i) => SuggestionChip(
          label: items[i],
          featured: i == 0,
          onTap: () => controller.processRequest(customText: items[i]),
        ),
      ),
    );
  }
}
