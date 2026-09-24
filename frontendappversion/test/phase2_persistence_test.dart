// ══════════════════════════════════════════════════
// 💾 ما يُحفظ عند المغادرة، وما يعود عند الرجوع
// ══════════════════════════════════════════════════
//
// 🎯 ثلاثةُ أعطالٍ يجمعها أن الطالب **لا يراها لحظةَ وقوعها**: يغادر
//    الشاشة وكلُّ شيءٍ يبدو سليماً، ثم يعود فيجد النقص.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/services/stt_service.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/edu_session.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

/// قدراتٌ فيها شجرةُ دروسٍ حقيقية — يتحقّق بها الاستعادة.
class _Content extends TutorContentRepository {
  @override
  Future<SubjectCapabilities> getCapabilities(
          String subject, int grade, String track) async =>
      SubjectCapabilities(
        subject: subject,
        lessonsAvailable: true,
        pagesAvailable: false,
        lessonsUnits: const [
          LessonsUnit(unit: "الجهاز العصبي", lessons: ["الخلية العصبية", "السيالة"]),
        ],
        pagesUnits: const [],
      );

  @override
  Future<List<String>> getUnits(String subject, int grade, String track) async =>
      const [];
}

/// عميلٌ يبثّ جزءاً ثم يتوقّف عند بوّابةٍ نتحكّم بها.
class _GatedStream extends http.BaseClient {
  _GatedStream(this.gate);
  final Completer<void> gate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    Stream<List<int>> body() async* {
      // ⚠️ `utf8.encode` لا `codeUnits`: العربية في UTF-16 تُفسد فكّ الترميز.
      yield utf8.encode('data: {"t":"delta","v":"آخرُ جملةٍ في الشرح"}\n\n');
      await gate.future;
    }

    return http.StreamedResponse(body(), 200, request: request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_phase2');
    await ChatStorage.initForTests(dir.path);
  });
  tearDownAll(() async => dir.delete(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EduSession.I.clear();
    await ChatStorage.clearAll();
    UserSession.I
      ..isGuest = true
      ..grade = 3
      ..track = "علمي";
  });

  // ══════════════════════════════════════════════════
  // 🧭 ① سياقُ الدرس يُحفظ ويعود
  // ══════════════════════════════════════════════════

  test('☢️ المحادثةُ تحفظ الوحدةَ والدرسَ ووضعَ المحتوى', () async {
    final c = ChatController(contentRepository: _Content());
    await c.init();
    c.selectedSubject = "احياء";
    await c.loadCapabilities();
    await c.setContentMode("lessons");
    await c.setV3Unit("الجهاز العصبي");
    await c.setV3Lesson("الخلية العصبية");
    c.messages.add({"role": "user", "text": "اشرح"});
    c.currentConversationId = "conv-1";
    await c.saveCurrentConversation();

    final saved = ChatStorage.getConversation("conv-1")!;
    expect(saved.contentMode, "lessons");
    expect(saved.unit, "الجهاز العصبي");
    expect(saved.lesson, "الخلية العصبية",
        reason: '🔴 المحادثة تعود بمادتها بلا درسها');
    c.dispose();
  });

  test('☢️ واستئنافُها يُعيد الدرس لا لوحةَ إعدادات فارغة', () async {
    final saved = ChatConversation(
      id: "conv-2",
      title: "شرح",
      subject: "احياء",
      mode: "شرح",
      grade: 3,
      track: "علمي",
      contentMode: "lessons",
      unit: "الجهاز العصبي",
      lesson: "السيالة",
      messages: [ChatMessage(role: "user", text: "اشرح", refs: const [])],
    );

    final c = ChatController(contentRepository: _Content());
    await c.init();
    c.selectedSubject = "احياء";
    await c.loadCapabilities();
    await c.loadConversation(saved);

    expect(c.selectedV3Unit, "الجهاز العصبي");
    expect(c.selectedV3Lesson, "السيالة",
        reason: '🔴 عادت المحادثة بلا درسٍ فتُرسل رسالتُها باسمٍ فارغ');
    expect(c.showSettingsPanel, isFalse,
        reason: 'السياقُ كاملٌ فلا داعي لإعادة الاختيار');
    c.dispose();
  });

  // 🗄️ الترحيل: ما حُفظ قبل هذه الحقول يُقرأ بلا انهيار وبسلوكه القديم.
  test('🗄️ محادثةٌ قديمة بلا سياق تُقرأ وتفتح لوحة الاختيار', () async {
    final legacy = ChatConversation(
      id: "conv-legacy",
      title: "قديمة",
      subject: "احياء",
      mode: "شرح",
      grade: 3,
      track: "علمي",
      messages: [ChatMessage(role: "user", text: "اشرح", refs: const [])],
    );
    expect(legacy.unit, "");
    expect(legacy.lesson, "");
    expect(legacy.contentMode, "");

    // وتمرّ بالتخزين ذهاباً وإياباً بلا فقد.
    await ChatStorage.saveConversation(legacy, ownerUid: "");
    final back = ChatStorage.getConversation("conv-legacy")!;
    expect(back.lesson, "");
    expect(ChatConversation.fromJson(back.toJson()).unit, "");

    final c = ChatController(contentRepository: _Content());
    await c.init();
    c.selectedSubject = "احياء";
    await c.loadCapabilities();
    await c.loadConversation(back);

    expect(c.selectedV3Lesson, "", reason: 'لا سياقَ يُستعاد من القديم');
    expect(c.showSettingsPanel, isFalse,
        reason: 'الدرجُ لا يفرض اللوحة — ذاك قرارُ openFromSearch');
    c.dispose();
  });

  test('🛡️ ودرسٌ لم يعد في المنهج لا يُستعاد', () async {
    final stale = ChatConversation(
      id: "conv-3",
      title: "قديم",
      subject: "احياء",
      mode: "شرح",
      grade: 3,
      track: "علمي",
      contentMode: "lessons",
      unit: "وحدةٌ حُذفت",
      lesson: "درسٌ حُذف",
      messages: [ChatMessage(role: "user", text: "اشرح", refs: const [])],
    );

    final c = ChatController(contentRepository: _Content());
    await c.init();
    c.selectedSubject = "احياء";
    await c.loadCapabilities();
    await c.loadConversation(stale);

    expect(c.selectedV3Lesson, isNot("درسٌ حُذف"),
        reason: '🔴 درسٌ محذوف يُرسل الطالبَ إلى «قيد الإضافة»');
    c.dispose();
  });

  // ══════════════════════════════════════════════════
  // 💾 ② المغادرة أثناء البثّ لا تبتر آخر جملة
  // ══════════════════════════════════════════════════

  test('☢️ الخروجُ أثناء البثّ يحفظ ما وصل كاملاً', () async {
    final gate = Completer<void>();
    final c = ChatController(
      contentRepository: _Content(),
      askStream: AskStream(_GatedStream(gate)),
    );
    await c.init();
    c.selectedSubject = "احياء";
    // 🚦 اختيارٌ مكتمل ([sendBlocker]): المحتوى المزيّف دروسٌ وحدها.
    c.selectedV3Unit = "الجهاز العصبي";
    c.selectedV3Lesson = "الخلية العصبية";
    c.inputController.text = "اشرح";

    final pending = c.processRequest();
    // ⏱️ ننتظر وصول الجزء **دون** أن نبلغ موعد السكب (٥٠ملّي) — وهي
    //    بالضبط اللحظة التي كان الخروج فيها يبتر آخر جملة.
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(c.isStreaming, isTrue, reason: 'التهيئة خاطئة: لا بثّ');

    final id = c.currentConversationId!;
    c.dispose();
    gate.complete();
    await pending.catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final saved = ChatStorage.getConversation(id);
    expect(saved, isNotNull, reason: '🔴 لم تُحفظ المحادثة أصلاً');
    final ai = saved!.messages.where((m) => m.role == "ai").toList();
    expect(ai, hasLength(1));
    expect(ai.single.text, contains("آخرُ جملةٍ في الشرح"),
        reason: '🔴 المتراكم في المصرف ضاع مع إلغاء المؤقّت');
  });

  // ══════════════════════════════════════════════════
  // 🚪 ③ رسالةُ الخروج تطابق ما يحدث فعلاً
  // ══════════════════════════════════════════════════

  test('🚪 حوارُ إنهاء الاختبار لا يقول «ستفقد تقدّمك» والتقدّمُ يُحفظ', () {
    final play = File(
      'lib/features/quiz/presentation/quiz_play_screen.dart',
    ).readAsStringSync();
    final ctrl = File(
      'lib/features/quiz/presentation/quiz_controller.dart',
    ).readAsStringSync();

    // الشرطُ الذي يجعل النصَّ كذباً: الشاشةُ تكتب لقطةً قابلة للاستئناف.
    expect(ctrl, contains("QuizResumeStore.save"),
        reason: 'تغيّر مصدرُ الحفظ — راجع نصَّ حوار الخروج');
    // ⚠️ التعليقاتُ تُستثنى: شرحُ العطل يقتبس النصَّ القديم عمداً،
    //    والقاعدةُ على ما يُعرض لا على ما يُكتب ([quiz_setup_markdown_test]).
    final shown = play
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(shown, isNot(contains("ستفقد تقدّمك")),
        reason: '🔴 الحوارُ يقول للطالب إن تقدّمه ضاع وهو محفوظ');
    expect(play, contains("تقدّمك محفوظ"));
  });

  voiceCleanupTests();
}

// ══════════════════════════════════════════════════
// 🎤 ④ حالةُ الصوت تُطفأ مهما رمى المحرّك
// ══════════════════════════════════════════════════
//
// 🔴 **العطل:** `finish()` تلمس محرّك النظام، و`/voice/clean` رحلةُ شبكة.
//    ورميُ أيٍّ منهما كان يترك عَلَماً مرفوعاً إلى الأبد: `isRecording`
//    فيموت زرُّ المايك، أو `isCleaningVoice` فيدور المؤشّر بلا نهاية.
//    ولا مخرجَ للطالب إلا إغلاق التطبيق.
void voiceCleanupTests() {
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');

  test('☢️ رميُ محرّك الصوت لا يُجمّد زرَّ المايك', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'has_permission':
        case 'initialize':
          return true;
        case 'listen':
          return true;
        case 'stop':
        case 'cancel':
          throw PlatformException(code: 'انهار المحرّك');
        default:
          return null;
      }
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final c = ChatController(contentRepository: _Content());
    await c.init();

    await c.startVoiceRecording();
    expect(c.isRecording, isTrue, reason: 'التهيئة خاطئة: لم يبدأ التسجيل');

    // ⏹️ المحرّك يرمي عند الإيقاف — والحالةُ يجب أن تُطفأ رغم ذلك.
    await c.stopVoiceToText();

    expect(c.isRecording, isFalse,
        reason: '🔴 زرُّ المايك ماتَ: `if (isRecording) return` إلى الأبد');
    expect(c.isCleaningVoice, isFalse, reason: '🔴 مؤشّرُ التنظيف لا يتوقف');
    expect(SttService.I.isRecording.value, isFalse,
        reason: '🔴 الخدمةُ ما زالت تسجّل بلا شريطٍ يُظهر ذلك');
    c.dispose();
  });

  test('☢️ وإلغاءُ التسجيل كذلك', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'cancel') throw PlatformException(code: 'انهار');
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    final c = ChatController(contentRepository: _Content());
    await c.init();
    await c.startVoiceRecording();
    expect(c.isRecording, isTrue);

    await c.deleteVoiceRecording();

    expect(c.isRecording, isFalse);
    expect(SttService.I.isRecording.value, isFalse);
    c.dispose();
  });
}
