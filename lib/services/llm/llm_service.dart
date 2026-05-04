/// LLM service for recipe extraction using Google Gemini via Cloud Functions.
///
/// This service provides:
/// - Text-to-recipe extraction (structureRecipe)
/// - Image-to-recipe OCR (ocrRecipeImage)
/// - Selective ingredient line parsing (parseIngredientLines)
/// - Rate limiting integration
/// - Cost tracking
library;

import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/circuit_breaker.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/pii_scrubber.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Service for LLM-based recipe extraction.
///
/// Uses Firebase Cloud Functions to call Google Gemini securely.
/// API keys are stored in Firebase Secrets, never exposed to client.
class LlmService extends BaseService {
  @override
  String get serviceName => 'LlmService';

  final FirebaseFunctions _functions;
  final ImportRateLimiter _rateLimiter;
  final ConsentService _consentService;

  /// BUT-589: shared circuit breaker for the Vertex/Gemini backend.
  /// Trips after [_failureThreshold] consecutive Cloud Function failures and
  /// short-circuits to a fast denied response for [_resetTime]. One callable
  /// trip protects every LLM operation (extract / OCR / ingredient lines)
  /// because they all share the same Gemini backend — if it's down for one,
  /// it's down for all.
  ///
  /// Rate-limit denials and consent denials are NOT failures (they're normal
  /// flow), so they don't increment the breaker.
  final CircuitBreaker _backendBreaker;

  static const int _failureThreshold = 3;
  static const Duration _resetTime = Duration(seconds: 60);

  /// Region for Cloud Functions (matches deployment)
  static const _region = 'europe-west1';

  /// Consent purpose key for AI processing (GDPR Art. 5(1)(b))
  static const _consentPurpose = ConsentPurpose.aiProcessing;

  LlmService({
    required ImportRateLimiter rateLimiter,
    required ConsentService consentService,
    FirebaseFunctions? functions,
    CircuitBreaker? backendBreaker,
  })  : _rateLimiter = rateLimiter,
        _consentService = consentService,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: _region),
        _backendBreaker = backendBreaker ??
            CircuitBreaker(
              failureThreshold: _failureThreshold,
              resetTime: _resetTime,
            );

  /// Test seam: read-only view of the backend circuit breaker so unit tests
  /// can assert open/closed transitions without poking the private field.
  @visibleForTesting
  CircuitBreaker get backendBreakerForTest => _backendBreaker;

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
    AppLogger.debug(
      'LlmService: structureRecipe called with ${text.length} chars, mode=$mode',
    );

    final llmType = mode == StructureMode.enhance
        ? LlmOperationType.enhancement
        : LlmOperationType.fullExtraction;
    final operation = ImportOperation.withLlm('llm', llmType);
    final request = StructureRecipeRequest(
      text: text,
      mode: mode,
      partialData: partialData,
      sourceUrl: sourceUrl,
    );

    final response = await _executeLlmCall(
      operation: operation,
      functionName: 'structureRecipe',
      requestJson: request.toJson(),
      parseResponse: StructureRecipeResponse.fromJson,
      buildDeniedResponse: (message) => StructureRecipeResponse(
        success: false,
        error: message,
        estimatedCost: 0.0,
      ),
    );

    if (response.success) {
      AppLogger.info(
        'LlmService: Successfully extracted "${response.recipe?.title}" '
        '(cost: \$${response.estimatedCost.toStringAsFixed(4)})',
      );
    }

    return response;
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

    AppLogger.debug(
      'LlmService: ocrRecipeImage called '
      '${imageBytes != null ? "with ${imageBytes.length} bytes" : "with URL: $imageUrl"}',
    );

    final operation = ImportOperation.withLlm('llm', LlmOperationType.vision);

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

    final response = await _executeLlmCall(
      operation: operation,
      functionName: 'ocrRecipeImage',
      requestJson: request.toJson(),
      parseResponse: OcrRecipeImageResponse.fromJson,
      buildDeniedResponse: (message) => OcrRecipeImageResponse(
        success: false,
        error: message,
        estimatedCost: 0.0,
      ),
      recordUsageOnFailure: true,
    );

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
  }

  /// Parse individual ingredient lines via LLM.
  ///
  /// Used by selective CRF→LLM routing: only low-confidence CRF lines
  /// are sent for re-parsing instead of the entire recipe.
  /// Returns a [StructureRecipeResponse] where `recipe.ingredients`
  /// contains the parsed lines (other recipe fields are placeholders).
  Future<StructureRecipeResponse> parseIngredientLines({
    required List<String> lines,
  }) async {
    if (lines.isEmpty) {
      return const StructureRecipeResponse(
        success: false,
        error: 'No ingredient lines to parse',
        estimatedCost: 0.0,
      );
    }

    AppLogger.debug(
      'LlmService: parseIngredientLines called with ${lines.length} lines',
    );

    final operation =
        ImportOperation.withLlm('llm', LlmOperationType.ingredientLines);
    final request = StructureRecipeRequest(
      text: lines.join('\n'),
      mode: StructureMode.ingredientLines,
    );

    final response = await _executeLlmCall(
      operation: operation,
      functionName: 'structureRecipe',
      requestJson: request.toJson(),
      parseResponse: StructureRecipeResponse.fromJson,
      buildDeniedResponse: (message) => StructureRecipeResponse(
        success: false,
        error: message,
        estimatedCost: 0.0,
      ),
    );

    if (response.success) {
      AppLogger.info(
        'LlmService: Parsed ${response.recipe?.ingredients.length ?? 0} '
        'ingredient lines (cost: \$${response.estimatedCost.toStringAsFixed(4)})',
      );
    }

    return response;
  }

  /// Check if LLM service is available (not rate limited, not killed).
  ///
  /// BUT-439: dual-control kill switch on the client too:
  ///   - `ai_enabled` (master) — kills every LLM-fronted feature.
  ///   - `llm_parser_enabled` (per-feature) — kills only recipe parsing.
  ///
  /// Both Remote Config keys default to true via the server `defaults`
  /// map. We fail open if Remote Config is unreachable: the server-side
  /// gate inside `structureRecipe` / `ocrRecipeImage` is the authoritative
  /// enforcement layer; the client check exists to short-circuit UI
  /// before the user spends rate-limit tokens.
  Future<bool> isAvailable() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      if (remoteConfig.getBool('ai_enabled') == false) {
        return false;
      }
      if (remoteConfig.getBool('llm_parser_enabled') == false) {
        return false;
      }
    } catch (_) {
      // Remote Config not available — allow (server-side will enforce)
    }
    return _rateLimiter.isLlmAvailable();
  }

  /// Get current LLM usage stats.
  Future<UsageLimits> getUsageStats() async {
    return _rateLimiter.getUsageStats();
  }

  /// Shared pipeline: consent → rate limit → Firebase callable → record usage.
  ///
  /// Encapsulates the boilerplate shared by all LLM operations:
  /// 1. GDPR consent check
  /// 2. Rate-limit guard
  /// 3. Firebase Cloud Function call + response parsing
  /// 4. Usage recording (on success, or always if [recordUsageOnFailure])
  /// 5. Error handling (Firebase and generic exceptions)
  Future<T> _executeLlmCall<T>({
    required ImportOperation operation,
    required String functionName,
    required Map<String, dynamic> requestJson,
    required T Function(Map<String, dynamic> data) parseResponse,
    required T Function(String message) buildDeniedResponse,
    bool recordUsageOnFailure = false,
  }) async {
    if (!await _consentService.hasConsent(_consentPurpose)) {
      throw const LlmException(
        'AI-bearbetning kräver ditt samtycke. '
        'Aktivera "AI-bearbetning" under Integritetsinställningar.',
      );
    }

    // BUT-589: check the breaker BEFORE the rate-limit Firestore read so an
    // open circuit short-circuits without paying I/O. This is the exact
    // scenario the breaker was added to protect — Gemini outage causing
    // request pile-up — and reading Firestore for a guaranteed-denied call
    // would defeat the cost protection.
    if (!_backendBreaker.allowRequest) {
      AppLogger.warning(
        'LlmService: backend circuit breaker OPEN, short-circuiting',
      );
      return buildDeniedResponse(
        'AI-tjänsten är tillfälligt otillgänglig. Försök igen om en minut.',
      );
    }

    final limitCheck = await _rateLimiter.checkLimit(operation);
    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      AppLogger.warning('LlmService: Rate limited - ${denied.message}');
      return buildDeniedResponse(denied.swedishMessage);
    }

    try {
      final callable = _functions.httpsCallable(
        functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );
      // Defence-in-depth: scrub PII on the client before the payload hits the
      // wire so Cloud Logging never ingests raw PII. The server-side scrubber
      // (functions/src/llm/pii-scrubber.ts) still runs as the second line of
      // defence; keep the Dart patterns in sync with the TS ones.
      final scrubbedJson = scrubPayload(requestJson);
      final result = await callable.call<Map<String, dynamic>>(scrubbedJson);
      final response = parseResponse(result.data);
      _backendBreaker.recordSuccess();

      final success = _isSuccessful(response);
      if (success || recordUsageOnFailure) {
        final cost = _extractCost(response);
        await _rateLimiter.recordUsage(operation, llmCost: cost);
      }

      return response;
    } on FirebaseFunctionsException catch (e) {
      _backendBreaker.recordFailure();
      AppLogger.error('LlmService: Firebase error - ${e.code}: ${e.message}');
      throw LlmException.fromFirebase(e);
    } catch (e) {
      _backendBreaker.recordFailure();
      AppLogger.error('LlmService: Unexpected error - $e');
      throw LlmException(AppLocale.current.llmUnexpectedError('$e'));
    }
  }

  bool _isSuccessful(dynamic response) {
    if (response is StructureRecipeResponse) return response.success;
    if (response is OcrRecipeImageResponse) return response.success;
    return false;
  }

  double _extractCost(dynamic response) {
    if (response is StructureRecipeResponse) return response.estimatedCost;
    if (response is OcrRecipeImageResponse) return response.estimatedCost;
    return 0.0;
  }
}
