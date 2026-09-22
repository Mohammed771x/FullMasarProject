import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../../core/services/image_service.dart';
import '../controllers/chat_controller.dart';
import '../../../../core/media/image_editor_screen.dart';
import '../../../../core/widgets/voice_recording_bar.dart';
import '../../../../core/widgets/input_bar_metrics.dart';

// ==========================================
// ⌨️ خانة الكتابة وأزرار الإرسال/الإيقاف
// ==========================================
class ChatInputArea extends StatelessWidget {
  final ChatController controller;
  final VoidCallback onEmptyWarning;

  /// ⌨️ هل الكيبورد مرفوع؟ (يُقرأ فوق الـ`Scaffold` ويُمرَّر — هو يبتلع
  /// `viewInsets` عن جسمه.)
  final bool keyboardOpen;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.onEmptyWarning,
    this.keyboardOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ الدرس المختار وحده يكفي — كما تَعِد لوحة الإعدادات حرفياً.
    //
    // 📷 **والصورةُ وحدها تكفي كذلك** — وهذا عطلُ المالك (2026-09-13):
    //    كانت البوّابة تسأل عن نصٍّ مكتوب أو درسٍ مختار **ولا تسأل عن
    //    المرفق إطلاقاً**. فمن أرفق صورةً بلا كتابة وجد الزرّ رمادياً
    //    وردَّ عليه «اكتب سؤالك أولاً» — وصورةُ المسألة أمامه.
    //    وظهر الفرق بين محادثةٍ وأخرى لأن الدرس (لا الصورة) هو ما كان
    //    يفتح البوّابة: محادثةٌ جديدة اختير درسُها ⇒ تُرسل، ومحادثةٌ
    //    مستعادة من السجلّ لا يُستعاد درسُها ⇒ **الزرّ ميت**.
    //
    // 🚦 و`isBusy` لا `isLoading`: البثُّ طلبٌ جارٍ وإن أطفأ مؤشّر
    //    الانتظار — راجع [ChatController.isBusy].
    final bool canSend = (controller.inputController.text.trim().isNotEmpty ||
            controller.canSendWithoutText ||
            controller.hasAttachments) &&
        !controller.isBusy;
    final bool isGenerating = controller.isBusy || (controller.messages.isNotEmpty && controller.messages.last["animating"] == true);

    return Container(
      // ⌨️ **ملاصقٌ للكيبورد وقت الكتابة** (ملاحظة المالك): حشوةٌ سفليّةٌ
      //    24 تحت الحقل معناها شريطٌ يطفو بعيداً فوق الكيبورد ويأكل سطراً
      //    من المحادثة بلا فائدة. وهي 24 حين لا كيبورد (مساحةُ الإبهام).
      padding: EdgeInsets.fromLTRB(16, keyboardOpen ? 6 : 12, 16,
          keyboardOpen ? 6 : 24),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📄 **الصفحات المختارة ترتفع مع البرومبت** (قرار المالك 2026-09-09)
            //
            // 🔴 كان الرقم يُكتب داخل نصّ الرسالة، فيضيع في الرسالة التالية:
            //    من اختار ص٤٠ ثم سأل «وضّح أكثر» فقد صفحته بلا أن يدري.
            // ⭐ وموضعُها هنا — فوق حقل الكتابة لا داخل الإعدادات — يجعلها
            //    **مرئيةً وقتَ الكتابة**، فيعرف الطالب عمّا يسأل قبل الإرسال.
            // 🚦 بالبوّابة نفسها التي تحكم الإرسال — فلا تظهر شريحةٌ
            //    لا تُرسل، ولا تُرسل صفحةٌ لا تظهر.
            if (controller.canPickPages &&
                controller.selectedPages.isNotEmpty &&
                !controller.isRecording)
              _selectedPagesBar(context),
            // 📷 معاينة الصور المرفقة (حتى صورتين)
            if (controller.attachedImages.isNotEmpty && !controller.isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(controller.attachedImages.length, (i) {
                      final img = controller.attachedImages[i];
                      return Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // ضغطة على المعاينة تفتح المحرّر (قص + رسم)
                            InkWell(
                              onTap: () => _editImage(context, i, img),
                              borderRadius: BorderRadius.circular(14),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(img.path),
                                  width: 72, height: 72, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 72, height: 72, color: AppColors.softSurface,
                                    child: Icon(PI.imageBroken.regular,
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                            // شارة «عدّل»
                            Positioned(
                              bottom: 0, right: 0, left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(14)),
                                ),
                                child: const Text("عدّل",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 9.5, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            Positioned(
                              top: -6, left: -6,
                              child: InkWell(
                                onTap: () => controller.removeAttachedImage(i),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error500, shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.surfaceWhite, width: 2),
                                  ),
                                  child: Icon(PI.x.bold,
                                      color: Colors.white, size: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            // ══════════════════════════════════════════════════
            // ⌨️ شريط الكتابة — 342×56 · r24 · حدّ `#CAD5E2`
            // ══════════════════════════════════════════════════
            // 📐 مواصفات Figma (الرفيق الذاكي · 390:2048 عند y=740):
            //    الكاميرا (323) 36×36 · الحقل (109) 214×34 ·
            //    المايك (73) 36×36 · الإرسال (31) 42×42 دائرةٌ `#155DFC`.
            //    وترتيب RTL: الكاميرا يميناً والإرسالُ يساراً.
            //
            // ⛔ **زرّ الإعدادات (`tune`) أُزيل من هنا**: لوحة الجلسة صارت
            //    بطاقةً في أعلى الشاشة لها رأسٌ يطويها ويفتحها — فزرٌّ
            //    ثانٍ لنفس الوظيفة تكرار.
            if (controller.isRecording)
              VoiceRecordingBar(
                onDelete: () => controller.deleteVoiceRecording(),
                onStopToText: () => controller.stopVoiceToText(),
                onSend: () => controller.stopVoiceAndSend(),
              )
            else
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.inputBarBorder),
                  boxShadow: AppColors.bubbleShadow,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 📷 الكاميرا — تختفي عند بلوغ الحدّ الأقصى للمرفقات.
                    if (!isGenerating && controller.canAttachMore)
                      _RoundIcon(
                        icon: PI.camera.regular,
                        size: 36,
                        color: controller.attachedImages.isNotEmpty
                            ? AppColors.primary
                            : AppColors.inputBarIcon,
                        onTap: () => _pickImage(context),
                      )
                    else
                      const SizedBox(width: 36),
                    // 🧠 **وضعُ التفكير — أيقونةٌ لا شريحةٌ مكتوبة.**
                    //    جُرّبت شريحةً باسمها فأكلت ٨٠ نقطةً من عرض الكتابة،
                    //    وحكمُ المالك: «ما عجبنا مكانه… طول طول». فصارت
                    //    بحجم الكاميرا نفسِه (٣٦)، والشرحُ يظهر عند الضغط
                    //    لا يزاحم الحقلَ دائماً.
                    if (!isGenerating)
                      _RoundIcon(
                        icon: PI.brain(active: controller.thinking),
                        size: 36,
                        color: controller.thinking
                            ? AppColors.primary
                            : AppColors.inputBarIcon,
                        onTap: () => _pickThinking(context),
                      ),
                    Expanded(
                      child: TextField(
                        controller: controller.inputController,
                        // ⌨️ يبقى مفتوحاً أثناء البثّ: الطالب يُحضّر سؤاله
                        //    التالي وهو يقرأ. المنعُ على **الإرسال** وحده.
                        enabled:
                            !controller.isLoading || controller.messages.isEmpty,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => controller.refresh(),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inputBarText),
                        decoration: InputDecoration(
                          isDense: true,
                          // 🩹 **بلا تعبئة.** سمةُ التطبيق العامة
                          //    (`inputDecorationTheme`) تملأ كلَّ حقلٍ بلونٍ
                          //    رمادي، فظهر لوحٌ داخل الشريط الأبيض. وفي
                          //    التصميم الشريطُ **أبيضُ متّصل** من المايك إلى
                          //    الكاميرا — قِستُ بكسلاته: 255 بلا انقطاع.
                          filled: false,
                          hintText: controller.isCleaningVoice
                              ? "✨ جارٍ ترتيب النص..."
                              : "اسأل مسار أو اكتب مسألتك هنا...",
                          hintStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inputBarIcon),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          // ⚠️ **الأربعةُ جميعاً.** `border` وحدها لا تكفي:
                          //    فلاتر تأخذ `enabledBorder` و`focusedBorder`
                          //    من سمة التطبيق حين لا تُذكر هنا — فبقي إطارٌ
                          //    رماديٌّ مستديرٌ حول الحقل داخل الشريط الأبيض.
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) {
                          if (canSend) controller.processRequest();
                        },
                      ),
                    ),
                    // 🎤 المايك
                    if (!isGenerating)
                      controller.isCleaningVoice
                          ? SizedBox(
                              width: 36,
                              height: kInputSideBox,
                              child: Center(
                                child: SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation(
                                          AppColors.primary)),
                                ),
                              ),
                            )
                          : _RoundIcon(
                              icon: PI.microphone.regular,
                              size: 36,
                              color: AppColors.inputBarIcon,
                              onTap: () => controller.startVoiceRecording(),
                            ),
                    const SizedBox(width: 2),
                    // 🚀 الإرسال — دائرةٌ 42 ممتلئة. وتصير حمراء للإيقاف.
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isGenerating) {
                            controller.stopCurrentRequest();
                          } else if (canSend) {
                            controller.processRequest();
                          } else {
                            onEmptyWarning();
                          }
                        },
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            // 🎨 **المعطّل = 40% من لون الإرسال لا رماديّ.**
                            //    قِستُ بكسلة التصميم `#A1BEFE` فكانت حاصلَ
                            //    `#155DFC` بشفافية 0.4 فوق الأبيض بالضبط —
                            //    والمصمّم رسم الشريطَ فارغاً، فهذه حالةُ
                            //    «لا شيء لِيُرسَل» كما تخيّلها.
                            color: isGenerating
                                ? AppColors.error500
                                : AppColors.sendButton
                                    .withValues(alpha: canSend ? 1 : 0.4),
                            shape: BoxShape.circle,
                          ),
                          // ↔️ **يشير يساراً.** خطُّ Phosphor لا يُعكس مع
                          //    الاتجاه (ثوابتُه بلا `matchTextDirection`)،
                          //    والطائرةُ في التصميم تطير نحو يسار الشاشة.
                          child: Transform.scale(
                            scaleX: isGenerating ? 1 : -1,
                            child: Icon(
                              isGenerating
                                  ? PI.stopCircle.fill
                                  : PI.paperPlaneRight.fill,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// يفتح محرّر الصورة (قص + رسم) ويستبدل المرفق بالنتيجة.
  Future<void> _editImage(BuildContext context, int index, PickedImage img) async {
    final edited = await Navigator.push<PickedImage>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditorScreen(image: img)),
    );
    if (edited != null) controller.replaceImage(index, edited);
  }

  /// اختيار مصدر الصورة: كاميرا أو معرض.
  // ══════════════════════════════════════════════════
  // 🧠 وضعُ الإجابة — يُشرح حين يُسأل عنه
  // ══════════════════════════════════════════════════
  // ⚖️ **قرارُ المالك (2026-09-22):** «يطلع له إنه التفكير يحلّ مسائل
  //    معقّدة وقد يتأخّر… والعادي يعطيك نتائج بسرعة».
  //
  // 📏 والوصفُ ليس تزييناً — هو الفرقُ المقيس على ٣٣ مسألةَ فيزياءٍ
  //    وكيمياءَ محسوبةٍ باليد ×٣ إعادات: ٩٦٪ في ٠٫٨ث مقابل ١٠٠٪ في ١٫٥ث،
  //    وفي الشرح الطويل ٨٫٥ث مقابل ٢٠ث.
  void _pickThinking(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            _modeTile(
              ctx,
              icon: PI.lightning.regular,
              title: "عادي",
              subtitle: "إجاباتٌ سريعة — الأنسبُ للشرح والفهم",
              selected: !controller.thinking,
              onTap: () => controller.thinking ? controller.toggleThinking() : null,
            ),
            _modeTile(
              ctx,
              icon: PI.brain.regular,
              title: "تفكير",
              subtitle: "يتمهّل ليحلّ المسائل المعقّدة — أدقُّ وأبطأُ قليلاً",
              selected: controller.thinking,
              onTap: () => controller.thinking ? null : controller.toggleThinking(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _modeTile(BuildContext ctx,
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool selected,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon,
          color: selected ? AppColors.primary : AppColors.inputBarIcon),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      // ✅ علامةُ المختار — فالورقةُ تُقرأ بلمحة، ولا يُبدَّل وضعٌ بالخطأ
      trailing: selected
          ? Icon(PI.check.bold, size: 18, color: AppColors.primary)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  void _pickImage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            ListTile(
              leading: Icon(PI.camera.regular, color: AppColors.primary),
              title: const Text("التقاط صورة",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                controller.attachImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: Icon(PI.images.regular, color: AppColors.secondary),
              title: const Text("اختيار من المعرض",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                controller.attachImage(fromCamera: false);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  // ══════════════════════════════════════════════════
  // 📄 شريط الصفحات المختارة
  // ══════════════════════════════════════════════════
  Widget _selectedPagesBar(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.softSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PI.bookOpen.regular, size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text("الصفحات",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                ]),
              ),
              ...controller.selectedPages.map((p) => InputChip(
                    label: Text("$p",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: AppColors.primary,
                    // ⚠️ الحذف بضغطةٍ واحدة على الشريحة نفسها: الطالب يرفعها
                    //    وهو ينظر إليها، فلا يعود إلى الإعدادات ليلغي اختياراً.
                    deleteIcon: Icon(PI.x.bold,
                        size: 16, color: Colors.white),
                    onDeleted: () => controller.removePage(p),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide.none),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )),
            ],
          ),
        ),
      );

}

/// أيقونةٌ دائرية داخل شريط الكتابة — 36×36 كما في التصميم.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon(
      {required this.icon,
      required this.size,
      required this.color,
      required this.onTap});

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  /// 📐 **الارتفاع [kInputSideBox] لا [size]** — انظر شرحَ الثابت.
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: kInputSideBox,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      );
}
