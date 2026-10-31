/// LLM-vision extraction for photo imports (BUT-684 / BUT-1460).
///
/// Extracted from [PhotoImportStrategy] (500-line limit).
///
/// Not a `BaseService`: pure delegation helper owned by the strategy (no
/// Firebase ops, no DI registration of its own) — it resolves
/// [LlmEnhancementService] lazily exactly the way the strategy used to.
library;

import 'dart:typed_data';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';

/// The LLM-vision route of the photo-import strategy.
class PhotoLlmVision {
  /// [strategyName] rides on failure metadata so analytics keep attributing
  /// vision outcomes to the owning strategy, exactly as before the extraction.
  const PhotoLlmVision({required this.strategyName});

  final String strategyName;

  /// Lazy lookup with graceful fallback (unchanged from the strategy).
  LlmEnhancementService? get _llmService {
    try {
      return ServiceLocator.get<LlmEnhancementService>();
    } catch (e) {
      return null;
    }
  }

  /// LLM-vision import for the handwritten opt-in (BUT-684), and a printed
  /// photo the person chose to send after the phone could not read it.
  ///
  /// This ALWAYS returns a terminal [ImportResult] — success, assistance, or
  /// failure — and so preserves the vision call's own message, notably the
  /// structured rate-limit retry text (BUT-1144).
  Future<ImportResult> visionImport(
    Uint8List imageBytes,
    String? sourceType, {
    required bool handwritten,
    ImageFormat formatBefore = ImageFormat.unknown,
    ImageFormat formatAfter = ImageFormat.unknown,
  }) async {
    final llmService = _llmService;
    if (llmService == null) {
      return ImportResult.failure(
        AppLocale.current.errorGeneric,
        metadata: {
          'strategy': strategyName,
          'error_type': 'llm_unavailable',
          'handwritten': handwritten,
        },
      );
    }

    try {
      final llmResult = await llmService.extractFromImage(
        imageBytes,
        context: handwritten
            ? 'Handwritten recipe image from photo import'
            : 'Recipe image from photo import',
        isHandwritten: handwritten,
      );

      final converted = _visionResultToImport(
        llmResult,
        imageBytes: imageBytes,
        sourceType: sourceType,
        formatBefore: formatBefore,
        formatAfter: formatAfter,
        handwritten: handwritten,
      );
      if (converted != null) return converted;

      // ImportFailure — surface its (already localized) message, including the
      // structured rate-limit retry text, instead of falling through to the
      // char-OCR path.
      final failure = llmResult as ImportFailure;
      return ImportResult.failure(
        failure.message,
        errorCode: failure.errorCode,
        metadata: {
          'strategy': strategyName,
          'method': handwritten ? 'llm-vision-handwritten' : 'llm-vision',
          'handwritten': handwritten,
          'error_code': failure.errorCode.name,
        },
      );
    } catch (e) {
      AppLogger.error('Vision photo import failed', e);
      return ImportResult.failure(
        AppLocale.current.errorGeneric,
        metadata: {
          'strategy': strategyName,
          'handwritten': handwritten,
        },
      );
    }
  }

  /// ImportResultV2→ImportResult conversion. Handles success and
  /// assistance; returns null for failure so the caller applies its own
  /// failure semantics.
  ImportResult? _visionResultToImport(
    ImportResultV2 llmResult, {
    required Uint8List imageBytes,
    required String? sourceType,
    required ImageFormat formatBefore,
    required ImageFormat formatAfter,
    required bool handwritten,
  }) {
    if (llmResult is ImportSuccess) {
      return ImportResult.success(
        llmResult.recipe,
        metadata: {
          'strategy': handwritten
              ? 'Photo Import (LLM Vision, handwritten)'
              : 'Photo Import (LLM Vision)',
          'tier': 4,
          'method': handwritten ? 'llm-vision-handwritten' : 'llm-vision',
          'usedLlm': true,
          if (handwritten) 'handwritten': true,
          'image_size_bytes': imageBytes.length,
          'source_type': sourceType,
          'image_format': ImageFormatUtils.wireName(formatBefore),
          'image_format_sent': ImageFormatUtils.wireName(formatAfter),
          ...?llmResult.metadata,
        },
      );
    }

    if (llmResult is ImportNeedsAssistance) {
      return ImportResult.assistance(
        extractedText: llmResult.extractedText,
        suggestedTitle: llmResult.suggestedTitle,
        metadata: {
          'imageBytes': imageBytes,
          'tier': 4,
          'method': handwritten
              ? 'llm-vision-handwritten-partial'
              : 'llm-vision-partial',
          if (handwritten) 'handwritten': true,
          'image_format': ImageFormatUtils.wireName(formatBefore),
          'image_format_sent': ImageFormatUtils.wireName(formatAfter),
        },
      );
    }

    return null; // ImportFailure — caller decides.
  }
}
