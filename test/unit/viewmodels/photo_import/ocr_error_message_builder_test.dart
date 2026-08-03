/// BUT-1195: direct unit tests for [OcrErrorMessageBuilder].
///
/// The OCR-failure message logic was extracted from `PhotoImportViewModel`
/// into this pure static builder (BUT-1154). The seam suite
/// (`ocr_classification_chain_test.dart`) exercises the classification →
/// Swedish-copy contract transitively through the ViewModel and asserts via
/// `contains`. These tests cover what that suite leaves uncovered, now that
/// direct testing is mock-free:
///   * the empty-recommendations → `ocrQualityTips` ELSE branch (the seam
///     suite only ever supplies a non-empty `recommendations` list),
///   * the trailing `ocrRetryOrManual` recovery line is ALWAYS appended,
///   * the [OcrErrorMessageResult] record fields (`qualityScore` /
///     `recommendations` / `confidence`) are populated straight from the
///     result — previously only observed indirectly via VM getters.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/viewmodels/photo_import/ocr_error_message_builder.dart';

/// Builds an [OCRResult] with the exact `confidence` + `metadata` a test needs.
/// Uses the full constructor (not `.failure`) so `confidence` is controllable —
/// `.failure` hard-codes it to 0.0, which would make the confidence-field
/// assertion vacuous.
OCRResult _result({
  double confidence = 0.0,
  Map<String, dynamic> metadata = const {},
}) {
  return OCRResult(
    text: '',
    confidence: confidence,
    processingMethod: 'user_recovery',
    metadata: metadata,
    timestamp: DateTime(2026, 6, 4),
    isSuccessful: false,
    errorMessage: 'test failure',
  );
}

void main() {
  group('OcrErrorMessageBuilder.build', () {
    group('recommendations branch', () {
      test('empty list takes the ocrQualityTips ELSE branch', () {
        // recommendations == [] is non-null but `.isNotEmpty` is false — the
        // distinction the VM-level `contains` tests never isolated. Must fall
        // through to the generic quality tips, NOT the per-item suggestions.
        final result = _result(metadata: {'recommendations': <String>[]});

        final message = OcrErrorMessageBuilder.build(result).message;

        expect(message, contains(AppLocale.current.ocrQualityTips));
        expect(
          message,
          isNot(contains(AppLocale.current.labelImprovementSuggestions)),
        );
      });

      test('absent key takes the ocrQualityTips ELSE branch', () {
        final message = OcrErrorMessageBuilder.build(_result()).message;

        expect(message, contains(AppLocale.current.ocrQualityTips));
      });

      test('non-empty list emits the suggestions header + each bullet '
          'and suppresses the generic tips', () {
        final result = _result(
          metadata: {
            'recommendations': ['Använd JPEG eller PNG', 'Högre upplösning'],
          },
        );

        final message = OcrErrorMessageBuilder.build(result).message;

        expect(
          message,
          contains(AppLocale.current.labelImprovementSuggestions),
        );
        expect(message, contains('• Använd JPEG eller PNG'));
        expect(message, contains('• Högre upplösning'));
        // The two branches are mutually exclusive.
        expect(message, isNot(contains(AppLocale.current.ocrQualityTips)));
      });
    });

    group('recovery line', () {
      test('ocrRetryOrManual is appended on the generic branch', () {
        final message = OcrErrorMessageBuilder.build(_result()).message;

        expect(message, contains(AppLocale.current.ocrRetryOrManual));
      });

      test('ocrRetryOrManual is appended even on the low-quality branch', () {
        // Different leading message path (errorImageQualityTooLow) — the
        // recovery line must still be the final segment regardless of branch.
        final result = _result(metadata: {'quality_assessment': 0.3});

        final message = OcrErrorMessageBuilder.build(result).message;

        expect(message, contains(AppLocale.current.ocrRetryOrManual));
      });
    });

    group('circuit-breaker branch (tier 0)', () {
      // The three paid providers down. Only `on_device_state` varies, so each
      // case below differs from the others in exactly one field.
      const paidProvidersDown = {
        'ocr_space_state': 'open',
        'google_vision_state': 'open',
        'tesseract_state': 'open',
      };

      OCRResult withBreakers(Map<String, dynamic> breakers) =>
          _result(metadata: {'circuit_breakers': breakers});

      test('a HEALTHY on-device tier suppresses "services unavailable"', () {
        // The discriminating case, and the reason the on-device clause exists:
        // tier 0 ran fine and merely read something that was not a recipe.
        // Telling that user the OCR services are unreachable is wrong — and
        // without this test, dropping the on-device conjunct entirely leaves
        // every other case in the repo green.
        final message = OcrErrorMessageBuilder.build(
          withBreakers({...paidProvidersDown, 'on_device_state': 'closed'}),
        ).message;

        expect(
          message,
          isNot(contains(AppLocale.current.errorOcrServicesUnavailable)),
        );
        expect(message, contains(AppLocale.current.errorNoTextExtracted));
      });

      test('an OPEN on-device tier reports "services unavailable"', () {
        // Positive control for the case above: same fixture, one field
        // changed, opposite copy.
        final message = OcrErrorMessageBuilder.build(
          withBreakers({...paidProvidersDown, 'on_device_state': 'open'}),
        ).message;

        expect(
          message,
          contains(AppLocale.current.errorOcrServicesUnavailable),
        );
      });

      test('an ABSENT on-device key counts as down', () {
        // The service omits the key when tier 0 never participated (flag off —
        // the default). Reading absence as "healthy" would make this message
        // unreachable for almost every user.
        final message = OcrErrorMessageBuilder.build(
          withBreakers(paidProvidersDown),
        ).message;

        expect(
          message,
          contains(AppLocale.current.errorOcrServicesUnavailable),
        );
      });
    });

    group('result record fields', () {
      test('qualityScore + recommendations are copied from metadata, '
          'confidence from the OCR result', () {
        final result = _result(
          confidence: 0.42,
          metadata: {
            'quality_assessment': 0.55,
            'recommendations': ['tips-a', 'tips-b'],
          },
        );

        final built = OcrErrorMessageBuilder.build(result);

        expect(built.qualityScore, 0.55);
        expect(built.recommendations, ['tips-a', 'tips-b']);
        expect(built.confidence, 0.42);
      });

      test('record fields are null/empty-safe when metadata is bare', () {
        final built = OcrErrorMessageBuilder.build(_result(confidence: 0.0));

        expect(built.qualityScore, isNull);
        expect(built.recommendations, isNull);
        expect(built.confidence, 0.0);
      });
    });
  });
}
