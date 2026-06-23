/// OCR service with multi-provider fallback (OCR.space → Google Vision → Tesseract), Swedish optimization, and smart caching.

import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/ocr/ocr_usage_tracker.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
import 'package:butlery/services/security/pinned_http_client_factory.dart';

/// OCR processing result with comprehensive metadata and quality metrics
class OCRResult {
  final String text;
  final double confidence;
  final String processingMethod;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final bool isSuccessful;
  final String? errorMessage;

  const OCRResult({
    required this.text,
    required this.confidence,
    required this.processingMethod,
    required this.metadata,
    required this.timestamp,
    this.isSuccessful = true,
    this.errorMessage,
  });

  factory OCRResult.failure({
    required String method,
    required String error,
    Map<String, dynamic>? metadata,
  }) {
    return OCRResult(
      text: '',
      confidence: 0.0,
      processingMethod: method,
      metadata: metadata ?? {},
      timestamp: clock.now(),
      isSuccessful: false,
      errorMessage: error,
    );
  }
}

/// Image quality assessment results for OCR optimization
class ImageQualityAssessment {
  final bool isGoodQuality;
  final double qualityScore; // 0.0 - 1.0
  final List<String> issues;
  final List<String> recommendations;

  /// BUT-660: hard-reject signal — OCR will not be attempted when this is
  /// true. The caller must surface [rejectionReason] to the user instead of
  /// spending OCR budget on an image that effectively cannot yield text.
  final bool isRejected;

  /// Localized actionable message shown to the user when [isRejected] is true.
  final String? rejectionReason;

  const ImageQualityAssessment({
    required this.isGoodQuality,
    required this.qualityScore,
    required this.issues,
    required this.recommendations,
    this.isRejected = false,
    this.rejectionReason,
  });
}

/// Circuit breaker state for OCR service resilience
enum CircuitBreakerState { closed, open, halfOpen }

class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;
  final Duration retryTimeout;
  final DateTime Function()? _timeProvider;

  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitBreakerState _state = CircuitBreakerState.closed;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
    this.retryTimeout = const Duration(minutes: 2),
    DateTime Function()? timeProvider,
  }) : _timeProvider = timeProvider;

  DateTime get _now => _timeProvider?.call() ?? clock.now();

  bool get canExecute {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        final now = _now;
        if (_lastFailureTime != null &&
            now.difference(_lastFailureTime!) > retryTimeout) {
          _state = CircuitBreakerState.halfOpen;
          return true;
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = _now;

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
    }
  }

  CircuitBreakerState get state => _state;
  int get failures => _failureCount;
}

/// Comprehensive OCR extraction service with universal device compatibility
class OCRExtractionService extends BaseService {
  static OCRExtractionService? _instance;
  static OCRExtractionService get instance =>
      _instance ??= OCRExtractionService._();

  // Test dependencies (injected for testing only)
  final http.Client? _testHttpClient;
  final String? _testOcrApiKey;
  final String? _testGoogleVisionKey;
  final String? _testTesseractApiUrl;
  final DateTime Function()? _testTimeProvider;

  OCRExtractionService._({
    http.Client? testHttpClient,
    String? testOcrApiKey,
    String? testGoogleVisionKey,
    String? testTesseractApiUrl,
    DateTime Function()? testTimeProvider,
  }) : _testHttpClient = testHttpClient,
       _testOcrApiKey = testOcrApiKey,
       _testGoogleVisionKey = testGoogleVisionKey,
       _testTesseractApiUrl = testTesseractApiUrl,
       _testTimeProvider = testTimeProvider {
    // Initialize circuit breakers with time provider
    _ocrSpaceCircuitBreaker = CircuitBreaker(timeProvider: testTimeProvider);
    _googleVisionCircuitBreaker = CircuitBreaker(
      timeProvider: testTimeProvider,
    );
    _tesseractCircuitBreaker = CircuitBreaker(timeProvider: testTimeProvider);
    _usageTracker = OCRUsageTracker(timeProvider: testTimeProvider);
    // First recordUsage on cold start may race with the load; tracker
    // reconciles via max() so the in-flight increment isn't lost.
    unawaited(_usageTracker.loadFromPersistence());
  }

  /// Create OCR service for testing with injectable dependencies.
  ///
  /// When [registerAsInstance] is true the created service is also installed
  /// as the static singleton, so static test hooks that operate on `instance`
  /// (e.g. [clearCacheForTesting]) act on this mock-driven service rather than
  /// a separate default singleton.
  @visibleForTesting
  static OCRExtractionService createForTesting({
    http.Client? testHttpClient,
    String? testOcrApiKey,
    String? testGoogleVisionKey,
    String? testTesseractApiUrl,
    DateTime Function()? testTimeProvider,
    bool registerAsInstance = false,
  }) {
    final service = OCRExtractionService._(
      testHttpClient: testHttpClient,
      testOcrApiKey: testOcrApiKey,
      testGoogleVisionKey: testGoogleVisionKey,
      testTesseractApiUrl: testTesseractApiUrl,
      testTimeProvider: testTimeProvider,
    );
    if (registerAsInstance) {
      _instance = service;
    }
    return service;
  }

  /// Reset singleton for testing (clears instance state)
  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  @override
  String get serviceName => 'OCRExtractionService';

  @override
  Future<void> onDispose() async {
    _cachedHttpClient?.close();
    _cachedHttpClient = null;
    await super.onDispose();
  }

  // Circuit breakers (late initialized with time provider)
  late final CircuitBreaker _ocrSpaceCircuitBreaker;
  late final CircuitBreaker _googleVisionCircuitBreaker;
  late final CircuitBreaker _tesseractCircuitBreaker;
  late final OCRUsageTracker _usageTracker;

  static const int _maxCacheSize = 100;

  /// Primary cache: keyed by SHA-256 of *preprocessed* bytes (BUT-666 — same
  /// logical image with different EXIF/quality collapses to one entry).
  /// BUT-817: migrated from timestamp-sort eviction (O(n log n) per evict) to
  /// LRU (O(1) per evict + recency awareness).
  late final LruMap<String, OCRResult> _cache = LruMap(
    maxSize: _maxCacheSize,
    onEvict: (key, _) => AppLogger.info(
      'cache_eviction service=OCRExtractionService cache=preprocessed key=$key bound=$_maxCacheSize',
    ),
  );

  /// Fast-path index: SHA-256 of *raw* bytes → preprocessed-bytes hash. Lets
  /// repeat-of-same-bytes (the common case) skip the preprocess pipeline and
  /// jump straight to `_cache`. Bounded the same way as `_cache`.
  late final LruMap<String, String> _rawHashToPreprocessedHash = LruMap(
    maxSize: _maxCacheSize,
    onEvict: (key, _) => AppLogger.info(
      'cache_eviction service=OCRExtractionService cache=raw_index key=$key bound=$_maxCacheSize',
    ),
  );
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const int _maxImageSize = UploadConstants.maxOcrImageBytes;
  static const double _minConfidenceThreshold = 0.6;

  // Lazily-created HTTP client (reused across calls, closed on dispose).
  // BUT-427: third-party OCR fallbacks (OCR.space, Google Vision, Tesseract)
  // are wrapped in PinnedHttpClient so a hostile-wifi attacker cannot
  // intercept upload bytes via a forged TLS cert. Pinning is no-op for hosts
  // without configured pins in CertPinConfig (TODO placeholders).
  http.Client? _cachedHttpClient;
  http.Client get _httpClient {
    if (_testHttpClient != null) return _testHttpClient;
    return _cachedHttpClient ??= PinnedHttpClientFactory.create();
  }

  String get _ocrApiKey {
    if (_testOcrApiKey != null) return _testOcrApiKey;
    return const String.fromEnvironment('OCR_SPACE_API_KEY');
  }

  String get _ocrApiUrl {
    return 'https://api.ocr.space/parse/image';
  }

  String get _googleVisionKey {
    if (_testGoogleVisionKey != null) return _testGoogleVisionKey;
    return const String.fromEnvironment('GOOGLE_VISION_API_KEY');
  }

  String get _tesseractApiUrl {
    if (_testTesseractApiUrl != null) return _testTesseractApiUrl;
    return const String.fromEnvironment('TESSERACT_API_URL');
  }

  DateTime get _now => _testTimeProvider?.call() ?? clock.now();

  /// Initialize OCR service
  @override
  Future<void> initialize() async {
    // OCR service ready - providers: OCR.space, Google Vision, Tesseract
  }

  /// Record OCR usage - delegates to usage tracker
  void _recordUsage(String provider) => _usageTracker.recordUsage(provider);

  /// Get usage statistics (for monitoring dashboard)
  Map<String, dynamic> getUsageStats() => _usageTracker.getUsageStats();

  /// Extract text from image using multi-tier OCR strategy.
  ///
  /// Two-level cache:
  /// 1. Fast path: SHA-256 of raw bytes → preprocessed-bytes hash. Repeat
  ///    of the exact same input skips preprocessing entirely.
  /// 2. Slow path: preprocess → SHA-256 of preprocessed bytes. Same logical
  ///    image with different EXIF/quality/container collapses to one cache
  ///    entry (BUT-666 — old raw-bytes-only hash spent OCR budget on
  ///    visually identical images).
  Future<OCRResult> extractText(Uint8List imageBytes) async {
    final rawHash = _generateImageHash(imageBytes);

    final knownPreprocessedHash = _rawHashToPreprocessedHash[rawHash];
    if (knownPreprocessedHash != null) {
      final cached = _getCachedResult(knownPreprocessedHash);
      if (cached != null) {
        _recordUsage('cache_hits');
        return cached;
      }
      _rawHashToPreprocessedHash.remove(rawHash);
    }

    final qualityAssessment = await assessImageQuality(imageBytes);

    // BUT-660: hard-reject before any preprocessing or OCR call. Saves
    // Mistral/OCR.space quota on inputs that cannot yield usable text
    // (bytes too small, resolution below [_minOcrShortEdgePx]).
    if (qualityAssessment.isRejected) {
      return OCRResult.failure(
        method: 'pre_ocr_quality_gate',
        error:
            qualityAssessment.rejectionReason ??
            'Image rejected by quality gate before OCR',
        metadata: {
          'quality_assessment': qualityAssessment.qualityScore,
          'recommendations': qualityAssessment.recommendations,
          'rejected_by_gate': true,
        },
      );
    }

    final preprocessedImage = await _preprocessImage(
      imageBytes,
      qualityAssessment,
    );

    final imageHash = _generateImageHash(preprocessedImage);
    final cachedResult = _getCachedResult(imageHash);
    if (cachedResult != null) {
      _rawHashToPreprocessedHash[rawHash] = imageHash;
      _recordUsage('cache_hits');
      return cachedResult;
    }
    OCRResult result;
    // BUT-963: capture each provider's last exception so the failure path
    // can classify the cause (rate limit / timeout / network / generic)
    // instead of collapsing every failure to "try better lighting."
    final providerErrors = <String, String>{};

    // No provider can run because none is configured (all API keys / URLs
    // absent). Without this guard the loop below attempts nothing, leaves
    // [providerErrors] empty, and the failure path classifies as "generic" —
    // surfacing the misleading "try better lighting" copy for what is actually
    // a missing-credentials misconfiguration. Mark every breaker `open` so the
    // message builder's "services unavailable" branch produces accurate copy.
    final noProviderConfigured =
        _ocrApiKey.isEmpty &&
        _googleVisionKey.isEmpty &&
        _tesseractApiUrl.isEmpty;
    if (noProviderConfigured) {
      return OCRResult.failure(
        method: 'no_provider_configured',
        error: 'OCR unavailable: no provider is configured (missing API keys)',
        metadata: {
          'quality_assessment': qualityAssessment.qualityScore,
          'recommendations': qualityAssessment.recommendations,
          'circuit_breakers': {
            'ocr_space_state': 'open',
            'google_vision_state': 'open',
            'tesseract_state': 'open',
          },
          'failure_classification': 'unavailable',
          'provider_errors': const <String, String>{},
        },
      );
    }

    if (_ocrSpaceCircuitBreaker.canExecute && _ocrApiKey.isNotEmpty) {
      try {
        result = await _extractWithOCRSpace(preprocessedImage);
        if (result.isSuccessful &&
            result.confidence >= _minConfidenceThreshold) {
          _ocrSpaceCircuitBreaker.recordSuccess();
          _recordUsage('ocr_space');
          _cacheResult(imageHash, result, rawHash: rawHash);
          return result;
        }
      } catch (e) {
        _ocrSpaceCircuitBreaker.recordFailure();
        providerErrors['ocr_space'] = e.toString();
      }
    }

    if (_googleVisionCircuitBreaker.canExecute && _googleVisionKey.isNotEmpty) {
      try {
        result = await _extractWithGoogleVision(preprocessedImage);
        if (result.isSuccessful &&
            result.confidence >= _minConfidenceThreshold) {
          _googleVisionCircuitBreaker.recordSuccess();
          _recordUsage('google_vision');
          _cacheResult(imageHash, result, rawHash: rawHash);
          return result;
        }
      } catch (e) {
        _googleVisionCircuitBreaker.recordFailure();
        providerErrors['google_vision'] = e.toString();
      }
    }

    if (_tesseractCircuitBreaker.canExecute && _tesseractApiUrl.isNotEmpty) {
      try {
        result = await _extractWithTesseract(preprocessedImage);
        if (result.isSuccessful &&
            result.confidence >= _minConfidenceThreshold) {
          _tesseractCircuitBreaker.recordSuccess();
          _recordUsage('tesseract');
          _cacheResult(imageHash, result, rawHash: rawHash);
          return result;
        }
      } catch (e) {
        _tesseractCircuitBreaker.recordFailure();
        providerErrors['tesseract'] = e.toString();
      }
    }

    // BUT-963: aggregate the captured provider exceptions into one of a
    // small enum of failure causes. The viewmodel picks user-facing copy
    // from this classification rather than mapping raw exception strings.
    final classification = _classifyProviderErrors(providerErrors);
    final failureResult = OCRResult.failure(
      method: 'user_recovery',
      error: 'OCR failed. Try: better lighting, clearer image, or manual input',
      metadata: {
        'quality_assessment': qualityAssessment.qualityScore,
        'recommendations': qualityAssessment.recommendations,
        'circuit_breakers': {
          'ocr_space_state': _ocrSpaceCircuitBreaker.state.name,
          'google_vision_state': _googleVisionCircuitBreaker.state.name,
          'tesseract_state': _tesseractCircuitBreaker.state.name,
        },
        'failure_classification': classification,
        'provider_errors': providerErrors,
      },
    );

    // Don't cache failures — they may be transient (network issues,
    // temporary provider outages) and caching them for 24h would
    // prevent successful retries.
    return failureResult;
  }

  /// BUT-963: classify a map of {provider → error string} into one of
  /// {rate_limit, timeout, network, unavailable, generic}. The viewmodel
  /// uses the result to pick localized copy. We pick the FIRST matching
  /// category in priority order — rate_limit wins over timeout wins over
  /// network — because the user-facing remedy differs (wait-then-retry vs
  /// check-connection).
  ///
  /// `unavailable` is reserved for "no provider could even be attempted"
  /// (caller decides via circuit-breaker states); this helper only sees
  /// providers that actually threw.
  /// BUT-1022: testing seam — the metadata-string contract between this
  /// classifier and `PhotoImportViewModel._buildEnhancedErrorMessage` is
  /// load-bearing. Direct unit coverage avoids the heavy HTTP-mocking dance
  /// that integration tests would require.
  @visibleForTesting
  static String classifyProviderErrorsForTesting(Map<String, String> errors) =>
      _classifyProviderErrors(errors);

  static String _classifyProviderErrors(Map<String, String> errors) {
    if (errors.isEmpty) return 'generic';
    final joined = errors.values.join(' | ').toLowerCase();
    if (joined.contains('429') ||
        joined.contains('rate limit') ||
        joined.contains('rate-limit') ||
        joined.contains('too many requests') ||
        joined.contains('quota')) {
      return 'rate_limit';
    }
    if (joined.contains('timeout') || joined.contains('timed out')) {
      return 'timeout';
    }
    if (joined.contains('socketexception') ||
        joined.contains('connection') ||
        joined.contains('network') ||
        joined.contains('unreachable') ||
        joined.contains('failed host lookup')) {
      return 'network';
    }
    return 'generic';
  }

  /// Reduce a locale tag to its bare ISO 639-1 language code, dropping any
  /// region/script suffix (`en_US`, `en-GB`, `sv_SE` → `en`/`en`/`sv`). The
  /// provider-language helpers below switch on the language only, so a
  /// regional locale must not fall through to the unknown-locale default.
  static String _languageCode(String localeName) =>
      localeName.split('_').first.split('-').first;

  /// Maps the active UI locale to the language code expected by OCR.space
  /// (ISO 639-2, single string). User-locale is the primary hint; 'eng' is the
  /// fallback for any unrecognised locale (OCR.space accepts only one code).
  @visibleForTesting
  static String ocrSpaceLanguage(String localeName) {
    switch (_languageCode(localeName)) {
      case 'sv':
        return 'swe';
      case 'en':
        return 'eng';
      default:
        return 'eng';
    }
  }

  /// Maps the active UI locale to Google Vision language hints (ISO 639-1
  /// array). User-locale goes first; the fallback language is always included
  /// so OCR stays robust for bilingual content.
  @visibleForTesting
  static List<String> googleVisionLanguageHints(String localeName) {
    switch (_languageCode(localeName)) {
      case 'sv':
        return ['sv', 'en'];
      case 'en':
        return ['en', 'sv'];
      default:
        // Unknown locale: keep Swedish + English — the app's primary audience.
        return ['sv', 'en'];
    }
  }

  /// Maps the active UI locale to a '+'-joined Tesseract language string
  /// (ISO 639-2). User-locale goes first; second language retained for
  /// bilingual robustness.
  @visibleForTesting
  static String tesseractLanguage(String localeName) {
    switch (_languageCode(localeName)) {
      case 'sv':
        return 'swe+eng';
      case 'en':
        return 'eng+swe';
      default:
        // Unknown locale: keep Swedish first (app default audience).
        return 'swe+eng';
    }
  }

  /// Extract text using OCR.space API (Primary - Universal compatibility)
  Future<OCRResult> _extractWithOCRSpace(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final request = http.MultipartRequest('POST', Uri.parse(_ocrApiUrl));
    request.fields['apikey'] = _ocrApiKey;
    request.fields['OCREngine'] = '2'; // Best for Swedish text
    request.fields['base64Image'] = 'data:image/jpeg;base64,$base64Image';
    // BUT-1053: use active UI locale for primary language hint; fallback to
    // 'eng' for unknown locales. OCR.space takes a single ISO 639-2 code.
    request.fields['language'] = ocrSpaceLanguage(AppLocale.current.localeName);
    request.fields['detectOrientation'] = 'true';
    request.fields['scale'] = 'true';
    request.fields['isTable'] = 'false';

    // _httpClient.send(request) routes through the (test-)injected client.
    // request.send() would create a fresh internal IOClient and bypass the
    // injected one, breaking testability and the singleton lifecycle.
    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody);

      if (json['IsErroredOnProcessing'] == false) {
        final parsedResults = json['ParsedResults'] as List?;
        final extractedText = HtmlSanitizer.instance.sanitizeText(
          (parsedResults?.first['ParsedText'] as String?).orEmpty(),
        );

        return OCRResult(
          text: extractedText,
          confidence: _calculateConfidenceFromText(extractedText),
          processingMethod: 'ocr_space',
          metadata: {
            'engine': '2',
            'language': 'swedish',
            'processing_time': _now.millisecondsSinceEpoch,
            'response_size': responseBody.length,
          },
          timestamp: _now,
        );
      } else {
        // API responded with success but processing failed
        final errorMessages = json['ErrorMessage'] as List?;
        final errorDetails =
            errorMessages?.join(', ') ?? 'OCR processing failed';
        throw Exception('OCR.space processing error: $errorDetails');
      }
    }

    throw Exception('OCR.space HTTP error: ${response.statusCode}');
  }

  /// Extract text using Google Vision API (Secondary fallback)
  Future<OCRResult> _extractWithGoogleVision(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final requestBody = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Image},
          'features': [
            {'type': 'TEXT_DETECTION', 'maxResults': 1},
          ],
          'imageContext': {
            // BUT-1053: user-locale first, fallback retained for robustness.
            'languageHints': googleVisionLanguageHints(
              AppLocale.current.localeName,
            ),
          },
        },
      ],
    });

    final response = await _httpClient
        .post(
          Uri.parse('https://vision.googleapis.com/v1/images:annotate'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _googleVisionKey,
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final responses = json['responses'] as List?;

      if (responses != null && responses.isNotEmpty) {
        final textAnnotations = responses.first['textAnnotations'] as List?;

        if (textAnnotations != null && textAnnotations.isNotEmpty) {
          final extractedText = HtmlSanitizer.instance.sanitizeText(
            (textAnnotations.first['description'] as String?).orEmpty(),
          );

          return OCRResult(
            text: extractedText,
            confidence: _calculateConfidenceFromText(extractedText),
            processingMethod: 'google_vision',
            metadata: {
              // BUT-1053: reflect the hints actually sent (locale-derived),
              // not a hardcoded pair — keeps debug/monitoring metadata honest.
              'language_hints': googleVisionLanguageHints(
                AppLocale.current.localeName,
              ),
              'processing_time': _now.millisecondsSinceEpoch,
              'annotations_count': textAnnotations.length,
            },
            timestamp: _now,
          );
        }
      }
    }

    throw Exception(
      'Google Vision API processing failed: ${response.statusCode}',
    );
  }

  /// Extract text using Tesseract API (Tertiary fallback)
  Future<OCRResult> _extractWithTesseract(Uint8List imageBytes) async {
    // This would connect to a hosted Tesseract service
    // For now, return a basic implementation

    final base64Image = base64Encode(imageBytes);

    final requestBody = jsonEncode({
      'image': base64Image,
      // BUT-1053: user-locale first, second language retained for robustness.
      'language': tesseractLanguage(AppLocale.current.localeName),
      'options': {
        'psm': '6', // Uniform block of text
        'oem': '3', // Default OCR engine mode
      },
    });

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_tesseractApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final extractedText = HtmlSanitizer.instance.sanitizeText(
          (json['text'] as String?).orEmpty(),
        );

        return OCRResult(
          text: extractedText,
          confidence: _calculateConfidenceFromText(extractedText),
          processingMethod: 'tesseract',
          metadata: {
            // BUT-1053: reflect the locale-derived language actually sent.
            'language': tesseractLanguage(AppLocale.current.localeName),
            'psm': '6',
            'processing_time': _now.millisecondsSinceEpoch,
          },
          timestamp: _now,
        );
      }
    } catch (e) {
      // Optional fallback
    }
    throw Exception('Tesseract API processing failed or not configured');
  }

  /// Assess image quality for OCR optimization (Phase 2 Enhancement - Now public for ViewModel access).
  /// [imageBytes] Raw image data to assess for OCR suitability
  /// Evaluates image quality metrics including size, resolution, and format to determine
  /// OCR readiness and provide actionable recommendations for improving extraction success.
  /// **Quality Assessment Process:**
  /// - Size validation: Too large (>10MB) or too small (<50KB) detection
  /// - Format validation: Optimal JPEG/PNG format checking
  /// - Quality scoring: 0.0-1.0 score based on image characteristics
  /// - Recommendation generation: Specific suggestions for improvement
  /// **Returns**: ImageQualityAssessment with score, issues list, and recommendations
  /// **Usage**: Called by ViewModel before OCR to warn users about quality issues
  Future<ImageQualityAssessment> assessImageQuality(
    Uint8List imageBytes,
  ) async {
    final issues = <String>[], recommendations = <String>[];
    double qualityScore = 1.0;
    bool isRejected = false;
    String? rejectionReason;

    if (imageBytes.length > _maxImageSize) {
      issues.add(AppLocale.current.ocrImageTooLarge);
      recommendations.add(AppLocale.current.ocrCompressImage);
      qualityScore -= 0.2;
    }
    if (imageBytes.length < UploadConstants.minOcrImageBytes) {
      // BUT-660: bytes below minOcrImageBytes (50 KB) is a hard reject. OCR
      // backends produce garbage on inputs this small, and the call would
      // burn Mistral/OCR.space quota on a guaranteed-fail attempt.
      issues.add(AppLocale.current.ocrImageTooSmall);
      recommendations.add(AppLocale.current.ocrUseHigherResolution);
      qualityScore -= 0.3;
      isRejected = true;
      rejectionReason = AppLocale.current.ocrImageRejected;
    }
    if (!ImageFormatUtils.isSupportedImage(imageBytes)) {
      issues.add(AppLocale.current.ocrImageFormatNotOptimal);
      recommendations.add(AppLocale.current.ocrUseJpegOrPng);
      qualityScore -= 0.1;
    }

    // BUT-660: short-edge resolution check — images below
    // [_minOcrShortEdgePx] reliably fail OCR even when bytes pass the size
    // gate (e.g. a heavily-compressed 800 KB JPEG can still be 400px wide).
    // Skip the decode when the bytes-size gate already rejected (saves the
    // decode cost on guaranteed-fail inputs).
    if (!isRejected) {
      final shortEdge = _shortEdgePixels(imageBytes);
      if (shortEdge != null && shortEdge < _minOcrShortEdgePx) {
        issues.add(AppLocale.current.ocrImageResolutionTooLow);
        recommendations.add(AppLocale.current.ocrUseHigherResolution);
        qualityScore -= 0.3;
        isRejected = true;
        rejectionReason = AppLocale.current.ocrImageRejected;
      }
    }

    return ImageQualityAssessment(
      isGoodQuality: qualityScore >= 0.6 && issues.isEmpty,
      qualityScore: math.max(0.0, qualityScore),
      issues: issues,
      recommendations: recommendations,
      isRejected: isRejected,
      rejectionReason: rejectionReason,
    );
  }

  /// BUT-660: minimum short-edge resolution for OCR to have any chance of
  /// succeeding. Backends produce garbage below this — the gate prevents
  /// burning OCR budget on inputs guaranteed to fail.
  static const int _minOcrShortEdgePx = 600;

  /// Decode just enough of [imageBytes] to read pixel dimensions and return
  /// the short edge. Returns null on decode failure (format check above will
  /// catch the bad-format case separately). The decode is heavier than a
  /// header-only read but matches the existing preprocessing path.
  int? _shortEdgePixels(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;
      return math.min(decoded.width, decoded.height);
    } catch (_) {
      return null;
    }
  }

  /// Preprocess image for optimal OCR results.
  ///
  /// Pure-function pipeline (deterministic — same input bytes always produce
  /// identical output bytes, enabling stable cache keys):
  /// 1. EXIF-orientation correction via `bakeOrientation()` so phone photos
  ///    taken sideways are uprighted before OCR.
  /// 2. Downscale so the long edge is at most [_maxLongEdge]. Vertex / OCR.space
  ///    don't benefit beyond ~2K and uploading larger only burns bandwidth/cost.
  /// 3. Greyscale + mild contrast stretch — helps OCR on low-light and
  ///    low-contrast cookbook photos.
  /// 4. JPEG re-encode at quality [_jpegQuality] to cap upload size and match
  ///    the OCR backends' expected input format.
  ///
  /// On decode failure (corrupted bytes, unsupported format) the original
  /// bytes are returned so the OCR providers still get a chance — they may
  /// have format-specific handling we don't.
  Future<Uint8List> _preprocessImage(
    Uint8List imageBytes,
    ImageQualityAssessment assessment,
  ) async {
    return preprocessImageForOcr(imageBytes);
  }

  /// Maximum long-edge in pixels after downscale. OCR engines don't gain
  /// accuracy beyond ~2K and larger inputs only inflate cost/latency.
  static const int _maxLongEdge = 2048;

  /// JPEG quality for re-encode. 85 is the standard "visually lossless,
  /// half the file size" sweet spot.
  static const int _jpegQuality = 85;

  /// Pure-function preprocessing entry point — exposed for unit tests.
  ///
  /// Idempotent in the sense that running it on already-preprocessed bytes
  /// will produce a different (re-encoded) result, but for any single input
  /// the output is deterministic.
  @visibleForTesting
  static Uint8List preprocessImageForOcr(Uint8List imageBytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(imageBytes);
    } catch (_) {
      // Some malformed inputs (notably tiny garbage) can throw out-of-range
      // errors from individual decoders inside the `image` package's
      // detection loop. Treat any decode error the same as a null decode:
      // hand the original bytes through and let the OCR provider decide.
      return imageBytes;
    }
    if (decoded == null) {
      // Couldn't decode — let the upstream provider try the raw bytes
      return imageBytes;
    }

    // Step 1: bake EXIF orientation into pixels
    var image = img.bakeOrientation(decoded);

    // Step 2: downscale long edge to _maxLongEdge if larger
    final longEdge = math.max(image.width, image.height);
    if (longEdge > _maxLongEdge) {
      if (image.width >= image.height) {
        image = img.copyResize(
          image,
          width: _maxLongEdge,
          interpolation: img.Interpolation.linear,
        );
      } else {
        image = img.copyResize(
          image,
          height: _maxLongEdge,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Step 3: greyscale + mild contrast stretch
    image = img.grayscale(image);
    image = img.contrast(image, contrast: 115); // ~1.15x contrast

    // Step 4: re-encode as JPEG q=85
    final jpegBytes = img.encodeJpg(image, quality: _jpegQuality);
    return Uint8List.fromList(jpegBytes);
  }

  /// Calculate confidence score from extracted text (universal method)
  double _calculateConfidenceFromText(String text) {
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
    final structureBonus = math.min(0.2, lineCount * 0.03);

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
    final keywordBonus = math.min(0.15, keywordMatches * 0.03);
    return math.min(1.0, baseConfidence + structureBonus + keywordBonus);
  }

  /// Generate hash for image caching
  String _generateImageHash(Uint8List imageBytes) {
    final digest = sha256.convert(imageBytes);
    return digest.toString();
  }

  /// Get cached OCR result if available and not expired
  OCRResult? _getCachedResult(String imageHash) {
    final cached = _cache[imageHash];
    if (cached != null) {
      final age = _now.difference(cached.timestamp);
      if (age <= _cacheExpiry) {
        return cached;
      } else {
        _cache.remove(imageHash);
      }
    }
    return null;
  }

  /// Cache OCR result. When a [rawHash] is supplied, also populates the
  /// fast-path index so a repeat of the exact same input bytes can skip
  /// preprocessing. LruMap handles size-bound eviction per insertion.
  void _cacheResult(String imageHash, OCRResult result, {String? rawHash}) {
    _cache[imageHash] = result;
    if (rawHash != null) {
      _rawHashToPreprocessedHash[rawHash] = imageHash;
    }
  }

  /// Get comprehensive OCR service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'timestamp': clock.now().toIso8601String(),
      'cache_size': _cache.length,
      'circuit_breakers': {
        'ocr_space': {
          'state': _ocrSpaceCircuitBreaker.state.name,
          'failures': _ocrSpaceCircuitBreaker.failures,
          'can_execute': _ocrSpaceCircuitBreaker.canExecute,
        },
        'google_vision': {
          'state': _googleVisionCircuitBreaker.state.name,
          'failures': _googleVisionCircuitBreaker.failures,
          'can_execute': _googleVisionCircuitBreaker.canExecute,
        },
        'tesseract': {
          'state': _tesseractCircuitBreaker.state.name,
          'failures': _tesseractCircuitBreaker.failures,
          'can_execute': _tesseractCircuitBreaker.canExecute,
        },
      },
      'device_compatibility': 'universal_ios_android',
      'api_keys_configured': {
        'ocr_space': _ocrApiKey.isNotEmpty,
        'google_vision': _googleVisionKey.isNotEmpty,
        'tesseract': _tesseractApiUrl.isNotEmpty,
      },
      'configuration': {
        'max_image_size_mb': _maxImageSize / (1024 * 1024),
        'min_confidence_threshold': _minConfidenceThreshold,
        'cache_expiry_hours': _cacheExpiry.inHours,
        'max_cache_size': _maxCacheSize,
      },
    };
  }

  /// Clear the service's own in-memory caches. Shared by [dispose] and the
  /// test hook so a test can reset OCR state without tearing down the
  /// singleton. The BaseService cache is cleared separately via
  /// [clearAllCache] — these LruMaps are not part of it.
  void _clearLocalCaches() {
    _cache.clear();
    _rawHashToPreprocessedHash.clear();
  }

  /// Clear cache for testing. Clears both the BaseService cache and the
  /// service's own OCR-result / raw-hash-index LruMaps — otherwise a test
  /// would see stale cache hits from a prior test's extractions.
  @visibleForTesting
  static void clearCacheForTesting() {
    instance.clearAllCache();
    instance._clearLocalCaches();
  }

  @override
  Future<void> dispose() async {
    _clearLocalCaches();
    await super.dispose();
  }
}
