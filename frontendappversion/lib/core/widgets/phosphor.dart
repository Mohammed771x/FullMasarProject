import 'package:flutter/widgets.dart';

// ==========================================
// ✒️ أيقونات Phosphor — مكتبة المصمّم نفسها
// ==========================================
// 🎯 **كيف عُرف أنها Phosphor؟** أسماء العقد في ملف Figma حرفياً:
//    `ChalkboardTeacher` · `Student` · `CloudCheck` · `AirplaneInFlight` ·
//    `CaretLeft` · `PencilSimple` — وهذه أسماء Phosphor بعينها. فالمصمّم
//    بنى الملف بها، واستعمالُ غيرِها يعني «يشبه» لا «يطابق».
//
// ⚠️ **ولماذا لا حزمة `phosphor_flutter`؟** جُرّبت (2.1.0) فسقط البناء:
//    `IconData` صارت `final class` في فلاتر الحديثة والحزمةُ ترثها.
//    فأُخذ منها **ما لا يقدَم**: ملفات الخط ورموزُ الأيقونات — وبُنيت
//    هذه الطبقة فوقها. لا حزمةً تتعطّل مع كل ترقية، ولا صوراً شبكية.
//
// ⚠️ **وكلُّ `IconData` هنا ثابتٌ (`const`) عمداً**: فلاتر لا تقلّم خطوط
//    الأيقونات إلا إن كانت الرموز ثوابت وقت الترجمة — وبغير ذلك يُرفض
//    البناء أو يُشحن الخطّ كاملاً (نصف ميغابايت لكل نمط).
//
// 📦 ثلاثة أنماط في `assets/fonts/` (عادي · ممتلئ · عريض) — وهي ما
//    يستعمله التصميم. وباقي أنماط Phosphor لم يُنسخ: وزنٌ بلا استعمال.

/// أيقونةٌ بأنماطها الثلاثة.
class PIcon {
  const PIcon({required this.regular, required this.fill, required this.bold});

  final IconData regular, fill, bold;

  /// النمط حسب الحالة — النشط ممتلئ والخامل عادي، كما في التصميم.
  IconData call({bool active = false}) => active ? fill : regular;
}

class PI {
  PI._();

  // 📚 مجموعةٌ واحدة لكل الأقسام — تُوسَّع بإضافة الاسم إلى مولِّدها.

  static const airplaneInFlight = PIcon(
    regular: IconData(0xe4fe, fontFamily: 'Phosphor'),
    fill: IconData(0xe4fe, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4fe, fontFamily: 'PhosphorBold'),
  );
  static const arrowLeft = PIcon(
    regular: IconData(0xe058, fontFamily: 'Phosphor'),
    fill: IconData(0xe058, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe058, fontFamily: 'PhosphorBold'),
  );
  static const arrowRight = PIcon(
    regular: IconData(0xe06c, fontFamily: 'Phosphor'),
    fill: IconData(0xe06c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe06c, fontFamily: 'PhosphorBold'),
  );
  /// ↗️ **رابطٌ خارجي** — زرُّ «الموقع الرسمي» في رأس شاشة التفاصيل.
  static const arrowSquareOut = PIcon(
    regular: IconData(0xe07c, fontFamily: 'Phosphor'),
    fill: IconData(0xe07c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe07c, fontFamily: 'PhosphorBold'),
  );
  static const arrowUp = PIcon(
    regular: IconData(0xe08e, fontFamily: 'Phosphor'),
    fill: IconData(0xe08e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe08e, fontFamily: 'PhosphorBold'),
  );
  static const arrowUpLeft = PIcon(
    regular: IconData(0xe090, fontFamily: 'Phosphor'),
    fill: IconData(0xe090, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe090, fontFamily: 'PhosphorBold'),
  );
  static const arrowUpRight = PIcon(
    regular: IconData(0xe092, fontFamily: 'Phosphor'),
    fill: IconData(0xe092, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe092, fontFamily: 'PhosphorBold'),
  );
  static const bell = PIcon(
    regular: IconData(0xe0ce, fontFamily: 'Phosphor'),
    fill: IconData(0xe0ce, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe0ce, fontFamily: 'PhosphorBold'),
  );
  static const bookOpen = PIcon(
    regular: IconData(0xe0e6, fontFamily: 'Phosphor'),
    fill: IconData(0xe0e6, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe0e6, fontFamily: 'PhosphorBold'),
  );
  static const bookOpenText = PIcon(
    regular: IconData(0xe8f2, fontFamily: 'Phosphor'),
    fill: IconData(0xe8f2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe8f2, fontFamily: 'PhosphorBold'),
  );
  static const bookmarkSimple = PIcon(
    regular: IconData(0xe0ea, fontFamily: 'Phosphor'),
    fill: IconData(0xe0ea, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe0ea, fontFamily: 'PhosphorBold'),
  );
  static const brain = PIcon(
    regular: IconData(0xe74e, fontFamily: 'Phosphor'),
    fill: IconData(0xe74e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe74e, fontFamily: 'PhosphorBold'),
  );
  static const calendar = PIcon(
    regular: IconData(0xe108, fontFamily: 'Phosphor'),
    fill: IconData(0xe108, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe108, fontFamily: 'PhosphorBold'),
  );
  static const camera = PIcon(
    regular: IconData(0xe10e, fontFamily: 'Phosphor'),
    fill: IconData(0xe10e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe10e, fontFamily: 'PhosphorBold'),
  );
  static const caretDown = PIcon(
    regular: IconData(0xe136, fontFamily: 'Phosphor'),
    fill: IconData(0xe136, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe136, fontFamily: 'PhosphorBold'),
  );
  static const caretLeft = PIcon(
    regular: IconData(0xe138, fontFamily: 'Phosphor'),
    fill: IconData(0xe138, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe138, fontFamily: 'PhosphorBold'),
  );
  static const caretRight = PIcon(
    regular: IconData(0xe13a, fontFamily: 'Phosphor'),
    fill: IconData(0xe13a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe13a, fontFamily: 'PhosphorBold'),
  );
  static const caretUp = PIcon(
    regular: IconData(0xe13c, fontFamily: 'Phosphor'),
    fill: IconData(0xe13c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe13c, fontFamily: 'PhosphorBold'),
  );
  static const chalkboardTeacher = PIcon(
    regular: IconData(0xe600, fontFamily: 'Phosphor'),
    fill: IconData(0xe600, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe600, fontFamily: 'PhosphorBold'),
  );
  static const chartBar = PIcon(
    regular: IconData(0xe150, fontFamily: 'Phosphor'),
    fill: IconData(0xe150, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe150, fontFamily: 'PhosphorBold'),
  );
  static const chartLine = PIcon(
    regular: IconData(0xe154, fontFamily: 'Phosphor'),
    fill: IconData(0xe154, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe154, fontFamily: 'PhosphorBold'),
  );
  /// 💬 **فقاعةٌ مربّعة** — أيقونةُ «محادثاتي» في رأس المساعد وفي بطاقات
  ///    الدرج. قِستُها من التصدير: فقاعةٌ بلا نقاطٍ وذيلُها أسفلَ اليسار.
  static const chat = PIcon(
    regular: IconData(0xe15c, fontFamily: 'Phosphor'),
    fill: IconData(0xe15c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe15c, fontFamily: 'PhosphorBold'),
  );

  /// 💬⋯ **فقاعةٌ بثلاث نقاط** — زرُّ «اسأل مساعد المنحة».
  static const chatDots = PIcon(
    regular: IconData(0xe170, fontFamily: 'Phosphor'),
    fill: IconData(0xe170, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe170, fontFamily: 'PhosphorBold'),
  );
  static const chatCircleDots = PIcon(
    regular: IconData(0xe16c, fontFamily: 'Phosphor'),
    fill: IconData(0xe16c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe16c, fontFamily: 'PhosphorBold'),
  );
  static const chats = PIcon(
    regular: IconData(0xe17c, fontFamily: 'Phosphor'),
    fill: IconData(0xe17c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe17c, fontFamily: 'PhosphorBold'),
  );
  static const chatsCircle = PIcon(
    regular: IconData(0xe17e, fontFamily: 'Phosphor'),
    fill: IconData(0xe17e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe17e, fontFamily: 'PhosphorBold'),
  );
  static const check = PIcon(
    regular: IconData(0xe182, fontFamily: 'Phosphor'),
    fill: IconData(0xe182, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe182, fontFamily: 'PhosphorBold'),
  );
  static const checkCircle = PIcon(
    regular: IconData(0xe184, fontFamily: 'Phosphor'),
    fill: IconData(0xe184, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe184, fontFamily: 'PhosphorBold'),
  );
  static const clock = PIcon(
    regular: IconData(0xe19a, fontFamily: 'Phosphor'),
    fill: IconData(0xe19a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe19a, fontFamily: 'PhosphorBold'),
  );
  static const clockCounterClockwise = PIcon(
    regular: IconData(0xe1a0, fontFamily: 'Phosphor'),
    fill: IconData(0xe1a0, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe1a0, fontFamily: 'PhosphorBold'),
  );
  static const cloudCheck = PIcon(
    regular: IconData(0xe1b0, fontFamily: 'Phosphor'),
    fill: IconData(0xe1b0, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe1b0, fontFamily: 'PhosphorBold'),
  );
  static const copy = PIcon(
    regular: IconData(0xe1ca, fontFamily: 'Phosphor'),
    fill: IconData(0xe1ca, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe1ca, fontFamily: 'PhosphorBold'),
  );
  static const dotsThree = PIcon(
    regular: IconData(0xe1fe, fontFamily: 'Phosphor'),
    fill: IconData(0xe1fe, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe1fe, fontFamily: 'PhosphorBold'),
  );
  static const dotsThreeVertical = PIcon(
    regular: IconData(0xe208, fontFamily: 'Phosphor'),
    fill: IconData(0xe208, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe208, fontFamily: 'PhosphorBold'),
  );
  static const envelope = PIcon(
    regular: IconData(0xe214, fontFamily: 'Phosphor'),
    fill: IconData(0xe214, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe214, fontFamily: 'PhosphorBold'),
  );
  static const eye = PIcon(
    regular: IconData(0xe220, fontFamily: 'Phosphor'),
    fill: IconData(0xe220, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe220, fontFamily: 'PhosphorBold'),
  );
  static const eyeSlash = PIcon(
    regular: IconData(0xe224, fontFamily: 'Phosphor'),
    fill: IconData(0xe224, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe224, fontFamily: 'PhosphorBold'),
  );
  static const faders = PIcon(
    regular: IconData(0xe228, fontFamily: 'Phosphor'),
    fill: IconData(0xe228, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe228, fontFamily: 'PhosphorBold'),
  );
  static const fadersHorizontal = PIcon(
    regular: IconData(0xe22a, fontFamily: 'Phosphor'),
    fill: IconData(0xe22a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe22a, fontFamily: 'PhosphorBold'),
  );
  static const file = PIcon(
    regular: IconData(0xe230, fontFamily: 'Phosphor'),
    fill: IconData(0xe230, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe230, fontFamily: 'PhosphorBold'),
  );
  static const fileText = PIcon(
    regular: IconData(0xe23a, fontFamily: 'Phosphor'),
    fill: IconData(0xe23a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe23a, fontFamily: 'PhosphorBold'),
  );
  static const fire = PIcon(
    regular: IconData(0xe242, fontFamily: 'Phosphor'),
    fill: IconData(0xe242, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe242, fontFamily: 'PhosphorBold'),
  );
  static const flask = PIcon(
    regular: IconData(0xe79e, fontFamily: 'Phosphor'),
    fill: IconData(0xe79e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe79e, fontFamily: 'PhosphorBold'),
  );
  static const folder = PIcon(
    regular: IconData(0xe24a, fontFamily: 'Phosphor'),
    fill: IconData(0xe24a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe24a, fontFamily: 'PhosphorBold'),
  );
  static const filePdf = PIcon(
    regular: IconData(0xe702, fontFamily: 'Phosphor'),
    fill: IconData(0xe702, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe702, fontFamily: 'PhosphorBold'),
  );
  static const downloadSimple = PIcon(
    regular: IconData(0xe20c, fontFamily: 'Phosphor'),
    fill: IconData(0xe20c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe20c, fontFamily: 'PhosphorBold'),
  );
  static const gear = PIcon(
    regular: IconData(0xe270, fontFamily: 'Phosphor'),
    fill: IconData(0xe270, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe270, fontFamily: 'PhosphorBold'),
  );
  static const gearSix = PIcon(
    regular: IconData(0xe272, fontFamily: 'Phosphor'),
    fill: IconData(0xe272, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe272, fontFamily: 'PhosphorBold'),
  );
  static const globe = PIcon(
    regular: IconData(0xe288, fontFamily: 'Phosphor'),
    fill: IconData(0xe288, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe288, fontFamily: 'PhosphorBold'),
  );
  static const graduationCap = PIcon(
    regular: IconData(0xe62c, fontFamily: 'Phosphor'),
    fill: IconData(0xe62c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe62c, fontFamily: 'PhosphorBold'),
  );
  static const house = PIcon(
    regular: IconData(0xe2c2, fontFamily: 'Phosphor'),
    fill: IconData(0xe2c2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2c2, fontFamily: 'PhosphorBold'),
  );
  static const image = PIcon(
    regular: IconData(0xe2ca, fontFamily: 'Phosphor'),
    fill: IconData(0xe2ca, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2ca, fontFamily: 'PhosphorBold'),
  );
  static const info = PIcon(
    regular: IconData(0xe2ce, fontFamily: 'Phosphor'),
    fill: IconData(0xe2ce, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2ce, fontFamily: 'PhosphorBold'),
  );
  static const lightbulb = PIcon(
    regular: IconData(0xe2dc, fontFamily: 'Phosphor'),
    fill: IconData(0xe2dc, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2dc, fontFamily: 'PhosphorBold'),
  );
  static const lightbulbFilament = PIcon(
    regular: IconData(0xe63c, fontFamily: 'Phosphor'),
    fill: IconData(0xe63c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe63c, fontFamily: 'PhosphorBold'),
  );
  static const lightning = PIcon(
    regular: IconData(0xe2de, fontFamily: 'Phosphor'),
    fill: IconData(0xe2de, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2de, fontFamily: 'PhosphorBold'),
  );
  static const listChecks = PIcon(
    regular: IconData(0xeadc, fontFamily: 'Phosphor'),
    fill: IconData(0xeadc, fontFamily: 'PhosphorFill'),
    bold: IconData(0xeadc, fontFamily: 'PhosphorBold'),
  );
  static const lock = PIcon(
    regular: IconData(0xe2fa, fontFamily: 'Phosphor'),
    fill: IconData(0xe2fa, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2fa, fontFamily: 'PhosphorBold'),
  );
  static const magnifyingGlass = PIcon(
    regular: IconData(0xe30c, fontFamily: 'Phosphor'),
    fill: IconData(0xe30c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe30c, fontFamily: 'PhosphorBold'),
  );
  static const medal = PIcon(
    regular: IconData(0xe320, fontFamily: 'Phosphor'),
    fill: IconData(0xe320, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe320, fontFamily: 'PhosphorBold'),
  );
  static const microphone = PIcon(
    regular: IconData(0xe326, fontFamily: 'Phosphor'),
    fill: IconData(0xe326, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe326, fontFamily: 'PhosphorBold'),
  );
  static const note = PIcon(
    regular: IconData(0xe348, fontFamily: 'Phosphor'),
    fill: IconData(0xe348, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe348, fontFamily: 'PhosphorBold'),
  );
  static const notePencil = PIcon(
    regular: IconData(0xe34c, fontFamily: 'Phosphor'),
    fill: IconData(0xe34c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe34c, fontFamily: 'PhosphorBold'),
  );
  static const notebook = PIcon(
    regular: IconData(0xe34e, fontFamily: 'Phosphor'),
    fill: IconData(0xe34e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe34e, fontFamily: 'PhosphorBold'),
  );
  static const paperPlaneRight = PIcon(
    regular: IconData(0xe396, fontFamily: 'Phosphor'),
    fill: IconData(0xe396, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe396, fontFamily: 'PhosphorBold'),
  );
  static const paperPlaneTilt = PIcon(
    regular: IconData(0xe398, fontFamily: 'Phosphor'),
    fill: IconData(0xe398, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe398, fontFamily: 'PhosphorBold'),
  );
  static const pencilSimple = PIcon(
    regular: IconData(0xe3b4, fontFamily: 'Phosphor'),
    fill: IconData(0xe3b4, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3b4, fontFamily: 'PhosphorBold'),
  );
  static const play = PIcon(
    regular: IconData(0xe3d0, fontFamily: 'Phosphor'),
    fill: IconData(0xe3d0, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3d0, fontFamily: 'PhosphorBold'),
  );
  static const playCircle = PIcon(
    regular: IconData(0xe3d2, fontFamily: 'Phosphor'),
    fill: IconData(0xe3d2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3d2, fontFamily: 'PhosphorBold'),
  );
  static const question = PIcon(
    regular: IconData(0xe3e8, fontFamily: 'Phosphor'),
    fill: IconData(0xe3e8, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3e8, fontFamily: 'PhosphorBold'),
  );
  static const plus = PIcon(
    regular: IconData(0xe3d4, fontFamily: 'Phosphor'),
    fill: IconData(0xe3d4, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3d4, fontFamily: 'PhosphorBold'),
  );
  static const share = PIcon(
    regular: IconData(0xe406, fontFamily: 'Phosphor'),
    fill: IconData(0xe406, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe406, fontFamily: 'PhosphorBold'),
  );
  /// 🛡️✓ **نوعُ التمويل** في شريط شاشة التفاصيل.
  static const shieldCheck = PIcon(
    regular: IconData(0xe40c, fontFamily: 'Phosphor'),
    fill: IconData(0xe40c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe40c, fontFamily: 'PhosphorBold'),
  );
  static const signOut = PIcon(
    regular: IconData(0xe42a, fontFamily: 'Phosphor'),
    fill: IconData(0xe42a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe42a, fontFamily: 'PhosphorBold'),
  );
  static const sliders = PIcon(
    regular: IconData(0xe432, fontFamily: 'Phosphor'),
    fill: IconData(0xe432, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe432, fontFamily: 'PhosphorBold'),
  );
  static const slidersHorizontal = PIcon(
    regular: IconData(0xe434, fontFamily: 'Phosphor'),
    fill: IconData(0xe434, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe434, fontFamily: 'PhosphorBold'),
  );
  static const sparkle = PIcon(
    regular: IconData(0xe6a2, fontFamily: 'Phosphor'),
    fill: IconData(0xe6a2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe6a2, fontFamily: 'PhosphorBold'),
  );
  /// 🗂️ **طبقات** — شارةُ كلِّ تخصّصٍ في «المجالات المتاحة».
  static const stack = PIcon(
    regular: IconData(0xe466, fontFamily: 'Phosphor'),
    fill: IconData(0xe466, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe466, fontFamily: 'PhosphorBold'),
  );
  static const star = PIcon(
    regular: IconData(0xe46a, fontFamily: 'Phosphor'),
    fill: IconData(0xe46a, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe46a, fontFamily: 'PhosphorBold'),
  );
  static const stopCircle = PIcon(
    regular: IconData(0xe46e, fontFamily: 'Phosphor'),
    fill: IconData(0xe46e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe46e, fontFamily: 'PhosphorBold'),
  );
  static const student = PIcon(
    regular: IconData(0xe73e, fontFamily: 'Phosphor'),
    fill: IconData(0xe73e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe73e, fontFamily: 'PhosphorBold'),
  );
  static const target = PIcon(
    regular: IconData(0xe47c, fontFamily: 'Phosphor'),
    fill: IconData(0xe47c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe47c, fontFamily: 'PhosphorBold'),
  );
  static const textAlignJustify = PIcon(
    regular: IconData(0xe482, fontFamily: 'Phosphor'),
    fill: IconData(0xe482, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe482, fontFamily: 'PhosphorBold'),
  );
  static const trash = PIcon(
    regular: IconData(0xe4a6, fontFamily: 'Phosphor'),
    fill: IconData(0xe4a6, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4a6, fontFamily: 'PhosphorBold'),
  );
  static const trashSimple = PIcon(
    regular: IconData(0xe4a8, fontFamily: 'Phosphor'),
    fill: IconData(0xe4a8, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4a8, fontFamily: 'PhosphorBold'),
  );
  static const trophy = PIcon(
    regular: IconData(0xe67e, fontFamily: 'Phosphor'),
    fill: IconData(0xe67e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe67e, fontFamily: 'PhosphorBold'),
  );
  static const user = PIcon(
    regular: IconData(0xe4c2, fontFamily: 'Phosphor'),
    fill: IconData(0xe4c2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4c2, fontFamily: 'PhosphorBold'),
  );
  static const userCircle = PIcon(
    regular: IconData(0xe4c4, fontFamily: 'Phosphor'),
    fill: IconData(0xe4c4, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4c4, fontFamily: 'PhosphorBold'),
  );
  static const warningCircle = PIcon(
    regular: IconData(0xe4e2, fontFamily: 'Phosphor'),
    fill: IconData(0xe4e2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4e2, fontFamily: 'PhosphorBold'),
  );
  static const arrowDown = PIcon(
    regular: IconData(0xe03e, fontFamily: 'Phosphor'),
    fill: IconData(0xe03e, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe03e, fontFamily: 'PhosphorBold'),
  );
  static const listNumbers = PIcon(
    regular: IconData(0xe2f6, fontFamily: 'Phosphor'),
    fill: IconData(0xe2f6, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2f6, fontFamily: 'PhosphorBold'),
  );
  static const rocketLaunch = PIcon(
    regular: IconData(0xe3fe, fontFamily: 'Phosphor'),
    fill: IconData(0xe3fe, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3fe, fontFamily: 'PhosphorBold'),
  );
  static const link = PIcon(
    regular: IconData(0xe2e2, fontFamily: 'Phosphor'),
    fill: IconData(0xe2e2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe2e2, fontFamily: 'PhosphorBold'),
  );
  static const imageBroken = PIcon(
    regular: IconData(0xe7a8, fontFamily: 'Phosphor'),
    fill: IconData(0xe7a8, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe7a8, fontFamily: 'PhosphorBold'),
  );
  static const images = PIcon(
    regular: IconData(0xe836, fontFamily: 'Phosphor'),
    fill: IconData(0xe836, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe836, fontFamily: 'PhosphorBold'),
  );
  static const warning = PIcon(
    regular: IconData(0xe4e0, fontFamily: 'Phosphor'),
    fill: IconData(0xe4e0, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4e0, fontFamily: 'PhosphorBold'),
  );
  static const phone = PIcon(
    regular: IconData(0xe3b8, fontFamily: 'Phosphor'),
    fill: IconData(0xe3b8, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe3b8, fontFamily: 'PhosphorBold'),
  );
  static const code = PIcon(
    regular: IconData(0xe1bc, fontFamily: 'Phosphor'),
    fill: IconData(0xe1bc, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe1bc, fontFamily: 'PhosphorBold'),
  );
  static const wifiSlash = PIcon(
    regular: IconData(0xe4f2, fontFamily: 'Phosphor'),
    fill: IconData(0xe4f2, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4f2, fontFamily: 'PhosphorBold'),
  );
  static const stop = PIcon(
    regular: IconData(0xe46c, fontFamily: 'Phosphor'),
    fill: IconData(0xe46c, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe46c, fontFamily: 'PhosphorBold'),
  );
  static const x = PIcon(
    regular: IconData(0xe4f6, fontFamily: 'Phosphor'),
    fill: IconData(0xe4f6, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4f6, fontFamily: 'PhosphorBold'),
  );
  static const xCircle = PIcon(
    regular: IconData(0xe4f8, fontFamily: 'Phosphor'),
    fill: IconData(0xe4f8, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe4f8, fontFamily: 'PhosphorBold'),
  );
  static const arrowCounterClockwise = PIcon(
    regular: IconData(0xe038, fontFamily: 'Phosphor'),
    fill: IconData(0xe038, fontFamily: 'PhosphorFill'),
    bold: IconData(0xe038, fontFamily: 'PhosphorBold'),
  );
}

/// أيقونةٌ ثنائيةُ اللون — رمزان: طبقةٌ باهتة وطبقةٌ أساسية.
///
/// 🎨 **لماذا نمطٌ رابع؟** رأسُ شاشة المحادثة في التصميم (المصباح · قائمة
///    المحادثات · فاضل الإعدادات) مرسومٌ بنمط Phosphor **Duotone**: شكلٌ
///    فاتحٌ خلف الخطوط. قِستُ بكسلاته فوجدتُ داخلَ المصباح رماديّاً فاتحاً
///    وداخلَ الفاضل أزرقَ باهتاً — وهذا لا يُنتجه `regular` ولا `fill`.
///
/// 📐 والشفافية **0.20** — نسبةُ Phosphor نفسها لا تقديرٌ منّي.
class PDIcon {
  const PDIcon({required this.primary, required this.secondary});

  /// الخطوط — تُرسم فوق.
  final IconData primary;

  /// الشكلُ الباهت — يُرسم تحت بشفافية [PDuo.secondaryOpacity].
  final IconData secondary;
}

/// يرسم [PDIcon] طبقتين — نظيرُ `Icon` للنمط الثنائي.
class PDuo extends StatelessWidget {
  const PDuo(this.icon, {super.key, required this.size, required this.color});

  final PDIcon icon;
  final double size;
  final Color color;

  static const double secondaryOpacity = 0.20;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon.secondary,
                size: size, color: color.withValues(alpha: secondaryOpacity)),
            Icon(icon.primary, size: size, color: color),
          ],
        ),
      );
}

/// رموزُ النمط الثنائي — يُضاف إليها ما يستعمله التصميم فقط.
class PD {
  PD._();

  static const textAlignJustify = PDIcon(
    primary: IconData(0xe483, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe482, fontFamily: 'PhosphorDuotone'),
  );
  static const lightbulbFilament = PDIcon(
    primary: IconData(0xe63d, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe63c, fontFamily: 'PhosphorDuotone'),
  );
  static const folderOpen = PDIcon(
    primary: IconData(0xe257, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe256, fontFamily: 'PhosphorDuotone'),
  );
  static const filePdf = PDIcon(
    primary: IconData(0xe703, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe702, fontFamily: 'PhosphorDuotone'),
  );
  static const warning = PDIcon(
    primary: IconData(0xe4e1, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe4e0, fontFamily: 'PhosphorDuotone'),
  );
  static const pencilSimple = PDIcon(
    primary: IconData(0xe3b5, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe3b4, fontFamily: 'PhosphorDuotone'),
  );

  /// 🗑️ **زرُّ الحذف في درج المنحة.** قِستُ التصدير: جسمُ السلّة
  ///    `#EEB9B9` داخل خطٍّ `#B22121` على تعبئة `#FCDFDF` — وهو الخطُّ
  ///    نفسُه بشفافية 0.20 بالضبط، أي نمطُ Duotone لا لونان.
  static const trashSimple = PDIcon(
    primary: IconData(0xe4a9, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe4a8, fontFamily: 'PhosphorDuotone'),
  );
  static const notebook = PDIcon(
    primary: IconData(0xe34f, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe34e, fontFamily: 'PhosphorDuotone'),
  );
  static const fadersHorizontal = PDIcon(
    primary: IconData(0xe22b, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe22a, fontFamily: 'PhosphorDuotone'),
  );

  /// 📋✓ رأسُ «اختبر نفسك» — رسمَه المصمّم أيقونةً مجسّمة، وهذه نظيرتُها
  ///    في مكتبته (`ListChecks`) كما فُعل في الشريط السفلي بالضبط.
  static const listChecks = PDIcon(
    primary: IconData(0xeadd, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xeadc, fontFamily: 'PhosphorDuotone'),
  );

  /// ☑️ **شارةُ النقاط في شريط الاختبار.** قِستُ التصدير: تعبئةٌ
  ///    `#CCF2E5` داخل خطٍّ `#00D492` — وهي **نفسُ لونٍ واحد بشفافية
  ///    0.20**، أي نمطُ Duotone لا أيقونتان.
  static const checkSquare = PDIcon(
    primary: IconData(0xe187, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe186, fontFamily: 'PhosphorDuotone'),
  );

  /// 📝 «راجع إجاباتك».
  static const notePencil = PDIcon(
    primary: IconData(0xe34d, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe34c, fontFamily: 'PhosphorDuotone'),
  );

  /// 🔄 «اختبار جديد بنفس الدروس».
  static const arrowCounterClockwise = PDIcon(
    primary: IconData(0xe039, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe038, fontFamily: 'PhosphorDuotone'),
  );

  /// 💬 بطاقةُ المحادثة في درج المنحة — قِستُ داخلَ الفقاعة `#CCE2F2`
  ///    على خطٍّ `#006EBF`، وهو **نفسُ اللون بشفافية 0.20** بالضبط: أي
  ///    نمطُ Duotone لا أيقونتان (نفسُ طريقة كشفِ `CheckSquare`).
  static const chat = PDIcon(
    primary: IconData(0xe15d, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe15c, fontFamily: 'PhosphorDuotone'),
  );

  /// 🎓 رأسُ «المنح» — رسمَه المصمّم كرةً أرضيّةً بقبّعةِ تخرّجٍ مجسّمة،
  ///    ونظيرُها في مكتبته `GraduationCap`؛ نفسُ القاعدة المطبّقة على
  ///    رأس «اختبر نفسك».
  static const graduationCap = PDIcon(
    primary: IconData(0xe62d, fontFamily: 'PhosphorDuotone'),
    secondary: IconData(0xe62c, fontFamily: 'PhosphorDuotone'),
  );
}

/// 📄✓ **«ورقةٌ عليها علامةُ صحّ»** — أيقونةُ «وزاري» و«اختبارات» في التصميم.
///
/// ⚠️ **ليست في خطّ Phosphor الذي بين أيدينا.** `file-check` أُضيفت إلى
///    نواة Phosphor بعد الإصدار الذي أُخذت منه الخطوط (2.1.0)، فلا رمزَ لها
///    في `Phosphor.ttf`. وأقربُ البدائل (`fileText` · `listChecks` ·
///    `checkSquare`) شكلٌ آخر يراه الطالب مختلفاً.
///
/// ✅ فرُكّبت من رمزَي Phosphor نفسيهما — الورقةُ `file` وعلامةُ `check` —
///    بنِسَبٍ مقيسةٍ من تصدير المصمّم: العلامة 46% من عرض الأيقونة، ومركزُها
///    عند 60% من ارتفاعه (تحت طيّة الزاوية لا فوقها). والعلامةُ **مرسومة**
///    لا مكتوبة — راجع [_CheckStroke] لِمَ لم يَصلُح رمزُ `check` نفسه.
class PFileCheck extends StatelessWidget {
  const PFileCheck(
      {super.key, required this.size, required this.color, this.bold = false});

  final double size;
  final Color color;

  /// نمطُ Phosphor العريض — وهو نمطُ شرائح الأوضاع في التصميم.
  final bool bold;

  /// سماكةُ خطّ Phosphor نسبةً إلى الحجم: 16/256 للعادي و24/256 للعريض.
  double get _stroke => size * (bold ? 24 : 16) / 256;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(bold ? PI.file.bold : PI.file.regular,
                size: size, color: color),
            Positioned.fill(
                child: CustomPaint(painter: _CheckStroke(color, size, _stroke))),
          ],
        ),
      );
}

/// علامةُ الصحّ داخل الورقة — **مرسومةٌ لا مكتوبة**.
///
/// ⚠️ ولمَ لا `PI.check`؟ نمطُه `fill` في Phosphor مربّعٌ مصمتٌ بداخله
///    علامةٌ بيضاء (جرّبتُه فظهر مربّعاً أزرقَ داخل الورقة)، ونمطُه
///    `regular` عند ثلث الحجم يصير خطُّه ثُلثَ سماكة إطار الورقة.
///    فرُسمت هنا بسماكة الإطار نفسها.
///
/// 📐 والمسارُ نفسُ مسار `check` في Phosphor: خطٌّ منكسر
///    (40,144) → (96,200) → (224,72) في مربّع 256، بأطرافٍ وزوايا مدوّرة.
///    وقياساتُه من تصدير المصمّم مكبّراً بكسلةً بكسلة: عرضُ العلامة
///    (بخطّها) 31% من الأيقونة، ومركزُها عند 60% من ارتفاعها.
class _CheckStroke extends CustomPainter {
  const _CheckStroke(this.color, this.iconSize, this.stroke);

  final Color color;
  final double iconSize;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    const p0 = Offset(40, 144), p1 = Offset(96, 200), p2 = Offset(224, 72);
    // صندوقُ خطّ المنتصف في وحدات Phosphor: 184×128 بدءاً من (40,72).
    // والعرضُ المرئيّ = هذا + سماكةُ الخطّ، فالمطلوب 0.31 ⇒ الصندوق أضيق.
    final w = iconSize * 0.31 - stroke;
    final h = w * 128 / 184;
    final left = size.width / 2 - w / 2;
    final top = size.height * 0.60 - h / 2;
    Offset m(Offset o) => Offset(
          left + (o.dx - 40) / 184 * w,
          top + (o.dy - 72) / 128 * h,
        );
    canvas.drawPath(
      Path()
        ..moveTo(m(p0).dx, m(p0).dy)
        ..lineTo(m(p1).dx, m(p1).dy)
        ..lineTo(m(p2).dx, m(p2).dy),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckStroke old) =>
      old.color != color || old.iconSize != iconSize || old.stroke != stroke;
}
