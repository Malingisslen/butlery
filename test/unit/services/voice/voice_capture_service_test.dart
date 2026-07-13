/// VoiceCaptureService behavioral tests (kb-whisper voice plan).
///
/// Intention: prove the privacy + degradation contract the stakeholder panel
/// made binding — the captured WAV is deleted on EVERY exit path (success,
/// transcription failure, model unavailable, cancel), and every failure mode
/// surfaces as null/false (typed input keeps working), never as a thrown
/// error. The whisper.cpp FFI and the mic are mocked at their seams; the
/// file lifecycle under test is real.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/services/voice/whisper_model_manager.dart';

class _MockRecorder extends Mock implements AudioRecorder {}

class _MockModelManager extends Mock implements WhisperModelManager {}

class _FakeTranscriber implements WhisperTranscriber {
  _FakeTranscriber({this.result, this.error});

  final String? result;
  final Object? error;
  String? seenAudioPath;
  String? seenModelPath;

  @override
  Future<String?> transcribe({
    required String audioPath,
    required String modelPath,
  }) async {
    seenAudioPath = audioPath;
    seenModelPath = modelPath;
    if (error != null) throw error!;
    return result;
  }
}

class _TestVoiceCaptureService extends VoiceCaptureService {
  _TestVoiceCaptureService({
    required super.modelManager,
    required super.recorder,
    required super.transcriber,
    required Directory tempDir,
  }) : _tempDir = tempDir;

  final Directory _tempDir;

  @override
  Future<Directory> getTempDir() async => _tempDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
  });

  late Directory tempDir;
  late _MockRecorder recorder;
  late _MockModelManager modelManager;

  // A fixed clock makes the service's generated WAV path deterministic.
  final fixedTime = DateTime.utc(2026, 7, 12, 12);
  String expectedWavPath() =>
      '${tempDir.path}/butlery_voice_${fixedTime.microsecondsSinceEpoch}.wav';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('voice_svc_');
    recorder = _MockRecorder();
    modelManager = _MockModelManager();

    when(() => recorder.hasPermission()).thenAnswer((_) async => true);
    when(
      () => recorder.start(any(), path: any(named: 'path')),
    ).thenAnswer((_) async {});
    when(() => recorder.stop()).thenAnswer((_) async => null);
    when(() => recorder.cancel()).thenAnswer((_) async {});
    when(() => recorder.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  _TestVoiceCaptureService service(WhisperTranscriber transcriber) =>
      _TestVoiceCaptureService(
        modelManager: modelManager,
        recorder: recorder,
        transcriber: transcriber,
        tempDir: tempDir,
      );

  /// Simulates the recorder having written audio to the path the service
  /// chose, then runs [action]. Returns whether the WAV survived.
  Future<bool> wavSurvives(
    _TestVoiceCaptureService svc,
    Future<void> Function() action,
  ) async {
    await File(expectedWavPath()).writeAsBytes(const [1, 2, 3]);
    await action();
    return File(expectedWavPath()).existsSync();
  }

  group('3-min cap is service-enforced (review finding #3)', () {
    test(
      'the cap timer stops the RECORDER itself, even with no callback',
      () async {
        when(() => modelManager.ensureModelAvailable()).thenAnswer(
          (_) async =>
              const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
        );
        final transcriber = _FakeTranscriber(result: 'takad diktering');
        final svc = service(transcriber);

        await withClock(Clock.fixed(fixedTime), () async {
          fakeAsync((async) {
            // No onAutoStopped callback — the menu prompt button's usage.
            svc.startRecording();
            async.flushMicrotasks();
            expect(svc.isRecording, isTrue);

            async.elapse(VoiceCaptureService.maxRecordingDuration);
            async.flushMicrotasks();

            // The recorder was stopped BY THE SERVICE at the cap.
            verify(() => recorder.stop()).called(1);
          });
        });
      },
    );

    test('auto-stop fires the per-capture callback and the follow-up '
        'stopAndTranscribe still returns the transcript', () async {
      when(() => modelManager.ensureModelAvailable()).thenAnswer(
        (_) async =>
            const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
      );
      when(() => recorder.stop()).thenAnswer((_) async => null);
      final transcriber = _FakeTranscriber(result: 'takad diktering');
      final svc = service(transcriber);

      var autoStopped = false;
      await withClock(Clock.fixed(fixedTime), () async {
        // Fake time ONLY for the cap timer; the transcription that follows
        // does real file I/O, which never pumps inside fakeAsync.
        fakeAsync((async) {
          svc.startRecording(onAutoStopped: () => autoStopped = true);
          async.flushMicrotasks();
          async.elapse(VoiceCaptureService.maxRecordingDuration);
          async.flushMicrotasks();
        });
      });
      expect(autoStopped, isTrue);

      // The capped WAV must still transcribe like a manual stop.
      await withClock(Clock.fixed(fixedTime), () async {
        await File(expectedWavPath()).writeAsBytes(const [1, 2, 3]);
      });
      final transcript = await svc.stopAndTranscribe();

      expect(transcript, 'takad diktering');
      expect(
        File(expectedWavPath()).existsSync(),
        isFalse,
        reason: 'capped audio is deleted like any other capture',
      );
    });

    test('a cap-stopped recording at a recorder-relocated path transcribes '
        'THAT file and deletes both (privacy contract)', () async {
      // The cap timer's recorder.stop() may return a relocated path; a
      // second stop() after the recorder is already stopped returns null.
      // If stopAndTranscribe re-stopped instead of using the cap-stored
      // path, it would transcribe the wrong file AND leak the real WAV.
      when(() => modelManager.ensureModelAvailable()).thenAnswer(
        (_) async =>
            const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
      );
      final altPath = '${tempDir.path}/relocated_by_plugin.wav';
      var stopCalls = 0;
      when(
        () => recorder.stop(),
      ).thenAnswer((_) async => ++stopCalls == 1 ? altPath : null);
      final transcriber = _FakeTranscriber(result: 'takad diktering');
      final svc = service(transcriber);

      await withClock(Clock.fixed(fixedTime), () async {
        fakeAsync((async) {
          svc.startRecording();
          async.flushMicrotasks();
          async.elapse(VoiceCaptureService.maxRecordingDuration);
          async.flushMicrotasks();
        });
        await File(expectedWavPath()).writeAsBytes(const [1, 2, 3]);
        await File(altPath).writeAsBytes(const [4, 5, 6]);
      });

      final transcript = await svc.stopAndTranscribe();

      expect(transcript, 'takad diktering');
      expect(
        transcriber.seenAudioPath,
        altPath,
        reason: 'the cap-stored recorder path holds the audio',
      );
      expect(File(expectedWavPath()).existsSync(), isFalse);
      expect(
        File(altPath).existsSync(),
        isFalse,
        reason: 'the relocated capped WAV must not outlive the capture',
      );
    });
  });

  group('happy path', () {
    test(
      'start → stop returns the trimmed transcript and deletes the WAV',
      () async {
        when(() => modelManager.ensureModelAvailable()).thenAnswer(
          (_) async =>
              const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
        );
        final transcriber = _FakeTranscriber(result: ' Tre middagar. ');
        final svc = service(transcriber);

        String? transcript;
        final survived = await withClock(Clock.fixed(fixedTime), () async {
          expect(await svc.startRecording(), isTrue);
          return wavSurvives(svc, () async {
            transcript = await svc.stopAndTranscribe();
          });
        });

        expect(transcript, 'Tre middagar.');
        expect(transcriber.seenModelPath, '/models/ggml.bin');
        expect(transcriber.seenAudioPath, expectedWavPath());
        expect(
          survived,
          isFalse,
          reason: 'audio must be deleted after a successful transcription',
        );
      },
    );

    test('a recorder-relocated file is transcribed AND deleted', () async {
      // Some plugin/platform combinations return a normalized or relocated
      // path from stop(); the privacy contract must cover whichever file
      // actually holds the audio.
      when(() => modelManager.ensureModelAvailable()).thenAnswer(
        (_) async =>
            const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
      );
      final altPath = '${tempDir.path}/relocated_by_plugin.wav';
      when(() => recorder.stop()).thenAnswer((_) async => altPath);
      final transcriber = _FakeTranscriber(result: 'tre middagar');
      final svc = service(transcriber);

      await withClock(Clock.fixed(fixedTime), () async {
        await svc.startRecording();
        await File(expectedWavPath()).writeAsBytes(const [1, 2, 3]);
        await File(altPath).writeAsBytes(const [4, 5, 6]);
        final transcript = await svc.stopAndTranscribe();
        expect(transcript, 'tre middagar');
      });

      expect(transcriber.seenAudioPath, altPath);
      expect(
        File(expectedWavPath()).existsSync(),
        isFalse,
        reason: 'the originally requested path must be deleted',
      );
      expect(
        File(altPath).existsSync(),
        isFalse,
        reason: 'the plugin-returned path holds the audio — must be deleted',
      );
    });

    test('a second start while recording is refused', () async {
      final svc = service(_FakeTranscriber(result: 'x'));
      await withClock(Clock.fixed(fixedTime), () async {
        expect(await svc.startRecording(), isTrue);
        expect(await svc.startRecording(), isFalse);
        expect(svc.isRecording, isTrue);
      });
    });
  });

  group('every failure path deletes the audio and degrades to null', () {
    test('transcriber throwing', () async {
      when(() => modelManager.ensureModelAvailable()).thenAnswer(
        (_) async =>
            const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
      );
      final svc = service(_FakeTranscriber(error: Exception('ffi boom')));

      String? transcript;
      final survived = await withClock(Clock.fixed(fixedTime), () async {
        await svc.startRecording();
        return wavSurvives(svc, () async {
          transcript = await svc.stopAndTranscribe();
        });
      });

      expect(transcript, isNull);
      expect(
        survived,
        isFalse,
        reason: 'audio must be deleted even when transcription throws',
      );
    });

    test('model unavailable (offline / fail-closed download)', () async {
      when(
        () => modelManager.ensureModelAvailable(),
      ).thenAnswer((_) async => null);
      final svc = service(_FakeTranscriber(result: 'aldrig hit'));

      String? transcript;
      final survived = await withClock(Clock.fixed(fixedTime), () async {
        await svc.startRecording();
        return wavSurvives(svc, () async {
          transcript = await svc.stopAndTranscribe();
        });
      });

      expect(transcript, isNull);
      expect(survived, isFalse, reason: 'audio must not outlive the attempt');
    });

    test('cancelRecording deletes audio without transcribing', () async {
      final transcriber = _FakeTranscriber(result: 'aldrig hit');
      final svc = service(transcriber);

      final survived = await withClock(Clock.fixed(fixedTime), () async {
        await svc.startRecording();
        return wavSurvives(svc, () => svc.cancelRecording());
      });

      expect(survived, isFalse, reason: 'cancel must delete the capture');
      expect(
        transcriber.seenAudioPath,
        isNull,
        reason: 'cancel must never transcribe',
      );
      verify(() => recorder.cancel()).called(1);
      expect(await svc.stopAndTranscribe(), isNull);
    });

    test('whitespace-only transcript is null, not an empty prompt', () async {
      when(() => modelManager.ensureModelAvailable()).thenAnswer(
        (_) async =>
            const WhisperModelFile(modelPath: '/models/ggml.bin', version: 1),
      );
      final svc = service(_FakeTranscriber(result: '   '));

      final transcript = await withClock(Clock.fixed(fixedTime), () async {
        await svc.startRecording();
        return svc.stopAndTranscribe();
      });

      expect(transcript, isNull);
    });

    test(
      'denied mic permission refuses to start (no prompt, no file)',
      () async {
        when(() => recorder.hasPermission()).thenAnswer((_) async => false);
        final svc = service(_FakeTranscriber(result: 'x'));

        final started = await withClock(
          Clock.fixed(fixedTime),
          () => svc.startRecording(),
        );

        expect(started, isFalse);
        expect(svc.isRecording, isFalse);
        verifyNever(() => recorder.start(any(), path: any(named: 'path')));
      },
    );

    test('recorder.start throwing leaves the service reusable', () async {
      when(
        () => recorder.start(any(), path: any(named: 'path')),
      ).thenThrow(Exception('mic busy'));
      final svc = service(_FakeTranscriber(result: 'x'));

      final started = await withClock(
        Clock.fixed(fixedTime),
        () => svc.startRecording(),
      );

      expect(started, isFalse);
      expect(svc.isRecording, isFalse);
    });
  });
}
