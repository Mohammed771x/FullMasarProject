// ==========================================
// 🔒 قوّة كلمة المرور — سياسةٌ واحدة في ملفٍ واحد
// ==========================================
// ⚠️ **لماذا ملفٌ مستقل؟** الشرطُ نفسه يُفحص في ثلاثة مواضع: شريطُ القوّة
//    تحت الحقل، وزرُّ «إنشاء حساب»، و`UserSession.signUp`. وثلاثُ نسخٍ من
//    الشرط تتفرّق عند أول تعديل — فيرى الطالب شريطاً أخضر ثم يُرفض طلبُه.
//
// 🔴 **ما تغيّر في مراجعة الأمان ٢٠٢٦-٠٩-٢٣:**
//
//    | القاعدة | كان | صار | السبب |
//    |---|---|---|---|
//    | الطول الأدنى | ٦ | **٨** | ٦ أرقام = مليونُ احتمال، تُخمَّن دون اتصال |
//    | قائمة الشائع | — | **٢٨ كلمة** | `12345678` تمرّ بكل شروط الطول |
//    | الحرفُ المكرَّر | — | **يُرفض** | `aaaaaaaa` ثمانيةُ أحرفٍ باحتمالٍ واحد |
//    | جزءُ البريد | — | **يُرفض** | من بريده `ahmed@…` كلمتُه `ahmed123` |
//
// ⚖️ **والحسابات القائمة لا تتأثر:** هذه سياسةُ **الإنشاء** وحدها. من سجّل
//    بكلمةٍ من ستّة أحرف يدخل بها كما كان — فحصُ الدخول هو «ليست فارغة»
//    لا غير. ورفعُ الحدّ على الدخول يحبس صاحبَ الحساب خارج حسابه.
//
// 📊 **والشريطُ ثلاثُ درجات لا خمس:** المستخدم لا يفرّق بين «٦٠٪» و«٧٠٪»،
//    والدرجةُ الرابعة تُغري بالتوقّف عند الثالثة. ثلاثٌ تُقرأ بلمحة.
library;

/// درجةُ القوّة كما تُعرض.
enum PasswordLevel {
  /// لا شيء مكتوب — لا شريط ولا رسالة.
  empty,

  /// مرفوضة: تحت الحدّ أو في قائمة الشائع.
  weak,

  /// مقبولة لكنها بسيطة — تمرّ، ويُنصح بتحسينها.
  fair,

  /// مقبولة وقوية.
  strong,
}

/// 🔐 نتيجةُ الفحص — درجةٌ للعرض، وسببُ الرفض إن وُجد.
class PasswordStrength {
  const PasswordStrength._(this.level, this.label, this.blocker);

  final PasswordLevel level;

  /// كلمةٌ واحدة تُعرض بجانب الشريط.
  final String label;

  /// سببُ المنع بالعربية — `null` يعني أن الكلمة **مقبولة**.
  ///
  /// ⚠️ هذا هو الحقلُ الذي يقرّر، لا [level]: فـ[PasswordLevel.fair]
  ///    مقبولةٌ وتُعرض برتقالية، و[PasswordLevel.weak] مرفوضةٌ دائماً.
  final String? blocker;

  bool get accepted => blocker == null && level != PasswordLevel.empty;

  /// عددُ المربّعات المملوءة في الشريط (من ثلاثة).
  int get filled => switch (level) {
        PasswordLevel.empty => 0,
        PasswordLevel.weak => 1,
        PasswordLevel.fair => 2,
        PasswordLevel.strong => 3,
      };

  static const _empty =
      PasswordStrength._(PasswordLevel.empty, '', 'اكتب كلمة المرور');

  /// 📏 الحدّ الأدنى — **٨** لا ٦. انظر جدول المراجعة أعلى الملف.
  static const int minLength = 8;

  /// 🔢 **الرقم كما يُعرض للطالب — هندياً لا لاتينياً.**
  ///
  /// ⚠️ `'$minLength'` تُخرج `8`، فتظهر «كلمة المرور 8 أحرف» — رقمٌ
  ///    لاتينيٌّ وحيدٌ في سطرٍ عربيّ، وخطُّه مغايرٌ فيُقرأ دخيلاً. وقاعدةُ
  ///    المشروع أن ما يُعرض في سياقٍ عربيّ **يُكتب بأرقامه**.
  ///    والثابتُ [minLength] يبقى `int` لأن المقارنة حساب لا عرض.
  static const String minLengthLabel = '٨';

  /// 🚫 كلماتٌ شائعة تُرفض مهما طالت.
  ///
  /// ⚠️ **ليست قائمةَ حمايةٍ شاملة** — عشرةُ ملايين كلمةٍ مسرَّبة لا تُشحن
  ///    في تطبيق. هذه أكثرُ ما يُكتب فعلاً حين يُطلب «ثمانية أحرف»، وهي
  ///    أولُ ما يجرّبه المهاجم. الحمايةُ الحقيقية سقفُ محاولات Firebase.
  static const Set<String> commonPasswords = {
    '12345678', '123456789', '1234567890', '123456', '12345',
    'password', 'password1', 'password123', 'passw0rd',
    'qwertyui', 'qwerty123', 'qwerty', '1q2w3e4r', 'qazwsxedc',
    'abc12345', 'abcd1234', 'a1b2c3d4', 'asdfghjk', 'asdfasdf',
    'iloveyou', 'sunshine', 'princess', 'football', 'baseball',
    'welcome1', 'admin123', 'letmein1', 'monkey12', 'dragon12',
    '11111111', '00000000', '11223344', '12341234',
  };

  /// 🧪 يفحص [raw] ويعيد درجتَه وسببَ رفضه.
  ///
  /// [email] و[name] اختياريان: حين يُمرَّران تُرفض الكلمةُ المشتقّة منهما
  /// (`ahmed@x.com` ⇒ `ahmed123` مرفوضة) — وهي أولُ ما يُخمَّن بعد الشائع.
  static PasswordStrength of(String raw, {String? email, String? name}) {
    if (raw.isEmpty) return _empty;

    final lower = raw.toLowerCase();

    // ① تحت الحدّ — لا نُكمل الفحص، فالطولُ شرطٌ قاطع.
    if (raw.length < minLength) {
      return PasswordStrength._(PasswordLevel.weak, 'قصيرة',
          'كلمة المرور $minLengthLabel أحرف على الأقل');
    }

    // ② شائعةٌ معروفة.
    if (commonPasswords.contains(lower)) {
      return const PasswordStrength._(PasswordLevel.weak, 'شائعة',
          'هذه كلمة مرور شائعة جداً — اختر غيرها');
    }

    // ③ حرفٌ واحدٌ مكرَّر، أو تسلسلٌ صاعد/هابط كامل.
    if (_singleCharacter(raw) || _sequential(lower)) {
      return const PasswordStrength._(PasswordLevel.weak, 'متوقّعة',
          'حروفٌ متكرّرة أو متتالية — امزج الأحرف والأرقام');
    }

    // ④ مشتقّةٌ من البريد أو الاسم.
    final derived = _derivedFrom(lower, email: email, name: name);
    if (derived != null) {
      return PasswordStrength._(PasswordLevel.weak, 'مكشوفة', derived);
    }

    // ⑤ مقبولة — تبقى درجتُها.
    return _score(raw) >= 3
        ? const PasswordStrength._(PasswordLevel.strong, 'قوية', null)
        : const PasswordStrength._(PasswordLevel.fair, 'متوسطة', null);
  }

  /// 🎚️ درجةُ التنوّع — كم صنفاً من المحارف استُعمل، وهل طالت الكلمة.
  ///
  /// ⚠️ **التنوّع لا يُشترط للقبول**: `correct horse battery` أقوى من
  ///    `Aa1@` رغم خلوّها من الرموز. فاشتراطُ رمزٍ خاصّ يدفع الناس إلى
  ///    `Password1!` — وهي أضعفُ وأسهلُ تخميناً. التنوّعُ **يرفع الدرجة**
  ///    ولا يمنع.
  static int _score(String p) {
    var s = 0;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    if (p.length >= 12) s++;
    if (p.length >= 16) s++;
    return s;
  }

  static bool _singleCharacter(String p) =>
      p.split('').every((c) => c == p[0]);

  /// `12345678` · `abcdefgh` · `87654321` — خطوةٌ ثابتة من أوله لآخره.
  static bool _sequential(String p) {
    if (p.length < 4) return false;
    final step = p.codeUnitAt(1) - p.codeUnitAt(0);
    if (step != 1 && step != -1) return false;
    for (var i = 2; i < p.length; i++) {
      if (p.codeUnitAt(i) - p.codeUnitAt(i - 1) != step) return false;
    }
    return true;
  }

  /// هل الكلمةُ هي البريدُ أو الاسمُ بزيادةٍ يسيرة؟
  static String? _derivedFrom(String lower, {String? email, String? name}) {
    final local = (email ?? '').trim().toLowerCase().split('@').first;
    if (local.length >= 4 && lower.contains(local)) {
      return 'لا تبنِ كلمة المرور من بريدك';
    }
    // ⚠️ **كلُّ كلمةٍ في الاسم لا أوّلُها وحدها.** «سالم Salim» أوّلُها
    //    عربيّ، وكلمةُ المرور تُكتب لاتينيةً — ففحصُ الأوّل وحده يترك
    //    `salim9988` تمرّ لصاحب هذا الاسم بالضبط.
    for (final part in (name ?? '').trim().toLowerCase().split(RegExp(r'\s+'))) {
      if (part.length >= 4 && lower.contains(part)) {
        return 'لا تبنِ كلمة المرور من اسمك';
      }
    }
    return null;
  }
}
