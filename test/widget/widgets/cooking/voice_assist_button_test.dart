/// VoiceAssistButton + VoiceHeardChip widget tests (Köksbutlern Batch D).
///
/// Intention: prove the button's UI contract against a REAL
/// CookingVoiceController (fakes only at the TTS/capture seam, same pattern
/// as the Batch C controller tests) — idle renders the mic, a tap runs the
/// caller's permission gate BEFORE any capture starts, a granted tap
/// reaches listening (stop icon + talk-window hint), transcribing renders
/// the shared LoadingIndicator (never a raw spinner), and the heard-chip
/// surfaces the last transcript once a command cycle resolves.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/cooking/cooking_voice_controller.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/cooking/voice_assist_button.dart';
import 'package:butlery/widgets/cooking/voice_heard_chip.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

/// Always-available, immediately-resolving TTS fake — mirrors the Batch C
/// controller test's `_FakeTts`.
class _FakeTts implements TtsService {
  final List<String> spoken = [];
  bool available = true;
  bool _speaking = false;

  @override
  bool get isAvailable => available;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text) async {
    _speaking = true;
    spoken.add(text);
    await Future<void>.delayed(Duration.zero);
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    _speaking = false;
  }

  @override
  Future<void> dispose() async {}
}

/// Capture fake with a controllable `stopAndTranscribe`: either resolves
/// immediately from a queued transcript, or — when [holdNext] is set —
/// returns a pending Future the test resolves by hand, so the widget can be
/// pumped mid-transcription.
class _FakeCapture extends Fake implements VoiceCaptureService {
  final List<String?> transcriptQueue = [];
  int starts = 0;
  bool holdNext = false;
  Completer<String?>? _held;

  @override
  Future<bool> startRecording({
    void Function()? onAutoStopped,
    Duration? maxDuration,
  }) async {
    starts++;
    return true;
  }

  @override
  Future<String?> stopAndTranscribe() {
    if (holdNext) {
      holdNext = false;
      final completer = Completer<String?>();
      _held = completer;
      return completer.future;
    }
    return Future.value(
      transcriptQueue.isEmpty ? null : transcriptQueue.removeAt(0),
    );
  }

  void releaseHeld(String? value) {
    _held?.complete(value);
    _held = null;
  }

  @override
  Future<void> cancelRecording() async {}

  @override
  bool get isRecording => false;
}

Recipe _recipe() => RecipeFactory.build(
  id: 'r1',
  title: 'Köttbullar',
  ingredients: ['500 g köttfärs'],
  instructions: ['Blanda smeten.', 'Rulla bollar.'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTts tts;
  late _FakeCapture capture;
  late StepTimerService timers;
  late CookingModeViewModel cookingVm;
  late CookingVoiceController controller;

  setUp(() {
    tts = _FakeTts();
    capture = _FakeCapture();
    timers = StepTimerService();
    cookingVm = CookingModeViewModel(recipe: _recipe());
    controller = CookingVoiceController(
      voiceCapture: capture,
      tts: tts,
      timers: timers,
      cookingVm: cookingVm,
    );
  });

  tearDown(() {
    controller.dispose();
    timers.dispose();
  });

  Widget buttonApp({required Future<bool> Function() onEnsurePermission}) {
    return createLocalizedTestApp(
      child: VoiceAssistButton(
        controller: controller,
        onEnsurePermission: onEnsurePermission,
      ),
    );
  }

  testWidgets('idle renders the mic icon with its localized tooltip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buttonApp(onEnsurePermission: () async => true));

    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(find.bySemanticsLabel('Tala med köksbutlern'), findsOneWidget);

    handle.dispose();
  });

  testWidgets(
    'a tap runs onEnsurePermission FIRST; a false result starts no capture',
    (tester) async {
      var permissionCalls = 0;
      await tester.pumpWidget(
        buttonApp(
          onEnsurePermission: () async {
            permissionCalls++;
            return false;
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      expect(permissionCalls, 1);
      expect(capture.starts, 0);
      expect(controller.state, VoiceAssistState.idle);
    },
  );

  testWidgets(
    'permission granted: tap reaches listening (stop icon + talk-window hint)',
    (tester) async {
      await tester.pumpWidget(buttonApp(onEnsurePermission: () async => true));

      await tester.tap(find.byIcon(Icons.mic_none));
      // A single pump is deliberate: the listening pulse animation repeats
      // indefinitely, so pumpAndSettle() would never return while it runs.
      await tester.pump();

      expect(controller.state, VoiceAssistState.listening);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.text('Säg ett kommando…'), findsOneWidget);
    },
  );

  testWidgets('transcribing shows the shared LoadingIndicator', (
    tester,
  ) async {
    await tester.pumpWidget(buttonApp(onEnsurePermission: () async => true));

    await tester.tap(find.byIcon(Icons.mic_none)); // idle -> listening
    await tester.pump();

    capture.holdNext = true;
    await tester.tap(find.byIcon(Icons.stop)); // listening -> transcribing
    await tester.pump();

    expect(controller.state, VoiceAssistState.transcribing);
    expect(find.byType(LoadingIndicator), findsOneWidget);

    // Resolve so the pending Future doesn't leak into the next test.
    capture.releaseHeld(null);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'heard chip renders the last transcript after an Unrecognized cycle',
    (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VoiceHeardChip(controller: controller),
              VoiceAssistButton(
                controller: controller,
                onEnsurePermission: () async => true,
              ),
            ],
          ),
        ),
      );

      // No chip yet: nothing has been heard.
      expect(find.textContaining('Hörde:'), findsNothing);

      capture.transcriptQueue.add('Blubb.');
      await tester.tap(find.byIcon(Icons.mic_none)); // idle -> listening
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop)); // listening -> resolve
      // The miss cycle speaks a short message then settles back to idle;
      // no repeating animation is active once listening has ended.
      await tester.pumpAndSettle();

      expect(controller.state, VoiceAssistState.idle);
      expect(controller.lastHeard, 'Blubb.');
      expect(find.text('Hörde: Blubb.'), findsOneWidget);
    },
  );
}
