/// TtsService behavioral tests (Köksbutlern, tasks/koksbutlern-plan.md).
///
/// Intention: prove the two contracts CookingVoiceController (Batch C) is
/// built on — (1) the degrade contract: any failure to confirm a Swedish
/// voice, at init or at speak time, makes the service silently text-only,
/// never throwing into the caller; (2) the serialization contract: two
/// overlapping [TtsService.speak] calls never run their utterances
/// concurrently — an in-flight one is stopped before the next starts. The
/// flutter_tts plugin itself is never touched; only the [SpeechSynthesizer]
/// seam is exercised, via a hand-rolled fake with Completer-controlled
/// timing.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/voice/tts_service.dart';

/// Fake [SpeechSynthesizer] with explicit control over when an utterance
/// "finishes" — entries in [held] block until either [stop] completes them
/// or the test completes them directly, so tests can hold one utterance
/// open while a second is issued. Utterances not registered in [held]
/// resolve immediately, which keeps tests that don't care about timing
/// simple.
class _FakeSynthesizer implements SpeechSynthesizer {
  _FakeSynthesizer({
    this.swedishAvailable = true,
    this.configureError,
    this.speakErrorFor,
  });

  final bool swedishAvailable;
  final Object? configureError;
  final String? speakErrorFor;

  final List<String> calls = [];
  final Map<String, Completer<void>> held = {};
  final List<Completer<void>> _active = [];

  @override
  Future<void> configure() async {
    calls.add('configure');
    if (configureError != null) throw configureError!;
  }

  @override
  Future<bool> isSwedishAvailable() async {
    calls.add('isSwedishAvailable');
    return swedishAvailable;
  }

  @override
  Future<void> speakAndWait(String text) async {
    calls.add('speak:$text');
    if (speakErrorFor == text) {
      throw StateError('fake synthesizer failure for "$text"');
    }
    final hold = held[text];
    if (hold != null) {
      _active.add(hold);
      await hold.future;
    }
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    for (final c in _active) {
      if (!c.isCompleted) c.complete();
    }
    _active.clear();
  }
}

void main() {
  group('TtsService.init degrade contract', () {
    test('Swedish voice available marks the service available', () async {
      final fake = _FakeSynthesizer(swedishAvailable: true);
      final service = TtsService(synthesizer: fake);

      await service.init();

      expect(service.isAvailable, isTrue);
    });

    test('no Swedish voice degrades to unavailable without throwing', () async {
      final fake = _FakeSynthesizer(swedishAvailable: false);
      final service = TtsService(synthesizer: fake);

      await expectLater(service.init(), completes);
      expect(service.isAvailable, isFalse);
    });

    test(
      'configure() throwing degrades to unavailable without throwing',
      () async {
        final fake = _FakeSynthesizer(configureError: StateError('boom'));
        final service = TtsService(synthesizer: fake);

        await expectLater(service.init(), completes);
        expect(service.isAvailable, isFalse);
      },
    );
  });

  group('TtsService.speak serialization', () {
    test(
      'a speak() call while one is in flight stops the first before '
      'starting the second',
      () async {
        final held = Completer<void>();
        final fake = _FakeSynthesizer()..held['first'] = held;
        final service = TtsService(synthesizer: fake);
        await service.init();

        final firstFuture = service.speak('first');
        final secondFuture = service.speak('second');
        await Future.wait([firstFuture, secondFuture]);

        expect(fake.calls, [
          'configure',
          'isSwedishAvailable',
          'speak:first',
          'stop',
          'speak:second',
        ]);
      },
    );

    test('sequential, non-overlapping speaks do not call stop', () async {
      final fake = _FakeSynthesizer();
      final service = TtsService(synthesizer: fake);
      await service.init();

      await service.speak('first');
      await service.speak('second');

      expect(
        fake.calls,
        containsAllInOrder(['speak:first', 'speak:second']),
      );
      expect(fake.calls, isNot(contains('stop')));
    });
  });

  group('TtsService.speak unavailable/error handling', () {
    test('is a silent no-op when unavailable', () async {
      final fake = _FakeSynthesizer(swedishAvailable: false);
      final service = TtsService(synthesizer: fake);
      await service.init();
      fake.calls.clear(); // drop the init-time configure/probe calls

      await service.speak('should never reach the synthesizer');

      expect(fake.calls, isEmpty);
    });

    test('never throws when the synthesizer throws', () async {
      final fake = _FakeSynthesizer(speakErrorFor: 'boom');
      final service = TtsService(synthesizer: fake);
      await service.init();

      await expectLater(service.speak('boom'), completes);
      expect(service.isSpeaking, isFalse);
    });
  });

  group('TtsService.stop', () {
    test('is safe when idle', () async {
      final fake = _FakeSynthesizer();
      final service = TtsService(synthesizer: fake);
      await service.init();

      await expectLater(service.stop(), completes);
      expect(service.isSpeaking, isFalse);
    });
  });

  group('TtsService.isSpeaking', () {
    test('is true during an in-flight speak and false after', () async {
      final held = Completer<void>();
      final fake = _FakeSynthesizer()..held['x'] = held;
      final service = TtsService(synthesizer: fake);
      await service.init();

      final future = service.speak('x');
      expect(service.isSpeaking, isTrue);

      held.complete();
      await future;

      expect(service.isSpeaking, isFalse);
    });
  });
}
