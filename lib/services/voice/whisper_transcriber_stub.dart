import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/voice/whisper_transcriber.dart';

/// Web factory (no `dart:ffi`). A harmless no-op rather than a throw: the
/// DI module constructs VoiceCaptureService on web too, and the mic button
/// hides itself there — this transcriber should never actually run (the
/// model manager also refuses to cache on web), but if it ever does, the
/// contract is "null = degrade to typed input", never a crash.
WhisperTranscriber createWhisperTranscriber() =>
    const _UnavailableTranscriber();

class _UnavailableTranscriber implements WhisperTranscriber {
  const _UnavailableTranscriber();

  @override
  Future<String?> transcribe({
    required String audioPath,
    required String modelPath,
  }) async {
    AppLogger.debug('WhisperTranscriber: unavailable on this platform');
    return null;
  }
}
