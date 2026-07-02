/// LLM-vision extraction for photo imports (BUT-684 / BUT-1460).
///
/// Extracted from [PhotoImportStrategy] (500-line limit): both vision routes —
/// the printed Tier-4 fallback and the handwritten opt-in — live here and share
/// ONE ImportResultV2→ImportResult conversion so they cannot silently drift.
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

/// The two LLM-vision routes of the photo-import strategy.
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

  /// BUT-684: LLM-vision import for the handwritten opt-in.
  ///
  /// Unlike [tryFallback] (which returns null so the char-OCR cascade can
  /// try the next tier), this ALWAYS returns a terminal [ImportResult] —
  /// success, assistance, or failure — because handwriting has no viable
  /// char-OCR fallback. Returning a failure here (rather than null) stops
  /// the import from re-entering the LLM fallback with the printed prompt (a
  /// second billed call) and preserves the vision call's own message — notably
  /// the structured rate-limit retry text (BUT-1144).
  Future<ImportResult> handwrittenImport(
    Uint8List imageBytes,
    String? sourceType, {
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
          'handwritten': true,
        },
      );
    }

    try {
      final llmResult = await llmService.extractFromImage(
        imageBytes,
        context: 'Handwritten recipe image from photo import',
        isHandwritten: true,
      );

      final converted = _visionResultToImport(
        llmResult,
        imageBytes: imageBytes,
        sourceType: sourceType,
        formatBefore: formatBefore,
        formatAfter: formatAfter,
        handwritten: true,
      );
      if (converted != null) return converted;

      // ImportFailure — surface its (already localized) message, including the
      // structured rate-limit retry text, instead of falling through to the
      // char-OCR cascade (which would fire a second, printed-prompt LLM call).
      final failure = llmResult as ImportFailure;
      return ImportResult.failure(
        failure.message,
        metadata: {
          'strategy': strategyName,
          'method': 'llm-vision-handwritten',
          'handwritten': true,
          'error_code': failure.errorCode.name,
        },
      );
    } catch (e) {
      AppLogger.error('Handwritten photo import failed', e);
      return ImportResult.failure(
        AppLocale.current.errorGeneric,
        metadata: {
          'strategy': strategyName,
          'handwritten': true,
        },
      );
    }
  }

  /// Try LLM vision extraction as Tier 4 fallback when char-OCR fails
  /// (printed path). Returns null on failure/unavailability so the strategy
  /// falls through to its original error.
  Future<ImportResult?> tryFallback(
    Uint8List imageBytes,
    String? sourceType, {
    ImageFormat formatBefore = ImageFormat.unknown,
    ImageFormat formatAfter = ImageFormat.unknown,
  }) async {
    final llmService = _llmService;
    if (llmService == null) {
      return null; // LLM service not available
    }

    try {
      final llmResult = await llmService.extractFromImage(
        imageBytes,
        context: 'Recipe image from photo import',
      );

      // LLM failure converts to null here: fall through to original error.
      return _visionResultToImport(
        llmResult,
        imageBytes: imageBytes,
        sourceType: sourceType,
        formatBefore: formatBefore,
        formatAfter: formatAfter,
        handwritten: false,
      );
    } catch (e) {
      // LLM error - return null to fall through to original error
      return null;
    }
  }

  /// Shared ImportResultV2→ImportResult conversion for BOTH vision routes
  /// (BUT-1460 review FIX 2 — previously copy-pasted, only the
  /// method/strategy metadata strings differed). Handles success and
  /// assistance; returns null for failure so each caller applies its own
  /// failure semantics (terminal for handwritten, fall-through for printed).
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
