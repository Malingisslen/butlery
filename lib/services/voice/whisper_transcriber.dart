/// Seam over the whisper.cpp FFI call so unit tests never load a native
/// library and the WEB build never sees `dart:ffi` (whisper_ggml_plus
/// imports it unconditionally, which would brick `flutter build web`).
/// The production implementation is selected by a conditional import in
/// voice_capture_service.dart:
///   - native → whisper_transcriber_ffi.dart (WhisperGgmlTranscriber)
///   - web    → whisper_transcriber_stub.dart (no-op; voice is mobile-only)
library;

abstract class WhisperTranscriber {
  Future<String?> transcribe({
    required String audioPath,
    required String modelPath,
  });
}
