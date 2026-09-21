// 🎓 قسم «المنح» بعد إعادة التصميم (٢٠٢٦-٠٩-٢١).
//
// 🎯 **عقدُ المشروع:** «الموضع يتغيّر · الوظيفة لا». وإعادةُ رسمِ خمسِ
//    شاشاتٍ دفعةً واحدة هي **أخطرُ لحظةٍ على الأزرار**: زرٌّ يسقط أثناء
//    إعادة الكتابة لا يُسقط `analyze` ولا اختباراً وظيفياً — ولا يُرى إلا
//    حين يبحث عنه الطالب فلا يجده.
//
// 🛡️ **ولماذا حرّاسٌ بنيويّة على الملفات؟** بناءُ هذه الشاشات يستدعي شبكةً
//    وتخزيناً وHive وجلسةَ مستخدم؛ وحارسٌ لا يعمل إلا بمحاكاة نصف التطبيق
//    يُعطَّل عند أوّل تغيير فيصير أخضرَ على عيبٍ قائم. فتُحرس **قطعُ اللغة
//    البصرية** باختبارات ويدجت حقيقية، و**بقاءُ النداءات** بقراءة الملفّ.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/core/widgets/input_bar_metrics.dart';
import 'package:ye_student_tutor/features/scholarships/data/models/scholarship_chat.dart';
import 'package:ye_student_tutor/core/widgets/phosphor.dart';
import 'package:ye_student_tutor/features/scholarships/presentation/widgets/scholarship_ui.dart';

String _read(String path) => File(path).readAsStringSync();

const _list = 'lib/features/scholarships/presentation/scholarships_screen.dart';
const _detail =
    'lib/features/scholarships/presentation/scholarship_detail_screen.dart';
const _chat =
    'lib/features/scholarships/presentation/scholarship_chat_screen.dart';
const _drawer =
    'lib/features/scholarships/presentation/widgets/scholarship_chat_drawer.dart';
const _ui = 'lib/features/scholarships/presentation/widgets/scholarship_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  // ══════════════════════════════════════════════════
  // ① لا زرَّ فُقد
  // ══════════════════════════════════════════════════
  group('① كلُّ فعلٍ كان موجوداً ما زال موجوداً', () {
    test('شاشةُ القائمة', () {
      final s = _read(_list);
      for (final call in [
        'ScholarshipFavorites.I.toggle',   // ⭐ المتابعة
        'ScholarshipFavorites.I.closingSoon', // 🔔 تنبيه الإغلاق
        '_load(force: true)',              // 🔄 التحديث اليدوي
        'RefreshIndicator',                // ↕️ السحب للتحديث
        'BannerCarousel',                  // 🎏 بانر اللوحة
        'SchFilter.values',                // 🧮 الفلاتر الستة
        'onChanged',                       // 🔎 البحث
        'ScholarshipDetailScreen',         // ➡️ الدخول للتفاصيل
        'ScreenTip',                       // 💡 تلميح الشاشة
        '_onBannerAction',                 // 🎏 نقر البانر
        'معروضة من نسخة محفوظة',            // 📴 شارة الكاش
      ]) {
        expect(s.contains(call), isTrue, reason: 'سقط من القائمة: $call');
      }
    });

    test('شاشةُ التفاصيل', () {
      final s = _read(_detail);
      for (final call in [
        'launchUrl',                       // 🌐 الموقع الرسمي
        'ScholarshipChatScreen',           // 💬 المساعد
        's.requirements.isNotEmpty',       // 🚫 لا تبويب فارغ
        's.documents.isNotEmpty',
        's.howToApply.isNotEmpty',
        '_loadCover',                      // 🖼️ الغلاف القديم (base64)
        'CachedNetworkImage',              // 🖼️ الغلاف الحديث (رابط)
        'لم تُعلن مواعيد هذه المنحة بعد',
      ]) {
        expect(s.contains(call), isTrue, reason: 'سقط من التفاصيل: $call');
      }
      // ⚠️ التبويباتُ الخمسة بأسمائها — «المواعيد» و«نبذة» ظاهرتان دائماً.
      for (final tab in ['"نبذة"', '"الشروط"', '"الوثائق"', '"المواعيد"', '"التقديم"']) {
        expect(s.contains(tab), isTrue, reason: 'سقط تبويب: $tab');
      }
    });

    test('شاشةُ المساعد ودرجُها', () {
      final s = _read(_chat);
      for (final call in [
        '_c.newChat()',                    // ➕ محادثة جديدة
        'openDrawer',                      // 📂 السجلّ
        '_pickImage',                      // 📷 إرفاق صورة
        '_startVoice',                     // 🎤 التسجيل
        'VoiceRecordingBar',               // 🎙️ شريط التسجيل
        '_c.stop',                         // 🛑 إيقاف البثّ
        'SavedStorage.toggle',             // ⭐ الحفظ في المحفوظات
        'Clipboard.setData',               // 📋 النسخ
        'ImageViewerScreen',               // 🔍 عارض الصور
        'ImageEditorScreen',               // ✂️ محرّر الصورة
        's.doors',                         // 🧭 أبواب المنحة
        '_c.removeAttachedImage',          // 🗑️ حذف مرفق
        // 🔢 **عددُ المحادثات لم يضع** — نُقل من نصّ زرّ التفاصيل (الذي
        //    ثبّته المالك على «اسأل مساعد المنحة» كما في التصدير) إلى
        //    شارةٍ على زرّ السجلّ هنا.
        'badge: count > 0',
      ]) {
        expect(s.contains(call), isTrue, reason: 'سقط من المساعد: $call');
      }

      final d = _read(_drawer);
      for (final call in [
        'controller.newChat',
        'controller.openConversation',
        'controller.deleteConversation',
        'controller.clearAll',
        'controller.renameConversation',   // ✏️ تعديلُ الاسم
        'UserSession.I.isGuest',           // 🧪 تنبيه الزائر
        'questionCount',                   // ٣ أسئلة · قبل ساعة
      ]) {
        expect(d.contains(call), isTrue, reason: 'سقط من الدرج: $call');
      }
    });
  });

  // ══════════════════════════════════════════════════
  // ② أيقوناتُ Phosphor حصراً
  // ══════════════════════════════════════════════════
  //
  // 🔴 قاعدةُ المالك ⑤: المصمّم بنى الملف بـPhosphor، و«يشبه» ليست
  //    «يطابق». وأيقونةُ Material تتسلّل بسطرٍ واحد لا يُلاحَظ في مراجعة.
  test('② لا أيقونة Material في شاشات المنح', () {
    for (final path in [_list, _detail, _chat, _drawer, _ui]) {
      expect(RegExp(r'\bIcons\.').hasMatch(_read(path)), isFalse,
          reason: 'أيقونةُ Material في $path');
    }
  });

  // ══════════════════════════════════════════════════
  // ③ فخُّ RTL — أوّلُ ابنٍ في اليمين
  // ══════════════════════════════════════════════════
  //
  // 🔴 أكثرُ علّةٍ تكرّرت في هذا المشروع، وهي **لا تُسقط أيَّ اختبارٍ
  //    وظيفي**: الشاشة تعمل تماماً وهي مقلوبة. فيُقاس الموضع.
  testWidgets('③ رأسُ الصفحة: رسمُ المصمّم يمينَ العنوان', (t) async {
    await t.pumpWidget(_wrap(const SchHeader(title: "المنح")));
    // 🎨 **رسمُ التصميم نفسُه لا نظيرٌ من مكتبة أيقونات** (أمرُ المالك
    //    2026-09-21: «الشعار والأيقونات كامل نفس اللي موجودة في التصميم»).
    final art = find.byType(Image);
    expect(art, findsOneWidget);
    expect(
        (t.widget<Image>(art).image as AssetImage).assetName,
        'assets/art/art_scholarship.png');
    expect(t.getCenter(art).dx, greaterThan(t.getCenter(find.text("المنح")).dx),
        reason: 'الرسم يجب أن يكون في يمين العنوان كما في التصدير');
  });

  testWidgets('③ الوسم: الأيقونةُ يمينَ التسمية', (t) async {
    await t.pumpWidget(_wrap(SchTag(
      label: "ممولة بالكامل",
      icon: PI.sparkle,
      fill: AppColors.schGreenFill,
      ink: AppColors.schGreenInk,
    )));
    final iconX = t.getCenter(find.byType(Icon)).dx;
    final textX = t.getCenter(find.text("ممولة بالكامل")).dx;
    expect(iconX, greaterThan(textX));
  });

  // ══════════════════════════════════════════════════
  // ④ المقاسات المقيسة لا تنزلق
  // ══════════════════════════════════════════════════
  testWidgets('④ ارتفاعاتُ الوسم والشريحة والحقل كما قِيست', (t) async {
    await t.pumpWidget(_wrap(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SchTag(
            label: "س",
            fill: AppColors.schBlueFill,
            ink: AppColors.schBlueInk),
        SchFilterChip(label: "الكل", selected: true, onTap: () {}),
      ],
    )));
    expect(t.getSize(find.byType(SchTag)).height, SchMetrics.tagHeight);
    expect(t.getSize(find.byType(SchFilterChip)).height,
        SchMetrics.filterHeight);
    // 📐 القيمُ نفسُها كما قُرئت من `01-المنح.png` (@2x).
    expect(SchMetrics.margin, 24);
    expect(SchMetrics.cardRadius, 24);
    expect(SchMetrics.searchHeight, 50);
    expect(SchMetrics.bannerHeight, 92);
    expect(SchMetrics.heroHeight, 165);
  });

  // ══════════════════════════════════════════════════
  // ⑥ بطاقةُ الإلحاح — تُرسم ولا تُرى في المحاكي
  // ══════════════════════════════════════════════════
  //
  // ⚠️ **لا تظهر إلا لطالبٍ يتابع منحةً قاربت على الإغلاق.** وبيانات
  //    الخادم اليوم كلُّها منحٌ مغلقة، فلا سبيلَ لرؤيتها في المحاكي —
  //    وما لا يُرى في التجربة يجب أن يُرى في اختبار.
  testWidgets('⑥ بطاقةُ الإلحاح: الساعةُ يميناً والسهمُ يساراً', (t) async {
    var tapped = false;
    await t.pumpWidget(_wrap(SizedBox(
      width: 342,
      child: SchUrgentBanner(
        title: "منحة الأزهر الشريف",
        badge: "عاجل",
        subtitle: "تُغلق بعد 4 أيام — جهّز أوراقك الآن وراجع الشروط.",
        onTap: () => tapped = true,
      ),
    )));

    expect(t.getSize(find.byType(SchUrgentBanner)).height,
        SchMetrics.bannerHeight);
    expect(find.text("عاجل"), findsOneWidget);
    expect(find.text("منحة الأزهر الشريف"), findsOneWidget);

    // ⏰ الساعةُ في أقصى اليمين والسهمُ في أقصى اليسار — كما في التصدير.
    final icons = t.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.length, 2);
    final clockX = t.getCenter(find.byIcon(PI.clock.regular)).dx;
    final caretX = t.getCenter(find.byIcon(PI.caretLeft.regular)).dx;
    expect(clockX, greaterThan(caretX));

    await t.tap(find.byType(SchUrgentBanner));
    expect(tapped, isTrue, reason: 'البطاقةُ تنقل إلى فلتر المتابَعة');
  });

  // ══════════════════════════════════════════════════
  // ⑦ المعدّلُ يُستخرَج ولا يُختلَق
  // ══════════════════════════════════════════════════
  //
  // 🎯 المالك ثبّت التسمية «المعدل المطلوب» كما في التصدير — ولا حقلَ
  //    للمعدّل في بطاقة المنحة. فيُقرأ من الشروط، و**الصمتُ أصدقُ من رقمٍ
  //    مخترَع** حين لا تذكره المنحة.
  group('⑦ المعدّل المطلوب', () {
    test('يأخذ **أصغر** نسبةٍ في الشروط — وهي الحدّ الأدنى للدخول', () {
      expect(
          minGpaOf(const [
            "الحد الأدنى للمعدل:",
            "• الدبلوم والبكالوريوس: 70%.",
            "• الماجستير: 75%.",
            "• الدكتوراه: 75%.",
          ]),
          "70%+");
    });

    test('ولا يخترع رقماً حين لا تذكره المنحة', () {
      expect(minGpaOf(const ["الحد الأدنى للعمر 18 سنة", "إجادة الإنجليزية"]),
          isNull);
      expect(minGpaOf(const []), isNull);
    });

    test('ولا يلتقط عدداً ليس معدّلاً', () {
      // «خصم 30%» ليس معدّلاً مطلوباً، والنطاق 40–100 يحرس هذا.
      expect(minGpaOf(const ["خصم 30% على الرسوم"]), isNull);
      expect(minGpaOf(const ["تغطية 100% من الرسوم"]), "100%+");
    });

    // 🔴 **أمرُ المالك (2026-09-21):** «أضف كم المعدّل المطلوب … يجيب
    //    لوحة التحكم». فصار الحقلُ الصريحُ مصدراً أوّلَ، والاستخراجُ
    //    احتياطاً — وهذا الترتيبُ هو ما يحرسه ما يلي.
    test('حقلُ اللوحة يسبق الاستخراجَ من النصّ', () {
      // شرطٌ فيه «خصم 30%» لا معدَّلَ فيه، والمشرفُ كتب 85 — فالمكتوبُ هو
      // ما يُعرض، ولا يُترك للتعبير النمطيّ أن يقرأ نصّاً كُتب لعينٍ بشرية.
      expect(gpaTextOf(85, const ["خصم 30% على الرسوم"]), "85%+");
      expect(gpaTextOf(85, const ["الدبلوم: 70%"]), "85%+");
    });

    test('وحين يُترك الحقلُ فارغاً يعود الاستخراجُ احتياطاً', () {
      expect(gpaTextOf(0, const ["الدبلوم: 70%"]), "70%+");
      expect(gpaTextOf(0, const ["إجادة الإنجليزية"]), isNull);
    });
  });

  // ══════════════════════════════════════════════════
  // ①① زرّا بطاقة المحادثة في الدرج
  // ══════════════════════════════════════════════════
  //
  // ✏️ رسمَ المصمّمُ زرَّ تعديلٍ بجانب الحذف ولم يكن في التطبيق — أضافه
  //    المالك بأمرٍ صريح (2026-09-21). وألوانُ الزرّين **مقيسةٌ من التصدير**
  //    لا مشتقّة: كان الحدُّ `ink@0.35` تخميناً.
  group('①① التعديلُ والحذفُ كما في `07-Group 1`', () {
    test('الزرّان بألوانِ التصدير الستّة', () {
      expect(AppColors.schEditFill, AppColors.secondary100);    // #E2E8F7
      expect(AppColors.schEditBorder, AppColors.secondary200);  // #C3CFEF
      expect(AppColors.schEditInk, AppColors.secondary800);     // #2D4C98
      expect(AppColors.schDeleteFill, AppColors.error100);      // #FCDFDF
      expect(AppColors.schDeleteBorder, AppColors.error200);    // #F9BEBE
      expect(AppColors.schDeleteInk, AppColors.error800);       // #B22121
    });

    test('وأيقونتاهما ثنائيّتا اللون لا خطّيّتان', () {
      // 🎨 قِستُ داخلَ السلّة `#EEB9B9` على خطٍّ `#B22121` — وهو الخطُّ
      //    نفسُه بشفافية 0.20 بالضبط، أي Duotone.
      final d = _read(_drawer);
      expect(d.contains('PD.pencilSimple'), isTrue);
      expect(d.contains('PD.trashSimple'), isTrue);
      expect(d.contains('PI.trash,'), isFalse,
          reason: 'عاد الحذفُ أيقونةً خطّية');
      expect(PD.trashSimple.secondary.codePoint, PI.trashSimple.regular.codePoint);
    });

    test('وحوارُ التسمية هو حوارُ قسم التعليم نفسُه', () {
      final d = _read(_drawer);
      expect(d.contains('"تعديل أسم المحادثة"'), isTrue);
      expect(d.contains('maxLines: 1'), isTrue,
          reason: 'حقلٌ بلا سقفِ أسطرٍ يطول تحت الإصبع — علّةُ المالك في التعليم');
      // ⚠️ الخمسةُ صراحةً وإلا رسمت سمةُ التطبيق إطاراً لا وجودَ له.
      for (final b in ['enabledBorder', 'focusedBorder', 'disabledBorder',
                       'errorBorder']) {
        expect(d.contains(b), isTrue, reason: 'ناقصٌ في حقل التسمية: $b');
      }
    });

    // 🔴 **علّةٌ ظهرت بعد دقائق من إضافة الزرّ، في المحاكي:** العنوانُ
    //    يُشتقّ من أوّل سؤالٍ مع **كلّ** رسالة — والسؤالُ الأوّل لا يتغيّر،
    //    فكلُّ سؤالٍ تالٍ يمحو الاسمَ الذي اختاره الطالب. (والعلّةُ نفسُها
    //    كانت في قسم التعليم منذ ما قبل زرّ المنحة، فأُصلحت هناك أيضاً.)
    test('والاسمُ المختار لا يُمحى عند السؤال التالي', () {
      final c = SchConversation(
        id: "x",
        title: SchConversation.defaultTitle,
        scholarshipId: "turkey",
        scholarshipName: "المنحة التركية",
        messages: [SchMessage(role: "user", text: "ما شروط التقديم؟")],
      );
      c.retitleFromFirstQuestion();
      expect(c.title, "ما شروط التقديم؟");   // ① الاشتقاقُ يعمل

      c.title = "منحة أخي";                  // ② سمّاها الطالب
      c.messages.add(SchMessage(role: "user", text: "وما الوثائق؟"));
      c.retitleFromFirstQuestion();
      expect(c.title, "منحة أخي");           // ③ ولا تُمحى
    });

    test('ولا تُنسخ المحادثةُ حقلاً حقلاً عند التسمية', () {
      // 🔴 هذا بالضبط ما أعطب نظيرتَها في التعليم: `ownerUid` سقط من
      //    النسخ فصارت المحادثةُ يتيمةً واختفت — ورآها المالكُ «محذوفة».
      final c = _read('lib/features/scholarships/presentation/'
          'controllers/scholarship_chat_controller.dart');
      final at = c.indexOf('Future<void> renameConversation');
      final body = c.substring(at, c.indexOf('\n  }', at));
      expect(body.contains('SchConversation('), isFalse,
          reason: 'إعادةُ التسمية تبني محادثةً جديدة بدل تبديل العنوان');
      expect(body.contains('c.title = '), isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // ①② الكاميرا على خطّ الكلام
  // ══════════════════════════════════════════════════
  //
  // 🔴 **علّةُ المالك:** «الزرّ حقّ الكاميرا نازل شوية عن الكلام». صندوقٌ
  //    36 في صفٍّ محاذىً من الأسفل مركزُه 18 من القاع، ودائرةُ الإرسال 42
  //    مركزُها 21 — ثلاثُ بكسلاتٍ تراها العينُ ولا يراها اختبار.
  //
  // 👥 والحارسُ على **الشريطين معاً**: هما ملفّان منفصلان لواجهةٍ
  //    واحدة، فإصلاحُ أحدهما وحده هو الخطأُ الذي وقع أوّلَ مرة.
  test('①② صندوقُ الكاميرا والمايك بارتفاع دائرةِ الإرسال', () {
    expect(kInputSideBox, 42);
    for (final path in [
      _chat,
      'lib/features/chat/presentation/widgets/chat_input_area.dart',
    ]) {
      final s = _read(path);
      expect(s.contains('height: kInputSideBox'), isTrue,
          reason: 'الشريطُ ما زال يصنع صندوقاً مربّعاً 36: $path');
      expect(RegExp(r'height:\s*36\b').hasMatch(s), isFalse,
          reason: 'بقي ارتفاعُ 36 في شريط الكتابة: $path');
    }
  });

  // ══════════════════════════════════════════════════
  // ⑧ النقطةُ اليدويّة تُزال من العرض
  // ══════════════════════════════════════════════════
  test('⑧ «• تغطية الرسوم» تُعرض بلا نقطةٍ مكرّرة', () {
    expect(stripBullet("• تغطية كاملة للرسوم الدراسية."),
        "تغطية كاملة للرسوم الدراسية.");
    expect(stripBullet("- راتب شهري"), "راتب شهري");
    expect(stripBullet("راتب شهري"), "راتب شهري");
    // ⚠️ ولا تُمسّ البياناتُ نفسُها — الدالةُ تعرض ولا تكتب.
    expect(stripBullet("٥٠٠ دولار — شهرياً"), "٥٠٠ دولار — شهرياً");
  });

  // ══════════════════════════════════════════════════
  // ⑨ المحادثةُ نسخةٌ من قسم التعليم
  // ══════════════════════════════════════════════════
  //
  // 🎯 **أمرُ المالك (2026-09-21):** «الخلفية المموّجة، الأزرار اللي تحت،
  //    طريقة عرض الكلام، صورة الشخص، مكان النسخ واللصق، وصورة الذكاء
  //    الصناعي وين تكون — نفس حق التعليم بالضبط».
  //
  // 🛡️ وهذه **تفاصيلُ شكلٍ لا يحرسها اختبارٌ وظيفي**: تبديلُ فقاعةٍ بيضاء
  //    بأخرى ملوّنة لا يُسقط شيئاً.
  test('⑨ فقاعاتُ المساعد وشريطُ الكتابة من لغة قسم التعليم', () {
    final s = _read(_chat);
    for (final token in [
      'AppColors.chatBackdrop',   // 🌈 الخلفية المموّجة
      'AppColors.bubbleGradient', // 💬 فقاعة الطالب
      'UserAvatar(radius: 15)',   // 👤 صورة الطالب يمينَ رسالته
      'MasarRobot(size: 28)',     // 🤖 صورة المساعد يمينَ ردّه
      '"مسار AI"',                 // 🏷️ اسمُ المتكلّم فوق الردّ
      'AppColors.surfaceWhite',   // ⬜ ردٌّ أبيضُ بحبرٍ أسود
      'AppColors.sendButton',     // 🚀 دائرةُ الإرسال 42
      'PI.paperPlaneRight.fill',
      'Alignment.centerRight',    // الطالبُ يميناً كما في التعليم
    ]) {
      expect(s.contains(token), isTrue, reason: 'غاب عن المحادثة: $token');
    }
  });

  // ══════════════════════════════════════════════════
  // ⑩ `ScreenTip` يرجع `Positioned` — فمكانُه `Stack`
  // ══════════════════════════════════════════════════
  //
  // 🔴 **رُصد في سجلّ `flutter run` أثناء فحص الاستثناءات:** كان في
  //    `home_tab` آخرَ أبناء عمودٍ داخل التمرير، فيرمي فلاتر
  //    «Incorrect use of ParentDataWidget» في كل بناء ولا يظهر التلميحُ
  //    للطالب أبداً. والعلّةُ **لا تُسقط `analyze`** ولا أيَّ اختبارٍ قائم.
  test('⑩ كلُّ `ScreenTip` ابنٌ مباشرٌ لـ`Stack`', () {
    /// يرجع اسمَ المُنشئ الذي يحتضن الموضع [at] مباشرةً — بمشيٍ عكسيٍّ
    /// على الأقواس المتوازنة، لا بـ«أقربِ كلمةٍ قبله» (تلك تُخطئ حين
    /// يجاور `ScreenTip` عموداً داخل الكومة).
    String enclosing(String src, int at) {
      var depth = 0;
      for (var i = at - 1; i >= 0; i--) {
        final ch = src[i];
        if (ch == ')' || ch == ']' || ch == '}') depth++;
        if (ch == '(' || ch == '[' || ch == '{') {
          if (depth == 0) {
            final head = src.substring(0, i);
            final m = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*$').firstMatch(head);
            // `children: [` و`child:` ليسا مُنشئاً — نواصل الصعود.
            final name = m?.group(1) ?? "";
            if (name.isEmpty || name == "children" || name == "child") {
              return enclosing(src, i);
            }
            return name;
          }
          depth--;
        }
      }
      return "";
    }

    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('screen_tip.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'\bScreenTip\(').allMatches(src)) {
        expect(enclosing(src, m.start), 'Stack',
            reason: '${f.path}: `ScreenTip` يرجع `Positioned`، فمكانُه '
                '`Stack` مباشرةً — وإلا رمى فلاتر عند كل بناء');
      }
    }
  });

  // ══════════════════════════════════════════════════
  // ⑤ الشريحةُ المختارة تحمل نصّاً أبيض
  // ══════════════════════════════════════════════════
  //
  // 🌙 **الزلّةُ التي وقعت في «اختبر نفسك» ورُصدت في المحاكي**: تعبئةٌ
  //    بـ`primary` (الأزرقِ المفتَّح **ليُقرأ نصّاً**) تحت أبيضَ تهبط
  //    بالتباين إلى 2.1:1 في الوضع الداكن. الصوابُ `primaryFill`.
  test('⑤ لا `primary` تعبئةً تحت نصٍّ أبيض', () {
    final s = _read(_ui);
    expect(s.contains('AppColors.primaryFill'), isTrue);
    expect(RegExp(r'color:\s*selected\s*\?\s*AppColors\.primary\s*:')
            .hasMatch(s),
        isFalse,
        reason: 'الشريحةُ المختارة تأخذ `primaryFill` لا `primary`');
  });
}
