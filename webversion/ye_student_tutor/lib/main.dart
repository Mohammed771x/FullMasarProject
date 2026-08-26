
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // ← أضف هذا
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ye_student_tutor/models/chat_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/chat_storage.dart';
import 'instructions/app_instructions.dart';
import 'dart:math' as math;
import 'dart:io';  // ← أضف هذا السطر

final String apiBaseUrl = kDebugMode ? 'http://127.0.0.1:8000' : 'https://mohammed771-my-tutor-backend.hf.space';


// ==========================================
// 🎨 نظام الألوان الجديد (Modern Premium AI)
// ==========================================
// 🌙 ريموت التحكم بالوضع الداكن (Global Notifier)
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);
// ==========================================
// 🎨 نظام الألوان الذكي (يدعم الفاتح والداكن)
// ==========================================
class AppColors {
  // الألوان الأساسية (لا تتغير)
  static const Color primary = Color(0xFF3B82F6); 
  static const Color secondary = Color(0xFF8B5CF6);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // 🌙 الألوان المتغيرة بناءً على الوضع
  static Color get bgLight => isDarkModeNotifier.value ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get surfaceWhite => isDarkModeNotifier.value ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get softSurface => isDarkModeNotifier.value ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
  
  static Color get textPrimary => isDarkModeNotifier.value ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => isDarkModeNotifier.value ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // الظلال
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: isDarkModeNotifier.value ? Colors.black.withOpacity(0.3) : primary.withOpacity(0.12),
      blurRadius: 30,
      offset: const Offset(0, 10),
    )
  ];
  
  static List<BoxShadow> get bubbleShadow => [
    BoxShadow(
      color: isDarkModeNotifier.value ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
      blurRadius: 15,
      offset: const Offset(0, 4),
    )
  ];
}

// ==========================================
// ✨ أدوات الأنيميشن السلسة (Apple-Level Smoothness)
// ==========================================
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final double delay;
  final Offset beginOffset;

  FadeInSlide({
    Key? key,
    required this.child,
    this.delay = 0,
    this.beginOffset = const Offset(0, 0.1),
  }) : super(key: key);

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _offsetAnimation = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInCubic);

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnimation, child: SlideTransition(position: _offsetAnimation, child: widget.child));
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _animations = _controllers.map((controller) => Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOutSine))).toList();
    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      _controllers[i].repeat(reverse: true);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => AnimatedBuilder(
        animation: _controllers[index],
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _animations[index].value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8, height: 8,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
        ),
      )),
    );
  }
}

// ==========================================
// 📚 نظام التعليمات
// ==========================================
// ==========================================
// 📚 نظام التعليمات (مربوط بالملف الخارجي والذاكرة الدائمة)
// ==========================================
class InstructionsDialog {
  static Future<void> showIfNeeded(BuildContext context, String subject, {bool forceShow = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String storageKey = 'instruction_shown_$subject';
    final bool hasBeenShown = prefs.getBool(storageKey) ?? false;

    // إذا ظهرت مسبقاً ولم يطلبها الطالب يدوياً، لا تظهرها مرة أخرى
    if (hasBeenShown && !forceShow) return;

    // جلب البيانات من الملف الخارجي
    final instructionData = AppInstructions.data[subject] ?? AppInstructions.data["احياء"]!;
    final String instructionText = instructionData["text"]!;
    final String videoUrl = instructionData["video_url"]!;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite.withOpacity(0.98),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: AppColors.primary.withOpacity(0.1))),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.tips_and_updates_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 15),
            Text("كيف تستخدم مسار؟", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videoUrl.isNotEmpty) ...[
                InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse(videoUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "اضغط هنا لمشاهدة الفيديو التعليمي لاستخدام هذا القسم",
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                          )
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: AppColors.softSurface, height: 1),
                const SizedBox(height: 16),
              ],
              Text(
                instructionText, 
                style: TextStyle(fontSize: 15, height: 1.8, color: AppColors.textSecondary)
              ),
            ],
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(20)),
            child: TextButton(
              onPressed: () async {
                // ✅ حفظ في الذاكرة الدائمة أن الطالب قرأ التعليمات ولن تظهر مجدداً
                await prefs.setBool(storageKey, true);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("فهمت، ابدأ الآن 🚀", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  
  await ChatStorage.init();
  final prefs = await SharedPreferences.getInstance();
  final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;
  final bool isActivated = prefs.getBool('isActivated') ?? false;
  isDarkModeNotifier.value = prefs.getBool('isDarkMode') ?? false;
  Widget homeScreen = isFirstRun ? const AnimatedWelcomeScreen() : (!isActivated ? const ActivationScreen() : const YEStudentTutorApp(showDrawerHelp: false));

  runApp(
    ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'منصة مسار',
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.bgLight,
            textTheme: GoogleFonts.cairoTextTheme().apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary, 
              background: AppColors.bgLight,
              brightness: isDark ? Brightness.dark : Brightness.light, // 👈 مهم جداً
            ),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          home: homeScreen,
        );
      },
    ),
  );
}

class YEStudentTutorApp extends StatelessWidget {
  final bool showDrawerHelp;
  const YEStudentTutorApp({super.key, required this.showDrawerHelp});
  @override
  Widget build(BuildContext context) { return MainChatScreen(showDrawerHelp: showDrawerHelp); }
}

// ==========================================
// 🚀 شاشة الترحيب (Onboarding - Premium Cinematic Version)
// ==========================================
class AnimatedWelcomeScreen extends StatefulWidget {
  const AnimatedWelcomeScreen({super.key});
  @override
  State<AnimatedWelcomeScreen> createState() => _AnimatedWelcomeScreenState();
}

class _AnimatedWelcomeScreenState extends State<AnimatedWelcomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -15, end: 15).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onNext() async {
    // ✅ غيرناها إلى 3 لأن صار عندنا 4 صفحات بدال 3
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstRun', false);
      if (mounted) Navigator.pushReplacement(context, PageRouteBuilder(transitionDuration: const Duration(milliseconds: 1000), pageBuilder: (_, __, ___) => const ActivationScreen(), transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)));
    }
  }

  void _onPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          Positioned(top: -150, left: -100, child: _buildGlowOrb(AppColors.primary, 400)),
          Positioned(bottom: -100, right: -150, child: _buildGlowOrb(AppColors.secondary, 500)),
          
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            physics: const BouncingScrollPhysics(),
            children: [ 
              _buildPage(Icons.bubble_chart_rounded, "مرحباً بكم في مسار", "وجهتك الأولى للتعليم الذكي.\nرفيقك الدائم لشرح المواد وتلخيصها بذكاء."), 
              _buildPage(Icons.psychology_rounded, "عقلٌ اصطناعي متطور", "تم بناء هذه المنصة بأحدث تقنيات الذكاء الاصطناعي لخدمة الطالب اليمني."), 
              
              // ✅ صارت الشاشة الثالثة هنا!
              _buildDeveloperPage(), 

              _buildPage(Icons.rocket_launch_rounded, "انطلق نحو المستقبل", "احصل على شروحات، تلخيصات، وأسئلة وزارية مصممة خصيصاً لمنهجك الدراسي.")
            ],
          ),
          
          Positioned(
            bottom: 60, left: 30, right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _currentPage > 0 ? _onPrevious : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    decoration: BoxDecoration(
                      color: _currentPage > 0 ? AppColors.surfaceWhite : AppColors.softSurface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _currentPage > 0 ? AppColors.primary.withOpacity(0.3) : Colors.transparent, width: 1.5),
                      boxShadow: _currentPage > 0 ? AppColors.softShadow : []
                    ),
                    child: Text("رجوع", style: TextStyle(color: _currentPage > 0 ? AppColors.primary : AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                
                // ✅ غيرنا العداد إلى 4
                Row(
                  children: List.generate(4, (index) => 
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 10,
                      height: 10,
                      decoration: BoxDecoration(color: _currentPage == index ? AppColors.primary : AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12))
                    )
                  )
                ),
                
                GestureDetector(
                  onTap: _onNext,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                    decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(30), boxShadow: AppColors.softShadow),
                    // ✅ غيرنا الشرط لـ 3 عشان تظهر كلمة ابدأ الآن في آخر صفحة
                    child: Text(_currentPage == 3 ? "ابدأ الآن" : "التالي", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

 // خدعة الـ RadialGradient لشاشة الترحيب (تعديل الشفافية والانتشار)
  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        )
      ),
    );
  }
  Widget _buildPage(IconData icon, String title, String desc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _floatAnimation, 
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _floatAnimation.value), 
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(color: AppColors.surfaceWhite.withOpacity(0.8), shape: BoxShape.circle, boxShadow: AppColors.softShadow, border: Border.all(color: AppColors.surfaceWhite, width: 3)),
              child: Icon(icon, size: 90, color: AppColors.primary),
            )
          )
        ),
        const SizedBox(height: 70),
        FadeInSlide(delay: 0.2, child: Text(title, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5))),
        const SizedBox(height: 24),
        FadeInSlide(delay: 0.4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: TypewriterText(text: desc, isCentered: true))),
      ],
    );
  }
  

  // ✅ تصميم شاشة المطور الأنيقة
  // ✅ تصميم شاشة المطور (متناسق 100% مع باقي الواجهات)
  Widget _buildDeveloperPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _floatAnimation, 
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _floatAnimation.value), 
            child: Container(
              padding: const EdgeInsets.all(48), // نفس مقاس الواجهات السابقة
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite.withOpacity(0.8), // خلفية بيضاء
                shape: BoxShape.circle, 
                boxShadow: AppColors.softShadow, 
                border: Border.all(color: AppColors.surfaceWhite, width: 3)
              ),
              // أيقونة لابتوب/مبرمج عصرية باللون الأزرق
              child: Icon(Icons.laptop_mac_rounded, size: 90, color: AppColors.primary), 
            )
          )
        ),
        const SizedBox(height: 70), // نفس المسافة في الواجهات الثانية
        FadeInSlide(
          delay: 0.2,
          child: Text("هندسة وتطوير 👨‍💻", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)) // عبارة جديدة وفخمة
        ),
        const SizedBox(height: 24),
        FadeInSlide(
          delay: 0.4,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40), 
            child: Text(
              "تم بناء هذا الذكاء الاصطناعي لخدمة الطلاب وتسهيل مسيرتهم التعليمية من قبل المطور:\nم. محمد الديني",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.8, fontWeight: FontWeight.w600)
            )
          )
        ),
        const SizedBox(height: 35),
        FadeInSlide(
          delay: 0.6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDevChip(Icons.phone_rounded, "780278574"),
              const SizedBox(width: 12),
              _buildDevChip(Icons.camera_alt_rounded, "Instagram"),
              const SizedBox(width: 12),
              _buildDevChip(Icons.email_rounded, "Email"),
            ],
          )
        ),
      ],
    );
  }

  Widget _buildDevChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1))
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))
        ],
      ),
    );
  }
}



class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";

  Future<void> _verifyCode() async {
    setState(() { _isLoading = true; _errorMessage = ""; });
    if (_codeController.text.trim().isEmpty) { 
      setState(() { _isLoading = false; _errorMessage = "⚠️ الرجاء إدخال كود التفعيل أولاً"; }); 
      return; 
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String deviceId = prefs.getString('device_id') ?? const Uuid().v4();
      await prefs.setString('device_id', deviceId);
      
      final String baseUrl = kDebugMode ? "http://127.0.0.1:8000" : "https://mohammed771-my-tutor-backend.hf.space";
      
      final response = await http.post(
        Uri.parse("$baseUrl/verify-access"), 
        headers: {"Content-Type": "application/json"}, 
        body: jsonEncode({"code": _codeController.text.trim(), "device_id": deviceId})
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data["status"] == "success") {
            await prefs.setBool('isActivated', true); 
            await prefs.setString('user_code', _codeController.text.trim());
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const YEStudentTutorApp(showDrawerHelp: true)));
          } else if (data["status"] == "invalid_code") {
            setState(() => _errorMessage = "🔐 الكود غير صحيح، تأكد من الكود وحاول مجدداً.");
          } else if (data["status"] == "already_used") {
            setState(() => _errorMessage = "⛔ هذا الكود مستخدم مسبقاً على جهاز آخر.");
          } else if (data["status"] == "expired") {
            setState(() => _errorMessage = "⌛ انتهت صلاحية هذا الكود، تواصل مع الدعم.");
          } else {
            setState(() => _errorMessage = data["message"] ?? "❌ كود غير صحيح أو منتهي الصلاحية.");
          }
        } catch (formatException) {
          setState(() => _errorMessage = "⚠️ استجابة غير صالحة من الخادم.");
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() => _errorMessage = "🔐 الكود غير صحيح أو غير مصرح به.");
      } else if (response.statusCode >= 500) {
        setState(() => _errorMessage = "🔴 السيرفر طافي حالياً، حاول مجدداً بعد قليل.");
      } else {
        setState(() => _errorMessage = "⚠️ حدث خطأ غير متوقع. الرمز: ${response.statusCode}");
      }
      
    } on TimeoutException catch (_) {
       setState(() => _errorMessage = "⏱️ السيرفر لا يستجيب حالياً، حاول مجدداً بعد دقيقة.");
    } on SocketException catch (_) {
       setState(() => _errorMessage = "📡 لا يوجد اتصال بالإنترنت، تأكد من الواي فاي أو البيانات.");
    } catch (e) {
      setState(() => _errorMessage = "❌ حدث خطأ غير معروف، تواصل مع الدعم الفني.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: AppColors.bgLight,
       body: Stack(
         children: [
           Positioned(top: -150, left: -50, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary.withOpacity(0.05)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)))),
           
           Center(
             child: SingleChildScrollView(
               padding: const EdgeInsets.all(30.0),
               child: FadeInSlide(
                 child: Container(
                   padding: const EdgeInsets.all(40),
                   decoration: BoxDecoration(color: AppColors.surfaceWhite.withOpacity(0.9), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white, width: 2), boxShadow: AppColors.softShadow),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.softSurface, shape: BoxShape.circle), child: Icon(Icons.lock_person_rounded, size: 50, color: AppColors.primary)),
                       const SizedBox(height: 30),
                       Text("تفعيل منصة مسار", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                       const SizedBox(height: 12),
                       Text("أدخل الكود السري للوصول للذكاء الاصطناعي.\n(سيتم ربط الكود بجهازك الحالي)\n\nكود التفعيل التجريبي: SHAHED_USER", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 14)),
                       const SizedBox(height: 40),
                       TextField(
                         controller: _codeController, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4, color: AppColors.textPrimary),
                         decoration: InputDecoration(hintText: "••••••••", hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 4), filled: true, fillColor: AppColors.softSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 20)),
                       ),
                       if (_errorMessage.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 15), child: Text(_errorMessage, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))),
                       const SizedBox(height: 35),
                       Container(
                         width: double.infinity, height: 65,
                         decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                         child: ElevatedButton(
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                           onPressed: _isLoading ? null : _verifyCode,
                           child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("تأكيد التفعيل", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           ),
         ],
       ),
    );
  }
}
// ==========================================
// 🌌 الشاشة الرئيسية (شات بوت مسار الأسطوري)
// ==========================================
class MainChatScreen extends StatefulWidget {
  final bool showDrawerHelp;
  const MainChatScreen({super.key, this.showDrawerHelp = false});
  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> with TickerProviderStateMixin {
  final String userId = const Uuid().v4();
  final TextEditingController _inputController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final Map<String, List<Map<String, dynamic>>> _allChatsHistory = {};
  
  // Logic Variables (Untouched)
  String? currentConversationId;
  List<ChatConversation> conversations = [];
  String selectedMathBranch = "";
  String mathMode = "";
  List<String> physicsLessons = [];
  // 🟢 الكيمياء
  List<String> chemistryLessons = [];
  String selectedChemistryLesson = "";
  // 🟢 العربي
  List<String> arabicLessons = [];
  String selectedArabicLesson = "";
  // 🟢 الإنجليزي
  List<String> englishLessons = [];
  String selectedEnglishLesson = "";
  String selectedPhysicsLesson = "";

  // 🟢 متغيرات العربي الوزاري
  String selectedArabicExamYear = "";
  String selectedArabicExamSection = "";
  String selectedArabicExamType = ""; // لحفظ خيار (قطعة أو أسئلة عامة)
  final TextEditingController _arabicQuestionCountController = TextEditingController(text: "5");
  final List<String> arabicExamSections = ["أولاً: القراءة", "ثانياً: الأدب والنصوص والنقد", "ثالثاً: النحو والصرف", "رابعاً: التعبير"];
  final List<String> arabicExamTypes = ["قطعة", "أسئلة عامة"];

  // 🟢 متغيرات الإنجليزي الوزاري
  String selectedEnglishExamYear = "";
  String selectedEnglishQuestionType = "";
  final TextEditingController _englishQuestionCountController = TextEditingController(text: "5");
  
// قائمة فارغة ستتعبأ تلقائياً من السيرفر
  List<String> englishQuestionTypes = [];

  List<String> mathLessons = [];
  List<String> mathExamYears = [];
  List<String> mathExamLessons = [];
  String selectedMathExamYear = "";
  String selectedMathExamLesson = "";
  final TextEditingController _questionCountController = TextEditingController(text: "10");
  String selectedLesson = "";
  List<String> availableUnits = [];
  String selectedUnit = "الكل";
  final List<String> mathBranches = ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"];
  String selectedExamYear = "";
  String selectedSubject = "احياء";
  String selectedMode = "شرح";
  String inputType = "برومت";
  String selectedUnitName = "الكل";
  int summaryLevel = 3;
  bool isLoading = false;
  bool sessionActive = false;
  bool mathWazariQuestionsLoaded = false;
  bool _instructionsShown = false;
  List<Map<String, dynamic>> messages = [];
  List<String> availableYears = [];
  final List<String> subjects = ["احياء", "فيزياء", "كيمياء", "عربي", "انجليزي", "رياضيات"];
  http.Client? _activeHttpClient;
  bool _isResponseCancelled = false;
  bool _isMathExplanationStarted = false;
  // ✅ إضافة مراقب لإيقاف أنيميشن الكتابة فوراً
  final ValueNotifier<bool> _stopTypingNotifier = ValueNotifier(false);
  // UI State
  bool _showSettingsPanel = true;

  late AnimationController _fadeController;

  int? _lastAIMessageIndex;
  StreamSubscription? _typingStreamSubscription;
  http.Client _createHttpClient() {
    return http.Client();
  }

void _stopCurrentRequest() {
  // ✅ الشرط الجديد: هل التطبيق يحمل البيانات أو يكتب الأنيميشن؟
  bool isAnimating = messages.isNotEmpty && messages.last["animating"] == true;
  if (!isLoading && !isAnimating) return; 
  
  // 1. أوقف الـ HTTP request إذا كان لا يزال يحمل
  if (_activeHttpClient != null) {
    try {
      _activeHttpClient?.close();
    } catch (e) {
      debugPrint('Error closing HTTP client: $e');
    }
    _activeHttpClient = null;
  }

  // 2. إطلاق رصاصة الإيقاف للأنيميشن (يوقف عند نفس الحرف)
  _stopTypingNotifier.value = true;

  setState(() {
    isLoading = false;
    _isResponseCancelled = true;
  });

  // 3. عرض رسالة تأكيد للمستخدم
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "⏹️ تم إيقاف الإجابة",
        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.orange.shade700,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    )
  );
}

@override
void initState() {
  super.initState();
  _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  _loadConversations();
  _createNewConversation();
  loadAvailableUnits();

  // ✅ التعديل: إظهار التعليمات مرة واحدة فقط في أول فتح
  if (widget.showDrawerHelp) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InstructionsDialog.showIfNeeded(context, selectedSubject);
    });
  }
}


@override
void dispose() {
  try {
    // 1. احفظ آخر محادثة
    if (currentConversationId != null && messages.isNotEmpty) {
      _saveCurrentConversation();
    }

    // 2. ألغِ أي طلب شغال
    if (isLoading) {
      _stopCurrentRequest();
    }

    // 3. أغلق الـ HTTP client بأمان
    try {
      _activeHttpClient?.close();
    } catch (e) {
      debugPrint('Error closing HTTP client in dispose: $e');
    }
    _activeHttpClient = null;

    // 4. ألغِ الـ Subscriptions
    _typingStreamSubscription?.cancel();

    // 5. أغلق الـ ValueNotifiers
    _stopTypingNotifier.dispose();

    // 6. أغلق الـ AnimationControllers
    _fadeController.dispose();

    // 7. أغلق الـ TextEditingControllers
    _inputController.dispose();
    _scrollController.dispose();
    _questionCountController.dispose();
    _arabicQuestionCountController.dispose();
    _englishQuestionCountController.dispose();

    super.dispose();
  } catch (e) {
    debugPrint('Error in dispose: $e');
    super.dispose();
  }
}


 String _getCurrentChatKey() {
  // لكل mode من كل subject يكون chat منفصل
  if (selectedSubject == "رياضيات") {
    return "رياضيات_${selectedMathBranch}_$mathMode";
  } else {
    return "${selectedSubject}_$selectedMode";
  }
}


  // ========== [APIs & Logic Functions - Untouched] ==========
  void _showUpdateCodeDialog({bool isError = false}) {
    final TextEditingController _updateCodeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: !isError,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isError ? Colors.red.withOpacity(0.1) : AppColors.softSurface, borderRadius: BorderRadius.circular(12)),
              child: Icon(isError ? Icons.error_outline : Icons.vpn_key_rounded, color: isError ? Colors.redAccent : AppColors.primary),
            ),
            const SizedBox(width: 15),
            Text(isError ? "تنبيه هام" : "تحديث الكود", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isError)
              Padding(
                padding: EdgeInsets.only(bottom: 15),
                child: Text("⛔ كود التفعيل المستخدم حالياً غير صالح أو انتهت صلاحيته.\nيرجى إدخال الكود الجديد للمتابعة.", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, height: 1.5), textAlign: TextAlign.center),
              ),
            TextField(
              controller: _updateCodeController,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: "أدخل الكود الجديد هنا",
                hintStyle: TextStyle(letterSpacing: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.softSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 18)
              ),
            ),
          ],
        ),
        actions: [
          if (!isError) TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            onPressed: () async {
              if (_updateCodeController.text.trim().isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_code', _updateCodeController.text.trim());
                await prefs.setBool('isActivated', true);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم تحديث الكود بنجاح! حاول الإرسال الآن.", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating));
                }
              }
            },
            child: Text("حفظ وتحديث", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

 Future<void> loadEnglishLessons(String unitName) async {
    try {
      final uri = Uri.parse("$apiBaseUrl/subjects/lessons").replace(
        queryParameters: {
          "subject": "انجليزي",
          "unit": unitName,
        }
      );

      final res = await http.get(
        uri,
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) {
          setState(() {
            englishLessons = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes)));
            selectedEnglishLesson = "";
          });
        }
      } else {
         _showDataErrorSnackBar("حدث خطأ في السيرفر أثناء جلب دروس الإنجليزي.");
      }
    } catch (e) {
      _showDataErrorSnackBar("تأكد من اتصالك بالإنترنت لجلب الدروس.");
    }
  }


Future<void> loadExamSections(String subject, String year) async {
    try {
      final uri = Uri.parse("$apiBaseUrl/exams/sections").replace(
        queryParameters: {
          "subject": subject,
          "year": year,
        }
      );

      final res = await http.get(
        uri,
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            if (subject == "انجليزي") {
              englishQuestionTypes = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes)));
              selectedEnglishQuestionType = ""; // تصفير الاختيار السابق ليختار من القائمة الجديدة
            }
          });
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب صيغ الأسئلة من السيرفر.");
      }
    } catch (e) {
      _showDataErrorSnackBar("مشكلة في الاتصال أثناء جلب صيغ الأسئلة.");
    }
  }


Future<void> loadArabicLessons(String unitName) async {
    try {
      final uri = Uri.parse("$apiBaseUrl/subjects/lessons").replace(
        queryParameters: {
          "subject": "عربي",
          "unit": unitName,
        }
      );

      final res = await http.get(
        uri,
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) {
          setState(() {
            arabicLessons = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes)));
            selectedArabicLesson = "";
          });
        }
      } else {
        _showDataErrorSnackBar("حدث خطأ في السيرفر أثناء جلب دروس العربي.");
      }
    } catch (e) {
      _showDataErrorSnackBar("تأكد من اتصالك بالإنترنت لجلب الدروس.");
    }
  }

  Future<void> loadPhysicsLessons(String unitName) async { 
    try { 
      final uri = Uri.parse("$apiBaseUrl/subjects/lessons").replace(
        queryParameters: {
          "subject": "فيزياء",
          "unit": unitName,
        }
      );

      final res = await http.get(
        uri, 
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) {
          setState(() { 
            physicsLessons = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes))); 
            selectedPhysicsLesson = ""; 
          }); 
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب دروس الفيزياء.");
      }
    } catch (e) { 
      _showDataErrorSnackBar("مشكلة في الاتصال بالإنترنت.");
    } 
  }

void _switchContext(VoidCallback updateSettings) {
    setState(() {
      // 1. حفظ المحادثة الحالية قبل الانتقال
      String currentKey = _getCurrentChatKey();
      if (messages.isNotEmpty) _allChatsHistory[currentKey] = List.from(messages);
      
      // 2. تنفيذ التغيير (تغيير المادة أو الوضع)
      updateSettings();
      
      // ✅ 3. تصفير حالة زر شرح الرياضيات (هنا الإضافة!)
      _isMathExplanationStarted = false; 

      // 4. استرجاع المحادثة الجديدة (إن وجدت)
      String newKey = _getCurrentChatKey();
      messages = List.from(_allChatsHistory[newKey] ?? []);
      
      // 5. تأثيرات بصرية
      _fadeController.reset();
      _fadeController.forward();
      
      // 6. تحميل البيانات المطلوبة للمادة الجديدة
      if (selectedSubject != "رياضيات") {
        if (selectedMode == "وزاري") loadAvailableYears();
        else loadAvailableUnits();
      }
      if (selectedSubject == "كيمياء") {
          chemistryLessons = [];
          selectedChemistryLesson = "";
        }
        
        // ✅ تصفير دروس الفيزياء لما تنقل
        if (selectedSubject == "فيزياء") {
          physicsLessons = [];
          selectedPhysicsLesson = "";
        }


        if (selectedSubject == "عربي") {
          arabicLessons = [];
          selectedArabicLesson = "";
          
          selectedArabicExamYear = "";
          selectedArabicExamSection = "";
        }

if (selectedSubject == "انجليزي") {
          englishLessons = [];
          selectedEnglishLesson = "";
          selectedEnglishExamYear = "";
          selectedEnglishQuestionType = "";
        }

      WidgetsBinding.instance.addPostFrameCallback((_) => InstructionsDialog.showIfNeeded(context, selectedSubject));
    });
  }
bool _validateArabicExamInputs() {
  List<String> errors = [];
  
  if (selectedArabicExamYear.isEmpty) {
    errors.add("اختر السنة الوزارية");
  }
  if (selectedArabicExamSection.isEmpty) {
    errors.add("اختر القسم");
  }
  if (selectedArabicExamType.isEmpty) {
    errors.add("اختر نوع التدريب");
  }
  
  if (errors.isNotEmpty) {
    // اعرض رسالة الأخطاء
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            Text("الحقول المطلوبة", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors.map((err) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    err,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("فهمت", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
    return false;
  }
  
  return true;
}

Future<void> loadChemistryLessons(String unitName) async {
    try {
      final uri = Uri.parse("$apiBaseUrl/subjects/lessons").replace(
        queryParameters: {
          "subject": "كيمياء",
          "unit": unitName,
        }
      );

      final res = await http.get(
        uri,
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) {
          setState(() {
            chemistryLessons = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes)));
            selectedChemistryLesson = "";
          });
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب دروس الكيمياء.");
      }
    } catch (e) {
      _showDataErrorSnackBar("مشكلة في الاتصال بالإنترنت.");
    }
  }
// ==========================================
  // 🛡️ دالة مساعدة لعرض أخطاء جلب البيانات (مضادة للانهيار 100%)
  // ==========================================
  void _showDataErrorSnackBar(String message) {
    if (mounted) {
      // 🔴 التعديل السحري: إضافة addPostFrameCallback لمنع التعارض مع الـ Build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
            backgroundColor: Colors.redAccent.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          )
        );
      });
    }
  }
  void _loadConversations() { setState(() { conversations = ChatStorage.getConversationsBySubject(selectedSubject)..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated)); }); }
  void _createNewConversation() { setState(() { currentConversationId = const Uuid().v4(); messages = []; sessionActive = false; _showSettingsPanel = true; }); }
  void _loadConversation(ChatConversation conversation) { setState(() { currentConversationId = conversation.id; messages = conversation.messages.map((m) => {'role': m.role, 'text': m.text, 'refs': m.refs, 'animating': false}).toList(); selectedMode = conversation.mode; _showSettingsPanel = false; }); ChatStorage.updateLastUsed(conversation.id); Navigator.pop(context); _scrollToBottom(); }
  Future<void> _saveCurrentConversation() async { if (currentConversationId == null || messages.isEmpty) return; String title = messages.first['text'] ?? 'محادثة جديدة'; if (title.length > 50) title = '${title.substring(0, 47)}...'; final chatMessages = messages.map((m) => ChatMessage(role: m['role'], text: m['text'], refs: List<String>.from(m['refs'] ?? []))).toList(); final conversation = ChatConversation(id: currentConversationId!, title: title, subject: selectedSubject, mode: selectedMode, messages: chatMessages); await ChatStorage.saveConversation(conversation); _loadConversations(); }
  Future<void> _deleteConversation(String id) async { await ChatStorage.deleteConversation(id); if (currentConversationId == id) _createNewConversation(); _loadConversations(); }
 Future<void> loadAvailableYears() async { 
    try { 
      final uri = Uri.parse("$apiBaseUrl/exams/years").replace(
        queryParameters: {
          "subject": selectedSubject,
        }
      );

      final res = await http.get(
        uri, 
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) { 
        if(mounted) {
          setState(() { 
            availableYears = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes)).map((y) => y.toString()))..sort((a, b) => b.compareTo(a)); 
          }); 
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب سنوات الاختبار. السيرفر مشغول.");
      }
    } catch (e) { 
      _showDataErrorSnackBar("مشكلة في الاتصال أثناء جلب السنوات.");
    } 
  }
  Future<void> loadMathLessons(String branch) async { 
    try { 
      final uri = Uri.parse("$apiBaseUrl/math/lessons").replace(
        queryParameters: {
          "branch": branch,
        }
      );

      final res = await http.get(
        uri, 
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) setState(() => mathLessons = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes)))); 
      } else {
        _showDataErrorSnackBar("تعذر جلب دروس الرياضيات.");
      }
    } catch (e) { 
      _showDataErrorSnackBar("تأكد من الإنترنت لجلب دروس الرياضيات.");
    } 
  }

 Future<void> loadMathExamYears(String branch) async { 
    try { 
      final uri = Uri.parse("$apiBaseUrl/math/exams/years").replace(
        queryParameters: {
          "branch": branch,
        }
      );

      final res = await http.get(
        uri, 
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) {
          setState(() { 
            mathExamYears = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes))); 
            selectedMathExamYear = ""; 
            mathExamLessons = []; 
            selectedMathExamLesson = ""; 
          }); 
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب سنوات الرياضيات.");
      }
    } catch (e) { 
      _showDataErrorSnackBar("مشكلة في الاتصال.");
    } 
  }

  // 🟢 جلب دروس وزاري الرياضيات
 Future<void> loadMathExamLessons(String branch, String year) async { 
    try { 
      final uri = Uri.parse("$apiBaseUrl/math/exams/lessons").replace(
        queryParameters: {
          "branch": branch,
          "year": year,
        }
      );

      final res = await http.get(
        uri, 
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if(mounted) {
          setState(() { 
            mathExamLessons = List<String>.from(jsonDecode(utf8.decode(res.bodyBytes))); 
            selectedMathExamLesson = ""; 
          }); 
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب الدروس الوزارية.");
      }
    } catch (e) { 
      _showDataErrorSnackBar("تأكد من اتصالك بالإنترنت.");
    } 
  }
  // ==========================================
  // 🧭 نظام البوصلة (تحديد مسار الطالب الحالي)
  // ==========================================
  String _truncateText(String text, int maxWords) {
    if (text.isEmpty) return "";
    List<String> words = text.split(' ');
    if (words.length <= maxWords) return text;
    return "${words.take(maxWords).join(' ')}..."; // يقص النص ويضيف نقاط
  }

  String _getCurrentLocationText() {
    List<String> path = [selectedSubject]; // دائماً نبدأ باسم المادة

    if (selectedSubject == "رياضيات") {
      if (selectedMathBranch.isNotEmpty) path.add(selectedMathBranch);
      if (selectedLesson.isNotEmpty) path.add(_truncateText(selectedLesson, 4));
    } else {
      if (selectedUnit != "الكل" && selectedUnit.isNotEmpty) {
        path.add(_truncateText(selectedUnit, 3));
      }
      
      String currentLesson = "";
      if (selectedSubject == "فيزياء") currentLesson = selectedPhysicsLesson;
      else if (selectedSubject == "كيمياء") currentLesson = selectedChemistryLesson;
      else if (selectedSubject == "عربي") currentLesson = selectedArabicLesson;
      else if (selectedSubject == "انجليزي") currentLesson = selectedEnglishLesson;
      // الأحياء لا يوجد فيها اختيار درس في الكود الحالي، تعتمد على الوحدة

      if (currentLesson.isNotEmpty) {
        path.add(_truncateText(currentLesson, 4));
      }
    }

    return path.join(' • '); // نستخدم النقطة كفاصل أنيق وآمن للغة العربية
  }


 Future<void> loadAvailableUnits() async { 
    try { 
      final uri = Uri.parse("$apiBaseUrl/subjects/units").replace(
        queryParameters: {
          "subject": selectedSubject,
        }
      );

      final res = await http.get(
        uri, 
        headers: {"ngrok-skip-browser-warning": "true"}
      ).timeout(const Duration(seconds: 10)); // مهلة 10 ثوانٍ كحد أقصى

      if (res.statusCode == 200) { 
        final List<dynamic> units = jsonDecode(utf8.decode(res.bodyBytes)); 
        if(mounted) {
          setState(() { 
            availableUnits = ["الكل"]; 
            for (var unit in units) { 
              if (unit.toString().isNotEmpty && unit != "الكل") availableUnits.add(unit.toString()); 
            } 
            selectedUnit = "الكل"; 
          }); 
        }
      } else {
        _showDataErrorSnackBar("تعذر جلب وحدات $selectedSubject. السيرفر مشغول.");
      }
    } catch (e) { 
      _showDataErrorSnackBar("مشكلة في الاتصال. تأكد من الإنترنت.");
      debugPrint("Error loading units: $e");
    } 
  }
// ========== دالة processRequest معدلة كاملة ==========

// ✅ دالة تفصيل الأخطاء (أضفها قبل processRequest)
String _getDetailedErrorMessage(dynamic error) {
  if (error is TimeoutException) {
    return "⏱️ انتهت مهلة الانتظار\nاستغرق الطلب وقتاً طويلاً جداً.\nقد يكون السيرفر مشغول. حاول مجدداً بعد دقيقة.";
  } 
  else if (error is SocketException) {
    return "📡 خطأ في الاتصال\n• تأكد من وصول الإنترنت\n• السيرفر قد يكون مغلقاً حالياً";
  } 
  else if (error is FormatException) {
    return "⚠️ خطأ في البيانات\nالبيانات المستقبلة من السيرفر غير مفهومة (ربما السيرفر يعاد تشغيله).";
  }
  else if (error is http.ClientException) { 
    return "🔗 انقطع الاتصال\nلم نتمكن من إكمال التخاطب مع السيرفر.";
  }
  else {
    return "❌ خطأ غير معروف\nحاول مجدداً أو تواصل مع الدعم الفني.";
  }
}

Future<void> processRequest({String? customText}) async {
  // ✅ حماية 1: تحقق من الشروط الأساسية
  final text = customText ?? _inputController.text.trim();
  final String baseUrl = kDebugMode ? "http://127.0.0.1:8000" : "https://mohammed771-my-tutor-backend.hf.space";
  
  bool isMathWazari = selectedSubject == "رياضيات" && mathMode == "وزاري" && text.isNotEmpty;
  bool isMathExplain = selectedSubject == "رياضيات" && mathMode == "شرح" && selectedLesson.isNotEmpty;

  if (text.isEmpty && customText == null && !isMathExplain) return;
  
  // ✅ حماية 2: لا تسمح بطلبين معاً
  if (isLoading) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⏳ يرجى انتظار الرد الحالي أو إيقافه أولاً.",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    return; 
  }

  if (currentConversationId == null) _createNewConversation();
  _stopTypingNotifier.value = false;

  // ✅ حماية 3: أضف رسالة الطالب للواجهة
  setState(() {
    _showSettingsPanel = false;
    _isResponseCancelled = false;
    
    if (customText == null) {
      if (selectedSubject == "رياضيات" && mathMode == "شرح" && text.isEmpty) {
        messages.add({"role": "user", "text": "شرح درس: $selectedLesson"});
      } else {
        messages.add({"role": "user", "text": text});
      }
    } else if (selectedSubject == "رياضيات" && mathMode == "وزاري") {
      final parts = text.split('|');
      if (parts.length >= 2) {
        messages.add({"role": "user", "text": "جلب أسئلة وزاري: ${parts[1]} (${parts[0]})"});
      } else {
        messages.add({"role": "user", "text": text});
      }
    } else {
      messages.add({"role": "user", "text": text});
    }

    _inputController.clear();
    isLoading = true;
  });

  _scrollToBottom();

  // ==================================================
  // 🚀 محاولة واحدة فقط (بدون Loop) بحد أقصى دقيقتين
  // ==================================================
  try {
    final chatHistory = messages.reversed
        .take(10)
        .map((m) => {"role": m["role"], "content": m["text"]})
        .toList()
        .reversed
        .toList();

    String finalContentToSend = text;
    String finalLessonName = "";
    
    if (selectedSubject == "فيزياء") finalLessonName = selectedPhysicsLesson;
    else if (selectedSubject == "كيمياء") finalLessonName = selectedChemistryLesson;
    else if (selectedSubject == "عربي") finalLessonName = selectedArabicLesson;
    else if (selectedSubject == "انجليزي") finalLessonName = selectedEnglishLesson;
    else if (selectedSubject == "رياضيات") finalLessonName = selectedLesson;

    if (selectedSubject != "رياضيات" && selectedMode == "وزاري" && customText == null) {
      finalContentToSend = "$selectedExamYear,$text";
    }

    final prefs = await SharedPreferences.getInstance();
    final String savedCode = prefs.getString('user_code') ?? "";
    String deviceId = prefs.getString('device_id') ?? const Uuid().v4();

    // إغلاق أي اتصال سابق للتنظيف
    try { _activeHttpClient?.close(); } catch (_) {}
    
    _activeHttpClient = _createHttpClient();

    // ⏱️ تعيين المهلة الزمنية إلى 60 ثانية (دقيقة) بالضبط
    final response = await _activeHttpClient!
        .post(
          Uri.parse("$baseUrl/ask"),
          headers: {
            "Content-Type": "application/json",
            "ngrok-skip-browser-warning": "true"
          },
          body: jsonEncode({
            "user_id": userId,
            "code": savedCode,
            "device_id": deviceId,
            "subject": selectedSubject,
            "mode": selectedMode,
            "input_type": inputType,
            "summary_level": summaryLevel,
            "lesson_name": finalLessonName,
            "content": finalContentToSend,
            "unit_name": (selectedSubject == "رياضيات") ? selectedMathBranch : selectedUnit,
            "chat_history": chatHistory,
          }),
        )
        .timeout(
          const Duration(seconds: 60), // مهلة 60 ثانية لانتظار الرد
          onTimeout: () => throw TimeoutException("Timeout after 120s"),
        );

    // إذا ضغط المستخدم على إيقاف أثناء التحميل
    if (_isResponseCancelled || !mounted) return;

    // 🔴 حالة الكود الخاطئ
    if (response.statusCode == 401 || response.statusCode == 403) {
      setState(() {
        isLoading = false;
        messages.add({
          "role": "system",
          "text": "🔐 **كود التفعيل غير صالح**\nيرجى تحديث الكود من الإعدادات.",
          "refs": [],
          "animating": false,
        });
      });
      _showUpdateCodeDialog(isError: true);
      return;
    }

    // ✅ حالة النجاح
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": data["answer"] ?? "لا يوجد رد",
          "refs": data["references"] ?? [],
          "animating": true,
          "fullText": data["answer"] ?? "لا يوجد رد",
        });
        _lastAIMessageIndex = messages.length - 1;
        sessionActive = data["session_active"] ?? false;
      });
      await _saveCurrentConversation();
      _scrollToBottom();
    } else {
      throw HttpException("Server error: ${response.statusCode}");
    }

  } on TimeoutException catch (_) {
    // ⏱️ انتهت الدقيقتان (يتم قطع الاتصال وعرض رسالة)
    if (mounted && !_isResponseCancelled) {
      setState(() {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": "⏱️ **عذراً، السيرفر مشغول جداً حالياً**\n\nاستغرق الطلب وقتاً أطول من اللازم.\nالرجاء المحاولة مرة أخرى أو طرح سؤال مختلف.",
          "refs": [],
          "animating": false,
          "isError": true
        });
      });
      _scrollToBottom();
    }
  } on SocketException catch (_) {
    // 📡 انقطع الإنترنت
    if (mounted && !_isResponseCancelled) {
      setState(() {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": "📡 **تعذر الاتصال بالخادم**\n\nتأكد من اتصالك بالإنترنت وحاول مجدداً.",
          "refs": [],
          "animating": false,
          "isError": true
        });
      });
      _scrollToBottom();
    }
  } catch (e) {
    // ❌ أخطاء أخرى
    if (mounted && !_isResponseCancelled) {
      setState(() {
        isLoading = false;
        messages.add({
          "role": "ai",
          "text": "⚠️ **حدث خطأ غير متوقع**\n\nيرجى المحاولة لاحقاً.",
          "refs": [],
          "animating": false,
          "isError": true
        });
      });
      _scrollToBottom();
    }
  } finally {
    // 🔪 القتل النهائي للاتصال (تحرير موارد التطبيق والسيرفر)
    try {
      _activeHttpClient?.close();
    } catch (_) {}
    _activeHttpClient = null;
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}



  void _scrollToBottom() {
  Future.delayed(const Duration(milliseconds: 100), () {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic
      );
    }
  });
}

  // ========== [الواجهة العصرية الأسطورية - Redesigned UI] ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgLight,
      drawer: _buildModernDrawer(),
      extendBodyBehindAppBar: true, // Let chat flow behind appbar for full immersion
      appBar: PreferredSize(
        // 👈 خلينا الارتفاع ديناميكي: 70 بيكسل + حجم شريط الإشعارات عشان ما يضيق على النص أبدًا
        preferredSize: Size.fromHeight(90 + MediaQuery.of(context).padding.top), 
        child: _buildGlassAppBar(),
      ),
      body: Stack(
        children: [
          // 1️⃣ الخلفية (اللمعان)
          Positioned(top: -100, right: -50, child: _buildBgGlow(AppColors.secondary.withOpacity(0.06))),
          Positioned(bottom: 0, left: -50, child: _buildBgGlow(AppColors.primary.withOpacity(0.04))),
          
          // 2️⃣ قائمة المحادثة (تملأ الشاشة كاملة وتصير خلف خانة الكتابة)
          // شلنا الـ Column والـ Expanded وخليناها تملأ الشاشة مباشرة
          Positioned.fill(
            child: _buildChatList(), 
          ),

          // 3️⃣ خانة الكتابة وأزرار التحكم (مثبتة في الأسفل)
          // 3️⃣ خانة الكتابة وأزرار التحكم (مثبتة في الأسفل)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                // أزرار التحكم (تظهر فقط في وضع الوزاري)
                if (sessionActive && selectedMode == "وزاري") _buildControlButtons(),
                
                // ✅ زر بدء الشرح (يظهر دائماً في وضع شرح الرياضيات)
               // في بناء زر الشرح للرياضيات:
if (selectedSubject == "رياضيات" && mathMode == "شرح") 
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // ✅ رسالة التنبيه إذا ما اختار درس
      if (selectedLesson.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1.5
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "اختر درس من القائمة أعلاه لبدء الشرح الذكي 📚",
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      
      const SizedBox(height: 12),
      
      // الزر الرئيسي
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: selectedLesson.isNotEmpty ? AppColors.mainGradient : null,
            color: selectedLesson.isEmpty ? AppColors.softSurface : null,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selectedLesson.isNotEmpty ? AppColors.softShadow : []
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
            ),
            onPressed: selectedLesson.isNotEmpty ? () {
              setState(() => _isMathExplanationStarted = true);
              processRequest();
            } : null,
            child: Text(
              "🚀 ابدأ الشرح الذكي",
              style: TextStyle(
                fontSize: 18,
                color: selectedLesson.isNotEmpty ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold
              )
            )
          ),
        ),
      ),
    ],
  ),
                
                // ✅ خانة الكتابة العائمة
                // الشرط: تظهر دائماً، إلا في حالة (رياضيات + شرح) وما ضغط الزر لسه
                
                  _buildModernInputArea(),
              ],
            ),
          ),

          // 4️⃣ القائمة المنبثقة للإعدادات (فوق كل شيء)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            bottom: _showSettingsPanel ? 90 : -MediaQuery.of(context).size.height,
            left: 16,
            right: 16,
            child: _buildModernExpandableSelectors(),
          ),
        ],
      ),
    );
  }
// خدعة الـ RadialGradient تعطي نفس تأثير البلور ولكنها خفيفة جداً وسريعة كالبرق
 // استبدل الدالة القديمة بهذا الكود لإخفاء اللمعان الملون تماماً
  Widget _buildBgGlow(Color color) {
    return const SizedBox.shrink(); // هذا الأمر يعني "لا ترسم أي شيء هنا"
  }

  Widget _buildGlassAppBar() {
  bool isLoadingMsg = isLoading || 
      (messages.isNotEmpty && messages.last["animating"] == true);

  // تم إلغاء ClipRRect و BackdropFilter
  return Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 10,
      bottom: 15,
      left: 20,
      right: 20
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceWhite.withOpacity(0.98), // لون شبه صلب ليغطي الرسائل تحته
      border: Border(
        bottom: BorderSide(
          color: isLoadingMsg 
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.textPrimary.withOpacity(0.05)
        )
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // زر القائمة
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.softSurface, // لون صلب
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 22),
          ),
        ),
        
        // العنوان + بوصلة المسار
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "مسار الطالب",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5
                    ),
                  ),
                  if (isLoadingMsg) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  ]
                ],
              ),
              const SizedBox(height: 4),
              
              // بوصلة المسار الديناميكية
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6), 
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _getCurrentLocationText(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary
                        ),
                        overflow: TextOverflow.ellipsis, 
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // زر المساعدة
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            InstructionsDialog.showIfNeeded(context, selectedSubject, forceShow: true);
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.softSurface, // لون صلب
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.tips_and_updates_rounded, color: AppColors.secondary, size: 22),
          ),
        ),
      ],
    ),
  );
}
  // 2️⃣ New Bottom Control Panel (Cards instead of dropdowns where possible)
  Widget _buildModernExpandableSelectors() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("إعدادات الجلسة", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _showSettingsPanel = false),
                )
              ],
            ),
            const SizedBox(height: 16),
            _buildModeSelectorModern(),
            if (selectedSubject == "رياضيات") ...[
              const SizedBox(height: 16), _buildMathBranchSelectorModern(),
              if (mathMode == "وزاري" && selectedMathBranch.isNotEmpty) _buildMathExamSelectorModern(),
              if (mathLessons.isNotEmpty && mathMode != "وزاري") ...[
  const SizedBox(height: 12),
  _buildModernDropdown(
    hint: "اختر الدرس",
    value: selectedLesson.isEmpty ? null : selectedLesson,
    items: mathLessons,
    onChanged: (v) => setState(() => selectedLesson = v ?? ""),
    icon: Icons.menu_book_rounded
  ),
],
              if (selectedMathBranch.isNotEmpty) const SizedBox(height: 12), _buildMathModeSelectorModern(),
            ],
            if (selectedSubject != "رياضيات") _buildUnitFilterAreaModern(),
            if (selectedMode == "تلخيص" && selectedSubject != "رياضيات") _buildSummarySliderModern(),
            if (selectedSubject != "رياضيات" && selectedMode != "سؤال" && selectedMode != "وزاري") _buildInputTypeSelectorModern(),
          ],
        ),
      ),
    );
  }

 Widget _buildUnitFilterAreaModern() {
    // 🔴 وضع الوزاري - نفس للجميع
    if (selectedMode == "وزاري") {
      if (selectedSubject == "رياضيات") {
        return const SizedBox.shrink(); // الرياضيات لها إعداداتها تحت
      }

      // 👇 هذا القسم الخاص باللغة العربية حصراً 👇
      // ========== الحل الصحيح - استبدل القسم الخاص بالعربي ==========

// 👇 هذا القسم الخاص باللغة العربية حصراً 👇
if (selectedSubject == "عربي") {
  // ✅ تحقق من البيانات بدون عرض Dialog بعد
  bool isArabicReady = selectedArabicExamYear.isNotEmpty && 
                       selectedArabicExamSection.isNotEmpty && 
                       selectedArabicExamType.isNotEmpty;
  
  return Column(
    children: [
      const SizedBox(height: 16),
      _buildModernDropdown(
        hint: "اختر السنة الوزارية",
        value: selectedArabicExamYear.isEmpty ? null : selectedArabicExamYear,
        items: availableYears,
        onChanged: (v) => setState(() => selectedArabicExamYear = v!),
        icon: Icons.calendar_today_rounded
      ),
      const SizedBox(height: 12),
      _buildModernDropdown(
        hint: "اختر القسم",
        value: selectedArabicExamSection.isEmpty ? null : selectedArabicExamSection,
        items: arabicExamSections,
        onChanged: (v) => setState(() {
          selectedArabicExamSection = v!;
          selectedArabicExamType = ""; // تصفير النوع عند تغيير القسم
        }),
        icon: Icons.category_rounded
      ),
      const SizedBox(height: 12),
      if (selectedArabicExamSection.isNotEmpty)
        _buildModernDropdown(
          hint: "نوع التدريب (قطعة أم أسئلة عامة؟)",
          value: selectedArabicExamType.isEmpty ? null : selectedArabicExamType,
          items: arabicExamTypes,
          onChanged: (v) => setState(() => selectedArabicExamType = v!),
          icon: Icons.filter_alt_rounded
        ),
      
      if (selectedArabicExamType.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(selectedArabicExamType == "قطعة" ? "عدد القطع:" : "عدد الأسئلة:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _arabicQuestionCountController, 
                  keyboardType: TextInputType.number, 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
                    filled: true, 
                    fillColor: AppColors.softSurface, 
                    contentPadding: const EdgeInsets.symmetric(vertical: 8)
                  ),
                ),
              ),
            ],
          ),
        ),
      ],

      const SizedBox(height: 16),
      
      // ✅ الحل: استخدم الفحص المباشر بدون Dialog
      SizedBox(
        width: double.infinity, 
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isArabicReady ? AppColors.primary : Colors.grey.shade300,
            foregroundColor: isArabicReady ? Colors.white : Colors.grey,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
            elevation: isArabicReady ? 4 : 0
          ),
          onPressed: isArabicReady ? () {
            final count = int.tryParse(_arabicQuestionCountController.text) ?? (selectedArabicExamType == "قطعة" ? 1 : 5);
            String content = "$selectedArabicExamYear|$selectedArabicExamSection|$selectedArabicExamType|$count";
            setState(() => _showSettingsPanel = false);
            processRequest(customText: content); 
          } : null,
          icon: Icon(Icons.download_rounded, size: 20),
          label: Text("جلب الأسئلة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
      
      // ✅ رسالة توضيحية إذا ما اختار كل شيء
      if (!isArabicReady)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            "اختر جميع الخيارات أولاً",
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ]
  );
}
      
      // 👇 هذا القسم الخاص باللغة الإنجليزية حصراً 👇
// 👇 هذا القسم الخاص باللغة الإنجليزية حصراً 👇
      if (selectedSubject == "انجليزي") {
        return Column(
          children: [
            const SizedBox(height: 16),
            _buildModernDropdown(
              hint: "Choose Exam Year",
              value: selectedEnglishExamYear.isEmpty ? null : selectedEnglishExamYear,
              items: ["الكل", ...availableYears], // ✅ أضفنا "الكل" ليتمكن من جلب كل السنوات
              onChanged: (v) {
                setState(() {
                  selectedEnglishExamYear = v!;
                  // 🔥 السطر اللي كان ناقصك: هنا نكلم السيرفر يجيب صيغ الأسئلة بمجرد ما يختار السنة!
                  loadExamSections("انجليزي", v);
                });
              },
              icon: Icons.calendar_today_rounded
            ),
            const SizedBox(height: 12),
            _buildModernDropdown(
              hint: "Choose Question Type",
              value: selectedEnglishQuestionType.isEmpty ? null : selectedEnglishQuestionType,
              items: englishQuestionTypes,
              onChanged: (v) => setState(() => selectedEnglishQuestionType = v!),
              icon: Icons.category_rounded
            ),
            
            if (selectedEnglishQuestionType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(selectedEnglishQuestionType.contains("passage") || selectedEnglishQuestionType.contains("paragraph") ? "Number of Passages:" : "Number of Questions:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _englishQuestionCountController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: AppColors.softSurface, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                onPressed: selectedEnglishExamYear.isEmpty || selectedEnglishQuestionType.isEmpty ? null : () {
                  final count = int.tryParse(_englishQuestionCountController.text) ?? 5;
                  String content = "$selectedEnglishExamYear|$selectedEnglishQuestionType|$count";
                  setState(() => _showSettingsPanel = false);
                  processRequest(customText: content);
                },
                icon: Icon(Icons.rocket_launch_rounded, size: 20),
                label: Text("Start Practice", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        );
      }
      
      // 👇 لبقية المواد (فيزياء، كيمياء، أحياء) 👇
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _buildModernDropdown(
          hint: "اختر السنة الوزارية",
          value: selectedExamYear.isEmpty ? null : selectedExamYear,
          items: ["الكل", ...availableYears],
          onChanged: (v) => setState(() => selectedExamYear = v!),
          icon: Icons.calendar_today_rounded
        ),
      );
    }
    
    // 🟡 الأحياء فقط - نظام الصفحات والوحدات
    if (selectedSubject == "احياء") {
      return Column(
        children: [
          const SizedBox(height: 16),
          _buildModernDropdown(
            hint: "اختر الوحدة",
            value: selectedUnit.isEmpty ? null : selectedUnit,
            items: availableUnits.toSet().toList(),
            onChanged: (v) {
              setState(() {
                selectedUnit = v ?? "الكل";
                selectedUnitName = selectedUnit;
              });
            },
            icon: Icons.library_books_rounded
          ),
        ],
      );
    }
    
 // 🔵 الفيزياء والكيمياء والعربي والإنجليزي
if (selectedSubject == "فيزياء" || selectedSubject == "كيمياء" || selectedSubject == "عربي" || selectedSubject == "انجليزي") {
  return Column(
    children: [
      const SizedBox(height: 16),
      _buildModernDropdown(
        hint: "اختر الوحدة",
        value: selectedUnit.isEmpty ? null : selectedUnit,
        items: availableUnits.toSet().toList(),
        onChanged: (v) {
          setState(() {
            selectedUnit = v ?? "الكل";
            selectedUnitName = selectedUnit;
            if (selectedSubject == "فيزياء" && selectedUnit != "الكل") {
              loadPhysicsLessons(selectedUnit);
            }
            if (selectedSubject == "كيمياء" && selectedUnit != "الكل") {
              loadChemistryLessons(selectedUnit);
            }
            if (selectedSubject == "عربي" && selectedUnit != "الكل") {
              loadArabicLessons(selectedUnit);
            }
            if (selectedSubject == "انجليزي" && selectedUnit != "الكل") {
              loadEnglishLessons(selectedUnit);
            }
          });
        },
        icon: Icons.library_books_rounded
      ),
      // الدروس للفيزياء
      if (selectedSubject == "فيزياء" && physicsLessons.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildModernDropdown(
          hint: "اختر الدرس",
          value: selectedPhysicsLesson.isEmpty ? null : selectedPhysicsLesson,
          items: physicsLessons,
          onChanged: (v) => setState(() => selectedPhysicsLesson = v ?? ""),
          icon: Icons.science_rounded
        ),
      ],
      // الدروس للكيمياء
      if (selectedSubject == "كيمياء" && chemistryLessons.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildModernDropdown(
          hint: "اختر الدرس",
          value: selectedChemistryLesson.isEmpty ? null : selectedChemistryLesson,
          items: chemistryLessons,
          onChanged: (v) => setState(() => selectedChemistryLesson = v ?? ""),
          icon: Icons.science_rounded
        ),
      ],
      // الدروس للعربي
      if (selectedSubject == "عربي" && arabicLessons.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildModernDropdown(
          hint: "اختر الدرس",
          value: selectedArabicLesson.isEmpty ? null : selectedArabicLesson,
          items: arabicLessons,
          onChanged: (v) => setState(() => selectedArabicLesson = v ?? ""),
          icon: Icons.language_rounded
        ),
      ],
      // 🟢 الدروس للإنجليزي
      if (selectedSubject == "انجليزي" && englishLessons.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildModernDropdown(
          hint: "اختر الدرس",
          value: selectedEnglishLesson.isEmpty ? null : selectedEnglishLesson,
          items: englishLessons,
          onChanged: (v) => setState(() => selectedEnglishLesson = v ?? ""),
          icon: Icons.language_rounded
        ),
      ],
    ],
  );
}
    
    return const SizedBox.shrink();
  }
  Widget _buildModernDropdown({required String hint, required String? value, required List<String> items, required Function(String?) onChanged, IconData icon = Icons.folder_rounded}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true, icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          hint: Row(children: [Icon(icon, size: 20, color: AppColors.primary), const SizedBox(width: 12), Text(hint, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600))]),
          value: value,
          dropdownColor: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

Widget _buildModernDrawer() {
  return Container(
    width: MediaQuery.of(context).size.width * 0.85,
    decoration: BoxDecoration(
      color: AppColors.surfaceWhite,
      border: Border(left: BorderSide(color: AppColors.softSurface))
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ Header 
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10), 
                    decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(16)), 
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20)
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("منصة مسار", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                        Text("Premium Education", style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold))
                      ]
                    )
                  )
                ],
              ),
            ),
            
            // ✅ زر محادثة جديدة 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () { _createNewConversation(); Navigator.pop(context); },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary, 
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                      )
                    ]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 18), 
                      const SizedBox(width: 8), 
                      const Text("محادثة جديدة", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))
                    ]
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // ✅ الخيارات 
            _buildDrawerItem(Icons.library_books_rounded, "الموارد", () { Navigator.pop(context); _showResourcesDialog(); }, 12),
            _buildDrawerItem(Icons.vpn_key_rounded, "تحديث الكود", () { Navigator.pop(context); _showUpdateCodeDialog(isError: false); }, 12),
            _buildDrawerItem(Icons.support_agent_rounded, "المطور", () { Navigator.pop(context); _showDeveloperInfoDialog(context); }, 12),
            
            // 🌙 زر الوضع الداكن
            ValueListenableBuilder<bool>(
              valueListenable: isDarkModeNotifier,
              builder: (context, isDark, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      isDarkModeNotifier.value = !isDark;
                      setState(() {}); 
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('isDarkMode', isDarkModeNotifier.value);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary.withOpacity(0.1) : AppColors.softSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.primary.withOpacity(0.3) : Colors.transparent)
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? AppColors.primary : Colors.orange.shade600,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isDark ? "الوضع الداكن مفعّل" : "تفعيل الوضع الداكن",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.primary : AppColors.textPrimary,
                                fontSize: 13
                              )
                            )
                          ),
                          Switch(
                            value: isDark,
                            onChanged: (val) async {
                              isDarkModeNotifier.value = val;
                              setState(() {}); 
                              final prefs = await SharedPreferences.getInstance();
                              prefs.setBool('isDarkMode', val);
                            },
                            activeColor: AppColors.primary,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
            
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Divider(height: 1, color: AppColors.softSurface)),
            
            // ✅ عنوان المواد
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "المواد الدراسية",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3)
                )
              )
            ),
            
            // ✅ قائمة المواد - تظهر كاملة بدون Expanded
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: subjects.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _switchContext(() { 
                        selectedUnit = "الكل"; 
                        availableUnits = []; 
                        selectedSubject = s; 
                        sessionActive = false; 
                        selectedExamYear = ""; 
                        availableYears = []; 
                        _loadConversations(); 
                        _createNewConversation(); 
                        if (s == "رياضيات") { 
                          selectedMathBranch = ""; 
                          mathMode = "شرح"; 
                          selectedMode = "شرح"; 
                          selectedLesson = ""; 
                          mathLessons = []; 
                          inputType = "برومت"; 
                        } else { 
                          selectedMode = "شرح"; 
                          inputType = "برومت"; 
                        } 
                      });
                      loadAvailableUnits(); 
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedSubject == s ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.book_rounded, size: 18, color: selectedSubject == s ? AppColors.primary : AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Text(s, style: TextStyle(fontSize: 13, color: selectedSubject == s ? AppColors.primary : AppColors.textPrimary, fontWeight: selectedSubject == s ? FontWeight.bold : FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),

            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Divider(height: 1, color: AppColors.softSurface)),
            
            // ✅ عنوان المحادثات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "المحادثات السابقة",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3)
                )
              )
            ),
            
            // ✅ قائمة المحادثات بحجم ثابت
            SizedBox(
              height: 300,
              child: _buildConversationsList(),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

 Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, [double padding = 24]) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.textPrimary, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13))),
          ],
        ),
      ),
    );
  }

 Widget _buildConversationsList() {
  if (conversations.isEmpty) return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text("لا توجد محادثات بعد.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    )
  );
  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.only(top: 0),
    itemCount: conversations.length,
    itemBuilder: (context, index) {
      final conv = conversations[index];
      final isActive = conv.id == currentConversationId;
      return InkWell(
        onTap: () => _loadConversation(conv),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: isActive ? AppColors.softSurface : Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 18, color: isActive ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  conv.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? AppColors.primary : AppColors.textPrimary
                  )
                )
              ),
              IconButton(
                icon: Icon(Icons.edit_rounded, size: 18, color: AppColors.secondary),
                onPressed: () => _showRenameDialog(conv),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                onPressed: () => _showDeleteConfirmationDialog(conv.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _showResourcesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(children: [ Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.folder_special_rounded, color: AppColors.primary)), const SizedBox(width: 15), Text("مركز الموارد", style: TextStyle(fontWeight: FontWeight.w800))]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
_buildResourceCard("📐 الرياضيات", [
                  {"name": "ملخص التفاضل", "url": "https://drive.google.com/drive/folders/1hIojvkK09LT7IcqaK5aGoEV_vrrVZjLs"}, 
                  {"name": "ملخص الجبر", "url": "https://drive.google.com/drive/folders/1m8QVLyM6tbG5buQNDdGwNCRbV_28bsxA"},
                  {"name": "ملخص التكامل", "url": "https://drive.google.com/drive/u/1/folders/1ao83kRRVKk40VOAsgnLcjDeOodIyHNri"},
                  {"name": "ملخص الهندسة", "url": "https://drive.google.com/drive/u/1/folders/1TWxdgszrwzxCQW2uRSXkv7VZrIKIGvGV"},
                  {"name": "ملخص الاحتمالات", "url": "https://drive.google.com/drive/u/1/folders/1Sx-ZJqwjORzFwQR5EDVrVd32mkjkI_lh"},
                   {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"}
                ]),
                _buildResourceCard("🧬 الأحياء", [
                  {"name": "ملخصات الأحياء", "url": "https://drive.google.com/drive/u/1/folders/1LLzIsWFKiZOkrr6DUaagm9RVmBdKKDQn"}, 
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"}
                ]),
                _buildResourceCard("⚛️ الكيمياء", [
                  {"name": "ملخصات الكيمياء", "url": "https://drive.google.com/drive/u/1/folders/1_9YpbhSvG4-qcVihLU10o8muFFPh0Gqt"}, // 👈 عدل هذا
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"} // 👈 عدل هذا (كان نفس حق الأحياء)
                ]),
                _buildResourceCard("🔬 الفيزياء", [
                  {"name": "ملخص الفيزياء", "url": "https://drive.google.com/drive/folders/1ATQPwJNXYf-yidgXjhkW7E7AaqYev2vc"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"} // 👈 عدل هذا (كان نفس حق الأحياء)
                ]),
                _buildResourceCard("📜 اللغة العربية", [
                  {"name": "ملخص النحو", "url": "https://drive.google.com/drive/u/1/folders/13Ec4BtxzxvJTOrR9_BriUGfr1HszU3M1"},
                   {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"} // 👈 عدل هذا
                ]),
                _buildResourceCard("🔤 اللغة الإنجليزية", [
                  {"name": "ملخصات الانجليزي", "url": "https://drive.google.com/drive/u/1/folders/1hEE0h4iBkgNRDsoy9OOVfL1eNFzYeiHU"},
                   {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"} // 👈 عدل هذا
                ]),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إغلاق", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)))],
      ),
    );
  }
  
  // ✅ نافذة الدعم والمطور الفاخرة
  void _showDeveloperInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                shape: BoxShape.circle,
                boxShadow: AppColors.softShadow
              ),
              child: Icon(Icons.code_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text("م. محمد الديني", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              "تم تطوير هذا الذكاء الاصطناعي بكل حب لخدمة الطلاب وتسهيل العملية التعليمية.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            // ✅ أزرار التواصل التفاعلية
            _buildContactRow(
              icon: Icons.phone_rounded, 
              title: "رقم الهاتف (واتساب / اتصال)", 
              subtitle: "917736388574+", 
              // ✅ التعديل هنا: أضفنا https:// وحددنا إنه يفتح كتطبيق خارجي
              onTap: () => launchUrl(
                Uri.parse("https://wa.me/917736388574"), 
                mode: LaunchMode.externalApplication
              )
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.camera_alt_rounded, 
              title: "انستقرام", 
              subtitle: "@mo_37ui", 
              onTap: () => launchUrl(
                Uri.parse("https://www.instagram.com/mo_37ui?igsh=MTJxZHB1cTQ5bmEwdg%3D%3D&utm_source=qr"),
                mode: LaunchMode.externalApplication
              )
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.email_rounded, 
              title: "البريد الإلكتروني", 
              subtitle: "bfsak530156@gmail.com", 
              onTap: () => launchUrl(Uri.parse("mailto:bsak530156@gmail.com")) // 👈 حط إيميلك هنا
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إغلاق", style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  Widget _buildContactRow({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
  Widget _buildResourceCard(String title, List<Map<String, String>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(20)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          children: items.map((item) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
            title: Text(item['name']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            trailing: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.download_rounded, color: AppColors.primary, size: 16)),
            onTap: () async { if (await canLaunchUrl(Uri.parse(item['url']!))) { await launchUrl(Uri.parse(item['url']!), mode: LaunchMode.externalApplication); } },
          )).toList(),
        ),
      ),
    );
  }

  // 4️⃣ Premium Chat Bubbles
 // 4️⃣ Premium Chat Bubbles
  Widget _buildChatList() {
  return ListView.builder(
    controller: _scrollController,
    padding: EdgeInsets.only(
          left: 16, 
          right: 16, 
          bottom: 160, // مساحة كافية لخانة الكتابة والزر عشان ما تغطي آخر رسالة
          top: MediaQuery.of(context).padding.top + 85 // مساحة للبار العلوي
      ),
    itemCount: messages.length + (isLoading ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == messages.length) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 10, bottom: 20, top: 10),
            child: TypingIndicator(),
          ),
        );
      }

      final msg = messages[i];
      final isUser = msg["role"] == "user";
      
      return FadeInSlide(
        delay: 0.0,
        beginOffset: Offset(isUser ? -0.05 : 0.05, 0),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  margin: const EdgeInsets.only(left: 10, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.bubbleShadow
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
                ),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: isUser ? 4 : 12), 
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isUser ? AppColors.bubbleGradient : null,
                        color: isUser ? null : AppColors.surfaceWhite,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(24),
                          topRight: const Radius.circular(24),
                          bottomLeft: Radius.circular(isUser ? 24 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 24)
                        ),
                        boxShadow: AppColors.bubbleShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text("مسار AI", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold))
                            ),
                          if (msg["animating"] == true && !isLoading)
                            TypewriterText(
                              text: msg["fullText"] ?? msg["text"],
                              stopNotifier: _stopTypingNotifier,   
                              onTyping: () {
                                if (_scrollController.hasClients) {
                                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                                }
                              },
                              onStopped: (stoppedText) {
                            if (mounted) {
                              setState(() {
                                msg["text"] = "$stoppedText\n\n⏹️ *تم الإيقاف*"; 
                                msg["animating"] = false;
                              });
                              _saveCurrentConversation(); 
                            }
                          },
                              onFinished: () {
                                if (mounted) {
                                  setState(() {
                                    msg["animating"] = false;
                                  });
                                  _saveCurrentConversation();
                                }
                              },
                            )
                          else
                            MarkdownBody(
                              data: msg["text"],
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: isUser ? Colors.white : AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.6
                                )
                              )
                            ),
                          if (msg["refs"] != null && (msg["refs"] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (msg["refs"] as List)
                                    .map<Widget>((ref) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.softSurface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.primary.withOpacity(0.1))
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.link_rounded, size: 12, color: AppColors.secondary),
                                          const SizedBox(width: 6),
                                          // ✅ التعديل هنا: غلفناه بـ Flexible وخلينا فلاتر هو اللي يقص بناءً على حجم شاشة الجوال
                                          Flexible(
                                            child: Tooltip(
                                              message: "$ref",
                                              child: Text(
                                                "$ref", // رجعنا المتغير كامل بدون دالة القص
                                                style: TextStyle(
                                                  fontSize: 11, 
                                                  fontWeight: FontWeight.bold, 
                                                  color: AppColors.textSecondary
                                                ),
                                                overflow: TextOverflow.ellipsis, // السحر هنا: يقص النص تلقائياً لو خلصت الشاشة
                                                maxLines: 1, // يجبره يكون في سطر واحد
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ))
                                    .toList()
                              )
                            ),

                          // 👇 زر النسخ للذكاء الاصطناعي (تم التعديل للاحترافية) 👇
                          if (!isUser) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final textToCopy = msg["fullText"] ?? msg["text"];
                                await Clipboard.setData(ClipboardData(text: textToCopy));
                                if (mounted) {
                                  setState(() {
                                    msg["isCopied"] = true; // تحويل للون الأخضر والصح
                                  });
                                  // إرجاع الزر لشكله الطبيعي بعد ثانيتين
                                  Future.delayed(const Duration(seconds: 2), () {
                                    if (mounted) {
                                      setState(() {
                                        msg["isCopied"] = false;
                                      });
                                    }
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: msg["isCopied"] == true ? Colors.green.withOpacity(0.1) : AppColors.softSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      msg["isCopied"] == true ? Icons.check_rounded : Icons.content_copy_rounded, 
                                      size: 14, 
                                      color: msg["isCopied"] == true ? Colors.green : AppColors.textSecondary
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      msg["isCopied"] == true ? "تم النسخ" : "نسخ", 
                                      style: TextStyle(
                                        fontSize: 11, 
                                        color: msg["isCopied"] == true ? Colors.green : AppColors.textSecondary, 
                                        fontWeight: FontWeight.bold
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // 👆 نهاية زر الذكاء الاصطناعي 👆

                        ],
                      ),
                    ),

                    // 👇 زر النسخ للطالب (تم التعديل للاحترافية) 👇
                    if (isUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, right: 6),
                        child: InkWell(
                          onTap: () async {
                            final textToCopy = msg["fullText"] ?? msg["text"];
                            await Clipboard.setData(ClipboardData(text: textToCopy));
                            if (mounted) {
                              setState(() {
                                msg["isCopied"] = true; // تحويل للون الأخضر والصح
                              });
                              // إرجاع الزر لشكله الطبيعي بعد ثانيتين
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() {
                                    msg["isCopied"] = false;
                                  });
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  msg["isCopied"] == true ? Icons.check_rounded : Icons.content_copy_rounded, 
                                  size: 13, 
                                  color: msg["isCopied"] == true ? Colors.green : AppColors.textSecondary
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  msg["isCopied"] == true ? "تم النسخ" : "نسخ", 
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: msg["isCopied"] == true ? Colors.green : AppColors.textSecondary.withOpacity(0.8), 
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 👆 نهاية زر الطالب 👆

                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}


void _showRenameDialog(ChatConversation conversation) {
  final TextEditingController _renameController = TextEditingController(text: conversation.title);
  
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text("تعديل اسم المحادثة", style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _renameController,
        style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: "اسم جديد...",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: AppColors.softSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: () async {
            final newTitle = _renameController.text.trim();
            if (newTitle.isNotEmpty) {
              final updated = ChatConversation(
                id: conversation.id,
                title: newTitle,
                subject: conversation.subject,
                mode: conversation.mode,
                messages: conversation.messages
              );
              await ChatStorage.saveConversation(updated);
              _loadConversations();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("✅ تم تعديل الاسم"), backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating)
              );
            }
          },
          child: Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold))
        )
      ],
    ),
  );
}


void _showDeleteConfirmationDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            Text("حذف المحادثة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "هل أنت متأكد أنك تريد حذف هذه المحادثة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            ),
            onPressed: () {
              Navigator.pop(ctx); // إغلاق النافذة
              _deleteConversation(id); // تنفيذ الحذف
              
              // رسالة تأكيد سريعة أسفل الشاشة
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("🗑️ تم حذف المحادثة بنجاح"), 
                  backgroundColor: Colors.redAccent, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                  behavior: SnackBarBehavior.floating
                )
              );
            },
            child: Text("حذف", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

Widget _buildModernInputArea() {
  bool canSend = _inputController.text.trim().isNotEmpty && !isLoading;
  bool isGenerating = isLoading || (messages.isNotEmpty && messages.last["animating"] == true);
  bool showTextInput = !(selectedSubject == "رياضيات" && mathMode == "شرح" && !_isMathExplanationStarted);

  return Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    color: Colors.transparent,
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1️⃣ زر الإعدادات
          InkWell(
            onTap: () => setState(() => _showSettingsPanel = !_showSettingsPanel),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: _showSettingsPanel ? AppColors.primary : AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.softShadow, // إضافة ظل خفيف للجمالية
                border: Border.all(
                  color: _showSettingsPanel ? Colors.transparent : AppColors.textSecondary.withOpacity(0.1), 
                  width: 1
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: _showSettingsPanel ? Colors.white : AppColors.textSecondary,
                size: 24,
              ),
            ),
          ),
          
          if (showTextInput) ...[
            const SizedBox(width: 10),

            // 2️⃣ خانة الكتابة
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite, // لون صلب سريع المعالجة
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: AppColors.softShadow, // ظل خفيف للبروز
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.1), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !isGenerating || messages.isEmpty,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary
                        ),
                        decoration: InputDecoration(
                          hintText: "اكتب سؤالك...",
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.6),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) {
                          if (canSend) processRequest();
                        },
                      ),
                    ),
                    
                    // زر الإرسال
                    Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: InkWell(
                        onTap: () {
                          if (isGenerating) {
                            _stopCurrentRequest();
                          } else if (canSend) {
                            processRequest();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("اكتب سؤالك أولاً ✍️", style: TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.orange.shade600,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: isGenerating ? null : (canSend ? AppColors.mainGradient : null),
                            color: isGenerating ? Colors.redAccent : (canSend ? null : AppColors.softSurface),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                            color: isGenerating ? Colors.white : (canSend ? Colors.white : AppColors.textSecondary),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildModeSelectorModern() {
    if (selectedSubject == "رياضيات") return const SizedBox.shrink();
    Map<String, IconData> modeIcons = {"شرح": Icons.auto_stories_rounded, "تلخيص": Icons.psychology_rounded, "سؤال": Icons.help_outline_rounded, "وزاري": Icons.gavel_rounded};
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: ["شرح", "تلخيص", "سؤال", "وزاري"].map((m) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ChoiceChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(modeIcons[m], size: 16, color: selectedMode == m ? Colors.white : AppColors.textSecondary), const SizedBox(width: 8), Text(m)]),
          selected: selectedMode == m, selectedColor: AppColors.primary, showCheckmark: false,
          labelStyle: TextStyle(color: selectedMode == m ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
          backgroundColor: AppColors.softSurface, 
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none), 
          onSelected: (_) => _switchContext(() { selectedMode = m; mathWazariQuestionsLoaded = false; if (selectedSubject == "فيزياء") { selectedPhysicsLesson = ""; physicsLessons = []; } if (m == "وزاري") { selectedExamYear = ""; loadAvailableYears(); } else { loadAvailableUnits(); } }),
        ),
      )).toList(),
    );
  }

Widget _buildInputTypeSelectorModern() {
    if (selectedSubject == "فيزياء" || selectedSubject == "كيمياء" || selectedSubject == "عربي" || selectedSubject == "انجليزي" || selectedMode == "وزاري" || selectedMode == "سؤال") return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: ["صفحة", "برومت"].map((t) => Expanded(
            child: InkWell(
              onTap: () => setState(() => inputType = t),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: inputType == t ? AppColors.surfaceWhite : Colors.transparent, borderRadius: BorderRadius.circular(20), boxShadow: inputType == t ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)] : []),
                child: Center(child: Text(t, style: TextStyle(color: inputType == t ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.bold))),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildMathBranchSelectorModern() => Wrap(spacing: 8, runSpacing: 8, children: mathBranches.map((b) => ChoiceChip(label: Text(b), selected: selectedMathBranch == b, selectedColor: AppColors.primary, showCheckmark: false, labelStyle: TextStyle(color: selectedMathBranch == b ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold), backgroundColor: AppColors.softSurface, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none), onSelected: (_) => _switchContext(() { selectedMathBranch = b; mathMode = "شرح"; selectedLesson = ""; loadMathLessons(b); mathWazariQuestionsLoaded = false; }))).toList()); 
  
  Widget _buildMathModeSelectorModern() => Wrap(spacing: 10, children: ["شرح", "سؤال", "وزاري"].map((mode) => ChoiceChip(label: Text(mode), selected: mathMode == mode, selectedColor: AppColors.secondary, showCheckmark: false, labelStyle: TextStyle(color: mathMode == mode ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold), backgroundColor: AppColors.softSurface, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none), onSelected: (_) => setState(() { mathMode = mode; selectedMode = mode; inputType = "برومت"; mathWazariQuestionsLoaded = false; if (mode == "وزاري" && selectedMathBranch.isNotEmpty) loadMathExamYears(selectedMathBranch); }))).toList()); 

  Widget _buildMathExamSelectorModern() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(color: AppColors.softSurface.withOpacity(0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withOpacity(0.1))),
      child: Column(
        children: [
          Row(children: [Icon(Icons.school_rounded, color: AppColors.primary, size: 20), SizedBox(width: 8), Text("إعدادات الأسئلة الوزارية", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary))]),
          const SizedBox(height: 16),
          if (mathExamYears.isNotEmpty) _buildModernDropdown(hint: "اختر السنة", value: selectedMathExamYear.isEmpty ? null : selectedMathExamYear, items: mathExamYears, onChanged: (v) { setState(() { selectedMathExamYear = v!; loadMathExamLessons(selectedMathBranch, v); }); }, icon: Icons.calendar_month_rounded),
          const SizedBox(height: 12),
          if (mathExamLessons.isNotEmpty) _buildModernDropdown(hint: "اختر الدرس", value: selectedMathExamLesson.isEmpty ? null : selectedMathExamLesson, items: mathExamLessons, onChanged: (v) => setState(() => selectedMathExamLesson = v!), icon: Icons.menu_book_rounded),
          if (selectedMathExamLesson.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text("عدد الأسئلة:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _questionCountController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: AppColors.softSurface, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                onPressed: selectedMathExamLesson.isEmpty ? null : () {
                  final count = int.tryParse(_questionCountController.text) ?? 10;
                  final content = "$selectedMathExamYear|$selectedMathExamLesson|$count";
                  selectedLesson = selectedMathExamLesson;
                  setState(() => mathWazariQuestionsLoaded = true);
                  processRequest(customText: content);
                },
                icon: Icon(Icons.download_rounded, size: 20),
                label: Text("جلب الأسئلة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSummarySliderModern() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("مستوى التلخيص", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text("$summaryLevel", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold))),
            ],
          ),
          Slider(activeColor: AppColors.primary, inactiveColor: AppColors.softSurface, min: 1, max: 5, divisions: 4, value: summaryLevel.toDouble(), onChanged: (v) => setState(() => summaryLevel = v.toInt())),
        ],
      ),
    );
  }
  
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(onPressed: () => processRequest(customText: "كمل"), icon: Icon(Icons.arrow_forward_rounded, size: 18), label: Text("أكمل"), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), elevation: 0)),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () => processRequest(customText: "وقف"), icon: Icon(Icons.stop_rounded, size: 18), label: Text("إيقاف"), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), elevation: 0)),
        ],
      ),
    );
  }
}

// ==========================================
// ⌨️ كلاس الكتابة المتسلسلة (Premium Typewriter)
// ==========================================

class TypewriterText extends StatefulWidget {
  final String text; 
  final VoidCallback? onFinished; 
  final bool isCentered;
  final ValueNotifier<bool>? stopNotifier; 
  final Function(String)? onStopped;       
  final VoidCallback? onTyping; // 👈 أضفنا هذي عشان النزول التلقائي

  const TypewriterText({
    super.key, 
    required this.text, 
    this.onFinished, 
    this.isCentered = false,
    this.stopNotifier,
    this.onStopped,
    this.onTyping, // 👈
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  bool _isStopped = false; 
  bool _isFinished = false; 

  @override
  void initState() { 
    super.initState(); 
    if (widget.stopNotifier != null) {
      widget.stopNotifier!.addListener(_onStopRequested);
    }
    _startTyping(); 
  }

  void _onStopRequested() {
    if (widget.stopNotifier?.value == true && !_isStopped) {
      _isStopped = true; 
      if (widget.onStopped != null) {
        widget.onStopped!(_displayedText); 
      }
    }
  }

  @override
  void dispose() {
    if (widget.stopNotifier != null) {
      widget.stopNotifier!.removeListener(_onStopRequested);
    }
    super.dispose();
  }

  void _startTyping() async {
    final String fullText = widget.text;
    int currentIndex = 0;

    int step = 12; 

    while (currentIndex < fullText.length) {
      if (!mounted || _isStopped) break;

      currentIndex += step;
      if (currentIndex > fullText.length) {
        currentIndex = fullText.length;
      }

      await Future.delayed(const Duration(milliseconds: 15)); 

      if (mounted && !_isStopped) {
        setState(() {
          _displayedText = fullText.substring(0, currentIndex);
        });
        
        // 👈 هذا اللي بيخلي الشاشة تسحب لتحت مع كل دفعة كلمات جديدة
        if (widget.onTyping != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onTyping!();
          });
        }
      }
    }

    if (mounted && !_isStopped) {
      setState(() {
        _isFinished = true;
      });
      
      // نسحب الشاشة سحبة أخيرة للتأكيد بعد ما يخلص
      if (widget.onTyping != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onTyping!();
        });
      }

      if (widget.onFinished != null) {
        widget.onFinished!();
      }
    }
  }

  @override
  Widget build(BuildContext context) { 
    String textToRender = _displayedText;
    
    if (!_isFinished && !_isStopped) {
      textToRender += " ▌"; 
    }

    return MarkdownBody(
      data: textToRender, 
      styleSheet: MarkdownStyleSheet(
        textAlign: widget.isCentered ? WrapAlignment.center : WrapAlignment.start,
        p: TextStyle(
          fontSize: 16, 
          color: AppColors.textPrimary, 
          height: 1.6, 
          fontWeight: FontWeight.w500
        )
      )
    ); 
  }
}
