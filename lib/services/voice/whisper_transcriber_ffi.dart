import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

import 'package:butlery/services/voice/whisper_transcriber.dart';

/// Native-platform factory (selected via `if (dart.library.ffi)`).
WhisperTranscriber createWhisperTranscriber() => const WhisperGgmlTranscriber();

/// Runs KB-Whisper via whisper_ggml_plus (whisper.cpp FFI, in an isolate).
class WhisperGgmlTranscriber implements WhisperTranscriber {
  const WhisperGgmlTranscriber();

  @override
  Future<String?> transcribe({
    required String audioPath,
    required String modelPath,
  }) async {
    // The WhisperModel enum only selects a default download URL/dir inside
    // the package; inference uses OUR explicit modelPath (the KB-Whisper
    // GGML file delivered by WhisperModelManager), so `base` here is inert.
    const whisper = Whisper(model: WhisperModel.base);
    final response = await whisper.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: 'sv',
        isNoTimestamps: true,
        // No voice-activity detection: push-to-talk utterances are short
        // and explicitly delimited, and VAD would pull in a second bundled
        // model for no gain.
        vadMode: WhisperVadMode.disabled,
      ),
      modelPath: modelPath,
    );
    return response.text;
  }
}
