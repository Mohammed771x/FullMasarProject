import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/robot_widget.dart';
import '../../chat/presentation/screens/main_chat_screen.dart';
import '../data/models/quiz_models.dart';
import 'quiz_controller.dart';
import 'quiz_play_screen.dart';
import 'quiz_review_screen.dart';

// ==========================================
// 🏁 نتيجة الاختبار + خريطة نقاط الضعف
// ==========================================
// **الحلقة الذهبية** ([31§7]): كل نقطة ضعف تحمل **درسها**، فزر «اشرح لي 📚»
// يفتح الشات على ذلك الدرس بعينه — لا على المادة عموماً.
class QuizResultScreen extends StatefulWidget {
  final QuizController controller;
  final QuizResult result;

  const QuizResultScreen({super.key, required this.controller, required this.result});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _percent;

  QuizResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _percent = Tween<double>(begin: 0, end: r.percent / 100)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Color get _color => r.percent >= 80
      ? Colors.green.shade600
      : (r.percent >= 50 ? Colors.orange.shade700 : Colors.redAccent);

  String get _headline => r.percent >= 90
      ? "ممتاز! أنت متمكّن 🌟"
      : r.percent >= 80
          ? "أداء قوي 👏"
          : r.percent >= 50
              ? "جيد — وفيه مجال للأفضل 💪"
              : "لا بأس، هذه بداية الطريق 🌱";

  /// دروس فريدة أخطأ فيها، مرتّبة بعدد الأخطاء.
  List<MapEntry<String, int>> get _weakLessons {
    final counts = <String, int>{};
    for (final w in r.wrong) {
      final key = w.lesson.isEmpty ? w.topic : w.lesson;
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: FadeInSlide(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
              _circle(),
              const SizedBox(height: 18),
              Text(_headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text("${r.subject} · ${r.unit}",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              _stats(),
              const SizedBox(height: 22),
              if (_weakLessons.isNotEmpty) _weakMap() else _perfect(),
              const SizedBox(height: 22),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle() => AnimatedBuilder(
        animation: _percent,
        builder: (_, _) => SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: _percent.value,
                  strokeWidth: 14,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.softSurface,
                  valueColor: AlwaysStoppedAnimation(_color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${(_percent.value * 100).round()}%",
                      style: TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w900, color: _color)),
                  Text("${r.score} من ${r.total}",
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _stats() => Row(
        children: [
          _stat("✅ صحيحة", "${r.score}", Colors.green.shade600),
          const SizedBox(width: 10),
          _stat("❌ خاطئة", "${r.total - r.score}", Colors.redAccent),
          const SizedBox(width: 10),
          _stat("⏱️ الوقت", _fmt(r.durationSec), AppColors.primary),
        ],
      );

  static String _fmt(int sec) {
    final m = sec ~/ 60, s = sec % 60;
    return m > 0 ? "$m:${s.toString().padLeft(2, '0')}" : "$s ث";
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _perfect() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            RobotWidget(size: 52, state: RobotState.wave),
            const SizedBox(width: 12),
            Expanded(
              child: Text("لا أخطاء في هذا الاختبار — أتقنت هذه الدروس 🎯",
                  style: TextStyle(
                      fontSize: 13, height: 1.7,
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ],
        ),
      );

  Widget _weakMap() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text("🎯 تحتاج تركيزاً في:",
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 10),
          ..._weakLessons.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text("${e.value}✗",
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w900,
                                color: Colors.redAccent)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.key,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      // 🔁 الحلقة الذهبية: من الخطأ إلى شرح الدرس نفسه
                      TextButton.icon(
                        onPressed: () => _explain(e.key),
                        icon: Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
                        label: Text("اشرح لي",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      );

  /// يفتح شاشة الشات على **درس** نقطة الضعف مباشرةً.
  void _explain(String lesson) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainChatScreen(
          openSubject: r.subject,
          openUnit: r.unit,
          openLesson: lesson,
          openMode: "شرح",
        ),
      ),
      (route) => route.isFirst,
    );
  }

  Widget _actions() => Column(
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceWhite,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => QuizReviewScreen(controller: widget.controller)),
              ),
              icon: const Icon(Icons.fact_check_rounded, size: 20),
              label: const Text("راجع إجاباتك 📋",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () {
                final c = widget.controller;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => QuizPlayScreen(controller: c..questions = const [])),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text("اختبار جديد بنفس الدروس 🔄",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
}
