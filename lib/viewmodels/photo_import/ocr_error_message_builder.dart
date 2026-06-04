// lib/viewmodels/photo_import/ocr_error_message_builder.dart

import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Outcome of [OcrErrorMessageBuilder.build]: the user-facing Swedish failure
/// message plus the quality metrics extracted from the OCR result that the
/// ViewModel surfaces through its `qualityScore` / `recommendations` /
/// `confidence` getters.
class OcrErrorMessageResult {
  const OcrErrorMessageResult({
    required this.message,
    this.qualityScore,
    this.recommendations,
    this.confidence,
  });

  final String message;
  final double? qualityScore;
  final List<String>? recommendations;
  final double? confidence;
}

/// Builds the enhanced OCR-failure message from an [OCRResult]'s metadata.
/// Extracted from `PhotoImportViewModel` (BUT-1154) to keep that file under the
/// 500-line limit. Pure + side-effect-free, so the BUT-1022 metadata→Swedish-copy
/// contract is unit-testable without the ViewModel or the OCR singleton.
class OcrErrorMessageBuilder {
  const OcrErrorMessageBuilder._();

  static OcrErrorMessageResult build(OCRResult result) {
    final qualityScore = result.metadata['quality_assessment'] as double?;
    final recommendations =
        (result.metadata['recommendations'] as List?)?.cast<String>();
    final confidence = result.confidence;

    // Extract circuit breaker states
    final circuitBreakers =
        result.metadata['circuit_breakers'] as Map<String, dynamic>?;
    final allProvidersDown = circuitBreakers != null &&
        circuitBreakers['ocr_space_state'] == 'open' &&
        circuitBreakers['google_vision_state'] == 'open' &&
        circuitBreakers['tesseract_state'] == 'open';

    // Build specific error message based on failure reasons
    final messageParts = <String>[];

    // BUT-963: typed failure classification from the OCR service. Wins over
    // the "no text extracted" generic fallback when the providers actually
    // threw a recognizable error (rate limit, timeout, network). Quality
    // gate still wins over classification — if the image was unreadable to
    // begin with, the user should fix the image, not retry blindly.
    final classification = result.metadata['failure_classification'] as String?;

    if (qualityScore != null && qualityScore < 0.6) {
      final l = AppLocale.current;
      messageParts.add(
        l.errorImageQualityTooLow((qualityScore * 100).toInt()),
      );
    } else if (classification == 'rate_limit') {
      messageParts.add(AppLocale.current.errorOcrRateLimit);
    } else if (classification == 'timeout' || classification == 'network') {
      messageParts.add(AppLocale.current.errorOcrTimeout);
    } else if (allProvidersDown) {
      messageParts.add(
        AppLocale.current.errorOcrServicesUnavailable,
      );
    } else {
      messageParts.add(AppLocale.current.errorNoTextExtracted);
    }

    // Add specific recommendations if available
    if (recommendations != null && recommendations.isNotEmpty) {
      messageParts.add('\n\n${AppLocale.current.labelImprovementSuggestions}');
      for (final recommendation in recommendations) {
        messageParts.add('• $recommendation');
      }
    } else {
      // Generic quality tips if no specific recommendations
      messageParts.add(
        '\n\n${AppLocale.current.ocrQualityTips}',
      );
    }

    // Add recovery options
    messageParts.add(
      '\n\n${AppLocale.current.ocrRetryOrManual}',
    );

    return OcrErrorMessageResult(
      message: messageParts.join('\n'),
      qualityScore: qualityScore,
      recommendations: recommendations,
      confidence: confidence,
    );
  }
}
