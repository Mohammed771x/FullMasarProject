import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import '../../../../core/widgets/robot_widget.dart';
import 'aptitude_result_screen.dart';

// ==========================================
// 🧭 اختبار الميول — 15 سؤالاً (بلا صح/خطأ)
// ==========================================
class AptitudeScreen extends StatefulWidget {
  const AptitudeScreen({super.key});

  @override
  State<AptitudeScreen> createState() => _AptitudeScreenState();
}

class _AptitudeScreenState extends State<AptitudeScreen> {
  int _i = 0;
  int? _selected;
  final Map<AptDim, int> _tally = {for (var d in AptDim.values) d: 0};

  void _pick(int k) {
    setState(() => _selected = k);
  }

  void _next() {
    if (_selected == null) return;
    _tally[demoAptitude[_i].options[_selected!].dim] = (_tally[demoAptitude[_i].options[_selected!].dim] ?? 0) + 1;
    if (_i < demoAptitude.length - 1) {
      setState(() {
        _i++;
        _selected = null;
      });
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AptitudeResultScreen(tally: _tally)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = demoAptitude[_i];
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      InkWell(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, color: AppColors.textPrimary)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: (_i + 1) / demoAptitude.length, minHeight: 8, backgroundColor: AppColors.softSurface, valueColor: AlwaysStoppedAnimation(AppColors.secondary)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text("${_i + 1}/${demoAptitude.length}", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                    children: [
                      Row(
                        children: [
                          RobotWidget(size: 56, state: RobotState.think),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.bubbleShadow),
                              child: Text(q.text, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.5)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(q.options.length, (k) {
                        final sel = k == _selected;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _pick(k),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.secondary.withValues(alpha: 0.08) : AppColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: sel ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.12), width: 1.6),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel ? AppColors.secondary : AppColors.textSecondary.withValues(alpha: 0.3), width: 2), color: sel ? AppColors.secondary : Colors.transparent),
                                    child: sel ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(child: Text(q.options[k].text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                    child: InkWell(
                      onTap: _next,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _selected != null ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]) : null,
                          color: _selected == null ? AppColors.softSurface : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(child: Text(_i < demoAptitude.length - 1 ? "التالي" : "عرض النتيجة", style: TextStyle(color: _selected != null ? Colors.white : AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
