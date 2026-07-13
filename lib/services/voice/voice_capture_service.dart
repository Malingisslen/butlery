import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/voice/whisper_model_manager.dart';
import 'package:butlery/services/voice/whisper_transcriber.dart';
// Compile-time platform select: whisper_ggml_plus imports dart:ffi
// unconditionally, so it must never be imported on the web compile path
// (it would brick `flutter build web` — runtime kIsWeb guards can't help,
// imports resolve at compile time).
import 'package:butlery/services/voice/whisper_transcriber_stub.dart'
    if (dart.library.ffi) 'package:butlery/services/voice/whisper_transcriber_ffi.dart';

export 'package:butlery/services/voice/whisper_transcriber.dart';

// Deliberately NOT a BaseService (documented non-adopter, see
// lib/services/CLAUDE.md): pure device I/O — mic capture + on-device FFI
// inference. No Firebase user-data operations, no repositories, no
// permission decisions (the OS mic permission is requested by the UI layer
// through OsPermissionHelper before any call lands here).

/// Voice capture → on-device Swedish transcription.
///
/// Menu-agnostic by design (panel condition): the API is
/// "record, then hand back a transcript string" — the weekly-menu prompt,
/// future voice recipe import, and the cooking assistant all consume the
/// same seam. Callers own what the text means.
///
/// Privacy contract (DPO panel condition, kb-whisper plan): audio lives ONLY
/// as a WAV in the app's temporary directory for the duration of one
/// capture. That directory is excluded from OS backups on both platforms
/// (Android cacheDir, iOS NSTemporaryDirectory), nothing is ever uploaded,
/// and the file is deleted in `finally` blocks on EVERY exit path —
/// success, transcription failure, and cancel. The transcript is the only
/// thing that leaves this service, and it goes no further than the caller.
class VoiceCaptureService {
  VoiceCaptureService({
    required WhisperModelManager modelManager,
    AudioRecorder? recorder,
    WhisperTranscriber? transcriber,
  }) : _modelManager = modelManager,
       _recorder = recorder ?? AudioRecorder(),
       _transcriber = transcriber ?? createWhisperTranscriber();

  final WhisperModelManager _modelManager;
  final AudioRecorder _recorder;
  final WhisperTranscriber _transcriber;

  String? _activeRecordingPath;

  /// Injectable temp-dir seam for tests. Production default is the app's
  /// temporary directory — backup-excluded on both platforms (Android
  /// cacheDir, iOS NSTemporaryDirectory), which the privacy contract above
  /// depends on. NOT Directory.systemTemp, which is a world-visible path on
  /// some Android configurations.
  Future<Directory> getTempDir() => getTemporaryDirectory();

  bool get isRecording => _activeRecordingPath != null;

  /// Hard ceiling on one capture. Guided dictation sections run ≤ ~90 s of
  /// speech; 3 min is generous headroom while capping the WAV (~5.5 MB at
  /// 16 kHz mono PCM16) and the transcription cost of a forgotten-open mic.
  static const Duration maxRecordingDuration = Duration(minutes: 3);

  /// Deadline on the native whisper.cpp call. Sized to the capped 3-min
  /// WAV with generous slow-device headroom (>1.3x realtime) — a fired
  /// timeout silently discards the dictation, so it must only catch true
  /// hangs, never a slow success (review finding, 2026-07-13).
  static const Duration transcriptionTimeout = Duration(seconds: 240);

  Timer? _maxDurationTimer;

  /// Set when the cap timer already stopped the recorder: the recorder's
  /// returned path, kept so a later stopAndTranscribe/cancel still
  /// transcribes/deletes the capped file.
  String? _capStoppedPath;

  /// Per-capture auto-stop notification, passed to [startRecording] and
  /// cleared by the service when the capture ends — never a long-lived
  /// field, so one screen's ViewModel can't clobber another's wiring.
  void Function()? _onAutoStopped;

  /// Ensures the speech model is present (downloads ~55 MB on first use).
  /// Returns false when the model can't be obtained — callers keep typed
  /// input as the path of record and surface a quiet notice, never an error
  /// wall.
  Future<bool> prepareModel() async {
    final model = await _modelManager.ensureModelAvailable();
    return model != null;
  }

  /// Starts a push-to-talk capture. Returns true when recording began.
  ///
  /// The OS permission must already be granted (UI layer responsibility via
  /// OsPermissionHelper); a denied permission surfaces here as a failed
  /// start, not a prompt.
  ///
  /// [onAutoStopped] fires if [maxRecordingDuration] caps this capture.
  /// The cap is enforced HERE regardless of the callback: the recorder is
  /// stopped so the WAV never grows past the ceiling, and a later
  /// [stopAndTranscribe] transcribes the capped audio exactly like a
  /// manual stop — callers that pass no callback (menu prompt button)
  /// simply discover the stop when the user taps.
  Future<bool> startRecording({void Function()? onAutoStopped}) async {
    if (_activeRecordingPath != null) return false;

    final tempDir = await getTempDir();
    final path =
        '${tempDir.path}/butlery_voice_'
        '${clock.now().microsecondsSinceEpoch}.wav';
    try {
      if (!await _recorder.hasPermission()) {
        AppLogger.debug('VoiceCaptureService: mic permission not granted');
        return false;
      }
      // whisper.cpp consumes 16 kHz mono PCM16 WAV natively — recording in
      // that exact shape avoids any conversion dependency (no ffmpeg).
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _activeRecordingPath = path;
      _onAutoStopped = onAutoStopped;
      _maxDurationTimer = Timer(maxRecordingDuration, () async {
        if (_activeRecordingPath != path) return;
        AppLogger.debug('VoiceCaptureService: max duration auto-stop');
        String? capStopped;
        try {
          capStopped = await _recorder.stop() ?? path;
        } catch (e) {
          AppLogger.debug('VoiceCaptureService: cap stop failed: $e');
          capStopped = path;
        }
        // Re-check after the await: a manual stop can interleave with the
        // recorder.stop() above, and a stale write here would leak into
        // the NEXT capture (reviewer's millisecond-race hardening).
        if (_activeRecordingPath != path) return;
        _capStoppedPath = capStopped;
        _onAutoStopped?.call();
      });
      return true;
    } catch (e) {
      AppLogger.warning('VoiceCaptureService: recording start failed: $e');
      await _deleteQuietly(path);
      _activeRecordingPath = null;
      return false;
    }
  }

  /// Stops the capture and transcribes it on-device.
  ///
  /// Returns the transcript (trimmed), or null when anything failed — the
  /// caller falls back to typed input. The WAV is deleted on every path.
  Future<String?> stopAndTranscribe() async {
    final path = _activeRecordingPath;
    if (path == null) return null;
    _activeRecordingPath = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _onAutoStopped = null;
    final capStopped = _capStoppedPath;
    _capStoppedPath = null;

    // Kept outside the try so the finally can delete BOTH candidate files:
    // the recorder may return a normalized/relocated path different from the
    // one we requested, and the privacy contract covers whichever file
    // actually holds the audio.
    String? stoppedPath;
    try {
      // A cap-stopped recorder is already stopped — stopping again would
      // return null and lose the real path.
      stoppedPath = capStopped ?? await _recorder.stop();
      final audioPath = stoppedPath ?? path;

      final model = await _modelManager.ensureModelAvailable();
      if (model == null) {
        AppLogger.warning('VoiceCaptureService: model unavailable');
        return null;
      }

      final text = await _transcriber
          .transcribe(audioPath: audioPath, modelPath: model.modelPath)
          .timeout(transcriptionTimeout);
      final trimmed = text?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (e) {
      AppLogger.warning('VoiceCaptureService: transcription failed: $e');
      return null;
    } finally {
      await _deleteQuietly(path);
      if (stoppedPath != null && stoppedPath != path) {
        await _deleteQuietly(stoppedPath);
      }
    }
  }

  /// Aborts an in-progress capture without transcribing. Audio is deleted.
  Future<void> cancelRecording() async {
    final path = _activeRecordingPath;
    if (path == null) return;
    _activeRecordingPath = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _onAutoStopped = null;
    final capStopped = _capStoppedPath;
    _capStoppedPath = null;

    try {
      await _recorder.cancel();
    } catch (e) {
      AppLogger.debug('VoiceCaptureService: cancel failed: $e');
    } finally {
      await _deleteQuietly(path);
      if (capStopped != null && capStopped != path) {
        await _deleteQuietly(capStopped);
      }
    }
  }

  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      // Deletion failure must never mask the primary result; the temp dir
      // is OS-purged and backup-excluded, so the exposure is bounded.
      AppLogger.debug('VoiceCaptureService: temp WAV cleanup failed: $e');
    }
  }
}
