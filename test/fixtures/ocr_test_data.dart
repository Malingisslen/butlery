/// Test fixtures and data for OCR extraction service tests
///
/// This file contains:
/// - Test image data and quality scenarios
/// - Expected results for various test cases
/// - Helper functions for creating test data

import 'dart:typed_data';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr_extraction_service.dart';

/// Test image data generators
class OCRTestImages {
  /// Create a valid PNG image (minimal header + data)
  static Uint8List get validPNG => Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    ...List.generate(1024, (i) => i % 256), // 1KB of data
  ]);

  /// Create a valid JPEG image (minimal header + data).
  ///
  /// BUT-660: bumped to 60KB so the pre-OCR quality gate (which rejects
  /// images below `UploadConstants.minOcrImageBytes` = 50KB) doesn't filter
  /// this fixture out before the test reaches its OCR-mock assertions.
  static Uint8List get validJPEG => Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature
    ...List.generate(60 * 1024, (i) => i % 256), // 60KB of data
  ]);

  /// BUT-660: produce a unique 60KB PNG-header'd image for tests that need
  /// distinct cache keys. Inputs below 50KB are rejected by the pre-OCR
  /// quality gate (see `OCRExtractionService.assessImageQuality`); use this
  /// helper instead of inline 100-byte blobs so the gate doesn't filter
  /// the test image out before reaching the OCR-mock assertions.
  static Uint8List uniqueImage(int seed) => Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ...List.generate(60 * 1024, (j) => (seed + j) % 256),
  ]);

  /// Create an invalid image format
  static Uint8List get invalidFormat => Uint8List.fromList([
    0x00, 0x00, 0x00, 0x00, // Invalid signature
    ...List.generate(100, (i) => i % 256),
  ]);

  /// Create a very small image (poor quality).
  ///
  /// BUT-660: 10KB triggers the hard-reject path in `extractText` (gate
  /// rejects < 50KB). Use only for `assessImageQuality`-direct tests; if you
  /// pass this to `extractText` the result will be a `pre_ocr_quality_gate`
  /// failure, not the advisory-warning path the fixture name suggests.
  static Uint8List get tooSmall => Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...List.generate(10 * 1024, (i) => i % 256), // 10KB (below 50KB threshold)
  ]);

  /// Create a very large image (exceeds max size)
  static Uint8List get tooLarge => Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...List.generate(
      11 * 1024 * 1024,
      (i) => i % 256,
    ), // 11MB (exceeds 10MB limit)
  ]);

  /// Create a medium-quality image (good for testing)
  static Uint8List get mediumQuality => Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...List.generate(500 * 1024, (i) => i % 256), // 500KB
  ]);
}

/// Expected OCR text results for testing
class OCRExpectedResults {
  /// Swedish recipe text (Köttbullar)
  static const String swedishRecipeText = '''Köttbullar med gräddsås

500g köttfärs
1 ägg
2 dl ströbröd
1 dl mjölk

Instruktioner:
1. Blanda alla ingredienser
2. Forma till bullar
3. Stek i smör tills genomstekta
4. Servera med gräddsås

Portioner: 4
Tid: 30 minuter''';

  /// High confidence text (lots of keywords)
  static const String highConfidenceText = '''Ingredienser för 4 portioner:
500g köttfärs
1 ägg
2 dl ströbröd
1 dl mjölk
Salt och peppar

Tillsätt all ingredienser i en skål. Vispa ihop tills jämnt.
Stek i 20 minuter på medelhög värme.''';

  /// Medium confidence text (some keywords)
  static const String mediumConfidenceText = '''Recept på Köttbullar
Blanda köttfärs med ägg
Stek i panna
Servera''';

  /// Low confidence text (few keywords, poor structure)
  static const String lowConfidenceText = '''K0ttbullar
500g f4rs
1 egg''';

  /// Very short text (low confidence due to length)
  static const String veryShortText = 'Köttbullar';

  /// Empty text (zero confidence)
  static const String emptyText = '';
}

/// Test helper functions
class OCRTestHelpers {
  /// Create a test OCRResult with default values
  static OCRResult createTestResult({
    String text = OCRExpectedResults.swedishRecipeText,
    double confidence = 0.85,
    String processingMethod = 'on_device',
    bool isSuccessful = true,
    String? errorMessage,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return OCRResult(
      text: text,
      confidence: confidence,
      processingMethod: processingMethod,
      metadata: metadata ?? {'test': true},
      timestamp: timestamp ?? DateTime(2025, 1, 15, 12, 0, 0),
      isSuccessful: isSuccessful,
      errorMessage: errorMessage,
    );
  }

  /// Create a test ImageQualityAssessment with default values
  static ImageQualityAssessment createQualityAssessment({
    bool isGoodQuality = true,
    double qualityScore = 0.9,
    List<String>? issues,
    List<String>? recommendations,
  }) {
    return ImageQualityAssessment(
      isGoodQuality: isGoodQuality,
      qualityScore: qualityScore,
      issues: issues ?? [],
      recommendations: recommendations ?? [],
    );
  }

  /// Calculate expected confidence for text (mirrors service logic)
  static double calculateExpectedConfidence(String text) {
    if (text.isEmpty) return 0.0;

    final textLength = text.trim().length;
    final lineCount = text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;

    if (textLength == 0) return 0.0;
    if (textLength < 10) return 0.3;
    if (textLength < 30) return 0.5;
    if (textLength < 100) return 0.7;

    const baseConfidence = 0.8;
    final structureBonus = lineCount * 0.03 > 0.2 ? 0.2 : lineCount * 0.03;

    const keywords = [
      'ingrediens',
      'tillsätt',
      'vispa',
      'stek',
      'portioner',
      'minut',
    ];
    final keywordMatches = keywords
        .where((k) => text.toLowerCase().contains(k))
        .length;
    final keywordBonus = keywordMatches * 0.03 > 0.15
        ? 0.15
        : keywordMatches * 0.03;

    return (baseConfidence + structureBonus + keywordBonus) > 1.0
        ? 1.0
        : baseConfidence + structureBonus + keywordBonus;
  }
}

/// Test scenarios for comprehensive testing
class OCRTestScenarios {
  /// Scenario: Recognizer keeps failing (circuit breaker trips)
  static const String scenario2Description =
      'Recognizer fails repeatedly → Circuit breaker opens';

  /// Scenario: Cache hit after successful extraction
  static const String scenario3Description =
      'First extraction succeeds → Second extraction uses cache';

  /// Scenario: Usage limit warning at 80%
  static const String scenario5Description =
      'Usage reaches 80% → Warning triggered';

  /// Scenario: Cache expiry after 24 hours
  static const String scenario6Description =
      'Cache entry expires after 24 hours';

  /// Scenario: Image quality assessment failure
  static const String scenario7Description =
      'Poor image quality detected → Recommendations provided';

  /// Scenario: Swedish recipe with keywords
  static const String scenario8Description =
      'Swedish recipe text → High confidence with keyword bonus';
}

/// Scripted on-device recognizer: returns [text] for every image (null reads
/// as "nothing usable") and counts how often it was asked.
class FakeDeviceTextRecognizer implements DeviceTextRecognizer {
  FakeDeviceTextRecognizer({this.text});

  String? text;
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async {
    calls++;
    final t = text;
    return t == null ? null : RecognitionResult(providerText: t);
  }

  @override
  Future<void> dispose() async {}
}
