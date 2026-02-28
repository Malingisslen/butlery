/// LLM service for recipe extraction using Mistral AI via Cloud Functions.
///
/// This service provides:
/// - Text-to-recipe extraction (structureRecipe)
/// - Image-to-recipe OCR (ocrRecipeImage)
/// - Rate limiting integration
/// - Cost tracking
library;

import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Service for LLM-based recipe extraction.
///
/// Uses Firebase Cloud Functions to call Mistral AI securely.
/// API keys are stored in Firebase Secrets, never exposed to client.
class LlmService extends BaseService {
  @override
  String get serviceName => 'LlmService';

  final FirebaseFunctions _functions;
  final ImportRateLimiter _rateLimiter;
  final ConsentService _consentService;

  /// Region for Cloud Functions (matches deployment)
  static const _region = 'europe-west1';

  LlmService({
    required ImportRateLimiter rateLimiter,
    required ConsentService consentService,
    FirebaseFunctions? functions,
  })  : _rateLimiter = rateLimiter,
        _consentService = consentService,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: _region);

  /// Extract structured recipe from text.
  ///
  /// [text] - Raw text containing recipe (HTML, plain text, etc.)
  /// [mode] - Extraction mode (extract, enhance, spoken)
  /// [partialData] - Optional partial data to enhance
  /// [sourceUrl] - Source URL for reference
  ///
  /// Returns [StructureRecipeResponse] with extracted recipe or error.
  /// Throws [LlmException] on Firebase errors.
  Future<StructureRecipeResponse> structureRecipe({
    required String text,
    StructureMode mode = StructureMode.extract,
    Map<String, dynamic>? partialData,
    String? sourceUrl,
  }) async {
    // GDPR Art. 5(1)(b): Require explicit consent for AI processing
    if (!await _consentService.hasConsent('aiProcessing')) {
      throw const LlmException(
        'AI-bearbetning kräver ditt samtycke. '
        'Aktivera "AI-bearbetning" under Integritetsinställningar.',
      );
    }

    AppLogger.debug(
      'LlmService: structureRecipe called with ${text.length} chars, mode=$mode',
    );

    // Check rate limit
    final llmType = mode == StructureMode.enhance
        ? LlmOperationType.enhancement
        : LlmOperationType.fullExtraction;
    final operation = ImportOperation.withLlm('llm', llmType);
    final limitCheck = await _rateLimiter.checkLimit(operation);

    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      AppLogger.warning('LlmService: Rate limited - ${denied.message}');
      return StructureRecipeResponse(
        success: false,
        error: denied.swedishMessage,
        estimatedCost: 0.0,
      );
    }

    try {
      final callable = _functions.httpsCallable('structureRecipe');
      final request = StructureRecipeRequest(
        text: text,
        mode: mode,
        partialData: partialData,
        sourceUrl: sourceUrl,
      );

      final result =
          await callable.call<Map<String, dynamic>>(request.toJson());
      final response = StructureRecipeResponse.fromJson(result.data);

      // Record usage with cost
      if (response.success) {
        await _rateLimiter.recordUsage(operation,
            llmCost: response.estimatedCost);
        AppLogger.info(
          'LlmService: Successfully extracted "${response.recipe?.title}" '
          '(cost: \$${response.estimatedCost.toStringAsFixed(4)})',
        );
      }

      return response;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('LlmService: Firebase error - ${e.code}: ${e.message}');
      throw LlmException.fromFirebase(e);
    } catch (e) {
      AppLogger.error('LlmService: Unexpected error - $e');
      throw LlmException(AppLocale.current.llmUnexpectedError('$e'));
    }
  }

  /// Extract recipe from image using OCR and vision AI.
  ///
  /// [imageBytes] - Image data as bytes
  /// [imageUrl] - Alternative: URL to image
  /// [mimeType] - Optional MIME type (auto-detected if not provided)
  /// [context] - Optional context (e.g., filename)
  ///
  /// Returns [OcrRecipeImageResponse] with extracted recipe or raw text.
  /// Throws [LlmException] on Firebase errors.
  Future<OcrRecipeImageResponse> ocrRecipeImage({
    Uint8List? imageBytes,
    String? imageUrl,
    String? mimeType,
    String? context,
  }) async {
    if (imageBytes == null && imageUrl == null) {
      throw const LlmException(
          'Either imageBytes or imageUrl must be provided');
    }

    // GDPR Art. 5(1)(b): Require explicit consent for AI processing
    if (!await _consentService.hasConsent('aiProcessing')) {
      throw const LlmException(
        'AI-bearbetning kräver ditt samtycke. '
        'Aktivera "AI-bearbetning" under Integritetsinställningar.',
      );
    }

    AppLogger.debug(
      'LlmService: ocrRecipeImage called '
      '${imageBytes != null ? "with ${imageBytes.length} bytes" : "with URL: $imageUrl"}',
    );

    // Check rate limit - vision is more expensive
    final operation = ImportOperation.withLlm('llm', LlmOperationType.vision);
    final limitCheck = await _rateLimiter.checkLimit(operation);

    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      AppLogger.warning('LlmService: Rate limited - ${denied.message}');
      return OcrRecipeImageResponse(
        success: false,
        error: denied.swedishMessage,
        estimatedCost: 0.0,
      );
    }

    try {
      final callable = _functions.httpsCallable('ocrRecipeImage');

      final OcrRecipeImageRequest request;
      if (imageBytes != null) {
        request = OcrRecipeImageRequest.fromBytes(
          imageBytes,
          mimeType: mimeType,
          context: context,
        );
      } else {
        request = OcrRecipeImageRequest.fromUrl(
          imageUrl!,
          context: context,
        );
      }

      final result =
          await callable.call<Map<String, dynamic>>(request.toJson());
      final response = OcrRecipeImageResponse.fromJson(result.data);

      // Record usage with cost
      await _rateLimiter.recordUsage(operation,
          llmCost: response.estimatedCost);

      if (response.success) {
        AppLogger.info(
          'LlmService: Successfully extracted "${response.recipe?.title}" from image '
          '(cost: \$${response.estimatedCost.toStringAsFixed(4)})',
        );
      } else if (response.rawText != null) {
        AppLogger.info(
          'LlmService: Got raw text (${response.rawText!.length} chars) but no structured recipe',
        );
      }

      return response;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error('LlmService: Firebase error - ${e.code}: ${e.message}');
      throw LlmException.fromFirebase(e);
    } catch (e) {
      AppLogger.error('LlmService: Unexpected error - $e');
      throw LlmException(AppLocale.current.llmUnexpectedError('$e'));
    }
  }

  /// Check if LLM service is available (not rate limited).
  Future<bool> isAvailable() async {
    return _rateLimiter.isLlmAvailable();
  }

  /// Get current LLM usage stats.
  Future<UsageLimits> getUsageStats() async {
    return _rateLimiter.getUsageStats();
  }
}
