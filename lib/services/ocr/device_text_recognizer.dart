/// Seam over the platform's built-in text recognizer (ML Kit), used as the
/// free tier-0 provider in [OCRExtractionService] before any paid provider.
///
/// The production implementation is selected by a conditional import in
/// `ocr_extraction_service.dart`:
///   - native → device_text_recognizer_mlkit.dart
///   - web    → device_text_recognizer_stub.dart (ML Kit is mobile-only)
///
/// The import must be conditional rather than a runtime `kIsWeb` guard:
/// `google_mlkit_text_recognition` resolves platform channels at compile
/// time and has no web implementation, so importing it on the web compile
/// path breaks `flutter build web`.
library;

import 'dart:typed_data';

abstract class DeviceTextRecognizer {
  /// False on platforms without an on-device recognizer, so callers can skip
  /// the tier without treating it as a provider failure.
  bool get isAvailable;

  /// Returns recognized text, or null when nothing usable was read.
  ///
  /// Contract: null means "fall through to the next provider", never a crash.
  /// The caller still decides whether the text is *acceptable* — this layer
  /// makes no judgement about recipe-shapedness.
  Future<String?> recognize(Uint8List imageBytes);

  Future<void> dispose();
}
