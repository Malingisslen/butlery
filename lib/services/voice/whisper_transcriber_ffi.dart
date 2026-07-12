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
        // model for no gain. vadModelPath MUST be '' (not omitted): with
        // VAD disabled the plugin serializes a null vad_model_path, and the
        // native nlohmann::json side demands a string — null throws
        // type_error.302 ("Rösten kunde inte tolkas", found on-device
        // 2026-07-12 Pixel 9a).
        vadMode: WhisperVadMode.disabled,
        vadModelPath: '',
      ),
      modelPath: modelPath,
    );
    return response.text;
  }
}
