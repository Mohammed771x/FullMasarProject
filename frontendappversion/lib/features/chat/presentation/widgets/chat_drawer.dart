import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../data/conversation_search.dart';
import '../../../../core/widgets/search_hit_tile.dart';
import '../../data/models/chat_model.dart';
import '../controllers/chat_controller.dart';
import '../../../teacher/data/teacher_tool.dart';
import 'chat_dialogs.dart';
import '../../../banners/data/banner_model.dart';
import '../../../banners/presentation/banner_carousel.dart';
import '../../../future_masar/presentation/screens/notifications_screen.dart';
import '../../../future_masar/presentation/screens/settings_screen.dart';
import '../../../saved/presentation/saved_screen.dart';
import '../../../../core/notifications/notifications_repository.dart';
import '../../../../core/widgets/user_avatar.dart';

// ==========================================
// 📂 القائمة الجانبية
// ==========================================
// 🎨 **تصميم Figma** — `Frame 2147224834` (468:4290) · إحداثيات مطلقة:
//    اللوح 342×1024 · محتواه 310 عرضاً بهامش 16.
//    الرأس (16,23) 310×53 والشعار 57×45 في يمينه ·
//    «محادثة جديدة» (16,84) 310×52 r16 بتدرّج `#0092FF→#1D5783` ·
//    «الموارد» (16,144) 310×36 r8 · عنوان «اختر المادة الدراسية» 10/w700
//    `#62748E` · صفوفُ المواد 310×46 r8 (المختارة `#EFF6FF` بحدّ `#51A2FF`)
//    · «المحدثات» + شارةُ النطاق 136×27 r12 `#D9EFFF` ·
//    وصفوفُ المحادثات 311×64 r8 بزرَّي حذفٍ وتعديلٍ 27×27.
//
// ✅ **البحث أُبقي رغم غيابه عن التصميم** — ميزةٌ قائمة، وسبقَ أن رفعها
//    المالك إلى أعلى القائمة لعلّةٍ حقيقية (انظر [_searchField]).
class ChatDrawer extends StatefulWidget {
  const ChatDrawer({super.key, required this.controller, this.isHome = false});

  final ChatController controller;

  /// 🏠 هل الشاشةُ خلفَ هذا الدرج **بيتُ الدور**؟ (رئيسيةُ المعلّم في
  ///    التصميم الجديد هي الشاتُ نفسُه) — فلا شيءَ يُرجَع إليه، ويُخفى
  ///    زرُّ الخروج.
  final bool isHome;

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  /// 🔎 نصّ البحث الحالي — فارغٌ يعني «اعرض محادثات هذا القسم كالمعتاد».
  final TextEditingController _search = TextEditingController();
  String _query = "";

  ChatController get c => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 🌍 **البحث يتخطّى نطاق الشاشة عمداً.**
  ///
  /// القائمة العادية تعرض محادثات (الصف · المادة · الوضع) الحالي وحدها —
  /// وهذا صحيحٌ للتصفّح. لكن الطالب الباحث عن «الأكسدة» **لا يتذكّر في أي
  /// مادةٍ سألها**، وحصرُ البحث في القسم المفتوح كان سيُرجع «لا نتائج» عن
  /// محادثةٍ موجودةٍ عنده فعلاً. فالبحث على كل محادثات الحساب.
  ///
  /// 👨‍🏫 **لكن لا يعبر بين الدورين:** محادثاتُ المعلّم والطالب في صندوقٍ
  ///    واحد، ونتيجةُ «خطة درس» في درج الطالب كانت تُفتح في شاشته بمفتاحِ
  ///    معلّم (`openFromSearch` ينقل الوضعَ كما هو) — فيختلط السجلّان.
  List<ChatConversation> get _visible {
    if (!_searching) return c.conversations;
    final all = ChatStorage.getAllConversations(
      UserSession.I.uid,
      teacher: c.isTeacher,
    );
    return ConversationSearch.filter(all, _query);
  }

  bool get _searching => _query.trim().isNotEmpty;

  void _clearSearch() {
    _search.clear();
    setState(() => _query = "");
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width * 0.88,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: const BorderRadiusDirectional.horizontal(
            start: Radius.circular(26),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _header(),
                const SizedBox(height: 8),
                _newChatButton(context),
                const SizedBox(height: 8),
                _resourcesRow(context),
                const SizedBox(height: 8),
                // 🔎 **البحث ثابتٌ في الأعلى** لا داخل القائمة.
                //
                // 🔴 **علّة رآها المالك:** كان أسفل القائمة، فيلزم تمريرٌ
                //    طويل للوصول إليه — ثم يفتح الكيبورد **فيغطّيه هو
                //    ونتائجه**، فيكتب الطالب في حقلٍ لا يراه.
                _searchField(),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      // ⌨️ ارتفاع الكيبورد حشوةً سفلية: بدونه تبقى آخر
                      //    نتيجتين خلفه ولا سبيل للوصول إليهما.
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    // 🔎 **البحثُ يُخلي القائمةَ لنتائجه** (قرار المالك
                    //    ٢٠٢٦-٠٩-٢٤): كانت المواد ومنافذُ المعلّم ومبدّلُ
                    //    الصف فوق النتائج، فيكتب الطالبُ ولا يرى ما وجد إلا
                    //    بتمرير. والآن: حرفٌ واحد ⇒ النتائجُ وحدها، ومسحُ
                    //    النصّ ⇒ القائمةُ كما كانت.
                    children: _searching
                        ? [
                            ..._searchResults(context),
                          ]
                        : [
                            // 🎓 لا مُبدِّل صفٍّ ولا مسارٍ هنا (قرار المالك):
                            //    الصفُّ يُختار مرةً في الإعدادات ويرافق الحساب،
                            //    وتكرارُه في قائمةٍ تُفتح يومياً يُغري بتبديلٍ
                            //    عرَضيّ يقلب المحتوى كلَّه.
                            // 👨‍🏫 **منافذُ المعلّم** — ما كان في ترويسة شاشة
                            //    البوابة قبل أن يحلّ الشاتُ محلَّها. لم يرسمها
                            //    المصمّم في درج المعلم، فبُنيت بمفردته نفسِها
                            //    (`_OutlineRow` بارتفاع 46) ولم تُفقد.
                            if (c.isTeacher) ..._teacherEntries(context),
                            // 🎓 **مبدّلُ الصفّ — للمعلّم وحده** وهو في تصدير
                            //    درجه (`09-teacher/05`): ثلاثُ شرائحَ 41 r14،
                            //    المختارةُ مصمتةٌ بلون الهوية.
                            //
                            //    وهو محذوفٌ من درج الطالب بقرار المالك (يُختار
                            //    مرّةً في الإعدادات)، أمّا المعلّم فيدرّس ثلاثةَ
                            //    صفوفٍ في يومٍ واحد — فبقاؤه بعيداً عنه عبث.
                            if (c.isTeacher) ..._gradeSwitcher(),
                            _label("اختر المادة الدراسية"),
                            const SizedBox(height: 8),
                            ..._subjectRows(context),
                            const SizedBox(height: 16),
                            _label("المحادثات"),
                            const SizedBox(height: 8),
                            _scopeChip(),
                            const SizedBox(height: 8),
                            ..._conversationRows(context),
                            const SizedBox(height: 24),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── الرأس ─────────────────────────
  Widget _header() => SizedBox(
    height: 53,
    child: Row(
      children: [
        // 🌀 الشعار في **بداية** السطر (يمين RTL) كما في التصميم.
        const MasarLogo(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "مسار",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandInk,
                ),
              ),
              // 👨‍🏫 **سطرُ القسم** — «مساعد المعلم الذكي» في تصدير
              //    درج المعلم (`design/09-teacher/05`).
              Text(
                c.isTeacher ? "مساعد المعلم الذكي" : "سفير الطالب اليمني 🇾🇪",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cardHint,
                ),
              ),
            ],
          ),
        ),
        // 🆕 **الخروج من المحادثة.** ليس في التصميم — ورأسُ شاشة
        //    المحادثة عنده ثلاثةُ أزرارٍ لا رابعَ لها (قائمة · عنوان ·
        //    مصباح)، فلو وُضع هناك لأخلَّ بالنسخ الحرفيّ.
        //
        // 🔴 **ولا بدَّ منه:** الشاشة تُفتح ملءَ الشاشة من زرّ «مسار»،
        //    فلا شريطَ سفليّاً تحتها ولا سهمَ رجوع. ولا يبقى للطالب
        //    إلا سحبةُ الحافّة — وهي **نفسُ حافّة فتح هذه القائمة** في
        //    الواجهة العربية، فتتنازعان. جرّبتُها في المحاكي فنجحت،
        //    لكنّ ميزةً لا تُرى ليست ميزة.
        //
        // 🎨 وبلغة المصمّم نفسها: مربّعٌ 40 بنصف قطر 16 وحدٍّ فاتح —
        //    مواصفاتُ أزرار رأس المحادثة عنده حرفياً.
        // 🏠 **ولا يُعرض في بيت الدور**: رئيسيةُ المعلّم هي الشاتُ
        //    نفسُه، فلا شاشةَ تحته يُرجَع إليها — وزرٌّ يقفل التطبيق
        //    بلا قصدٍ أسوأُ من لا زرّ.
        if (!widget.isHome)
          _HomeButton(
            onTap: () {
              Navigator.pop(context); // القائمة
              Navigator.pop(context); // شاشة المحادثة
            },
          ),
      ],
    ),
  );

  // ─────────────────── محادثة جديدة (310×52 r16) ───────────────────
  Widget _newChatButton(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        c.createNewConversation();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.newChatGradient,
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PI.plus.bold, size: 19, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              "محادثة جديدة",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ─────────────────── الموارد ───────────────────
  // 📏 **46 لا 36** (ملاحظة المالك: «كبّرها عشان يشوفها الطالب»).
  //    و36 دون الحدّ الأدنى لمساحة اللمس (44) أصلاً، فالصفُّ كان صغيراً
  //    على العين وعلى الإصبع معاً. وصار بارتفاع صفوف المواد نفسه.
  Widget _resourcesRow(BuildContext context) => _OutlineRow(
    height: 46,
    onTap: () {
      Navigator.pop(context);
      ChatDialogs.showResources(context, grade: c.grade, track: c.track);
    },
    child: Row(
      children: [
        PDuo(PD.notebook, size: 22, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "الموارد",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Icon(PI.caretLeft.regular, size: 16, color: AppColors.dropdownCaret),
      ],
    ),
  );

  // ─────────────────── البحث ───────────────────
  // 🔎 **مربّعُ بحثٍ واحد** (ملاحظة المالك: «مربّعٌ داخل مربّع»).
  //
  // 🔴 سمةُ التطبيق العامّة (`inputDecorationTheme`) تملأ كلَّ حقلٍ بلونٍ
  //    رماديّ وترسم حوله `enabledBorder` مستديراً — و`border: none` وحدها
  //    **لا تنفيهما**. فظهر لوحٌ ثانٍ داخل الصندوق. تُنفى الأربعةُ صراحةً.
  //
  // 📏 و**46 لا 40** كبقيّة صفوف القائمة، فيراه الطالب ويصيبه إصبعُه.
  Widget _searchField() => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.rowBorder),
    ),
    child: Row(
      children: [
        Icon(PI.magnifyingGlass.bold, size: 19, color: AppColors.dropdownCaret),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: "ابحث في كل محادثاتك…",
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dropdownCaret,
              ),
            ),
          ),
        ),
        if (_query.isNotEmpty)
          InkWell(
            onTap: () {
              _clearSearch();
            },
            child: Icon(PI.x.bold, size: 15, color: AppColors.cardHint),
          ),
      ],
    ),
  );

  // ─────────────────── المواد (310×46 r8) ───────────────────
  List<Widget> _subjectRows(BuildContext context) => [
    for (final s in c.subjects) ...[
      Builder(
        builder: (_) {
          final sel = c.selectedSubject == s;
          final available = Curriculum.isAvailable(c.grade, c.track, s);
          return Opacity(
            opacity: available ? 1 : 0.5,
            child: _OutlineRow(
              // 📏 **52 لا 46** (ملاحظة المالك: «كبّرها شوية»).
              height: 52,
              selected: sel,
              onTap: () async {
                if (!available) return;
                await c.setSubject(s);
                if (context.mounted) Navigator.pop(context);
              },
              child: Row(
                children: [
                  // 🔤 حرفُ المادة الأول في مربّعٍ — كما في التصميم.
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primaryFill
                          : AppColors.primaryTintSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.characters.first,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: sel ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: sel ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!available)
                    Text(
                      "قريباً",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning900,
                      ),
                    )
                  else if (sel)
                    Icon(
                      PI.checkCircle.fill,
                      size: 19,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
    ],
  ];

  // ─────────────────── شارة النطاق (136×27 r12) ───────────────────
  Widget _scopeChip() {
    final mode = c.isTeacher
        ? c.teacherTool!.label
        : (c.selectedSubject == "رياضيات" ? c.mathMode : c.selectedMode);
    final text =
        "${c.selectedSubject} · $mode · "
        "${Curriculum.gradeShort(c.grade)}"
        "${Curriculum.hasTracks(c.grade) ? ' ${c.track.label}' : ''}";
    return Align(
      alignment: AlignmentDirectional.centerStart,
      // ⚠️ **بلا `alignment`**: `Container` ذو محاذاةٍ يتمدّد إلى أقصى
      //    القيد، فكانت الشارةُ تمتدّ عرضَ القائمة كلَّه بينما هي في
      //    التصميم 136 بمقدار نصّها. و`Row(min)` يقيسها على محتواها
      //    ويوسّطها رأسياً في الـ27 معاً.
      child: Container(
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.scopeSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.scopeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 📍 نتائجُ البحث — كما في ChatGPT ───────────────────
  // كلُّ موضعٍ ذُكرت فيه الكلمة: اسمُ المحادثة ومكانُها، ثم أسطرٌ من
  // الرسالة نفسها والكلمةُ مظلَّلة ([SearchHitTile]). واللمسُ يفتح المحادثة
  // **على تلك الرسالة** ([ChatController.revealMessage]).
  List<Widget> _searchResults(BuildContext context) {
    final all = ChatStorage.getAllConversations(UserSession.I.uid,
        teacher: c.isTeacher);
    final hits = searchHits<ChatConversation>(
      all,
      _query,
      titleOf: (conv) => conv.title,
      messagesOf: (conv) => [
        for (final m in conv.messages)
          SearchableMessage(m.text, isUser: m.role == "user"),
      ],
    );
    if (hits.isEmpty) return _conversationRows(context); // «لا نتائج» + العودة
    final conversations = hits.map((h) => h.conversation.id).toSet().length;
    return [
      _label(hits.length >= ConversationSearchHits.maxHits
          ? "نتائج البحث — أول ${hits.length} موضعاً"
          : "نتائج البحث — ${hits.length} في $conversations محادثة"),
      const SizedBox(height: 8),
      for (final h in hits)
        SearchHitTile(
          title: h.conversation.title,
          tag: "${h.conversation.subject} · "
              "${teacherModeLabel(h.conversation.mode)}",
          before: h.before,
          match: h.match,
          after: h.after,
          isUser: h.isUser,
          inTitleOnly: h.messageIndex < 0,
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
            c.openFromSearch(h.conversation,
                messageIndex: h.messageIndex, position: h.position);
          },
        ),
    ];
  }

  // ─────────────────── المحادثات (311×64 r8) ───────────────────
  List<Widget> _conversationRows(BuildContext context) {
    final items = _visible;
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            _searching
                ? "لا توجد محادثة تطابق «${_query.trim()}»."
                : "لا توجد محادثات في هذا القسم بعد.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.cardHint,
            ),
          ),
        ),
        // ↩️ لا نتائج ⇒ طريقٌ ظاهرٌ للعودة، لا «امسح النصّ» يُستنتج.
        if (_searching)
          Center(
            child: TextButton.icon(
              onPressed: _clearSearch,
              icon: Icon(
                PI.arrowRight.bold,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                "العودة إلى القائمة",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ];
    }
    return [
      for (final conv in items) ...[
        _OutlineRow(
          height: 64,
          selected: c.currentConversationId == conv.id,
          onTap: () {
            Navigator.pop(context);
            // 🌍 نتيجةُ بحثٍ قد تكون من مادةٍ أخرى — `openFromSearch` ينقل
            //    السياق كاملاً، و`loadConversation` يكفي داخل القسم نفسه.
            if (_query.trim().isEmpty) {
              c.loadConversation(conv);
            } else {
              c.openFromSearch(conv);
            }
          },
          child: Row(
            children: [
              Icon(
                PI.chatCircleDots.regular,
                size: 20,
                color: AppColors.dropdownCaret,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      conv.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // 🏷️ وضعُ المعلّم يُترجَم: `معلم:homework` مفتاحُ نطاق
                    //    لا نصُّ شاشة.
                    Text(
                      "${conv.subject} · ${teacherModeLabel(conv.mode)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.cardHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ✏️ 🗑️ زرّان 27×27 — تعديلُ الاسم وحذفُ المحادثة.
              _MiniAction(
                icon: PI.pencilSimple.regular,
                fill: AppColors.secondary100,
                border: AppColors.secondary200,
                ink: AppColors.secondary700,
                onTap: () => ChatDialogs.showRename(context, c, conv),
              ),
              const SizedBox(width: 6),
              _MiniAction(
                icon: PI.trash.regular,
                fill: AppColors.error100,
                border: AppColors.error200,
                ink: AppColors.error500,
                onTap: () =>
                    ChatDialogs.showDeleteConfirmation(context, c, conv.id),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  // ─────────────── منافذُ المعلّم (🆕) ───────────────
  List<Widget> _teacherEntries(BuildContext context) {
    final s = UserSession.I;
    return [
      _OutlineRow(
        height: 52,
        onTap: () => _go(context, const SettingsScreen()),
        child: Row(
          children: [
            UserAvatar(radius: 17, editable: false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  // 👨‍🏫 «أُدرّس …» لا «الصف …»: الصفُّ نفسُه والمعنى مختلف.
                  Text(
                    "أُدرّس ${Curriculum.gradeLabel(s.grade)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cardHint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PI.gear.regular, size: 18, color: AppColors.dropdownCaret),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _OutlineRow(
        height: 46,
        onTap: () => _go(context, const SavedScreen()),
        child: Row(
          children: [
            PDuo(PD.folderOpen, size: 22, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "المحفوظات",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              PI.caretLeft.regular,
              size: 16,
              color: AppColors.dropdownCaret,
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: NotificationsRepository.I,
        builder: (_, _) => _OutlineRow(
          height: 46,
          onTap: () => _go(context, const NotificationsScreen()),
          child: Row(
            children: [
              PDuo(PD.chat, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "الإشعارات",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (NotificationsRepository.I.hasUnread)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.error500,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                PI.caretLeft.regular,
                size: 16,
                color: AppColors.dropdownCaret,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      // 🎏 بانرُ قسم المعلم — كان في شاشة البوابة، ولا يرسم شيئاً حين لا بانر.
      BannerCarousel(
        section: BannerSection.teacher,
        onAction: (_, _) {},
        height: 100,
      ),
      const SizedBox(height: 8),
    ];
  }

  /// ⚠️ **يُلتقط `Navigator` قبل الإغلاق**: بعد `pop` يبدأ الدرجُ رحلةَ
  ///    الخروج وقد يُنزع ابنُه من الشجرة، فاستعمالُ سياقِه بعدها مخاطرة.
  Future<void> _go(BuildContext context, Widget screen) async {
    final nav = Navigator.of(context);
    nav.pop();
    await nav.push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  // ─────────────── مبدّلُ الصفّ (41 · r14) ───────────────
  List<Widget> _gradeSwitcher() => [
    _label("الصف الدراسي"),
    const SizedBox(height: 8),
    Row(
      children: [
        for (final g in const [1, 2, 3]) ...[
          Expanded(
            child: _GradeChip(
              label: Curriculum.gradeShort(g),
              selected: c.grade == g,
              onTap: () async {
                await c.setGrade(g);
                if (mounted) setState(() {});
              },
            ),
          ),
          if (g != 3) const SizedBox(width: 12),
        ],
      ],
    ),
    const SizedBox(height: 16),
  ];

  Widget _label(String t) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      t,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.sectionLabel,
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// ▭ صفٌّ محدَّد بحدٍّ — مفردةُ الدرج المتكرّرة
// ══════════════════════════════════════════════════
class _OutlineRow extends StatelessWidget {
  const _OutlineRow({
    required this.child,
    required this.onTap,
    required this.height,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.drawerRowSelected
              : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.drawerRowSelectedBorder
                : AppColors.rowBorder,
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// زرٌّ صغير 27×27 داخل صفّ المحادثة.
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.fill,
    required this.border,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final Color fill, border, ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 15, color: ink),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 🏠 زرّ العودة إلى الرئيسية — 40×40 r16 (مواصفات رأس المحادثة)
// ══════════════════════════════════════════════════
class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: "الرئيسية",
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rowBorder),
          ),
          child: Icon(
            PI.house.regular,
            size: 20,
            color: AppColors.primary990Ink,
          ),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 🎓 شريحةُ صفٍّ — 41 · r14 (تصدير درج المعلم)
// ══════════════════════════════════════════════════
class _GradeChip extends StatelessWidget {
  const _GradeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primaryFill : AppColors.surfaceWhite,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 41,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryFill : AppColors.quizCardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : AppColors.rowAction,
          ),
        ),
      ),
    ),
  );
}
