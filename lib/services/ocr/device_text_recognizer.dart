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

import 'package:butlery/services/ocr/text_layout.dart';

/// What one recognition pass produced: the text, and — when the provider
/// measured it — where the words sat.
///
/// ONE type rather than a second `recognizeLayout()` method, deliberately. Two
/// methods would mean two platform round-trips, two temp files and two failure
/// modes for one photo, and nothing would guarantee the second call read the
/// same bytes as the first. The geometry is a by-product the recognizer has
/// already computed by the time it hands back the text, so taking both at once
/// costs nothing.
class RecognitionResult {
  /// The provider's OWN string, exactly as it assembled it — what shipped
  /// before this seam carried geometry.
  final String providerText;

  /// Null when the provider measured nothing.
  final PageLayout? layout;

  const RecognitionResult({required this.providerText, this.layout});

  /// The string built from [layout]'s lines — the only one a line index
  /// addresses. Null when there is no geometry.
  String? get layoutText => layout?.text;

  /// There is deliberately NO `text` getter that picks one for you.
  ///
  /// The two are assembled differently and, since 2026-08-08, need not hold the
  /// same words: the layout string has the edge-bleed rows cropped out of it
  /// (`edge_crop.dart`), so on a page whose photo caught the neighbouring column
  /// it is a strict SUBSET of [providerText]. Which one ships is a product
  /// decision the caller owns, not a default this type gets to make:
  /// [layoutText] is required for the geometry path to mean
  /// anything, and [providerText] is what a rollback has to be able to return
  /// to. A convenience getter preferring the layout would make that rollback
  /// impossible to express, which is exactly the hole this shape closes.
}

abstract class DeviceTextRecognizer {
  /// False on platforms without an on-device recognizer, so callers can skip
  /// the tier without treating it as a provider failure.
  bool get isAvailable;

  /// Returns what was recognized, or null when nothing usable was read.
  ///
  /// Contract: null means "fall through to the next provider", never a crash.
  /// The caller still decides whether the text is *acceptable* — this layer
  /// makes no judgement about recipe-shapedness.
  Future<RecognitionResult?> recognize(Uint8List imageBytes);

  Future<void> dispose();
}
