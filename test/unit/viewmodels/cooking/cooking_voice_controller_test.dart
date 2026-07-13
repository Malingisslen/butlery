/// CookingVoiceController state-machine tests (Köksbutlern Batch C).
///
/// Intention: prove the conductor's contract — the speaker/mic sequencing
/// invariant (never record while speaking; the talk-window opens only
/// AFTER a readout completes), source-dependent miss handling (button
/// misses speak up, talk-window silence stays silent), command execution
/// against the real CookingModeViewModel, and voice-minted timers landing
/// in the real StepTimerService. TTS + capture are faked at their seams;
/// the viewmodel and timer service are real.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/cooking/cooking_voice_controller.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

/// Scripted TTS fake: records the spoken texts and whether stop() arrived,
/// and lets a test hold a speak() open to probe the sequencing invariant.
class _FakeTts implements TtsService {
  final List<String> spoken = [];
  int stops = 0;
  bool available = true;
  bool _speaking = false;

  @override
  bool get isAvailable => available;

  @override
  bool get isSpeaking => _speaking;

  @override
  Future<void> init() async {}

  /// When set, speak() holds "in flight" until completed or stop()ped —
  /// lets the barge-in test freeze the speaking state.
  Completer<void>? holdSpeech;

  @override
  Future<void> speak(String text) async {
    _speaking = true;
    spoken.add(text);
    final hold = holdSpeech;
    if (hold != null) {
      await hold.future;
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    _speaking = false;
  }

  @override
  Future<void> stop() async {
    stops++;
    _speaking = false;
    if (holdSpeech != null && !holdSpeech!.isCompleted) {
      holdSpeech!.complete();
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Scripted capture fake: hands back queued transcripts; records whether a
/// capture was ever STARTED while the TTS fake was mid-speech (the
/// invariant probe).
class _FakeCapture extends Fake implements VoiceCaptureService {
  _FakeCapture(this._tts);

  final _FakeTts _tts;
  final List<String?> transcriptQueue = [];
  final List<Duration?> capsSeen = [];
  int starts = 0;
  int cancels = 0;
  bool startedWhileSpeaking = false;
  bool _recording = false;

  /// When set, startRecording parks here before returning — widens the
  /// start-race window so the single-flight and disposed-mid-start tests
  /// probe a HELD start instead of relying on the natural await suspension.
  Completer<void>? holdStart;

  @override
  Future<bool> startRecording({
    void Function()? onAutoStopped,
    Duration? maxDuration,
  }) async {
    if (_tts.isSpeaking) startedWhileSpeaking = true;
    starts++;
    capsSeen.add(maxDuration);
    _recording = true;
    final hold = holdStart;
    if (hold != null) await hold.future;
    return true;
  }

  @override
  Future<String?> stopAndTranscribe() async {
    _recording = false;
    return transcriptQueue.isEmpty ? null : transcriptQueue.removeAt(0);
  }

  @override
  Future<void> cancelRecording() async {
    cancels++;
    _recording = false;
  }

  @override
  bool get isRecording => _recording;
}

Recipe _recipe() => RecipeFactory.build(
  id: 'r1',
  title: 'Köttbullar',
  ingredients: ['500 g köttfärs', '2 dl mjölk'],
  instructions: ['Blanda smeten.', 'Rulla bollar.', 'Stek i smör.'],
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
    capture = _FakeCapture(tts);
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

  /// Runs one full BUTTON-initiated listen cycle with [transcript].
  /// A successful command leaves the hands-free talk-window open; close it
  /// silently first (like its cap expiring on silence) so the next press
  /// is a real button press, not a window stop.
  Future<void> speakCommand(String transcript) async {
    if (controller.state == VoiceAssistState.listening) {
      capture.transcriptQueue.add(null);
      await controller.onMicPressed();
    }
    capture.transcriptQueue.add(transcript);
    await controller.onMicPressed(); // start listening
    await controller.onMicPressed(); // stop + interpret + act
  }

  group('sequencing invariant (the audio-session substitute)', () {
    test('the mic NEVER opens while the butler is speaking — across a full '
        'navigate→readout→window cycle', () async {
      await speakCommand('Nästa.');
      // The command triggered a readout (spoken) and then a talk-window
      // (capture start). The fake records any overlap.
      expect(capture.startedWhileSpeaking, isFalse);
      expect(tts.spoken, isNotEmpty);
      expect(capture.starts, greaterThan(1), reason: 'window did open');
    });

    test('barge-in: mic press DURING held speech stops the voice exactly '
        'once, then listens', () async {
      // Hold the readout open so the press provably lands mid-speech —
      // the old version pressed after speech ended and asserted a
      // monotonic counter >= itself (vacuous, review finding #10).
      tts.holdSpeech = Completer<void>();
      final reading = controller.readCurrentStep();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, VoiceAssistState.speaking);
      expect(tts.stops, 0);

      capture.transcriptQueue.add(null);
      final press = controller.onMicPressed();
      await press;
      await reading;

      expect(tts.stops, 1, reason: 'the voice was cut exactly once');
      expect(capture.startedWhileSpeaking, isFalse);
      expect(controller.state, VoiceAssistState.listening);
      tts.holdSpeech = null;
      await controller.onMicPressed(); // close the listen cleanly
    });

    test(
      'command captures use the SHORT cap, never the 3-minute one',
      () async {
        capture.transcriptQueue.add(null);
        await controller.onMicPressed();
        await controller.onMicPressed();
        expect(
          capture.capsSeen.every(
            (c) => c == CookingVoiceController.commandCaptureCap,
          ),
          isTrue,
        );
      },
    );
  });

  group('command execution', () {
    test(
      '"nästa" advances the real viewmodel and reads the new step',
      () async {
        expect(cookingVm.currentStepIndex, 0);
        await speakCommand('Nästa steg, tack.');
        expect(cookingVm.currentStepIndex, 1);
        expect(tts.spoken.last, contains('Rulla bollar'));
        expect(tts.spoken.last, contains('Steg 2 av 3'));
      },
    );

    test('"nästa" on the last step says so instead of overrunning', () async {
      cookingVm.goToStep(2);
      await speakCommand('Nästa.');
      expect(cookingVm.currentStepIndex, 2);
      expect(tts.spoken.last.toLowerCase(), contains('inget nästa steg'));
    });

    test('"läs ingredienserna" reads the scaled list', () async {
      await speakCommand('Läs ingredienserna.');
      expect(tts.spoken.last, contains('köttfärs'));
      expect(tts.spoken.last, contains('mjölk'));
    });

    test(
      '"sätt timer tio minuter" starts a REAL timer and confirms aloud',
      () async {
        await speakCommand('Sätt timer tio minuter.');
        final running = timers.currentTimers.where((t) => t.isRunning);
        expect(running, hasLength(1));
        expect(running.single.remaining.inMinutes, closeTo(10, 1));
        expect(running.single.id, startsWith('voice-'));
        expect(tts.spoken.last, contains('10 minuter'));
        expect(tts.spoken.last.toLowerCase(), contains('startad'));
      },
    );

    test('"hur lång tid kvar" with no timers says so', () async {
      await speakCommand('Hur lång tid kvar?');
      expect(tts.spoken.last.toLowerCase(), contains('ingen timer'));
    });

    test('"tyst" stops speech and executes nothing', () async {
      final stepBefore = cookingVm.currentStepIndex;
      await speakCommand('Tyst.');
      expect(cookingVm.currentStepIndex, stepBefore);
      expect(tts.stops, greaterThan(0));
    });
  });

  group('miss handling by source', () {
    test('a button-sourced miss is acknowledged aloud; two in a row adds '
        'the buttons hint', () async {
      await speakCommand('Var är visten?');
      expect(tts.spoken.last.toLowerCase(), contains('uppfattade inte'));

      await speakCommand('Blubb.');
      expect(tts.spoken.last.toLowerCase(), contains('knapparna'));
      expect(controller.lastHeard, 'Blubb.');
    });

    test('talk-window silence closes SILENTLY — no speech, no error', () async {
      // Trigger a readout so a window opens, then let the window's capture
      // return silence.
      capture.transcriptQueue.add('Nästa.'); // button command
      capture.transcriptQueue.add(null); // window capture → silence
      await controller.onMicPressed();
      await controller.onMicPressed();
      final spokenCount = tts.spoken.length;

      // Resolve the window capture (auto-stop path).
      await controller.onMicPressed(); // acts as manual close of window
      expect(
        tts.spoken.length,
        spokenCount,
        reason: 'window silence must never trigger a spoken complaint',
      );
      expect(controller.state, VoiceAssistState.idle);
    });

    test('the heard chip is for MISSES only — a successful command clears '
        'lastHeard (review finding #9: stale "Hörde:" chip)', () async {
      await speakCommand('Blubb.');
      expect(controller.lastHeard, 'Blubb.');

      await speakCommand('Nästa.');
      expect(
        controller.lastHeard,
        isNull,
        reason:
            'a recognized command must clear the chip, or the last '
            'mishearing stays on screen for the rest of the session',
      );
    });

    test('a successful command resets the miss counter', () async {
      await speakCommand('Blubb.');
      await speakCommand('Nästa.');
      await speakCommand('Grej.');
      expect(
        tts.spoken.last.toLowerCase(),
        contains('uppfattade inte'),
        reason: 'first miss after a success gets the SHORT message again',
      );
      expect(tts.spoken.last.toLowerCase(), isNot(contains('knapparna')));
    });
  });

  group('muted / unavailable degradation', () {
    test('muted: commands still execute but nothing is spoken and no '
        'window opens', () async {
      controller.muted = true;
      await speakCommand('Nästa.');
      expect(cookingVm.currentStepIndex, 1);
      expect(tts.spoken, isEmpty);
      expect(
        capture.starts,
        1,
        reason: 'no talk-window without a readout to follow',
      );
    });

    test('TTS unavailable (no Swedish voice): same silent-but-working '
        'behavior', () async {
      tts.available = false;
      await speakCommand('Nästa.');
      expect(cookingVm.currentStepIndex, 1);
      expect(tts.spoken, isEmpty);
      expect(capture.starts, 1);
    });
  });

  group('lifecycle', () {
    test(
      'dispose mid-listen cancels the capture and silences the voice',
      () async {
        await controller.onMicPressed();
        expect(controller.state, VoiceAssistState.listening);
        controller.dispose();
        expect(capture.cancels, 1);
        // Re-create so tearDown's dispose has a live object.
        controller = CookingVoiceController(
          voiceCapture: capture,
          tts: tts,
          timers: timers,
          cookingVm: cookingVm,
        );
      },
    );

    test(
      'a rapid double-tap while the capture is still STARTING opens '
      'exactly one capture (single-flight guard, review finding #2)',
      () async {
        // Hold the recorder start open so the second press provably lands
        // inside the start gap — the race that used to orphan a live capture
        // and wedge the shared voice service.
        capture.holdStart = Completer<void>();
        final first = controller.onMicPressed();
        final second = controller.onMicPressed(); // NOT awaited in between
        capture.holdStart!.complete();
        await Future.wait([first, second]);

        expect(
          capture.starts,
          1,
          reason: 'the losing press must never open a second capture',
        );
        expect(controller.state, VoiceAssistState.listening);
        capture.holdStart = null;
        capture.transcriptQueue.add(null);
        await controller.onMicPressed(); // close the listen cleanly
      },
    );

    test('disposed while the capture is STARTING: the ownerless capture is '
        'cancelled, not leaked (review finding #3)', () async {
      capture.holdStart = Completer<void>();
      final press = controller.onMicPressed();
      // Dispose lands in the start gap — state is still idle, so dispose()
      // itself cancels nothing; only the resuming start can see the orphan.
      controller.dispose();
      capture.holdStart!.complete();
      await press;

      expect(
        capture.cancels,
        1,
        reason:
            'an unowned capture blocks the singleton recorder for every '
            'voice feature until app restart',
      );
      expect(controller.state, VoiceAssistState.idle);
      // Re-create so tearDown's dispose has a live object.
      controller = CookingVoiceController(
        voiceCapture: capture,
        tts: tts,
        timers: timers,
        cookingVm: cookingVm,
      );
    });
  });
}
