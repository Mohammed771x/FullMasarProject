import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/masar_dialog.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../data/models/scholarship_chat.dart';
import '../controllers/scholarship_chat_controller.dart';
import 'scholarship_ui.dart';

// ==========================================
// 📂 سجلّ محادثات المنحة (Drawer)
// ==========================================
// ⭐ **الميزة التي كانت غائبة تماماً من الديمو.** الشات بلا سجلّ يعني أن
//    الطالب يفقد كل ما سأل عنه في كل مرة يغلق فيه الشاشة.
//
// السجلّ **مقصور على هذه المنحة وعلى هذا الحساب**: زميلك على جوّالك لا يرى
// أسئلتك، ومحادثات المنحة التركية لا تختلط بالماليزية.
//
// 🎨 **إعادة التصميم (2026-09-21):** من `design/06-scholarships/07-Group 1`:
//    عرضٌ 0.8 من الشاشة · شعارُ مسار يميناً في الرأس · زرُّ «محادثة جديدة»
//    52 بتدرّج الهوية · بطاقاتُ محادثةٍ 64 بحدٍّ `#F2F3F2` فيها مربّعُ
//    أيقونةٍ 32 يميناً وزرُّ حذفٍ 27 يساراً.
class ScholarshipChatDrawer extends StatelessWidget {
  final ScholarshipChatController controller;
  const ScholarshipChatDrawer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final list = controller.history;
    final current = controller.conversation?.id;

    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(left: BorderSide(color: AppColors.quizCardBorder)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            _newButton(context),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SchMetrics.cardPad),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text("المحادثات",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.headingInk)),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          SchMetrics.cardPad, 0, SchMetrics.cardPad, 12),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _tile(context, list[i], list[i].id == current),
                    ),
            ),
            if (list.isNotEmpty) _clearAll(context, list.length),
            if (UserSession.I.isGuest) _guestNote(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final s = controller.scholarship;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SchMetrics.cardPad, 16, SchMetrics.cardPad, 14),
      child: Row(
        children: [
          // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك الشعارُ في التصدير.
          const MasarLogo(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("محادثاتي",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.headingInk)),
                const SizedBox(height: 2),
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.schMutedInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _newButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SchMetrics.cardPad),
      child: Material(
        borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.newChat();
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            // 🎨 **تدرّجُ التصدير نفسُه** (علّةُ المالك 2026-09-21:
            //    «الألوان مش نفس ألوان التصميم»): قِستُ صفَّ البكسلات
            //    فكان من `#0193FF` يميناً إلى `#47779A` يساراً — لا
            //    `mainGradient` العامّ.
            decoration: BoxDecoration(
                gradient: AppColors.schDrawerGradient,
                borderRadius: BorderRadius.circular(SchMetrics.buttonRadius)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PI.plus.regular, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Text("محادثة جديدة",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => SchEmptyState(
        icon: PI.chat,
        text: "لا محادثات بعد مع هذه المنحة.\nاسأل سؤالك الأول وسيُحفظ هنا.",
      );

  Widget _tile(BuildContext context, SchConversation c, bool active) {
    return Material(
      color: active ? AppColors.schBlueFill : AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
      child: InkWell(
        onTap: () {
          controller.openConversation(c.id);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
            border: Border.all(
                color: active
                    ? AppColors.schBlueInk
                    : AppColors.quizCardBorder),
          ),
          child: Row(
            children: [
              // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك مربّعُ الأيقونة.
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.quizCardBorder),
                ),
                // 🎨 **ثنائيّةُ اللون كما في التصدير**: قِستُ داخلَ
                //    الفقاعة `#CCE2F2` على خطٍّ `#006EBF` — وهو نفسُ
                //    اللون بشفافية 0.20 بالضبط.
                child: PDuo(PD.chat, size: 17, color: AppColors.schBlueInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.schDrawerInk)),
                    const SizedBox(height: 3),
                    // ⭐ ليس في التصميم، ومع ذلك يبقى: «٣ أسئلة · قبل ساعة»
                    //    هو ما يميّز محادثةً عن أخرى حين تتشابه العناوين.
                    Text("${c.questionCount} سؤال · ${_ago(c.lastUpdated)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.schMutedInk)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ✏️ **التعديلُ قبل الحذف** — وفي RTL يعني ذلك أنه
              //    **يمينَه**، وهو موضعُه في التصدير بالضبط.
              _smallAction(
                icon: PD.pencilSimple,
                fill: AppColors.schEditFill,
                border: AppColors.schEditBorder,
                ink: AppColors.schEditInk,
                tooltip: "تعديل الاسم",
                onTap: () => _showRename(context, c),
              ),
              const SizedBox(width: 8),
              _smallAction(
                icon: PD.trashSimple,
                fill: AppColors.schDeleteFill,
                border: AppColors.schDeleteBorder,
                ink: AppColors.schDeleteInk,
                tooltip: "حذف",
                onTap: () => _confirmDelete(context, c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// زرٌّ صغير 27×27 — شكلُ أزرارِ البطاقة في التصدير.
  ///
  /// 📐 مقيسٌ من `07-Group 1`: مربّعٌ 27 بحدٍّ **مقيسٍ لا مشتقّ**
  ///    (كان `ink@0.35` تخميناً، والتصديرُ يقول `#F9BEBE` و`#C3CFEF`)،
  ///    وأيقونتُه **ثنائيةُ اللون**: جسمُ السلّة والقلم مملوءٌ بالحبر نفسه
  ///    بشفافية 0.20 — قِستُه فكان `#EEB9B9` على `#FCDFDF` بالضبط.
  Widget _smallAction({
    required PDIcon icon,
    required Color fill,
    required Color border,
    required Color ink,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: border),
              ),
              child: PDuo(icon, size: 15, color: ink),
            ),
          ),
        ),
      );

  /// ✏️ **تعديلُ اسم المحادثة** — نفسُ حوارِ قسم التعليم
  ///    (`chat_dialogs.showRename`).
  ///
  /// 🔴 **وهو حوارٌ ذو حالة، وقد كلّفني ذلك شاشةً حمراء.** كتبتُه أوّلاً
  ///    بمتحكّمٍ محلّيّ يُتلَف بعد `showDialog`:
  ///
  ///      final field = TextEditingController(…);
  ///      await showDialog(…);
  ///      field.dispose();          // ← هنا
  ///
  ///    و`showDialog` يعود **عند بدء حركة الإغلاق لا عند انتهائها**، فحقلُ
  ///    الكتابة ما يزال مركَّباً حين يُتلَف متحكّمُه — فرمى فلاتر
  ///    `_dependents.isEmpty is not true` وسقطت الشاشة كلُّها.
  ///    ⭐ ولم يكشفه `analyze` ولا اختبارٌ ولا نظرةٌ إلى اللقطة: ظهر في
  ///       المحاكي عند الضغط على «حفظ».
  ///
  /// ✅ فصار الحوارُ ودجتاً ذا حالة **يملك متحكّمَه**: يُتلَف في
  ///    `dispose` بعد أن يُفكَّك الحقلُ نفسُه — وهو الترتيبُ الوحيد الآمن.
  Future<void> _showRename(BuildContext context, SchConversation c) =>
      showDialog<void>(
        context: context,
        builder: (_) => _RenameDialog(controller: controller, conversation: c),
      );

  Future<void> _confirmDelete(BuildContext context, SchConversation c) async {
    await showDialog<void>(
      context: context,
      builder: (_) => MasarDialog(
        icon: PD.warning,
        iconTint: AppColors.quizWrongFill,
        iconInk: AppColors.quizWrong,
        title: "حذف المحادثة؟",
        primaryLabel: "حذف",
        primaryColor: AppColors.quizWrong,
        cancelLabel: "إلغاء",
        onPrimary: () async => controller.deleteConversation(c.id),
        child: Text("«${c.title}» — لا يمكن التراجع.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.7,
                fontWeight: FontWeight.w600,
                color: AppColors.chipInk)),
      ),
    );
  }

  Widget _clearAll(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SchMetrics.cardPad, 8, SchMetrics.cardPad, 12),
      child: TextButton.icon(
        onPressed: () async {
          // ⚠️ **الإغلاقُ بعد الحوار لا داخله.** `MasarDialog` يغلق نفسَه
          //    عقب `onPrimary`، فـ`pop` هناك يُطبق **الحوار** لا الدرج ثم
          //    يُطبق الدرجَ بالصدفة. فنُمسك القرار في راية ونُغلق بعده.
          var cleared = false;
          await showDialog<void>(
            context: context,
            builder: (_) => MasarDialog(
              icon: PD.warning,
              iconTint: AppColors.quizWrongFill,
              iconInk: AppColors.quizWrong,
              title: "مسح كل المحادثات؟",
              primaryLabel: "مسح",
              primaryColor: AppColors.quizWrong,
              cancelLabel: "إلغاء",
              onPrimary: () async {
                await controller.clearAll();
                cleared = true;
              },
              child: Text("ستُحذف $count محادثة مع هذه المنحة.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                      color: AppColors.chipInk)),
            ),
          );
          if (cleared && context.mounted) Navigator.pop(context);
        },
        icon: Icon(PI.trashSimple.regular, size: 17, color: AppColors.schMutedInk),
        label: Text("مسح كل المحادثات",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.schMutedInk)),
      ),
    );
  }

  /// ⚠️ صراحةٌ مع الزائر: محادثاته على الجهاز فقط ولا تُرفع — وحسابه مؤقت.
  Widget _guestNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.schTint,
          borderRadius: BorderRadius.circular(14)),
      child: Text(
        "🧪 أنت تتصفح كزائر — محادثاتك محفوظة على هذا الجهاز فقط.\n"
        "سجّل حساباً مجانياً لتعود معك على أي جهاز.",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11.5,
            height: 1.7,
            fontWeight: FontWeight.w600,
            color: AppColors.schTintInk),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return "الآن";
    if (d.inMinutes < 60) return "قبل ${d.inMinutes} د";
    if (d.inHours < 24) return "قبل ${d.inHours} س";
    if (d.inDays < 7) return "قبل ${d.inDays} يوم";
    return "${t.day}/${t.month}";
  }
}

/// ✏️ حوارُ تعديل اسم المحادثة — يملك متحكّمَ حقلِه (انظر [_showRename]).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.controller, required this.conversation});

  final ScholarshipChatController controller;
  final SchConversation conversation;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _field =
      TextEditingController(text: widget.conversation.title);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MasarDialog(
        icon: PD.pencilSimple,
        iconTint: AppColors.schEditFill,
        iconInk: AppColors.schEditInk,
        title: "تعديل أسم المحادثة",
        primaryLabel: "حفظ",
        cancelLabel: "إلغاء",
        onPrimary: () =>
            widget.controller.renameConversation(widget.conversation, _field.text),
        child: SizedBox(
          height: 52,
          child: TextField(
            controller: _field,
            // ⚠️ **سطرٌ واحدٌ لا يكبر مع الكتابة** — علّةُ المالك في
            //    التعليم: حقلٌ بلا سقفٍ يلتفّ فيطول الحوارُ تحت الإصبع.
            maxLines: 1,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: "اسم جديد…",
              hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.schMutedInk),
              filled: true,
              fillColor: AppColors.fieldFill,
              // ⚠️ صراحةً وإلا رسمت سمةُ التطبيق إطاراً لا وجودَ له
              //    في التصميم — وهو «مربّعٌ داخل مربّع» نفسُه.
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.4)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
          ),
        ),
      );
}
