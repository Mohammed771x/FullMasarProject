import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// ==========================================
// 🎤 خدمة التحويل الصوتي (على الجهاز — مجانية)
// ==========================================
// وضع مستمر بنمط ChatGPT: التسجيل **لا يتوقف تلقائياً** إطلاقاً.
// محركا أندرويد وiOS يوقفان الجلسة وحدهما بعد فترة أو عند الصمت، فنعيد
// تشغيلها فوراً ونراكم النص — والطالب وحده من ينهي التسجيل.
//
// تكشف للواجهة:
//   isAvailable → هل الجهاز يدعم التعرف؟ (الزر يخفي نفسه إن لا)
//   isRecording → هل التسجيل جارٍ؟
//   liveText    → النص المتراكم حياً
//   soundLevel  → مستوى الصوت 0..1 لرسم الموجات
//   elapsed     → مدة التسجيل
class SttService {
  SttService._();
  static final SttService I = SttService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  bool _available = false;

  /// الطالب يريد الاستمرار — يبقى true حتى يضغط إيقاف/حذف.
  bool _userWantsRecording = false;

  /// النص المؤكَّد من الجلسات المنتهية (قبل إعادة التشغيل).
  String _committed = "";

  Timer? _elapsedTimer;
  Timer? _restartTimer;

  final ValueNotifier<bool> isRecording = ValueNotifier(false);
  final ValueNotifier<String> liveText = ValueNotifier("");
  final ValueNotifier<double> soundLevel = ValueNotifier(0);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  bool get isAvailable => _available;

  Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onStatus: _onStatus,
        onError: (_) => _onEngineEnded(),
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  void _onStatus(String status) {
    if (status == stt.SpeechToText.doneStatus ||
        status == stt.SpeechToText.notListeningStatus) {
      _onEngineEnded();
    }
  }

  /// المحرك أنهى جلسته وحده — نعيد التشغيل ما دام الطالب لم يضغط إيقاف.
  void _onEngineEnded() {
    if (!_userWantsRecording) return;
    // ثبّت ما التُقط في هذه الجلسة قبل بدء التالية
    _commitCurrentSession();
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 120), () {
      if (_userWantsRecording) _listenOnce();
    });
  }

  void _commitCurrentSession() {
    final session = _sessionText.trim();
    if (session.isEmpty) return;
    _committed = _committed.isEmpty ? session : "$_committed $session";
    _sessionText = "";
    liveText.value = _committed;
  }

  String _sessionText = "";

  Future<void> _listenOnce() async {
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          localeId: "ar",
          // مهلات طويلة جداً: نحن نتحكم بالإيقاف، لا المحرك.
          // وإن أنهى المحرك الجلسة رغم ذلك، _onEngineEnded يعيد تشغيلها.
          pauseFor: const Duration(minutes: 5),
          listenFor: const Duration(minutes: 5),
        ),
        onSoundLevelChange: (level) {
          // أندرويد يعطي ديسيبل تقريبي (~ -2..10). نطبّعه إلى 0..1.
          final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
          soundLevel.value = normalized;
        },
        onResult: (result) {
          _sessionText = result.recognizedWords;
          final merged =
              _committed.isEmpty ? _sessionText : "$_committed $_sessionText";
          liveText.value = merged.trim();
        },
      );
    } catch (_) {
      // فشل بدء الجلسة — نحاول مرة أخرى بعد لحظة
      if (_userWantsRecording) {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 400), _listenOnce);
      }
    }
  }

  /// يبدأ تسجيلاً مستمراً. يرجع false إن كان الجهاز لا يدعم.
  Future<bool> start() async {
    if (!await init()) return false;

    _userWantsRecording = true;
    _committed = "";
    _sessionText = "";
    liveText.value = "";
    soundLevel.value = 0;
    elapsed.value = Duration.zero;

    await _listenOnce();
    isRecording.value = true;

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed.value += const Duration(seconds: 1);
    });
    return true;
  }

  Future<void> _teardown() async {
    _userWantsRecording = false;
    _restartTimer?.cancel();
    _elapsedTimer?.cancel();
    isRecording.value = false;
    soundLevel.value = 0;
  }

  /// إيقاف بطلب الطالب — يرجع النص الكامل المتراكم.
  Future<String> finish() async {
    await _teardown();
    try {
      await _speech.stop();
    } catch (_) {}
    _commitCurrentSession();
    final text = _committed.trim();
    _committed = "";
    _sessionText = "";
    return text;
  }

  /// إلغاء وحذف — لا يُرجع شيئاً.
  Future<void> discard() async {
    await _teardown();
    try {
      await _speech.cancel();
    } catch (_) {}
    _committed = "";
    _sessionText = "";
    liveText.value = "";
    elapsed.value = Duration.zero;
  }
}
